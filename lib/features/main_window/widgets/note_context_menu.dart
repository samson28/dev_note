import 'package:flutter/material.dart' show Material, MaterialType, showDialog;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../../widgets/type_badge.dart';

import '../../../core/models/note.dart';
import '../../../core/theme/jot_theme.dart';
import '../../../widgets/jot_icons.dart';
import '../../../widgets/jot_primitives.dart';
import 'prompt_dialog.dart';

/// Actions available on a note row, matching the design's `···` menu.
enum NoteAction { pin, tag, move, copy, export, delete }

/// The floating menu itself: `#22242A` on `#34363D`, 196px wide, 8px radius,
/// 28px rows with a keycap hint on the right.
class NoteContextMenu extends StatelessWidget {
  const NoteContextMenu({super.key, required this.note, required this.onAction});

  final Note note;
  final ValueChanged<NoteAction> onAction;

  @override
  Widget build(BuildContext context) => Container(
        width: 196,
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: JotColors.raised,
          border: Border.all(color: JotColors.borderRaised),
          borderRadius: BorderRadius.circular(8),
          boxShadow: JotColors.active.shadow(JotMetrics.menuShadow),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _MenuItem(
              leading: PinMark(active: !note.pinned),
              label: note.pinned ? 'Détacher' : 'Épingler',
              shortcut: 'Ctrl P',
              onTap: () => onAction(NoteAction.pin),
            ),
            _MenuItem(
              leading: JotIcon(JotIcons.tag, size: 11, color: JotColors.textDim),
              label: 'Ajouter un tag...',
              shortcut: 'Ctrl T',
              onTap: () => onAction(NoteAction.tag),
            ),
            _MenuItem(
              leading: JotIcon(JotIcons.move, size: 11, color: JotColors.textDim),
              label: 'Déplacer vers...',
              shortcut: 'Ctrl M',
              onTap: () => onAction(NoteAction.move),
            ),
            _MenuItem(
              leading: JotIcon(JotIcons.copy, size: 11, color: JotColors.textDim),
              label: 'Copier le contenu',
              shortcut: 'Ctrl C',
              onTap: () => onAction(NoteAction.copy),
            ),
            _MenuItem(
              leading:
                  JotIcon(JotIcons.download, size: 11, color: JotColors.textDim),
              label: 'Enregistrer sous...',
              shortcut: 'Ctrl S',
              onTap: () => onAction(NoteAction.export),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 2, vertical: 4),
              child: Hairline(color: JotColors.borderRaised),
            ),
            _MenuItem(
              leading:
                  JotIcon(JotIcons.trash, size: 11, color: JotColors.danger),
              label: 'Supprimer',
              shortcut: 'Suppr',
              danger: true,
              onTap: () => onAction(NoteAction.delete),
            ),
          ],
        ),
      );
}

class _MenuItem extends StatelessWidget {
  const _MenuItem({
    required this.label,
    required this.shortcut,
    required this.onTap,
    this.leading,
    this.danger = false,
  });

  final Widget? leading;
  final String label;
  final String shortcut;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) => Hoverable(
        onTap: onTap,
        builder: (context, hovered) => Container(
          height: 28,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: hovered ? JotColors.neutralWashMenu : null,
            borderRadius: BorderRadius.circular(5),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 9,
                child: Center(
                  child: leading ?? const SizedBox.shrink(),
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  label,
                  style: JotText.ui(
                    size: 12,
                    color: danger
                        ? JotColors.danger
                        : (hovered ? JotColors.textBright : JotColors.textStrong),
                  ),
                ),
              ),
              Text(shortcut, style: JotText.keycap.copyWith(color: JotColors.textSubtle)),
            ],
          ),
        ),
      );
}

