import 'package:flutter/material.dart' show Material, MaterialType, showDialog;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../widgets/jot_icons.dart';
import '../../../core/models/note.dart';
import '../../../core/models/note_type.dart';
import '../../../core/theme/jot_theme.dart';
import '../../../core/utils/jot_format.dart';
import '../../../state/settings_notifier.dart';
import '../../../state/jot_services.dart';
import '../../import/file_import.dart';
import '../../../state/vault_notifier.dart';
import '../../../widgets/jot_primitives.dart';
import '../../../widgets/json_viewer.dart' show JsonViewer, copyToClipboard;
import '../../../widgets/note_body.dart';
import '../../../widgets/type_badge.dart';
import 'home_panel.dart';
import 'note_context_menu.dart';
import 'prompt_dialog.dart';

/// Right column: header with the title and per-note actions, a breadcrumb row
/// carrying the folder and tags, the body panel, and the status bar.
class EditorPane extends ConsumerWidget {
  const EditorPane({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final note = ref.watch(vaultProvider.select((s) => s.openNote));

    return Expanded(
      child: ColoredBox(
        color: JotColors.editorSurface,
        child: note == null ? const HomePanel() : _Editor(note: note),
      ),
    );
  }
}

class _Editor extends ConsumerStatefulWidget {
  const _Editor({required this.note});

  final Note note;

  @override
  ConsumerState<_Editor> createState() => _EditorState();
}

class _EditorState extends ConsumerState<_Editor> {
  @override
  Widget build(BuildContext context) {
    final note = widget.note;
    final vault = ref.read(vaultProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Header(note: note),
        _Breadcrumb(note: note),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
            child: NoteBody(
              note: note,
              attachmentFile:
                  ref.read(servicesProvider).files.attachmentFile(note),
              showLineNumbers: ref.watch(
                settingsProvider.select((s) => s.showLineNumbers),
              ),
              // Retyping the body can change what the note *is* — a pasted
              // JSON blob should pick up its badge without being asked.
              onChanged: (content) => vault.edit(
                note.copyWith(
                  content: content,
                  type: note.type == NoteTypeDetector.detect(note.content)
                      ? NoteTypeDetector.detect(content)
                      : note.type,
                ),
              ),
            ),
          ),
        ),
        _StatusBar(note: note),
      ],
    );
  }
}

class _Header extends ConsumerWidget {
  const _Header({required this.note});

  final Note note;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vault = ref.read(vaultProvider.notifier);

    return Container(
      height: JotMetrics.paneHeaderHeight,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: JotColors.borderEditor)),
      ),
      child: Row(
        children: [
          if (note.pinned) ...[
            const PinMark(),
            const SizedBox(width: 9),
          ],
          Flexible(
            child: Hoverable(
              onTap: () => _rename(context, ref),
              builder: (context, hovered) => Text(
                note.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: JotText.ui(
                  size: 13.5,
                  weight: FontWeight.w600,
                  color: JotColors.textBright,
                  decoration: hovered ? TextDecoration.underline : null,
                ),
              ),
            ),
          ),
          const SizedBox(width: 9),
          _TypePicker(note: note),
          const Spacer(),
          _IconButton(
            active: note.pinned,
            onTap: () => vault.togglePin(note),
            child: PinMark(active: note.pinned),
          ),
          _IconButton(
            onTap: () async {
              final tag = await promptForTag(context);
              if (tag != null) await vault.addTag(note, tag);
            },
            child: JotIcon(JotIcons.tag, size: 13, color: JotColors.textMuted),
          ),
          _IconButton(
            onTap: () => _move(context, ref),
            child: JotIcon(JotIcons.move, size: 13, color: JotColors.textMuted),
          ),
          _IconButton(
            onTap: () => copyToClipboard(note.content),
            child: JotIcon(JotIcons.copy, size: 13, color: JotColors.textMuted),
          ),
          // Anything the app can hold, it can hand back — including a note
          // that was typed here rather than imported.
          _IconButton(
            onTap: () => pickAndExportNote(ref, note),
            child: JotIcon(
              JotIcons.download,
              size: 13,
              color: JotColors.textMuted,
            ),
          ),
          Container(
            width: 1,
            height: 18,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            color: JotColors.borderTag,
          ),
          _IconButton(
            danger: true,
            onTap: () => _confirmDelete(context, ref),
            child: JotIcon(JotIcons.close, size: 13, color: JotColors.textMuted),
          ),
        ],
      ),
    );
  }

  Future<void> _rename(BuildContext context, WidgetRef ref) async {
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
      await ref.read(vaultProvider.notifier).save(note.copyWith(title: title.trim()));
    }
  }

  Future<void> _move(BuildContext context, WidgetRef ref) async {
    final folders = ref.read(vaultProvider).folders.map((f) => f.name).toList();
    if (!context.mounted) return;
    final target = await showDialog<String>(
      context: context,
      barrierColor: JotColors.scrim,
      builder: (_) => FolderPickerDialog(folders: folders, current: note.folder),
    );
    if (target != null) {
      await ref.read(vaultProvider.notifier).move(note, target);
    }
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await confirmDeleteNote(context, note);
    if (confirmed == true) {
      await ref.read(vaultProvider.notifier).delete(note);
    }
  }
}

