// Smart Mix analysis (D-026 final): can NEXA's own libmpv decode a file to
// PCM in a separate, silent player (ao=pcm, untimed) - independent of the
// playback decks - so NEXA can measure silence and level itself?
//
//   flutter test integration_test/audio_analysis_probe_test.dart -d windows
//
// Nothing is played on a sound device: the "pcm" output writes a file.
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:nexa_music/core/audio/audio_analyzer.dart';
import 'package:path/path.dart' as p;

File _wav(String path) {
  // 2 s silence, 6 s tone, 4 s silence.
  const rate = 44100;
  const frames = rate * 12;
  final data = ByteData(frames * 2);
  for (var i = 0; i < frames; i++) {
    final t = i / rate;
    final v = t >= 2 && t < 8
        ? (math.sin(2 * math.pi * 440 * t) * 0.5 * 32767).round()
        : 0;
    data.setInt16(i * 2, v, Endian.little);
  }
  final h = ByteData(44)
    ..setUint32(0, 0x46464952, Endian.little)
    ..setUint32(4, 36 + frames * 2, Endian.little)
    ..setUint32(8, 0x45564157, Endian.little)
    ..setUint32(12, 0x20746d66, Endian.little)
    ..setUint32(16, 16, Endian.little)
    ..setUint16(20, 1, Endian.little)
    ..setUint16(22, 1, Endian.little)
    ..setUint32(24, rate, Endian.little)
    ..setUint32(28, rate * 2, Endian.little)
    ..setUint16(32, 2, Endian.little)
    ..setUint16(34, 16, Endian.little)
    ..setUint32(36, 0x61746164, Endian.little)
    ..setUint32(40, frames * 2, Endian.little);
  return File(path)
    ..writeAsBytesSync([...h.buffer.asUint8List(), ...data.buffer.asUint8List()]);
}

Future<String> _decode(String input, String output) async {
  final player = Player(
    configuration: const PlayerConfiguration(title: 'NEXA analysis'),
  );
  final native = player.platform! as NativePlayer;
  final errors = <String>[];
  final sub = player.stream.error.listen(errors.add);
  final sw = Stopwatch()..start();
  try {
    for (final e in {
      'vid': 'no',
      'ao': 'pcm',
      'ao-pcm-file': output,
      'ao-pcm-waveheader': 'yes',
      'untimed': 'yes',
      'audio-samplerate': '11025',
      'audio-channels': 'mono',
      'audio-format': 's16',
      'volume': '100',
    }.entries) {
      try {
        await native.setProperty(e.key, e.value);
      } on Object catch (err) {
        errors.add('set ${e.key}: $err');
      }
    }
    await player.open(Media(input));
    final end = DateTime.now().add(const Duration(seconds: 60));
    while (DateTime.now().isBefore(end) && !player.state.completed) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    final ao = await native.getProperty('current-ao');
    return 'completed=${player.state.completed} ms=${sw.elapsedMilliseconds} '
        'ao=<$ao> errors=$errors';
  } finally {
    await sub.cancel();
    await player.dispose();
  }
}

String _summary(File wav) {
  if (!wav.existsSync()) {
    return 'no output file';
  }
  final b = wav.readAsBytesSync();
  if (b.length < 44) {
    return 'output too short (${b.length} bytes)';
  }
  final bd = ByteData.sublistView(b);
  final rate = bd.getUint32(24, Endian.little);
  final ch = bd.getUint16(22, Endian.little);
  final bits = bd.getUint16(34, Endian.little);
  final n = (b.length - 44) ~/ 2;
  // RMS per 100 ms.
  final win = rate ~/ 10;
  final levels = <int>[];
  for (var s = 0; s + win <= n; s += win) {
    var sum = 0.0;
    for (var i = s; i < s + win; i++) {
      final v = bd.getInt16(44 + i * 2, Endian.little) / 32768;
      sum += v * v;
    }
    final rms = math.sqrt(sum / win);
    levels.add(rms <= 0 ? -120 : (20 * math.log(rms) / math.ln10).round());
  }
  final loud = [for (var i = 0; i < levels.length; i++) if (levels[i] > -50) i];
  return 'bytes=${b.length} rate=$rate ch=$ch bits=$bits windows=${levels.length} '
      'firstLoud=${loud.isEmpty ? '-' : loud.first / 10}s '
      'lastLoud=${loud.isEmpty ? '-' : (loud.last + 1) / 10}s '
      'levels=${levels.take(130).join(',')}';
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

  testWidgets('libmpv decodes to PCM in a separate silent player', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final temp = Directory.systemTemp.createTempSync('nexa_analysis');
      final inputs = <String>[
        _wav(p.join(temp.path, 'probe.wav')).path,
        // The AutoTest library next to the repository (not committed).
        for (final f in ['mix/mix_b.flac', 'mix/mix_c.mp3'])
          p.normalize(p.join(Directory.current.path, '..', '_autotest_library', f)),
      ];
      var ok = false;
      for (final input in inputs) {
        if (!File(input).existsSync()) {
          // ignore: avoid_print
          print('ANALYSIS ${p.basename(input)}: missing');
          continue;
        }
        final out = p.join(temp.path, '${p.basenameWithoutExtension(input)}.pcm.wav');
        final info = await _decode(input, out);
        final sum = _summary(File(out));
        // ignore: avoid_print
        print('ANALYSIS ${p.basename(input)}: $info | $sum');
        ok = ok || sum.startsWith('bytes=');
      }

      // The production analyzer (what Smart Mix uses): decoder, measurement
      // in an isolate and the cache file.
      final analyzer = AudioAnalyzer(
        decoder: const MpvPcmDecoder(),
        cacheDir: () async => temp,
      );
      final sw = Stopwatch()..start();
      for (final input in inputs.where((f) => File(f).existsSync())) {
        analyzer.request(input);
      }
      await analyzer.idle;
      for (final input in inputs.where((f) => File(f).existsSync())) {
        final a = analyzer.cached(input);
        // ignore: avoid_print
        print('ANALYZER ${p.basename(input)}: ${a?.toJson()}');
      }
      // ignore: avoid_print
      print('ANALYZER total ms=${sw.elapsedMilliseconds} cache='
          '${File(p.join(temp.path, AudioAnalyzer.cacheName)).existsSync()}');
      final probe = analyzer.cached(inputs.first);
      await analyzer.dispose();
      try {
        temp.deleteSync(recursive: true);
      } on FileSystemException {
        // Removed later.
      }
      expect(ok, isTrue, reason: 'see the ANALYSIS lines');
      expect(probe, isNotNull, reason: 'the analyzer measured nothing');
      expect(probe!.soundStart.inMilliseconds, closeTo(2000, 100));
      expect(probe.soundEnd.inMilliseconds, closeTo(8000, 150));
      expect(probe.duration.inMilliseconds, closeTo(12000, 150));
    });
  });
}
