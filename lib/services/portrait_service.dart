import 'package:drift/drift.dart';

import '../database/database.dart';
import 'llm_context.dart';
import 'llm_service.dart';

class PortraitService {
  final AppDatabase _db;

  PortraitService(this._db);

  static const longTermKind = 'long_term';
  static const recentKind = 'recent';

  static const int recentWindowDays = 7;

  /// 在生成内容末尾提取"【简要】"开头的 AI 摘要，返回 (正文, 摘要)。
  (String, String?) _splitSummary(String text) {
    final marker = RegExp(r'【简要】\s*');
    final match = marker.firstMatch(text);
    if (match == null) return (text.trim(), null);
    final summary = text.substring(match.end).trim();
    final content = text.substring(0, match.start).trim();
    return (content, summary.isEmpty ? null : summary);
  }

  // ========== 周期划分 ==========

  DateTime _addMonths(DateTime d, int n) => DateTime(d.year, d.month + n, 1);

  DateTime _quarterStart(DateTime d) =>
      DateTime(d.year, ((d.month - 1) ~/ 3) * 3 + 1, 1);

  /// 近一年：已关闭的 12 个月周期（当前月之前的完整月份）。
  List<(String, DateTime, DateTime)> monthlyPeriods(DateTime now) {
    final current = DateTime(now.year, now.month, 1);
    final result = <(String, DateTime, DateTime)>[];
    for (var i = 1; i <= 12; i++) {
      final start = _addMonths(current, -i);
      final end = _addMonths(current, -i + 1);
      result.add(('month', start, end));
    }
    return result;
  }

  /// 一年至三年前：已关闭的季度周期。
  List<(String, DateTime, DateTime)> quarterlyPeriods(DateTime now) {
    final current = DateTime(now.year, now.month, 1);
    final boundary12 = _addMonths(current, -12);
    final boundary36 = _addMonths(current, -36);
    final result = <(String, DateTime, DateTime)>[];
    var q = _quarterStart(boundary36);
    while (q.isBefore(boundary12)) {
      final end = _addMonths(q, 3);
      if (!end.isAfter(boundary12)) {
        result.add(('quarter', q, end));
      } else {
        break;
      }
      q = _addMonths(q, 3);
    }
    return result;
  }

  /// 三年以前：已关闭的年度周期。
  List<(String, DateTime, DateTime)> yearlyPeriods(DateTime now) {
    final current = DateTime(now.year, now.month, 1);
    final boundary36 = _addMonths(current, -36);
    final result = <(String, DateTime, DateTime)>[];
    for (var y = boundary36.year - 1; y >= 1990; y--) {
      final start = DateTime(y, 1, 1);
      final end = DateTime(y + 1, 1, 1);
      if (!end.isAfter(boundary36)) {
        result.add(('year', start, end));
      } else {
        break;
      }
    }
    return result;
  }

  /// 日期所在的三级周期（用于编辑失效）。
  List<(String, DateTime, DateTime)> periodsForDate(DateTime date) {
    final d = startOfDay(date);
    final monthStart = DateTime(d.year, d.month, 1);
    return [
      ('month', monthStart, DateTime(d.year, d.month + 1, 1)),
      ('quarter', _quarterStart(d), _addMonths(_quarterStart(d), 3)),
      ('year', DateTime(d.year, 1, 1), DateTime(d.year + 1, 1, 1)),
    ];
  }

  // ========== 周期摘要 ==========

  /// 补齐所有缺失的周期摘要，返回 (生成数, 总周期数)。
  Future<(int, int)> ensurePeriodSummaries(
    LlmService svc, {
    void Function(int done, int total)? onProgress,
  }) async {
    final now = DateTime.now();
    final periods = [
      ...yearlyPeriods(now),
      ...quarterlyPeriods(now),
      ...monthlyPeriods(now),
    ];
    final missing = <(String, DateTime, DateTime)>[];
    for (final (type, start, end) in periods) {
      final existing = await _db.getPeriodSummary(start, end);
      if (existing == null) {
        final entries = await _db.getEntriesInRange(start, end);
        if (entries.isNotEmpty) missing.add((type, start, end));
      }
    }
    var done = 0;
    for (final (type, start, end) in missing) {
      await _generatePeriodSummary(svc, type, start, end);
      done++;
      onProgress?.call(done, missing.length);
    }
    return (done, periods.length);
  }

