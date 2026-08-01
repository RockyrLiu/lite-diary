import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull, Column;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../database/database.dart';
import '../providers/database_provider.dart';
import '../providers/encryption_provider.dart';
import '../providers/entry_provider.dart';
import '../providers/group_provider.dart';
import '../providers/tag_provider.dart';
import '../providers/calendar_data_provider.dart';
import 'crypto_service.dart';
import 'dav_service.dart';
import 'export_format.dart';

const _prefKeyDavUri = 'dav_uri';
const _prefKeyDavUser = 'dav_user';
const _prefKeyDavPassword = 'dav_password';
const _prefKeySyncHash = 'cloud_sync_hash';

class CloudBackupService {
  final WidgetRef ref;
  final AppDatabase db;

  CloudBackupService(this.ref) : db = ref.read(databaseProvider);

  Future<(Uint8List, String)?> _encryptionContext() async {
    final cfg = await EncryptionConfig.load();
    if (cfg.keyHex.isEmpty) return null;
    final key = CryptoService.hexToKey(cfg.keyHex);
    return (key, cfg.salt);
  }

  // ── WebDAV Config ──

  Future<DAVService?> _createClient() async {
    final prefs = await SharedPreferences.getInstance();
    final uri = prefs.getString(_prefKeyDavUri);
    final user = prefs.getString(_prefKeyDavUser);
    final password = prefs.getString(_prefKeyDavPassword);
    if (uri == null || uri.isEmpty) return null;
    return DAVService(uri: uri, user: user ?? '', password: password ?? '');
  }

