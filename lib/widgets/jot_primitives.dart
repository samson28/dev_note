import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../core/theme/jot_theme.dart';

/// The pin marker: `9×9`, `border-radius:50% 50% 2px 50%`, rotated 45°.
class PinMark extends StatelessWidget {
  const PinMark({super.key, this.active = true, this.size = 9});

  final bool active;
  final double size;

  @override
  Widget build(BuildContext context) => Transform.rotate(
        angle: math.pi / 4,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: active ? JotColors.accent : JotColors.textDisabled,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(size / 2),
              topRight: Radius.circular(size / 2),
              bottomRight: const Radius.circular(2),
              bottomLeft: Radius.circular(size / 2),
            ),
          ),
        ),
      );
}

/// The outlined rectangle used as the folder icon:
/// `13×11`, `1.5px` border, `2px` radius.
class FolderGlyph extends StatelessWidget {
  const FolderGlyph({super.key, required this.color, this.width = 13, this.height = 11});

  final Color color;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) => Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          border: Border.all(color: color, width: 1.5),
          borderRadius: BorderRadius.circular(2),
        ),
      );
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
    this.cursor = SystemMouseCursors.click,
  });

  final Widget Function(BuildContext context, bool hovered) builder;
  final VoidCallback? onTap;
  final VoidCallback? onSecondaryTap;
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
          behavior: HitTestBehavior.opaque,
          child: widget.builder(context, _hovered),
        ),
      );
}

/// The overflow affordance, drawn as three dots rather than typed as `···`.
///
/// The design removed middot characters from its copy, but the affordance
/// itself is still needed; drawing it keeps the shape without depending on a
/// character the design no longer uses.
class OverflowDots extends StatelessWidget {
  const OverflowDots({super.key, this.color, this.dot = 2.5, this.gap = 2.5});

  final Color? color;
  final double dot;
  final double gap;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < 3; i++) ...[
            if (i > 0) SizedBox(width: gap),
            Container(
              width: dot,
              height: dot,
              decoration: BoxDecoration(
                color: color ?? JotColors.textDim,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ],
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
