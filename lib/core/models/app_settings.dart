import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show Color;

import '../theme/jot_colors.dart';

/// The three themes offered in the Apparence tab.
enum JotThemeMode {
  anthracite('anthracite', 'Anthracite'),
  oled('oled', 'Noir profond (OLED)'),
  light('light', 'Clair');

  const JotThemeMode(this.id, this.label);
  final String id;
  final String label;

  static JotThemeMode fromId(String? id) =>
      JotThemeMode.values.firstWhere((m) => m.id == id, orElse: () => anthracite);
}

/// The five accent swatches from the design.
enum JotAccent {
  orange('orange', Color(0xFFFF6A3D)),
  amber('amber', Color(0xFFE3B341)),
  blue('blue', Color(0xFF58A6FF)),
  green('green', Color(0xFF3FD08A)),
  violet('violet', Color(0xFFA78BFA));

  const JotAccent(this.id, this.color);
  final String id;
  final Color color;

  static JotAccent fromId(String? id) =>
      JotAccent.values.firstWhere((a) => a.id == id, orElse: () => orange);

  /// Text/icon colour to place on top of a solid fill of this accent.
  Color get onColor => this == orange ? JotColors.onAccent : const Color(0xFF12100A);
}

enum ListDensity {
  compact('compact', 'Compacte'),
  comfortable('comfortable', 'Confortable');

  const ListDensity(this.id, this.label);
  final String id;
  final String label;

  static ListDensity fromId(String? id) =>
      ListDensity.values.firstWhere((d) => d.id == id, orElse: () => comfortable);
}

enum CapturePosition {
  screenCenter('center', 'Centre écran'),
  nearCursor('cursor', 'Près du curseur'),
  lastPosition('last', 'Dernière position');

  const CapturePosition(this.id, this.label);
  final String id;
  final String label;

  static CapturePosition fromId(String? id) =>
      CapturePosition.values.firstWhere((p) => p.id == id, orElse: () => screenCenter);
}

enum BackupFrequency {
  daily('daily', 'Quotidienne'),
  weekly('weekly', 'Hebdomadaire'),
  monthly('monthly', 'Mensuelle');

  const BackupFrequency(this.id, this.label);
  final String id;
  final String label;

  static BackupFrequency fromId(String? id) =>
      BackupFrequency.values.firstWhere((f) => f.id == id, orElse: () => daily);
}

enum UpdateChannel {
  stable('stable', 'Stable'),
  beta('beta', 'Beta');

  const UpdateChannel(this.id, this.label);
  final String id;
  final String label;

  static UpdateChannel fromId(String? id) =>
      UpdateChannel.values.firstWhere((c) => c.id == id, orElse: () => stable);
}

/// Every action that can carry a user-remappable shortcut.
enum ShortcutAction {
  quickCapture('quickCapture', 'Ouvrir la capture rapide', global: true),
  pasteClipboard('pasteClipboard', 'Coller le presse-papier en note', global: true),
  toggleMainWindow('toggleMainWindow', 'Afficher / masquer la fenêtre principale',
      global: true),
  searchPalette('searchPalette', 'Palette de recherche'),
  newNote('newNote', 'Nouvelle note'),
  pinNote('pinNote', 'Épingler la note'),
  copyNote('copyNote', 'Copier le contenu de la note'),
  toggleJson('toggleJson', 'Plier / déplier tout le JSON'),
  deleteNote('deleteNote', 'Supprimer la note');

  const ShortcutAction(this.id, this.label, {this.global = false});

  final String id;
  final String label;

  /// Global shortcuts are registered system-wide and work outside the app.
  final bool global;

  static ShortcutAction? fromId(String id) {
    for (final a in ShortcutAction.values) {
      if (a.id == id) return a;
    }
    return null;
  }
}

/// A key combination, stored as modifier flags plus a key label.
@immutable
class KeyCombo {
  const KeyCombo({
    required this.key,
    this.ctrl = false,
    this.alt = false,
    this.shift = false,
    this.meta = false,
  });

