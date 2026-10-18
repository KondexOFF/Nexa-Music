import 'dart:io';

import 'package:flutter/material.dart';

import '../../ui/cover_art.dart';

/// Cover of a library track: the cached / folder image when there is one,
/// otherwise a generated NEXA placeholder (stable per [seed]).
class TrackArt extends StatelessWidget {
  const TrackArt({
    super.key,
    required this.artworkPath,
    required this.seed,
    this.size = 44,
    this.radius = 6,
  });

  final String? artworkPath;
  final int seed;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final placeholder = CoverArt(
      spec: CoverArtSpec(
        seed,
        CoverPalette.values[seed.abs() % CoverPalette.values.length],
      ),
      size: size,
      radius: radius,
    );
    final path = artworkPath;
    if (path == null) {
      return placeholder;
    }
    final px = (size * MediaQuery.devicePixelRatioOf(context)).round();
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Image.file(
        File(path),
        width: size,
        height: size,
        fit: BoxFit.cover,
        cacheWidth: px,
        gaplessPlayback: true,
        filterQuality: FilterQuality.medium,
        errorBuilder: (context, error, stack) => placeholder,
      ),
    );
  }
}
