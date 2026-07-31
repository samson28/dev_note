import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/jot_theme.dart';
import '../../../core/utils/jot_format.dart';
import '../../../data/file_repository.dart';
import '../../../state/settings_notifier.dart';
import '../../../state/vault_notifier.dart';
import '../../../widgets/jot_primitives.dart';
import '../../../widgets/note_card.dart';

/// The trash, filling the list and editor columns.
///
/// Deletion in Jot is one click with a single confirmation, which is what
/// keeps it fast. This is the other half of that bargain: nothing is actually
/// gone until the retention window expires, and until then it can be put back
/// exactly where it was.
class TrashPane extends ConsumerStatefulWidget {
  const TrashPane({super.key});

  @override
  ConsumerState<TrashPane> createState() => _TrashPaneState();
}

class _TrashPaneState extends ConsumerState<TrashPane> {
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
    final retention = ref.watch(settingsProvider.select((s) => s.trashRetentionDays));
    final entries = _entries;

    return Expanded(
      child: ColoredBox(
        color: JotColors.editorSurface,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Header(
              count: entries?.length ?? 0,
              onEmpty: entries == null || entries.isEmpty
                  ? null
                  : () async {
                      await ref.read(vaultProvider.notifier).emptyTrash();
                      await _load();
                    },
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
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                          itemCount: entries.length,
                          itemBuilder: (context, i) => _TrashRow(
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

class _Header extends StatelessWidget {
  const _Header({required this.count, required this.onEmpty});

  final int count;
  final VoidCallback? onEmpty;

  @override
  Widget build(BuildContext context) => Container(
        height: JotMetrics.paneHeaderHeight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: JotColors.borderEditor)),
        ),
        child: Row(
          children: [
            Text(
              'Corbeille',
              style: JotText.ui(
                size: 13.5,
                weight: FontWeight.w600,
                color: JotColors.textBright,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              '$count note${count == 1 ? '' : 's'}',
              style: JotText.mono(size: 11, color: JotColors.textSubtle),
            ),
            const Spacer(),
            if (onEmpty != null)
              JotButton(
                'Vider la corbeille',
                kind: JotButtonKind.danger,
                onTap: onEmpty,
              ),
          ],
        ),
      );
}

class _TrashRow extends StatelessWidget {
  const _TrashRow({
    required this.entry,
    required this.retentionDays,
    required this.onRestore,
    required this.onPurge,
  });

  final TrashedNote entry;
  final int retentionDays;
  final VoidCallback onRestore;
  final VoidCallback onPurge;

  @override
  Widget build(BuildContext context) {
    final remaining = retentionDays -
        DateTime.now().difference(entry.deletedAt).inDays;

    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: JotColors.codePanel,
          border: Border.all(color: JotColors.borderEditor),
          borderRadius: BorderRadius.circular(8),
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
                      size: 13,
                      weight: FontWeight.w600,
                      color: JotColors.textStrong,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Depuis ${entry.originalPath}, supprimée '
                    '${JotFormat.relative(entry.deletedAt)}, '
                    '${remaining <= 0 ? 'purge imminente' : 'purge dans $remaining j'}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: JotText.mono(size: 11, color: JotColors.textSubtle),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            JotButton(
              'Restaurer',
              kind: JotButtonKind.secondary,
              onTap: onRestore,
            ),
            const SizedBox(width: 8),
            JotButton(
              'Supprimer',
              kind: JotButtonKind.danger,
              onTap: onPurge,
            ),
          ],
        ),
      ),
    );
  }
}
