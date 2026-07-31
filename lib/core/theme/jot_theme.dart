import 'package:flutter/material.dart';

import 'jot_colors.dart';
import 'jot_typography.dart';

export 'jot_colors.dart';
export 'jot_metrics.dart';
export 'jot_typography.dart';

/// Jot only ever renders in its own dark palette, there is no light variant
/// in the design, so the theme is a thin shell that stops Material defaults
/// (ripples, blue selection, Roboto) from leaking into the UI.
abstract final class JotTheme {
  static ThemeData build() {
    final base = ThemeData.dark(useMaterial3: true);

    return base.copyWith(
      scaffoldBackgroundColor: JotColors.window,
      canvasColor: JotColors.window,
      colorScheme: base.colorScheme.copyWith(
        primary: JotColors.accent,
        onPrimary: JotColors.onAccent,
        surface: JotColors.editorSurface,
        onSurface: JotColors.textStrong,
        error: JotColors.danger,
      ),
      textTheme: base.textTheme.apply(
        fontFamily: JotFonts.ui,
        fontFamilyFallback: JotFonts.uiFallback,
        bodyColor: JotColors.textStrong,
        displayColor: JotColors.textBright,
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: JotColors.accent,
        // ::selection { background: rgba(255,106,61,.3) }
        selectionColor: Color(0x4DFF6A3D),
        selectionHandleColor: JotColors.accent,
      ),
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      splashColor: Colors.transparent,
      hoverColor: Colors.transparent,
      dividerColor: JotColors.borderSubtle,
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.hovered)
              ? JotColors.borderRaised
              : JotColors.borderWindow,
        ),
        trackColor: const WidgetStatePropertyAll(Colors.transparent),
        thickness: const WidgetStatePropertyAll(6),
        radius: const Radius.circular(3),
        crossAxisMargin: 2,
      ),
      visualDensity: VisualDensity.standard,
    );
  }
}
