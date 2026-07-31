import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/database_provider.dart';
import '../../providers/llm_config_provider.dart';
import '../../services/suggestion_service.dart';

class SuggestionPage extends ConsumerStatefulWidget {
  const SuggestionPage({super.key});

  @override
  ConsumerState<SuggestionPage> createState() => _SuggestionPageState();
}

class _SuggestionPageState extends ConsumerState<SuggestionPage> {
  String? _suggestion;
  bool _generating = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadLatest());
  }

  Future<void> _loadLatest() async {
    final reviews = await ref
        .read(databaseProvider)
        .getAllReviews(kind: SuggestionService.suggestionKind);
    if (!mounted) return;
    if (reviews.isNotEmpty) {
      setState(() => _suggestion = reviews.first.content);
    }
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
      final result = await SuggestionService(
        ref.read(databaseProvider),
      ).generate(svc);
      if (!mounted) return;
      setState(() {
        _suggestion = result;
        _generating = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _generating = false;
        _error = '生成失败: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('AI 建议')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              icon: _generating
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.lightbulb_outline),
              label: Text(_generating ? '生成中...' : '生成建议（近 7 天）'),
              onPressed: _generating ? null : _generate,
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(_error!, style: TextStyle(color: scheme.error)),
            ),
          if (_suggestion != null) ...[
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: SelectableText(
                  _suggestion!,
                  style: const TextStyle(height: 1.6),
                ),
              ),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            '建议基于近 7 天日记生成，不限于情绪，涵盖生活各方面；内容已尽量简练。',
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
