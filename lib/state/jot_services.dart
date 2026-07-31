import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/models/app_settings.dart';
import '../data/settings_repository.dart';
import '../data/database.dart';
import '../data/file_repository.dart';
import '../data/file_watcher_service.dart';
import '../data/index_repository.dart';
import '../data/vault_paths.dart';
import 'sample_notes.dart';

/// Everything the app needs from the disk, wired together once at startup.
///
/// Built before `runApp` so the first frame already has a warm index — the
/// window must be usable the instant it appears.
class JotServices {
  JotServices({
    required this.files,
    required this.db,
    required this.index,
    required this.watcher,
    required this.settings,
    required this.initialSettings,
  });

  final FileRepository files;
  final JotDatabase db;
  final IndexRepository index;
  final FileWatcherService watcher;
  final SettingsRepository settings;

  /// Settings as read from disk at boot; [SettingsNotifier] owns them after.
  final AppSettings initialSettings;

  static Future<JotServices> boot() async {
    final files = await FileRepository.open();
    await files.ensureScaffold();

    if (VaultPaths.createdThisLaunch) {
      await SampleNotes.seed(files);
    }

    // Before the settings are read, not after: the app was renamed and the
    // preferences are sitting in the directory the old name resolved to.
    await VaultPaths.migrateLegacySupportDirectory();

    final settings = await SettingsRepository.open();
    final initialSettings = await settings.load();

    // Trash retention is enforced once per launch rather than on a timer:
    // the window is 30 days by default, so precision is irrelevant and a
    // background timer would be pure overhead.
    unawaited(files.purgeExpiredTrash(initialSettings.trashRetentionDays));

    final indexFile = await VaultPaths.indexFile();
    final (db, index) = await _openIndex(files, indexFile);

    final watcher = FileWatcherService(files, index);
    await watcher.start();

    return JotServices(
      files: files,
      db: db,
      index: index,
      watcher: watcher,
      settings: settings,
      initialSettings: initialSettings,
    );
  }

  /// Opens the index, and if anything about it is unusable — missing columns,
  /// a truncated file, a half-written page — deletes it and builds a fresh one
  /// from the vault.
  ///
  /// The files on disk are the only source of truth, so a broken cache is
  /// never a reason to fail a launch.
  static Future<(JotDatabase, IndexRepository)> _openIndex(
    FileRepository files,
    File indexFile,
  ) async {
    JotDatabase? failed;
    try {
      final db = failed = JotDatabase.atFile(indexFile);
      final index = IndexRepository(db, files);
      await index.synchronise();
      return (db, index);
    } on Object catch (e) {
      debugPrint('Dev Note: index inutilisable ($e), reconstruction complète');

      // Close the broken connection first. Opening a second one over the same
      // file while the first is live races on the executor and hangs the boot.
      try {
        await failed?.close();
      } on Object {
        // Already unusable; nothing to salvage.
      }

      try {
        if (await indexFile.exists()) await indexFile.delete();
        for (final suffix in const ['-wal', '-shm', '-journal']) {
          final sidecar = File('${indexFile.path}$suffix');
          if (await sidecar.exists()) await sidecar.delete();
        }
      } on Object {
        // If it cannot even be deleted, the retry below will surface it.
      }

      final db = JotDatabase.atFile(indexFile);
      final index = IndexRepository(db, files);
      await index.synchronise(force: true);
      return (db, index);
    }
  }

  Future<void> dispose() async {
    await watcher.dispose();
    await db.close();
  }
}

/// Overridden in `main()` once [JotServices.boot] has completed.
final servicesProvider = Provider<JotServices>(
  (ref) => throw StateError('servicesProvider must be overridden in main()'),
);
