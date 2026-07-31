import 'package:flutter/foundation.dart';

import 'note_type.dart';

/// A single note.
///
/// The file on disk is the source of truth; [Note] is the in-memory view of
/// one `.md` file (YAML frontmatter + body). [relativePath] is relative to the
/// vault root and doubles as the file's identity on disk, while [id] is the
/// stable identity used by the index and by the UI.
@immutable
class Note {
  const Note({
    required this.id,
    required this.title,
    required this.type,
    required this.content,
    required this.folder,
    required this.tags,
    required this.created,
    required this.modified,
    required this.relativePath,
    this.pinned = false,
    this.color,
    this.sizeBytes = 0,
    this.fileModified,
    this.fileSize = 0,
  });

  final String id;
  final String title;
  final NoteType type;
  final String content;

  /// Folder name, e.g. `Inbox`. Sub-folders use `/` as separator.
  final String folder;
  final List<String> tags;
  final DateTime created;
  final DateTime modified;

  /// Path relative to the vault root, e.g. `Inbox/webhook-checkout.md`.
  final String relativePath;
  final bool pinned;

  /// Optional per-note accent, stored in the frontmatter. Unused by the
  /// current screens but round-tripped so hand-edited files keep it.
  final String? color;

  /// Byte size of the body — what the status bar reports.
  final int sizeBytes;

  /// Filesystem mtime/size as last seen on disk. Only the index uses these,
  /// to skip re-parsing files that have not changed.
  final DateTime? fileModified;
  final int fileSize;

  /// The body collapsed onto a single line — this is what the note list and
  /// palette show under the title.
  ///
  /// Deliberately not "the first line": a pretty-printed JSON note's first
  /// line is `{`, which tells the reader nothing. Flattening the whole body
  /// puts the first real keys and values in front of them instead, which is
  /// what makes a result recognisable at a glance.
  String get preview {
    final collapsed = content.replaceAll(RegExp(r'\s+'), ' ').trim();
    return collapsed.length <= 220 ? collapsed : '${collapsed.substring(0, 220)}...';
  }

  int get lineCount => content.isEmpty ? 0 : content.split('\n').length;

  Note copyWith({
    String? title,
    NoteType? type,
    String? content,
    String? folder,
    List<String>? tags,
    DateTime? created,
    DateTime? modified,
    String? relativePath,
    bool? pinned,
    String? color,
    int? sizeBytes,
    DateTime? fileModified,
    int? fileSize,
  }) => Note(
    id: id,
    title: title ?? this.title,
    type: type ?? this.type,
    content: content ?? this.content,
    folder: folder ?? this.folder,
    tags: tags ?? this.tags,
    created: created ?? this.created,
    modified: modified ?? this.modified,
    relativePath: relativePath ?? this.relativePath,
    pinned: pinned ?? this.pinned,
    color: color ?? this.color,
    sizeBytes: sizeBytes ?? this.sizeBytes,
    fileModified: fileModified ?? this.fileModified,
    fileSize: fileSize ?? this.fileSize,
  );

  @override
  bool operator ==(Object other) =>
      other is Note &&
      other.id == id &&
      other.title == title &&
      other.type == type &&
      other.content == content &&
      other.folder == folder &&
      listEquals(other.tags, tags) &&
      other.modified == modified &&
      other.pinned == pinned;

  @override
  int get hashCode =>
      Object.hash(id, title, type, content, folder, modified, pinned);
}

/// A folder in the sidebar, backed by a directory under the vault root.
@immutable
class Folder {
  const Folder({required this.name, required this.noteCount, this.muted = false});

  final String name;
  final int noteCount;

  /// `Archive` is rendered dimmer than the rest in the design.
  final bool muted;

  static const inbox = 'Inbox';
  static const archive = 'Archive';
}

/// A tag, derived from the union of every note's `tags:` frontmatter list.
@immutable
class Tag {
  const Tag({required this.name, required this.noteCount});

  final String name;
  final int noteCount;
}
