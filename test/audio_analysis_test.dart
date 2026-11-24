import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nexa_music/core/audio/audio_analysis.dart';
import 'package:nexa_music/core/audio/audio_analyzer.dart';
import 'package:path/path.dart' as p;

const int rate = 11025;

/// Mono samples: [parts] of (seconds, amplitude 0..1) - a 440 Hz tone.
Int16List signal(List<(double, double)> parts) {
  final out = <int>[];
  var t = 0;
  for (final (seconds, amp) in parts) {
    final n = (seconds * rate).round();
    for (var i = 0; i < n; i++, t++) {
      out.add((math.sin(2 * math.pi * 440 * t / rate) * amp * 32767).round());
    }
  }
  return Int16List.fromList(out);
}

/// A WAV like the one libmpv's "pcm" output writes: WAVE_FORMAT_EXTENSIBLE
/// (a 40-byte "fmt " chunk) and, while streaming, an open data size.
Uint8List mpvWav(Int16List samples, {bool openSize = false}) {
  final h = ByteData(68)
    ..setUint32(0, 0x46464952, Endian.little) // RIFF
    ..setUint32(4, openSize ? 0 : 60 + samples.length * 2, Endian.little)
    ..setUint32(8, 0x45564157, Endian.little) // WAVE
    ..setUint32(12, 0x20746d66, Endian.little) // fmt
    ..setUint32(16, 40, Endian.little)
    ..setUint16(20, 0xFFFE, Endian.little)
    ..setUint16(22, 1, Endian.little)
    ..setUint32(24, rate, Endian.little)
    ..setUint32(28, rate * 2, Endian.little)
    ..setUint16(32, 2, Endian.little)
    ..setUint16(34, 16, Endian.little)
    ..setUint32(60, 0x61746164, Endian.little) // data
    ..setUint32(64, openSize ? 0xFFFFFFFF : samples.length * 2, Endian.little);
  return Uint8List.fromList([
    ...h.buffer.asUint8List(),
    ...samples.buffer.asUint8List(),
  ]);
}

class _FakeDecoder implements AudioDecoder {
  _FakeDecoder(this.samples);

  final Int16List samples;
  final List<String> decoded = [];
  bool fail = false;

  @override
  Future<bool> decode(String input, String output) async {
    decoded.add(input);
    if (fail) {
      return false;
    }
    File(output).writeAsBytesSync(mpvWav(samples));
    return true;
  }
}

