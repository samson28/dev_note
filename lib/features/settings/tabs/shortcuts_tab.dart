import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/app_settings.dart';
import '../../../core/theme/jot_theme.dart';
import '../../../state/settings_notifier.dart';
import '../../../widgets/jot_primitives.dart';
import '../../../widgets/json_viewer.dart' show BlinkingCaret;
import '../settings_window.dart';
import '../widgets/settings_controls.dart';

/// 2b — Raccourcis, including the live "press the new combination" state.
class ShortcutsTab extends ConsumerStatefulWidget {
  const ShortcutsTab({super.key, required this.onDone});

  final VoidCallback onDone;

  @override
  ConsumerState<ShortcutsTab> createState() => _ShortcutsTabState();
}

class _ShortcutsTabState extends ConsumerState<ShortcutsTab> {
  final _focus = FocusNode();

  /// The row currently listening for a combination, if any.
  ShortcutAction? _capturing;

  /// Modifiers held down so far, shown live next to the caret.
  var _held = const KeyCombo(key: '');

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  void _startCapture(ShortcutAction action) {
    setState(() {
      _capturing = action;
      _held = const KeyCombo(key: '');
    });
    _focus.requestFocus();
  }

  void _cancelCapture() => setState(() {
        _capturing = null;
        _held = const KeyCombo(key: '');
      });

  /// Modifier-only presses accumulate; the first non-modifier key commits the
  /// combination. Escape aborts and leaves the previous binding untouched.
  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    final action = _capturing;
    if (action == null) return KeyEventResult.ignored;
    if (event is KeyUpEvent) return KeyEventResult.handled;

    if (event.logicalKey == LogicalKeyboardKey.escape) {
      _cancelCapture();
      return KeyEventResult.handled;
    }

    final pressed = HardwareKeyboard.instance;
    final combo = KeyCombo(
      key: '',
      ctrl: pressed.isControlPressed,
      alt: pressed.isAltPressed,
      shift: pressed.isShiftPressed,
      meta: pressed.isMetaPressed,
    );

    final label = _labelFor(event.logicalKey);
    if (label == null) {
      // A bare modifier — keep showing it and wait for the real key.
      setState(() => _held = combo);
      return KeyEventResult.handled;
    }

    ref.read(settingsProvider.notifier).setShortcut(
          action,
          KeyCombo(
            key: label,
            ctrl: combo.ctrl,
            alt: combo.alt,
            shift: combo.shift,
            meta: combo.meta,
          ),
        );
    _cancelCapture();
    return KeyEventResult.handled;
  }

  /// `null` for modifier keys, which are not a combination on their own.
  static String? _labelFor(LogicalKeyboardKey key) {
    // Not const: LogicalKeyboardKey overrides `==`, which Dart forbids in a
    // constant set.
    final modifiers = {
      LogicalKeyboardKey.control,
      LogicalKeyboardKey.controlLeft,
      LogicalKeyboardKey.controlRight,
      LogicalKeyboardKey.alt,
      LogicalKeyboardKey.altLeft,
      LogicalKeyboardKey.altRight,
      LogicalKeyboardKey.shift,
      LogicalKeyboardKey.shiftLeft,
      LogicalKeyboardKey.shiftRight,
      LogicalKeyboardKey.meta,
      LogicalKeyboardKey.metaLeft,
      LogicalKeyboardKey.metaRight,
    };
    if (modifiers.contains(key)) return null;

    if (key == LogicalKeyboardKey.backspace) return '⌫';
    if (key == LogicalKeyboardKey.delete) return 'Suppr';
    if (key == LogicalKeyboardKey.enter) return 'Entrée';
    if (key == LogicalKeyboardKey.space) return 'Espace';
    if (key == LogicalKeyboardKey.tab) return 'Tab';

    final label = key.keyLabel;
    if (label.isEmpty) return null;
    return label.length == 1 ? label.toUpperCase() : label;
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final conflicts = settings.conflicts;

    final global = ShortcutAction.values.where((a) => a.global).toList();
    final inApp = ShortcutAction.values.where((a) => !a.global).toList();

    return Focus(
      focusNode: _focus,
      onKeyEvent: _onKey,
      child: SettingsPane(
        gap: 18,
        sections: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Raccourcis clavier',
                      style: JotText.ui(
                        size: 13.5,
                        weight: FontWeight.w600,
                        color: JotColors.textBright,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Clique sur une combinaison pour la réenregistrer. Les raccourcis '
                      "globaux fonctionnent hors de l'appli.",
                      style: JotText.ui(size: 11.5, height: 1.4, color: JotColors.textFaint),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              JotRowButton(
                label: 'Rétablir les valeurs par défaut',
                onTap: () {
                  _cancelCapture();
                  ref.read(settingsProvider.notifier).resetShortcuts();
                },
              ),
            ],
          ),
          SettingsSection(
            title: 'Global (système)',
            child: SettingsCard(
              children: [
                for (final action in global)
                  _row(action, settings, conflicts.contains(action)),
              ],
            ),
          ),
          SettingsSection(
            title: "Dans l'application",
            child: SettingsCard(
              children: [
                for (final action in inApp)
                  _row(action, settings, conflicts.contains(action), compact: true),
              ],
            ),
          ),
        ],
        footer: SettingsFooter(
          status: conflicts.isEmpty
              ? 'aucun conflit'
              : '${conflicts.length} conflit${conflicts.length > 1 ? 's' : ''} détecté'
                  '${conflicts.length > 1 ? 's' : ''}',
          actions: [JotButton('Terminé', onTap: widget.onDone)],
        ),
      ),
    );
  }

  Widget _row(
    ShortcutAction action,
    AppSettings settings,
    bool conflicting, {
    bool compact = false,
  }) {
    final capturing = _capturing == action;
    final combo = settings.shortcutFor(action);

    return SettingRow(
      label: action.label,
      highlighted: capturing,
      onTap: () => capturing ? _cancelCapture() : _startCapture(action),
      padding: EdgeInsets.symmetric(horizontal: 14, vertical: compact ? 10 : 11),
      labelWidget: compact && !capturing
          ? Text(
              action.label,
              style: JotText.ui(size: 12.5, height: 1.3, color: JotColors.textStrong),
            )
          : null,
      helpWidget: capturing
          ? Text(
              'appuie sur la nouvelle combinaison, Échap pour annuler',
              style: JotText.mono(
                size: 11.5,
                height: 1.4,
                color: JotColors.accentHighlightText,
              ),
            )
          : null,
      help: !capturing && conflicting ? 'Déjà attribué à une autre action' : null,
      helpIsError: conflicting,
      trailing: [
        if (capturing)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
            decoration: BoxDecoration(
              color: JotColors.accentWashIcon,
              border: Border.all(color: JotColors.accent),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final part in _held.parts) ...[
                  Text(
                    part,
                    style: JotText.mono(
                      size: 11,
                      weight: FontWeight.w500,
                      color: JotColors.accentHighlightText,
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
                const BlinkingCaret(height: 13),
              ],
            ),
          )
        else
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final part in combo.parts) ...[
                if (part != combo.parts.first) const SizedBox(width: 4),
                ShortcutChip(part, conflicting: conflicting),
              ],
            ],
          ),
      ],
    );
  }
}
