// NEXA Wave across catalogs (E1) on Windows with the real stack: media_kit
// / libmpv, a SQLite file database in a temporary profile, real HTTP.
//
//   flutter test integration_test/wave_online_test.dart -d windows
//
// A local HTTP server stands in for the Audius API (trending list and
// stream endpoint), so the run is repeatable and needs no account; one
// optional check asks the real Audius API and is skipped when offline.
// The test songs are generated tones, played at volume 0 (silent). The
// user's own library and settings are never opened.
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:integration_test/integration_test.dart';
import 'package:media_kit/media_kit.dart' show MediaKit;
import 'package:nexa_music/app/strings.dart';
import 'package:nexa_music/core/audio/transition.dart';
import 'package:nexa_music/core/database/app_database.dart';
import 'package:nexa_music/core/models/listening.dart';
import 'package:nexa_music/features/discover/catalog_providers.dart';
import 'package:nexa_music/features/library/library_providers.dart';
import 'package:nexa_music/features/mix_engine/mix_settings.dart';
import 'package:nexa_music/features/mix_engine/transition_planner.dart';
import 'package:nexa_music/features/nexa_dna/dna_providers.dart';
import 'package:nexa_music/features/nexa_wave/wave_controller.dart';
import 'package:nexa_music/features/player/player_controller.dart';
import 'package:nexa_music/integrations/audius/audius_source.dart';
import 'package:nexa_music/integrations/music_source.dart';
import 'package:path/path.dart' as p;

import '../test/helpers/wav.dart';
import 'support/autotest_support.dart' show FixedPicker, waitUntil;

/// Fake Audius API: `/v1/tracks/trending`, `/v1/tracks/search` and
/// `/v1/tracks/{id}/stream` (a WAV file, or 404 for [dead]).
class FakeAudius {
  FakeAudius._(this._server, this.streams, this.dead);

  final HttpServer _server;
  final Map<String, File> streams;
  final String dead;
  final List<Uri> requests = [];

