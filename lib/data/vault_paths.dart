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

  static const vaultFolderName = 'JotVault';
  static const indexFileName = 'index.sqlite';

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
