import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/app_settings.dart';
import '../../../core/theme/jot_theme.dart';
import '../../../state/settings_notifier.dart';
import '../../../widgets/jot_primitives.dart';
import '../settings_window.dart';
import '../widgets/settings_controls.dart';
import 'general_tab.dart' show pickFolder;

/// 3a — Capture rapide : ouverture, enregistrement, et l'aperçu de la
/// mini-fenêtre.
class QuickCaptureTab extends ConsumerWidget {
  const QuickCaptureTab({super.key, required this.onDone});

  final VoidCallback onDone;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final combo = settings.shortcutFor(ShortcutAction.quickCapture);

    return SettingsPane(
      gap: 16,
      sections: [
        SettingsSection(
          title: 'Ouverture',
          child: SettingsCard(
            children: [
              SettingRow(
                label: 'Raccourci global',
                help: 'Ouvre la mini-fenêtre où que tu sois, sans voler le focus au reste.',
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                trailing: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final part in combo.parts) ...[
                        if (part != combo.parts.first) const SizedBox(width: 4),
                        ShortcutChip(part),
                      ],
                    ],
                  ),
                ],
              ),
              SettingRow(
                label: "Position à l'ouverture",
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                trailing: [
                  JotSegmented<CapturePosition>(
                    options: CapturePosition.values,
                    value: settings.capturePosition,
                    labelOf: (p) => p.label,
                    onChanged: (p) => notifier.update((s) => s.copyWith(capturePosition: p)),
                  ),
                ],
              ),
              SettingRow(
                label: 'Toujours au premier plan',
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                trailing: [
                  JotSwitch(
                    value: settings.captureAlwaysOnTop,
                    onChanged: (v) =>
                        notifier.update((s) => s.copyWith(captureAlwaysOnTop: v)),
                  ),
                ],
              ),
              SettingRow(
                label: 'Pré-remplir avec le presse-papier',
                help: "Le contenu copié est déjà là, prêt à enregistrer.",
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                trailing: [
                  JotSwitch(
                    value: settings.prefillFromClipboard,
                    onChanged: (v) =>
                        notifier.update((s) => s.copyWith(prefillFromClipboard: v)),
                  ),
                ],
              ),
            ],
          ),
        ),
        SettingsSection(
          title: 'Enregistrement',
          child: SettingsCard(
            children: [
              SettingRow(
                label: 'Dossier de destination',
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                trailing: [
                  JotSelect(
                    label: settings.captureFolder,
                    onTap: () async {
                      final folder =
                          await pickFolder(context, ref, settings.captureFolder);
                      if (folder != null) {
                        notifier.update((s) => s.copyWith(captureFolder: folder));
                      }
                    },
                  ),
                ],
              ),
              SettingRow(
                label: 'Fermer la fenêtre après enregistrement',
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                trailing: [
                  JotSwitch(
                    value: settings.closeAfterSave,
                    onChanged: (v) => notifier.update((s) => s.copyWith(closeAfterSave: v)),
                  ),
                ],
              ),
              SettingRow(
                label: 'Titre automatique',
                help: "Première ligne, clé racine du JSON, ou domaine de l'URL.",
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                trailing: [
                  JotSwitch(
                    value: settings.autoTitle,
                    onChanged: (v) => notifier.update((s) => s.copyWith(autoTitle: v)),
                  ),
                ],
              ),
              SettingRow(
                label: 'Notification après enregistrement',
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                trailing: [
                  JotSwitch(
                    value: settings.notifyAfterSave,
                    onChanged: (v) => notifier.update((s) => s.copyWith(notifyAfterSave: v)),
                  ),
                ],
              ),
            ],
          ),
        ),
        SettingsSection(
          title: 'Aperçu de la mini-fenêtre',
          gap: 8,
          child: Align(
            alignment: Alignment.centerLeft,
            child: _CapturePreview(folder: settings.captureFolder, combo: combo),
          ),
        ),
      ],
      footer: SettingsFooter(
        status: 'la capture n\'ouvre ni index ni watcher, elle écrit un fichier',
        actions: [JotButton('Terminé', onTap: onDone)],
      ),
    );
  }
}

/// A scaled-down, non-interactive copy of the capture window.
class _CapturePreview extends StatelessWidget {
  const _CapturePreview({required this.folder, required this.combo});

  final String folder;
  final KeyCombo combo;

  @override
  Widget build(BuildContext context) => Container(
        width: 420,
        decoration: BoxDecoration(
          color: JotColors.palette,
          border: Border.all(color: JotColors.borderCapture),
          borderRadius: BorderRadius.circular(10),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: 30,
              padding: const EdgeInsets.symmetric(horizontal: 11),
              decoration: BoxDecoration(
                color: JotColors.captureBar,
                border: Border(bottom: BorderSide(color: JotColors.borderPalette)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: JotColors.accent,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Capture rapide',
                    style: JotText.ui(
                      size: 10.5,
                      weight: FontWeight.w600,
                      color: JotColors.textBody,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    combo.parts.join(' '),
                    style: JotText.mono(
                      size: 9.5,
                      weight: FontWeight.w500,
                      color: JotColors.textSubtle,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
              child: Text(
                'Note rapide...',
                style: JotText.mono(size: 12, height: 1.6, color: JotColors.textDisabled),
              ),
            ),
            Container(
              height: 36,
              padding: const EdgeInsets.only(left: 13, right: 10),
              decoration: BoxDecoration(
                color: JotColors.footer,
                border: Border(top: BorderSide(color: JotColors.borderPalette)),
              ),
              child: Row(
                children: [
                  Text(
                    folder,
                    style: JotText.mono(size: 10, color: JotColors.textSubtle),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                    decoration: BoxDecoration(
                      color: JotColors.accent,
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Text(
                      'Enregistrer Entrée',
                      style: JotText.ui(
                        size: 10.5,
                        weight: FontWeight.w600,
                        color: JotColors.onAccent,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}
