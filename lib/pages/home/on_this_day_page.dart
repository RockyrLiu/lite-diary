import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../database/database.dart';
import '../../providers/entry_provider.dart';

class OnThisDayPage extends ConsumerStatefulWidget {
  const OnThisDayPage({super.key});

  @override
  ConsumerState<OnThisDayPage> createState() => _OnThisDayPageState();
}

class _OnThisDayPageState extends ConsumerState<OnThisDayPage> {
  List<Entry> _entries = [];

  void _loadEntries() async {
    final prefs = await SharedPreferences.getInstance();
    final selectedIds = (prefs.getStringList('on_this_day_groups') ?? [])
        .map(int.parse)
        .toSet();

    if (!mounted) return;
    final allAsync = ref.read(allEntriesProvider);
    allAsync.whenData((entries) {
      final today = DateTime.now();
      final matching = entries.where((e) {
        if (e.date.month != today.month || e.date.day != today.day) return false;
        if (e.date.year == today.year) return false;
        if (selectedIds.isNotEmpty && !selectedIds.contains(e.groupId)) return false;
        return true;
      }).toList();
      matching.sort((a, b) => b.date.compareTo(a.date));

      if (mounted) setState(() => _entries = matching);
    });
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
          : ListView.builder(
              padding: const EdgeInsets.only(bottom: 32),
              itemCount: _entries.length,
              itemBuilder: (context, index) => _buildEntryCard(_entries[index]),
            ),
    );
  }

  Widget _buildEntryCard(Entry entry) {
    final dateStr = '${entry.date.year}年${entry.date.month}月${entry.date.day}日';
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (entry.title != null && entry.title!.isNotEmpty)
              Text(entry.title!, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text(dateStr, style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
            const Divider(),
            Markdown(data: entry.content, selectable: true, shrinkWrap: true, physics: const NeverScrollableScrollPhysics()),
          ],
        ),
      ),
    );
  }
}
