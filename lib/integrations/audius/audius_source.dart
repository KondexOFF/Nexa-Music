import 'package:http/http.dart' as http;

import '../../core/models/track.dart';
import '../music_source.dart';

/// Audius through its official REST API (https://api.audius.co).
///
/// Search: `GET /v1/tracks/search`; playback: the API's stream endpoint
/// `GET /v1/tracks/{id}/stream`, which the audio engine opens directly.
/// Tracks the artist gated (purchase, follow, tip) or marked not
/// streamable are returned as unavailable with the reason.
class AudiusSource implements MusicSource {
  AudiusSource(this._client, {Uri? base, this.appName = defaultAppName})
    : base = base ?? Uri.parse('https://api.audius.co/v1');

  static const String defaultAppName = 'NEXA_Music';

  final http.Client _client;
  final Uri base;

  /// Identifies NEXA to Audius (the API's `app_name` parameter).
  final String appName;

  @override
  TrackSource get source => TrackSource.audius;

  @override
  bool get configured => true;

  Uri _uri(String path, [Map<String, String> query = const {}]) =>
      base.replace(
        path: '${base.path}$path',
        queryParameters: {...query, 'app_name': appName},
      );

  /// The URL the engine streams for [trackId].
  Uri streamUri(String trackId) =>
      _uri('/tracks/${Uri.encodeComponent(trackId)}/stream');

  @override
  Future<List<Track>> search(String query, {int limit = 20}) async {
    final q = query.trim();
    if (q.isEmpty) {
      return const [];
    }
    final json = await getJson(
      _client,
      _uri('/tracks/search', {'query': q, 'limit': '$limit'}),
    );
    final data = json is Map ? json['data'] : null;
    if (data is! List) {
      throw const CatalogException(CatalogErrorKind.provider, 'no data');
    }
    return [
      for (final item in data.take(limit))
        if (item is Map) ?parseTrack(item),
    ];
  }

  /// One Audius track object -> [Track] (null when unusable).
  Track? parseTrack(Map<dynamic, dynamic> j) {
    final id = jsonString(j['id']);
    final title = jsonString(j['title']);
    if (id == null || title == null) {
      return null;
    }
    final user = j['user'];
    final artist =
        (user is Map ? jsonString(user['name']) ?? jsonString(user['handle']) : null) ??
        'Audius artist';
    final artwork = j['artwork'];
    final art = artwork is Map
        ? jsonString(artwork['480x480']) ?? jsonString(artwork['150x150'])
        : null;
    final permalink = jsonString(j['permalink']);
    final seconds = jsonInt(j['duration']);

    String? problem;
    final access = j['access'];
    if (j['is_delete'] == true) {
      problem = 'Removed on Audius';
    } else if (j['is_streamable'] == false) {
      problem = 'The artist does not allow streaming';
    } else if (access is Map && access['stream'] == false) {
      problem = 'Gated by the artist (e.g. purchase or follow on Audius)';
    } else if (access is! Map && j['stream_conditions'] != null) {
      problem = 'Gated by the artist (e.g. purchase or follow on Audius)';
    }

    return Track(
      id: Track.onlineId(TrackSource.audius, id),
      source: TrackSource.audius,
      sourceTrackId: id,
      path: streamUri(id).toString(),
      title: title,
      artist: artist,
      album: 'Audius',
      genre: jsonString(j['genre']),
      duration: seconds == null || seconds <= 0
          ? null
          : Duration(seconds: seconds),
      artworkPath: art != null && art.startsWith('https://') ? art : null,
      available: problem == null,
      problem: problem,
      addedAt: DateTime.now(),
      pageUrl: permalink == null
          ? null
          : (permalink.startsWith('https://')
                ? permalink
                : 'https://audius.co$permalink'),
    );
  }
}
