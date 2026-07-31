import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../database/database.dart';
import '../../providers/database_provider.dart';

class OnThisDayFilterPage extends ConsumerStatefulWidget {
  const OnThisDayFilterPage({super.key});

  @override
  ConsumerState<OnThisDayFilterPage> createState() => _OnThisDayFilterPageState();
}

class _OnThisDayFilterPageState extends ConsumerState<OnThisDayFilterPage> {
  Set<int> _selectedGroupIds = {};
  List<Group> _groups = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList('on_this_day_groups') ?? [];
    final db = ref.read(databaseProvider);
    final groups = await db.getAllGroups();
    if (mounted) {
      setState(() {
        _selectedGroupIds = saved.map(int.parse).toSet();
        _groups = groups;
      });
    }
  }

  Future<void> _toggle(int groupId) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      if (_selectedGroupIds.contains(groupId)) {
        _selectedGroupIds.remove(groupId);
      } else {
        _selectedGroupIds.add(groupId);
      }
    });
    await prefs.setStringList(
      'on_this_day_groups',
      _selectedGroupIds.map((e) => e.toString()).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('那年今日过滤')),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text(
              '勾选希望在"那年今日"中展示的分组',
              style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
            ),
          ),
          ..._groups.map((g) => CheckboxListTile(
                value: _selectedGroupIds.contains(g.id),
                onChanged: (_) => _toggle(g.id),
                title: Text(g.name),
              )),
          const Divider(),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              _selectedGroupIds.isEmpty
                  ? '当前：全部展示'
                  : '当前：已选 ${_selectedGroupIds.length} 个分组',
              style: TextStyle(fontSize: 14, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
            ),
          ),
        ],
      ),
    );
  }
}
