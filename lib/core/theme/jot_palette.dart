import 'package:flutter/widgets.dart';

import '../models/app_settings.dart';

/// The colour layer that swaps between themes.
///
/// From the design's "Règles de bascule" (section 6):
///
///  * **Une seule couche de couleur change.** The six surface tokens and the
///    five syntax tokens permute. No geometry, size or spacing moves between
///    themes, which is why [JotMetrics] and [JotText] are untouched by this.
///  * **Élévation selon le thème.** Clair and Anthracite use shadows; OLED uses
///    hairlines only, because a card on pure black cannot cast a visible
///    shadow. [elevated] carries that switch.
///  * **Suivre le système** is on by default (clair by day, anthracite by
///    night). OLED is always an explicit choice, never automatic, see
///    [resolve].
@immutable
class JotPalette {
  const JotPalette({
    required this.id,
    required this.isLight,
    required this.elevated,
    // six surface tokens
    required this.background,
    required this.surface,
    required this.surfaceRaised,
    required this.surfaceSunken,
    required this.border,
    required this.borderStrong,
    // text ramp
    required this.textPrimary,
    required this.textBody,
    required this.textMuted,
    required this.textDim,
    required this.textDisabled,
    // accent
    required this.accent,
    required this.onAccent,
    // five syntax tokens
    required this.syntaxKey,
    required this.syntaxString,
    required this.syntaxNumber,
    required this.syntaxKeyword,
    required this.syntaxPunctuation,
    // per-type badges
    required this.badgeJson,
    required this.badgeCode,
    required this.badgeUrl,
    required this.badgeText,
    required this.badgeFile,
    required this.danger,
  });

  final String id;
  final bool isLight;

  /// False for OLED: shadows are replaced by 1px hairlines.
  final bool elevated;

  final Color background;
  final Color surface;
  final Color surfaceRaised;
  final Color surfaceSunken;
  final Color border;
  final Color borderStrong;

  final Color textPrimary;
  final Color textBody;
  final Color textMuted;
  final Color textDim;
  final Color textDisabled;

  final Color accent;
  final Color onAccent;

  final Color syntaxKey;
  final Color syntaxString;
  final Color syntaxNumber;
  final Color syntaxKeyword;
  final Color syntaxPunctuation;

  final BadgeColors badgeJson;
  final BadgeColors badgeCode;
  final BadgeColors badgeUrl;
  final BadgeColors badgeText;

  /// Imported binaries. Deliberately outside the design's four content
  /// badges: a PDF is not TXT, JSON, CODE or URL, and colouring it as one of
  /// them would make the list lie about what opens.
  final BadgeColors badgeFile;
  final Color danger;

  /// Applies the user's accent choice on top of a theme's base palette.
  ///
  /// The design darkens the accent to `#E0511F` on light ("assombri pour tenir
  /// 4,5:1 sur blanc") and lightens it to `#FF7A4F` on OLED. Only the default
  /// orange has those hand-tuned variants, so any other swatch is adjusted the
  /// same direction rather than used raw against a background it was never
  /// checked against.
  JotPalette withAccent(JotAccent choice) {
    if (choice == JotAccent.orange) return this;

    final tuned = isLight
        ? _shade(choice.color, -0.22)
        : (elevated ? choice.color : _shade(choice.color, 0.12));

    return copyWith(
      accent: tuned,
      onAccent: isLight ? const Color(0xFFFFFFFF) : onAccent,
    );
  }

  /// Darkens (`amount < 0`) or lightens (`amount > 0`) towards black/white.
  static Color _shade(Color c, double amount) {
    final target = amount < 0 ? 0.0 : 255.0;
    final t = amount.abs();
    double mix(double channel) => channel + (target - channel) * t;
    return Color.fromARGB(
      (c.a * 255).round(),
      mix(c.r * 255).round().clamp(0, 255),
      mix(c.g * 255).round().clamp(0, 255),
      mix(c.b * 255).round().clamp(0, 255),
    );
  }

