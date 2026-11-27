import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/theme/tokens.dart';
import '../core/models/track.dart';
import '../features/player/player_controller.dart';
import 'cover_art.dart';

/// NEXARYVE 1.2 "the song lights the room": one soft colour taken from the
/// playing song's artwork. Library artwork is measured once (24 px decode,
/// the most colourful pixels weigh most) and cached by path; generated covers
/// give their own palette colour; nothing playing = NEXARYVE lavender.
class ArtworkLight {
  ArtworkLight._();

  static final Map<String, Color> _cache = {};

  /// Light of [track] right away when known (cache or generated cover).
  static Color? quick(Track? track) {
    if (track == null) {
      return null;
    }
    final path = track.artworkPath;
    if (path == null || path.startsWith('https://')) {
      return coverLight(coverPaletteForSeed(track.id));
    }
    return _cache[path];
  }

  /// Light of [track], measuring a library artwork file when needed.
  static Future<Color?> of(Track? track) async {
    final known = quick(track);
    if (known != null || track == null) {
      return known;
    }
    final path = track.artworkPath!;
    try {
      final bytes = await File(path).readAsBytes();
      final color = await measure(bytes);
      if (color != null) {
        _cache[path] = color;
      }
      return color ?? coverLight(coverPaletteForSeed(track.id));
    } on Object {
      return coverLight(coverPaletteForSeed(track.id));
    }
  }

  /// The characteristic colour of an encoded image, made pleasant as a
  /// light: saturated but never neon, mid lightness.
  static Future<Color?> measure(Uint8List encoded) async {
    final codec = await ui.instantiateImageCodec(
      encoded,
      targetWidth: 24,
      targetHeight: 24,
    );
    final frame = await codec.getNextFrame();
    final data = await frame.image.toByteData();
    frame.image.dispose();
    codec.dispose();
    if (data == null) {
      return null;
    }
    return fromRgba(data.buffer.asUint8List());
  }

  /// [measure] on raw RGBA pixels (tests use it directly).
  static Color? fromRgba(Uint8List rgba) {
    var r = 0.0, g = 0.0, b = 0.0, weight = 0.0;
    for (var i = 0; i + 3 < rgba.length; i += 4) {
      if (rgba[i + 3] < 128) {
        continue;
      }
      final c = Color.fromARGB(255, rgba[i], rgba[i + 1], rgba[i + 2]);
      final hsl = HSLColor.fromColor(c);
      // Colourful, not too dark or washed out pixels decide the light.
      final w = 0.05 +
          hsl.saturation * (1 - (hsl.lightness - 0.5).abs() * 2).clamp(0, 1);
      r += rgba[i] * w;
      g += rgba[i + 1] * w;
      b += rgba[i + 2] * w;
      weight += w;
    }
    if (weight == 0) {
      return null;
    }
    final mean = Color.fromARGB(
      255,
      (r / weight).round().clamp(0, 255),
      (g / weight).round().clamp(0, 255),
      (b / weight).round().clamp(0, 255),
    );
    final hsl = HSLColor.fromColor(mean);
    return hsl
        .withSaturation(math.min(0.7, math.max(0.28, hsl.saturation)))
        .withLightness(hsl.lightness.clamp(0.53, 0.65))
        .toColor();
  }
}

/// The light of the playing song (lavender when nothing plays).
final ambientLightProvider = NotifierProvider<AmbientLightController, Color>(
  AmbientLightController.new,
);

class AmbientLightController extends Notifier<Color> {
  int _token = 0;
  Color _last = NexaColors.accent;

  @override
  Color build() {
    final track = ref.watch(playerProvider.select((p) => p.current));
    final token = ++_token;
    if (track == null) {
      return _last = NexaColors.accent;
    }
    final quick = ArtworkLight.quick(track);
    if (quick != null) {
      return _last = quick;
    }
    unawaited(
      ArtworkLight.of(track).then((c) {
        if (ref.mounted && token == _token && c != null) {
          _last = c;
          state = c;
        }
      }),
    );
    // The previous light stays until this artwork is measured.
    return _last;
  }
}

/// A very soft radial light in the song's colour behind [child], changing
/// smoothly with the song (no more than [strength] opacity).
class AmbientBackdrop extends ConsumerWidget {
  const AmbientBackdrop({
    super.key,
    required this.child,
    this.strength = 0.16,
    this.alignment = const Alignment(-0.35, -1.25),
    this.radius = 1.25,
  });

  final Widget child;
  final double strength;
  final Alignment alignment;
  final double radius;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final light = ref.watch(ambientLightProvider);
    return TweenAnimationBuilder<Color?>(
      tween: ColorTween(end: light),
      duration: NexaMotion.ambient,
      curve: Curves.easeInOut,
      builder: (context, color, child) => DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: alignment,
            radius: radius,
            colors: [
              (color ?? light).withValues(alpha: strength),
              (color ?? light).withValues(alpha: strength * 0.35),
              (color ?? light).withValues(alpha: 0),
            ],
            stops: const [0, 0.42, 1],
          ),
        ),
        child: child,
      ),
      child: child,
    );
  }
}
