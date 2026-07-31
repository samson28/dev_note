import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../core/models/note.dart';
import '../core/models/note_type.dart';
import 'jot_services.dart';

/// What the sidebar is currently filtering by.
@immutable
sealed class Scope {
  const Scope();
  String get label;

  bool isFolder(String name) => this is FolderScope && (this as FolderScope).folder == name;
  bool isTag(String name) => this is TagScope && (this as TagScope).tag == name;
}

class FolderScope extends Scope {
  const FolderScope(this.folder);
  final String folder;
  @override
  String get label => folder;
}

class TagScope extends Scope {
  const TagScope(this.tag);
  final String tag;
  @override
  String get label => '#$tag';
}

@immutable
class VaultState {
  const VaultState({
    this.folders = const [],
    this.tags = const [],
    this.notes = const [],
    this.scope = const FolderScope(Folder.inbox),
    this.openNote,
    this.loading = true,
    this.totalNotes = 0,
    this.notice,
  });

  final List<Folder> folders;
  final List<Tag> tags;

  /// Notes for the current [scope]. Their `content` holds only the preview —
  /// the full body is loaded on demand into [openNote].
  final List<Note> notes;
  final Scope scope;

  /// The note shown in the right column, with its complete body.
  final Note? openNote;

  final bool loading;
  final int totalNotes;

  /// Transient, non-blocking message (unreadable file, index rebuilt...).
  final String? notice;

  VaultState copyWith({
    List<Folder>? folders,
    List<Tag>? tags,
    List<Note>? notes,
    Scope? scope,
    Note? openNote,
    bool clearOpenNote = false,
    bool? loading,
    int? totalNotes,
    String? notice,
    bool clearNotice = false,
  }) => VaultState(
    folders: folders ?? this.folders,
    tags: tags ?? this.tags,
    notes: notes ?? this.notes,
    scope: scope ?? this.scope,
    openNote: clearOpenNote ? null : (openNote ?? this.openNote),
    loading: loading ?? this.loading,
    totalNotes: totalNotes ?? this.totalNotes,
    notice: clearNotice ? null : (notice ?? this.notice),
  );
}

/// Owns everything the three columns render, and is the single place where a
/// note is written to disk.
///
/// Writes go to the file first and to the index immediately after, rather than
/// waiting for the watcher — saving must feel instant, and the watcher event
/// for our own write is suppressed so the work is not done twice.
class VaultNotifier extends Notifier<VaultState> {
  late final JotServices _services;
  StreamSubscription<void>? _watchSub;
  Timer? _autosave;

  @override
  VaultState build() {
    _services = ref.watch(servicesProvider);

    _watchSub = _services.watcher.onIndexChanged.listen((_) => refresh());
    ref.onDispose(() {
      _watchSub?.cancel();
      _autosave?.cancel();
    });

    scheduleMicrotask(refresh);
    return const VaultState();
  }

  // ------------------------------------------------------------------- load

  Future<void> refresh() async {
    final folders = await _services.index.listFolders();
    final tags = await _services.index.listTags();
    final notes = await _notesForScope(state.scope);
    final total = await _services.index.count();

    final errors = _services.files.recoverableErrors;
    final notice = errors.isEmpty
        ? null
        : '${errors.length} fichier(s) illisible(s), ignoré(s)';

    state = state.copyWith(
      folders: folders,
      tags: tags,
      notes: notes,
      totalNotes: total,
      loading: false,
      notice: notice,
      clearNotice: notice == null,
    );

    // Keep a selection alive across refreshes so an external edit does not
    // yank the editor out from under the user.
    final open = state.openNote;
    if (open == null) {
      if (notes.isNotEmpty) await open_(notes.first);
    } else if (!notes.any((n) => n.id == open.id)) {
      if (notes.isNotEmpty) {
        await open_(notes.first);
      } else {
        state = state.copyWith(clearOpenNote: true);
      }
    }
  }

  Future<List<Note>> _notesForScope(Scope scope) => switch (scope) {
    FolderScope(:final folder) => _services.index.listNotes(folder: folder),
    TagScope(:final tag) => _services.index.listNotes(tag: tag),
  };

