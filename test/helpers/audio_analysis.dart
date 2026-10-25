import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

/// Mono samples of a recording (NEXA AutoTest, WASAPI loopback).
class Recording {
  Recording(this.sampleRate, this.samples);

  final int sampleRate;
  final Float32List samples;

  double get seconds => samples.length / sampleRate;

  /// Reads a 16-bit PCM or 32-bit float WAV and mixes it down to mono.
  factory Recording.readWav(String path) {
    final bytes = File(path).readAsBytesSync();
    final data = ByteData.sublistView(bytes);
    String id(int at) => String.fromCharCodes(bytes.sublist(at, at + 4));
    if (bytes.length < 12 || id(0) != 'RIFF' || id(8) != 'WAVE') {
      throw const FormatException('not a WAV file');
    }
    var format = 0, channels = 0, rate = 0, bits = 0;
    var at = 12;
    while (at + 8 <= bytes.length) {
      final chunk = id(at);
      final size = data.getUint32(at + 4, Endian.little);
      final body = at + 8;
      if (chunk == 'fmt ') {
        format = data.getUint16(body, Endian.little);
        channels = data.getUint16(body + 2, Endian.little);
        rate = data.getUint32(body + 4, Endian.little);
        bits = data.getUint16(body + 14, Endian.little);
        if (format == 0xFFFE) {
          format = data.getUint16(body + 24, Endian.little);
        }
      } else if (chunk == 'data') {
        final end = math.min(body + size, bytes.length);
        final width = bits ~/ 8;
        final frames = (end - body) ~/ (width * channels);
        final out = Float32List(frames);
        for (var f = 0; f < frames; f++) {
          var sum = 0.0;
          for (var c = 0; c < channels; c++) {
            final p = body + (f * channels + c) * width;
            sum += format == 3 && bits == 32
                ? data.getFloat32(p, Endian.little)
                : bits == 16
                ? data.getInt16(p, Endian.little) / 32768
                : data.getInt32(p, Endian.little) / 2147483648;
          }
          out[f] = sum / channels;
        }
        return Recording(rate, out);
      }
      at = body + size + (size.isOdd ? 1 : 0);
    }
    throw const FormatException('no data chunk');
  }
}

/// One analysis window.
class AudioWindow {
  AudioWindow(this.time, this.rms, this.peak, this.amplitudes);

  /// Start of the window in seconds.
  final double time;
  final double rms;
  final double peak;

  /// Estimated sine amplitude per frequency (Hz).
  final Map<double, double> amplitudes;
}

/// Goertzel amplitude of [freq] in samples[start, start + n) (Hann window).
double toneAmplitude(Float32List s, int start, int n, int rate, double freq) {
  final w = 2 * math.pi * freq / rate;
  final coeff = 2 * math.cos(w);
  var q1 = 0.0, q2 = 0.0, windowSum = 0.0;
  for (var i = 0; i < n; i++) {
    final hann = 0.5 - 0.5 * math.cos(2 * math.pi * i / (n - 1));
    windowSum += hann;
    final q0 = coeff * q1 - q2 + s[start + i] * hann;
    q2 = q1;
    q1 = q0;
  }
  final power = q1 * q1 + q2 * q2 - q1 * q2 * coeff;
  return 2 * math.sqrt(math.max(power, 0)) / windowSum;
}

List<AudioWindow> analyze(
  Recording r,
  Iterable<double> freqs, {
  double windowSeconds = 0.02,
}) {
  final n = (windowSeconds * r.sampleRate).round();
  final out = <AudioWindow>[];
  for (var start = 0; start + n <= r.samples.length; start += n) {
    var sq = 0.0, peak = 0.0;
    for (var i = start; i < start + n; i++) {
      final v = r.samples[i];
      sq += v * v;
      peak = math.max(peak, v.abs());
    }
    out.add(
      AudioWindow(start / r.sampleRate, math.sqrt(sq / n), peak, {
        for (final f in freqs) f: toneAmplitude(r.samples, start, n, r.sampleRate, f),
      }),
    );
  }
  return out;
}

/// What a transition from tone [a] to tone [b] looked like.
class TransitionMeasure {
  TransitionMeasure({
    required this.found,
    this.overlap = 0,
    this.gap = 0,
    this.peak = 0,
    this.minLevelRatio = 0,
    this.maxLevelRatio = 0,
    this.lastA = 0,
    this.firstB = 0,
  });

  /// Both tones were heard.
  final bool found;

  /// Seconds both tones were audible at the same time.
  final double overlap;

  /// Seconds of silence between the end of [a] and the start of [b].
  final double gap;

  /// Highest sample value in the recording (1.0 = clipping).
  final double peak;

  /// Lowest / highest combined level during the overlap relative to the
  /// steady level of [a] before it (equal-power crossfade: about 1.0).
  final double minLevelRatio;
  final double maxLevelRatio;
  final double lastA;
  final double firstB;

  Map<String, Object> toJson() => {
    'found': found,
    'overlapSeconds': _r(overlap),
    'gapSeconds': _r(gap),
    'peak': _r(peak),
    'minLevelRatio': _r(minLevelRatio),
    'maxLevelRatio': _r(maxLevelRatio),
    'lastA': _r(lastA),
    'firstB': _r(firstB),
  };
}

double _r(double v) => (v * 1000).round() / 1000;

