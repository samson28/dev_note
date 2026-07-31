// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $NoteRowsTable extends NoteRows with TableInfo<$NoteRowsTable, NoteRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $NoteRowsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _folderMeta = const VerificationMeta('folder');
  @override
  late final GeneratedColumn<String> folder = GeneratedColumn<String>(
    'folder',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tagsMeta = const VerificationMeta('tags');
  @override
  late final GeneratedColumn<String> tags = GeneratedColumn<String>(
    'tags',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _previewMeta = const VerificationMeta(
    'preview',
  );
  @override
  late final GeneratedColumn<String> preview = GeneratedColumn<String>(
    'preview',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _relativePathMeta = const VerificationMeta(
    'relativePath',
  );
  @override
  late final GeneratedColumn<String> relativePath = GeneratedColumn<String>(
    'relative_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdMeta = const VerificationMeta(
    'created',
  );
  @override
  late final GeneratedColumn<DateTime> created = GeneratedColumn<DateTime>(
    'created',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _modifiedMeta = const VerificationMeta(
    'modified',
  );
  @override
  late final GeneratedColumn<DateTime> modified = GeneratedColumn<DateTime>(
    'modified',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _pinnedMeta = const VerificationMeta('pinned');
  @override
  late final GeneratedColumn<bool> pinned = GeneratedColumn<bool>(
    'pinned',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("pinned" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _colorMeta = const VerificationMeta('color');
  @override
  late final GeneratedColumn<String> color = GeneratedColumn<String>(
    'color',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sizeBytesMeta = const VerificationMeta(
    'sizeBytes',
  );
  @override
  late final GeneratedColumn<int> sizeBytes = GeneratedColumn<int>(
    'size_bytes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lineCountMeta = const VerificationMeta(
    'lineCount',
  );
  @override
  late final GeneratedColumn<int> lineCount = GeneratedColumn<int>(
    'line_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _fileModifiedMeta = const VerificationMeta(
    'fileModified',
  );
  @override
  late final GeneratedColumn<DateTime> fileModified = GeneratedColumn<DateTime>(
    'file_modified',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: Constant(DateTime.fromMillisecondsSinceEpoch(0)),
  );
  static const VerificationMeta _fileSizeMeta = const VerificationMeta(
    'fileSize',
  );
  @override
  late final GeneratedColumn<int> fileSize = GeneratedColumn<int>(
    'file_size',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    title,
    type,
    folder,
    tags,
    preview,
    relativePath,
    created,
    modified,
    pinned,
    color,
    sizeBytes,
    lineCount,
    fileModified,
    fileSize,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'note_rows';
  @override
  VerificationContext validateIntegrity(
    Insertable<NoteRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('folder')) {
      context.handle(
        _folderMeta,
        folder.isAcceptableOrUnknown(data['folder']!, _folderMeta),
      );
    } else if (isInserting) {
      context.missing(_folderMeta);
    }
    if (data.containsKey('tags')) {
      context.handle(
        _tagsMeta,
        tags.isAcceptableOrUnknown(data['tags']!, _tagsMeta),
      );
    }
    if (data.containsKey('preview')) {
      context.handle(
        _previewMeta,
        preview.isAcceptableOrUnknown(data['preview']!, _previewMeta),
      );
    }
    if (data.containsKey('relative_path')) {
      context.handle(
        _relativePathMeta,
        relativePath.isAcceptableOrUnknown(
          data['relative_path']!,
          _relativePathMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_relativePathMeta);
    }
    if (data.containsKey('created')) {
      context.handle(
        _createdMeta,
        created.isAcceptableOrUnknown(data['created']!, _createdMeta),
      );
    } else if (isInserting) {
      context.missing(_createdMeta);
    }
    if (data.containsKey('modified')) {
      context.handle(
        _modifiedMeta,
        modified.isAcceptableOrUnknown(data['modified']!, _modifiedMeta),
      );
    } else if (isInserting) {
      context.missing(_modifiedMeta);
    }
    if (data.containsKey('pinned')) {
      context.handle(
        _pinnedMeta,
        pinned.isAcceptableOrUnknown(data['pinned']!, _pinnedMeta),
      );
    }
    if (data.containsKey('color')) {
      context.handle(
        _colorMeta,
        color.isAcceptableOrUnknown(data['color']!, _colorMeta),
      );
    }
    if (data.containsKey('size_bytes')) {
      context.handle(
        _sizeBytesMeta,
        sizeBytes.isAcceptableOrUnknown(data['size_bytes']!, _sizeBytesMeta),
      );
    }
    if (data.containsKey('line_count')) {
      context.handle(
        _lineCountMeta,
        lineCount.isAcceptableOrUnknown(data['line_count']!, _lineCountMeta),
      );
    }
    if (data.containsKey('file_modified')) {
      context.handle(
        _fileModifiedMeta,
        fileModified.isAcceptableOrUnknown(
          data['file_modified']!,
          _fileModifiedMeta,
        ),
      );
    }
    if (data.containsKey('file_size')) {
      context.handle(
        _fileSizeMeta,
        fileSize.isAcceptableOrUnknown(data['file_size']!, _fileSizeMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  NoteRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return NoteRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      folder: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}folder'],
      )!,
      tags: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tags'],
      )!,
      preview: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}preview'],
      )!,
      relativePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}relative_path'],
      )!,
      created: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created'],
      )!,
      modified: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}modified'],
      )!,
      pinned: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}pinned'],
      )!,
      color: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}color'],
      ),
      sizeBytes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}size_bytes'],
      )!,
      lineCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}line_count'],
      )!,
      fileModified: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}file_modified'],
      )!,
      fileSize: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}file_size'],
      )!,
    );
  }

  @override
  $NoteRowsTable createAlias(String alias) {
    return $NoteRowsTable(attachedDatabase, alias);
  }
}

