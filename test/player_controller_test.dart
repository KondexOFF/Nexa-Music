import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexa_music/core/models/track.dart';
import 'package:nexa_music/core/database/app_database.dart';
import 'package:nexa_music/core/settings/settings_provider.dart';
import 'package:nexa_music/core/settings/settings_repository.dart';
import 'package:nexa_music/features/library/library_providers.dart';
import 'package:nexa_music/features/player/player_controller.dart';
import 'package:nexa_music/features/youtube/youtube_track.dart';
import 'package:path/path.dart' as p;

import 'helpers/fake_engine.dart';
import 'helpers/test_app.dart';

/// Phase 3 acceptance (Master Plan v1.0): 20 tracks in a row, pause /
/// resume, repeat / shuffle, device change, never two tracks at once.
void main() {
  late Directory temp;
  late FakeEngine engine;
  late ProviderContainer container;

  PlayerController player() => container.read(playerProvider.notifier);
  PlayerState state() => container.read(playerProvider);

  List<Track> makeTracks(int count, {Set<int> missing = const {}}) => [
    for (var i = 1; i <= count; i++)
      Track(
        id: i,
        source: TrackSource.local,
        sourceTrackId: 'track$i',
        path: () {
          final path = p.join(temp.path, 'track_$i.mp3');
          if (!missing.contains(i)) {
            File(path).writeAsStringSync('x');
          }
          return path;
        }(),
        title: 'Song $i',
        artist: 'Artist',
        album: 'Album',
        addedAt: DateTime(2026),
      ),
  ];

  Future<void> flush() => Future<void>.delayed(Duration.zero);

  setUp(() async {
    temp = Directory.systemTemp.createTempSync('nexa_player_test');
    engine = FakeEngine();
    container = ProviderContainer(overrides: testOverrides(engine: engine));
    container.read(playerProvider);
    await flush();
  });

  tearDown(() async {
    container.dispose();
    await flush();
    try {
      temp.deleteSync(recursive: true);
    } on FileSystemException {
      // Best effort on Windows.
    }
  });

  test('20 tracks play one after another, then playback stops', () async {
    final tracks = makeTracks(20);
    await player().playTracks(tracks);
    for (var i = 1; i < 20; i++) {
      expect(engine.activeFiles, lessThanOrEqualTo(1));
      engine.finishCurrent();
      await flush();
    }
    expect(engine.loads, [for (final t in tracks) t.path]);
    expect(state().current!.title, 'Song 20');

    engine.finishCurrent();
    await flush();
    expect(state().playing, isFalse);
    // The end of the last song still plays from the Windows audio buffer;
    // the engine stops after that.
    expect(engine.state.path, tracks.last.path, reason: 'not cut at the end');
    await Future<void>.delayed(PlayerController.endOfQueueDrain + const Duration(milliseconds: 100));
    expect(engine.state.path, isNull, reason: 'stopped at the end');
    expect(engine.loads.length, 20);
  });

  test('pause and resume keep the same file', () async {
    await player().playTracks(makeTracks(3));
    expect(state().playing, isTrue);
    await player().togglePlay();
    expect(state().playing, isFalse);
    await player().togglePlay();
    expect(state().playing, isTrue);
    expect(engine.loads.length, 1);
  });

  test('next / previous; previous after 3 s restarts the song', () async {
    final tracks = makeTracks(3);
    await player().playTracks(tracks);
    await player().next();
    expect(state().current!.title, 'Song 2');
    engine.setPosition(const Duration(seconds: 10));
    await player().previous();
    expect(state().current!.title, 'Song 2');
    expect(engine.state.position, Duration.zero);
    await player().previous();
    expect(state().current!.title, 'Song 1');
  });

  test('repeat one replays the song; repeat all wraps around', () async {
    final tracks = makeTracks(2);
    await player().playTracks(tracks);
    await player().cycleRepeat(); // all
    expect(state().repeat, PlayerRepeat.all);
    engine.finishCurrent();
    await flush();
    engine.finishCurrent();
    await flush();
    expect(state().current!.title, 'Song 1', reason: 'wrapped to start');

    await player().cycleRepeat(); // one
    expect(state().repeat, PlayerRepeat.one);
    final loadsBefore = engine.loads.length;
    engine.finishCurrent();
    await flush();
    expect(state().current!.title, 'Song 1');
    expect(engine.loads.length, loadsBefore + 1);
  });

  test('shuffle keeps every track once and restores the order', () async {
    final tracks = makeTracks(12);
    await player().playTracks(tracks, start: 4);
    await player().toggleShuffle();
    expect(state().current!.title, 'Song 5');
    expect(state().cursor, 0);
    expect(
      state().queue.map((e) => e.track.id).toSet(),
      {for (final t in tracks) t.id},
    );
    expect(state().queue.length, 12);

    await player().toggleShuffle();
    expect(
      state().queue.map((e) => e.track.id).toList(),
      [for (final t in tracks) t.id],
    );
    expect(state().current!.title, 'Song 5');
  });

  test('a missing file is skipped with a clear notice', () async {
    final tracks = makeTracks(3, missing: {2});
    await player().playTracks(tracks);
    engine.finishCurrent();
    await flush();
    expect(state().current!.title, 'Song 3');
    expect(state().notice, contains('file not found'));
    expect(engine.loads, isNot(contains(tracks[1].path)));
  });

  test('engine errors become a readable notice', () async {
    await player().playTracks(makeTracks(1));
    engine.fail('decoder error');
    expect(state().notice, 'Cannot play "Song 1": decoder error');
  });

  test('volume, mute and output device go to the engine', () async {
    await player().playTracks(makeTracks(1));
    await player().setVolume(0.4);
    expect(engine.volume, closeTo(0.4, 1e-9));
    await player().toggleMute();
    expect(engine.volume, 0);
    await player().toggleMute();
    expect(engine.volume, closeTo(0.4, 1e-9));
    await player().setOutputDevice(engine.availableDevices.last);
    expect(engine.device?.id, 'wasapi/speakers');
  });

  test('media keys map to transport actions', () async {
    await player().playTracks(makeTracks(2));
    await player().handleMediaKey('playPause');
    expect(state().playing, isFalse);
    await player().handleMediaKey('next');
    expect(state().current!.title, 'Song 2');
    await player().handleMediaKey('stop');
    expect(state().playing, isFalse);
  });

  test('queue: play next, add, remove, clear', () async {
    final tracks = makeTracks(4);
    await player().playTracks(tracks.sublist(0, 2));
    player().playNext([tracks[3]]);
    expect(state().upNext.first.track.title, 'Song 4');
    player().addToQueue([tracks[2]]);
    expect(state().queue.last.track.title, 'Song 3');
    player().removeFromQueue(state().upNext.first.uid);
    expect(state().upNext.map((e) => e.track.title), ['Song 2', 'Song 3']);
    player().clearUpNext();
    expect(state().upNext, isEmpty);
    expect(state().current!.title, 'Song 1');
  });

  group('songs removed from the library leave the queue (D-042)', () {
    test('a song after the current one: the queue shrinks, playback goes on',
        () async {
      final tracks = makeTracks(4);
      await player().playTracks(tracks, start: 1);
      await player().forgetLibraryTracks({1, 3});
      expect(state().queue.map((e) => e.track.title), ['Song 2', 'Song 4']);
      expect(state().current!.title, 'Song 2');
      expect(state().playing, isTrue);
      expect(engine.loads, [tracks[1].path]);
      expect(engine.preparedPath, tracks[3].path, reason: 'next prepared again');
    });

    test('the playing song: it stops, the next remaining one plays', () async {
      final tracks = makeTracks(4);
      await player().playTracks(tracks);
      await player().forgetLibraryTracks({1, 2});
      expect(state().current!.title, 'Song 3');
      expect(state().playing, isTrue);
      expect(engine.loads, [tracks[0].path, tracks[2].path]);
      expect(engine.activeFiles, 1);
    });

    test('paused stays paused; the last song removed stops the player',
        () async {
      final tracks = makeTracks(3);
      await player().playTracks(tracks, start: 1);
      await player().togglePlay();
      await player().forgetLibraryTracks({2});
      expect(state().current!.title, 'Song 3');
      expect(state().playing, isFalse);
      await player().forgetLibraryTracks({3});
      expect(state().current, isNull);
      expect(state().playing, isFalse);
      expect(engine.state.path, isNull);
      expect(state().queue.map((e) => e.track.title), ['Song 1']);
    });

    test('other sources and unknown ids are left alone', () async {
      final tracks = makeTracks(2);
      await player().playTracks(tracks);
      await player().forgetLibraryTracks({99});
      expect(state().queue.length, 2);
      expect(engine.loads.length, 1);
    });
  });

  group('one queue for all sources (E2.8)', () {
    late _FakeExternal yt;

    setUp(() {
      yt = _FakeExternal();
      container
          .read(externalQueuePlayerProvider.notifier)
          .set(TrackSource.youtube, yt);
    });

    Track video(String id) => youtubeTrack(videoId: id, title: 'Video $id');

    test('Local -> YouTube -> Local plays in order, one sound at a time',
        () async {
      final local = makeTracks(2);
      final v = video('dQw4w9WgXcQ');
      await player().playTracks([local[0], v, local[1]]);
      expect(engine.loads, [local[0].path]);

      engine.finishCurrent();
      await flush();
      expect(yt.started, ['dQw4w9WgXcQ']);
      expect(state().current!.title, 'Video dQw4w9WgXcQ');
      expect(engine.activeFiles, 0, reason: 'NEXA stopped for YouTube');
      expect(state().upNext.single.track.title, 'Song 2');

      // YouTube plays; the transport and the queue follow it.
      yt.active = true;
      player().externalStatus(TrackSource.youtube, 'dQw4w9WgXcQ', active: true);
      expect(state().sounding, isTrue);
      await player().togglePlay();
      expect(yt.pauses, 1);

      // The video ends: the queue goes on with NEXA's engine.
      await player().externalEnded(TrackSource.youtube, 'dQw4w9WgXcQ');
      await flush();
      expect(engine.loads, [local[0].path, local[1].path]);
      expect(state().current!.title, 'Song 2');
    });

    test('a video watched on its own never moves the queue', () async {
      final local = makeTracks(1);
      final v = video('dQw4w9WgXcQ');
      await player().playTracks([v, local[0]]);
      expect(yt.started, ['dQw4w9WgXcQ']);
      // The user watches something else in the YouTube player.
      player().externalStatus(TrackSource.youtube, 'M7lc1UVf-VE', active: true);
      await player().externalEnded(TrackSource.youtube, 'M7lc1UVf-VE');
      await player().externalEnded(TrackSource.youtube, 'dQw4w9WgXcQ');
      expect(state().current!.title, 'Video dQw4w9WgXcQ');
      expect(engine.loads, isEmpty);
      // Play starts the queue's video again.
      await player().togglePlay();
      expect(yt.started, ['dQw4w9WgXcQ', 'dQw4w9WgXcQ']);
    });

    test('autoplay blocked: the queue waits for Continue', () async {
      final local = makeTracks(1);
      await player().playTracks([video('dQw4w9WgXcQ'), local[0]]);
      player().externalStatus(TrackSource.youtube, 'dQw4w9WgXcQ', active: false, blocked: true);
      expect(state().waitingForUser, isTrue);
      expect(state().current!.title, 'Video dQw4w9WgXcQ');
      await player().togglePlay();
      expect(yt.resumes, 1);
      expect(state().waitingForUser, isFalse);
      expect(engine.loads, isEmpty, reason: 'nothing skipped');
    });

    test('an unplayable video is skipped with its reason, never silently',
        () async {
      final local = makeTracks(1);
      await player().playTracks([video('dQw4w9WgXcQ'), local[0]]);
      final uid = state().currentEntry!.uid;
      await player().externalFailed(TrackSource.youtube, 'dQw4w9WgXcQ', 'removed by the owner');
      await flush();
      expect(state().skipped[uid], 'removed by the owner');
      expect(state().notice, contains('removed by the owner'));
      expect(state().current!.title, 'Song 1');
      expect(engine.loads, [local[0].path]);
    });

    test('no YouTube player: marked and skipped', () async {
      container
          .read(externalQueuePlayerProvider.notifier)
          .set(TrackSource.youtube, null);
      final local = makeTracks(1);
      await player().playTracks([video('dQw4w9WgXcQ'), local[0]]);
      expect(state().current!.title, 'Song 1');
      expect(state().skipped.values.single, isNotEmpty);
    });

    test('next entry YouTube: no crossfade into it', () async {
      final local = makeTracks(1);
      await player().playTracks([local[0], video('dQw4w9WgXcQ')]);
      await flush();
      expect(engine.preparedPath, isNull);
    });

    test('the queue comes back after a restart (not playing)', () async {
      final local = makeTracks(2);
      await player().playTracks([local[0], video('dQw4w9WgXcQ'), local[1]]);
      engine.finishCurrent();
      for (var i = 0; i < 5; i++) {
        await flush();
      }
      final saved = await container
          .read(settingsRepositoryProvider)
          .getString(SettingKeys.queue);
      expect(saved, isNotNull);

      // A new start with the same database.
      final db = memoryDatabase();
      addTearDown(db.close);
      for (final t in local) {
        await db
            .into(db.tracks)
            .insert(
              TracksCompanion.insert(
                pathKey: t.path.toLowerCase(),
                path: t.path,
                title: t.title,
                artist: t.artist,
                album: t.album,
                fileSize: 1,
                fileModified: DateTime(2026),
                searchText: t.title.toLowerCase(),
                addedAt: DateTime(2026),
              ),
            );
      }
      // Library ids 1 and 2 are the same songs in the new database.
      await SettingsRepository(db).setString(SettingKeys.queue, saved!);
      final engine2 = FakeEngine();
      final c2 = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          ...testOverrides(engine: engine2).skip(1),
        ],
      );
      addTearDown(c2.dispose);
      c2.read(playerProvider);
      for (var i = 0; i < 5; i++) {
        await flush();
      }
      final restored = c2.read(playerProvider);
      expect(restored.queue.map((e) => e.track.title), [
        'Song 1',
        'Video dQw4w9WgXcQ',
        'Song 2',
      ]);
      expect(restored.cursor, 1);
      expect(restored.playing, isFalse);
      expect(engine2.loads, isEmpty);
    });

    test('queue actions accept every source; repeat and shuffle keep them',
        () async {
      final local = makeTracks(3);
      await player().playTracks(local);
      player().addToQueue([video('aaaaaaaaaaa')]);
      player().playNext([video('bbbbbbbbbbb')]);
      expect(state().queue.map((e) => e.track.title), [
        'Song 1',
        'Video bbbbbbbbbbb',
        'Song 2',
        'Song 3',
        'Video aaaaaaaaaaa',
      ]);
      await player().toggleShuffle();
      expect(state().queue, hasLength(5));
      await player().toggleShuffle();
      expect(state().queue.map((e) => e.track.title).toList()[1],
          'Video bbbbbbbbbbb');
    });
  });
}

class _FakeExternal implements QueueExternalPlayer {
  final List<String> started = [];
  int pauses = 0;
  int resumes = 0;
  @override
  bool active = false;

  @override
  Future<String?> start(Track track) async {
    started.add(track.sourceTrackId);
    return null;
  }

  @override
  Future<void> pause() async {
    pauses++;
    active = false;
  }

  @override
  Future<void> resume() async {
    resumes++;
    active = true;
  }
}
