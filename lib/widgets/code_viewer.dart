import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/material.dart' show SelectableText;
import 'package:flutter/widgets.dart';
import 'package:re_highlight/languages/bash.dart';
import 'package:re_highlight/languages/c.dart';
import 'package:re_highlight/languages/cpp.dart';
import 'package:re_highlight/languages/csharp.dart';
import 'package:re_highlight/languages/css.dart';
import 'package:re_highlight/languages/dart.dart';
import 'package:re_highlight/languages/diff.dart';
import 'package:re_highlight/languages/dockerfile.dart';
import 'package:re_highlight/languages/go.dart';
import 'package:re_highlight/languages/ini.dart';
import 'package:re_highlight/languages/java.dart';
import 'package:re_highlight/languages/javascript.dart';
import 'package:re_highlight/languages/json.dart';
import 'package:re_highlight/languages/kotlin.dart';
import 'package:re_highlight/languages/php.dart';
import 'package:re_highlight/languages/python.dart';
import 'package:re_highlight/languages/ruby.dart';
import 'package:re_highlight/languages/rust.dart';
import 'package:re_highlight/languages/sql.dart';
import 'package:re_highlight/languages/swift.dart';
import 'package:re_highlight/languages/typescript.dart';
import 'package:re_highlight/languages/xml.dart';
import 'package:re_highlight/languages/yaml.dart';
import 'package:re_highlight/re_highlight.dart';

import '../core/content_limits.dart';
import '../core/theme/jot_theme.dart';
import 'json_viewer.dart' show LargeContentNotice;

/// Syntax highlighting for `CODE` notes.
///
/// Only a developer-relevant subset of grammars is registered rather than all
/// 197, registering the full set costs startup time the capture path cannot
/// spare, and a note that is not one of these still renders (unhighlighted)
/// rather than failing.
abstract final class CodeHighlighter {
  static final Highlight _engine = Highlight()..registerLanguages(_languages());

  /// Shared between the main-isolate [_engine] and [_highlightInBackground],
  /// which builds its own engine on a fresh isolate rather than trying to
  /// send this one across, so a language only ever gets registered in one
  /// place.
  static Map<String, Mode> _languages() => {
    'bash': langBash,
    'c': langC,
    'cpp': langCpp,
    'csharp': langCsharp,
    'css': langCss,
    'dart': langDart,
    'diff': langDiff,
    'dockerfile': langDockerfile,
    'go': langGo,
    'ini': langIni,
    'java': langJava,
    'javascript': langJavascript,
    'json': langJson,
    'kotlin': langKotlin,
    'php': langPhp,
    'python': langPython,
    'ruby': langRuby,
    'rust': langRust,
    'sql': langSql,
    'swift': langSwift,
    'typescript': langTypescript,
    'xml': langXml,
    'yaml': langYaml,
  };

  /// The design's own syntax legend, `clé` / `"texte"` / `1234` / `true` /
  /// `{ } ,`, mapped onto highlight.js scopes. Everything that is not one of
  /// those four roles falls through to the punctuation grey, which is what
  /// keeps a code block reading as the same picture as a JSON block.
  static Map<String, TextStyle> theme(Color baseColor) {
    // Read once per call: these are palette getters now, and the map is
    // rebuilt whenever the theme changes anyway.
    final key = TextStyle(color: JotSyntax.key);
    final string = TextStyle(color: JotSyntax.string);
    final number = TextStyle(color: JotSyntax.number);
    final keyword = TextStyle(color: JotSyntax.keyword);
    final muted = TextStyle(color: JotSyntax.punctuation);

    return {
      'root': TextStyle(color: baseColor),
      // keys / identifiers / attributes
      'attr': key,
      'attribute': key,
      'property': key,
      'title': key,
      'title.function': key,
      'title.class': key,
      'name': key,
      'selector-tag': key,
      'section': key,
      'tag': key,
      // strings
      'string': string,
      'regexp': string,
      'addition': string,
      'meta-string': string,
      'symbol': string,
      'char.escape': string,
      // numbers
      'number': number,
      'literal': number,
      'variable': number,
      'template-variable': number,
      'params': TextStyle(color: baseColor),
      // keywords
      'keyword': keyword,
      'built_in': keyword,
      'type': keyword,
      'doctag': keyword,
      'meta': keyword,
      'operator': keyword,
      // muted
      'comment': muted,
      'quote': muted,
      'punctuation': muted,
      'deletion': TextStyle(color: JotColors.danger),
    };
  }