void main() {
  group('AudioAnalysis.measure', () {
    test('silent intro and silent tail', () {
      final a = AudioAnalysis.measure(
        signal([(2, 0), (6, 0.5), (4, 0)]),
        rate,
      )!;
      expect(a.duration.inMilliseconds, closeTo(12000, 1));
      expect(a.soundStart.inMilliseconds, closeTo(2000, 60));
      expect(a.soundEnd.inMilliseconds, closeTo(8000, 60));
      expect(a.loudnessDb, closeTo(-9, 0.5)); // RMS of a 0.5 sine
      expect(a.silentTail, isTrue);
    });

    test('a fading outro: where it has become quiet', () {
      // Loud song (-9 dB), then 6 s at -31 dB (outro), then silence.
      final a = AudioAnalysis.measure(
        signal([(20, 0.5), (6, 0.04), (2, 0)]),
        rate,
      )!;
      expect(a.quietEnd.inMilliseconds, closeTo(20000, 60));
      expect(a.soundEnd.inMilliseconds, closeTo(26000, 60));
    });

    test('a song without silence keeps its full length', () {
      final a = AudioAnalysis.measure(signal([(10, 0.5)]), rate)!;
      expect(a.soundStart, Duration.zero);
      expect(a.soundEnd, a.duration);
      expect(a.quietEnd, a.duration);
      expect(a.silentTail, isFalse);
    });

    test('a silent file and a too short one', () {
      final silent = AudioAnalysis.measure(signal([(3, 0)]), rate)!;
      expect(silent.soundEnd, silent.duration);
      expect(silent.soundStart, Duration.zero);
      expect(AudioAnalysis.measure(signal([(0.1, 0.5)]), rate), isNull);
    });
  });

  group('AudioAnalysis.measureWav', () {
    test('reads the libmpv WAV, also with an open data size', () {
      final samples = signal([(1, 0), (3, 0.5), (1, 0)]);
      for (final open in [false, true]) {
        final a = AudioAnalysis.measureWav(mpvWav(samples, openSize: open))!;
        expect(a.soundStart.inMilliseconds, closeTo(1000, 60));
        expect(a.soundEnd.inMilliseconds, closeTo(4000, 60));
      }
      expect(AudioAnalysis.measureWav(Uint8List(10)), isNull);
    });

    test('is kept as JSON', () {
      final a = AudioAnalysis.measure(signal([(1, 0), (3, 0.5)]), rate)!;
      final b = AudioAnalysis.fromJson(a.toJson())!;
      expect(b.soundStart, Duration(milliseconds: a.soundStart.inMilliseconds));
      expect(b.loudnessDb, closeTo(a.loudnessDb, 0.05));
      expect(AudioAnalysis.fromJson({...a.toJson(), 'v': 0}), isNull);
    });
  });

  group('AudioAnalyzer (background, cached)', () {
    late Directory temp;
    late File song;

    setUp(() {
      temp = Directory.systemTemp.createTempSync('nexa_analyzer_test');
      song = File(p.join(temp.path, 'song.mp3'))..writeAsStringSync('audio');
    });
    tearDown(() => temp.deleteSync(recursive: true));

    test('measures once, saves the cache and reads it back', () async {
      final decoder = _FakeDecoder(signal([(1, 0), (4, 0.5), (2, 0)]));
      final analyzer = AudioAnalyzer(
        decoder: decoder,
        cacheDir: () async => temp,
      );
      final updates = <String>[];
      analyzer.updates.listen(updates.add);
      expect(analyzer.cached(song.path), isNull);
      analyzer
        ..request(song.path)
        ..request(song.path);
      await analyzer.idle;
      await Future<void>.delayed(Duration.zero);
      expect(decoder.decoded, [song.path], reason: 'one measurement');
      expect(updates, [song.path]);
      final a = analyzer.cached(song.path)!;
      expect(a.soundStart.inMilliseconds, closeTo(1000, 60));
      expect(
        File(p.join(temp.path, AudioAnalyzer.cacheName)).existsSync(),
        isTrue,
      );
      await analyzer.dispose();

      // Next start: from the cache, nothing decoded again.
      final again = _FakeDecoder(Int16List(0));
      final second = AudioAnalyzer(decoder: again, cacheDir: () async => temp)
        ..request(song.path);
      await second.idle;
      expect(again.decoded, isEmpty);
      expect(
        second.cached(song.path)!.soundStart.inMilliseconds,
        a.soundStart.inMilliseconds,
      );

      // A changed file is not taken from the cache.
      song.writeAsStringSync('other audio, longer');
      expect(second.cached(song.path), isNull);
      await second.dispose();
    });

    test('a failure is not retried; long files are not measured', () async {
      final decoder = _FakeDecoder(Int16List(0))..fail = true;
      final analyzer = AudioAnalyzer(decoder: decoder)
        ..request(song.path);
      await analyzer.idle;
      analyzer.request(song.path);
      await analyzer.idle;
      expect(decoder.decoded, [song.path]);
      expect(analyzer.cached(song.path), isNull);

      final other = File(p.join(temp.path, 'mix.flac'))..writeAsStringSync('x');
      analyzer.request(other.path, duration: const Duration(hours: 1));
      await analyzer.idle;
      expect(decoder.decoded, [song.path]);
      await analyzer.dispose();
    });

    test('without a decoder (tests, other platforms) nothing happens', () async {
      final analyzer = AudioAnalyzer(decoder: null)..request(song.path);
      await analyzer.idle;
      expect(analyzer.cached(song.path), isNull);
      await analyzer.dispose();
    });
  });
}
