import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nexa_music/core/models/track.dart';
import 'package:nexa_music/integrations/audius/audius_source.dart';
import 'package:nexa_music/integrations/jamendo/jamendo_source.dart';
import 'package:nexa_music/integrations/music_source.dart';

/// E1: what the catalog adapters ask for NEXA Wave and what they return.
/// Only liked genres and artists are sent; removed, gated, stream-less,
/// non-music and odd-length songs never reach the Wave.
void main() {
  Map<String, Object?> audiusTrack(
    String id, {
    String artist = 'Artist',
    String genre = 'Electronic',
    int duration = 200,
    Map<String, Object?> extra = const {},
  }) => {
    'id': id,
    'title': 'Song $id',
    'duration': duration,
    'genre': genre,
    'permalink': '/a/$id',
    'is_streamable': true,
    'user': {'name': artist, 'handle': artist.toLowerCase()},
    ...extra,
  };

  http.Response json(Object body) => http.Response(
    jsonEncode(body),
    200,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );

  group('Audius', () {
    test('liked genres use the official trending list per genre; artists '
        'the search, keeping only that artist', () async {
      final asked = <Uri>[];
      final client = MockClient((request) async {
        asked.add(request.url);
        if (request.url.path.endsWith('/tracks/trending')) {
          final g = request.url.queryParameters['genre']!;
          return json({
            'data': [
              audiusTrack('t-$g', genre: g),
              audiusTrack('gone', extra: {'is_delete': true}),
              audiusTrack('gated', extra: {'access': {'stream': false}}),
              audiusTrack('mix', duration: 3410),
              audiusTrack('snip', duration: 12),
              audiusTrack('pod', genre: 'Podcasts'),
            ],
          });
        }
        return json({
          'data': [
            audiusTrack('own', artist: 'Bonobo'),
            audiusTrack('other', artist: 'Bonobo Tribute Band'),
          ],
        });
      });
      final found = await AudiusSource(client).waveCandidates(
        const WaveRequest(
          genres: ['Hip-Hop', 'electronic', 'Polka Fusion'],
          artists: ['bonobo'],
        ),
      );

      final trending = asked.where((u) => u.path.endsWith('/trending'));
      expect(
        trending.map((u) => u.queryParameters['genre']).toSet(),
        {'Hip-Hop/Rap', 'Electronic'},
        reason: 'mapped to Audius genres; an unknown genre is not guessed',
      );
      for (final u in asked) {
        expect(u.host, 'api.audius.co');
        expect(u.queryParameters['app_name'], AudiusSource.defaultAppName);
      }
      final search = asked.singleWhere((u) => u.path.endsWith('/search'));
      expect(search.queryParameters['query'], 'bonobo');

      final ids = {for (final c in found) c.track.sourceTrackId};
      expect(ids, {'t-Hip-Hop/Rap', 't-Electronic', 'own'});
      for (final c in found) {
        expect(c.track.source, TrackSource.audius);
        expect(c.track.available, isTrue);
        expect(c.basis, contains('Audius'));
      }
      expect(
        found.singleWhere((c) => c.track.sourceTrackId == 'own').basis,
        contains('Bonobo'),
      );
    });

    test('without liked genres or artists: popular this week, nothing '
        'personal is sent', () async {
      late Uri asked;
      final client = MockClient((request) async {
        asked = request.url;
        return json({
          'data': [audiusTrack('a')],
        });
      });
      final found = await AudiusSource(
        client,
      ).waveCandidates(const WaveRequest());
      expect(asked.path, '/v1/tracks/trending');
      expect(asked.queryParameters.keys.toSet(), {'time', 'limit', 'app_name'});
      expect(asked.queryParameters['time'], 'week');
      expect(found.single.basis, 'Popular on Audius right now');
    });

    test('at most three genres and three artists are asked for', () async {
      var calls = 0;
      final client = MockClient((request) async {
        calls++;
        return json({'data': const []});
      });
      await AudiusSource(client).waveCandidates(
        const WaveRequest(
          genres: ['Rock', 'Pop', 'Jazz', 'Metal', 'Folk'],
          artists: ['A', 'B', 'C', 'D'],
        ),
      );
      expect(calls, 6);
    });

    test('offline: the error is reported (the Wave then uses the library)',
        () async {
      final client = MockClient(
        (request) async => throw http.ClientException('no network'),
      );
      await expectLater(
        AudiusSource(client).waveCandidates(
          const WaveRequest(genres: ['Rock', 'Pop']),
        ),
        throwsA(
          isA<CatalogException>().having(
            (e) => e.kind,
            'kind',
            CatalogErrorKind.offline,
          ),
        ),
      );
    });

    test('one failing request does not hide the others', () async {
      final client = MockClient((request) async {
        if (request.url.queryParameters['genre'] == 'Rock') {
          return http.Response('oops', 500);
        }
        return json({
          'data': [audiusTrack('p', genre: 'Pop')],
        });
      });
      final found = await AudiusSource(
        client,
      ).waveCandidates(const WaveRequest(genres: ['Rock', 'Pop']));
      expect(found.single.track.sourceTrackId, 'p');
    });

    test('genre mapping', () {
      expect(AudiusSource.audiusGenre('R&B'), 'R&B/Soul');
      expect(AudiusSource.audiusGenre('drum and bass'), 'Drum & Bass');
      expect(AudiusSource.audiusGenre('LOFI'), 'Lo-Fi');
      expect(AudiusSource.audiusGenre('Deep House'), 'Deep House');
      expect(AudiusSource.audiusGenre('Synthwave'), isNull);
      expect(AudiusSource.audiusGenre(''), isNull);
    });
  });

  group('Jamendo', () {
    Map<String, Object?> jamendoTrack(
      String id, {
      String artist = 'Artist',
      List<String> genres = const ['rock'],
      String audio = 'https://stream.example/x.mp3',
      int duration = 180,
    }) => {
      'id': id,
      'name': 'Track $id',
      'artist_name': artist,
      'album_name': 'Album',
      'duration': duration,
      'audio': audio,
      'shareurl': 'https://www.jamendo.com/track/$id',
      'license_ccurl': 'https://creativecommons.org/licenses/by-sa/3.0/',
      'musicinfo': {
        'tags': {'genres': genres},
      },
    };

    Map<String, Object?> ok(List<Object?> results) => {
      'headers': {'status': 'success', 'code': 0},
      'results': results,
    };

    test('liked genres are asked as fuzzy tags, artists by name; genres '
        'come back from musicinfo', () async {
      final asked = <Uri>[];
      final client = MockClient((request) async {
        asked.add(request.url);
        final q = request.url.queryParameters;
        if (q.containsKey('fuzzytags')) {
          return json(
            ok([
              jamendoTrack('1', genres: ['rock', 'indie']),
              jamendoTrack('2', audio: ''),
            ]),
          );
        }
        return json(ok([jamendoTrack('3', artist: 'Kasbo')]));
      });
      final found = await JamendoSource(client, clientId: 'my-id')
          .waveCandidates(
            const WaveRequest(genres: ['Rock', 'Hip-Hop'], artists: ['Kasbo']),
          );

      final tags = asked.singleWhere(
        (u) => u.queryParameters.containsKey('fuzzytags'),
      );
      expect(tags.queryParameters['fuzzytags'], 'rock hiphop');
      expect(tags.queryParameters['boost'], 'popularity_month');
      expect(tags.queryParameters['include'], 'musicinfo');
      expect(tags.queryParameters['client_id'], 'my-id');
      expect(
        asked.where((u) => u.queryParameters['artist_name'] == 'Kasbo'),
        hasLength(1),
      );

      expect(found.map((c) => c.track.sourceTrackId).toSet(), {'1', '3'});
      final rock = found.firstWhere((c) => c.track.sourceTrackId == '1');
      expect(rock.track.genre, 'rock; indie');
      expect(rock.track.license, 'CC BY-SA 3.0');
      expect(rock.track.source, TrackSource.jamendo);
    });

    test('without likes: popular this week', () async {
      late Uri asked;
      final client = MockClient((request) async {
        asked = request.url;
        return json(ok([jamendoTrack('1')]));
      });
      final found = await JamendoSource(client, clientId: 'id')
          .waveCandidates(const WaveRequest());
      expect(asked.queryParameters['boost'], 'popularity_week');
      expect(asked.queryParameters.containsKey('fuzzytags'), isFalse);
      expect(asked.queryParameters.containsKey('artist_name'), isFalse);
      expect(found.single.basis, 'Popular on Jamendo right now');
    });

    test('without a client id nothing is asked', () async {
      var calls = 0;
      final client = MockClient((request) async {
        calls++;
        return json(ok(const []));
      });
      await expectLater(
        JamendoSource(client, clientId: ' ').waveCandidates(
          const WaveRequest(genres: ['rock']),
        ),
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

    test('tag mapping', () {
      expect(JamendoSource.jamendoTag('Hip-Hop'), 'hiphop');
      expect(JamendoSource.jamendoTag('R&B'), 'rnb');
      expect(JamendoSource.jamendoTag('Drum & Bass'), 'drumnbass');
      expect(JamendoSource.jamendoTag('!!'), '');
    });
  });

  test('a Wave song must be playable, music and song-length', () {
    Track t({
      bool available = true,
      String path = 'https://s/1',
      Duration? duration = const Duration(minutes: 3),
      String? genre,
    }) => Track(
      id: -1,
      source: TrackSource.audius,
      sourceTrackId: '1',
      path: path,
      title: 'T',
      artist: 'A',
      album: 'Audius',
      genre: genre,
      duration: duration,
      available: available,
      addedAt: DateTime(2026),
    );
    expect(waveSuitable(t()), isTrue);
    expect(waveSuitable(t(duration: null)), isTrue);
    expect(waveSuitable(t(available: false)), isFalse);
    expect(waveSuitable(t(path: '')), isFalse);
    expect(waveSuitable(t(duration: const Duration(seconds: 10))), isFalse);
    expect(waveSuitable(t(duration: const Duration(minutes: 40))), isFalse);
    expect(waveSuitable(t(genre: 'Podcasts')), isFalse);
  });
}
