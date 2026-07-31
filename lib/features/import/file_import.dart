import 'dart:io';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/note.dart';
import '../../core/theme/jot_theme.dart';
import '../../data/file_repository.dart';
import '../../state/jot_services.dart';
import '../../state/vault_notifier.dart';
import '../../widgets/jot_icons.dart';

/// Importing files into the vault.
///
/// Deliberately type-agnostic: the picker filters nothing, because the moment
/// a list of allowed extensions exists it is wrong for somebody. What a file
/// becomes is decided after reading it, not before choosing it.
Future<int> pickAndImportFiles(WidgetRef ref, {String? folder}) async {
  // No type groups: the picker filters nothing on purpose. A list of allowed
  // extensions is wrong for somebody the moment it exists.
  final files = await openFiles();
  if (files.isEmpty) return 0;

  return ref.read(vaultProvider.notifier).importFiles(
        files.map((f) => f.path),
        folder: folder,
      );
}

/// Hands a note back as a file, at a location the user picks.
///
/// The counterpart to importing: anything that went in can come back out,
/// under the name it arrived with. Returns the path written, or null when the
/// user cancelled.
///
/// On mobile there is no "save as" dialog in the desktop sense, `saveFile`
/// writes the bytes itself and reports where, so the same call covers both.
Future<String?> pickAndExportNote(WidgetRef ref, Note note) async {
  final files = ref.read(servicesProvider).files;

  final List<int> bytes;
  try {
    bytes = await files.exportBytes(note);
  } on Object {
    // The only way here is an attachment whose bytes are gone; the card
    // already says so, and a dialog on top would add nothing.
    return null;
  }

  final location = await getSaveLocation(
    suggestedName: FileRepository.suggestedFileName(note),
  );
  if (location == null) return null;

  // file_selector hands back a destination rather than writing for us, which
  // is the honest split: it owns the dialog, we own the bytes.
  await XFile.fromData(
    Uint8List.fromList(bytes),
    name: FileRepository.suggestedFileName(note),
  ).saveTo(location.path);
  return location.path;
}

/// Whether drag-and-drop is worth wiring up on this platform.
bool get supportsFileDrop =>
    Platform.isWindows || Platform.isMacOS || Platform.isLinux;

/// The overlay shown while files hover over the window.
///
/// Drag-and-drop is the fastest way in, no dialog, no folder navigation -
/// so it needs an unmistakable target, not a subtle highlight.
class DropTargetOverlay extends StatelessWidget {
  const DropTargetOverlay({super.key});

  @override
  Widget build(BuildContext context) => Positioned.fill(
        child: IgnorePointer(
          child: ColoredBox(
            color: JotColors.scrim,
            child: Center(
              child: Container(
                padding: const EdgeInsets.fromLTRB(28, 24, 28, 24),
                decoration: BoxDecoration(
                  color: JotColors.raised,
                  border: Border.all(color: JotColors.accent, width: 1.5),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    JotIcon(
                      JotIcons.import_,
                      size: 26,
                      color: JotColors.accent,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Déposer pour importer',
                      style: JotText.ui(
                        size: 14,
                        weight: FontWeight.w600,
                        color: JotColors.textBright,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'JSON, CSV, XML, code, PDF, tout le reste',
                      style: JotText.mono(
                        size: 11.5,
                        color: JotColors.textFaint,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
}
