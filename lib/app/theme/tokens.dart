import 'package:flutter/animation.dart';

/// NEXARYVE 1.2 tokens (Visual Evolution, docs/design/VISUAL_EVOLUTION_1.2.md):
/// graphite surfaces, lavender accent, coral for "live" moments.
abstract final class NexaColors {
  static const Color background = Color(0xFF0F1013);
  static const Color sidebar = Color(0xFF0B0C0F);
  static const Color playerBar = Color(0xFF0B0C0F);
  static const Color panel = Color(0xFF15161B);
  static const Color panelRaised = Color(0xFF1B1D23);
  static const Color panelHover = Color(0xFF23252D);
  static const Color navSelected = Color(0x24AD9AFF);
  static const Color border = Color(0x0FFFFFFF);
  static const Color divider = Color(0x0CFFFFFF);
  static const Color textPrimary = Color(0xFFF2F1EE);
  static const Color textSecondary = Color(0xFFA3A5B0);
  static const Color textTertiary = Color(0xFF6B6D78);
  static const Color textDisabled = Color(0x52F2F1EE);
  static const Color accent = Color(0xFFAD9AFF);
  static const Color accentStrong = Color(0xFF9883FF);
  static const Color accentSoft = Color(0x29AD9AFF);
  static const Color accentFaint = Color(0x14AD9AFF);
  static const Color coral = Color(0xFFFF8A74);

  /// "Live" moments next to lavender: playing indicator, progress.
  static const Color live = Color(0xFFFF8A74);
  static const Color sky = Color(0xFF86A8FF);
  static const Color orange = Color(0xFFFFA15C);
  static const Color demo = Color(0xFFE6C36E);
  static const Color tooltip = Color(0xFF26282F);
}

/// 8 px rhythm.
abstract final class NexaSpace {
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
}

abstract final class NexaRadius {
  static const double sm = 10;
  static const double md = 14;
  static const double lg = 18;
  static const double xl = 24;
}

/// Layout sizes from Master Plan v1.0 §1 (sidebar ~220, player 80-88,
/// optional right panel 275-345).
abstract final class NexaSizes {
  static const double sidebar = 224;
  static const double sidebarCompact = 76;
  static const double topBar = 64;
  static const double bottomPlayer = 88;
  static const double rightPanelWide = 336;
  static const double rightPanelNarrow = 288;
}

/// Window-width breakpoints (logical px). Target range is 1280-1920; below
/// 1180 the right panel collapses, below 1100 the sidebar becomes an icon rail.
abstract final class NexaBreakpoints {
  static const double sidebarRail = 1100;
  static const double rightPanel = 1180;
  static const double wideRightPanel = 1500;
  static const double compactPlayerBar = 1260;
}

abstract final class NexaMotion {
  static const Duration fast = Duration(milliseconds: 160);
  static const Duration normal = Duration(milliseconds: 260);
  static const Duration slow = Duration(milliseconds: 420);

  /// Artwork light following the playing song.
  static const Duration ambient = Duration(milliseconds: 600);
  static const Curve curve = Curves.easeOutCubic;
}
