import 'dart:convert';

import '../../core/models/track.dart';

/// The play queue kept between starts (E2.8): entries of every source and
/// the position in it. Library songs are kept by their database id (read
/// again at start, so renamed or removed files are current); catalog songs
/// and YouTube videos with their own data. YouTube's title, channel and
/// thumbnail are dropped from a queue older than 30 days (Developer
/// Policies III.E.4.c) - the video id and link stay.
class QueueSnapshot {
  const QueueSnapshot({
    required this.tracks,
    required this.cursor,
    required this.savedAt,
  });

  final List<Track> tracks;
  final int cursor;
  final DateTime savedAt;

  /// At most this many entries are kept.
  static const int limit = 500;
  static const Duration youtubeDataAge = Duration(days: 30);

  String encode() => jsonEncode({
    'v': 1,
    'savedAt': savedAt.toIso8601String(),
    'cursor': cursor,
    'tracks': [for (final t in tracks.take(limit)) _encode(t)],
  });

  static Map<String, Object?> _encode(Track t) => t.source == TrackSource.local
      ? {'s': t.source.name, 'id': t.id}
      : {
          's': t.source.name,
          'sid': t.sourceTrackId,
          'path': t.path,
          'title': t.title,
          'artist': t.artist,
          'album': t.album,
          'ms': t.duration?.inMilliseconds,
          'art': t.artworkPath,
          'page': t.pageUrl,
          'lic': t.license,
          'licUrl': t.licenseUrl,
        };

  /// Decodes a snapshot; library songs are looked up with [libraryTrack]
  /// (missing ones are left out). Null for anything unreadable.
  static Future<QueueSnapshot?> decode(
    String? text,
    Future<Track?> Function(int id) libraryTrack, {
    DateTime? now,
  }) async {
    if (text == null || text.isEmpty) {
      return null;
    }
    try {
      final data = jsonDecode(text);
      if (data is! Map<String, Object?> || data['v'] != 1) {
        return null;
      }
      final savedAt = DateTime.parse('${data['savedAt']}');
      final stale =
          (now ?? DateTime.now()).difference(savedAt) > youtubeDataAge;
      final raw = data['tracks'];
      var cursor = (data['cursor'] as num?)?.toInt() ?? -1;
      final tracks = <Track>[];
      if (raw is List) {
        for (var i = 0; i < raw.length && tracks.length < limit; i++) {
          final item = raw[i];
          final t = item is Map<String, Object?>
              ? await _decode(item, libraryTrack, stale)
              : null;
          if (t == null) {
            if (i < cursor) {
              cursor--;
            } else if (i == cursor) {
              cursor = -1;
            }
            continue;
          }
          tracks.add(t);
        }
      }
      if (cursor >= tracks.length) {
        cursor = tracks.isEmpty ? -1 : 0;
      }
      return QueueSnapshot(tracks: tracks, cursor: cursor, savedAt: savedAt);
    } on Object {
      return null;
    }
  }

  static Future<Track?> _decode(
    Map<String, Object?> m,
    Future<Track?> Function(int id) libraryTrack,
    bool stale,
  ) async {
    final source = TrackSource.values.asNameMap()['${m['s']}'];
    if (source == null) {
      return null;
    }
    if (source == TrackSource.local) {
      final id = m['id'];
      return id is int ? libraryTrack(id) : null;
    }
    final sid = m['sid'];
    final path = m['path'];
    if (sid is! String || path is! String) {
      return null;
    }
    final dropYouTubeData = stale && source == TrackSource.youtube;
    String text(String key) => m[key] is String ? m[key]! as String : '';
    String? optional(String key) => m[key] is String ? m[key]! as String : null;
    final ms = m['ms'];
    return Track(
      id: Track.onlineId(source, sid),
      source: source,
      sourceTrackId: sid,
      path: path,
      title: dropYouTubeData || text('title').isEmpty
          ? (source == TrackSource.youtube ? 'YouTube video' : sid)
          : text('title'),
      artist: dropYouTubeData ? '' : text('artist'),
      album: text('album'),
      duration: ms is int ? Duration(milliseconds: ms) : null,
      artworkPath: dropYouTubeData ? null : optional('art'),
      addedAt: DateTime.now(),
      pageUrl: optional('page'),
      license: optional('lic'),
      licenseUrl: optional('licUrl'),
    );
  }
}
