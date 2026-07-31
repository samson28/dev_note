// Material is imported for TextField/InputDecoration/SelectableText only —
// the visual language comes entirely from JotTheme, not from Material.
import 'package:flutter/material.dart';

import '../core/models/note.dart';
import '../core/models/note_type.dart';
import '../core/theme/jot_theme.dart';
import 'code_viewer.dart';
import 'json_viewer.dart';

/// The note body panel: the bordered `#1A1B1F` box with the `arbre` / `brut`
/// header, holding whichever viewer suits the note's type.
///
/// The rendered view is the default because recognising a note at a glance is
/// the whole point; `brut` is a live editor, one click away, so correcting a
/// value never costs more than that.
class NoteBody extends StatefulWidget {
  const NoteBody({
    super.key,
    required this.note,
    required this.onChanged,
    this.fontSize = 12.5,
    this.showLineNumbers = true,
    this.framed = true,
  });

  final Note note;
  final ValueChanged<String> onChanged;
  final double fontSize;
  final bool showLineNumbers;

  /// Mobile drops the header strip and keeps just the panel.
  final bool framed;

  @override
  State<NoteBody> createState() => _NoteBodyState();
}

class _NoteBodyState extends State<NoteBody> {
  final _jsonKey = GlobalKey<JsonViewerState>();
  late TextEditingController _controller;
  late FocusNode _focus;

  /// Prose is edited directly — there is nothing to render differently, and
  /// making the user click "brut" first would be pure friction.
  bool get _alwaysRaw => widget.note.type == NoteType.text;

  bool _raw = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.note.content);
    _focus = FocusNode();
  }

  @override
  void didUpdateWidget(NoteBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.note.id != widget.note.id) {
      _controller.text = widget.note.content;
      _raw = false;
    } else if (!_focus.hasFocus && widget.note.content != _controller.text) {
      // An external edit landed via the watcher while we were not typing.
      _controller.text = widget.note.content;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _enterRaw() {
    setState(() => _raw = true);
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  @override
  Widget build(BuildContext context) {
    final showRaw = _raw || _alwaysRaw;

    final panel = Container(
      decoration: BoxDecoration(
        color: JotColors.codePanel,
        border: Border.all(color: JotColors.borderEditor),
        borderRadius: BorderRadius.circular(widget.framed ? 8 : 9),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.framed && !_alwaysRaw)
            ViewerHeader(
              rawMode: showRaw,
              onModeChanged: (raw) => raw ? _enterRaw() : setState(() => _raw = false),
              onExpandAll: widget.note.type == NoteType.json
                  ? () => _jsonKey.currentState?.expandAll()
                  : null,
              onCollapseAll: widget.note.type == NoteType.json
                  ? () => _jsonKey.currentState?.collapseAll()
                  : null,
            ),
          Expanded(child: showRaw ? _buildEditor() : _buildRendered()),
        ],
      ),
    );

    return panel;
  }

  Widget _buildRendered() {
    final content = widget.note.content;

    final Widget child = switch (widget.note.type) {
      NoteType.json => JsonViewer(
          key: _jsonKey,
          source: content,
          showLineNumbers: widget.showLineNumbers,
          fontSize: widget.fontSize,
        ),
      NoteType.code => CodeViewer(
          source: content,
          showLineNumbers: widget.showLineNumbers,
          fontSize: widget.fontSize,
        ),
      NoteType.url => _UrlView(url: content, fontSize: widget.fontSize),
      NoteType.text => const SizedBox.shrink(),
    };

    // A double-click anywhere in the rendered body drops straight into the
    // editor at the same scroll position.
    return GestureDetector(
      onDoubleTap: _enterRaw,
      behavior: HitTestBehavior.translucent,
      child: child,
    );
  }

  Widget _buildEditor() => Padding(
        padding: EdgeInsets.fromLTRB(widget.framed ? 16 : 12, 12, 12, 12),
        child: TextField(
          controller: _controller,
          focusNode: _focus,
          onChanged: widget.onChanged,
          maxLines: null,
          expands: true,
          cursorColor: JotColors.accent,
          cursorWidth: 1.5,
          style: widget.note.type == NoteType.text
              ? JotText.ui(size: 13, height: 1.7, color: JotColors.textPrimary)
              : JotText.mono(size: widget.fontSize, height: 1.85, color: JotColors.textPrimary),
          decoration: InputDecoration(
            border: InputBorder.none,
            isCollapsed: true,
            hintText: 'Note rapide...',
            hintStyle: JotText.ui(size: 12.5, height: 1.5, color: JotColors.textDisabled),
          ),
        ),
      );
}

/// A URL note: the address in the accent colour on its own, since that is the
/// entire content.
class _UrlView extends StatelessWidget {
  const _UrlView({required this.url, required this.fontSize});

  final String url;
  final double fontSize;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Align(
          alignment: Alignment.topLeft,
          child: SelectableText(
            url.trim(),
            style: JotText.mono(
              size: fontSize,
              height: 1.85,
              color: JotColors.accent,
            ),
          ),
        ),
      );
}
