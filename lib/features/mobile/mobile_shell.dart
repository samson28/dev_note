import 'package:flutter/material.dart'
    show
        InputBorder,
        InputDecoration,
        MaterialPageRoute,
        Scaffold,
        TextField,
        showDialog;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/note.dart';
import '../../widgets/jot_icons.dart';
import '../../core/models/note_type.dart';
import '../../core/theme/jot_theme.dart';
import '../../core/utils/jot_format.dart';
import '../../data/index_repository.dart' show SearchHit;
import '../../state/jot_services.dart';
import '../../state/search_notifier.dart';
import '../../state/vault_notifier.dart';
import '../../widgets/jot_primitives.dart';
import '../../widgets/json_viewer.dart' show copyToClipboard;
import '../../widgets/note_body.dart';
import '../../widgets/note_card.dart';
import '../../widgets/type_badge.dart';
import 'mobile_action_sheet.dart';
import 'mobile_capture_sheet.dart';
import 'mobile_drawer.dart';
import '../main_window/widgets/note_context_menu.dart';
import '../main_window/widgets/prompt_dialog.dart';

/// Mobile entry point: a list that pushes a detail screen onto the stack.
class MobileShell extends StatelessWidget {
  const MobileShell({super.key});

  @override
  Widget build(BuildContext context) => const MobileListScreen();
}

/// List screen, the large scope title, an inline search field, the type
/// filter row, then grouped cards with the "+" FAB anchored bottom-right.
class MobileListScreen extends ConsumerStatefulWidget {
  const MobileListScreen({super.key});

  @override
  ConsumerState<MobileListScreen> createState() => _MobileListScreenState();
}

class _MobileListScreenState extends ConsumerState<MobileListScreen> {
  final _query = TextEditingController();
  NoteType? _typeFilter;
  bool _drawerOpen = false;

  /// Set by "Chercher partout": the next queries ignore the current scope.
  /// Reset as soon as the field is cleared, so the scope means something
  /// again the next time the user types.
  bool _everywhere = false;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  bool get _searching => _query.text.trim().isNotEmpty;

  /// Runs the query through the same FTS5 index the desktop palette uses.
  ///
  /// The list used to match substrings against the titles and previews it
  /// already had in memory, which meant the phone found strictly less than
  /// the desktop: no ranking, no match inside a note body longer than the
  /// 220-character preview, and nothing at all in a folder that was not the
  /// current scope. The index answers in under a millisecond, so there is no
  /// reason for the phone to search differently.
  Future<void> _onQueryChanged(String raw) async {
    final search = ref.read(searchProvider.notifier);
    if (raw.trim().isEmpty) _everywhere = false;

    // The scope the user is looking at is part of the question: searching
    // inside "Enko" should not surface Inbox notes, unless they asked for it.
    if (_everywhere) {
      await search.setFolder(null);
      await search.clearTags();
    } else {
      switch (ref.read(vaultProvider).scope) {
        case FolderScope(folder: final folder):
          await search.setFolder(folder);
          await search.clearTags();
        case TagScope(tag: final tag):
          await search.setFolder(null);
          await search.setOnlyTag(tag);
        case TrashScope():
          await search.setFolder(null);
          await search.clearTags();
      }
    }

    await search.setQuery(raw.trim());
    if (mounted) setState(() {});
  }

