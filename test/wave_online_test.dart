import 'dart:io';
import 'dart:math' as math;

import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexa_music/app/strings.dart';
import 'package:nexa_music/core/audio/transition.dart';
import 'package:nexa_music/core/database/app_database.dart';
import 'package:nexa_music/core/models/listening.dart';
import 'package:nexa_music/core/models/track.dart';
import 'package:nexa_music/core/settings/settings_provider.dart';
import 'package:nexa_music/core/settings/settings_repository.dart';
import 'package:nexa_music/features/discover/catalog_providers.dart';
import 'package:nexa_music/features/library/library_providers.dart';
import 'package:nexa_music/features/nexa_dna/dna_providers.dart';
import 'package:nexa_music/features/nexa_wave/wave_controller.dart';
import 'package:nexa_music/features/player/player_controller.dart';
import 'package:nexa_music/integrations/music_source.dart';
import 'package:path/path.dart' as p;

import 'helpers/fake_engine.dart';
import 'helpers/test_app.dart';

/// Catalog stand-in for the Wave (no network in unit tests).
class WaveSource implements MusicSource {
  WaveSource(this.source, {this.songs = const [], this.error});

  @override
  final TrackSource source;
  List<Track> songs;
  CatalogException? error;
  final List<WaveRequest> requests = [];

  @override
  bool get configured => true;

  @override
  Future<List<Track>> search(String query, {int limit = 20}) async =>
      const [];

  @override
  Future<List<WaveCandidate>> waveCandidates(WaveRequest request) async {
    requests.add(request);
    if (error != null) {
      throw error!;
    }
    return [
      for (final t in songs) WaveCandidate(t, 'Popular on ${source.label}'),
    ];
  }
}

Track onlineSong(
  TrackSource source,
  String id, {
  String artist = 'Online artist',
  String genre = 'Electronic',
}) => Track(
  id: Track.onlineId(source, id),
  source: source,
  sourceTrackId: id,
  path: 'https://stream.example/${source.name}/$id',
  title: 'Online $id',
  artist: artist,
  album: source.label,
  genre: genre,
  duration: const Duration(minutes: 3),
  addedAt: DateTime(2026),
);

