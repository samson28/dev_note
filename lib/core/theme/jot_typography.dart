import 'package:flutter/widgets.dart';

import 'jot_colors.dart';

/// Two families, exactly as in the design:
///
/// * the platform UI font for chrome and prose,
/// * JetBrains Mono for every piece of *content* (JSON, code, URLs, keys),
///   plus counters, keycaps and badges.
///
/// JetBrains Mono is bundled in `assets/fonts/` (SIL OFL 1.1) at the three
/// weights the design uses, so content renders identically everywhere. The
/// fallback chain below only matters if an asset ever fails to load.
abstract final class JotFonts {
  static const ui = 'Segoe UI';

  static const uiFallback = <String>[
    '.AppleSystemUIFont',
    'SF Pro Text',
    'Helvetica Neue',
    'Roboto',
    'Ubuntu',
    'Cantarell',
    'sans-serif',
  ];

  static const mono = 'JetBrains Mono';

  static const monoFallback = <String>[
    'Cascadia Mono',
    'Consolas',
    'SF Mono',
    'Menlo',
    'DejaVu Sans Mono',
    'Roboto Mono',
    'monospace',
  ];
}

/// Text style constructors mirroring the CSS `font:` shorthands in the design.
///
/// [size] maps to `font-size`, [height] to the `/line-height` part (as a
/// multiplier, which is how CSS unitless line-heights work too), and
/// [tracking] is expressed in `em` like the design's `letter-spacing`.
abstract final class JotText {
  static TextStyle ui({
    required double size,
    FontWeight weight = FontWeight.w400,
    double height = 1.0,
    double tracking = 0,
    // Nullable so the default can come from the live palette: a default
    // parameter value has to be a compile-time constant, and colours are not
    // constants any more.
    Color? color,
    TextDecoration? decoration,
  }) => TextStyle(
    fontFamily: JotFonts.ui,
    fontFamilyFallback: JotFonts.uiFallback,
    fontSize: size,
    fontWeight: weight,
    height: height,
    letterSpacing: tracking * size,
    color: color ?? JotColors.textStrong,
    decoration: decoration,
    leadingDistribution: TextLeadingDistribution.even,
  );

  static TextStyle mono({
    required double size,
    FontWeight weight = FontWeight.w400,
    double height = 1.0,
    double tracking = 0,
    Color? color,
  }) => TextStyle(
    fontFamily: JotFonts.mono,
    fontFamilyFallback: JotFonts.monoFallback,
    fontSize: size,
    fontWeight: weight,
    height: height,
    letterSpacing: tracking * size,
    color: color ?? JotColors.textMuted,
    leadingDistribution: TextLeadingDistribution.even,
  );

  // ------------------------------------------------------------- named roles

  /// `font:600 12px/1 ...; letter-spacing:.02em` — window title.
  static TextStyle get windowTitle => ui(
    size: 12,
    weight: FontWeight.w600,
    tracking: 0.02,
    color: JotColors.textPrimary,
  );

  /// `font:400 12px/1 ...` — the "— Inbox · 24 notes" suffix.
  static TextStyle get windowSubtitle =>
      ui(size: 12, color: JotColors.textSubtle);

  /// `font:600 10px/1 ...; letter-spacing:.09em; text-transform:uppercase`
  /// — "DOSSIERS" / "TAGS" section headers in the sidebar.
  static TextStyle get sectionLabel => ui(
    size: 10,
    weight: FontWeight.w600,
    tracking: 0.09,
    color: JotColors.textSubtle,
  );

  /// Same idea at 9.5px — "ÉPINGLÉES" / "CETTE SEMAINE" / "NOTES" / "ACTIONS".
  static TextStyle get groupLabel => ui(
    size: 9.5,
    weight: FontWeight.w600,
    tracking: 0.09,
    color: JotColors.textSubtle,
  );

  /// `font:600 12.5px/1 ...` — active sidebar row.
  static TextStyle get sidebarRowActive => ui(
    size: 12.5,
    weight: FontWeight.w600,
    color: JotColors.textBright,
  );

  /// `font:400 12.5px/1 ...` — idle sidebar row.
  static TextStyle get sidebarRow => ui(size: 12.5, color: JotColors.textBody);

  /// `font:500 11px/1 mono` — sidebar counters.
  static TextStyle get counter =>
      mono(size: 11, weight: FontWeight.w500, color: JotColors.textSubtle);

  /// `font:600 13px/1.25 ...` — note title in the list.
  static TextStyle get noteTitle => ui(
    size: 13,
    weight: FontWeight.w600,
    height: 1.25,
    color: JotColors.textStrong,
  );

  /// `font:400 11.5px/1.5 mono` — note preview line.
  static TextStyle get notePreview =>
      mono(size: 11.5, height: 1.5, color: JotColors.textFaint);

  /// `font:400 11px/1 ...` — timestamp next to the type badge.
  static TextStyle get metaTime => ui(size: 11, color: JotColors.textSubtle);

  /// `font:400 11px/1 mono` — inline `#tag` on a list row.
  static TextStyle get metaTag => mono(size: 11, color: JotColors.textDisabled);

  /// `font:600 9.5px/1 mono; letter-spacing:.06em` — type badges.
  static TextStyle get badge =>
      mono(size: 9.5, weight: FontWeight.w600, tracking: 0.06);

  /// `font:500 10px/1 mono` — keycap hints.
  static TextStyle get keycap =>
      mono(size: 10, weight: FontWeight.w500, color: JotColors.textDim);

  /// `font:400 11px/1 mono` — tag chips.
  static TextStyle get tagChip => mono(size: 11, color: JotColors.textMuted);

  /// `font:400 12.5px/1.85 mono` — JSON tree body in the desktop editor.
  static TextStyle get jsonBody => mono(size: 12.5, height: 1.85);

  /// `font:400 11px/1 mono` — editor status bar.
  static TextStyle get statusBar => mono(size: 11, color: JotColors.textSubtle);

  /// `font:600 11.5px/1 ...` — primary button label.
  static TextStyle get buttonPrimary =>
      ui(size: 11.5, weight: FontWeight.w600, color: JotColors.onAccent);

  /// `font:500 11.5px/1 ...` — secondary button label.
  static TextStyle get buttonSecondary =>
      ui(size: 11.5, weight: FontWeight.w500, color: JotColors.textStrong);
}