  List<Note> _visible(List<Note> scoped, List<SearchHit> hits) {
    final source = _searching ? [for (final hit in hits) hit.note] : scoped;
    if (_typeFilter == null) return source;
    return source.where((n) => n.type == _typeFilter).toList();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(vaultProvider);
    final hits = ref.watch(searchProvider.select((s) => s.results));
    final notes = _visible(state.notes, hits);

    return Scaffold(
      backgroundColor: JotColors.window,
      body: Stack(
        children: [
          SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Header(
              scope: state.scope,
              // The scope's own count, not the vault total: the number sits
              // beside the scope title and has to agree with the list under it.
              total: _searching ? notes.length : state.notes.length,
              scopeTotal: state.notes.length,
              searching: _searching,
              controller: _query,
              onQueryChanged: _onQueryChanged,
              typeFilter: _typeFilter,
              onTypeChanged: (type) => setState(() => _typeFilter = type),
              onMenu: () => setState(() => _drawerOpen = true),
            ),
            Expanded(
              child: notes.isEmpty
                  ? _searching
                      // Offering "nouvelle note" here would be answering a
                      // question the user did not ask; widening the search is
                      // what they want next.
                      ? EmptyState(
                          title: 'Aucun résultat',
                          message: 'Rien ne correspond à « ${_query.text.trim()} » '
                              'dans « ${state.scope.label} ».',
                          primaryLabel: 'Chercher partout',
                          onPrimary: () async {
                            _everywhere = true;
                            await _onQueryChanged(_query.text);
                          },
                        )
                      : EmptyState(
                          title: '« ${state.scope.label} » est vide',
                          message:
                              'Colle un extrait, une URL ou un bout de JSON, le type est '
                              'détecté tout seul.',
                          primaryLabel: 'Nouvelle note',
                          onPrimary: () => _create(context),
                        )
                  : _NoteList(notes: notes),
            ),
            _BottomBar(
              folders: state.folders.map((f) => f.name).toList(),
              onFolderPicked: (folder) => ref
                  .read(vaultProvider.notifier)
                  .selectScope(FolderScope(folder)),
              onCreate: () => _create(context),
            ),
          ],
        ),
          ),
          MobileDrawer(
            open: _drawerOpen,
            onClose: () => setState(() => _drawerOpen = false),
          ),
        ],
      ),
    );
  }

  Future<void> _create(BuildContext context) =>
      showCaptureSheet(context, ref);
}

class _Header extends ConsumerWidget {
  const _Header({
    required this.scope,
    required this.total,
    required this.scopeTotal,
    required this.searching,
    required this.controller,
    required this.onQueryChanged,
    required this.typeFilter,
    required this.onTypeChanged,
    required this.onMenu,
  });

  final VoidCallback onMenu;

  final Scope scope;

  /// What the list below is showing: results while searching, notes otherwise.
  final int total;

