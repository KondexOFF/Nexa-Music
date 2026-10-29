// Measures one song transition in a WASAPI loopback recording of the real
// NEXA exe (tools/exe_audio/exe_mix_check.ps1). Same analysis and the same
// pass criteria as the NEXA AutoTest mix checks (AT-11..AT-14).
//
//   dart tools/exe_audio/analyze_mix.dart <recording.wav> <freqA> <freqB> <crossfade|gapless> [seconds]
//
// Prints one JSON line: overlap / gap / peak / levels, where song A was last
// heard and song B first heard, and "ok".
import 'dart:convert';
import 'dart:io';

import '../../test/helpers/audio_analysis.dart';

void main(List<String> args) {
  if (args.length < 4) {
    stderr.writeln('usage: analyze_mix.dart <wav> <freqA> <freqB> <crossfade|gapless> [seconds]');
    exit(2);
  }
  final a = double.parse(args[1]);
  final b = double.parse(args[2]);
  final kind = args[3];
  final seconds = args.length > 4 ? double.parse(args[4]) : 0.0;
  final rec = Recording.readWav(args[0]);
  final x = measureTransition(analyze(rec, [a, b]), a, b);
  final crossfadeOk =
      x.overlap >= seconds * 0.85 - 0.3 &&
      x.overlap <= seconds * 1.1 + 0.3 &&
      x.gap <= 0.06 &&
      x.peak < 0.98 &&
      x.minLevelRatio >= 0.55 &&
      x.maxLevelRatio <= 1.4;
  final gaplessOk = x.overlap <= 0.04 && x.gap <= 0.02 && x.peak < 0.98;
  final ok = x.found && (kind == 'crossfade' ? crossfadeOk : gaplessOk);
  stdout.writeln(
    jsonEncode({
      ...x.toJson(),
      'recordingSeconds': rec.seconds,
      'expect': kind,
      'seconds': seconds,
      'ok': ok,
    }),
  );
}
