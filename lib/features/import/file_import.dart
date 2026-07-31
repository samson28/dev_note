import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/jot_theme.dart';
import '../../state/vault_notifier.dart';
import '../../widgets/jot_icons.dart';

/// Importing files into the vault.
///
/// Deliberately type-agnostic: the picker filters nothing, because the moment
/// a list of allowed extensions exists it is wrong for somebody. What a file
/// becomes is decided after reading it, not before choosing it.
Future<int> pickAndImportFiles(WidgetRef ref, {String? folder}) async {
  final result = await FilePicker.pickFiles(allowMultiple: true);
  if (result == null) return 0;

  final paths = result.files
      .map((f) => f.path)
      .whereType<String>()
      .toList(growable: false);
  if (paths.isEmpty) return 0;

  return ref.read(vaultProvider.notifier).importFiles(paths, folder: folder);
}

/// Whether drag-and-drop is worth wiring up on this platform.
bool get supportsFileDrop =>
    Platform.isWindows || Platform.isMacOS || Platform.isLinux;

/// The overlay shown while files hover over the window.
///
/// Drag-and-drop is the fastest way in — no dialog, no folder navigation —
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