  JotPalette copyWith({Color? accent, Color? onAccent}) => JotPalette(
        id: id,
        isLight: isLight,
        elevated: elevated,
        background: background,
        surface: surface,
        surfaceRaised: surfaceRaised,
        surfaceSunken: surfaceSunken,
        border: border,
        borderStrong: borderStrong,
        textPrimary: textPrimary,
        textBody: textBody,
        textMuted: textMuted,
        textDim: textDim,
        textDisabled: textDisabled,
        accent: accent ?? this.accent,
        onAccent: onAccent ?? this.onAccent,
        syntaxKey: syntaxKey,
        syntaxString: syntaxString,
        syntaxNumber: syntaxNumber,
        syntaxKeyword: syntaxKeyword,
        syntaxPunctuation: syntaxPunctuation,
        badgeJson: badgeJson,
        badgeCode: badgeCode,
        badgeUrl: badgeUrl,
        badgeText: badgeText,
        badgeFile: badgeFile,
        danger: danger,
      );

  /// Picks the palette for the current settings and platform brightness.
  ///
  /// "Le mode OLED reste un choix explicite, jamais automatique", following
  /// the system only ever chooses between Clair and Anthracite, even if the
  /// user last picked OLED by hand.
  static JotPalette resolve(AppSettings settings, Brightness systemBrightness) {
    if (settings.followSystemTheme) {
      return systemBrightness == Brightness.light ? light : anthracite;
    }
    return switch (settings.theme) {
      JotThemeMode.light => light,
      JotThemeMode.anthracite => anthracite,
      JotThemeMode.oled => oled,
    };
  }

  // ------------------------------------------------------------------ 6a
  /// "fond F7F7F5, surface FFFFFF, filet E3E3DE · accent E0511F, assombri pour
  /// tenir 4,5:1 sur blanc · syntaxe désaturée."
  static const light = JotPalette(
    id: 'light',
    isLight: true,
    elevated: true,
    background: Color(0xFFF7F7F5),
    surface: Color(0xFFFFFFFF),
    surfaceRaised: Color(0xFFFFFFFF),
    surfaceSunken: Color(0xFFF0F0ED),
    border: Color(0xFFE3E3DE),
    borderStrong: Color(0xFFC6C6BE),
    textPrimary: Color(0xFF1A1B1D),
    textBody: Color(0xFF5F6169),
    textMuted: Color(0xFF8A8C93),
    textDim: Color(0xFF9A9CA3),
    textDisabled: Color(0xFFB4B6BB),
    accent: Color(0xFFE0511F),
    onAccent: Color(0xFFFFFFFF),
    syntaxKey: Color(0xFF1F6FCC),
    syntaxString: Color(0xFF2F7D45),
    syntaxNumber: Color(0xFFB0521B),
    syntaxKeyword: Color(0xFF6D4BB8),
    syntaxPunctuation: Color(0xFF5F6169),
    badgeJson: BadgeColors(Color(0xFFB0521B), Color(0xFFFBEEDF)),
    badgeCode: BadgeColors(Color(0xFF6D4BB8), Color(0xFFEFEAFB)),
    badgeUrl: BadgeColors(Color(0xFF1F6FCC), Color(0xFFE6F0FC)),
    badgeText: BadgeColors(Color(0xFF5F6169), Color(0xFFECECE8)),
    badgeFile: BadgeColors(Color(0xFF2F7D6B), Color(0xFFE2F0EC)),
    danger: Color(0xFFC4443C),
  );

  // ------------------------------------------------------------------ 6b
  /// "fond 17181B, surface 1E1F23, filet 2A2C31 · accent FF6A3D sur texte
  /// sombre 140A06 · élévations autorisées."
  static const anthracite = JotPalette(
    id: 'anthracite',
    isLight: false,
    elevated: true,
    background: Color(0xFF17181B),
    surface: Color(0xFF1E1F23),
    surfaceRaised: Color(0xFF22242A),
    surfaceSunken: Color(0xFF1A1B1F),
    border: Color(0xFF2A2C31),
    borderStrong: Color(0xFF3E4048),
    textPrimary: Color(0xFFF3F4F6),
    textBody: Color(0xFFC6C8CE),
    textMuted: Color(0xFF9A9CA3),
    textDim: Color(0xFF5F6169),
    textDisabled: Color(0xFF4A4C53),
    accent: Color(0xFFFF6A3D),
    onAccent: Color(0xFF140A06),
    syntaxKey: Color(0xFF7FB2F0),
    syntaxString: Color(0xFFC3E88D),
    syntaxNumber: Color(0xFFF0A15E),
    syntaxKeyword: Color(0xFFC792EA),
    syntaxPunctuation: Color(0xFF6C6E76),
    badgeJson: BadgeColors(Color(0xFFE3B341), Color(0x24E3B341)),
    badgeCode: BadgeColors(Color(0xFFA78BFA), Color(0x24A78BFA)),
    badgeUrl: BadgeColors(Color(0xFF58A6FF), Color(0x2458A6FF)),
    badgeText: BadgeColors(Color(0xFF8B8D95), Color(0x12FFFFFF)),
    badgeFile: BadgeColors(Color(0xFF5EC8A8), Color(0x245EC8A8)),
    danger: Color(0xFFE5534B),
  );