  /// Display label of the main key, e.g. `N`, `K`, `.`, `⌫`.
  final String key;
  final bool ctrl;
  final bool alt;
  final bool shift;
  final bool meta;

  bool get isEmpty => key.isEmpty;

  /// The chips shown in the Raccourcis tab, in the design's order.
  List<String> get parts => [
        if (ctrl) 'Ctrl',
        if (alt) 'Alt',
        if (shift) 'Shift',
        if (meta) 'Win',
        if (key.isNotEmpty) key,
      ];

  @override
  String toString() => parts.join(' + ');

  Map<String, dynamic> toJson() => {
        'key': key,
        'ctrl': ctrl,
        'alt': alt,
        'shift': shift,
        'meta': meta,
      };

  static KeyCombo fromJson(Map<String, dynamic> json) => KeyCombo(
        key: '${json['key'] ?? ''}',
        ctrl: json['ctrl'] == true,
        alt: json['alt'] == true,
        shift: json['shift'] == true,
        meta: json['meta'] == true,
      );

  @override
  bool operator ==(Object other) =>
      other is KeyCombo &&
      other.key.toUpperCase() == key.toUpperCase() &&
      other.ctrl == ctrl &&
      other.alt == alt &&
      other.shift == shift &&
      other.meta == meta;

  @override
  int get hashCode => Object.hash(key.toUpperCase(), ctrl, alt, shift, meta);
}

/// Everything the Réglages window can change, persisted as one JSON file.
@immutable
class AppSettings {
  const AppSettings({
    // Général
    this.launchAtStartup = true,
    this.closeToTray = true,
    this.defaultFolder = 'Inbox',
    this.autoDetectType = true,
    this.reformatJsonOnSave = false,
    this.maskCredentialValues = true,
    // Apparence
    this.theme = JotThemeMode.anthracite,
    // "Suivre le système : activé par défaut" (design, Règles de bascule).
    this.followSystemTheme = true,
    this.accent = JotAccent.orange,
    this.textSize = 13,
    this.codeLigatures = true,
    this.density = ListDensity.comfortable,
    this.previewLines = 2,
    this.showLineNumbers = true,
    // Raccourcis
    this.shortcuts = defaultShortcuts,
    // Capture rapide
    this.capturePosition = CapturePosition.screenCenter,
    this.captureAlwaysOnTop = true,
    this.prefillFromClipboard = true,
    this.captureFolder = 'Inbox',
    this.closeAfterSave = true,
    this.autoTitle = true,
    this.notifyAfterSave = false,
    // Stockage
    this.backupEnabled = true,
    this.backupFrequency = BackupFrequency.daily,
    this.trashRetentionDays = 30,
    // À propos
    this.updateChannel = UpdateChannel.stable,
    this.autoInstallUpdates = true,
  });

  final bool launchAtStartup;
  final bool closeToTray;
  final String defaultFolder;
  final bool autoDetectType;
  final bool reformatJsonOnSave;
  final bool maskCredentialValues;

  final JotThemeMode theme;
  final bool followSystemTheme;
  final JotAccent accent;

  /// Base UI text size in logical pixels, 11–18 in the design's slider.
  final double textSize;
  final bool codeLigatures;
  final ListDensity density;

  /// Number of preview lines under a note title in the list, 0–3.
  final int previewLines;
  final bool showLineNumbers;

  final Map<ShortcutAction, KeyCombo> shortcuts;

  final CapturePosition capturePosition;
  final bool captureAlwaysOnTop;
  final bool prefillFromClipboard;
  final String captureFolder;
  final bool closeAfterSave;
  final bool autoTitle;
  final bool notifyAfterSave;

  final bool backupEnabled;
  final BackupFrequency backupFrequency;
  final int trashRetentionDays;

  final UpdateChannel updateChannel;
  final bool autoInstallUpdates;