  Future<void> selectScope(Scope scope) async {
    state = state.copyWith(scope: scope, clearOpenNote: true);
    final notes = await _notesForScope(scope);
    state = state.copyWith(notes: notes);
    if (notes.isNotEmpty) await open_(notes.first);
  }

  /// Loads the full body of [note] into the editor.
  Future<void> open_(Note note) async {
    // Show the row's metadata immediately, then swap in the body once read —
    // the pane must never flash empty.
    state = state.copyWith(openNote: note);

    final file = File(
      p.joinAll([_services.files.root.path, ...p.split(note.relativePath)]),
    );
    final full = await _services.files.tryRead(file);
    if (full != null && state.openNote?.id == note.id) {
      state = state.copyWith(openNote: full);
    }
  }

  /// Opens a note that may live outside the current scope (from the palette),
  /// switching the sidebar selection to follow it.
  Future<void> reveal(Note note) async {
    if (state.scope case FolderScope(:final folder) when folder == note.folder) {
      await open_(note);
      return;
    }
    state = state.copyWith(scope: FolderScope(note.folder));
    state = state.copyWith(notes: await _notesForScope(state.scope));
    await open_(note);
  }

  // ------------------------------------------------------------------ write

  Future<Note> create({
    String content = '',
    String? title,
    NoteType? type,
    String? folder,
    List<String> tags = const [],
  }) async {
    final target = folder ??
        switch (state.scope) {
          FolderScope(folder: final current) => current,
          // A tag is not a place on disk — new notes from a tag view land in
          // Inbox, which is where the user can always find them again.
          TagScope() => Folder.inbox,
        };

    final note = await _services.files.create(
      content: content,
      title: title,
      type: type,
      folder: target,
      tags: tags,
    );
    _services.watcher.expectSelfWrite(note.relativePath);
    await _services.index.upsert(note);
    await refresh();
    await open_(note);
    return note;
  }

  /// Debounced autosave — the design's status bar says "Enregistré
  /// automatiquement", so there is no save button to press.
  void edit(Note updated) {
    state = state.copyWith(openNote: updated);
    _autosave?.cancel();
    _autosave = Timer(const Duration(milliseconds: 400), () => save(updated));
  }

  Future<void> save(Note updated) async {
    final previous = state.notes.firstWhere(
      (n) => n.id == updated.id,
      orElse: () => updated,
    );
    final saved = await _services.files.update(previous, updated);
    _services.watcher
      ..expectSelfWrite(previous.relativePath)
      ..expectSelfWrite(saved.relativePath);
    await _services.index.upsert(saved);
    state = state.copyWith(openNote: saved);
    await refresh();
  }

  Future<void> togglePin(Note note) =>
      save(note.copyWith(pinned: !note.pinned));

  Future<void> setType(Note note, NoteType type) =>
      save(note.copyWith(type: type));

  Future<void> addTag(Note note, String tag) {
    final clean = tag.trim().replaceFirst('#', '').toLowerCase();
    if (clean.isEmpty || note.tags.contains(clean)) return Future.value();
    return save(note.copyWith(tags: [...note.tags, clean]));
  }

  Future<void> removeTag(Note note, String tag) =>
      save(note.copyWith(tags: note.tags.where((t) => t != tag).toList()));

  Future<void> move(Note note, String folder) =>
      save(note.copyWith(folder: folder));

  Future<void> delete(Note note) async {
    await _services.files.delete(note);
    _services.watcher.expectSelfWrite(note.relativePath);
    await _services.index.remove(note.id);
    if (state.openNote?.id == note.id) {
      state = state.copyWith(clearOpenNote: true);
    }
    await refresh();
  }

  Future<void> createFolder(String name) async {
    await _services.files.createFolder(name.trim());
    await refresh();
  }

  /// Manual repair for an index that has drifted out of sync.
  Future<void> rebuildIndex() async {
    state = state.copyWith(loading: true);
    await _services.index.rebuild();
    await refresh();
    state = state.copyWith(
      notice: 'Index reconstruit en '
          '${_services.index.lastRebuild?.inMilliseconds ?? 0} ms',
    );
  }

  void dismissNotice() => state = state.copyWith(clearNotice: true);
}

final vaultProvider =
    NotifierProvider<VaultNotifier, VaultState>(VaultNotifier.new);
