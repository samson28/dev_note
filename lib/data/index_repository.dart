import 'package:drift/drift.dart';

import '../core/models/note.dart';
import '../core/models/note_type.dart';
import 'database.dart';
import 'file_repository.dart';

/// One search result: the note plus the span of the query that matched, so
/// the palette can highlight it the way the design does.
class SearchHit {
  const SearchHit({required this.note, this.titleMatch, this.previewMatch});

  final Note note;

  /// `(start, end)` inside [Note.title], or null when the match was elsewhere.
  final (int, int)? titleMatch;

  /// `(start, end)` inside [Note.preview].
  final (int, int)? previewMatch;
}

/// Filters applied on top of a query, mirroring the palette's chip row.
class SearchFilters {
  const SearchFilters({this.types = const {}, this.folder, this.tags = const {}});

  final Set<NoteType> types;
  final String? folder;
  final Set<String> tags;

  bool get isEmpty => types.isEmpty && folder == null && tags.isEmpty;

  SearchFilters copyWith({
    Set<NoteType>? types,
    String? folder,
    bool clearFolder = false,
    Set<String>? tags,
  }) => SearchFilters(
    types: types ?? this.types,
    folder: clearFolder ? null : (folder ?? this.folder),
    tags: tags ?? this.tags,
  );
}

/// The SQLite/FTS5 index over the vault.
///
/// It is a *cache*: every method degrades to a full rescan of the vault
/// rather than reporting an error, because the files on disk are always
/// authoritative and a stale index is never worth blocking the user over.
class IndexRepository {
  IndexRepository(this.db, this.files);

  final JotDatabase db;
  final FileRepository files;

  /// How long the last full rebuild took, shown in the palette footer.
  Duration? lastRebuild;

  // ------------------------------------------------------------------- sync

  /// Brings the index in line with the vault. Cheap when nothing changed:
  /// only files whose mtime or size differs from the indexed row are re-read.
  ///
  /// Returns the notes now in the index.
  Future<List<Note>> synchronise({bool force = false}) async {
    final started = DateTime.now();

    final indexed = {
      for (final row in await db.select(db.noteRows).get()) row.relativePath: row,
    };

    final seen = <String>{};
    final notes = <Note>[];

    await for (final file in files.noteFiles()) {
      final relative = files.relativePathOf(file);
      seen.add(relative);

      final row = indexed[relative];
      if (!force && row != null) {
        final stat = await file.stat();
        // Compare against the filesystem metadata we recorded, not the
        // frontmatter's `modified`, our own writes always bump the file's
        // mtime past it, which would make every file look dirty forever.
        final unchanged = stat.modified == row.fileModified &&
            stat.size == row.fileSize;
        if (unchanged) {
          notes.add(_fromRow(row, content: null));
          continue;
        }
      }

      final note = await files.tryRead(file);
      if (note == null) continue;
      await upsert(note);
      notes.add(note);
    }

    // Rows whose file disappeared while we were not watching.
    for (final stale in indexed.keys.where((k) => !seen.contains(k))) {
      await removeByPath(stale);
    }

    lastRebuild = DateTime.now().difference(started);
    return notes;
  }

  /// Wipes the index and reads the whole vault back in. Used when the index
  /// is missing or unusable, and available from the UI as a repair action.
  Future<List<Note>> rebuild() async {
    await db.transaction(() async {
      await db.delete(db.noteRows).go();
      await db.customStatement('DELETE FROM notes_fts');
    });
    return synchronise(force: true);
  }

  bool get isEmpty => _cachedCount == 0;
  int _cachedCount = -1;

  Future<int> count() async {
    final row = await db
        .customSelect('SELECT count(*) AS c FROM note_rows')
        .getSingle();
    return _cachedCount = row.read<int>('c');
  }

  // ------------------------------------------------------------------ write

  Future<void> upsert(Note note) async {
    await db.transaction(() async {
      // `relative_path` carries a UNIQUE index, but the upsert below resolves
      // conflicts on `id`. A note recreated at a path a *different* id once
      // held, a rename that slugifies the same, a deleted-then-restored
      // file, would otherwise trip the index instead of replacing the row.
      await (db.delete(db.noteRows)
            ..where((t) =>
                t.relativePath.equals(note.relativePath) & t.id.equals(note.id).not()))
          .go();

      await db.into(db.noteRows).insertOnConflictUpdate(
            NoteRowsCompanion.insert(
              id: note.id,
              title: note.title,
              type: note.type.id,
              folder: note.folder,
              relativePath: note.relativePath,
              created: note.created,
              modified: note.modified,
              tags: Value(note.tags.map((t) => t.toLowerCase()).join(' ')),
              preview: Value(note.preview),
              pinned: Value(note.pinned),
              color: Value(note.color),
              sizeBytes: Value(note.sizeBytes),
              lineCount: Value(note.lineCount),
              fileModified: Value(
                note.fileModified ?? DateTime.fromMillisecondsSinceEpoch(0),
              ),
              fileSize: Value(note.fileSize),
            ),
          );

      await db.customStatement(
        'DELETE FROM notes_fts WHERE note_id = ?',
        [note.id],
      );
      await db.customStatement(
        'INSERT INTO notes_fts (note_id, title, content, tags) VALUES (?, ?, ?, ?)',
        [note.id, note.title, note.content, note.tags.join(' ')],
      );
    });
    _cachedCount = -1;
  }

