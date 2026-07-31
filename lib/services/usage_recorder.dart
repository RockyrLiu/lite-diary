import 'package:drift/drift.dart';

import '../database/database.dart';
import 'llm_service.dart';

/// 全局用量记录器：由 databaseProvider 绑定后，所有 LlmService 上报自动入库。
class UsageRecorder {
  static AppDatabase? _db;

  static void bind(AppDatabase db) {
    _db = db;
  }

  static void record(LlmUsage usage) {
    final db = _db;
    if (db == null) return;
    db.recordUsage(
      UsageLogsCompanion(
        model: Value(usage.model),
        promptTokens: Value(usage.promptTokens),
        promptCacheHitTokens: Value(usage.promptCacheHitTokens),
        promptCacheMissTokens: Value(usage.promptCacheMissTokens),
        completionTokens: Value(usage.completionTokens),
        createdAt: Value(DateTime.now()),
      ),
    );
  }
}
