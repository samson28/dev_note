import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dev_note/core/content_limits.dart';
import 'package:dev_note/core/models/note.dart';
import 'package:dev_note/core/models/note_type.dart';
import 'package:dev_note/data/database.dart';
import 'package:dev_note/data/file_repository.dart';
import 'package:dev_note/data/index_repository.dart';

Note _note(String content) => Note(
      id: 'n',
      title: 't',
      type: NoteType.json,
      content: content,
      folder: Folder.inbox,
      tags: const [],
      created: DateTime(2026),
      modified: DateTime(2026),
      relativePath: 'Inbox/n.md',
    );

void main() {
  late Directory tempDir;
  late JotDatabase db;
  late IndexRepository index;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('index_repository_test_');
    db = JotDatabase.memory();
    index = IndexRepository(db, FileRepository(tempDir));
  });

  tearDown(() async {
    await db.close();
    tempDir.deleteSync(recursive: true);
  });

  group('IndexRepository FTS body cap', () {
    test('ordinary content is stored in full', () async {
      const content = '{"hello": "world"}';
      await index.upsert(_note(content));

      final row = await db
          .customSelect('SELECT content FROM notes_fts WHERE note_id = ?',
              variables: [Variable<String>('n')])
          .getSingle();
      expect(row.read<String>('content'), content);
    });

    test('a body past ContentLimits.large is truncated before indexing',
        () async {
      final content = 'x' * (ContentLimits.large + 50000);
      await index.upsert(_note(content));

      final row = await db
          .customSelect('SELECT content FROM notes_fts WHERE note_id = ?',
              variables: [Variable<String>('n')])
          .getSingle();
      // The row must never grow past the cap, regardless of how far past it
      // the note's real body goes: this is what keeps re-indexing on every
      // autosave bounded, rather than scaling with the note's own size.
      expect(row.read<String>('content').length, ContentLimits.large);
    });

    test('re-upserting a shrunk note does not leave the old, larger row',
        () async {
      await index.upsert(_note('x' * (ContentLimits.large + 50000)));
      await index.upsert(_note('short now'));

      final row = await db
          .customSelect('SELECT content FROM notes_fts WHERE note_id = ?',
              variables: [Variable<String>('n')])
          .getSingle();
      expect(row.read<String>('content'), 'short now');
    });
  });
}