  /// How many notes the scope holds, which is what the field offers to search.
  final int scopeTotal;
  final bool searching;
  final TextEditingController controller;
  final ValueChanged<String> onQueryChanged;
  final NoteType? typeFilter;
  final ValueChanged<NoteType?> onTypeChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    searching ? 'Résultats' : scope.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: JotText.ui(
                      size: 24,
                      weight: FontWeight.w600,
                      height: 1.1,
                      color: JotColors.textBright,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text('$total', style: JotText.mono(size: 12, color: JotColors.textSubtle)),
                const SizedBox(width: 10),
                Hoverable(
                  onTap: onMenu,
                  builder: (context, _) => Container(
                    width: 34,
                    height: 34,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: JotColors.neutralWashSoft,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: JotIcon(JotIcons.menu, size: 15, color: JotColors.textBody),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              height: 38,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: JotColors.editorSurface,
                border: Border.all(color: JotColors.borderWindow),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Row(
                children: [
                  JotIcon(JotIcons.search, size: 14, color: JotColors.textSubtle),
                  const SizedBox(width: 9),
                  Expanded(
                    child: TextField(
                      controller: controller,
                      onChanged: onQueryChanged,
                      cursorColor: JotColors.accent,
                      cursorWidth: 1.5,
                      style: JotText.ui(size: 13.5, color: JotColors.textPrimary),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        isCollapsed: true,
                        hintText: 'Rechercher dans $scopeTotal notes',
                        hintStyle: JotText.ui(size: 13.5, color: JotColors.textSubtle),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                TypeFilterChip(
                  label: 'Tout',
                  selected: typeFilter == null,
                  onTap: () => onTypeChanged(null),
                ),
                for (final type in NoteType.values) ...[
                  const SizedBox(width: 7),
                  TypeFilterChip(
                    type: type,
                    label: type.label,
                    selected: typeFilter == type,
                    onTap: () => onTypeChanged(typeFilter == type ? null : type),
                  ),
                ],
              ],
            ),
          ],
        ),
      );
}

class _NoteList extends ConsumerWidget {
  const _NoteList({required this.notes});

  final List<Note> notes;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pinned = notes.where((n) => n.pinned).toList();
    final rest = notes.where((n) => !n.pinned).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
      children: [
        if (pinned.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.fromLTRB(6, 0, 6, 9),
            child: SectionLabel('Épinglées', small: true),
          ),
          for (final note in pinned) ...[
            NoteCard(
              note: note,
              onTap: () => _open(context, ref, note),
              onLongPress: () => showNoteActionSheet(context, ref, note),
            ),
            const SizedBox(height: 9),
          ],
        ],
        if (rest.isNotEmpty) ...[
          Padding(
            padding: EdgeInsets.fromLTRB(6, pinned.isEmpty ? 0 : 6, 6, 9),
            child: SectionLabel(JotFormat.group(rest.first.modified), small: true),
          ),
          for (final note in rest) ...[
            NoteCard(
              note: note,
              onTap: () => _open(context, ref, note),
              onLongPress: () => showNoteActionSheet(context, ref, note),
            ),
            const SizedBox(height: 9),
          ],
        ],
      ],
    );
  }

  Future<void> _open(BuildContext context, WidgetRef ref, Note note) async {
    await ref.read(vaultProvider.notifier).open_(note);
    if (!context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => MobileDetailScreen(noteId: note.id)),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.folders,
    required this.onFolderPicked,
    required this.onCreate,
  });

  final List<String> folders;
  final ValueChanged<String> onFolderPicked;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 26),
        decoration: BoxDecoration(
          color: JotColors.chrome,
          border: Border(top: BorderSide(color: JotColors.borderSubtle)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Hoverable(
                onTap: () async {
                  final picked = await showDialog<String>(
                    context: context,
                    barrierColor: JotColors.scrim,
                    builder: (_) => FolderPickerDialog(folders: folders),
                  );
                  if (picked != null) onFolderPicked(picked);
                },
                builder: (context, _) => Text(
                  folders.join(', '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: JotText.mono(size: 11.5, color: JotColors.textSubtle),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Hoverable(
              onTap: onCreate,
              builder: (context, _) => Container(
                width: JotMetrics.mobileFabSize,
                height: JotMetrics.mobileFabSize,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: JotColors.accent,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text('+', style: JotText.ui(size: 22, color: JotColors.onAccent)),
              ),
            ),
          ],
        ),
      );
}

/// Detail screen, back affordance, metadata, tags, the body, and the four
/// bottom actions from the design.
class MobileDetailScreen extends ConsumerWidget {
  const MobileDetailScreen({super.key, required this.noteId});

  final String noteId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final note = ref.watch(vaultProvider.select((s) => s.openNote));
    final vault = ref.read(vaultProvider.notifier);

    if (note == null || note.id != noteId) {
      return Scaffold(
        backgroundColor: JotColors.editorSurface,
        body: SizedBox.shrink(),
      );
    }

    return Scaffold(
      backgroundColor: JotColors.editorSurface,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _DetailHeader(note: note),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      TypeBadge.roomy(note.type),
                      const SizedBox(width: 9),
                      Text(
                        '${JotFormat.relative(note.modified)}, '
                        '${JotFormat.bytes(note.sizeBytes)}',
                        style: JotText.ui(size: 11.5, color: JotColors.textSubtle),
                      ),
                    ],
                  ),
                  const SizedBox(height: 9),
                  Text(
                    note.title,
                    style: JotText.ui(
                      size: 19,
                      weight: FontWeight.w600,
                      height: 1.3,
                      color: JotColors.textBright,
                    ),
                  ),
                  if (note.tags.isNotEmpty) ...[
                    const SizedBox(height: 9),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [for (final tag in note.tags) TagChip('#$tag')],
                    ),
                  ],
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
                child: NoteBody(
                  note: note,
                  attachmentFile:
                      ref.read(servicesProvider).files.attachmentFile(note),
                  fontSize: 12,
                  showLineNumbers: false,
                  onChanged: (content) => vault.edit(note.copyWith(content: content)),
                ),
              ),
            ),
            _DetailActions(note: note),
          ],
        ),
      ),
    );
  }
}

