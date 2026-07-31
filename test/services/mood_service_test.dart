import 'package:lite_diary/database/database.dart';
import 'package:lite_diary/services/llm_service.dart';
import 'package:lite_diary/services/mood_service.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';

class _FakeLlmService extends LlmService {
  final String Function(String prompt)? handler;

  _FakeLlmService({this.handler})
    : super(apiUrl: 'https://example.com', apiKey: 'key', model: 'model');

  @override
  Future<String> sendMessage({
    required List<Map<String, String>> messages,
  }) async {
    final prompt = messages.isEmpty ? '' : messages.last['content'] ?? '';
    return handler?.call(prompt) ?? '';
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

  Future<int> createEntry(DateTime date, String content, {double? score}) {
    return db.createEntry(
      EntriesCompanion(
        title: Value('标题'),
        date: Value(date),
        content: Value(content),
        groupId: const Value(1),
        createdAt: Value(date),
        updatedAt: Value(date),
        moodScore: Value(score),
      ),
    );
  }

  group('MoodScoreService', () {
    test('getUnscoredDays 只返回有内容且未打分的日期', () async {
      await createEntry(DateTime(2026, 7, 28), '今天很开心', score: 3);
      await createEntry(DateTime(2026, 7, 29), '今天有点累');
      await createEntry(DateTime(2026, 7, 30), '');

      final days = await MoodScoreService(db).getUnscoredDays();
      expect(days, [DateTime(2026, 7, 29)]);
    });

    test('scoreDays 解析 JSON 并写入同一天所有条目', () async {
      final d28 = await createEntry(DateTime(2026, 7, 28), '开心的一天');
      final d29a = await createEntry(DateTime(2026, 7, 29), '早上焦虑');
      final d29b = await createEntry(DateTime(2026, 7, 29), '晚上放松了');
      final d30 = await createEntry(DateTime(2026, 7, 30), '一般般');

      final svc = MoodScoreService(db);
      final scored = await svc.scoreDays(
        _FakeLlmService(
          handler: (_) =>
              '{"2026-07-28": 3.5, "2026-07-29": -2, "2026-07-30": 1}',
        ),
        [DateTime(2026, 7, 28), DateTime(2026, 7, 29), DateTime(2026, 7, 30)],
      );

      expect(scored, 3);
      expect((await db.getEntryById(d28))!.moodScore, 3.5);
      expect((await db.getEntryById(d29a))!.moodScore, -2);
      expect((await db.getEntryById(d29b))!.moodScore, -2);
      expect((await db.getEntryById(d30))!.moodScore, 1);
    });

    test('scoreDays 输出带代码块标记时也能解析', () async {
      await createEntry(DateTime(2026, 7, 28), '还不错');
      final svc = MoodScoreService(db);
      final scored = await svc.scoreDays(
        _FakeLlmService(handler: (_) => '```json\n{"2026-07-28": 2}\n```'),
        [DateTime(2026, 7, 28)],
      );
      expect(scored, 1);
    });

    test('scoreDays 无法解析时返回失败且不写库', () async {
      final id = await createEntry(DateTime(2026, 7, 28), '还不错');
      final svc = MoodScoreService(db);
      final scored = await svc.scoreDays(
        _FakeLlmService(handler: (_) => '这不是 JSON'),
        [DateTime(2026, 7, 28)],
      );
      expect(scored, 0);
      expect((await db.getEntryById(id))!.moodScore, isNull);
    });

    test('dailyMoodCurve 同日多篇取均分，空日返回 null', () async {
      await createEntry(DateTime(2026, 7, 28), 'a', score: 2);
      await createEntry(DateTime(2026, 7, 28), 'b', score: 4);
      await createEntry(DateTime(2026, 7, 29), 'c', score: -3);
      await createEntry(DateTime(2026, 7, 30), 'd');

      final curve = await MoodScoreService(
        db,
      ).dailyMoodCurve(DateTime(2026, 7, 28), DateTime(2026, 7, 30));

      expect(curve.length, 3);
      expect(curve[0], (DateTime(2026, 7, 28), 3.0));
      expect(curve[1], (DateTime(2026, 7, 29), -3.0));
      expect(curve[2].$2, isNull);
    });

    test('clearMoodScore 将分数置空', () async {
      final id = await createEntry(DateTime(2026, 7, 28), 'a', score: 3);
      await db.clearMoodScore(id);
      expect((await db.getEntryById(id))!.moodScore, isNull);
    });
  });
}
