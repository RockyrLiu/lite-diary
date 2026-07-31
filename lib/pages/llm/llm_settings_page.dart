import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../database/database.dart';
import '../../providers/llm_config_provider.dart';
import '../../providers/analysis_prompt_provider.dart';
import '../../providers/database_provider.dart';
import '../../services/llm_service.dart';
import '../../services/usage_service.dart';
import '../../widgets/section_header.dart';

class LlmSettingsPage extends ConsumerStatefulWidget {
  const LlmSettingsPage({super.key});

  @override
  ConsumerState<LlmSettingsPage> createState() => _LlmSettingsPageState();
}

class _LlmSettingsPageState extends ConsumerState<LlmSettingsPage> {
  static const priceModels = ['deepseek-v4-flash', 'deepseek-v4-pro'];

  bool? _connected;
  bool _checking = false;
  Map<String, String> _config = {};
  final Map<String, TextEditingController> _priceInCtrl = {};
  final Map<String, TextEditingController> _priceHitCtrl = {};
  final Map<String, TextEditingController> _priceOutCtrl = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadConfig();
      _loadPrices();
    });
  }

  @override
  void dispose() {
    for (final c in _priceInCtrl.values) {
      c.dispose();
    }
    for (final c in _priceHitCtrl.values) {
      c.dispose();
    }
    for (final c in _priceOutCtrl.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadPrices() async {
    for (final m in priceModels) {
      final (inMiss, inHit, out) = await UsageService.loadPrice(m);
      _priceInCtrl[m] = TextEditingController(text: _fmtPrice(inMiss));
      _priceHitCtrl[m] = TextEditingController(text: _fmtPrice(inHit));
      _priceOutCtrl[m] = TextEditingController(text: _fmtPrice(out));
    }
    if (mounted) setState(() {});
  }

  String _fmtPrice(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

  Future<void> _savePrice(String model) async {
    final miss = double.tryParse(_priceInCtrl[model]!.text.trim());
    final hit = double.tryParse(_priceHitCtrl[model]!.text.trim());
    final out = double.tryParse(_priceOutCtrl[model]!.text.trim());
    if (miss == null || hit == null || out == null || miss < 0 || hit < 0 || out < 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请输入有效的非负数字')));
      return;
    }
    await UsageService.savePrice(model, miss, hit, out);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('已保存 $model 单价')));
    }
  }

  Future<void> _loadConfig() async {
    final config = await LlmConfigService.loadConfig();
    if (!mounted) return;
    setState(() => _config = config);
    _checkConnection();
  }

  Future<void> _checkConnection() async {
    final apiUrl = _config['apiUrl'] ?? '';
    final apiKey = _config['apiKey'] ?? '';
    if (apiUrl.isEmpty || apiKey.isEmpty) {
      if (mounted) setState(() { _connected = null; _checking = false; });
      return;
    }
    if (!mounted) return;
    setState(() { _checking = true; _connected = null; });
    try {
      final model = _config['model'] ?? 'deepseek-v4-flash';
      final svc = LlmService(apiUrl: apiUrl, apiKey: apiKey, model: model);
      await svc.sendMessage(messages: [{'role': 'user', 'content': 'hi'}]);
      if (mounted) setState(() { _checking = false; _connected = true; });
    } catch (_) {
      if (mounted) setState(() { _checking = false; _connected = false; });
    }
  }

  Future<void> _showConfigDialog() async {
    final urlCtrl = TextEditingController(text: _config['apiUrl'] ?? '');
    final keyCtrl = TextEditingController(text: _config['apiKey'] ?? '');
    final modelCtrl = TextEditingController(text: _config['model'] ?? 'deepseek-v4-flash');
    bool obscure = true;
    final configured = (urlCtrl.text.isNotEmpty && keyCtrl.text.isNotEmpty);

    final saved = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('API 配置'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: urlCtrl,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.link),
                  border: OutlineInputBorder(),
                  labelText: 'API 地址',
                  hintText: 'https://api.deepseek.com',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: keyCtrl,
                obscureText: obscure,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.key),
                  border: const OutlineInputBorder(),
                  labelText: 'API 密钥',
                  hintText: 'sk-...',
                  suffixIcon: IconButton(
                    icon: Icon(obscure ? Icons.visibility : Icons.visibility_off),
                    onPressed: () => setDialogState(() => obscure = !obscure),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: modelCtrl,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.auto_awesome),
                  border: OutlineInputBorder(),
                  labelText: '模型名称',
                  hintText: 'deepseek-v4-flash',
                ),
              ),
            ],
          ),
          actions: [
            if (configured)
              TextButton(
                onPressed: () => Navigator.pop(ctx, 'delete'),
                style: TextButton.styleFrom(foregroundColor: Theme.of(ctx).colorScheme.error),
                child: const Text('删除'),
              ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () async {
                final url = urlCtrl.text.trim();
                final key = keyCtrl.text.trim();
                if (url.isEmpty) return;
                await LlmConfigService.saveConfig(
                  apiUrl: url,
                  apiKey: key,
                  model: modelCtrl.text.trim(),
                );
                if (ctx.mounted) Navigator.pop(ctx, 'save');
              },
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );

    if (saved == 'save' && mounted) {
      await _loadConfig();
    } else if (saved == 'delete' && mounted) {
      await LlmConfigService.saveConfig(apiUrl: '', apiKey: '', model: 'deepseek-v4-flash');
      await _loadConfig();
    }
  }

  Widget _connectionDot() {
    if (_checking) {
      return const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 1));
    }
    return Container(
      width: 12, height: 12,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _connected == true ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.error,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final promptsAsync = ref.watch(allAnalysisPromptsProvider);
    final configured = (_config['apiUrl']?.isNotEmpty == true) && (_config['apiKey']?.isNotEmpty == true);

    return Scaffold(
      appBar: AppBar(title: const Text('LLM 配置')),
      body: ListView(
        children: [
          const SectionHeader('API 配置'),
          if (!configured)
            ListTile(
              leading: const Icon(Icons.smart_toy),
              title: const Text('未配置'),
              subtitle: const Text('请配置 API 地址和密钥'),
              trailing: FilledButton.tonal(
                onPressed: _showConfigDialog,
                child: const Text('配置'),
              ),
            )
          else ...[
            ListTile(
              leading: const Icon(Icons.smart_toy),
              title: Text(_config['model'] ?? 'deepseek-v4-flash'),
              subtitle: Row(children: [
                const Text('连接状态 '),
                _connectionDot(),
              ]),
              trailing: FilledButton.tonal(
                onPressed: _showConfigDialog,
                child: const Text('编辑'),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.link),
              title: Text(
                _config['apiUrl'] ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 14),
              ),
              subtitle: const Text('API 端点'),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: FilledButton.tonalIcon(
                icon: const Icon(Icons.wifi_find),
                label: const Text('测试连接'),
                onPressed: _checking ? null : _checkConnection,
              ),
            ),
          ],
          if (_connected == false && !_checking)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.errorContainer.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('连接失败，请检查 API 地址和密钥',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.error)),
              ),
            ),
          const Divider(),
          const SectionHeader('模型单价'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Text('设置每百万 token 费用（元），用于 AI 看板估算',
                style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ),
          for (final m in priceModels)
            Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(m, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(
                      child: TextField(
                        controller: _priceInCtrl[m],
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: '输入（未命中）', border: OutlineInputBorder(), isDense: true),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _priceHitCtrl[m],
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: '输入（命中）', border: OutlineInputBorder(), isDense: true),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(
                      child: TextField(
                        controller: _priceOutCtrl[m],
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: '输出', border: OutlineInputBorder(), isDense: true),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Center(
                        child: FilledButton.tonal(onPressed: () => _savePrice(m), child: const Text('保存')),
                      ),
                    ),
                  ]),
                ]),
              ),
            ),
          const Divider(),
          const SectionHeader('分析提示词'),
          promptsAsync.when(
            data: (prompts) => Column(children: [
              ...List.generate(prompts.length, (i) => _PromptTile(
                prompt: prompts[i],
                index: i,
                onEdit: () => _editPrompt(prompts[i]),
                onDelete: () => _deletePrompt(prompts[i]),
                onToggle: () => _toggleVisible(prompts[i]),
              )),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(children: [
                  Expanded(child: OutlinedButton.icon(icon: const Icon(Icons.add), label: const Text('新建提示词'), onPressed: () => _editPrompt(null))),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(icon: const Icon(Icons.restore), label: const Text('重置默认'), onPressed: _resetDefaults),
                ]),
              ),
            ]),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('加载失败: $e')),
          ),
        ],
      ),
    );
  }

  Future<bool> _confirm(String title, String content) async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(title),
            content: Text(content),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
              TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text('确定', style: TextStyle(color: Theme.of(ctx).colorScheme.error))),
            ],
          ),
        ) == true;
  }

  Future<void> _editPrompt(AnalysisPrompt? prompt) async {
    final nameCtrl = TextEditingController(text: prompt?.name ?? '');
    final tmplCtrl = TextEditingController(text: prompt?.promptTemplate ?? '');

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(prompt == null ? '新建提示词' : '编辑提示词'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: '名称', border: OutlineInputBorder(), isDense: true)),
          const SizedBox(height: 12),
          TextField(controller: tmplCtrl, maxLines: 6, decoration: const InputDecoration(labelText: '提示词模板', hintText: '使用 {entries} 作为日记内容占位符', border: OutlineInputBorder(), isDense: true)),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(
            onPressed: () async {
              final name = nameCtrl.text.trim();
              final template = tmplCtrl.text.trim();
              if (name.isEmpty) return;
              final db = ref.read(databaseProvider);
              if (prompt == null) {
                final prompts = await db.getAllAnalysisPrompts();
                await db.createAnalysisPrompt(AnalysisPromptsCompanion(name: Value(name), promptTemplate: Value(template), sortOrder: Value(prompts.length)));
              } else {
                await db.updateAnalysisPrompt(prompt.id, AnalysisPromptsCompanion(name: Value(name), promptTemplate: Value(template)));
              }
              if (ctx.mounted) Navigator.pop(ctx, true);
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
    if (ok == true) ref.invalidate(allAnalysisPromptsProvider);
  }

  Future<void> _deletePrompt(AnalysisPrompt prompt) async {
    if (await _confirm('删除提示词', '确定要删除"${prompt.name}"吗？')) {
      await ref.read(databaseProvider).deleteAnalysisPrompt(prompt.id);
      ref.invalidate(allAnalysisPromptsProvider);
    }
  }

  Future<void> _toggleVisible(AnalysisPrompt prompt) async {
    await ref.read(databaseProvider).updateAnalysisPrompt(
      prompt.id,
      AnalysisPromptsCompanion(isVisible: Value(!prompt.isVisible)),
    );
    ref.invalidate(allAnalysisPromptsProvider);
  }

  Future<void> _resetDefaults() async {
    if (!await _confirm('重置提示词', '将删除所有自定义提示词并恢复默认，确定吗？')) return;
    final db = ref.read(databaseProvider);
    for (final p in await db.getAllAnalysisPrompts()) {
      await db.deleteAnalysisPrompt(p.id);
    }
    await db.insertDefaultAnalysisPrompts();
    ref.invalidate(allAnalysisPromptsProvider);
  }
}

class _PromptTile extends StatelessWidget {
  final AnalysisPrompt prompt;
  final int index;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onToggle;

  const _PromptTile({required this.prompt, required this.index, required this.onEdit, required this.onDelete, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(radius: 14, backgroundColor: Theme.of(context).colorScheme.secondaryContainer, child: Text('${index + 1}', style: const TextStyle(fontSize: 12))),
      title: Text(prompt.name),
      subtitle: Text(prompt.promptTemplate, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        IconButton(icon: Icon(prompt.isVisible ? Icons.visibility : Icons.visibility_off, size: 20), onPressed: onToggle, tooltip: prompt.isVisible ? '对话页可见' : '对话页隐藏'),
        IconButton(icon: const Icon(Icons.edit, size: 20), onPressed: onEdit),
        IconButton(icon: Icon(Icons.delete, size: 20, color: Theme.of(context).colorScheme.error), onPressed: onDelete),
      ]),
    );
  }
}
