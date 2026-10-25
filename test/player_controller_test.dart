import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexa_music/core/models/track.dart';
import 'package:nexa_music/features/player/player_controller.dart';
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
}
