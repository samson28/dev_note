/// Date and size formatting matching the strings in the design
/// ("il y a 4 min", "hier, 18:32", "mar. 14:07", "17 juil.", "1,42 Ko").
///
/// Hand-rolled rather than pulled from `intl` so the output is byte-for-byte
/// what the mockup shows, and so the list can format hundreds of rows without
/// touching a locale database.
abstract final class JotFormat {
  static const _weekdays = <String>[
    'lun.',
    'mar.',
    'mer.',
    'jeu.',
    'ven.',
    'sam.',
    'dim.',
  ];

  static const _months = <String>[
    'janv.',
    'févr.',
    'mars',
    'avr.',
    'mai',
    'juin',
    'juil.',
    'août',
    'sept.',
    'oct.',
    'nov.',
    'déc.',
  ];

  static String _two(int n) => n.toString().padLeft(2, '0');

  static String _clock(DateTime d) => '${_two(d.hour)}:${_two(d.minute)}';

  /// Relative timestamp for note rows and search results.
  static String relative(DateTime when, {DateTime? now}) {
    final ref = now ?? DateTime.now();
    final delta = ref.difference(when);

    if (delta.isNegative || delta.inSeconds < 60) return 'à l\'instant';
    if (delta.inMinutes < 60) return 'il y a ${delta.inMinutes} min';

    final today = DateTime(ref.year, ref.month, ref.day);
    final day = DateTime(when.year, when.month, when.day);
    final daysApart = today.difference(day).inDays;

    if (daysApart == 0) return 'il y a ${delta.inHours} h';
    if (daysApart == 1) return 'hier, ${_clock(when)}';
    if (daysApart < 7) {
      return '${_weekdays[when.weekday - 1]} ${_clock(when)}';
    }
    if (when.year == ref.year) {
      return '${when.day} ${_months[when.month - 1]}';
    }
    return '${when.day} ${_months[when.month - 1]} ${when.year}';
  }

  /// Absolute timestamp used in the editor sub-header ("28 juil. 09:12").
  static String absolute(DateTime when) =>
      '${when.day} ${_months[when.month - 1]} ${_clock(when)}';

  /// "1,42 Ko" — French decimal comma, binary-free kilobytes as the design
  /// shows them.
  static String bytes(int size) {
    if (size < 1000) return '$size o';
    if (size < 1000 * 1000) {
      return '${_decimal(size / 1000)} Ko';
    }
    return '${_decimal(size / (1000 * 1000))} Mo';
  }

  static String _decimal(double value) {
    final s = value.toStringAsFixed(value >= 100 ? 0 : 2);
    return s.replaceAll('.', ',');
  }

  /// Section header for a note-list group.
  static String group(DateTime modified, {DateTime? now}) {
    final ref = now ?? DateTime.now();
    final today = DateTime(ref.year, ref.month, ref.day);
    final day = DateTime(modified.year, modified.month, modified.day);
    final daysApart = today.difference(day).inDays;

    if (daysApart <= 0) return "Aujourd'hui";
    if (daysApart == 1) return 'Hier';
    if (daysApart < 7) return 'Cette semaine';
    if (daysApart < 31) return 'Ce mois-ci';
    return 'Plus ancien';
  }
}
