import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'helpers/audio_analysis.dart';

/// The analyser NEXA AutoTest uses on loopback recordings, checked with
/// generated signals whose answer is known.
void main() {
  const rate = 8000;

  Recording render(
    double seconds,
    double Function(double t) gainA,
    double Function(double t) gainB, {
    double a = 440,
    double b = 660,
  }) {
    final n = (seconds * rate).round();
    final s = Float32List(n);
    for (var i = 0; i < n; i++) {
      final t = i / rate;
      s[i] =
          0.5 * gainA(t) * math.sin(2 * math.pi * a * t) +
          0.5 * gainB(t) * math.sin(2 * math.pi * b * t);
    }
    return Recording(rate, s);
  }

  test('equal-power crossfade of 3 s is measured as about 3 s, level kept',
      () {
    double fade(double t) => ((t - 2) / 3).clamp(0.0, 1.0);
    final r = render(
      7,
      (t) => math.cos(fade(t) * math.pi / 2),
      (t) => t < 2 ? 0 : math.sin(fade(t) * math.pi / 2),
    );
    final m = measureTransition(analyze(r, [440, 660]), 440, 660);
    expect(m.found, isTrue);
    expect(m.overlap, inInclusiveRange(2.7, 3.1));
    expect(m.gap, 0);
    expect(m.peak, lessThan(0.75));
    expect(m.minLevelRatio, greaterThan(0.8));
    expect(m.maxLevelRatio, lessThan(1.2));
  });

  test('a hard cut has no overlap; a pause shows as a gap', () {
    final cut = render(4, (t) => t < 2 ? 1 : 0, (t) => t < 2 ? 0 : 1);
    final m = measureTransition(analyze(cut, [440, 660]), 440, 660);
    expect(m.overlap, lessThanOrEqualTo(0.04));
    expect(m.gap, 0);

    final paused = render(4, (t) => t < 1.5 ? 1 : 0, (t) => t < 2 ? 0 : 1);
    final p = measureTransition(analyze(paused, [440, 660]), 440, 660);
    expect(p.gap, inInclusiveRange(0.44, 0.52));
    expect(longestSilence(analyze(paused, [440, 660])), inInclusiveRange(0.44, 0.52));
  });

  test('short stray detections of the other tone do not count as overlap', () {
    // A at 0-3 s, B at 3-6 s, plus 40 ms blips of B at 1 s and of A at 5 s
    // (like another program's sound that contains the frequency).
    bool blip(double t, double at) => t >= at && t < at + 0.04;
    final r = render(
      6,
      (t) => t < 3 || blip(t, 5) ? 1 : 0,
      (t) => t >= 3 || blip(t, 1) ? 1 : 0,
    );
    final m = measureTransition(analyze(r, [440, 660]), 440, 660);
    expect(m.found, isTrue);
    expect(m.overlap, lessThanOrEqualTo(0.04));
    expect(m.gap, 0);
    expect(m.firstB, inInclusiveRange(2.96, 3.02));
    expect(m.lastA, inInclusiveRange(2.96, 3.02));
  });

  test('tone segments follow the order of tracks', () {
    final r = render(
      6,
      (t) => t < 3 ? 1 : 0,
      (t) => t < 3 ? 0 : 1,
    );
    final seg = toneSegments(analyze(r, [440, 660]), [440, 660]);
    expect([for (final s in seg) s.frequency], [440, 660]);
    expect(seg.first.length, inInclusiveRange(2.9, 3.05));
  });

  test('clipping is visible in the peak', () {
    final s = Float32List.fromList([0.2, 1.0, -1.0, 0.3]);
    final w = analyze(Recording(4, s), [1], windowSeconds: 1);
    expect(w.single.peak, 1.0);
  });
}
