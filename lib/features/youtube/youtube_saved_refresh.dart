import '../../app/strings.dart';
import '../../integrations/youtube/youtube_oembed.dart';
import '../library/library_repository.dart';

/// Saved YouTube videos: data from YouTube older than [refreshAfter] is
/// fetched again; when that fails and the data is older than [keepAtMost]
/// (30 days, Developer Policies III.E.4.c), YouTube's title, channel and
/// thumbnail are removed - the video id, link and the user's own name stay.
/// A removed or private video is marked unavailable. Returns how many
/// entries were checked.
Future<int> refreshSavedYouTube(
  LibraryRepository repo,
  YouTubeOEmbed oembed, {
  Duration refreshAfter = const Duration(days: 25),
  Duration keepAtMost = const Duration(days: 30),
  DateTime Function() now = DateTime.now,
}) async {
  await repo.pruneOrphanYouTube();
  final rows = await repo.staleYouTube(refreshAfter);
  for (final row in rows) {
    final videoId = row.pathKey.substring(row.pathKey.indexOf(':') + 1);
    final result = await oembed.fetch(videoId);
    switch (result) {
      case OEmbedFound(:final title, :final channel, :final thumbnail):
        await repo.refreshYouTube(
          row.id,
          title: title.isEmpty ? youtubeUnnamed : title,
          channel: channel,
          thumbnail: thumbnail,
          available: true,
        );
      case OEmbedGone():
        await repo.refreshYouTube(
          row.id,
          available: false,
          problem: S.ytVideoGone,
        );
      case OEmbedFailed():
        final fetched = row.metaFetchedAt;
        if (fetched == null || now().difference(fetched) > keepAtMost) {
          await repo.refreshYouTube(
            row.id,
            available: row.available,
            problem: row.problem,
          );
        }
    }
  }
  return rows.length;
}
