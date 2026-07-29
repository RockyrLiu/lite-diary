import 'package:diary_lite/database/database.dart';
import 'package:diary_lite/providers/database_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'group_provider.g.dart';

@riverpod
Future<List<Group>> allGroups(AllGroupsRef ref) {
  return ref.watch(databaseProvider).getAllGroups();
}


