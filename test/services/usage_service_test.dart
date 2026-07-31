import 'package:lite_diary/database/database.dart';
import 'package:lite_diary/services/llm_service.dart';
import 'package:lite_diary/services/usage_service.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting();
  });

  tearDown(() async {
    await db.close();
  });

  group('LlmUsage.build', () {
    test('解析 API 返回的 usage（含缓存明细）', () {
      final usage = LlmUsage.build({
        'prompt_tokens': 100,
        'prompt_cache_hit_tokens': 60,
        'prompt_cache_miss_tokens': 40,
        'completion_tokens': 50,
      }, model: 'm');
      expect(usage.promptTokens, 100);
      expect(usage.promptCacheHitTokens, 60);
      expect(usage.promptCacheMissTokens, 40);
      expect(usage.completionTokens, 50);
      expect(usage.totalTokens, 150);
      expect(usage.estimated, isFalse);
    });

    test('无缓存明细时按全部未命中处理', () {
      final usage = LlmUsage.build({
        'prompt_tokens': 100,
        'completion_tokens': 50,
      }, model: 'm');
      expect(usage.promptCacheHitTokens, 0);
      expect(usage.promptCacheMissTokens, 100);
    });

    test('usage 缺失时按字符长度估算', () {
      final usage = LlmUsage.build(
        null,
        model: 'm',
        estimatedPrompt: 400,
        estimatedCompletion: 80,
      );
      expect(usage.promptTokens, 100);
      expect(usage.completionTokens, 20);
      expect(usage.promptCacheMissTokens, 100);
      expect(usage.estimated, isTrue);
    });

    test('usage 部分缺失时补估算', () {
      final usage = LlmUsage.build(
        {'prompt_tokens': 10},
        model: 'm',
        estimatedPrompt: 40,
        estimatedCompletion: 100,
      );
      expect(usage.promptTokens, 10);
      expect(usage.completionTokens, 25);
    });
  });

  group('UsageService', () {
    Future<void> record(
      String model,
      int prompt,
      int completion,
      DateTime time, {
      int? hit,
    }) {
      final miss = prompt - (hit ?? 0);
      return db.recordUsage(
        UsageLogsCompanion(
          model: Value(model),
          promptTokens: Value(prompt),
          promptCacheHitTokens: Value(hit ?? 0),
          promptCacheMissTokens: Value(miss),
          completionTokens: Value(completion),
          createdAt: Value(time),
        ),
      );
    }

    test('summary 汇总 token 与请求数，按范围过滤', () async {
      final today = DateTime(2026, 7, 31, 12);
      await record('deepseek-v4-flash', 100, 50, today);
      await record(
        'deepseek-v4-flash',
        200,
        100,
        today.subtract(const Duration(days: 5)),
      );
      await record(
        'deepseek-v4-flash',
        300,
        150,
        today.subtract(const Duration(days: 40)),
      );

      final total = await UsageService(db).summary();
      expect(total.count, 3);
      expect(total.promptTokens, 600);
      expect(total.completionTokens, 300);
      expect(total.totalTokens, 900);

      final week = await UsageService(
        db,
      ).summary(from: today.subtract(const Duration(days: 6)));
      expect(week.count, 2);
      expect(week.totalTokens, 450);
    });

    test('summary 费用按缓存命中/未命中与输出分别计价', () async {
      await record(
        'deepseek-v4-flash',
        1_000_000,
        1_000_000,
        DateTime(2026, 7, 31, 12),
        hit: 500_000,
      );
      final s = await UsageService(db).summary();
      // 0.5M 命中 * 0.02 + 0.5M 未命中 * 1.0 + 1M 输出 * 2.0
      expect(s.cost, closeTo(2.51, 0.0001));
    });

    test('dailyUsage 按天聚合，空日返回 0', () async {
      final today = DateTime(2026, 7, 31, 12);
      await record('m', 100, 0, today);
      await record('m', 50, 0, today);
      await record('m', 200, 0, today.subtract(const Duration(days: 1)));

      final daily = await UsageService(
        db,
      ).dailyUsage(today.subtract(const Duration(days: 2)), today);
      expect(daily.length, 3);
      expect(daily[2].$2, 150);
      expect(daily[1].$2, 200);
      expect(daily[0].$2, 0);
    });

    test('modelBreakdown 按模型分组并估算费用', () async {
      await record('deepseek-v4-flash', 1_000_000, 0, DateTime(2026, 7, 31, 12));
      await record(
        'deepseek-v4-pro',
        1_000_000,
        0,
        DateTime(2026, 7, 31, 12),
      );

      final breakdown = await UsageService(db).modelBreakdown();
      expect(breakdown.length, 2);
      final flash = breakdown.firstWhere((m) => m.$1 == 'deepseek-v4-flash');
      expect(flash.$2, 1_000_000);
      expect(flash.$4, closeTo(1.0, 0.0001));
    });

    test('savePrice 覆盖后费用按新单价计算', () async {
      await record('deepseek-v4-flash', 1_000_000, 0, DateTime(2026, 7, 31, 12));
      await UsageService.savePrice('deepseek-v4-flash', 0.5, 0.1, 2.0);

      final s = await UsageService(db).summary();
      expect(s.cost, closeTo(0.5, 0.0001));
    });
  });
}
