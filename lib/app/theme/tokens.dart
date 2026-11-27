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
  /// Selected navigation item (accent at 14 %; see [applyAccent]).
  static Color navSelected = const Color(0x248B5CF6);
  static const Color border = Color(0x0FFFFFFF);
  static const Color divider = Color(0x0CFFFFFF);
  static const Color textPrimary = Color(0xFFF2F1EE);
  static const Color textSecondary = Color(0xFFA3A5B0);
  static const Color textTertiary = Color(0xFF6B6D78);
  static const Color textDisabled = Color(0x52F2F1EE);
  // The accent family follows the user's choice (D-042 Local Profile):
  // runtime values, set by [applyAccent] before the app is (re)built.

  /// Text, icons and selected states.
  static Color accent = const Color(0xFFB69CFF);

  /// Filled buttons and the start of gradients.
  static Color accentStrong = const Color(0xFF8B5CF6);
  static Color accentSoft = const Color(0x29B69CFF);
  static Color accentFaint = const Color(0x14B69CFF);

  /// End of accent gradients (magenta in the default violet).
  static Color accentGlow = const Color(0xFFE15FED);

  static void applyAccent({
    required Color color,
    required Color deep,
    required Color glow,
  }) {
    accent = color;
    accentStrong = deep;
    accentSoft = color.withAlpha(0x29);
    accentFaint = color.withAlpha(0x14);
    accentGlow = glow;
    navSelected = deep.withAlpha(0x24);
  }
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

/// Durations follow the user's animation setting (D-042 Local Profile):
/// [applyScale] 1 = full, 0.5 = reduced, 0 = off.
abstract final class NexaMotion {
  static Duration fast = const Duration(milliseconds: 160);
  static Duration normal = const Duration(milliseconds: 260);
  static Duration slow = const Duration(milliseconds: 420);

  /// Artwork light following the playing song.
  static Duration ambient = const Duration(milliseconds: 600);
  static const Curve curve = Curves.easeOutCubic;

  static void applyScale(double scale) {
    Duration d(int ms) => Duration(milliseconds: (ms * scale).round());
    fast = d(160);
    normal = d(260);
    slow = d(420);
    ambient = d(600);
  }
}
