import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

class LlmApiException implements Exception {
  final String message;
  LlmApiException(this.message);
  @override
  String toString() => message;
}

class LlmService {
  final String apiUrl;
  final String apiKey;
  final String model;

  const LlmService({
    required this.apiUrl,
    required this.apiKey,
    required this.model,
  });

  String get _baseUrl => apiUrl.endsWith('/') ? apiUrl.substring(0, apiUrl.length - 1) : apiUrl;
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

    final response = await http.post(
      Uri.parse(_chatUrl),
      headers: _headers,
      body: body,
    ).timeout(const Duration(seconds: 120));

    if (response.statusCode != 200) {
      final errorBody = _tryParseError(response.body);
      throw LlmApiException('API 错误 (${response.statusCode}): $errorBody');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
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
    });

    final request = http.Request('POST', Uri.parse(_chatUrl));
    request.headers.addAll(_headers);
    request.body = body;

    final http.StreamedResponse response;
    try {
      response = await http.Client().send(request).timeout(const Duration(seconds: 120));
    } catch (e) {
      throw LlmApiException('连接失败: $e');
    }

    if (response.statusCode != 200) {
      final errorBody = await response.stream.bytesToString();
      throw LlmApiException('API 错误 (${response.statusCode}): ${_tryParseError(errorBody)}');
    }

    await for (final line in response.stream
        .transform(utf8.decoder)
        .transform(const LineSplitter())) {
      if (line.startsWith('data: ')) {
        final data = line.substring(6).trim();
        if (data == '[DONE]') break;
        try {
          final json = jsonDecode(data) as Map<String, dynamic>;
          final choices = json['choices'] as List?;
          if (choices != null && choices.isNotEmpty) {
            final delta = choices.first['delta'] as Map<String, dynamic>?;
            final content = delta?['content']?.toString();
            if (content != null && content.isNotEmpty) {
              yield content;
            }
          }
        } catch (_) {
          // ignore malformed chunks
        }
      }
    }
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