  static Future<FakeAudius> start(Map<String, File> streams, String dead) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final api = FakeAudius._(server, streams, dead);
    server.listen(api._handle);
    return api;
  }

  Uri get base => Uri.parse('http://127.0.0.1:${_server.port}/v1');

  Future<void> _handle(HttpRequest request) async {
    requests.add(request.uri);
    final path = request.uri.path;
    final response = request.response;
    if (path == '/v1/tracks/trending' || path == '/v1/tracks/search') {
      final ids = path.endsWith('search') ? <String>[] : [...streams.keys, dead];
      response.headers.contentType = ContentType.json;
      response.write(
        jsonEncode({
          'data': [
            for (final id in ids)
              {
                'id': id,
                'title': 'Catalog $id',
                'duration': 200,
                'genre': 'Electronic',
                'permalink': '/fake/$id',
                'is_streamable': true,
                'user': {'name': 'Catalog artist $id'},
              },
          ],
        }),
      );
    } else if (path.startsWith('/v1/tracks/') && path.endsWith('/stream')) {
      final id = path.split('/')[3];
      final file = streams[id];
      if (file == null) {
        response.statusCode = HttpStatus.notFound;
      } else {
        response.headers.contentType = ContentType('audio', 'wav');
        response.contentLength = file.lengthSync();
        await response.addStream(file.openRead());
      }
    } else {
      response.statusCode = HttpStatus.notFound;
    }
    await response.close();
  }

  Future<void> close() => _server.close(force: true);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late Directory temp;
  late Directory library;
  late FakeAudius api;
  final client = http.Client();

  ProviderContainer container(MusicSource catalog, String profile) {
    Directory(profile).createSync(recursive: true);
    return ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWith((ref) {
          final db = AppDatabase(
            NativeDatabase(File(p.join(profile, 'nexa_library.sqlite'))),
          );
          ref.onDispose(db.close);
          return db;
        }),
        artworkDirProvider.overrideWith(
          (ref) async => p.join(profile, 'artwork'),
        ),
        autoRescanProvider.overrideWithValue(false),
        libraryPickerProvider.overrideWithValue(FixedPicker(library.path)),
        musicSourcesProvider.overrideWith((ref) => [catalog]),
        waveRandomProvider.overrideWithValue(math.Random(5)),
      ],
    );
  }

  /// Library imported, silent, history on, online picks on at Discovery.
  Future<void> prepare(ProviderContainer c) async {
    await c.read(libraryScanProvider.notifier).addFolder();
    await waitUntil(() => c.read(dnaSettingsProvider).loaded);
    await waitUntil(() => c.read(catalogSettingsProvider).loaded);
    final dna = c.read(dnaSettingsProvider.notifier);
    await dna.setHistoryConsent(true);
    await dna.setWaveOnline(true);
    await dna.setDiscovery(1);
    await c.read(playerProvider.notifier).setVolume(0);
    c.read(waveProvider);
  }

  setUpAll(() async {
    temp = Directory.systemTemp.createTempSync('nexa_e1_it');
    library = Directory(p.join(temp.path, 'library'))..createSync();
    for (var i = 1; i <= 4; i++) {
      writeWav(
        p.join(library.path, 'local_$i.wav'),
        title: 'Local song $i',
        artist: 'Local artist $i',
        album: 'Local album $i',
        seconds: 4,
        frequency: 300.0 + 100 * i,
        sampleRate: 22050,
      );
    }
    final streams = <String, File>{};
    for (final id in ['live1', 'live2']) {
      final f = File(p.join(temp.path, 'served', '$id.wav'));
      writeWav(f.path, seconds: 4, frequency: 900, sampleRate: 22050);
      streams[id] = f;
    }
    api = await FakeAudius.start(streams, 'dead1');
  });

  tearDownAll(() async {
    await api.close();
    client.close();
    try {
      temp.deleteSync(recursive: true);
    } on FileSystemException {
      // Best effort on Windows (the database may still be closing).
    }
  });

  testWidgets('E1: one Wave queue switches between library songs and '
      'catalog streams; a dead stream is skipped; history only for the '
      'library', (tester) async {
    await tester.runAsync(() async {
      final c = container(
        AudiusSource(client, base: api.base),
        p.join(temp.path, 'profile1'),
      );
      try {
        await prepare(c);
        // Liked genre: the catalog's genre list is asked for. Liked artist:
        // puts the dead stream first among the catalog songs, so it is
        // followed by a playable song (deterministic order).
        final taste = c.read(tasteRepositoryProvider);
        await taste.setItem(TasteKind.genre, 'Electronic');
        await taste.setItem(TasteKind.artist, 'Catalog artist dead1');
        final wave = c.read(waveProvider.notifier);
        final engine = c.read(playbackEngineProvider);

        // Every song that really played (position > 0.8 s), in order.
        final played = <String>[];
        final notices = <String>[];
        final sub = engine.states.listen((s) {
          final path = s.path;
          if (path != null &&
              s.playing &&
              s.position > const Duration(milliseconds: 800) &&
              (played.isEmpty || played.last != path)) {
            played.add(path);
          }
        });
        c.listen(playerProvider.select((s) => s.notice), (_, n) {
          if (n != null) {
            notices.add(n);
          }
        });

        await wave.start();
        final queue = c.read(playerProvider).queue;
        final local = queue.where((e) => !e.track.isOnline).toList();
        final online = queue.where((e) => e.track.isOnline).toList();
        expect(local, hasLength(4));
        expect(online, hasLength(3), reason: 'live1, live2 and dead1');
        expect(queue.first.track.isOnline, isFalse);
        expect(queue.last.track.sourceTrackId, isNot('dead1'));
        for (final e in queue) {
          expect(wave.reasonFor(e.track.id), isNotNull);
        }
        expect(
          api.requests.where((u) => u.path == '/v1/tracks/trending'),
          isNotEmpty,
        );

        // Catalog songs never get a crossfade.
        final mix = c.read(mixSettingsProvider);
        for (var i = 0; i + 1 < queue.length; i++) {
          final a = queue[i].track;
          final b = queue[i + 1].track;
          if (a.isOnline || b.isOnline) {
            expect(planTransition(mix, a, b).kind, TransitionKind.cut);
          }
        }

        // The first batch (7 songs of 4 s, one of them dead) plays through;
        // the Wave is endless, so afterwards it simply goes on (a small
        // library starts a new round).
        final expected = [
          for (final e in queue)
            if (e.track.sourceTrackId != 'dead1') e.track.path,
        ];
        final done = await waitUntil(
          () => played.length > expected.length,
          timeout: const Duration(seconds: 90),
        );
        await sub.cancel();
        // ignore: avoid_print
        print('E1 played: ${played.map(p.basename).join(' -> ')}');
        // ignore: avoid_print
        print('E1 notices: $notices');
        expect(done, isTrue, reason: 'the first batch played and the Wave went on');
        expect(
          played.take(expected.length).toList(),
          expected,
          reason: 'every playable song of the batch, in order',
        );
        expect(
          notices.where((n) => n == S.skippedStream('Catalog dead1')),
          hasLength(1),
          reason: 'the dead stream is skipped exactly once',
        );

        await Future<void>.delayed(const Duration(milliseconds: 500));
        final events = await c.read(appDatabaseProvider).select(
          c.read(appDatabaseProvider).listeningEvents,
        ).get();
        expect(events, isNotEmpty);
        expect(
          events.every((e) => e.trackId > 0),
          isTrue,
          reason: 'catalog songs are never written to the history',
        );
        expect(events.every((e) => e.mode == PlayContext.wave.name), isTrue);
      } finally {
        await c.read(playerProvider.notifier).stop();
        c.dispose();
      }
    });
  }, timeout: const Timeout(Duration(minutes: 4)));

  testWidgets('E1: catalogs unreachable - the Wave plays the library and '
      'says why', (tester) async {
    await tester.runAsync(() async {
      final c = container(
        AudiusSource(client, base: Uri.parse('http://127.0.0.1:9/v1')),
        p.join(temp.path, 'profile2'),
      );
      try {
        await prepare(c);
        await c.read(waveProvider.notifier).start();
        final state = c.read(playerProvider);
        expect(state.queue, isNotEmpty);
        expect(state.queue.every((e) => !e.track.isOnline), isTrue);
        expect(
          c.read(waveProvider).onlineNote,
          S.waveOnlineUnavailable(S.waveOnlineWhyOffline),
        );
        final engine = c.read(playbackEngineProvider);
        final plays = await waitUntil(
          () =>
              engine.state.path == state.current!.path &&
              engine.state.position > const Duration(seconds: 1),
          timeout: const Duration(seconds: 15),
        );
        expect(plays, isTrue, reason: 'the local Wave still plays');
      } finally {
        await c.read(playerProvider.notifier).stop();
        c.dispose();
      }
    });
  }, timeout: const Timeout(Duration(minutes: 2)));

  testWidgets('E1: the real Audius API returns Wave picks (skipped when '
      'offline)', (tester) async {
    await tester.runAsync(() async {
      try {
        final found = await AudiusSource(client).waveCandidates(
          const WaveRequest(genres: ['Electronic'], limit: 10),
        );
        // ignore: avoid_print
        print('E1 live Audius: ${found.length} picks');
        expect(found, isNotEmpty);
        for (final c in found) {
          expect(waveSuitable(c.track), isTrue);
          expect(c.track.pageUrl, startsWith('https://audius.co'));
        }
      } on CatalogException catch (e) {
        if (e.kind != CatalogErrorKind.offline) {
          rethrow;
        }
        // ignore: avoid_print
        print('E1 live Audius: SKIPPED (offline: $e)');
      }
    });
  });
}
