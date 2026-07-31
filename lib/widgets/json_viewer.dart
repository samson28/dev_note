import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart' show SelectableText;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../core/theme/jot_theme.dart';
import 'jot_primitives.dart';

/// Collapsible JSON tree, reproducing the `arbre` view in the design:
/// a 44px line-number gutter, 22px of indent per level, the five syntax
/// colours, and a shaded band behind the subtree under the cursor.
///
/// Falls back to the raw text when the content does not parse, so a note the
/// user typed as JSON but has not finished is still readable.
class JsonViewer extends StatefulWidget {
  const JsonViewer({
    super.key,
    required this.source,
    this.showLineNumbers = true,
    this.showCaret = true,
    this.indent = 22,
    this.fontSize = 12.5,
    this.padding = const EdgeInsets.symmetric(vertical: 12),
  });

  final String source;
  final bool showLineNumbers;

  /// The blinking accent caret the design parks after the closing brace.
  final bool showCaret;

  final double indent;
  final double fontSize;
  final EdgeInsets padding;

  /// Whether [source] can be rendered as a tree at all.
  static bool canParse(String source) {
    try {
      jsonDecode(source.trim());
      return true;
    } on Object {
      return false;
    }
  }

  @override
  State<JsonViewer> createState() => JsonViewerState();
}

