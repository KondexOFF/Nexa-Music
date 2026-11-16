import 'package:flutter/foundation.dart';

/// Where a track comes from (Phase 6: official catalog APIs).
enum TrackSource {
  local('Library'),
  audius('Audius'),
  jamendo('Jamendo'),

  /// A YouTube video saved by the user (E2.7: a bookmark - video id, link,
  /// a name; never downloaded). Played only in YouTube's own visible
  /// player, never by NEXA's PlaybackEngine.
  youtube('YouTube'),

  /// A SoundCloud track (E3, CR-002): its link in SoundCloud's official
  /// widget - never streamed, mixed or cached by NEXA.
  soundcloud('SoundCloud');

  const TrackSource(this.label);

  /// Name shown to the user (attribution).
  final String label;

  bool get isOnline => this != TrackSource.local;

  /// Played in the source's own visible player (YouTube, SoundCloud), not
  /// by NEXA's engine.
  bool get isExternal =>
      this == TrackSource.youtube || this == TrackSource.soundcloud;

  static TrackSource parse(String name) =>
      TrackSource.values.asNameMap()[name] ?? TrackSource.local;
}

/// What NEXA may do with a track's audio. Local files the user owns may be
/// played, mixed (crossfade) and analysed. Catalog tracks may only be
/// streamed: there is no explicit right to process their audio, so the Mix
/// Engine never overlaps them (D-017).
@immutable
class PlaybackRights {
  const PlaybackRights({required this.play, required this.mix});

  final bool play;
  final bool mix;

  static const PlaybackRights localFile = PlaybackRights(play: true, mix: true);
  static const PlaybackRights streamOnly = PlaybackRights(play: true, mix: false);

  /// Audius / Jamendo catalog streams (D-025, 2026-11-15): played and
  /// crossfaded like local files - a volume fade while playing, nothing is
  /// stored or redistributed. Neither the Jamendo API Terms of Use nor the
  /// Audius Open Music License (2 July 2025) restricts it.
  static const PlaybackRights catalogStream = PlaybackRights(play: true, mix: true);

  /// YouTube and SoundCloud: only their own visible players play them;
  /// NEXA's engine never loads, mixes or analyses them.
  static const PlaybackRights externalPlayer = PlaybackRights(play: false, mix: false);
}

/// A track in the NEXA library (Master Plan v1.0, section 3).
@immutable
class Track {
  const Track({
    required this.id,
    required this.source,
    required this.sourceTrackId,
    required this.path,
    required this.title,
    required this.artist,
    required this.album,
    this.albumArtist,
    this.genre,
    this.year,
    this.trackNumber,
    this.discNumber,
    this.duration,
    this.artworkPath,
    this.favorite = false,
    this.disliked = false,
    this.available = true,
    this.problem,
    required this.addedAt,
    this.pageUrl,
    this.license,
    this.licenseUrl,
  });

  final int id;
  final TrackSource source;

  /// Stable id inside the source; for local files the normalised path.
  final String sourceTrackId;

  /// Absolute file path as found on disk.
  final String path;
  final String title;
  final String artist;
  final String album;
  final String? albumArtist;
  final String? genre;
  final int? year;
  final int? trackNumber;
  final int? discNumber;
  final Duration? duration;

  /// Cached cover image (inside the app data folder), if any. For catalog
  /// tracks: the artwork URL from the provider.
  final String? artworkPath;
  final bool favorite;

  /// Explicit dislike (NEXA DNA): never suggested by NEXA Wave.
  final bool disliked;

  /// False when the file is missing or unreadable.
  final bool available;

  /// Human readable reason when [available] is false.
  final String? problem;
  final DateTime addedAt;

  /// Catalog tracks: the track page at the provider (attribution backlink).
  final String? pageUrl;

  /// Catalog tracks: licence name (e.g. a Creative Commons licence) and link.
  final String? license;
  final String? licenseUrl;

  bool get isOnline => source.isOnline;

  PlaybackRights get rights => switch (source) {
    TrackSource.local => PlaybackRights.localFile,
    TrackSource.audius || TrackSource.jamendo => PlaybackRights.catalogStream,
    TrackSource.youtube ||
    TrackSource.soundcloud => PlaybackRights.externalPlayer,
  };

  /// Key of a saved catalog / YouTube entry in the database (tracks.path_key).
  String get savedKey => '${source.name}:$sourceTrackId';

  /// Format label: file extension for local files, "STREAM" for catalogs.
  String get fileExtension {
    if (source == TrackSource.youtube) {
      return 'VIDEO';
    }
    if (source.isExternal) {
      return 'WIDGET';
    }
    if (isOnline) {
      return 'STREAM';
    }
    final dot = path.lastIndexOf('.');
    return dot < 0 ? '' : path.substring(dot + 1).toUpperCase();
  }

  /// Stable negative id for catalog tracks (never clashes with library ids,
  /// which are positive database ids).
  static int onlineId(TrackSource source, String sourceTrackId) {
    var h = 0x811c9dc5;
    for (final c in '${source.name}:$sourceTrackId'.codeUnits) {
      h = ((h ^ c) * 0x01000193) & 0x3fffffff;
    }
    return -(h + 1);
  }
}
