import 'package:drift/drift.dart';

import '../database/database.dart';
import 'llm_context.dart';
import 'llm_service.dart';
import 'portrait_service.dart';

class SuggestionService {
  final AppDatabase _db;

  SuggestionService(this._db);

  static const suggestionKind = 'suggestion';

  /// 基于近 7 天内容生成生活建议（≤300 字）并入库。近 7 天无日记时回退到画像上下文。
  Future<String> generate(LlmService svc) async {
    final now = DateTime.now();
    final end = startOfDay(now);
    final start = end.subtract(const Duration(days: 6));
    final range = formatDateRangeLabel(start, end);

    final entries = await _db.getEntriesInRange(
      start,
      end.add(const Duration(days: 1)),
    );
    entries.removeWhere((e) => e.content.isEmpty);

    final String prompt;
    if (entries.isNotEmpty) {
      final content = formatEntriesForLlm(entries);
      prompt =
          '''
你是用户的 AI 生活顾问。请根据用户近 7 天（$range）的日记内容，给出 3~5 条实用、具体的建议。
建议不限于情绪，可涵盖：工作学习、生活习惯、健康作息、人际关系、心态调整等。
要求：内容尽量简练，总字数控制在 300 字以内，按编号列表输出，每条一行，不要任何开场白或总结。

日记内容：
$content''';
    } else {
      final portrait = await PortraitService(_db).buildInjectionText();
      prompt =
          '''
近 7 天（$range）用户没有写日记。${portrait != null ? '以下是你对用户的了解：\n$portrait\n' : ''}
请给出 3 条通用、可执行的日常自我提升建议。要求：内容尽量简练，总字数控制在 300 字以内，按编号列表输出，每条一行。''';
    }

    final result = (await svc.sendMessage(
      messages: [
        {'role': 'user', 'content': prompt},
      ],
    )).trim();
    final content = result.length > 400 ? '${result.substring(0, 400)}...' : result;

    await _db.createReview(ReviewsCompanion(
      kind: Value(suggestionKind),
      periodStart: Value(start),
      periodEnd: Value(end),
      content: Value(content),
      generatedAt: Value(DateTime.now()),
    ));
    return content;
  }
}
