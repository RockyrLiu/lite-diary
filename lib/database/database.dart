import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'dart:io';

import 'tables.dart';

part 'database.g.dart';

@DriftDatabase(tables: [Entries, Groups, Tags, EntryTags, Images, Conversations, Messages, AnalysisPrompts])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  AppDatabase.forTesting() : super(NativeDatabase.memory());

  @override
  int get schemaVersion => 8;

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

  Future<Entry?> getEntryByCreatedAt(DateTime createdAt) {
    return (select(entries)..where((e) => e.createdAt.equals(createdAt)))
        .getSingleOrNull();
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

  // ========== Conversation ==========

  Future<int> createConversation(ConversationsCompanion conversation) {
    return into(conversations).insert(conversation);
  }

  Future<List<Conversation>> getAllConversations() {
    return (select(conversations)
      ..orderBy([(c) => OrderingTerm(expression: c.updatedAt, mode: OrderingMode.desc)]))
        .get();
  }

  Future<Conversation?> getConversationById(int id) {
    return (select(conversations)..where((c) => c.id.equals(id))).getSingleOrNull();
  }

  Future<bool> updateConversation(int id, ConversationsCompanion conversation) {
    return (update(conversations)..where((c) => c.id.equals(id))).write(conversation).then((count) => count > 0);
  }

  Future<bool> deleteConversation(int id) {
    return (delete(conversations)..where((c) => c.id.equals(id))).go().then((count) => count > 0);
  }

  // ========== Message ==========

  Future<int> createMessage(MessagesCompanion message) {
    return into(messages).insert(message);
  }

  Future<List<Message>> getMessagesByConversation(int conversationId) {
    return (select(messages)
      ..where((m) => m.conversationId.equals(conversationId))
      ..orderBy([(m) => OrderingTerm(expression: m.createdAt, mode: OrderingMode.asc)]))
        .get();
  }

  Future<bool> updateMessage(int id, MessagesCompanion message) {
    return (update(messages)..where((m) => m.id.equals(id))).write(message).then((count) => count > 0);
  }

  // ========== AnalysisPrompt ==========

  Future<int> createAnalysisPrompt(AnalysisPromptsCompanion prompt) {
    return into(analysisPrompts).insert(prompt);
  }

  Future<List<AnalysisPrompt>> getAllAnalysisPrompts() {
    return (select(analysisPrompts)
      ..orderBy([(p) => OrderingTerm(expression: p.sortOrder, mode: OrderingMode.asc)]))
        .get();
  }

  Future<bool> updateAnalysisPrompt(int id, AnalysisPromptsCompanion prompt) {
    return (update(analysisPrompts)..where((p) => p.id.equals(id))).write(prompt).then((count) => count > 0);
  }

  Future<bool> deleteAnalysisPrompt(int id) {
    return (delete(analysisPrompts)..where((p) => p.id.equals(id))).go().then((count) => count > 0);
  }

  Future<void> insertDefaultAnalysisPrompts() async {
    final defaults = <Map<String, String>>[
      {'name': '情绪分析', 'template': '请根据以上日记内容，分析作者的情绪变化和趋势，给出详细分析。'},
      {'name': '内容摘要', 'template': '请对以上日记内容进行总结，提炼关键要点。'},
      {'name': '本周回顾', 'template': '请根据以上本周日记，生成周度回顾（主要事件、情绪变化、收获与反思）。'},
    ];
    for (var i = 0; i < defaults.length; i++) {
      final item = defaults[i];
      await into(analysisPrompts).insert(
        AnalysisPromptsCompanion(
          name: Value(item['name']!),
          promptTemplate: Value(item['template']!),
          sortOrder: Value(i),
        ),
        mode: InsertMode.insertOrIgnore,
      );
    }
  }
  // ========== Migration ==========

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (m) async {
        await m.createAll();
        await insertDefaultGroups();
        await insertDefaultAnalysisPrompts();
      },
      onUpgrade: (m, from, to) async {
        if (from < 3) {
          await m.createTable(conversations);
          await m.createTable(messages);
          await m.createTable(analysisPrompts);
          await insertDefaultAnalysisPrompts();
        }
        if (from < 4) {
          await customStatement('DELETE FROM analysis_prompts');
          await insertDefaultAnalysisPrompts();
        }
        if (from < 5) {
          await m.addColumn(analysisPrompts, analysisPrompts.isVisible);
        }
        if (from < 6) {
          await customStatement('DROP TABLE IF EXISTS settings');
        }
        if (from < 7) {
          await customStatement("DELETE FROM analysis_prompts WHERE name = '写作建议'");
          await customStatement("UPDATE analysis_prompts SET name = '内容摘要' WHERE name = '今日摘要'");
          await customStatement("UPDATE analysis_prompts SET name = '本周回顾' WHERE name = '每周回顾'");
        }
        if (from < 8) {
          await customStatement("UPDATE analysis_prompts SET prompt_template = REPLACE(prompt_template, '\n\n{entries}', '')");
          await customStatement("UPDATE analysis_prompts SET prompt_template = REPLACE(prompt_template, '{entries}', '')");
        }
      },
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
