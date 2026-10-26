import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nexa_music/app/app.dart';
import 'package:nexa_music/app/navigation.dart';
import 'package:nexa_music/app/strings.dart';
import 'package:nexa_music/core/settings/settings_repository.dart';
import 'package:nexa_music/features/discover/catalog_providers.dart';
import 'package:nexa_music/features/youtube/youtube_discover.dart';
import 'package:nexa_music/features/youtube/youtube_player_controller.dart';
import 'package:nexa_music/features/youtube/youtube_settings.dart';
import 'package:nexa_music/features/youtube/youtube_watch_page.dart';

import 'helpers/test_app.dart';
import 'youtube_player_test.dart' show FakeEmbed;

/// E2.1-E2.4 on screen: consent before use, key handling, the separate
/// YouTube section in Discover (link and search), the YouTube page.
void main() {
  late FakeEmbed embed;
  late List<String> opened;
  late List<Uri> requests;

  http.Client api() => MockClient((r) async {
    requests.add(r.url);
    if (r.url.path.endsWith('/search')) {
      return http.Response(
        jsonEncode({
          'items': [
            {
              'id': {'videoId': 'aaaaaaaaaaa'},
              'snippet': {
                'title': 'Night drive mix',
                'channelTitle': 'Channel A',
                'thumbnails': {},
              },
            },
          ],
        }),
        200,
      );
    }
    return http.Response(
      jsonEncode({
        'items': [
          {
            'id': 'aaaaaaaaaaa',
            'contentDetails': {'duration': 'PT3M5S'},
          },
        ],
      }),
      200,
    );
  });

  Future<ProviderContainer> start(
    WidgetTester tester, {
    bool enabled = false,
    String key = '',
    Size size = size1280,
  }) async {
    embed = FakeEmbed();
    opened = [];
    requests = [];
    final db = memoryDatabase();
    await tester.runAsync(() async {
      final repo = SettingsRepository(db);
      await repo.setBool(SettingKeys.youtubeEnabled, enabled);
      await repo.setString(SettingKeys.youtubeApiKey, key);
    });
    await loadNexaFonts();
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...testOverrides(database: db),
          httpClientProvider.overrideWithValue(api()),
          youtubeEmbedFactoryProvider.overrideWithValue(() async => embed),
          youtubeTitleLookupProvider.overrideWithValue((id) async => null),
          linkOpenerProvider.overrideWithValue((url) async {
            opened.add(url);
            return true;
          }),
        ],
        child: const NexaApp(ambientMotion: false),
      ),
    );
    await settle(tester);
    return ProviderScope.containerOf(tester.element(find.byType(NexaApp)));
  }

  Future<void> discoverYouTube(WidgetTester tester, ProviderContainer c) async {
    c.read(navigationProvider.notifier).go(NexaDestination.discover);
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('discover-youtube')));
    await settle(tester);
  }

  testWidgets('YouTube is off by default; turning it on needs the consent '
      'screen; the key can be saved, checked and deleted', (tester) async {
    final c = await start(tester);
    expect(c.read(youtubeSettingsProvider).enabled, isFalse);
    c.read(navigationProvider.notifier).go(NexaDestination.settings);
    await settle(tester);
    final toggle = find.byKey(const ValueKey('yt-enabled'));
    await tester.ensureVisible(toggle);
    await settle(tester);

    await tester.tap(toggle);
    await settle(tester);
    expect(find.byKey(const ValueKey('yt-consent')), findsOneWidget);
    expect(find.text(S.ytConsentTitle), findsOneWidget);
    for (final point in S.ytConsentPoints) {
      expect(find.text(point), findsOneWidget);
    }
    await tester.tap(find.byKey(const ValueKey('yt-consent-cancel')));
    await settle(tester);
    expect(c.read(youtubeSettingsProvider).enabled, isFalse);

    await tester.tap(toggle);
    await settle(tester);
    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('yt-consent')),
        matching: find.text(S.ytTerms),
      ),
    );
    expect(opened.last, youtubeTermsUrl);
    await tester.tap(find.byKey(const ValueKey('yt-consent-agree')));
    await settle(tester);
    expect(c.read(youtubeSettingsProvider).enabled, isTrue);

    await tester.enterText(find.byKey(const ValueKey('yt-key')), ' my-key ');
    await tester.tap(find.byKey(const ValueKey('yt-key-save')));
    await settle(tester);
    expect(c.read(youtubeSettingsProvider).apiKey, 'my-key');
    await tester.tap(find.byKey(const ValueKey('yt-key-check')));
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await settle(tester);
    }
    final checked = c.read(youtubeSettingsProvider);
    expect(
      checked.keyCheck,
      KeyCheck.ok,
      reason: 'error ${checked.keyError}, requests $requests',
    );
    expect(find.text(S.ytKeyOk), findsOneWidget);
    expect(requests.single.queryParameters['part'], 'id');

    await tester.tap(find.byKey(const ValueKey('yt-key-delete')));
    await settle(tester);
    expect(c.read(youtubeSettingsProvider).apiKey, isEmpty);
    expect(find.text(S.ytKeyNone), findsOneWidget);

    await tester.tap(toggle);
    await settle(tester);
    expect(c.read(youtubeSettingsProvider).enabled, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Discover: YouTube off -> a note and the way to Settings',
      (tester) async {
    final c = await start(tester);
    await discoverYouTube(tester, c);
    expect(find.byKey(const ValueKey('yt-discover-off')), findsOneWidget);
    expect(find.text(S.ytDiscoverOff), findsOneWidget);
    await tester.tap(find.text(S.openSettings));
    await settle(tester);
    expect(c.read(navigationProvider).current, NexaDestination.settings);
  });

  for (final size in [size1024, size1920]) {
    testWidgets('${size.width.round()}: a pasted link opens the YouTube page '
        'without a key; player 16:9 >= 480 x 270 with nothing over it; '
        'errors explained; leaving stops it', (tester) async {
      final c = await start(tester, enabled: true, size: size);
      await discoverYouTube(tester, c);
      expect(find.byKey(const ValueKey('yt-discover')), findsOneWidget);
      expect(find.byKey(const ValueKey('yt-no-key')), findsOneWidget);

      await tester.enterText(find.byKey(const ValueKey('yt-link')), 'hello');
      await tester.tap(find.byKey(const ValueKey('yt-link-watch')));
      await settle(tester);
      expect(find.text(S.ytBadLink), findsOneWidget);
      expect(find.byType(YouTubeWatchPage), findsNothing);

      await tester.enterText(
        find.byKey(const ValueKey('yt-link')),
        'https://youtu.be/M7lc1UVf-VE?t=3',
      );
      await tester.tap(find.byKey(const ValueKey('yt-link-watch')));
      await settle(tester);
      expect(find.byType(YouTubeWatchPage), findsOneWidget);
      expect(embed.pages, 1);
      expect(embed.sent.last['videoId'], 'M7lc1UVf-VE');
      expect(embed.sent.last['play'], isTrue);

      final area = find.byKey(const ValueKey('yt-player'));
      final box = tester.getSize(area);
      expect(box.width, greaterThanOrEqualTo(youtubeMinPlayer.width));
      expect(box.height, greaterThanOrEqualTo(youtubeMinPlayer.height));
      expect(box.width / box.height, closeTo(16 / 9, 0.01));
      expect(
        find.descendant(
          of: area,
          matching: find.byKey(const ValueKey('fake-youtube-view')),
        ),
        findsOneWidget,
      );
      expect(find.descendant(of: area, matching: find.byType(Text)), findsNothing);
      expect(
        find.descendant(of: area, matching: find.byType(Tooltip)),
        findsNothing,
      );

      embed.emit({'type': 'error', 'code': 150});
      await settle(tester);
      expect(find.text(S.ytErrorNotEmbeddable), findsOneWidget);
      await tester.ensureVisible(
        find.byKey(const ValueKey('yt-open-on-youtube')),
      );
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('yt-open-on-youtube')));
      expect(opened.last, 'https://www.youtube.com/watch?v=M7lc1UVf-VE');

      embed.setFullScreen(true);
      await settle(tester);
      expect(find.byKey(const ValueKey('yt-title')), findsNothing);
      embed.setFullScreen(false);
      await settle(tester);

      await tester.ensureVisible(find.byTooltip(S.ytBack));
      await settle(tester);
      await tester.tap(find.byTooltip(S.ytBack));
      await settle(tester);
      expect(find.byType(YouTubeWatchPage), findsNothing);
      expect(embed.disposed, isTrue);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('with a key: search only on request, results marked YouTube '
      'with title, channel and length; Watch in NEXA / Open on YouTube',
      (tester) async {
    final c = await start(tester, enabled: true, key: 'my-key');
    await discoverYouTube(tester, c);
    expect(find.byKey(const ValueKey('yt-no-key')), findsNothing);
    expect(find.text(S.ytQuotaNote), findsOneWidget);

    await tester.enterText(find.byKey(const ValueKey('yt-query')), 'night');
    await settle(tester);
    expect(requests, isEmpty, reason: 'no search while typing');
    await tester.tap(find.byKey(const ValueKey('yt-search')));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await settle(tester);
    expect(requests.where((u) => u.path.endsWith('/search')), hasLength(1));
    final row = find.byKey(const ValueKey('yt-result-aaaaaaaaaaa'));
    expect(row, findsOneWidget);
    expect(find.descendant(of: row, matching: find.text('Night drive mix')),
        findsOneWidget);
    expect(
      find.descendant(of: row, matching: find.text('Channel A  ·  3:05')),
      findsOneWidget,
    );
    expect(find.descendant(of: row, matching: find.text('YOUTUBE')),
        findsOneWidget);

    // The same query again comes from memory: no quota used.
    await tester.tap(find.byKey(const ValueKey('yt-search')));
    await settle(tester);
    expect(requests.where((u) => u.path.endsWith('/search')), hasLength(1));

    await tester.tap(
      find.descendant(of: row, matching: find.byTooltip(S.ytOpenOnYouTube)),
    );
    expect(opened.last, 'https://www.youtube.com/watch?v=aaaaaaaaaaa');

    await tester.tap(
      find.descendant(of: row, matching: find.byTooltip(S.ytWatchInNexa)),
    );
    await settle(tester);
    expect(find.byType(YouTubeWatchPage), findsOneWidget);
    expect(find.text('Night drive mix'), findsOneWidget);
    expect(find.text('Channel A'), findsOneWidget);
    expect(c.read(youtubeSearchProvider).results, hasLength(1));
    await tester.tap(find.byTooltip(S.ytBack));
    await settle(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('search errors are plain text (quota)', (tester) async {
    embed = FakeEmbed();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...testOverrides(),
          httpClientProvider.overrideWithValue(
            MockClient(
              (r) async => http.Response(
                jsonEncode({
                  'error': {
                    'errors': [
                      {'reason': 'quotaExceeded'},
                    ],
                  },
                }),
                403,
              ),
            ),
          ),
          youtubeSettingsProvider.overrideWith(_KeySettings.new),
          youtubeEmbedFactoryProvider.overrideWithValue(() async => embed),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(child: YouTubeDiscoverSection()),
          ),
        ),
      ),
    );
    await settle(tester);
    await tester.enterText(find.byKey(const ValueKey('yt-query')), 'x');
    await tester.tap(find.byKey(const ValueKey('yt-search')));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await settle(tester);
    expect(find.text(S.ytApiQuota), findsOneWidget);
    expect(find.byKey(const ValueKey('yt-link')), findsOneWidget,
        reason: 'links still work');
  });
}

class _KeySettings extends YouTubeSettingsController {
  @override
  YouTubeSettings build() =>
      const YouTubeSettings(loaded: true, enabled: true, apiKey: 'my-key');
}
