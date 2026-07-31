import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import 'package:yaml/yaml.dart';

import '../core/models/note.dart';
import '../core/models/note_type.dart';
import 'vault_paths.dart';

/// A failure that should surface to the user without taking the app down.
///
/// Reading notes is best-effort by design: one unreadable or hand-mangled
/// file must never block the rest of the vault from loading.
class VaultException implements Exception {
  VaultException(this.message, [this.path]);
  final String message;
  final String? path;

  @override
  String toString() =>
      path == null ? 'VaultException: $message' : 'VaultException: $message ($path)';
}

/// A note sitting in the trash, with enough context to put it back.
class TrashedNote {
  const TrashedNote({
    required this.file,
    required this.originalPath,
    required this.deletedAt,
    this.frontmatterTitle,
  });

  final File file;
  final String originalPath;
  final DateTime deletedAt;

  /// Title read from the trashed file, when it was readable.
  final String? frontmatterTitle;

  /// The note's own title, falling back to the file name when the frontmatter
  /// could not be read.
  String get title =>
      frontmatterTitle ?? p.basenameWithoutExtension(originalPath);
}

/// Reads and writes the vault: one `.md` file per note, YAML frontmatter on
/// top, raw content underneath. Files are the source of truth — the SQLite
/// index in [IndexRepository] is a derived cache that can be thrown away.
class FileRepository {
  FileRepository(this.root);

  final Directory root;

  static const _uuid = Uuid();
  static const _fence = '---';

  static Future<FileRepository> open() async =>
      FileRepository(await VaultPaths.vault());

  /// Errors hit during the last scan, surfaced in the UI as a non-blocking
  /// notice rather than a dialog.
  final List<VaultException> recoverableErrors = [];

  // ------------------------------------------------------------------ layout

  Directory folderDir(String folder) =>
      Directory(p.joinAll([root.path, ...p.split(folder)]));

