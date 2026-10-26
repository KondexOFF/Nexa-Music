// E2 YouTube on Windows with the real stack: Microsoft Edge WebView2, the
// official YouTube IFrame Player (from youtube.com), media_kit / libmpv,
// a SQLite file database in a temporary profile.
//
//   flutter test integration_test/youtube_test.dart -d windows
//
// Needs the internet (YouTube). The YouTube Data API search is answered by
// a local stand-in server (no key in the repository or the logs); the video
// it returns is played by the real YouTube player. Videos play muted, the
// local song is a tone at volume 0: the run is silent. The user's own
// library, settings and WebView2 profile are never opened.
import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:integration_test/integration_test.dart';
import 'package:media_kit/media_kit.dart' show MediaKit;
import 'package:nexa_music/app/app.dart';
import 'package:nexa_music/app/navigation.dart';
import 'package:nexa_music/app/strings.dart';
import 'package:nexa_music/core/database/app_database.dart';
import 'package:nexa_music/core/models/track.dart';
import 'package:nexa_music/core/settings/settings_repository.dart';
import 'package:nexa_music/features/discover/catalog_providers.dart';
import 'package:nexa_music/features/library/library_providers.dart';
import 'package:nexa_music/features/player/playback_arbiter.dart';
import 'package:nexa_music/features/player/player_controller.dart';
import 'package:nexa_music/features/youtube/youtube_player_controller.dart';
import 'package:nexa_music/features/youtube/youtube_settings.dart';
import 'package:nexa_music/features/youtube/youtube_watch_page.dart';
import 'package:nexa_music/integrations/youtube/youtube_data_api.dart';
import 'package:nexa_music/integrations/youtube/youtube_embed.dart';
import 'package:path/path.dart' as p;

import '../test/helpers/wav.dart';

