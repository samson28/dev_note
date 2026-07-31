import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:dev_note/core/models/note.dart';
import 'package:dev_note/core/models/note_type.dart';
import 'package:dev_note/data/file_repository.dart';

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
      // The broken file either parses loosely or is skipped, either way the
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

  group('Folder tree', () {
    late Directory root;
    late FileRepository files;

    setUp(() async {
      root = await Directory.systemTemp.createTemp('jot_tree_');
      files = FileRepository(root);
      await files.ensureScaffold();
    });

    tearDown(() async {
      if (await root.exists()) await root.delete(recursive: true);
    });

    test('children follow their parent, Inbox first and Archive last',
        () async {
      for (final f in const ['Enko/Webhooks', 'Enko', 'Klém', 'Enko/API']) {
        await files.createFolder(f);
      }

      // Archive comes from the scaffold and belongs at the end.
      expect(await files.listFolders(), [
        'Inbox',
        'Enko',
        'Enko/API',
        'Enko/Webhooks',
        'Klém',
        'Archive',
      ]);
    });

    test('the Inbox/Archive ranking applies at the top level only', () async {
      // A folder named Archive nested inside another is just a folder, and
      // must not be dragged to the end of the whole list.
      for (final f in const ['Enko/Archive', 'Enko/Zeta', 'Zulu']) {
        await files.createFolder(f);
      }

      final folders = await files.listFolders();
      expect(
        folders.indexOf('Enko/Archive') < folders.indexOf('Enko/Zeta'),
        isTrue,
      );
      expect(folders.indexOf('Enko/Zeta') < folders.indexOf('Zulu'), isTrue);
    });

    test('depth, leaf and descendant read the path the same way', () {
      expect(FileRepository.depthOf('Inbox'), 0);
      expect(FileRepository.depthOf('Enko/Webhooks'), 1);
      expect(FileRepository.leafOf('Enko/Webhooks'), 'Webhooks');
      expect(FileRepository.leafOf('Inbox'), 'Inbox');

      expect(FileRepository.isDescendant('Enko/API', 'Enko'), isTrue);
      expect(FileRepository.isDescendant('Enko', 'Enko'), isFalse);
      // A shared prefix is not a parent: "Enkore" is not inside "Enko".
      expect(FileRepository.isDescendant('Enkore', 'Enko'), isFalse);
    });

    test('a note filed in a sub-folder keeps its full path', () async {
      await files.createFolder('Enko/Webhooks');
      final note = await files.create(
        content: 'x',
        title: 'stripe',
        folder: 'Enko/Webhooks',
      );

      final read = await files.read(File('${root.path}/${note.relativePath}'));
      expect(read.folder, 'Enko/Webhooks');
    });
  });

  group('FileRepository vault move', () {
    late Directory root;
    late Directory target;
    late FileRepository files;

    setUp(() async {
      root = await Directory.systemTemp.createTemp('jot_from_');
      target = await Directory.systemTemp.createTemp('jot_to_');
      files = FileRepository(root);
      await files.ensureScaffold();
    });

    tearDown(() async {
      for (final d in [root, target]) {
        if (await d.exists()) await d.delete(recursive: true);
      }
    });

    test('carries every note across, then empties the old folder', () async {
      await files.create(content: 'un', title: 'a', folder: Folder.inbox);
      await files.create(content: 'deux', title: 'b', folder: 'Enko');

      final copied = await files.moveVaultTo(target);

      expect(copied, greaterThanOrEqualTo(2));
      expect(await root.exists(), isFalse);

      final moved = FileRepository(target);
      final notes = await moved.readAll();
      expect(notes.map((n) => n.title).toSet(), {'a', 'b'});
      // The folder structure has to survive, not just the files.
      expect(notes.firstWhere((n) => n.title == 'b').folder, 'Enko');
    });

    test('a move onto the same folder is a no-op, not a wipe', () async {
      await files.create(content: 'x', title: 'garde');

      expect(await files.moveVaultTo(root), 0);
      expect(await root.exists(), isTrue);
      expect((await files.readAll()).length, 1);
    });

    test('attachments travel with their notes', () async {
      final source = await Directory.systemTemp.createTemp('jot_src_');
      final pdf = File('${source.path}/doc.pdf')
        ..writeAsBytesSync([0x00, 0x11, 0x22]);
      final note = await files.importFile(pdf);

      await files.moveVaultTo(target);

      final moved = FileRepository(target);
      final read = await moved.read(
        File('${target.path}/${note.relativePath}'),
      );
      expect(await moved.attachmentFile(read)!.exists(), isTrue);
      expect(await moved.exportBytes(read), [0x00, 0x11, 0x22]);

      await source.delete(recursive: true);
    });

    test('the trash travels too, so nothing restorable is silently lost',
        () async {
      final note = await files.create(content: 'y', title: 'jetee');
      await files.delete(note);
      expect((await files.listTrash()).length, 1);

      await files.moveVaultTo(target);

      expect((await FileRepository(target).listTrash()).length, 1);
    });
  });

  group('FileRepository import', () {
    late Directory root;
    late Directory source;
    late FileRepository files;

    setUp(() async {
      root = await Directory.systemTemp.createTemp('jot_import_');
      source = await Directory.systemTemp.createTemp('jot_source_');
      files = FileRepository(root);
      await files.ensureScaffold();
    });

    tearDown(() async {
      if (await root.exists()) await root.delete(recursive: true);
      if (await source.exists()) await source.delete(recursive: true);
    });

    File at(String name) => File('${source.path}/$name');

    test('a flat file becomes a searchable note, not an attachment', () async {
      final csv = at('ventes.csv')
        ..writeAsStringSync('mois,total\njanvier,1240\nfevrier,980\n');

      final note = await files.importFile(csv);

      expect(note.attachment, isNull);
      expect(note.title, 'ventes');
      expect(note.content, contains('fevrier,980'));
      // A CSV lines up only in the monospace face.
      expect(note.type, NoteType.code);
    });

    test('the extension wins over content sniffing', () async {
      // Valid JSON, but the user called it .xml, trust the name.
      final xml = at('config.xml')..writeAsStringSync('{"a": 1}');
      expect((await files.importFile(xml)).type, NoteType.code);

      final json = at('payload.json')..writeAsStringSync('{"a": 1}');
      expect((await files.importFile(json)).type, NoteType.json);
    });

    test('an unknown extension still imports as text when it is text', () async {
      final odd = at('dump.wat')..writeAsStringSync('juste des mots');
      final note = await files.importFile(odd);

      expect(note.attachment, isNull);
      expect(note.content, 'juste des mots');
    });

    test('a binary is copied into the vault and pointed at', () async {
      // A NUL byte is what marks this as something Jot cannot inline.
      final pdf = at('facture.pdf')
        ..writeAsBytesSync([0x25, 0x50, 0x44, 0x46, 0x00, 0x01, 0x02]);

      final note = await files.importFile(pdf);

      expect(note.type, NoteType.file);
      expect(note.attachmentName, 'facture.pdf');
      expect(note.attachmentExtension, 'PDF');
      expect(note.attachmentBytes, 7);
      expect(await files.attachmentFile(note)!.exists(), isTrue);
      // The body is what search matches on, so the filename has to be in it.
      expect(note.content, contains('facture.pdf'));
    });

    test('the attachment survives a round-trip through the frontmatter', () async {
      final pdf = at('rapport.pdf')..writeAsBytesSync([0x00, 0x11]);
      final created = await files.importFile(pdf);

      final read = await files.read(
        File('${root.path}/${created.relativePath}'),
      );
      expect(read.attachment, created.attachment);
      expect(read.attachmentBytes, 2);
      expect(read.type, NoteType.file);
    });

    test('two imports of the same name do not collide', () async {
      final a = at('facture.pdf')..writeAsBytesSync([0x00, 1]);
      final first = await files.importFile(a);
      final second = await files.importFile(a);

      expect(first.attachment, isNot(second.attachment));
      expect(await files.attachmentFile(first)!.exists(), isTrue);
      expect(await files.attachmentFile(second)!.exists(), isTrue);
    });

    test('orphan attachments are purged, referenced ones are kept', () async {
      final kept = await files.importFile(
        at('garde.pdf')..writeAsBytesSync([0x00, 1]),
      );
      final dropped = await files.importFile(
        at('jette.pdf')..writeAsBytesSync([0x00, 2]),
      );

      // Remove the note but not its bytes, what the trash does.
      await File('${root.path}/${dropped.relativePath}').delete();

      expect(await files.purgeOrphanAttachments(), 1);
      expect(await files.attachmentFile(kept)!.exists(), isTrue);
      expect(await files.attachmentFile(dropped)!.exists(), isFalse);
    });

    test('the four kinds a developer actually drops in', () async {
      // One assertion per path through importFile, on files shaped like the
      // real thing rather than on minimal fixtures.
      final csv = at('ventes_q1.csv')
        ..writeAsStringSync('mois,total,marge\njanvier,1240,18\nmars,1510,25\n');
      final xml = at('config.xml')..writeAsStringSync(
          '<?xml version="1.0"?>\n<config>\n  <retries>3</retries>\n</config>\n');
      final json = at('payload.json')
        ..writeAsStringSync('{"webhook": "checkout.session.completed"}');
      final pdf = at('facture_2026.pdf')
        ..writeAsBytesSync([0x25, 0x50, 0x44, 0x46, ...List.filled(64, 0)]);

      final notes = [
        for (final f in [csv, xml, json, pdf]) await files.importFile(f),
      ];

      expect(notes.map((n) => n.type).toList(), [
        NoteType.code, // csv, monospace
        NoteType.code, // xml
        NoteType.json,
        NoteType.file, // pdf, copied
      ]);
      expect(notes.map((n) => n.title).toList(),
          ['ventes_q1', 'config', 'payload', 'facture_2026']);

      // Only the PDF left bytes behind; the other three are notes outright.
      expect(notes.where((n) => n.attachment != null).length, 1);

      // Every one is findable by something the user would type.
      expect(notes[0].content, contains('marge'));
      expect(notes[1].content, contains('retries'));
      expect(notes[2].content, contains('checkout.session.completed'));
      expect(notes[3].content, contains('facture_2026.pdf'));
    });

    test('an empty file imports rather than failing', () async {
      final note = await files.importFile(at('vide.txt')..writeAsStringSync(''));
      expect(note.attachment, isNull);
      expect(note.title, 'vide');
    });

    test('a file with no extension is judged on its bytes', () async {
      final text = await files.importFile(at('Makefile')..writeAsStringSync(
          'build:\n\tflutter build windows\n'));
      expect(text.attachment, isNull);

      final binary = await files.importFile(
        at('blob')..writeAsBytesSync([0x89, 0x50, 0x00, 0x0D]),
      );
      expect(binary.type, NoteType.file);
      expect(binary.attachmentExtension, isNull);
    });

    test('a flat file comes back out under its original name', () async {
      // The whole point of recording the source name: the note is titled
      // "ventes_q1" and typed as code, so nothing else could reconstruct
      // ".csv".
      final csv = at('ventes_q1.csv')
        ..writeAsStringSync('mois,total\njanvier,1240\n');
      final note = await files.importFile(csv);

      expect(note.sourceName, 'ventes_q1.csv');
      expect(FileRepository.suggestedFileName(note), 'ventes_q1.csv');
      expect(
        utf8.decode(await files.exportBytes(note)),
        'mois,total\njanvier,1240\n',
      );
    });

    test('a binary comes back byte for byte', () async {
      final bytes = [0x25, 0x50, 0x44, 0x46, 0x00, 0xFF, 0x7F, 0x01];
      final pdf = at('facture.pdf')..writeAsBytesSync(bytes);
      final note = await files.importFile(pdf);

      expect(FileRepository.suggestedFileName(note), 'facture.pdf');
      expect(await files.exportBytes(note), bytes);
    });

    test('the source name survives the frontmatter round-trip', () async {
      final created = await files.importFile(
        at('config.xml')..writeAsStringSync('<a/>'),
      );
      final read = await files.read(
        File('${root.path}/${created.relativePath}'),
      );
      expect(read.sourceName, 'config.xml');
    });

    test('edits made after import are what comes back out', () async {
      final note = await files.importFile(
        at('notes.json')..writeAsStringSync('{"a": 1}'),
      );
      await files.write(note.copyWith(content: '{"a": 2}'));

      final read = await files.read(
        File('${root.path}/${note.relativePath}'),
      );
      expect(utf8.decode(await files.exportBytes(read)), '{"a": 2}');
      expect(FileRepository.suggestedFileName(read), 'notes.json');
    });

    test('an attachment falls back to its stored name, never to .bin', () async {
      // Notes imported before the `source:` key existed have no sourceName,
      // but the copy in the vault still carries the name the user knew. The
      // save dialog must offer that, not a slug with a made-up extension.
      final note = await files.importFile(
        at('Contrat Ouaga (1).pdf')..writeAsBytesSync([0x25, 0x50, 0x00, 1]),
      );
      final legacy = note.copyWith(sourceName: '');

      expect(FileRepository.suggestedFileName(legacy), 'Contrat Ouaga (1).pdf');
    });

    test('a note typed in the app gets a name from its title and type',
        () async {
      final note = await files.create(
        content: '{"a": 1}',
        title: 'Réponse webhook',
      );
      expect(note.sourceName, isNull);
      expect(FileRepository.suggestedFileName(note), 'reponse-webhook.json');
    });

    test('exporting an attachment whose bytes vanished fails loudly', () async {
      final note = await files.importFile(
        at('perdu.pdf')..writeAsBytesSync([0x00, 1]),
      );
      await files.attachmentFile(note)!.delete();

      expect(files.exportBytes(note), throwsA(isA<FileSystemException>()));
    });

    test('attachments are invisible to the note walk and the folder list',
        () async {
      await files.importFile(at('doc.pdf')..writeAsBytesSync([0x00, 1]));

      expect(await files.listFolders(), isNot(contains('.attachments')));
      final paths = await files.noteFiles().map((f) => f.path).toList();
      expect(paths.any((p) => p.contains('.attachments')), isFalse);
    });
  });
}
