import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/models/note.dart';
import '../core/theme/jot_theme.dart';
import '../core/utils/jot_format.dart';
import 'jot_icons.dart';
import 'jot_primitives.dart';

/// What an imported binary looks like inside the editor column.
///
/// Jot does not try to render PDFs or images: a viewer it does not own would
/// be slower than the one the user already has, and the promise here is
/// retrieval, not display. So this states plainly what the file is, and hands
/// it to the system on request.
class AttachmentView extends StatefulWidget {
  const AttachmentView({super.key, required this.note, required this.file});

  final Note note;

  /// Absolute path of the copy inside the vault. Null when the vault has been
  /// moved or the file was removed by hand.
  final File? file;

  @override
  State<AttachmentView> createState() => _AttachmentViewState();
}

class _AttachmentViewState extends State<AttachmentView> {
  bool? _exists;

  @override
  void initState() {
    super.initState();
    _check();
  }

  @override
  void didUpdateWidget(AttachmentView old) {
    super.didUpdateWidget(old);
    if (old.file?.path != widget.file?.path) _check();
  }

  Future<void> _check() async {
    final exists = await widget.file?.exists() ?? false;
    if (mounted) setState(() => _exists = exists);
  }

  Future<void> _open() async {
    final file = widget.file;
    if (file == null) return;
    await launchUrl(Uri.file(file.path));
  }

  Future<void> _reveal() async {
    final file = widget.file;
    if (file == null) return;
    // Selecting the file in the OS file manager, rather than just opening its
    // folder, so the user can drag it straight out to somewhere else.
    if (Platform.isWindows) {
      await Process.run('explorer.exe', ['/select,', file.path]);
    } else if (Platform.isMacOS) {
      await Process.run('open', ['-R', file.path]);
    } else {
      await launchUrl(Uri.file(file.parent.path));
    }
  }

  @override
  Widget build(BuildContext context) {
    final note = widget.note;
    final missing = _exists == false;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
          decoration: BoxDecoration(
            color: JotColors.raised,
            border: Border.all(color: JotColors.borderRaised),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 62,
                height: 62,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: JotColors.active.badgeFile.background,
                  border: Border.all(
                    color: JotColors.active.badgeFile.outline ??
                        JotColors.borderRaised,
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  note.attachmentExtension ?? 'BIN',
                  maxLines: 1,
                  style: JotText.mono(
                    size: 12,
                    weight: FontWeight.w600,
                    color: JotColors.active.badgeFile.foreground,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                note.attachmentName ?? note.title,
                textAlign: TextAlign.center,
                style: JotText.ui(
                  size: 14,
                  weight: FontWeight.w600,
                  color: JotColors.textBright,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                missing
                    ? 'Fichier introuvable dans le coffre'
                    : JotFormat.bytes(note.attachmentBytes),
                style: JotText.mono(
                  size: 11.5,
                  color: missing ? JotColors.danger : JotColors.textFaint,
                ),
              ),
              const SizedBox(height: 18),
              if (!missing)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _Button(
                      icon: JotIcons.open,
                      label: 'Ouvrir',
                      primary: true,
                      onTap: _open,
                    ),
                    const SizedBox(width: 9),
                    _Button(
                      icon: JotIcons.folder,
                      label: 'Afficher le fichier',
                      onTap: _reveal,
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Button extends StatelessWidget {
  const _Button({
    required this.icon,
    required this.label,
    required this.onTap,
    this.primary = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) => Hoverable(
        onTap: onTap,
        builder: (context, hovered) => Container(
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: primary
                ? JotColors.accent
                : (hovered ? JotColors.neutralWash : null),
            border: primary ? null : Border.all(color: JotColors.borderRaised),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              JotIcon(
                icon,
                size: 14,
                color: primary ? JotColors.onAccent : JotColors.textBody,
              ),
              const SizedBox(width: 7),
              Text(
                label,
                style: JotText.ui(
                  size: 12.5,
                  weight: primary ? FontWeight.w600 : FontWeight.w400,
                  color: primary ? JotColors.onAccent : JotColors.textBody,
                ),
              ),
            ],
          ),
        ),
      );
}
