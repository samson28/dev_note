import 'package:flutter/material.dart' show showDialog, showModalBottomSheet;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/note.dart';
import '../../core/models/note_type.dart';
import '../../core/theme/jot_theme.dart';
import '../../state/vault_notifier.dart';
import '../../widgets/jot_icons.dart';
import '../../widgets/jot_primitives.dart';
import '../../widgets/json_viewer.dart' show copyToClipboard;
import '../main_window/widgets/note_context_menu.dart';
import '../settings/widgets/settings_controls.dart';
import '../main_window/widgets/prompt_dialog.dart';

/// 4e — the note action sheet.
///
/// The desktop reaches these actions through a right-click menu. A phone has
/// no right click, so the same set rises from the bottom of the screen where a
/// thumb can reach it, at 52px a row.
///
/// Returns true when the note was deleted, so the caller can leave a detail
/// screen that no longer has anything to show.
Future<bool> showNoteActionSheet(
  BuildContext context,
  WidgetRef ref,
  Note note,
) async {
  final deleted = await showModalBottomSheet<bool>(
    context: context,
    backgroundColor: const Color(0x00000000),
    barrierColor: JotColors.scrim,
    // Without this the sheet is capped at 9/16 of the screen and the delete
    // group falls off the bottom.
    isScrollControlled: true,
    builder: (sheetContext) => _ActionSheet(note: note, ref: ref),
  );
  return deleted ?? false;
}

class _ActionSheet extends StatelessWidget {
  const _ActionSheet({required this.note, required this.ref});

  final Note note;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final vault = ref.read(vaultProvider.notifier);

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Group(
              children: [
                _Head(note: note),
                _Row(
                  icon: JotIcons.pin,
                  label: note.pinned ? 'Désépingler' : 'Épingler',
                  onTap: () async {
                    Navigator.of(context).pop();
                    await vault.togglePin(note);
                  },
                ),
                _Row(
                  icon: JotIcons.copy,
                  label: 'Copier le contenu',
                  onTap: () {
                    Navigator.of(context).pop();
                    copyToClipboard(note.content);
                  },
                ),
                _Row(
                  icon: JotIcons.tag,
                  label: 'Ajouter un tag',
                  onTap: () async {
                    Navigator.of(context).pop();
                    final tag = await promptForTag(context);
                    if (tag != null) await vault.addTag(note, tag);
                  },
                ),
                _Row(
                  icon: JotIcons.folder,
                  label: 'Déplacer vers...',
                  value: note.folder,
                  onTap: () async {
                    Navigator.of(context).pop();
                    final folders =
                        ref.read(vaultProvider).folders.map((f) => f.name).toList();
                    if (!context.mounted) return;
                    final target = await showDialog<String>(
                      context: context,
                      barrierColor: JotColors.scrim,
                      builder: (_) => FolderPickerDialog(
                        folders: folders,
                        current: note.folder,
                      ),
                    );
                    if (target != null) await vault.move(note, target);
                  },
                ),
                _Row(
                  icon: JotIcons.edit,
                  label: 'Renommer',
                  onTap: () async {
                    Navigator.of(context).pop();
                    final title = await showDialog<String>(
                      context: context,
                      barrierColor: JotColors.scrim,
                      builder: (_) => PromptDialog(
                        title: 'Renommer la note',
                        hint: 'Titre',
                        initialValue: note.title,
                        confirmLabel: 'Renommer',
                      ),
                    );
                    if (title != null && title.trim().isNotEmpty) {
                      await vault.save(note.copyWith(title: title.trim()));
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Type override, so a misdetected note can be corrected without
            // touching its content.
            _Group(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
                  child: Row(
                    children: [
                      const Expanded(child: SectionLabel('Type')),
                      JotSegmented<NoteType>(
                        large: true,
                        mono: true,
                        options: NoteType.values,
                        value: note.type,
                        labelOf: (t) => t.label,
                        onChanged: (t) async {
                          Navigator.of(context).pop();
                          await vault.setType(note, t);
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _Group(
              children: [
                _Row(
                  icon: JotIcons.trash,
                  label: 'Supprimer',
                  danger: true,
                  onTap: () async {
                    final confirmed = await confirmDeleteNote(context, note);
                    if (confirmed != true) return;
                    await vault.delete(note);
                    if (context.mounted) Navigator.of(context).pop(true);
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            _Group(
              children: [
                _Row(
                  label: 'Annuler',
                  centred: true,
                  onTap: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: JotColors.raised,
          border: Border.all(color: JotColors.borderRaised),
          borderRadius: BorderRadius.circular(14),
          boxShadow: JotColors.active.shadow(JotMetrics.menuShadow),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: children,
        ),
      );
}

/// Names the note the sheet is about, so an action sheet raised by a long
/// press on a card cannot be applied to the wrong note by mistake.
class _Head extends StatelessWidget {
  const _Head({required this.note});

  final Note note;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(16, 13, 16, 12),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: JotColors.borderRaised)),
        ),
        child: Text(
          note.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: JotText.ui(
            size: 13,
            weight: FontWeight.w600,
            color: JotColors.textBright,
          ),
        ),
      );
}

class _Row extends StatelessWidget {
  const _Row({
    required this.label,
    required this.onTap,
    this.icon,
    this.value,
    this.danger = false,
    this.centred = false,
  });

  final String label;
  final VoidCallback onTap;
  final IconData? icon;
  final String? value;
  final bool danger;
  final bool centred;

  @override
  Widget build(BuildContext context) {
    final color = danger ? JotColors.danger : JotColors.textBody;

    return Hoverable(
      onTap: onTap,
      builder: (context, hovered) => Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        color: hovered ? JotColors.neutralWash : null,
        child: Row(
          mainAxisAlignment:
              centred ? MainAxisAlignment.center : MainAxisAlignment.start,
          children: [
            if (icon != null) ...[
              JotIcon(icon!, size: 17, color: color),
              const SizedBox(width: 14),
            ],
            centred
                ? Text(
                    label,
                    style: JotText.ui(size: 14.5, color: color),
                  )
                : Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: JotText.ui(size: 14.5, color: color),
                    ),
                  ),
            if (value != null)
              Text(
                value!,
                style: JotText.mono(size: 12, color: JotColors.textSubtle),
              ),
          ],
        ),
      ),
    );
  }
}