  // ------------------------------------------------------------------ 6c
  /// "fond 000000 partout, aucune carte grise · séparation par filets 1F1F22,
  /// zéro ombre portée · accent éclairci FF7A4F, texte mini 6B6B70 pour éviter
  /// l'écrasement des noirs."
  ///
  /// Every surface token collapses to pure black on purpose: the separation
  /// comes from [border], not from stacked greys.
  static const oled = JotPalette(
    id: 'oled',
    isLight: false,
    elevated: false,
    background: Color(0xFF000000),
    surface: Color(0xFF000000),
    surfaceRaised: Color(0xFF000000),
    surfaceSunken: Color(0xFF000000),
    border: Color(0xFF1F1F22),
    borderStrong: Color(0xFF37373C),
    textPrimary: Color(0xFFEDEDEF),
    textBody: Color(0xFFC9C9CD),
    textMuted: Color(0xFF9C9CA2),
    textDim: Color(0xFF6B6B70),
    textDisabled: Color(0xFF4A4A4F),
    accent: Color(0xFFFF7A4F),
    onAccent: Color(0xFF160800),
    syntaxKey: Color(0xFF8CBCF5),
    syntaxString: Color(0xFFCBEE96),
    syntaxNumber: Color(0xFFE8BC53),
    syntaxKeyword: Color(0xFFB79CFB),
    syntaxPunctuation: Color(0xFF9C9CA2),
    // On OLED a badge is an outline, not a fill: transparent background with a
    // 1px tinted border.
    badgeJson: BadgeColors(Color(0xFFE8BC53), Color(0x00000000), Color(0xFF3A3116)),
    badgeCode: BadgeColors(Color(0xFFB79CFB), Color(0x00000000), Color(0xFF2C2350)),
    badgeUrl: BadgeColors(Color(0xFF6FB2FF), Color(0x00000000), Color(0xFF16304F)),
    badgeText: BadgeColors(Color(0xFF9C9CA2), Color(0x00000000), Color(0xFF2A2A2E)),
    badgeFile: BadgeColors(Color(0xFF74D6B8), Color(0x00000000), Color(0xFF13332B)),
    danger: Color(0xFFF2645B),
  );

  static const all = [light, anthracite, oled];

  // --------------------------------------------------------- desktop ramp
  //
  // Section 6 renders the *mobile* screen, which only needs background /
  // surface / border. The desktop's three columns need a longer ramp. These
  // are resolved per theme rather than stored as fields so the three palettes
  // above stay readable as the design's own token list.
  //
  // Anthracite keeps the exact values from screens 1a–3d. Light follows the
  // 2c thumbnail (sidebar EAEAE6, list F0F0ED) reconciled with 6a's rendered
  // values. OLED collapses every surface to black, per "aucune carte grise" -
  // the separation is the hairline, not a shade.

  bool get _oled => id == 'oled';
  bool get _light => id == 'light';

  /// Title bar and sidebar, the darkest chrome.
  Color get chrome => _oled
      ? const Color(0xFF000000)
      : (_light ? const Color(0xFFEFEFEC) : const Color(0xFF131417));

  /// Middle column.
  Color get listSurface => _oled
      ? const Color(0xFF000000)
      : (_light ? const Color(0xFFF0F0ED) : const Color(0xFF1A1B1F));

  /// Right column / mobile cards.
  Color get editorSurface => _oled
      ? const Color(0xFF000000)
      : (_light ? const Color(0xFFFFFFFF) : const Color(0xFF1E1F23));

  /// Search palette and quick-capture body.
  Color get paletteSurface => _oled
      ? const Color(0xFF000000)
      : (_light ? const Color(0xFFFFFFFF) : const Color(0xFF1F2125));

