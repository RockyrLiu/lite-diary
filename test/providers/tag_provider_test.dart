import 'package:lite_diary/database/database.dart';
import 'package:lite_diary/providers/database_provider.dart';
import 'package:lite_diary/providers/tag_provider.dart';
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
  group('TagProvider', () {
    test('allTagsProvider 返回所有标签按名称排序', () async {
      final container = createContainer();
      final db = container.read(databaseProvider);

      await db.createTag(TagsCompanion(name: const Value('C')));
      await db.createTag(TagsCompanion(name: const Value('A')));

      final tags = await container.read(allTagsProvider.future);
      expect(tags.length, 2);
      expect(tags[0].name, 'A');
      expect(tags[1].name, 'C');
    });

    test('tagsForEntryProvider 获取条目的所有标签', () async {
      final container = createContainer();
      final db = container.read(databaseProvider);

      final date = DateTime(2026, 7, 29);
      final entryId = await db.createEntry(EntriesCompanion(
        title: const Value('日记'),
        date: Value(date),
        content: const Value(''),
        groupId: const Value(1),
        createdAt: Value(date),
        updatedAt: Value(date),
      ));
      final tag1 = await db.createTag(TagsCompanion(name: const Value('旅行')));
      final tag2 = await db.createTag(TagsCompanion(name: const Value('美食')));

      await db.attachTag(entryId, tag1);
      await db.attachTag(entryId, tag2);

      final tags = await container.read(tagsForEntryProvider(entryId).future);
      expect(tags.length, 2);
      final names = tags.map((t) => t.name).toSet();
      expect(names, containsAll(['旅行', '美食']));
    });
  });
}
