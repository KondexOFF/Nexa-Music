// Smart Mix (D-026 Final) end to end on the real engine: NEXA measures the
// files with its own silent decoder, plans the transition from the
// measurement and the two media_kit decks hand over early - the silent tail
// of the first song is skipped, the second starts after its silent intro.
//
//   flutter test integration_test/smart_mix_engine_test.dart -d windows
//
// Silent run: NEXA's volume is 0 (both decks), the measurement writes to a
// file, never to a sound device. A temporary profile.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:media_kit/media_kit.dart' show MediaKit;
import 'package:nexa_music/app/strings.dart';
import 'package:nexa_music/core/audio/audio_analyzer.dart';
import 'package:nexa_music/core/audio/transition.dart';
import 'package:nexa_music/core/database/app_database.dart';
import 'package:nexa_music/core/models/track.dart';
import 'package:nexa_music/features/library/library_providers.dart';
import 'package:nexa_music/features/mix_engine/mix_settings.dart';
import 'package:nexa_music/features/player/player_controller.dart';
import 'package:path/path.dart' as p;

/// A 16-bit mono WAV of [parts]: (seconds, sound) - a 440 Hz tone or
/// silence.
String writeToneWav(String path, List<(double, bool)> parts) {
  const rate = 22050;
  final samples = <int>[];
  var t = 0;
  for (final (seconds, sound) in parts) {
    final n = (seconds * rate).round();
    for (var i = 0; i < n; i++, t++) {
      samples.add(
        sound ? (math.sin(2 * math.pi * 440 * t / rate) * 0.4 * 32767).round() : 0,
      );
    }
  }
  final data = ByteData(44 + samples.length * 2)
    ..setUint32(0, 0x46464952, Endian.little)
    ..setUint32(4, 36 + samples.length * 2, Endian.little)
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
    ..setUint32(40, samples.length * 2, Endian.little);
  for (var i = 0; i < samples.length; i++) {
    data.setInt16(44 + i * 2, samples[i], Endian.little);
  }
  File(path).writeAsBytesSync(data.buffer.asUint8List());
  return path;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  testWidgets('Smart Mix: silent tail skipped, silent intro skipped, on the '
      'real decks', (tester) async {
    final result = <String, Object?>{};
    await tester.runAsync(() async {
      final temp = Directory.systemTemp.createTempSync('nexa_smart_mix');
      final db = AppDatabase(
        NativeDatabase(File(p.join(temp.path, 'nexa_library.sqlite'))),
      );
      final analyzer = AudioAnalyzer(
        decoder: const MpvPcmDecoder(),
        cacheDir: () async => temp,
      );
      final c = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          artworkDirProvider.overrideWith((ref) async => temp.path),
          autoRescanProvider.overrideWithValue(false),
          audioAnalyzerProvider.overrideWithValue(analyzer),
        ],
      );
      Track song(int id, String name, List<(double, bool)> parts) {
        final path = writeToneWav(p.join(temp.path, '$name.wav'), parts);
        final seconds = parts.fold<double>(0, (s, e) => s + e.$1);
        return Track(
          id: id,
          source: TrackSource.local,
          sourceTrackId: path,
          path: path,
          title: name,
          artist: name,
          album: name,
          duration: Duration(milliseconds: (seconds * 1000).round()),
          addedAt: DateTime(2026),
        );
      }

      // 8 s of sound, then 5 s of silence; then 2 s of silence, 6 s sound.
      final a = song(920001, 'Tail', [(8, true), (5, false)]);
      final b = song(920002, 'Intro', [(2, false), (6, true)]);
      try {
        final player = c.read(playerProvider.notifier);
        c.read(mixSettingsProvider.notifier)
          ..setMode(TransitionMode.smartMix)
          ..setSeconds(6);
        await Future<void>.delayed(const Duration(milliseconds: 300));
        await player.setVolume(0);
        final engine = c.read(playbackEngineProvider);
        final advanced = Completer<Duration>();
        final sw = Stopwatch();
        final sub = engine.advanced.listen((path) {
          if (path == b.path && !advanced.isCompleted) {
            advanced.complete(sw.elapsed);
          }
        });
        final plans = <TransitionPlan>[];
        final ps = Timer.periodic(const Duration(milliseconds: 200), (_) {
          final s = c.read(mixSettingsProvider);
          final plan = planWithAnalysis(analyzer, s, a, b);
          if (plans.isEmpty || plans.last != plan) {
            plans.add(plan);
          }
        });
        await player.playTracks([a, b]);
        sw.start();
        final at = await advanced.future.timeout(
          const Duration(seconds: 20),
          onTimeout: () => const Duration(seconds: -1),
        );
        ps.cancel();
        final pos = engine.state.position;
        result['plans'] = [for (final x in plans) '$x'];
        result['advancedAfterMs'] = at.inMilliseconds;
        result['nextPositionMs'] = pos.inMilliseconds;
        result['analysisTail'] = analyzer.cached(a.path)?.toJson();
        result['analysisIntro'] = analyzer.cached(b.path)?.toJson();
        await sub.cancel();

        final last = plans.last;
        expect(last.kind, TransitionKind.crossfade);
        expect(last.reason, S.planSmartSilentTail);
        expect(last.endAt!.inMilliseconds, closeTo(8000, 150));
        expect(last.startAt!.inMilliseconds, closeTo(1900, 150));
        // Handed over at the end of the sound (8 s), not of the file (13 s).
        expect(at.inMilliseconds, inInclusiveRange(7000, 9800));
        // The second song started after its silent intro: 1.9 s + the
        // overlap (2 s), not 2 s from its start.
        expect(pos.inMilliseconds, inInclusiveRange(3000, 5500));
      } finally {
        debugPrint('SMARTMIXRESULT ${jsonEncode(result)}');
        await c.read(playerProvider.notifier).stop();
        c.dispose();
        await Future<void>.delayed(const Duration(seconds: 1));
        await db.close();
        try {
          temp.deleteSync(recursive: true);
        } on FileSystemException {
          // Removed later.
        }
      }
    });
  });
}
