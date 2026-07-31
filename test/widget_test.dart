import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:jot/core/models/note.dart';
import 'package:jot/core/models/note_type.dart';
import 'package:jot/data/file_repository.dart';

void main() {
  group('NoteTypeDetector', () {
    test('valid JSON is json', () {
      expect(NoteTypeDetector.detect('{"a": 1}'), NoteType.json);
      expect(NoteTypeDetector.detect('[1, 2, 3]'), NoteType.json);
    });

    test('JSON-shaped but invalid falls back rather than lying', () {
      expect(NoteTypeDetector.detect('{ "a": }'), isNot(NoteType.json));
    });

    test('a bare URL is url, a URL inside prose is not', () {
      expect(NoteTypeDetector.detect('https://example.com/a?b=c'), NoteType.url);
      expect(NoteTypeDetector.detect('grafana.enko.internal/d/9fbz1'), NoteType.url);
      expect(
        NoteTypeDetector.detect('voir https://example.com pour la suite'),
        NoteType.text,
      );
    });

    test('code signals win over prose', () {
      expect(
        NoteTypeDetector.detect('ALTER TABLE invoices ADD COLUMN settled_at TIMESTAMPTZ;'),
        NoteType.code,
      );
      expect(
        NoteTypeDetector.detect('final x = ref.watch(provider);'),
        NoteType.code,
      );
    });

    test('plain prose stays text', () {
      expect(
        NoteTypeDetector.detect(
          "Le tri par date casse quand le fuseau est UTC+13. Vérifier l'export CSV.",
        ),
        NoteType.text,
      );
    });

    test('empty input is text', () {
      expect(NoteTypeDetector.detect('   '), NoteType.text);
    });
  });

  group('FileRepository', () {
    late Directory root;
    late FileRepository files;

    setUp(() async {
      root = await Directory.systemTemp.createTemp('jot_test_');
      files = FileRepository(root);
      await files.ensureScaffold();
    });

    tearDown(() async {
      if (await root.exists()) await root.delete(recursive: true);
    });

    test('round-trips frontmatter through disk', () async {
      final created = await files.create(
        content: '{"id": "evt_1"}',
        title: 'webhook checkout.session',
        folder: Folder.inbox,
        tags: const ['api', 'stripe'],
        pinned: true,
      );

      final file = File('${root.path}/${created.relativePath}');
      expect(await file.exists(), isTrue);

      final read = await files.read(file);
      expect(read.id, created.id);
      expect(read.title, 'webhook checkout.session');
      expect(read.type, NoteType.json);
      expect(read.tags, ['api', 'stripe']);
      expect(read.folder, Folder.inbox);
      expect(read.pinned, isTrue);
      expect(read.content, '{"id": "evt_1"}');
    });

    test('reads a plain .md with no frontmatter', () async {
      final file = File('${root.path}/Inbox/manuel.md');
      await file.writeAsString('# Titre écrit à la main\n\ndu contenu');

      final note = await files.read(file);
      expect(note.title, 'Titre écrit à la main');
      expect(note.folder, Folder.inbox);
      expect(note.type, NoteType.text);
      expect(note.id, isNotEmpty);
    });

    test('a title collision does not overwrite the first note', () async {
      final a = await files.create(content: 'un', title: 'même titre');
      final b = await files.create(content: 'deux', title: 'même titre');

      expect(a.relativePath, isNot(b.relativePath));
      expect((await files.readAll()).length, 2);
    });

    test('renaming moves the file and leaves nothing behind', () async {
      final note = await files.create(content: 'x', title: 'avant');
      final old = File('${root.path}/${note.relativePath}');

      final renamed = await files.update(note, note.copyWith(title: 'après'));

      expect(await old.exists(), isFalse);
      expect(await File('${root.path}/${renamed.relativePath}').exists(), isTrue);
      expect(renamed.title, 'après');
    });

    test('an unreadable file is skipped, not fatal', () async {
      await files.create(content: 'bon', title: 'lisible');
      await File('${root.path}/Inbox/casse.md')
          .writeAsString('---\n: : : pas du yaml\n---\ncorps');

      final notes = await files.readAll();
      // The broken file either parses loosely or is skipped — either way the
      // good note must still come back.
      expect(notes.map((n) => n.title), contains('lisible'));
    });

    group('automatic title', () {
      test('a JSON blob is titled by its root key, not by "{"', () async {
        final note = await files.create(
          content: '{\n  "type": "checkout.session.completed",\n  "id": 4900\n}',
        );
        expect(note.title, 'type: checkout.session.completed');
      });

      test('a bare URL is titled by its host and path', () async {
        final note = await files.create(
          content: 'https://grafana.enko.internal/d/9fbz1/api-latency',
        );
        expect(note.title, 'grafana.enko.internal/d/9fbz1/api-latency');
      });

      test('a URL with no path keeps just the host', () async {
        final note = await files.create(content: 'https://dashboard.enko.dev/');
        expect(note.title, 'dashboard.enko.dev');
      });

      test('prose still uses its first line', () async {
        final note = await files.create(
          content: 'Le tri par date casse en UTC+13.\nVérifier export.',
        );
        expect(note.title, 'Le tri par date casse en UTC+13.');
      });

      test('an explicit title always wins', () async {
        final note = await files.create(content: '{"a": 1}', title: 'Mon titre');
        expect(note.title, 'Mon titre');
      });
    });

    test('preview flattens the body instead of showing the first brace', () {
      final epoch = DateTime.utc(2026, 7, 30);
      final note = Note(
        id: 'n',
        title: 't',
        type: NoteType.json,
        content: '{\n  "id": "evt_1",\n  "type": "checkout"\n}',
        folder: Folder.inbox,
        tags: const [],
        created: epoch,
        modified: epoch,
        relativePath: 'Inbox/n.md',
      );
      expect(note.preview, '{ "id": "evt_1", "type": "checkout" }');
    });
  });
}
