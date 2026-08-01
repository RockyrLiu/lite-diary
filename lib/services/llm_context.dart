import '../database/database.dart';

String formatEntriesForLlm(
  List<Entry> entries, {
  int maxChars = 8000,
  Map<int, String>? groupNames,
}) {
  final buffer = StringBuffer();
  for (final e in entries) {
    buffer.writeln('---');
    buffer.writeln(
      '日期: ${e.date.year}-${e.date.month.toString().padLeft(2, '0')}-${e.date.day.toString().padLeft(2, '0')}',
    );
    final group = groupNames?[e.groupId];
    if (group != null && group.isNotEmpty) {
      buffer.writeln('分组: $group');
    }
    if (e.title != null && e.title!.isNotEmpty) {
      buffer.writeln('标题: ${e.title}');
    }
    buffer.writeln(e.content);
    buffer.writeln();
  }

  final result = buffer.toString();
  if (result.length > maxChars) {
    return '${result.substring(0, maxChars)}...\n\n(内容过长已截断)';
  }
  return result;
}

String formatDateRangeLabel(DateTime start, DateTime end) {
  String fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  if (start.year == end.year &&
      start.month == end.month &&
      start.day == end.day) {
    return fmt(start);
  }
  return '${fmt(start)} ~ ${fmt(end)}';
}

DateTime startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);

