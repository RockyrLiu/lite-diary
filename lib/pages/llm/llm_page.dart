import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../database/database.dart';
import '../../providers/database_provider.dart';
import '../../providers/llm_config_provider.dart';
import '../../services/mood_service.dart';
import '../../services/portrait_service.dart';
import '../../services/suggestion_service.dart';
import '../../widgets/mood_curve_chart.dart';
import 'chat_page.dart';
import 'mood_chart_page.dart';
import 'portrait_page.dart';
import 'recent_state_page.dart';
import 'suggestion_page.dart';
import 'usage_page.dart';
import 'weekly_review_page.dart';

class LlmPage extends ConsumerStatefulWidget {
  const LlmPage({super.key});

  @override
  ConsumerState<LlmPage> createState() => _LlmPageState();
}

class _LlmPageState extends ConsumerState<LlmPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI'),
        actions: [
          IconButton(
            icon: const Icon(Icons.event_note),
            tooltip: 'AI 回顾',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const WeeklyReviewPage()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.insights),
            tooltip: 'AI 看板',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const UsagePage()),
            ),
          ),
        ],
      ),
      body: PageView(
        controller: PageController(initialPage: 1),
        children: const [
          _ProfileOverviewPage(),
          _MoodSuggestionOverviewPage(),
          _KeepAlive(child: ChatPage()),
        ],
      ),
    );
  }
}

class _KeepAlive extends StatefulWidget {
  final Widget child;

  const _KeepAlive({required this.child});

  @override
  State<_KeepAlive> createState() => _KeepAliveState();
}

class _KeepAliveState extends State<_KeepAlive>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}

/// 第一页：个人画像 + 近期状态（简要展示，点击进入详情）
class _ProfileOverviewPage extends ConsumerStatefulWidget {
  const _ProfileOverviewPage();

  @override
  ConsumerState<_ProfileOverviewPage> createState() =>
      _ProfileOverviewPageState();
}

class _ProfileOverviewPageState extends ConsumerState<_ProfileOverviewPage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  Portrait? _longTerm;
  Portrait? _recent;
  DateTime? _nextPortraitDate;
  bool _loading = true;
  bool _updatingPortrait = false;
  bool _updatingRecent = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = ref.read(databaseProvider);
    final longTerm = await db.getPortrait(PortraitService.longTermKind);
    final recent = await db.getPortrait(PortraitService.recentKind);
    final nextDate = await PortraitService(db).nextPortraitUpdateDate();
    if (!mounted) return;
    setState(() {
      _longTerm = longTerm;
      _recent = recent;
      _nextPortraitDate = nextDate;
      _loading = false;
    });
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
      );
  }

  String _portraitNote() {
    final next = _nextPortraitDate;
    if (next == null) return '需先积累至少一个完整自然月的日记';
    if (next.isAfter(DateTime.now())) {
      return '下次可更新：${next.year}年${next.month}月${next.day}日';
    }
    return '每月 1 号起可更新一次';
  }

  Future<void> _updatePortrait() async {
    final portraitSvc = PortraitService(ref.read(databaseProvider));
    final next = await portraitSvc.nextPortraitUpdateDate();
    if (next == null) {
      _snack('新数据尚不足够：需先积累至少一个完整自然月的日记');
      return;
    }
    if (next.isAfter(DateTime.now())) {
      _snack('本月已更新，下次可更新：${next.year}年${next.month}月${next.day}日');
      return;
    }
    final svc = await LlmConfigService.buildConfiguredService();
    if (svc == null) {
      _snack('请先在设置中配置 API 地址和密钥');
      return;
    }
    setState(() => _updatingPortrait = true);
    try {
      await portraitSvc.ensurePeriodSummaries(svc);
      await portraitSvc.generateLongTermPortrait(svc);
      await _load();
      _snack('已更新个人画像');
    } catch (e) {
      _snack('更新失败: $e');
    } finally {
      if (mounted) setState(() => _updatingPortrait = false);
    }
  }

  Future<void> _updateRecent() async {
    final svc = await LlmConfigService.buildConfiguredService();
    if (svc == null) {
      _snack('请先在设置中配置 API 地址和密钥');
      return;
    }
    setState(() => _updatingRecent = true);
    try {
      final result = await PortraitService(
        ref.read(databaseProvider),
      ).updateRecentState(svc);
      await _load();
      _snack(result.updated ? '已更新近期状态' : '近 7 天没有新增日记，无需更新');
    } catch (e) {
      _snack('更新失败: $e');
    } finally {
      if (mounted) setState(() => _updatingRecent = false);
    }
  }

  /// 概览简要内容：优先使用 AI 生成的简要版；旧数据无摘要时截断兜底。
  String _brief(Portrait? p) {
    if (p == null) return '';
    final summary = (p.summary ?? '').trim();
    if (summary.isNotEmpty) return summary;
    final content = p.content.trim();
    return content.length > 120 ? '${content.substring(0, 120)}...' : content;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
              child: _OverviewCard(
                icon: Icons.face_retouching_natural,
                title: '个人画像',
                content: _brief(_longTerm),
                updatedAt: _longTerm?.generatedAt,
                note: _portraitNote(),
                updating: _updatingPortrait,
                onUpdate: _updatePortrait,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PortraitPage()),
                ),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
              child: _OverviewCard(
                icon: Icons.wb_twilight,
                title: '近期状态',
                content: _brief(_recent),
                updatedAt: _recent?.generatedAt,
                updating: _updatingRecent,
                onUpdate: _updateRecent,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const RecentStatePage()),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 第二页：情绪波动 + AI 建议（简要展示，点击进入详情）