class NoteRow extends DataClass implements Insertable<NoteRow> {
  final String id;
  final String title;
  final String type;
  final String folder;

  /// Space-separated, `#`-free, lowercased — cheap to `LIKE` against.
  final String tags;
  final String preview;
  final String relativePath;
  final DateTime created;
  final DateTime modified;
  final bool pinned;
  final String? color;

  /// Size of the note *body*, which is what the status bar reports.
  final int sizeBytes;
  final int lineCount;

  /// Filesystem mtime and byte size at the time this row was written. These
  /// are what [IndexRepository.synchronise] compares against, so an unchanged
  /// vault costs one `stat` per file and no parsing at all.
  final DateTime fileModified;
  final int fileSize;
  const NoteRow({
    required this.id,
    required this.title,
    required this.type,
    required this.folder,
    required this.tags,
    required this.preview,
    required this.relativePath,
    required this.created,
    required this.modified,
    required this.pinned,
    this.color,
    required this.sizeBytes,
    required this.lineCount,
    required this.fileModified,
    required this.fileSize,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['title'] = Variable<String>(title);
    map['type'] = Variable<String>(type);
    map['folder'] = Variable<String>(folder);
    map['tags'] = Variable<String>(tags);
    map['preview'] = Variable<String>(preview);
    map['relative_path'] = Variable<String>(relativePath);
    map['created'] = Variable<DateTime>(created);
    map['modified'] = Variable<DateTime>(modified);
    map['pinned'] = Variable<bool>(pinned);
    if (!nullToAbsent || color != null) {
      map['color'] = Variable<String>(color);
    }
    map['size_bytes'] = Variable<int>(sizeBytes);
    map['line_count'] = Variable<int>(lineCount);
    map['file_modified'] = Variable<DateTime>(fileModified);
    map['file_size'] = Variable<int>(fileSize);
    return map;
  }

  NoteRowsCompanion toCompanion(bool nullToAbsent) {
    return NoteRowsCompanion(
      id: Value(id),
      title: Value(title),
      type: Value(type),
      folder: Value(folder),
      tags: Value(tags),
      preview: Value(preview),
      relativePath: Value(relativePath),
      created: Value(created),
      modified: Value(modified),
      pinned: Value(pinned),
      color: color == null && nullToAbsent
          ? const Value.absent()
          : Value(color),
      sizeBytes: Value(sizeBytes),
      lineCount: Value(lineCount),
      fileModified: Value(fileModified),
      fileSize: Value(fileSize),
    );
  }

  factory NoteRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return NoteRow(
      id: serializer.fromJson<String>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      type: serializer.fromJson<String>(json['type']),
      folder: serializer.fromJson<String>(json['folder']),
      tags: serializer.fromJson<String>(json['tags']),
      preview: serializer.fromJson<String>(json['preview']),
      relativePath: serializer.fromJson<String>(json['relativePath']),
      created: serializer.fromJson<DateTime>(json['created']),
      modified: serializer.fromJson<DateTime>(json['modified']),
      pinned: serializer.fromJson<bool>(json['pinned']),
      color: serializer.fromJson<String?>(json['color']),
      sizeBytes: serializer.fromJson<int>(json['sizeBytes']),
      lineCount: serializer.fromJson<int>(json['lineCount']),
      fileModified: serializer.fromJson<DateTime>(json['fileModified']),
      fileSize: serializer.fromJson<int>(json['fileSize']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'title': serializer.toJson<String>(title),
      'type': serializer.toJson<String>(type),
      'folder': serializer.toJson<String>(folder),
      'tags': serializer.toJson<String>(tags),
      'preview': serializer.toJson<String>(preview),
      'relativePath': serializer.toJson<String>(relativePath),
      'created': serializer.toJson<DateTime>(created),
      'modified': serializer.toJson<DateTime>(modified),
      'pinned': serializer.toJson<bool>(pinned),
      'color': serializer.toJson<String?>(color),
      'sizeBytes': serializer.toJson<int>(sizeBytes),
      'lineCount': serializer.toJson<int>(lineCount),
      'fileModified': serializer.toJson<DateTime>(fileModified),
      'fileSize': serializer.toJson<int>(fileSize),
    };
  }

  NoteRow copyWith({
    String? id,
    String? title,
    String? type,
    String? folder,
    String? tags,
    String? preview,
    String? relativePath,
    DateTime? created,
    DateTime? modified,
    bool? pinned,
    Value<String?> color = const Value.absent(),
    int? sizeBytes,
    int? lineCount,
    DateTime? fileModified,
    int? fileSize,
  }) => NoteRow(
    id: id ?? this.id,
    title: title ?? this.title,
    type: type ?? this.type,
    folder: folder ?? this.folder,
    tags: tags ?? this.tags,
    preview: preview ?? this.preview,
    relativePath: relativePath ?? this.relativePath,
    created: created ?? this.created,
    modified: modified ?? this.modified,
    pinned: pinned ?? this.pinned,
    color: color.present ? color.value : this.color,
    sizeBytes: sizeBytes ?? this.sizeBytes,
    lineCount: lineCount ?? this.lineCount,
    fileModified: fileModified ?? this.fileModified,
    fileSize: fileSize ?? this.fileSize,
  );
  NoteRow copyWithCompanion(NoteRowsCompanion data) {
    return NoteRow(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      type: data.type.present ? data.type.value : this.type,
      folder: data.folder.present ? data.folder.value : this.folder,
      tags: data.tags.present ? data.tags.value : this.tags,
      preview: data.preview.present ? data.preview.value : this.preview,
      relativePath: data.relativePath.present
          ? data.relativePath.value
          : this.relativePath,
      created: data.created.present ? data.created.value : this.created,
      modified: data.modified.present ? data.modified.value : this.modified,
      pinned: data.pinned.present ? data.pinned.value : this.pinned,
      color: data.color.present ? data.color.value : this.color,
      sizeBytes: data.sizeBytes.present ? data.sizeBytes.value : this.sizeBytes,
      lineCount: data.lineCount.present ? data.lineCount.value : this.lineCount,
      fileModified: data.fileModified.present
          ? data.fileModified.value
          : this.fileModified,
      fileSize: data.fileSize.present ? data.fileSize.value : this.fileSize,
    );
  }

  @override
  String toString() {
    return (StringBuffer('NoteRow(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('type: $type, ')
          ..write('folder: $folder, ')
          ..write('tags: $tags, ')
          ..write('preview: $preview, ')
          ..write('relativePath: $relativePath, ')
          ..write('created: $created, ')
          ..write('modified: $modified, ')
          ..write('pinned: $pinned, ')
          ..write('color: $color, ')
          ..write('sizeBytes: $sizeBytes, ')
          ..write('lineCount: $lineCount, ')
          ..write('fileModified: $fileModified, ')
          ..write('fileSize: $fileSize')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    title,
    type,
    folder,
    tags,
    preview,
    relativePath,
    created,
    modified,
    pinned,
    color,
    sizeBytes,
    lineCount,
    fileModified,
    fileSize,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is NoteRow &&
          other.id == this.id &&
          other.title == this.title &&
          other.type == this.type &&
          other.folder == this.folder &&
          other.tags == this.tags &&
          other.preview == this.preview &&
          other.relativePath == this.relativePath &&
          other.created == this.created &&
          other.modified == this.modified &&
          other.pinned == this.pinned &&
          other.color == this.color &&
          other.sizeBytes == this.sizeBytes &&
          other.lineCount == this.lineCount &&
          other.fileModified == this.fileModified &&
          other.fileSize == this.fileSize);
}

class NoteRowsCompanion extends UpdateCompanion<NoteRow> {
  final Value<String> id;
  final Value<String> title;
  final Value<String> type;
  final Value<String> folder;
  final Value<String> tags;
  final Value<String> preview;
  final Value<String> relativePath;
  final Value<DateTime> created;
  final Value<DateTime> modified;
  final Value<bool> pinned;
  final Value<String?> color;
  final Value<int> sizeBytes;
  final Value<int> lineCount;
  final Value<DateTime> fileModified;
  final Value<int> fileSize;
  final Value<int> rowid;
  const NoteRowsCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.type = const Value.absent(),
    this.folder = const Value.absent(),
    this.tags = const Value.absent(),
    this.preview = const Value.absent(),
    this.relativePath = const Value.absent(),
    this.created = const Value.absent(),
    this.modified = const Value.absent(),
    this.pinned = const Value.absent(),
    this.color = const Value.absent(),
    this.sizeBytes = const Value.absent(),
    this.lineCount = const Value.absent(),
    this.fileModified = const Value.absent(),
    this.fileSize = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  NoteRowsCompanion.insert({
    required String id,
    required String title,
    required String type,
    required String folder,
    this.tags = const Value.absent(),
    this.preview = const Value.absent(),
    required String relativePath,
    required DateTime created,
    required DateTime modified,
    this.pinned = const Value.absent(),
    this.color = const Value.absent(),
    this.sizeBytes = const Value.absent(),
    this.lineCount = const Value.absent(),
    this.fileModified = const Value.absent(),
    this.fileSize = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       title = Value(title),
       type = Value(type),
       folder = Value(folder),
       relativePath = Value(relativePath),
       created = Value(created),
       modified = Value(modified);
  static Insertable<NoteRow> custom({
    Expression<String>? id,
    Expression<String>? title,
    Expression<String>? type,
    Expression<String>? folder,
    Expression<String>? tags,
    Expression<String>? preview,
    Expression<String>? relativePath,
    Expression<DateTime>? created,
    Expression<DateTime>? modified,
    Expression<bool>? pinned,
    Expression<String>? color,
    Expression<int>? sizeBytes,
    Expression<int>? lineCount,
    Expression<DateTime>? fileModified,
    Expression<int>? fileSize,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (type != null) 'type': type,
      if (folder != null) 'folder': folder,
      if (tags != null) 'tags': tags,
      if (preview != null) 'preview': preview,
      if (relativePath != null) 'relative_path': relativePath,
      if (created != null) 'created': created,
      if (modified != null) 'modified': modified,
      if (pinned != null) 'pinned': pinned,
      if (color != null) 'color': color,
      if (sizeBytes != null) 'size_bytes': sizeBytes,
      if (lineCount != null) 'line_count': lineCount,
      if (fileModified != null) 'file_modified': fileModified,
      if (fileSize != null) 'file_size': fileSize,
      if (rowid != null) 'rowid': rowid,
    });
  }

  NoteRowsCompanion copyWith({
    Value<String>? id,
    Value<String>? title,
    Value<String>? type,
    Value<String>? folder,
    Value<String>? tags,
    Value<String>? preview,
    Value<String>? relativePath,
    Value<DateTime>? created,
    Value<DateTime>? modified,
    Value<bool>? pinned,
    Value<String?>? color,
    Value<int>? sizeBytes,
    Value<int>? lineCount,
    Value<DateTime>? fileModified,
    Value<int>? fileSize,
    Value<int>? rowid,
  }) {
    return NoteRowsCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      type: type ?? this.type,
      folder: folder ?? this.folder,
      tags: tags ?? this.tags,
      preview: preview ?? this.preview,
      relativePath: relativePath ?? this.relativePath,
      created: created ?? this.created,
      modified: modified ?? this.modified,
      pinned: pinned ?? this.pinned,
      color: color ?? this.color,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      lineCount: lineCount ?? this.lineCount,
      fileModified: fileModified ?? this.fileModified,
      fileSize: fileSize ?? this.fileSize,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (folder.present) {
      map['folder'] = Variable<String>(folder.value);
    }
    if (tags.present) {
      map['tags'] = Variable<String>(tags.value);
    }
    if (preview.present) {
      map['preview'] = Variable<String>(preview.value);
    }
    if (relativePath.present) {
      map['relative_path'] = Variable<String>(relativePath.value);
    }
    if (created.present) {
      map['created'] = Variable<DateTime>(created.value);
    }
    if (modified.present) {
      map['modified'] = Variable<DateTime>(modified.value);
    }
    if (pinned.present) {
      map['pinned'] = Variable<bool>(pinned.value);
    }
    if (color.present) {
      map['color'] = Variable<String>(color.value);
    }
    if (sizeBytes.present) {
      map['size_bytes'] = Variable<int>(sizeBytes.value);
    }
    if (lineCount.present) {
      map['line_count'] = Variable<int>(lineCount.value);
    }
    if (fileModified.present) {
      map['file_modified'] = Variable<DateTime>(fileModified.value);
    }
    if (fileSize.present) {
      map['file_size'] = Variable<int>(fileSize.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('NoteRowsCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('type: $type, ')
          ..write('folder: $folder, ')
          ..write('tags: $tags, ')
          ..write('preview: $preview, ')
          ..write('relativePath: $relativePath, ')
          ..write('created: $created, ')
          ..write('modified: $modified, ')
          ..write('pinned: $pinned, ')
          ..write('color: $color, ')
          ..write('sizeBytes: $sizeBytes, ')
          ..write('lineCount: $lineCount, ')
          ..write('fileModified: $fileModified, ')
          ..write('fileSize: $fileSize, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$JotDatabase extends GeneratedDatabase {
  _$JotDatabase(QueryExecutor e) : super(e);
  $JotDatabaseManager get managers => $JotDatabaseManager(this);
  late final $NoteRowsTable noteRows = $NoteRowsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [noteRows];
}

typedef $$NoteRowsTableCreateCompanionBuilder =
    NoteRowsCompanion Function({
      required String id,
      required String title,
      required String type,
      required String folder,
      Value<String> tags,
      Value<String> preview,
      required String relativePath,
      required DateTime created,
      required DateTime modified,
      Value<bool> pinned,
      Value<String?> color,
      Value<int> sizeBytes,
      Value<int> lineCount,
      Value<DateTime> fileModified,
      Value<int> fileSize,
      Value<int> rowid,
    });
typedef $$NoteRowsTableUpdateCompanionBuilder =
    NoteRowsCompanion Function({
      Value<String> id,
      Value<String> title,
      Value<String> type,
      Value<String> folder,
      Value<String> tags,
      Value<String> preview,
      Value<String> relativePath,
      Value<DateTime> created,
      Value<DateTime> modified,
      Value<bool> pinned,
      Value<String?> color,
      Value<int> sizeBytes,
      Value<int> lineCount,
      Value<DateTime> fileModified,
      Value<int> fileSize,
      Value<int> rowid,
    });

class $$NoteRowsTableFilterComposer
    extends Composer<_$JotDatabase, $NoteRowsTable> {
  $$NoteRowsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get folder => $composableBuilder(
    column: $table.folder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tags => $composableBuilder(
    column: $table.tags,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get preview => $composableBuilder(
    column: $table.preview,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get relativePath => $composableBuilder(
    column: $table.relativePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get created => $composableBuilder(
    column: $table.created,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get modified => $composableBuilder(
    column: $table.modified,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get pinned => $composableBuilder(
    column: $table.pinned,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get color => $composableBuilder(
    column: $table.color,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sizeBytes => $composableBuilder(
    column: $table.sizeBytes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lineCount => $composableBuilder(
    column: $table.lineCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get fileModified => $composableBuilder(
    column: $table.fileModified,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get fileSize => $composableBuilder(
    column: $table.fileSize,
    builder: (column) => ColumnFilters(column),
  );
}

class $$NoteRowsTableOrderingComposer
    extends Composer<_$JotDatabase, $NoteRowsTable> {
  $$NoteRowsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get folder => $composableBuilder(
    column: $table.folder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tags => $composableBuilder(
    column: $table.tags,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get preview => $composableBuilder(
    column: $table.preview,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get relativePath => $composableBuilder(
    column: $table.relativePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get created => $composableBuilder(
    column: $table.created,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get modified => $composableBuilder(
    column: $table.modified,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get pinned => $composableBuilder(
    column: $table.pinned,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get color => $composableBuilder(
    column: $table.color,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sizeBytes => $composableBuilder(
    column: $table.sizeBytes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lineCount => $composableBuilder(
    column: $table.lineCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get fileModified => $composableBuilder(
    column: $table.fileModified,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get fileSize => $composableBuilder(
    column: $table.fileSize,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$NoteRowsTableAnnotationComposer
    extends Composer<_$JotDatabase, $NoteRowsTable> {
  $$NoteRowsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get folder =>
      $composableBuilder(column: $table.folder, builder: (column) => column);

  GeneratedColumn<String> get tags =>
      $composableBuilder(column: $table.tags, builder: (column) => column);

  GeneratedColumn<String> get preview =>
      $composableBuilder(column: $table.preview, builder: (column) => column);

  GeneratedColumn<String> get relativePath => $composableBuilder(
    column: $table.relativePath,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get created =>
      $composableBuilder(column: $table.created, builder: (column) => column);

  GeneratedColumn<DateTime> get modified =>
      $composableBuilder(column: $table.modified, builder: (column) => column);

  GeneratedColumn<bool> get pinned =>
      $composableBuilder(column: $table.pinned, builder: (column) => column);

  GeneratedColumn<String> get color =>
      $composableBuilder(column: $table.color, builder: (column) => column);

  GeneratedColumn<int> get sizeBytes =>
      $composableBuilder(column: $table.sizeBytes, builder: (column) => column);

  GeneratedColumn<int> get lineCount =>
      $composableBuilder(column: $table.lineCount, builder: (column) => column);

  GeneratedColumn<DateTime> get fileModified => $composableBuilder(
    column: $table.fileModified,
    builder: (column) => column,
  );

  GeneratedColumn<int> get fileSize =>
      $composableBuilder(column: $table.fileSize, builder: (column) => column);
}

class $$NoteRowsTableTableManager
    extends
        RootTableManager<
          _$JotDatabase,
          $NoteRowsTable,
          NoteRow,
          $$NoteRowsTableFilterComposer,
          $$NoteRowsTableOrderingComposer,
          $$NoteRowsTableAnnotationComposer,
          $$NoteRowsTableCreateCompanionBuilder,
          $$NoteRowsTableUpdateCompanionBuilder,
          (NoteRow, BaseReferences<_$JotDatabase, $NoteRowsTable, NoteRow>),
          NoteRow,
          PrefetchHooks Function()
        > {
  $$NoteRowsTableTableManager(_$JotDatabase db, $NoteRowsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$NoteRowsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$NoteRowsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$NoteRowsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<String> folder = const Value.absent(),
                Value<String> tags = const Value.absent(),
                Value<String> preview = const Value.absent(),
                Value<String> relativePath = const Value.absent(),
                Value<DateTime> created = const Value.absent(),
                Value<DateTime> modified = const Value.absent(),
                Value<bool> pinned = const Value.absent(),
                Value<String?> color = const Value.absent(),
                Value<int> sizeBytes = const Value.absent(),
                Value<int> lineCount = const Value.absent(),
                Value<DateTime> fileModified = const Value.absent(),
                Value<int> fileSize = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => NoteRowsCompanion(
                id: id,
                title: title,
                type: type,
                folder: folder,
                tags: tags,
                preview: preview,
                relativePath: relativePath,
                created: created,
                modified: modified,
                pinned: pinned,
                color: color,
                sizeBytes: sizeBytes,
                lineCount: lineCount,
                fileModified: fileModified,
                fileSize: fileSize,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String title,
                required String type,
                required String folder,
                Value<String> tags = const Value.absent(),
                Value<String> preview = const Value.absent(),
                required String relativePath,
                required DateTime created,
                required DateTime modified,
                Value<bool> pinned = const Value.absent(),
                Value<String?> color = const Value.absent(),
                Value<int> sizeBytes = const Value.absent(),
                Value<int> lineCount = const Value.absent(),
                Value<DateTime> fileModified = const Value.absent(),
                Value<int> fileSize = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => NoteRowsCompanion.insert(
                id: id,
                title: title,
                type: type,
                folder: folder,
                tags: tags,
                preview: preview,
                relativePath: relativePath,
                created: created,
                modified: modified,
                pinned: pinned,
                color: color,
                sizeBytes: sizeBytes,
                lineCount: lineCount,
                fileModified: fileModified,
                fileSize: fileSize,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$NoteRowsTableProcessedTableManager =
    ProcessedTableManager<
      _$JotDatabase,
      $NoteRowsTable,
      NoteRow,
      $$NoteRowsTableFilterComposer,
      $$NoteRowsTableOrderingComposer,
      $$NoteRowsTableAnnotationComposer,
      $$NoteRowsTableCreateCompanionBuilder,
      $$NoteRowsTableUpdateCompanionBuilder,
      (NoteRow, BaseReferences<_$JotDatabase, $NoteRowsTable, NoteRow>),
      NoteRow,
      PrefetchHooks Function()
    >;

class $JotDatabaseManager {
  final _$JotDatabase _db;
  $JotDatabaseManager(this._db);
  $$NoteRowsTableTableManager get noteRows =>
      $$NoteRowsTableTableManager(_db, _db.noteRows);
}
