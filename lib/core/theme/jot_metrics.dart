import 'package:flutter/widgets.dart';

import 'jot_colors.dart';

/// Fixed dimensions taken from the design. Anything the design pins in pixels
/// lives here so the three columns keep their exact proportions.
abstract final class JotMetrics {
  // main window -------------------------------------------------------------
  static const windowSize = Size(1360, 860);
  static const windowMinSize = Size(880, 560);
  static const windowRadius = 10.0;

  static const titleBarHeight = 40.0;
  static const windowButtonWidth = 44.0;
  static const windowButtonHeight = 39.0;

  static const sidebarWidth = 236.0;
  static const noteListWidth = 340.0;

  /// Header strip above both the note list and the editor.
  static const paneHeaderHeight = 46.0;
  static const statusBarHeight = 34.0;

  static const sidebarRowHeight = 30.0;
  static const tagRowHeight = 28.0;

  // search palette ----------------------------------------------------------
  static const paletteWidth = 760.0;
  static const paletteTop = 96.0;
  static const paletteRadius = 12.0;
  static const paletteInputHeight = 60.0;
  static const paletteFooterHeight = 36.0;

  // quick capture -----------------------------------------------------------
  static const captureSize = Size(540, 190);
  static const captureRadius = 12.0;
  static const captureBarHeight = 34.0;
  static const captureBodyMinHeight = 104.0;
  static const captureFooterHeight = 44.0;

  // mobile ------------------------------------------------------------------
  static const mobileBottomBarHeight = 66.0;
  static const mobileFabSize = 46.0;

  // shadows -----------------------------------------------------------------
  /// `0 18px 50px rgba(0,0,0,.5)`
  static const windowShadow = <BoxShadow>[
    BoxShadow(
      color: JotColors.shadowWindow,
      offset: Offset(0, 18),
      blurRadius: 50,
    ),
  ];

  /// `0 30px 80px rgba(0,0,0,.65)`
  static const paletteShadow = <BoxShadow>[
    BoxShadow(
      color: JotColors.shadowPalette,
      offset: Offset(0, 30),
      blurRadius: 80,
    ),
  ];

  /// `0 22px 60px rgba(0,0,0,.6)`
  static const captureShadow = <BoxShadow>[
    BoxShadow(
      color: JotColors.shadowCapture,
      offset: Offset(0, 22),
      blurRadius: 60,
    ),
  ];

  /// `0 16px 40px rgba(0,0,0,.55)`
  static const menuShadow = <BoxShadow>[
    BoxShadow(
      color: JotColors.shadowMenu,
      offset: Offset(0, 16),
      blurRadius: 40,
    ),
  ];

  /// `0 16px 40px rgba(0,0,0,.6)` — the notification-area menu.
  static const trayShadow = <BoxShadow>[
    BoxShadow(
      color: JotColors.shadowCapture,
      offset: Offset(0, 16),
      blurRadius: 40,
    ),
  ];

  /// `14px 0 40px rgba(0,0,0,.5)` — the mobile drawer, cast sideways rather
  /// than down because the panel slides in from the left edge.
  static const drawerShadow = <BoxShadow>[
    BoxShadow(
      color: JotColors.shadowWindow,
      offset: Offset(14, 0),
      blurRadius: 40,
    ),
  ];

  /// `0 18px 50px rgba(0,0,0,.45)` — the light theme casts a softer window
  /// shadow than the dark ones, since the surface beneath it is paper.
  static const windowShadowLight = <BoxShadow>[
    BoxShadow(
      color: Color(0x73000000),
      offset: Offset(0, 18),
      blurRadius: 50,
    ),
  ];
}
