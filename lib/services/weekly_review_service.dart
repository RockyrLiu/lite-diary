import 'package:drift/drift.dart';

import '../database/database.dart';
import 'llm_context.dart';
import 'llm_service.dart';

class ReviewService {
  final AppDatabase _db;

  ReviewService(this._db);

  static const weekKind = 'week';
  static const monthKind = 'month';
  static const yearKind = 'year';

  static int daysOf(String kind) => switch (kind) {
        monthKind => 30,
        yearKind => 365,
        _ => 7,
      };

  /// 生成回顾报告并入库，返回生成的记录。
  Future<Review> generate(LlmService svc, {String kind = weekKind}) async {
    final now = DateTime.now();
    final end = startOfDay(now);
    final start = end.subtract(Duration(days: daysOf(kind) - 1));

    final entries = await _db.getEntriesInRange(
      start,
      end.add(const Duration(days: 1)),
    );
    entries.removeWhere((e) => e.content.isEmpty);

    final content = entries.isEmpty ? '' : formatEntriesForLlm(entries);
    final range = formatDateRangeLabel(start, end);
    final title = switch (kind) {
      monthKind => '月度',
      yearKind => '年度',
      _ => '周度',
    };
    final prompt = entries.isEmpty
        ? '过去${daysOf(kind)}天（$range）没有任何日记记录。请直接说明这一段时间没有可回顾的内容，并给出简单鼓励。'
        : '''
请根据用户过去${daysOf(kind)}天（$range）的日记内容，生成$title回顾报告，包含：
1. 这段时间的主要事件
2. 情绪变化
3. 收获与反思
4. 对下一段时间的小小建议
语言温暖、有洞察力，直接输出正文，不要任何其他内容。

日记内容：
$content''';

    final report = (await svc.sendMessage(
      messages: [
        {'role': 'user', 'content': prompt},
      ],
    )).trim();

    final id = await _db.createReview(
      ReviewsCompanion(
        kind: Value(kind),
        periodStart: Value(start),
        periodEnd: Value(end),
        content: Value(report),
        generatedAt: Value(DateTime.now()),
      ),
    );
    final saved = await _db.getAllReviews(kind: kind);
    return saved.firstWhere((r) => r.id == id);
  }
}