  String relativePathOf(File file) =>
      p.relative(file.path, from: root.path).replaceAll(r'\', '/');

  String folderOf(File file) {
    final rel = relativePathOf(file);
    final dir = p.url.dirname(rel);
    return (dir == '.' || dir.isEmpty) ? Folder.inbox : dir;
  }

  /// Creates the default folders so a fresh vault is never an empty void.
  Future<void> ensureScaffold() async {
    for (final name in const [Folder.inbox, Folder.archive]) {
      final dir = folderDir(name);
      if (!await dir.exists()) await dir.create(recursive: true);
    }
  }

  Future<List<String>> listFolders() async {
    final folders = <String>{Folder.inbox};
    await for (final entity in root.list(recursive: true, followLinks: false)) {
      if (entity is! Directory) continue;
      final name = p.relative(entity.path, from: root.path).replaceAll(r'\', '/');
      if (name.startsWith('.')) continue;
      folders.add(name);
    }
    return folders.toList()..sort(_folderOrder);
  }

  /// Inbox first, Archive last, everything else alphabetically — matching the
  /// order shown in the sidebar.
  static int _folderOrder(String a, String b) {
    int rank(String f) => switch (f) {
      Folder.inbox => 0,
      Folder.archive => 2,
      _ => 1,
    };
    final byRank = rank(a).compareTo(rank(b));
    return byRank != 0 ? byRank : a.toLowerCase().compareTo(b.toLowerCase());
  }

  // ------------------------------------------------------------------- read

  Stream<File> noteFiles() => root
      .list(recursive: true, followLinks: false)
      .where((e) => e is File && p.extension(e.path).toLowerCase() == '.md')
      .cast<File>()
      // Skip dotfolders (e.g. a `.git` inside the vault).
      .where((f) => !p.split(p.relative(f.path, from: root.path)).any((s) => s.startsWith('.')));

  /// Reads every note in the vault. Unreadable files are collected in
  /// [recoverableErrors] and skipped.
  Future<List<Note>> readAll() async {
    recoverableErrors.clear();
    final notes = <Note>[];
    await for (final file in noteFiles()) {
      final note = await tryRead(file);
      if (note != null) notes.add(note);
    }
    return notes;
  }

  /// Reads one file, returning `null` (and recording the reason) on failure.
  Future<Note?> tryRead(File file) async {
    try {
      return await read(file);
    } on Object catch (e) {
      recoverableErrors.add(VaultException('$e', file.path));
      return null;
    }
  }

  Future<Note> read(File file) async {
    final raw = await file.readAsString();
    final stat = await file.stat();
    final (frontmatter, body) = _split(raw);

    final map = frontmatter == null ? const <String, dynamic>{} : _parseYaml(frontmatter);
    final relative = relativePathOf(file);

    // Anything missing from the frontmatter is inferred, so a plain `.md`
    // dropped into the vault by hand still shows up as a proper note.
    final title = _string(map['title']) ??
        _titleFromBody(body) ??
        p.basenameWithoutExtension(file.path);

    return Note(
      id: _string(map['id']) ?? _deterministicId(relative),
      title: title,
      type: map['type'] != null
          ? NoteType.fromId(_string(map['type']))
          : NoteTypeDetector.detect(body),
      content: body,
      folder: _string(map['folder']) ?? folderOf(file),
      tags: _stringList(map['tags']),
      created: _dateTime(map['created']) ?? stat.changed,
      modified: _dateTime(map['modified']) ?? stat.modified,
      relativePath: relative,
      pinned: map['pinned'] == true,
      color: _string(map['color']),
      attachment: _string(map['attachment']),
      attachmentBytes: _int(map['attachment_size']) ?? 0,
      sourceName: _string(map['source']),
      // The body's size, not the file's — the frontmatter is bookkeeping and
      // has no business showing up in the status bar.
      sizeBytes: utf8.encode(body).length,
      fileModified: stat.modified,
      fileSize: stat.size,
    );
  }

  // ------------------------------------------------------------------ write

  /// Creates a new note and writes it to disk. Returns the persisted note,
  /// with its final [Note.relativePath] resolved against filename collisions.
  Future<Note> create({
    required String content,
    String? title,
    NoteType? type,
    String folder = Folder.inbox,
    List<String> tags = const [],
    bool pinned = false,
  }) async {
    final now = DateTime.now();
    final resolvedTitle = (title == null || title.trim().isEmpty)
        ? _titleFromBody(content) ?? 'Note sans titre'
        : title.trim();

    final note = Note(
      id: _uuid.v4(),
      title: resolvedTitle,
      type: type ?? NoteTypeDetector.detect(content),
      content: content,
      folder: folder,
      tags: tags,
      created: now,
      modified: now,
      relativePath: await _freePath(folder, resolvedTitle),
      pinned: pinned,
      sizeBytes: utf8.encode(content).length,
    );

    return write(note);
  }

  /// Writes [note] to disk, creating parent directories as needed.
  Future<Note> write(Note note) async {
    final file = File(p.joinAll([root.path, ...p.split(note.relativePath)]));
    await file.parent.create(recursive: true);

    final payload = _serialize(note);
    // Write to a sibling temp file then rename, so a crash mid-write can
    // never leave a truncated note behind.
    final temp = File('${file.path}.tmp');
    await temp.writeAsString(payload, flush: true);
    await temp.rename(file.path);

    // Carry back the filesystem metadata we just produced so the index row
    // matches the file exactly and the next scan can skip it.
    final stat = await file.stat();
    return note.copyWith(
      sizeBytes: utf8.encode(note.content).length,
      fileModified: stat.modified,
      fileSize: stat.size,
    );
  }

  /// Updates a note's content/metadata. Renames the file when the title
  /// changed, and moves it when the folder changed.
  Future<Note> update(Note previous, Note next) async {
    var target = next.copyWith(modified: DateTime.now());

    final folderChanged = previous.folder != next.folder;
    final titleChanged = previous.title != next.title;

    if (folderChanged || titleChanged) {
      target = target.copyWith(
        relativePath: await _freePath(target.folder, target.title, keep: previous.relativePath),
      );
    }

    final saved = await write(target);
    if (saved.relativePath != previous.relativePath) {
      await _deleteAt(previous.relativePath);
    }
    return saved;
  }

  // ----------------------------------------------------------------- import

  /// Where imported binaries are copied. Dot-prefixed like the trash, so the
  /// sidebar never shows it as a folder.
  static const attachmentsDirName = '.attachments';

  /// Anything above this is copied rather than inlined, whatever it contains.
  /// A 5 MB CSV pasted into an editor would freeze the window, and the point
  /// of the app is that nothing about it stutters.
  static const inlineLimitBytes = 2 * 1024 * 1024;

  Directory get attachmentsDir =>
      Directory(p.join(root.path, attachmentsDirName));

  /// Imports [source] into the vault and returns the note that now stands for
  /// it.
  ///
  /// Flat files become ordinary notes with their text as the body, which is
  /// what makes them searchable — the whole value of importing a CSV or an
  /// XML into Jot is finding it again by its contents. Anything that is not
  /// text, or is too big to edit comfortably, is copied into the vault and
  /// referenced by the note instead.
  Future<Note> importFile(
    File source, {
    String folder = Folder.inbox,
    List<String> tags = const [],
  }) async {
    final name = p.basename(source.path);
    final title = p.basenameWithoutExtension(source.path);
    final length = await source.length();

    if (length <= inlineLimitBytes) {
      final text = await _readAsTextOrNull(source);
      if (text != null) {
        final note = await create(
          content: text,
          title: title,
          type: NoteTypeDetector.fromExtension(name) ??
              NoteTypeDetector.detect(text),
          folder: folder,
          tags: tags,
        );
        // Recorded after the fact rather than threaded through create(),
        // which every other caller would have to ignore.
        return write(note.copyWith(sourceName: name));
      }
    }

    // Prefixed with a uuid so two imports of `facture.pdf` cannot collide,
    // and so the copy is never mistaken for a file the user placed there.
    final stored = '$attachmentsDirName/${_uuid.v4()}!$name';
    if (!await attachmentsDir.exists()) {
      await attachmentsDir.create(recursive: true);
    }
    await source.copy(p.joinAll([root.path, ...p.split(stored)]));

    final now = DateTime.now();
    final note = Note(
      id: _uuid.v4(),
      title: title,
      type: NoteType.file,
      // The body is what search matches on, so it holds the words a person
      // would actually type looking for this file.
      content: '$name\n${_extensionLabel(name)}, ${_humanBytes(length)}',
      folder: folder,
      tags: tags,
      created: now,
      modified: now,
      relativePath: await _freePath(folder, title),
      attachment: stored,
      attachmentBytes: length,
      sourceName: name,
    );
    return write(note);
  }

  // ----------------------------------------------------------------- export

  /// The bytes to hand back when the user asks for this note as a file.
  ///
  /// For an imported binary that is the copy in the vault, byte for byte. For
  /// everything else it is the body as UTF-8, which is exactly what was read
  /// in at import — a note that came from a CSV gives back the same CSV,
  /// including any edits made since.
  Future<List<int>> exportBytes(Note note) async {
    final file = attachmentFile(note);
    if (file != null) {
      if (!await file.exists()) {
        throw FileSystemException('pièce jointe introuvable', file.path);
      }
      return file.readAsBytes();
    }
    return utf8.encode(note.content);
  }

  /// The file name to offer in the save dialog.
  ///
  /// The imported name wins whenever there is one: handing back `ventes_q1.md`
  /// for a file that arrived as `ventes_q1.csv` would be a small lie with real
  /// consequences at the other end. Notes written inside the app have no
  /// original name, so they get their title and an extension that matches what
  /// the body actually is.
  static String suggestedFileName(Note note) {
    final source = note.sourceName;
    if (source != null && source.trim().isNotEmpty) return source;

    final base = VaultPaths.slugify(note.title);
    return '$base${_extensionFor(note.type)}';
  }

  static String _extensionFor(NoteType type) => switch (type) {
        NoteType.json => '.json',
        // `code` covers everything from SQL to CSV here, and there is no way
        // back to which. `.txt` opens everywhere and claims nothing false.
        NoteType.code => '.txt',
        NoteType.url || NoteType.text => '.md',
        NoteType.file => '.bin',
      };

  /// Reads [file] as UTF-8, or returns null when the bytes are not text.
  ///
  /// A NUL byte is the cheap, reliable tell: no text encoding this app cares
  /// about produces one, and every binary container does within its header.
  static Future<String?> _readAsTextOrNull(File file) async {
    try {
      final bytes = await file.readAsBytes();
      if (bytes.contains(0)) return null;
      return utf8.decode(bytes);
    } on Object {
      return null;
    }
  }

  static String _extensionLabel(String name) {
    final ext = p.extension(name).replaceFirst('.', '').toUpperCase();
    return ext.isEmpty ? 'Fichier' : ext;
  }

  static String _humanBytes(int size) {
    if (size < 1024) return '$size o';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} Ko';
    return '${(size / (1024 * 1024)).toStringAsFixed(1)} Mo';
  }

  /// Deletes attachment files no note points at any more.
  ///
  /// Notes and their bytes are two files, and the trash only moves the first;
  /// this is what stops the second from accumulating forever. Run from the
  /// index rebuild, where the vault is being walked anyway.
  Future<int> purgeOrphanAttachments() async {
    if (!await attachmentsDir.exists()) return 0;

    final referenced = <String>{};
    await for (final file in noteFiles()) {
      try {
        final (frontmatter, _) = _split(await file.readAsString());
        if (frontmatter == null) continue;
        final attachment = _string(_parseYaml(frontmatter)['attachment']);
        if (attachment != null) referenced.add(p.basename(attachment));
      } on Object {
        // An unreadable note is not proof its attachment is unreferenced.
        return 0;
      }
    }

    var removed = 0;
    await for (final entity in attachmentsDir.list(followLinks: false)) {
      if (entity is! File) continue;
      if (referenced.contains(p.basename(entity.path))) continue;
      await entity.delete();
      removed++;
    }
    return removed;
  }

  /// Absolute path of a note's attachment, for opening or revealing it.
  File? attachmentFile(Note note) {
    final stored = note.attachment;
    if (stored == null) return null;
    return File(p.joinAll([root.path, ...p.split(stored)]));
  }

  /// Where deleted notes go. Dot-prefixed so [noteFiles] and [listFolders]
  /// skip it — the trash is not a folder you can browse into by accident.
  static const trashDirName = '.trash';

  Directory get trashDir => Directory(p.join(root.path, trashDirName));

  /// Moves a note to the trash instead of unlinking it.
  ///
  /// Deletion in this app is a single click with no confirmation, which is
  /// what makes it fast — the trash is what makes that safe. Files are kept
  /// under their original relative path so [restore] can put them back
  /// exactly where they were.
  Future<void> delete(Note note) async {
    final source = File(p.joinAll([root.path, ...p.split(note.relativePath)]));
    if (!await source.exists()) return;

    final stamp = DateTime.now().millisecondsSinceEpoch;
    final target = File(
      p.join(trashDir.path, '$stamp!${note.relativePath.replaceAll('/', '!')}'),
    );
    await target.parent.create(recursive: true);
    await source.rename(target.path);
  }

  /// Everything currently in the trash, newest first.
  Future<List<TrashedNote>> listTrash() async {
    if (!await trashDir.exists()) return const [];

    final entries = <TrashedNote>[];
    await for (final entity in trashDir.list(followLinks: false)) {
      if (entity is! File || p.extension(entity.path).toLowerCase() != '.md') {
        continue;
      }
      final name = p.basename(entity.path);
      final split = name.indexOf('!');
      if (split <= 0) continue;

      final stamp = int.tryParse(name.substring(0, split));
      if (stamp == null) continue;

      // Read the frontmatter title: restoring is a decision about a note, and
      // a slugified filename is not what the user called it.
      String? title;
      try {
        final (frontmatter, body) = _split(await entity.readAsString());
        final map = frontmatter == null ? const {} : _parseYaml(frontmatter);
        title = _string(map['title']) ?? _titleFromBody(body);
      } on Object {
        title = null;
      }

      entries.add(TrashedNote(
        file: entity,
        originalPath: name.substring(split + 1).replaceAll('!', '/'),
        deletedAt: DateTime.fromMillisecondsSinceEpoch(stamp),
        frontmatterTitle: title,
      ));
    }

    entries.sort((a, b) => b.deletedAt.compareTo(a.deletedAt));
    return entries;
  }

  /// Puts a trashed note back where it came from.
  Future<void> restore(TrashedNote trashed) async {
    final target = File(p.joinAll([root.path, ...p.split(trashed.originalPath)]));
    await target.parent.create(recursive: true);
    if (await target.exists()) {
      // Something already occupies the old path — keep both.
      final base = p.basenameWithoutExtension(trashed.originalPath);
      final dir = p.dirname(trashed.originalPath);
      final free = await _freePath(dir == '.' ? '' : dir, '$base-restaure');
      await trashed.file.rename(p.joinAll([root.path, ...p.split(free)]));
      return;
    }
    await trashed.file.rename(target.path);
  }

  Future<void> emptyTrash() async {
    if (!await trashDir.exists()) return;
    await for (final entity in trashDir.list(followLinks: false)) {
      if (entity is File) await entity.delete();
    }
  }

  /// Drops trashed notes older than [retentionDays]. Called at startup.
  Future<int> purgeExpiredTrash(int retentionDays) async {
    final cutoff = DateTime.now().subtract(Duration(days: retentionDays));
    var purged = 0;
    for (final trashed in await listTrash()) {
      if (trashed.deletedAt.isBefore(cutoff)) {
        await trashed.file.delete();
        purged++;
      }
    }
    return purged;
  }

  Future<void> _deleteAt(String relativePath) async {
    final file = File(p.joinAll([root.path, ...p.split(relativePath)]));
    if (await file.exists()) await file.delete();
  }

  Future<void> createFolder(String name) async {
    final dir = folderDir(name);
    if (!await dir.exists()) await dir.create(recursive: true);
  }

  // ------------------------------------------------------- (de)serialisation

  String _serialize(Note note) {
    final b = StringBuffer()
      ..writeln(_fence)
      ..writeln('id: ${_yamlString(note.id)}')
      ..writeln('title: ${_yamlString(note.title)}')
      ..writeln('type: ${note.type.id}')
      ..writeln('tags: [${note.tags.map(_yamlString).join(', ')}]')
      ..writeln('folder: ${_yamlString(note.folder)}')
      ..writeln('created: ${note.created.toIso8601String()}')
      ..writeln('modified: ${note.modified.toIso8601String()}')
      ..writeln('pinned: ${note.pinned}');

    if (note.color != null) b.writeln('color: ${_yamlString(note.color!)}');
    if (note.attachment != null) {
      b
        ..writeln('attachment: ${_yamlString(note.attachment!)}')
        ..writeln('attachment_size: ${note.attachmentBytes}');
    }
    if (note.sourceName != null) {
      b.writeln('source: ${_yamlString(note.sourceName!)}');
    }

    b
      ..writeln(_fence)
      ..write(note.content);
    return b.toString();
  }

  /// Splits `---\n<yaml>\n---\n<body>`. Returns `(null, wholeFile)` when there
  /// is no frontmatter, so plain markdown still loads.
  static (String?, String) _split(String raw) {
    final normalized = raw.replaceAll('\r\n', '\n');
    if (!normalized.startsWith('$_fence\n')) return (null, normalized);

    final end = normalized.indexOf('\n$_fence', _fence.length);
    if (end == -1) return (null, normalized);

    final yaml = normalized.substring(_fence.length + 1, end);
    var bodyStart = end + 1 + _fence.length;
    if (bodyStart < normalized.length && normalized[bodyStart] == '\n') bodyStart++;
    return (yaml, normalized.substring(bodyStart));
  }

  static Map<String, dynamic> _parseYaml(String source) {
    final doc = loadYaml(source);
    if (doc is! YamlMap) return const {};
    return {for (final entry in doc.entries) '${entry.key}': entry.value};
  }

  static String _yamlString(String value) =>
      '"${value.replaceAll(r'\', r'\\').replaceAll('"', r'\"')}"';

  static String? _string(Object? value) {
    if (value == null) return null;
    final s = '$value'.trim();
    return s.isEmpty || s == 'null' ? null : s;
  }

  static int? _int(Object? value) =>
      value is int ? value : int.tryParse('$value'.trim());

  static List<String> _stringList(Object? value) {
    if (value is YamlList) {
      return value.map((e) => '$e'.trim().replaceFirst('#', '')).where((e) => e.isNotEmpty).toList();
    }
    if (value is List) {
      return value.map((e) => '$e'.trim().replaceFirst('#', '')).where((e) => e.isNotEmpty).toList();
    }
    if (value is String) {
      return value
          .split(RegExp(r'[,\s]+'))
          .map((e) => e.trim().replaceFirst('#', ''))
          .where((e) => e.isNotEmpty)
          .toList();
    }
    return const [];
  }

  static DateTime? _dateTime(Object? value) {
    if (value is DateTime) return value;
    final s = _string(value);
    return s == null ? null : DateTime.tryParse(s);
  }

  /// "Première ligne, clé racine du JSON, ou domaine de l'URL" — the design's
  /// own description of automatic titling.
  ///
  /// The first line of a JSON blob is `{`, and the first line of a URL is the
  /// whole URL: neither makes a title anyone can scan, so both get a shape of
  /// their own before falling back to the first line.
  static String? _titleFromBody(String body) {
    final trimmedBody = body.trim();
    if (trimmedBody.isEmpty) return null;

    if (trimmedBody.startsWith('{')) {
      final key = _firstJsonKey(trimmedBody);
      if (key != null) return key;
    }

    if (!trimmedBody.contains(RegExp(r'\s'))) {
      final host = _urlHost(trimmedBody);
      if (host != null) return host;
    }

    for (final line in trimmedBody.split('\n')) {
      final line_ = line.trim().replaceFirst(RegExp(r'^#+\s*'), '');
      if (line_.isEmpty) continue;
      return line_.length <= 70 ? line_ : '${line_.substring(0, 70)}...';
    }
    return null;
  }

  static String? _firstJsonKey(String source) {
    try {
      final decoded = jsonDecode(source);
      if (decoded is Map && decoded.isNotEmpty) {
        final first = decoded.keys.first;
        // A bare key is a poor title on its own; pair it with its value when
        // the value is a short scalar.
        final value = decoded[first];
        if (value is String && value.length <= 40) return '$first: $value';
        if (value is num || value is bool) return '$first: $value';
        return '$first';
      }
    } on Object {
      // Not valid JSON after all; the caller falls through to the first line.
    }
    return null;
  }

  static String? _urlHost(String source) {
    final uri = Uri.tryParse(source.startsWith('http') ? source : 'https://$source');
    final host = uri?.host;
    if (host == null || host.isEmpty || !host.contains('.')) return null;
    final path = uri!.path.replaceAll(RegExp(r'/+$'), '');
    return path.isEmpty || path == '/' ? host : '$host$path';
  }

  /// Stable fallback id for files that have no `id:` — derived from the path
  /// so re-scanning the same file twice does not produce two index entries.
  static String _deterministicId(String relativePath) =>
      _uuid.v5(Namespace.url.value, 'jot://$relativePath');

  /// Finds an unused `<folder>/<slug>.md`, appending `-2`, `-3`... on collision.
  /// [keep] lets an update reuse its own current path.
  Future<String> _freePath(String folder, String title, {String? keep}) async {
    final slug = VaultPaths.slugify(title);
    final dir = folder == '.' || folder.isEmpty ? '' : '$folder/';

    for (var i = 1; i < 1000; i++) {
      final candidate = i == 1 ? '$dir$slug.md' : '$dir$slug-$i.md';
      if (candidate == keep) return candidate;
      final file = File(p.joinAll([root.path, ...p.split(candidate)]));
      if (!await file.exists()) return candidate;
    }
    return '$dir$slug-${DateTime.now().millisecondsSinceEpoch}.md';
  }
}
