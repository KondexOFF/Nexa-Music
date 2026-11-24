// Ad blocking (D-026 final): the simple install and the restart rule, with
// the real WebView2 runtime and the real downloaded .zip:
//
//   flutter test integration_test/ad_block_restart_test.dart -d windows
//       --dart-define=NEXA_UBOL_ZIP=<uBOLite_....chromium.zip>
//
// 1. The official Chromium .zip unpacks (Windows Expand-Archive, as in
//    Settings) into a folder with the extension.
// 2. In a run whose WebView2 environment was created WITHOUT extension
//    support (ad blocking was off when the first web player opened),
//    switching it on needs a restart: NEXA says so instead of failing
//    silently, and WebView2 itself refuses the extension.
// A temporary WebView2 profile is used, never the user's.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:nexa_music/features/privacy/ad_block.dart';
import 'package:nexa_music/integrations/youtube/youtube_embed.dart';
import 'package:path/path.dart' as p;
import 'package:webview_flutter_windows/webview_flutter_windows.dart';

const String ubolZip = String.fromEnvironment('NEXA_UBOL_ZIP');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Ad blocking: .zip install; a restart is needed when the '
      'environment has no extension support', (tester) async {
    expect(File(ubolZip).existsSync(), isTrue,
        reason: 'pass --dart-define=NEXA_UBOL_ZIP=<.zip>');
    final result = <String, Object?>{};
    await tester.runAsync(() async {
      final temp = Directory.systemTemp.createTempSync('nexa_ab_restart');
      try {
        // 1. The downloaded .zip.
        final dest = Directory(p.join(temp.path, 'unpacked'))..createSync();
        final sw = Stopwatch()..start();
        await expandArchive(ubolZip, dest.path);
        final folder = findExtensionFolder(dest.path);
        result['unpackMs'] = sw.elapsedMilliseconds;
        result['found'] = folder != null;
        result['name'] = folder == null ? null : extensionName(folder);
        expect(folder, isNotNull);
        expect(extensionName(folder!), contains('uBlock'));

        // 2. First web player of this run with ad blocking off: the
        // environment is created without extension support.
        final profile = p.join(temp.path, 'webview2');
        final plain = WindowsYouTubeEmbed(profileDir: profile);
        await plain.initialize();
        result['environment'] = 'created without extensions';
        await plain.dispose();

        // Switched on afterwards (same run): NEXA asks for a restart.
        final replies = <Map<String, Object?>>[];
        final later = WindowsYouTubeEmbed(
          profileDir: profile,
          extension: (path: folder, id: '', enabled: true, remove: false),
          onExtension: replies.add,
        );
        await later.initialize();
        result['nexaReply'] = replies.isEmpty ? null : replies.last;
        await later.dispose();
        expect(replies, isNotEmpty);
        expect(replies.last['error'], 'restart');

        // WebView2's own answer in that environment (the reason for the
        // restart rule).
        final probe = WebviewController();
        await probe.initialize();
        try {
          result['webview2Reply'] = await probe.setBrowserExtension(
            path: folder,
            id: '',
            enabled: true,
            nameHint: adBlockNameHint,
          );
        } on Object catch (e) {
          result['webview2Reply'] = 'error: $e';
        }
        await probe.dispose();
        final w = result['webview2Reply'];
        expect(w is Map && w['ok'] == true, isFalse,
            reason: 'WebView2 accepted an extension without support: $w');
      } finally {
        debugPrint('ABRESULT ${jsonEncode(result)}');
        await Future<void>.delayed(const Duration(seconds: 1));
        try {
          temp.deleteSync(recursive: true);
        } on FileSystemException {
          // WebView2 may still hold its profile for a moment.
        }
      }
    });
  });
}
