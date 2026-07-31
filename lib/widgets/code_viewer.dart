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

import '../core/theme/jot_theme.dart';

/// Syntax highlighting for `CODE` notes.
///
/// Only a developer-relevant subset of grammars is registered rather than all
/// 197 — registering the full set costs startup time the capture path cannot
/// spare, and a note that is not one of these still renders (unhighlighted)
/// rather than failing.
abstract final class CodeHighlighter {
  static final Highlight _engine = () {
    final h = Highlight()
      ..registerLanguages({
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
      });
    return h;
  }();

  /// The design's own syntax legend — `clé` / `"texte"` / `1234` / `true` /
  /// `{ } ,` — mapped onto highlight.js scopes. Everything that is not one of
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
class CodeViewer extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final base = JotText.mono(size: fontSize, height: 1.85, color: JotColors.textStrong);
    final lines = source.split('\n');

    return SingleChildScrollView(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showLineNumbers)
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
                TextSpan(
                  children: [
                    CodeHighlighter.render(source, base, language: language),
                  ],
                ),
                style: base,
              ),
            ),
          ),
        ],
      ),
    );
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
