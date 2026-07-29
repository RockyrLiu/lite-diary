import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull, Column;

import '../../database/database.dart';
import '../../providers/database_provider.dart';
import '../../providers/calendar_data_provider.dart';
import '../../providers/entry_provider.dart';
import '../../widgets/markdown_editor.dart';
import '../../widgets/tag_editor.dart';
import '../../services/image_service.dart';

class ContentPage extends ConsumerStatefulWidget {
  final int? entryId;
  final bool isNew;
  final DateTime? initialDate;

  const ContentPage({super.key, this.entryId, this.isNew = false, this.initialDate});

  @override
  ConsumerState<ContentPage> createState() => _ContentPageState();
}

class _ContentPageState extends ConsumerState<ContentPage> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  DateTime _currentDate = DateTime.now();
  int _currentEntryIndex = 0;
  List<Entry> _currentEntries = [];
  int? _editingEntryId;
  EditorMode _editorMode = EditorMode.preview;

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  List<DateTime> _getAllEntryDates() {
    final entriesAsync = ref.read(allEntriesProvider);
    final entries = entriesAsync.valueOrNull;
    if (entries == null) return [];
    return entries
        .map((e) => DateTime(e.date.year, e.date.month, e.date.day))
        .toSet()
        .toList()
      ..sort();
  }

  void _loadEntriesForDate(DateTime date) {
    setState(() {
      _currentDate = date;
      _currentEntryIndex = 0;
      _editingEntryId = null;
    });
    final entriesAsync = ref.read(entriesByDateProvider(date));
    entriesAsync.whenData((entries) {
      if (mounted) {
        setState(() => _currentEntries = entries);
        _loadCurrentEntry();
      }
    });
  }

  void _loadCurrentEntry() {
    if (_currentEntries.isNotEmpty && _currentEntryIndex < _currentEntries.length) {
      final entry = _currentEntries[_currentEntryIndex];
      _titleController.text = entry.title ?? '';
      _contentController.text = entry.content;
      _editingEntryId = entry.id;
    } else {
      _titleController.clear();
      _contentController.clear();
      _editingEntryId = null;
    }
  }

  void _goToNextDate() {
    final dates = _getAllEntryDates();
    final currentKey = DateTime(_currentDate.year, _currentDate.month, _currentDate.day);
    final nextDate = dates.firstWhere((d) => d.isAfter(currentKey), orElse: () => _currentDate);
    if (nextDate != _currentDate) _loadEntriesForDate(nextDate);
  }

  void _goToPreviousDate() {
    final dates = _getAllEntryDates();
    final currentKey = DateTime(_currentDate.year, _currentDate.month, _currentDate.day);
    final prevDate = dates.reversed.firstWhere((d) => d.isBefore(currentKey), orElse: () => _currentDate);
    if (prevDate != _currentDate) _loadEntriesForDate(prevDate);
  }

  void _goToNextEntry() {
    if (_currentEntryIndex < _currentEntries.length - 1) {
      setState(() {
        _currentEntryIndex++;
        _loadCurrentEntry();
      });
    }
  }

  void _goToPreviousEntry() {
    if (_currentEntryIndex > 0) {
      setState(() {
        _currentEntryIndex--;
        _loadCurrentEntry();
      });
    }
  }

  Future<void> _saveEntry() async {
    final db = ref.read(databaseProvider);
    final now = DateTime.now();
    if (_editingEntryId != null) {
      await db.updateEntry(
        _editingEntryId!,
        EntriesCompanion(
          title: Value(_titleController.text.isEmpty ? null : _titleController.text),
          content: Value(_contentController.text),
          updatedAt: Value(now),
        ),
      );
    } else {
      await db.createEntry(
        EntriesCompanion(
          title: Value(_titleController.text.isEmpty ? null : _titleController.text),
          date: Value(_currentDate),
          content: Value(_contentController.text),
          groupId: const Value(1),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );
    }
    ref.invalidate(entriesByDateProvider(_currentDate));
    ref.invalidate(allEntriesProvider);
    ref.invalidate(calendarDateCountsProvider);
    _loadEntriesForDate(_currentDate);
  }

  void _startNewEntry() {
    setState(() {
      _titleController.clear();
      _contentController.clear();
      _editingEntryId = null;
    });
  }

  @override
  void initState() {
    super.initState();
    final targetDate = widget.initialDate ?? DateTime.now();
    _currentDate = DateTime(targetDate.year, targetDate.month, targetDate.day);

    if (widget.entryId != null) {
      ref.read(entryByIdProvider(widget.entryId!)).whenData((entry) {
        if (entry != null && mounted) {
          final date = DateTime(entry.date.year, entry.date.month, entry.date.day);
          _loadEntriesForDate(date);
          ref.read(entriesByDateProvider(date)).whenData((entries) {
            final idx = entries.indexWhere((e) => e.id == entry.id);
            if (idx >= 0 && mounted) {
              setState(() => _currentEntryIndex = idx);
              _loadCurrentEntry();
            }
          });
        }
      });
    } else if (widget.isNew) {
      _startNewEntry();
    } else {
      _loadEntriesForDate(_currentDate);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateStr = '${_currentDate.year}年${_currentDate.month}月${_currentDate.day}日';

    return Scaffold(
      appBar: AppBar(
        title: Column(
          children: [
            Text(dateStr),
            if (_currentEntries.length > 1)
              Text('${_currentEntryIndex + 1}/${_currentEntries.length}', style: const TextStyle(fontSize: 12)),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: () {
              setState(() {
                _editorMode = _editorMode == EditorMode.source ? EditorMode.preview : EditorMode.source;
              });
            },
            icon: Icon(_editorMode == EditorMode.source ? Icons.visibility : Icons.edit),
            label: Text(_editorMode == EditorMode.source ? '预览' : '编辑'),
          ),
          IconButton(icon: const Icon(Icons.save), onPressed: _saveEntry),
          if (_currentEntries.length > 1) ...[
            IconButton(icon: const Icon(Icons.arrow_upward), onPressed: _goToPreviousEntry),
            IconButton(icon: const Icon(Icons.arrow_downward), onPressed: _goToNextEntry),
          ],
        ],
      ),
      body: GestureDetector(
        onHorizontalDragEnd: (details) {
          if (details.primaryVelocity != null) {
            if (details.primaryVelocity! < -50) {
              _goToNextDate();
            } else if (details.primaryVelocity! > 50) {
              _goToPreviousDate();
            }
          }
        },
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: TextField(
                controller: _titleController,
                decoration: const InputDecoration(
                  hintText: '标题（可选）',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 8),
                ),
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
            if (_editingEntryId != null)
              TagEditor(key: ValueKey(_editingEntryId), entryId: _editingEntryId!),
            const Divider(height: 1),
            Expanded(
              child: MarkdownEditor(
                controller: _contentController,
                externalMode: _editorMode,
                onToggleMode: () {
                  setState(() {
                    _editorMode = _editorMode == EditorMode.source ? EditorMode.preview : EditorMode.source;
                  });
                },
                onInsertImage: _editingEntryId != null
                    ? () async {
                        final imageService = ImageService();
                        return imageService.pickAndSaveImage(ref, _editingEntryId!);
                      }
                    : null,
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _startNewEntry,
        tooltip: '补记',
        child: const Icon(Icons.add),
      ),
    );
  }
}