  Future<void> _generatePeriodSummary(
    LlmService svc,
    String type,
    DateTime start,
    DateTime end,
  ) async {
    final entries = await _db.getEntriesInRange(start, end);
    if (entries.isEmpty) return;
    final groups = await _db.getAllGroups();
    final groupNames = {for (final g in groups) g.id: g.name};
    final content = formatEntriesForLlm(entries, groupNames: groupNames);
    final typeName = switch (type) {
      'year' => '年',
      'quarter' => '季度',
      _ => '月',
    };
    final label = _periodLabel(type, start, end);
    final prompt =
        '''
你是一位日记和文本分析助手。以下是用户$label期间的日记和文本摘录。
请提炼这一时期的关键信息，形成一份简洁的分期摘要（200-400字），内容包括：主要生活事件、情绪基调、关注的事物、重要的变化或习惯。
注意：各则材料已标注所属分组。小说、剧本等明显虚构的创作不代表用户本人的真实经历，应视为创作风格与兴趣的参考；而诗词、随笔等往往与真实生活、情绪密切相关，可纳入分析。请结合内容性质自行判断其参考价值。
直接输出摘要正文，不要任何其他内容。

日记和文本内容：
$content''';
    final summary = (await svc.sendMessage(
      messages: [
        {'role': 'user', 'content': prompt},
      ],
    )).trim();
    if (summary.isEmpty) return;
    await _db.upsertPeriodSummary(
      PeriodSummariesCompanion(
        periodType: Value(typeName),
        periodStart: Value(start),
        periodEnd: Value(end),
        summary: Value(summary),
      ),
    );
  }

  String _periodLabel(String type, DateTime start, DateTime end) {
    final s = start;
    if (type == 'year') return '${s.year} 年';
    if (type == 'quarter') {
      final q = ((s.month - 1) ~/ 3) + 1;
      return '${s.year} 年第 $q 季度';
    }
    return '${s.year} 年 ${s.month} 月';
  }

  /// 编辑旧条目时作废其所属周期摘要。
  Future<void> invalidateSummariesForDate(DateTime date) async {
    for (final (_, start, end) in periodsForDate(date)) {
      await _db.deletePeriodSummary(start, end);
    }
  }

  // ========== 长期画像 ==========

  /// 下次可更新长期画像的日期；null 表示尚无完整自然月数据。
  /// 规则：每月 1 号起最多更新一次，数据始终为自然月（上月及更早）。
  /// 首次：有任意一个已关闭自然月的日记即可生成。
  Future<DateTime?> nextPortraitUpdateDate() async {
    final portrait = await _db.getPortrait(longTermKind);
    if (portrait != null && portrait.periodEnd != null) {
      // 画像已覆盖到 periodEnd 之前的一个月，下次更新需等到下一个月 1 号
      return DateTime(
        portrait.periodEnd!.year,
        portrait.periodEnd!.month + 1,
        1,
      );
    }
    final now = DateTime.now();
    for (final (_, start, end) in monthlyPeriods(now)) {
      final entries = await _db.getEntriesInRange(start, end);
      if (entries.isNotEmpty) return startOfDay(now);
    }
    return null;
  }

  Future<bool> canUpdateLongTermPortrait() async {
    final next = await nextPortraitUpdateDate();
    if (next == null) return false;
    return !next.isAfter(DateTime.now());
  }

  /// 综合所有周期摘要生成长期画像；无摘要时返回 null。
  Future<String?> generateLongTermPortrait(LlmService svc) async {
    final summaries = await _db.getAllPeriodSummaries();
    if (summaries.isEmpty) return null;

    final buffer = StringBuffer();
    for (final p in summaries.reversed) {
      buffer.writeln(
        '【${_periodLabel(p.periodType, p.periodStart, p.periodEnd)}】',
      );
      buffer.writeln(p.summary);
      buffer.writeln();
    }
    final prompt = '''
以下是用户不同时期的日记和文本分期摘要（时间越近的摘要越详细）。
请综合生成用户的"长期个人画像"，要求：
1. 身份、职业、生活阶段以最近的摘要为准；早期摘要中的过时身份（如学生身份）只能作为人生轨迹的一部分，不能当作当前状态
2. 提炼稳定特质：性格、价值观、兴趣、关系模式、长期主题
3. 按以下小节输出（每个小节以【】标题开头）：【核心特质】【身份与生活阶段】【兴趣与关注】【关系与情感模式】【长期主题与变化轨迹】
4. 语言简洁、有洞察力，直接输出正文
5. 在正文最后另起一行输出"【简要】"开头的简要版画像（一句话，不超过 200 字，用于首页概览展示）
注意：摘要中的虚构创作（如小说、剧本）不代表用户本人的真实经历，仅作创作风格参考；诗词、随笔等可纳入对用户的真实分析。

分期摘要：
$buffer''';
    final portrait = (await svc.sendMessage(
      messages: [
        {'role': 'user', 'content': prompt},
      ],
    )).trim();
    if (portrait.isEmpty) return null;

    final (content, summary) = _splitSummary(portrait);
    final oldest = summaries.last.periodStart;
    final newest = summaries.first.periodEnd;
    await _db.upsertPortrait(
      PortraitsCompanion(
        kind: Value(longTermKind),
        content: Value(content),
        summary: Value(summary),
        periodStart: Value(oldest),
        periodEnd: Value(newest),
        generatedAt: Value(DateTime.now()),
      ),
    );
    return content;
  }

