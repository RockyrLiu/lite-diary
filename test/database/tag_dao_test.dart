import 'package:lite_diary/database/database.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting();
  });

  tearDown(() async {
    await db.close();
  });

  Future<int> createTestEntry(String title, DateTime date, int groupId) {
    return db.createEntry(EntriesCompanion(
      title: Value(title),
      date: Value(date),
      content: const Value(''),
      groupId: Value(groupId),
      createdAt: Value(date),
      updatedAt: Value(date),
    ));
  }

  group('TagDao', () {
    test('createTag 创建后可通过 id 查回', () async {
      final tagId = await db.createTag(TagsCompanion(name: const Value('旅行')));
      final tag = await db.getTagById(tagId);
      expect(tag, isNotNull);
      expect(tag!.name, '旅行');
    });

    test('getTagByName 按名称查找', () async {
      await db.createTag(TagsCompanion(name: const Value('旅行')));

      final tag = await db.getTagByName('旅行');
      expect(tag, isNotNull);
      expect(tag!.name, '旅行');
    });

    test('getTagByName 不存在时返回 null', () async {
      expect(await db.getTagByName('不存在'), isNull);
    });

    test('getAllTags 返回所有标签按名称排序', () async {
      await db.createTag(TagsCompanion(name: const Value('C标签')));
      await db.createTag(TagsCompanion(name: const Value('A标签')));

      final tags = await db.getAllTags();
      expect(tags.length, 2);
      expect(tags[0].name, 'A标签');
      expect(tags[1].name, 'C标签');
    });

    test('updateTag 可重命名', () async {
      final tagId = await db.createTag(TagsCompanion(name: const Value('旧名')));

      await db.updateTag(tagId, TagsCompanion(name: const Value('新名')));

      final tag = await db.getTagById(tagId);
      expect(tag!.name, '新名');
    });

    test('deleteTag 删除后不存在', () async {
      final tagId = await db.createTag(TagsCompanion(name: const Value('待删除')));

      await db.deleteTag(tagId);

      expect(await db.getTagById(tagId), isNull);
    });
  });

  group('EntryTag', () {
    test('attachTag 关联标签后可通过条目查到', () async {
      final date = DateTime(2026, 7, 29);
      final entryId = await createTestEntry('日记', date, 1);
      final tagId = await db.createTag(TagsCompanion(name: const Value('旅行')));

      await db.attachTag(entryId, tagId);

      final tags = await db.getTagsForEntry(entryId);
      expect(tags.length, 1);
      expect(tags.first.name, '旅行');
    });

    test('一个条目可以有多个标签', () async {
      final date = DateTime(2026, 7, 29);
      final entryId = await createTestEntry('日记', date, 1);
      final tag1 = await db.createTag(TagsCompanion(name: const Value('旅行')));
      final tag2 = await db.createTag(TagsCompanion(name: const Value('美食')));

      await db.attachTag(entryId, tag1);
      await db.attachTag(entryId, tag2);

      final tags = await db.getTagsForEntry(entryId);
      expect(tags.length, 2);
      final names = tags.map((t) => t.name).toSet();
      expect(names, containsAll(['旅行', '美食']));
    });

    test('detachTag 解除关联后标签不在条目列表中', () async {
      final date = DateTime(2026, 7, 29);
      final entryId = await createTestEntry('日记', date, 1);
      final tagId = await db.createTag(TagsCompanion(name: const Value('旅行')));

      await db.attachTag(entryId, tagId);
      await db.detachTag(entryId, tagId);

      final tags = await db.getTagsForEntry(entryId);
      expect(tags, isEmpty);
    });

    test('getEntriesByTag 可按标签反查条目', () async {
      final date = DateTime(2026, 7, 29);
      final entry1 = await createTestEntry('日记1', date, 1);
      final entry3 = await createTestEntry('日记3', date, 1);
      final tagId = await db.createTag(TagsCompanion(name: const Value('旅行')));

      await db.attachTag(entry1, tagId);
      await db.attachTag(entry3, tagId);

      final entries = await db.getEntriesByTag(tagId);
      expect(entries.length, 2);
      final titles = entries.map((e) => e.title).toSet();
      expect(titles, containsAll(['日记1', '日记3']));
    });

    test('删除标签后关联自动解除（级联删除）', () async {
      final date = DateTime(2026, 7, 29);
      final entryId = await createTestEntry('日记', date, 1);
      final tagId = await db.createTag(TagsCompanion(name: const Value('旅行')));

      await db.attachTag(entryId, tagId);

      // 先确认有关联
      var tags = await db.getTagsForEntry(entryId);
      expect(tags.length, 1);

      await db.deleteTag(tagId);

      tags = await db.getTagsForEntry(entryId);
      expect(tags, isEmpty);
    });
  });
}