  Future<void> remove(String id) async {
    await db.transaction(() async {
      await (db.delete(db.noteRows)..where((t) => t.id.equals(id))).go();
      await db.customStatement('DELETE FROM notes_fts WHERE note_id = ?', [id]);
    });
    _cachedCount = -1;
  }

  Future<void> removeByPath(String relativePath) async {
    final row = await (db.select(db.noteRows)
          ..where((t) => t.relativePath.equals(relativePath)))
        .getSingleOrNull();
    if (row != null) await remove(row.id);
  }

  // ------------------------------------------------------------------- read

  /// Notes for a sidebar selection, ordered the way the list column shows
  /// them: pinned first, then most recently modified.
  Future<List<Note>> listNotes({String? folder, String? tag, int limit = 500}) async {
    final query = db.select(db.noteRows)
      ..orderBy([
        (t) => OrderingTerm(expression: t.pinned, mode: OrderingMode.desc),
        (t) => OrderingTerm(expression: t.modified, mode: OrderingMode.desc),
      ])
      ..limit(limit);

    // A parent shows what is under it. Selecting "Enko" and being told it is
    // empty because everything sits in "Enko/Webhooks" would make the tree
    // worse than the flat list it replaced.
    if (folder != null) {
      query.where(
        (t) => t.folder.equals(folder) | t.folder.like('$folder/%'),
      );
    }
    if (tag != null) {
      query.where(
        (t) => t.tags.equals(tag.toLowerCase()) |
            t.tags.like('${tag.toLowerCase()} %') |
            t.tags.like('% ${tag.toLowerCase()}') |
            t.tags.like('% ${tag.toLowerCase()} %'),
      );
    }

    return (await query.get()).map((r) => _fromRow(r, content: null)).toList();
  }

  Future<List<Folder>> listFolders() async {
    final rows = await db
        .customSelect(
          'SELECT folder, count(*) AS c FROM note_rows GROUP BY folder',
        )
        .get();

    final counts = {
      for (final r in rows) r.read<String>('folder'): r.read<int>('c'),
    };

    final names = await files.listFolders();
    for (final name in counts.keys) {
      if (!names.contains(name)) names.add(name);
    }

    // A parent's count includes everything beneath it, because that is what
    // clicking it shows. A folder whose badge says 0 but which opens onto
    // twelve notes would be worse than no badge at all.
    int total(String name) => counts.entries
        .where((e) => e.key == name || FileRepository.isDescendant(e.key, name))
        .fold(0, (sum, e) => sum + e.value);

    return [
      for (final name in names)
        Folder(
          name: name,
          noteCount: total(name),
          muted: name == Folder.archive,
        ),
    ];
  }

  Future<List<Tag>> listTags() async {
    final rows = await db
        .customSelect("SELECT tags FROM note_rows WHERE tags <> ''")
        .get();

    final counts = <String, int>{};
    for (final row in rows) {
      for (final tag in row.read<String>('tags').split(' ')) {
        if (tag.isEmpty) continue;
        counts[tag] = (counts[tag] ?? 0) + 1;
      }
    }

    final tags = counts.entries.map((e) => Tag(name: e.key, noteCount: e.value)).toList()
      ..sort((a, b) {
        final byCount = b.noteCount.compareTo(a.noteCount);
        return byCount != 0 ? byCount : a.name.compareTo(b.name);
      });
    return tags;
  }

  // ----------------------------------------------------------------- search

  /// Full-text search over title, body and tags.
  ///
  /// FTS5 handles the token/prefix matching (fast, ranked). Because developers
  /// habitually search for a fragment *inside* an identifier, `hook` to find
  /// `webhook_failed`, the FTS pass is topped up with a substring scan, which
  /// tokenised search structurally cannot answer. The two are merged with FTS
  /// hits first, since those are the better matches.
  Future<List<SearchHit>> search(
    String rawQuery, {
    SearchFilters filters = const SearchFilters(),
    int limit = 50,
  }) async {
    final query = rawQuery.trim();
    if (query.isEmpty) {
      final notes = await listNotes(folder: filters.folder, limit: limit);
      return notes.where((n) => _passes(n, filters)).map((n) => SearchHit(note: n)).toList();
    }

    final byId = <String, Note>{};
    final ordered = <Note>[];

    void take(Iterable<Note> notes) {
      for (final note in notes) {
        if (byId.containsKey(note.id)) continue;
        if (!_passes(note, filters)) continue;
        byId[note.id] = note;
        ordered.add(note);
      }
    }

    take(await _ftsSearch(query, limit));
    if (ordered.length < limit) {
      take(await _substringSearch(query, limit));
    }

    return [
      for (final note in ordered.take(limit))
        SearchHit(
          note: note,
          titleMatch: _span(note.title, query),
          previewMatch: _span(note.preview, query),
        ),
    ];
  }

