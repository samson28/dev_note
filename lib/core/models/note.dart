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
    this.attachment,
    this.attachmentBytes = 0,
    this.sourceName,
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

  /// For an imported binary: the path of the copied file, relative to the
  /// vault root. The note itself stays a plain `.md` so a vault synced by any
  /// means keeps working; this is just a pointer beside the bytes.
  final String? attachment;
  final int attachmentBytes;

  /// Name of the file this note was imported from, kept so it can be handed
  /// back unchanged.
  ///
  /// A flat file is inlined at import — its text becomes the body, which is
  /// what makes it searchable — and with it the extension would be gone. That
  /// is fine until the user wants the file back: `ventes_q1` is not a CSV, and
  /// guessing `.txt` from the note type would hand them something their
  /// spreadsheet refuses to open.
  final String? sourceName;

  /// True when the note can be handed back as a file.
  bool get isExportable => attachment != null || content.isNotEmpty;

  /// The imported file's own name, as the user knew it.
  String? get attachmentName {
    final path = attachment;
    if (path == null) return null;
    final base = path.split('/').last;
    // Stored as `<uuid>!<original name>`, the same separator the trash uses.
    // A uuid contains no `!`, so the first one is always the boundary, even
    // when the file the user picked has one in its name.
    final mark = base.indexOf('!');
    return mark == -1 ? base : base.substring(mark + 1);
  }

  String? get attachmentExtension {
    final name = attachmentName;
    if (name == null || !name.contains('.')) return null;
    return name.split('.').last.toUpperCase();
  }

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
    String? attachment,
    int? attachmentBytes,
    String? sourceName,
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
    attachment: attachment ?? this.attachment,
    attachmentBytes: attachmentBytes ?? this.attachmentBytes,
    sourceName: sourceName ?? this.sourceName,
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