/// The badge in the header doubles as the manual type override the spec asks
/// for: click it, pick another type.
class _TypePicker extends ConsumerWidget {
  const _TypePicker({required this.note});

  final Note note;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Hoverable(
        onTap: () async {
          final picked = await showDialog<NoteType>(
            context: context,
            barrierColor: const Color(0x00000000),
            builder: (dialogContext) => Center(
              child: Material(
                type: MaterialType.transparency,
                child: Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: JotColors.raised,
                    border: Border.all(color: JotColors.borderRaised),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: JotColors.active.shadow(JotMetrics.menuShadow),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final type in NoteType.values)
                        Hoverable(
                          onTap: () => Navigator.of(dialogContext).pop(type),
                          builder: (context, hovered) => Container(
                            width: 150,
                            height: 28,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            decoration: BoxDecoration(
                              color: hovered ? JotColors.neutralWashMenu : null,
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Row(
                              children: [
                                TypeBadge(type),
                                const SizedBox(width: 10),
                                if (type == note.type)
                                  Text(
                                    'actuel',
                                    style: JotText.ui(
                                      size: 11,
                                      color: JotColors.textSubtle,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          );
          if (picked != null && picked != note.type) {
            await ref.read(vaultProvider.notifier).setType(note, picked);
          }
        },
        builder: (context, _) => TypeBadge(note.type),
      );
}

class _IconButton extends StatelessWidget {
  const _IconButton({
    required this.child,
    required this.onTap,
    this.active = false,
    this.danger = false,
  });

  final Widget child;
  final VoidCallback onTap;
  final bool active;
  final bool danger;

  @override
  Widget build(BuildContext context) => Hoverable(
        onTap: onTap,
        builder: (context, hovered) => Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active
                ? JotColors.accentWashIcon
                : (hovered
                    ? (danger ? JotColors.dangerBorder : JotColors.neutralWashChip)
                    : null),
            borderRadius: BorderRadius.circular(6),
          ),
          child: child,
        ),
      );
}

/// `Inbox / #api #stripe + ... Modifié il y a 4 min · créé le 28 juil. 09:12`
class _Breadcrumb extends ConsumerWidget {
  const _Breadcrumb({required this.note});

  final Note note;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vault = ref.read(vaultProvider.notifier);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: Row(
        children: [
          Text(note.folder, style: JotText.ui(size: 11.5, color: JotColors.textSubtle)),
          const SizedBox(width: 14),
          Text('/', style: JotText.ui(size: 11.5, color: JotColors.textGhost)),
          const SizedBox(width: 14),
          Flexible(
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final tag in note.tags)
                  TagChip('#$tag', onRemove: () => vault.removeTag(note, tag)),
                TagChip(
                  '+',
                  dashed: true,
                  onTap: () async {
                    final tag = await promptForTag(context);
                    if (tag != null) await vault.addTag(note, tag);
                  },
                ),
              ],
            ),
          ),
          const Spacer(),
          Text(
            'Modifié ${JotFormat.relative(note.modified)}, '
            'créé le ${JotFormat.absolute(note.created)}',
            style: JotText.ui(size: 11.5, color: JotColors.textSubtle),
          ),
        ],
      ),
    );
  }
}

class _StatusBar extends StatelessWidget {
  const _StatusBar({required this.note});

  final Note note;

  @override
  Widget build(BuildContext context) {
    final validity = switch (note.type) {
      NoteType.json => JsonViewer.canParse(note.content)
          ? _Validity('JSON valide', JotSyntax.key)
          : _Validity('JSON invalide', JotColors.danger),
      NoteType.url => _Validity('URL', JotSyntax.key),
      _ => null,
    };

    return SizedBox(
      height: JotMetrics.statusBarHeight,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          children: [
            Text(JotFormat.bytes(note.sizeBytes), style: JotText.statusBar),
            const SizedBox(width: 14),
            Text('${note.lineCount} lignes', style: JotText.statusBar),
            if (validity != null) ...[
              const SizedBox(width: 14),
              Text(
                validity.label,
                style: JotText.statusBar.copyWith(color: validity.color),
              ),
            ],
            const Spacer(),
            Text('Enregistré automatiquement', style: JotText.statusBar),
            const SizedBox(width: 14),
            Hoverable(
              onTap: () => copyToClipboard(note.content),
              builder: (context, hovered) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                decoration: BoxDecoration(
                  color: hovered ? JotColors.neutralWashBadge : JotColors.neutralWashChip,
                  border: Border.all(color: JotColors.borderTag),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Copier',
                  style: JotText.statusBar.copyWith(color: JotColors.textMuted),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Validity {
  const _Validity(this.label, this.color);
  final String label;
  final Color color;
}
