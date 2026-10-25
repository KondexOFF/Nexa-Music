// NEXA AutoTest - integration scenarios with the real stack (media_kit /
// libmpv audio, SQLite file database, real files, real HTTP), run by
// tools/autotest/NEXA_AutoTest.ps1:
//
//   flutter test integration_test/autotest_test.dart -d windows
//     --dart-define=NEXA_AT_LIBRARY=<copy of the test library>
//     --dart-define=NEXA_AT_OUT=<run folder>
//     --dart-define=NEXA_AT_LOOPBACK=<loopback_capture.exe>
//
// Each check is recorded as PASS / FAIL / BLOCKED in <run>/integration.json;
// the run never stops at the first failure. Audio checks use a WASAPI
// loopback recording of what Windows really plays.
import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:integration_test/integration_test.dart';
import 'package:media_kit/media_kit.dart' show MediaKit;
import 'package:nexa_music/app/strings.dart';
import 'package:nexa_music/core/audio/playback_engine.dart';
import 'package:nexa_music/core/models/listening.dart';
import 'package:nexa_music/core/models/track.dart';
import 'package:nexa_music/features/library/library_providers.dart';
import 'package:nexa_music/features/library/library_repository.dart';
import 'package:nexa_music/features/mix_engine/mix_settings.dart';
import 'package:nexa_music/features/mix_engine/transition_planner.dart';
import 'package:nexa_music/features/nexa_dna/dna_providers.dart';
import 'package:nexa_music/features/nexa_wave/wave_controller.dart';
import 'package:nexa_music/features/player/player_controller.dart';
import 'package:nexa_music/integrations/audius/audius_source.dart';
import 'package:nexa_music/integrations/jamendo/jamendo_source.dart';
import 'package:nexa_music/integrations/music_source.dart';
import 'package:path/path.dart' as p;

import '../test/helpers/audio_analysis.dart';
import 'support/autotest_support.dart';
import 'support/gapless_probe.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  // Each group opens its own container one after another (the previous one
  // is disposed and closes its database), so drift's debug warning is noise.
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  final results = AutoTestResults();

  testWidgets('NEXA AutoTest', (tester) async {
    await tester.runAsync(() async {
      if (AutoTestConfig.library.isEmpty || AutoTestConfig.out.isEmpty) {
        results.blocked('AT-00', '-', 'Configuration', 'NEXA_AT_LIBRARY / NEXA_AT_OUT not set');
        return;
      }
      final manifest = LibraryManifest.load(AutoTestConfig.library);
      final loop = Loopback(
        AutoTestConfig.loopback,
        p.join(AutoTestConfig.out, 'recordings'),
      );
      // name -> (scenarios, time limit). A group that hangs is reported and
      // the run goes on with the next group.
      final groups = <String, (Future<void> Function(), Duration)>{
        'library': (() => _library(results, manifest), const Duration(minutes: 4)),
        'playback': (() => _playback(results, manifest, loop), const Duration(minutes: 9)),
        'mix': (() => _mix(results, manifest, loop), const Duration(minutes: 7)),
        'dna': (() => _dna(results, manifest), const Duration(minutes: 4)),
        'online': (() => _online(results, loop), const Duration(minutes: 4)),
        // Diagnostics only, run when asked for (-Groups probe).
        'probe': (() => gaplessProbe(results, manifest, loop), const Duration(minutes: 5)),
      };
      final json = p.join(AutoTestConfig.out, 'integration.json');
      if (!AutoTestConfig.runs('library')) {
        // Only some groups selected (e.g. playback,mix): they need the test
        // library in the profile, which the library group would import.
        await _importLibraryOnly();
      }
      for (final entry in groups.entries) {
        final requested = AutoTestConfig.groups.split(',').map((g) => g.trim()).contains(entry.key);
        if (entry.key == 'probe' ? !requested : !AutoTestConfig.runs(entry.key)) {
          continue;
        }
        final (run, limit) = entry.value;
        try {
          await run().timeout(limit);
        } on TimeoutException {
          results.add(
            'AT-${entry.key}-timeout',
            '-',
            'Group "${entry.key}" did not finish within ${limit.inMinutes} min',
            'BLOCKED',
            detail: 'scenarios after the last reported result were not checked; see integration.log',
          );
        } on Object catch (e, st) {
          results.add(
            'AT-${entry.key}-crash',
            '-',
            'Group "${entry.key}" stopped by an exception',
            'FAIL',
            detail: '$e\n${st.toString().split('\n').take(8).join('\n')}',
          );
        }
        // Saved after every group, so a later hang keeps what was measured.
        await results.save(json);
      }
    });
    await results.save(p.join(AutoTestConfig.out, 'integration.json'));
  }, timeout: const Timeout(Duration(minutes: 30)));
}

// ---------------------------------------------------------------- library

/// Imports the test library into the test profile without checking it
/// (the "library" group does the checks).
Future<void> _importLibraryOnly() async {
  final c = autoTestContainer();
  try {
    final repo = c.read(libraryRepositoryProvider);
    if ((await repo.getTracks()).isEmpty) {
      await c.read(libraryScanProvider.notifier).addFolder();
    }
    // ignore: avoid_print
    print('AUTOTEST setup: test library in the profile, ${(await repo.getTracks()).length} tracks');
  } finally {
    c.dispose();
  }
}

