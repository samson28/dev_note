import 'dart:convert';
import 'dart:io';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:window_manager/window_manager.dart';

import '../../core/theme/jot_theme.dart';

/// Marker written into the sub-window's `arguments` so every engine can tell
/// which window it is running.
const kQuickCaptureArguments = '{"mode":"quick_capture"}';

bool isQuickCaptureArguments(String arguments) {
  if (arguments.isEmpty) return false;
  try {
    final decoded = jsonDecode(arguments);
    return decoded is Map && decoded['mode'] == 'quick_capture';
  } on FormatException {
    return false;
  }
}

/// `desktop_multi_window` 0.3 gives each window its own engine but no window
/// geometry API, so the sub-window sizes and closes *itself* through
/// `window_manager`. These are the calls the parent needs to reach across.
extension QuickCaptureWindowControl on WindowController {
  Future<void> attachControlHandler() =>
      setWindowMethodHandler((call) async => switch (call.method) {
            'window_close' => windowManager.close(),
            'window_focus' => windowManager.focus(),
            _ => throw MissingPluginException('Not implemented: ${call.method}'),
          });

  Future<void> requestClose() => invokeMethod<void>('window_close');
  Future<void> requestFocus() => invokeMethod<void>('window_focus');
}

/// Opens the capture window and owns the global hotkey.
///
/// The window is a real OS window rather than an in-app overlay, because the
/// whole point is capturing *without* leaving the task at hand — the main
/// window may well be minimised. If the platform refuses to give us one,
/// [open] reports failure and the main window falls back to an in-app panel;
/// capture is the one thing that must never be unavailable.
abstract final class QuickCaptureLauncher {
  /// `Ctrl + Alt + N`, written `Ctrl Alt N` in the design.
  static final _hotKey = HotKey(
    key: PhysicalKeyboardKey.keyN,
    modifiers: [HotKeyModifier.control, HotKeyModifier.alt],
    scope: HotKeyScope.system,
  );

  static bool get supported =>
      !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);

  /// Called when [open] cannot produce an OS window, so the host can show the
  /// in-app panel instead.
  static VoidCallback? onFallback;

  /// Registers the system-wide shortcut. Failure is non-fatal: another app may
  /// already own the combination, and the in-app binding still works.
  static Future<void> registerHotKey() async {
    if (!supported) return;
    try {
      await hotKeyManager.unregisterAll();
      await hotKeyManager.register(_hotKey, keyDownHandler: (_) => open());
    } on Object catch (e) {
      debugPrint('Jot: raccourci global indisponible ($e)');
    }
  }

  /// Shows the capture window, reusing it if it is already up.
  /// Returns false when no OS window could be shown.
  static Future<bool> open() async {
    if (!supported) {
      onFallback?.call();
      return false;
    }

    try {
      for (final controller in await WindowController.getAll()) {
        if (isQuickCaptureArguments(controller.arguments)) {
          await controller.show();
          await controller.requestFocus();
          return true;
        }
      }

      final controller = await WindowController.create(
        const WindowConfiguration(
          arguments: kQuickCaptureArguments,
          hiddenAtLaunch: true,
        ),
      );
      // The sub-window sizes and centres itself once its engine is up; show()
      // after creation avoids a flash of an unsized window.
      await controller.show();
      return true;
    } on Object catch (e) {
      debugPrint('Jot: capture en fenêtre séparée indisponible ($e) — repli en overlay');
      onFallback?.call();
      return false;
    }
  }

  static Future<void> dispose() async {
    if (!supported) return;
    try {
      await hotKeyManager.unregisterAll();
    } on Object {
      // Nothing useful to do at shutdown.
    }
  }
}

/// Configures the main window: hidden OS title bar, the design's size, and a
/// minimum below which the three columns stop making sense.
Future<void> configureMainWindow() async {
  await windowManager.ensureInitialized();

  final options = WindowOptions(
    size: JotMetrics.windowSize,
    minimumSize: JotMetrics.windowMinSize,
    center: true,
    backgroundColor: JotColors.window,
    titleBarStyle: TitleBarStyle.hidden,
    title: 'Jot',
  );

  await windowManager.waitUntilReadyToShow(options, () async {
    await windowManager.show();
    await windowManager.focus();
  });
}

/// Sizes the window to a phone when the mobile stack is previewed on desktop.
Future<void> configureMobilePreviewWindow() async {
  await windowManager.ensureInitialized();

  final options = WindowOptions(
    size: Size(390, 844),
    center: true,
    backgroundColor: JotColors.window,
    title: 'Jot, aperçu mobile',
  );

  await windowManager.waitUntilReadyToShow(options, () async {
    await windowManager.show();
    await windowManager.focus();
  });
}

/// Configures the capture sub-window from inside its own engine: frameless,
/// fixed to the design's 540px, floating above other apps and out of the
/// taskbar, so it reads as a HUD rather than a second app.
Future<void> configureCaptureWindow() async {
  await windowManager.ensureInitialized();

  const options = WindowOptions(
    size: JotMetrics.captureSize,
    center: true,
    backgroundColor: Color(0x00000000),
    skipTaskbar: true,
    titleBarStyle: TitleBarStyle.hidden,
    alwaysOnTop: true,
    title: 'Jot, capture rapide',
  );

  await windowManager.waitUntilReadyToShow(options, () async {
    await windowManager.setAsFrameless();
    await windowManager.setResizable(false);
    await windowManager.show();
    await windowManager.focus();
  });
}
