import 'package:flutter/material.dart' show showDialog;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/note.dart';
import '../../../core/theme/jot_theme.dart';
import '../../../state/search_notifier.dart';
import '../../../state/vault_notifier.dart';
import '../../../widgets/jot_primitives.dart';
import '../../settings/settings_window.dart';
import 'prompt_dialog.dart';

/// Left column, 236px: the search entry point, folders, tags, and the
/// quick-capture shortcut reminder pinned to the bottom.
class Sidebar extends ConsumerWidget {
  const Sidebar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(vaultProvider);

    return Container(
      width: JotMetrics.sidebarWidth,
      decoration: BoxDecoration(
        color: JotColors.chrome,
        border: Border(right: BorderSide(color: JotColors.borderSubtle)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(12, 14, 12, 10),
            child: _SearchEntry(),
          ),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
                    child: Row(
                      children: [
                        const Expanded(child: SectionLabel('Dossiers')),
                        Hoverable(
                          onTap: () => _newFolder(context, ref),
                          builder: (context, hovered) => Text(
                            '+',
                            style: JotText.ui(
                              size: 13,
                              color: hovered ? JotColors.accent : JotColors.textSubtle,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    // Stretch so every row spans the full 220px gutter and the
                    // counters line up in one column.
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final folder in state.folders)
                          _FolderRow(
                            folder: folder,
                            active: state.scope.isFolder(folder.name),
                            onTap: () => ref
                                .read(vaultProvider.notifier)
                                .selectScope(FolderScope(folder.name)),
                          ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: _TrashRow(active: state.scope is TrashScope),
                  ),
                  if (state.tags.isNotEmpty) ...[
                    const Padding(
                      padding: EdgeInsets.fromLTRB(12, 20, 12, 6),
                      child: SectionLabel('Tags'),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (final tag in state.tags)
                            _TagRow(
                              tag: tag,
                              active: state.scope.isTag(tag.name),
                              onTap: () => ref
                                  .read(vaultProvider.notifier)
                                  .selectScope(TagScope(tag.name)),
                            ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: JotColors.borderSubtle)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Capture rapide',
                        style: JotText.ui(size: 11, color: JotColors.textSubtle),
                      ),
                    ),
                    const Keycap('Ctrl Alt N', outlined: true),
                  ],
                ),
                const SizedBox(height: 8),
                Hoverable(
                  onTap: () => showSettings(context),
                  builder: (context, hovered) => Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Réglages',
                          style: JotText.ui(
                            size: 11,
                            color: hovered ? JotColors.textPrimary : JotColors.textSubtle,
                          ),
                        ),
                      ),
                      const Keycap('Ctrl ,', outlined: true),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _newFolder(BuildContext context, WidgetRef ref) async {
    final name = await showDialog<String>(
      context: context,
      barrierColor: JotColors.scrim,
      builder: (_) => const PromptDialog(
        title: 'Nouveau dossier',
        hint: 'Nom du dossier',
        confirmLabel: 'Créer',
      ),
    );
    if (name != null && name.trim().isNotEmpty) {
      await ref.read(vaultProvider.notifier).createFolder(name);
    }
  }
}

/// The `⌕ Rechercher ... Ctrl K` box. It is a button, not a field: typing happens in
/// the palette, which is one keystroke away and searches everything.
class _SearchEntry extends ConsumerWidget {
  const _SearchEntry();

  @override
  Widget build(BuildContext context, WidgetRef ref) => Hoverable(
        onTap: () => ref.read(searchProvider.notifier).openPalette(),
        builder: (context, hovered) => Container(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: JotColors.field,
            border: Border.all(
              color: hovered ? JotColors.borderRaised : JotColors.borderWindow,
            ),
            borderRadius: BorderRadius.circular(7),
          ),
          child: Row(
            children: [
              Text('⌕', style: JotText.ui(size: 12, color: JotColors.textSubtle)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Rechercher',
                  style: JotText.ui(size: 12, color: JotColors.textSubtle),
                ),
              ),
              const Keycap('Ctrl K'),
            ],
          ),
        ),
      );
}

class _FolderRow extends StatelessWidget {
  const _FolderRow({required this.folder, required this.active, required this.onTap});

