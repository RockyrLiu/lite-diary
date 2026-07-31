import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../database/database.dart';
import '../../providers/database_provider.dart';
import '../../providers/llm_config_provider.dart';
import '../../services/llm_context.dart';
import '../../services/portrait_service.dart';

class PortraitPage extends ConsumerStatefulWidget {
  const PortraitPage({super.key});

  @override
  ConsumerState<PortraitPage> createState() => _PortraitPageState();
}

class _PortraitPageState extends ConsumerState<PortraitPage> {
  Portrait? _portrait;
  DateTime? _nextDate;
  bool _loading = true;
  bool _generating = false;
  String? _phase;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = ref.read(databaseProvider);
    final portrait = await db.getPortrait(PortraitService.longTermKind);
    final nextDate = await PortraitService(db).nextPortraitUpdateDate();
    if (!mounted) return;
    setState(() {
      _portrait = portrait;
      _nextDate = nextDate;
      _loading = false;
    });
  }

  String _fmtDate(DateTime d) => '${d.year}年${d.month}月${d.day}日';

  /// 生成按钮下方的更新规则提示。
  String _hint() {
    final next = _nextDate;
    if (next == null) return '需积累至少一个完整自然月的日记后才能生成画像';
    if (next.isAfter(DateTime.now())) return '本月已更新，下次可更新：${_fmtDate(next)}';
    return '每月 1 号起可更新一次，画像基于自然月数据（上月及更早）';
  }

  Future<void> _generate() async {
    final portraitSvc = PortraitService(ref.read(databaseProvider));
    final next = await portraitSvc.nextPortraitUpdateDate();
    if (!mounted) return;
    if (next == null) {
      setState(() => _error = '新数据尚不足够：需先积累至少一个完整自然月的日记');
      return;
    }
    if (next.isAfter(DateTime.now())) {
      setState(() => _error = '本月已更新，下次可更新：${_fmtDate(next)}');
      return;
    }
    final svc = await LlmConfigService.buildConfiguredService();
    if (!mounted) return;
    if (svc == null) {
      setState(() => _error = '请先在设置中配置 API 地址和密钥');
      return;
    }
    setState(() {
      _generating = true;
      _phase = '正在生成周期摘要...';
      _error = null;
    });
    try {
      await portraitSvc.ensurePeriodSummaries(
        svc,
        onProgress: (done, total) {
          if (!mounted) return;
          setState(
            () =>
                _phase = total == 0 ? '周期摘要已齐全' : '正在生成周期摘要 ($done/$total)...',
          );
        },
      );
      if (!mounted) return;
      setState(() => _phase = '正在合成个人画像...');
      await portraitSvc.generateLongTermPortrait(svc);
      await _load();
      if (!mounted) return;
      setState(() {
        _generating = false;
        _phase = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _generating = false;
        _phase = null;
        _error = '生成失败: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('个人画像')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_generating)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          const SizedBox(width: 12),
                          Expanded(child: Text(_phase ?? '处理中...')),
                        ],
                      ),
                    ),
                  ),
                if (_error != null)
                  Card(
                    color: scheme.errorContainer.withValues(alpha: 0.3),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        _error ?? '',
                        style: TextStyle(color: scheme.error),
                      ),
                    ),
                  ),
                if (_portrait != null) ...[
                  _InfoRow(
                    label: '覆盖范围',
                    value: formatDateRangeLabel(
                      _portrait!.periodStart!,
                      _portrait!.periodEnd!,
                    ),
                  ),
                  _InfoRow(
                    label: '生成时间',
                    value:
                        '${_portrait!.generatedAt.year}-${_portrait!.generatedAt.month.toString().padLeft(2, '0')}-${_portrait!.generatedAt.day.toString().padLeft(2, '0')} ${_portrait!.generatedAt.hour.toString().padLeft(2, '0')}:${_portrait!.generatedAt.minute.toString().padLeft(2, '0')}',
                  ),
                  const SizedBox(height: 8),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: SelectableText(
                        _portrait!.content,
                        style: const TextStyle(height: 1.6),
                      ),
                    ),
                  ),
                ] else ...[
                  const SizedBox(height: 32),
                  Icon(
                    Icons.face_retouching_natural,
                    size: 64,
                    color: scheme.onSurfaceVariant.withValues(alpha: 0.4),
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: Text(
                      '还没有个人画像\n生成后 AI 将在对话中更好地理解你',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                FilledButton.icon(
                  icon: Icon(_generating ? Icons.hourglass_top : Icons.refresh),
                  label: Text(
                    _generating
                        ? '生成中...'
                        : (_portrait == null ? '生成个人画像' : '重新生成'),
                  ),
                  onPressed: _generating ? null : _generate,
                ),
                const SizedBox(height: 8),
                Text(
                  _hint(),
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '画像由多年（年摘要）、近三年（季摘要）、近一年（月摘要）的日记分期摘要合成，身份与生活阶段以近期为准。',
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 12))),
        ],
      ),
    );
  }
}