/// YouTube's own public API demo video (embeddable; verified in E2.0).
const String demoVideo = 'M7lc1UVf-VE';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  testWidgets('E2: search -> Watch in NEXA in the real YouTube player; one '
      'sound at a time; media keys; hidden window; errors; leaving stops it',
      (tester) async {
    final temp = Directory.systemTemp.createTempSync('nexa_e2_it');
    final profile = Directory(p.join(temp.path, 'profile'))..createSync();
    final song = p.join(temp.path, 'tone.wav');
    writeWav(song, title: 'Tone', seconds: 60, frequency: 440, sampleRate: 22050);

    // Stand-in for the Data API: one search result, the demo video.
    final api = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final apiRequests = <Uri>[];
    api.listen((r) {
      apiRequests.add(r.uri);
      r.response.headers.contentType = ContentType.json;
      r.response.write(
        jsonEncode(
          r.uri.path.endsWith('/search')
              ? {
                  'items': [
                    {
                      'id': {'videoId': demoVideo},
                      'snippet': {
                        'title': 'YouTube Developers Live',
                        'channelTitle': 'Google for Developers',
                        'thumbnails': {},
                      },
                    },
                  ],
                }
              : {
                  'items': [
                    {
                      'id': demoVideo,
                      'contentDetails': {'duration': 'PT1H1M1S'},
                    },
                  ],
                },
        ),
      );
      r.response.close();
    });
    final client = http.Client();
    final opened = <String>[];
    final db = AppDatabase(
      NativeDatabase(File(p.join(profile.path, 'nexa_library.sqlite'))),
    );
    await tester.runAsync(() async {
      final repo = SettingsRepository(db);
      await repo.setBool(SettingKeys.youtubeEnabled, true);
      await repo.setString(SettingKeys.youtubeApiKey, 'local-test-key');
    });
    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        artworkDirProvider.overrideWith(
          (ref) async => p.join(profile.path, 'artwork'),
        ),
        autoRescanProvider.overrideWithValue(false),
        youtubeEmbedFactoryProvider.overrideWithValue(
          () async => WindowsYouTubeEmbed(
            profileDir: p.join(profile.path, 'webview2'),
          ),
        ),
        youtubeDataApiProvider.overrideWith(
          (ref) => YouTubeDataApi(
            client,
            apiKey: 'local-test-key',
            base: Uri.parse('http://127.0.0.1:${api.port}/youtube/v3'),
          ),
        ),
        linkOpenerProvider.overrideWithValue((url) async {
          opened.add(url);
          return true;
        }),
      ],
    );
    YtStatus yt() => container.read(youtubePlayerProvider);
    YouTubePlayerController player() =>
        container.read(youtubePlayerProvider.notifier);
    bool nexaPlaying() => container.read(playerProvider).playing;

    /// Pumps frames and lets real time pass until [test] holds.
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

    Future<void> mediaKey(String key) async {
      // As the Windows runner sends it (windows/runner/media_session.cpp).
      await tester.runAsync(() async {
        ServicesBinding.instance.channelBuffers.push(
          'nexa/media_keys',
          const StandardMethodCodec().encodeMethodCall(MethodCall(key)),
          (_) {},
        );
      });
    }

    try {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const NexaApp(ambientMotion: false),
        ),
      );
      await waitFor(() => container.read(youtubeSettingsProvider).loaded);
      await tester.runAsync(
        () => container.read(playerProvider.notifier).setVolume(0),
      );

      // E2.3: Discover -> YouTube -> search -> Watch in NEXA.
      container.read(navigationProvider.notifier).go(NexaDestination.discover);
      await waitFor(() => false, timeout: const Duration(milliseconds: 600));
      await tester.tap(find.byKey(const ValueKey('discover-youtube')));
      await waitFor(() => false, timeout: const Duration(milliseconds: 400));
      await tester.enterText(find.byKey(const ValueKey('yt-query')), 'demo');
      await tester.tap(find.byKey(const ValueKey('yt-search')));
      expect(
        await waitFor(
          () => find
              .byKey(const ValueKey('yt-result-$demoVideo'))
              .evaluate()
              .isNotEmpty,
        ),
        isTrue,
        reason: 'search result shown',
      );
      expect(apiRequests.first.queryParameters['videoEmbeddable'], 'true');
      await tester.tap(
        find.descendant(
          of: find.byKey(const ValueKey('yt-result-$demoVideo')),
          matching: find.byTooltip(S.ytWatchInNexa),
        ),
      );
      expect(
        await waitFor(() => yt().apiLoaded && yt().pageOrigin != null),
        isTrue,
        reason: 'player page and IFrame API loaded; ${yt().unavailable}',
      );
      expect(find.byType(YouTubeWatchPage), findsOneWidget);
      expect(yt().pageOrigin, 'https://$youtubeAppHost');
      expect(find.text('YouTube Developers Live'), findsOneWidget);
      // Watch with sound is started from NEXA's button, outside the page:
      // WebView2 may block it until the user presses play in the player.
      await waitFor(
        () => yt().active || yt().autoplayBlocked,
        timeout: const Duration(seconds: 15),
      );

      // R1: the official player plays (muted for the automated run).
      await tester.runAsync(() => player().load(demoVideo, mute: true));
      expect(
        await waitFor(() => yt().state == YtState.playing),
        isTrue,
        reason: 'playing; error ${yt().errorCode}',
      );
      expect(yt().errorCode, isNull);
      expect(container.read(playbackArbiterProvider), PlaybackOwner.external);
      expect(container.read(mediaOverlayOverrideProvider)?.playing, isTrue);

      // One sound at a time: NEXA starts -> YouTube pauses.
      await tester.runAsync(
        () => container.read(playerProvider.notifier).playTracks([
          Track(
            id: 900001,
            source: TrackSource.local,
            sourceTrackId: song,
            path: song,
            title: 'Tone',
            artist: 'Test',
            album: 'Test',
            addedAt: DateTime(2026),
          ),
        ]),
      );
      expect(await waitFor(nexaPlaying), isTrue);
      expect(
        await waitFor(() => yt().state == YtState.paused),
        isTrue,
        reason: 'YouTube paused when NEXA started',
      );
      expect(container.read(mediaOverlayOverrideProvider), isNull);

      // YouTube starts -> NEXA pauses.
      await tester.runAsync(player().play);
      expect(await waitFor(() => yt().state == YtState.playing), isTrue);
      expect(await waitFor(() => !nexaPlaying()), isTrue);

      // Media keys: Windows sends Pause for the playing overlay, then Play.
      await mediaKey('pause');
      expect(await waitFor(() => yt().state == YtState.paused), isTrue);
      expect(nexaPlaying(), isFalse);
      await mediaKey('play');
      expect(await waitFor(() => yt().state == YtState.playing), isTrue);
      expect(nexaPlaying(), isFalse);
      await mediaKey('playPause');
      expect(await waitFor(() => yt().state == YtState.paused), isTrue);
      await mediaKey('playPause');
      expect(await waitFor(() => yt().state == YtState.playing), isTrue);

      // Hidden (minimised) window -> paused, stays paused when shown.
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      expect(await waitFor(() => yt().state == YtState.paused), isTrue);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await waitFor(() => false, timeout: const Duration(seconds: 2));
      expect(yt().state, YtState.paused);

      // An unknown video: a plain message and Open on YouTube.
      await tester.runAsync(() => player().load('aaaaaaaaaaa', mute: true));
      expect(await waitFor(() => yt().errorCode != null), isTrue);
      expect(const [100, 101, 150], contains(yt().errorCode));
      await tester.pump();
      expect(find.text(youtubeErrorText(yt().errorCode!)), findsOneWidget);
      await tester.ensureVisible(
        find.byKey(const ValueKey('yt-open-on-youtube')),
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('yt-open-on-youtube')));
      expect(opened.last, 'https://www.youtube.com/watch?v=aaaaaaaaaaa');

      // Leaving the page stops YouTube and releases WebView2.
      await tester.runAsync(() => player().load(demoVideo, mute: true));
      expect(await waitFor(() => yt().state == YtState.playing), isTrue);
      await tester.ensureVisible(find.byTooltip(S.ytBack));
      await tester.pump();
      await tester.tap(find.byTooltip(S.ytBack));
      expect(await waitFor(() => player().embed == null), isTrue);
      expect(container.read(mediaKeyRedirectProvider), isNull);
      expect(find.byType(YouTubeWatchPage), findsNothing);

      // Nothing about YouTube was recorded.
      final history = await tester.runAsync(
        () => db.select(db.listeningEvents).get(),
      );
      expect(history, isEmpty);
      expect(
        container.read(playerProvider).queue.every(
          (e) => e.track.source == TrackSource.local,
        ),
        isTrue,
      );
      expect(apiRequests.every((u) => u.queryParameters['key'] != null), isTrue);
    } finally {
      await tester.runAsync(container.read(playerProvider.notifier).stop);
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(() async {
        container.dispose();
        await Future<void>.delayed(const Duration(seconds: 1));
        await db.close();
        client.close();
        await api.close(force: true);
      });
      try {
        temp.deleteSync(recursive: true);
      } on FileSystemException {
        // WebView2 may still hold its profile for a moment.
      }
    }
  });
}
