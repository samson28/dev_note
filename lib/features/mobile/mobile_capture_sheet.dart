import 'package:flutter/material.dart'
    show InputBorder, InputDecoration, TextField, showModalBottomSheet;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/note_type.dart';
import '../../core/theme/jot_theme.dart';
import '../../state/settings_notifier.dart';
import '../../state/vault_notifier.dart';
import '../../widgets/jot_icons.dart';
import '../../widgets/jot_primitives.dart';
import '../../widgets/type_badge.dart';
import '../import/file_import.dart';

/// 4d, quick capture on the phone.
///
/// The desktop opens a window on a global hotkey; a phone has no hotkey, so
/// the "+" in the bottom bar raises this sheet instead. It exists rather than
/// pushing the editor because the whole promise is "ouvrir, écrire,
/// enregistrer en quelques secondes": a sheet keeps the list behind it and
/// costs no navigation.
Future<void> showCaptureSheet(BuildContext context, WidgetRef ref) =>
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0x00000000),
      barrierColor: JotColors.scrim,
      isScrollControlled: true,
      builder: (_) => const _CaptureSheet(),
    );

class _CaptureSheet extends ConsumerStatefulWidget {
  const _CaptureSheet();

  @override
  ConsumerState<_CaptureSheet> createState() => _CaptureSheetState();
}

class _CaptureSheetState extends ConsumerState<_CaptureSheet> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  late String _folder;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(settingsProvider);
    _folder = settings.captureFolder;
    if (settings.prefillFromClipboard) _prefill();
    // autofocus alone does not fire into an already-populated focus scope.
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  Future<void> _prefill() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text;
    if (text != null && text.trim().isNotEmpty && mounted) {
      _controller.text = text;
      setState(() {});
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final content = _controller.text.trim();
    if (content.isEmpty || _saving) return;
    setState(() => _saving = true);

    final settings = ref.read(settingsProvider);
    await ref.read(vaultProvider.notifier).create(
          content: content,
          folder: _folder,
          type: settings.autoDetectType ? null : NoteType.text,
        );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final text = _controller.text;
    final type = text.trim().isEmpty
        ? NoteType.text
        : NoteTypeDetector.detect(text);

    return Padding(
      // Lifts the sheet above the on-screen keyboard.
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        top: false,
        child: Container(
          margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
          decoration: BoxDecoration(
            color: JotColors.captureBar,
            border: Border.all(color: JotColors.borderCapture),
            borderRadius: BorderRadius.circular(14),
            boxShadow: JotColors.active.shadow(JotMetrics.trayShadow),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 10, 10),
                child: Row(
                  children: [
                    const Expanded(child: SectionLabel('Capture rapide')),
                    // A file is the other thing a person arrives with, so it
                    // belongs in the same sheet rather than behind a menu.
                    Hoverable(
                      onTap: () async {
                        final navigator = Navigator.of(context);
                        final count =
                            await pickAndImportFiles(ref, folder: _folder);
                        if (count > 0 && mounted) navigator.pop();
                      },
                      builder: (context, _) => JotIcon(
                        JotIcons.import_,
                        size: 17,
                        color: JotColors.textDim,
                      ),
                    ),
                    const SizedBox(width: 12),
                    TypeBadge(type),
                    const SizedBox(width: 10),
                    Hoverable(
                      onTap: () => Navigator.of(context).pop(),
                      builder: (context, _) => JotIcon(
                        JotIcons.close,
                        size: 17,
                        color: JotColors.textDim,
                      ),
                    ),
                  ],
                ),
              ),
              Hairline(color: JotColors.borderCapture),
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 120, maxHeight: 260),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  child: TextField(
                    controller: _controller,
                    focusNode: _focus,
                    maxLines: null,
                    expands: false,
                    keyboardType: TextInputType.multiline,
                    onChanged: (_) => setState(() {}),
                    cursorColor: JotColors.accent,
                    style: JotText.mono(
                      size: 13,
                      height: 1.55,
                      color: JotColors.textPrimary,
                    ),
                    decoration: InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                      hintText: 'Colle un extrait, une URL, du JSON...',
                      hintStyle: JotText.mono(
                        size: 13,
                        color: JotColors.textDisabled,
                      ),
                    ),
                  ),
                ),
              ),
              Hairline(color: JotColors.borderCapture),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 9, 10, 10),
                child: Row(
                  children: [
                    _FolderPill(
                      folder: _folder,
                      onPicked: (f) => setState(() => _folder = f),
                    ),
                    const Spacer(),
                    Hoverable(
                      onTap: _save,
                      builder: (context, _) => Container(
                        height: 40,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: text.trim().isEmpty
                              ? JotColors.neutralWash
                              : JotColors.accent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          'Enregistrer',
                          style: JotText.ui(
                            size: 13.5,
                            weight: FontWeight.w600,
                            color: text.trim().isEmpty
                                ? JotColors.textDisabled
                                : JotColors.onAccent,
                          ),
                        ),
                      ),
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

/// Cycles through the vault's folders rather than opening a picker: with a
/// handful of folders, one tap beats a dialog, and the destination is written
/// on the control itself.
class _FolderPill extends ConsumerWidget {
  const _FolderPill({required this.folder, required this.onPicked});

  final String folder;
  final ValueChanged<String> onPicked;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final folders = ref.watch(vaultProvider).folders.map((f) => f.name).toList();

    return Hoverable(
      onTap: () {
        if (folders.isEmpty) return;
        final next = (folders.indexOf(folder) + 1) % folders.length;
        onPicked(folders[next]);
      },
      builder: (context, hovered) => Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 13),
        decoration: BoxDecoration(
          color: hovered ? JotColors.neutralWash : null,
          border: Border.all(color: JotColors.borderCapture),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            JotIcon(JotIcons.folder, size: 14, color: JotColors.textDim),
            const SizedBox(width: 8),
            Text(
              folder,
              style: JotText.ui(size: 13, color: JotColors.textBody),
            ),
          ],
        ),
      ),
    );
  }
}
