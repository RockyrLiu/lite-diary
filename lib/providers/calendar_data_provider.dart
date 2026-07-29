import 'dart:collection';

import 'package:diary_lite/providers/entry_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'calendar_data_provider.g.dart';

@riverpod
Future<Map<DateTime, int>> calendarDateCounts(CalendarDateCountsRef ref) async {
  final entries = await ref.watch(allEntriesProvider.future);
  final counts = HashMap<DateTime, int>(
    equals: (a, b) => a.year == b.year && a.month == b.month && a.day == b.day,
    hashCode: (d) => Object.hash(d.year, d.month, d.day),
  );
  for (final entry in entries) {
    final key = DateTime(entry.date.year, entry.date.month, entry.date.day);
    counts[key] = (counts[key] ?? 0) + 1;
  }
  return counts;
}
