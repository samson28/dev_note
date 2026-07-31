import 'package:flutter/material.dart' show Scaffold;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/app_settings.dart';
import '../../core/theme/jot_theme.dart';
import '../../state/settings_notifier.dart';
import '../../widgets/jot_primitives.dart';
import '../settings/widgets/settings_controls.dart';
import 'mobile_settings.dart';

/// 4b — Réglages, Apparence.
///
/// The three theme cards are stacked previews rather than the desktop's
/// three-column miniatures: a phone only ever shows one column, so the mock
/// shows stacked lines instead.
class MobileAppearanceScreen extends ConsumerWidget {
  const MobileAppearanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    return Scaffold(
      backgroundColor: JotColors.window,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const MobileHeader(title: 'Apparence', parent: 'Réglages'),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(4, 0, 4, 9),
                    child: SectionLabel('Thème'),
                  ),
                  Row(
                    children: [
                      for (final mode in JotThemeMode.values) ...[
                        if (mode != JotThemeMode.values.first)
                          const SizedBox(width: 9),
                        Expanded(
                          child: _ThemeCard(
                            mode: mode,
                            selected: settings.theme == mode &&
                                !settings.followSystemTheme,
                            onTap: () => notifier.update(
                              (s) => s.copyWith(
                                theme: mode,
                                followSystemTheme: false,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 18),
                  MobileSection(
                    rows: [
                      MobileRow(
                        label: 'Suivre le système',
                        trailing: JotSwitch(
                          large: true,
                          value: settings.followSystemTheme,
                          onChanged: (v) => notifier
                              .update((s) => s.copyWith(followSystemTheme: v)),
                        ),
                      ),
                      MobileRow(
                        label: 'Accent',
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            for (final accent in JotAccent.values.take(4)) ...[
                              if (accent != JotAccent.values.first)
                                const SizedBox(width: 8),
                              Hoverable(
                                onTap: () => notifier
                                    .update((s) => s.copyWith(accent: accent)),
                                builder: (context, _) => Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    color: accent.color,
                                    borderRadius: BorderRadius.circular(7),
                                    boxShadow: settings.accent == accent
                                        ? [
                                            BoxShadow(
                                              color: JotColors.editorSurface,
                                              spreadRadius: 1.5,
                                            ),
                                            BoxShadow(
                                              color: accent.color,
                                              spreadRadius: 3,
                                            ),
                                          ]
                                        : null,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(4, 0, 4, 9),
                    child: SectionLabel('Texte'),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: JotColors.editorSurface,
                      border: Border.all(color: JotColors.borderWindow),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      'Taille',
                                      style: JotText.ui(
                                        size: 14,
                                        color: JotColors.textPrimary,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    '${settings.textSize.round()} px',
                                    style: JotText.mono(
                                      size: 12.5,
                                      color: JotColors.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 11),
                              LayoutBuilder(
                                builder: (context, c) => JotSlider(
                                  large: true,
                                  width: c.maxWidth,
                                  value: settings.textSize,
                                  min: 11,
                                  max: 18,
                                  onChanged: (v) => notifier.update(
                                    (s) => s.copyWith(
                                      textSize: v.roundToDouble(),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Hairline(
                          color: JotColors.borderEditor,
                          inset: const EdgeInsets.symmetric(horizontal: 14),
                        ),
                        MobileRow(
                          label: "Lignes d'extrait",
                          trailing: JotSegmented<int>(
                            large: true,
                            mono: true,
                            options: const [1, 2, 3],
                            value: settings.previewLines.clamp(1, 3),
                            onChanged: (n) => notifier
                                .update((s) => s.copyWith(previewLines: n)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A stacked-lines preview of one theme, in that theme's own colours.
class _ThemeCard extends StatelessWidget {
  const _ThemeCard({
    required this.mode,
    required this.selected,
    required this.onTap,
  });

  final JotThemeMode mode;
  final bool selected;
  final VoidCallback onTap;

  /// Deliberately literal: each card must show *its* palette, not the active
  /// one, so these cannot come from JotColors.
  ({Color surface, Color rule, Color strong, Color weak}) get _swatch =>
      switch (mode) {
        JotThemeMode.anthracite => (
            surface: const Color(0xFF17181B),
            rule: const Color(0xFF26282D),
            strong: const Color(0xFF2E3037),
            weak: const Color(0xFF26282D),
          ),
        JotThemeMode.oled => (
            surface: const Color(0xFF0C0D0F),
            rule: const Color(0xFF1E1F23),
            strong: const Color(0xFF25272C),
            weak: const Color(0xFF1C1E22),
          ),
        JotThemeMode.light => (
            surface: const Color(0xFFF4F4F2),
            rule: const Color(0xFFDEDEDA),
            strong: const Color(0xFFBFBFB9),
            weak: const Color(0xFFD5D5D0),
          ),
      };

  /// The design labels the OLED card "OLED" on the phone, where the desktop
  /// spells out "Noir profond (OLED)".
  String get _label => mode == JotThemeMode.oled ? 'OLED' : mode.label;

  @override
  Widget build(BuildContext context) {
    final s = _swatch;

    return Hoverable(
      onTap: onTap,
      builder: (context, _) => Container(
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: JotColors.editorSurface,
          border: Border.all(
            color: selected ? JotColors.accent : JotColors.borderWindow,
            width: selected ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(11),
        ),
        child: Column(
          children: [
            Container(
              height: 74,
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 8),
              decoration: BoxDecoration(
                color: s.surface,
                border: Border.all(color: s.rule),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final bar in const [(0.76, 5.0), (0.56, 4.0), (0.66, 4.0)]) ...[
                    FractionallySizedBox(
                      widthFactor: bar.$1,
                      child: Container(
                        height: bar.$2,
                        decoration: BoxDecoration(
                          color: bar.$2 == 5.0 ? s.strong : s.weak,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 5),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 7),
            Text(
              _label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: JotText.ui(
                size: 11.5,
                weight: selected ? FontWeight.w500 : FontWeight.w400,
                color: selected ? JotColors.textBright : JotColors.textBody,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
