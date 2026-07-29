import 'package:diary_lite/database/database.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting();
  });

  tearDown(() async {
    await db.close();
  });

  group('Settings', () {
    test('setSetting 写入后可通过 key 查回', () async {
      await db.setSetting('theme', 'dark');
      final value = await db.getSetting('theme');
      expect(value, 'dark');
    });

    test('getSetting 不存在时返回 null', () async {
      expect(await db.getSetting('nonexistent'), isNull);
    });

    test('setSetting 多次写入同一 key 会覆盖', () async {
      await db.setSetting('theme', 'dark');
      await db.setSetting('theme', 'light');

      final value = await db.getSetting('theme');
      expect(value, 'light');
    });
  });
}
