import 'dart:ui' as ui;

import 'package:flutter/material.dart' show TextField, InputDecoration, InputBorder, showDialog;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../widgets/jot_icons.dart';
import '../../core/models/note_type.dart';
import '../../core/theme/jot_theme.dart';
import '../../core/utils/jot_format.dart';
import '../../data/index_repository.dart';
import '../../state/search_notifier.dart';
import '../../state/vault_notifier.dart';
import '../../widgets/jot_primitives.dart';
import '../../widgets/note_card.dart';
import '../../widgets/type_badge.dart';
import '../main_window/widgets/prompt_dialog.dart';

/// The Ctrl K overlay: a blurred scrim over the window and a 760px card pinned
/// 96px from the top.
///
/// Results refresh on every keystroke with no debounce — see [SearchNotifier].
class SearchPalette extends ConsumerStatefulWidget {
  const SearchPalette({super.key});

  @override
  ConsumerState<SearchPalette> createState() => _SearchPaletteState();
}

class _SearchPaletteState extends ConsumerState<SearchPalette> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();

  /// The handler lives on the field's *own* node, not on an ancestor: from
  /// here it sees ↑/↓/⏎ before `DefaultTextEditingShortcuts` turns them into
  /// caret moves, while anything it ignores still falls through to normal
  /// typing.
  late final _focus = FocusNode(onKeyEvent: _onKey);

  @override
  void initState() {
    super.initState();
    final query = ref.read(searchProvider).query;
    _controller
      ..text = query
      ..selection = TextSelection.collapsed(offset: query.length);

    // `autofocus` is not enough here: the main window's shortcut handler
    // already owns the focus scope, and autofocus only fires into an empty
    // one. The palette has to take focus outright, or the user's first
    // keystrokes vanish.
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  SearchNotifier get _search => ref.read(searchProvider.notifier);

  Future<void> _openSelected({bool alsoClose = true}) async {
    final state = ref.read(searchProvider);
    if (state.results.isEmpty) return;
    final note = state.results[state.selectedIndex].note;
    await ref.read(vaultProvider.notifier).reveal(note);
    if (alsoClose) _search.close();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }

    switch (event.logicalKey) {
      case LogicalKeyboardKey.escape:
        _search.close();
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowDown:
        _search.moveSelection(1);
        _revealSelection();
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowUp:
        _search.moveSelection(-1);
        _revealSelection();
        return KeyEventResult.handled;
      case LogicalKeyboardKey.enter:
      case LogicalKeyboardKey.numpadEnter:
        final pressed = HardwareKeyboard.instance.logicalKeysPressed;
        final withModifier = pressed.contains(LogicalKeyboardKey.controlLeft) ||
            pressed.contains(LogicalKeyboardKey.controlRight) ||
            pressed.contains(LogicalKeyboardKey.metaLeft) ||
            pressed.contains(LogicalKeyboardKey.metaRight);
        if (withModifier) {
          _createFromQuery();
        } else {
          _openSelected();
        }
        return KeyEventResult.handled;
      default:
        return KeyEventResult.ignored;
    }
  }

  void _revealSelection() {
    if (!_scroll.hasClients) return;
    final index = ref.read(searchProvider).selectedIndex;
    // Rows are ~56px; keeping the selection roughly centred is enough here.
    const rowHeight = 56.0;
    final target = (index * rowHeight - 120).clamp(
      0.0,
      _scroll.position.maxScrollExtent,
    );
    _scroll.animateTo(
      target,
      duration: const Duration(milliseconds: 90),
      curve: Curves.easeOut,
    );
  }

  Future<void> _createFromQuery() async {
    final query = ref.read(searchProvider).query.trim();
    if (query.isEmpty) return;
    _search.close();
    await ref.read(vaultProvider.notifier).create(title: query);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(searchProvider);

    return Stack(
      children: [
        // Scrim: `rgba(8,9,11,.7)` over a 3px blur.
        Positioned.fill(
          child: GestureDetector(
            onTap: _search.close,
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 3, sigmaY: 3),
              child: ColoredBox(color: JotColors.scrim),
            ),
          ),
        ),
        Positioned(
          top: JotMetrics.paletteTop,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
                width: JotMetrics.paletteWidth,
                constraints: const BoxConstraints(maxHeight: 620),
                decoration: BoxDecoration(
                  color: JotColors.palette,
                  border: Border.all(color: JotColors.borderPaletteOuter),
                  borderRadius: BorderRadius.circular(JotMetrics.paletteRadius),
                  boxShadow: JotColors.active.shadow(JotMetrics.paletteShadow),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _QueryField(
                      controller: _controller,
                      focusNode: _focus,
                      onChanged: _search.setQuery,
                    ),
                    _FilterRow(state: state),
                    Flexible(
                      child: state.isEmpty
                          ? _PaletteEmpty(state: state, onCreate: _createFromQuery)
                          : _Results(
                              state: state,
                              scroll: _scroll,
                              onOpen: (index) {
                                ref.read(searchProvider.notifier).moveSelection(
                                      index - state.selectedIndex,
                                    );
                                _openSelected();
                              },
                              onCreate: _createFromQuery,
                            ),
                    ),
                    _Footer(state: state),
                  ],
                ),
            ),
          ),
        ),
      ],
    );
  }
}