  static const defaultShortcuts = <ShortcutAction, KeyCombo>{
    ShortcutAction.quickCapture: KeyCombo(key: 'N', ctrl: true, alt: true),
    ShortcutAction.pasteClipboard: KeyCombo(key: 'V', ctrl: true, alt: true),
    ShortcutAction.toggleMainWindow: KeyCombo(key: 'J', ctrl: true, shift: true),
    ShortcutAction.searchPalette: KeyCombo(key: 'K', ctrl: true),
    ShortcutAction.newNote: KeyCombo(key: 'N', ctrl: true),
    ShortcutAction.pinNote: KeyCombo(key: 'P', ctrl: true),
    ShortcutAction.copyNote: KeyCombo(key: 'C', ctrl: true, shift: true),
    ShortcutAction.toggleJson: KeyCombo(key: '.', ctrl: true),
    ShortcutAction.deleteNote: KeyCombo(key: '⌫', ctrl: true),
  };

  /// Actions whose combination collides with another action's — the design
  /// surfaces these in red and counts them in the footer.
  Set<ShortcutAction> get conflicts {
    final seen = <KeyCombo, ShortcutAction>{};
    final clashing = <ShortcutAction>{};
    for (final entry in shortcuts.entries) {
      if (entry.value.isEmpty) continue;
      final previous = seen[entry.value];
      if (previous != null) {
        clashing..add(previous)..add(entry.key);
      } else {
        seen[entry.value] = entry.key;
      }
    }
    return clashing;
  }

  KeyCombo shortcutFor(ShortcutAction action) =>
      shortcuts[action] ?? defaultShortcuts[action] ?? const KeyCombo(key: '');

  AppSettings copyWith({
    bool? launchAtStartup,
    bool? closeToTray,
    String? defaultFolder,
    bool? autoDetectType,
    bool? reformatJsonOnSave,
    bool? maskCredentialValues,
    JotThemeMode? theme,
    bool? followSystemTheme,
    JotAccent? accent,
    double? textSize,
    bool? codeLigatures,
    ListDensity? density,
    int? previewLines,
    bool? showLineNumbers,
    Map<ShortcutAction, KeyCombo>? shortcuts,
    CapturePosition? capturePosition,
    bool? captureAlwaysOnTop,
    bool? prefillFromClipboard,
    String? captureFolder,
    bool? closeAfterSave,
    bool? autoTitle,
    bool? notifyAfterSave,
    bool? backupEnabled,
    BackupFrequency? backupFrequency,
    int? trashRetentionDays,
    UpdateChannel? updateChannel,
    bool? autoInstallUpdates,
  }) =>
      AppSettings(
        launchAtStartup: launchAtStartup ?? this.launchAtStartup,
        closeToTray: closeToTray ?? this.closeToTray,
        defaultFolder: defaultFolder ?? this.defaultFolder,
        autoDetectType: autoDetectType ?? this.autoDetectType,
        reformatJsonOnSave: reformatJsonOnSave ?? this.reformatJsonOnSave,
        maskCredentialValues: maskCredentialValues ?? this.maskCredentialValues,
        theme: theme ?? this.theme,
        followSystemTheme: followSystemTheme ?? this.followSystemTheme,
        accent: accent ?? this.accent,
        textSize: textSize ?? this.textSize,
        codeLigatures: codeLigatures ?? this.codeLigatures,
        density: density ?? this.density,
        previewLines: previewLines ?? this.previewLines,
        showLineNumbers: showLineNumbers ?? this.showLineNumbers,
        shortcuts: shortcuts ?? this.shortcuts,
        capturePosition: capturePosition ?? this.capturePosition,
        captureAlwaysOnTop: captureAlwaysOnTop ?? this.captureAlwaysOnTop,
        prefillFromClipboard: prefillFromClipboard ?? this.prefillFromClipboard,
        captureFolder: captureFolder ?? this.captureFolder,
        closeAfterSave: closeAfterSave ?? this.closeAfterSave,
        autoTitle: autoTitle ?? this.autoTitle,
        notifyAfterSave: notifyAfterSave ?? this.notifyAfterSave,
        backupEnabled: backupEnabled ?? this.backupEnabled,
        backupFrequency: backupFrequency ?? this.backupFrequency,
        trashRetentionDays: trashRetentionDays ?? this.trashRetentionDays,
        updateChannel: updateChannel ?? this.updateChannel,
        autoInstallUpdates: autoInstallUpdates ?? this.autoInstallUpdates,
      );

