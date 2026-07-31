import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/note.dart';
import '../../../core/theme/jot_theme.dart';
import '../../../core/utils/jot_format.dart';
import '../../../state/search_notifier.dart';
import '../../../state/vault_notifier.dart';
import '../../../widgets/jot_icons.dart';
import '../../../widgets/jot_primitives.dart';
import '../../../widgets/type_badge.dart';
import '../../import/file_import.dart';

/// What the right column shows when no note is open.
///
/// It replaces a dead-end "Aucune note sélectionnée", and it is why the app no
/// longer opens a note on your behalf at launch: landing inside a note means
/// the app has already decided what you came for, and this one exists for
/// capture and retrieval, not reading.
///
/// It is deliberately not a screen in front of the app, nothing has to be
/// dismissed to start typing. It is the resting state of a column that was
/// empty anyway.
class HomePanel extends ConsumerWidget {
  const HomePanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(vaultProvider);
    final pinned = state.recent.where((n) => n.pinned).take(4).toList();
    final recent = state.recent.where((n) => !n.pinned).take(8).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(28, 30, 28, 28),
      children: [
        Text(
          'Dev Note',
          style: JotText.ui(
            size: 22,
            weight: FontWeight.w600,
            height: 1.2,
            color: JotColors.textBright,
          ),
        ),
        const SizedBox(height: 7),
        Text(
          state.totalNotes == 0
              ? 'Le coffre est vide.'
              : '${state.totalNotes} note${state.totalNotes == 1 ? '' : 's'}, '
                  '${state.folders.length} dossier${state.folders.length == 1 ? '' : 's'}, '
                  '${state.tags.length} tag${state.tags.length == 1 ? '' : 's'}',
          style: JotText.mono(size: 12, color: JotColors.textFaint),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            _Action(
              icon: JotIcons.plus,
              label: 'Nouvelle note',
              primary: true,
              onTap: () => ref.read(vaultProvider.notifier).create(),
            ),
            const SizedBox(width: 8),
            _Action(
              icon: JotIcons.import_,
              label: 'Importer un fichier',
              onTap: () => pickAndImportFiles(ref),
            ),
            const SizedBox(width: 8),
            _Action(
              icon: JotIcons.search,
              label: 'Rechercher',
              shortcut: 'Ctrl K',
              onTap: () => ref.read(searchProvider.notifier).openPalette(),
            ),
          ],
        ),
        if (pinned.isNotEmpty) ...[
          const SizedBox(height: 26),
          const SectionLabel('Épinglées'),
          const SizedBox(height: 10),
          for (final note in pinned) _HomeRow(note: note),
        ],
        if (recent.isNotEmpty) ...[
          const SizedBox(height: 26),
          const SectionLabel('Reprendre'),
          const SizedBox(height: 10),
          for (final note in recent) _HomeRow(note: note),
        ],
        if (state.totalNotes == 0) ...[
          const SizedBox(height: 26),
          Text(
            'Colle un extrait, une URL ou un bout de JSON : le type est '
            'détecté tout seul. Un fichier déposé sur la fenêtre atterrit ici '
            'aussi.',
            style: JotText.ui(
              size: 13,
              height: 1.6,
              color: JotColors.textSubtle,
            ),
          ),
        ],
      ],
    );
  }
}

/// One note on the home panel: badge, title, folder and when it was touched.
///
/// Flatter than the list column's row on purpose, this is a way back into
/// work, not a place to select and act on things.
class _HomeRow extends ConsumerWidget {
  const _HomeRow({required this.note});

  final Note note;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Hoverable(
          onTap: () => ref.read(vaultProvider.notifier).reveal(note),
          builder: (context, hovered) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: hovered ? JotColors.neutralWash : null,
              border: Border.all(
                color: hovered ? JotColors.borderRaised : JotColors.borderEditor,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                TypeBadge(note.type),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    note.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: JotText.ui(
                      size: 13,
                      weight: FontWeight.w500,
                      color: JotColors.textStrong,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  note.folder,
                  style: JotText.ui(size: 11.5, color: JotColors.textSubtle),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 74,
                  child: Text(
                    JotFormat.relative(note.modified),
                    textAlign: TextAlign.right,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: JotText.mono(size: 11, color: JotColors.textFaint),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

class _Action extends StatelessWidget {
  const _Action({
    required this.icon,
    required this.label,
    required this.onTap,
    this.shortcut,
    this.primary = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final String? shortcut;
  final bool primary;

  @override
  Widget build(BuildContext context) => Hoverable(
        onTap: onTap,
        builder: (context, hovered) => Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: primary
                ? (hovered ? JotColors.accentHover : JotColors.accent)
                : (hovered ? JotColors.neutralWash : null),
            border: primary ? null : Border.all(color: JotColors.borderRaised),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              JotIcon(
                icon,
                size: 14,
                color: primary ? JotColors.onAccent : JotColors.textBody,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: JotText.ui(
                  size: 12.5,
                  weight: primary ? FontWeight.w600 : FontWeight.w400,
                  color: primary ? JotColors.onAccent : JotColors.textBody,
                ),
              ),
              if (shortcut != null) ...[
                const SizedBox(width: 9),
                Keycap(shortcut!),
              ],
            ],
          ),
        ),
      );
}
