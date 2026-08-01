import 'package:drift/drift.dart';

import '../database/database.dart';
import 'llm_context.dart';
import 'llm_service.dart';
import 'portrait_service.dart';

class SuggestionService {
  final AppDatabase _db;

  SuggestionService(this._db);

  static const suggestionKind = 'suggestion';

  /// 基于近 7 天内容生成生活建议（≤300 字）并入库。近 7 天无文本时回退到画像上下文。
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

    final fictionNote =
        '注意：各则材料已标注所属分组。小说、剧本等明显虚构的创作不代表用户本人的真实经历，应视为创作风格与兴趣的参考；而诗词、随笔等往往与真实生活、情绪密切相关，可纳入分析。请结合内容性质自行判断其参考价值。';

    final String prompt;
    if (entries.isNotEmpty) {
      final groups = await _db.getAllGroups();
      final groupNames = {for (final g in groups) g.id: g.name};
      final content = formatEntriesForLlm(entries, groupNames: groupNames);
      prompt =
          '''
你是用户的 AI 生活顾问。请根据用户近 7 天（$range）的日记和文本内容，给出 3~5 条实用、具体的建议。
建议不限于情绪，可涵盖：工作学习、生活习惯、健康作息、人际关系、心态调整等。
$fictionNote
要求：内容尽量简练，总字数控制在 300 字以内，按编号列表输出，每条一行，不要任何开场白或总结。

日记和文本内容：
$content''';
    } else {
      final portrait = await PortraitService(_db).buildInjectionText();
      prompt =
          '''
近 7 天（$range）用户没有新的文本记录。${portrait != null ? '以下是你对用户的了解：\n$portrait\n' : ''}
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