class _QueryField extends StatelessWidget {
  const _QueryField({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => Container(
        height: JotMetrics.paletteInputHeight,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: JotColors.borderPalette)),
        ),
        child: Row(
          children: [
            JotIcon(JotIcons.search, size: 17, color: JotColors.accent),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                onChanged: onChanged,
                autofocus: true,
                cursorColor: JotColors.accent,
                cursorWidth: 1.5,
                style: JotText.ui(size: 18, height: 1.2, color: JotColors.textBright),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  isCollapsed: true,
                  hintText: 'Rechercher dans toutes les notes...',
                  hintStyle: JotText.ui(size: 18, height: 1.2, color: JotColors.textSubtle),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              decoration: BoxDecoration(
                color: JotColors.keycapPalette,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'Esc',
                style: JotText.mono(
                  size: 10.5,
                  weight: FontWeight.w500,
                  color: JotColors.textDim,
                ),
              ),
            ),
          ],
        ),
      );
}

/// `Tout 6 · JSON 3 · CODE 2 · URL 1 · TXT 0 | dossier: Inbox ▾ · #api ✕`
class _FilterRow extends ConsumerWidget {
  const _FilterRow({required this.state});

  final SearchState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final search = ref.read(searchProvider.notifier);
    final selectedTypes = state.filters.types;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: JotColors.borderPalette)),
      ),
      child: Wrap(
        spacing: 7,
        runSpacing: 7,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          TypeFilterChip(
            label: 'Tout',
            count: state.totalMatches,
            selected: selectedTypes.isEmpty,
            onTap: search.clearTypes,
          ),
          for (final type in NoteType.values)
            TypeFilterChip(
              type: type,
              label: type.label,
              count: state.typeCounts[type] ?? 0,
              selected: selectedTypes.contains(type),
              onTap: () => search.toggleType(type),
            ),
          Container(width: 1, height: 16, color: JotColors.borderPalette),
          FilterPill(
            label: 'dossier:',
            trailing: '${state.filters.folder ?? 'tous'} ▾',
            onTap: () => _pickFolder(context, ref),
          ),
          for (final tag in state.filters.tags)
            FilterPill(
              label: '#$tag',
              trailing: '✕',
              onTap: () => search.toggleTag(tag),
            ),
          FilterPill(label: '# tag', onTap: () => _pickTag(context, ref)),
        ],
      ),
    );
  }

  Future<void> _pickFolder(BuildContext context, WidgetRef ref) async {
    final folders = ['tous', ...ref.read(vaultProvider).folders.map((f) => f.name)];
    final picked = await showDialog<String>(
      context: context,
      barrierColor: const Color(0x00000000),
      builder: (_) => FolderPickerDialog(
        folders: folders,
        current: state.filters.folder ?? 'tous',
      ),
    );
    if (picked != null) {
      await ref.read(searchProvider.notifier).setFolder(picked == 'tous' ? null : picked);
    }
  }

  Future<void> _pickTag(BuildContext context, WidgetRef ref) async {
    final tags = ref.read(vaultProvider).tags;
    if (tags.isEmpty) return;
    final picked = await showDialog<String>(
      context: context,
      barrierColor: const Color(0x00000000),
      builder: (_) => FolderPickerDialog(folders: tags.map((t) => t.name).toList()),
    );
    if (picked != null) await ref.read(searchProvider.notifier).toggleTag(picked);
  }
}

class _Results extends StatelessWidget {
  const _Results({
    required this.state,
    required this.scroll,
    required this.onOpen,
    required this.onCreate,
  });

