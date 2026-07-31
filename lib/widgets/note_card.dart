import 'package:flutter/widgets.dart';

import '../core/models/note.dart';
import '../core/theme/jot_theme.dart';
import '../core/utils/jot_format.dart';
import 'jot_primitives.dart';
import 'type_badge.dart';

/// A row in the desktop note list (middle column).
///
/// Design: `padding:11px 14px 12px`, three stacked lines separated by 6px —
/// title (+ pin or the `···` menu affordance), a monospace preview, then the
/// meta line carrying the type badge, the timestamp and the first tag.
class NoteListRow extends StatelessWidget {
  const NoteListRow({
    super.key,
    required this.note,
    required this.selected,
    required this.onTap,
    this.onMenu,
    this.dimmed = false,
    this.previewLines = 2,
    this.compact = false,
  });

  final Note note;
  final bool selected;
  final VoidCallback onTap;

  /// From the Apparence tab; 0 hides the preview line entirely.
  final int previewLines;

  /// "Densité : compacte" trims the row's vertical padding.
  final bool compact;

  /// Opens the context menu; also bound to right-click on the row.
  final VoidCallback? onMenu;

  /// The design fades the oldest row to `opacity:.75`.
  final bool dimmed;

  @override
  Widget build(BuildContext context) => Hoverable(
        onTap: onTap,
        onSecondaryTap: onMenu,
        builder: (context, hovered) {
          final row = Container(
            padding: EdgeInsets.fromLTRB(14, compact ? 7 : 11, 14, compact ? 8 : 12),
            decoration: BoxDecoration(
              color: selected
                  ? JotColors.accentWashList
                  : (hovered ? JotColors.hoverRow : null),
              // The design dropped the 2px accent left edge: selection is now
              // carried by the wash plus a stronger hairline, and the accent
              // bar survives only in the sidebar's active row.
              border: selected
                  ? Border(bottom: BorderSide(color: JotColors.active.borderStrong))
                  : null,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        note.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: JotText.noteTitle.copyWith(
                          color: selected ? JotColors.textBright : JotColors.textStrong,
                        ),
                      ),
                    ),
                    const SizedBox(width: 7),
                    if (note.pinned)
                      const PinMark()
                    else if (hovered && onMenu != null)
                      Hoverable(
                        onTap: onMenu,
                        builder: (context, _) => const OverflowDots(),
                      ),
                  ],
                ),
                if (previewLines > 0) ...[
                const SizedBox(height: 6),
                // The preview keeps the note's own face: monospace for JSON,
                // code and URLs, the UI font for prose. That single cue is
                // what makes a list of 300 notes scannable.
                Text(
                  note.preview,
                  maxLines: previewLines,
                  overflow: TextOverflow.ellipsis,
                  style: note.type.isMonospace
                      ? JotText.notePreview.copyWith(
                          color: selected
                              ? JotColors.previewOnSelected
                              : JotColors.textFaint,
                        )
                      : JotText.ui(
                          size: 11.5,
                          height: 1.5,
                          color: selected
                              ? JotColors.previewOnSelected
                              : JotColors.textFaint,
                        ),
                ),
                ],
                const SizedBox(height: 6),
                Row(
                  children: [
                    TypeBadge(note.type),
                    const SizedBox(width: 8),
                    Text(JotFormat.relative(note.modified), style: JotText.metaTime),
                    if (note.tags.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          '#${note.tags.first}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: JotText.metaTag,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          );

          return dimmed ? Opacity(opacity: 0.75, child: row) : row;
        },
      );
}

/// The mobile variant: a self-contained card rather than a full-bleed row.
///
/// Design: `background:#1E1F23; border:1px solid #2A2C31; border-radius:10px;
/// padding:12px 13px`, with a 2px accent left edge when pinned.
class NoteCard extends StatelessWidget {
  const NoteCard({super.key, required this.note, required this.onTap});

  final Note note;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Hoverable(
        onTap: onTap,
        builder: (context, _) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
          decoration: BoxDecoration(
            color: JotColors.editorSurface,
            borderRadius: BorderRadius.circular(11),
            // The design removed `border-left:2px solid` from every card: a
            // pinned note is now marked by a stronger hairline on all sides.
            // The accent bar survives only in the sidebar's active row.
            border: Border.all(
              color: note.pinned
                  ? JotColors.active.borderStrong
                  : JotColors.borderWindow,
            ),
          ),
          child: _content(),
        ),
      );

