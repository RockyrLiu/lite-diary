import 'package:lite_diary/database/database.dart';
import 'package:lite_diary/services/llm_service.dart';
import 'package:lite_diary/services/suggestion_service.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';

class _FakeLlmService extends LlmService {
  _FakeLlmService() : super(apiUrl: 'https://example.com', apiKey: 'key', model: 'model');

  @override
  Future<String> sendMessage({required List<Map<String, String>> messages}) async {
    return '1. 保持作息\n2. 多运动\n3. 联系朋友';
  }
}

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting();
  });

  tearDown(() async {
    await db.close();
  });

  group('SuggestionService', () {
    test('generate 生成建议并保存到 Reviews', () async {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      await db.createEntry(EntriesCompanion(
        title: const Value('t'),
        date: Value(today),
        content: const Value('这周很忙'),
        groupId: const Value(1),
      ));

      final result = await SuggestionService(db).generate(_FakeLlmService());
      expect(result, contains('作息'));

      final reviews = await db.getAllReviews(kind: SuggestionService.suggestionKind);
      expect(reviews, hasLength(1));
      expect(reviews.first.content, result);
      expect(reviews.first.periodEnd, today);
      expect(reviews.first.periodStart, today.subtract(const Duration(days: 6)));
    });

    test('超长结果截断到 400 字后入库', () async {
      final long = List.filled(60, '建议内容建议内容建议内容').join('');
      final longFake = _LongLlmService(long);
      final result = await SuggestionService(db).generate(longFake);
      expect(result.length, 403); // 400 + 省略号
      final reviews = await db.getAllReviews(kind: SuggestionService.suggestionKind);
      expect(reviews.first.content.length, 403);
    });
  });
}

class _LongLlmService extends LlmService {
  final String response;

  _LongLlmService(this.response)
      : super(apiUrl: 'https://example.com', apiKey: 'key', model: 'model');

  @override
  Future<String> sendMessage({required List<Map<String, String>> messages}) async {
    return response;
  }
}
