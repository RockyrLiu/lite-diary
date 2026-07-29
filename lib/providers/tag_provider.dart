import 'package:diary_lite/database/database.dart';
import 'package:diary_lite/providers/database_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'tag_provider.g.dart';

@riverpod
Future<List<Tag>> allTags(AllTagsRef ref) {
  return ref.watch(databaseProvider).getAllTags();
}



@riverpod
Future<List<Tag>> tagsForEntry(TagsForEntryRef ref, int entryId) {
  return ref.watch(databaseProvider).getTagsForEntry(entryId);
}
