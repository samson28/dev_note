import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

import '../quick_capture/quick_capture_launcher.dart';

/// 3d, the notification-area icon and its menu.
///
/// The point of a tray icon here is not decoration: it is what makes "fermer
/// réduit dans la zone de notification" mean something, and it is the one
/// place capture stays one click away when the window is not on screen.
/// Without it, that setting was a switch that did nothing.
class JotTray with TrayListener, WindowListener {
  JotTray._();

  static final instance = JotTray._();

  static bool get supported =>
      !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);

  /// Set by the main window so menu items can reach the UI. Kept as callbacks
  /// rather than a global navigator key because the tray outlives no widget:
  /// when the window is gone, these are simply null and the item is skipped.
  VoidCallback? onOpenSettings;

  bool _installed = false;

  /// Label of the global capture shortcut, shown beside the menu item so the
  /// menu teaches the faster way to do the same thing.
  String? _captureShortcut;

  Future<void> setCaptureShortcut(String label) async {
    if (_captureShortcut == label) return;
    _captureShortcut = label;
    if (_installed) await _buildMenu();
  }

  /// Whether closing the window should hide it instead of quitting. Mirrored
  /// from settings on every change.
  bool closeToTray = true;

  Future<void> install() async {
    if (!supported || _installed) return;

    try {
      // Windows wants an .ico; Linux hands the path to AppIndicator, which
      // reads PNG and not ICO. Passing the wrong one fails silently into the
      // catch below and the app simply has no tray.
      await trayManager.setIcon(
        Platform.isWindows ? 'assets/icons/tray.ico' : 'assets/icons/logo_64.png',
      );
      await trayManager.setToolTip('Dev Note');
      await _buildMenu();

      trayManager.addListener(this);
      windowManager.addListener(this);
      // Required for onWindowClose to fire at all; without it the window
      // closes before we can decide to hide it instead.
      await windowManager.setPreventClose(true);
      _installed = true;
    } on Object catch (e) {
      // A missing tray (some Linux sessions have none) must not stop the app.
      debugPrint('Dev Note: zone de notification indisponible ($e)');
    }
  }

  Future<void> _buildMenu() => trayManager.setContextMenu(
        Menu(
          items: [
            MenuItem(
              key: _capture,
              label: _captureShortcut == null
                  ? 'Capture rapide'
                  : 'Capture rapide\t$_captureShortcut',
            ),
            MenuItem(key: _show, label: 'Ouvrir Dev Note'),
            MenuItem.separator(),
            MenuItem(key: _settings, label: 'Réglages'),
            MenuItem.separator(),
            MenuItem(key: _quit, label: 'Quitter'),
          ],
        ),
      );

  static const _capture = 'capture';
  static const _show = 'show';
  static const _settings = 'settings';
  static const _quit = 'quit';

  /// Brings the window back from the tray.
  ///
  /// Hiding is the only way out of the window once close-to-tray is on, so
  /// this path has to work from every state it can be left in: hidden,
  /// minimised, or merely behind something else.
  Future<void> showWindow() async {
    if (await windowManager.isMinimized()) await windowManager.restore();
    await windowManager.setSkipTaskbar(false);
    await windowManager.show();
    await windowManager.focus();
  }

  @override
  void onTrayIconMouseDown() {
    // Left click restores the window: the menu is a right click, and making
    // the common case wait for a menu would be pure friction.
    showWindow();
  }

  @override
  void onTrayIconRightMouseDown() {
    trayManager.popUpContextMenu();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    switch (menuItem.key) {
      case _capture:
        QuickCaptureLauncher.open();
      case _show:
        showWindow();
      case _settings:
        // Settings live inside the main window, so it has to be up first.
        showWindow().then((_) => onOpenSettings?.call());
      case _quit:
        _quit_();
    }
  }

  @override
  void onWindowClose() {
    if (closeToTray) {
      windowManager.hide();
      return;
    }
    _quit_();
  }

  Future<void> _quit_() async {
    await dispose();
    await windowManager.setPreventClose(false);
    await windowManager.destroy();
  }

  Future<void> dispose() async {
    if (!_installed) return;
    trayManager.removeListener(this);
    windowManager.removeListener(this);
    await trayManager.destroy();
    _installed = false;
  }
}
