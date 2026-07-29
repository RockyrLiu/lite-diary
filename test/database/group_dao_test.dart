import 'package:diary_lite/database/database.dart';
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

  group('GroupDao', () {
    test('createGroup 创建后可通过 id 查回', () async {
      final groupId = await db.createGroup(
        GroupsCompanion(name: const Value('旅行')),
      );

      final group = await db.getGroupById(groupId);
      expect(group, isNotNull);
      expect(group!.name, '旅行');
    });

    test('getGroupById 不存在时返回 null', () async {
      expect(await db.getGroupById(999), isNull);
    });

    test('getAllGroups 返回所有分组按排序权重排序', () async {
      await db.createGroup(GroupsCompanion(name: const Value('B'), sortOrder: const Value(2)));
      await db.createGroup(GroupsCompanion(name: const Value('A'), sortOrder: const Value(1)));

      final groups = await db.getAllGroups();
      expect(groups.length, 2);
      expect(groups[0].name, 'A');
      expect(groups[1].name, 'B');
    });

    test('updateGroup 可改名和排序', () async {
      final groupId = await db.createGroup(GroupsCompanion(name: const Value('原名')));

      await db.updateGroup(groupId, GroupsCompanion(name: const Value('新名'), sortOrder: const Value(99)));

      final group = await db.getGroupById(groupId);
      expect(group!.name, '新名');
      expect(group.sortOrder, 99);
    });

    test('deleteGroup 删除后不存在', () async {
      final groupId = await db.createGroup(GroupsCompanion(name: const Value('待删除')));

      await db.deleteGroup(groupId);

      expect(await db.getGroupById(groupId), isNull);
    });

    test('insertDefaultGroups 插入默认分组', () async {
      await db.insertDefaultGroups();

      final groups = await db.getAllGroups();
      expect(groups.length, 2);
      final names = groups.map((g) => g.name).toSet();
      expect(names, containsAll(['日记', '诗词']));
    });

    test('insertDefaultGroups 多次调用不重复插入', () async {
      await db.insertDefaultGroups();
      await db.insertDefaultGroups();

      final groups = await db.getAllGroups();
      expect(groups.length, 2);
    });
  });
}
