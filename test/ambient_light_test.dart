import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexa_music/ui/ambient_light.dart';

Uint8List pixels(List<Color> colors) => Uint8List.fromList([
  for (final c in colors) ...[
    (c.r * 255).round(),
    (c.g * 255).round(),
    (c.b * 255).round(),
    (c.a * 255).round(),
  ],
]);

void main() {
  test('colourful pixels decide the light; it stays pleasant', () {
    final light = ArtworkLight.fromRgba(
      pixels([
        ...List.filled(30, const Color(0xFF101010)), // dark background
        ...List.filled(10, const Color(0xFFE0483A)), // a red subject
      ]),
    )!;
    final hsl = HSLColor.fromColor(light);
    expect(hsl.hue, anyOf(lessThan(30), greaterThan(330)), reason: 'red wins');
    expect(hsl.lightness, inInclusiveRange(0.5, 0.68));
    expect(hsl.saturation, inInclusiveRange(0.25, 0.72));
  });

  test('grey artwork still gives a calm light; transparent gives none', () {
    final grey = ArtworkLight.fromRgba(
      pixels(List.filled(16, const Color(0xFF808080))),
    )!;
    expect(HSLColor.fromColor(grey).lightness, inInclusiveRange(0.5, 0.68));
    expect(
      ArtworkLight.fromRgba(pixels(List.filled(4, const Color(0x00FF0000)))),
      isNull,
    );
  });
}