class _DetailHeader extends ConsumerWidget {
  const _DetailHeader({required this.note});

  final Note note;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Container(
        height: JotMetrics.paneHeaderHeight,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: JotColors.borderEditor)),
        ),
        child: Row(
          children: [
            Hoverable(
              onTap: () => Navigator.of(context).maybePop(),
              builder: (context, _) => Row(
                children: [
                  JotIcon(JotIcons.back, size: 18, color: JotColors.accent),
                  const SizedBox(width: 11),
                  Text(
                    note.folder,
                    style: JotText.ui(size: 12.5, color: JotColors.accent),
                  ),
                ],
              ),
            ),
            const Spacer(),
            Hoverable(
              onTap: () => ref.read(vaultProvider.notifier).togglePin(note),
              builder: (context, _) => PinMark(active: note.pinned),
            ),
            const SizedBox(width: 8),
            Hoverable(
              onTap: () async {
                final deleted = await showNoteActionSheet(context, ref, note);
                if (deleted && context.mounted) {
                  await Navigator.of(context).maybePop();
                }
              },
              builder: (context, _) =>
                  OverflowDots(color: JotColors.textMuted, size: 18),
            ),
          ],
        ),
      );

}

class _DetailActions extends ConsumerWidget {
  const _DetailActions({required this.note});

  final Note note;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vault = ref.read(vaultProvider.notifier);

    return Container(
      height: JotMetrics.mobileBottomBarHeight,
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
      decoration: BoxDecoration(
        color: JotColors.footer,
        border: Border(top: BorderSide(color: JotColors.borderEditor)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _Action(
            icon: JotIcons.copy,
            label: 'Copier',
            accent: true,
            onTap: () => copyToClipboard(note.content),
          ),
          _Action(
            icon: JotIcons.tag,
            label: 'Taguer',
            onTap: () async {
              final tag = await promptForTag(context);
              if (tag != null) await vault.addTag(note, tag);
            },
          ),
          _Action(
            label: 'Déplacer',
            icon: JotIcons.move,
            onTap: () async {
              final folders = ref.read(vaultProvider).folders.map((f) => f.name).toList();
              if (!context.mounted) return;
              final target = await showDialog<String>(
                context: context,
                barrierColor: JotColors.scrim,
                builder: (_) =>
                    FolderPickerDialog(folders: folders, current: note.folder),
              );
              if (target != null) await vault.move(note, target);
            },
          ),
          _Action(
            icon: JotIcons.trash,
            label: 'Supprimer',
            danger: true,
            // Confirmed, like on the desktop: deleting is one tap and there is
            // no undo gesture on a phone to fall back on.
            onTap: () async {
              final confirmed = await confirmDeleteNote(context, note);
              if (confirmed != true) return;
              await vault.delete(note);
              if (context.mounted) Navigator.of(context).maybePop();
            },
          ),
        ],
      ),
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({
    required this.label,
    required this.onTap,
    required this.icon,
    this.accent = false,
    this.danger = false,
  });

  final String label;
  final VoidCallback onTap;
  final IconData icon;
  final bool accent;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger
        ? JotColors.danger
        : (accent ? JotColors.accent : JotColors.textMuted);

    return Hoverable(
      onTap: onTap,
      builder: (context, _) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 16,
            child: Center(child: JotIcon(icon, size: 16, color: color)),
          ),
          const SizedBox(height: 5),
          Text(
            label,
            style: JotText.ui(
              size: 10,
              color: danger ? JotColors.danger : JotColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}
