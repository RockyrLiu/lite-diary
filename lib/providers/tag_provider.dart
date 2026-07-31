import 'package:lite_diary/database/database.dart';
import 'package:lite_diary/providers/database_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'tag_provider.g.dart';

@riverpod
Future<List<Tag>> allTags(AllTagsRef ref) {
  return ref.watch(databaseProvider).getAllTags();
}
