import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart' show showDialog;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../../core/models/app_settings.dart';
import '../../../core/theme/jot_theme.dart';
import '../../../core/utils/jot_format.dart';
import '../../../data/vault_paths.dart';
import '../../../state/jot_services.dart';
import '../../../state/settings_notifier.dart';
import '../../../state/vault_notifier.dart';
import '../../../widgets/jot_primitives.dart';
import '../../main_window/widgets/prompt_dialog.dart';
import '../settings_window.dart';
import '../widgets/settings_controls.dart';

/// 3b — Stockage & sauvegarde.
class StorageTab extends ConsumerStatefulWidget {
  const StorageTab({super.key, required this.onDone});

  final VoidCallback onDone;

  @override
  ConsumerState<StorageTab> createState() => _StorageTabState();
}

class _StorageTabState extends ConsumerState<StorageTab> {
  _Stats? _stats;
  String? _busy;

  @override
  void initState() {
    super.initState();
    _refreshStats();
  }

  Future<void> _refreshStats() async {
    final services = ref.read(servicesProvider);

    var vaultBytes = 0;
    await for (final file in services.files.noteFiles()) {
      vaultBytes += await file.length();
    }

    var indexBytes = 0;
    try {
      final index = await VaultPaths.indexFile();
      if (await index.exists()) indexBytes = await index.length();
    } on Object {
      // The index is a cache; not being able to size it is not worth an error.
    }

    final trash = await services.files.listTrash();
    final notes = await services.index.count();

    if (mounted) {
      setState(() => _stats = _Stats(
            notes: notes,
            vaultBytes: vaultBytes,
            indexBytes: indexBytes,
            trashCount: trash.length,
          ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final services = ref.watch(servicesProvider);
    final stats = _stats;

    return SettingsPane(
      gap: 16,
      sections: [
        Row(
          children: [
            Expanded(
              child: StatTile(label: 'Notes', value: '${stats?.notes ?? 0}'),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: StatTile(
                label: 'Coffre',
                value: JotFormat.bytes(stats?.vaultBytes ?? 0),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: StatTile(
                label: 'Index recherche',
                value: JotFormat.bytes(stats?.indexBytes ?? 0),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: StatTile(label: 'Corbeille', value: '${stats?.trashCount ?? 0}'),
            ),
          ],
        ),
        SettingsSection(
          title: 'Emplacement',
          child: SettingsCard(
            children: [
              SettingRow(
                label: 'Dossier de données',
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                helpWidget: Text(
                  services.files.root.path,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: JotText.mono(size: 11.5, height: 1.4, color: JotColors.textDim),
                ),
                trailing: [
                  JotRowButton(
                    label: 'Ouvrir',
                    onTap: () => _openInExplorer(services.files.root.path),
                  ),
                ],
              ),
              SettingRow(
                label: "Reconstruire l'index de recherche",
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                help: services.index.lastRebuild == null
                    ? 'Relit tout le coffre et reconstruit la table FTS5.'
                    : 'Dernière reconstruction : '
                        '${services.index.lastRebuild!.inMilliseconds} ms pour '
                        '${stats?.notes ?? 0} notes.',
                trailing: [
                  JotRowButton(
                    label: _busy == 'index' ? 'En cours...' : 'Reconstruire',
                    onTap: () async {
                      setState(() => _busy = 'index');
                      await ref.read(vaultProvider.notifier).rebuildIndex();
                      await _refreshStats();
                      if (mounted) setState(() => _busy = null);
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
        SettingsSection(
          title: 'Sauvegarde & export',
          child: SettingsCard(
            children: [
              SettingRow(
                label: 'Sauvegarde automatique',
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                help: 'Copie le coffre dans le dossier de sauvegarde à chaque démarrage.',
                trailing: [
                  JotSelect(
                    label: settings.backupFrequency.label,
                    onTap: () => _pickBackupFrequency(context, notifier, settings),
                  ),
                  JotSwitch(
                    value: settings.backupEnabled,
                    onChanged: (v) => notifier.update((s) => s.copyWith(backupEnabled: v)),
                  ),
                ],
              ),
              SettingRow(
                label: 'Exporter toutes les notes',
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                trailing: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      JotRowButton(
                        label: '.json',
                        mono: true,
                        onTap: () => _export(context, ref, json: true),
                      ),
                      const SizedBox(width: 6),
                      JotRowButton(
                        label: '.md',
                        mono: true,
                        onTap: () => _export(context, ref, json: false),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
        SettingsSection(
          title: 'Zone sensible',
          child: SettingsCard(
            danger: true,
            children: [
              SettingRow(
                label: 'Vider la corbeille',
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                help: '${stats?.trashCount ?? 0} note(s) supprimée(s), purge automatique '
                    'après ${settings.trashRetentionDays} jours.',
                trailing: [
                  JotSelect(
                    label: '${settings.trashRetentionDays} jours',
                    onTap: () => _pickRetention(context, notifier, settings),
                  ),
                  JotRowButton(
                    label: 'Vider',
                    danger: true,
                    onTap: () async {
                      await services.files.emptyTrash();
                      await _refreshStats();
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
      footer: SettingsFooter(
        status: '100 % hors ligne, aucune donnée envoyée',
        actions: [JotButton('Terminé', onTap: widget.onDone)],
      ),
    );
  }

  Future<void> _pickBackupFrequency(
    BuildContext context,
    SettingsNotifier notifier,
    AppSettings settings,
  ) async {
    final picked = await showDialog<String>(
      context: context,
      barrierColor: JotColors.scrim,
      builder: (_) => FolderPickerDialog(
        folders: BackupFrequency.values.map((f) => f.label).toList(),
        current: settings.backupFrequency.label,
      ),
    );
    if (picked == null) return;
    final choice = BackupFrequency.values.firstWhere((f) => f.label == picked);
    notifier.update((s) => s.copyWith(backupFrequency: choice));
  }

  Future<void> _pickRetention(
    BuildContext context,
    SettingsNotifier notifier,
    AppSettings settings,
  ) async {
    const options = [7, 30, 90, 365];
    final picked = await showDialog<String>(
      context: context,
      barrierColor: JotColors.scrim,
      builder: (_) => FolderPickerDialog(
        folders: options.map((d) => '$d jours').toList(),
        current: '${settings.trashRetentionDays} jours',
      ),
    );
    if (picked == null) return;
    final days = int.tryParse(picked.split(' ').first);
    if (days != null) notifier.update((s) => s.copyWith(trashRetentionDays: days));
  }

  Future<void> _export(BuildContext context, WidgetRef ref, {required bool json}) async {
    final services = ref.read(servicesProvider);
    final notes = await services.files.readAll();

    final stamp = DateTime.now().toIso8601String().replaceAll(RegExp(r'[:.]'), '-');
    final target = File(
      p.join(services.files.root.path, 'export-$stamp.${json ? 'json' : 'md'}'),
    );

    if (json) {
      const encoder = JsonEncoder.withIndent('  ');
      await target.writeAsString(encoder.convert([
        for (final n in notes)
          {
            'id': n.id,
            'title': n.title,
            'type': n.type.id,
            'folder': n.folder,
            'tags': n.tags,
            'created': n.created.toIso8601String(),
            'modified': n.modified.toIso8601String(),
            'pinned': n.pinned,
            'content': n.content,
          },
      ]));
    } else {
      final buffer = StringBuffer();
      for (final n in notes) {
        buffer
          ..writeln('# ${n.title}')
          ..writeln()
          ..writeln('_${n.folder}, ${n.type.label}'
              '${n.tags.isEmpty ? '' : ', ${n.tags.map((t) => '#$t').join(' ')}'}_')
          ..writeln()
          ..writeln(n.content)
          ..writeln()
          ..writeln('---')
          ..writeln();
      }
      await target.writeAsString(buffer.toString());
    }

    await _refreshStats();
    _openInExplorer(services.files.root.path);
  }

  void _openInExplorer(String path) {
    try {
      if (Platform.isWindows) {
        Process.run('explorer', [path]);
      } else if (Platform.isMacOS) {
        Process.run('open', [path]);
      } else if (Platform.isLinux) {
        Process.run('xdg-open', [path]);
      }
    } on Object {
      // Opening a file manager is a convenience, never a failure path.
    }
  }
}

class _Stats {
  const _Stats({
    required this.notes,
    required this.vaultBytes,
    required this.indexBytes,
    required this.trashCount,
  });

  final int notes;
  final int vaultBytes;
  final int indexBytes;
  final int trashCount;
}