/// E1 acceptance on the controller level: online picks only when switched
/// on, only likes are sent, Familiar <-> Discovery decides the share, the
/// Wave survives offline catalogs, catalog songs are never mixed or kept in
/// the history, a dead stream is skipped once.
void main() {
  late Directory temp;
  late AppDatabase db;
  late FakeEngine engine;
  late ProviderContainer container;
  late WaveSource audius;
  late WaveSource jamendo;

  Future<void> seed(int count) async {
    final now = DateTime(2026, 10, 25);
    for (var i = 1; i <= count; i++) {
      final path = p.join(temp.path, 'song_$i.mp3');
      File(path).writeAsStringSync('x');
      await db
          .into(db.tracks)
          .insert(
            TracksCompanion.insert(
              pathKey: path.toLowerCase(),
              path: path,
              title: 'Song $i',
              artist: 'Local ${i % 3}',
              album: 'Album $i',
              genre: const Value('Electronic'),
              fileSize: 1,
              fileModified: now,
              searchText: 'song $i',
              addedAt: now,
              durationMs: const Value(180000),
            ),
          );
    }
  }

  setUp(() async {
    temp = Directory.systemTemp.createTempSync('nexa_wave_online');
    db = memoryDatabase();
    engine = FakeEngine();
    audius = WaveSource(
      TrackSource.audius,
      songs: [
        for (var i = 1; i <= 6; i++)
          onlineSong(TrackSource.audius, 'a$i', artist: 'Audius $i'),
      ],
    );
    jamendo = WaveSource(
      TrackSource.jamendo,
      songs: [
        for (var i = 1; i <= 6; i++)
          onlineSong(TrackSource.jamendo, 'j$i', artist: 'Jamendo $i'),
      ],
    );
    container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        ...testOverrides(engine: engine).skip(1),
        waveRandomProvider.overrideWithValue(math.Random(3)),
        musicSourcesProvider.overrideWith((ref) => [audius, jamendo]),
      ],
    );
    container.read(playerProvider);
    container.read(dnaSettingsProvider);
    container.read(waveProvider);
    await pumpEventQueue();
    await seed(12);
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

  WaveController wave() => container.read(waveProvider.notifier);
  DnaSettingsController dna() => container.read(dnaSettingsProvider.notifier);
  PlayerState player() => container.read(playerProvider);
  List<QueueEntry> onlineIn(List<QueueEntry> q) =>
      q.where((e) => e.track.isOnline).toList();

  Future<void> startWave() async {
    await wave().start();
    await pumpEventQueue();
  }

  test('off by default: no catalog is asked, the Wave stays local', () async {
    expect(container.read(dnaSettingsProvider).waveOnline, isFalse);
    await startWave();
    expect(audius.requests, isEmpty);
    expect(jamendo.requests, isEmpty);
    expect(player().queue, hasLength(WaveController.batchSize));
    expect(onlineIn(player().queue), isEmpty);
  });

  test('switched on: only liked genres and artists are sent; Discovery '
      'decides the share; source and reason are known', () async {
    final taste = container.read(tasteRepositoryProvider);
    await taste.setItem(TasteKind.genre, 'Electronic');
    await taste.setItem(TasteKind.artist, 'Bonobo');
    await taste.setItem(TasteKind.artist, 'Never Me', excluded: true);
    await taste.setItem(TasteKind.genre, 'Polka', excluded: true);
    await dna().setWaveOnline(true);
    await dna().setDiscovery(1);
    await startWave();

    for (final source in [audius, jamendo]) {
      final r = source.requests.single;
      expect(r.genres, ['Electronic']);
      expect(r.artists, ['Bonobo']);
    }
    final queue = player().queue;
    expect(queue, hasLength(WaveController.batchSize));
    expect(onlineIn(queue), hasLength(WaveController.batchSize ~/ 2));
    expect(queue.first.track.isOnline, isFalse, reason: 'starts local');
    for (final e in onlineIn(queue)) {
      expect(e.track.source, isNot(TrackSource.local));
      expect(wave().reasonFor(e.track.id), isNotNull);
    }
    expect(container.read(waveProvider).onlineNote, isNull);
    expect(container.read(waveProvider).onlineReady, 12);

    // The choice is saved.
    expect(
      await container
          .read(settingsRepositoryProvider)
          .getBool(SettingKeys.waveOnline),
      isTrue,
    );
  });

  test('Familiar: online picks switched on but none in the queue', () async {
    await dna().setWaveOnline(true);
    await dna().setDiscovery(0);
    await startWave();
    expect(onlineIn(player().queue), isEmpty);
  });

  test('offline catalogs: the Wave plays the library and says why',
      () async {
    audius.error = const CatalogException(CatalogErrorKind.offline);
    jamendo.error = const CatalogException(CatalogErrorKind.offline);
    await dna().setWaveOnline(true);
    await dna().setDiscovery(1);
    await startWave();
    expect(player().queue, hasLength(WaveController.batchSize));
    expect(onlineIn(player().queue), isEmpty);
    expect(player().playing, isTrue);
    expect(
      container.read(waveProvider).onlineNote,
      S.waveOnlineUnavailable(S.waveOnlineWhyOffline),
    );
  });

  test('one catalog failing: the other still adds songs', () async {
    jamendo.error = const CatalogException(CatalogErrorKind.rateLimited);
    await dna().setWaveOnline(true);
    await dna().setDiscovery(1);
    await startWave();
    final online = onlineIn(player().queue);
    expect(online, isNotEmpty);
    expect(online.every((e) => e.track.source == TrackSource.audius), isTrue);
    expect(
      container.read(waveProvider).onlineNote,
      S.waveOnlinePartly('Jamendo', S.waveOnlineWhyRateLimited),
    );
  });

  test('"Not for me" hides a catalog song for the session, saves nothing',
      () async {
    await dna().setWaveOnline(true);
    await dna().setDiscovery(1);
    await startWave();
    final hidden = onlineIn(player().upNext).first.track;
    await wave().dislike(hidden);
    await pumpEventQueue();
    expect(player().queue.any((e) => e.track.id == hidden.id), isFalse);
    await wave().refresh();
    expect(
      container.read(waveProvider).items.any((i) => i.track.id == hidden.id),
      isFalse,
    );
    final disliked = await (db.select(
      db.tracks,
    )..where((t) => t.disliked.equals(true))).get();
    expect(disliked, isEmpty);
  });

  test('local <-> online: cut transitions, history only for library songs',
      () async {
    await dna().setHistoryConsent(true);
    await dna().setWaveOnline(true);
    await dna().setDiscovery(1);
    await startWave();
    // Pattern: local, online, local, ...
    expect(player().current!.isOnline, isFalse);
    expect(player().nextEntry!.track.isOnline, isTrue);
    expect(engine.preparedPlan!.kind, TransitionKind.cut);
    expect(engine.preparedPlan!.reason, S.planNoMixRights);

    engine.finishCurrent(); // local -> online
    await pumpEventQueue();
    expect(player().current!.isOnline, isTrue);
    expect(engine.loads.last, player().current!.path);
    expect(engine.preparedPlan!.kind, TransitionKind.cut);

    engine.finishCurrent(); // online -> local
    await pumpEventQueue();
    expect(player().current!.isOnline, isFalse);
    expect(engine.loads.last, player().current!.path);

    final events = await db.select(db.listeningEvents).get();
    expect(events, isNotEmpty);
    expect(events.every((e) => e.trackId > 0), isTrue,
        reason: 'catalog songs are never written to the history');
  });

  test('a dead stream is skipped once (not twice when the engine also '
      'reports the end)', () async {
    await dna().setWaveOnline(true);
    await dna().setDiscovery(1);
    await startWave();
    await container.read(playerProvider.notifier).jumpTo(1);
    await pumpEventQueue();
    expect(player().current!.isOnline, isTrue);

    engine.fail('HTTP 404');
    await Future<void>.delayed(
      PlayerController.failedStreamGrace + const Duration(milliseconds: 200),
    );
    await pumpEventQueue();
    expect(player().cursor, 2);
    expect(player().notice, S.skippedStream('Online ${_id(player(), 1)}'));

    // Error followed by the engine's own end report: still one step.
    await container.read(playerProvider.notifier).jumpTo(3);
    await pumpEventQueue();
    expect(player().current!.isOnline, isTrue);
    engine.fail('HTTP 404');
    engine.finishCurrent();
    await Future<void>.delayed(
      PlayerController.failedStreamGrace + const Duration(milliseconds: 200),
    );
    await pumpEventQueue();
    expect(player().cursor, 4);
  });

  test('a queue of only dead streams stops instead of looping', () async {
    final notifier = container.read(playerProvider.notifier);
    await notifier.cycleRepeat(); // all
    await notifier.playTracks([
      onlineSong(TrackSource.audius, 'x1'),
      onlineSong(TrackSource.audius, 'x2'),
    ]);
    await pumpEventQueue();
    for (var i = 0; i < 2; i++) {
      engine.fail('HTTP 404');
      await Future<void>.delayed(
        PlayerController.failedStreamGrace + const Duration(milliseconds: 200),
      );
      await pumpEventQueue();
    }
    expect(player().notice, S.noPlayableStream);
    expect(engine.state.path, isNull);
    expect(player().playing, isFalse);
  });

  test('resetting the Wave settings switches online picks off', () async {
    await dna().setWaveOnline(true);
    await dna().resetPreferences();
    expect(container.read(dnaSettingsProvider).waveOnline, isFalse);
    expect(
      await container
          .read(settingsRepositoryProvider)
          .getBool(SettingKeys.waveOnline),
      isFalse,
    );
  });
}

/// The source id of the queue entry at [index] ("a1", "j2", ...).
String _id(PlayerState s, int index) => s.queue[index].track.sourceTrackId;
