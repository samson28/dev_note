import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/models/app_settings.dart';
import 'jot_services.dart';

/// Holds [AppSettings] and writes them back to disk.
///
/// The Réglages window says "réglages appliqués immédiatement", so there is no
/// Save button: every change updates the state synchronously and schedules a
/// debounced write, which keeps dragging a slider from hammering the disk.
class SettingsNotifier extends Notifier<AppSettings> {
  late final JotServices _services;
  Timer? _writeDebounce;

  @override
  AppSettings build() {
    _services = ref.watch(servicesProvider);
    ref.onDispose(() => _writeDebounce?.cancel());
    return _services.initialSettings;
  }

  void update(AppSettings Function(AppSettings) change) {
    state = change(state);
    _scheduleWrite();
  }

  void _scheduleWrite() {
    _writeDebounce?.cancel();
    _writeDebounce = Timer(
      const Duration(milliseconds: 300),
      () => _services.settings.save(state),
    );
  }

  /// Writes immediately — used when closing the settings window.
  Future<void> flush() async {
    _writeDebounce?.cancel();
    await _services.settings.save(state);
  }

  void resetAll() => update((_) => const AppSettings());

  void resetShortcuts() =>
      update((s) => s.copyWith(shortcuts: AppSettings.defaultShortcuts));

  void setShortcut(ShortcutAction action, KeyCombo combo) => update(
        (s) => s.copyWith(shortcuts: {...s.shortcuts, action: combo}),
      );
}

final settingsProvider =
    NotifierProvider<SettingsNotifier, AppSettings>(SettingsNotifier.new);