  Map<String, dynamic> toJson() => {
        'launchAtStartup': launchAtStartup,
        'closeToTray': closeToTray,
        'defaultFolder': defaultFolder,
        'autoDetectType': autoDetectType,
        'reformatJsonOnSave': reformatJsonOnSave,
        'maskCredentialValues': maskCredentialValues,
        'theme': theme.id,
        'followSystemTheme': followSystemTheme,
        'accent': accent.id,
        'textSize': textSize,
        'codeLigatures': codeLigatures,
        'density': density.id,
        'previewLines': previewLines,
        'showLineNumbers': showLineNumbers,
        'shortcuts': {
          for (final e in shortcuts.entries) e.key.id: e.value.toJson(),
        },
        'capturePosition': capturePosition.id,
        'captureAlwaysOnTop': captureAlwaysOnTop,
        'prefillFromClipboard': prefillFromClipboard,
        'captureFolder': captureFolder,
        'closeAfterSave': closeAfterSave,
        'autoTitle': autoTitle,
        'notifyAfterSave': notifyAfterSave,
        'backupEnabled': backupEnabled,
        'backupFrequency': backupFrequency.id,
        'trashRetentionDays': trashRetentionDays,
        'updateChannel': updateChannel.id,
        'autoInstallUpdates': autoInstallUpdates,
      };

  /// Tolerant of missing or malformed keys: a settings file written by an
  /// older build, or hand-edited, must never stop the app from starting.
  static AppSettings fromJson(Map<String, dynamic> json) {
    bool flag(String key, bool fallback) =>
        json[key] is bool ? json[key] as bool : fallback;

    final rawShortcuts = json['shortcuts'];
    final shortcuts = <ShortcutAction, KeyCombo>{...defaultShortcuts};
    if (rawShortcuts is Map) {
      for (final entry in rawShortcuts.entries) {
        final action = ShortcutAction.fromId('${entry.key}');
        if (action == null || entry.value is! Map) continue;
        shortcuts[action] =
            KeyCombo.fromJson(Map<String, dynamic>.from(entry.value as Map));
      }
    }

    return AppSettings(
      launchAtStartup: flag('launchAtStartup', true),
      closeToTray: flag('closeToTray', true),
      defaultFolder: '${json['defaultFolder'] ?? 'Inbox'}',
      autoDetectType: flag('autoDetectType', true),
      reformatJsonOnSave: flag('reformatJsonOnSave', false),
      maskCredentialValues: flag('maskCredentialValues', true),
      theme: JotThemeMode.fromId(json['theme'] as String?),
      followSystemTheme: flag('followSystemTheme', true),
      accent: JotAccent.fromId(json['accent'] as String?),
      textSize: ((json['textSize'] as num?)?.toDouble() ?? 13).clamp(11, 18),
      codeLigatures: flag('codeLigatures', true),
      density: ListDensity.fromId(json['density'] as String?),
      previewLines: ((json['previewLines'] as num?)?.toInt() ?? 2).clamp(0, 3),
      showLineNumbers: flag('showLineNumbers', true),
      shortcuts: shortcuts,
      capturePosition: CapturePosition.fromId(json['capturePosition'] as String?),
      captureAlwaysOnTop: flag('captureAlwaysOnTop', true),
      prefillFromClipboard: flag('prefillFromClipboard', true),
      captureFolder: '${json['captureFolder'] ?? 'Inbox'}',
      closeAfterSave: flag('closeAfterSave', true),
      autoTitle: flag('autoTitle', true),
      notifyAfterSave: flag('notifyAfterSave', false),
      backupEnabled: flag('backupEnabled', true),
      backupFrequency: BackupFrequency.fromId(json['backupFrequency'] as String?),
      trashRetentionDays:
          ((json['trashRetentionDays'] as num?)?.toInt() ?? 30).clamp(1, 365),
      updateChannel: UpdateChannel.fromId(json['updateChannel'] as String?),
      autoInstallUpdates: flag('autoInstallUpdates', true),
    );
  }
}
