import 'package:lite_diary/database/database.dart';
import 'package:lite_diary/providers/database_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'entry_provider.g.dart';

@riverpod
Future<List<Entry>> allEntries(AllEntriesRef ref) {
  return ref.watch(databaseProvider).getAllEntries();
}

@riverpod
Future<Entry?> entryById(EntryByIdRef ref, int id) {
  return ref.watch(databaseProvider).getEntryById(id);
}

@riverpod
Future<List<Entry>> entriesByDate(EntriesByDateRef ref, DateTime date) {
  return ref.watch(databaseProvider).getEntriesByDate(date);
}

@riverpod
Future<List<Entry>> entriesByGroup(EntriesByGroupRef ref, int groupId) {
  return ref.watch(databaseProvider).getEntriesByGroup(groupId);
}
