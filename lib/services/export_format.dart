import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../database/database.dart';

class ExportFormat {
  static String serializeEntries(
    List<Entry> entries,
    Map<int, List<String>> tagMap,
    Map<int, String> groupNames,
  ) {
    final buf = StringBuffer();
    for (var i = 0; i < entries.length; i++) {
      final e = entries[i];
      buf.writeln('> date: ${dateStr(e.date)}');
      if (e.title != null && e.title!.isNotEmpty) {
        buf.writeln('> title: ${e.title}');
      }
      buf.writeln('> group: ${groupNames[e.groupId] ?? ''}');
      final tags = tagMap[e.id];
      if (tags != null && tags.isNotEmpty) {
        buf.writeln('> tags: ${tags.join(', ')}');
      }
      if (e.weather != null && e.weather!.isNotEmpty) {
        buf.writeln('> weather: ${e.weather}');
      }
      if (e.location != null && e.location!.isNotEmpty) {
        buf.writeln('> location: ${e.location}');
      }
      buf.writeln('> created_at: ${dateTimeStr(e.createdAt)}');
      buf.writeln('> updated_at: ${dateTimeStr(e.updatedAt)}');
      final hash = e.hash ?? computeHash(e.date, e.content);
      buf.writeln('> hash: $hash');
      buf.writeln();
      buf.writeln(e.content);
      buf.writeln();
      if (i < entries.length - 1) {
        buf.writeln('---');
        buf.writeln();
      }
    }
    return buf.toString();
  }

  static List<Map<String, String>> parseEntries(String content) {
    final entries = <Map<String, String>>[];
    final blocks = content.split('\n---\n');
    for (final block in blocks) {
      if (block.trim().isEmpty) continue;
      final lines = block.split('\n');
      final meta = <String, String>{};
      final contentLines = <String>[];
      var inMeta = true;
      for (final line in lines) {
        if (inMeta && line.startsWith('> ')) {
          final rest = line.substring(2);
          final colonIdx = rest.indexOf(':');
          if (colonIdx > 0) {
            meta[rest.substring(0, colonIdx).trim()] =
                rest.substring(colonIdx + 1).trim();
          }
        } else if (inMeta && line.isEmpty) {
          continue;
        } else {
          inMeta = false;
          contentLines.add(line);
        }
      }
      meta['content'] = contentLines.join('\n').trim();
      if (meta['date'] != null || meta['content']!.isNotEmpty) {
        entries.add(meta);
      }
    }
    return entries;
  }

  static String computeHash(DateTime date, String content) {
    final ds =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    return sha256.convert(utf8.encode('$ds|$content')).toString();
  }

  static String dateStr(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static String dateTimeStr(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')} '
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}:${d.second.toString().padLeft(2, '0')}';

  static DateTime? parseDate(String? s) {
    if (s == null || s.isEmpty) return null;
    final parts = s.split('-');
    if (parts.length != 3) return null;
    final y = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    final d = int.tryParse(parts[2]);
    if (y == null || m == null || d == null) return null;
    return DateTime(y, m, d);
  }

  static DateTime? parseDateTime(String? s) {
    if (s == null || s.isEmpty) return null;
    final parts = s.split(' ');
    final date = parseDate(parts[0]);
    if (date == null || parts.length < 2) return date;
    final timeParts = parts[1].split(':');
    final h = int.tryParse(timeParts[0]);
    final min = int.tryParse(timeParts[1]);
    final sec = timeParts.length > 2 ? int.tryParse(timeParts[2]) : null;
    if (h == null || min == null) return date;
    return DateTime(date.year, date.month, date.day, h, min, sec ?? 0);
  }

  static bool inRange(DateTime date, DateTime start, DateTime end,
      [bool allTime = false]) {
    if (allTime) return true;
    final d = DateTime(date.year, date.month, date.day);
    return !d.isBefore(start) && !d.isAfter(end);
  }
}
