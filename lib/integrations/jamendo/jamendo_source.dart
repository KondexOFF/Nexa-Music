import 'package:http/http.dart' as http;

import '../../app/strings.dart';
import '../../core/models/track.dart';
import '../music_source.dart';

/// Jamendo through its official API v3.0 (https://developer.jamendo.com).
///
/// Needs the owner's own `client_id` (free, personal, non-commercial use;
/// never stored in the repository). Results carry the Creative Commons
/// licence and the track page for attribution; tracks without a stream URL
/// are returned as unavailable. NEXA Wave (E1) uses the same `/tracks/`
/// endpoint with `fuzzytags` (liked genres), `artist_name` (liked artists)
/// or, without either, the popularity boost.
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
    return _tracks({'search': q}, limit);
  }

  @override
  Future<List<WaveCandidate>> waveCandidates(WaveRequest request) async {
    if (!configured) {
      throw const CatalogException(CatalogErrorKind.notConfigured);
    }
    final limit = request.limit.clamp(1, 50);
    final tags = <String>{
      for (final g in request.genres.take(WaveRequest.maxTerms))
        if (jamendoTag(g).isNotEmpty) jamendoTag(g),
    };
    final calls = <Future<List<WaveCandidate>> Function()>[
      if (tags.isNotEmpty)
        () => _candidates(
          // A space is sent as "+": Jamendo reads it as "any of these tags".
          {
            'fuzzytags': tags.join(' '),
            'boost': 'popularity_month',
            'groupby': 'artist_id',
          },
          limit,
          S.basisGenres(source.label),
        ),
      for (final a in request.artists.take(WaveRequest.maxTerms))
        if (a.trim().isNotEmpty)
          () => _candidates(
            {'artist_name': a.trim()},
            limit,
            S.basisArtist(source.label, a.trim()),
          ),
    ];
    if (calls.isEmpty) {
      calls.add(
        () => _candidates(
          {'boost': 'popularity_week', 'groupby': 'artist_id'},
          limit,
          S.basisPopular(source.label),
        ),
      );
    }
    final found = await collectCandidates(calls);
    return [
      for (final c in found)
        if (waveSuitable(c.track)) c,
    ];
  }

  Future<List<WaveCandidate>> _candidates(
    Map<String, String> filter,
    int limit,
    String basis,
  ) async => [
    for (final t in await _tracks(filter, limit)) WaveCandidate(t, basis),
  ];

  /// `GET /tracks/` with [filter]; also asks for the genre tags
  /// (`include=musicinfo`), so excluded genres work for Jamendo songs.
  Future<List<Track>> _tracks(Map<String, String> filter, int limit) async {
    if (!configured) {
      throw const CatalogException(CatalogErrorKind.notConfigured);
    }
    final uri = base.replace(
      path: '${base.path}/tracks/',
      queryParameters: {
        'client_id': clientId.trim(),
        'format': 'json',
        'limit': '$limit',
        ...filter,
        'audioformat': 'mp32',
        'imagesize': '300',
        'include': 'musicinfo',
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

  static const Map<String, String> _tagAliases = {
    'rb': 'rnb',
    'drumandbass': 'drumnbass',
    'drumbass': 'drumnbass',
    'dnb': 'drumnbass',
    'electronica': 'electronic',
    'lofihiphop': 'lofi',
  };

  /// Jamendo tag for a NEXA DNA genre: lower case letters and digits
  /// ("Hip-Hop" -> "hiphop", "R&B" -> "rnb").
  static String jamendoTag(String genre) {
    final key = genre.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    return _tagAliases[key] ?? key;
  }

  /// Genre tags of a track object (`musicinfo.tags.genres`), if present.
  static String? genresOf(Map<dynamic, dynamic> j) {
    final info = j['musicinfo'];
    final tags = info is Map ? info['tags'] : null;
    final genres = tags is Map ? tags['genres'] : null;
    if (genres is! List) {
      return null;
    }
    final names = [
      for (final g in genres)
        if (jsonString(g) != null) jsonString(g)!,
    ];
    return names.isEmpty ? null : names.join('; ');
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
      genre: genresOf(j),
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