Future<void> _library(AutoTestResults r, LibraryManifest m) async {
  final root = AutoTestConfig.library;
  final before = hashTree(root);
  final c = autoTestContainer();
  try {
    final repo = c.read(libraryRepositoryProvider);
    final report = await c.read(libraryScanProvider.notifier).addFolder();
    var tracks = await repo.getTracks();
    final byPath = tracksByPath(tracks);

    r.check(
      'AT-02-count', 'FT-02', 'Import: every test file is in the library once',
      tracks.length == m.tracks.length &&
          byPath.length == m.tracks.length &&
          (report?.problems.isEmpty ?? false),
      detail: 'library ${tracks.length} / expected ${m.tracks.length}; '
          'problems: ${report?.problems ?? 'no report'}',
    );

    final wrongTags = <String>[];
    final knownIssue = <String>[];
    final wrongDurations = <String>[];
    var maxDeviation = 0.0;
    for (final t in m.tracks) {
      final file = t['file'] as String;
      final track = byPath[file];
      if (track == null) {
        wrongTags.add('$file missing');
        continue;
      }
      final title = t['title'] as String? ?? p.basenameWithoutExtension(file);
      final ok = track.title == title &&
          (t['artist'] == null || track.artist == t['artist']) &&
          (t['album'] == null || track.album == t['album']);
      if (!ok) {
        final text = '$file: "${track.title}" / "${track.artist}" / "${track.album}"';
        (t['tag_issue'] != null ? knownIssue : wrongTags).add(text);
      }
      final expected = (t['seconds'] as num).toDouble();
      final actual = (track.duration?.inMilliseconds ?? 0) / 1000;
      final dev = (actual - expected).abs();
      maxDeviation = math.max(maxDeviation, dev);
      if (dev > 0.3) {
        wrongDurations.add('$file: $actual s (expected $expected s)');
      }
    }
    r.check(
      'AT-02-tags', 'FT-02', 'Import: titles, artists, albums incl. Cyrillic MP3 / FLAC',
      wrongTags.isEmpty,
      detail: wrongTags.isEmpty ? 'all tags as written' : wrongTags.join('; '),
    );
    r.check(
      'AT-02-wav-cyrillic', 'FT-02', 'Import: Cyrillic RIFF INFO tags in WAV (known issue TD-04)',
      knownIssue.isEmpty,
      detail: knownIssue.isEmpty ? 'read correctly' : 'TD-04 confirmed: ${knownIssue.join('; ')}',
    );
    r.check(
      'AT-02-durations', 'FT-02', 'Import: durations within 0.3 s of the generated length',
      wrongDurations.isEmpty,
      detail: 'largest deviation ${maxDeviation.toStringAsFixed(3)} s'
          '${wrongDurations.isEmpty ? '' : '; ${wrongDurations.join('; ')}'}',
    );
    final metaTracks = [
      for (final t in tracks)
        if (relPath(root, t.path).startsWith('meta/')) t,
    ];
    r.check(
      'AT-02-cover', 'FT-02', 'Import: folder cover.jpg used as artwork',
      metaTracks.isNotEmpty &&
          metaTracks.every(
            (t) => t.artworkPath != null && File(t.artworkPath!).existsSync(),
          ),
      detail: '${metaTracks.where((t) => t.artworkPath != null).length} of ${metaTracks.length} tracks in meta/ have a cover',
    );
    r.check(
      'AT-02-files-unchanged', 'FT-02', 'Import never changes, moves or adds music files',
      _sameTree(before, hashTree(root)),
      detail: '${before.length} files compared by SHA-256',
    );
    await c.read(libraryScanProvider.notifier).rescan();
    tracks = await repo.getTracks();
    r.check(
      'AT-02-rescan', 'FT-02', 'Rescan adds no duplicates',
      tracks.length == m.tracks.length,
      detail: '${tracks.length} tracks after rescan',
    );

    // FT-03: playlist, likes and settings survive a restart.
    final playlistId = await repo.createPlaylist('AutoTest playlist');
    final three = tracks.take(3).map((t) => t.id).toList();
    await repo.addToPlaylist(playlistId, three);
    await repo.setFavorite(tracks[3].id, true);
    await repo.setFavorite(tracks[4].id, true);
    c.read(mixSettingsProvider.notifier).setMode(TransitionMode.gapless);
    c.read(playerProvider);
    await pause(0.5);
    await c.read(playerProvider.notifier).setVolume(0.6);
    await pause(0.5);
  } finally {
    c.dispose();
  }

  final c2 = autoTestContainer();
  try {
    final repo = c2.read(libraryRepositoryProvider);
    c2.read(playerProvider);
    c2.read(mixSettingsProvider);
    await pause(1);
    final playlists = await repo.getPlaylists();
    final list = playlists.where((x) => x.name == 'AutoTest playlist').toList();
    final favorites = await repo.getTracks(filter: TrackFilter.favorites);
    final tracks = await repo.getTracks();
    r.check(
      'AT-03-restart', 'FT-03', 'After a restart: library, playlist, likes, Mix mode and volume restored',
      tracks.length == m.tracks.length &&
          list.length == 1 &&
          list.single.trackCount == 3 &&
          favorites.length == 2 &&
          c2.read(mixSettingsProvider).mode == TransitionMode.gapless &&
          (c2.read(playerProvider).volume - 0.6).abs() < 0.01,
      detail: 'tracks ${tracks.length}, playlist ${list.isEmpty ? 'missing' : '${list.single.trackCount} songs'}, '
          'favorites ${favorites.length}, mode ${c2.read(mixSettingsProvider).mode.name}, '
          'volume ${c2.read(playerProvider).volume}',
    );

    // FT-04: a missing file is shown with a reason and comes back.
    const moved = 'meta/untagged_track.wav';
    final original = File(p.join(root, moved));
    final renamed = p.join(root, 'meta', 'untagged_track_renamed.wav');
    original.renameSync(renamed);
    await c2.read(libraryScanProvider.notifier).rescan();
    var all = tracksByPath(await repo.getTracks());
    final missing = all[moved];
    final missingOk = missing != null && !missing.available && (missing.problem?.isNotEmpty ?? false);
    File(renamed).renameSync(original.path);
    await c2.read(libraryScanProvider.notifier).rescan();
    all = tracksByPath(await repo.getTracks());
    final back = all[moved];
    final available = all.values.where((t) => t.available).length;
    r.check(
      'AT-04-missing', 'FT-04', 'Renamed file: unavailable with a reason, available again after renaming back',
      missingOk && back != null && back.available && available == m.tracks.length,
      detail: 'while renamed: ${missing == null ? 'not found' : '${missing.available ? 'available' : 'unavailable'} "${missing.problem}"'}; '
          'after: ${back?.available == true ? 'available' : 'not available'}; available tracks $available '
          '(the renamed copy stays listed as missing by design)',
    );

    // FT-05: search, also Cyrillic and other letter case.
    Future<int> count(String q) async => (await repo.getTracks(query: q)).length;
    final seq = await count('seq 0');
    final cyr = await count('тестовая');
    final upper = await count('ТЕСТОВЫЙ');
    final band = await count('live band');
    r.check(
      'AT-05-search', 'FT-05', 'Search: words, letter case and Cyrillic',
      seq == 11 && cyr >= 1 && upper >= 2 && band == 3,
      // "seq 0" = both words: Seq 01-09, Seq 10, Seq 20.
      detail: '"seq 0" $seq (11), "тестовая" $cyr (>=1), "ТЕСТОВЫЙ" $upper (>=2), "live band" $band (3)',
    );
  } finally {
    c2.dispose();
  }
}

