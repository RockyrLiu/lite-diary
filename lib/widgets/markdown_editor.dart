import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

enum EditorMode { source, preview }

class MarkdownEditor extends StatefulWidget {
  final TextEditingController? controller;
  final void Function(String value)? onChanged;
  final String? initialValue;
  final Future<String?> Function()? onInsertImage;
  final EditorMode? externalMode;
  final double titleSize;
  final double bodySize;

  const MarkdownEditor({
    super.key,
    this.controller,
    this.onChanged,
    this.initialValue,
    this.onInsertImage,
    this.externalMode,
    this.titleSize = 24,
    this.bodySize = 16,
  });

  @override
  State<MarkdownEditor> createState() => _MarkdownEditorState();
}

class _MarkdownEditorState extends State<MarkdownEditor> {
  late final TextEditingController _controller;
  EditorMode _mode = EditorMode.source;

  @override
  void initState() {
    super.initState();
    _mode = widget.externalMode ?? EditorMode.source;
    _controller = widget.controller ?? TextEditingController(text: widget.initialValue ?? '');
    _controller.addListener(_onTextChanged);
  }

  @override
  void didUpdateWidget(covariant MarkdownEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.externalMode != null && widget.externalMode != _mode) {
      setState(() => _mode = widget.externalMode!);
    }
  }

  @override
  void dispose() {
    if (widget.controller == null) {
      _controller.dispose();
    }
    super.dispose();
  }

  void _onTextChanged() {
    widget.onChanged?.call(_controller.text);
  }

  void _insertMarkdown(String prefix, String suffix) {
    final text = _controller.text;
    final selection = _controller.selection;

    if (selection.isValid && selection.start != selection.end) {
      final selected = selection.textInside(text);
      final newText = text.replaceRange(selection.start, selection.end, '$prefix$selected$suffix');
      _controller.text = newText;
      _controller.selection = TextSelection.collapsed(
        offset: selection.start + prefix.length + selected.length,
      );
    } else {
      final cursorPos = selection.baseOffset;
      final newText = text.replaceRange(
        cursorPos,
        cursorPos,
        '$prefix$suffix',
      );
      _controller.text = newText;
      _controller.selection = TextSelection.collapsed(
        offset: cursorPos + prefix.length,
      );
    }
    widget.onChanged?.call(_controller.text);
  }

  void _insertLink() {
    final text = _controller.text;
    final cursorPos = _controller.selection.baseOffset;
    final newText = text.replaceRange(
      cursorPos,
      cursorPos,
      '[链接文字](https://)',
    );
    _controller.text = newText;
    _controller.selection = TextSelection(
      baseOffset: cursorPos + 1,
      extentOffset: cursorPos + 5,
    );
    widget.onChanged?.call(_controller.text);
  }

  Future<void> _insertImage() async {
    if (widget.onInsertImage != null) {
      final imagePath = await widget.onInsertImage!();
      if (imagePath != null && imagePath.isNotEmpty) {
        final text = _controller.text;
        final cursorPos = _controller.selection.baseOffset;
        final newText = text.replaceRange(cursorPos, cursorPos, '![]($imagePath)');
        _controller.text = newText;
        _controller.selection = TextSelection.collapsed(offset: cursorPos + imagePath.length + 4);
        widget.onChanged?.call(_controller.text);
      }
      return;
    }
    final text = _controller.text;
    final cursorPos = _controller.selection.baseOffset;
    final newText = text.replaceRange(
      cursorPos,
      cursorPos,
      '![图片描述](图片路径)',
    );
    _controller.text = newText;
    _controller.selection = TextSelection(
      baseOffset: cursorPos + 2,
      extentOffset: cursorPos + 6,
    );
    widget.onChanged?.call(_controller.text);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildToolbar(),
        Expanded(child: _mode == EditorMode.source ? _buildSourceView() : _buildPreview()),
      ],
    );
  }

  Widget _buildToolbar() {
    if (_mode == EditorMode.preview) {
      return const SizedBox.shrink();
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _toolbarButton(Icons.format_bold, () => _insertMarkdown('**', '**'), '加粗'),
          _toolbarButton(Icons.format_italic, () => _insertMarkdown('*', '*'), '斜体'),
          _toolbarButton(Icons.format_strikethrough, () => _insertMarkdown('~~', '~~'), '删除线'),
          _toolbarButton(Icons.title, () => _insertMarkdown('# ', ''), '标题'),
          _toolbarButton(Icons.format_list_bulleted, () => _insertMarkdown('- ', ''), '无序列表'),
          _toolbarButton(Icons.format_list_numbered, () => _insertMarkdown('1. ', ''), '有序列表'),
          _toolbarButton(Icons.code, () => _insertMarkdown('`', '`'), '行内代码'),
          _toolbarButton(Icons.link, _insertLink, '链接'),
          _toolbarButton(Icons.image, _insertImage, '图片'),
        ],
      ),
    );
  }

  Widget _toolbarButton(IconData icon, VoidCallback onPressed, String tooltip) {
    return IconButton(
      icon: Icon(icon, size: 20),
      tooltip: tooltip,
      onPressed: onPressed,
      constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
    );
  }

  Widget _buildSourceView() {
    return TextField(
      controller: _controller,
      maxLines: null,
      expands: true,
      textAlignVertical: TextAlignVertical.top,
      decoration: const InputDecoration(
        border: InputBorder.none,
        contentPadding: EdgeInsets.all(12),
        hintText: '开始写日记...',
      ),
      style: const TextStyle(fontSize: 16, height: 1.6),
    );
  }

  Widget _buildPreview() {
    return Markdown(
      data: _controller.text,
      selectable: true,
      padding: const EdgeInsets.all(12),
      styleSheet: MarkdownStyleSheet(
        h1: TextStyle(fontSize: widget.titleSize, fontWeight: FontWeight.bold),
        h2: TextStyle(fontSize: widget.titleSize - 2, fontWeight: FontWeight.bold),
        h3: TextStyle(fontSize: widget.titleSize - 4, fontWeight: FontWeight.bold),
        p: TextStyle(fontSize: widget.bodySize, height: 1.6),
      ),
    );
  }
}