  /// Cheap language guess from the content itself. `null` means "render plain",
  /// which is always safe.
  static String? guessLanguage(String code) {
    final head = code.trimLeft();
    final lower = head.toLowerCase();

    if (RegExp(r'^\s*(SELECT|INSERT|UPDATE|DELETE|ALTER|CREATE|DROP|WITH)\s',
            caseSensitive: false)
        .hasMatch(head)) {
      return 'sql';
    }
    if (head.startsWith('{') || head.startsWith('[')) return 'json';
    if (head.startsWith('<')) return 'xml';
    if (head.startsWith('#!') || lower.startsWith('#!/bin')) return 'bash';
    if (lower.startsWith('from ') || lower.startsWith('dockerfile')) return 'dockerfile';
    if (head.startsWith('diff ') || head.startsWith('@@')) return 'diff';

    if (RegExp(r'\b(final|late|Widget|BuildContext|ref\.watch|Future<)').hasMatch(code)) {
      return 'dart';
    }
    if (RegExp(r'\b(def |import \w+$|self\.)', multiLine: true).hasMatch(code)) return 'python';
    if (RegExp(r'\b(fn |let mut |impl |pub fn)').hasMatch(code)) return 'rust';
    if (RegExp(r'\b(func |package main|:=)').hasMatch(code)) return 'go';
    if (RegExp(r'\b(interface |type \w+ =|: string|: number)').hasMatch(code)) {
      return 'typescript';
    }
    if (RegExp(r'\b(const |let |=>|function |=== )').hasMatch(code)) return 'javascript';
    if (RegExp(r'^\s*\w[\w.-]*:\s', multiLine: true).hasMatch(code)) return 'yaml';

    return null;
  }

  static TextSpan render(String code, TextStyle base, {String? language}) {
    final lang = language ?? guessLanguage(code);
    if (lang == null) return TextSpan(text: code, style: base);

    try {
      final result = _engine.highlight(code: code, language: lang, ignoreIllegals: true);
      final renderer = TextSpanRenderer(base, theme(base.color ?? JotColors.textStrong));
      result.render(renderer);
      return renderer.span ?? TextSpan(text: code, style: base);
    } on Object {
      // An unregistered or mis-guessed grammar must never blank the note.
      return TextSpan(text: code, style: base);
    }
  }
}

/// Read-only syntax-highlighted code block with the design's line-number
/// gutter.
///
/// Past [ContentLimits.large], highlighting is not run automatically: it
/// tokenizes and colours the *entire* source in one call and renders it as
/// one `SelectableText.rich`, and doing that unconditionally on open is what
/// froze the app on a large file. Instead the note opens as plain, virtualised
/// text, and highlighting becomes a one-tap, off-thread choice.
class CodeViewer extends StatefulWidget {
  const CodeViewer({
    super.key,
    required this.source,
    this.language,
    this.showLineNumbers = true,
    this.fontSize = 12.5,
    this.padding = const EdgeInsets.symmetric(vertical: 12),
    this.showCaret = false,
  });

  final String source;
  final String? language;
  final bool showLineNumbers;
  final double fontSize;
  final EdgeInsets padding;
  final bool showCaret;

  @override
  State<CodeViewer> createState() => _CodeViewerState();
}

class _CodeViewerState extends State<CodeViewer> {
  bool _forceRender = false;
  bool _highlighting = false;
  TextSpan? _highlighted;

