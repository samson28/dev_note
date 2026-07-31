import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'app_settings.dart';

/// Turns a stored [KeyCombo] into the two key types Flutter and
/// `hotkey_manager` need.
///
/// [KeyCombo] deliberately stores a display label ("N", "K", ".", "Entrée")
/// rather than a key object, so settings survive a Flutter upgrade that
/// renumbers key constants. This is where that label is resolved back.
extension KeyComboBinding on KeyCombo {
  /// For in-app `Shortcuts`. Null when the label is not a key we can bind.
  SingleActivator? get activator {
    final logical = logicalKey;
    if (logical == null) return null;
    return SingleActivator(
      logical,
      control: ctrl,
      alt: alt,
      shift: shift,
      meta: meta,
    );
  }

  LogicalKeyboardKey? get logicalKey {
    final label = key.trim();
    if (label.isEmpty) return null;

    // Letters and digits map straight onto their character code.
    if (label.length == 1) {
      final lower = label.toLowerCase().codeUnitAt(0);
      final isLetter = lower >= 0x61 && lower <= 0x7A;
      final isDigit = lower >= 0x30 && lower <= 0x39;
      if (isLetter || isDigit) return LogicalKeyboardKey(lower);
      return _punctuation[label];
    }

    return _named[label];
  }

  /// For `hotkey_manager`, which registers by physical position.
  PhysicalKeyboardKey? get physicalKey {
    final label = key.trim();
    if (label.isEmpty) return null;

    if (label.length == 1) {
      final upper = label.toUpperCase().codeUnitAt(0);
      // USB HID: A is 0x04 through Z at 0x1D.
      if (upper >= 0x41 && upper <= 0x5A) {
        return PhysicalKeyboardKey(0x00070004 + (upper - 0x41));
      }
      // 1..9 are 0x1E..0x26, and 0 is 0x27.
      if (upper >= 0x31 && upper <= 0x39) {
        return PhysicalKeyboardKey(0x0007001E + (upper - 0x31));
      }
      if (upper == 0x30) return PhysicalKeyboardKey.digit0;
      return _physicalPunctuation[label];
    }

    return _physicalNamed[label];
  }

  /// Whether this combination can actually be bound. The Raccourcis tab shows
  /// the rest as-is but they will not fire.
  bool get isBindable => logicalKey != null;

  static const _punctuation = <String, LogicalKeyboardKey>{
    '.': LogicalKeyboardKey.period,
    ',': LogicalKeyboardKey.comma,
    ';': LogicalKeyboardKey.semicolon,
    '/': LogicalKeyboardKey.slash,
    '-': LogicalKeyboardKey.minus,
    '=': LogicalKeyboardKey.equal,
  };

  static const _named = <String, LogicalKeyboardKey>{
    'Entrée': LogicalKeyboardKey.enter,
    'Retour': LogicalKeyboardKey.backspace,
    'Suppr': LogicalKeyboardKey.delete,
    'Espace': LogicalKeyboardKey.space,
    'Tab': LogicalKeyboardKey.tab,
    'Echap': LogicalKeyboardKey.escape,
    'Haut': LogicalKeyboardKey.arrowUp,
    'Bas': LogicalKeyboardKey.arrowDown,
  };

  static const _physicalPunctuation = <String, PhysicalKeyboardKey>{
    '.': PhysicalKeyboardKey.period,
    ',': PhysicalKeyboardKey.comma,
    ';': PhysicalKeyboardKey.semicolon,
    '/': PhysicalKeyboardKey.slash,
    '-': PhysicalKeyboardKey.minus,
    '=': PhysicalKeyboardKey.equal,
  };

  static const _physicalNamed = <String, PhysicalKeyboardKey>{
    'Entrée': PhysicalKeyboardKey.enter,
    'Retour': PhysicalKeyboardKey.backspace,
    'Suppr': PhysicalKeyboardKey.delete,
    'Espace': PhysicalKeyboardKey.space,
    'Tab': PhysicalKeyboardKey.tab,
    'Echap': PhysicalKeyboardKey.escape,
    'Haut': PhysicalKeyboardKey.arrowUp,
    'Bas': PhysicalKeyboardKey.arrowDown,
  };
}