class _MoodSuggestionOverviewPage extends ConsumerStatefulWidget {
  const _MoodSuggestionOverviewPage();

  @override
  ConsumerState<_MoodSuggestionOverviewPage> createState() =>
      _MoodSuggestionOverviewPageState();
}

class _MoodSuggestionOverviewPageState
    extends ConsumerState<_MoodSuggestionOverviewPage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  List<(DateTime, double?)>? _weekCurve;
  String? _suggestion;
  bool _loading = true;
  bool _updatingMood = false;
  bool _updatingSuggestion = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
      );
  }

  Future<void> _updateMood() async {
    final svc = await LlmConfigService.buildConfiguredService();
    if (svc == null) {
      _snack('请先在设置中配置 API 地址和密钥');
      return;
    }
    final moodSvc = MoodScoreService(ref.read(databaseProvider));
    final now = DateTime.now();
    final start = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(const Duration(days: 29));
    final unscored = await moodSvc.getUnscoredDays();
    final inRange = unscored.where((d) => !d.isBefore(start)).toList();
    if (inRange.isEmpty) {
      _snack('近 30 天没有待打分的日期');
      return;
    }
    setState(() => _updatingMood = true);
    try {
      await moodSvc.scoreDays(svc, inRange);
      await _load();
      _snack('已补算近 30 天情绪打分');
    } catch (e) {
      _snack('打分失败: $e');
    } finally {
      if (mounted) setState(() => _updatingMood = false);
    }
  }

  Future<void> _updateSuggestion() async {
    final svc = await LlmConfigService.buildConfiguredService();
    if (svc == null) {
      _snack('请先在设置中配置 API 地址和密钥');
      return;
    }
    setState(() => _updatingSuggestion = true);
    try {
      await SuggestionService(ref.read(databaseProvider)).generate(svc);
      await _load();
      _snack('已更新建议');
    } catch (e) {
      _snack('更新失败: $e');
    } finally {
      if (mounted) setState(() => _updatingSuggestion = false);
    }
  }

  Future<void> _load() async {
    final db = ref.read(databaseProvider);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final curve = await MoodScoreService(
      db,
    ).dailyMoodCurve(today.subtract(const Duration(days: 6)), today);
    final reviews = await db.getAllReviews(
      kind: SuggestionService.suggestionKind,
    );
    if (!mounted) return;
    setState(() {
      _weekCurve = curve;
      _suggestion = reviews.isEmpty ? null : reviews.first.content;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    final scheme = Theme.of(context).colorScheme;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _OverviewCard(
            icon: Icons.mood,
            title: '情绪波动',
            content: '',
            updating: _updatingMood,
            onUpdate: _updateMood,
            body: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 140,
                  child: MoodCurveChart(
                    data: _weekCurve ?? [],
                    height: 140,
                    showTitles: true,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '近一周情绪变化，点击查看曲线与热力图',
                  style: TextStyle(
                    fontSize: 11,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const MoodChartPage()),
            ),
          ),
          const SizedBox(height: 12),
          _OverviewCard(
            icon: Icons.lightbulb_outline,
            title: 'AI 建议',
            content: _suggestion ?? '',
            maxLines: 12,
            updating: _updatingSuggestion,
            onUpdate: _updateSuggestion,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SuggestionPage()),
            ),
          ),
        ],
      ),
    );
  }
}

class _OverviewCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String content;
  final Widget? body;
  final DateTime? updatedAt;
  final String? note;
  final int maxLines;
  final VoidCallback onTap;
  final VoidCallback? onUpdate;
  final bool updating;

  const _OverviewCard({
    required this.icon,
    required this.title,
    required this.content,
    required this.onTap,
    this.body,
    this.updatedAt,
    this.note,
    this.maxLines = 5,
    this.onUpdate,
    this.updating = false,
  });

  String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')} '
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.primary.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 16, color: scheme.onSurfaceVariant),
                  const SizedBox(width: 6),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const Spacer(),
                  if (onUpdate != null)
                    updating
                        ? const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 12),
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : IconButton(
                            icon: const Icon(Icons.refresh, size: 18),
                            tooltip: '更新',
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 32,
                              minHeight: 32,
                            ),
                            onPressed: onUpdate,
                          ),
                  Icon(
                    Icons.chevron_right,
                    size: 16,
                    color: scheme.onSurfaceVariant,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (body != null)
                body!
              else if (content.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    '尚未生成，点击查看',
                    style: TextStyle(
                      fontSize: 14,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                )
              else
                Text(
                  content,
                  maxLines: maxLines,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.6,
                    color: scheme.onSurface,
                  ),
                ),
              if (updatedAt != null) ...[
                const SizedBox(height: 8),
                Text(
                  '更新于 ${_fmt(updatedAt!)}',
                  style: TextStyle(
                    fontSize: 11,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
              if (note != null) ...[
                const SizedBox(height: 4),
                Text(
                  note!,
                  style: TextStyle(
                    fontSize: 11,
                    color: scheme.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
