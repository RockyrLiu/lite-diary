import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/calendar_data_provider.dart';
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
    final now = DateTime.now();

    return countsAsync.when(
      data: (counts) {
        if (counts.isEmpty) return const Center(child: Text('还没有日记，点击右下角 + 开始记录'));
        return SingleChildScrollView(
          padding: const EdgeInsets.all(8),
          child: MonthCalendarWidget(data: CalendarData(dateCounts: counts), initialMonth: now, onDateTap: (date) => _navigateToDate(context, date)),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('加载失败: $error')),
    );
  }
}