class JsonViewerState extends State<JsonViewer> {
  /// Paths of branches the user has collapsed. Everything starts expanded,
  /// which is what the design shows.
  final Set<String> _collapsed = {};
  String? _hoveredBranch;
  Object? _decoded;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _decode();
  }

  @override
  void didUpdateWidget(JsonViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.source != widget.source) _decode();
  }

  void _decode() {
    try {
      _decoded = jsonDecode(widget.source.trim());
      _error = null;
    } on Object catch (e) {
      _decoded = null;
      _error = e;
    }
  }

  /// Wired to the "tout déplier" / "tout replier" affordances in the header.
  void expandAll() => setState(_collapsed.clear);

  void collapseAll() => setState(() {
        _collapsed.clear();
        _collectBranchPaths(_decoded, '\$', _collapsed);
      });

  static void _collectBranchPaths(Object? node, String path, Set<String> into) {
    if (node is Map) {
      // The root stays open — collapsing it would leave a single "{ ... }".
      if (path != '\$') into.add(path);
      for (final entry in node.entries) {
        _collectBranchPaths(entry.value, '$path.${entry.key}', into);
      }
    } else if (node is List) {
      if (path != '\$') into.add(path);
      for (var i = 0; i < node.length; i++) {
        _collectBranchPaths(node[i], '$path[$i]', into);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null || _decoded == null) {
      return _RawText(
        source: widget.source,
        fontSize: widget.fontSize,
        padding: widget.padding,
        showLineNumbers: widget.showLineNumbers,
      );
    }

    final rows = <_Row>[];
    _flatten(_decoded, depth: 0, path: '\$', key: null, trailing: '', into: rows);

    return SingleChildScrollView(
      padding: widget.padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < rows.length; i++)
            _RowView(
              row: rows[i],
              lineNumber: i + 1,
              showLineNumbers: widget.showLineNumbers,
              indent: widget.indent,
              fontSize: widget.fontSize,
              highlighted: _isUnderHover(rows[i]),
              bandTop: _bandEdge(rows, i, -1),
              bandBottom: _bandEdge(rows, i, 1),
              caret: widget.showCaret && i == rows.length - 1,
              onToggle: rows[i].branchPath == null
                  ? null
                  : () => setState(() {
                        final p = rows[i].branchPath!;
                        if (!_collapsed.remove(p)) _collapsed.add(p);
                      }),
              onHover: (hovering) {
                final owner = rows[i].ownerPath;
                if (hovering) {
                  if (_hoveredBranch != owner) setState(() => _hoveredBranch = owner);
                } else if (_hoveredBranch == owner) {
                  setState(() => _hoveredBranch = null);
                }
              },
            ),
        ],
      ),
    );
  }

  bool _isUnderHover(_Row row) {
    final hovered = _hoveredBranch;
    if (hovered == null || hovered == '\$') return false;
    return row.ownerPath == hovered || row.ownerPath.startsWith('$hovered.') ||
        row.ownerPath.startsWith('$hovered[');
  }

  /// True when the neighbouring row in [direction] is outside the shaded band,
  /// so this row should round that corner.
  bool _bandEdge(List<_Row> rows, int index, int direction) {
    if (!_isUnderHover(rows[index])) return false;
    final neighbour = index + direction;
    if (neighbour < 0 || neighbour >= rows.length) return true;
    return !_isUnderHover(rows[neighbour]);
  }

  void _flatten(
    Object? node, {
    required int depth,
    required String path,
    required String? key,
    required String trailing,
    required List<_Row> into,
  }) {
    final isMap = node is Map;
    final isList = node is List;

    if (!isMap && !isList) {
      into.add(_Row(
        depth: depth,
        key: key,
        value: _token(node),
        trailing: trailing,
        ownerPath: _parentOf(path),
      ));
      return;
    }

    final open = isMap ? '{' : '[';
    final close = isMap ? '}' : ']';
    final entries = isMap
        ? (node).entries.map((e) => ('${e.key}', e.value)).toList()
        : [for (var i = 0; i < (node as List).length; i++) (null, node[i])];

    final collapsed = _collapsed.contains(path);

    if (collapsed) {
      into.add(_Row(
        depth: depth,
        key: key,
        chevron: _Chevron.collapsed,
        branchPath: path,
        open: open,
        close: close,
        collapsedCount: entries.length,
        collapsedLabel: isMap
            ? '${entries.length} clé${entries.length > 1 ? 's' : ''}'
            : '${entries.length} élément${entries.length > 1 ? 's' : ''}',
        trailing: trailing,
        ownerPath: _parentOf(path),
      ));
      return;
    }

    into.add(_Row(
      depth: depth,
      key: key,
      chevron: _Chevron.expanded,
      branchPath: path,
      open: open,
      ownerPath: path,
    ));

    for (var i = 0; i < entries.length; i++) {
      final (childKey, childValue) = entries[i];
      _flatten(
        childValue,
        depth: depth + 1,
        path: childKey == null ? '$path[$i]' : '$path.$childKey',
        key: childKey,
        trailing: i == entries.length - 1 ? '' : ',',
        into: into,
      );
    }

    into.add(_Row(
      depth: depth,
      close: close,
      trailing: trailing,
      ownerPath: path,
    ));
  }

  static String _parentOf(String path) {
    final dot = path.lastIndexOf('.');
    final bracket = path.lastIndexOf('[');
    final cut = dot > bracket ? dot : bracket;
    return cut <= 0 ? '\$' : path.substring(0, cut);
  }

  static _Token _token(Object? value) => switch (value) {
        String s => _Token('"$s"', JotSyntax.string),
        num n => _Token('$n', JotSyntax.number),
        bool b => _Token('$b', JotSyntax.keyword),
        null => _Token('null', JotSyntax.keyword),
        _ => _Token('$value', JotSyntax.string),
      };
}

enum _Chevron { expanded, collapsed }

class _Token {
  const _Token(this.text, this.color);
  final String text;
  final Color color;
}

class _Row {
  const _Row({
    required this.depth,
    required this.ownerPath,
    this.key,
    this.value,
    this.chevron,
    this.branchPath,
    this.open,
    this.close,
    this.collapsedCount,
    this.collapsedLabel,
    this.trailing = '',
  });

  final int depth;

  /// Path of the branch this row visually belongs to — drives the hover band.
  final String ownerPath;

  final String? key;
  final _Token? value;
  final _Chevron? chevron;

  /// Non-null when the row can be expanded/collapsed.
  final String? branchPath;
  final String? open;
  final String? close;
  final int? collapsedCount;
  final String? collapsedLabel;
  final String trailing;
}

