import 'package:flutter/material.dart';
import 'package:lite_diary/services/lunar_calendar.dart';

class CalendarData {
  final Map<DateTime, int> dateCounts;
  const CalendarData({required this.dateCounts});
  factory CalendarData.empty() => CalendarData(dateCounts: {});
  int countForDate(DateTime date) {
    final key = DateTime(date.year, date.month, date.day);
    return dateCounts[key] ?? 0;
  }
}

class MonthCalendarWidget extends StatefulWidget {
  final CalendarData data;
  final DateTime initialMonth;
  final void Function(DateTime date)? onDateTap;
  const MonthCalendarWidget({super.key, required this.data, required this.initialMonth, this.onDateTap});
  @override
  State<MonthCalendarWidget> createState() => _MonthCalendarWidgetState();
}

class _MonthCalendarWidgetState extends State<MonthCalendarWidget> {
  late DateTime _currentMonth;

  @override
  void initState() {
    super.initState();
    _currentMonth = DateTime(widget.initialMonth.year, widget.initialMonth.month, 1);
  }

  void _jumpToToday() {
    final now = DateTime.now();
    setState(() { _currentMonth = DateTime(now.year, now.month, 1); });
  }

  void _previousMonth() => setState(() { _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1, 1); });
  void _nextMonth() => setState(() { _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 1); });

  void _pickYear() async {
    final now = DateTime.now();
    const startYear = 1900;
    const endYear = 2100;
    const totalYears = endYear - startYear + 1;
    final currentIndex = endYear - now.year;
    final scrollController = ScrollController();

    final year = await showDialog<int>(
      context: context,
      builder: (ctx) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (scrollController.hasClients) {
            final targetOffset =
                (currentIndex * 48.0 - 126).clamp(0.0, scrollController.position.maxScrollExtent);
            scrollController.jumpTo(targetOffset);
          }
        });
        return SimpleDialog(
          backgroundColor: Theme.of(ctx).colorScheme.surface,
          title: const Text('选择年份'),
          children: [
            SizedBox(
              height: 300,
              width: 120,
              child: ListView.builder(
                controller: scrollController,
                itemExtent: 48,
                itemCount: totalYears,
                itemBuilder: (_, i) {
                  final y = endYear - i;
                  return SimpleDialogOption(
                    onPressed: () => Navigator.pop(ctx, y),
                    child: Text('$y 年',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontWeight: y == now.year ? FontWeight.bold : null)),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
    scrollController.dispose();
    if (year != null && mounted) setState(() { _currentMonth = DateTime(year, _currentMonth.month, 1); });
  }

  @override
  Widget build(BuildContext context) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      _buildHeader(),
      _buildDayHeaders(),
      _buildDateGrid(),
    ]);
  }

  Widget _buildHeader() {
    final now = DateTime.now();
    final isCurrentMonth = _currentMonth.year == now.year && _currentMonth.month == now.month;
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      IconButton(icon: const Icon(Icons.chevron_left), onPressed: _previousMonth),
      GestureDetector(
        onTap: _pickYear,
        child: Text('${_currentMonth.year} 年 ${_currentMonth.month} 月', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
      ),
      Row(mainAxisSize: MainAxisSize.min, children: [
        if (!isCurrentMonth)
          IconButton(icon: const Icon(Icons.today, size: 22), tooltip: '回到今日', onPressed: _jumpToToday),
        IconButton(icon: const Icon(Icons.chevron_right), onPressed: _nextMonth),
      ]),
    ]);
  }

  Widget _buildDayHeaders() {
    const dayNames = ['日', '一', '二', '三', '四', '五', '六'];
    return Row(children: dayNames.map((name) => Expanded(child: Center(child: Text(name, style: TextStyle(fontSize: 14, color: Colors.grey.shade600))))).toList());
  }

  Widget _buildDateGrid() {
    final firstDay = DateTime(_currentMonth.year, _currentMonth.month, 1);
    final lastDay = DateTime(_currentMonth.year, _currentMonth.month + 1, 0);
    final startWeekday = firstDay.weekday % 7;
    final daysInMonth = lastDay.day;
    final today = DateTime.now();
    final todayKey = DateTime(today.year, today.month, today.day);
    final colorScheme = Theme.of(context).colorScheme;
    final rows = <Widget>[];
    var currentRow = <Widget>[];

    for (int i = 0; i < startWeekday; i++) { currentRow.add(const Expanded(child: SizedBox())); }
    for (int day = 1; day <= daysInMonth; day++) {
      final date = DateTime(_currentMonth.year, _currentMonth.month, day);
      final dateKey = DateTime(date.year, date.month, date.day);
      final count = widget.data.countForDate(date);
      final isToday = dateKey == todayKey;
      currentRow.add(Expanded(child: GestureDetector(
        onTap: widget.onDateTap != null ? () => widget.onDateTap!(date) : null,
        child: Container(
          margin: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: isToday ? colorScheme.primary.withAlpha(35) : null,
            borderRadius: BorderRadius.circular(8),
            border: isToday ? Border.all(color: colorScheme.primary.withAlpha(120)) : null,
          ),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, mainAxisSize: MainAxisSize.min, children: [
            Text('$day', style: TextStyle(fontSize: 18, fontWeight: isToday ? FontWeight.bold : null)),
            Text(LunarService.lunarDayShort(date), style: TextStyle(fontSize: 11, color: Colors.grey.shade500), maxLines: 1, overflow: TextOverflow.ellipsis),
            if (count > 0) Container(width: 6, height: 6, decoration: BoxDecoration(color: colorScheme.primary, shape: BoxShape.circle)),
          ]),
        ),
      )));
      if (currentRow.length == 7) { rows.add(Row(children: currentRow)); currentRow = []; }
    }
    if (currentRow.isNotEmpty) {
      while (currentRow.length < 7) { currentRow.add(const Expanded(child: SizedBox())); }
      rows.add(Row(children: currentRow));
    }
    return Column(children: rows);
  }
}
