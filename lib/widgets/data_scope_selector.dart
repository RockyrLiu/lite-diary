import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/group_provider.dart';

enum _DatePreset { today, week, month, year, all, custom }

final conversationDateStartProvider = StateProvider<DateTime?>((ref) => null);
final conversationDateEndProvider = StateProvider<DateTime?>((ref) => null);
final conversationGroupIdsProvider = StateProvider<List<int>>((ref) => []);
final pinnedEntryIdsProvider = StateProvider<List<int>>((ref) => []);

class DataScopeSelector extends ConsumerStatefulWidget {
  const DataScopeSelector({super.key});

  @override
  ConsumerState<DataScopeSelector> createState() => _DataScopeSelectorState();
}

class _DataScopeSelectorState extends ConsumerState<DataScopeSelector> {
  _DatePreset _preset = _DatePreset.all;
  late TextEditingController _startCtrl;
  late TextEditingController _endCtrl;

  @override
  void initState() {
    super.initState();
    _startCtrl = TextEditingController();
    _endCtrl = TextEditingController();
    final s = ref.read(conversationDateStartProvider);
    final e = ref.read(conversationDateEndProvider);
    _preset = _detectPreset(s, e);
    if (_preset == _DatePreset.custom) {
      _startCtrl.text = _fmt(s);
      _endCtrl.text = _fmt(e);
    }
  }

  _DatePreset _detectPreset(DateTime? start, DateTime? end) {
    if (start == null && end == null) return _DatePreset.all;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (start == today && end == today) return _DatePreset.today;
    if (start == today.subtract(const Duration(days: 6)) && end == today) return _DatePreset.week;
    if (start == today.subtract(const Duration(days: 29)) && end == today) return _DatePreset.month;
    if (start == today.subtract(const Duration(days: 364)) && end == today) return _DatePreset.year;
    return _DatePreset.custom;
  }

  @override
  void dispose() {
    _startCtrl.dispose();
    _endCtrl.dispose();
    super.dispose();
  }

  String _fmt(DateTime? d) {
    if (d == null) return '';
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  (DateTime?, DateTime?) _datesForPreset(_DatePreset p) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return switch (p) {
      _DatePreset.today => (today, today),
      _DatePreset.week => (today.subtract(const Duration(days: 6)), today),
      _DatePreset.month => (today.subtract(const Duration(days: 29)), today),
      _DatePreset.year => (today.subtract(const Duration(days: 364)), today),
      _DatePreset.all => (null, null),
      _DatePreset.custom => (_parseDate(_startCtrl.text), _parseDate(_endCtrl.text)),
    };
  }

  DateTime? _parseDate(String s) {
    final parts = s.split('-');
    if (parts.length != 3) return null;
    final y = int.tryParse(parts[0]), m = int.tryParse(parts[1]), d = int.tryParse(parts[2]);
    if (y == null || m == null || d == null || m < 1 || m > 12 || d < 1 || d > 31) return null;
    return DateTime(y, m, d);
  }

  @override
  Widget build(BuildContext context) {
    final groupIds = ref.watch(conversationGroupIdsProvider);
    final groupsAsync = ref.watch(allGroupsProvider);

    return AlertDialog(
      title: const Text('选择数据范围'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('日期范围', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              for (final entry in const [
                (_DatePreset.today, '今天'),
                (_DatePreset.week, '近一周'),
                (_DatePreset.month, '近一月'),
                (_DatePreset.year, '近一年'),
                (_DatePreset.all, '全部'),
                (_DatePreset.custom, '自定义'),
              ])
                ChoiceChip(
                  selected: _preset == entry.$1,
                  label: Text(entry.$2),
                  onSelected: (_) => setState(() => _preset = entry.$1),
                ),
            ],
          ),
          if (_preset == _DatePreset.custom) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _startCtrl,
                    decoration: const InputDecoration(labelText: '起始', hintText: '2024-01-01', border: OutlineInputBorder(), isDense: true),
                  ),
                ),
                const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('—')),
                Expanded(
                  child: TextField(
                    controller: _endCtrl,
                    decoration: const InputDecoration(labelText: '结束', hintText: '2024-12-31', border: OutlineInputBorder(), isDense: true),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          const Text('分组筛选', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          groupsAsync.when(
            data: (groups) => Wrap(spacing: 6, children: [
              FilterChip(selected: groupIds.isEmpty, label: const Text('全部'), onSelected: (_) => ref.read(conversationGroupIdsProvider.notifier).state = []),
              ...groups.map((g) => FilterChip(
                    selected: groupIds.contains(g.id),
                    label: Text(g.name),
                    onSelected: (sel) {
                      final ids = List<int>.from(groupIds);
                      sel ? ids.add(g.id) : ids.remove(g.id);
                      ref.read(conversationGroupIdsProvider.notifier).state = ids;
                    },
                  )),
            ]),
            loading: () => const CircularProgressIndicator(),
            error: (_, _) => const Text('加载分组失败'),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
        FilledButton(
          onPressed: () {
            final (start, end) = _datesForPreset(_preset);
            ref.read(conversationDateStartProvider.notifier).state = start;
            ref.read(conversationDateEndProvider.notifier).state = end;
            ref.read(pinnedEntryIdsProvider.notifier).state = [];
            Navigator.pop(context);
          },
          child: const Text('确定'),
        ),
      ],
    );
  }
}
