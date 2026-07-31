import 'package:lite_diary/database/database.dart';
import 'package:lite_diary/services/llm_service.dart';
import 'package:lite_diary/services/portrait_service.dart';
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
    return handler?.call(prompt) ?? '摘要';
  }
}

void main() {
  late AppDatabase db;
  late PortraitService svc;

  /// 上个月的一个日期（当前月不参与周期摘要）
  DateTime closedMonthDate() {
    final now = DateTime.now();
    return DateTime(now.year, now.month - 1, 10);
  }

  setUp(() {
    db = AppDatabase.forTesting();
    svc = PortraitService(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('周期划分', () {
    test('monthlyPeriods 返回当前月之前 12 个完整月份', () {
      final periods = svc.monthlyPeriods(DateTime(2026, 8, 15));
      expect(periods.length, 12);
      expect(periods.first.$2, DateTime(2026, 7, 1));
      expect(periods.first.$3, DateTime(2026, 8, 1));
      expect(periods.last.$2, DateTime(2025, 8, 1));
      expect(periods.last.$3, DateTime(2025, 9, 1));
    });

    test('quarterlyPeriods 覆盖一年至三年前，季度边界正确', () {
      final periods = svc.quarterlyPeriods(DateTime(2026, 8, 15));
      expect(periods.first.$2, DateTime(2023, 7, 1));
      expect(periods.first.$3, DateTime(2023, 10, 1));
      expect(periods.last.$2, DateTime(2025, 4, 1));
      expect(periods.last.$3, DateTime(2025, 7, 1));
      for (final p in periods) {
        expect(p.$3.difference(p.$2).inDays, inInclusiveRange(89, 92));
      }
    });

    test('yearlyPeriods 仅包含三年以前已结束的年份', () {
      final periods = svc.yearlyPeriods(DateTime(2026, 8, 15));
      expect(periods.first.$2, DateTime(2022, 1, 1));
      expect(periods.first.$3, DateTime(2023, 1, 1));
      expect(periods.last.$2, DateTime(1990, 1, 1));
    });

    test('periodsForDate 返回所在月/季/年三级周期', () {
      final periods = svc.periodsForDate(DateTime(2026, 5, 10));
      expect(periods.length, 3);
      expect(periods[0].$1, 'month');
      expect(periods[0].$2, DateTime(2026, 5, 1));
      expect(periods[1].$1, 'quarter');
      expect(periods[1].$2, DateTime(2026, 4, 1));
      expect(periods[2].$1, 'year');
      expect(periods[2].$2, DateTime(2026, 1, 1));
    });
  });

  group('周期摘要', () {
    test('ensurePeriodSummaries 只生成有内容的缺失周期', () async {
      await db.createEntry(
        EntriesCompanion(
          title: const Value('t'),
          date: Value(closedMonthDate()),
          content: const Value('七月的日记'),
          groupId: const Value(1),
        ),
      );

      final (generated, total) = await svc.ensurePeriodSummaries(
        _FakeLlmService(),
      );
      expect(generated, 1);
      expect(total, greaterThanOrEqualTo(12));

      final stored = await db.getAllPeriodSummaries();
      expect(stored.length, 1);
      expect(stored.first.periodType, '月');
      expect(
        stored.first.periodStart,
        DateTime(closedMonthDate().year, closedMonthDate().month, 1),
      );
    });

    test('ensurePeriodSummaries 重复执行不产生重复摘要', () async {
      await db.createEntry(
        EntriesCompanion(
          title: const Value('t'),
          date: Value(closedMonthDate()),
          content: const Value('内容'),
          groupId: const Value(1),
        ),
      );
      final fake = _FakeLlmService(handler: (_) => '七月摘要');
      await svc.ensurePeriodSummaries(fake);
      await svc.ensurePeriodSummaries(fake);

      final stored = await db.getAllPeriodSummaries();
      expect(stored.length, 1);
      expect(stored.first.summary, '七月摘要');
    });

    test('invalidateSummariesForDate 删除所在周期的摘要', () async {
      await db.createEntry(
        EntriesCompanion(
          title: const Value('t'),
          date: Value(closedMonthDate()),
          content: const Value('内容'),
          groupId: const Value(1),
        ),
      );
      await svc.ensurePeriodSummaries(_FakeLlmService());

      await svc.invalidateSummariesForDate(
        closedMonthDate().add(const Duration(days: 2)),
      );
      expect(await db.getAllPeriodSummaries(), isEmpty);
    });
  });

  group('长期画像', () {
    test('无摘要时返回 null', () async {
      final result = await svc.generateLongTermPortrait(_FakeLlmService());
      expect(result, isNull);
    });

    test('首次生成门槛：无已关闭月份日记时不允许', () async {
      final now = DateTime.now();
      final currentMonthStart = DateTime(now.year, now.month, 1);
      // 只写当前月的日记（当前月不参与周期摘要）
      await db.createEntry(
        EntriesCompanion(
          title: const Value('t'),
          date: Value(DateTime(now.year, now.month, 15)),
          content: const Value('内容'),
          groupId: const Value(1),
        ),
      );
      expect(await svc.canUpdateLongTermPortrait(), isFalse);
      expect(await svc.nextPortraitUpdateDate(), isNull);

      // 上个月有日记 → 允许
      await db.createEntry(
        EntriesCompanion(
          title: const Value('t2'),
          date: Value(currentMonthStart.subtract(const Duration(days: 1))),
          content: const Value('上月内容'),
          groupId: const Value(1),
        ),
      );
      expect(await svc.canUpdateLongTermPortrait(), isTrue);
      final next = await svc.nextPortraitUpdateDate();
      expect(next, isNotNull);
      expect(next!.isAfter(DateTime.now()), isFalse); // 现在即可更新
    });

    test('更新门槛：画像覆盖落后于当前月份起点时允许', () async {
      await db.upsertPortrait(
        PortraitsCompanion(
          kind: Value(PortraitService.longTermKind),
          content: const Value('旧画像'),
          periodStart: Value(DateTime(2026, 1, 1)),
          periodEnd: Value(DateTime(2026, 7, 1)),
        ),
      );
      // 画像覆盖终点（2026-07-01）早于当前月起点 → 每月 1 号起可更新
      expect(await svc.canUpdateLongTermPortrait(), isTrue);
      final next = await svc.nextPortraitUpdateDate();
      expect(next, DateTime(2026, 8, 1));
    });

    test('更新门槛：画像已覆盖到本月时不更新（新数据不足）', () async {
      final now = DateTime.now();
      final currentMonthStart = DateTime(now.year, now.month, 1);
      await db.upsertPortrait(
        PortraitsCompanion(
          kind: Value(PortraitService.longTermKind),
          content: const Value('新画像'),
          periodStart: Value(currentMonthStart.subtract(const Duration(days: 30))),
          periodEnd: Value(currentMonthStart),
        ),
      );
      expect(await svc.canUpdateLongTermPortrait(), isFalse);
      // 下次可更新日期 = 下月 1 号
      final next = await svc.nextPortraitUpdateDate();
      expect(next, DateTime(currentMonthStart.year, currentMonthStart.month + 1, 1));
    });

    test('有摘要时合成画像并入库，含 AI 简要版', () async {
      await db.createEntry(
        EntriesCompanion(
          title: const Value('t'),
          date: Value(closedMonthDate()),
          content: const Value('内容'),
          groupId: const Value(1),
        ),
      );
      await svc.ensurePeriodSummaries(_FakeLlmService(handler: (_) => '七月摘要'));

      final fake = _FakeLlmService(
        handler: (prompt) {
          expect(prompt, contains('七月摘要'));
          return '【核心特质】沉稳\n【身份与生活阶段】上班族\n【兴趣与关注】读书\n【关系与情感模式】友善\n【长期主题与变化轨迹】学生转职场\n【简要】一个沉稳的上班族';
        },
      );
      final result = await svc.generateLongTermPortrait(fake);
      expect(result, contains('核心特质'));
      expect(result, isNot(contains('简要')));

      final stored = await db.getPortrait(PortraitService.longTermKind);
      expect(stored, isNotNull);
      expect(stored!.content, contains('核心特质'));
      expect(stored.content, isNot(contains('简要')));
      expect(stored.summary, '一个沉稳的上班族');
    });

    test('无【简要】标记时摘要为空、内容完整保留', () async {
      await db.createEntry(
        EntriesCompanion(
          title: const Value('t'),
          date: Value(closedMonthDate()),
          content: const Value('内容'),
          groupId: const Value(1),
        ),
      );
      await svc.ensurePeriodSummaries(_FakeLlmService(handler: (_) => '七月摘要'));

      await svc.generateLongTermPortrait(
        _FakeLlmService(handler: (_) => '【核心特质】沉稳\n【身份与生活阶段】上班族'),
      );
      final stored = await db.getPortrait(PortraitService.longTermKind);
      expect(stored!.summary, isNull);
      expect(stored.content, contains('核心特质'));
    });
  });

  group('近期状态', () {
    test('首次更新基于近 7 天窗口生成，含 AI 简要版', () async {
      final today = DateTime.now();
      await db.createEntry(
        EntriesCompanion(
          title: const Value('t'),
          date: Value(today),
          content: const Value('今天的日记'),
          groupId: const Value(1),
        ),
      );
      final fake = _FakeLlmService(
        handler: (prompt) {
          expect(prompt, contains('近期状态'));
          return '最近状态不错\n【简要】状态不错';
        },
      );
      final result = await svc.updateRecentState(fake);
      expect(result.content, '最近状态不错');
      expect(result.updated, isTrue);

      final stored = await db.getPortrait(PortraitService.recentKind);
      expect(stored, isNotNull);
      expect(stored!.content, '最近状态不错');
      expect(stored.summary, '状态不错');
    });

    test('二次更新为增量：携带上次总结与新日记', () async {
      final today = DateTime.now();
      await db.createEntry(
        EntriesCompanion(
          title: const Value('t'),
          date: Value(today),
          content: const Value('内容'),
          groupId: const Value(1),
        ),
      );
      final fake = _FakeLlmService(handler: (_) => '状态一');
      await svc.updateRecentState(fake);

      // drift 的 DateTime 按秒存储，需等待 1 秒避免与上次生成时间相同
      await Future<void>.delayed(const Duration(seconds: 1));
      await db.createEntry(
        EntriesCompanion(
          title: const Value('t2'),
          date: Value(today),
          content: const Value('今天新增的内容'),
          groupId: const Value(1),
          createdAt: Value(DateTime.now()),
          updatedAt: Value(DateTime.now()),
        ),
      );

      final incremental = _FakeLlmService(
        handler: (prompt) {
          expect(prompt, contains('状态一'));
          expect(prompt, contains('上次近期状态总结'));
          return '状态二';
        },
      );
      final result = await svc.updateRecentState(incremental);
      expect(result.content, '状态二');
      expect(result.updated, isTrue);
    });

    test('无新增日记时返回上次结果且不重复调用', () async {
      final today = DateTime.now();
      await db.createEntry(
        EntriesCompanion(
          title: const Value('t'),
          date: Value(today),
          content: const Value('内容'),
          groupId: const Value(1),
        ),
      );
      final fake = _FakeLlmService(handler: (_) => '状态一');
      await svc.updateRecentState(fake);

      var called = false;
      final result = await svc.updateRecentState(
        _FakeLlmService(
          handler: (p) {
            called = true;
            return '不应该调用';
          },
        ),
      );
      expect(result.content, '状态一');
      expect(result.updated, isFalse);
      expect(called, isFalse);
    });
  });

  group('注入文本', () {
    test('无画像时返回 null', () async {
      expect(await svc.buildInjectionText(), isNull);
    });

    test('有画像时返回带标记的文本', () async {
      await db.upsertPortrait(
        PortraitsCompanion(
          kind: Value(PortraitService.longTermKind),
          content: const Value('长期内容'),
        ),
      );
      await db.upsertPortrait(
        PortraitsCompanion(
          kind: Value(PortraitService.recentKind),
          content: const Value('近期内容'),
        ),
      );
      final text = await svc.buildInjectionText();
      expect(text, contains('长期内容'));
      expect(text, contains('近期内容'));
    });
  });
}