/// "; not heard: seq/seq_03.flac, ..." for tones missing from [heard].
String _notHeard(List<Track> tracks, List<double> freqs, List<double> heard) {
  final missing = [
    for (var i = 0; i < tracks.length; i++)
      if (!heard.contains(freqs[i])) relPath(AutoTestConfig.library, tracks[i].path),
  ];
  return missing.isEmpty ? '' : '; not heard: ${missing.join(', ')}';
}

bool _sameTree(Map<String, String> a, Map<String, String> b) =>
    a.length == b.length && a.entries.every((e) => b[e.key] == e.value);

// --------------------------------------------------------------- playback

Future<void> _playback(
  AutoTestResults r,
  LibraryManifest m,
  Loopback loop,
) async {
  final c = autoTestContainer();
  final errors = <String>[];
  try {
    final player = c.read(playerProvider.notifier);
    final engine = c.read(playbackEngineProvider);
    final sub = engine.errors.listen(errors.add);
    await pause(0.5);
    await player.setVolume(1.0);
    final mix = c.read(mixSettingsProvider.notifier);
    mix.setMode(TransitionMode.gapless);
    final tracks = tracksByPath(await c.read(libraryRepositoryProvider).getTracks());
    final seq = [
      for (var n = 1; n <= 24; n++)
        tracks.entries.firstWhere((e) => e.key.startsWith('seq/seq_${n.toString().padLeft(2, '0')}.')).value,
    ];

    // FT-06: 24 tracks in a row.
    final order = <String>[];
    final listen = c.listen(playerProvider, (prev, next) {
      final id = next.current?.sourceTrackId;
      if (id != null && (order.isEmpty || order.last != id)) {
        order.add(id);
      }
    });
    // Length from the manifest (what was generated), not from the tags the
    // app read, so a wrong duration in the library cannot stretch the test.
    final total = seq.fold<double>(0, (s, t) => s + m.seconds(relPath(AutoTestConfig.library, t.path)));
    bool finished() => !c.read(playerProvider).playing && c.read(playerProvider).cursor == 23;
    final rec = await loop.record('ft06_24_tracks', total + 4, () async {
      await player.playTracks(seq);
      await waitUntil(finished, timeout: Duration(seconds: total.ceil() + 10));
    });
    if (rec == null) {
      await waitUntil(finished, timeout: Duration(seconds: total.ceil() + 10));
    }
    await pause(1);
    listen.close();
    final expectedIds = seq.map((t) => t.sourceTrackId).toList();
    r.check(
      'AT-06-order', 'FT-06', '24 tracks in a row: each started once, in order (engine)',
      _listEquals(order, expectedIds),
      detail: '${order.length} tracks started; engine errors: ${errors.isEmpty ? 'none' : errors.join('; ')}',
    );
    if (rec == null) {
      r.blocked('AT-06-audio', 'FT-06', '24 tracks in a row: audible order, no overlap, no gaps (loopback)', loop.lastError ?? '');
    } else {
      final freqs = seq.map((t) => m.frequency(relPath(AutoTestConfig.library, t.path))).toList();
      final w = analyze(rec, freqs);
      final segments = toneSegments(w, freqs);
      final heard = segments.map((s) => s.frequency).toList();
      var maxOverlap = 0.0, maxGap = 0.0;
      for (var i = 0; i + 1 < freqs.length; i++) {
        final t = measureTransition(w, freqs[i], freqs[i + 1]);
        maxOverlap = math.max(maxOverlap, t.overlap);
        maxGap = math.max(maxGap, t.gap);
      }
      // Every song must be heard for (almost) its full length.
      final shortest = segments.isEmpty ? 0.0 : segments.map((x) => x.length).reduce(math.min);
      r.check(
        'AT-06-audio', 'FT-06', '24 tracks in a row: audible order, full length, never two at once, no gaps (loopback)',
        _listEquals(heard, freqs) && maxOverlap <= 0.04 && maxGap <= 0.02 && shortest >= 5.8,
        detail: 'heard ${heard.length} of 24 tones in ${_listEquals(heard, freqs) ? 'the right' : 'a WRONG'} order; '
            'largest overlap ${maxOverlap.toStringAsFixed(3)} s, largest gap ${maxGap.toStringAsFixed(3)} s, '
            'shortest song heard ${shortest.toStringAsFixed(2)} s of 6.00 s'
            '${_notHeard(seq, freqs, heard)}',
        data: {'recordingSeconds': rec.seconds, 'outputDevice': loop.deviceInfo},
      );
    }

    // FT-06 edge case: a FLAC file with an ID3v2 tag in front (TD-19)
    // between MP3 and WAV in Gapless mode.
    final edge = tracksByPath(await c.read(libraryRepositoryProvider).getTracks())['edge/id3_prefixed.flac'];
    if (edge == null) {
      r.blocked('AT-06-id3-flac', 'FT-06', 'Gapless: MP3 -> FLAC with ID3 tag in front -> WAV, all audible',
          'edge/id3_prefixed.flac is not in the test library (library version 1)');
    } else {
      final trio = [seq[1], edge, seq[3]];
      final trioFreqs = trio.map((t) => m.frequency(relPath(AutoTestConfig.library, t.path))).toList();
      final trioSeconds = trio.fold<double>(0, (s, t) => s + m.seconds(relPath(AutoTestConfig.library, t.path)));
      bool trioDone() => !c.read(playerProvider).playing && c.read(playerProvider).cursor == 2;
      final trec = await loop.record('ft06_id3_flac', trioSeconds + 3, () async {
        await player.playTracks(trio);
        await waitUntil(trioDone, timeout: Duration(seconds: trioSeconds.ceil() + 10));
      });
      if (trec == null) {
        r.blocked('AT-06-id3-flac', 'FT-06', 'Gapless: MP3 -> FLAC with ID3 tag in front -> WAV, all audible', loop.lastError ?? '');
      } else {
        final tw = analyze(trec, trioFreqs);
        final heardTrio = toneSegments(tw, trioFreqs).where((x) => x.length > 1).map((x) => x.frequency).toList();
        r.check(
          'AT-06-id3-flac', 'FT-06', 'Gapless: MP3 -> FLAC with ID3 tag in front -> WAV, all audible',
          _listEquals(heardTrio, trioFreqs),
          detail: 'heard ${heardTrio.map((f) => '${f.round()} Hz').join(' -> ')} (expected ${trioFreqs.map((f) => '${f.round()} Hz').join(' -> ')})',
        );
      }
    }

    // FT-07: pause, resume, seek, previous / next.
    final a = tracks['mix/mix_a.wav']!;
    final b = tracks['mix/mix_b.flac']!;
    await player.playTracks([a, b]);
    await waitUntil(() => engine.state.path == a.path && engine.state.position > const Duration(seconds: 1));
    await player.pause();
    await pause(0.3);
    final p1 = engine.state.position;
    final silent = await loop.record('ft07_pause', 1.5, () async {}, expectSound: false);
    final p2 = engine.state.position;
    final pausedOk = !c.read(playerProvider).playing && (p2 - p1).inMilliseconds.abs() < 100;
    await player.togglePlay();
    await pause(1.2);
    final p3 = engine.state.position;
    await player.seek(const Duration(seconds: 20));
    await pause(0.5);
    final p4 = engine.state.position;
    await player.previous(); // > 3 s: restart
    await pause(0.5);
    final restarted = engine.state.path == a.path && engine.state.position < const Duration(seconds: 2);
    await player.next();
    await waitUntil(() => engine.state.path == b.path);
    final nextOk = c.read(playerProvider).current?.id == b.id;
    await player.previous(); // < 3 s: previous track
    await waitUntil(() => engine.state.path == a.path);
    final prevOk = c.read(playerProvider).current?.id == a.id;
    r.check(
      'AT-07-transport', 'FT-07', 'Pause holds the position, resume, seek, previous (restart / previous track), next',
      pausedOk && p3 > p2 && p4.inMilliseconds >= 19900 && p4.inMilliseconds < 21500 && restarted && nextOk && prevOk,
      detail: 'pause ${p1.inMilliseconds}->${p2.inMilliseconds} ms, resume -> ${p3.inMilliseconds} ms, '
          'seek 20 s -> ${p4.inMilliseconds} ms, restart $restarted, next $nextOk, previous $prevOk',
    );
    if (silent == null) {
      r.blocked('AT-07-pause-silence', 'FT-07', 'Silence while paused (loopback)', loop.lastError ?? '');
    } else {
      // The loopback hears every app on the PC, so the check measures the
      // paused song's own tone (Mix A, 440 Hz), not the overall level.
      final w = analyze(silent, [440]);
      final tone = w.isEmpty ? 1.0 : w.map((x) => x.amplitudes[440.0]!).reduce(math.max);
      final peak = w.isEmpty ? 0.0 : w.map((x) => x.peak).reduce(math.max);
      r.check('AT-07-pause-silence', 'FT-07', 'Silence while paused (loopback, tone of the paused song)', tone < 0.002,
          detail: '440 Hz level while paused ${tone.toStringAsFixed(5)} (playing at 100 %: about 0.12); '
              'other sound on the PC: peak ${peak.toStringAsFixed(4)}');
    }

    // FT-08: queue.
    final s = seq.take(6).toList();
    await player.playTracks(s.take(3).toList());
    await waitUntil(() => engine.state.path == s[0].path);
    player.playNext([s[4]]);
    player.addToQueue([s[5]]);
    var st = c.read(playerProvider);
    final insertedFirst = st.upNext.first.track.id == s[4].id && st.upNext.last.track.id == s[5].id;
    player.removeFromQueue(st.upNext.firstWhere((e) => e.track.id == s[1].id).uid);
    st = c.read(playerProvider);
    final removed = st.upNext.every((e) => e.track.id != s[1].id);
    await player.next();
    final playedInserted = await waitUntil(() => engine.state.path == s[4].path);
    player.clearUpNext();
    final cleared = c.read(playerProvider).upNext.isEmpty;
    r.check(
      'AT-08-queue', 'FT-08', 'Play next, Add to queue, Remove, Clear; the engine plays the inserted song',
      insertedFirst && removed && playedInserted && cleared,
      detail: 'play next/add $insertedFirst, remove $removed, engine played inserted $playedInserted, clear $cleared',
    );

    // FT-09: shuffle and repeat.
    final ten = seq.take(10).toList();
    if (!c.read(playerProvider).shuffle) {
      await player.toggleShuffle();
    }
    await player.playTracks(ten);
    final paths = <String>{};
    for (var i = 0; i < 10; i++) {
      await waitUntil(() => engine.state.path != null);
      paths.add(engine.state.path!);
      if (i < 9) {
        await player.next();
        await pause(0.3);
      }
    }
    final shuffledIds = c.read(playerProvider).queue.map((e) => e.track.id).toList();
    await player.toggleShuffle();
    final restored = _listEquals(
      c.read(playerProvider).queue.map((e) => e.track.id).toList(),
      ten.map((t) => t.id).toList(),
    );
    r.check(
      'AT-09-shuffle', 'FT-09', 'Shuffle plays each song once; switching it off restores the order',
      paths.length == 10 && restored && !_listEquals(shuffledIds, ten.map((t) => t.id).toList()),
      detail: '${paths.length} different files played; order restored $restored',
    );
    Future<void> repeat(PlayerRepeat mode) async {
      while (c.read(playerProvider).repeat != mode) {
        await player.cycleRepeat();
      }
    }

    await repeat(PlayerRepeat.one);
    await player.playTracks([seq[0], seq[1]]);
    await waitUntil(() => engine.state.duration > Duration.zero && engine.state.path == seq[0].path);
    await player.seek(engine.state.duration - const Duration(milliseconds: 800));
    await pause(2.5);
    final repeatOne = c.read(playerProvider).current?.id == seq[0].id &&
        engine.state.path == seq[0].path &&
        engine.state.position < const Duration(seconds: 3);
    await repeat(PlayerRepeat.all);
    await player.jumpTo(1);
    await waitUntil(() => engine.state.path == seq[1].path && engine.state.duration > Duration.zero);
    await player.seek(engine.state.duration - const Duration(milliseconds: 800));
    final wrapped = await waitUntil(() => engine.state.path == seq[0].path, timeout: const Duration(seconds: 5));
    await repeat(PlayerRepeat.off);
    r.check(
      'AT-09-repeat', 'FT-09', 'Repeat this song replays it; Repeat all wraps to the first song',
      repeatOne && wrapped,
      detail: 'repeat one $repeatOne, repeat all wrap $wrapped',
    );

    // FT-10: volume and mute (loopback levels), output devices listed.
    await player.playTracks([a]);
    await waitUntil(() => engine.state.path == a.path && engine.state.playing);
    await pause(0.5);
    await player.setVolume(1.0);
    final full = await loop.record('ft10_volume_100', 1.5, () async {});
    await player.setVolume(0.5);
    await pause(0.3);
    final half = await loop.record('ft10_volume_50', 1.5, () async {});
    await player.toggleMute();
    await pause(0.3);
    final muted = await loop.record('ft10_mute', 1.5, () async {}, expectSound: false);
    await player.toggleMute();
    await player.setVolume(1.0);
    if (full == null || half == null || muted == null) {
      r.blocked('AT-10-volume', 'FT-10', 'Volume and mute change the real output level (loopback)', loop.lastError ?? '');
    } else {
      double level(Recording x) => toneAmplitude(x.samples, 0, x.samples.length, x.sampleRate, 440);
      final l1 = level(full), l05 = level(half), l0 = level(muted);
      r.check(
        'AT-10-volume', 'FT-10', 'Volume and mute change the real output level (loopback)',
        l05 < l1 * 0.8 && l0 < l1 * 0.01,
        detail: '440 Hz level at 100 %: ${l1.toStringAsFixed(4)}, 50 %: ${l05.toStringAsFixed(4)}, mute: ${l0.toStringAsFixed(5)}; '
            'recorder ${loop.deviceInfo ?? '-'}',
      );
    }
    final devices = engine.availableDevices;
    await player.setOutputDevice(const OutputDevice('auto', 'System default'));
    r.check(
      'AT-10-devices', 'FT-10', 'Output devices are listed; "System default" can be selected',
      devices.isNotEmpty,
      detail: '${devices.length} devices reported by the engine',
    );
    await player.stop();
    await sub.cancel();
  } finally {
    c.dispose();
  }
}