class _RowView extends StatelessWidget {
  const _RowView({
    required this.row,
    required this.lineNumber,
    required this.showLineNumbers,
    required this.indent,
    required this.fontSize,
    required this.highlighted,
    required this.bandTop,
    required this.bandBottom,
    required this.caret,
    required this.onToggle,
    required this.onHover,
  });

  final _Row row;
  final int lineNumber;
  final bool showLineNumbers;
  final double indent;
  final double fontSize;
  final bool highlighted;
  final bool bandTop;
  final bool bandBottom;
  final bool caret;
  final VoidCallback? onToggle;
  final ValueChanged<bool> onHover;

  @override
  Widget build(BuildContext context) {
    final mono = JotText.mono(size: fontSize, height: 1.85);

    final spans = <InlineSpan>[];

    if (row.chevron != null) {
      spans.add(TextSpan(
        text: row.chevron == _Chevron.expanded ? '▾ ' : '▸ ',
        style: mono.copyWith(color: JotSyntax.chevron),
      ));
    }

    if (row.key != null) {
      spans
        ..add(TextSpan(text: '"${row.key}"', style: mono.copyWith(color: JotSyntax.key)))
        ..add(TextSpan(text: ': ', style: mono.copyWith(color: JotSyntax.punctuation)));
    }

    if (row.value != null) {
      spans.add(TextSpan(text: row.value!.text, style: mono.copyWith(color: row.value!.color)));
    }

    if (row.collapsedCount != null) {
      spans
        ..add(TextSpan(text: '${row.open} ', style: mono.copyWith(color: JotSyntax.punctuation)))
        ..add(WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 5),
            decoration: BoxDecoration(
              color: JotColors.neutralWashMenu,
              borderRadius: BorderRadius.circular(3),
            ),
            child: Text(
              row.collapsedLabel!,
              style: mono.copyWith(color: JotSyntax.collapsedCount, height: 1.4),
            ),
          ),
        ))
        ..add(TextSpan(text: ' ${row.close}', style: mono.copyWith(color: JotSyntax.punctuation)));
    } else if (row.open != null) {
      spans.add(TextSpan(text: row.open, style: mono.copyWith(color: JotSyntax.punctuation)));
    } else if (row.close != null) {
      spans.add(TextSpan(text: row.close, style: mono.copyWith(color: JotSyntax.punctuation)));
    }

    if (row.trailing.isNotEmpty) {
      spans.add(TextSpan(text: row.trailing, style: mono.copyWith(color: JotSyntax.punctuation)));
    }

    if (caret) {
      spans.add(WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: Padding(
          padding: const EdgeInsets.only(left: 3),
          child: BlinkingCaret(height: fontSize + 0.5),
        ),
      ));
    }

    final radius = BorderRadius.vertical(
      top: Radius.circular(bandTop ? 3 : 0),
      bottom: Radius.circular(bandBottom ? 3 : 0),
    );

    return MouseRegion(
      onEnter: (_) => onHover(true),
      onExit: (_) => onHover(false),
      child: GestureDetector(
        onTap: onToggle,
        behavior: HitTestBehavior.opaque,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showLineNumbers)
              SizedBox(
                width: 44,
                child: Padding(
                  padding: const EdgeInsets.only(right: 14),
                  child: Text(
                    '$lineNumber',
                    textAlign: TextAlign.right,
                    style: mono.copyWith(color: JotSyntax.lineNumber),
                  ),
                ),
              ),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: highlighted ? JotColors.jsonNestBlock : null,
                  borderRadius: radius,
                ),
                padding: EdgeInsets.only(left: 4 + row.depth * indent),
                child: Text.rich(TextSpan(children: spans), style: mono),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The `brut` tab, and the fallback when the JSON does not parse.
class _RawText extends StatelessWidget {
  const _RawText({
    required this.source,
    required this.fontSize,
    required this.padding,
    required this.showLineNumbers,
  });

  final String source;
  final double fontSize;
  final EdgeInsets padding;
  final bool showLineNumbers;

