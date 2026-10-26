import 'package:flutter_test/flutter_test.dart';
import 'package:nexa_music/integrations/youtube/youtube_link.dart';

/// E2.2: a pasted YouTube link plays without a Data API key.
void main() {
  test('the usual forms of one video link give its id', () {
    const id = 'M7lc1UVf-VE';
    for (final link in [
      id,
      'https://www.youtube.com/watch?v=$id',
      'https://youtube.com/watch?v=$id&t=42s&list=PL123',
      'http://m.youtube.com/watch?feature=share&v=$id',
      'www.youtube.com/watch?v=$id',
      'https://youtu.be/$id',
      'https://youtu.be/$id?si=abc',
      'https://www.youtube.com/shorts/$id',
      'https://www.youtube.com/embed/$id',
      'https://www.youtube.com/live/$id',
      'https://music.youtube.com/watch?v=$id',
      'https://www.youtube-nocookie.com/embed/$id',
      '  https://youtu.be/$id  ',
    ]) {
      expect(youtubeVideoId(link), id, reason: link);
    }
  });

  test('anything else is refused', () {
    for (final text in [
      '',
      'hello',
      'M7lc1UVf-V', // 10 characters
      'https://www.youtube.com/watch?v=short',
      'https://www.youtube.com/playlist?list=PL123',
      'https://www.youtube.com/@channel',
      'https://evil.example/watch?v=M7lc1UVf-VE',
      'https://youtube.com.evil.example/watch?v=M7lc1UVf-VE',
      'ftp://youtu.be/M7lc1UVf-VE',
      'javascript:alert(1)',
    ]) {
      expect(youtubeVideoId(text), isNull, reason: text);
    }
  });

  test('watch URL for "Open on YouTube"', () {
    expect(
      youtubeWatchUrl('M7lc1UVf-VE'),
      'https://www.youtube.com/watch?v=M7lc1UVf-VE',
    );
  });
}
