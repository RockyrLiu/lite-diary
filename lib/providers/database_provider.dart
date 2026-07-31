import 'package:lite_diary/database/database.dart';
import 'package:lite_diary/services/usage_recorder.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'database_provider.g.dart';

@Riverpod(keepAlive: true)
AppDatabase database(DatabaseRef ref) {
  final db = AppDatabase();
  UsageRecorder.bind(db);
  Future.microtask(() => db.insertDefaultGroups());
  return db;
}
