import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// What a pasted SoundCloud link is.
sealed class SoundCloudLink {
  const SoundCloudLink();

  /// Parses a pasted link. Only single tracks play in this version (one
  /// queue entry = one sound); sets, profiles and short links are named so
  /// the user knows what to paste instead.
  static SoundCloudLink parse(String input) {
    final text = input.trim();
    final uri = Uri.tryParse(text.contains('://') ? text : 'https://$text');
    if (uri == null || uri.host.isEmpty) {
      return const SoundCloudNotALink();
    }
    final host = uri.host.toLowerCase();
    if (host == 'on.soundcloud.com' || host == 'snd.sc') {
      return const SoundCloudShortLink();
    }
    if (host != 'soundcloud.com' &&
        host != 'www.soundcloud.com' &&
        host != 'm.soundcloud.com') {
      return const SoundCloudNotALink();
    }
    final parts = [
      for (final s in uri.pathSegments)
        if (s.isNotEmpty) s,
    ];
    const reserved = {
      'discover', 'search', 'you', 'stream', 'upload', 'charts', 'pages',
      'terms-of-use', 'settings', 'messages', 'notifications', 'feed',
    };
    if (parts.isEmpty || reserved.contains(parts.first.toLowerCase())) {
      return const SoundCloudNotALink();
    }
    if (parts.length >= 2 && parts[1] == 'sets') {
      return const SoundCloudSet();
    }
    if (parts.length < 2 ||
        const {
          'tracks', 'albums', 'popular-tracks', 'reposts', 'likes',
          'following', 'followers', 'comments', 'sets',
        }.contains(parts[1].toLowerCase())) {
      return const SoundCloudProfile();
    }
    // A private track link has a secret token as its third part.
    final path = parts.length >= 3 && parts[2].startsWith('s-')
        ? '${parts[0]}/${parts[1]}/${parts[2]}'
        : '${parts[0]}/${parts[1]}';
    return SoundCloudTrackLink('https://soundcloud.com/$path');
  }
}

/// A track: its canonical link (`https://soundcloud.com/<user>/<track>`).
class SoundCloudTrackLink extends SoundCloudLink {
  const SoundCloudTrackLink(this.url);

  final String url;
}

class SoundCloudSet extends SoundCloudLink {
  const SoundCloudSet();
}

class SoundCloudProfile extends SoundCloudLink {
  const SoundCloudProfile();
}

class SoundCloudShortLink extends SoundCloudLink {
  const SoundCloudShortLink();
}

class SoundCloudNotALink extends SoundCloudLink {
  const SoundCloudNotALink();
}

/// Title, uploader and artwork of a SoundCloud link from SoundCloud's
/// public oEmbed endpoint (no account, no key). Null when unknown.
class SoundCloudOEmbed {
  SoundCloudOEmbed(this._client, {Uri? base})
    : base = base ?? Uri.parse('https://soundcloud.com/oembed');

  final http.Client _client;
  final Uri base;

  Future<({String title, String author, String? thumbnail})?> fetch(
    String url,
  ) async {
    try {
      final response = await _client
          .get(base.replace(queryParameters: {'url': url, 'format': 'json'}))
          .timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) {
        return null;
      }
      final body = jsonDecode(utf8.decode(response.bodyBytes));
      if (body is! Map<String, Object?>) {
        return null;
      }
      var title = body['title'] is String ? body['title']! as String : '';
      final author = body['author_name'] is String
          ? body['author_name']! as String
          : '';
      // oEmbed titles read "<track> by <uploader>".
      final suffix = ' by $author';
      if (author.isNotEmpty && title.endsWith(suffix)) {
        title = title.substring(0, title.length - suffix.length);
      }
      final thumb = body['thumbnail_url'];
      return (
        title: title,
        author: author,
        thumbnail: thumb is String && thumb.startsWith('https://')
            ? thumb
            : null,
      );
    } on Object {
      return null;
    }
  }
}
