import 'package:http/http.dart' as http;

import '../../app/strings.dart';
import '../../core/models/listening.dart' show tasteKey;
import '../../core/models/track.dart';
import '../music_source.dart';

/// Audius through its official REST API (https://api.audius.co).
///
/// Search: `GET /v1/tracks/search`; playback: the API's stream endpoint
/// `GET /v1/tracks/{id}/stream`, which the audio engine opens directly.
/// NEXA Wave (E1): `GET /v1/tracks/trending` (optionally by genre) and the
/// search for a liked artist's own songs.
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
    return _tracksOf(json, limit);
  }

  /// Audius' fixed genre list (the values its `genre` field and the
  /// trending `genre` filter use).
  static const List<String> genres = [
    'Electronic', 'Rock', 'Metal', 'Alternative', 'Hip-Hop/Rap',
    'Experimental', 'Punk', 'Folk', 'Pop', 'Ambient', 'Soundtrack', 'World',
    'Jazz', 'Acoustic', 'Funk', 'R&B/Soul', 'Devotional', 'Classical',
    'Reggae', 'Country', 'Blues', 'Latin', 'Lo-Fi', 'Hyperpop', 'Dancehall',
    'Techno', 'Trap', 'House', 'Tech House', 'Deep House', 'Disco',
    'Electro', 'Jungle', 'Progressive House', 'Hardstyle', 'Glitch Hop',
    'Trance', 'Future Bass', 'Future House', 'Tropical House', 'Downtempo',
    'Drum & Bass', 'Dubstep', 'Jersey Club', 'Vaporwave', 'Moombahton',
  ];

  static const Map<String, String> _genreAliases = {
    'hiphop': 'Hip-Hop/Rap',
    'rap': 'Hip-Hop/Rap',
    'rnb': 'R&B/Soul',
    'rb': 'R&B/Soul',
    'soul': 'R&B/Soul',
    'drumandbass': 'Drum & Bass',
    'drumnbass': 'Drum & Bass',
    'dnb': 'Drum & Bass',
    'lofi': 'Lo-Fi',
    'lofihiphop': 'Lo-Fi',
  };

  static String _norm(String s) =>
      s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

  /// The Audius genre for a NEXA DNA genre; null when Audius has none
  /// (then that genre is simply not asked for - no guessed matches).
  static String? audiusGenre(String genre) {
    final key = _norm(genre);
    if (key.isEmpty) {
      return null;
    }
    for (final g in genres) {
      if (_norm(g) == key) {
        return g;
      }
    }
    return _genreAliases[key];
  }

  @override
  Future<List<WaveCandidate>> waveCandidates(WaveRequest request) async {
    final limit = request.limit.clamp(1, 50);
    final asked = <String>{
      for (final g in request.genres.take(WaveRequest.maxTerms))
        ?audiusGenre(g),
    };
    final calls = <Future<List<WaveCandidate>> Function()>[
      for (final g in asked)
        () => _trending(
          {'genre': g, 'time': 'month'},
          limit,
          S.basisGenre(source.label, g),
        ),
      for (final a in request.artists.take(WaveRequest.maxTerms))
        () => _byArtist(a, limit),
    ];
    if (calls.isEmpty) {
      calls.add(
        () => _trending({'time': 'week'}, limit, S.basisPopular(source.label)),
      );
    }
    final found = await collectCandidates(calls);
    return [
      for (final c in found)
        if (waveSuitable(c.track)) c,
    ];
  }

  Future<List<WaveCandidate>> _trending(
    Map<String, String> filter,
    int limit,
    String basis,
  ) async {
    final json = await getJson(
      _client,
      _uri('/tracks/trending', {...filter, 'limit': '$limit'}),
    );
    return [
      for (final t in _tracksOf(json, limit)) WaveCandidate(t, basis),
    ];
  }

  /// Songs whose Audius artist is exactly the liked artist (a search for
  /// the name also finds other artists - those are left out).
  Future<List<WaveCandidate>> _byArtist(String artist, int limit) async {
    final name = artist.trim();
    if (name.isEmpty) {
      return const [];
    }
    final json = await getJson(
      _client,
      _uri('/tracks/search', {'query': name, 'limit': '$limit'}),
    );
    final key = tasteKey(name);
    return [
      for (final t in _tracksOf(json, limit))
        if (tasteKey(t.artist) == key)
          WaveCandidate(t, S.basisArtist(source.label, t.artist)),
    ];
  }

  List<Track> _tracksOf(Object? json, int limit) {
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
