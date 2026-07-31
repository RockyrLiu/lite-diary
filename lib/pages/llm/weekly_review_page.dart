import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../database/database.dart';
import '../../providers/database_provider.dart';
import '../../providers/llm_config_provider.dart';
import '../../services/llm_context.dart';
import '../../services/weekly_review_service.dart';

class WeeklyReviewPage extends ConsumerStatefulWidget {
  const WeeklyReviewPage({super.key});

  @override
  ConsumerState<WeeklyReviewPage> createState() => _WeeklyReviewPageState();
}

class _WeeklyReviewPageState extends ConsumerState<WeeklyReviewPage> {
  String _kind = ReviewService.weekKind;
  List<Review> _reviews = [];
  bool _loading = true;
  bool _generating = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final reviews = await ref.read(databaseProvider).getAllReviews(kind: _kind);
    if (!mounted) return;
    setState(() {
      _reviews = reviews;
      _loading = false;
    });
  }

  Future<void> _generate() async {
    final svc = await LlmConfigService.buildConfiguredService();
    if (!mounted) return;
    if (svc == null) {
      setState(() => _error = '请先在设置中配置 API 地址和密钥');
      return;
    }
    setState(() {
      _generating = true;
      _error = null;
    });
    try {
      await ReviewService(
        ref.read(databaseProvider),
      ).generate(svc, kind: _kind);
      await _load();
      if (!mounted) return;
      setState(() => _generating = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _generating = false;
        _error = '生成失败: $e';
      });
    }
  }

  Future<void> _delete(Review review) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除回顾'),
        content: const Text('确定要删除这份回顾吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              '删除',
              style: TextStyle(color: Theme.of(ctx).colorScheme.error),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(databaseProvider).deleteReview(review.id);
      await _load();
    }
  }

  void _switchKind(String kind) {
    setState(() {
      _kind = kind;
      _loading = true;
    });
    _load();
  }

  String get _kindLabel => switch (_kind) {
        ReviewService.monthKind => '月报',
        ReviewService.yearKind => '年报',
        _ => '周报',
      };

  String get _spanLabel => switch (_kind) {
        ReviewService.monthKind => '近 30 天',
        ReviewService.yearKind => '近 365 天',
        _ => '近 7 天',
      };

  String get _btnLabel {
    return _generating ? '生成中...' : '生成$_kindLabel（$_spanLabel）';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('AI 回顾')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Row(
                    children: [
                      SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(value: 'week', label: Text('周报')),
                          ButtonSegment(value: 'month', label: Text('月报')),
                          ButtonSegment(value: 'year', label: Text('年报')),
                        ],
                        selected: {_kind},
                        onSelectionChanged: (s) => _switchKind(s.first),
                        showSelectedIcon: false,
                        style: const ButtonStyle(
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      icon: _generating
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.auto_awesome),
                      label: Text(_btnLabel),
                      onPressed: _generating ? null : _generate,
                    ),
                  ),
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(_error!, style: TextStyle(color: scheme.error)),
                  ),
                Expanded(
                  child: _reviews.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.event_note,
                                size: 64,
                                color: scheme.onSurfaceVariant.withValues(
                                  alpha: 0.4,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                '还没有$_kindLabel',
                                style: TextStyle(
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          itemCount: _reviews.length,
                          itemBuilder: (_, i) {
                            final review = _reviews[i];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            formatDateRangeLabel(
                                              review.periodStart,
                                              review.periodEnd,
                                            ),
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                        Text(
                                          '${review.generatedAt.month}/${review.generatedAt.day} ${review.generatedAt.hour.toString().padLeft(2, '0')}:${review.generatedAt.minute.toString().padLeft(2, '0')}',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: scheme.onSurfaceVariant,
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(
                                            Icons.delete_outline,
                                            size: 18,
                                          ),
                                          onPressed: () => _delete(review),
                                        ),
                                      ],
                                    ),
                                    SelectableText(
                                      review.content,
                                      style: const TextStyle(height: 1.6),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