bool _listEquals<T>(List<T> a, List<T> b) {
  if (a.length != b.length) {
    return false;
  }
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) {
      return false;
    }
  }
  return true;
}

// -------------------------------------------------------------------- mix

Future<void> _mix(AutoTestResults r, LibraryManifest m, Loopback loop) async {
  final c = autoTestContainer();
  try {
    final player = c.read(playerProvider.notifier);
    final engine = c.read(playbackEngineProvider);
    final mix = c.read(mixSettingsProvider.notifier);
    await pause(0.5);
    await player.setVolume(1.0);
    if (c.read(playerProvider).shuffle) {
      await player.toggleShuffle();
    }
    final t = tracksByPath(await c.read(libraryRepositoryProvider).getTracks());

    Future<void> transition({
      required String id,
      required String ft,
      required String title,
      required String a,
      required String b,
      required TransitionMode mode,
      required double seconds,
      bool albumGapless = true,
      required double seekBefore,
      required double capture,
      required bool Function(TransitionMeasure x, TransitionPlan plan) ok,
    }) async {
      mix
        ..setMode(mode)
        ..setSeconds(seconds)
        ..setAllowSmartAdjust(true)
        ..setAlbumGapless(albumGapless);
      final ta = t[a]!, tb = t[b]!;
      final plan = planTransition(c.read(mixSettingsProvider), ta, tb);
      await player.playTracks([ta, tb]);
      await waitUntil(() => engine.state.path == ta.path && engine.state.duration > Duration.zero);
      await pause(1);
      final duration = engine.state.duration;
      final rec = await loop.record(id, capture, () async {
        await player.seek(duration - Duration(milliseconds: (seekBefore * 1000).round()));
      });
      final advanced = await waitUntil(() => c.read(playerProvider).current?.id == tb.id, timeout: const Duration(seconds: 6));
      await player.stop();
      final planText = '${plan.kind.name} ${plan.fade.inMilliseconds / 1000} s ("${plan.reason}")';
      if (rec == null) {
        r.blocked(id, ft, title, '${loop.lastError}; planned $planText; engine moved on: $advanced');
        return;
      }
      final x = measureTransition(analyze(rec, [m.frequency(a), m.frequency(b)]), m.frequency(a), m.frequency(b));
      r.check(
        id, ft, title,
        x.found && advanced && ok(x, plan),
        detail: 'planned $planText; measured overlap ${x.overlap.toStringAsFixed(2)} s, gap ${x.gap.toStringAsFixed(3)} s, '
            'peak ${x.peak.toStringAsFixed(3)}, level during overlap ${x.minLevelRatio.toStringAsFixed(2)}-${x.maxLevelRatio.toStringAsFixed(2)} x; '
            'player moved on: $advanced',
        data: x.toJson(),
      );
    }

    bool crossfadeOk(TransitionMeasure x, double s) =>
        x.overlap >= s * 0.85 - 0.3 &&
        x.overlap <= s * 1.1 + 0.3 &&
        x.gap <= 0.06 &&
        x.peak < 0.98 &&
        x.minLevelRatio >= 0.55 &&
        x.maxLevelRatio <= 1.4;
    // Gapless: no overlap and no audible silence (one 20 ms analysis window
    // of tolerance for the switch itself).
    bool gaplessOk(TransitionMeasure x) => x.overlap <= 0.04 && x.gap <= 0.02 && x.peak < 0.98;

    await transition(
      id: 'AT-11-crossfade-6', ft: 'FT-11', title: 'Crossfade 6 s (WAV -> FLAC): smooth overlap, no dip, no clipping',
      a: 'mix/mix_a.wav', b: 'mix/mix_b.flac', mode: TransitionMode.crossfade, seconds: 6,
      seekBefore: 10, capture: 15, ok: (x, plan) => plan.kind == TransitionKind.crossfade && crossfadeOk(x, 6),
    );
    await transition(
      id: 'AT-12-crossfade-0', ft: 'FT-12', title: 'Crossfade 0 s: no overlap, no gap',
      a: 'mix/mix_a.wav', b: 'mix/mix_d.wav', mode: TransitionMode.crossfade, seconds: 0,
      seekBefore: 4, capture: 8, ok: (x, plan) => plan.kind != TransitionKind.crossfade && gaplessOk(x),
    );
    await transition(
      id: 'AT-12-crossfade-12', ft: 'FT-12', title: 'Crossfade 12 s: long smooth overlap',
      a: 'mix/mix_a.wav', b: 'mix/mix_b.flac', mode: TransitionMode.crossfade, seconds: 12,
      seekBefore: 16, capture: 22, ok: (x, plan) => plan.kind == TransitionKind.crossfade && crossfadeOk(x, 12),
    );
    await transition(
      id: 'AT-13-album-gapless', ft: 'FT-13', title: 'Same album with Crossfade on: gapless, no overlap (FLAC)',
      a: 'album/live_1.flac', b: 'album/live_2.flac', mode: TransitionMode.crossfade, seconds: 6,
      seekBefore: 4, capture: 8, ok: (x, plan) => plan.reason == S.planSameAlbum && gaplessOk(x),
    );
    await transition(
      id: 'AT-14-smart-mix', ft: 'FT-14', title: 'Smart Mix shortens the overlap for short tracks and says why',
      a: 'mix/mix_b.flac', b: 'mix/mix_d.wav', mode: TransitionMode.smartMix, seconds: 6,
      seekBefore: 8, capture: 12,
      ok: (x, plan) => plan.reason == S.planSmartShortTrack && crossfadeOk(x, plan.fade.inMilliseconds / 1000),
    );
    await transition(
      id: 'AT-15-mp3-flac', ft: 'FT-15', title: 'Crossfade 6 s MP3 -> FLAC',
      a: 'mix/mix_c.mp3', b: 'mix/mix_b.flac', mode: TransitionMode.crossfade, seconds: 6,
      seekBefore: 10, capture: 15, ok: (x, plan) => crossfadeOk(x, 6),
    );
    await transition(
      id: 'AT-15-flac-wav', ft: 'FT-15', title: 'Crossfade 6 s FLAC -> WAV',
      a: 'mix/mix_b.flac', b: 'mix/mix_d.wav', mode: TransitionMode.crossfade, seconds: 6,
      seekBefore: 10, capture: 15, ok: (x, plan) => crossfadeOk(x, 6),
    );
    mix
      ..setMode(TransitionMode.crossfade)
      ..setSeconds(6);
    await pause(0.3);
  } finally {
    c.dispose();
  }
}

