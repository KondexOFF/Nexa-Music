import '../../core/models/track.dart';
import '../../integrations/youtube/youtube_link.dart';
import '../library/library_repository.dart' show youtubeUnnamed;

/// A YouTube video as a [Track] entry (E2.7): a bookmark with the video id,
/// its link, title, channel and thumbnail link - never audio. Saved only
/// when the user likes it or adds it to a playlist; the data from YouTube
/// is refreshed (or removed) within 30 days (Developer Policies III.E.4).
/// The length is not kept: oEmbed, which refreshes the data, has none.
Track youtubeTrack({
  required String videoId,
  String? title,
  String? channel,
  String? thumbnail,
}) {
  final url = youtubeWatchUrl(videoId);
  final name = (title ?? '').trim();
  return Track(
    id: Track.onlineId(TrackSource.youtube, videoId),
    source: TrackSource.youtube,
    sourceTrackId: videoId,
    path: url,
    title: name.isEmpty ? youtubeUnnamed : name,
    artist: channel ?? '',
    album: TrackSource.youtube.label,
    artworkPath: thumbnail,
    addedAt: DateTime.now(),
    pageUrl: url,
  );
}
