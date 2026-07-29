import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../../database/database.dart';
import '../../providers/entry_provider.dart';

class OnThisDayPage extends ConsumerStatefulWidget {
  const OnThisDayPage({super.key});

  @override
  ConsumerState<OnThisDayPage> createState() => _OnThisDayPageState();
}

class _OnThisDayPageState extends ConsumerState<OnThisDayPage> {
  int _currentIndex = 0;
  List<Entry> _entries = [];

  void _loadEntries() {
    final allAsync = ref.read(allEntriesProvider);
    allAsync.whenData((entries) {
      final today = DateTime.now();
      final matching = entries.where((e) {
        return e.date.month == today.month &&
            e.date.day == today.day &&
            e.date.year != today.year;
      }).toList();
      matching.sort((a, b) => b.date.compareTo(a.date));

      if (mounted) {
        final random = matching.isNotEmpty ? Random() : null;
        if (random != null && matching.length > 1) {
          matching.shuffle(random);
        }
        setState(() {
          _entries = matching;
          _currentIndex = 0;
        });
      }
    });
  }

  void _nextEntry() {
    if (_currentIndex < _entries.length - 1) {
      setState(() => _currentIndex++);
    }
  }

  void _previousEntry() {
    if (_currentIndex > 0) {
      setState(() => _currentIndex--);
    }
  }

  @override
  void initState() {
    super.initState();
    _loadEntries();
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();

    return Scaffold(
      appBar: AppBar(title: Text('${today.month}月${today.day}日 — 那年今日')),
      body: _entries.isEmpty
          ? const Center(child: Text('往年的今天还没有日记'))
          : Column(
              children: [
                if (_entries.length > 1)
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(icon: const Icon(Icons.arrow_back), onPressed: _previousEntry),
                        Text('${_currentIndex + 1} / ${_entries.length}'),
                        IconButton(icon: const Icon(Icons.arrow_forward), onPressed: _nextEntry),
                      ],
                    ),
                  ),
                Expanded(
                  child: _buildEntryView(_entries[_currentIndex]),
                ),
              ],
            ),
    );
  }

  Widget _buildEntryView(Entry entry) {
    final dateStr = '${entry.date.year}年${entry.date.month}月${entry.date.day}日';
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (entry.title != null && entry.title!.isNotEmpty)
            Text(entry.title!, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          Text(dateStr, style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
          const Divider(),
          Expanded(
            child: Markdown(data: entry.content, selectable: true),
          ),
        ],
      ),
    );
  }
}
