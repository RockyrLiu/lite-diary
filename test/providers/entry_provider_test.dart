import 'package:lite_diary/database/database.dart';
import 'package:lite_diary/providers/database_provider.dart';
import 'package:lite_diary/providers/entry_provider.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

ProviderContainer createContainer() {
  final db = AppDatabase.forTesting();
  final container = ProviderContainer(
    overrides: [
      databaseProvider.overrideWith((ref) => db),
    ],
  );
  addTearDown(() async {
    await db.close();
    container.dispose();
  });
  return container;
}

void main() {
  group('EntryProvider', () {
    test('allEntriesProvider 返回所有日记', () async {
      final container = createContainer();
      final db = container.read(databaseProvider);

      final date = DateTime(2026, 7, 29);
      await db.createEntry(EntriesCompanion(
        title: const Value('日记1'),
        date: Value(date),
        content: const Value('内容1'),
        groupId: const Value(1),
        createdAt: Value(date),
        updatedAt: Value(date),
      ));
      await db.createEntry(EntriesCompanion(
        title: const Value('日记2'),
        date: Value(date),
        content: const Value('内容2'),
        groupId: const Value(1),
        createdAt: Value(date),
        updatedAt: Value(date),
      ));

      final entries = await container.read(allEntriesProvider.future);
      expect(entries.length, 2);
    });

    test('entriesByDateProvider 按日期筛选', () async {
      final container = createContainer();
      final db = container.read(databaseProvider);

      final date = DateTime(2026, 7, 29);
      await db.createEntry(EntriesCompanion(
        title: const Value('7月29日'),
        date: Value(date),
        content: const Value(''),
        groupId: const Value(1),
        createdAt: Value(date),
        updatedAt: Value(date),
      ));
      await db.createEntry(EntriesCompanion(
        title: const Value('7月30日'),
        date: Value(DateTime(2026, 7, 30)),
        content: const Value(''),
        groupId: const Value(1),
        createdAt: Value(DateTime(2026, 7, 30)),
        updatedAt: Value(DateTime(2026, 7, 30)),
      ));

      final entries = await container.read(entriesByDateProvider(date).future);
      expect(entries.length, 1);
      expect(entries.first.title, '7月29日');
    });

    test('entriesByGroupProvider 按分组筛选', () async {
      final container = createContainer();
      final db = container.read(databaseProvider);

      final date = DateTime(2026, 7, 29);
      await db.createEntry(EntriesCompanion(
        title: const Value('分组1'),
        date: Value(date),
        content: const Value(''),
        groupId: const Value(1),
        createdAt: Value(date),
        updatedAt: Value(date),
      ));
      await db.createEntry(EntriesCompanion(
        title: const Value('分组2'),
        date: Value(date),
        content: const Value(''),
        groupId: const Value(2),
        createdAt: Value(date),
        updatedAt: Value(date),
      ));

      final entries = await container.read(entriesByGroupProvider(1).future);
      expect(entries.length, 1);
      expect(entries.first.title, '分组1');
    });
  });
}
