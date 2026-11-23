// Smart Mix: can libmpv measure silence / level while it plays? (D-026)
//
//   flutter test integration_test/smart_mix_quiet_test.dart -d windows
//
// A generated WAV (6 s tone, then 8 s silence) plays through libmpv, silent
// for the user (volume 0), with each candidate FFmpeg audio filter. Result
// on the owner's PC (2026-11-23, log 261): the libmpv of
// media_kit_libs_windows_audio accepts none of them ("Audio filter
// initialized failed!", "lavfi-silencedetect doesn't exist") - playback
// stops. So Smart Mix v1 cannot analyse silence or level in the engine; it
// stays LIMITED to track length and albums (reports/FEATURE_COMPLETE_REPORT.md).
// The test passes when the plain file plays; it prints what each filter did.
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:path/path.dart' as p;

File _toneThenSilence(String path) {
  const rate = 44100;
  const toneSeconds = 6;
  const silenceSeconds = 8;
  const frames = rate * (toneSeconds + silenceSeconds);
  final data = ByteData(frames * 2);
  for (var i = 0; i < frames; i++) {
    final v = i < rate * toneSeconds
        ? (math.sin(2 * math.pi * 440 * i / rate) * 0.5 * 32767).round()
        : 0;
    data.setInt16(i * 2, v, Endian.little);
  }
  final header = ByteData(44)
    ..setUint32(0, 0x46464952, Endian.little) // RIFF
    ..setUint32(4, 36 + frames * 2, Endian.little)
    ..setUint32(8, 0x45564157, Endian.little) // WAVE
    ..setUint32(12, 0x20746d66, Endian.little) // fmt
    ..setUint32(16, 16, Endian.little)
    ..setUint16(20, 1, Endian.little)
    ..setUint16(22, 1, Endian.little)
    ..setUint32(24, rate, Endian.little)
    ..setUint32(28, rate * 2, Endian.little)
    ..setUint16(32, 2, Endian.little)
    ..setUint16(34, 16, Endian.little)
    ..setUint32(36, 0x61746164, Endian.little) // data
    ..setUint32(40, frames * 2, Endian.little);
  return File(path)
    ..writeAsBytesSync([
      ...header.buffer.asUint8List(),
      ...data.buffer.asUint8List(),
    ]);
}

const List<String> candidates = [
  '',
  '@nexaquiet:lavfi=[silencedetect=n=-40dB:d=1.5]',
  '@nexaquiet:lavfi=[silencedetect=n=0.01:d=1.5]',
  '@nexaquiet:lavfi="silencedetect=n=0.01:d=1.5"',
  '@nexaquiet:lavfi-silencedetect=n=0.01:d=1.5',
  '@nexaquiet:lavfi=[astats=metadata=1:reset=1]',
];

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

  testWidgets('Smart Mix: which quiet filters libmpv accepts', (tester) async {
    await tester.runAsync(() async {
      final temp = Directory.systemTemp.createTempSync('nexa_quiet');
      final file = _toneThenSilence(p.join(temp.path, 'quiet_end.wav'));
      for (final af in candidates) {
        final player = Player();
        final errors = <String>[];
        final sub = player.stream.error.listen(errors.add);
        final native = player.platform! as NativePlayer;
        var meta = '';
        try {
          await native.setProperty('volume', '0');
          if (af.isNotEmpty) {
            await native.setProperty('af', af);
          }
          await player.open(Media(file.path));
          final end = DateTime.now().add(const Duration(seconds: 9));
          while (DateTime.now().isBefore(end)) {
            await Future<void>.delayed(const Duration(milliseconds: 500));
            if (af.isNotEmpty) {
              try {
                final m = await native.getProperty('af-metadata/nexaquiet');
                if (m.isNotEmpty) {
                  meta = m;
                }
              } on Object catch (e) {
                meta = 'getProperty error: $e';
              }
            }
          }
          final afNow = await native.getProperty('af');
          if (af.isEmpty) {
            expect(errors, isEmpty);
            expect(player.state.position, greaterThan(Duration.zero));
          }
          // ignore: avoid_print
          print(
            'QUIETRESULT af=<$af> position=${player.state.position} '
            'errors=$errors afNow=<$afNow> meta=<${meta.length > 300 ? meta.substring(0, 300) : meta}>',
          );
        } finally {
          await sub.cancel();
          await player.dispose();
        }
      }
      try {
        temp.deleteSync(recursive: true);
      } on FileSystemException {
        // Removed later.
      }
    });
  });
}