/// Opens [NoteContextMenu] anchored at [position] and resolves the action.
Future<NoteAction?> showNoteMenu(
  BuildContext context, {
  required Note note,
  required Offset position,
}) {
  final overlay = Overlay.of(context).context.findRenderObject()! as RenderBox;
  final size = overlay.size;

  // Flip the menu when it would run off the bottom or right edge.
  const menuWidth = 196.0;
  const menuHeight = 178.0;
  final left = (position.dx + menuWidth > size.width)
      ? position.dx - menuWidth
      : position.dx;
  final top = (position.dy + menuHeight > size.height)
      ? position.dy - menuHeight
      : position.dy;

  return showDialog<NoteAction>(
    context: context,
    barrierColor: const Color(0x00000000),
    builder: (dialogContext) => Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          Positioned(
            left: left.clamp(8.0, size.width - menuWidth - 8),
            top: top.clamp(8.0, size.height - menuHeight - 8),
            child: NoteContextMenu(
              note: note,
              onAction: (action) => Navigator.of(dialogContext).pop(action),
            ),
          ),
        ],
      ),
    ),
  );
}

/// 3d, "Supprimer « ... » ?"
///
/// Deletion is a single click everywhere else in the app, which is what keeps
/// it fast; this dialog is what makes that safe. It states plainly where the
/// note goes ("à la corbeille") and shows the content being removed, so the
/// user is confirming a *thing*, not a filename.
Future<bool?> confirmDeleteNote(BuildContext context, Note note) => showDialog<bool>(
      context: context,
      barrierColor: JotColors.scrim,
      builder: (dialogContext) => Center(
        child: Material(
          type: MaterialType.transparency,
          child: _ConfirmDelete(
            note: note,
            onCancel: () => Navigator.of(dialogContext).pop(false),
            onConfirm: () => Navigator.of(dialogContext).pop(true),
          ),
        ),
      ),
    );

class _ConfirmDelete extends StatelessWidget {
  const _ConfirmDelete({
    required this.note,
    required this.onCancel,
    required this.onConfirm,
  });

  final Note note;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) => Focus(
        autofocus: true,
        onKeyEvent: (node, event) {
          if (event is! KeyDownEvent) return KeyEventResult.ignored;
          if (event.logicalKey == LogicalKeyboardKey.escape) {
            onCancel();
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.backspace) {
            onConfirm();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: Container(
          width: 420,
          decoration: BoxDecoration(
            color: JotColors.palette,
            border: Border.all(color: JotColors.borderCapture),
            borderRadius: BorderRadius.circular(12),
            boxShadow: JotColors.active.shadow(JotMetrics.captureShadow),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Supprimer « ${note.title} » ?',
                      style: JotText.ui(
                        size: 14,
                        weight: FontWeight.w600,
                        height: 1.3,
                        color: JotColors.textBright,
                      ),
                    ),
                    const SizedBox(height: 9),
                    Text(
                      'La note part à la corbeille et sera purgée définitivement '
                      'dans 30 jours.',
                      style: JotText.ui(size: 12, height: 1.6, color: JotColors.textDim),
                    ),
                    const SizedBox(height: 13),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
                      decoration: BoxDecoration(
                        color: JotColors.codePanel,
                        border: Border.all(color: JotColors.borderEditor),
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: Row(
                        children: [
                          TypeBadge(note.type),
                          const SizedBox(width: 9),
                          Expanded(
                            child: Text(
                              note.preview,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: JotText.mono(size: 11.5, color: JotColors.textDim),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                height: 52,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: JotColors.footer,
                  border: Border(top: BorderSide(color: JotColors.borderPalette)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Retour pour confirmer, Echap pour annuler',
                        style: JotText.mono(size: 10.5, color: JotColors.textDisabled),
                      ),
                    ),
                    JotButton(
                      'Annuler',
                      kind: JotButtonKind.secondary,
                      onTap: onCancel,
                    ),
                    const SizedBox(width: 8),
                    Hoverable(
                      onTap: onConfirm,
                      builder: (context, hovered) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: hovered
                              ? JotColors.danger
                              : const Color(0xFFC4443C),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Supprimer',
                          style: JotText.ui(
                            size: 11.5,
                            weight: FontWeight.w600,
                            color: const Color(0xFFF3F4F6),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}

/// Prompts for a tag name using the shared dialog.
Future<String?> promptForTag(BuildContext context) => showDialog<String>(
      context: context,
      barrierColor: JotColors.scrim,
      builder: (_) => const PromptDialog(
        title: 'Ajouter un tag',
        hint: 'api, snippet, creds...',
        confirmLabel: 'Ajouter',
        monospace: true,
      ),
    );