  // ========== 近期状态 ==========

  /// 增量更新近期状态（近 7 天窗口，按 7 天为单位增量合并）。
  /// 返回 (内容, 是否实际调用并更新)；无新增日记时不调用 API，仅返回上次内容。
  Future<({String? content, bool updated})> updateRecentState(
    LlmService svc,
  ) async {
    final now = DateTime.now();
    final windowStart = startOfDay(
      now,
    ).subtract(const Duration(days: recentWindowDays - 1));
    final windowEnd = startOfDay(now);

    final prev = await _db.getPortrait(recentKind);
    final windowEntries = await _db.getEntriesInRange(
      windowStart,
      windowEnd.add(const Duration(days: 1)),
    );
    var newEntries = windowEntries.where((e) => e.content.isNotEmpty).toList();
    if (prev != null && prev.content.isNotEmpty) {
      newEntries = newEntries
          .where(
            (e) =>
                e.createdAt.isAfter(prev.generatedAt) ||
                e.updatedAt.isAfter(prev.generatedAt),
          )
          .toList();
    }

    if (newEntries.isEmpty) {
      return (content: prev?.content, updated: false);
    }

    final groups = await _db.getAllGroups();
    final groupNames = {for (final g in groups) g.id: g.name};
    const fictionNote =
        '注意：各则材料已标注所属分组。小说、剧本等明显虚构的创作不代表用户本人的真实经历，应视为创作风格与兴趣的参考；而诗词、随笔等往往与真实生活、情绪密切相关，可纳入分析。请结合内容性质自行判断其参考价值。';

    final String recent;
    if (prev != null && prev.content.isNotEmpty) {
      final content = formatEntriesForLlm(newEntries, groupNames: groupNames);
      final since = formatDateRangeLabel(prev.periodEnd!, windowEnd);
      final prompt =
          '''
这是 AI 之前对用户近期状态（近 7 天）的总结，以及自上次总结以来（$since）新增的日记和文本内容。
请综合两者生成更新后的近期状态总结（300-500字）：保持仍然成立的观察，更新已变化的部分，删除已过时的内容。
覆盖：当前生活状态、情绪基调、近期关注焦点、困扰或压力源、近期目标、人际关系动态。
$fictionNote
直接输出正文，并在正文最后另起一行输出"【简要】"开头的简要版（不超过 200 字，用于首页概览展示）。

上次近期状态总结：
${prev.content}

新增日记和文本内容：
$content''';
      recent = (await svc.sendMessage(
        messages: [
          {'role': 'user', 'content': prompt},
        ],
      )).trim();
    } else {
      final content = formatEntriesForLlm(newEntries, groupNames: groupNames);
      final range = formatDateRangeLabel(windowStart, windowEnd);
      final prompt =
          '''
以下是用户最近 $recentWindowDays 天（$range）的日记和文本内容。
请分析并生成用户的"近期状态"总结（300-500字），覆盖：当前生活状态、情绪基调、近期关注焦点、困扰或压力源、近期目标、人际关系动态。
$fictionNote
直接输出正文，并在正文最后另起一行输出"【简要】"开头的简要版（不超过 200 字，用于首页概览展示）。

日记和文本内容：
$content''';
      recent = (await svc.sendMessage(
        messages: [
          {'role': 'user', 'content': prompt},
        ],
      )).trim();
    }
    if (recent.isEmpty) return (content: prev?.content, updated: false);

    final (content, summary) = _splitSummary(recent);
    await _db.upsertPortrait(
      PortraitsCompanion(
        kind: Value(recentKind),
        content: Value(content),
        summary: Value(summary),
        periodStart: Value(windowStart),
        periodEnd: Value(windowEnd),
        generatedAt: Value(DateTime.now()),
      ),
    );
    return (content: content, updated: true);
  }

  // ========== 注入文本 ==========

  /// 构造对话注入的画像上下文；无画像时返回 null。
  Future<String?> buildInjectionText() async {
    final longTerm = await _db.getPortrait(longTermKind);
    final recent = await _db.getPortrait(recentKind);
    if ((longTerm == null || longTerm.content.isEmpty) &&
        (recent == null || recent.content.isEmpty)) {
      return null;
    }
    final buffer = StringBuffer();
    if (longTerm != null && longTerm.content.isNotEmpty) {
      buffer.writeln('【对用户的长期理解】');
      buffer.writeln(longTerm.content);
      buffer.writeln();
    }
    if (recent != null && recent.content.isNotEmpty) {
      buffer.writeln('【用户的近期状态（近 7 天）】');
      buffer.writeln(recent.content);
    }
    return buffer.toString().trim();
  }
}
