import 'dart:io';
import 'dart:math' as math;

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexa_music/core/database/app_database.dart';
import 'package:nexa_music/core/models/listening.dart';
import 'package:nexa_music/features/library/library_providers.dart';
import 'package:nexa_music/features/nexa_dna/dna_providers.dart';
import 'package:nexa_music/features/nexa_dna/taste_repository.dart';
import 'package:nexa_music/features/nexa_wave/wave_controller.dart';
import 'package:nexa_music/features/player/player_controller.dart';
import 'package:path/path.dart' as p;

import 'helpers/fake_engine.dart';
import 'helpers/test_app.dart';

/// Phase 5 acceptance (Master Plan v1.0): listening history only with
/// consent and never in a private session, a dislike excludes a song,
/// preferences change the Wave, everything is local and can be reset.
void main() {
  late Directory temp;
  late AppDatabase db;
  late FakeEngine engine;
  late ProviderContainer container;

  const artists = ['Aurora', 'Bonobo', 'Caribou', 'Daft Punk'];

  Future<void> seed(int count) async {
    final now = DateTime(2026, 10, 19);
    for (var i = 1; i <= count; i++) {
      final path = p.join(temp.path, 'song_$i.mp3');
      File(path).writeAsStringSync('x');
      final artist = artists[i % artists.length];
      await db
          .into(db.tracks)
          .insert(
            TracksCompanion.insert(
              pathKey: path.toLowerCase(),
              path: path,
              title: 'Song $i',
              artist: artist,
              album: 'Album $i',
              genre: Value(i.isEven ? 'Electronic' : 'Pop'),
              fileSize: 1,
              fileModified: now,
              searchText: 'song $i $artist',
              addedAt: now,
              durationMs: const Value(180000),
            ),
          );
    }
  }

  /// The database outlives a container (to test what is saved), so it is
  /// provided as a plain value and closed in [tearDown].
  ProviderContainer makeContainer() => ProviderContainer(
    overrides: [
      appDatabaseProvider.overrideWithValue(db),
      ...testOverrides(engine: engine).skip(1),
      waveRandomProvider.overrideWithValue(math.Random(7)),
    ],
  );

  PlayerController player() => container.read(playerProvider.notifier);
  DnaSettingsController dna() => container.read(dnaSettingsProvider.notifier);
  TasteRepository taste() => container.read(tasteRepositoryProvider);

  Future<List<ListeningEventRow>> events() =>
      db.select(db.listeningEvents).get();

  setUp(() async {
    temp = Directory.systemTemp.createTempSync('nexa_dna_test');
    db = memoryDatabase();
    engine = FakeEngine();
    container = makeContainer();
    container.read(playerProvider);
    container.read(dnaSettingsProvider);
    await pumpEventQueue();
  });

  tearDown(() async {
    container.dispose();
    await pumpEventQueue();
    await db.close();
    try {
      temp.deleteSync(recursive: true);
    } on FileSystemException {
      // Best effort on Windows.
    }
  });

  Future<void> playLibrary() async {
    final tracks = await container.read(libraryRepositoryProvider).getTracks();
    await player().playTracks(tracks);
    await pumpEventQueue();
  }

  test('without consent nothing is recorded', () async {
    await seed(3);
    expect(container.read(dnaSettingsProvider).historyConsent, isFalse);
    await playLibrary();
    await player().next();
    engine.finishCurrent();
    await pumpEventQueue();
    expect(await events(), isEmpty);
  });

  test('with consent: skips, completions and stops are recorded locally',
      () async {
    await seed(4);
    await dna().setHistoryConsent(true);
    await playLibrary();

    engine.setPosition(const Duration(seconds: 10));
    await player().next(); // fast skip of song 1
    engine.setPosition(const Duration(seconds: 95));
    await player().next(); // late skip of song 2
    engine.finishCurrent(); // song 3 played to the end
    await pumpEventQueue();
    engine.setPosition(const Duration(seconds: 20));
    await player().stop(); // song 4 stopped
    await pumpEventQueue();

    final rows = await events();
    expect([for (final r in rows) r.endReason], [
      'skipped',
      'skipped',
      'completed',
      'stopped',
    ]);
    expect(rows[0].listenedMs, 10000);
    expect(rows[1].listenedMs, 95000);
    expect(rows.every((r) => r.mode == PlayContext.library.name), isTrue);

    final stats = await taste().trackStats();
    expect(stats[rows[0].trackId]!.fastSkips, 1);
    expect(stats[rows[1].trackId]!.lateSkips, 1);
    expect(stats[rows[2].trackId]!.completions, 1);
    expect(await taste().recentTrackIds(), [
      rows[3].trackId,
      rows[2].trackId,
      rows[1].trackId,
      rows[0].trackId,
    ]);
  });

  test('a private session and paused learning record nothing', () async {
    await seed(3);
    await dna().setHistoryConsent(true);
    dna().setPrivateSession(true);
    await playLibrary();
    await player().next();
    expect(await events(), isEmpty, reason: 'private session');

    dna().setPrivateSession(false);
    await dna().setLearningPaused(true);
    await player().next();
    expect(await events(), isEmpty, reason: 'learning paused');

    await dna().setLearningPaused(false);
    engine.finishCurrent();
    await pumpEventQueue();
    expect(await events(), hasLength(1), reason: 'recording again');
  });

  test('settings are saved; a private session is not', () async {
    await dna().setHistoryConsent(true);
    await dna().setDiscovery(0.8);
    await dna().setOnboarded(true);
    dna().setPrivateSession(true);

    container.dispose();
    engine = FakeEngine();
    container = makeContainer();
    container.read(dnaSettingsProvider);
    await pumpEventQueue();
    final s = container.read(dnaSettingsProvider);
    expect(s.loaded, isTrue);
    expect(s.historyConsent, isTrue);
    expect(s.discovery, closeTo(0.8, 1e-9));
    expect(s.onboarded, isTrue);
    expect(s.privateSession, isFalse);
  });

  test('history can be deleted and NEXA DNA reset', () async {
    await seed(3);
    await dna().setHistoryConsent(true);
    await playLibrary();
    await player().next();
    await taste().setItem(TasteKind.artist, 'Bonobo');
    await taste().setItem(TasteKind.genre, 'Pop', excluded: true);
    final tracks = await container.read(libraryRepositoryProvider).getTracks();
    await taste().setDisliked(tracks.first.id, true);

    expect(await taste().eventCount(), 1);
    await taste().clearHistory();
    expect(await taste().eventCount(), 0);

    expect(await taste().getItems(), hasLength(2));
    await taste().resetTaste();
    expect(await taste().getItems(), isEmpty);
    final after = await container.read(libraryRepositoryProvider).getTracks();
    expect(after.any((t) => t.disliked), isFalse);
  });

  test('taste choices are stored once per genre / artist and can change',
      () async {
    await taste().setItem(TasteKind.artist, 'Bonobo');
    await taste().setItem(TasteKind.artist, ' bonobo ', excluded: true);
    final items = await taste().getItems();
    expect(items, hasLength(1));
    expect(items.single.excluded, isTrue);
    await taste().removeItem(TasteKind.artist, 'BONOBO');
    expect(await taste().getItems(), isEmpty);
  });

  test('a dislike removes the favorite and a like removes the dislike',
      () async {
    await seed(1);
    final repo = container.read(libraryRepositoryProvider);
    final id = (await repo.getTracks()).single.id;
    await repo.setFavorite(id, true);
    await taste().setDisliked(id, true);
    var t = await repo.getTrack(id);
    expect(t!.disliked, isTrue);
    expect(t.favorite, isFalse);
    await repo.setFavorite(id, true);
    t = await repo.getTrack(id);
    expect(t!.disliked, isFalse);
    expect(t.favorite, isTrue);
  });

  group('NEXA Wave', () {
    WaveController wave() => container.read(waveProvider.notifier);

    test('starts a Wave queue from playable songs with reasons', () async {
      await seed(12);
      container.read(waveProvider);
      await wave().start();
      await pumpEventQueue();
      final state = container.read(playerProvider);
      expect(state.context, PlayContext.wave);
      expect(state.queue, hasLength(WaveController.batchSize));
      expect(state.playing, isTrue);
      for (final e in state.queue) {
        expect(wave().reasonFor(e.track.id), isNotNull);
      }
    });

    test('preferences change the queue', () async {
      await seed(12);
      await taste().setItem(TasteKind.artist, 'Caribou');
      container.read(waveProvider);
      await wave().start();
      await pumpEventQueue();
      final queue = container.read(playerProvider).queue;
      expect(queue.first.track.artist, 'Caribou');
      // Liked songs lead; other artists are mixed in between them.
      expect(
        queue.take(5).where((e) => e.track.artist == 'Caribou'),
        hasLength(3),
      );
    });

    test('the Wave refills itself before the queue runs out', () async {
      await seed(12);
      container.read(waveProvider);
      await wave().start();
      await pumpEventQueue();
      await player().jumpTo(WaveController.batchSize - 1);
      await pumpEventQueue();
      final queue = container.read(playerProvider).queue;
      expect(queue.length, greaterThan(WaveController.batchSize));
      expect(
        queue.map((e) => e.track.id).toSet(),
        hasLength(12),
        reason: 'all songs once before any repeats',
      );
    });

    test('a dislike skips the playing Wave song and excludes it', () async {
      await seed(6);
      container.read(waveProvider);
      await wave().start();
      await pumpEventQueue();
      final current = container.read(playerProvider).current!;
      await wave().dislike(current);
      await pumpEventQueue();
      final state = container.read(playerProvider);
      expect(state.current!.id, isNot(current.id));
      expect(state.upNext.any((e) => e.track.id == current.id), isFalse);

      await wave().start();
      await pumpEventQueue();
      expect(
        container.read(playerProvider).queue.any(
          (e) => e.track.id == current.id,
        ),
        isFalse,
      );
    });

    test('works only from the local library (no network involved) and '
        'explains an empty library', () async {
      container.read(waveProvider);
      await wave().start();
      await pumpEventQueue();
      expect(container.read(playerProvider).current, isNull);
      expect(container.read(waveProvider).message, isNotNull);
    });
  });

  test('migration from schema v2 keeps the library and adds NEXA DNA',
      () async {
    final file = File(p.join(temp.path, 'nexa_v2.sqlite'));
    final v3 = AppDatabase(NativeDatabase(file));
    final now = DateTime(2026, 10, 19);
    await v3
        .into(v3.tracks)
        .insert(
          TracksCompanion.insert(
            pathKey: 'c:/m/1.mp3',
            path: 'C:/m/1.mp3',
            title: 'Old song',
            artist: 'Artist',
            album: 'Album',
            fileSize: 1,
            fileModified: now,
            searchText: 'old song',
            addedAt: now,
            favorite: const Value(true),
          ),
        );
    // Turn it into a schema v2 database (as on the owner's PC).
    for (final sql in [
      'DROP TABLE listening_events',
      'DROP TABLE taste_items',
      'ALTER TABLE tracks DROP COLUMN disliked_at',
      'ALTER TABLE tracks DROP COLUMN disliked',
      'PRAGMA user_version = 2',
    ]) {
      await v3.customStatement(sql);
    }
    await v3.close();

    final upgraded = AppDatabase(NativeDatabase(file));
    addTearDown(upgraded.close);
    final rows = await upgraded.select(upgraded.tracks).get();
    expect(rows.single.title, 'Old song');
    expect(rows.single.favorite, isTrue);
    expect(rows.single.disliked, isFalse);
    final repo = TasteRepository(upgraded);
    await repo.recordEvent(
      ListeningEvent(
        trackId: rows.single.id,
        startedAt: now,
        listened: const Duration(seconds: 30),
        reason: EndReason.completed,
        context: PlayContext.library,
      ),
    );
    await repo.setItem(TasteKind.genre, 'Pop');
    expect(await repo.eventCount(), 1);
    expect(await repo.getItems(), hasLength(1));
  });
}
