import 'dart:async';

import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../database/database.dart';
import '../../providers/database_provider.dart';
import '../../providers/llm_config_provider.dart';
import '../../providers/conversation_provider.dart';
import '../../providers/analysis_prompt_provider.dart';
import '../../services/llm_service.dart';
import '../../widgets/chat_bubble.dart';
import '../../widgets/data_scope_selector.dart';

final currentConversationIdProvider = StateProvider<int?>((ref) => null);
final isStreamingProvider = StateProvider<bool>((ref) => false);

class LlmPage extends ConsumerStatefulWidget {
  const LlmPage({super.key});

  @override
  ConsumerState<LlmPage> createState() => _LlmPageState();
}

class _LlmPageState extends ConsumerState<LlmPage> {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  StreamSubscription<String>? _streamSub;
  bool _titleGenerated = false;

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    _streamSub?.cancel();
    super.dispose();
  }

  Future<LlmService?> _buildService() async {
    final config = await LlmConfigService.loadConfig();
    final apiUrl = config['apiUrl'] ?? '';
    final apiKey = config['apiKey'] ?? '';
    final model = config['model'] ?? '';
    if (apiUrl.isEmpty || apiKey.isEmpty) return null;
    return LlmService(apiUrl: apiUrl, apiKey: apiKey, model: model);
  }

  Future<String> _buildEntriesContext() async {
    final dateStart = ref.read(conversationDateStartProvider);
    final dateEnd = ref.read(conversationDateEndProvider);
    final groupIds = ref.read(conversationGroupIdsProvider);

    final db = ref.read(databaseProvider);
    var entries = await db.getAllEntries();

    if (dateStart != null) {
      entries = entries.where((e) => e.date.isAfter(dateStart.subtract(const Duration(days: 1)))).toList();
    }
    if (dateEnd != null) {
      entries = entries.where((e) => e.date.isBefore(dateEnd.add(const Duration(days: 1)))).toList();
    }
    if (groupIds.isNotEmpty) {
      entries = entries.where((e) => groupIds.contains(e.groupId)).toList();
    }

    if (entries.isEmpty) return '';

    final buffer = StringBuffer();
    for (final e in entries) {
      buffer.writeln('---');
      buffer.writeln('日期: ${e.date.year}-${e.date.month.toString().padLeft(2, '0')}-${e.date.day.toString().padLeft(2, '0')}');
      if (e.title != null) buffer.writeln('标题: ${e.title}');
      buffer.writeln(e.content);
      buffer.writeln();
    }

    final result = buffer.toString();
    if (result.length > 8000) {
      return '${result.substring(0, 8000)}...\n\n(内容过长已截断)';
    }
    return result;
  }

  Future<void> _generateTitle(int convId) async {
    final db = ref.read(databaseProvider);
    final conv = await db.getConversationById(convId);
    if (conv == null || conv.title != '新对话') return;

    final service = await _buildService();
    if (service == null) return;

    final history = await db.getMessagesByConversation(convId);
    if (history.isEmpty) return;

    try {
      final prompt = '请为以下对话生成一个简短的标题（不超过15个字），只返回标题不要加其他内容：\n${history.first.content}';
      final title = await service.sendMessage(messages: [{'role': 'user', 'content': prompt}]);
      final cleaned = title.trim().replaceAll(RegExp(r'["\n]'), '');
      if (cleaned.isNotEmpty && cleaned.length <= 20) {
        await db.updateConversation(convId, ConversationsCompanion(title: Value(cleaned), updatedAt: Value(DateTime.now())));
        ref.invalidate(allConversationsProvider);
      }
    } catch (_) {}
  }

  Future<void> _sendMessage({String? overrideContent}) async {
    final content = (overrideContent ?? _inputController.text).trim();
    if (content.isEmpty) return;
    if (overrideContent == null) {
      _inputController.clear();
    }

    final service = await _buildService();
    if (service == null) {
      _showError('请先在设置中配置 API 地址和密钥');
      return;
    }

    final db = ref.read(databaseProvider);
    var convId = ref.read(currentConversationIdProvider);
    final isNewConv = convId == null;

    if (convId == null) {
      convId = await db.createConversation(ConversationsCompanion(
        title: const Value('新对话'),
        dateStart: Value(ref.read(conversationDateStartProvider)),
        dateEnd: Value(ref.read(conversationDateEndProvider)),
        groupIds: Value(ref.read(conversationGroupIdsProvider).isNotEmpty
            ? ref.read(conversationGroupIdsProvider).join(',')
            : null),
      ));
      ref.read(currentConversationIdProvider.notifier).state = convId;
      ref.invalidate(allConversationsProvider);
    }

    await db.updateConversation(convId, ConversationsCompanion(
      updatedAt: Value(DateTime.now()),
      dateStart: Value(ref.read(conversationDateStartProvider)),
      dateEnd: Value(ref.read(conversationDateEndProvider)),
      groupIds: Value(ref.read(conversationGroupIdsProvider).isNotEmpty
          ? ref.read(conversationGroupIdsProvider).join(',')
          : null),
    ));

    await db.createMessage(MessagesCompanion(
      conversationId: Value(convId),
      role: const Value('user'),
      content: Value(content),
    ));

    final entriesContext = await _buildEntriesContext();

    final messages = <Map<String, String>>[];
    if (entriesContext.isNotEmpty) {
      messages.add({
        'role': 'system',
        'content': '以下是用户的日记内容，供参考：\n\n$entriesContext',
      });
    }
    messages.add({'role': 'system', 'content': '你是一个日记助手，请用中文回复。'});

    final history = await db.getMessagesByConversation(convId);
    for (final msg in history) {
      messages.add({'role': msg.role, 'content': msg.content});
    }

    ref.invalidate(messagesByConversationProvider(convId));
    setState(() {});

    final assistantMsgId = await db.createMessage(MessagesCompanion(
      conversationId: Value(convId),
      role: const Value('assistant'),
      content: const Value(''),
    ));

    ref.read(isStreamingProvider.notifier).state = true;
    final buffer = StringBuffer();

    try {
      _streamSub?.cancel();
      final stream = service.sendMessageStream(messages: messages);
      _streamSub = stream.listen(
        (chunk) {
          buffer.write(chunk);
          db.updateMessage(assistantMsgId, MessagesCompanion(content: Value(buffer.toString())));
          ref.invalidate(messagesByConversationProvider(convId!));
          _scrollToBottom();
        },
        onDone: () async {
          ref.read(isStreamingProvider.notifier).state = false;
          await db.updateConversation(convId!, ConversationsCompanion(updatedAt: Value(DateTime.now())));
          ref.invalidate(allConversationsProvider);
          if (isNewConv && !_titleGenerated) {
            _titleGenerated = true;
            _generateTitle(convId);
          }
          setState(() {});
        },
        onError: (e) async {
          ref.read(isStreamingProvider.notifier).state = false;
          await db.updateMessage(assistantMsgId, MessagesCompanion(content: Value('[错误] ${e.toString()}')));  
          ref.invalidate(messagesByConversationProvider(convId!));
          setState(() {});
        },
      );
    } catch (e) {
      ref.read(isStreamingProvider.notifier).state = false;
      await db.updateMessage(assistantMsgId, MessagesCompanion(content: Value('[错误] ${e.toString()}')));
      ref.invalidate(messagesByConversationProvider(convId));
      setState(() {});
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(_scrollController.position.maxScrollExtent, duration: const Duration(milliseconds: 100), curve: Curves.easeOut);
      }
    });
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  void _selectConversation(int id) {
    _titleGenerated = true;
    ref.read(currentConversationIdProvider.notifier).state = id;
    ref.read(databaseProvider).getConversationById(id).then((conv) {
      if (conv != null && mounted) {
        _titleGenerated = conv.title != '新对话';
        if (conv.dateStart != null) { ref.read(conversationDateStartProvider.notifier).state = conv.dateStart; } else { ref.read(conversationDateStartProvider.notifier).state = null; }
        if (conv.dateEnd != null) { ref.read(conversationDateEndProvider.notifier).state = conv.dateEnd; } else { ref.read(conversationDateEndProvider.notifier).state = null; }
        if (conv.groupIds != null && conv.groupIds!.isNotEmpty) {
          ref.read(conversationGroupIdsProvider.notifier).state = conv.groupIds!.split(',').map(int.parse).toList();
        } else {
          ref.read(conversationGroupIdsProvider.notifier).state = [];
        }
      }
    });
    _scrollToBottom();
  }

  Future<void> _newConversation() async {
    _titleGenerated = false;
    ref.read(conversationDateStartProvider.notifier).state = null;
    ref.read(conversationDateEndProvider.notifier).state = null;
    ref.read(conversationGroupIdsProvider.notifier).state = [];
    ref.read(currentConversationIdProvider.notifier).state = null;
    _inputController.clear();
  }

  Future<void> _deleteConversation(int id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除对话'),
        content: const Text('确定要删除这个对话吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('删除', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(databaseProvider).deleteConversation(id);
      if (ref.read(currentConversationIdProvider) == id) {
        ref.read(currentConversationIdProvider.notifier).state = null;
      }
      ref.invalidate(allConversationsProvider);
    }
  }

  Future<void> _useAnalysisPrompt(AnalysisPrompt prompt) async {
    final entriesContext = await _buildEntriesContext();
    if (entriesContext.isEmpty) {
      _showError('当前数据范围内没有日记，请先选择数据范围');
      return;
    }
    final content = prompt.promptTemplate.replaceAll('{entries}', entriesContext);
    _sendMessage(overrideContent: content);
  }

  String _formatDateRange(DateTime? start, DateTime? end, List<int> groups) {
    final parts = <String>[];
    if (start != null || end != null) {
      final s = start != null ? '${start.year}-${start.month.toString().padLeft(2, '0')}-${start.day.toString().padLeft(2, '0')}' : '不限';
      final e = end != null ? '${end.year}-${end.month.toString().padLeft(2, '0')}-${end.day.toString().padLeft(2, '0')}' : '不限';
      parts.add('$s ~ $e');
    }
    if (groups.isNotEmpty) parts.add('${groups.length} 个分组');
    if (parts.isEmpty) return '数据范围: 全部';
    return parts.join(' | ');
  }

  @override
  Widget build(BuildContext context) {
    final convId = ref.watch(currentConversationIdProvider);
    final isStreaming = ref.watch(isStreamingProvider);
    final conversationsAsync = ref.watch(allConversationsProvider);
    final dateStart = ref.watch(conversationDateStartProvider);
    final dateEnd = ref.watch(conversationDateEndProvider);
    final groupIds = ref.watch(conversationGroupIdsProvider);

    final promptsAsync = ref.watch(allAnalysisPromptsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(convId == null ? 'LLM 对话' : ''),
        actions: [
          IconButton(icon: const Icon(Icons.filter_list), tooltip: '数据范围', onPressed: () => showDialog(context: context, builder: (_) => const DataScopeSelector())),
          IconButton(icon: const Icon(Icons.add_comment), tooltip: '新建对话', onPressed: _newConversation),
          Builder(builder: (ctx) => IconButton(icon: const Icon(Icons.history), tooltip: '对话历史', onPressed: () => Scaffold.of(ctx).openEndDrawer())),
        ],
      ),
      endDrawer: Drawer(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(width: double.infinity, padding: const EdgeInsets.fromLTRB(16, 8, 16, 8), child: const Text('对话历史', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold))),
            const Divider(),
            Expanded(
              child: conversationsAsync.when(
                data: (convs) {
                  if (convs.isEmpty) return const Center(child: Text('暂无对话', style: TextStyle(color: Colors.grey)));
                  return ListView.builder(
                    itemCount: convs.length,
                    itemBuilder: (_, i) {
                      final c = convs[i];
                      final isActive = c.id == convId;
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        color: isActive ? Theme.of(context).colorScheme.primary.withAlpha(25) : null,
                        child: ListTile(
                          selected: isActive,
                          title: Text(c.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w500)),
                          subtitle: Text(
                            '${c.updatedAt.year}-${c.updatedAt.month.toString().padLeft(2, '0')}-${c.updatedAt.day.toString().padLeft(2, '0')}',
                            style: const TextStyle(fontSize: 12),
                          ),
                          trailing: IconButton(icon: const Icon(Icons.delete, size: 18), onPressed: () => _deleteConversation(c.id)),
                          onTap: () { _selectConversation(c.id); Navigator.pop(context); },
                        ),
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('加载失败: $e')),
              ),
            ),
          ],
        ),
      ),
    ),
    body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            color: Theme.of(context).colorScheme.surfaceContainerHighest.withAlpha(100),
            child: Text(_formatDateRange(dateStart, dateEnd, groupIds), style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withAlpha(180))),
          ),
          Expanded(
            child: convId == null
                ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey.shade400),
                    const SizedBox(height: 16),
                    Text('新建对话或选择历史对话', style: TextStyle(color: Colors.grey.shade500)),
                  ]))
                : ref.watch(messagesByConversationProvider(convId)).when(
                      data: (messages) {
                        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
                        return ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.only(top: 8, bottom: 8),
                          itemCount: messages.length,
                          itemBuilder: (_, i) {
                            final msg = messages[i];
                            final isLast = i == messages.length - 1;
                            return ChatBubble(content: msg.content, isUser: msg.role == 'user', isLoading: isLast && msg.role == 'assistant' && isStreaming && msg.content.isEmpty);
                          },
                        );
                      },
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (e, _) => Center(child: Text('加载失败: $e')),
                    ),
          ),
          promptsAsync.whenOrNull(
            data: (prompts) {
              final visible = prompts.where((p) => p.isVisible).toList();
              if (visible.isEmpty) return null;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Wrap(spacing: 6, children: visible.map((p) => ActionChip(
                  avatar: const Icon(Icons.auto_awesome, size: 16),
                  label: Text(p.name, style: const TextStyle(fontSize: 12)),
                  onPressed: isStreaming ? null : () => _useAnalysisPrompt(p),
                )).toList()),
              );
            },
          ) ?? const SizedBox.shrink(),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: _inputController,
                  decoration: InputDecoration(hintText: '输入消息...', border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)), contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10), isDense: true),
                  maxLines: 3, minLines: 1,
                  textInputAction: TextInputAction.newline,
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                icon: isStreaming ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.send),
                onPressed: isStreaming ? null : () => _sendMessage(),
              ),
            ]),
          ),
        ],
      ),
    );
  }
}
