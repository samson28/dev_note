import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../core/models/app_settings.dart';

/// Reads and writes `settings.json` next to the index.
///
/// Settings are applied immediately (the design's footer says so), so writes
/// are debounced rather than tied to a Save button, and a failed write never
/// blocks the UI, the in-memory value stays authoritative for the session.
class SettingsRepository {
  SettingsRepository(this.file);

  final File file;

  static Future<SettingsRepository> open() async {
    final dir = await getApplicationSupportDirectory();
    if (!await dir.exists()) await dir.create(recursive: true);
    return SettingsRepository(File(p.join(dir.path, 'settings.json')));
  }

  Future<AppSettings> load() async {
    try {
      if (!await file.exists()) return const AppSettings();
      final raw = await file.readAsString();
      if (raw.trim().isEmpty) return const AppSettings();
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return const AppSettings();
      return AppSettings.fromJson(Map<String, dynamic>.from(decoded));
    } on Object catch (e) {
      debugPrint('Dev Note: réglages illisibles ($e), valeurs par défaut');
      return const AppSettings();
    }
  }

  Future<void> save(AppSettings settings) async {
    try {
      const encoder = JsonEncoder.withIndent('  ');
      final temp = File('${file.path}.tmp');
      await temp.writeAsString(encoder.convert(settings.toJson()), flush: true);
      await temp.rename(file.path);
    } on Object catch (e) {
      debugPrint('Dev Note: impossible d\'enregistrer les réglages ($e)');
    }
  }
}
