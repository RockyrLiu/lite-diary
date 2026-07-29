import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/calendar_data_provider.dart';
import '../../widgets/heatmap_widget.dart';
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

  final _pages = const [OnThisDayPage(), _CalendarViewPage(), GroupsPage()];

  @override
  void initState() {
    super.initState();
    final order = ref.read(homePageOrderProvider);
    final homeIdx = order[0]; // 第一个即默认首页
    _pageController = PageController(initialPage: _kPageMultiplier * _pages.length + homeIdx);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pageOrder = ref.watch(homePageOrderProvider);

    final orderedPages = pageOrder.map((idx) => _pages[idx]).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Diary Lite'),
        actions: const [SearchWidget()],
      ),
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
    final now = DateTime.now();

    return countsAsync.when(
      data: (counts) {
        if (counts.isEmpty) return const Center(child: Text('还没有日记，点击右下角 + 开始记录'));
        return SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(children: [
              HeatmapWidget(data: HeatmapData(dateCounts: counts), year: now.year, onDateTap: (date) => _navigateToDate(context, date)),
              const SizedBox(height: 16),
              MonthCalendarWidget(data: CalendarData(dateCounts: counts), initialMonth: now, onDateTap: (date) => _navigateToDate(context, date)),
            ]),
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('加载失败: $error')),
    );
  }
}