  Future<void> saveDavConfig(String uri, String user, String password) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKeyDavUri, uri);
    await prefs.setString(_prefKeyDavUser, user);
    await prefs.setString(_prefKeyDavPassword, password);
  }

  Future<void> deleteDavConfig() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefKeyDavUri);
    await prefs.remove(_prefKeyDavUser);
    await prefs.remove(_prefKeyDavPassword);
    await prefs.remove(_prefKeySyncHash);
  }

  Future<({String uri, String user, bool configured})> getDavConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final uri = prefs.getString(_prefKeyDavUri) ?? '';
    final user = prefs.getString(_prefKeyDavUser) ?? '';
    return (uri: uri, user: user, configured: uri.isNotEmpty);
  }

  Future<bool> testConnection() async {
    final client = await _createClient();
    return client?.ping() ?? false;
  }

  // ── Backup ──

  Future<({int uploaded, String message})> backup({
    bool encrypt = false,
    void Function(String status)? onProgress,
  }) async {
    final client = await _createClient();
    if (client == null) {
      return (uploaded: 0, message: '未配置 WebDAV');
    }

    onProgress?.call('正在收集本地数据...');
    final entries = await db.getAllEntries();
    final groups = await db.getAllGroups();
    final tagMap = await db.getEntryTagsMap();
    final imageRecords = await _collectImages(entries);

    onProgress?.call('正在比对云端数据...');
    final manifest = _buildManifest(entries);
    final manifestHash = _hashJson(manifest);

    final header = await client.readJson('_header.json');
    if (header != null) {
      final remoteHash = header['hash'] as String? ?? '';
      if (remoteHash == manifestHash) {
        return (uploaded: 0, message: '已是最新，无需备份');
      }
    }

    onProgress?.call('正在打包...');
    final tempDir = await Directory.systemTemp.createTemp('cloud_backup_');
    final entriesWithResolvedImages = entries.map((e) {
      var content = e.content;
      for (final img in imageRecords.where((r) => r.entryId == e.id)) {
        content = content.replaceAll(img.originalPath, img.destPath);
      }
      return e.copyWith(content: content);
    }).toList();
    final groupNames = {for (final g in groups) g.id: g.name};
    final mdContent = ExportFormat.serializeEntries(entriesWithResolvedImages, tagMap, groupNames);
    final mdFile = File('${tempDir.path}/export.md');
    await mdFile.writeAsString(mdContent);

    final manifestFile = File('${tempDir.path}/_manifest.json');
    await manifestFile.writeAsString(jsonEncode(manifest));

    for (final r in imageRecords) {
      final dest = File('${tempDir.path}/${r.destPath}');
      await dest.parent.create(recursive: true);
      await File(r.sourcePath).copy(dest.path);
    }

    final zipPath = '${tempDir.path}/backup.zip';
    final encoder = ZipFileEncoder()..create(zipPath);
    await encoder.addFile(mdFile, 'export.md');
    await encoder.addFile(manifestFile, '_manifest.json');
    for (final r in imageRecords) {
      await encoder.addFile(File('${tempDir.path}/${r.destPath}'), r.destPath);
    }
    await encoder.close();

    final encCtx = encrypt ? await _encryptionContext() : null;
    final headerData = <String, dynamic>{
      'hash': manifestHash,
      'encrypted': encCtx != null,
    };
    String uploadPath = zipPath;
    String uploadName = 'backup.zip';

    if (encCtx != null) {
      final (key, salt) = encCtx;
      onProgress?.call('正在加密...');
      final zipBytes = await File(zipPath).readAsBytes();
      final encrypted = CryptoService.encrypt(Uint8List.fromList(zipBytes), key);
      final encPath = '${tempDir.path}/backup.zip.enc';
      await File(encPath).writeAsBytes(encrypted);
      uploadPath = encPath;
      uploadName = 'backup.zip.enc';
      headerData['salt'] = salt;
    }

    onProgress?.call('正在上传...');
    await client.uploadString(jsonEncode(headerData), '_header.json');
    await client.uploadFile(uploadPath, uploadName);

    await _saveSyncHash(manifestHash);

    return (uploaded: entries.length, message: '备份成功');
  }

  // ── Restore ──

  Future<({int imported, int skipped, String message})> restore({
    void Function(String status)? onProgress,
  }) async {
    final client = await _createClient();
    if (client == null) {
      return (imported: 0, skipped: 0, message: '未配置 WebDAV');
    }

    onProgress?.call('正在检查云端状态...');
    final header = await client.readJson('_header.json');
    if (header == null) {
      return (imported: 0, skipped: 0, message: '云端无备份数据');
    }

    final encrypted = header['encrypted'] as bool? ?? false;

    final tempDir = await Directory.systemTemp.createTemp('cloud_restore_');
    String dlName;
    if (encrypted) {
      dlName = 'backup.zip.enc';
    } else {
      final hasOld = await client.readJson('_metadata.json') != null;
      dlName = hasOld ? 'backup.zip' : 'backup.zip';
    }

    onProgress?.call('正在下载备份...');
    final dlPath = '${tempDir.path}/$dlName';
    final downloaded = await client.downloadFile(dlName, dlPath);
    if (!downloaded) {
      return (imported: 0, skipped: 0, message: '下载失败');
    }

    String zipPath = dlPath;

    if (encrypted) {
      onProgress?.call('正在解密...');
      final encCfg = await EncryptionConfig.load();
      Uint8List key;
      if (encCfg.keyHex.isNotEmpty) {
        key = CryptoService.hexToKey(encCfg.keyHex);
      } else {
        return (imported: 0, skipped: 0, message: '未配置加密密钥');
      }
      final encBytes = await File(dlPath).readAsBytes();
      final decrypted = CryptoService.decrypt(Uint8List.fromList(encBytes), key);
      zipPath = '${tempDir.path}/backup.zip';
      await File(zipPath).writeAsBytes(decrypted);
    }

    onProgress?.call('正在解压...');
    final bytes = await File(zipPath).readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);
    final extractDir = '${tempDir.path}/extract';
    await Directory(extractDir).create(recursive: true);

    String? mdContent;
    final imageFiles = <String, String>{};
    for (final file in archive) {
      if (file.isFile) {
        final outPath = '$extractDir/${file.name}';
        final outFile = File(outPath);
        await outFile.parent.create(recursive: true);
        await outFile.writeAsBytes(file.content as List<int>);
        if (file.name == 'export.md') {
          mdContent = utf8.decode(file.content as List<int>);
        } else if (!file.name.startsWith('_')) {
          imageFiles[file.name] = outPath;
        }
      }
    }

    if (mdContent == null) {
      return (imported: 0, skipped: 0, message: '备份文件无效');
    }

    onProgress?.call('正在导入...');
    final result = await _importEntries(mdContent, imageFiles, onProgress);
    ref.invalidate(allEntriesProvider);
    ref.invalidate(allGroupsProvider);
    ref.invalidate(allTagsProvider);
    ref.invalidate(calendarDateCountsProvider);

    final newHeader = await client.readJson('_header.json');
    if (newHeader != null) {
      await _saveSyncHash(newHeader['hash'] as String? ?? '');
    }

    return result;
  }

  // ── Common Import Logic ──

  Future<({int imported, int skipped, String message})> _importEntries(
    String mdContent,
    Map<String, String> imageFiles,
    void Function(String)? onProgress,
  ) async {
    final parsed = ExportFormat.parseEntries(mdContent);
    int imported = 0;
    int skipped = 0;

    final allGroups = await db.getAllGroups();
    final groupNameMap = {for (final g in allGroups) g.name: g.id};
    final allTags = await db.getAllTags();
    final tagNameMap = {for (final t in allTags) t.name: t.id};

    final appDir = await getApplicationDocumentsDirectory();

    for (final entryData in parsed) {
      final date = ExportFormat.parseDate(entryData['date']);
      if (date == null) { skipped++; continue; }

      final hash = entryData['hash'] ?? '';
      final hasCreatedAt = entryData['created_at'] != null && entryData['created_at']!.isNotEmpty;
      final createdAt = hasCreatedAt ? ExportFormat.parseDateTime(entryData['created_at']) ?? date : null;
      final updatedAt = ExportFormat.parseDateTime(entryData['updated_at']) ?? date;

      Entry? existing;
      if (hash.isNotEmpty) {
        existing = await db.getEntryByHash(hash);
      }
      if (existing == null && createdAt != null) {
        existing = await db.getEntryByCreatedAt(createdAt);
      }
      if (existing != null) {
        if (!existing.updatedAt.isBefore(updatedAt)) { skipped++; continue; }
        await db.updateEntry(existing.id, EntriesCompanion(
          title: Value(entryData['title']),
          content: Value(entryData['content'] ?? ''),
          hash: Value(hash),
          updatedAt: Value(updatedAt),
          weather: Value(entryData['weather']),
          location: Value(entryData['location']),
          moodScore: const Value(null),
        ));
        imported++; continue;
      }

      final groupName = entryData['group'] ?? '日记';
      int groupId;
      if (groupNameMap.containsKey(groupName)) {
        groupId = groupNameMap[groupName]!;
      } else {
        groupId = await db.createGroup(GroupsCompanion(name: Value(groupName)));
        groupNameMap[groupName] = groupId;
      }

      var body = entryData['content'] ?? '';
      for (final imgEntry in imageFiles.entries) {
        final relPath = imgEntry.key;
        final srcPath = imgEntry.value;
        final destPath = '${appDir.path}/$relPath';
        final destFile = File(destPath);
        if (!await destFile.exists()) {
          await destFile.parent.create(recursive: true);
          await File(srcPath).copy(destPath);
        }
        body = body.replaceAll(relPath, destPath);
      }

      final dateStr = '${date.year}年${date.month}月${date.day}日';
      final title = (entryData['title'] != null && entryData['title']!.isNotEmpty) ? entryData['title'] : dateStr;

      final effectiveCreatedAt = createdAt ?? DateTime(date.year, date.month, date.day, DateTime.now().hour, DateTime.now().minute);

      final entryId = await db.createEntry(EntriesCompanion(
        title: Value(title), date: Value(date), content: Value(body),
        groupId: Value(groupId), weather: Value(entryData['weather']),
        location: Value(entryData['location']), createdAt: Value(effectiveCreatedAt),
        updatedAt: Value(updatedAt),
        hash: Value((entryData['hash'] ?? '').isEmpty ? ExportFormat.computeHash(date, body) : entryData['hash']!),
      ));

      final tagsStr = entryData['tags'];
      if (tagsStr != null && tagsStr.isNotEmpty) {
        for (final tagName in tagsStr.split(',').map((t) => t.trim()).where((t) => t.isNotEmpty)) {
          int tagId;
          if (tagNameMap.containsKey(tagName)) {
            tagId = tagNameMap[tagName]!;
          } else {
            tagId = await db.createTag(TagsCompanion(name: Value(tagName)));
            tagNameMap[tagName] = tagId;
          }
          await db.attachTag(entryId, tagId);
        }
      }
      imported++;
    }

    return (imported: imported, skipped: skipped, message: '恢复完成');
  }

  // ── Manifest / Header ──

  Map<String, dynamic> _buildManifest(List<Entry> entries) {
    return {
      'count': entries.length,
      'entries': entries
          .map((e) => {
                'created_at': ExportFormat.dateTimeStr(e.createdAt),
                'hash': e.hash ?? ExportFormat.computeHash(e.date, e.content),
                'updated_at': ExportFormat.dateTimeStr(e.updatedAt),
              })
          .toList()
        ..sort((a, b) => (a['created_at'] as String).compareTo(b['created_at'] as String)),
    };
  }

  String _hashJson(Map<String, dynamic> json) {
    return sha256.convert(utf8.encode(jsonEncode(json))).toString();
  }

  Future<void> _saveSyncHash(String hash) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKeySyncHash, hash);
  }

  // ── Image collection ──

  Future<List<_ImageBackup>> _collectImages(List<Entry> entries) async {
    final appDir = await getApplicationDocumentsDirectory();
    final records = <_ImageBackup>[];
    for (final e in entries) {
      final images = await (db.select(db.images)..where((i) => i.entryId.equals(e.id))).get();
      for (final img in images) {
        final absPath = '${appDir.path}/${img.filePath}';
        if (await File(absPath).exists()) {
          records.add(_ImageBackup(sourcePath: absPath, destPath: img.filePath, originalPath: absPath, entryId: e.id));
        }
      }
    }
    return records;
  }
}

class _ImageBackup {
  final String sourcePath;
  final String destPath;
  final String originalPath;
  final int entryId;
  const _ImageBackup({required this.sourcePath, required this.destPath, required this.originalPath, required this.entryId});
}