  Future<List<Note>> _ftsSearch(String query, int limit) async {
    final match = _toMatchExpression(query);
    if (match == null) return const [];

    try {
      final rows = await db.customSelect(
        '''
SELECT n.* FROM notes_fts f
JOIN note_rows n ON n.id = f.note_id
WHERE notes_fts MATCH ?
ORDER BY rank, n.pinned DESC, n.modified DESC
LIMIT ?
''',
        variables: [Variable<String>(match), Variable<int>(limit)],
        readsFrom: {db.noteRows},
      ).get();
      return rows.map(_fromQueryRow).toList();
    } on Object {
      // A malformed MATCH expression must not break the search box, fall
      // through to the substring pass instead.
      return const [];
    }
  }

  Future<List<Note>> _substringSearch(String query, int limit) async {
    final like = '%${query.replaceAll('%', r'\%').replaceAll('_', r'\_')}%';
    final rows = await db.customSelect(
      '''
SELECT * FROM note_rows
WHERE title LIKE ? ESCAPE '\\' OR preview LIKE ? ESCAPE '\\' OR tags LIKE ? ESCAPE '\\'
ORDER BY pinned DESC, modified DESC
LIMIT ?
''',
      variables: [
        Variable<String>(like),
        Variable<String>(like),
        Variable<String>(like),
        Variable<int>(limit),
      ],
      readsFrom: {db.noteRows},
    ).get();
    return rows.map(_fromQueryRow).toList();
  }

  /// Builds a prefix MATCH expression: `webhook str` -> `"webhook"* "str"*`.
  /// Everything is quoted so punctuation in the query cannot be read as FTS
  /// syntax.
  static String? _toMatchExpression(String query) {
    final terms = query
        .split(RegExp(r'\s+'))
        .map((t) => t.replaceAll(RegExp(r'[^\wÀ-ɏ]+'), ' ').trim())
        .where((t) => t.isNotEmpty)
        .toList();
    if (terms.isEmpty) return null;
    return terms.map((t) => '"${t.replaceAll('"', '""')}"*').join(' ');
  }

  static (int, int)? _span(String haystack, String needle) {
    final index = haystack.toLowerCase().indexOf(needle.toLowerCase());
    return index == -1 ? null : (index, index + needle.length);
  }

  bool _passes(Note note, SearchFilters f) {
    if (f.types.isNotEmpty && !f.types.contains(note.type)) return false;
    if (f.folder != null &&
        note.folder != f.folder &&
        !FileRepository.isDescendant(note.folder, f.folder!)) {
      return false;
    }
    if (f.tags.isNotEmpty) {
      final lower = note.tags.map((t) => t.toLowerCase()).toSet();
      if (!f.tags.every((t) => lower.contains(t.toLowerCase()))) return false;
    }
    return true;
  }

  /// Counts per type for the palette's filter chips, computed over the
  /// unfiltered result set so the chips can show what *would* match.
  static Map<NoteType, int> typeCounts(List<SearchHit> hits) {
    final counts = {for (final t in NoteType.values) t: 0};
    for (final hit in hits) {
      counts[hit.note.type] = (counts[hit.note.type] ?? 0) + 1;
    }
    return counts;
  }

  // ---------------------------------------------------------------- mapping

  Note _fromRow(NoteRow row, {required String? content}) => Note(
        id: row.id,
        title: row.title,
        type: NoteType.fromId(row.type),
        content: content ?? row.preview,
        folder: row.folder,
        tags: row.tags.isEmpty ? const [] : row.tags.split(' '),
        created: row.created,
        modified: row.modified,
        relativePath: row.relativePath,
        pinned: row.pinned,
        color: row.color,
        sizeBytes: row.sizeBytes,
        fileModified: row.fileModified,
        fileSize: row.fileSize,
      );

  Note _fromQueryRow(QueryRow row) => Note(
        id: row.read<String>('id'),
        title: row.read<String>('title'),
        type: NoteType.fromId(row.read<String>('type')),
        content: row.read<String>('preview'),
        folder: row.read<String>('folder'),
        tags: () {
          final t = row.read<String>('tags');
          return t.isEmpty ? const <String>[] : t.split(' ');
        }(),
        created: row.read<DateTime>('created'),
        modified: row.read<DateTime>('modified'),
        relativePath: row.read<String>('relative_path'),
        pinned: row.read<bool>('pinned'),
        color: row.readNullable<String>('color'),
        sizeBytes: row.read<int>('size_bytes'),
      );
}
