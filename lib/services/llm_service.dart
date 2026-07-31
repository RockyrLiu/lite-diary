import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

class LlmApiException implements Exception {
  final String message;
  LlmApiException(this.message);
  @override
  String toString() => message;
}

class LlmUsage {
  final String model;
  final int promptTokens;
  final int promptCacheHitTokens;
  final int promptCacheMissTokens;
  final int completionTokens;
  final bool estimated;

  const LlmUsage({
    required this.model,
    required this.promptTokens,
    required this.completionTokens,
    this.promptCacheHitTokens = 0,
    this.promptCacheMissTokens = 0,
    this.estimated = false,
  });

  int get totalTokens => promptTokens + completionTokens;

  /// 从 API 返回的 usage 字段构建；缺失时用字符长度估算（估算按 4 字符 ≈ 1 token）。
  factory LlmUsage.build(
    Object? usage, {
    required String model,
    int? estimatedPrompt,
    int estimatedCompletion = 0,
  }) {
    int? prompt;
    int? hit;
    int? miss;
    int? completion;
    if (usage is Map<String, dynamic>) {
      final p = usage['prompt_tokens'];
      final h = usage['prompt_cache_hit_tokens'];
      final m = usage['prompt_cache_miss_tokens'];
      final c = usage['completion_tokens'];
      prompt = p is num ? p.toInt() : null;
      hit = h is num ? h.toInt() : null;
      miss = m is num ? m.toInt() : null;
      completion = c is num ? c.toInt() : null;
      // 无缓存明细时按全部未命中处理
      if (prompt != null && hit == null && miss == null) {
        miss = prompt;
      }
    }
    if (prompt == null && estimatedPrompt != null) {
      prompt = (estimatedPrompt / 4).round();
      miss ??= prompt;
    }
    completion ??= (estimatedCompletion / 4).round();
    return LlmUsage(
      model: model,
      promptTokens: prompt ?? 0,
      promptCacheHitTokens: hit ?? 0,
      promptCacheMissTokens: miss ?? 0,
      completionTokens: completion,
      estimated: usage is! Map<String, dynamic>,
    );
  }
}

class LlmService {
  final String apiUrl;
  final String apiKey;
  final String model;
  final void Function(LlmUsage usage)? onUsage;

  const LlmService({
    required this.apiUrl,
    required this.apiKey,
    required this.model,
    this.onUsage,
  });

  String get _baseUrl =>
      apiUrl.endsWith('/') ? apiUrl.substring(0, apiUrl.length - 1) : apiUrl;
  String get _chatUrl => '$_baseUrl/chat/completions';

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $apiKey',
  };

  Future<String> sendMessage({
    required List<Map<String, String>> messages,
  }) async {
    final body = jsonEncode({
      'model': model,
      'messages': messages,
      'stream': false,
    });

    final response = await http
        .post(Uri.parse(_chatUrl), headers: _headers, body: body)
        .timeout(const Duration(seconds: 120));

    if (response.statusCode != 200) {
      final errorBody = _tryParseError(response.body);
      throw LlmApiException('API 错误 (${response.statusCode}): $errorBody');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    _reportUsage(data['usage'], estimatedPrompt: body.length);
    final choices = data['choices'] as List?;
    if (choices == null || choices.isEmpty) {
      throw LlmApiException('API 返回空结果');
    }
    final message = choices.first['message'] as Map<String, dynamic>?;
    return message?['content']?.toString() ?? '';
  }

  Stream<String> sendMessageStream({
    required List<Map<String, String>> messages,
  }) async* {
    final body = jsonEncode({
      'model': model,
      'messages': messages,
      'stream': true,
      'stream_options': {'include_usage': true},
    });

    final request = http.Request('POST', Uri.parse(_chatUrl));
    request.headers.addAll(_headers);
    request.body = body;

    final http.StreamedResponse response;
    try {
      response = await http.Client()
          .send(request)
          .timeout(const Duration(seconds: 120));
    } catch (e) {
      throw LlmApiException('连接失败: $e');
    }

    if (response.statusCode != 200) {
      final errorBody = await response.stream.bytesToString();
      throw LlmApiException(
        'API 错误 (${response.statusCode}): ${_tryParseError(errorBody)}',
      );
    }

    var output = 0;
    var reported = false;
    await for (final line
        in response.stream
            .transform(utf8.decoder)
            .transform(const LineSplitter())) {
      if (line.startsWith('data: ')) {
        final data = line.substring(6).trim();
        if (data == '[DONE]') break;
        try {
          final json = jsonDecode(data) as Map<String, dynamic>;
          final usage = json['usage'];
          if (usage is Map<String, dynamic>) {
            _reportUsage(usage, estimatedPrompt: body.length);
            reported = true;
          }
          final choices = json['choices'] as List?;
          if (choices != null && choices.isNotEmpty) {
            final delta = choices.first['delta'] as Map<String, dynamic>?;
            final content = delta?['content']?.toString();
            if (content != null && content.isNotEmpty) {
              output += content.length;
              yield content;
            }
          }
        } catch (_) {
          // ignore malformed chunks
        }
      }
    }
    if (!reported) {
      _reportUsage(
        null,
        estimatedPrompt: body.length,
        estimatedCompletion: output,
      );
    }
  }

  void _reportUsage(
    Object? usage, {
    int? estimatedPrompt,
    int estimatedCompletion = 0,
  }) {
    final cb = onUsage;
    if (cb == null) return;
    cb(
      LlmUsage.build(
        usage,
        model: model,
        estimatedPrompt: estimatedPrompt,
        estimatedCompletion: estimatedCompletion,
      ),
    );
  }

  String _tryParseError(String body) {
    try {
      final data = jsonDecode(body) as Map<String, dynamic>;
      return data['error']?['message']?.toString() ?? body;
    } catch (_) {
      return body;
    }
  }
}
