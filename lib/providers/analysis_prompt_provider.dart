import 'package:lite_diary/database/database.dart';
import 'package:lite_diary/providers/database_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'analysis_prompt_provider.g.dart';

@riverpod
Future<List<AnalysisPrompt>> allAnalysisPrompts(AllAnalysisPromptsRef ref) {
  return ref.watch(databaseProvider).getAllAnalysisPrompts();
}
