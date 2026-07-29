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
  List<Entry> _results = [];
  List<Entry> _allEntries = [];
  bool _isSearching = false;
  bool _loaded = false;

  AppDatabase get db => ref.read(databaseProvider);

  @override
  void dispose() { _controller.dispose(); super.dispose(); }

  Future<void> _loadAll() async {
    _allEntries = await db.getAllEntries();
    if (mounted) setState(() => _loaded = true);
  }

  void _onSearch(String query) {
    if (query.isEmpty) { setState(() => _results = []); return; }
    final q = query.toLowerCase();
    setState(() {
      _results = _allEntries.where((e) {
        return (e.title?.toLowerCase().contains(q) ?? false) || e.content.toLowerCase().contains(q);
      }).toList();
    });
  }

  @override
  void initState() { super.initState(); _loadAll(); }

  @override
  Widget build(BuildContext context) {
    if (!_isSearching) {
      return IconButton(icon: const Icon(Icons.search), onPressed: () { setState(() => _isSearching = true); if (!_loaded) _loadAll(); });
    }

    return Expanded(
      child: Row(children: [
        Expanded(child: TextField(controller: _controller, autofocus: true, onChanged: _onSearch,
          decoration: const InputDecoration(hintText: '搜索日记...', border: InputBorder.none))),
        IconButton(icon: const Icon(Icons.close), onPressed: () { setState(() { _isSearching = false; _results = []; }); _controller.clear(); }),
        if (_results.isNotEmpty)
          IconButton(icon: const Icon(Icons.list), tooltip: '搜索结果', onPressed: _showResults),
      ]),
    );
  }

  void _showResults() {
    showModalBottomSheet(
      context: context, isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6, minChildSize: 0.3, maxChildSize: 0.9, expand: false,
        builder: (ctx, scrollController) => Column(children: [
          Padding(padding: const EdgeInsets.all(8), child: Text('${_results.length} 条结果', style: const TextStyle(fontWeight: FontWeight.bold))),
          Expanded(child: ListView.builder(
            controller: scrollController, itemCount: _results.length,
            itemBuilder: (ctx, index) {
              final entry = _results[index];
              final dateStr = '${entry.date.year}-${entry.date.month.toString().padLeft(2, '0')}-${entry.date.day.toString().padLeft(2, '0')}';
              return ListTile(
                title: Text(entry.title ?? '无标题', maxLines: 1),
                subtitle: Text('$dateStr  ${entry.content}', maxLines: 2),
                onTap: () { Navigator.pop(ctx); context.go('/entry/${entry.id}'); },
              );
            },
          )),
        ]),
      ),
    );
  }
}