  /// Footer strips under the palette and capture window.
  Color get footer => _oled
      ? const Color(0xFF000000)
      : (_light ? const Color(0xFFF7F7F5) : const Color(0xFF1B1D21));

  /// Inset fields and keycaps.
  Color get field => _oled
      ? const Color(0xFF000000)
      : (_light ? const Color(0xFFFFFFFF) : const Color(0xFF1B1C20));

  /// Code / JSON panel and its header strip.
  Color get codePanel => _oled
      ? const Color(0xFF000000)
      : (_light ? const Color(0xFFFCFCFB) : const Color(0xFF1A1B1F));

  Color get codePanelHeader => _oled
      ? const Color(0xFF000000)
      : (_light ? const Color(0xFFF3F3F0) : const Color(0xFF181A1D));

  /// Segmented-control trough.
  Color get panel => _oled
      ? const Color(0xFF000000)
      : (_light ? const Color(0xFFECECE8) : const Color(0xFF141518));

  /// Quick-capture title bar.
  Color get captureBar => _oled
      ? const Color(0xFF000000)
      : (_light ? const Color(0xFFF3F3F0) : const Color(0xFF191A1E));

  Color get keycap => _oled
      ? const Color(0xFF000000)
      : (_light ? const Color(0xFFECECE8) : const Color(0xFF23252A));

  // Border ramp. OLED uses the single hairline value everywhere except where
  // the design calls for the stronger one (the selected row's top rule).
  Color get borderSubtle => _oled
      ? const Color(0xFF1F1F22)
      : (_light ? const Color(0xFFE3E3DE) : const Color(0xFF23252A));

  Color get borderEditor => _oled
      ? const Color(0xFF1F1F22)
      : (_light ? const Color(0xFFE3E3DE) : const Color(0xFF26282D));

  Color get borderWindow => _oled
      ? const Color(0xFF232326)
      : (_light ? const Color(0xFFE3E3DE) : const Color(0xFF2A2C31));

  Color get borderPalette => _oled
      ? const Color(0xFF1F1F22)
      : (_light ? const Color(0xFFE3E3DE) : const Color(0xFF2C2E34));

  Color get borderTag => _oled
      ? const Color(0xFF2A2A2E)
      : (_light ? const Color(0xFFDEDEDA) : const Color(0xFF2E3037));

  Color get borderRaised => _oled
      ? const Color(0xFF37373C)
      : (_light ? const Color(0xFFC6C6BE) : const Color(0xFF34363D));

  Color get borderPaletteOuter => _oled
      ? const Color(0xFF37373C)
      : (_light ? const Color(0xFFC6C6BE) : const Color(0xFF383A42));

  Color get borderCapture => _oled
      ? const Color(0xFF37373C)
      : (_light ? const Color(0xFFC6C6BE) : const Color(0xFF3A3C43));

  /// Neutral overlay used for hover / wash states. White on dark, black on
  /// light, a white wash on a white surface is invisible.
  Color overlay(double opacity) => _light
      ? Color.fromRGBO(0, 0, 0, opacity)
      : Color.fromRGBO(255, 255, 255, opacity);

  /// Accent-tinted wash at [opacity].
  Color accentWash(double opacity) =>
      accent.withValues(alpha: opacity);

  /// Scrim behind modals.
  Color get scrim => _light
      ? const Color(0x66FFFFFF).withValues(alpha: 0.55)
      : const Color(0xB308090B);

  /// Shadows are suppressed entirely on OLED ("zéro ombre portée"), and the
  /// light theme softens the window shadow from .5 to .45 alpha.
  List<BoxShadow> shadow(List<BoxShadow> value) {
    if (!elevated) return const [];
    if (!_light) return value;
    return [
      for (final s in value)
        BoxShadow(
          color: s.color.withValues(alpha: s.color.a * 0.9),
          offset: s.offset,
          blurRadius: s.blurRadius,
          spreadRadius: s.spreadRadius,
        ),
    ];
  }
}

/// Foreground / background pair for a type badge, plus an optional outline -
/// OLED draws badges as outlines instead of fills.
@immutable
class BadgeColors {
  const BadgeColors(this.foreground, this.background, [this.outline]);

  final Color foreground;
  final Color background;
  final Color? outline;
}