  @override
  Widget build(BuildContext context) {
    final mono = JotText.mono(size: fontSize, height: 1.85, color: JotColors.textStrong);
    final lines = source.split('\n');

    return SingleChildScrollView(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < lines.length; i++)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (showLineNumbers)
                  SizedBox(
                    width: 44,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 14),
                      child: Text(
                        '${i + 1}',
                        textAlign: TextAlign.right,
                        style: mono.copyWith(color: JotSyntax.lineNumber),
                      ),
                    ),
                  ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: SelectableText(lines[i], style: mono),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

/// `@keyframes caret { 0%,49%{opacity:1} 50%,100%{opacity:0} }` at 1.1s,
/// stepped — so it snaps rather than fades.
class BlinkingCaret extends StatefulWidget {
  const BlinkingCaret({super.key, this.height = 13, this.width = 1.5});

  final double height;
  final double width;

  @override
  State<BlinkingCaret> createState() => _BlinkingCaretState();
}

/// A timer rather than an [AnimationController].
///
/// The value consumed here is binary, so a ticker rebuilt this widget sixty
/// times a second to produce two changes per cycle — and the animated
/// [Opacity] forced a `saveLayer` on every one of those frames, forever, in
/// both the JSON viewer and the shortcut capture field.
class _BlinkingCaretState extends State<BlinkingCaret> {
  static const _halfPeriod = Duration(milliseconds: 550);

  Timer? _timer;
  bool _on = true;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(_halfPeriod, (_) {
      if (mounted) setState(() => _on = !_on);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
        width: widget.width,
        height: widget.height,
        // Swapping the fill in and out beats fading it: no layer, and the
        // caret was never meant to be seen mid-fade anyway.
        child: _on ? ColoredBox(color: JotColors.accent) : null,
      );
}

/// Header strip above the viewer: `arbre` / `brut` tabs plus the expand and
/// collapse affordances.
class ViewerHeader extends StatelessWidget {
  const ViewerHeader({
    super.key,
    required this.rawMode,
    required this.onModeChanged,
    this.onExpandAll,
    this.onCollapseAll,
    this.onCopy,
  });

  final bool rawMode;
  final ValueChanged<bool> onModeChanged;
  final VoidCallback? onExpandAll;
  final VoidCallback? onCollapseAll;
  final VoidCallback? onCopy;

  @override
  Widget build(BuildContext context) => Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: JotColors.codePanelHeader,
          border: Border(bottom: BorderSide(color: JotColors.borderEditor)),
        ),
        child: Row(
          children: [
            _HeaderAction('arbre', active: !rawMode, onTap: () => onModeChanged(false)),
            const SizedBox(width: 10),
            _HeaderAction('brut', active: rawMode, onTap: () => onModeChanged(true)),
            const Spacer(),
            if (onExpandAll != null && !rawMode) ...[
              _HeaderAction('tout déplier', onTap: onExpandAll!),
              const SizedBox(width: 10),
            ],
            if (onCollapseAll != null && !rawMode) _HeaderAction('tout replier', onTap: onCollapseAll!),
            if (onCopy != null) ...[
              const SizedBox(width: 10),
              _HeaderAction('copier', onTap: onCopy!),
            ],
          ],
        ),
      );
}

class _HeaderAction extends StatelessWidget {
  const _HeaderAction(this.label, {required this.onTap, this.active});

  final String label;
  final VoidCallback onTap;

  /// `null` for the non-tab actions, which are always rendered dim.
  final bool? active;

  @override
  Widget build(BuildContext context) => Hoverable(
        onTap: onTap,
        builder: (context, hovered) => Text(
          label,
          style: JotText.mono(
            size: 10.5,
            weight: FontWeight.w500,
            color: switch (active) {
              true => JotColors.textDim,
              false => JotColors.textDisabled,
              null => hovered ? JotColors.textDim : JotColors.textSubtle,
            },
          ),
        ),
      );
}

/// Copies [text] to the clipboard — used by every "Copier" affordance.
Future<void> copyToClipboard(String text) =>
    Clipboard.setData(ClipboardData(text: text));
