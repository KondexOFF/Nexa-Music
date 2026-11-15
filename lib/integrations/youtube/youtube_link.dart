/// YouTube links pasted by the user (E2.2; works without a Data API key).
///
/// Accepts the usual forms of a single public video link and returns its
/// 11-character video id, or null when the text is not such a link.
library;

final RegExp _videoId = RegExp(r'^[A-Za-z0-9_-]{11}$');

/// Video id of a YouTube link (watch, youtu.be, shorts, embed, live,
/// music.youtube.com), or of a bare 11-character id; null otherwise.
String? youtubeVideoId(String input) {
  final text = input.trim();
  if (text.isEmpty) {
    return null;
  }
  if (_videoId.hasMatch(text)) {
    return text;
  }
  var uri = Uri.tryParse(text);
  if (uri == null) {
    return null;
  }
  if (!uri.hasScheme) {
    uri = Uri.tryParse('https://$text');
    if (uri == null) {
      return null;
    }
  }
  if (uri.scheme != 'https' && uri.scheme != 'http') {
    return null;
  }
  final host = uri.host.toLowerCase();
  String? id;
  if (host == 'youtu.be') {
    id = uri.pathSegments.isEmpty ? null : uri.pathSegments.first;
  } else if (host == 'youtube.com' ||
      host.endsWith('.youtube.com') ||
      host == 'youtube-nocookie.com' ||
      host.endsWith('.youtube-nocookie.com')) {
    final segments = uri.pathSegments;
    if (segments.isNotEmpty && segments.first == 'watch') {
      id = uri.queryParameters['v'];
    } else if (segments.length >= 2 &&
        const {'shorts', 'embed', 'live', 'v'}.contains(segments.first)) {
      id = segments[1];
    }
  }
  return id != null && _videoId.hasMatch(id) ? id : null;
}

/// The public YouTube page of [videoId] (for "Open on YouTube").
String youtubeWatchUrl(String videoId) =>
    'https://www.youtube.com/watch?v=${Uri.encodeComponent(videoId)}';

/// YouTube's own thumbnail of [videoId] (shown, never stored as an image).
String youtubeThumbnailUrl(String videoId) =>
    'https://i.ytimg.com/vi/$videoId/hqdefault.jpg';