/// Measures the hand-over from tone [a] to tone [b]. A tone counts as
/// audible above [threshold] x its own loudest level (default -30 dB).
TransitionMeasure measureTransition(
  List<AudioWindow> w,
  double a,
  double b, {
  double threshold = 0.03,
  double steadySeconds = 0.2,
}) {
  if (w.isEmpty) {
    return TransitionMeasure(found: false);
  }
  final refA = w.map((x) => x.amplitudes[a]!).reduce(math.max);
  final refB = w.map((x) => x.amplitudes[b]!).reduce(math.max);
  final peak = w.map((x) => x.peak).reduce(math.max);
  if (refA < 1e-4 || refB < 1e-4) {
    return TransitionMeasure(found: false, peak: peak);
  }
  bool hasA(AudioWindow x) => x.amplitudes[a]! > refA * threshold;
  bool hasB(AudioWindow x) => x.amplitudes[b]! > refB * threshold;
  final step = w.length > 1 ? w[1].time - w[0].time : 0.02;
  // A tone counts from where it stays audible for [steadySeconds] (80 % of
  // the windows), so a short stray detection - a click, another sound that
  // happens to contain the frequency - does not move the transition.
  final span = math.max(1, (steadySeconds / step).round());
  bool steadyFrom(int i, bool Function(AudioWindow) has) {
    final end = math.min(w.length, i + span);
    var hits = 0;
    for (var k = i; k < end; k++) {
      if (has(w[k])) {
        hits++;
      }
    }
    return has(w[i]) && hits >= (end - i) * 0.8;
  }

  bool steadyUntil(int i, bool Function(AudioWindow) has) {
    final start = math.max(0, i - span + 1);
    var hits = 0;
    for (var k = start; k <= i; k++) {
      if (has(w[k])) {
        hits++;
      }
    }
    return has(w[i]) && hits >= (i - start + 1) * 0.8;
  }

  var firstB = -1;
  for (var i = 0; i < w.length; i++) {
    if (steadyFrom(i, hasB)) {
      firstB = i;
      break;
    }
  }
  var lastA = -1;
  for (var i = w.length - 1; i >= 0; i--) {
    if (steadyUntil(i, hasA)) {
      lastA = i;
      break;
    }
  }
  if (firstB < 0 || lastA < 0) {
    return TransitionMeasure(found: false, peak: peak);
  }
  var both = 0;
  for (var i = firstB; i <= lastA; i++) {
    if (hasA(w[i]) && hasB(w[i])) {
      both++;
    }
  }
  final gapWindows = firstB - lastA - 1;
  // Steady level of A: median RMS of the second before the overlap.
  final steadyEnd = math.max(0, math.min(firstB, lastA) - 2);
  final steadyStart = math.max(0, steadyEnd - (1 / step).round());
  final steady = [for (var i = steadyStart; i < steadyEnd; i++) w[i].rms]..sort();
  final ref = steady.isEmpty ? 0.0 : steady[steady.length ~/ 2];
  var minRatio = double.infinity, maxRatio = 0.0;
  if (ref > 0) {
    for (var i = firstB; i <= lastA; i++) {
      final ratio = w[i].rms / ref;
      minRatio = math.min(minRatio, ratio);
      maxRatio = math.max(maxRatio, ratio);
    }
  }
  return TransitionMeasure(
    found: true,
    overlap: both * step,
    gap: gapWindows > 0 ? gapWindows * step : 0,
    peak: peak,
    minLevelRatio: minRatio.isFinite ? minRatio : 0,
    maxLevelRatio: maxRatio,
    lastA: w[lastA].time,
    firstB: w[firstB].time,
  );
}

/// Segments of the loudest tone over time (which track was audible).
class Segment {
  Segment(this.frequency, this.start, this.end);

  final double frequency;
  final double start;
  double end;

  double get length => end - start;
}

List<Segment> toneSegments(
  List<AudioWindow> w,
  List<double> freqs, {
  double threshold = 0.1,
}) {
  if (w.isEmpty) {
    return const [];
  }
  final ref = {
    for (final f in freqs) f: w.map((x) => x.amplitudes[f]!).reduce(math.max),
  };
  final global = ref.values.reduce(math.max);
  final step = w.length > 1 ? w[1].time - w[0].time : 0.02;
  final out = <Segment>[];
  for (final x in w) {
    double? best;
    var bestAmp = global * threshold;
    for (final f in freqs) {
      if (x.amplitudes[f]! > bestAmp) {
        bestAmp = x.amplitudes[f]!;
        best = f;
      }
    }
    if (best == null) {
      continue;
    }
    if (out.isNotEmpty &&
        out.last.frequency == best &&
        x.time - out.last.end < 3 * step) {
      out.last.end = x.time + step;
    } else {
      out.add(Segment(best, x.time, x.time + step));
    }
  }
  // Drop blips shorter than 0.1 s (window edges between two tones).
  return [
    for (final s in out)
      if (s.length >= 0.1) s,
  ];
}

/// Seconds with (almost) no sound between the first and last audible window.
double longestSilence(List<AudioWindow> w, {double ratio = 0.01}) {
  if (w.isEmpty) {
    return 0;
  }
  final ref = w.map((x) => x.rms).reduce(math.max);
  final step = w.length > 1 ? w[1].time - w[0].time : 0.02;
  final first = w.indexWhere((x) => x.rms > ref * ratio);
  final last = w.lastIndexWhere((x) => x.rms > ref * ratio);
  var longest = 0, run = 0;
  for (var i = first; i <= last && i >= 0; i++) {
    if (w[i].rms <= ref * ratio) {
      run++;
      longest = math.max(longest, run);
    } else {
      run = 0;
    }
  }
  return longest * step;
}
