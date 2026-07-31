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
  });
}
