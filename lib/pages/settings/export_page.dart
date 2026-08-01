import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../database/database.dart';
import '../../providers/database_provider.dart';
import '../../providers/encryption_provider.dart';
import '../../services/crypto_service.dart';
import '../../services/export_format.dart';
import '../../services/lunar_calendar.dart';

class ExportPage extends ConsumerStatefulWidget {
  const ExportPage({super.key});

  @override
  ConsumerState<ExportPage> createState() => _ExportPageState();
}

class _ExportPageState extends ConsumerState<ExportPage> {
  bool _encrypt = false;
  bool _hasEncryptionKey = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final cfg = await EncryptionConfig.load();
      if (mounted) {
        setState(() {
          _hasEncryptionKey = cfg.keyHex.isNotEmpty;
          _encrypt = _hasEncryptionKey;
        });
      }
    });
  }

  void _showSnackBar(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: error ? Theme.of(context).colorScheme.error : null,
      duration: const Duration(seconds: 3),
    ));
  }

  // ── Date range dialog ──

  Future<_DateRange?> _pickDateRange({bool defaultAllTime = false}) async {
    if (mounted) {
      ScaffoldMessenger.of(context).clearSnackBars();
    }
    final startCtrl = TextEditingController(
        text: '${DateTime.now().year}-01-01');
    final endCtrl = TextEditingController(
        text: ExportFormat.dateStr(DateTime.now()));
    bool allTime = defaultAllTime;
    String? errorText;

    bool parseDate(String s) {
      final parts = s.split('-');
      if (parts.length != 3) return false;
      final y = int.tryParse(parts[0]), m = int.tryParse(parts[1]), d = int.tryParse(parts[2]);
      return y != null && m != null && d != null && m >= 1 && m <= 12 && d >= 1 && d <= 31;
    }

    String? validate() {
      if (allTime) return null;
      final start = startCtrl.text;
      final end = endCtrl.text;
      if (start.isEmpty || end.isEmpty) return '请输入日期';
      if (!parseDate(start)) return '起始日期格式错误';
      if (!parseDate(end)) return '结束日期格式错误';
      final partsS = start.split('-');
      final partsE = end.split('-');
      final s = DateTime(int.parse(partsS[0]), int.parse(partsS[1]), int.parse(partsS[2]));
      final e = DateTime(int.parse(partsE[0]), int.parse(partsE[1]), int.parse(partsE[2]));
      if (s.isAfter(e)) return '起始日期不能晚于结束日期';
      return null;
    }

    final picked = await showDialog<_DateRange>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            title: const Text('选择导出时间'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CheckboxListTile(
                  value: allTime,
                  onChanged: (v) {
                    setDialogState(() {
                      allTime = v ?? false;
                      errorText = null;
                    });
                  },
                  title: const Text('所有时间'),
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: startCtrl,
                  enabled: !allTime,
                  decoration: const InputDecoration(
                    labelText: '起始日期',
                    hintText: '2024-01-01',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: endCtrl,
                  enabled: !allTime,
                  decoration: const InputDecoration(
                    labelText: '结束日期',
                    hintText: '2026-07-29',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                if (errorText != null) ...[
                  const SizedBox(height: 8),
                  Text(errorText!, style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 13)),
                ],
              ],
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('取消')),
              FilledButton(
                onPressed: () {
                  final err = validate();
                  if (err != null) {
                    setDialogState(() => errorText = err);
                    return;
                  }
                  if (allTime) {
                    Navigator.pop(ctx, _DateRange.all());
                  } else {
                    final s = startCtrl.text.split('-');
                    final e = endCtrl.text.split('-');
                    Navigator.pop(ctx, _DateRange(
                      start: DateTime(int.parse(s[0]), int.parse(s[1]), int.parse(s[2])),
                      end: DateTime(int.parse(e[0]), int.parse(e[1]), int.parse(e[2])),
                    ));
                  }
                },
                child: const Text('确定'),
              ),
            ],
          );
        },
      ),
    );
    return picked;
  }

  // ── Group picker ──

  Future<Group?> _pickGroup() async {
    final db = ref.read(databaseProvider);
    final groups = await db.getAllGroups();
    if (!mounted) return null;

    return showDialog<Group>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('选择分组'),
        children: groups
            .map((g) => SimpleDialogOption(
                  onPressed: () => Navigator.pop(ctx, g),
                  child: Text(g.name),
                ))
            .toList(),
      ),
    );
  }

  // ── Image helpers ──

  Future<List<_ImageRecord>> _collectImages(List<Entry> entries) async {
    final db = ref.read(databaseProvider);
    final appDir = await getApplicationDocumentsDirectory();
    final records = <_ImageRecord>[];

    for (final entry in entries) {
      final images = await (db.select(db.images)
            ..where((i) => i.entryId.equals(entry.id)))
          .get();
      for (final image in images) {
        final absPath = '${appDir.path}/${image.filePath}';
        if (await File(absPath).exists()) {
          records.add(_ImageRecord(
            sourceAbsPath: absPath,
            destRelPath: image.filePath,
            entryId: entry.id,
          ));
        }
      }
    }
    return records;
  }

  String _replaceImagePaths(String content, List<_ImageRecord> records, int entryId) {
    var result = content;
    for (final r in records.where((r) => r.entryId == entryId)) {
      result = result.replaceAll(r.sourceAbsPath, r.destRelPath);
      result = result.replaceAll(r.sourceAbsPath.replaceAll('/', '\\'), r.destRelPath);
    }
    return result;
  }

  Future<String> _buildZip(
      String mdFileName, StringBuffer mdContent, List<_ImageRecord> imageRecords,
      {String? manifestJson}) async {
    final tempDir = await Directory.systemTemp.createTemp('diary_export_');
    final mdFile = File('${tempDir.path}/$mdFileName');
    await mdFile.writeAsString(mdContent.toString());

    File? metaFile;
    if (manifestJson != null) {
      metaFile = File('${tempDir.path}/_manifest.json');
      await metaFile.writeAsString(manifestJson);
    }

    for (final r in imageRecords) {
      final destFile = File('${tempDir.path}/${r.destRelPath}');
      await destFile.parent.create(recursive: true);
      await File(r.sourceAbsPath).copy(destFile.path);
    }

    final zipPath = '${tempDir.path}/$mdFileName.zip';
    final encoder = ZipFileEncoder()..create(zipPath);
    await encoder.addFile(mdFile, mdFileName);
    if (metaFile != null) {
      await encoder.addFile(metaFile, '_manifest.json');
    }
    for (final r in imageRecords) {
      await encoder.addFile(File('${tempDir.path}/${r.destRelPath}'), r.destRelPath);
    }
    await encoder.close();

    return zipPath;
  }

  // ── Export: 日记 ──

  Future<void> _exportDiary() async {
    final range = await _pickDateRange();
    if (range == null) return;

    final db = ref.read(databaseProvider);
    final groups = await db.getAllGroups();
    Group? diaryGroup;
    try {
      diaryGroup = groups.firstWhere((g) => g.name == '日记');
    } catch (_) {
      _showSnackBar('未找到"日记"分组', error: true);
      return;
    }

    final allEntries = await db.getEntriesByGroup(diaryGroup.id);
    final entries = range.allTime
        ? allEntries
        : allEntries.where((e) => ExportFormat.inRange(e.date, range.start, range.end, range.allTime)).toList();
    if (entries.isEmpty) { _showSnackBar('未找到符合条件的日记', error: true); return; }
    entries.sort((a, b) => a.date.compareTo(b.date));

    final tagMap = await db.getEntryTagsMap();

    final nameSuffix = range.allTime ? '全部' : '${ExportFormat.dateStr(range.start)}_${ExportFormat.dateStr(range.end)}';
    await _doEntriesZip(entries, tagMap, groups, '日记_$nameSuffix.md');
  }

  // ── Export: 诗稿 ──

  Future<void> _exportPoetry() async {
    final range = await _pickDateRange();
    if (range == null) return;

    final db = ref.read(databaseProvider);
    final groups = await db.getAllGroups();
    Group? poetryGroup;
    try {
      poetryGroup = groups.firstWhere((g) => g.name == '诗词');
    } catch (_) {
      _showSnackBar('未找到"诗词"分组，请先创建', error: true);
      return;
    }

    final allEntries = await db.getEntriesByGroup(poetryGroup.id);
    final entries = range.allTime
        ? allEntries
        : allEntries.where((e) => ExportFormat.inRange(e.date, range.start, range.end, range.allTime)).toList();
    if (entries.isEmpty) { _showSnackBar('未找到符合条件的诗稿', error: true); return; }
    entries.sort((a, b) => a.date.compareTo(b.date));

    final imageRecords = await _collectImages(entries);
    final firstYear = entries.first.date.year;
    final ganZhiYear = LunarService.ganZhiYear(firstYear);
    final nameSuffix = range.allTime ? '' : '_${ExportFormat.dateStr(range.start)}_${ExportFormat.dateStr(range.end)}';
    final fileName = '$ganZhiYear诗稿$nameSuffix.md';

    final buffer = StringBuffer();
    buffer.writeln('# $ganZhiYear诗稿');
    buffer.writeln();

    buffer.writeln('## 目录');
    buffer.writeln();
    for (final entry in entries) {
      final title = entry.title ?? '无标题';
      final lunar = LunarService.lunarDay(entry.date);
      buffer.writeln('- [$title  $lunar](#${Uri.encodeComponent(title)})');
    }
    buffer.writeln();

    for (final entry in entries) {
      final title = entry.title ?? '无标题';
      final lunar = LunarService.lunarDay(entry.date);
      final content = _replaceImagePaths(entry.content, imageRecords, entry.id);
      buffer.writeln('## $title  $lunar');
      buffer.writeln();
      buffer.writeln(content);
      buffer.writeln();
    }

    final zipPath = await _buildZip(fileName, buffer, imageRecords);
    if (mounted) {
      await _shareOrSave(zipPath, fileName, entries.length);
    }
  }

  // ── Export: 分组 ──

  Future<void> _exportByGroup() async {
    final group = await _pickGroup();
    if (group == null) return;

    final range = await _pickDateRange();
    if (range == null) return;

    final db = ref.read(databaseProvider);
    final allEntries = await db.getEntriesByGroup(group.id);
    final entries = range.allTime
        ? allEntries
        : allEntries.where((e) => ExportFormat.inRange(e.date, range.start, range.end, range.allTime)).toList();
    if (entries.isEmpty) { _showSnackBar('未找到符合条件的"${group.name}"分组日记', error: true); return; }
    entries.sort((a, b) => a.date.compareTo(b.date));

    final tagMap = await db.getEntryTagsMap();
    final groups = await db.getAllGroups();

    final nameSuffix = range.allTime ? '全部' : '${ExportFormat.dateStr(range.start)}_${ExportFormat.dateStr(range.end)}';
    await _doEntriesZip(entries, tagMap, groups, '${group.name}_$nameSuffix.md');
  }

  // ── Export: 所有数据 ──

  Future<void> _exportAll() async {
    final range = await _pickDateRange(defaultAllTime: true);
    if (range == null) return;

    final db = ref.read(databaseProvider);
    final entries = await db.getAllEntries();
    final filtered = range.allTime
        ? entries
        : entries.where((e) => ExportFormat.inRange(e.date, range.start, range.end, range.allTime)).toList();
    if (filtered.isEmpty) { _showSnackBar('未找到符合条件的数据', error: true); return; }
    filtered.sort((a, b) => a.date.compareTo(b.date));

    final tagMap = await db.getEntryTagsMap();
    final groups = await db.getAllGroups();

    final nameSuffix = range.allTime ? '全部' : '${ExportFormat.dateStr(range.start)}_${ExportFormat.dateStr(range.end)}';
    await _doEntriesZip(filtered, tagMap, groups, '全部日记_$nameSuffix.md');
  }

  // ── Common: entries → zip → share ──

  Future<void> _doEntriesZip(List<Entry> entries, Map<int, List<String>> tagMap, List<Group> groups, String fileName) async {
    final imageRecords = await _collectImages(entries);

    final groupNameById = {for (final g in groups) g.id: g.name};

    final entriesWithResolvedImages = entries.map((entry) {
      final content = _replaceImagePaths(entry.content, imageRecords, entry.id);
      return entry.copyWith(content: content);
    }).toList();

    final buffer = StringBuffer();
    buffer.write(ExportFormat.serializeEntries(entriesWithResolvedImages, tagMap, groupNameById));

    final manifestJson = jsonEncode({
      'version': 1,
      'exported_at': ExportFormat.dateTimeStr(DateTime.now()),
      'entries': entries
          .map((e) => {
                'created_at': ExportFormat.dateTimeStr(e.createdAt),
                'hash': e.hash ?? ExportFormat.computeHash(e.date, e.content),
                'updated_at': ExportFormat.dateTimeStr(e.updatedAt),
              })
          .toList()
        ..sort((a, b) =>
            (a['created_at'] as String).compareTo(b['created_at'] as String)),
    });

    final zipPath = await _buildZip(fileName, buffer, imageRecords,
        manifestJson: manifestJson);
    if (mounted) {
      await _shareOrSave(zipPath, fileName, entries.length);
    }
  }

  // ── Helpers ──

  Future<void> _shareOrSave(String zipPath, String fileName, int entryCount) async {
    final baseName = fileName.endsWith('.md') ? fileName.substring(0, fileName.length - 3) : fileName;
    String finalPath = zipPath;
    String finalName = '$baseName.zip';

    if (_encrypt && _hasEncryptionKey) {
      final cfg = await EncryptionConfig.load();
      if (cfg.keyHex.isNotEmpty) {
        final key = CryptoService.hexToKey(cfg.keyHex);
        final zipBytes = await File(zipPath).readAsBytes();
        final encrypted = CryptoService.encrypt(Uint8List.fromList(zipBytes), key);

        final manifestHash = await _hashManifestFromZip(zipPath);
        final header = {
          'encrypted': true,
          'hash': manifestHash,
          'salt': cfg.salt,
        };

        final dir = Directory(zipPath).parent.path;
        final encPath = '$dir/$finalName.enc';
        final headerPath = '$dir/_header.json';
        await File(encPath).writeAsBytes(encrypted);
        await File(headerPath).writeAsString(jsonEncode(header));

        // wrap both into outer ZIP
        final outerZipPath = '$dir/$finalName';
        final encoder = ZipFileEncoder()..create(outerZipPath);
        await encoder.addFile(File(encPath), '$finalName.enc');
        await encoder.addFile(File(headerPath), '_header.json');
        await encoder.close();
        finalPath = outerZipPath;
      }
    }

    if (!mounted) return;
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(leading: const Icon(Icons.share), title: const Text('分享'), onTap: () => Navigator.pop(ctx, 'share')),
          ListTile(leading: const Icon(Icons.folder), title: const Text('保存到本地'), onTap: () => Navigator.pop(ctx, 'save')),
        ]),
      ),
    );
    if (action == null || !mounted) return;

    if (action == 'save') {
      try {
        final saved = await const MethodChannel('lite_diary/file_picker')
            .invokeMethod<bool>('saveFile', {
          'sourcePath': finalPath,
          'fileName': finalName,
        });
        if (saved == true && mounted) {
          _showSnackBar('已保存 $entryCount 篇日记到下载目录');
        } else if (mounted) {
          _showSnackBar('保存失败', error: true);
        }
      } catch (_) {
        if (mounted) _showSnackBar('保存失败', error: true);
      }
    } else {
      final result = await SharePlus.instance.share(ShareParams(
        files: [XFile(finalPath, name: finalName)], subject: finalName, text: finalName,
      ));
      if (result.status == ShareResultStatus.success && mounted) {
        _showSnackBar('已导出 $entryCount 篇日记');
      }
    }
  }

  Future<String> _hashManifestFromZip(String zipPath) async {
    final bytes = await File(zipPath).readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);
    for (final file in archive) {
      if (file.isFile && file.name == '_manifest.json') {
        final content = utf8.decode(file.content as List<int>);
        return sha256.convert(utf8.encode(content)).toString();
      }
    }
    return sha256.convert(bytes).toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('导出')),
      body: ListView(
        children: [
          _ExportTile(
            icon: Icons.edit_note,
            title: '导出日记',
            subtitle: '导出"日记"分组的内容',
            onTap: _exportDiary,
          ),
          _ExportTile(
            icon: Icons.auto_stories,
            title: '导出诗稿',
            subtitle: '导出"诗词"分组的诗稿合集',
            onTap: _exportPoetry,
          ),
          _ExportTile(
            icon: Icons.folder,
            title: '导出分组',
            subtitle: '选择分组，导出该分组内容',
            onTap: _exportByGroup,
          ),
          _ExportTile(
            icon: Icons.file_download,
            title: '导出全部数据',
            subtitle: '导出全部分组中的所有内容',
            onTap: _exportAll,
          ),
          SwitchListTile(
            secondary: const Icon(Icons.lock),
            title: Text(_encrypt ? '加密导出' : '不加密'),
            subtitle: Text(_hasEncryptionKey ? '使用加密配置中的密钥加密文件' : '请在"加密配置"中设置密码后启用'),
            value: _encrypt,
            onChanged: _hasEncryptionKey ? (v) => setState(() => _encrypt = v) : null,
          ),
        ],
      ),
    );
  }
}

// ── Supporting types ──

class _DateRange {
  final DateTime start;
  final DateTime end;
  final bool allTime;
  const _DateRange({required this.start, required this.end}) : allTime = false;
  _DateRange.all()
      : start = DateTime(1900),
        end = DateTime(2100),
        allTime = true;
}

class _ImageRecord {
  final String sourceAbsPath;
  final String destRelPath;
  final int entryId;
  const _ImageRecord({
    required this.sourceAbsPath,
    required this.destRelPath,
    required this.entryId,
  });
}

class _ExportTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ExportTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
