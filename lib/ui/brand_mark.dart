import 'package:flutter/material.dart';

import '../app/strings.dart';
import '../app/theme/nexa_theme.dart';
import '../app/theme/tokens.dart';

/// The NEXARYVE mark (D-034): an "N" drawn as one ribbon whose diagonal is a
/// sound wave, lavender into coral. Painted, so it stays sharp at any size;
/// the same geometry as `docs/brand/nexaryve_mark.svg` and the app icon.
class NexaryveMark extends StatelessWidget {
  const NexaryveMark({super.key, this.size = 32, this.tile = true});

  final double size;

  /// With the graphite rounded tile behind the ribbon (app icon look).
  final bool tile;

  @override
  Widget build(BuildContext context) => Semantics(
    label: S.appTitle,
    image: true,
    child: SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: _MarkPainter(tile: tile)),
    ),
  );
}

class _MarkPainter extends CustomPainter {
  _MarkPainter({required this.tile});

  final bool tile;

  static const Color inkTop = Color(0xFFC4B5FF);
  static const Color inkMid = Color(0xFF9C8BFF);
  static const Color inkEnd = Color(0xFFFF8A74);

  @override
  void paint(Canvas canvas, Size size) {
    // Geometry on a 512 grid (as in the SVG).
    final k = size.width / 512;
    canvas.scale(k);
    if (tile) {
      final rect = RRect.fromRectAndRadius(
        const Rect.fromLTWH(16, 16, 480, 480),
        const Radius.circular(116),
      );
      canvas.drawRRect(
        rect,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF20232F), Color(0xFF0E1016)],
          ).createShader(rect.outerRect),
      );
      canvas.drawRRect(
        rect,
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(0.44, -0.56),
            radius: 0.75,
            colors: [
              NexaColors.accent.withValues(alpha: 0.34),
              NexaColors.accent.withValues(alpha: 0),
            ],
          ).createShader(rect.outerRect),
      );
      canvas.drawRRect(
        rect.deflate(1.5),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = const Color(0x12FFFFFF),
      );
    }
    final ribbon = Path()
      ..moveTo(150, 362)
      ..lineTo(150, 150)
      ..cubicTo(262, 150, 250, 362, 362, 362)
      ..lineTo(362, 150);
    canvas.drawPath(
      ribbon,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = tile ? 46 : 58
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..shader = const LinearGradient(
          colors: [inkTop, inkMid, inkEnd],
          stops: [0, 0.55, 1],
        ).createShader(const Rect.fromLTRB(130, 140, 380, 380)),
    );
  }

  @override
  bool shouldRepaint(_MarkPainter old) => old.tile != tile;
}

/// Mark and the NEXARYVE wordmark side by side.
class NexaryveWordmark extends StatelessWidget {
  const NexaryveWordmark({super.key, this.markSize = 30, this.fontSize = 17});

  final double markSize;
  final double fontSize;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      ExcludeSemantics(child: NexaryveMark(size: markSize)),
      SizedBox(width: markSize * 0.4),
      Text(
        S.brandName,
        style: TextStyle(
          fontFamily: NexaText.family,
          fontSize: fontSize,
          fontWeight: FontWeight.w800,
          letterSpacing: fontSize * 0.28,
          color: NexaColors.textPrimary,
        ),
      ),
    ],
  );
}
