import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nexa_music/core/audio/transition.dart';
import 'package:nexa_music/core/models/track.dart';
import 'package:nexa_music/features/mix_engine/mix_settings.dart';
import 'package:nexa_music/features/mix_engine/transition_planner.dart';
import 'package:nexa_music/integrations/audius/audius_source.dart';
import 'package:nexa_music/integrations/jamendo/jamendo_source.dart';
import 'package:nexa_music/integrations/music_source.dart';

/// Phase 6 (Master Plan v1.0): official catalog adapters return only what
/// the provider allows, label it, and fail without breaking anything.
void main() {
  Map<String, Object?> audiusTrack(String id, {Map<String, Object?> extra = const {}}) => {
    'id': id,
    'title': 'Song $id',
    'duration': 215,
    'genre': 'Electronic',
    'permalink': '/artist/song-$id',
    'is_streamable': true,
    'artwork': {'480x480': 'https://img.example/$id.jpg'},
    'user': {'name': 'Artist $id', 'handle': 'artist$id'},
    ...extra,
  };

  group('Audius', () {
    test('search asks the official API with app_name and maps tracks', () async {
      late Uri asked;
      final client = MockClient((request) async {
        asked = request.url;
        return http.Response(
          jsonEncode({
            'data': [
              audiusTrack('a1'),
              audiusTrack('a2', extra: {'access': {'stream': false}}),
              audiusTrack('a3', extra: {'is_streamable': false}),
              audiusTrack('a4', extra: {'stream_conditions': {'usdc_purchase': {}}}),
              {'id': 'broken'},
            ],
          }),
          200,
        );
      });
      final source = AudiusSource(client);
      final tracks = await source.search('  night drive ');

      expect(asked.host, 'api.audius.co');
      expect(asked.path, '/v1/tracks/search');
      expect(asked.queryParameters['query'], 'night drive');
      expect(asked.queryParameters['app_name'], AudiusSource.defaultAppName);

      expect(tracks, hasLength(4), reason: 'the broken entry is skipped');
      final t = tracks.first;
      expect(t.source, TrackSource.audius);
      expect(t.isOnline, isTrue);
      expect(t.available, isTrue);
      expect(t.title, 'Song a1');
      expect(t.artist, 'Artist a1');
      expect(t.duration, const Duration(seconds: 215));
      expect(t.pageUrl, 'https://audius.co/artist/song-a1');
      expect(t.artworkPath, 'https://img.example/a1.jpg');
      expect(
        Uri.parse(t.path).path,
        '/v1/tracks/a1/stream',
        reason: 'played through the API stream endpoint',
      );
      expect(t.id, isNegative);

      expect(tracks[1].available, isFalse, reason: 'gated by access');
      expect(tracks[2].available, isFalse, reason: 'not streamable');
      expect(tracks[3].available, isFalse, reason: 'stream conditions');
      for (final gated in tracks.skip(1)) {
        expect(gated.problem, isNotNull);
      }
    });

    test('an empty query asks nothing', () async {
      var calls = 0;
      final source = AudiusSource(
        MockClient((_) async {
          calls++;
          return http.Response('{}', 200);
        }),
      );
      expect(await source.search('   '), isEmpty);
      expect(calls, 0);
    });

    test('errors are mapped: offline, rate limit, refused, bad answer', () async {
      Future<CatalogErrorKind> kindFor(MockClient client) async {
        try {
          await AudiusSource(client).search('x');
        } on CatalogException catch (e) {
          return e.kind;
        }
        fail('no exception');
      }

      expect(
        await kindFor(MockClient((_) => throw const SocketException('down'))),
        CatalogErrorKind.offline,
      );
      expect(
        await kindFor(MockClient((_) => throw http.ClientException('reset'))),
        CatalogErrorKind.offline,
      );
      expect(
        await kindFor(MockClient((_) async => http.Response('', 429))),
        CatalogErrorKind.rateLimited,
      );
      expect(
        await kindFor(MockClient((_) async => http.Response('', 403))),
        CatalogErrorKind.notConfigured,
      );
      expect(
        await kindFor(MockClient((_) async => http.Response('<html>', 200))),
        CatalogErrorKind.provider,
      );
      expect(
        await kindFor(MockClient((_) async => http.Response('{"x":1}', 200))),
        CatalogErrorKind.provider,
      );
    });
  });

  group('Jamendo', () {
    Map<String, Object?> jamendoTrack(int id, {String? audio}) => {
      'id': '$id',
      'name': 'Track $id',
      'duration': 180,
      'artist_name': 'Band $id',
      'album_name': 'Album $id',
      'image': 'https://img.jamendo.example/$id.jpg',
      'audio': audio ?? 'https://stream.jamendo.example/$id.mp3',
      'shareurl': 'https://www.jamendo.com/track/$id',
      'license_ccurl': 'http://creativecommons.org/licenses/by-nc-sa/3.0/',
    };

    test('needs the owner\'s client id and never calls without it', () async {
      var calls = 0;
      final source = JamendoSource(
        MockClient((_) async {
          calls++;
          return http.Response('{}', 200);
        }),
        clientId: ' ',
      );
      expect(source.configured, isFalse);
      await expectLater(
        source.search('jazz'),
        throwsA(
          isA<CatalogException>().having(
            (e) => e.kind,
            'kind',
            CatalogErrorKind.notConfigured,
          ),
        ),
      );
      expect(calls, 0);
    });

    test('search maps tracks with licence and backlink', () async {
      late Uri asked;
      final source = JamendoSource(
        MockClient((request) async {
          asked = request.url;
          return http.Response(
            jsonEncode({
              'headers': {'status': 'success', 'code': 0},
              'results': [jamendoTrack(1), jamendoTrack(2, audio: '')],
            }),
            200,
          );
        }),
        clientId: 'my-id',
      );
      final tracks = await source.search('chill');
      expect(asked.host, 'api.jamendo.com');
      expect(asked.path, '/v3.0/tracks/');
      expect(asked.queryParameters['client_id'], 'my-id');
      expect(asked.queryParameters['search'], 'chill');

      final t = tracks.first;
      expect(t.source, TrackSource.jamendo);
      expect(t.available, isTrue);
      expect(t.path, 'https://stream.jamendo.example/1.mp3');
      expect(t.license, 'CC BY-NC-SA 3.0');
      expect(t.licenseUrl, contains('creativecommons.org'));
      expect(t.pageUrl, 'https://www.jamendo.com/track/1');
      expect(tracks[1].available, isFalse, reason: 'no stream offered');
    });

    test('an API error about the client id is reported as a key problem',
        () async {
      final source = JamendoSource(
        MockClient(
          (_) async => http.Response(
            jsonEncode({
              'headers': {
                'status': 'failed',
                'code': 5,
                'error_message': 'Your credential is suspended or client_id is invalid',
              },
              'results': [],
            }),
            200,
          ),
        ),
        clientId: 'wrong',
      );
      await expectLater(
        source.search('x'),
        throwsA(
          isA<CatalogException>().having(
            (e) => e.kind,
            'kind',
            CatalogErrorKind.notConfigured,
          ),
        ),
      );
    });

    test('Creative Commons labels', () {
      expect(
        JamendoSource.creativeCommonsLabel(
          'https://creativecommons.org/licenses/by/4.0/',
        ),
        'CC BY 4.0',
      );
      expect(JamendoSource.creativeCommonsLabel('https://x.example'), 'Licence');
    });
  });

  test('catalog ids are negative, stable and separate per source', () {
    final a = Track.onlineId(TrackSource.audius, '42');
    expect(a, isNegative);
    expect(Track.onlineId(TrackSource.audius, '42'), a);
    expect(Track.onlineId(TrackSource.jamendo, '42'), isNot(a));
  });

  test('catalog tracks may stream but are never mixed (D-017)', () {
    Track make(TrackSource source, int id) => Track(
      id: id,
      source: source,
      sourceTrackId: '$id',
      path: source.isOnline ? 'https://x.example/$id' : 'C:/m/$id.mp3',
      title: 'T$id',
      artist: 'A',
      album: 'B',
      duration: const Duration(minutes: 4),
      addedAt: DateTime(2026),
    );
    final online = make(TrackSource.jamendo, -5);
    expect(online.rights.play, isTrue);
    expect(online.rights.mix, isTrue, reason: 'D-025: catalog streams crossfade');
    expect(online.fileExtension, 'STREAM');
    final plan = planTransition(
      const MixSettings(mode: TransitionMode.crossfade, crossfadeSeconds: 6),
      make(TrackSource.local, 1),
      online,
    );
    expect(plan.kind, TransitionKind.crossfade);
    expect(plan.fade, const Duration(seconds: 6));
  });
}
