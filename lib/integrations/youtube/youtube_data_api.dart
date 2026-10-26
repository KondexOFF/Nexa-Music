import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// One YouTube video found by the search (E2.3). Shown only for the
/// session; never stored (YouTube API Services Developer Policies III.E.4).
@immutable
class YouTubeVideo {
  const YouTubeVideo({
    required this.id,
    required this.title,
    required this.channel,
    this.thumbnailUrl,
    this.duration,
    this.live = false,
  });

  final String id;
  final String title;
  final String channel;
  final String? thumbnailUrl;
  final Duration? duration;

  /// A live broadcast (no fixed length).
  final bool live;
}

enum YouTubeApiError {
  /// The key is missing, wrong or restricted to something else.
  badKey,

  /// "YouTube Data API v3" is not enabled in the key's Google Cloud project.
  apiDisabled,

  /// The daily quota of the key's project is used up.
  quotaExceeded,

  /// Too many requests in a short time.
  rateLimited,

  /// No network / YouTube cannot be reached.
  offline,

  /// Anything else YouTube answered with.
  provider,
}

/// A failed Data API call. Never carries the key or the request URL.
class YouTubeApiException implements Exception {
  const YouTubeApiException(this.error, [this.detail]);

  final YouTubeApiError error;

  /// YouTube's reason code (e.g. `quotaExceeded`), never free text.
  final String? detail;

  @override
  String toString() =>
      'YouTubeApiException($error${detail == null ? '' : ': $detail'})';
}

/// The official YouTube Data API v3 (search only, E2.3).
///
/// The owner's own API key is sent with each request and nowhere else.
/// Quota (Google's defaults, checked 2026-10-26): 10,000 units per day per
/// project; `search.list` costs 100 units, `videos.list` 1 unit - so about
/// 99 searches a day. NEXA searches only when the user presses Search and
/// keeps the results of the last queries in memory for the session.
class YouTubeDataApi {
  YouTubeDataApi(this._client, {required this.apiKey, Uri? base})
    : base = base ?? Uri.parse('https://www.googleapis.com/youtube/v3');

  final http.Client _client;
  final String apiKey;
  final Uri base;

  static const int searchCost = 100;
  static const Duration _timeout = Duration(seconds: 15);

  /// A public video that always exists (YouTube's own API demo), used to
  /// check a key for 1 quota unit.
  static const String probeVideo = 'M7lc1UVf-VE';

  bool get configured => apiKey.trim().isNotEmpty;

  /// Embeddable videos for [query], with their length.
  Future<List<YouTubeVideo>> search(String query, {int limit = 12}) async {
    final q = query.trim();
    if (q.isEmpty) {
      return const [];
    }
    final found = await _get('search', {
      'part': 'snippet',
      'type': 'video',
      'videoEmbeddable': 'true',
      'safeSearch': 'moderate',
      'maxResults': '${limit.clamp(1, 25)}',
      'q': q,
    });
    final items = found['items'];
    final videos = <YouTubeVideo>[];
    if (items is List) {
      for (final item in items.whereType<Map<String, Object?>>()) {
        final id = item['id'];
        final snippet = item['snippet'];
        if (id is! Map || snippet is! Map) {
          continue;
        }
        final videoId = id['videoId'];
        if (videoId is! String || videoId.isEmpty) {
          continue;
        }
        videos.add(
          YouTubeVideo(
            id: videoId,
            title: _text(snippet['title']),
            channel: _text(snippet['channelTitle']),
            thumbnailUrl: _thumbnail(snippet['thumbnails']),
            live: snippet['liveBroadcastContent'] == 'live',
          ),
        );
      }
    }
    if (videos.isEmpty) {
      return videos;
    }
    // Lengths (1 unit); the list still shows when this call fails.
    try {
      final details = await _get('videos', {
        'part': 'contentDetails',
        'id': videos.map((v) => v.id).join(','),
      });
      final lengths = <String, Duration>{};
      final list = details['items'];
      if (list is List) {
        for (final item in list.whereType<Map<String, Object?>>()) {
          final content = item['contentDetails'];
          final d = content is Map ? parseIsoDuration(content['duration']) : null;
          if (item['id'] is String && d != null) {
            lengths[item['id']! as String] = d;
          }
        }
      }
      return [
        for (final v in videos)
          YouTubeVideo(
            id: v.id,
            title: v.title,
            channel: v.channel,
            thumbnailUrl: v.thumbnailUrl,
            duration: v.live ? null : lengths[v.id],
            live: v.live,
          ),
      ];
    } on YouTubeApiException {
      return videos;
    }
  }

  /// Checks the key with one cheap request (1 unit). Throws
  /// [YouTubeApiException] when YouTube does not accept it.
  Future<void> checkKey() => _get('videos', {'part': 'id', 'id': probeVideo});

