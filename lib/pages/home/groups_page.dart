import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull, Column;
import 'package:go_router/go_router.dart';

import '../../database/database.dart';
import '../../providers/database_provider.dart';
import '../../providers/entry_provider.dart';
import '../../providers/group_provider.dart';

class GroupsPage extends ConsumerStatefulWidget {
  const GroupsPage({super.key});

  @override
  ConsumerState<GroupsPage> createState() => _GroupsPageState();
}

class _GroupsPageState extends ConsumerState<GroupsPage> {
  int? _selectedGroupId; // null = 全部

  Future<void> _createGroup() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('新建分组'),
        content: TextField(controller: controller, autofocus: true, decoration: const InputDecoration(hintText: '分组名称')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.pop(ctx, controller.text), child: const Text('确定')),
        ],
      ),
    );
    if (name != null && name.trim().isNotEmpty) {
      await ref.read(databaseProvider).createGroup(GroupsCompanion(name: Value(name.trim())));
      ref.invalidate(allGroupsProvider);
    }
  }

  Future<void> _renameGroup(Group group) async {
    final controller = TextEditingController(text: group.name);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('重命名分组'),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.pop(ctx, controller.text), child: const Text('确定')),
        ],
      ),
    );
    if (name != null && name.trim().isNotEmpty && name.trim() != group.name) {
      await ref.read(databaseProvider).updateGroup(group.id, GroupsCompanion(name: Value(name.trim())));
      ref.invalidate(allGroupsProvider);
    }
  }

  Future<void> _deleteGroup(Group group) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('删除分组 "${group.name}"'),
        content: const Text('该分组下的日记不会被删除。确定删除？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('删除')),
        ],
      ),
    );
    if (confirm == true) {
      await ref.read(databaseProvider).deleteGroup(group.id);
      if (!mounted) return;
      ref.invalidate(allGroupsProvider);
      if (_selectedGroupId == group.id) setState(() => _selectedGroupId = null);
    }
  }

  String _formatDate(DateTime d) => '${d.month}.${d.day}';

  @override
  Widget build(BuildContext context) {
    final groupsAsync = ref.watch(allGroupsProvider);
    final entriesAsync = _selectedGroupId == null
        ? ref.watch(allEntriesProvider)
        : ref.watch(entriesByGroupProvider(_selectedGroupId!));

    return Scaffold(
      appBar: AppBar(
        title: const Text('分组'),
        actions: [
          IconButton(icon: const Icon(Icons.add), onPressed: _createGroup),
        ],
      ),
      body: Row(
        children: [
          // 左侧分组列表
          SizedBox(
            width: 120,
            child: groupsAsync.when(
              data: (groups) => ListView(
                children: [
                  ListTile(
                    title: const Text('全部', style: TextStyle(fontWeight: FontWeight.bold)),
                    selected: _selectedGroupId == null,
                    selectedTileColor: Colors.lightBlue.shade50,
                    onTap: () => setState(() => _selectedGroupId = null),
                  ),
                  ...groups.map((g) => ListTile(
                    title: Text(g.name),
                    selected: _selectedGroupId == g.id,
                    selectedTileColor: Colors.lightBlue.shade50,
                    onTap: () => setState(() => _selectedGroupId = g.id),
                    onLongPress: () => _showGroupMenu(g),
                  )),
                ],
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => const SizedBox(),
            ),
          ),
          const VerticalDivider(width: 1),
          // 右侧日记列表
          Expanded(
            child: entriesAsync.when(
              data: (entries) {
                if (entries.isEmpty) return const Center(child: Text('暂无日记'));
                return ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: entries.length,
                  itemBuilder: (_, i) {
                    final e = entries[i];
                    return _EntryCard(
                      title: e.title ?? '无标题',
                      date: _formatDate(e.date),
                      content: e.content,
                      onTap: () => context.go('/entry/${e.id}'),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('加载失败: $e')),
            ),
          ),
        ],
      ),
    );
  }

  void _showGroupMenu(Group group) {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(leading: const Icon(Icons.edit), title: const Text('重命名'), onTap: () { Navigator.pop(context); _renameGroup(group); }),
            ListTile(leading: const Icon(Icons.delete, color: Colors.red), title: const Text('删除'), onTap: () { Navigator.pop(context); _deleteGroup(group); }),
          ],
        ),
      ),
    );
  }
}

class _EntryCard extends StatelessWidget {
  final String title;
  final String date;
  final String content;
  final VoidCallback onTap;

  const _EntryCard({
    required this.title,
    required this.date,
    required this.content,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        title: Text(title, maxLines: 1, style: const TextStyle(fontWeight: FontWeight.w500)),
        subtitle: Text('$date  $content', maxLines: 2, style: const TextStyle(fontSize: 12)),
        onTap: onTap,
      ),
    );
  }
}
