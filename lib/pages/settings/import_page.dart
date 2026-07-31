import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull, Column;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../database/database.dart';
import '../../providers/database_provider.dart';
import '../../providers/encryption_provider.dart';
import '../../providers/entry_provider.dart';
import '../../providers/group_provider.dart';
import '../../providers/tag_provider.dart';
import '../../providers/calendar_data_provider.dart';
import '../../services/crypto_service.dart';
import '../../services/export_format.dart';

class ImportPage extends ConsumerStatefulWidget {
  const ImportPage({super.key});

  @override
  ConsumerState<ImportPage> createState() => _ImportPageState();
}

class _ImportPageState extends ConsumerState<ImportPage> {
  bool _importing = false;

  AppDatabase get db => ref.read(databaseProvider);

  Future<void> _pickAndImport() async {
    Map? result;
    try {
      result = await const MethodChannel('lite_diary/file_picker')
          .invokeMethod<Map>('pickFile');
    } catch (_) {
      _showResult('文件选择器不可用，请直接分享文件到应用');
      return;
    }
    if (result == null || !mounted) return;

    final filePath = result['path'] as String?;
    final fileName = result['name'] as String? ?? 'import.md';
    if (filePath == null) {
      _showResult('无法读取文件');
      return;
    }
    setState(() => _importing = true);

    String actualPath = filePath;
    // Check if this is a new-style outer-ZIP wrapping (.enc + _header.json)
    final isZip = fileName.endsWith('.zip');
    if (isZip) {
      final innerEnc = await _findEncInZip(filePath);
      if (innerEnc != null) {
        // new format: outer ZIP contains .enc + _header.json
        actualPath = innerEnc;
      }
    }

    final isEnc = fileName.contains('.enc') || actualPath != filePath;
    if (isEnc) {
      final cfg = await EncryptionConfig.load();
      if (cfg.keyHex.isEmpty) {
        _showResult('加密文件需要先配置加密密钥');
        setState(() => _importing = false);
        return;
      }
      try {
        final key = CryptoService.hexToKey(cfg.keyHex);
        final encBytes = await File(actualPath).readAsBytes();
        final decrypted = CryptoService.decrypt(Uint8List.fromList(encBytes), key);
        final decPath = '$filePath.dec';
        await File(decPath).writeAsBytes(decrypted);
        actualPath = decPath;
      } catch (_) {
        _showResult('解密失败，请检查加密密钥');
        setState(() => _importing = false);
        return;
      }
    }

    int importedCount = 0;
    int skippedCount = 0;

    try {
      final shouldExtractZip = isZip || isEnc;
      String content;
      final Map<String, String> imagePathMap = {};

      if (shouldExtractZip) {
        content = await _extractZip(actualPath, imagePathMap);
      } else {
        content = await File(actualPath).readAsString();
      }

      final entries = ExportFormat.parseEntries(content);
      for (final entryData in entries) {
        final date = ExportFormat.parseDate(entryData['date'] ?? '');
        if (date == null) {
          skippedCount++;
          continue;
        }

        final body = entryData['content'] ?? '';
        final hash = entryData['hash'] ?? '';
        final hasCreatedAt = entryData['created_at'] != null &&
            entryData['created_at']!.isNotEmpty;
        final createdAt =
            hasCreatedAt ? ExportFormat.parseDateTime(entryData['created_at']) ?? date : null;
        final updatedAt = ExportFormat.parseDateTime(entryData['updated_at']) ?? date;

        // Dedup: hash first (content-unique), created_at as fallback
        Entry? existing;
        if (hash.isNotEmpty) {
          existing = await db.getEntryByHash(hash);
        }
        if (existing == null && createdAt != null) {
          existing = await db.getEntryByCreatedAt(createdAt);
        }
        if (existing != null) {
          if (existing.updatedAt.isAtSameMomentAs(updatedAt) ||
              existing.updatedAt.isAfter(updatedAt)) {
            skippedCount++;
            continue;
          }
          // Cloud entry is newer — update
          await db.updateEntry(existing.id, EntriesCompanion(
            title: Value(entryData['title']),
            content: Value(body),
            hash: Value(hash.isNotEmpty ? hash : ExportFormat.computeHash(date, body)),
            updatedAt: Value(updatedAt),
            weather: Value(entryData['weather']),
            location: Value(entryData['location']),
          ));
          importedCount++;
          continue;
        }

        final groupId = await _resolveGroup(entryData['group'] ?? '日记');
        final dateStr = '${date.year}年${date.month}月${date.day}日';
        final title = (entryData['title'] != null && entryData['title']!.isNotEmpty)
            ? entryData['title']
            : dateStr;
        final weather = entryData['weather'];
        final location = entryData['location'];
        final effectiveCreatedAt = createdAt ??
            DateTime(date.year, date.month, date.day,
                DateTime.now().hour, DateTime.now().minute);

        // Replace image paths if importing from zip
        var processedContent = body;
        if (isZip && imagePathMap.isNotEmpty) {
          for (final entry in imagePathMap.entries) {
            processedContent = processedContent.replaceAll(entry.key, entry.value);
          }
        }

        final entryId = await db.createEntry(EntriesCompanion(
          title: Value(title),
          date: Value(date),
          content: Value(processedContent),
          groupId: Value(groupId),
          weather: Value(weather),
          location: Value(location),
          createdAt: Value(effectiveCreatedAt),
          updatedAt: Value(updatedAt),
          hash: Value(hash.isNotEmpty ? hash : ExportFormat.computeHash(date, processedContent)),
        ));

        // Attach tags
        final tagsStr = entryData['tags'];
        if (tagsStr != null && tagsStr.isNotEmpty) {
          final tagNames = tagsStr.split(',').map((t) => t.trim()).where((t) => t.isNotEmpty);
          for (final tagName in tagNames) {
            final tagId = await _resolveTag(tagName);
            await db.attachTag(entryId, tagId);
          }
        }

        // Create image records for zip images
        if (isZip && imagePathMap.isNotEmpty) {
          final appDir = await getApplicationDocumentsDirectory();
          for (final entry in imagePathMap.entries) {
            final origName = entry.key;
            final destPath = entry.value;
            final relPath = destPath.replaceFirst('${appDir.path}/', '');
            await db.into(db.images).insert(ImagesCompanion(
              entryId: Value(entryId),
              filePath: Value(relPath),
              originalName: Value(origName),
            ));
          }
        }

        importedCount++;
      }

      if (mounted) {
        ref.invalidate(allEntriesProvider);
        ref.invalidate(allGroupsProvider);
        ref.invalidate(allTagsProvider);
        ref.invalidate(calendarDateCountsProvider);
        _showResult('已导入 $importedCount 篇，跳过 $skippedCount 篇（重复）');
      }
    } catch (e) {
      if (mounted) _showResult('导入失败：$e');
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  /// Checks if the ZIP is an outer wrapper containing a .enc file.
  /// Returns the path to the extracted .enc file, or null.
  Future<String?> _findEncInZip(String zipPath) async {
    final bytes = await File(zipPath).readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);
    for (final file in archive) {
      if (file.isFile && file.name.endsWith('.enc')) {
        final tempDir = await Directory.systemTemp.createTemp('import_enc_');
        final encPath = '${tempDir.path}/${file.name}';
        await File(encPath).parent.create(recursive: true);
        await File(encPath).writeAsBytes(file.content as List<int>);
        return encPath;
      }
    }
    return null;
  }

  Future<String> _extractZip(String zipPath, Map<String, String> imagePathMap) async {
    final bytes = await File(zipPath).readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);

    final tempDir = await Directory.systemTemp.createTemp('diary_import_');

    String? mdContent;

    for (final file in archive) {
      if (file.isFile) {
        final name = file.name;
        if (name.endsWith('.md')) {
          mdContent = utf8.decode(file.content as List<int>);
        } else {
          // Image file
          final destFile = File('${tempDir.path}/$name');
          await destFile.parent.create(recursive: true);
          await destFile.writeAsBytes(file.content as List<int>);
          imagePathMap[name] = destFile.path;
        }
      }
    }

    if (mdContent == null) throw Exception('ZIP 中未找到 .md 文件');
    return mdContent;
  }

  Future<int> _resolveGroup(String name) async {
    final groups = await db.getAllGroups();
    final existing = groups.where((g) => g.name == name);
    if (existing.isNotEmpty) return existing.first.id;
    return await db.createGroup(GroupsCompanion(name: Value(name)));
  }

  Future<int> _resolveTag(String name) async {
    final existing = await db.getTagByName(name);
    if (existing != null) return existing.id;
    return await db.createTag(TagsCompanion(name: Value(name)));
  }

  void _showResult(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 3)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('导入')),
      body: Center(
        child: _importing
            ? const Column(mainAxisSize: MainAxisSize.min, children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('正在导入...'),
              ])
            : Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.file_upload, size: 64, color: Theme.of(context).colorScheme.onSurfaceVariant),
                const SizedBox(height: 16),
                Text('选择导出的 .zip 或 .enc 文件', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _pickAndImport,
                  icon: const Icon(Icons.file_open),
                  label: const Text('选择文件'),
                ),
              ]),
      ),
    );
  }
}
