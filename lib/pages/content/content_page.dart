import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull, Column;
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  int _diaryGroupId = 1;
  EditorMode _editorMode = EditorMode.preview;
  bool _hasUnsavedChanges = false;
  bool _slideForward = true;
  String? _modifiedTime;
  String _weather = '';
  String _location = '';
  final List<String> _pendingTags = [];
  bool _isSaving = false;

  AppDatabase get db => ref.read(databaseProvider);

  String? _extractTitle(String content) {
    final firstLine = content.split('\n').first.trim();
    if (firstLine.startsWith('#') && firstLine.length > 1) {
      final title = firstLine.replaceFirst(RegExp(r'^#+\s*'), '');
      return title.isEmpty ? null : title;
    }
    return null;
  }

  String _computeHash(DateTime date, String content) {
    final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    return sha256.convert(utf8.encode('$dateStr|$content')).toString();
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

    final groups = await db.getAllGroups();
    final diaryGroup = groups.firstWhere(
      (g) => g.name == '日记',
      orElse: () => groups.isNotEmpty ? groups.first : Group(id: 1, name: '日记', sortOrder: 0),
    );
    _diaryGroupId = diaryGroup.id;
    _currentGroupId = _diaryGroupId;

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
      if (entries.isEmpty) _autoLocate();
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
    if (!_hasUnsavedChanges || _isSaving) return;
    _isSaving = true;
    final content = _contentController.text.trim();
    if (content.isEmpty) {
      if (_editingEntryId != null) {
        await db.deleteEntry(_editingEntryId!);
        SharedPreferences.getInstance()
            .then((p) => p.remove('cloud_sync_hash'));
        _editingEntryId = null;
        final refreshedEntries = await db.getEntriesByDate(_currentDate);
        if (mounted) {
          setState(() {
            _currentEntries = refreshedEntries;
            _currentEntryIndex = 0;
          });
          _loadCurrentEntry();
        }
      }
      _hasUnsavedChanges = false;
      _isSaving = false;
      ref.invalidate(entriesByDateProvider(_currentDate));
      ref.invalidate(allEntriesProvider);
      ref.invalidate(calendarDateCountsProvider);
      return;
    }
    final title = _extractTitle(content) ??
        '${_currentDate.year}年${_currentDate.month}月${_currentDate.day}日';
    final now = DateTime.now();
    if (_editingEntryId != null) {
      final hash = _computeHash(_currentDate, content);
      await db.updateEntry(_editingEntryId!, EntriesCompanion(
        title: Value(title), content: Value(content), updatedAt: Value(now),
        weather: Value(_weather.isEmpty ? null : _weather),
        location: Value(_location.isEmpty ? null : _location),
        hash: Value(hash),
      ));
      await _attachPendingTags(_editingEntryId!);
    } else {
      final hash = _computeHash(_currentDate, content);
      final newId = await db.createEntry(EntriesCompanion(
        title: Value(title), date: Value(_currentDate), content: Value(content),
        groupId: Value(_currentGroupId), createdAt: Value(now), updatedAt: Value(now),
        weather: Value(_weather.isEmpty ? null : _weather),
        location: Value(_location.isEmpty ? null : _location),
        hash: Value(hash),
      ));
      if (mounted) {
        final refreshedEntries = await db.getEntriesByDate(_currentDate);
        if (mounted) {
          final newIndex = refreshedEntries.indexWhere((e) => e.id == newId);
          setState(() {
            _editingEntryId = newId;
            _currentEntries = refreshedEntries;
            _currentEntryIndex = newIndex >= 0 ? newIndex : refreshedEntries.length - 1;
          });
        }
      }
      await _attachPendingTags(newId);
    }
    _hasUnsavedChanges = false;
    _modifiedTime = _timeStr(now);
    _isSaving = false;
    ref.invalidate(entriesByDateProvider(_currentDate));
    ref.invalidate(allEntriesProvider);
    ref.invalidate(calendarDateCountsProvider);
  }

  Future<void> _refreshCurrentEntry() async {
    _saveTimer?.cancel();
    await _saveNow();
    final refreshedEntries = await db.getEntriesByDate(_currentDate);
    if (!mounted) return;
    setState(() {
      _currentEntries = refreshedEntries;
      if (_currentEntries.isEmpty) {
        _currentEntryIndex = 0;
      } else if (_currentEntryIndex >= refreshedEntries.length) {
        _currentEntryIndex = refreshedEntries.length - 1;
      }
    });
    _loadCurrentEntry();
    ref.invalidate(entriesByDateProvider(_currentDate));
    ref.invalidate(allEntriesProvider);
    ref.invalidate(calendarDateCountsProvider);
  }

  void _loadCurrentEntry() {
    if (_currentEntries.isNotEmpty && _currentEntryIndex < _currentEntries.length) {
      final entry = _currentEntries[_currentEntryIndex];
      _contentController.text = entry.content;
      _editingEntryId = entry.id;
      _currentGroupId = entry.groupId;
      _hasUnsavedChanges = false;
      _modifiedTime = _timeStr(entry.updatedAt);
      _weather = entry.weather ?? '';
      _location = entry.location ?? '';
    } else {
      _contentController.clear();
      _editingEntryId = null;
      _currentGroupId = _diaryGroupId;
      _hasUnsavedChanges = false;
      _pendingTags.clear();
      _modifiedTime = null;
      _weather = '';
      _location = '';
    }
  }

  Future<void> _goToDate(DateTime date, bool forward) async {
    await _saveNow();
    _slideForward = forward;
    final entries = await db.getEntriesByDate(date);
    if (!mounted) return;
    setState(() {
      _currentDate = date;
      _currentEntries = entries;
      _currentEntryIndex = 0;
      _editingEntryId = null;
    });
    _loadCurrentEntry();
    if (entries.isEmpty) _autoLocate();
  }

  Future<void> _goToNextDate() async {
    await _saveNow();
    final entries = await db.getAllEntries();
    final dates = entries.map((e) => DateTime(e.date.year, e.date.month, e.date.day)).toSet().toList()..sort();
    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    if (!dates.any((d) => d == today)) dates.add(today);
    dates.sort();
    final currentKey = DateTime(_currentDate.year, _currentDate.month, _currentDate.day);
    final nextDate = dates.firstWhere((d) => d.isAfter(currentKey), orElse: () => _currentDate);
    if (nextDate != _currentDate) await _goToDate(nextDate, true);
  }

  Future<void> _goToPreviousDate() async {
    await _saveNow();
    final entries = await db.getAllEntries();
    final dates = entries.map((e) => DateTime(e.date.year, e.date.month, e.date.day)).toSet().toList()..sort();
    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    if (!dates.any((d) => d == today)) dates.add(today);
    dates.sort();
    final currentKey = DateTime(_currentDate.year, _currentDate.month, _currentDate.day);
    final prevDate = dates.reversed.firstWhere((d) => d.isBefore(currentKey), orElse: () => _currentDate);
    if (prevDate != _currentDate) await _goToDate(prevDate, false);
  }

  Future<void> _goToNextEntry() async { await _saveNow(); if (_currentEntryIndex < _currentEntries.length - 1) { setState(() { _currentEntryIndex++; _loadCurrentEntry(); }); } }
  Future<void> _goToPreviousEntry() async { await _saveNow(); if (_currentEntryIndex > 0) { setState(() { _currentEntryIndex--; _loadCurrentEntry(); }); } }

  Future<void> _startNewEntry() async {
    await _saveNow();
    setState(() { _contentController.clear(); _editingEntryId = null; _currentGroupId = _diaryGroupId; _hasUnsavedChanges = false; });
    _pendingTags.clear();
    _weather = '';
    _location = '';
    _autoLocate();
  }

  String _timeStr(DateTime t) {
    final hm = '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    if (t.year == _currentDate.year && t.month == _currentDate.month && t.day == _currentDate.day) {
      return hm;
    }
    final md = '${t.month.toString().padLeft(2, '0')}/${t.day.toString().padLeft(2, '0')}';
    if (t.year == _currentDate.year) return '$md $hm';
    return '${t.year}/$md $hm';
  }

  int get _wordCount {
    var text = _contentController.text;
    text = text.replaceAll(RegExp(r'!\[.*?\]\(.*?\)'), '');
    text = text.replaceAll(RegExp(r'^#{1,6}\s', multiLine: true), '');
    text = text.replaceAll(RegExp(r'\*\*([^*]+)\*\*'), r'$1');
    text = text.replaceAll(RegExp(r'\*([^*]+)\*'), r'$1');
    text = text.replaceAll(RegExp(r'~~([^~]+)~~'), r'$1');
    text = text.replaceAll(RegExp(r'`([^`]+)`'), r'$1');
    text = text.replaceAll(RegExp(r'\s'), '');
    return text.length;
  }

  Future<String> _fetchLocation() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission != LocationPermission.whileInUse &&
            permission != LocationPermission.always) {
          return '';
        }
      }
      if (permission == LocationPermission.deniedForever) return '';

      final position = await Geolocator.getCurrentPosition(
          locationSettings: AndroidSettings(
              accuracy: LocationAccuracy.high, timeLimit: const Duration(seconds: 10)));
      final placemarks = await placemarkFromCoordinates(
          position.latitude, position.longitude);
      if (placemarks.isEmpty) return '';
      final p = placemarks.first;
      return [p.locality, p.subLocality].where((e) => e != null && e.isNotEmpty).join('');
    } catch (_) {
      return '';
    }
  }

  Future<void> _autoLocate() async {
    final loc = await _fetchLocation();
    if (loc.isNotEmpty && mounted) {
      setState(() => _location = loc);
    }
  }

  void _editMeta() {
    final weatherCtrl = TextEditingController(text: _weather);
    final locationCtrl = TextEditingController(text: _location);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('天气 / 地点'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Wrap(
              spacing: 6,
              children: ['晴', '多云', '阴', '雨', '雪', '雾', '风'].map((w) {
                return ActionChip(
                  label: Text(w, style: const TextStyle(fontSize: 13)),
                  onPressed: () => weatherCtrl.text = w,
                  visualDensity: VisualDensity.compact,
                );
              }).toList(),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: weatherCtrl,
              decoration: const InputDecoration(labelText: '天气', isDense: true, border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: locationCtrl,
                    decoration: const InputDecoration(labelText: '地点', isDense: true, border: OutlineInputBorder()),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.my_location, size: 20),
                  tooltip: '获取位置',
                  onPressed: () async {
                    locationCtrl.text = '定位中...';
                    final loc = await _fetchLocation();
                    locationCtrl.text = loc.isEmpty ? '定位失败' : loc;
                  },
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(
            onPressed: () async {
              final w = weatherCtrl.text.trim();
              final l = locationCtrl.text.trim();
              Navigator.pop(ctx);
              if (mounted) {
                setState(() {
                  _weather = w;
                  _location = l;
                });
                // 同步更新内存中的条目对象，防止 loadCurrentEntry 覆盖
                if (_editingEntryId != null &&
                    _currentEntries.isNotEmpty &&
                    _currentEntryIndex < _currentEntries.length) {
                  final idx = _currentEntries.indexWhere((e) => e.id == _editingEntryId);
                  if (idx >= 0) {
                    _currentEntries[idx] = _currentEntries[idx].copyWith(
                      weather: Value<String?>(w.isEmpty ? null : w),
                      location: Value<String?>(l.isEmpty ? null : l),
                    );
                  }
                }
                if (_editingEntryId != null) {
                  final now = DateTime.now();
                  await db.updateEntry(_editingEntryId!, EntriesCompanion(
                    weather: Value(w.isEmpty ? null : w),
                    location: Value(l.isEmpty ? null : l),
                    updatedAt: Value(now),
                  ));
                  _modifiedTime = _timeStr(now);
                } else {
                  _hasUnsavedChanges = true;
                }
              }
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickGroup() async {
    final groups = await db.getAllGroups();
    if (!mounted) return;
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

  Widget _buildStatusBar() {
    final parts = <String>[
      if (_editingEntryId != null) '$_wordCount字',
      ?_modifiedTime,
    ];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: GestureDetector(
        onTap: _editorMode == EditorMode.source ? _editMeta : null,
        child: Row(
          children: [
            Text(parts.join('  '),
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
            if (_location.isNotEmpty) ...[
              const SizedBox(width: 8),
              Text(_location,
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
            ],
            if (_weather.isNotEmpty) ...[
              const SizedBox(width: 8),
              Text(_weather,
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
            ],
            const Spacer(),
          ],
        ),
      ),
    );
  }

  Widget _buildContentPane(RenderingSettings renderSettings) {
    if (_currentEntries.isEmpty && _editingEntryId == null && _isToday(_currentDate) && _editorMode != EditorMode.source) {
      return const Column(children: [
        Expanded(
          child: Center(
              child: Text('今日无事',
                  style: TextStyle(fontSize: 16, color: Colors.grey))),
        ),
      ]);
    }
    return Column(children: [
      if (_editorMode == EditorMode.source) ...[
        if (_editingEntryId != null)
          TagEditor(key: ValueKey(_editingEntryId), entryId: _editingEntryId!, readOnly: false)
        else
          _buildPendingTags(),
      ] else ...[
        if (_editingEntryId != null)
          TagEditor(key: ValueKey(_editingEntryId), entryId: _editingEntryId!, readOnly: true)
      ],
      Expanded(child: MarkdownEditor(
        controller: _contentController, externalMode: _editorMode,
        titleSize: renderSettings.titleSize, bodySize: renderSettings.bodySize,
        onChanged: (_) => _scheduleSave(),
        onInsertImage: _editingEntryId != null ? () async => ImageService().pickAndSaveImage(ref, _editingEntryId!) : null,
      )),
    ]);
  }

  Widget _buildPendingTags() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_pendingTags.isNotEmpty)
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: _pendingTags
                  .map((tag) => Chip(
                        label: Text(tag, style: const TextStyle(fontSize: 12)),
                        deleteIcon: const Icon(Icons.close, size: 16),
                        onDeleted: () =>
                            setState(() => _pendingTags.remove(tag)),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                      ))
                  .toList(),
            ),
          SizedBox(
            height: 36,
            child: TextField(
              decoration: const InputDecoration(
                hintText: '输入标签名，回车添加',
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 8),
                isDense: true,
              ),
              style: const TextStyle(fontSize: 13),
              onSubmitted: (value) {
                final name = value.trim();
                if (name.isNotEmpty && !_pendingTags.contains(name)) {
                  setState(() => _pendingTags.add(name));
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  bool _isToday(DateTime d) {
    final now = DateTime.now();
    return d.year == now.year && d.month == now.month && d.day == now.day;
  }

  String _dateStr(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  bool _parseDate(String s) {
    final parts = s.split('-');
    if (parts.length != 3) return false;
    final y = int.tryParse(parts[0]), m = int.tryParse(parts[1]), d2 = int.tryParse(parts[2]);
    return y != null && m != null && d2 != null && m >= 1 && m <= 12 && d2 >= 1 && d2 <= 31;
  }

  Future<void> _pickDate() async {
    final ctrl = TextEditingController(text: _dateStr(_currentDate));
    String? errorText;

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('跳转到指定日期'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: ctrl,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: '2024-01-01',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              if (errorText != null) ...[
                const SizedBox(height: 8),
                Text(errorText!, style: TextStyle(color: Colors.red.shade700, fontSize: 13)),
              ],
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
            FilledButton(
              onPressed: () {
                final text = ctrl.text.trim();
                if (!_parseDate(text)) {
                  setDialogState(() => errorText = '日期格式错误，请使用 yyyy-MM-dd');
                  return;
                }
                Navigator.pop(ctx, text);
              },
              child: const Text('确定'),
            ),
          ],
        ),
      ),
    );
    if (result != null && mounted) {
      final parts = result.split('-');
      final target = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
      await _goToDate(target, target.isAfter(_currentDate));
    }
  }

  Future<void> _attachPendingTags(int entryId) async {
    if (_pendingTags.isEmpty) return;
    for (final tagName in _pendingTags) {
      var tag = await db.getTagByName(tagName);
      if (tag == null) {
        final tagId = await db.createTag(TagsCompanion(name: Value(tagName)));
        tag = await db.getTagById(tagId);
      }
      if (tag != null) {
        await db.attachTag(entryId, tag.id);
      }
    }
    _pendingTags.clear();
  }

  @override
  Widget build(BuildContext context) {
    final dateStr = '${_currentDate.year}年${_currentDate.month}月${_currentDate.day}日';
    final renderSettings = ref.watch(renderingSettingsProvider);

    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          onTap: _pickDate,
          behavior: HitTestBehavior.opaque,
          child: Column(children: [
            Row(mainAxisSize: MainAxisSize.min, children: [
              Text(dateStr, style: const TextStyle(fontWeight: FontWeight.bold)),
            ]),
            if (_currentEntries.length > 1) Text('${_currentEntryIndex + 1}/${_currentEntries.length}', style: const TextStyle(fontSize: 12)),
          ]),
        ),
        actions: [
          if (_currentEntries.length > 1) ...[
            IconButton(icon: const Icon(Icons.arrow_upward), onPressed: _goToPreviousEntry),
            IconButton(icon: const Icon(Icons.arrow_downward), onPressed: _goToNextEntry),
          ],
          IconButton(icon: const Icon(Icons.folder), tooltip: '分组', onPressed: _pickGroup),
          IconButton(
            icon: Icon(_editorMode == EditorMode.source ? Icons.visibility : Icons.edit),
            tooltip: _editorMode == EditorMode.source ? '渲染' : '编辑',
            onPressed: () async {
              final goingToPreview = _editorMode == EditorMode.source;
              if (goingToPreview) {
                _saveTimer?.cancel();
                await _saveNow();
              }
              if (!mounted) return;
              setState(() { _editorMode = goingToPreview ? EditorMode.preview : EditorMode.source; });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refreshCurrentEntry,
              notificationPredicate: _editorMode == EditorMode.preview
                  ? defaultScrollNotificationPredicate
                  : (_) => false,
              child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragEnd: (details) {
          if (_editorMode == EditorMode.source) return;
          if (details.primaryVelocity != null) {
            if (details.primaryVelocity! < -50) { _goToNextDate(); } else if (details.primaryVelocity! > 50) { _goToPreviousDate(); }
          }
        },
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          transitionBuilder: (child, animation) {
            return SlideTransition(
              position: Tween<Offset>(
                begin: Offset(_slideForward ? 1 : -1, 0),
                end: Offset.zero,
              ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
              child: child,
            );
          },
          child: KeyedSubtree(
            key: ValueKey(_currentDate),
            child: _buildContentPane(renderSettings),
          ),
        ),
      ),
      ),
    ),
    _buildStatusBar(),
      ],
    ),
      floatingActionButton: FloatingActionButton(
        onPressed: _startNewEntry,
        tooltip: '补记',
        backgroundColor: Color.lerp(Theme.of(context).colorScheme.primary, Colors.white, 0.6)!,
        child: const Icon(Icons.add),
      ),
    );
  }
}