  Widget _content() => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      note.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: JotText.ui(
                        size: 14,
                        weight: FontWeight.w600,
                        height: 1.25,
                        color: note.pinned ? JotColors.textBright : JotColors.textStrong,
                      ),
                    ),
                  ),
                  if (note.pinned) ...[
                    const SizedBox(width: 8),
                    const PinMark(),
                  ],
                ],
              ),
              const SizedBox(height: 7),
              Text(
                note.preview,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: note.type.isMonospace
                    ? JotText.mono(
                        size: 12,
                        height: 1.5,
                        color: note.pinned
                            ? JotColors.previewOnSelected
                            : JotColors.textFaint,
                      )
                    : JotText.ui(size: 12, height: 1.5, color: JotColors.textFaint),
              ),
              const SizedBox(height: 7),
              Row(
                children: [
                  TypeBadge(note.type),
                  const SizedBox(width: 9),
                  Text(
                    JotFormat.relative(note.modified),
                    style: JotText.ui(size: 11.5, color: JotColors.textSubtle),
                  ),
                  if (note.tags.isNotEmpty) ...[
                    const SizedBox(width: 9),
                    Flexible(
                      child: Text(
                        '#${note.tags.first}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: JotText.mono(size: 11.5, color: JotColors.textDisabled),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          );
}

/// Text with the matched span picked out the way the palette does it:
/// `background:rgba(255,106,61,.28); color:#FFB699; border-radius:3px`.
class HighlightedText extends StatelessWidget {
  const HighlightedText(
    this.text, {
    super.key,
    required this.span,
    required this.style,
    this.maxLines = 1,
  });

  final String text;

  /// `(start, end)` of the run to highlight, or null for no highlight.
  final (int, int)? span;
  final TextStyle style;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final match = span;
    if (match == null || match.$1 < 0 || match.$2 > text.length) {
      return Text(text, maxLines: maxLines, overflow: TextOverflow.ellipsis, style: style);
    }

    final highlight = style.copyWith(
      color: JotColors.accentHighlightText,
      backgroundColor: JotColors.accentWashStrong,
    );

    return Text.rich(
      TextSpan(
        children: [
          if (match.$1 > 0) TextSpan(text: text.substring(0, match.$1)),
          TextSpan(text: text.substring(match.$1, match.$2), style: highlight),
          if (match.$2 < text.length) TextSpan(text: text.substring(match.$2)),
        ],
      ),
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
      style: style,
    );
  }
}

/// The two empty states from the design (`1c`): a dashed glyph, a title, an
/// explanatory line and one or two actions.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.title,
    required this.message,
    this.glyph,
    this.circular = false,
    this.primaryLabel,
    this.onPrimary,
    this.primaryHint,
    this.secondaryLabel,
    this.onSecondary,
  });

  final String title;
  final String message;

  /// `null` draws the plain dashed rectangle used for an empty folder.
  final String? glyph;
  final bool circular;

  final String? primaryLabel;
  final VoidCallback? onPrimary;
  final String? primaryHint;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 34),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _DashedGlyph(glyph: glyph, circular: circular),
              const SizedBox(height: 13),
              Text(
                title,
                textAlign: TextAlign.center,
                style: JotText.ui(
                  size: 13.5,
                  weight: FontWeight.w600,
                  color: JotColors.textStrong,
                ),
              ),
              const SizedBox(height: 13),
              Text(
                message,
                textAlign: TextAlign.center,
                style: JotText.ui(size: 12, height: 1.6, color: JotColors.textFaint),
              ),
              if (primaryLabel != null || secondaryLabel != null) ...[
                const SizedBox(height: 15),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (primaryLabel != null)
                      JotButton(primaryLabel!, onTap: onPrimary),
                    if (primaryHint != null) ...[
                      const SizedBox(width: 8),
                      Text(primaryHint!, style: JotText.keycap),
                    ],
                    if (secondaryLabel != null) ...[
                      if (primaryLabel != null) const SizedBox(width: 8),
                      JotButton(
                        secondaryLabel!,
                        onTap: onSecondary,
                        kind: JotButtonKind.secondary,
                      ),
                    ],
                  ],
                ),
              ],
            ],
          ),
        ),
      );
}

class _DashedGlyph extends StatelessWidget {
  const _DashedGlyph({this.glyph, this.circular = false});

  final String? glyph;
  final bool circular;

  @override
  Widget build(BuildContext context) => Container(
        width: circular ? 46 : 52,
        height: circular ? 46 : 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border.all(color: JotColors.borderRaised, width: 1.5),
          borderRadius: circular ? BorderRadius.circular(23) : BorderRadius.circular(7),
        ),
        child: glyph == null
            ? null
            : Text(glyph!, style: JotText.ui(size: 16, color: JotColors.textDisabled)),
      );
}
