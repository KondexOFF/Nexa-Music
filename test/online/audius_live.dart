// Live check of the Audius adapter against the real API (network needed).
// Not part of `flutter test` (no _test.dart suffix); run explicitly:
//   flutter test test/online/audius_live.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:nexa_music/integrations/audius/audius_source.dart';

void main() {
  test('Audius: search returns streamable tracks and the stream answers',
      () async {
    final client = http.Client();
    addTearDown(client.close);
    final source = AudiusSource(client);
    final tracks = await source.search('lofi', limit: 10);
    final playable = tracks.where((t) => t.available).toList();
    // ignore: avoid_print
    print('LIVE audius: ${tracks.length} results, ${playable.length} playable');
    for (final t in tracks.take(3)) {
      // ignore: avoid_print
      print('LIVE audius track: available=${t.available} '
          'problem=${t.problem} page=${t.pageUrl != null}');
    }
    expect(tracks, isNotEmpty);
    expect(playable, isNotEmpty);

    final request = http.Request('GET', Uri.parse(playable.first.path))
      ..headers['Range'] = 'bytes=0-2047';
    final response = await client.send(request);
    final type = response.headers['content-type'] ?? '';
    // ignore: avoid_print
    print('LIVE audius stream: HTTP ${response.statusCode} type=$type');
    await response.stream.drain<void>();
    expect(response.statusCode, anyOf(200, 206));
    expect(type, anyOf(contains('audio'), contains('mpeg'), contains('octet')));
  }, timeout: const Timeout(Duration(seconds: 60)));
}
