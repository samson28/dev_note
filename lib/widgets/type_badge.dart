import 'package:flutter/widgets.dart';

import '../core/models/note_type.dart';
import '../core/theme/jot_theme.dart';

/// `TXT` / `JSON` / `CODE` / `URL` pill.
///
/// Design: `font:600 9.5px/1 mono; letter-spacing:.06em; padding:3px 5px;
/// border-radius:3px` with the per-type foreground/background pair. On OLED
/// the pair carries an outline instead of a fill.
class TypeBadge extends StatelessWidget {
  const TypeBadge(
    this.type, {
    super.key,
    this.padding = const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
  });

  /// The slightly roomier `padding:4px 5px` variant used in the palette, and
  /// `4px 6px` in the component sheet.
  const TypeBadge.roomy(this.type, {super.key})
      : padding = const EdgeInsets.symmetric(horizontal: 5, vertical: 4);

  final NoteType type;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final colors = type.badge;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: colors.background,
        border: colors.outline == null ? null : Border.all(color: colors.outline!),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        type.label,
        style: JotText.badge.copyWith(color: colors.foreground),
      ),
    );
  }
}

/// Filter chip variant shown in the palette and the mobile header, e.g.
/// `JSON 3`. The "all" chip is rendered with a solid accent fill.
class TypeFilterChip extends StatelessWidget {
  const TypeFilterChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.type,
    this.count,
  });

  /// `null` renders the neutral "Tout" chip.
  final NoteType? type;
  final String label;
  final int? count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final badge = type?.badge;

    final Color foreground;
    final Color background;
    if (selected) {
      foreground = JotColors.onAccent;
      background = JotColors.accent;
    } else if (badge != null) {
      foreground = badge.foreground;
      background = badge.background;
    } else {
      foreground = JotColors.active.badgeText.foreground;
      background = JotColors.neutralWashSoft;
    }

    return _Pressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          count == null ? label : '$label $count',
          style: JotText.mono(
            size: 10.5,
            weight: FontWeight.w500,
            color: foreground,
          ),
        ),
      ),
    );
  }
}

/// Outlined filter pill: `dossier: Inbox ▾`, `#api ✕`.
class FilterPill extends StatelessWidget {
  const FilterPill({
    super.key,
    required this.label,
    required this.onTap,
    this.trailing,
  });

  final String label;
  final String? trailing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => _Pressable(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            border: Border.all(color: JotColors.borderRaised),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            trailing == null ? label : '$label $trailing',
            style: JotText.mono(
              size: 10.5,
              weight: FontWeight.w500,
              color: JotColors.textMuted,
            ),
          ),
        ),
      );
}

/// Shared hover/press wrapper, the design has no ripples, just a cursor
/// change and the background swaps the parent already handles.
class _Pressable extends StatelessWidget {
  const _Pressable({required this.child, required this.onTap});
  final Widget child;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(onTap: onTap, child: child),
      );
}
