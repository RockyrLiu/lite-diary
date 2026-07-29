import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull, Column;

import '../../database/database.dart';
import '../../providers/database_provider.dart';
import '../../providers/calendar_data_provider.dart';
import '../../providers/entry_provider.dart';
import '../../providers/group_provider.dart';
import '../../widgets/markdown_editor.dart';
import '../../widgets/tag_editor.dart';
import '../../services/image_service.dart';
import '../../services/rendering_settings.dart';

class ContentPage extends ConsumerStatefulWidget {
  final int? entryId;
  final bool isNew;
  final DateTime? initialDate;

  const ContentPage({super.key, this.entryId, this.isNew = false, this.initialDate});

  @override
  ConsumerState<ContentPage> createState() => _ContentPageState();
}

class _ContentPageState extends ConsumerState<ContentPage> with WidgetsBindingObserver {
  final TextEditingController _contentController = TextEditingController();
  Timer? _saveTimer;
  DateTime _currentDate = DateTime.now();
  int _currentEntryIndex = 0;
  List<Entry> _currentEntries = [];
  int? _editingEntryId;
  int _currentGroupId = 1;
  EditorMode _editorMode = EditorMode.preview;
  bool _hasUnsavedChanges = false;

  AppDatabase get db => ref.read(databaseProvider);

  String? _extractTitle(String content) {
    final firstLine = content.split('\n').first.trim();
    if (firstLine.startsWith('#') && firstLine.length > 1) {
      final title = firstLine.replaceFirst(RegExp(r'^#+\s*'), '');
      return title.isEmpty ? null : title;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _init();
  }

  Future<void> _init() async {
    final targetDate = widget.initialDate ?? DateTime.now();
    _currentDate = DateTime(targetDate.year, targetDate.month, targetDate.day);

    if (widget.entryId != null) {
      final entry = await db.getEntryById(widget.entryId!);
      if (entry == null || !mounted) return;
      _currentGroupId = entry.groupId;
      final date = DateTime(entry.date.year, entry.date.month, entry.date.day);
      final entries = await db.getEntriesByDate(date);
      if (!mounted) return;
      final idx = entries.indexWhere((e) => e.id == entry.id);
      setState(() {
        _currentDate = date;
        _currentEntries = entries;
        _currentEntryIndex = idx >= 0 ? idx : 0;
      });
      _loadCurrentEntry();
    } else if (widget.isNew) {
      _startNewEntry();
    } else {
      final entries = await db.getEntriesByDate(_currentDate);
      if (!mounted) return;
      setState(() => _currentEntries = entries);
      _loadCurrentEntry();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _saveTimer?.cancel();
      _saveNow();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _saveTimer?.cancel();
    _saveNow();
    _contentController.dispose();
    super.dispose();
  }

  void _scheduleSave() {
    _hasUnsavedChanges = true;
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 1500), () {
      if (mounted) _saveNow();
    });
  }

  Future<void> _saveNow() async {
    if (!_hasUnsavedChanges) return;
    final content = _contentController.text.trim();
    if (content.isEmpty) { _hasUnsavedChanges = false; return; }
    final title = _extractTitle(content);
    final now = DateTime.now();
    if (_editingEntryId != null) {
      await db.updateEntry(_editingEntryId!, EntriesCompanion(
        title: Value(title), content: Value(content), updatedAt: Value(now),
      ));
    } else {
      final newId = await db.createEntry(EntriesCompanion(
        title: Value(title), date: Value(_currentDate), content: Value(content),
        groupId: Value(_currentGroupId), createdAt: Value(now), updatedAt: Value(now),
      ));
      if (mounted) setState(() => _editingEntryId = newId);
    }
    _hasUnsavedChanges = false;
    ref.invalidate(entriesByDateProvider(_currentDate));
    ref.invalidate(allEntriesProvider);
    ref.invalidate(calendarDateCountsProvider);
  }

  Future<void> _loadEntriesForDate(DateTime date) async {
    _saveNow();
    final entries = await db.getEntriesByDate(date);
    if (!mounted) return;
    setState(() { _currentDate = date; _currentEntries = entries; _currentEntryIndex = 0; _editingEntryId = null; });
    _loadCurrentEntry();
  }

  void _loadCurrentEntry() {
    if (_currentEntries.isNotEmpty && _currentEntryIndex < _currentEntries.length) {
      final entry = _currentEntries[_currentEntryIndex];
      _contentController.text = entry.content;
      _editingEntryId = entry.id;
      _currentGroupId = entry.groupId;
      _hasUnsavedChanges = false;
    } else {
      _contentController.clear();
      _editingEntryId = null;
      _hasUnsavedChanges = false;
    }
  }

  Future<void> _goToNextDate() async {
    _saveNow();
    final entries = await db.getAllEntries();
    final dates = entries.map((e) => DateTime(e.date.year, e.date.month, e.date.day)).toSet().toList()..sort();
    final currentKey = DateTime(_currentDate.year, _currentDate.month, _currentDate.day);
    final nextDate = dates.firstWhere((d) => d.isAfter(currentKey), orElse: () => _currentDate);
    if (nextDate != _currentDate) await _loadEntriesForDate(nextDate);
  }

