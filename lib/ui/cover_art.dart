import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Colour sets for procedurally drawn placeholder artwork.
enum CoverPalette { sunset, dusk, night, ocean, golden, rose, storm }

/// Describes one placeholder cover. Covers are drawn in code (original
/// artwork), not loaded from images.
@immutable
class CoverArtSpec {
  const CoverArtSpec(this.seed, this.palette);

  final int seed;
  final CoverPalette palette;

  @override
  bool operator ==(Object other) =>
      other is CoverArtSpec && other.seed == seed && other.palette == palette;

  @override
  int get hashCode => Object.hash(seed, palette);
}

/// The light a generated cover gives off (NEXARYVE 1.2 artwork light).
Color coverLight(CoverPalette palette) => _palettes[palette]!.skyMid;

/// The palette [TrackArt] uses for a track without artwork.
CoverPalette coverPaletteForSeed(int seed) =>
    CoverPalette.values[seed.abs() % CoverPalette.values.length];

class _Palette {
  const _Palette({
    required this.skyTop,
    required this.skyMid,
    required this.skyBottom,
    required this.sun,
    required this.far,
    required this.near,
    required this.water,
  });

  final Color skyTop;
  final Color skyMid;
  final Color skyBottom;
  final Color sun;
  final Color far;
  final Color near;
  final Color water;
}

const Map<CoverPalette, _Palette> _palettes = {
  CoverPalette.sunset: _Palette(
    skyTop: Color(0xFF2B1F4F),
    skyMid: Color(0xFFB6527A),
    skyBottom: Color(0xFFFF9A6B),
    sun: Color(0xFFFFD49A),
    far: Color(0xFF6A3A72),
    near: Color(0xFF2A1A3A),
    water: Color(0xFF7B3F6E),
  ),
  CoverPalette.dusk: _Palette(
    skyTop: Color(0xFF1B2246),
    skyMid: Color(0xFF6C5BA8),
    skyBottom: Color(0xFFE79AB5),
    sun: Color(0xFFFFE2C2),
    far: Color(0xFF4A3F7A),
    near: Color(0xFF1C1836),
    water: Color(0xFF4B4385),
  ),
  CoverPalette.night: _Palette(
    skyTop: Color(0xFF0B1028),
    skyMid: Color(0xFF2B2F6B),
    skyBottom: Color(0xFF8B5FA6),
    sun: Color(0xFFF3EBD8),
    far: Color(0xFF25285A),
    near: Color(0xFF0E1026),
    water: Color(0xFF1E2350),
  ),
  CoverPalette.ocean: _Palette(
    skyTop: Color(0xFF0F2A4A),
    skyMid: Color(0xFF3E7CB0),
    skyBottom: Color(0xFFBFD8EE),
    sun: Color(0xFFFFFFFF),
    far: Color(0xFF2C5A84),
    near: Color(0xFF0F2238),
    water: Color(0xFF2D6C9C),
  ),
  CoverPalette.golden: _Palette(
    skyTop: Color(0xFF3B1F3F),
    skyMid: Color(0xFFD46A4E),
    skyBottom: Color(0xFFFFC27A),
    sun: Color(0xFFFFF1C4),
    far: Color(0xFF7A3B3B),
    near: Color(0xFF2B1620),
    water: Color(0xFFA2533F),
  ),
  CoverPalette.rose: _Palette(
    skyTop: Color(0xFF3A1E3E),
    skyMid: Color(0xFFE0708C),
    skyBottom: Color(0xFFFFB59A),
    sun: Color(0xFFFFE7D6),
    far: Color(0xFF8A3E62),
    near: Color(0xFF331A30),
    water: Color(0xFFB65A78),
  ),
  CoverPalette.storm: _Palette(
    skyTop: Color(0xFF15181F),
    skyMid: Color(0xFF3A4152),
    skyBottom: Color(0xFF8C93A6),
    sun: Color(0xFFDDE3F0),
    far: Color(0xFF3B4254),
    near: Color(0xFF14171E),
    water: Color(0xFF2E3445),
  ),
};

/// Original, code-drawn landscape artwork used for DEMO items.
class CoverArt extends StatelessWidget {
  const CoverArt({
    super.key,
    required this.spec,
    this.size,
    this.radius = 8,
  });

  final CoverArtSpec spec;
  final double? size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final art = ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: RepaintBoundary(
        child: CustomPaint(
          painter: _ScenePainter(spec),
          child: const SizedBox.expand(),
        ),
      ),
    );
    if (size == null) {
      return art;
    }
    return SizedBox.square(dimension: size, child: art);
  }
}

class _ScenePainter extends CustomPainter {
  _ScenePainter(this.spec);

  final CoverArtSpec spec;

  @override
  void paint(Canvas canvas, Size size) {
    final p = _palettes[spec.palette]!;
    final rnd = math.Random(spec.seed);
    final rect = Offset.zero & size;

    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [p.skyTop, p.skyMid, p.skyBottom],
          stops: const [0, 0.55, 1],
        ).createShader(rect),
    );

    final horizon = size.height * (0.58 + rnd.nextDouble() * 0.1);
    final sunCenter = Offset(
      size.width * (0.3 + rnd.nextDouble() * 0.4),
      horizon - size.height * (0.08 + rnd.nextDouble() * 0.14),
    );
    final sunRadius = size.shortestSide * (0.09 + rnd.nextDouble() * 0.06);
    final glow = Rect.fromCircle(center: sunCenter, radius: sunRadius * 3);
    canvas.drawCircle(
      sunCenter,
      sunRadius * 3,
      Paint()
        ..shader = RadialGradient(
          colors: [
            p.sun.withValues(alpha: 0.45),
            p.sun.withValues(alpha: 0),
          ],
        ).createShader(glow),
    );
    canvas.drawCircle(sunCenter, sunRadius, Paint()..color = p.sun);

    _ridge(canvas, size, rnd, horizon, size.height * 0.2, p.far, 5);
    _ridge(
      canvas,
      size,
      rnd,
      horizon + size.height * 0.03,
      size.height * 0.13,
      p.near,
      4,
    );

    final water = Rect.fromLTRB(
      0,
      horizon + size.height * 0.03,
      size.width,
      size.height,
    );
    canvas.drawRect(
      water,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [p.water, p.skyTop],
        ).createShader(water),
    );

    final streak = Paint()
      ..color = p.sun.withValues(alpha: 0.4)
      ..strokeCap = StrokeCap.round
      ..strokeWidth = math.max(1.0, size.height / 110);
    for (var i = 0; i < 5; i++) {
      final y = water.top + water.height * (0.12 + i * 0.16);
      final half = size.width * (0.16 - i * 0.022);
      canvas.drawLine(
        Offset(sunCenter.dx - half, y),
        Offset(sunCenter.dx + half, y),
        streak,
      );
    }
  }

  void _ridge(
    Canvas canvas,
    Size size,
    math.Random rnd,
    double base,
    double height,
    Color color,
    int peaks,
  ) {
    final bottom = base + size.height * 0.04;
    final path = Path()..moveTo(0, bottom);
    final steps = peaks * 2;
    for (var i = 0; i <= steps; i++) {
      final x = size.width * i / steps;
      final isPeak = i.isOdd;
      final y = isPeak
          ? base - height * (0.45 + rnd.nextDouble() * 0.55)
          : base - height * rnd.nextDouble() * 0.3;
      path.lineTo(x, y);
    }
    path
      ..lineTo(size.width, bottom)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_ScenePainter oldDelegate) => oldDelegate.spec != spec;
}
