import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/database_provider.dart';
import '../../services/usage_service.dart';

class UsagePage extends ConsumerStatefulWidget {
  const UsagePage({super.key});

  @override
  ConsumerState<UsagePage> createState() => _UsagePageState();
}

class _UsagePageState extends ConsumerState<UsagePage> {
  bool _loading = true;
  UsageSummary? _today;
  UsageSummary? _week;
  UsageSummary? _month;
  UsageSummary? _total;
  List<(String, int, int, double)>? _models;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final svc = UsageService(ref.read(databaseProvider));
    final todaySummary = await svc.summary(from: today);
    final weekSummary = await svc.summary(
      from: today.subtract(const Duration(days: 6)),
    );
    final monthSummary = await svc.summary(
      from: today.subtract(const Duration(days: 29)),
    );
    final totalSummary = await svc.summary();
    final models = await svc.modelBreakdown();
    if (!mounted) return;
    setState(() {
      _today = todaySummary;
      _week = weekSummary;
      _month = monthSummary;
      _total = totalSummary;
      _models = models;
      _loading = false;
    });
  }

  Future<void> _editPrice((String, int, int, double) model) async {
    final (inMiss, inHit, out) = await UsageService.loadPrice(model.$1);
    final missCtrl = TextEditingController(text: inMiss.toString());
    final hitCtrl = TextEditingController(text: inHit.toString());
    final outCtrl = TextEditingController(text: out.toString());
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${model.$1} 单价（元/百万 token）'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: missCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: '输入（未命中）',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: hitCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: '输入（命中）',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: outCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: '输出',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              final i = double.tryParse(missCtrl.text.trim());
              final h = double.tryParse(hitCtrl.text.trim());
              final o = double.tryParse(outCtrl.text.trim());
              if (i == null || h == null || o == null || i < 0 || h < 0 || o < 0) return;
              UsageService.savePrice(model.$1, i, h, o);
              Navigator.pop(ctx, true);
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
    if (saved == true) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('AI 看板')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _statsRow(),
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '模型明细',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 4),
                          if (_models!.isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              child: Center(
                                child: Text(
                                  '暂无用量记录，使用 AI 功能后这里会显示数据',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ),
                          for (final m in _models!)
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              dense: true,
                              title: Text(
                                m.$1,
                                style: const TextStyle(fontSize: 13),
                              ),
                              subtitle: Text(
                                '输入 ${_fmt(m.$2)} · 输出 ${_fmt(m.$3)}',
                                style: const TextStyle(fontSize: 11),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '¥${m.$4.toStringAsFixed(2)}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: scheme.primary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.tune, size: 18),
                                    tooltip: '设置单价',
                                    onPressed: () => _editPrice(m),
                                  ),
                                ],
                              ),
                            ),
                          Text(
                            '费用为按单价估算，可在设置中调整',
                            style: TextStyle(
                              fontSize: 11,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  String _fmt(int n) => n >= 10000 ? '${(n / 1000).toStringAsFixed(1)}k' : '$n';

  Widget _statsRow() {
    final items = [
      ('今日', _today!),
      ('近 7 日', _week!),
      ('近 30 日', _month!),
      ('累计', _total!),
    ];
    return GridView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 240,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.6,
      ),
      children: [
        for (final (label, s) in items)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_fmt(s.totalTokens)} tokens',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    '¥${s.cost.toStringAsFixed(2)} · ${s.count} 次请求',
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
