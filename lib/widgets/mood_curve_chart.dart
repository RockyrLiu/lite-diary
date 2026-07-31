import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

/// 情绪曲线图：只连接有数据的点，无数据日期断开。
class MoodCurveChart extends StatelessWidget {
  final List<(DateTime, double?)> data;
  final double height;
  final bool showTitles;

  const MoodCurveChart({
    super.key,
    required this.data,
    this.height = 160,
    this.showTitles = true,
  });

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    final runs = _contiguousRuns();

    if (runs.isEmpty) {
      return SizedBox(
        height: height,
        child: Center(
          child: Text(
            '暂无情绪数据',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    final barData = runs.map((run) {
      return LineChartBarData(
        spots: [for (final (x, y) in run) FlSpot(x.toDouble(), y)],
        isCurved: true,
        preventCurveOverShooting: true,
        color: color,
        barWidth: 2.5,
        isStrokeCapRound: true,
        dotData: const FlDotData(show: false),
        belowBarData: BarAreaData(
          show: true,
          color: color.withValues(alpha: 0.10),
        ),
      );
    }).toList();

    return SizedBox(
      height: height,
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: (data.length - 1).toDouble(),
          minY: -5,
          maxY: 5,
          lineTouchData: const LineTouchData(enabled: false),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: 2.5,
            getDrawingHorizontalLine: (v) => FlLine(
              color: Theme.of(
                context,
              ).colorScheme.outlineVariant.withValues(alpha: 0.4),
              strokeWidth: 0.8,
            ),
          ),
          borderData: FlBorderData(show: false),
          titlesData: showTitles
              ? FlTitlesData(
                  topTitles: const AxisTitles(),
                  rightTitles: const AxisTitles(),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      interval: 2.5,
                      getTitlesWidget: (v, meta) => Text(
                        v.toInt().toString(),
                        style: TextStyle(
                          fontSize: 9,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: _labelInterval,
                      getTitlesWidget: (v, meta) {
                        final idx = v.round();
                        if (idx < 0 || idx >= data.length) {
                          return const SizedBox.shrink();
                        }
                        final d = data[idx].$1;
                        return Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            '${d.month}/${d.day}',
                            style: TextStyle(
                              fontSize: 9,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                )
              : const FlTitlesData(show: false),
          lineBarsData: barData,
        ),
      ),
    );
  }

  double get _labelInterval {
    final n = data.length;
    if (n <= 7) return 1;
    if (n <= 31) return (n / 5).ceilToDouble();
    return (n / 8).ceilToDouble();
  }

  List<List<(int, double)>> _contiguousRuns() {
    final runs = <List<(int, double)>>[];
    List<(int, double)>? current;
    for (var i = 0; i < data.length; i++) {
      final v = data[i].$2;
      if (v == null) {
        current = null;
        continue;
      }
      if (current == null) {
        current = [(i, v)];
        runs.add(current);
      } else {
        current.add((i, v));
      }
    }
    return runs;
  }
}
