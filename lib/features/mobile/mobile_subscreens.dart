import 'dart:io';

import 'package:flutter/material.dart' show Scaffold, showDialog;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_version.dart';
import '../../core/theme/jot_theme.dart';
import '../../core/utils/jot_format.dart';
import '../../data/vault_paths.dart';
import '../../state/jot_services.dart';
import '../../state/settings_notifier.dart';
import '../../state/vault_notifier.dart';
import '../main_window/widgets/prompt_dialog.dart';
import '../settings/widgets/settings_controls.dart';
import 'mobile_settings.dart';

/// The remaining Réglages subscreens on the phone.
///
/// They exist because a settings row that carries a value but does nothing
/// when tapped is worse than no row at all: it promises a screen. Each of
/// these is the phone shape of one desktop tab, built from the same three
/// shared pieces.

/// Général: the startup and content settings from tab 2a that still make
/// sense on a phone. "Lancer au démarrage" and "fermer dans la zone de
/// notification" are desktop-only and deliberately absent.
class MobileGeneralScreen extends ConsumerWidget {
  const MobileGeneralScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    return _Screen(
      title: 'Général',
      children: [
        MobileSection(
          title: 'Notes',
          rows: [
            MobileRow(
              label: 'Dossier par défaut',
              value: settings.defaultFolder,
              onTap: () async {
                final folder = await _pickFolder(context, ref, settings.defaultFolder);
                if (folder != null) {
                  notifier.update((s) => s.copyWith(defaultFolder: folder));
                }
              },
            ),
            MobileRow(
              label: 'Détection automatique du type',
              trailing: JotSwitch(
                large: true,
                value: settings.autoDetectType,
                onChanged: (v) => notifier.update((s) => s.copyWith(autoDetectType: v)),
              ),
            ),
            MobileRow(
              label: "Reformater le JSON à l'enregistrement",
              trailing: JotSwitch(
                large: true,
                value: settings.reformatJsonOnSave,
                onChanged: (v) =>
                    notifier.update((s) => s.copyWith(reformatJsonOnSave: v)),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Capture rapide: the phone has no global hotkey, so the shortcut row from
/// tab 3a is replaced by the settings that do apply.
class MobileCaptureScreen extends ConsumerWidget {
  const MobileCaptureScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    return _Screen(
      title: 'Capture rapide',
      children: [
        MobileSection(
          title: 'Enregistrement',
          rows: [
            MobileRow(
              label: 'Dossier de destination',
              value: settings.captureFolder,
              onTap: () async {
                final folder = await _pickFolder(context, ref, settings.captureFolder);
                if (folder != null) {
                  notifier.update((s) => s.copyWith(captureFolder: folder));
                }
              },
            ),
            MobileRow(
              label: 'Titre automatique',
              trailing: JotSwitch(
                large: true,
                value: settings.autoTitle,
                onChanged: (v) => notifier.update((s) => s.copyWith(autoTitle: v)),
              ),
            ),
            MobileRow(
              label: 'Pré-remplir avec le presse-papier',
              trailing: JotSwitch(
                large: true,
                value: settings.prefillFromClipboard,
                onChanged: (v) =>
                    notifier.update((s) => s.copyWith(prefillFromClipboard: v)),
              ),
            ),
            MobileRow(
              label: 'Fermer après enregistrement',
              trailing: JotSwitch(
                large: true,
                value: settings.closeAfterSave,
                onChanged: (v) => notifier.update((s) => s.copyWith(closeAfterSave: v)),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Stockage: real measurements, not the design's decorative figures.
class MobileStorageScreen extends ConsumerStatefulWidget {
  const MobileStorageScreen({super.key});

  @override
  ConsumerState<MobileStorageScreen> createState() => _MobileStorageScreenState();
}

class _MobileStorageScreenState extends ConsumerState<MobileStorageScreen> {
  int? _vaultBytes;
  int? _indexBytes;
  int _trash = 0;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _measure();
  }

  Future<void> _measure() async {
    final services = ref.read(servicesProvider);

    var vault = 0;
    await for (final file in services.files.noteFiles()) {
      vault += await file.length();
    }

    var index = 0;
    try {
      final f = await VaultPaths.indexFile();
      if (await f.exists()) index = await f.length();
    } on Object {
      // The index is a cache; failing to size it is not worth an error.
    }

    final trash = await services.files.listTrash();
    if (mounted) {
      setState(() {
        _vaultBytes = vault;
        _indexBytes = index;
        _trash = trash.length;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final services = ref.watch(servicesProvider);
    final retention = ref.watch(settingsProvider.select((s) => s.trashRetentionDays));

    return _Screen(
      title: 'Stockage',
      children: [
        MobileSection(
          title: 'Sur cet appareil',
          rows: [
            MobileRow(
              label: 'Notes',
              value: '${ref.watch(vaultProvider).totalNotes}',
            ),
            MobileRow(
              label: 'Coffre',
              value: _vaultBytes == null ? '...' : JotFormat.bytes(_vaultBytes!),
            ),
            MobileRow(
              label: 'Index de recherche',
              value: _indexBytes == null ? '...' : JotFormat.bytes(_indexBytes!),
            ),
            MobileRow(label: 'Corbeille', value: '$_trash'),
          ],
        ),
        const SizedBox(height: 18),
        MobileSection(
          title: 'Emplacement',
          rows: [
            MobileRow(
              label: 'Dossier',
              value: Platform.isAndroid || Platform.isIOS
                  ? 'JotVault'
                  : services.files.root.path.split(Platform.pathSeparator).last,
            ),
          ],
        ),
        const SizedBox(height: 18),
        MobileSection(
          title: 'Entretien',
          rows: [
            MobileRow(
              label: _busy ? 'Reconstruction...' : "Reconstruire l'index",
              onTap: _busy
                  ? null
                  : () async {
                      setState(() => _busy = true);
                      await ref.read(vaultProvider.notifier).rebuildIndex();
                      await _measure();
                      if (mounted) setState(() => _busy = false);
                    },
            ),
            MobileRow(
              label: 'Vider la corbeille',
              value: '$_trash en attente',
              onTap: () async {
                await ref.read(vaultProvider.notifier).emptyTrash();
                await _measure();
              },
            ),
            MobileRow(
              label: 'Purge automatique',
              value: '$retention jours',
              onTap: () async {
                const options = [7, 30, 90, 365];
                final picked = await showDialog<String>(
                  context: context,
                  barrierColor: JotColors.scrim,
                  builder: (_) => FolderPickerDialog(
                    folders: options.map((d) => '$d jours').toList(),
                    current: '$retention jours',
                  ),
                );
                final days = int.tryParse(picked?.split(' ').first ?? '');
                if (days != null) {
                  ref
                      .read(settingsProvider.notifier)
                      .update((s) => s.copyWith(trashRetentionDays: days));
                }
              },
            ),
          ],
        ),
      ],
    );
  }
}

/// À propos. No update channel and no version check: the app contacts no
/// server, so offering either would be a claim it cannot keep.
class MobileAboutScreen extends StatelessWidget {
  const MobileAboutScreen({super.key});

  @override
  Widget build(BuildContext context) => _Screen(
        title: 'À propos',
        children: [
          MobileSection(
            rows: [
              MobileRow(label: 'Version', value: AppVersion.full),
              MobileRow(label: 'Système', value: Platform.operatingSystem),
              MobileRow(label: 'Stockage', value: 'Fichiers .md locaux'),
              MobileRow(label: 'Recherche', value: 'SQLite FTS5'),
            ],
          ),
          const SizedBox(height: 18),
          MobileSection(
            title: 'Licences',
            rows: [
              MobileRow(
                label: 'JetBrains Mono',
                value: 'SIL OFL 1.1',
              ),
              MobileRow(label: 'Lucide', value: 'ISC'),
            ],
          ),
          const SizedBox(height: 18),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              'Aucune télémétrie. Toutes les notes restent sur cet appareil.',
              style: JotText.mono(
                size: 11,
                height: 1.5,
                color: JotColors.textDisabled,
              ),
            ),
          ),
        ],
      );
}

/// Folders and tags, with the counts that make the row worth opening.
class MobileFoldersScreen extends ConsumerWidget {
  const MobileFoldersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(vaultProvider);

    return _Screen(
      title: 'Dossiers & tags',
      children: [
        MobileSection(
          title: 'Dossiers',
          rows: [
            for (final folder in state.folders)
              MobileRow(
                label: folder.name,
                value: '${folder.noteCount}',
                onTap: () {
                  ref
                      .read(vaultProvider.notifier)
                      .selectScope(FolderScope(folder.name));
                  Navigator.of(context)
                    ..pop()
                    ..pop();
                },
              ),
          ],
        ),
        if (state.tags.isNotEmpty) ...[
          const SizedBox(height: 18),
          MobileSection(
            title: 'Tags',
            rows: [
              for (final tag in state.tags)
                MobileRow(
                  label: '#${tag.name}',
                  value: '${tag.noteCount}',
                  onTap: () {
                    ref
                        .read(vaultProvider.notifier)
                        .selectScope(TagScope(tag.name));
                    Navigator.of(context)
                      ..pop()
                      ..pop();
                  },
                ),
            ],
          ),
        ],
      ],
    );
  }
}

/// Shared scaffold: header with a back affordance to Réglages, then a
/// scrolling body.
class _Screen extends StatelessWidget {
  const _Screen({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: JotColors.window,
        body: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              MobileHeader(title: title, parent: 'Réglages'),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
                  children: children,
                ),
              ),
            ],
          ),
        ),
      );
}

Future<String?> _pickFolder(
  BuildContext context,
  WidgetRef ref,
  String current,
) async {
  final folders = ref.read(vaultProvider).folders.map((f) => f.name).toList();
  if (!context.mounted) return null;
  return showDialog<String>(
    context: context,
    barrierColor: JotColors.scrim,
    builder: (_) => FolderPickerDialog(folders: folders, current: current),
  );
}
