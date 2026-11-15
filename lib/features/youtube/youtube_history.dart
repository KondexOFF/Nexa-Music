import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/listening.dart';
import '../../integrations/youtube/youtube_link.dart';
import '../library/library_providers.dart';
import '../nexa_dna/dna_providers.dart';
import 'youtube_settings.dart';
import 'youtube_track.dart';

/// Why a watched YouTube video was (not) written to the history.
enum YtHistoryOutcome {
  recorded,

  /// History or the YouTube history switch is off (or a private session).
  off,

  /// Watched for less than [YouTubeHistoryRecorder.minListen].
  tooShort,

  /// No API key: the made-for-kids status cannot be checked.
  noKey,

  /// Made for kids: never recorded (Developer Policies III.E.4.j).
  madeForKids,

  /// The status could not be read (offline, quota, removed video).
  unknown,
}

/// Local YouTube history (E2.7b): a watched video is written only when the
/// user switched it on, history is allowed, and YouTube says the video is
/// not made for kids (`videos.list part=status`, 1 quota unit; the answer
/// is kept for the session). Without a key nothing is written. The entry
/// is a saved YouTube bookmark (video id, link, title, channel) whose data
/// is refreshed or removed within 30 days like every saved video.
class YouTubeHistoryRecorder {
  YouTubeHistoryRecorder(this._ref);

  final Ref _ref;
  final Map<String, bool> _kids = {};

  static const Duration minListen = Duration(seconds: 10);

  Future<YtHistoryOutcome> record({
    required String videoId,
    required DateTime startedAt,
    required Duration listened,
    required EndReason reason,
    Duration? duration,
    String? title,
    String? channel,
  }) async {
    if (listened < minListen) {
      return YtHistoryOutcome.tooShort;
    }
    if (!_ref.read(dnaSettingsProvider).recordsYouTube) {
      return YtHistoryOutcome.off;
    }
    final api = _ref.read(youtubeDataApiProvider);
    if (!api.configured) {
      return YtHistoryOutcome.noKey;
    }
    var kids = _kids[videoId];
    if (kids == null) {
      try {
        kids = (await api.madeForKids([videoId]))[videoId];
      } on Object {
        kids = null;
      }
      if (kids != null) {
        _kids[videoId] = kids;
      }
    }
    if (kids == true) {
      return YtHistoryOutcome.madeForKids;
    }
    if (kids == null) {
      return YtHistoryOutcome.unknown;
    }
    try {
      final id = await _ref
          .read(libraryRepositoryProvider)
          .save(
            youtubeTrack(
              videoId: videoId,
              title: title,
              channel: channel,
              thumbnail: youtubeThumbnailUrl(videoId),
            ),
          );
      await _ref
          .read(tasteRepositoryProvider)
          .recordEvent(
            ListeningEvent(
              trackId: id,
              startedAt: startedAt,
              listened: listened,
              duration: duration,
              reason: reason,
              context: PlayContext.youtube,
            ),
          );
    } on Object {
      return YtHistoryOutcome.unknown; // History is optional.
    }
    return YtHistoryOutcome.recorded;
  }
}

final youtubeHistoryProvider = Provider<YouTubeHistoryRecorder>(
  YouTubeHistoryRecorder.new,
);