  @override
  void didUpdateWidget(CodeViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.source != widget.source) {
      _forceRender = false;
      _highlighted = null;
    }
  }

  void _highlight(TextStyle base) {
    setState(() => _highlighting = true);
    compute(
      _highlightInBackground,
      _HighlightRequest(
        code: widget.source,
        language: widget.language,
        base: base,
        theme: CodeHighlighter.theme(base.color ?? JotColors.textStrong),
      ),
    ).then((span) {
      if (!mounted) return;
      setState(() {
        _highlighting = false;
        _highlighted = span;
      });
    }).catchError((Object e) {
      if (!mounted) return;
      // An unregistered or mis-guessed grammar must never blank the note.
      setState(() {
        _highlighting = false;
        _highlighted = TextSpan(text: widget.source, style: base);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final base = JotText.mono(size: widget.fontSize, height: 1.85, color: JotColors.textStrong);
    final large = ContentLimits.isLarge(widget.source);

    if (large && !_forceRender) {
      return LargeContentNotice(
        source: widget.source,
        fontSize: widget.fontSize,
        padding: widget.padding,
        showLineNumbers: widget.showLineNumbers,
        actionLabel: 'Afficher avec coloration syntaxique',
        onForceRender: () {
          setState(() => _forceRender = true);
          _highlight(base);
        },
      );
    }

    if (_highlighting) {
      return Padding(
        padding: widget.padding,
        child: Text(
          'Mise en couleur en cours...',
          style: base.copyWith(color: JotSyntax.lineNumber),
        ),
      );
    }

    // Small content still highlights straight away, synchronously, exactly
    // as before, this path is already fast and gains nothing from a
    // round trip through another isolate.
    final rendered = _highlighted ??
        CodeHighlighter.render(widget.source, base, language: widget.language);
    final lines = widget.source.split('\n');

    return SingleChildScrollView(
      padding: widget.padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.showLineNumbers)
            SizedBox(
              width: 44,
              child: Padding(
                padding: const EdgeInsets.only(right: 14),
                child: Text.rich(
                  TextSpan(
                    children: [
                      for (var i = 0; i < lines.length; i++)
                        TextSpan(text: '${i + 1}${i == lines.length - 1 ? '' : '\n'}'),
                    ],
                  ),
                  textAlign: TextAlign.right,
                  style: base.copyWith(color: JotSyntax.lineNumber),
                ),
              ),
            ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(left: 4),
              child: SelectableText.rich(
                TextSpan(children: [rendered]),
                style: base,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Everything [_highlightInBackground] needs, packaged so it can cross the
/// isolate boundary. A [Highlight] engine cannot be sent across, so the
/// receiving isolate builds its own from [CodeHighlighter._languages]; the
/// palette (`JotColors`/`JotSyntax`) cannot cross either, it is a mutable
/// static the fresh isolate would never see updated, so [theme] and [base]
/// are resolved on the main isolate first and sent over already built.
class _HighlightRequest {
  const _HighlightRequest({
    required this.code,
    required this.language,
    required this.base,
    required this.theme,
  });

  final String code;
  final String? language;
  final TextStyle base;
  final Map<String, TextStyle> theme;
}

/// Run via [compute]: tokenizing a large document is what froze the frame
/// that opened it. [TextSpan]/[TextStyle] are plain data, safe to build off
/// the main isolate and hand back.
///
/// Registers only the one grammar this request needs, not all 23: compiling
/// every grammar's regexes on a fresh isolate for a single highlight call
/// was slow enough to defeat the point of moving this off the main thread.
TextSpan _highlightInBackground(_HighlightRequest request) {
  final lang = request.language ?? CodeHighlighter.guessLanguage(request.code);
  final grammar = lang == null ? null : CodeHighlighter._languages()[lang];
  if (lang == null || grammar == null) {
    return TextSpan(text: request.code, style: request.base);
  }

  try {
    final engine = Highlight()..registerLanguages({lang: grammar});
    final result = engine.highlight(code: request.code, language: lang, ignoreIllegals: true);
    final renderer = TextSpanRenderer(request.base, request.theme);
    result.render(renderer);
    return renderer.span ?? TextSpan(text: request.code, style: request.base);
  } on Object {
    return TextSpan(text: request.code, style: request.base);
  }
}

/// A single-line inline code snippet, used for URL notes and list previews.
class InlineCode extends StatelessWidget {
  const InlineCode(
    this.text, {
    super.key,
    this.style,
    this.maxLines = 1,
  });

  final String text;
  final TextStyle? style;
  final int maxLines;

  @override
  Widget build(BuildContext context) => Text(
        text,
        maxLines: maxLines,
        overflow: TextOverflow.ellipsis,
        style: style ?? JotText.notePreview,
      );
}
