// Live check of the Jamendo adapter against the real API (network needed).
// Not part of `flutter test` (no _test.dart suffix); run explicitly:
//   flutter test test/online/jamendo_live.dart
// The owner's client id is read from ../_phase1_ctl/jamendo_client_id.txt
// (outside the repository) and never printed.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:nexa_music/integrations/jamendo/jamendo_source.dart';

void main() {
  test('Jamendo: search returns licensed tracks and the stream answers',
      () async {
    final idFile = File('../_phase1_ctl/jamendo_client_id.txt');
    if (!idFile.existsSync()) {
      markTestSkipped('no client id file');
      return;
    }
    final client = http.Client();
    addTearDown(client.close);
    final source = JamendoSource(
      client,
      clientId: idFile.readAsStringSync().trim(),
    );
    final tracks = await source.search('chill', limit: 10);
    final playable = tracks.where((t) => t.available).toList();
    // ignore: avoid_print
    print('LIVE jamendo: ${tracks.length} results, ${playable.length} playable');
    for (final t in tracks.take(3)) {
      // ignore: avoid_print
      print('LIVE jamendo track: available=${t.available} '
          'license=${t.license} page=${t.pageUrl != null}');
    }
    expect(tracks, isNotEmpty);
    expect(playable, isNotEmpty);
    expect(playable.first.license, isNotNull);
    expect(playable.first.pageUrl, isNotNull);

    final request = http.Request('GET', Uri.parse(playable.first.path))
      ..headers['Range'] = 'bytes=0-2047';
    final response = await client.send(request);
    final type = response.headers['content-type'] ?? '';
    // ignore: avoid_print
    print('LIVE jamendo stream: HTTP ${response.statusCode} type=$type');
    await response.stream.drain<void>();
    expect(response.statusCode, anyOf(200, 206));
    expect(type, anyOf(contains('audio'), contains('mpeg'), contains('octet')));
  }, timeout: const Timeout(Duration(seconds: 60)));
}