// -------------------------------------------------------------------- dna

Future<void> _dna(AutoTestResults r, LibraryManifest m) async {
  final c = autoTestContainer();
  try {
    final player = c.read(playerProvider.notifier);
    final engine = c.read(playbackEngineProvider);
    final dna = c.read(dnaSettingsProvider.notifier);
    final taste = c.read(tasteRepositoryProvider);
    final wave = c.read(waveProvider.notifier);
    await waitUntil(() => c.read(dnaSettingsProvider).loaded);
    await player.setVolume(1.0);

    // FT-19: NEXA DNA choices from the library tags, stored.
    // Riverpod 3 pauses a provider nobody listens to; keep a listener while
    // waiting for the first value of this stream provider.
    final tagsSub = c.listen(libraryTagsProvider, (_, _) {});
    final tags = await c.read(libraryTagsProvider.future).timeout(const Duration(seconds: 15));
    tagsSub.close();
    await taste.setItem(TasteKind.artist, 'Mix Artist A');
    await taste.setItem(TasteKind.genre, 'Rock', excluded: true);
    await dna.setHistoryConsent(true);
    final items = await taste.getItems();
    r.check(
      'AT-19-dna', 'FT-19', 'NEXA DNA offers the library genres / artists and stores liked / excluded choices',
      tags.genres.contains('Electronic') && tags.genres.contains('Поп') &&
          tags.artists.contains('AutoTest Band') && items.length == 2,
      detail: 'genres ${tags.genres.join(', ')}; ${items.length} choices stored',
    );

    // FT-20: Wave plays, explains, respects exclusions, refills, learns.
    final before = await taste.eventCount();
    await wave.start();
    await waitUntil(() => engine.state.path != null);
    var st = c.read(playerProvider);
    final queue = st.queue.map((e) => e.track).toList();
    final excludedInQueue = queue.where((t) => t.genre == 'Rock').length;
    final reasons = queue.where((t) => wave.reasonFor(t.id) != null).length;
    final likedFirst = queue.take(3).any((t) => t.artist == 'Mix Artist A');
    await player.next();
    await pause(1);
    await player.next();
    await pause(1);
    await player.jumpTo(c.read(playerProvider).queue.length - 1);
    final refilled = await waitUntil(() => c.read(playerProvider).queue.length > queue.length, timeout: const Duration(seconds: 6));
    await pause(0.5);
    final after = await taste.eventCount();
    st = c.read(playerProvider);
    r.check(
      'AT-20-wave', 'FT-20', 'Wave: liked artist among the first picks, reasons shown, excluded genre never, refills itself, skips recorded',
      st.context == PlayContext.wave && excludedInQueue == 0 && reasons == queue.length && likedFirst && refilled && after >= before + 3,
      detail: 'queue ${queue.length} (liked first $likedFirst, excluded genre $excludedInQueue, reasons $reasons), '
          'refilled $refilled to ${st.queue.length}, history $before->$after',
    );

    // FT-21: a dislike skips at once and is never suggested again.
    final current = c.read(playerProvider).current!;
    await wave.dislike(current);
    final skipped = await waitUntil(() => engine.state.path != current.path, timeout: const Duration(seconds: 3));
    await wave.start();
    await pause(0.5);
    final again = c.read(playerProvider).queue.any((e) => e.track.id == current.id);
    r.check(
      'AT-21-dislike', 'FT-21', 'Dislike skips the playing Wave song and excludes it',
      skipped && !again,
      detail: 'skipped $skipped, suggested again $again',
    );

    // FT-22: Familiar <-> Discovery changes the picks.
    // Known songs: finished three times, two days ago, each by a different
    // artist (the Wave avoids the same artist twice in a row, which would
    // mix new songs between known songs of one artist). Fifteen newer
    // listenings of other songs fill the "recently played" window, so the
    // known songs stay eligible.
    await taste.clearHistory();
    final lib = await c.read(libraryRepositoryProvider).getTracks();
    final byArtist = <String, Track>{};
    for (final t in lib) {
      if (t.disliked || !t.available || t.genre == 'Rock' || t.artist == 'Mix Artist A' || t.artist == 'AutoTest Band') {
        continue;
      }
      byArtist.putIfAbsent(t.artist, () => t);
    }
    final known = byArtist.values.take(4).toList();
    final filler = lib.where((t) => t.artist == 'AutoTest Band' && !t.disliked).take(15).toList();
    final old = DateTime.now().subtract(const Duration(days: 2));
    for (final k in known) {
      for (var i = 0; i < 3; i++) {
        await taste.recordEvent(ListeningEvent(
          trackId: k.id, startedAt: old, listened: k.duration ?? Duration.zero,
          reason: EndReason.completed, context: PlayContext.library,
        ));
      }
    }
    for (final f in filler) {
      await taste.recordEvent(ListeningEvent(
        trackId: f.id, startedAt: DateTime.now(), listened: const Duration(seconds: 2),
        reason: EndReason.skipped, context: PlayContext.library,
      ));
    }
    await player.stop();
    await dna.setDiscovery(0);
    await wave.refresh();
    final familiarTop = c.read(waveProvider).items.take(4).where((i) => !i.fresh).length;
    await dna.setDiscovery(1);
    await wave.refresh();
    final discoveryTop = c.read(waveProvider).items.take(4).where((i) => i.fresh).length;
    r.check(
      'AT-22-discovery', 'FT-22', 'Familiar picks played songs first; Discovery picks unplayed songs first',
      known.length == 4 && familiarTop >= 3 && discoveryTop >= 3,
      detail: 'familiar: $familiarTop of top 4 known; discovery: $discoveryTop of top 4 new '
          '(${known.length} known songs by different artists)',
    );

    // FT-23: private session and paused learning record nothing.
    await wave.start();
    await waitUntil(() => engine.state.path != null);
    Future<int> skipTwice() async {
      final n0 = await taste.eventCount();
      for (var i = 0; i < 2; i++) {
        await pause(0.8);
        await player.next();
      }
      await pause(0.8);
      return (await taste.eventCount()) - n0;
    }

    dna.setPrivateSession(true);
    final privateAdded = await skipTwice();
    dna.setPrivateSession(false);
    await dna.setLearningPaused(true);
    final pausedAdded = await skipTwice();
    await dna.setLearningPaused(false);
    final normalAdded = await skipTwice();
    r.check(
      'AT-23-privacy', 'FT-23', 'Private session and Pause learning add nothing to the history; normal listening does',
      privateAdded == 0 && pausedAdded == 0 && normalAdded >= 1,
      detail: 'added: private $privateAdded, paused $pausedAdded, normal $normalAdded',
    );
    dna.setPrivateSession(true);
    await player.stop();
  } finally {
    c.dispose();
  }

  // FT-24: delete history, reset DNA, restart.
  final c2 = autoTestContainer();
  try {
    final taste = c2.read(tasteRepositoryProvider);
    final repo = c2.read(libraryRepositoryProvider);
    final dna = c2.read(dnaSettingsProvider.notifier);
    await waitUntil(() => c2.read(dnaSettingsProvider).loaded);
    final privateAfterRestart = c2.read(dnaSettingsProvider).privateSession;
    final favoritesBefore = (await repo.getTracks(filter: TrackFilter.favorites)).length;
    await taste.clearHistory();
    await taste.resetTaste();
    await dna.resetPreferences();
    final events = await taste.eventCount();
    final items = await taste.getItems();
    final disliked = (await repo.getTracks()).where((t) => t.disliked).length;
    final favorites = (await repo.getTracks(filter: TrackFilter.favorites)).length;
    final playlists = (await repo.getPlaylists()).length;
    r.check(
      'AT-24-reset', 'FT-24', 'Delete history and Reset DNA; likes and playlists stay; private session ends with the app',
      !privateAfterRestart && events == 0 && items.isEmpty && disliked == 0 && favorites == favoritesBefore && playlists >= 1 &&
          c2.read(dnaSettingsProvider).discovery == DnaSettings.defaultDiscovery,
      detail: 'private after restart $privateAfterRestart, events $events, choices ${items.length}, dislikes $disliked, '
          'favorites $favoritesBefore->$favorites, playlists $playlists, discovery ${c2.read(dnaSettingsProvider).discovery}',
    );
  } finally {
    c2.dispose();
  }
}

