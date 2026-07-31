import 'package:flutter/widgets.dart';

import 'jot_palette.dart';

export 'jot_palette.dart' show JotPalette, BadgeColors;

/// The active palette, and every token the UI reads.
///
/// These were `static const` while the design had a single theme, which the
/// compiler enforced nicely. Section 6 added three, so they are now getters
/// over a swappable [JotPalette]. Call sites are unchanged (`JotColors.accent`
/// still reads the same); only `const` expressions had to give, which the
/// compiler pointed out one by one.
///
/// [apply] is called from the app root whenever the theme or accent setting
/// changes, followed by a rebuild.
abstract final class JotColors {
  static JotPalette _active = JotPalette.anthracite;

  /// The active palette itself. Named `active` because `palette` is already a
  /// surface token (the search palette's background).
  static JotPalette get active => _active;

  /// Swaps the palette. Returns true when it actually changed, so the caller
  /// can skip a rebuild.
  static bool apply(JotPalette next) {
    if (identical(_active, next) ||
        (_active.id == next.id && _active.accent == next.accent)) {
      return false;
    }
    _active = next;
    return true;
  }

  // ---------------------------------------------------------------- surfaces
  static Color get canvas => _active.background;
  static Color get window => _active.background;
  static Color get chrome => _active.chrome;
  static Color get listSurface => _active.listSurface;
  static Color get editorSurface => _active.editorSurface;
  static Color get raised => _active.surfaceRaised;
  static Color get palette => _active.paletteSurface;
  static Color get footer => _active.footer;
  static Color get captureBar => _active.captureBar;
  static Color get field => _active.field;
  static Color get codePanel => _active.codePanel;
  static Color get codePanelHeader => _active.codePanelHeader;
  static Color get panel => _active.panel;
  static Color get keycap => _active.keycap;
  static Color get keycapPalette => _active.borderWindow;

  // ----------------------------------------------------------------- borders
  static Color get borderSubtle => _active.borderSubtle;
  static Color get borderEditor => _active.borderEditor;
  static Color get borderWindow => _active.borderWindow;
  static Color get borderPalette => _active.borderPalette;
  static Color get borderTag => _active.borderTag;
  static Color get borderRaised => _active.borderRaised;
  static Color get borderPaletteOuter => _active.borderPaletteOuter;
  static Color get borderCapture => _active.borderCapture;

  // -------------------------------------------------------------------- text
  static Color get textBright => _active.textPrimary;
  static Color get textPrimary => _active.textPrimary;
  static Color get textStrong => _active.isLight ? _active.textPrimary : const Color(0xFFDDDEE3);
  static Color get textBody => _active.textBody;
  static Color get textMuted => _active.textMuted;
  static Color get textDim => _active.textMuted;
  static Color get textFaint => _active.textBody;
  static Color get textSubtle => _active.textDim;
  static Color get textDisabled => _active.textDisabled;
  static Color get textGhost => _active.textDisabled;
  static Color get previewOnSelected => _active.textMuted;

  // ------------------------------------------------------------------ accent
  static Color get accent => _active.accent;
  static Color get accentHover => _active.isLight
      ? _active.accent.withValues(alpha: 0.85)
      : const Color(0xFFFF8A63);
  static Color get onAccent => _active.onAccent;
  static Color get accentHighlightText =>
      _active.isLight ? _active.accent : const Color(0xFFFFB699);

  static Color get accentWashSidebar => _active.accentWash(0.13);
  static Color get accentWashList => _active.accentWash(0.10);
  static Color get accentWashResult => _active.accentWash(0.12);
  static Color get accentWashStrong => _active.accentWash(0.28);
  static Color get accentWashIcon => _active.accentWash(0.14);

  // ------------------------------------------------------------------ danger
  static Color get danger => _active.danger;
  static Color get dangerBorder => _active.danger.withValues(alpha: 0.35);

  // -------------------------------------------------------- neutral overlays
  static Color get hoverRow => _active.overlay(0.03);
  static Color get jsonNestBlock => _active.overlay(0.035);
  static Color get neutralWash => _active.overlay(0.04);
  static Color get neutralWashMenu => _active.overlay(0.05);
  static Color get neutralWashChip => _active.overlay(0.055);
  static Color get neutralWashSoft => _active.overlay(0.06);
  static Color get neutralWashBadge => _active.overlay(0.07);
  static Color get neutralWashStrong => _active.overlay(0.08);

  static Color get scrim => _active.scrim;

  // ------------------------------------------------------------------ shadow
  /// Kept as raw values; [JotMetrics] routes them through
  /// [JotPalette.shadow] so OLED drops them.
  static const shadowWindow = Color(0x80000000);
  static const shadowPalette = Color(0xA6000000);
  static const shadowCapture = Color(0x99000000);
  static const shadowMenu = Color(0x8C000000);
}

/// Per-type badge colours, resolved from the active palette.
typedef TypeBadgeColors = BadgeColors;

/// Syntax colours shared by the JSON tree view and the code viewer.
abstract final class JotSyntax {
  static Color get key => JotColors.active.syntaxKey;
  static Color get string => JotColors.active.syntaxString;
  static Color get number => JotColors.active.syntaxNumber;
  static Color get keyword => JotColors.active.syntaxKeyword;
  static Color get punctuation => JotColors.active.syntaxPunctuation;
  static Color get chevron => JotColors.active.textDim;
  static Color get lineNumber => JotColors.active.textDisabled;
  static Color get collapsedCount => JotColors.active.textDisabled;
}
