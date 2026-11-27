import 'package:flutter/material.dart';

import 'tokens.dart';

/// Typography scale (Manrope, bundled under OFL 1.1).
abstract final class NexaText {
  static const String family = 'Manrope';

  static const TextStyle display = TextStyle(
    fontFamily: family,
    fontSize: 46,
    height: 1.06,
    fontWeight: FontWeight.w800,
    letterSpacing: -1.0,
    color: NexaColors.textPrimary,
  );

  /// Page titles (NEXARYVE 1.2).
  static const TextStyle h1 = TextStyle(
    fontFamily: family,
    fontSize: 30,
    height: 1.15,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.4,
    color: NexaColors.textPrimary,
  );
  static const TextStyle h2 = TextStyle(
    fontFamily: family,
    fontSize: 20,
    height: 1.25,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.2,
    color: NexaColors.textPrimary,
  );
  static const TextStyle h3 = TextStyle(
    fontFamily: family,
    fontSize: 17,
    height: 1.3,
    fontWeight: FontWeight.w700,
    color: NexaColors.textPrimary,
  );
  static const TextStyle title = TextStyle(
    fontFamily: family,
    fontSize: 15,
    height: 1.3,
    fontWeight: FontWeight.w700,
    color: NexaColors.textPrimary,
  );
  static const TextStyle body = TextStyle(
    fontFamily: family,
    fontSize: 14,
    height: 1.4,
    fontWeight: FontWeight.w500,
    color: NexaColors.textPrimary,
  );
  static const TextStyle bodySecondary = TextStyle(
    fontFamily: family,
    fontSize: 14,
    height: 1.45,
    fontWeight: FontWeight.w500,
    color: NexaColors.textSecondary,
  );
  static const TextStyle caption = TextStyle(
    fontFamily: family,
    fontSize: 12.5,
    height: 1.35,
    fontWeight: FontWeight.w500,
    color: NexaColors.textSecondary,
  );
  static const TextStyle overline = TextStyle(
    fontFamily: family,
    fontSize: 12,
    height: 1.2,
    fontWeight: FontWeight.w700,
    letterSpacing: 3.2,
    color: NexaColors.textPrimary,
  );

  /// Small capitals above a title (calmer than [overline]).
  static const TextStyle eyebrow = TextStyle(
    fontFamily: family,
    fontSize: 11.5,
    height: 1.2,
    fontWeight: FontWeight.w700,
    letterSpacing: 2.6,
    color: NexaColors.textSecondary,
  );

  /// Times and counters: tabular figures, so they never jitter.
  static const List<FontFeature> numbers = [FontFeature.tabularFigures()];
  static const TextStyle tableHeader = TextStyle(
    fontFamily: family,
    fontSize: 11,
    height: 1.2,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.2,
    color: NexaColors.textTertiary,
  );
  static const TextStyle badge = TextStyle(
    fontFamily: family,
    fontSize: 10,
    height: 1.1,
    fontWeight: FontWeight.w800,
    letterSpacing: 1.1,
  );
  static const TextStyle button = TextStyle(
    fontFamily: family,
    fontSize: 15,
    height: 1.2,
    fontWeight: FontWeight.w700,
  );
}

ThemeData buildNexaTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: NexaColors.accent,
    brightness: Brightness.dark,
  ).copyWith(
    primary: NexaColors.accent,
    onPrimary: Colors.white,
    surface: NexaColors.panel,
    onSurface: NexaColors.textPrimary,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    fontFamily: NexaText.family,
    scaffoldBackgroundColor: NexaColors.background,
    canvasColor: NexaColors.background,
    dividerColor: NexaColors.divider,
    splashFactory: NoSplash.splashFactory,
    hoverColor: NexaColors.accentFaint,
    focusColor: NexaColors.accentSoft,
    highlightColor: Colors.transparent,
    visualDensity: VisualDensity.standard,
    tooltipTheme: TooltipThemeData(
      waitDuration: const Duration(milliseconds: 350),
      textStyle: NexaText.caption.copyWith(color: NexaColors.textPrimary),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: NexaColors.tooltip,
        borderRadius: BorderRadius.circular(NexaRadius.sm),
        border: Border.all(color: NexaColors.border),
      ),
    ),
    sliderTheme: const SliderThemeData(
      trackHeight: 4,
      activeTrackColor: NexaColors.accent,
      inactiveTrackColor: Color(0x24FFFFFF),
      thumbColor: Color(0xFFEDE8FF),
      overlayColor: NexaColors.accentSoft,
      disabledActiveTrackColor: Color(0x55AD9AFF),
      disabledInactiveTrackColor: Color(0x18FFFFFF),
      disabledThumbColor: Color(0x99B8B2CC),
      thumbShape: RoundSliderThumbShape(enabledThumbRadius: 7),
      overlayShape: RoundSliderOverlayShape(overlayRadius: 14),
      showValueIndicator: ShowValueIndicator.never,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? Colors.white
            : NexaColors.textSecondary,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? NexaColors.accent
            : NexaColors.panelHover,
      ),
      trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
    ),
    scrollbarTheme: ScrollbarThemeData(
      thickness: WidgetStateProperty.all(6),
      radius: const Radius.circular(3),
      thumbColor: WidgetStateProperty.all(const Color(0x33FFFFFF)),
    ),
    iconTheme: const IconThemeData(color: NexaColors.textPrimary, size: 20),
  );
}
