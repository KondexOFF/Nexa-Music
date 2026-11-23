// Optional ad blocking (D-026, from the X1 experiment of D-023): uBlock
// Origin Lite in NEXA's WebView2 with the real runtime:
//
//   flutter test integration_test/ad_block_test.dart -d windows
//       --dart-define=NEXA_X1_UBOL=<folder of the unpacked Chromium build>
//
// What it checks (facts for the reports, not a promise that ads are
// blocked):
// 1. WebView2 accepts the unpacked MV3 extension (install, enable, disable).
// 2. Whether its network rules act in WebView2: requests to well-known ad
//    hosts from a blank page, before install, while on and after off; a
//    YouTube request that must never be blocked is the control.
// 3. The official YouTube player still plays (muted) with the extension on,
//    and after it is switched off (no regression when off).
// The user's own WebView2 profile is never opened (temporary profile).
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:nexa_music/integrations/youtube/youtube_embed.dart';
import 'package:path/path.dart' as p;
import 'package:webview_flutter_windows/webview_flutter_windows.dart';

const String ubolFolder = String.fromEnvironment('NEXA_X1_UBOL');

/// YouTube's own public API demo video (embeddable; verified in E2.0).
const String demoVideo = 'M7lc1UVf-VE';

const List<String> adProbes = [
  'https://googleads.g.doubleclick.net/pagead/id',
  'https://pagead2.googlesyndication.com/pagead/js/adsbygoogle.js',
  'https://www.youtube.com/api/stats/ads',
];
const String controlProbe = 'https://www.youtube.com/favicon.ico';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Ad blocking: uBlock Origin Lite in WebView2 - install, rules, '
      'off', (tester) async {
    expect(
      ubolFolder.isNotEmpty &&
          File(p.join(ubolFolder, 'manifest.json')).existsSync(),
      isTrue,
      reason: 'pass --dart-define=NEXA_X1_UBOL=<unpacked uBOL folder>',
    );
    final temp = Directory.systemTemp.createTempSync('nexa_x1_it');
    final profile = p.join(temp.path, 'webview2');
    final result = <String, Object?>{};

    Future<T> real<T>(Future<T> Function() f) async =>
        (await tester.runAsync(f)) as T;

    Future<void> wait(Duration d) =>
        real(() => Future<void>.delayed(d));

    final probe = WebviewController();
    final probeMessages = StreamController<Map<String, Object?>>.broadcast();

    Future<Map<String, String>> runProbe() async {
      final urls = [...adProbes, controlProbe];
      final script =
          '''
(function () {
  var urls = ${jsonEncode(urls)}, r = {}, n = urls.length;
  urls.forEach(function (u) {
    fetch(u + (u.indexOf('?') < 0 ? '?' : '&') + 'nexa_x1=' + Date.now(),
          { mode: 'no-cors', cache: 'no-store' })
      .then(function () { r[u] = 'loaded'; })
      .catch(function (e) { r[u] = 'failed: ' + e; })
      .finally(function () {
        if (--n === 0) { chrome.webview.postMessage({ type: 'probe', r: r }); }
      });
  });
})();''';
      // One real-time section (runAsync calls must not overlap).
      final m = await real(() async {
        final reply = probeMessages.stream
            .firstWhere((m) => m['type'] == 'probe')
            .timeout(const Duration(seconds: 30));
        await probe.executeScript(script);
        return reply;
      });
      return (m['r']! as Map).map((k, v) => MapEntry('$k', '$v'));
    }

    Future<Map<String, Object?>> playIn(WindowsYouTubeEmbed embed) async {
      final events = <Map<String, Object?>>[];
      final sub = embed.events.listen(events.add);
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: SizedBox(width: 640, height: 360, child: embed.view()),
          ),
        ),
      );
      await real(embed.openPage);
      bool seen(bool Function(Map<String, Object?>) t) => events.any(t);
      Future<bool> until(bool Function() t, int seconds) async {
        final end = DateTime.now().add(Duration(seconds: seconds));
        while (DateTime.now().isBefore(end)) {
          if (t()) {
            return true;
          }
          await wait(const Duration(milliseconds: 200));
          await tester.pump(const Duration(milliseconds: 16));
        }
        return t();
      }

      final api = await until(() => seen((e) => e['type'] == 'api'), 45);
      if (api) {
        await real(
          () => embed.send({
            'cmd': 'load',
            'videoId': demoVideo,
            'mute': true,
            'play': true,
          }),
        );
      }
      // Playing = state 1 and the time moving past 3 s (an ad, if YouTube
      // shows one, also counts as playing: ads cannot be told apart here).
      final playing = await until(
        () => seen(
          (e) =>
              e['type'] == 'tick' &&
              e['state'] == 1 &&
              e['time'] is num &&
              (e['time']! as num) > 3,
        ),
        90,
      );
      await sub.cancel();
      await real(() => embed.send({'cmd': 'stop'}));
      final errors = events
          .where((e) => e['type'] == 'error')
          .map((e) => e['code'])
          .toList();
      return {
        'apiLoaded': api,
        'playing': playing,
        'errors': errors,
        'autoplayBlocked': seen((e) => e['type'] == 'autoplayBlocked'),
      };
    }

    try {
      await real(() async {
        await Directory(profile).create(recursive: true);
        await WebviewController.initializeEnvironment(
          userDataPath: profile,
          browserExtensions: true,
        );
        WindowsYouTubeEmbed.environmentCreated(extensions: true);
      });
      result['webview2'] = await real(WebviewController.getWebViewVersion);
      await real(probe.initialize);
      probe.webMessage.listen((m) {
        if (m is Map) {
          probeMessages.add(m.cast<String, Object?>());
        }
      });
      await real(() => probe.loadUrl('about:blank'));
      await wait(const Duration(seconds: 1));

      // 1. Baseline: no extension.
      result['probeBefore'] = await runProbe();

      // 2. Install + on.
      final added = await real(
        () => probe.setBrowserExtension(
          path: ubolFolder,
          enabled: true,
          nameHint: 'uBlock',
        ),
      );
      result['install'] = added;
      expect(added['ok'], isTrue, reason: 'WebView2 refused: $added');
      expect('${added['name']}', contains('uBlock'));
      expect(added['enabled'], isTrue);
      final id = '${added['id']}';
      expect(id, isNotEmpty);
      // Its service worker loads the rule sets.
      await wait(const Duration(seconds: 8));
      result['probeOn'] = await runProbe();

      // Same request again: already installed - found by id, not added twice.
      final again = await real(
        () => probe.setBrowserExtension(
          path: ubolFolder,
          id: id,
          enabled: true,
          nameHint: 'uBlock',
        ),
      );
      result['reEnable'] = again;
      expect(again['ok'], isTrue);
      expect(again['id'], id);

      // 3. The YouTube player with the extension on (NEXA's own embed).
      final replies = <Map<String, Object?>>[];
      final on = WindowsYouTubeEmbed(
        profileDir: profile,
        extension: (path: ubolFolder, id: id, enabled: true, remove: false),
        onExtension: replies.add,
      );
      await real(on.initialize);
      result['playerOn'] = await playIn(on);
      result['embedReplyOn'] = replies.isEmpty ? null : replies.last;
      await tester.pumpWidget(const SizedBox());
      await real(on.dispose);

      // 4. Off.
      replies.clear();
      final off = WindowsYouTubeEmbed(
        profileDir: profile,
        extension: (path: ubolFolder, id: id, enabled: false, remove: false),
        onExtension: replies.add,
      );
      await real(off.initialize);
      result['embedReplyOff'] = replies.isEmpty ? null : replies.last;
      expect(replies, isNotEmpty);
      expect(replies.last['ok'], isTrue);
      expect(replies.last['enabled'], isFalse);
      await wait(const Duration(seconds: 3));
      result['probeOff'] = await runProbe();
      result['playerOff'] = await playIn(off);
      await tester.pumpWidget(const SizedBox());
      await real(off.dispose);

      // 5. Remove: out of the profile completely.
      replies.clear();
      final gone = WindowsYouTubeEmbed(
        profileDir: profile,
        extension: (path: ubolFolder, id: id, enabled: false, remove: true),
        onExtension: replies.add,
      );
      await real(gone.initialize);
      result['embedReplyRemove'] = replies.isEmpty ? null : replies.last;
      expect(replies, isNotEmpty);
      expect(replies.last['ok'], isTrue);
      expect('${replies.last['id']}', isEmpty);
      await real(gone.dispose);
      final after = await real(
        () => probe.setBrowserExtension(path: '', id: id, enabled: false),
      );
      result['afterRemove'] = after;
      expect(after['ok'], isTrue);
      expect('${after['id']}', isEmpty, reason: 'no longer installed');

      // No regression when off: the official player plays.
      expect(
        (result['playerOff']! as Map)['playing'],
        isTrue,
        reason: 'player with the extension off: ${result['playerOff']}',
      );
      // The control request is never blocked.
      for (final k in ['probeBefore', 'probeOn', 'probeOff']) {
        expect(
          (result[k]! as Map)[controlProbe],
          'loaded',
          reason: '$k: control request failed - network problem?',
        );
      }
    } finally {
      // One line for the report (no paths: the folder is not printed).
      debugPrint('X1RESULT ${jsonEncode(result)}');
      await real(() async {
        await probeMessages.close();
        await probe.dispose();
        await Future<void>.delayed(const Duration(seconds: 1));
      });
      try {
        temp.deleteSync(recursive: true);
      } on FileSystemException {
        // WebView2 may still hold its profile for a moment.
      }
    }
  });
}
