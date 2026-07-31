import 'package:flutter/material.dart'
    show InputBorder, InputDecoration, TextField, showDialog;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../core/models/app_settings.dart';
import '../../core/models/note.dart';
import '../../core/models/note_type.dart';
import '../../core/theme/jot_theme.dart';
import '../../data/file_repository.dart';
import '../../data/settings_repository.dart';
import '../../widgets/code_viewer.dart';
import '../../widgets/jot_primitives.dart';
import '../main_window/widgets/prompt_dialog.dart';

/// The floating 540px capture panel.
///
/// Everything here is tuned for the few seconds it is meant to exist: it opens
/// focused, detects the content type as you type, saves on ⏎ and dismisses
/// itself. No confirmation, no dialogs — Esc throws the draft away.
///
/// It knows nothing about *how* it is hosted: the same widget backs the
/// separate OS window and the in-app fallback overlay.
class QuickCaptureWindow extends StatefulWidget {
  const QuickCaptureWindow({super.key, required this.onDismiss, this.onSaved});

  /// Closes the host — the OS window, or the overlay.
  final Future<void> Function() onDismiss;

  /// Lets an in-app host refresh its list without waiting for the watcher.
  final VoidCallback? onSaved;

  @override
  State<QuickCaptureWindow> createState() => _QuickCaptureWindowState();
}

class _QuickCaptureWindowState extends State<QuickCaptureWindow> {
  final _controller = TextEditingController();

  /// On the field's own node so plain ⏎ reaches [_save] instead of being
  /// turned into a newline by the multiline field.
  late final _focus = FocusNode(onKeyEvent: _onKey);

  NoteType _type = NoteType.text;

  /// Set once the user overrides the badge by hand; detection then stops
  /// fighting them.
  bool _typeLocked = false;

  String _folder = Folder.inbox;
  final List<String> _tags = [];
  bool _saving = false;
  String? _error;

  /// Read from disk rather than from a provider: this window runs in its own
  /// engine and shares no state with the main one.
  AppSettings _settings = const AppSettings();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final repository = await SettingsRepository.open();
    final settings = await repository.load();
    if (!mounted) return;

    // Pre-fill before the user starts typing, never after: overwriting what
    // they already wrote would be the opposite of a capture tool.
    String? clipboard;
    if (settings.prefillFromClipboard && _controller.text.isEmpty) {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      clipboard = data?.text?.trim();
    }

