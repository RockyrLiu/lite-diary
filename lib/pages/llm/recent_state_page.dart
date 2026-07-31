import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../database/database.dart';
import '../../providers/database_provider.dart';
import '../../providers/llm_config_provider.dart';
import '../../services/llm_context.dart';
import '../../services/portrait_service.dart';

class RecentStatePage extends ConsumerStatefulWidget {
  const RecentStatePage({super.key});

  @override
  ConsumerState<RecentStatePage> createState() => _RecentStatePageState();
}

class _RecentStatePageState extends ConsumerState<RecentStatePage> {
  Portrait? _portrait;
  bool _loading = true;
  bool _generating = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = ref.read(databaseProvider);
    final portrait = await db.getPortrait(PortraitService.recentKind);
    if (!mounted) return;
    setState(() {
      _portrait = portrait;
      _loading = false;
    });
  }

  Future<void> _update() async {
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
      final result = await PortraitService(
        ref.read(databaseProvider),
      ).updateRecentState(svc);
      await _load();
      if (!mounted) return;
      setState(() => _generating = false);
      if (!result.updated) {
        setState(() => _error = '近 7 天没有新增日记内容，无需更新');
      } else if (result.content == null || result.content!.isEmpty) {
        setState(() => _error = '近 7 天没有日记内容，先写点日记吧');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _generating = false;
        _error = '更新失败: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('近期状态')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_generating)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 12),
                        Text('正在更新近期状态...'),
                      ],
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
                if (_portrait != null && _portrait!.content.isNotEmpty) ...[
                  _InfoRow(
                    label: '覆盖范围',
                    value: formatDateRangeLabel(
                      _portrait!.periodStart!,
                      _portrait!.periodEnd!,
                    ),
                  ),
                  _InfoRow(
                    label: '更新时间',
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
                    Icons.wb_twilight,
                    size: 64,
                    color: scheme.onSurfaceVariant.withValues(alpha: 0.4),
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: Text(
                      '暂无近期状态\n基于近 7 天日记增量更新',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                FilledButton.icon(
                  icon: Icon(_generating ? Icons.hourglass_top : Icons.refresh),
                  label: Text(_generating ? '更新中...' : '更新近期状态'),
                  onPressed: _generating ? null : _update,
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
