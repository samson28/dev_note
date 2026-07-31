import 'package:flutter/material.dart' show showDialog;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/note_type.dart';
import '../../../core/theme/jot_theme.dart';
import '../../../state/settings_notifier.dart';
import '../../../state/vault_notifier.dart';
import '../../../widgets/jot_primitives.dart';
import '../../../widgets/type_badge.dart';
import '../../main_window/widgets/prompt_dialog.dart';
import '../settings_window.dart';
import '../widgets/settings_controls.dart';

/// 2a — Général : démarrage et contenu.
class GeneralTab extends ConsumerWidget {
  const GeneralTab({super.key, required this.onDone});

  final VoidCallback onDone;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    return SettingsPane(
      sections: [
        SettingsSection(
          title: 'Démarrage',
          child: SettingsCard(
            children: [
              SettingRow(
                label: 'Lancer Jot au démarrage de Windows',
                help: 'Démarre en arrière-plan, icône dans la zone de notification.',
                trailing: [
                  JotSwitch(
                    value: settings.launchAtStartup,
                    onChanged: (v) => notifier.update((s) => s.copyWith(launchAtStartup: v)),
                  ),
                ],
              ),
              SettingRow(
                label: 'Fermer réduit dans la zone de notification',
                help: "Garde l'index en mémoire pour une ouverture instantanée.",
                trailing: [
                  JotSwitch(
                    value: settings.closeToTray,
                    onChanged: (v) => notifier.update((s) => s.copyWith(closeToTray: v)),
                  ),
                ],
              ),
              SettingRow(
                label: 'Dossier par défaut des nouvelles notes',
                trailing: [
                  JotSelect(
                    label: settings.defaultFolder,
                    onTap: () async {
                      final folder = await _pickFolder(context, ref, settings.defaultFolder);
                      if (folder != null) {
                        notifier.update((s) => s.copyWith(defaultFolder: folder));
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
        SettingsSection(
          title: 'Contenu',
          child: SettingsCard(
            children: [
              SettingRow(
                label: 'Détection automatique du type',
                help: 'JSON, code, URL, sinon texte simple.',
                trailing: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const TypeBadge.roomy(NoteType.json),
                      const SizedBox(width: 5),
                      const TypeBadge.roomy(NoteType.code),
                      const SizedBox(width: 5),
                      const TypeBadge.roomy(NoteType.url),
                      const SizedBox(width: 11),
                      JotSwitch(
                        value: settings.autoDetectType,
                        onChanged: (v) =>
                            notifier.update((s) => s.copyWith(autoDetectType: v)),
                      ),
                    ],
                  ),
                ],
              ),
              SettingRow(
                label: "Reformater le JSON à l'enregistrement",
                help: 'Indentation 2 espaces, clés conservées dans l\'ordre.',
                trailing: [
                  JotSwitch(
                    value: settings.reformatJsonOnSave,
                    onChanged: (v) =>
                        notifier.update((s) => s.copyWith(reformatJsonOnSave: v)),
                  ),
                ],
              ),
              SettingRow(
                label: 'Masquer les valeurs des notes taguées',
                labelWidget: Text.rich(
                  TextSpan(
                    children: [
                      const TextSpan(text: 'Masquer les valeurs des notes taguées '),
                      TextSpan(
                        text: '#creds',
                        style: JotText.mono(size: 12.5, color: JotColors.textMuted),
                      ),
                    ],
                  ),
                  style: JotText.ui(
                    size: 12.5,
                    weight: FontWeight.w500,
                    height: 1.3,
                    color: JotColors.textPrimary,
                  ),
                ),
                help: "Affiche •••• jusqu'au survol ou à la copie.",
                trailing: [
                  JotSwitch(
                    value: settings.maskCredentialValues,
                    onChanged: (v) =>
                        notifier.update((s) => s.copyWith(maskCredentialValues: v)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
      footer: SettingsFooter(
        status: 'réglages appliqués immédiatement',
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
}

/// Shared folder picker used by several tabs.
Future<String?> _pickFolder(BuildContext context, WidgetRef ref, String current) async {
  final folders = ref.read(vaultProvider).folders.map((f) => f.name).toList();
  if (!context.mounted) return null;
  return showDialog<String>(
    context: context,
    barrierColor: JotColors.scrim,
    builder: (_) => FolderPickerDialog(folders: folders, current: current),
  );
}

/// Re-exported so the other tabs can reuse it.
Future<String?> pickFolder(BuildContext context, WidgetRef ref, String current) =>
    _pickFolder(context, ref, current);