  final Folder folder;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Hoverable(
        onTap: onTap,
        builder: (context, hovered) {
          final glyphColor = active
              ? JotColors.accent
              : (folder.muted ? JotColors.textGhost : JotColors.textSubtle);

          return Container(
            height: JotMetrics.sidebarRowHeight,
            decoration: BoxDecoration(
              color: active
                  ? JotColors.accentWashSidebar
                  : (hovered ? JotColors.neutralWash : null),
              borderRadius: BorderRadius.circular(6),
            ),
            // Two things this Stack has to get right:
            //  * the 2px accent edge sits inside the row's own bounds — Stack
            //    clips to its size, so a negative offset would draw nothing;
            //  * `alignment` must centre the content, because a Stack aligns
            //    non-positioned children to topStart by default and the row
            //    is 30px tall — leaving the label and counter floating above
            //    the accent edge, which is centred by its own insets.
            child: Stack(
              alignment: Alignment.centerLeft,
              children: [
                if (active)
                  Positioned(
                    left: 0,
                    top: 7,
                    bottom: 7,
                    width: 2,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: JotColors.accent,
                        borderRadius: BorderRadius.all(Radius.circular(2)),
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Row(
                    children: [
                      FolderGlyph(color: glyphColor),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          folder.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: active
                              ? JotText.sidebarRowActive
                              : JotText.sidebarRow.copyWith(
                                  color: folder.muted
                                      ? JotColors.textDim
                                      : JotColors.textBody,
                                ),
                        ),
                      ),
                      Text(
                        '${folder.noteCount}',
                        style: JotText.counter.copyWith(
                          color: active
                              ? JotColors.accent
                              : (folder.muted
                                  ? JotColors.textDisabled
                                  : JotColors.textSubtle),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      );
}

/// Sits under the folders: the trash is a destination, not a folder, so it
/// gets its own row rather than appearing in the folder list.
class _TrashRow extends ConsumerWidget {
  const _TrashRow({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Hoverable(
        onTap: () =>
            ref.read(vaultProvider.notifier).selectScope(const TrashScope()),
        builder: (context, hovered) => Container(
          height: JotMetrics.sidebarRowHeight,
          decoration: BoxDecoration(
            color: active
                ? JotColors.accentWashSidebar
                : (hovered ? JotColors.neutralWash : null),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Stack(
            alignment: Alignment.centerLeft,
            children: [
              if (active)
                Positioned(
                  left: 0,
                  top: 7,
                  bottom: 7,
                  width: 2,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: JotColors.accent,
                      borderRadius: const BorderRadius.all(Radius.circular(2)),
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Row(
                  children: [
                    FolderGlyph(
                      color: active ? JotColors.accent : JotColors.textGhost,
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        'Corbeille',
                        style: active
                            ? JotText.sidebarRowActive
                            : JotText.sidebarRow.copyWith(color: JotColors.textDim),
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

class _TagRow extends StatelessWidget {
  const _TagRow({required this.tag, required this.active, required this.onTap});

  final Tag tag;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Hoverable(
        onTap: onTap,
        builder: (context, hovered) => Container(
          height: JotMetrics.tagRowHeight,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: active
                ? JotColors.accentWashSidebar
                : (hovered ? JotColors.neutralWash : null),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            children: [
              Text(
                '#',
                style: JotText.mono(
                  size: 12,
                  weight: FontWeight.w500,
                  color: active ? JotColors.accent : JotColors.textSubtle,
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  tag.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: active ? JotText.sidebarRowActive : JotText.sidebarRow,
                ),
              ),
              Text(
                '${tag.noteCount}',
                style: JotText.counter.copyWith(
                  color: active ? JotColors.accent : JotColors.textSubtle,
                ),
              ),
            ],
          ),
        ),
      );
}
