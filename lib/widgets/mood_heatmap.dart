import 'package:flutter/material.dart';

/// 年度情绪热力图：12 个月以月历网格形式从左到右、从上到下排开。
/// 每格一天，颜色深浅表示情绪分；点击有数据的格子回调对应日期，点击整月卡片回调月首日期。
class MoodHeatmap extends StatelessWidget {
  final List<(DateTime, double?)> data;
  final ValueChanged<DateTime>? onDayTap;
  final ValueChanged<DateTime>? onMonthTap;

  static const double gap = 2;
  static const double cardPadding = 6;

  const MoodHeatmap({super.key, required this.data, this.onDayTap, this.onMonthTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (data.isEmpty) {
      return Center(
        child: Text('暂无情绪数据', style: TextStyle(color: scheme.onSurfaceVariant)),
      );
    }

    final year = data.first.$1.year;
    final byDate = <DateTime, double?>{};
    for (final (d, v) in data) {
      byDate[d] = v;
    }
    final now = DateTime.now();
    final isCurrentYear = now.year == year;

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxW = constraints.maxWidth;
        final cols = 2;
        final spacing = 10.0;
        final cardW = (maxW - (cols - 1) * spacing) / cols;
        final cell = ((cardW - cardPadding * 2 - 7 * gap) / 7).clamp(8.0, 24.0);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: [
                for (var m = 1; m <= 12; m++)
                  SizedBox(
                    width: cardW,
                    child: _MonthCard(
                      year: year,
                      month: m,
                      cell: cell,
                      byDate: byDate,
                      scheme: scheme,
                      isCurrent: isCurrentYear && now.month == m,
                      onTap: onMonthTap == null ? null : () => onMonthTap!(DateTime(year, m, 1)),
                      onDayTap: onDayTap,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            _legend(scheme),
          ],
        );
      },
    );
  }

  Color _cellColor(double? score, ColorScheme scheme) {
    if (score == null) {
      return scheme.surfaceContainerHighest.withValues(alpha: 0.6);
    }
    final base = scheme.outlineVariant;
    final s = score.clamp(-5.0, 5.0);
    if (s > 0) return Color.lerp(base, const Color(0xFFE65100), s / 5)!;
    if (s < 0) return Color.lerp(base, const Color(0xFF1565C0), -s / 5)!;
    return base;
  }

  Widget _legend(ColorScheme scheme) {
    return Row(children: [
      Text('-5', style: TextStyle(fontSize: 10, color: scheme.onSurfaceVariant)),
      const SizedBox(width: 4),
      for (var i = 0; i <= 10; i++)
        Container(
          width: 10,
          height: 10,
          margin: const EdgeInsets.symmetric(horizontal: 1),
          decoration: BoxDecoration(
            color: _cellColor(-5.0 + i, scheme),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      const SizedBox(width: 4),
      Text('+5', style: TextStyle(fontSize: 10, color: scheme.onSurfaceVariant)),
      const SizedBox(width: 12),
      Text('无数据', style: TextStyle(fontSize: 10, color: scheme.onSurfaceVariant)),
      const SizedBox(width: 4),
      Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    ]);
  }
}

class _MonthCard extends StatelessWidget {
  final int year;
  final int month;
  final double cell;
  final Map<DateTime, double?> byDate;
  final ColorScheme scheme;
  final bool isCurrent;
  final VoidCallback? onTap;
  final ValueChanged<DateTime>? onDayTap;

  const _MonthCard({
    required this.year,
    required this.month,
    required this.cell,
    required this.byDate,
    required this.scheme,
    required this.isCurrent,
    this.onTap,
    this.onDayTap,
  });

  @override
  Widget build(BuildContext context) {
    final first = DateTime(year, month, 1);
    final last = DateTime(year, month + 1, 0);
    final offset = first.weekday - 1; // 周一 = 0

    Color cellColor(double? score) {
      if (score == null) return scheme.surfaceContainerHighest.withValues(alpha: 0.6);
      final base = scheme.outlineVariant;
      final s = score.clamp(-5.0, 5.0);
      if (s > 0) return Color.lerp(base, const Color(0xFFE65100), s / 5)!;
      if (s < 0) return Color.lerp(base, const Color(0xFF1565C0), -s / 5)!;
      return base;
    }

    Widget cellWidget(int r, int wd) {
      final day = r * 7 + wd - offset + 1;
      if (day < 1 || day > last.day) {
        return Container(
          width: cell,
          height: cell,
          margin: EdgeInsets.all(MoodHeatmap.gap / 2),
        );
      }
      final date = DateTime(year, month, day);
      final score = byDate[date];
      final color = cellColor(score);
      return GestureDetector(
        onTap: score == null || onDayTap == null ? null : () => onDayTap!(date),
        child: Container(
          width: cell,
          height: cell,
          margin: EdgeInsets.all(MoodHeatmap.gap / 2),
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
        ),
      );
    }

    return Material(
      color: isCurrent
          ? scheme.primaryContainer.withValues(alpha: 0.35)
          : scheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(MoodHeatmap.cardPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$month月', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
              const SizedBox(height: 3),
              Row(
                children: [
                  for (final l in const ['一', '二', '三', '四', '五', '六', '日'])
                    Expanded(
                      child: Center(
                        child: Text(l, style: TextStyle(fontSize: 7, color: scheme.onSurfaceVariant)),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 2),
              for (var r = 0; r < 6; r++)
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  for (var wd = 0; wd < 7; wd++) cellWidget(r, wd),
                ]),
            ],
          ),
        ),
      ),
    );
  }
}
