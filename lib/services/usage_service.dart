import 'package:shared_preferences/shared_preferences.dart';

import '../database/database.dart';
import 'llm_context.dart';

class UsageSummary {
  final int promptTokens;
  final int completionTokens;
  final int count;
  final double cost;

  const UsageSummary({
    required this.promptTokens,
    required this.completionTokens,
    required this.count,
    required this.cost,
  });

  int get totalTokens => promptTokens + completionTokens;
}

class UsageService {
  final AppDatabase _db;

  UsageService(this._db);

  /// 每百万 token 的价格（元/CNY）：(输入·缓存未命中, 输入·缓存命中, 输出)。
  /// 未收录的模型给一个保守默认值。
  static const defaultPrices = <String, (double, double, double)>{
    'deepseek-v4-flash': (1.0, 0.02, 2.0),
    'deepseek-v4-pro': (3.0, 0.025, 6.0),
  };

  static const _priceInKey = 'usage_price_in_';
  static const _priceHitKey = 'usage_price_in_hit_';
  static const _priceOutKey = 'usage_price_out_';

  static Future<(double, double, double)> loadPrice(String model) async {
    final prefs = await SharedPreferences.getInstance();
    final base = defaultPrices[model] ?? (0.5, 0.1, 1.5);
    final miss = prefs.getDouble('$_priceInKey$model') ?? base.$1;
    final hit = prefs.getDouble('$_priceHitKey$model') ?? base.$2;
    final out = prefs.getDouble('$_priceOutKey$model') ?? base.$3;
    return (miss, hit, out);
  }

  static Future<void> savePrice(String model, double inMiss, double inHit, double out) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('$_priceInKey$model', inMiss);
    await prefs.setDouble('$_priceHitKey$model', inHit);
    await prefs.setDouble('$_priceOutKey$model', out);
  }

  Future<UsageSummary> summary({DateTime? from}) async {
    final logs = from == null
        ? await _db.getAllUsageLogs()
        : await _db.getUsageLogs(from, DateTime.now().add(const Duration(days: 1)));
    return _summarize(logs);
  }

  Future<UsageSummary> _summarize(List<UsageLog> logs) async {
    var prompt = 0;
    var completion = 0;
    final byModel = <String, (int, int, int)>{};
    for (final log in logs) {
      prompt += log.promptTokens;
      completion += log.completionTokens;
      final cur = byModel[log.model] ?? (0, 0, 0);
      byModel[log.model] = (
        cur.$1 + log.promptCacheHitTokens,
        cur.$2 + log.promptCacheMissTokens,
        cur.$3 + log.completionTokens,
      );
    }
    var cost = 0.0;
    for (final entry in byModel.entries) {
      final (inMiss, inHit, out) = await loadPrice(entry.key);
      cost += entry.value.$1 / 1e6 * inHit +
          entry.value.$2 / 1e6 * inMiss +
          entry.value.$3 / 1e6 * out;
    }
    return UsageSummary(
      promptTokens: prompt,
      completionTokens: completion,
      count: logs.length,
      cost: cost,
    );
  }

  /// 按天聚合 token 用量（含起止日），无日志的天返回 0。
  Future<List<(DateTime, int)>> dailyUsage(DateTime start, DateTime end) async {
    final logs = await _db.getUsageLogs(start, end.add(const Duration(days: 1)));
    final byDay = <DateTime, int>{};
    for (final log in logs) {
      final day = startOfDay(log.createdAt);
      byDay[day] = (byDay[day] ?? 0) + log.promptTokens + log.completionTokens;
    }
    final result = <(DateTime, int)>[];
    var d = startOfDay(start);
    final last = startOfDay(end);
    while (!d.isAfter(last)) {
      result.add((d, byDay[d] ?? 0));
      d = d.add(const Duration(days: 1));
    }
    return result;
  }

  /// 各模型用量明细与估算费用。
  Future<List<(String, int, int, double)>> modelBreakdown() async {
    final logs = await _db.getAllUsageLogs();
    final byModel = <String, (int, int, int)>{};
    for (final log in logs) {
      final cur = byModel[log.model] ?? (0, 0, 0);
      byModel[log.model] = (
        cur.$1 + log.promptCacheHitTokens,
        cur.$2 + log.promptCacheMissTokens,
        cur.$3 + log.completionTokens,
      );
    }
    final result = <(String, int, int, double)>[];
    for (final entry in byModel.entries) {
      final (inMiss, inHit, out) = await loadPrice(entry.key);
      final cost = entry.value.$1 / 1e6 * inHit +
          entry.value.$2 / 1e6 * inMiss +
          entry.value.$3 / 1e6 * out;
      result.add((
        entry.key,
        entry.value.$1 + entry.value.$2,
        entry.value.$3,
        cost,
      ));
    }
    result.sort((a, b) => b.$2 + b.$3 - (a.$2 + a.$3));
    return result;
  }
}