    if (!mounted) return;
    setState(() {
      _settings = settings;
      _folder = settings.captureFolder;
      if (clipboard != null && clipboard.isNotEmpty && _controller.text.isEmpty) {
        _controller.text = clipboard;
        _controller.selection =
            TextSelection.collapsed(offset: clipboard.length);
        if (!_typeLocked) _type = NoteTypeDetector.detect(clipboard);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    if (_typeLocked) return;
    final detected = NoteTypeDetector.detect(value);
    if (detected != _type) setState(() => _type = detected);
  }

  Future<void> _save() async {
    final content = _controller.text.trim();
    if (content.isEmpty || _saving) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      // The capture window runs in its own engine, so it writes the file
      // directly. The main window's watcher picks it up and indexes it within
      // ~220 ms — no cross-window plumbing needed.
      final files = await FileRepository.open();
      await files.create(
        content: content,
        // With auto-title off the note keeps a neutral name and the body is
        // left to speak for itself.
        title: _settings.autoTitle ? null : 'Note rapide',
        type: _type,
        folder: _folder,
        tags: _tags,
      );
      widget.onSaved?.call();

      if (_settings.closeAfterSave) {
        await _close();
      } else if (mounted) {
        // Stay open for a burst of captures: clear the field and keep focus.
        setState(() {
          _controller.clear();
          _saving = false;
          _type = NoteType.text;
          _typeLocked = false;
        });
        _focus.requestFocus();
      }
    } on Object catch (e) {
      // Never lose what the user typed — keep the window open with the text
      // intact and say what went wrong.
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Échec de l\'enregistrement : $e';
        });
      }
    }
  }

  Future<void> _close() => widget.onDismiss();

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    if (event.logicalKey == LogicalKeyboardKey.escape) {
      _close();
      return KeyEventResult.handled;
    }

    final isEnter = event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.numpadEnter;
    if (isEnter) {
      final pressed = HardwareKeyboard.instance.logicalKeysPressed;
      final newline = pressed.contains(LogicalKeyboardKey.shiftLeft) ||
          pressed.contains(LogicalKeyboardKey.shiftRight);
      // Shift+Enter inserts a newline; plain Enter saves — multi-line pastes
      // still work because a paste is not a key press.
      if (!newline) {
        _save();
        return KeyEventResult.handled;
      }
    }

    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: JotColors.palette,
          border: Border.all(color: JotColors.borderCapture),
          borderRadius: BorderRadius.circular(JotMetrics.captureRadius),
          boxShadow: JotColors.active.shadow(JotMetrics.captureShadow),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _TitleBar(onClose: _close),
            Expanded(child: _buildInput()),
            if (_error != null) _ErrorStrip(message: _error!),
            _buildFooter(),
          ],
        ),
      );

  Widget _buildInput() => ConstrainedBox(
        constraints: const BoxConstraints(minHeight: JotMetrics.captureBodyMinHeight),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          child: TextField(
            controller: _controller,
            focusNode: _focus,
            onChanged: _onChanged,
            maxLines: null,
            expands: true,
            autofocus: true,
            cursorColor: JotColors.accent,
            cursorWidth: 1.5,
            style: JotText.mono(size: 13, height: 1.7, color: JotColors.textPrimary),
            decoration: InputDecoration(
              border: InputBorder.none,
              isCollapsed: true,
              hintText: 'Note rapide...',
              hintStyle: JotText.ui(size: 12.5, height: 1.5, color: JotColors.textDisabled),
            ),
          ),
        ),
      );

  Widget _buildFooter() => Container(
        height: JotMetrics.captureFooterHeight,
        padding: const EdgeInsets.fromLTRB(16, 0, 12, 0),
        decoration: BoxDecoration(
          color: JotColors.footer,
          border: Border(top: BorderSide(color: JotColors.borderPalette)),
        ),
        child: Row(
          children: [
            Hoverable(
              onTap: _cycleType,
              builder: (context, _) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                decoration: BoxDecoration(
                  color: _type.badge.background,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  _typeLocked ? _type.label : '${_type.label} détecté',
                  style: JotText.mono(
                    size: 10,
                    weight: FontWeight.w500,
                    color: _type.badge.foreground,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 9),
            Hoverable(
              onTap: _pickFolder,
              builder: (context, _) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  border: Border.all(color: JotColors.borderRaised),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(
                  '$_folder ▾',
                  style: JotText.ui(size: 11, color: JotColors.textMuted),
                ),
              ),
            ),
            const SizedBox(width: 9),
            Flexible(
              child: Hoverable(
                onTap: _addTag,
                builder: (context, _) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(
                    border: Border.all(color: JotColors.borderRaised),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(
                    _tags.isEmpty ? '# tag' : _tags.map((t) => '#$t').join(' '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: JotText.mono(
                      size: 11,
                      color: _tags.isEmpty ? JotColors.textSubtle : JotColors.textMuted,
                    ),
                  ),
                ),
              ),
            ),
            const Spacer(),
            Text(
              'Esc annuler',
              style: JotText.mono(size: 10.5, color: JotColors.textSubtle),
            ),
            const SizedBox(width: 9),
            JotButton(
              _saving ? 'Enregistrement...' : 'Enregistrer',
              trailing: _saving ? null : 'Entrée',
              kind: _saving ? JotButtonKind.disabled : JotButtonKind.primary,
              onTap: _save,
            ),
          ],
        ),
      );

  void _cycleType() {
    final next = NoteType.values[(_type.index + 1) % NoteType.values.length];
    setState(() {
      _type = next;
      _typeLocked = true;
    });
  }

  Future<void> _pickFolder() async {
    final files = await FileRepository.open();
    final folders = await files.listFolders();
    if (!mounted) return;

    final picked = await showDialog<String>(
      context: context,
      barrierColor: JotColors.scrim,
      builder: (_) => FolderPickerDialog(folders: folders, current: _folder),
    );
    if (picked != null) setState(() => _folder = picked);
  }

  Future<void> _addTag() async {
    final tag = await showDialog<String>(
      context: context,
      barrierColor: JotColors.scrim,
      builder: (_) => const PromptDialog(
        title: 'Ajouter un tag',
        hint: 'api, snippet, creds...',
        confirmLabel: 'Ajouter',
        monospace: true,
      ),
    );
    final clean = tag?.trim().replaceFirst('#', '').toLowerCase();
    if (clean != null && clean.isNotEmpty && !_tags.contains(clean)) {
      setState(() => _tags.add(clean));
    }
  }
}

class _TitleBar extends StatelessWidget {
  const _TitleBar({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) => Container(
        height: JotMetrics.captureBarHeight,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: JotColors.captureBar,
          border: Border(bottom: BorderSide(color: JotColors.borderPalette)),
        ),
        child: Row(
          children: [
            Container(
              width: 11,
              height: 11,
              decoration: BoxDecoration(
                color: JotColors.accent,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(width: 9),
            Text(
              'Capture rapide',
              style: JotText.ui(
                size: 11,
                weight: FontWeight.w600,
                color: JotColors.textBody,
              ),
            ),
            const SizedBox(width: 9),
            Text(
              'Ctrl Alt N',
              style: JotText.mono(
                size: 10,
                weight: FontWeight.w500,
                color: JotColors.textSubtle,
              ),
            ),
            const Spacer(),
            Hoverable(
              onTap: onClose,
              builder: (context, hovered) => Text(
                '✕',
                style: JotText.ui(
                  size: 12,
                  color: hovered ? JotColors.textPrimary : JotColors.textDim,
                ),
              ),
            ),
          ],
        ),
      );
}

class _ErrorStrip extends StatelessWidget {
  const _ErrorStrip({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        color: JotColors.dangerBorder,
        child: InlineCode(
          message,
          maxLines: 2,
          style: JotText.mono(size: 10.5, height: 1.4, color: JotColors.danger),
        ),
      );
}
