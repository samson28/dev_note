import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart' show Scaffold;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/app_settings.dart';
import '../../core/models/key_binding.dart';
import '../../core/theme/jot_theme.dart';
import '../../state/settings_notifier.dart';
import '../../widgets/json_viewer.dart' show copyToClipboard;
import 'widgets/note_context_menu.dart';
import '../../state/search_notifier.dart';
import '../../state/vault_notifier.dart';
import '../../widgets/jot_icons.dart';
import '../../widgets/jot_primitives.dart';
import '../import/file_import.dart';
import '../quick_capture/quick_capture_hosts.dart';
import '../quick_capture/quick_capture_launcher.dart';
import '../search_palette/search_palette.dart';
import '../settings/settings_window.dart';
import '../tray/jot_tray.dart';
import 'widgets/editor_pane.dart';
import 'widgets/note_list_pane.dart';
import 'widgets/sidebar.dart';
import 'widgets/title_bar.dart';
import 'widgets/trash_pane.dart';

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
    JotTray.instance.onOpenSettings = () {
      if (mounted) showSettings(context);
    };
  }

  @override
  void dispose() {
    QuickCaptureLauncher.onFallback = null;
    JotTray.instance.onOpenSettings = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(vaultProvider);
    final paletteOpen = ref.watch(searchProvider.select((s) => s.open));

    return Scaffold(
      backgroundColor: JotColors.window,
      body: _DropZone(
        onDropped: (paths) async {
          final count =
              await ref.read(vaultProvider.notifier).importFiles(paths);
          if (count > 0) {
            ref.read(vaultProvider.notifier).notify(
                  count == 1
                      ? 'Fichier importé'
                      : '$count fichiers importés',
                );
          }
        },
        child: _Shortcuts(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            JotTitleBar(
              scopeLabel: state.scope.label,
              noteCount: state.scope is TrashScope ? -1 : state.notes.length,
            ),
            if (state.notice != null) _NoticeBar(message: state.notice!),
            Expanded(
              child: Stack(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: state.scope is TrashScope
                        ? const [Sidebar(), TrashPane()]
                        : const [Sidebar(), NoteListPane(), EditorPane()],
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
      ),
    );
  }
}

/// Wraps the window so files dragged from the file manager land in the vault.
///
/// This is the fastest import path there is — no dialog, no folder to
/// navigate — so it covers the whole window rather than a designated strip.
class _DropZone extends StatefulWidget {
  const _DropZone({required this.child, required this.onDropped});

  final Widget child;
  final ValueChanged<List<String>> onDropped;

  @override
  State<_DropZone> createState() => _DropZoneState();
}

class _DropZoneState extends State<_DropZone> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    if (!supportsFileDrop) return widget.child;

    return DropTarget(
      onDragEntered: (_) => setState(() => _hovering = true),
      onDragExited: (_) => setState(() => _hovering = false),
      onDragDone: (detail) {
        setState(() => _hovering = false);
        final paths = detail.files.map((f) => f.path).toList();
        if (paths.isNotEmpty) widget.onDropped(paths);
      },
      child: Stack(
        children: [
          widget.child,
          // Kept mounted so it fades rather than snapping over the window.
          // Short, because the answer to "will this accept my file?" should
          // not be made to wait.
          AnimatedOpacity(
            opacity: _hovering ? 1 : 0,
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOut,
            child: const DropTargetOverlay(),
          ),
        ],
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
              builder: (context, hovered) => JotIcon(
                JotIcons.close,
                size: 12,
                color: hovered ? JotColors.textPrimary : JotColors.textSubtle,
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

  /// Built from the user's bindings rather than hardcoded, so rebinding in the
  /// Raccourcis tab actually takes effect. Combinations whose label cannot be
  /// resolved to a key are skipped instead of throwing.
  Map<ShortcutActivator, Intent> _bindings(AppSettings settings) {
    final map = <ShortcutActivator, Intent>{};

    void bind(ShortcutAction action, Intent intent) {
      final activator = settings.shortcutFor(action).activator;
      if (activator != null) map[activator] = intent;
    }

    bind(ShortcutAction.searchPalette, const _OpenPaletteIntent());
    bind(ShortcutAction.newNote, const _NewNoteIntent());
    bind(ShortcutAction.quickCapture, const _QuickCaptureIntent());
    bind(ShortcutAction.pinNote, const _TogglePinIntent());
    bind(ShortcutAction.deleteNote, const _DeleteNoteIntent());
    bind(ShortcutAction.copyNote, const _CopyNoteIntent());

    // Ctrl+, is conventional for preferences and is not user-rebindable.
    map[const SingleActivator(LogicalKeyboardKey.comma, control: true)] =
        const _SettingsIntent();
    // Escape closes the note and shows the home panel. The palette handles its
    // own Escape on its focus node, so this never fires while it is open.
    map[const SingleActivator(LogicalKeyboardKey.escape)] = const _HomeIntent();

    return map;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) => Shortcuts(
        shortcuts: _bindings(ref.watch(settingsProvider)),
        child: Actions(
          actions: {
            _HomeIntent: CallbackAction<_HomeIntent>(
              onInvoke: (_) {
                ref.read(vaultProvider.notifier).closeNote();
                return null;
              },
            ),
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
            _DeleteNoteIntent: CallbackAction<_DeleteNoteIntent>(
              onInvoke: (_) {
                final note = ref.read(vaultProvider).openNote;
                if (note != null) {
                  confirmDeleteNote(context, note).then((confirmed) {
                    if (confirmed == true) {
                      ref.read(vaultProvider.notifier).delete(note);
                    }
                  });
                }
                return null;
              },
            ),
            _CopyNoteIntent: CallbackAction<_CopyNoteIntent>(
              onInvoke: (_) {
                final note = ref.read(vaultProvider).openNote;
                if (note != null) copyToClipboard(note.content);
                return null;
              },
            ),
          },
          child: Focus(autofocus: true, child: child),
        ),
      );
}

class _HomeIntent extends Intent {
  const _HomeIntent();
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

class _DeleteNoteIntent extends Intent {
  const _DeleteNoteIntent();
}

class _CopyNoteIntent extends Intent {
  const _CopyNoteIntent();
}
