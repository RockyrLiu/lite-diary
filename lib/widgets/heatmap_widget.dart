import 'package:flutter/material.dart';

class HeatmapData {
  final Map<DateTime, int> dateCounts;
  const HeatmapData({required this.dateCounts});
  factory HeatmapData.empty() => HeatmapData(dateCounts: {});

  int countForDate(DateTime date) {
    final key = DateTime(date.year, date.month, date.day);
    return dateCounts[key] ?? 0;
  }
}

class HeatmapWidget extends StatelessWidget {
  final HeatmapData data;
  final int year;
  final void Function(DateTime date)? onDateTap;

  static const _cellSize = 14.0;
  static const _cellMargin = 2.0;
  static const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  static const _weekDays = ['', 'Mon', '', 'Wed', '', 'Fri', ''];

  const HeatmapWidget({super.key, required this.data, required this.year, this.onDateTap});

  @override
  Widget build(BuildContext context) {
    final start = DateTime(year, 1, 1);
    final end = DateTime(year, 12, 31);
    final totalDays = end.difference(start).inDays + 1;
    final startWeekday = start.weekday; // Mon=1 .. Sun=7
    final gridCols = ((totalDays + startWeekday - 1) / 7).ceil();
    final today = DateTime.now();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Month labels
        _buildMonthLabels(start, gridCols, startWeekday),
        const SizedBox(height: 2),
        // Grid with weekday labels
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildWeekDayLabels(),
            const SizedBox(width: 4),
            _buildGrid(start, startWeekday, gridCols, totalDays, today),
          ],
        ),
        const SizedBox(height: 4),
        _buildLegend(),
      ],
    );
  }

  Widget _buildMonthLabels(DateTime start, int gridCols, int startWeekday) {
    final labels = <Widget>[];
    int currentMonth = -1;

    for (int col = 0; col < gridCols; col++) {
      final dayOffset = col * 7 - (startWeekday - 1);
      final date = start.add(Duration(days: dayOffset));
      if (date.year != year) {
        labels.add(const SizedBox(width: _cellSize + _cellMargin * 2));
        continue;
      }
      if (date.month != currentMonth) {
        currentMonth = date.month;
        labels.add(SizedBox(
          width: _cellSize + _cellMargin * 2,
          child: Text(_months[date.month - 1], style: const TextStyle(fontSize: 10)),
        ));
      } else {
        labels.add(const SizedBox(width: _cellSize + _cellMargin * 2));
      }
    }

    return Padding(
      padding: EdgeInsets.only(left: 14 * 8 + 4), // offset for weekday labels
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: labels),
      ),
    );
  }

  Widget _buildWeekDayLabels() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: _weekDays.map((d) {
        return SizedBox(
          height: _cellSize + _cellMargin * 2,
          child: Center(child: Text(d, style: const TextStyle(fontSize: 9))),
        );
      }).toList(),
    );
  }

  Widget _buildGrid(DateTime start, int startWeekday, int gridCols, int totalDays, DateTime today) {
    final cols = <Widget>[];

    for (int col = 0; col < gridCols; col++) {
      final cells = <Widget>[];
      for (int row = 0; row < 7; row++) {
        final dayIndex = col * 7 + row - (startWeekday - 1);
        if (dayIndex < 0 || dayIndex >= totalDays) {
          cells.add(const SizedBox(width: _cellSize + _cellMargin * 2, height: _cellSize + _cellMargin * 2));
          continue;
        }
        final date = start.add(Duration(days: dayIndex));
        final count = data.countForDate(date);
        final isFuture = date.isAfter(today);
        final color = _colorForCount(count, isFuture);

        cells.add(
          GestureDetector(
            onTap: onDateTap != null ? () => onDateTap!(date) : null,
            child: Container(
              width: _cellSize,
              height: _cellSize,
              margin: EdgeInsets.all(_cellMargin),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        );
      }
      cols.add(Column(mainAxisSize: MainAxisSize.min, children: cells));
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(mainAxisSize: MainAxisSize.min, children: cols),
    );
  }

  Widget _buildLegend() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        const Text('Less ', style: TextStyle(fontSize: 10)),
        _legendCell(Colors.grey.shade200),
        _legendCell(const Color(0xFF9BE9A8)),
        _legendCell(const Color(0xFF40C463)),
        _legendCell(const Color(0xFF30A14E)),
        _legendCell(const Color(0xFF216E39)),
        const Text(' More', style: TextStyle(fontSize: 10)),
      ],
    );
  }

  Widget _legendCell(Color color) {
    return Container(
      width: 12,
      height: 12,
      margin: const EdgeInsets.symmetric(horizontal: 1),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
    );
  }

  Color _colorForCount(int count, bool isFuture) {
    if (isFuture) return Colors.transparent;
    if (count == 0) return Colors.grey.shade200;
    if (count == 1) return const Color(0xFF9BE9A8);
    if (count == 2) return const Color(0xFF40C463);
    if (count == 3) return const Color(0xFF30A14E);
    return const Color(0xFF216E39);
  }
}
