import 'dart:io';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/models/app_settings.dart';
import 'core/theme/jot_theme.dart';
import 'state/settings_notifier.dart';
import 'features/main_window/main_window_screen.dart';
import 'features/mobile/mobile_shell.dart';
import 'features/quick_capture/quick_capture_hosts.dart';
import 'features/quick_capture/quick_capture_launcher.dart';
import 'state/jot_services.dart';

/// Every window runs this `main` in its own Flutter engine;
/// `WindowController.fromCurrentEngine()` says which one we are.
///
/// * The **main window** boots the vault, the index and the watcher, then
///   shows the three columns (or the mobile stack).
/// * The **capture window** stays deliberately thin — no index, no watcher,
///   it only writes a file — so it can appear in a fraction of a second,
///   which is the entire reason it exists.
Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  if (await _isQuickCaptureEngine()) {
    await configureCaptureWindow();
    runApp(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: JotTheme.build(),
        home: const QuickCaptureWindowHost(),
      ),
    );
    return;
  }

  // `--dart-define=JOT_FORCE_MOBILE=true` renders the mobile stack on the
  // desktop, so the phone layout can be worked on (and reviewed) without an
  // emulator in the loop.
  const forceMobile = bool.fromEnvironment('JOT_FORCE_MOBILE');

  final isDesktop = !kIsWeb &&
      !forceMobile &&
      (Platform.isWindows || Platform.isMacOS || Platform.isLinux);

  if (isDesktop) {
    await configureMainWindow();
  } else if (!kIsWeb && Platform.isWindows) {
    await configureMobilePreviewWindow();
  }

  final services = await JotServices.boot();

  if (isDesktop) {
    await QuickCaptureLauncher.registerHotKey();
  }

  runApp(
    ProviderScope(
      overrides: [servicesProvider.overrideWithValue(services)],
      child: JotApp(desktop: isDesktop),
    ),
  );
}

/// True when this engine was spawned as the capture sub-window.
///
/// On the main window the plugin has no definition to hand back, so any
/// failure here simply means "this is the main window".
Future<bool> _isQuickCaptureEngine() async {
  if (!QuickCaptureLauncher.supported) return false;
  try {
    final controller = await WindowController.fromCurrentEngine();
    if (!isQuickCaptureArguments(controller.arguments)) return false;
    await controller.attachControlHandler();
    return true;
  } on Object {
    return false;
  }
}

/// Watches the theme and accent settings, swaps the palette, and rebuilds.
///
/// This is the piece that makes theme switching real: [JotColors] is a set of
/// getters over a mutable palette, so changing it is only half the job — the
/// tree also has to be rebuilt, which happens because this widget watches the
/// two settings that feed [JotPalette.resolve].
class JotApp extends ConsumerWidget {
  const JotApp({super.key, required this.desktop});

  final bool desktop;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(settingsProvider.select((s) => s.theme));
    final follow = ref.watch(settingsProvider.select((s) => s.followSystemTheme));
    final accent = ref.watch(settingsProvider.select((s) => s.accent));

    // MediaQuery would need a context below MaterialApp; the platform
    // dispatcher gives the same value and updates through the same rebuild.
    final systemBrightness =
        View.of(context).platformDispatcher.platformBrightness;

    JotColors.apply(
      JotPalette.resolve(
        AppSettings(theme: theme, followSystemTheme: follow),
        systemBrightness,
      ).withAccent(accent),
    );

    return MaterialApp(
      title: 'Jot',
      debugShowCheckedModeBanner: false,
      theme: JotTheme.build(),
      // The palette is a mutable global, so swapping it marks nothing dirty:
      // Flutter would rebuild some widgets and leave others painted in the old
      // theme — a half-updated frame. Keying the subtree on the palette forces
      // the whole thing to be rebuilt at once. Widget State is discarded, but
      // the selection and scope live in Riverpod, so only scroll position is
      // lost — a fair price on an explicit theme change.
      home: KeyedSubtree(
        key: ValueKey('${JotColors.active.id}:${JotColors.accent.toARGB32()}'),
        child: desktop ? const MainWindowScreen() : const MobileShell(),
      ),
    );
  }
}
