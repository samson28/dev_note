import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dev_note/core/content_limits.dart';
import 'package:dev_note/core/models/note.dart';
import 'package:dev_note/core/models/note_type.dart';
import 'package:dev_note/widgets/code_viewer.dart';
import 'package:dev_note/widgets/json_viewer.dart';
import 'package:dev_note/widgets/note_body.dart';

/// A note importing a large file behaves like: valid JSON, comfortably past
/// [ContentLimits.large]. Built rather than read from a fixture, so the test
/// states its own size assumption instead of depending on a file elsewhere.
String _bigJsonArray() {
  final buffer = StringBuffer('[');
  var i = 0;
  while (buffer.length < ContentLimits.large + 20000) {
    if (i > 0) buffer.write(',');
    buffer.write('{"id":$i,"name":"item-$i","active":true}');
    i++;
  }
  buffer.write(']');
  return buffer.toString();
}

/// Deliberately varied, not thousands of identical lines: a highly
/// repetitive input was found to trigger pathological backtracking in the
/// grammar's tokenizer regexes, real code never looks like that, and a
/// microbenchmark for a regex engine is not what this test is for.
String _bigCode() {
  final buffer = StringBuffer();
  var i = 0;
  final kinds = [
    (int i) => 'final value$i = compute($i * 2);',
    (int i) => '// comment number $i about something',
    (int i) => 'class Thing$i extends Widget { }',
    (int i) => 'if (value$i > 10) { print("big"); }',
    (int i) => "const name$i = 'literal string $i here';",
  ];
  while (buffer.length < ContentLimits.large + 20000) {
    buffer.writeln(kinds[i % kinds.length](i));
    i++;
  }
  return buffer.toString();
}

Note _note({
  required String content,
  NoteType type = NoteType.text,
}) => Note(
      id: 'n',
      title: 't',
      type: type,
      content: content,
      folder: Folder.inbox,
      tags: const [],
      created: DateTime(2026),
      modified: DateTime(2026),
      relativePath: 'Inbox/n.md',
    );

Widget _host(Widget child) => MaterialApp(home: Scaffold(body: child));

/// Waits for a [compute] isolate to finish and its `setState` to land.
///
/// `pumpAndSettle` alone never observes this: `testWidgets` runs in a
/// fake-async zone that controls `Duration`-based timers, but an isolate's
/// result arrives through the real event loop, which that zone does not
/// advance. `runAsync` steps briefly outside the fake zone so real time
/// actually passes, which is the documented way to wait on genuine async
/// work (isolates, real I/O) inside a widget test.
Future<void> _settleAsync(WidgetTester tester) async {
  // 20 * 400ms = 8s of real time: JSON decode resolves in under one tick,
  // syntax highlighting a large document (registering and running one
  // grammar) took around 4s when measured, so this leaves real margin.
  for (var i = 0; i < 20; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 400)),
    );
    await tester.pump();
  }
}

