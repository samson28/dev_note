import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Resolves where the vault and the search index live.
///
/// The vault is `~/JotVault/` on desktop, as specified. On mobile there is no
/// meaningful home directory, so it falls back to the app's documents folder.
abstract final class VaultPaths {
  static Directory? _cachedVault;
  static Directory? _cachedSupport;

  /// Left as `JotVault` on purpose. Renaming it to match the app would strand
  /// every note already in it, and the notes are the one thing here that is
  /// genuinely the user's. Anyone who wants the new name can rename the
  /// folder themselves and point the app at it.
  static const vaultFolderName = 'JotVault';
  static const indexFileName = 'index.sqlite';
  static const settingsFileName = 'settings.json';

  /// True when [vault] had to create the directory, i.e. this is a brand-new
  /// install. Used to decide whether to drop in the example notes — it can
  /// never be true for a vault that already holds the user's own files.
  static bool createdThisLaunch = false;

  /// The vault root, created on first access.
  static Future<Directory> vault() async {
    final cached = _cachedVault;
    if (cached != null) return cached;

    final home = _homeDirectory();
    final dir = home != null
        ? Directory(p.join(home, vaultFolderName))
        : Directory(
            p.join((await getApplicationDocumentsDirectory()).path, vaultFolderName),
          );

    if (!await dir.exists()) {
      await dir.create(recursive: true);
      createdThisLaunch = true;
    }
    return _cachedVault = dir;
  }

  /// Where the SQLite index is stored. Kept outside the vault so the vault
  /// holds nothing but the user's `.md` files and the watcher never sees
  /// SQLite's `-wal` / `-shm` churn.
  static Future<File> indexFile() async {
    final support = _cachedSupport ??= await getApplicationSupportDirectory();
    if (!await support.exists()) await support.create(recursive: true);
    return File(p.join(support.path, indexFileName));
  }

  /// Carries settings over from the support directory the app used when it
  /// was called Jot.
  ///
  /// Windows derives that directory from the executable's ProductName and
  /// CompanyName, so renaming the app moved it and left the old preferences
  /// behind. The index is not migrated: it is a cache and rebuilds itself in
  /// milliseconds, so copying it would only risk carrying a stale one over.
  ///
  /// Runs once — as soon as settings exist under the new name, there is
  /// nothing to do and this costs a single stat call.
  static Future<bool> migrateLegacySupportDirectory() async {
    if (!Platform.isWindows) return false;

    final support = _cachedSupport ??= await getApplicationSupportDirectory();
    final current = File(p.join(support.path, settingsFileName));
    if (await current.exists()) return false;

    final appData = Platform.environment['APPDATA'];
    if (appData == null || appData.isEmpty) return false;

    final legacy = File(p.join(appData, 'io.jot', 'jot', settingsFileName));
    if (!await legacy.exists()) return false;

    try {
      if (!await support.exists()) await support.create(recursive: true);
      await legacy.copy(current.path);
      return true;
    } on Object {
      // A failed migration means default settings, not a failed launch.
      return false;
    }
  }

  static String? _homeDirectory() {
    if (Platform.isAndroid || Platform.isIOS) return null;
    final env = Platform.environment;
    final home = Platform.isWindows
        ? (env['USERPROFILE'] ?? _windowsFallback(env))
        : env['HOME'];
    return (home == null || home.isEmpty) ? null : home;
  }

  static String? _windowsFallback(Map<String, String> env) {
    final drive = env['HOMEDRIVE'];
    final path = env['HOMEPATH'];
    if (drive == null || path == null) return null;
    return '$drive$path';
  }

  /// Turns a note title into a filesystem-safe base name.
  static String slugify(String title, {int maxLength = 60}) {
    final normalized = title
        .toLowerCase()
        .replaceAll(RegExp(r'[àáâãäå]'), 'a')
        .replaceAll(RegExp(r'[èéêë]'), 'e')
        .replaceAll(RegExp(r'[ìíîï]'), 'i')
        .replaceAll(RegExp(r'[òóôõö]'), 'o')
        .replaceAll(RegExp(r'[ùúûü]'), 'u')
        .replaceAll('ç', 'c')
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');

    final slug = normalized.isEmpty ? 'note' : normalized;
    return slug.length <= maxLength ? slug : slug.substring(0, maxLength);
  }
}