// ----------------------------------------------------------------- online

Future<void> _online(AutoTestResults r, Loopback loop) async {
  final client = http.Client();
  final c = autoTestContainer();
  try {
    final player = c.read(playerProvider.notifier);
    final engine = c.read(playbackEngineProvider);
    final taste = c.read(tasteRepositoryProvider);
    await waitUntil(() => c.read(dnaSettingsProvider).loaded);
    await c.read(dnaSettingsProvider.notifier).setHistoryConsent(true);
    c.read(dnaSettingsProvider.notifier).setPrivateSession(false);
    await player.setVolume(1.0);

    Future<Track?> search(String id, MusicSource source, String firstQuery) async {
      try {
        // A catalog's search can come back empty for one word now and then;
        // a few common words are tried before the check fails.
        var query = firstQuery;
        var tracks = await source.search(query, limit: 10);
        for (final other in const ['jazz', 'piano', 'rock', 'ambient']) {
          if (tracks.any((t) => t.available)) {
            break;
          }
          query = other;
          tracks = await source.search(query, limit: 10);
        }
        final playable = tracks.where((t) => t.available).toList();
        final labelled = tracks.every((t) => t.source == source.source && (t.available || (t.problem?.isNotEmpty ?? false)));
        r.check(
          id, 'FT-25', '${source.source.label}: search returns results with source and playability',
          tracks.isNotEmpty && playable.isNotEmpty && labelled &&
              (source.source != TrackSource.jamendo || playable.first.license != null),
          detail: '"$query": ${tracks.length} results, ${playable.length} playable'
              '${source.source == TrackSource.jamendo && playable.isNotEmpty ? ', licence ${playable.first.license}' : ''}',
        );
        return playable.isEmpty ? null : playable.first;
      } on CatalogException catch (e) {
        r.add(id, 'FT-25', '${source.source.label}: search', e.kind == CatalogErrorKind.offline ? 'BLOCKED' : 'FAIL',
            detail: '$e');
        return null;
      }
    }

    final audius = await search('AT-25-audius', AudiusSource(client), 'lofi');
    final idFile = File(AutoTestConfig.jamendoIdFile);
    Track? jamendo;
    if (AutoTestConfig.jamendoIdFile.isNotEmpty && idFile.existsSync()) {
      jamendo = await search(
        'AT-25-jamendo',
        JamendoSource(client, clientId: idFile.readAsStringSync().trim()),
        'chill',
      );
    } else {
      r.blocked('AT-25-jamendo', 'FT-25', 'Jamendo: search', 'no Jamendo client id file');
    }

    final events0 = await taste.eventCount();
    Future<void> stream(String id, Track? track) async {
      if (track == null) {
        r.blocked(id, 'FT-26', 'Stream plays through the real engine', 'no playable search result');
        return;
      }
      await player.playTracks([track]);
      final playing = await waitUntil(
        () => engine.state.path == track.path && engine.state.position > const Duration(seconds: 3),
        timeout: const Duration(seconds: 25),
      );
      final rec = playing ? await loop.record(id, 2, () async {}) : null;
      final level = rec == null ? null : analyze(rec, const [440]).map((w) => w.rms).fold<double>(0, math.max);
      await player.stop();
      r.check(
        id, 'FT-26', '${track.source.label}: stream plays through the real engine${rec == null ? '' : ' and is audible (loopback)'}',
        playing && (rec == null || (level ?? 0) > 0.001),
        detail: 'position > 3 s: $playing'
            '${rec == null ? (playing ? '; loopback: ${loop.lastError}' : '') : '; output RMS ${level!.toStringAsFixed(4)}'}',
      );
    }

    await stream('AT-26-audius', audius);
    await stream('AT-26-jamendo', jamendo);
    if (audius != null && jamendo != null) {
      final plan = planTransition(c.read(mixSettingsProvider), audius, jamendo);
      r.check(
        'AT-26-no-mix', 'FT-26', 'Catalog tracks are never crossfaded; not written to the history',
        plan.kind == TransitionKind.cut && plan.reason == S.planNoMixRights && await taste.eventCount() == events0,
        detail: 'plan ${plan.kind.name} "${plan.reason}"; history $events0->${await taste.eventCount()}',
      );
    }

    // FT-27 (simulated): catalog unreachable, local playback still works.
    CatalogErrorKind? kind;
    try {
      await AudiusSource(client, base: Uri.parse('https://127.0.0.1:9/v1')).search('x');
    } on CatalogException catch (e) {
      kind = e.kind;
    }
    final local = (await c.read(libraryRepositoryProvider).getTracks(query: 'seq 01')).first;
    await player.playTracks([local]);
    final localPlays = await waitUntil(
      () => engine.state.path == local.path && engine.state.position > const Duration(seconds: 1),
    );
    await player.stop();
    r.check(
      'AT-27-unreachable', 'FT-27', 'Unreachable catalog gives the "offline" message; the local library still plays',
      kind == CatalogErrorKind.offline && localPlays,
      detail: 'error kind ${kind?.name}; local playback $localPlays (simulated with an unreachable address, real network still on)',
    );
  } finally {
    c.dispose();
    client.close();
  }
}
