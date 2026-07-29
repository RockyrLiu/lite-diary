import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../database/database.dart';
import '../providers/database_provider.dart';

class SearchWidget extends ConsumerStatefulWidget {
  const SearchWidget({super.key});

  @override
  ConsumerState<SearchWidget> createState() => _SearchWidgetState();
}

class _SearchWidgetState extends ConsumerState<SearchWidget> {
  final TextEditingController _controller = TextEditingController();
  List<Entry> _allEntries = [];
  Map<int, List<String>> _entryTags = {};
  List<Entry> _results = [];
  bool _open = false;

  AppDatabase get db => ref.read(databaseProvider);

  @override
  void dispose() { _controller.dispose(); super.dispose(); }

  Future<void> _ensureLoaded() async {
    if (_allEntries.isNotEmpty) return;
    _allEntries = await db.getAllEntries();
    _entryTags = await db.getEntryTagsMap();
    if (mounted) setState(() {});
  }

  void _onChanged(String q) {
    if (q.isEmpty) { setState(() => _results = []); return; }
    final lower = q.toLowerCase();
    setState(() {
      _results = _allEntries.where((e) =>
        (e.title?.toLowerCase().contains(lower) ?? false) ||
        e.content.toLowerCase().contains(lower) ||
        (_entryTags[e.id]?.any((t) => t.toLowerCase().contains(lower)) ?? false)
      ).toList();
    });
  }

  void _onSubmitted(String q) {
    if (q.trim().isEmpty) return;
    _onChanged(q);
    if (_results.isNotEmpty) _showResults();
  }

  void _close() {
    setState(() { _open = false; _results = []; });
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    if (!_open) {
      return IconButton(icon: const Icon(Icons.search), onPressed: () { setState(() => _open = true); _ensureLoaded(); });
    }

    return Expanded(
      child: Row(children: [
        Expanded(child: TextField(
          controller: _controller, autofocus: true,
          onChanged: _onChanged, onSubmitted: _onSubmitted,
          decoration: const InputDecoration(hintText: '搜索...', border: InputBorder.none),
        )),
        IconButton(icon: const Icon(Icons.close), onPressed: _close),
      ]),
    );
  }

  void _showResults() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6, minChildSize: 0.3, maxChildSize: 0.9, expand: false,
        builder: (ctx, scrollController) => Column(children: [
          Padding(padding: const EdgeInsets.all(8), child: Text('${_results.length} 条结果', style: const TextStyle(fontWeight: FontWeight.bold))),
          Expanded(child: ListView.builder(
            controller: scrollController, itemCount: _results.length,
            itemBuilder: (ctx, i) {
              final e = _results[i];
              final ds = '${e.date.year}-${e.date.month.toString().padLeft(2, '0')}-${e.date.day.toString().padLeft(2, '0')}';
              return ListTile(
                title: Text(e.title ?? '无标题', maxLines: 1),
                subtitle: Text('$ds  ${e.content}', maxLines: 2),
                onTap: () { Navigator.pop(ctx); context.go('/entry/${e.id}'); },
              );
            },
          )),
        ]),
      ),
    );
  }
}
