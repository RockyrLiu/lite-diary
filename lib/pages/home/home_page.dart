import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../database/database.dart';
import '../../providers/calendar_data_provider.dart';
import '../../providers/entry_provider.dart';
import '../../providers/group_provider.dart';
import '../../widgets/calendar_widget.dart';
import '../../widgets/search_widget.dart';
import '../settings/display_page.dart';
import 'on_this_day_page.dart';
import 'groups_page.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  late PageController _pageController;
  static const _kPageMultiplier = 1000;
  List<int> _lastOrder = [0, 1, 2];

  final _pages = const [OnThisDayPage(), _CalendarViewPage(), GroupsPage()];

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _kPageMultiplier * 3);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final order = ref.read(homePageOrderProvider);
      _lastOrder = order;
      _pageController.jumpToPage(_kPageMultiplier * 3);
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pageOrder = ref.watch(homePageOrderProvider);

    if (pageOrder != _lastOrder && _pageController.hasClients) {
      _lastOrder = pageOrder;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _pageController.jumpToPage(_kPageMultiplier * 3);
      });
    }

    final orderedPages = pageOrder.map((idx) => _pages[idx]).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Diary Lite'), actions: const [SearchWidget()]),
      body: PageView.builder(
        controller: _pageController,
        itemBuilder: (context, index) => orderedPages[index % orderedPages.length],
      ),
    );
  }
}

class _CalendarViewPage extends ConsumerWidget {
  const _CalendarViewPage();

  void _navigateToDate(BuildContext context, DateTime date) {
    final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    context.go('/content/date/$dateStr');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final countsAsync = ref.watch(calendarDateCountsProvider);
    final entriesAsync = ref.watch(allEntriesProvider);
    final groupsAsync = ref.watch(allGroupsProvider);
    final now = DateTime.now();

    return countsAsync.when(
      data: (counts) {
        if (counts.isEmpty) return const Center(child: Text('还没有日记，点击右下角 + 开始记录'));
        return SingleChildScrollView(
          padding: const EdgeInsets.all(8),
          child: Column(
            children: [
              MonthCalendarWidget(data: CalendarData(dateCounts: counts), initialMonth: now, onDateTap: (date) => _navigateToDate(context, date)),
              const SizedBox(height: 16),
              _buildStats(context, entriesAsync, groupsAsync),
            ],
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('加载失败: $error')),
    );
  }

  Widget _buildStats(BuildContext context,
      AsyncValue<List<Entry>> entriesAsync, AsyncValue<List<Group>> groupsAsync) {
    final entries = entriesAsync.valueOrNull;
    final groups = groupsAsync.valueOrNull;
    if (entries == null || groups == null || entries.isEmpty) {
      return const SizedBox.shrink();
    }

    final diaryGroup = groups.firstWhere(
      (g) => g.name == '日记',
      orElse: () => groups.first,
    );
    final poetryGroup = groups.firstWhere(
      (g) => g.name == '诗词',
      orElse: () => groups.first,
    );
    final diaryEntries = entries.where((e) => e.groupId == diaryGroup.id).length;
    final poetryEntries = entries.where((e) => e.groupId == poetryGroup.id).length;
    final totalWords = entries.fold<int>(0, (sum, e) {
      var text = e.content;
      text = text.replaceAll(RegExp(r'!\[.*?\]\(.*?\)'), '');
      text = text.replaceAll(RegExp(r'^#{1,6}\s', multiLine: true), '');
      text = text.replaceAll(RegExp(r'\*\*([^*]+)\*\*'), r'$1');
      text = text.replaceAll(RegExp(r'\*([^*]+)\*'), r'$1');
      text = text.replaceAll(RegExp(r'~~([^~]+)~~'), r'$1');
      text = text.replaceAll(RegExp(r'`([^`]+)`'), r'$1');
      text = text.replaceAll(RegExp(r'\s'), '');
      return sum + text.length;
    });

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _statItem('总篇数', '${entries.length}'),
          _statItem('日记', '$diaryEntries'),
          _statItem('诗词', '$poetryEntries'),
          _statItem('总字数', '$totalWords'),
        ],
      ),
    );
  }

  Widget _statItem(String label, String value) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
      ],
    );
  }
}
