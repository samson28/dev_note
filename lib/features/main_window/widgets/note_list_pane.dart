import 'package:flutter/material.dart' show showDialog;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/app_settings.dart';
import '../../../core/models/note.dart';
import '../../../core/theme/jot_theme.dart';
import '../../../core/utils/jot_format.dart';
import '../../../state/settings_notifier.dart';
import '../../../state/vault_notifier.dart';
import '../../../widgets/jot_icons.dart';
import '../../../widgets/jot_primitives.dart';
import '../../import/file_import.dart';
import '../../../widgets/json_viewer.dart' show copyToClipboard;
import '../../../widgets/note_card.dart';
import 'note_context_menu.dart';
import 'prompt_dialog.dart';

/// Middle column, 340px: header with the scope name, the sort control and the
/// "+" button, then the notes grouped into "Épinglées" and date buckets.
class NoteListPane extends ConsumerWidget {
  const NoteListPane({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(vaultProvider);

    return Container(
      width: JotMetrics.noteListWidth,
      decoration: BoxDecoration(
        color: JotColors.listSurface,
        border: Border(right: BorderSide(color: JotColors.borderSubtle)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Header(scope: state.scope),
          Expanded(
            child: state.notes.isEmpty
                ? _EmptyScope(scope: state.scope)
                : _NoteList(state: state),
          ),
        ],
      ),
    );
  }
}

class _Header extends ConsumerWidget {
  const _Header({required this.scope});

  final Scope scope;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Container(
        height: JotMetrics.paneHeaderHeight,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: JotColors.borderSubtle)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                scope.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: JotText.ui(
                  size: 13,
                  weight: FontWeight.w600,
                  color: JotColors.textPrimary,
                ),
              ),
            ),
            Text('Modifié', style: JotText.ui(size: 11, color: JotColors.textSubtle)),
            const SizedBox(width: 2),
            JotIcon(JotIcons.dropdown, size: 12, color: JotColors.textSubtle),
            const SizedBox(width: 10),
            // Import sits beside "new note" because it is the same intent:
            // getting something into the vault right now.
            Hoverable(
              onTap: () => pickAndImportFiles(ref),
              builder: (context, hovered) => Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: hovered ? JotColors.neutralWash : null,
                  border: Border.all(color: JotColors.borderSubtle),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: JotIcon(
                  JotIcons.import_,
                  size: 13,
                  color: JotColors.textBody,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Hoverable(
              onTap: () => ref.read(vaultProvider.notifier).create(),
              builder: (context, hovered) => Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: hovered ? JotColors.accentHover : JotColors.accent,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: JotIcon(
                  JotIcons.plus,
                  size: 15,
                  color: JotColors.onAccent,
                ),
              ),
            ),
          ],
        ),
      );
}

class _NoteList extends ConsumerWidget {
  const _NoteList({required this.state});

  final VaultState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groups = _group(state.notes);
    final selectedId = state.openNote?.id;
    final settings = ref.watch(settingsProvider);

    return ListView.builder(
      padding: EdgeInsets.zero,
      itemCount: groups.length,
      itemBuilder: (context, groupIndex) {
        final group = groups[groupIndex];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(14, groupIndex == 0 ? 10 : 14, 14, 6),
              child: SectionLabel(group.label, small: true, rule: true),
            ),
            for (var i = 0; i < group.notes.length; i++) ...[
              NoteListRow(
                note: group.notes[i],
                selected: group.notes[i].id == selectedId,
                previewLines: settings.previewLines,
                compact: settings.density == ListDensity.compact,
                onTap: () => ref.read(vaultProvider.notifier).open_(group.notes[i]),
                onMenu: () => _openMenu(context, ref, group.notes[i]),
              ),
              // The design draws a hairline only where a selected row's
              // background needs closing off.
              if (i < group.notes.length - 1 &&
                  (group.notes[i].id == selectedId ||
                      group.notes[i + 1].id == selectedId))
                const Hairline(inset: EdgeInsets.symmetric(horizontal: 14)),
            ],
          ],
        );
      },
    );
  }

  Future<void> _openMenu(BuildContext context, WidgetRef ref, Note note) async {
    final box = context.findRenderObject() as RenderBox?;
    final position = box == null
        ? const Offset(200, 200)
        : box.localToGlobal(Offset.zero) + const Offset(160, 60);

    final action = await showNoteMenu(context, note: note, position: position);
    if (action == null || !context.mounted) return;

    final vault = ref.read(vaultProvider.notifier);
    switch (action) {
      case NoteAction.pin:
        await vault.togglePin(note);
      case NoteAction.tag:
        final tag = await promptForTag(context);
        if (tag != null) await vault.addTag(note, tag);
      case NoteAction.move:
        final folders = ref.read(vaultProvider).folders.map((f) => f.name).toList();
        if (!context.mounted) return;
        final target = await showDialog<String>(
          context: context,
          barrierColor: JotColors.scrim,
          builder: (_) => FolderPickerDialog(folders: folders, current: note.folder),
        );
        if (target != null) await vault.move(note, target);
      case NoteAction.copy:
        await copyToClipboard(note.content);
      case NoteAction.export:
        await pickAndExportNote(ref, note);
      case NoteAction.delete:
        final confirmed = await confirmDeleteNote(context, note);
        if (confirmed == true) await vault.delete(note);
    }
  }

  static List<_Group> _group(List<Note> notes) {
    final pinned = notes.where((n) => n.pinned).toList();
    final rest = notes.where((n) => !n.pinned).toList();

    final groups = <_Group>[
      if (pinned.isNotEmpty) _Group('Épinglées', pinned),
    ];

    // Buckets keep their first-seen order, which is already
    // most-recent-first because the query sorts by modified DESC.
    final buckets = <String, List<Note>>{};
    for (final note in rest) {
      buckets.putIfAbsent(JotFormat.group(note.modified), () => []).add(note);
    }
    for (final entry in buckets.entries) {
      groups.add(_Group(entry.key, entry.value));
    }
    return groups;
  }
}

class _Group {
  const _Group(this.label, this.notes);
  final String label;
  final List<Note> notes;
}

/// "« Klém » est vide" — the design's empty-folder state.
class _EmptyScope extends ConsumerWidget {
  const _EmptyScope({required this.scope});

  final Scope scope;

  @override
  Widget build(BuildContext context, WidgetRef ref) => EmptyState(
        title: '« ${scope.label} » est vide',
        message:
            'Colle un extrait, une URL ou un bout de JSON, le type est détecté tout seul.',
        primaryLabel: 'Nouvelle note',
        primaryHint: 'Ctrl N',
        onPrimary: () => ref.read(vaultProvider.notifier).create(),
      );
}
