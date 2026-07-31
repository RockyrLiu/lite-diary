import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull, Column;

import '../database/database.dart';
import '../providers/database_provider.dart';
import '../providers/tag_provider.dart';

class TagEditor extends ConsumerStatefulWidget {
  final int entryId;
  final bool readOnly;

  const TagEditor({super.key, required this.entryId, this.readOnly = false});

  @override
  ConsumerState<TagEditor> createState() => _TagEditorState();
}

class _TagEditorState extends ConsumerState<TagEditor> {
  final TextEditingController _controller = TextEditingController();
  List<Tag> _entryTags = [];
  List<Tag> _allTags = [];
  List<Tag> _suggestions = [];

  AppDatabase get db => ref.read(databaseProvider);

  @override
  void dispose() { _controller.dispose(); super.dispose(); }

  Future<void> _loadTags() async {
    final entryTags = await db.getTagsForEntry(widget.entryId);
    final allTags = await db.getAllTags();
    if (mounted) setState(() { _entryTags = entryTags; _allTags = allTags; });
  }

  void _onTextChanged(String text) {
    if (text.isEmpty) { setState(() => _suggestions = []); return; }
    setState(() {
      _suggestions = _allTags.where((t) => t.name.contains(text) && !_entryTags.any((et) => et.id == t.id)).toList();
    });
  }

  Future<void> _addTag(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;

    var tag = await db.getTagByName(trimmed);
    if (tag == null) {
      final tagId = await db.createTag(TagsCompanion(name: Value(trimmed)));
      tag = await db.getTagById(tagId);
      ref.invalidate(allTagsProvider);
    }

    if (tag != null && !_entryTags.any((t) => t.id == tag!.id)) {
      await db.attachTag(widget.entryId, tag.id);
      ref.invalidate(tagsForEntryProvider(widget.entryId));
      await _loadTags();
    }

    _controller.clear();
    if (mounted) setState(() => _suggestions = []);
  }

  Future<void> _removeTag(Tag tag) async {
    await db.detachTag(widget.entryId, tag.id);
    ref.invalidate(tagsForEntryProvider(widget.entryId));
    await _loadTags();
  }

  @override
  void initState() {
    super.initState();
    _loadTags();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(mainAxisSize: MainAxisSize.min, children: [
      if (_entryTags.isNotEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Wrap(spacing: 6, runSpacing: 4, children: _entryTags.map((tag) {
            return Chip(
              label: Text(tag.name, style: const TextStyle(fontSize: 12)),
              deleteIcon: widget.readOnly ? null : const Icon(Icons.close, size: 16),
              onDeleted: widget.readOnly ? null : () => _removeTag(tag),
              backgroundColor: colorScheme.primaryContainer.withValues(alpha: 0.71),
              side: BorderSide.none,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            );
          }).toList()),
        ),
      if (!widget.readOnly) ...[
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        child: TextField(
          controller: _controller,
          onChanged: _onTextChanged,
          onSubmitted: _addTag,
          decoration: const InputDecoration(hintText: '添加标签...', border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.symmetric(vertical: 4)),
          style: const TextStyle(fontSize: 14),
        ),
      ),
      if (_suggestions.isNotEmpty)
        SizedBox(
          height: 36,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _suggestions.length,
            itemBuilder: (context, index) {
              final tag = _suggestions[index];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: ActionChip(
                  label: Text(tag.name, style: const TextStyle(fontSize: 12)),
                  onPressed: () => _addTag(tag.name),
                  backgroundColor: colorScheme.secondaryContainer.withValues(alpha: 0.47),
                  side: BorderSide.none,
                  visualDensity: VisualDensity.compact,
                ),
              );
            },
          ),
        ),
      ],
    ]);
  }
}
