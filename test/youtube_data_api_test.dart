import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nexa_music/integrations/youtube/youtube_data_api.dart';

/// E2.3: YouTube Data API v3 search - requests, parsing, quota-aware
/// errors, and the key never leaking into errors.
void main() {
  const key = 'test-key-123';

  Map<String, Object?> searchBody() => {
    'items': [
      {
        'id': {'kind': 'youtube#video', 'videoId': 'aaaaaaaaaaa'},
        'snippet': {
          'title': 'Rock &amp; Roll &quot;Live&quot;',
          'channelTitle': 'Channel A',
          'liveBroadcastContent': 'none',
          'thumbnails': {
            'default': {'url': 'https://i.ytimg.com/vi/a/default.jpg'},
            'medium': {'url': 'https://i.ytimg.com/vi/a/mqdefault.jpg'},
          },
        },
      },
      {
        'id': {'kind': 'youtube#video', 'videoId': 'bbbbbbbbbbb'},
        'snippet': {
          'title': 'Live now',
          'channelTitle': 'Channel B',
          'liveBroadcastContent': 'live',
          'thumbnails': {},
        },
      },
      {
        'id': {'kind': 'youtube#channel', 'channelId': 'x'},
        'snippet': {'title': 'not a video'},
      },
    ],
  };

  test('search asks for embeddable videos only and adds their length', () async {
    final requests = <Uri>[];
    final api = YouTubeDataApi(
      MockClient((r) async {
        requests.add(r.url);
        if (r.url.path.endsWith('/search')) {
          return http.Response(jsonEncode(searchBody()), 200);
        }
        return http.Response(
          jsonEncode({
            'items': [
              {
                'id': 'aaaaaaaaaaa',
                'contentDetails': {'duration': 'PT1H2M3S'},
              },
              {
                'id': 'bbbbbbbbbbb',
                'contentDetails': {'duration': 'P0D'},
              },
            ],
          }),
          200,
        );
      }),
      apiKey: key,
    );
    final found = await api.search('  night drive ');
    expect(requests, hasLength(2));
    final search = requests.first;
    expect(search.host, 'www.googleapis.com');
    expect(search.path, '/youtube/v3/search');
    expect(search.queryParameters['q'], 'night drive');
    expect(search.queryParameters['type'], 'video');
    expect(search.queryParameters['videoEmbeddable'], 'true');
    expect(search.queryParameters['part'], 'snippet');
    expect(search.queryParameters['key'], key);
    expect(requests.last.path, '/youtube/v3/videos');
    expect(requests.last.queryParameters['id'], 'aaaaaaaaaaa,bbbbbbbbbbb');

    expect(found, hasLength(2), reason: 'the channel result is dropped');
    expect(found.first.title, 'Rock & Roll "Live"');
    expect(found.first.channel, 'Channel A');
    expect(found.first.thumbnailUrl, 'https://i.ytimg.com/vi/a/mqdefault.jpg');
    expect(found.first.duration, const Duration(hours: 1, minutes: 2, seconds: 3));
    expect(found.last.live, isTrue);
    expect(found.last.duration, isNull);
  });

  test('an empty query or a missing key sends nothing', () async {
    var calls = 0;
    final client = MockClient((r) async {
      calls++;
      return http.Response('{}', 200);
    });
    expect(await YouTubeDataApi(client, apiKey: key).search('  '), isEmpty);
    await expectLater(
      YouTubeDataApi(client, apiKey: ' ').search('x'),
      throwsA(
        isA<YouTubeApiException>().having(
          (e) => e.error,
          'error',
          YouTubeApiError.badKey,
        ),
      ),
    );
    expect(calls, 0);
  });

  test('lengths are optional: the list still shows when that call fails',
      () async {
    final api = YouTubeDataApi(
      MockClient((r) async {
        if (r.url.path.endsWith('/search')) {
          return http.Response(jsonEncode(searchBody()), 200);
        }
        return http.Response('{}', 500);
      }),
      apiKey: key,
    );
    final found = await api.search('x');
    expect(found, hasLength(2));
    expect(found.first.duration, isNull);
  });

  Map<String, Object?> error(int code, String reason, {String? status}) => {
    'error': {
      'code': code,
      'message': 'API key not valid. Please pass a valid API key. key=$key',
      'errors': [
        {'reason': reason, 'domain': 'global'},
      ],
      'status': ?status,
    },
  };

  for (final (status, body, expected) in [
    (400, error(400, 'badRequest', status: 'INVALID_ARGUMENT'), YouTubeApiError.badKey),
    (400, error(400, 'keyInvalid'), YouTubeApiError.badKey),
    (403, error(403, 'forbidden'), YouTubeApiError.badKey),
    (403, error(403, 'quotaExceeded'), YouTubeApiError.quotaExceeded),
    (403, error(403, 'dailyLimitExceeded'), YouTubeApiError.quotaExceeded),
    (403, error(403, 'rateLimitExceeded'), YouTubeApiError.rateLimited),
    (429, <String, Object?>{}, YouTubeApiError.rateLimited),
    (403, error(403, 'accessNotConfigured'), YouTubeApiError.apiDisabled),
    (503, <String, Object?>{}, YouTubeApiError.provider),
  ]) {
    test('HTTP $status ${jsonEncode(body).length > 2 ? '(reason)' : ''} -> '
        '${expected.name}; the key is not in the error', () async {
      final api = YouTubeDataApi(
        MockClient((r) async => http.Response(jsonEncode(body), status)),
        apiKey: key,
      );
      try {
        await api.search('x');
        fail('no error');
      } on YouTubeApiException catch (e) {
        expect(e.error, expected);
        expect(e.toString(), isNot(contains(key)));
      }
    });
  }

  test('offline: a plain error, without the request URL (it has the key)',
      () async {
    for (final failure in <Object>[
      const SocketException('no network'),
      http.ClientException('Failed host lookup', Uri.parse('https://x/?key=$key')),
    ]) {
      final api = YouTubeDataApi(
        MockClient((r) async => throw failure),
        apiKey: key,
      );
      try {
        await api.checkKey();
        fail('no error');
      } on YouTubeApiException catch (e) {
        expect(e.error, YouTubeApiError.offline);
        expect(e.toString(), isNot(contains(key)));
      }
    }
  });

  test('checking a key costs one cheap videos.list call', () async {
    final requests = <Uri>[];
    final api = YouTubeDataApi(
      MockClient((r) async {
        requests.add(r.url);
        return http.Response('{"items": []}', 200);
      }),
      apiKey: key,
    );
    await api.checkKey();
    expect(requests.single.path, '/youtube/v3/videos');
    expect(requests.single.queryParameters['part'], 'id');
  });

  test('ISO 8601 lengths', () {
    expect(parseIsoDuration('PT4M13S'), const Duration(minutes: 4, seconds: 13));
    expect(parseIsoDuration('PT45S'), const Duration(seconds: 45));
    expect(parseIsoDuration('P1DT2H'), const Duration(days: 1, hours: 2));
    expect(parseIsoDuration('P0D'), Duration.zero);
    expect(parseIsoDuration('soon'), isNull);
    expect(parseIsoDuration(null), isNull);
  });
}
