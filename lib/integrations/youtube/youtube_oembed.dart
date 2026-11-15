import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'youtube_link.dart';

/// What YouTube's public oEmbed endpoint says about a video.
sealed class OEmbedResult {
  const OEmbedResult();
}

/// The video exists: its current title, channel and thumbnail.
class OEmbedFound extends OEmbedResult {
  const OEmbedFound({required this.title, required this.channel, this.thumbnail});

  final String title;
  final String channel;
  final String? thumbnail;
}

/// Removed, private or not embeddable any more (HTTP 400 / 401 / 403 / 404).
class OEmbedGone extends OEmbedResult {
  const OEmbedGone();
}

/// No answer (offline, timeout, server error): try again later.
class OEmbedFailed extends OEmbedResult {
  const OEmbedFailed();
}

/// YouTube's oEmbed endpoint (no API key, no quota): refreshes the title,
/// channel and thumbnail of saved videos (Developer Policies III.E.4: API
/// data is refreshed or deleted within 30 days).
class YouTubeOEmbed {
  YouTubeOEmbed(this._client, {Uri? base})
    : base = base ?? Uri.parse('https://www.youtube.com/oembed');

  final http.Client _client;
  final Uri base;

  static const Duration _timeout = Duration(seconds: 15);

  Future<OEmbedResult> fetch(String videoId) async {
    final uri = base.replace(
      queryParameters: {'url': youtubeWatchUrl(videoId), 'format': 'json'},
    );
    final http.Response response;
    try {
      response = await _client.get(uri).timeout(_timeout);
    } on Object {
      return const OEmbedFailed();
    }
    if (const {400, 401, 403, 404}.contains(response.statusCode)) {
      return const OEmbedGone();
    }
    if (response.statusCode != 200) {
      return const OEmbedFailed();
    }
    try {
      final body = jsonDecode(utf8.decode(response.bodyBytes));
      if (body is! Map<String, Object?>) {
        return const OEmbedFailed();
      }
      final title = body['title'];
      final channel = body['author_name'];
      final thumb = body['thumbnail_url'];
      return OEmbedFound(
        title: title is String ? title : '',
        channel: channel is String ? channel : '',
        thumbnail: thumb is String && thumb.startsWith('https://') ? thumb : null,
      );
    } on FormatException {
      return const OEmbedFailed();
    }
  }
}
