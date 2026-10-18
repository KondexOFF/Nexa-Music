import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexa_music/app/shell/bottom_player.dart';
import 'package:nexa_music/app/strings.dart';
import 'package:nexa_music/ui/nexa_widgets.dart';

import 'helpers/test_app.dart';

/// Scrolls the vertical scroll view identified by [key] to its end.
Future<void> scrollToEnd(WidgetTester tester, Key key) async {
  final scrollable = find.descendant(
    of: find.byKey(key),
    matching: find.byType(Scrollable),
  );
  final state = tester.state<ScrollableState>(scrollable.first);
  state.position.jumpTo(state.position.maxScrollExtent);
  await settle(tester);
}

/// The last widget found by [finder] is fully visible:
/// below the top bar and above the bottom player, inside the window.
void expectFullyVisible(WidgetTester tester, Finder finder, Size window) {
  final rect = tester.getRect(finder.last);
  final playerTop = tester.getRect(find.byType(BottomPlayer)).top;
  expect(rect.bottom, lessThanOrEqualTo(playerTop), reason: 'covered by player');
  expect(rect.top, greaterThanOrEqualTo(0));
  expect(rect.right, lessThanOrEqualTo(window.width));
}

Future<void> openNowPlaying(WidgetTester tester) async {
  await tester.tap(find.byTooltip(S.openNowPlaying).last);
  await settle(tester);
}

void main() {
  const pageKey = PageStorageKey<String>('page-now-playing');
  const mixPanelKey = PageStorageKey<String>('panel-mix');

  testWidgets(
    '1280x720: end of Now Playing (queue) and of the Mix Engine / Up Next '
    'panel is reachable and not covered by the bottom player',
    (tester) async {
      await pumpNexaApp(tester, size1280);
      await openNowPlaying(tester);

      await scrollToEnd(tester, pageKey);
      // End of the queue section inside the page (empty queue).
      expectFullyVisible(
        tester,
        find.descendant(
          of: find.byKey(pageKey),
          matching: find.text(S.queueEmpty),
        ),
        size1280,
      );

      await scrollToEnd(tester, mixPanelKey);
      expectFullyVisible(
        tester,
        find.descendant(
          of: find.byKey(mixPanelKey),
          matching: find.text(S.queueEmpty),
        ),
        size1280,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    '1024x640: inline Mix Engine at the end of Now Playing is reachable and '
    'not covered by the bottom player',
    (tester) async {
      await pumpNexaApp(tester, size1024);
      await openNowPlaying(tester);

      await scrollToEnd(tester, pageKey);
      expectFullyVisible(
        tester,
        find.descendant(
          of: find.byKey(pageKey),
          matching: find.text(S.smartMixDescription),
        ),
        size1024,
      );
      // The queue section is above the Mix Engine and also reachable.
      expect(
        find.descendant(
          of: find.byKey(pageKey),
          matching: find.text(S.queueEmpty),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  for (final size in [size1280, size1024]) {
    final label = '${size.width.round()}x${size.height.round()}';
    testWidgets(
      '$label: every disabled control explains itself in a tooltip',
      (tester) async {
        await pumpNexaApp(tester, size);
        for (final open in [false, true]) {
          if (open) {
            await openNowPlaying(tester);
          }
          final icons = tester.widgetList<NexaIconButton>(
            find.byType(NexaIconButton),
          );
          for (final b in icons.where((b) => b.onPressed == null)) {
            // Back / forward are working buttons that are only disabled
            // when there is no history.
            if (b.label == S.navBack || b.label == S.navForward) {
              continue;
            }
            expect(b.disabledReason, isNotNull, reason: b.label);
          }
          final pills = tester.widgetList<NexaPillButton>(
            find.byType(NexaPillButton),
          );
          for (final p in pills.where((p) => p.onPressed == null)) {
            expect(p.disabledReason, isNotNull, reason: p.label);
          }
        }
        // Without a song the favourite (bottom player) is muted, with a
        // reason; Now Playing offers "Go to library" instead.
        expect(
          find.byTooltip('${S.like} - ${S.nothingToPlay}'),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: find.byKey(pageKey),
            matching: find.text(S.goToLibrary),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: find.byKey(pageKey),
            matching: find.byIcon(Icons.favorite_rounded),
          ),
          findsNothing,
          reason: 'no fake "liked" state on Now Playing',
        );
      },
    );
  }
}
