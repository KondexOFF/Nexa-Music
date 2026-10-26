import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexa_music/app/app.dart';
import 'package:nexa_music/app/navigation.dart';
import 'package:nexa_music/app/strings.dart';
import 'package:nexa_music/features/youtube_prototype/youtube_prototype_controller.dart';
import 'package:nexa_music/features/youtube_prototype/youtube_prototype_page.dart';

import 'helpers/test_app.dart';
import 'youtube_prototype_test.dart' show FakeEmbed;

/// E2.0 prototype page: opened from Settings, a visible 16:9 player of at
/// least 480 x 270 with nothing over it, clear messages, closed on Back.
void main() {
  for (final size in [const Size(1024, 700), const Size(1920, 1080)]) {
    testWidgets('${size.width.round()}: Settings opens the prototype; the '
        'player is visible, 16:9, >= 480 x 270, nothing drawn over it',
        (tester) async {
      final embed = FakeEmbed();
      await loadNexaFonts();
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...testOverrides(),
            youtubeEmbedFactoryProvider.overrideWithValue(() async => embed),
          ],
          child: const NexaApp(ambientMotion: false),
        ),
      );
      await settle(tester);
      final c = ProviderScope.containerOf(tester.element(find.byType(NexaApp)));
      c.read(navigationProvider.notifier).go(NexaDestination.settings);
      await settle(tester);

      final button = find.byKey(const ValueKey('open-youtube-prototype'));
      await tester.ensureVisible(button);
      await settle(tester);
      await tester.tap(button);
      await settle(tester);
      expect(find.byType(YouTubePrototypePage), findsOneWidget);
      expect(embed.pages, [true]);

      final area = find.byKey(const ValueKey('yt-player'));
      final box = tester.getSize(area);
      expect(box.width, greaterThanOrEqualTo(youtubeMinPlayer.width));
      expect(box.height, greaterThanOrEqualTo(youtubeMinPlayer.height));
      expect(box.width / box.height, closeTo(16 / 9, 0.01));
      // Only the player itself inside the player area.
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

      // A wrong link is explained; a right one loads the video.
      await tester.enterText(find.byKey(const ValueKey('yt-link')), 'hello');
      await tester.tap(find.text(S.ytLoad));
      await settle(tester);
      expect(find.text(S.ytBadLink), findsOneWidget);
      expect(embed.sent, isEmpty);
      await tester.enterText(
        find.byKey(const ValueKey('yt-link')),
        'https://youtu.be/M7lc1UVf-VE',
      );
      await tester.tap(find.text(S.ytLoad));
      await settle(tester);
      expect(embed.sent.last['videoId'], 'M7lc1UVf-VE');

      // Not embeddable: the reason and "Open on YouTube".
      embed.emit({'type': 'error', 'code': 150});
      await settle(tester);
      expect(find.text(S.ytErrorNotEmbeddable), findsOneWidget);
      expect(find.text(S.ytOpenOnYouTube), findsOneWidget);

      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('leaving the page closes the player and releases the web view',
      (tester) async {
    final embed = FakeEmbed();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...testOverrides(),
          youtubeEmbedFactoryProvider.overrideWithValue(() async => embed),
        ],
        child: const MaterialApp(home: YouTubePrototypePage()),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(embed.pages, [true]);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    await tester.pump();
    expect(embed.disposed, isTrue);
  });
}
