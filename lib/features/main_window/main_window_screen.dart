import 'package:flutter/material.dart' show Scaffold;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/jot_theme.dart';
import '../../state/search_notifier.dart';
import '../../state/vault_notifier.dart';
import '../../widgets/jot_primitives.dart';
import '../quick_capture/quick_capture_hosts.dart';
import '../quick_capture/quick_capture_launcher.dart';
import '../search_palette/search_palette.dart';
import '../settings/settings_window.dart';
import 'widgets/editor_pane.dart';
import 'widgets/note_list_pane.dart';
import 'widgets/sidebar.dart';
import 'widgets/title_bar.dart';

/// The desktop shell: title bar on top, three columns below, with the search
/// palette (and, if needed, the capture fallback) layered over everything.
class MainWindowScreen extends ConsumerStatefulWidget {
  const MainWindowScreen({super.key});

  @override
  ConsumerState<MainWindowScreen> createState() => _MainWindowScreenState();
}

class _MainWindowScreenState extends ConsumerState<MainWindowScreen> {
  /// Shown only when the platform could not give us a separate capture window.
  bool _captureOverlay = false;

  @override
  void initState() {
    super.initState();
    QuickCaptureLauncher.onFallback = () {
      if (mounted) setState(() => _captureOverlay = true);
    };
  }

  @override
  void dispose() {
    QuickCaptureLauncher.onFallback = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(vaultProvider);
    final paletteOpen = ref.watch(searchProvider.select((s) => s.open));

    return Scaffold(
      backgroundColor: JotColors.window,
      body: _Shortcuts(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            JotTitleBar(
              scopeLabel: state.scope.label,
              noteCount: state.notes.length,
            ),
            if (state.notice != null) _NoticeBar(message: state.notice!),
            Expanded(
              child: Stack(
                children: [
                  const Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [Sidebar(), NoteListPane(), EditorPane()],
                  ),
                  if (paletteOpen) const SearchPalette(),
                  if (_captureOverlay)
                    QuickCaptureOverlay(
                      onDismiss: () => setState(() => _captureOverlay = false),
                      onSaved: () => ref.read(vaultProvider.notifier).refresh(),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A thin strip for non-blocking problems — unreadable files, a rebuilt index.
///
/// Deliberately not a dialog: nothing here is worth interrupting a capture for.
class _NoticeBar extends ConsumerWidget {
  const _NoticeBar({required this.message});

  final String message;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Container(
        height: 26,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: JotColors.field,
          border: Border(bottom: BorderSide(color: JotColors.borderSubtle)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                message,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: JotText.ui(size: 11, color: JotColors.textDim),
              ),
            ),
            Hoverable(
              onTap: () => ref.read(vaultProvider.notifier).rebuildIndex(),
              builder: (context, hovered) => Text(
                'Reconstruire l\'index',
                style: JotText.ui(
                  size: 11,
                  color: hovered ? JotColors.accent : JotColors.textSubtle,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Hoverable(
              onTap: () => ref.read(vaultProvider.notifier).dismissNotice(),
              builder: (context, hovered) => Text(
                '✕',
                style: JotText.ui(
                  size: 11,
                  color: hovered ? JotColors.textPrimary : JotColors.textSubtle,
                ),
              ),
            ),
          ],
        ),
      );
}

/// Global bindings for the main window.
///
/// `Ctrl` doubles for `⌘` on Windows and Linux; the design writes the macOS
/// glyphs, and both are accepted so the labels stay honest on every platform.
class _Shortcuts extends ConsumerWidget {
  const _Shortcuts({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Shortcuts(
        shortcuts: const {
          SingleActivator(LogicalKeyboardKey.keyK, control: true): _OpenPaletteIntent(),
          SingleActivator(LogicalKeyboardKey.keyK, meta: true): _OpenPaletteIntent(),
          SingleActivator(LogicalKeyboardKey.keyN, control: true): _NewNoteIntent(),
          SingleActivator(LogicalKeyboardKey.keyN, meta: true): _NewNoteIntent(),
          SingleActivator(LogicalKeyboardKey.keyN, control: true, alt: true):
              _QuickCaptureIntent(),
          SingleActivator(LogicalKeyboardKey.keyP, control: true): _TogglePinIntent(),
          SingleActivator(LogicalKeyboardKey.keyP, meta: true): _TogglePinIntent(),
          SingleActivator(LogicalKeyboardKey.comma, control: true): _SettingsIntent(),
          SingleActivator(LogicalKeyboardKey.comma, meta: true): _SettingsIntent(),
        },
        child: Actions(
          actions: {
            _OpenPaletteIntent: CallbackAction<_OpenPaletteIntent>(
              onInvoke: (_) {
                ref.read(searchProvider.notifier).openPalette();
                return null;
              },
            ),
            _NewNoteIntent: CallbackAction<_NewNoteIntent>(
              onInvoke: (_) {
                ref.read(vaultProvider.notifier).create();
                return null;
              },
            ),
            _QuickCaptureIntent: CallbackAction<_QuickCaptureIntent>(
              onInvoke: (_) {
                QuickCaptureLauncher.open();
                return null;
              },
            ),
            _TogglePinIntent: CallbackAction<_TogglePinIntent>(
              onInvoke: (_) {
                final note = ref.read(vaultProvider).openNote;
                if (note != null) ref.read(vaultProvider.notifier).togglePin(note);
                return null;
              },
            ),
            _SettingsIntent: CallbackAction<_SettingsIntent>(
              onInvoke: (_) {
                showSettings(context);
                return null;
              },
            ),
          },
          child: Focus(autofocus: true, child: child),
        ),
      );
}

class _OpenPaletteIntent extends Intent {
  const _OpenPaletteIntent();
}

class _NewNoteIntent extends Intent {
  const _NewNoteIntent();
}

class _QuickCaptureIntent extends Intent {
  const _QuickCaptureIntent();
}

class _TogglePinIntent extends Intent {
  const _TogglePinIntent();
}

class _SettingsIntent extends Intent {
  const _SettingsIntent();
}
