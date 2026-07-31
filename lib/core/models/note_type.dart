import 'dart:convert';

import '../theme/jot_colors.dart';

/// The four content types the design distinguishes with a badge.
enum NoteType {
  text('txt', 'TXT'),
  json('json', 'JSON'),
  code('code', 'CODE'),
  url('url', 'URL');

  const NoteType(this.id, this.label);

  /// Value written to the YAML frontmatter.
  final String id;

  /// Badge caption.
  final String label;

  static NoteType fromId(String? id) => switch (id?.trim().toLowerCase()) {
    'json' => NoteType.json,
    'code' => NoteType.code,
    'url' => NoteType.url,
    _ => NoteType.text,
  };

  /// Resolved from the active palette: light uses tinted paper fills, OLED
  /// uses transparent chips with a 1px tinted outline.
  TypeBadgeColors get badge => switch (this) {
    NoteType.text => JotColors.active.badgeText,
    NoteType.json => JotColors.active.badgeJson,
    NoteType.code => JotColors.active.badgeCode,
    NoteType.url => JotColors.active.badgeUrl,
  };

  /// Whether the body should be rendered with the monospace face.
  bool get isMonospace => this != NoteType.text;
}

/// Best-effort content sniffing, run on every keystroke in quick capture and
/// once when a note is created.
///
/// Deliberately cheap: capture must never stutter, so this does no parsing
/// beyond a single `jsonDecode` attempt on inputs that already look like JSON.
abstract final class NoteTypeDetector {
  static final _urlPattern = RegExp(
    r'^(https?://|www\.)[^\s]+$|^[a-z0-9-]+(\.[a-z0-9-]+)+(/[^\s]*)?$',
    caseSensitive: false,
  );

  /// Lines that strongly suggest source code rather than prose.
  static final _codeSignals = <RegExp>[
    RegExp(r'^\s*(import|export|package|using|#include|from)\s'),
    RegExp(r'\b(function|const|let|var|final|def|class|fn|func|public|private)\s+\w'),
    RegExp(r'^\s*(SELECT|INSERT|UPDATE|DELETE|ALTER|CREATE|DROP)\s', caseSensitive: false),
    RegExp(r'=>|::|->|\{\s*$|\);\s*$|;\s*$'),
    RegExp(r'^\s*(if|for|while|switch|return|await|async)\b'),
    RegExp(r'^\s{2,}\S'), // consistent leading indentation
  ];

  static NoteType detect(String raw) {
    final content = raw.trim();
    if (content.isEmpty) return NoteType.text;

    if (_looksLikeJson(content) && _isValidJson(content)) return NoteType.json;

    // A URL only counts when it is the *whole* note — a link inside a
    // paragraph is still text.
    if (!content.contains(RegExp(r'\s')) && _urlPattern.hasMatch(content)) {
      return NoteType.url;
    }

    final lines = content.split('\n');
    var hits = 0;
    for (final line in lines) {
      if (_codeSignals.any((p) => p.hasMatch(line))) hits++;
    }
    // One signal is enough for a one-liner snippet; longer blocks need the
    // pattern to hold across a reasonable share of the lines.
    if (lines.length <= 2 ? hits >= 1 : hits >= (lines.length / 3).ceil()) {
      return NoteType.code;
    }

    return NoteType.text;
  }

  static bool _looksLikeJson(String s) =>
      (s.startsWith('{') && s.endsWith('}')) ||
      (s.startsWith('[') && s.endsWith(']'));

  static bool _isValidJson(String s) {
    try {
      jsonDecode(s);
      return true;
    } on FormatException {
      return false;
    }
  }
}
