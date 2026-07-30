import 'dart:math';

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

final randomPoetryPickProvider = StateProvider<({int entryId, DateTime date})?>((ref) => null);

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  late PageController _pageController;
  static const _kPageMultiplier = 1000;
  List<int> _lastOrder = [1, 2, 0];

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
      appBar: AppBar(title: const Text('Lite Diary'), actions: const [SearchWidget()]),
      body: PageView.builder(
        controller: _pageController,
        itemBuilder: (context, index) => orderedPages[index % orderedPages.length],
      ),
    );
  }
}

class _CalendarViewPage extends ConsumerStatefulWidget {
  const _CalendarViewPage();

  @override
  ConsumerState<_CalendarViewPage> createState() => _CalendarViewPageState();
}

class _CalendarViewPageState extends ConsumerState<_CalendarViewPage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  void _pickRandomPoetry(List<Entry> entries, List<Group> groups) {
    final poetryGroup = groups.firstWhere(
      (g) => g.name == '诗词',
      orElse: () => groups.first,
    );
    final poetryEntries = entries
        .where((e) => e.groupId == poetryGroup.id)
        .toList();
    final today = DateTime.now();
    final todayKey = DateTime(today.year, today.month, today.day);
    if (poetryEntries.isEmpty) {
      ref.read(randomPoetryPickProvider.notifier).state = null;
    } else {
      final picked = poetryEntries[Random().nextInt(poetryEntries.length)];
      ref.read(randomPoetryPickProvider.notifier).state = (entryId: picked.id, date: todayKey);
    }
  }

  void _navigateToDate(BuildContext context, DateTime date) {
    final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    context.go('/content/date/$dateStr');
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final countsAsync = ref.watch(calendarDateCountsProvider);
    final entriesAsync = ref.watch(allEntriesProvider);
    final groupsAsync = ref.watch(allGroupsProvider);
    final now = DateTime.now();

    return countsAsync.when(
      data: (counts) {
        if (counts.isEmpty) return const Center(child: Text('还没有日记，点击右下角 + 开始记录'));

        final entries = entriesAsync.valueOrNull;
        final groups = groupsAsync.valueOrNull;
        final pick = ref.watch(randomPoetryPickProvider);
        final todayKey = DateTime(now.year, now.month, now.day);
        if ((pick == null || pick.date != todayKey) && entries != null && groups != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _pickRandomPoetry(entries, groups);
          });
        }

        Entry? poetryEntry;
        if (pick != null && entries != null) {
          final idx = entries.indexWhere((e) => e.id == pick.entryId);
          if (idx >= 0) {
            poetryEntry = entries[idx];
          } else {
            poetryEntry = null;
          }
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: MonthCalendarWidget(
                          data: CalendarData(dateCounts: counts),
                          initialMonth: now,
                          onDateTap: (date) => _navigateToDate(context, date)),
                    ),
                    const SizedBox(height: 8),
                    _buildStats(context, entriesAsync, groupsAsync),
                    const SizedBox(height: 12),
                    if (poetryEntry != null)
                      _buildPoetryCard(context, poetryEntry),
                  ],
                ),
              ),
            );
          },
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

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Container(
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

  Widget _buildPoetryCard(BuildContext context, Entry entry) {
    final dateStr = '${entry.date.year}年${entry.date.month}月${entry.date.day}日';
    final content = entry.content
        .replaceAll(RegExp(r'!\[.*?\]\(.*?\)'), '')
        .replaceAll(RegExp(r'^#{1,6}\s', multiLine: true), '')
        .replaceAll(RegExp(r'[*_~`>]'), '')
        .trim();
    final preview = entry.title != null && content.startsWith(entry.title!)
        ? content.substring(entry.title!.length).trim()
        : content;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Card(
        margin: EdgeInsets.zero,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => context.go('/entry/${entry.id}'),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Icon(Icons.auto_stories, size: 16, color: Colors.grey),
                    const SizedBox(width: 6),
                    const Text('旧日诗词', style: TextStyle(fontSize: 13, color: Colors.grey)),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.refresh, size: 18),
                      tooltip: '换一篇',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      onPressed: () {
                        final entries = ref.read(allEntriesProvider).valueOrNull;
                        final groups = ref.read(allGroupsProvider).valueOrNull;
                        if (entries != null && groups != null) {
                          _pickRandomPoetry(entries, groups);
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (entry.title != null && entry.title!.isNotEmpty)
                  Text(entry.title!, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                Text(dateStr, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                const SizedBox(height: 6),
                Text(
                  preview,
                  maxLines: null,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 15, color: Colors.grey.shade700, height: 1.5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
