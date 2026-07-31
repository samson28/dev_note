import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/app_settings.dart';
import '../../../core/theme/jot_theme.dart';
import '../../../state/settings_notifier.dart';
import '../../../widgets/jot_primitives.dart';
import '../settings_window.dart';
import '../widgets/settings_controls.dart';

/// 2c, Apparence, avec aperçu live.
class AppearanceTab extends ConsumerWidget {
  const AppearanceTab({super.key, required this.onDone});

  final VoidCallback onDone;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    return SettingsPane(
      gap: 18,
      sections: [
        SettingsSection(
          title: 'Thème',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  for (final mode in JotThemeMode.values) ...[
                    if (mode != JotThemeMode.values.first) const SizedBox(width: 10),
                    Expanded(
                      child: _ThemeCard(
                        mode: mode,
                        selected: settings.theme == mode,
                        onTap: () => notifier.update((s) => s.copyWith(theme: mode)),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 10),
              SettingsCard(
                children: [
                  SettingRow(
                    label: 'Suivre le thème de Windows',
                    help: 'Bascule automatiquement entre Anthracite et Clair.',
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                    trailing: [
                      JotSwitch(
                        value: settings.followSystemTheme,
                        onChanged: (v) =>
                            notifier.update((s) => s.copyWith(followSystemTheme: v)),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
        SettingsSection(
          title: "Couleur d'accent",
          child: SettingsCard(
            children: [
              SettingRow(
                label: 'Un seul accent, utilisé partout',
                helpWidget: Text(
                  '${_hex(settings.accent.color)}, actions primaires, sélection, épinglé',
                  style: JotText.mono(size: 11.5, height: 1.4, color: JotColors.textFaint),
                ),
                trailing: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final accent in JotAccent.values) ...[
                        if (accent != JotAccent.values.first) const SizedBox(width: 8),
                        _Swatch(
                          accent: accent,
                          selected: settings.accent == accent,
                          onTap: () => notifier.update((s) => s.copyWith(accent: accent)),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
        SettingsSection(
          title: 'Typographie',
          child: SettingsCard(
            children: [
              SettingRow(
                label: "Police de l'interface",
                trailing: [JotSelect(label: JotFonts.ui, onTap: () {})],
              ),
              SettingRow(
                label: 'Police du contenu technique',
                trailing: [JotSelect(label: JotFonts.mono, mono: true, onTap: () {})],
              ),
              SettingRow(
                label: 'Taille du texte',
                trailing: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('11', style: JotText.mono(size: 11, color: JotColors.textSubtle)),
                      const SizedBox(width: 10),
                      JotSlider(
                        value: settings.textSize,
                        min: 11,
                        max: 18,
                        onChanged: (v) => notifier
                            .update((s) => s.copyWith(textSize: v.roundToDouble())),
                      ),
                      const SizedBox(width: 10),
                      Text('18', style: JotText.mono(size: 11, color: JotColors.textSubtle)),
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 38,
                        child: Text(
                          '${settings.textSize.round()} px',
                          style: JotText.mono(size: 11.5, color: JotColors.textMuted),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              SettingRow(
                label: 'Ligatures dans le code',
                trailing: [
                  Text(
                    '=>  !=  ===',
                    style: JotText.mono(size: 12, color: JotColors.textFaint),
                  ),
                  JotSwitch(
                    value: settings.codeLigatures,
                    onChanged: (v) => notifier.update((s) => s.copyWith(codeLigatures: v)),
                  ),
                ],
              ),
            ],
          ),
        ),
        SettingsSection(
          title: 'Liste des notes',
          child: SettingsCard(
            children: [
              SettingRow(
                label: 'Densité',
                trailing: [
                  JotSegmented<ListDensity>(
                    options: ListDensity.values,
                    value: settings.density,
                    labelOf: (d) => d.label,
                    onChanged: (d) => notifier.update((s) => s.copyWith(density: d)),
                  ),
                ],
              ),
              SettingRow(
                label: "Lignes d'extrait",
                trailing: [
                  JotSegmented<int>(
                    options: const [0, 1, 2, 3],
                    value: settings.previewLines,
                    mono: true,
                    onChanged: (n) => notifier.update((s) => s.copyWith(previewLines: n)),
                  ),
                ],
              ),
              SettingRow(
                label: "Numéros de ligne dans l'éditeur",
                trailing: [
                  JotSwitch(
                    value: settings.showLineNumbers,
                    onChanged: (v) => notifier.update((s) => s.copyWith(showLineNumbers: v)),
                  ),
                ],
              ),
            ],
          ),
        ),
        SettingsSection(
          title: 'Aperçu',
          gap: 8,
          child: _LivePreview(settings: settings),
        ),
      ],
      footer: SettingsFooter(
        status: 'aperçu en direct, aucun redémarrage requis',
        actions: [
          JotButton(
            'Réinitialiser',
            kind: JotButtonKind.secondary,
            onTap: notifier.resetAll,
          ),
          JotButton('Terminé', onTap: onDone),
        ],
      ),
    );
  }

  static String _hex(Color c) {
    final value = (c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0');
    return '#${value.toUpperCase()}';
  }
}

/// One of the three theme cards, with the miniature three-column mock the
/// design draws inside it.
class _ThemeCard extends StatelessWidget {
  const _ThemeCard({required this.mode, required this.selected, required this.onTap});

  final JotThemeMode mode;
  final bool selected;
  final VoidCallback onTap;

  /// (window, sidebar, list, editor, divider, barStrong, barWeak)
  ({Color window, Color side, Color list, Color editor, Color rule, Color strong, Color weak})
      get _swatch => switch (mode) {
            JotThemeMode.anthracite => (
                window: const Color(0xFF17181B),
                side: const Color(0xFF131417),
                list: const Color(0xFF1A1B1F),
                editor: const Color(0xFF17181B),
                rule: const Color(0xFF23252A),
                strong: const Color(0xFF2E3037),
                weak: const Color(0xFF26282D),
              ),
            JotThemeMode.oled => (
                window: const Color(0xFF0C0D0F),
                side: const Color(0xFF08090A),
                list: const Color(0xFF101113),
                editor: const Color(0xFF0C0D0F),
                rule: const Color(0xFF17181B),
                strong: const Color(0xFF25272C),
                weak: const Color(0xFF1C1E22),
              ),
            JotThemeMode.light => (
                window: const Color(0xFFF4F4F2),
                side: const Color(0xFFEAEAE6),
                list: const Color(0xFFF0F0ED),
                editor: const Color(0xFFF4F4F2),
                rule: const Color(0xFFDEDEDA),
                strong: const Color(0xFFBFBFB9),
                weak: const Color(0xFFD5D5D0),
              ),
          };

  @override
  Widget build(BuildContext context) {
    final s = _swatch;

    return Hoverable(
      onTap: onTap,
      builder: (context, hovered) => Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: JotColors.codePanel,
          border: Border.all(
            color: selected
                ? JotColors.accent
                : (hovered ? JotColors.borderRaised : JotColors.borderWindow),
            width: selected ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: 64,
              decoration: BoxDecoration(
                color: s.window,
                border: Border.all(color: s.rule),
                borderRadius: BorderRadius.circular(5),
              ),
              clipBehavior: Clip.antiAlias,
              child: Row(
                children: [
                  Expanded(flex: 24, child: ColoredBox(color: s.side)),
                  Container(width: 1, color: s.rule),
                  Expanded(
                    flex: 34,
                    child: Container(
                      color: s.list,
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                      child: _bars(s, const [0.8, 0.6]),
                    ),
                  ),
                  Container(width: 1, color: s.rule),
                  Expanded(
                    flex: 42,
                    child: Container(
                      color: s.editor,
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                      child: _bars(s, const [0.7, 0.88]),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _Radio(selected: selected),
                const SizedBox(width: 7),
                Flexible(
                  child: Text(
                    mode.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: JotText.ui(
                      size: 12,
                      weight: selected ? FontWeight.w500 : FontWeight.w400,
                      color: selected ? JotColors.textBright : JotColors.textBody,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _bars(
    ({Color window, Color side, Color list, Color editor, Color rule, Color strong, Color weak}) s,
    List<double> widths,
  ) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < widths.length; i++) ...[
            if (i > 0) const SizedBox(height: 5),
            FractionallySizedBox(
              widthFactor: widths[i],
              child: Container(
                height: i == 0 ? 5 : 4,
                decoration: BoxDecoration(
                  color: i == 0 ? s.strong : s.weak,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ],
        ],
      );
}

class _Radio extends StatelessWidget {
  const _Radio({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) => Container(
        width: 13,
        height: 13,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? JotColors.accent : JotColors.borderCapture,
            width: 1.5,
          ),
        ),
        child: selected
            ? Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: JotColors.accent,
                  shape: BoxShape.circle,
                ),
              )
            : null,
      );
}

class _Swatch extends StatelessWidget {
  const _Swatch({required this.accent, required this.selected, required this.onTap});

  final JotAccent accent;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Hoverable(
        onTap: onTap,
        builder: (context, _) => Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: accent.color,
            borderRadius: BorderRadius.circular(6),
            // `box-shadow: 0 0 0 1.5px <bg>, 0 0 0 3px <accent>`, a ring
            // separated from the swatch by a gap of window background.
            boxShadow: selected
                ? [
                    BoxShadow(color: JotColors.window, spreadRadius: 1.5),
                    BoxShadow(color: accent.color, spreadRadius: 3),
                  ]
                : null,
          ),
        ),
      );
}

/// The live preview pair: a note row on the left, a JSON snippet on the right,
/// both reflecting the current typography and density settings.
class _LivePreview extends StatelessWidget {
  const _LivePreview({required this.settings});

  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    final compact = settings.density == ListDensity.compact;
    final mono = settings.textSize - 1;

    // IntrinsicHeight so the two panels match: a bare `stretch` Row inside the
    // pane's scroll view would be asked for an unbounded height and throw.
    return IntrinsicHeight(
      child: Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: 250,
          child: Container(
            decoration: BoxDecoration(
              color: JotColors.codePanel,
              borderRadius: BorderRadius.circular(8),
              // Selected preview uses the stronger hairline, matching the
              // note cards since the design dropped the accent edge.
              border: Border.all(color: JotColors.active.borderStrong),
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              children: [
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 13,
                    vertical: compact ? 8 : 11,
                  ),
                  child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'webhook checkout.session',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: JotText.ui(
                              size: settings.textSize,
                              weight: FontWeight.w600,
                              height: 1.25,
                              color: JotColors.textBright,
                            ),
                          ),
                        ),
                        const SizedBox(width: 7),
                        const PinMark(),
                      ],
                    ),
                    if (settings.previewLines > 0) ...[
                      const SizedBox(height: 6),
                      Text(
                        '{ "id": "evt_1PqR2sK9x", "type": "checkout.session.completed" }',
                        maxLines: settings.previewLines,
                        overflow: TextOverflow.ellipsis,
                        style: JotText.mono(
                          size: mono - 1,
                          height: 1.5,
                          color: JotColors.previewOnSelected,
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0x24E3B341),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text(
                            'JSON',
                            style: JotText.badge.copyWith(color: const Color(0xFFE3B341)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text('il y a 4 min', style: JotText.metaTime),
                      ],
                    ),
                  ],
                ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
            decoration: BoxDecoration(
              color: JotColors.codePanel,
              border: Border.all(color: JotColors.borderEditor),
              borderRadius: BorderRadius.circular(8),
            ),
            child: DefaultTextStyle(
              style: JotText.mono(size: mono, height: 1.75),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text.rich(TextSpan(children: [
                    TextSpan(text: '▾ ', style: TextStyle(color: JotSyntax.chevron)),
                    TextSpan(text: '{', style: TextStyle(color: JotSyntax.punctuation)),
                  ])),
                  _line('"currency"', '"eur"', JotSyntax.string, comma: true),
                  _line('"amount_total"', '4900', JotSyntax.number, comma: true),
                  _line('"livemode"', 'false', JotSyntax.keyword),
                  Text('}', style: TextStyle(color: JotSyntax.punctuation)),
                ],
              ),
            ),
          ),
        ),
      ],
      ),
    );
  }

  Widget _line(String key, String value, Color valueColor, {bool comma = false}) => Padding(
        padding: const EdgeInsets.only(left: 20),
        child: Text.rich(
          TextSpan(
            children: [
              TextSpan(text: key, style: TextStyle(color: JotSyntax.key)),
              TextSpan(text: ': ', style: TextStyle(color: JotSyntax.punctuation)),
              TextSpan(text: value, style: TextStyle(color: valueColor)),
              if (comma)
                TextSpan(text: ',', style: TextStyle(color: JotSyntax.punctuation)),
            ],
          ),
        ),
      );
}
