import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexa_music/app/strings.dart';
import 'package:nexa_music/core/audio/mixing_engine.dart';
import 'package:nexa_music/core/audio/playback_engine.dart';
import 'package:nexa_music/core/models/track.dart';
import 'package:nexa_music/features/library/library_providers.dart';
import 'package:nexa_music/features/mix_engine/mix_settings.dart';
import 'package:nexa_music/features/mix_engine/transition_planner.dart';
import 'package:nexa_music/features/player/player_controller.dart';
import 'package:path/path.dart' as p;

import 'helpers/fake_engine.dart';
import 'helpers/test_app.dart';

Track track(
  int id, {
  String album = 'Album',
  int? number,
  int? disc,
  Duration? length = const Duration(minutes: 3),
  String? path,
}) => Track(
  id: id,
  source: TrackSource.local,
  sourceTrackId: 't$id',
  path: path ?? 't$id.mp3',
  title: 'Song $id',
  artist: 'Artist',
  album: album,
  trackNumber: number,
  discNumber: disc,
  duration: length,
  addedAt: DateTime(2026),
);

void main() {
  group('planTransition (Smart Mix v1 rules)', () {
    const crossfade6 = MixSettings();
    final a = track(1, album: 'A', number: 1);
    final bOtherAlbum = track(2, album: 'B', number: 2);

    test('crossfade uses the chosen seconds', () {
      final plan = planTransition(crossfade6, a, bOtherAlbum);
      expect(plan.kind, TransitionKind.crossfade);
      expect(plan.fade, const Duration(seconds: 6));
    });

    test('0 seconds disables the overlap', () {
      final plan = planTransition(
        crossfade6.copyWith(crossfadeSeconds: 0),
        a,
        bOtherAlbum,
      );
      expect(plan.kind, TransitionKind.gapless);
      expect(plan.reason, S.planCrossfadeOff);
    });

    test('gapless mode never overlaps', () {
      final plan = planTransition(
        crossfade6.copyWith(mode: TransitionMode.gapless),
        a,
        bOtherAlbum,
      );
      expect(plan.kind, TransitionKind.gapless);
      expect(plan.fade, Duration.zero);
    });

    test('the next track of the same album is never mixed', () {
      final next = track(2, album: 'a ', number: 2);
      final plan = planTransition(crossfade6, a, next);
      expect(plan.kind, TransitionKind.gapless);
      expect(plan.reason, S.planSameAlbum);
      // Rule can be switched off; another disc or a jump is not "next".
      expect(
        planTransition(crossfade6.copyWith(albumGapless: false), a, next).kind,
        TransitionKind.crossfade,
      );
      expect(continuesAlbum(a, track(3, album: 'A', number: 3)), isFalse);
      expect(
        continuesAlbum(
          track(1, album: 'A', number: 9, disc: 1),
          track(2, album: 'A', number: 10, disc: 2),
        ),
        isFalse,
      );
    });

    test('short recordings get a short overlap or none', () {
      final short = track(3, length: const Duration(seconds: 12));
      final plan = planTransition(crossfade6, a, short);
      expect(plan.fade, const Duration(seconds: 4), reason: 'a third of 12 s');
      expect(plan.reason, S.planLimitedByLength);
      final tiny = track(4, length: const Duration(milliseconds: 2500));
      expect(planTransition(crossfade6, a, tiny).kind, TransitionKind.gapless);
    });

    test('Smart Mix only shortens, and only when allowed', () {
      final smart = crossfade6.copyWith(
        mode: TransitionMode.smartMix,
        crossfadeSeconds: 10,
      );
      final shortSong = track(5, length: const Duration(seconds: 50));
      final plan = planTransition(smart, a, shortSong);
      expect(plan.fade, const Duration(seconds: 3));
      expect(plan.reason, S.planSmartShortTrack);
      final notAllowed = planTransition(
        smart.copyWith(allowSmartAdjust: false),
        a,
        shortSong,
      );
      expect(notAllowed.fade, const Duration(seconds: 10));
      expect(notAllowed.reason, S.planSmartDefault);
      final longSongs = planTransition(smart, a, track(6));
      expect(longSongs.fade, const Duration(seconds: 10));
    });
  });

  group('MixingEngine (two decks, equal-power crossfade)', () {
    late List<FakeEngine> decks;
    late MixingEngine engine;
    late DateTime now;
    final advanced = <String>[];
    var completed = 0;

    setUp(() {
      decks = [];
      now = DateTime(2026);
      advanced.clear();
      completed = 0;
      engine = MixingEngine(
        createDeck: () {
          final d = FakeEngine();
          decks.add(d);
          return d;
        },
        clock: () => now,
        autoTick: false,
      );
      engine.advanced.listen(advanced.add);
      engine.completed.listen((_) => completed++);
    });

    tearDown(() => engine.dispose());

    int playingDecks() => decks.where((d) => d.state.playing).length;

    test('equal-power gains keep the total power constant', () {
      for (final t in [0.0, 0.25, 0.5, 0.75, 1.0]) {
        final (out, inc) = MixingEngine.equalPowerGains(t);
        expect(out * out + inc * inc, closeTo(1, 1e-9));
      }
      final (out, inc) = MixingEngine.equalPowerGains(0.5);
      expect(out, closeTo(inc, 1e-9));
    });

    test('crossfade: preload, overlap, then only the new file plays', () async {
      await engine.load('a.mp3');
      await engine.prepareNext(
        'b.mp3',
        const TransitionPlan(
          TransitionKind.crossfade,
          fade: Duration(seconds: 6),
        ),
      );
      expect(decks[1].state.path, 'b.mp3', reason: 'preloaded');
      expect(decks[1].state.playing, isFalse);
      expect(decks[1].volume, 0);
      expect(playingDecks(), 1);

      decks[0].setPosition(const Duration(minutes: 2, seconds: 50));
      engine.onTick();
      expect(engine.isFading, isFalse, reason: 'too early');

      decks[0].setPosition(const Duration(minutes: 2, seconds: 54));
      engine.onTick();
      await Future<void>.delayed(Duration.zero);
      expect(engine.isFading, isTrue);
      expect(playingDecks(), 2, reason: 'overlap');

      now = now.add(const Duration(seconds: 3));
      engine.onTick();
      await Future<void>.delayed(Duration.zero);
      expect(decks[0].volume, closeTo(decks[1].volume, 1e-9));

      now = now.add(const Duration(seconds: 3, milliseconds: 100));
      engine.onTick();
      await Future<void>.delayed(Duration.zero);
      expect(engine.isFading, isFalse);
      expect(advanced, ['b.mp3']);
      expect(completed, 0);
      expect(playingDecks(), 1);
      expect(engine.state.path, 'b.mp3');
      expect(decks[1].volume, 1);
    });

    test('gapless is prepared on the playing deck, no second file', () async {
      await engine.load('a.mp3');
      await engine.prepareNext(
        'b.mp3',
        const TransitionPlan(TransitionKind.gapless),
      );
      expect(decks[0].preparedPath, 'b.mp3');
      expect(decks[1].state.path, isNull);
      decks[0].advanceGapless();
      expect(advanced, ['b.mp3']);
      expect(playingDecks(), 1);
    });

    test('cut: the file ends normally', () async {
      await engine.load('a.mp3');
      await engine.prepareNext('b.mp3', TransitionPlan.cut);
      decks[0].finishCurrent();
      expect(completed, 1);
      expect(advanced, isEmpty);
    });

    test('failed preload falls back to a normal transition', () async {
      await engine.load('a.mp3');
      await engine.prepareNext(
        'broken.mp3',
        const TransitionPlan(
          TransitionKind.crossfade,
          fade: Duration(seconds: 6),
        ),
      );
      decks[1].fail('cannot decode');
      decks[0].setPosition(const Duration(minutes: 2, seconds: 58));
      engine.onTick();
      expect(engine.isFading, isFalse);
      decks[0].finishCurrent();
      expect(completed, 1);
    });

    test('volume is applied; seek during a fade finishes it', () async {
      await engine.load('a.mp3');
      await engine.setVolume(0.5);
      expect(decks[0].volume, 0.5);
      await engine.prepareNext(
        'b.mp3',
        const TransitionPlan(
          TransitionKind.crossfade,
          fade: Duration(seconds: 4),
        ),
      );
      decks[0].setPosition(const Duration(minutes: 2, seconds: 57));
      engine.onTick();
      await Future<void>.delayed(Duration.zero);
      expect(engine.isFading, isTrue);
      await engine.seek(const Duration(seconds: 10));
      expect(engine.isFading, isFalse);
      expect(engine.state.path, 'b.mp3');
      expect(decks[1].volume, 0.5);
    });
  });

  group('player + Mix Engine', () {
    late Directory temp;
    late FakeEngine engine;
    late ProviderContainer container;

    List<Track> files(int n) => [
      for (var i = 1; i <= n; i++)
        track(
          i,
          album: 'Album $i',
          path: () {
            final path = p.join(temp.path, 'f$i.mp3');
            File(path).writeAsStringSync('x');
            return path;
          }(),
        ),
    ];

    setUp(() async {
      temp = Directory.systemTemp.createTempSync('nexa_mix_test');
      engine = FakeEngine();
      container = ProviderContainer(overrides: testOverrides(engine: engine));
      container.read(playerProvider);
      container.read(mixSettingsProvider);
      await Future<void>.delayed(Duration.zero);
    });

    tearDown(() async {
      container.dispose();
      await Future<void>.delayed(Duration.zero);
      try {
        temp.deleteSync(recursive: true);
      } on FileSystemException {
        // Best effort on Windows.
      }
    });

    test('the next track is prepared with the Mix plan and followed', () async {
      final tracks = files(3);
      await container.read(playerProvider.notifier).playTracks(tracks);
      await Future<void>.delayed(Duration.zero);
      expect(engine.preparedPath, tracks[1].path);
      expect(engine.preparedPlan!.kind, TransitionKind.crossfade);

      container.read(mixSettingsProvider.notifier).setMode(
        TransitionMode.gapless,
      );
      await Future<void>.delayed(Duration.zero);
      expect(engine.preparedPlan!.kind, TransitionKind.gapless);

      engine.advanceGapless();
      await Future<void>.delayed(Duration.zero);
      expect(container.read(playerProvider).current!.id, 2);
      expect(engine.preparedPath, tracks[2].path, reason: 'next prepared');
      expect(engine.loads.length, 1, reason: 'no reload on a transition');
    });

    test('nothing is prepared after the last track or on repeat one', () async {
      final tracks = files(2);
      final player = container.read(playerProvider.notifier);
      await player.playTracks(tracks, start: 1);
      await Future<void>.delayed(Duration.zero);
      expect(engine.preparedPath, isNull);
      await player.cycleRepeat(); // all
      await Future<void>.delayed(Duration.zero);
      expect(engine.preparedPath, tracks[0].path);
      await player.cycleRepeat(); // one
      await Future<void>.delayed(Duration.zero);
      expect(engine.preparedPath, isNull);
    });
  });

  test('Mix settings are saved and restored', () async {
    final db = memoryDatabase();
    addTearDown(db.close);
    ProviderContainer open() => ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
    );
    final first = open();
    first.read(mixSettingsProvider.notifier)
      ..setMode(TransitionMode.smartMix)
      ..setSeconds(9)
      ..setAlbumGapless(false);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    first.dispose();

    final second = open();
    addTearDown(second.dispose);
    second.read(mixSettingsProvider);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    final s = second.read(mixSettingsProvider);
    expect(s.mode, TransitionMode.smartMix);
    expect(s.crossfadeSeconds, 9);
    expect(s.albumGapless, isFalse);
  });

  testWidgets('choosing Gapless in the panel updates the player chip', (
    tester,
  ) async {
    await pumpNexaApp(tester, size1280);
    expect(find.text('Crossfade 6s'), findsOneWidget);

    await tester.tap(find.byTooltip(S.openNowPlaying).last);
    await settle(tester);
    await tester.tap(find.text(S.modeGapless));
    await settle(tester);

    expect(find.text(S.modeGapless), findsNWidgets(2));
    expect(find.text(S.gaplessNote), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
