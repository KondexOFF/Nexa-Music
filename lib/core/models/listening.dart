import 'package:flutter/foundation.dart';

/// Where playback was started from (stored with each listening event).
enum PlayContext {
  library,
  wave,

  /// A YouTube video in YouTube's own player (E2.7b, opt-in). Never used by
  /// NEXA Wave or NEXA DNA.
  youtube,
}

/// How a listening ended.
enum EndReason {
  /// Played to the end (also when the next track followed by gapless or
  /// crossfade).
  completed,

  /// The user moved on to another track.
  skipped,

  /// Playback was stopped.
  stopped,
}

/// One listening of a track (Master Plan v1.0, section 3). Recorded only
/// with the user's consent.
@immutable
class ListeningEvent {
  const ListeningEvent({
    required this.trackId,
    required this.startedAt,
    required this.listened,
    required this.reason,
    required this.context,
    this.duration,
  });

  final int trackId;
  final DateTime startedAt;

  /// How far the track was played when it ended.
  final Duration listened;
  final Duration? duration;
  final EndReason reason;
  final PlayContext context;
}

/// Kind of an explicit NEXA DNA choice.
enum TasteKind { genre, artist }

/// An explicit NEXA DNA choice: a liked or excluded genre / artist.
@immutable
class TasteChoice {
  const TasteChoice({
    required this.kind,
    required this.value,
    this.excluded = false,
    this.weight = 1,
  });

  final TasteKind kind;
  final String value;

  /// True: never suggest tracks with this genre / artist.
  final bool excluded;
  final double weight;

  String get key => tasteKey(value);
}

/// Normalised form used to compare genres and artists.
String tasteKey(String value) => value.trim().toLowerCase();

/// Genres of a track. Tags often hold several ("Rock; Indie", "Pop/Rock").
List<String> genreTokens(String? genre) {
  if (genre == null) {
    return const [];
  }
  return [
    for (final part in genre.split(RegExp(r'[;,/|\\]')))
      if (part.trim().isNotEmpty) part.trim(),
  ];
}
