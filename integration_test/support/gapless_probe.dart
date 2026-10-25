// NEXA AutoTest - diagnostic group "probe" (run only when asked for with
// -Groups probe). Plays six test files in a row with a bare media_kit player
// in several mpv configurations and records each run, to find out which
// setting causes skipped songs or silence at gapless transitions. Writes the
// mpv log of every variant to <out>/probe/.
import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:media_kit/media_kit.dart' as mk;
import 'package:path/path.dart' as p;

import '../../test/helpers/audio_analysis.dart';
import 'autotest_support.dart';

class _Variant {
  const _Variant(this.name, {required this.incremental, this.prefetch = true, this.gapless = 'weak'});

  final String name;

  /// Next file appended when the previous one starts (as NEXA does), or
  /// the whole list opened at once.
  final bool incremental;
  final bool prefetch;
  final String gapless;
}

const _variants = [
  _Variant('upfront', incremental: false),
  _Variant('incremental', incremental: true),
  _Variant('incremental-noprefetch', incremental: true, prefetch: false),
  _Variant('incremental-gapless-yes', incremental: true, gapless: 'yes'),
];

Future<void> gaplessProbe(AutoTestResults r, LibraryManifest m, Loopback loop) async {
  const files = [
    'seq/seq_01.wav',
    'seq/seq_02.mp3',
    'seq/seq_03.flac',
    'seq/seq_04.wav',
    'seq/seq_05.mp3',
    'seq/seq_06.flac',
  ];
  final paths = [for (final f in files) p.join(AutoTestConfig.library, f.replaceAll('/', p.separator))];
  final freqs = [for (final f in files) m.frequency(f)];
  final seconds = files.fold<double>(0, (s, f) => s + m.seconds(f));
  final logDir = Directory(p.join(AutoTestConfig.out, 'probe'))..createSync(recursive: true);

  for (final v in _variants) {
    final player = mk.Player(configuration: mk.PlayerConfiguration(logLevel: mk.MPVLogLevel.v));
    final log = StringBuffer();
    String now() => DateTime.now().toIso8601String().substring(11);
    final subs = <StreamSubscription<Object?>>[
      player.stream.log.listen((l) => log.writeln('${now()} [${l.prefix}] ${l.level}: ${l.text.trim()}')),
      player.stream.playlist.listen((pl) => log.writeln('${now()} PLAYLIST index ${pl.index} of ${pl.medias.length}')),
    ];
    try {
      final native = player.platform as mk.NativePlayer;
      await native.setProperty('prefetch-playlist', v.prefetch ? 'yes' : 'no');
      await native.setProperty('gapless-audio', v.gapless);
      var appended = 1;
      if (v.incremental) {
        subs.add(player.stream.playlist.listen((pl) {
          if (pl.index == appended - 1 && appended < paths.length) {
            log.writeln('${now()} APPEND ${files[appended]}');
            unawaited(player.add(mk.Media(paths[appended])));
            appended++;
          }
        }));
      }
      final rec = await loop.record('probe_${v.name}', seconds + 3, () async {
        if (v.incremental) {
          await player.open(mk.Media(paths.first));
        } else {
          await player.open(mk.Playlist([for (final x in paths) mk.Media(x)]));
        }
        await pause(seconds + 1.5);
      });
      if (rec == null) {
        r.blocked('PROBE-${v.name}', '-', 'Gapless probe: ${v.name}', loop.lastError ?? '');
        continue;
      }
      final w = analyze(rec, freqs, windowSeconds: 0.01);
      final segments = toneSegments(w, freqs);
      final heard = [for (final s in segments) s.frequency];
      final shortest = segments.isEmpty ? 0.0 : segments.map((s) => s.length).reduce(math.min);
      var maxGap = 0.0;
      for (var i = 0; i + 1 < freqs.length; i++) {
        final t = measureTransition(w, freqs[i], freqs[i + 1]);
        if (t.found) {
          maxGap = math.max(maxGap, t.gap);
        }
      }
      final missing = [
        for (var i = 0; i < files.length; i++)
          if (!heard.contains(freqs[i])) files[i],
      ];
      final ok = missing.isEmpty && heard.length == files.length && shortest >= 5.8 && maxGap <= 0.02;
      r.add(
        'PROBE-${v.name}',
        '-',
        'Diagnostic: 6 files in a row with a bare media_kit player (${v.incremental ? 'next file appended when the previous starts' : 'whole list opened at once'}, '
            'prefetch-playlist=${v.prefetch ? 'yes' : 'no'}, gapless-audio=${v.gapless})',
        ok ? 'PASS' : 'FAIL',
        detail: 'heard ${heard.length} of 6 in ${missing.isEmpty ? 'full' : 'part'}; shortest ${shortest.toStringAsFixed(2)} s; '
            'largest gap ${maxGap.toStringAsFixed(3)} s${missing.isEmpty ? '' : '; not heard: ${missing.join(', ')}'}',
      );
    } on Object catch (e) {
      r.blocked('PROBE-${v.name}', '-', 'Gapless probe: ${v.name}', '$e');
    } finally {
      for (final s in subs) {
        await s.cancel();
      }
      await player.dispose();
      File(p.join(logDir.path, 'mpv_${v.name}.log')).writeAsStringSync(log.toString());
    }
  }
}
