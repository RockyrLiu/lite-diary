import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../database/database.dart';
import '../../providers/database_provider.dart';
import '../../services/lunar_calendar.dart';

class ExportPage extends ConsumerStatefulWidget {
  const ExportPage({super.key});

  @override
  ConsumerState<ExportPage> createState() => _ExportPageState();
}

class _ExportPageState extends ConsumerState<ExportPage> {
  String? _message;

  Future<void> _exportPoetry() async {
    final db = ref.read(databaseProvider);
    final groups = await db.getAllGroups();
    Group? poetryGroup;
    try {
      poetryGroup = groups.firstWhere((g) => g.name == '诗词');
    } catch (_) {
      setState(() => _message = '未找到"诗词"分组，请先创建');
      return;
    }

    final entries = await db.getEntriesByGroup(poetryGroup.id);
    if (entries.isEmpty) {
      setState(() => _message = '"诗词"分组下暂无日记');
      return;
    }

    entries.sort((a, b) => a.date.compareTo(b.date));

    final firstYear = entries.first.date.year;
    final ganZhiYear = LunarService.ganZhiYear(firstYear);

    final buffer = StringBuffer();
    buffer.writeln('# $ganZhiYear诗稿');
    buffer.writeln();

    // 目录
    buffer.writeln('## 目录');
    buffer.writeln();
    for (final entry in entries) {
      final title = entry.title ?? '无标题';
      final lunar = LunarService.lunarDay(entry.date);
      buffer.writeln('- [$title  $lunar](#${Uri.encodeComponent(title)})');
    }
    buffer.writeln();

    // 正文
    for (final entry in entries) {
      final title = entry.title ?? '无标题';
      final lunar = LunarService.lunarDay(entry.date);
      buffer.writeln('## $title  $lunar');
      buffer.writeln();
      buffer.writeln(entry.content);
      buffer.writeln();
    }

    setState(() => _message = '诗稿已生成：\n\n${buffer.toString()}');
  }

  Future<void> _exportAll() async {
    final db = ref.read(databaseProvider);
    final entries = await db.getAllEntries();
    if (entries.isEmpty) {
      setState(() => _message = '暂无日记可导出');
      return;
    }

    entries.sort((a, b) => a.date.compareTo(b.date));

    final buffer = StringBuffer();
    for (final entry in entries) {
      final dateStr = '${entry.date.year}-${entry.date.month.toString().padLeft(2, '0')}-${entry.date.day.toString().padLeft(2, '0')}';
      buffer.writeln('---');
      buffer.writeln('date: $dateStr');
      if (entry.title != null && entry.title!.isNotEmpty) {
        buffer.writeln('title: ${entry.title}');
      }
      buffer.writeln('---');
      buffer.writeln();
      buffer.writeln(entry.content);
      buffer.writeln();
    }

    setState(() => _message = '已导出 ${entries.length} 篇日记：\n\n${buffer.toString()}');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('导出')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton.icon(
              onPressed: _exportPoetry,
              icon: const Icon(Icons.auto_stories),
              label: const Text('导出诗稿'),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _exportAll,
              icon: const Icon(Icons.file_download),
              label: const Text('导出所有日记'),
            ),
            const SizedBox(height: 16),
            if (_message != null)
              Expanded(
                child: SingleChildScrollView(
                  child: SelectableText(_message!, style: const TextStyle(fontSize: 13)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
