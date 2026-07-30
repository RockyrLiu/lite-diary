import 'package:lite_diary/database/database.dart';
import 'package:lite_diary/providers/database_provider.dart';
import 'package:lite_diary/providers/group_provider.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod/riverpod.dart';

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
  group('GroupProvider', () {
    test('allGroupsProvider 返回所有分组', () async {
      final container = createContainer();
      final db = container.read(databaseProvider);

      await db.createGroup(GroupsCompanion(name: const Value('B')));
      await db.createGroup(GroupsCompanion(name: const Value('A')));

      final groups = await container.read(allGroupsProvider.future);
      expect(groups.length, 2);
      expect(groups.first.name, 'A');
      expect(groups.last.name, 'B');
    });

  });
}