  final SearchState state;
  final ScrollController scroll;
  final ValueChanged<int> onOpen;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        controller: scroll,
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              child: SectionLabel('Notes', small: true),
            ),
            for (var i = 0; i < state.results.length; i++) ...[
              _ResultRow(
                hit: state.results[i],
                selected: i == state.selectedIndex,
                onTap: () => onOpen(i),
              ),
              const SizedBox(height: 2),
            ],
            if (state.query.trim().isNotEmpty) ...[
              const Padding(
                padding: EdgeInsets.fromLTRB(10, 9, 10, 5),
                child: SectionLabel('Actions', small: true),
              ),
              Hoverable(
                onTap: onCreate,
                builder: (context, hovered) => Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: hovered ? JotColors.neutralWash : null,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 26,
                        child: Center(
                          child: Text(
                            '+',
                            style: JotText.ui(size: 14, color: JotColors.accent),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Créer une note « ${state.query.trim()} »',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: JotText.ui(size: 12.5, color: JotColors.textStrong),
                        ),
                      ),
                      Text('Ctrl Entrée', style: JotText.keycap.copyWith(color: JotColors.textSubtle)),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      );
}

class _ResultRow extends StatelessWidget {
  const _ResultRow({required this.hit, required this.selected, required this.onTap});

  final SearchHit hit;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final note = hit.note;

    return Hoverable(
      onTap: onTap,
      builder: (context, hovered) => Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: selected
              ? JotColors.accentWashResult
              : (hovered ? JotColors.neutralWash : null),
          border: selected ? Border.all(color: JotColors.accentWashStrong) : null,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: TypeBadge.roomy(note.type),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  HighlightedText(
                    note.title,
                    span: hit.titleMatch,
                    style: JotText.ui(
                      size: 13,
                      weight: FontWeight.w600,
                      height: 1.3,
                      color: selected ? JotColors.textBright : JotColors.textStrong,
                    ),
                  ),
                  const SizedBox(height: 4),
                  HighlightedText(
                    note.preview,
                    span: hit.previewMatch,
                    style: JotText.mono(
                      size: 11.5,
                      height: 1.5,
                      color: selected ? JotColors.textMuted : JotColors.textFaint,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${note.folder}, ${JotFormat.relative(note.modified)}',
                  style: JotText.ui(
                    size: 11,
                    color: selected ? JotColors.textDim : JotColors.textSubtle,
                  ),
                ),
                if (selected) ...[
                  const SizedBox(height: 5),
                  Text(
                    'Entrée pour ouvrir',
                    style: JotText.mono(
                      size: 10,
                      weight: FontWeight.w500,
                      color: JotColors.accentHighlightText,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// "Aucun résultat pour « ... »" — offers the two fastest ways out: drop the
/// filters, or turn the query straight into a note.
class _PaletteEmpty extends ConsumerWidget {
  const _PaletteEmpty({required this.state, required this.onCreate});

  final SearchState state;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = state.query.trim();
    final filtered = !state.filters.isEmpty;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 64, 20, 70),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              border: Border.all(color: JotColors.borderRaised, width: 1.5),
              borderRadius: BorderRadius.circular(10),
            ),
            child: JotIcon(JotIcons.search, size: 20, color: JotColors.textDisabled),
          ),
          const SizedBox(height: 14),
          Text(
            query.isEmpty
                ? 'Aucune note à afficher'
                : 'Aucun résultat pour « $query »',
            style: JotText.ui(
              size: 14,
              weight: FontWeight.w600,
              color: JotColors.textStrong,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: 340,
            child: Text(
              filtered
                  ? 'Les filtres actifs limitent la recherche. Essaie sans eux, '
                      'ou cherche dans tous les dossiers.'
                  : 'Aucune note parmi les ${state.corpusSize} indexées.',
              textAlign: TextAlign.center,
              style: JotText.ui(size: 12, height: 1.6, color: JotColors.textFaint),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (filtered)
                JotButton(
                  'Chercher partout',
                  onTap: ref.read(searchProvider.notifier).clearFilters,
                ),
              if (filtered && query.isNotEmpty) const SizedBox(width: 8),
              if (query.isNotEmpty)
                JotButton(
                  'Créer « $query »',
                  kind: JotButtonKind.secondary,
                  onTap: onCreate,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({required this.state});

  final SearchState state;

  @override
  Widget build(BuildContext context) {
    final style = JotText.mono(size: 10.5, color: JotColors.textSubtle);

    return Container(
      height: JotMetrics.paletteFooterHeight,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: JotColors.footer,
        border: Border(top: BorderSide(color: JotColors.borderPalette)),
      ),
      child: Row(
        children: [
          Text('Flèches pour naviguer', style: style),
          const SizedBox(width: 16),
          Text('Entrée pour ouvrir', style: style),
          const SizedBox(width: 16),
          Text('Ctrl Entrée créer', style: style),
          const SizedBox(width: 16),
          Text('Esc fermer', style: style),
          const Spacer(),
          Text(
            'recherche dans ${state.corpusSize} notes, '
            '${state.elapsed.inMicroseconds ~/ 1000} ms',
            style: style,
          ),
        ],
      ),
    );
  }
}
