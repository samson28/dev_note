import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../core/theme/jot_theme.dart';

/// Every icon in the app, in one place.
///
/// The interface used to draw its icons as text characters, which is what made
/// it read as machine-written: the design's own copy contains no symbol glyphs
/// at all, only French letters and `×`. Lucide is the right pack here because
/// its 1.5px stroke matches the hairline weight the design uses everywhere
/// (the folder outline, the window controls, the dashed empty-state frames).
///
/// Sizes follow the text they sit next to rather than a scale of their own:
/// an icon beside 12.5px UI text is 14px, beside 11px monospace it is 12px.
abstract final class JotIcons {
  static const close = LucideIcons.x;
  static const search = LucideIcons.search;
  static const copy = LucideIcons.copy;
  static const menu = LucideIcons.menu;
  static const back = LucideIcons.chevronLeft;
  static const forward = LucideIcons.chevronRight;
  static const expanded = LucideIcons.chevronDown;
  static const collapsed = LucideIcons.chevronRight;
  static const dropdown = LucideIcons.chevronDown;
  static const overflow = LucideIcons.ellipsis;
  static const folder = LucideIcons.folder;
  static const tag = LucideIcons.hash;
  static const pin = LucideIcons.pin;
  static const trash = LucideIcons.trash2;
  static const settings = LucideIcons.settings;
  static const plus = LucideIcons.plus;
  static const check = LucideIcons.check;
  static const move = LucideIcons.folderInput;
  static const restore = LucideIcons.undo2;
  static const arrowUp = LucideIcons.arrowUp;
  static const arrowDown = LucideIcons.arrowDown;
  static const minimise = LucideIcons.minus;
  static const maximise = LucideIcons.square;
}

/// An icon at a size and colour drawn from the palette.
///
/// Wrapping [Icon] keeps every call site from repeating the colour lookup, and
/// gives one place to adjust optical weight if the pack is ever swapped.
class JotIcon extends StatelessWidget {
  const JotIcon(this.icon, {super.key, this.size = 14, this.color});

  final IconData icon;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) => Icon(
        icon,
        size: size,
        color: color ?? JotColors.textMuted,
      );
}
