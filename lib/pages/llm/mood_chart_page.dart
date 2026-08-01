import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/database_provider.dart';
import '../../providers/llm_config_provider.dart';
import '../../services/mood_service.dart';
import '../../widgets/mood_curve_chart.dart';
import '../../widgets/mood_heatmap.dart';

enum _MoodRange { week, month, year, all }

enum _MoodView { curve, heatmap }

class MoodChartPage extends ConsumerStatefulWidget {
  const MoodChartPage({super.key});

  @override
  ConsumerState<MoodChartPage> createState() => _MoodChartPageState();
}

class _MoodChartPageState extends ConsumerState<MoodChartPage> {
  _MoodView _view = _MoodView.curve;
  _MoodRange _range = _MoodRange.month;
  DateTime? _focusStart;
  List<(DateTime, double?)> _curve = [];
  List<(DateTime, double?)> _yearData = [];
  int _heatmapYear = DateTime.now().year;
  bool _loading = true;
  bool _scoring = false;
  String? _scorePhase;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  DateTime _startOf(_MoodRange range) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return switch (range) {
      _MoodRange.week => today.subtract(const Duration(days: 6)),
      _MoodRange.month => today.subtract(const Duration(days: 29)),
      _MoodRange.year => today.subtract(const Duration(days: 364)),
      _MoodRange.all => DateTime(2000, 1, 1),
    };
  }

  (DateTime, DateTime) get _curveRange {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (_focusStart != null) {
      return (
        _focusStart!,
        DateTime(
          _focusStart!.year,
          _focusStart!.month + 1,
          1,
        ).subtract(const Duration(days: 1)),
      );
    }
    return (_startOf(_range), today);
  }

  Future<void> _load() async {
    final svc = MoodScoreService(ref.read(databaseProvider));
    final (start, end) = _curveRange;
    final curve = await svc.dailyMoodCurve(start, end);
    if (!mounted) return;
    setState(() {
      _curve = curve;
      _loading = false;
    });
  }

  Future<void> _loadYearHeatmap() async {
    final year = _heatmapYear;
    final svc = MoodScoreService(ref.read(databaseProvider));
    final data = await svc.dailyMoodCurve(
      DateTime(year, 1, 1),
      DateTime(year, 12, 31),
    );
    if (!mounted) return;
    setState(() => _yearData = data);
  }

  void _switchYear(int delta) {
    final current = DateTime.now().year;
    final target = _heatmapYear + delta;
    if (target > current) return;
    setState(() {
      _heatmapYear = target;
      _loading = true;
    });
    _loadYearHeatmap().then((_) {
      if (mounted) setState(() => _loading = false);
    });
  }

  void _switchView(_MoodView view) {
    setState(() {
      _view = view;
      _loading = true;
    });
    if (view == _MoodView.heatmap) {
      _loadYearHeatmap().then((_) {
        if (mounted) setState(() => _loading = false);
      });
    } else {
      _load();
    }
  }

  Future<void> _scoreMissing() async {
    final llm = await LlmConfigService.buildConfiguredService();
    if (!mounted) return;
    if (llm == null) {
      setState(() => _error = '请先在设置中配置 API 地址和密钥');
      return;
    }
    final svc = MoodScoreService(ref.read(databaseProvider));
    final start = _startOf(_range);
    final allUnscored = await svc.getUnscoredDays();
    final inRange = allUnscored.where((d) => !d.isBefore(start)).toList();
    if (inRange.isEmpty) {
      setState(() => _error = '所选范围内没有待打分的日期');
      return;
    }
    setState(() {
      _scoring = true;
      _error = null;
    });
    try {
      await svc.scoreDays(
        llm,
        inRange,
        onProgress: (done, total) {
          if (!mounted) return;
          setState(() => _scorePhase = '正在打分 ($done/$total)...');
        },
      );
      if (!mounted) return;
      setState(() {
        _scoring = false;
        _scorePhase = null;
      });
      await _load();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _scoring = false;
        _scorePhase = null;
        _error = '打分失败: $e';
      });
    }
  }

  void _onHeatmapTap(DateTime date) {
    final score = _yearData
        .firstWhere((d) => d.$1 == date, orElse: () => (date, null))
        .$2;
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '情绪分: ${score == null ? '无数据' : score.toStringAsFixed(1)}',
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    setState(() {
                      _focusStart = DateTime(date.year, date.month, 1);
                      _view = _MoodView.curve;
                      _loading = true;
                    });
                    _load();
                  },
                  child: const Text('查看当月曲线'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final scored = _curve.where((c) => c.$2 != null).toList();
    final values = scored.map((c) => c.$2!).toList();
    final avg = values.isEmpty
        ? null
        : values.reduce((a, b) => a + b) / values.length;
    final max = values.isEmpty ? null : values.reduce((a, b) => a > b ? a : b);
    final min = values.isEmpty ? null : values.reduce((a, b) => a < b ? a : b);

    return Scaffold(
      appBar: AppBar(title: const Text('情绪波动')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                SegmentedButton<_MoodView>(
                  segments: const [
                    ButtonSegment(
                      value: _MoodView.curve,
                      icon: Icon(Icons.show_chart),
                      label: Text('曲线'),
                    ),
                    ButtonSegment(
                      value: _MoodView.heatmap,
                      icon: Icon(Icons.grid_view),
                      label: Text('热力图'),
                    ),
                  ],
                  selected: {_view},
                  onSelectionChanged: (s) => _switchView(s.first),
                  showSelectedIcon: false,
                  style: const ButtonStyle(
                    visualDensity: VisualDensity.compact,
                  ),
                ),
                const SizedBox(width: 24),
                FilledButton.tonalIcon(
                  icon: _scoring
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.auto_awesome, size: 18),
                  label: Text(_scoring ? '打分中' : '补算打分'),
                  onPressed: _scoring ? null : _scoreMissing,
                ),
                const Spacer(),
              ],
            ),
          ),
          if (_view == _MoodView.curve) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  for (final (r, label) in const [
                    (_MoodRange.week, '近一周'),
                    (_MoodRange.month, '近一月'),
                    (_MoodRange.year, '近一年'),
                    (_MoodRange.all, '全部'),
                  ])
                    ChoiceChip(
                      label: Text(label),
                      selected: _range == r,
                      onSelected: (_) {
                        setState(() {
                          _range = r;
                          _focusStart = null;
                          _loading = true;
                        });
                        _load();
                      },
                    ),
                  if (_focusStart != null)
                    ActionChip(
                      avatar: const Icon(Icons.calendar_month, size: 16),
                      label: Text(
                        '${_focusStart!.year}年${_focusStart!.month}月',
                      ),
                      onPressed: () {
                        setState(() {
                          _focusStart = null;
                          _loading = true;
                        });
                        _load();
                      },
                    ),
                ],
              ),
            ),
            if (_scoring)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _scorePhase ?? '',
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                child: Text(
                  _error!,
                  style: TextStyle(fontSize: 12, color: scheme.error),
                ),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  _StatChip(label: '平均', value: avg?.toStringAsFixed(1) ?? '—'),
                  const SizedBox(width: 8),
                  _StatChip(label: '最高', value: max?.toStringAsFixed(1) ?? '—'),
                  const SizedBox(width: 8),
                  _StatChip(label: '最低', value: min?.toStringAsFixed(1) ?? '—'),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 16, 16),
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : Column(
                        children: [
                          Expanded(
                            child: MoodCurveChart(
                              data: _curve,
                              height: double.infinity,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              '评分范围 -5（低落）~ +5（高涨），仅显示有数据的日期，评分由 AI 基于日记内容生成',
                              style: TextStyle(
                                fontSize: 11,
                                color: scheme.onSurfaceVariant,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ] else ...[
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : SingleChildScrollView(
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                IconButton(
                                  icon: const Icon(
                                    Icons.chevron_left,
                                    size: 22,
                                  ),
                                  tooltip: '上一年',
                                  visualDensity: VisualDensity.compact,
                                  constraints: const BoxConstraints(
                                    minWidth: 32,
                                    minHeight: 32,
                                  ),
                                  padding: EdgeInsets.zero,
                                  onPressed: () => _switchYear(-1),
                                ),
                                Text(
                                  '$_heatmapYear 年',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.chevron_right,
                                    size: 22,
                                  ),
                                  tooltip: '下一年',
                                  visualDensity: VisualDensity.compact,
                                  constraints: const BoxConstraints(
                                    minWidth: 32,
                                    minHeight: 32,
                                  ),
                                  padding: EdgeInsets.zero,
                                  onPressed: _heatmapYear >=
                                          DateTime.now().year
                                      ? null
                                      : () => _switchYear(1),
                                ),
                                if (_heatmapYear != DateTime.now().year)
                                  IconButton(
                                    icon: const Icon(
                                      Icons.today,
                                      size: 22,
                                    ),
                                    tooltip: '回到今年',
                                    visualDensity: VisualDensity.compact,
                                    constraints: const BoxConstraints(
                                      minWidth: 32,
                                      minHeight: 32,
                                    ),
                                    padding: EdgeInsets.zero,
                                    onPressed: () => _switchYear(
                                      DateTime.now().year - _heatmapYear,
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            MoodHeatmap(
                              data: _yearData,
                              onDayTap: _onHeatmapTap,
                              onMonthTap: (date) {
                                setState(() {
                                  _focusStart = DateTime(
                                    date.year,
                                    date.month,
                                    1,
                                  );
                                  _view = _MoodView.curve;
                                  _loading = true;
                                });
                                _load();
                              },
                            ),
                          ],
                        ),
                      ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;

  const _StatChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$label $value',
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
      ),
    );
  }
}
