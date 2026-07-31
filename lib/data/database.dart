import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';

part 'database.g.dart';

/// Mirror of the note metadata needed to render a list row without touching
/// the disk. The body itself lives only in the FTS table (and, of course, in
/// the file), the list never needs it.
class NoteRows extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get type => text()();
  TextColumn get folder => text()();

  /// Space-separated, `#`-free, lowercased, cheap to `LIKE` against.
  TextColumn get tags => text().withDefault(const Constant(''))();
  TextColumn get preview => text().withDefault(const Constant(''))();
  TextColumn get relativePath => text()();
  DateTimeColumn get created => dateTime()();
  DateTimeColumn get modified => dateTime()();
  BoolColumn get pinned => boolean().withDefault(const Constant(false))();
  TextColumn get color => text().nullable()();

  /// Size of the note *body*, which is what the status bar reports.
  IntColumn get sizeBytes => integer().withDefault(const Constant(0))();
  IntColumn get lineCount => integer().withDefault(const Constant(0))();

  /// Filesystem mtime and byte size at the time this row was written. These
  /// are what [IndexRepository.synchronise] compares against, so an unchanged
  /// vault costs one `stat` per file and no parsing at all.
  DateTimeColumn get fileModified =>
      dateTime().withDefault(Constant(DateTime.fromMillisecondsSinceEpoch(0)))();
  IntColumn get fileSize => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [NoteRows])
class JotDatabase extends _$JotDatabase {
  JotDatabase(super.e);

  JotDatabase.atFile(File file)
      : super(NativeDatabase.createInBackground(file, logStatements: false));

  /// In-memory instance used by tests.
  JotDatabase.memory() : super(NativeDatabase.memory());

  @override
  int get schemaVersion => 2;

  /// FTS5 is created with raw SQL because drift models it as an external
  /// virtual table. `note_id` is UNINDEXED, it is a join key, not something
  /// anyone searches for.
  static const _createFts = '''
CREATE VIRTUAL TABLE IF NOT EXISTS notes_fts USING fts5(
  note_id UNINDEXED,
  title,
  content,
  tags,
  tokenize = "unicode61 remove_diacritics 2"
)''';

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await customStatement(_createFts);
          await _createIndexes();
        },
        // Every row here is derived from a file in the vault, so there is
        // nothing to migrate: throw the index away and let IndexRepository
        // refill it. A rebuild over a few hundred notes costs milliseconds,
        // and it can never leave the schema half-upgraded.
        onUpgrade: (m, from, to) async {
          await customStatement('DROP TABLE IF EXISTS notes_fts');
          for (final table in allTables) {
            await m.deleteTable(table.actualTableName);
          }
          await m.createAll();
          await customStatement(_createFts);
          await _createIndexes();
        },
        beforeOpen: (details) async {
          // The index is a disposable cache. If the FTS table is missing or
          // unreadable, hand-deleted, half-written, corrupted, recreate the
          // shell here and let IndexRepository refill it from the vault.
          if (!await _ftsIsHealthy()) {
            await customStatement('DROP TABLE IF EXISTS notes_fts');
            await customStatement(_createFts);
          }
          await _createIndexes();
        },
      );

  Future<void> _createIndexes() async {
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_note_rows_folder ON note_rows (folder)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_note_rows_modified ON note_rows (modified DESC)',
    );
    await customStatement(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_note_rows_path ON note_rows (relative_path)',
    );
  }

  Future<bool> _ftsIsHealthy() async {
    try {
      await customSelect('SELECT count(*) FROM notes_fts').get();
      return true;
    } on Object {
      return false;
    }
  }
}
