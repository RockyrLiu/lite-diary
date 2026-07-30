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

  group('EntryDao', () {
    test('createEntry 创建后可通过 id 查回', () async {
      final now = DateTime(2026, 7, 29);
      final entryId = await db.createEntry(
        EntriesCompanion(
          title: const Value('测试日记'),
          date: Value(now),
          content: const Value('# Hello\n\n这是测试内容'),
          groupId: const Value(1),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );

      final entry = await db.getEntryById(entryId);
      expect(entry, isNotNull);
      expect(entry!.title, '测试日记');
      expect(entry.date, now);
      expect(entry.content, '# Hello\n\n这是测试内容');
      expect(entry.groupId, 1);
    });

    test('getEntryById 不存在时返回 null', () async {
      final entry = await db.getEntryById(999);
      expect(entry, isNull);
    });

    test('updateEntry 修改后查到的记录已更新', () async {
      final now = DateTime(2026, 7, 29);
      final entryId = await db.createEntry(
        EntriesCompanion(
          title: const Value('原标题'),
          date: Value(now),
          content: const Value('原内容'),
          groupId: const Value(1),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );

      await db.updateEntry(
        entryId,
        EntriesCompanion(
          title: const Value('新标题'),
          content: const Value('新内容'),
          updatedAt: Value(DateTime(2026, 7, 30)),
        ),
      );

      final entry = await db.getEntryById(entryId);
      expect(entry, isNotNull);
      expect(entry!.title, '新标题');
      expect(entry.content, '新内容');
      // date 不应被 update 改变
      expect(entry.date.year, now.year);
      expect(entry.date.month, now.month);
      expect(entry.date.day, now.day);
    });

    test('deleteEntry 删除后不存在', () async {
      final now = DateTime(2026, 7, 29);
      final entryId = await db.createEntry(
        EntriesCompanion(
          title: const Value('待删除'),
          date: Value(now),
          content: const Value('内容'),
          groupId: const Value(1),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );

      await db.deleteEntry(entryId);

      final entry = await db.getEntryById(entryId);
      expect(entry, isNull);
    });

    test('getEntriesByDate 同日多条记录全部返回', () async {
      final date = DateTime(2026, 7, 29);
      await db.createEntry(EntriesCompanion(
        title: const Value('第一条'),
        date: Value(date),
        content: const Value('内容1'),
        groupId: const Value(1),
        createdAt: Value(date),
        updatedAt: Value(date),
      ));
      await db.createEntry(EntriesCompanion(
        title: const Value('第二条'),
        date: Value(date),
        content: const Value('内容2'),
        groupId: const Value(1),
        createdAt: Value(date),
        updatedAt: Value(date),
      ));

      final entries = await db.getEntriesByDate(date);
      expect(entries.length, 2);
      final titles = entries.map((e) => e.title).toList();
      expect(titles, contains('第一条'));
      expect(titles, contains('第二条'));
    });

    test('getEntriesByDate 只返回对应日期的记录', () async {
      await db.createEntry(EntriesCompanion(
        title: const Value('7月29日'),
        date: Value(DateTime(2026, 7, 29)),
        content: const Value('a'),
        groupId: const Value(1),
        createdAt: Value(DateTime(2026, 7, 29)),
        updatedAt: Value(DateTime(2026, 7, 29)),
      ));
      await db.createEntry(EntriesCompanion(
        title: const Value('7月30日'),
        date: Value(DateTime(2026, 7, 30)),
        content: const Value('b'),
        groupId: const Value(1),
        createdAt: Value(DateTime(2026, 7, 30)),
        updatedAt: Value(DateTime(2026, 7, 30)),
      ));

      final entries = await db.getEntriesByDate(DateTime(2026, 7, 29));
      expect(entries.length, 1);
      expect(entries.first.title, '7月29日');
    });

    test('getNextEntry 返回日期大于当前日期的第一条记录', () async {
      await db.createEntry(EntriesCompanion(
        title: const Value('第一条'),
        date: Value(DateTime(2026, 7, 20)),
        content: const Value(''),
        groupId: const Value(1),
        createdAt: Value(DateTime(2026, 7, 20)),
        updatedAt: Value(DateTime(2026, 7, 20)),
      ));
      await db.createEntry(EntriesCompanion(
        title: const Value('第三条'),
        date: Value(DateTime(2026, 7, 25)),
        content: const Value(''),
        groupId: const Value(1),
        createdAt: Value(DateTime(2026, 7, 25)),
        updatedAt: Value(DateTime(2026, 7, 25)),
      ));
      await db.createEntry(EntriesCompanion(
        title: const Value('第二条'),
        date: Value(DateTime(2026, 7, 22)),
        content: const Value(''),
        groupId: const Value(1),
        createdAt: Value(DateTime(2026, 7, 22)),
        updatedAt: Value(DateTime(2026, 7, 22)),
      ));

      final next = await db.getNextEntry(DateTime(2026, 7, 20));
      expect(next, isNotNull);
      expect(next!.title, '第二条');
    });

    test('getNextEntry 没有更多记录时返回 null', () async {
      await db.createEntry(EntriesCompanion(
        title: const Value('最后一条'),
        date: Value(DateTime(2026, 7, 20)),
        content: const Value(''),
        groupId: const Value(1),
        createdAt: Value(DateTime(2026, 7, 20)),
        updatedAt: Value(DateTime(2026, 7, 20)),
      ));

      final next = await db.getNextEntry(DateTime(2026, 7, 20));
      expect(next, isNull);
    });

    test('getPreviousEntry 返回日期小于当前日期的最后一条记录', () async {
      await db.createEntry(EntriesCompanion(
        title: const Value('第一条'),
        date: Value(DateTime(2026, 7, 20)),
        content: const Value(''),
        groupId: const Value(1),
        createdAt: Value(DateTime(2026, 7, 20)),
        updatedAt: Value(DateTime(2026, 7, 20)),
      ));
      await db.createEntry(EntriesCompanion(
        title: const Value('第二条'),
        date: Value(DateTime(2026, 7, 22)),
        content: const Value(''),
        groupId: const Value(1),
        createdAt: Value(DateTime(2026, 7, 22)),
        updatedAt: Value(DateTime(2026, 7, 22)),
      ));

      final prev = await db.getPreviousEntry(DateTime(2026, 7, 25));
      expect(prev, isNotNull);
      expect(prev!.title, '第二条');
    });

    test('getPreviousEntry 没有更多记录时返回 null', () async {
      await db.createEntry(EntriesCompanion(
        title: const Value('第一条'),
        date: Value(DateTime(2026, 7, 20)),
        content: const Value(''),
        groupId: const Value(1),
        createdAt: Value(DateTime(2026, 7, 20)),
        updatedAt: Value(DateTime(2026, 7, 20)),
      ));

      final prev = await db.getPreviousEntry(DateTime(2026, 7, 19));
      expect(prev, isNull);
    });

    test('getEntriesByGroup 按分组筛选返回对应条目', () async {
      await db.createEntry(EntriesCompanion(
        title: const Value('分组1条目'),
        date: Value(DateTime(2026, 7, 29)),
        content: const Value(''),
        groupId: const Value(1),
        createdAt: Value(DateTime(2026, 7, 29)),
        updatedAt: Value(DateTime(2026, 7, 29)),
      ));
      await db.createEntry(EntriesCompanion(
        title: const Value('分组2条目'),
        date: Value(DateTime(2026, 7, 29)),
        content: const Value(''),
        groupId: const Value(2),
        createdAt: Value(DateTime(2026, 7, 29)),
        updatedAt: Value(DateTime(2026, 7, 29)),
      ));

      final group1Entries = await db.getEntriesByGroup(1);
      expect(group1Entries.length, 1);
      expect(group1Entries.first.title, '分组1条目');

      final group2Entries = await db.getEntriesByGroup(2);
      expect(group2Entries.length, 1);
      expect(group2Entries.first.title, '分组2条目');
    });
  });
}
