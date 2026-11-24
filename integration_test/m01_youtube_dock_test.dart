// M-01 (D-028, automated): the one YouTube player moves between the YouTube
// page, the compact player in the corner, full screen and the mini window
// without being reloaded and without losing its position; the window size
// comes back after the mini window.
//
//   flutter test integration_test/m01_youtube_dock_test.dart -d windows
//
// Real Microsoft Edge WebView2 and the official YouTube IFrame Player; the
// video plays muted (silent run). A temporary profile, never the user's.
// Full screen: YouTube's own button cannot be pressed by a program
// (browsers need a real click), so the test sends the same "full screen"
// signal WebView2 sends and checks what NEXA does with it: the same web
// view fills the window and keeps playing.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:media_kit/media_kit.dart' show MediaKit;
import 'package:nexa_music/app/app.dart';
import 'package:nexa_music/app/navigation.dart';
import 'package:nexa_music/core/database/app_database.dart';
import 'package:nexa_music/core/settings/settings_repository.dart';
import 'package:nexa_music/features/library/library_providers.dart';
import 'package:nexa_music/features/youtube/youtube_dock.dart';
import 'package:nexa_music/features/youtube/youtube_player_controller.dart';
import 'package:nexa_music/features/youtube/youtube_settings.dart';
import 'package:nexa_music/integrations/youtube/youtube_embed.dart';
import 'package:path/path.dart' as p;

/// YouTube's own public API demo video (embeddable; verified in E2.0).
const String demoVideo = 'M7lc1UVf-VE';

/// The real web view, plus the full-screen signal of the test.
class _Embed implements YouTubeEmbed {
  _Embed(this.real);

  final WindowsYouTubeEmbed real;
  final StreamController<bool> fullScreenSignal =
      StreamController<bool>.broadcast();
  int pages = 0;
  double lastTime = -1;
  bool timeWentBack = false;

  @override
  Stream<Map<String, Object?>> get events => real.events.map((e) {
    if (e['type'] == 'page') {
      pages++;
    }
    final t = e['time'];
    if (e['type'] == 'tick' && t is num) {
      if (t + 1.5 < lastTime) {
        timeWentBack = true;
      }
      lastTime = t.toDouble();
    }
    return e;
  });

  @override
  Stream<bool> get fullScreen {
    final out = StreamController<bool>.broadcast();
    real.fullScreen.listen(out.add);
    fullScreenSignal.stream.listen(out.add);
    return out.stream;
  }

  @override
  Future<void> initialize() => real.initialize();

  @override
  Future<void> openPage() => real.openPage();

  @override
  Future<void> send(Map<String, Object?> command) => real.send(command);

  @override
  Widget view() => real.view();

  @override
  Future<String?> runtimeVersion() => real.runtimeVersion();

