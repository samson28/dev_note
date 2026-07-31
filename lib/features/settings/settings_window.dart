import 'package:flutter/material.dart' show Material, MaterialType, showDialog;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../widgets/jot_icons.dart';
import '../../core/theme/jot_theme.dart';
import '../../widgets/jot_primitives.dart';
import 'tabs/about_tab.dart';
import 'tabs/appearance_tab.dart';
import 'tabs/general_tab.dart';
import 'tabs/quick_capture_tab.dart';
import 'tabs/shortcuts_tab.dart';
import 'tabs/storage_tab.dart';

/// The six panes of the Réglages window, in the design's order.
enum SettingsTab {
  general('Général'),
  appearance('Apparence'),
  shortcuts('Raccourcis'),
  quickCapture('Capture rapide'),
  storage('Stockage & sauvegarde'),
  about('À propos');

  const SettingsTab(this.label);
  final String label;
}

/// Réglages — 980px wide, left nav + right content, exactly like the main
/// window's grammar.
///
/// Shown as an overlay inside the main window rather than a second OS window:
/// it is modal to the app, and a separate window would mean a second engine
/// with its own copy of the index for no benefit.
class SettingsWindow extends ConsumerStatefulWidget {
  const SettingsWindow({super.key, required this.onClose, this.initialTab});

  final VoidCallback onClose;
  final SettingsTab? initialTab;

  @override
  ConsumerState<SettingsWindow> createState() => _SettingsWindowState();
}

class _SettingsWindowState extends ConsumerState<SettingsWindow> {
  late SettingsTab _tab = widget.initialTab ?? SettingsTab.general;

  @override
  Widget build(BuildContext context) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: widget.onClose,
              child: ColoredBox(color: JotColors.scrim),
            ),
          ),
          Center(
            child: Material(
              type: MaterialType.transparency,
              child: Container(
                width: 980,
                constraints: const BoxConstraints(maxHeight: 800),
                decoration: BoxDecoration(
                  color: JotColors.window,
                  border: Border.all(color: JotColors.borderWindow),
                  borderRadius: BorderRadius.circular(JotMetrics.windowRadius),
                  boxShadow: JotMetrics.windowShadow,
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _TitleBar(onClose: widget.onClose),
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _Nav(
                            current: _tab,
                            onSelect: (tab) => setState(() => _tab = tab),
                          ),
                          Expanded(
                            child: ColoredBox(
                              color: JotColors.editorSurface,
                              child: _content(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      );

  Widget _content() => switch (_tab) {
        SettingsTab.general => GeneralTab(onDone: widget.onClose),
        SettingsTab.appearance => AppearanceTab(onDone: widget.onClose),
        SettingsTab.shortcuts => ShortcutsTab(onDone: widget.onClose),
        SettingsTab.quickCapture => QuickCaptureTab(onDone: widget.onClose),
        SettingsTab.storage => StorageTab(onDone: widget.onClose),
        SettingsTab.about => const AboutTab(),
      };
}

class _TitleBar extends StatelessWidget {
  const _TitleBar({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) => Container(
        height: JotMetrics.titleBarHeight,
        decoration: BoxDecoration(
          color: JotColors.chrome,
          border: Border(bottom: BorderSide(color: JotColors.borderSubtle)),
        ),
        child: Row(
          children: [
            const SizedBox(width: 14),
            Text('Réglages', style: JotText.windowTitle),
            const Spacer(),
            Hoverable(
              onTap: onClose,
              cursor: SystemMouseCursors.basic,
              builder: (context, hovered) => Container(
                width: JotMetrics.windowButtonWidth,
                height: JotMetrics.windowButtonHeight,
                alignment: Alignment.center,
                color: hovered ? JotColors.danger : const Color(0x00000000),
                child: JotIcon(JotIcons.close, size: 15, color: JotColors.textDim),
              ),
            ),
          ],
        ),
      );
}

class _Nav extends StatelessWidget {
  const _Nav({required this.current, required this.onSelect});

  final SettingsTab current;
  final ValueChanged<SettingsTab> onSelect;

  @override
  Widget build(BuildContext context) => Container(
        width: 206,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        decoration: BoxDecoration(
          color: JotColors.chrome,
          border: Border(right: BorderSide(color: JotColors.borderSubtle)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final tab in SettingsTab.values) ...[
              if (tab != SettingsTab.values.first) const SizedBox(height: 1),
              _NavRow(
                label: tab.label,
                active: tab == current,
                onTap: () => onSelect(tab),
              ),
            ],
            const Spacer(),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Text(
                'Jot 1.4.0, Flutter 3.44\nWindows 11, x64',
                style: JotText.mono(size: 10.5, height: 1.5, color: JotColors.textDisabled),
              ),
            ),
          ],
        ),
      );
}

class _NavRow extends StatelessWidget {
  const _NavRow({required this.label, required this.active, required this.onTap});

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Hoverable(
        onTap: onTap,
        builder: (context, hovered) => Container(
          height: JotMetrics.sidebarRowHeight,
          decoration: BoxDecoration(
            color: active
                ? JotColors.accentWashSidebar
                : (hovered ? JotColors.neutralWash : null),
            borderRadius: BorderRadius.circular(6),
          ),
          // Same centred Stack as the main sidebar so the accent edge lines
          // up with the label rather than floating above it.
          child: Stack(
            alignment: Alignment.centerLeft,
            children: [
              if (active)
                Positioned(
                  left: 0,
                  top: 7,
                  bottom: 7,
                  width: 2,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: JotColors.accent,
                      borderRadius: BorderRadius.all(Radius.circular(2)),
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: active
                      ? JotText.sidebarRowActive
                      : JotText.sidebarRow.copyWith(color: JotColors.textBody),
                ),
              ),
            ],
          ),
        ),
      );
}

/// Shared scaffold for a tab's body: scrollable content plus a pinned footer.
class SettingsPane extends StatelessWidget {
  const SettingsPane({
    super.key,
    required this.sections,
    this.footer,
    this.gap = 20,
    this.padding = const EdgeInsets.fromLTRB(24, 20, 24, 20),
  });

  final List<Widget> sections;
  final Widget? footer;
  final double gap;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => Padding(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < sections.length; i++) ...[
                      if (i > 0) SizedBox(height: gap),
                      sections[i],
                    ],
                  ],
                ),
              ),
            ),
            if (footer != null) ...[const SizedBox(height: 16), footer!],
          ],
        ),
      );
}

/// Opens the Réglages window as a modal route over the main window.
Future<void> showSettings(BuildContext context, {SettingsTab? tab}) => showDialog<void>(
      context: context,
      barrierColor: const Color(0x00000000),
      builder: (dialogContext) => SettingsWindow(
        initialTab: tab,
        onClose: () => Navigator.of(dialogContext).pop(),
      ),
    );