void main() {
  group('ContentLimits', () {
    test('isLarge is a strict threshold on character count', () {
      expect(ContentLimits.isLarge('a' * ContentLimits.large), isFalse);
      expect(ContentLimits.isLarge('a' * (ContentLimits.large + 1)), isTrue);
    });
  });

  group('Note caching', () {
    test('preview stays capped and correct for large content', () {
      final note = _note(content: 'x' * (ContentLimits.large + 5000));
      final preview = note.preview;
      expect(preview.length, lessThanOrEqualTo(223)); // 220 chars + "..."
      expect(preview, endsWith('...'));
      // Read twice: the cached value must be the same answer, not a stale
      // or partially-computed one.
      expect(note.preview, preview);
    });

    test('lineCount matches the real number of lines, cached or not', () {
      final note = _note(content: List.filled(500, 'line').join('\n'));
      expect(note.lineCount, 500);
      expect(note.lineCount, 500); // second read hits the cache
    });

    test('a fresh Note (new copyWith) does not inherit a stale cache', () {
      final a = _note(content: 'short');
      final firstPreview = a.preview; // populates a's cache
      final b = a.copyWith(content: 'a completely different body');
      expect(firstPreview, isNot(b.preview));
      expect(b.preview, 'a completely different body');
    });
  });

  group('JsonViewer with large content', () {
    testWidgets('small valid JSON renders the tree immediately', (tester) async {
      await tester.pumpWidget(_host(const JsonViewer(source: '{"hello": "world"}')));
      await tester.pump();
      expect(find.textContaining('hello'), findsOneWidget);
      expect(find.byType(LargeContentNotice), findsNothing);
    });

    testWidgets('large JSON shows the notice instead of decoding eagerly',
        (tester) async {
      final source = _bigJsonArray();
      await tester.pumpWidget(_host(JsonViewer(source: source)));
      await tester.pump();

      expect(find.byType(LargeContentNotice), findsOneWidget);
      expect(find.text('Afficher en JSON structuré'), findsOneWidget);
      // The raw text underneath is still readable right away.
      expect(find.textContaining('"name":"item-0"'), findsOneWidget);
    });

    testWidgets('tapping the action decodes and shows the tree', (tester) async {
      final source = _bigJsonArray();
      await tester.pumpWidget(_host(JsonViewer(source: source)));
      await tester.pump();

      await tester.tap(find.text('Afficher en JSON structuré'));
      await tester.pump();
      await _settleAsync(tester);

      expect(find.byType(LargeContentNotice), findsNothing);
      expect(find.textContaining('"id"'), findsWidgets);
    });
  });

  group('CodeViewer with large content', () {
    testWidgets('small code highlights immediately, no notice', (tester) async {
      await tester.pumpWidget(_host(const CodeViewer(source: 'final x = 1;')));
      await tester.pump();
      expect(find.byType(LargeContentNotice), findsNothing);
      expect(find.textContaining('final x = 1;'), findsOneWidget);
    });

    testWidgets('large code shows the notice, not a wall of highlighted text',
        (tester) async {
      final source = _bigCode();
      await tester.pumpWidget(_host(CodeViewer(source: source)));
      await tester.pump();

      expect(find.byType(LargeContentNotice), findsOneWidget);
      expect(find.text('Afficher avec coloration syntaxique'), findsOneWidget);
    });

    testWidgets('opting in highlights off-thread and then shows the code',
        (tester) async {
      final source = _bigCode();
      await tester.pumpWidget(_host(CodeViewer(source: source)));
      await tester.pump();

      await tester.tap(find.text('Afficher avec coloration syntaxique'));
      await tester.pump();
      await _settleAsync(tester);

      expect(find.byType(LargeContentNotice), findsNothing);
      expect(find.textContaining('final value0 = compute(0 * 2);'), findsOneWidget);
    });
  });

  group('NoteBody editing a large note', () {
    testWidgets('a small text note edits live, no gate', (tester) async {
      final note = _note(content: 'short note', type: NoteType.text);
      await tester.pumpWidget(
        _host(NoteBody(note: note, onChanged: (_) {})),
      );
      await tester.pump();
      expect(find.byType(TextField), findsOneWidget);
      expect(find.byType(LargeContentNotice), findsNothing);
    });

    testWidgets('a large text note opens read-only, editing is opt-in',
        (tester) async {
      final note = _note(
        content: 'x' * (ContentLimits.large + 5000),
        type: NoteType.text,
      );
      await tester.pumpWidget(
        _host(NoteBody(note: note, onChanged: (_) {})),
      );
      await tester.pump();

      expect(find.byType(TextField), findsNothing);
      expect(find.byType(LargeContentNotice), findsOneWidget);
      expect(find.text('Modifier quand même'), findsOneWidget);

      await tester.tap(find.text('Modifier quand même'));
      await tester.pump();

      expect(find.byType(TextField), findsOneWidget);
      expect(find.byType(LargeContentNotice), findsNothing);
    });
  });
}
