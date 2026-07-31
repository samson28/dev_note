import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/app_settings.dart';
import '../../../core/theme/jot_theme.dart';
import '../../../state/settings_notifier.dart';
import '../../../widgets/json_viewer.dart' show copyToClipboard;
import '../settings_window.dart';
import '../widgets/settings_controls.dart';

/// 3c — À propos & mises à jour.
class AboutTab extends ConsumerWidget {
  const AboutTab({super.key});

  static const version = '1.4.0';

  // Not named `build`: that would collide with the widget's own build method.
  static const buildNumber = '1402';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    return SettingsPane(
      gap: 18,
      padding: const EdgeInsets.all(24),
      sections: [
        Row(
          children: [
            Container(
              width: 52,
              height: 52,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: JotColors.accent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'J',
                style: JotText.ui(
                  size: 22,
                  weight: FontWeight.w600,
                  color: JotColors.onAccent,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Jot',
                  style: JotText.ui(
                    size: 17,
                    weight: FontWeight.w600,
                    color: JotColors.textBright,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '$version (build $buildNumber), canal ${settings.updateChannel.label.toLowerCase()}',
                  style: JotText.mono(size: 11.5, color: JotColors.textDim),
                ),
              ],
            ),
          ],
        ),
        SettingsCard(
          children: [
            SettingRow(
              label: 'Mises à jour',
              help: 'Jot ne contacte aucun serveur, les mises à jour sont manuelles.',
              trailing: [
                JotSegmented<UpdateChannel>(
                  options: UpdateChannel.values,
                  value: settings.updateChannel,
                  labelOf: (c) => c.label,
                  onChanged: (c) => notifier.update((s) => s.copyWith(updateChannel: c)),
                ),
              ],
            ),
            SettingRow(
              label: 'Installer automatiquement au redémarrage',
              trailing: [
                JotSwitch(
                  value: settings.autoInstallUpdates,
                  onChanged: (v) =>
                      notifier.update((s) => s.copyWith(autoInstallUpdates: v)),
                ),
              ],
            ),
          ],
        ),
        SettingsSection(
          title: 'Nouveautés $version',
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
            decoration: BoxDecoration(
              color: JotColors.codePanel,
              border: Border.all(color: JotColors.borderEditor),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                _Change.added('Repli/dépli du JSON par nœud, avec compteur de clés masquées.'),
                SizedBox(height: 8),
                _Change.added('Filtres par type dans la palette de recherche.'),
                SizedBox(height: 8),
                _Change.changed('Corbeille avec purge automatique et restauration.'),
              ],
            ),
          ),
        ),
        Row(
          children: [
            JotRowButton(
              label: 'Licences open source',
              onTap: () => _showLicenses(context),
            ),
            const SizedBox(width: 8),
            JotRowButton(
              label: 'Copier les infos système',
              mono: true,
              onTap: () => copyToClipboard(_systemInfo(settings)),
            ),
          ],
        ),
      ],
      footer: SettingsFooter(
        status: 'Flutter 3.44, Dart 3.12, SQLite FTS5\n'
            'Aucune télémétrie. Toutes les notes restent sur cette machine.',
      ),
    );
  }

  static String _systemInfo(AppSettings settings) => [
        'Jot $version (build $buildNumber)',
        'Canal : ${settings.updateChannel.label}',
        'OS : ${Platform.operatingSystem} ${Platform.operatingSystemVersion}',
        'Dart : ${Platform.version}',
      ].join('\n');

  static void _showLicenses(BuildContext context) {
    // JetBrains Mono ships with the app under the SIL OFL; the file lives
    // alongside the fonts so the licence travels with the binary.
    copyToClipboard('assets/fonts/OFL.txt : JetBrains Mono, SIL Open Font License 1.1');
  }
}

class _Change extends StatelessWidget {
  const _Change.added(this.text) : marker = '+', accent = true;
  const _Change.changed(this.text) : marker = '~', accent = false;

  final String text;
  final String marker;
  final bool accent;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            marker,
            style: JotText.mono(
              size: 11,
              height: 1.5,
              weight: FontWeight.w500,
              color: accent ? JotColors.accent : JotColors.textDim,
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              text,
              style: JotText.ui(size: 12.5, height: 1.5, color: JotColors.textBody),
            ),
          ),
        ],
      );
}
