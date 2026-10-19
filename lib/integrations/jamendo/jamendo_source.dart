import 'package:http/http.dart' as http;

import '../../core/models/track.dart';
import '../music_source.dart';

/// Jamendo through its official API v3.0 (https://developer.jamendo.com).
///
/// Needs the owner's own `client_id` (free, personal, non-commercial use;
/// never stored in the repository). Results carry the Creative Commons
/// licence and the track page for attribution; tracks without a stream URL
/// are returned as unavailable.
class JamendoSource implements MusicSource {
  JamendoSource(this._client, {required this.clientId, Uri? base})
    : base = base ?? Uri.parse('https://api.jamendo.com/v3.0');

  final http.Client _client;
  final String clientId;
  final Uri base;

  @override
  TrackSource get source => TrackSource.jamendo;

  @override
  bool get configured => clientId.trim().isNotEmpty;

  @override
  Future<List<Track>> search(String query, {int limit = 20}) async {
    final q = query.trim();
    if (q.isEmpty) {
      return const [];
    }
    if (!configured) {
      throw const CatalogException(CatalogErrorKind.notConfigured);
    }
    final uri = base.replace(
      path: '${base.path}/tracks/',
      queryParameters: {
        'client_id': clientId.trim(),
        'format': 'json',
        'limit': '$limit',
        'search': q,
        'audioformat': 'mp32',
        'imagesize': '300',
      },
    );
    final json = await getJson(_client, uri);
    if (json is! Map) {
      throw const CatalogException(CatalogErrorKind.provider, 'no data');
    }
    final headers = json['headers'];
    if (headers is Map && headers['status'] != 'success') {
      final message = jsonString(headers['error_message']);
      final code = jsonInt(headers['code']);
      // Jamendo reports a wrong / unknown client id as an API error.
      final keyProblem =
          message != null && message.toLowerCase().contains('client');
      throw CatalogException(
        keyProblem
            ? CatalogErrorKind.notConfigured
            : CatalogErrorKind.provider,
        message ?? 'code $code',
      );
    }
    final results = json['results'];
    if (results is! List) {
      throw const CatalogException(CatalogErrorKind.provider, 'no results');
    }
    return [
      for (final item in results.take(limit))
        if (item is Map) ?parseTrack(item),
    ];
  }

  /// One Jamendo track object -> [Track] (null when unusable).
  Track? parseTrack(Map<dynamic, dynamic> j) {
    final id = jsonString('${j['id'] ?? ''}');
    final title = jsonString(j['name']);
    if (id == null || title == null) {
      return null;
    }
    final audio = jsonString(j['audio']);
    final seconds = jsonInt(j['duration']);
    final image = jsonString(j['image']) ?? jsonString(j['album_image']);
    final licenseUrl = jsonString(j['license_ccurl']);
    final scheme = audio == null ? null : Uri.tryParse(audio)?.scheme;
    final playable = scheme == 'https' || scheme == 'http';
    return Track(
      id: Track.onlineId(TrackSource.jamendo, id),
      source: TrackSource.jamendo,
      sourceTrackId: id,
      path: playable ? audio! : '',
      title: title,
      artist: jsonString(j['artist_name']) ?? 'Jamendo artist',
      album: jsonString(j['album_name']) ?? 'Jamendo',
      duration: seconds == null || seconds <= 0
          ? null
          : Duration(seconds: seconds),
      artworkPath: image != null && image.startsWith('https://') ? image : null,
      available: playable,
      problem: playable ? null : 'Jamendo offers no stream for this track',
      addedAt: DateTime.now(),
      pageUrl: jsonString(j['shareurl']) ?? jsonString(j['shorturl']),
      license: licenseUrl == null ? null : creativeCommonsLabel(licenseUrl),
      licenseUrl: licenseUrl,
    );
  }

  /// "https://creativecommons.org/licenses/by-nc-sa/3.0/" -> "CC BY-NC-SA 3.0".
  static String creativeCommonsLabel(String url) {
    final m = RegExp(
      r'creativecommons\.org/licenses/([a-z-]+)/([0-9.]+)',
    ).firstMatch(url);
    if (m == null) {
      return 'Licence';
    }
    return 'CC ${m.group(1)!.toUpperCase()} ${m.group(2)}';
  }
}
