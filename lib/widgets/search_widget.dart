import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../database/database.dart';
import '../providers/entry_provider.dart';

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

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onSearch(String query) {
    if (query.isEmpty) {
      setState(() => _results = []);
      return;
    }
    final q = query.toLowerCase();
    setState(() {
      _results = _allEntries.where((e) {
        return (e.title?.toLowerCase().contains(q) ?? false) || e.content.toLowerCase().contains(q);
      }).toList();
    });
  }

  String _dateStr(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  @override
  void initState() {
    super.initState();
    final async = ref.read(allEntriesProvider);
    async.whenData((entries) => setState(() => _allEntries = entries));
  }

  @override
  Widget build(BuildContext context) {
    if (!_isSearching) {
      return IconButton(
        icon: const Icon(Icons.search),
        onPressed: () => setState(() => _isSearching = true),
      );
    }

    return Expanded(
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              autofocus: true,
              onChanged: _onSearch,
              decoration: const InputDecoration(
                hintText: '搜索日记...',
                border: InputBorder.none,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () {
              setState(() {
                _isSearching = false;
                _results = [];
              });
              _controller.clear();
            },
          ),
          if (_results.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.list),
              tooltip: '搜索结果',
              onPressed: () => _showResults(),
            ),
        ],
      ),
    );
  }

  void _showResults() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.3,
          maxChildSize: 0.9,
          expand: false,
          builder: (ctx, scrollController) {
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text('${_results.length} 条结果', style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount: _results.length,
                    itemBuilder: (ctx, index) {
                      final entry = _results[index];
                      return ListTile(
                        title: Text(entry.title ?? '无标题', maxLines: 1),
                        subtitle: Text('$_dateStr(entry.date)  ${entry.content}', maxLines: 2),
                        onTap: () {
                          Navigator.pop(ctx);
                          context.go('/entry/${entry.id}');
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
