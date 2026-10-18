import 'package:flutter/foundation.dart';

/// Where a track comes from. Only local files exist before Phase 6.
enum TrackSource { local }

/// What NEXA may do with a track's audio. Local files the user owns may be
/// played, mixed (crossfade) and analysed; online sources (Phase 6) will set
/// this per provider terms.
@immutable
class PlaybackRights {
  const PlaybackRights({required this.play, required this.mix});

  final bool play;
  final bool mix;

  static const PlaybackRights localFile = PlaybackRights(play: true, mix: true);
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
    this.available = true,
    this.problem,
    required this.addedAt,
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

  /// Cached cover image (inside the app data folder), if any.
  final String? artworkPath;
  final bool favorite;

  /// False when the file is missing or unreadable.
  final bool available;

  /// Human readable reason when [available] is false.
  final String? problem;
  final DateTime addedAt;

  PlaybackRights get rights => switch (source) {
    TrackSource.local => PlaybackRights.localFile,
  };

  String get fileExtension {
    final dot = path.lastIndexOf('.');
    return dot < 0 ? '' : path.substring(dot + 1).toUpperCase();
  }
}
