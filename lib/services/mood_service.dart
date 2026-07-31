import 'dart:convert';

import '../database/database.dart';
import 'llm_context.dart';
import 'llm_service.dart';

class MoodScoreService {
  final AppDatabase _db;

  MoodScoreService(this._db);

  /// 找出缺少打分的日期（按天分组，取当天有内容的条目）。
  Future<List<DateTime>> getUnscoredDays() async {
    final entries = await _db.getEntriesNeedingMoodScore();
    final days = <DateTime>{};
    for (final e in entries) {
      days.add(startOfDay(e.date));
    }
    final sorted = days.toList()..sort();
    return sorted;
  }

  /// 对 [days] 按天批量打分（每批 [batchSize] 天），返回成功打分的天数。
  /// [onProgress] 回调已处理批数/总批数。
  Future<int> scoreDays(
    LlmService svc,
    List<DateTime> days, {
    int batchSize = 10,
    void Function(int done, int total)? onProgress,
  }) async {
    if (days.isEmpty) return 0;
    var scored = 0;
    final totalBatches = (days.length + batchSize - 1) ~/ batchSize;
    var done = 0;
    for (var i = 0; i < days.length; i += batchSize) {
      final batch = days.sublist(
        i,
        i + batchSize > days.length ? days.length : i + batchSize,
      );
      final ok = await _scoreBatch(svc, batch);
      if (ok) {
        scored += batch.length;
      }
      done++;
      onProgress?.call(done, totalBatches);
    }
    return scored;
  }

  Future<bool> _scoreBatch(LlmService svc, List<DateTime> days) async {
    final entries = await _db.getEntriesInRange(
      days.first,
      days.last.add(const Duration(days: 1)),
    );
    if (entries.isEmpty) return false;

    final buffer = StringBuffer();
    for (final d in days) {
      final dayEntries = entries.where((e) => startOfDay(e.date) == d).toList();
      if (dayEntries.isEmpty) continue;
      buffer.writeln(
        '=== ${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')} ===',
      );
      for (final e in dayEntries) {
        if (e.title != null && e.title!.isNotEmpty) {
          buffer.writeln('标题: ${e.title}');
        }
        buffer.writeln(e.content);
        buffer.writeln();
      }
    }

    final prompt = '''
你是情绪分析助手。请根据下面每天的用户日记内容，为每一天的情绪状态打分。
评分范围：-5（极度低落）到 +5（极度高涨），0 为中性。
只输出一个 JSON 对象，键为日期（YYYY-MM-DD），值为数字，不要输出任何其他内容。

日记内容：
$buffer''';

    final response = await svc.sendMessage(
      messages: [
        {'role': 'user', 'content': prompt},
      ],
    );
    final scores = _parseScores(response);
    if (scores.isEmpty) return false;

    for (final d in days) {
      final key =
          '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      final score = scores[key];
      if (score == null) continue;
      final dayEntries = await _db.getEntriesByDate(d);
      for (final e in dayEntries) {
        await _db.setMoodScore(e.id, score.clamp(-5.0, 5.0));
      }
    }
    return true;
  }

  Map<String, double> _parseScores(String raw) {
    final cleaned = raw.trim().replaceAll(
      RegExp(r'^```(json)?\s*|\s*```$'),
      '',
    );
    try {
      final decoded = jsonDecode(cleaned);
      if (decoded is Map<String, dynamic>) {
        return decoded.map((k, v) {
          final n = v is num ? v.toDouble() : double.tryParse('$v');
          return MapEntry(k, n ?? 0);
        });
      }
    } catch (_) {}
    final result = <String, double>{};
    final re = RegExp(r'"(\d{4}-\d{2}-\d{2})"\s*:\s*(-?\d+(?:\.\d+)?)');
    for (final m in re.allMatches(cleaned)) {
      result[m.group(1)!] = double.parse(m.group(2)!);
    }
    return result;
  }

  /// 按天聚合情绪得分：返回日期与均分；无数据的日期返回 null。
  Future<List<(DateTime, double?)>> dailyMoodCurve(
    DateTime start,
    DateTime end,
  ) async {
    final entries = await _db.getEntriesInRange(
      start,
      end.add(const Duration(days: 1)),
    );
    final byDay = <DateTime, List<double>>{};
    for (final e in entries) {
      final s = e.moodScore;
      if (s == null) continue;
      byDay.putIfAbsent(startOfDay(e.date), () => []).add(s);
    }
    final result = <(DateTime, double?)>[];
    var d = startOfDay(start);
    final last = startOfDay(end);
    while (!d.isAfter(last)) {
      final scores = byDay[d];
      result.add((
        d,
        scores == null || scores.isEmpty
            ? null
            : scores.reduce((a, b) => a + b) / scores.length,
      ));
      d = d.add(const Duration(days: 1));
    }
    return result;
  }
}
