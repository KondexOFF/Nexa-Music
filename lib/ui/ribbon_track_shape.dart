import 'package:flutter/material.dart';

import '../app/theme/tokens.dart';

/// NEXARYVE 1.2 seek track: the played part runs lavender into coral, the
/// brand ribbon; the rest stays a quiet line.
class RibbonTrackShape extends RoundedRectSliderTrackShape {
  const RibbonTrackShape();

  @override
  void paint(
    PaintingContext context,
    Offset offset, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required TextDirection textDirection,
    required Offset thumbCenter,
    Offset? secondaryOffset,
    bool isDiscrete = false,
    bool isEnabled = false,
    double additionalActiveTrackHeight = 2,
  }) {
    final rect = getPreferredRect(
      parentBox: parentBox,
      offset: offset,
      sliderTheme: sliderTheme,
      isEnabled: isEnabled,
      isDiscrete: isDiscrete,
    );
    final radius = Radius.circular(rect.height / 2);
    final canvas = context.canvas;
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, radius),
      Paint()
        ..color =
            sliderTheme.inactiveTrackColor ?? const Color(0x24FFFFFF),
    );
    final active = Rect.fromLTRB(
      rect.left,
      rect.top,
      thumbCenter.dx.clamp(rect.left, rect.right),
      rect.bottom,
    );
    if (active.width <= 0) {
      return;
    }
    canvas.drawRRect(
      RRect.fromRectAndRadius(active, radius),
      Paint()
        ..shader = LinearGradient(
          colors: isEnabled
              ? const [NexaColors.accent, NexaColors.live]
              : [
                  sliderTheme.disabledActiveTrackColor ?? const Color(0x55AD9AFF),
                  sliderTheme.disabledActiveTrackColor ?? const Color(0x55AD9AFF),
                ],
        ).createShader(rect),
    );
  }
}