  Future<Map<String, Object?>> _get(
    String endpoint,
    Map<String, String> query,
  ) async {
    if (!configured) {
      throw const YouTubeApiException(YouTubeApiError.badKey, 'noKey');
    }
    final uri = base.replace(
      path: '${base.path}/$endpoint',
      queryParameters: {...query, 'key': apiKey.trim()},
    );
    final http.Response response;
    try {
      response = await _client.get(uri).timeout(_timeout);
    } on TimeoutException {
      throw const YouTubeApiException(YouTubeApiError.offline);
    } on SocketException {
      throw const YouTubeApiException(YouTubeApiError.offline);
    } on http.ClientException {
      // Its message contains the URL with the key: never passed on.
      throw const YouTubeApiException(YouTubeApiError.offline);
    } on HandshakeException {
      throw const YouTubeApiException(YouTubeApiError.offline);
    }
    Object? body;
    try {
      body = jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException {
      body = null;
    }
    if (response.statusCode == 200 && body is Map<String, Object?>) {
      return body;
    }
    throw errorFor(response.statusCode, body);
  }

  /// Maps a Data API error answer to a plain kind.
  static YouTubeApiException errorFor(int status, Object? body) {
    final reasons = <String>{};
    if (body is Map && body['error'] is Map) {
      final error = body['error'] as Map;
      for (final e in (error['errors'] as List?) ?? const []) {
        if (e is Map && e['reason'] is String) {
          reasons.add(e['reason'] as String);
        }
      }
      for (final d in (error['details'] as List?) ?? const []) {
        if (d is Map && d['reason'] is String) {
          reasons.add(d['reason'] as String);
        }
      }
      if (error['status'] is String) {
        reasons.add(error['status'] as String);
      }
    }
    String? first(Iterable<String> names) {
      for (final n in names) {
        if (reasons.contains(n)) {
          return n;
        }
      }
      return null;
    }

    final quota = first(const ['quotaExceeded', 'dailyLimitExceeded']);
    if (quota != null) {
      return YouTubeApiException(YouTubeApiError.quotaExceeded, quota);
    }
    final rate = first(const ['rateLimitExceeded', 'userRateLimitExceeded']);
    if (rate != null || status == 429) {
      return YouTubeApiException(YouTubeApiError.rateLimited, rate);
    }
    final disabled = first(const ['accessNotConfigured', 'SERVICE_DISABLED']);
    if (disabled != null) {
      return YouTubeApiException(YouTubeApiError.apiDisabled, disabled);
    }
    final key = first(const [
      'keyInvalid',
      'API_KEY_INVALID',
      'keyExpired',
      'API_KEY_EXPIRED',
      'ipRefererBlocked',
      'API_KEY_HTTP_REFERRER_BLOCKED',
      'API_KEY_SERVICE_BLOCKED',
      'forbidden',
    ]);
    if (key != null || status == 401) {
      return YouTubeApiException(YouTubeApiError.badKey, key);
    }
    if (status == 400 && reasons.contains('INVALID_ARGUMENT')) {
      // "API key not valid" comes as 400 INVALID_ARGUMENT / badRequest.
      return const YouTubeApiException(YouTubeApiError.badKey, 'badRequest');
    }
    if (status >= 500) {
      return YouTubeApiException(YouTubeApiError.provider, 'HTTP $status');
    }
    return YouTubeApiException(
      YouTubeApiError.provider,
      reasons.isEmpty ? 'HTTP $status' : reasons.first,
    );
  }

  static String _text(Object? v) =>
      v is String ? _unescape(v.trim()) : '';

  /// The search returns HTML-escaped titles ("Rock &amp; Roll").
  static String _unescape(String s) => s
      .replaceAll('&amp;', '&')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>');

  static String? _thumbnail(Object? thumbnails) {
    if (thumbnails is! Map) {
      return null;
    }
    for (final size in const ['medium', 'high', 'default']) {
      final t = thumbnails[size];
      if (t is Map && t['url'] is String) {
        return t['url'] as String;
      }
    }
    return null;
  }
}

/// ISO 8601 length as the Data API sends it (`PT1H2M3S`, `P1DT2H`).
Duration? parseIsoDuration(Object? value) {
  if (value is! String) {
    return null;
  }
  final m = RegExp(
    r'^P(?:(\d+)D)?(?:T(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?)?$',
  ).firstMatch(value);
  if (m == null) {
    return null;
  }
  int n(int i) => int.tryParse(m.group(i) ?? '') ?? 0;
  return Duration(days: n(1), hours: n(2), minutes: n(3), seconds: n(4));
}
