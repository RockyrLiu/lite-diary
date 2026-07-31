import 'package:lite_diary/database/database.dart';
import 'package:lite_diary/services/llm_service.dart';
import 'package:lite_diary/services/weekly_review_service.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';

class _FakeLlmService extends LlmService {
  _FakeLlmService()
    : super(apiUrl: 'https://example.com', apiKey: 'key', model: 'model');

  @override
  Future<String> sendMessage({
    required List<Map<String, String>> messages,
  }) async {
    return '回顾报告内容';
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

  group('ReviewService', () {
    test('generate 默认生成近 7 天周回顾并入库', () async {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      await db.createEntry(
        EntriesCompanion(
          title: const Value('t'),
          date: Value(today),
          content: const Value('这一周的日记'),
          groupId: const Value(1),
        ),
      );

      final review = await ReviewService(db).generate(_FakeLlmService());

      expect(review.content, '回顾报告内容');
      expect(review.kind, ReviewService.weekKind);
      expect(review.periodEnd, today);
      expect(review.periodStart, today.subtract(const Duration(days: 6)));

      final all = await db.getAllReviews();
      expect(all.length, 1);
      expect(all.first.id, review.id);
    });

    test('generate 月报覆盖近 30 天且按 kind 区分', () async {
      final review = await ReviewService(
        db,
      ).generate(_FakeLlmService(), kind: ReviewService.monthKind);
      expect(review.kind, ReviewService.monthKind);
      expect(
        review.periodStart,
        review.periodEnd.subtract(const Duration(days: 29)),
      );

      final weeks = await db.getAllReviews(kind: ReviewService.weekKind);
      final months = await db.getAllReviews(kind: ReviewService.monthKind);
      expect(weeks, isEmpty);
      expect(months, hasLength(1));
    });

    test('generate 年报覆盖近 365 天', () async {
      final review = await ReviewService(
        db,
      ).generate(_FakeLlmService(), kind: ReviewService.yearKind);
      expect(review.kind, ReviewService.yearKind);
      expect(
        review.periodStart,
        review.periodEnd.subtract(const Duration(days: 364)),
      );

      final years = await db.getAllReviews(kind: ReviewService.yearKind);
      expect(years, hasLength(1));
    });

    test('无日记时也能生成（提示性报告）', () async {
      final review = await ReviewService(db).generate(_FakeLlmService());
      expect(review.content, '回顾报告内容');
      expect(await db.getAllReviews(), hasLength(1));
    });

    test('deleteReview 删除指定报告', () async {
      final review = await ReviewService(db).generate(_FakeLlmService());
      await db.deleteReview(review.id);
      expect(await db.getAllReviews(), isEmpty);
    });
  });
}
