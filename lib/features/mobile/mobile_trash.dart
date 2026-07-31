import 'package:flutter/material.dart' show Scaffold;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/jot_theme.dart';
import '../../core/utils/jot_format.dart';
import '../../data/file_repository.dart';
import '../../state/settings_notifier.dart';
import '../../state/vault_notifier.dart';
import '../../widgets/jot_icons.dart';
import '../../widgets/jot_primitives.dart';
import '../../widgets/note_card.dart' show EmptyState;
import 'mobile_settings.dart';

/// The trash on the phone.
///
/// The desktop version fills two columns and reveals its two actions on hover.
/// A phone has no hover and no second column, so both actions are always
/// visible as icon buttons on the right of each row, at a 40px touch target.
class MobileTrashScreen extends ConsumerStatefulWidget {
  const MobileTrashScreen({super.key});

  @override
  ConsumerState<MobileTrashScreen> createState() => _MobileTrashScreenState();
}

class _MobileTrashScreenState extends ConsumerState<MobileTrashScreen> {
  List<TrashedNote>? _entries;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final entries = await ref.read(vaultProvider.notifier).loadTrash();
    if (mounted) setState(() => _entries = entries);
  }

  @override
  Widget build(BuildContext context) {
    final retention =
        ref.watch(settingsProvider.select((s) => s.trashRetentionDays));
    final entries = _entries;

    return Scaffold(
      backgroundColor: JotColors.window,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const MobileHeader(title: 'Corbeille', parent: 'Dev Note'),
            if (entries != null && entries.isNotEmpty)
              Container(
                padding: const EdgeInsets.fromLTRB(18, 12, 14, 12),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: JotColors.borderSubtle),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${entries.length} note${entries.length == 1 ? '' : 's'}, '
                        'purge après $retention jours',
                        style: JotText.mono(
                          size: 11.5,
                          color: JotColors.textFaint,
                        ),
                      ),
                    ),
                    Hoverable(
                      onTap: () async {
                        await ref.read(vaultProvider.notifier).emptyTrash();
                        await _load();
                      },
                      builder: (context, _) => Container(
                        height: 32,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          border: Border.all(color: JotColors.dangerBorder),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Tout vider',
                          style: JotText.ui(
                            size: 12.5,
                            color: JotColors.danger,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: entries == null
                  ? const SizedBox.shrink()
                  : entries.isEmpty
                      ? const EmptyState(
                          title: 'La corbeille est vide',
                          message: 'Les notes supprimées atterrissent ici avant '
                              'leur purge, et peuvent être restaurées.',
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
                          itemCount: entries.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 8),
                          itemBuilder: (context, i) => _TrashCard(
                            entry: entries[i],
                            retentionDays: retention,
                            onRestore: () async {
                              await ref
                                  .read(vaultProvider.notifier)
                                  .restoreFromTrash(entries[i]);
                              await _load();
                            },
                            onPurge: () async {
                              await ref
                                  .read(vaultProvider.notifier)
                                  .purgeFromTrash(entries[i]);
                              await _load();
                            },
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrashCard extends StatelessWidget {
  const _TrashCard({
    required this.entry,
    required this.retentionDays,
    required this.onRestore,
    required this.onPurge,
  });

  final TrashedNote entry;
  final int retentionDays;
  final Future<void> Function() onRestore;
  final Future<void> Function() onPurge;

  @override
  Widget build(BuildContext context) {
    final left = retentionDays -
        DateTime.now().difference(entry.deletedAt).inDays;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      decoration: BoxDecoration(
        color: JotColors.editorSurface,
        border: Border.all(color: JotColors.borderWindow),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: JotText.ui(
                    size: 14,
                    weight: FontWeight.w500,
                    color: JotColors.textBright,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '${JotFormat.relative(entry.deletedAt)} · '
                  '${left <= 0 ? 'purge imminente' : 'purge dans $left j'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: JotText.mono(size: 11, color: JotColors.textFaint),
                ),
              ],
            ),
          ),
          _Action(
            icon: JotIcons.restore,
            color: JotColors.textDim,
            onTap: onRestore,
          ),
          _Action(
            icon: JotIcons.trash,
            color: JotColors.danger,
            onTap: onPurge,
          ),
        ],
      ),
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({required this.icon, required this.color, required this.onTap});

  final IconData icon;
  final Color color;
  final Future<void> Function() onTap;

  @override
  Widget build(BuildContext context) => Hoverable(
        onTap: onTap,
        builder: (context, hovered) => Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: hovered ? JotColors.neutralWash : null,
            borderRadius: BorderRadius.circular(10),
          ),
          child: JotIcon(icon, size: 17, color: color),
        ),
      );
}
