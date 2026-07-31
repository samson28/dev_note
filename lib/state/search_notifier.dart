import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/models/note_type.dart';
import '../data/index_repository.dart';
import 'jot_services.dart';

@immutable
class SearchState {
  const SearchState({
    this.open = false,
    this.query = '',
    this.filters = const SearchFilters(),
    this.results = const [],
    this.typeCounts = const {},
    this.totalMatches = 0,
    this.selectedIndex = 0,
    this.elapsed = Duration.zero,
    this.corpusSize = 0,
  });

  final bool open;
  final String query;
  final SearchFilters filters;

  /// Results after [filters] have been applied.
  final List<SearchHit> results;

  /// Counts per type *before* the type filter, so the chips can show what
  /// each one would yield.
  final Map<NoteType, int> typeCounts;
  final int totalMatches;

  final int selectedIndex;
  final Duration elapsed;
  final int corpusSize;

  bool get isEmpty => results.isEmpty;

  SearchState copyWith({
    bool? open,
    String? query,
    SearchFilters? filters,
    List<SearchHit>? results,
    Map<NoteType, int>? typeCounts,
    int? totalMatches,
    int? selectedIndex,
    Duration? elapsed,
    int? corpusSize,
  }) => SearchState(
    open: open ?? this.open,
    query: query ?? this.query,
    filters: filters ?? this.filters,
    results: results ?? this.results,
    typeCounts: typeCounts ?? this.typeCounts,
    totalMatches: totalMatches ?? this.totalMatches,
    selectedIndex: selectedIndex ?? this.selectedIndex,
    elapsed: elapsed ?? this.elapsed,
    corpusSize: corpusSize ?? this.corpusSize,
  );
}

/// Drives the Ctrl K palette.
///
/// Queries run on every keystroke with no debounce: FTS over a few hundred
/// notes is sub-millisecond, and waiting 150 ms before showing results is the
/// exact friction this app exists to remove. A monotonically increasing token
/// discards responses that arrive out of order.
class SearchNotifier extends Notifier<SearchState> {
  late final JotServices _services;
  int _token = 0;

  @override
  SearchState build() {
    _services = ref.watch(servicesProvider);
    return const SearchState();
  }

  Future<void> openPalette({String seed = ''}) async {
    state = state.copyWith(open: true, query: seed, selectedIndex: 0);
    await _run();
  }

  void close() => state = state.copyWith(open: false);

  Future<void> setQuery(String query) async {
    state = state.copyWith(query: query, selectedIndex: 0);
    await _run();
  }

  Future<void> toggleType(NoteType type) async {
    final types = Set<NoteType>.from(state.filters.types);
    if (!types.remove(type)) types.add(type);
    state = state.copyWith(
      filters: state.filters.copyWith(types: types),
      selectedIndex: 0,
    );
    await _run();
  }

  Future<void> clearTypes() async {
    state = state.copyWith(
      filters: state.filters.copyWith(types: const {}),
      selectedIndex: 0,
    );
    await _run();
  }

  Future<void> setFolder(String? folder) async {
    state = state.copyWith(
      filters: folder == null
          ? state.filters.copyWith(clearFolder: true)
          : state.filters.copyWith(folder: folder),
      selectedIndex: 0,
    );
    await _run();
  }

  Future<void> toggleTag(String tag) async {
    final tags = Set<String>.from(state.filters.tags);
    if (!tags.remove(tag)) tags.add(tag);
    state = state.copyWith(
      filters: state.filters.copyWith(tags: tags),
      selectedIndex: 0,
    );
    await _run();
  }

  /// Replaces the tag filter with exactly [tag].
  ///
  /// [toggleTag] is what the palette's chips need; a scope is not a toggle,
  /// it is the one tag being looked at.
  Future<void> setOnlyTag(String tag) async {
    if (state.filters.tags.length == 1 && state.filters.tags.contains(tag)) {
      return;
    }
    state = state.copyWith(
      filters: state.filters.copyWith(tags: {tag}),
      selectedIndex: 0,
    );
    await _run();
  }

  Future<void> clearTags() async {
    if (state.filters.tags.isEmpty) return;
    state = state.copyWith(
      filters: state.filters.copyWith(tags: const {}),
      selectedIndex: 0,
    );
    await _run();
  }

  /// "Chercher partout" on the empty state.
  Future<void> clearFilters() async {
    state = state.copyWith(
      filters: const SearchFilters(),
      selectedIndex: 0,
    );
    await _run();
  }

  void moveSelection(int delta) {
    if (state.results.isEmpty) return;
    final next = (state.selectedIndex + delta).clamp(0, state.results.length - 1);
    state = state.copyWith(selectedIndex: next);
  }

  Future<void> _run() async {
    final token = ++_token;
    final watch = Stopwatch()..start();

    // Run once without the type filter to get honest chip counts, then apply
    // it locally — one query instead of five.
    final unfiltered = await _services.index.search(
      state.query,
      filters: state.filters.copyWith(types: const {}),
      limit: 200,
    );
    if (token != _token) return;

    final types = state.filters.types;
    final results = types.isEmpty
        ? unfiltered
        : unfiltered.where((h) => types.contains(h.note.type)).toList();

    watch.stop();

    state = state.copyWith(
      results: results.take(50).toList(),
      typeCounts: IndexRepository.typeCounts(unfiltered),
      totalMatches: unfiltered.length,
      elapsed: watch.elapsed,
      corpusSize: await _services.index.count(),
      selectedIndex: state.selectedIndex.clamp(
        0,
        results.isEmpty ? 0 : results.length - 1,
      ),
    );
  }
}

final searchProvider =
    NotifierProvider<SearchNotifier, SearchState>(SearchNotifier.new);
