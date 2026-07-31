import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

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

  /// Not final, and deliberately so: [switchVault] rebuilds the data layer in
  /// place. Everything in the app holds this one [JotServices] instance and
  /// reads through it, so replacing the pieces here is what lets the vault
  /// move without a relaunch — and without turning a service locator into
  /// something every call site has to watch.
  FileRepository files;
  JotDatabase db;
  IndexRepository index;
  FileWatcherService watcher;

  final SettingsRepository settings;

  /// Settings as read from disk at boot; [SettingsNotifier] owns them after.
  final AppSettings initialSettings;

  static Future<JotServices> boot() async {
    // Before the settings are read, not after: the app was renamed and the
    // preferences are sitting in the directory the old name resolved to.
    await VaultPaths.migrateLegacySupportDirectory();

    // Settings first now, because they say where the vault is.
    final settings = await SettingsRepository.open();
    final initialSettings = await settings.load();

    final files = await FileRepository.open(vaultPath: initialSettings.vaultPath);
    await files.ensureScaffold();

    if (VaultPaths.createdThisLaunch) {
      await SampleNotes.seed(files);
    }

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

  /// Points the app at a different vault, without a relaunch.
  ///
  /// [move] copies the current notes across first; without it the folder is
  /// adopted as-is, which is what someone reconnecting to a vault their cloud
  /// client already restored on another machine wants.
  ///
  /// The index is rebuilt rather than carried over: it describes files that
  /// are no longer the ones being watched.
  Future<void> switchVault(String? path, {bool move = false}) async {
    final target = await VaultPaths.vault(override: path);
    if (p.equals(target.path, files.root.path)) return;

    if (move) {
      // Throws when the copy comes up short, leaving the old vault in place.
      await files.moveVaultTo(target);
    }

    await watcher.dispose();
    await db.close();

    VaultPaths.invalidate();
    files = FileRepository(target);
    await files.ensureScaffold();

    final indexFile = await VaultPaths.indexFile();
    final (freshDb, freshIndex) = await _openIndex(files, indexFile);
    db = freshDb;
    index = freshIndex;
    await index.synchronise(force: true);

    watcher = FileWatcherService(files, index);
    await watcher.start();
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
