import 'package:flutter/widgets.dart';
import 'package:window_manager/window_manager.dart';

import '../../../core/theme/jot_theme.dart';
import '../../../widgets/jot_icons.dart';
import '../../../widgets/jot_primitives.dart';

/// The custom 40px title bar from the design. The OS chrome is hidden
/// (`TitleBarStyle.hidden`) so the accent square, the title and the note count
/// sit on the same strip as the window buttons.
class JotTitleBar extends StatelessWidget {
  const JotTitleBar({super.key, required this.scopeLabel, required this.noteCount});

  final String scopeLabel;
  final int noteCount;

  @override
  Widget build(BuildContext context) => Container(
        height: JotMetrics.titleBarHeight,
        decoration: BoxDecoration(
          color: JotColors.chrome,
          border: Border(bottom: BorderSide(color: JotColors.borderSubtle)),
        ),
        child: Row(
          children: [
            Expanded(
              child: DragToMoveArea(
                child: Padding(
                  padding: const EdgeInsets.only(left: 14),
                  child: Row(
                    children: [
                      Container(
                        width: 15,
                        height: 15,
                        decoration: BoxDecoration(
                          color: JotColors.accent,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text('Jot', style: JotText.windowTitle),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          // The trash keeps its own count, which this pane
                          // does not hold; showing "0 notes" there would be a
                          // plain lie.
                          noteCount < 0
                              ? scopeLabel
                              : '$scopeLabel, $noteCount note${noteCount == 1 ? '' : 's'}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: JotText.windowSubtitle,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const _WindowButtons(),
          ],
        ),
      );
}

class _WindowButtons extends StatelessWidget {
  const _WindowButtons();

  @override
  Widget build(BuildContext context) => Row(
        children: [
          _WindowButton(
            onTap: windowManager.minimize,
            child: JotIcon(JotIcons.minimise, size: 15, color: JotColors.textDim),
          ),
          const SizedBox(width: 2),
          _WindowButton(
            onTap: () async {
              if (await windowManager.isMaximized()) {
                await windowManager.unmaximize();
              } else {
                await windowManager.maximize();
              }
            },
            child: JotIcon(JotIcons.maximise, size: 12, color: JotColors.textDim),
          ),
          const SizedBox(width: 2),
          _WindowButton(
            hoverColor: JotColors.danger,
            onTap: windowManager.close,
            child: JotIcon(JotIcons.close, size: 15, color: JotColors.textDim),
          ),
        ],
      );
}

class _WindowButton extends StatelessWidget {
  const _WindowButton({required this.child, required this.onTap, this.hoverColor});

  final Widget child;
  final VoidCallback onTap;
  final Color? hoverColor;

  @override
  Widget build(BuildContext context) => Hoverable(
        onTap: onTap,
        cursor: SystemMouseCursors.basic,
        builder: (context, hovered) => Container(
          width: JotMetrics.windowButtonWidth,
          height: JotMetrics.windowButtonHeight,
          alignment: Alignment.center,
          color: hovered
              ? (hoverColor ?? JotColors.neutralWashStrong)
              : const Color(0x00000000),
          child: child,
        ),
      );
}