  @override
  Future<void> dispose() async {
    await fullScreenSignal.close();
    await real.dispose();
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  testWidgets('M-01: page, compact player, full screen, mini window - no '
      'reload, position kept, window size restored', (tester) async {
    final temp = Directory.systemTemp.createTempSync('nexa_m01');
    final profile = Directory(p.join(temp.path, 'profile'))..createSync();
    final db = AppDatabase(
      NativeDatabase(File(p.join(profile.path, 'nexa_library.sqlite'))),
    );
    await tester.runAsync(
      () => SettingsRepository(db).setBool(SettingKeys.youtubeEnabled, true),
    );
    _Embed? embed;
    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        artworkDirProvider.overrideWith(
          (ref) async => p.join(profile.path, 'artwork'),
        ),
        autoRescanProvider.overrideWithValue(false),
        youtubeEmbedFactoryProvider.overrideWithValue(
          () async => embed = _Embed(
            WindowsYouTubeEmbed(profileDir: p.join(profile.path, 'webview2')),
          ),
        ),
      ],
    );
    final result = <String, Object?>{};
    YtStatus yt() => container.read(youtubePlayerProvider);
    YouTubePlayerController player() =>
        container.read(youtubePlayerProvider.notifier);
    Size window() => tester.view.physicalSize / tester.view.devicePixelRatio;

    Future<bool> waitFor(
      bool Function() test, {
      Duration timeout = const Duration(seconds: 30),
    }) async {
      final end = DateTime.now().add(timeout);
      while (DateTime.now().isBefore(end)) {
        if (test()) {
          return true;
        }
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)),
        );
        await tester.pump(const Duration(milliseconds: 50));
      }
      return test();
    }

    Future<void> idle(Duration d) => waitFor(() => false, timeout: d);

    /// The video keeps playing and its time moves on from [after].
    Future<double> stillPlaying(String step, double after) async {
      final moved = await waitFor(
        () => yt().state == YtState.playing && embed!.lastTime > after + 1,
        timeout: const Duration(seconds: 20),
      );
      result[step] = {
        'state': yt().state,
        'time': embed!.lastTime.toStringAsFixed(1),
        'pages': embed!.pages,
      };
      expect(moved, isTrue, reason: '$step: not playing on ($result)');
      expect(embed!.pages, 1, reason: '$step: the player page was reloaded');
      expect(embed!.timeWentBack, isFalse, reason: '$step: position lost');
      return embed!.lastTime;
    }

    try {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const NexaApp(ambientMotion: false),
        ),
      );
      await waitFor(() => container.read(youtubeSettingsProvider).loaded);
      final normal = window();
      result['window'] = '${normal.width.round()}x${normal.height.round()}';

      // 1. The YouTube page.
      container.read(navigationProvider.notifier).go(NexaDestination.youtube);
      await idle(const Duration(milliseconds: 600));
      await tester.runAsync(player().open);
      expect(await waitFor(() => yt().apiLoaded), isTrue,
          reason: 'IFrame API; ${yt().unavailable}');
      await tester.runAsync(() => player().load(demoVideo, mute: true));
      expect(await waitFor(() => yt().state == YtState.playing), isTrue,
          reason: 'playing; error ${yt().errorCode}');
      final first = embed;
      var t = await stillPlaying('page', 0);

      // 2. Another section: the compact player in the corner.
      container.read(navigationProvider.notifier).go(NexaDestination.library);
      expect(
        await waitFor(
          () => find.byKey(const ValueKey('yt-compact')).evaluate().isNotEmpty,
        ),
        isTrue,
      );
      t = await stillPlaying('compact', t);
      expect(identical(player().embed, first), isTrue);

      // 3. Full screen: the same web view fills the window.
      embed!.fullScreenSignal.add(true);
      expect(await waitFor(() => yt().fullScreen), isTrue);
      await idle(const Duration(milliseconds: 500));
      final fsView = tester.getSize(find.byKey(youtubeViewKey));
      result['fullScreenView'] =
          '${fsView.width.round()}x${fsView.height.round()}';
      expect(fsView.width, closeTo(window().width, 2));
      expect(fsView.height, closeTo(window().height, 2));
      t = await stillPlaying('fullScreen', t);
      embed!.fullScreenSignal.add(false);
      expect(await waitFor(() => !yt().fullScreen), isTrue);
      expect(
        await waitFor(
          () => find.byKey(const ValueKey('yt-compact')).evaluate().isNotEmpty,
        ),
        isTrue,
        reason: 'back in the corner after full screen',
      );

      // 4. Mini window: NEXA's window shrinks to the player, on top.
      final testEnv = Platform.environment['FLUTTER_TEST'] == 'true';
      result['flutterTestEnv'] = testEnv;
      await tester.tap(find.byKey(const ValueKey('yt-mini-window')));
      await tester.pump();
      if (testEnv) {
        // Under "flutter test" the app skips the native call; make it here,
        // exactly as MiniWindowController does.
        await tester.runAsync(
          () => const MethodChannel('nexa/window').invokeMethod<bool>(
            'setMini',
            {
              'on': true,
              'width': youtubeMiniWindow.width.round(),
              'height': youtubeMiniWindow.height.round(),
            },
          ),
        );
      }
      expect(await waitFor(() => container.read(miniWindowProvider)), isTrue);
      expect(
        await waitFor(
          () => (window().width - youtubeMiniWindow.width).abs() < 3 &&
              (window().height - youtubeMiniWindow.height).abs() < 3,
          timeout: const Duration(seconds: 5),
        ),
        isTrue,
        reason: 'mini window size ${window()}',
      );
      result['miniWindow'] =
          '${window().width.round()}x${window().height.round()}';
      expect(find.byKey(const ValueKey('yt-mini-restore')), findsOneWidget);
      t = await stillPlaying('miniWindow', t);
      expect(identical(player().embed, first), isTrue);

      // 5. Back: the window gets its size again.
      await tester.tap(find.byKey(const ValueKey('yt-mini-restore')));
      await tester.pump();
      if (testEnv) {
        await tester.runAsync(
          () => const MethodChannel('nexa/window').invokeMethod<bool>(
            'setMini',
            {'on': false},
          ),
        );
      }
      expect(await waitFor(() => !container.read(miniWindowProvider)), isTrue);
      expect(
        await waitFor(
          () => (window().width - normal.width).abs() < 3 &&
              (window().height - normal.height).abs() < 3,
          timeout: const Duration(seconds: 5),
        ),
        isTrue,
        reason: 'window size back: ${window()} (was $normal)',
      );
      result['restored'] =
          '${window().width.round()}x${window().height.round()}';
      t = await stillPlaying('restored', t);

      // 6. And the page again: still the same player.
      container.read(navigationProvider.notifier).go(NexaDestination.youtube);
      await idle(const Duration(milliseconds: 600));
      expect(find.byKey(const ValueKey('yt-compact')), findsNothing);
      await stillPlaying('pageAgain', t);
      expect(identical(player().embed, first), isTrue);
    } finally {
      debugPrint('M01RESULT ${jsonEncode(result)}');
      await tester.runAsync(() async {
        await container.read(miniWindowProvider.notifier).set(false);
        await player().close();
      });
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(() async {
        container.dispose();
        await Future<void>.delayed(const Duration(seconds: 1));
        await db.close();
      });
      try {
        temp.deleteSync(recursive: true);
      } on FileSystemException {
        // WebView2 may still hold its profile for a moment.
      }
    }
  });
}