  Future<void> _goToPreviousDate() async {
    _saveNow();
    final entries = await db.getAllEntries();
    final dates = entries.map((e) => DateTime(e.date.year, e.date.month, e.date.day)).toSet().toList()..sort();
    final currentKey = DateTime(_currentDate.year, _currentDate.month, _currentDate.day);
    final prevDate = dates.reversed.firstWhere((d) => d.isBefore(currentKey), orElse: () => _currentDate);
    if (prevDate != _currentDate) await _loadEntriesForDate(prevDate);
  }

  void _goToNextEntry() { _saveNow(); if (_currentEntryIndex < _currentEntries.length - 1) { setState(() { _currentEntryIndex++; _loadCurrentEntry(); }); } }
  void _goToPreviousEntry() { _saveNow(); if (_currentEntryIndex > 0) { setState(() { _currentEntryIndex--; _loadCurrentEntry(); }); } }

  void _startNewEntry() {
    _saveNow();
    setState(() { _contentController.clear(); _editingEntryId = null; _hasUnsavedChanges = false; });
  }

  Future<void> _pickGroup() async {
    final groups = await db.getAllGroups();
    final selected = await showModalBottomSheet<int>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(padding: const EdgeInsets.all(12), child: Row(children: [
            const Text('选择分组', style: TextStyle(fontWeight: FontWeight.bold)), const Spacer(),
            IconButton(icon: const Icon(Icons.add), onPressed: () async {
              final ctrl = TextEditingController();
              final name = await showDialog<String>(context: ctx, builder: (dctx) => AlertDialog(
                title: const Text('新建分组'), content: TextField(controller: ctrl, autofocus: true, decoration: const InputDecoration(hintText: '分组名称')),
                actions: [TextButton(onPressed: () => Navigator.pop(dctx), child: const Text('取消')), TextButton(onPressed: () => Navigator.pop(dctx, ctrl.text), child: const Text('确定'))],
              ));
              if (name != null && name.trim().isNotEmpty) { await db.createGroup(GroupsCompanion(name: Value(name.trim()))); ref.invalidate(allGroupsProvider); if (ctx.mounted) Navigator.pop(ctx); }
            }),
          ])),
          ...groups.map((g) => ListTile(leading: Icon(Icons.folder, color: _currentGroupId == g.id ? Colors.lightBlue : null), title: Text(g.name), trailing: _currentGroupId == g.id ? const Icon(Icons.check, color: Colors.lightBlue) : null, onTap: () => Navigator.pop(ctx, g.id))),
        ]),
      ),
    );
    if (selected != null && selected != _currentGroupId && mounted) {
      setState(() => _currentGroupId = selected);
      if (_editingEntryId != null) { await db.updateEntry(_editingEntryId!, EntriesCompanion(groupId: Value(selected), updatedAt: Value(DateTime.now()))); ref.invalidate(allEntriesProvider); }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateStr = '${_currentDate.year}年${_currentDate.month}月${_currentDate.day}日';
    final renderSettings = ref.watch(renderingSettingsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Column(children: [Text(dateStr), if (_currentEntries.length > 1) Text('${_currentEntryIndex + 1}/${_currentEntries.length}', style: const TextStyle(fontSize: 12))]),
        actions: [
          IconButton(icon: const Icon(Icons.folder), tooltip: '分组', onPressed: _pickGroup),
          TextButton.icon(
            onPressed: () {
              final goingToPreview = _editorMode == EditorMode.source;
              setState(() { _editorMode = goingToPreview ? EditorMode.preview : EditorMode.source; });
              if (goingToPreview && _contentController.text.trim().isNotEmpty) { _saveTimer?.cancel(); _saveNow(); }
            },
            icon: Icon(_editorMode == EditorMode.source ? Icons.visibility : Icons.edit),
            label: Text(_editorMode == EditorMode.source ? '预览' : '编辑'),
          ),
          if (_currentEntries.length > 1) ...[
            IconButton(icon: const Icon(Icons.arrow_upward), onPressed: _goToPreviousEntry),
            IconButton(icon: const Icon(Icons.arrow_downward), onPressed: _goToNextEntry),
          ],
        ],
      ),
      body: GestureDetector(
        onHorizontalDragEnd: (details) {
          if (details.primaryVelocity != null) {
            if (details.primaryVelocity! < -50) { _goToNextDate(); } else if (details.primaryVelocity! > 50) { _goToPreviousDate(); }
          }
        },
        child: Column(children: [
          if (_editingEntryId != null) TagEditor(key: ValueKey(_editingEntryId), entryId: _editingEntryId!),
          const Divider(height: 1),
          Expanded(child: MarkdownEditor(
            controller: _contentController, externalMode: _editorMode,
            titleSize: renderSettings.titleSize, bodySize: renderSettings.bodySize,
            onToggleMode: () { setState(() { _editorMode = _editorMode == EditorMode.source ? EditorMode.preview : EditorMode.source; }); },
            onChanged: (_) => _scheduleSave(),
            onInsertImage: _editingEntryId != null ? () async => ImageService().pickAndSaveImage(ref, _editingEntryId!) : null,
          )),
        ]),
      ),
      floatingActionButton: FloatingActionButton(onPressed: _startNewEntry, tooltip: '补记', child: const Icon(Icons.add)),
    );
  }
}
