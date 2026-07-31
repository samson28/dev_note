import 'package:flutter/material.dart';

import '../../../core/theme/jot_theme.dart';
import '../../../widgets/jot_primitives.dart';

/// Centres a floating panel and gives it the `Material` ancestor that
/// `TextField` (and the text-selection toolbar) require.
///
/// `showDialog` only provides a `Navigator`, not a `Material` — without this a
/// bare `TextField` inside a hand-built panel throws "No Material widget
/// found". Transparency keeps the panel's own surface and shadow intact.
class _DialogSurface extends StatelessWidget {
  const _DialogSurface({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Center(
        child: Material(
          type: MaterialType.transparency,
          child: child,
        ),
      );
}

/// A single-field prompt, styled as a raised surface from the design
/// (`#22242A` on `#34363D`, 8px radius).
///
/// Opens focused with the text selected and commits on Enter, so renaming a
/// note or adding a tag is a two-keystroke affair.
class PromptDialog extends StatefulWidget {
  const PromptDialog({
    super.key,
    required this.title,
    required this.hint,
    this.initialValue = '',
    this.confirmLabel = 'Valider',
    this.monospace = false,
  });

  final String title;
  final String hint;
  final String initialValue;
  final String confirmLabel;
  final bool monospace;

  @override
  State<PromptDialog> createState() => _PromptDialogState();
}

class _PromptDialogState extends State<PromptDialog> {
  late final _controller = TextEditingController(text: widget.initialValue)
    ..selection = TextSelection(
      baseOffset: 0,
      extentOffset: widget.initialValue.length,
    );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() => Navigator.of(context).pop(_controller.text);

  @override
  Widget build(BuildContext context) => _DialogSurface(
        child: Container(
          width: 340,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: JotColors.raised,
            border: Border.all(color: JotColors.borderRaised),
            borderRadius: BorderRadius.circular(10),
            boxShadow: JotColors.active.shadow(JotMetrics.menuShadow),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.title,
                style: JotText.ui(
                  size: 13,
                  weight: FontWeight.w600,
                  color: JotColors.textBright,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                height: 34,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                alignment: Alignment.centerLeft,
                decoration: BoxDecoration(
                  color: JotColors.field,
                  border: Border.all(color: JotColors.borderWindow),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: TextField(
                  controller: _controller,
                  autofocus: true,
                  onSubmitted: (_) => _submit(),
                  cursorColor: JotColors.accent,
                  cursorWidth: 1.5,
                  style: widget.monospace
                      ? JotText.mono(size: 12.5, color: JotColors.textPrimary)
                      : JotText.ui(size: 12.5, color: JotColors.textPrimary),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    isCollapsed: true,
                    hintText: widget.hint,
                    hintStyle: JotText.ui(size: 12.5, color: JotColors.textDisabled),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  JotButton(
                    'Annuler',
                    kind: JotButtonKind.secondary,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 8),
                  JotButton(widget.confirmLabel, trailing: 'Entrée', onTap: _submit),
                ],
              ),
            ],
          ),
        ),
      );
}

/// The "Déplacer vers..." picker — a list of folders on the same raised surface.
class FolderPickerDialog extends StatelessWidget {
  const FolderPickerDialog({super.key, required this.folders, this.current});

  final List<String> folders;
  final String? current;

  @override
  Widget build(BuildContext context) => _DialogSurface(
        child: Container(
          width: 280,
          constraints: const BoxConstraints(maxHeight: 380),
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: JotColors.raised,
            border: Border.all(color: JotColors.borderRaised),
            borderRadius: BorderRadius.circular(8),
            boxShadow: JotColors.active.shadow(JotMetrics.menuShadow),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
                child: Text(
                  'Déplacer vers...',
                  style: JotText.ui(
                    size: 12,
                    weight: FontWeight.w600,
                    color: JotColors.textBright,
                  ),
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      for (final folder in folders)
                        Hoverable(
                          onTap: () => Navigator.of(context).pop(folder),
                          builder: (context, hovered) => Container(
                            height: 28,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            decoration: BoxDecoration(
                              color: hovered ? JotColors.neutralWashMenu : null,
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Row(
                              children: [
                                FolderGlyph(
                                  color: folder == current
                                      ? JotColors.accent
                                      : JotColors.textDim,
                                  width: 9,
                                  height: 8,
                                ),
                                const SizedBox(width: 9),
                                Expanded(
                                  child: Text(
                                    folder,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: JotText.ui(
                                      size: 12,
                                      color: folder == current
                                          ? JotColors.textBright
                                          : JotColors.textStrong,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
}
