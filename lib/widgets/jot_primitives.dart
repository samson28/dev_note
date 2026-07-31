import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../core/theme/jot_theme.dart';
import 'jot_icons.dart';

/// The pin marker. Filled when the note is pinned, outlined when it is the
/// affordance to pin one.
class PinMark extends StatelessWidget {
  const PinMark({super.key, this.active = true, this.size = 13});

  final bool active;
  final double size;

  @override
  Widget build(BuildContext context) => JotIcon(
        JotIcons.pin,
        size: size,
        color: active ? JotColors.accent : JotColors.textDisabled,
      );
}

/// The folder icon. [width] and [height] are kept from the hand-drawn version
/// so existing call sites keep their sizing; the larger of the two wins.
class FolderGlyph extends StatelessWidget {
  const FolderGlyph({super.key, required this.color, this.width = 13, this.height = 11});

  final Color color;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) =>
      JotIcon(JotIcons.folder, size: math.max(width, height) + 1, color: color);
}

/// Keyboard hint chip. Two flavours in the design: filled (`#23252A`, inside
/// the sidebar search field) and outlined (`#1B1C20` + `#2A2C31` border).
class Keycap extends StatelessWidget {
  const Keycap(this.label, {super.key, this.outlined = false});

  final String label;
  final bool outlined;

  @override
  Widget build(BuildContext context) => Container(
        padding: EdgeInsets.symmetric(horizontal: outlined ? 6 : 5, vertical: outlined ? 4 : 3),
        decoration: BoxDecoration(
          color: outlined ? JotColors.field : JotColors.keycap,
          border: outlined ? Border.all(color: JotColors.borderWindow) : null,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          label,
          style: JotText.mono(
            size: 10,
            weight: FontWeight.w500,
            color: outlined ? JotColors.textDim : JotColors.textSubtle,
          ),
        ),
      );
}

/// `#api` chip. `dashed: true` renders the "+" affordance next to it.
///
/// Removal is deliberately *not* bound to a bare tap on the chip: an
/// accidental click would silently drop a tag, and the note list uses tags to
/// find things again. Instead a `✕` appears on hover — the same
/// `#api ✕` shape the design uses for the palette's active filters — and only
/// that hit target removes.
class TagChip extends StatelessWidget {
  const TagChip(
    this.label, {
    super.key,
    this.onTap,
    this.onRemove,
    this.dashed = false,
  });

  final String label;
  final VoidCallback? onTap;
  final VoidCallback? onRemove;
  final bool dashed;

  @override
  Widget build(BuildContext context) => Hoverable(
        onTap: onTap,
        cursor: onTap == null ? SystemMouseCursors.basic : SystemMouseCursors.click,
        builder: (context, hovered) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
          decoration: BoxDecoration(
            color: dashed ? null : JotColors.neutralWashChip,
            // Flutter has no dashed border; the design's dashed "+" reads as a
            // lighter affordance, so it drops to the dimmer text colour instead.
            border: Border.all(color: JotColors.borderTag),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: JotText.tagChip.copyWith(
                  color: dashed ? JotColors.textSubtle : JotColors.textMuted,
                ),
              ),
              if (onRemove != null && hovered) ...[
                const SizedBox(width: 5),
                Hoverable(
                  onTap: onRemove,
                  builder: (context, over) => Text(
                    '✕',
                    style: JotText.mono(
                      size: 10,
                      color: over ? JotColors.danger : JotColors.textSubtle,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
}

enum JotButtonKind { primary, secondary, danger, disabled }

/// `padding:8px 12px; border-radius:6px` for every variant.
class JotButton extends StatelessWidget {
  const JotButton(
    this.label, {
    super.key,
    this.onTap,
    this.kind = JotButtonKind.primary,
    this.trailing,
  });

  final String label;
  final VoidCallback? onTap;
  final JotButtonKind kind;

  /// Optional keycap rendered after the label, e.g. "Enregistrer Entrée".
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final enabled = kind != JotButtonKind.disabled && onTap != null;

    final (Color? fill, Color? border, Color text, FontWeight weight) = switch (kind) {
      JotButtonKind.primary => (
          JotColors.accent,
          null,
          JotColors.onAccent,
          FontWeight.w600,
        ),
      JotButtonKind.secondary => (
          null,
          JotColors.borderRaised,
          JotColors.textStrong,
          FontWeight.w500,
        ),
      JotButtonKind.danger => (
          null,
          JotColors.dangerBorder,
          JotColors.danger,
          FontWeight.w500,
        ),
      JotButtonKind.disabled => (
          JotColors.neutralWash,
          null,
          JotColors.textDisabled,
          FontWeight.w500,
        ),
    };

    final button = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: fill,
        border: border == null ? null : Border.all(color: border),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        trailing == null ? label : '$label $trailing',
        style: JotText.ui(size: 11.5, weight: weight, color: text),
      ),
    );

    if (!enabled) return button;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(onTap: onTap, child: button),
    );
  }
}

/// Uppercase section label: "DOSSIERS", "ÉPINGLÉES", "NOTES"...
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.small = false, this.rule = false});

  final String text;

  /// 9.5px group labels inside the list vs. 10px sidebar section headers.
  final bool small;

  /// Whether to draw the hairline that fills the rest of the row.
  final bool rule;

  @override
  Widget build(BuildContext context) {
    final label = Text(
      text.toUpperCase(),
      style: small ? JotText.groupLabel : JotText.sectionLabel,
    );
    if (!rule) return label;

    return Row(
      children: [
        label,
        const SizedBox(width: 6),
        Expanded(child: SizedBox(height: 1, child: ColoredBox(color: JotColors.borderSubtle))),
      ],
    );
  }
}

/// Rebuilds its child with the current hover state. Used for list rows and
/// menu items, which only change background on hover in this design.
class Hoverable extends StatefulWidget {
  const Hoverable({
    super.key,
    required this.builder,
    this.onTap,
    this.onSecondaryTap,
    this.onLongPress,
    this.cursor = SystemMouseCursors.click,
  });

  final Widget Function(BuildContext context, bool hovered) builder;
  final VoidCallback? onTap;
  final VoidCallback? onSecondaryTap;

  /// The touch equivalent of [onSecondaryTap]: a phone has no right click.
  final VoidCallback? onLongPress;
  final MouseCursor cursor;

  @override
  State<Hoverable> createState() => _HoverableState();
}

class _HoverableState extends State<Hoverable> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) => MouseRegion(
        cursor: widget.cursor,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          onSecondaryTap: widget.onSecondaryTap,
          onLongPress: widget.onLongPress,
          behavior: HitTestBehavior.opaque,
          child: widget.builder(context, _hovered),
        ),
      );
}

/// The overflow affordance.
class OverflowDots extends StatelessWidget {
  const OverflowDots({super.key, this.color, this.size = 15});

  final Color? color;
  final double size;

  @override
  Widget build(BuildContext context) => JotIcon(
        JotIcons.overflow,
        size: size,
        color: color ?? JotColors.textDim,
      );
}

/// A 1px hairline.
class Hairline extends StatelessWidget {
  const Hairline({super.key, this.color, this.inset = EdgeInsets.zero});

  final Color? color;
  final EdgeInsets inset;

  @override
  Widget build(BuildContext context) => Padding(
        padding: inset,
        child: SizedBox(
          height: 1,
          child: ColoredBox(color: color ?? JotColors.borderSubtle),
        ),
      );
}
