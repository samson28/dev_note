import 'package:package_info_plus/package_info_plus.dart';

/// The version the running binary actually carries.
///
/// It used to be a constant repeated in five files, which drifted from
/// `pubspec.yaml` the moment either changed — the app claimed 1.4.0 while the
/// executable Windows would install said 1.0.0. That mismatch is invisible in
/// development and permanent in a release, so the number now comes from the
/// same place the installer reads it.
///
/// Loaded once at boot and held as a plain value, because a version string is
/// not something any screen should await.
abstract final class AppVersion {
  static String _name = '';
  static String _build = '';

  /// e.g. `1.4.0`.
  static String get name => _name;

  /// e.g. `1402`.
  static String get build => _build;

  /// `1.4.0 (build 1402)`, or just the version when there is no build number.
  static String get full => _build.isEmpty ? _name : '$_name (build $_build)';

  static Future<void> load() async {
    try {
      final info = await PackageInfo.fromPlatform();
      _name = info.version;
      _build = info.buildNumber;
    } on Object {
      // A missing version is a blank label, never a failed launch.
      _name = '';
      _build = '';
    }
  }
}
