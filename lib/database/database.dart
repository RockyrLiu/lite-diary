import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'dart:io';

import 'tables.dart';

part 'database.g.dart';

@DriftDatabase(tables: [Entries, Groups, Tags, EntryTags, Images, Settings])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  AppDatabase.forTesting() : super(NativeDatabase.memory());

  @override
  int get schemaVersion => 2;

  // ========== Entry ==========

  Future<int> createEntry(EntriesCompanion entry) {
    return into(entries).insert(entry);
  }

  Future<Entry?> getEntryById(int id) {
    return (select(entries)..where((e) => e.id.equals(id))).getSingleOrNull();
  }

  Future<bool> updateEntry(int id, EntriesCompanion entry) {
    return (update(entries)..where((e) => e.id.equals(id))).write(entry).then((count) => count > 0);
  }

  Future<bool> deleteEntry(int id) {
    return (delete(entries)..where((e) => e.id.equals(id))).go().then((count) => count > 0);
  }

  Future<List<Entry>> getEntriesByDate(DateTime date) {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));
    return (select(entries)
      ..where((e) => e.date.isBiggerOrEqualValue(startOfDay) & e.date.isSmallerThanValue(endOfDay))
      ..orderBy([(e) => OrderingTerm(expression: e.createdAt, mode: OrderingMode.asc)]))
        .get();
  }

  Future<Entry?> getNextEntry(DateTime currentDate) {
    final startOfNextDay = DateTime(currentDate.year, currentDate.month, currentDate.day + 1);
    return (select(entries)
      ..where((e) => e.date.isBiggerOrEqualValue(startOfNextDay))
      ..orderBy([(e) => OrderingTerm(expression: e.date, mode: OrderingMode.asc)])
      ..limit(1))
        .getSingleOrNull();
  }

  Future<Entry?> getPreviousEntry(DateTime currentDate) {
    final endOfCurrentDay = DateTime(currentDate.year, currentDate.month, currentDate.day);
    return (select(entries)
      ..where((e) => e.date.isSmallerThanValue(endOfCurrentDay))
      ..orderBy([(e) => OrderingTerm(expression: e.date, mode: OrderingMode.desc)])
      ..limit(1))
        .getSingleOrNull();
  }

  Future<List<Entry>> getEntriesByGroup(int groupId) {
    return (select(entries)
      ..where((e) => e.groupId.equals(groupId))
      ..orderBy([(e) => OrderingTerm(expression: e.date, mode: OrderingMode.desc)]))
        .get();
  }

  Future<List<Entry>> getAllEntries() {
    return select(entries).get();
  }

  Future<Entry?> getEntryByHash(String hash) {
    return (select(entries)..where((e) => e.hash.equals(hash))).getSingleOrNull();
  }

  // ========== Group ==========

  Future<int> createGroup(GroupsCompanion group) {
    return into(groups).insert(group);
  }

  Future<Group?> getGroupById(int id) {
    return (select(groups)..where((g) => g.id.equals(id))).getSingleOrNull();
  }

  Future<List<Group>> getAllGroups() {
    return (select(groups)
      ..orderBy([
        (g) => OrderingTerm(expression: g.sortOrder, mode: OrderingMode.asc),
        (g) => OrderingTerm(expression: g.name, mode: OrderingMode.asc),
      ]))
        .get();
  }

  Future<bool> updateGroup(int id, GroupsCompanion group) {
    return (update(groups)..where((g) => g.id.equals(id))).write(group).then((count) => count > 0);
  }

  Future<bool> deleteGroup(int id) {
    return (delete(groups)..where((g) => g.id.equals(id))).go().then((count) => count > 0);
  }

  // ========== Tag ==========

  Future<int> createTag(TagsCompanion tag) {
    return into(tags).insert(tag);
  }

  Future<Tag?> getTagById(int id) {
    return (select(tags)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Future<Tag?> getTagByName(String name) {
    return (select(tags)..where((t) => t.name.equals(name))).getSingleOrNull();
  }

  Future<List<Tag>> getAllTags() {
    return (select(tags)..orderBy([(t) => OrderingTerm(expression: t.name, mode: OrderingMode.asc)])).get();
  }

  Future<bool> updateTag(int id, TagsCompanion tag) {
    return (update(tags)..where((t) => t.id.equals(id))).write(tag).then((count) => count > 0);
  }

  Future<bool> deleteTag(int id) {
    return (delete(tags)..where((t) => t.id.equals(id))).go().then((count) => count > 0);
  }

  // ========== EntryTag ==========

  Future<void> attachTag(int entryId, int tagId) {
    return into(entryTags).insert(EntryTagsCompanion(entryId: Value(entryId), tagId: Value(tagId)));
  }

  Future<void> detachTag(int entryId, int tagId) {
    return (delete(entryTags)
      ..where((et) => et.entryId.equals(entryId) & et.tagId.equals(tagId)))
        .go();
  }

  Future<List<Tag>> getTagsForEntry(int entryId) {
    final query = select(entryTags).join([
      innerJoin(tags, tags.id.equalsExp(entryTags.tagId)),
    ])
      ..where(entryTags.entryId.equals(entryId));
    return query.map((row) => row.readTable(tags)).get();
  }

  Future<List<Entry>> getEntriesByTag(int tagId) {
    final query = select(entryTags).join([
      innerJoin(entries, entries.id.equalsExp(entryTags.entryId)),
    ])
      ..where(entryTags.tagId.equals(tagId));
    return query.map((row) => row.readTable(entries)).get();
  }

  Future<Map<int, List<String>>> getEntryTagsMap() async {
    final query = select(entryTags).join([
      innerJoin(tags, tags.id.equalsExp(entryTags.tagId)),
    ]);
    final rows = await query.get();
    final map = <int, List<String>>{};
    for (final row in rows) {
      final entryId = row.readTable(entryTags).entryId;
      final tagName = row.readTable(tags).name;
      map.putIfAbsent(entryId, () => []).add(tagName);
    }
    return map;
  }

  // ========== Settings ==========

  Future<void> setSetting(String key, String value) {
    return into(settings).insertOnConflictUpdate(SettingsCompanion(key: Value(key), value: Value(value)));
  }

  Future<String?> getSetting(String key) {
    final query = select(settings)..where((s) => s.key.equals(key));
    return query.map((s) => s.value).getSingleOrNull();
  }

  // ========== Init ==========

  Future<void> insertDefaultGroups() async {
    await into(groups).insert(
      GroupsCompanion(name: const Value('日记'), sortOrder: const Value(0)),
      mode: InsertMode.insertOrIgnore,
    );
    await into(groups).insert(
      GroupsCompanion(name: const Value('诗词'), sortOrder: const Value(1)),
      mode: InsertMode.insertOrIgnore,
    );
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'diary_lite.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
