import 'package:flutter/material.dart' show Scaffold;
import 'package:flutter/widgets.dart';
import 'package:window_manager/window_manager.dart';

import '../../core/theme/jot_theme.dart';
import 'quick_capture_window.dart';

/// Host for the separate OS window: transparent scaffold so the panel's own
/// rounded corners and shadow are what you see.
class QuickCaptureWindowHost extends StatelessWidget {
  const QuickCaptureWindowHost({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0x00000000),
        body: DragToMoveArea(
          child: QuickCaptureWindow(onDismiss: windowManager.close),
        ),
      );
}

/// Fallback host, layered inside the main window when a separate OS window is
/// not available. Same panel, same keys, same 540px, only the frame differs.
class QuickCaptureOverlay extends StatelessWidget {
  const QuickCaptureOverlay({super.key, required this.onDismiss, this.onSaved});

  final VoidCallback onDismiss;
  final VoidCallback? onSaved;

  @override
  Widget build(BuildContext context) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: onDismiss,
              child: ColoredBox(color: JotColors.scrim),
            ),
          ),
          Positioned(
            top: 120,
            left: 0,
            right: 0,
            child: Center(
              child: SizedBox(
                width: JotMetrics.captureSize.width,
                height: JotMetrics.captureSize.height,
                child: QuickCaptureWindow(
                  onSaved: onSaved,
                  onDismiss: () async => onDismiss(),
                ),
              ),
            ),
          ),
        ],
      );
}
