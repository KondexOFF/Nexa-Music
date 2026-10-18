import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexa_music/app/strings.dart';
import 'package:nexa_music/ui/play_ring_button.dart';

import 'helpers/test_app.dart';

/// Regression tests for the three items the owner reported as FAIL in the
/// Phase 1 manual check: queue button, audio engine test from Settings,
/// Play / Pause hover tooltip.
void main() {
  Finder queueButton() => find.byTooltip(S.toggleQueue);

  Future<void> tapQueue(WidgetTester tester) async {
    await tester.tap(queueButton());
    await settle(tester);
  }

  testWidgets('wide window: queue button hides and shows the right panel', (
    tester,
  ) async {
    await pumpNexaApp(tester, size1280);
    expect(find.text(S.myTaste), findsOneWidget, reason: 'panel shown');

    await tapQueue(tester);
    expect(find.text(S.myTaste), findsNothing, reason: 'panel hidden');

    await tapQueue(tester);
    expect(find.text(S.myTaste), findsOneWidget, reason: 'panel shown again');
    expect(tester.takeException(), isNull);
  });

  testWidgets('wide window, Now Playing: queue button toggles the panel', (
    tester,
  ) async {
    await pumpNexaApp(tester, size1280);
    await tester.tap(find.byTooltip(S.openNowPlaying).last);
    await settle(tester);
    const panel = PageStorageKey<String>('panel-mix');
    expect(find.byKey(panel), findsOneWidget);

    await tapQueue(tester);
    expect(find.byKey(panel), findsNothing);

    await tapQueue(tester);
    expect(find.byKey(panel), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('narrow window: queue button opens and closes the drawer', (
    tester,
  ) async {
    await pumpNexaApp(tester, size1024);
    final scaffold = tester.firstState<ScaffoldState>(find.byType(Scaffold));
    expect(find.text(S.myTaste), findsNothing, reason: 'no right panel');

    await tapQueue(tester);
    expect(scaffold.isEndDrawerOpen, isTrue);
    expect(
      find.descendant(of: find.byType(Drawer), matching: find.text(S.upNext)),
      findsOneWidget,
    );

    // The drawer covers the button; it closes with Escape (or a click on
    // the dimmed area).
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await settle(tester);
    expect(scaffold.isEndDrawerOpen, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Play / Pause shows its tooltip on mouse hover', (tester) async {
    await pumpNexaApp(tester, size1280);
    final ring = find.byType(PlayRingButton);
    expect(ring, findsOneWidget);
    const message = '${S.playPause} - ${S.soonPlayback}';
    expect(find.text(message), findsNothing);

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: Offset.zero);
    await tester.pump();
    await mouse.moveTo(tester.getCenter(ring));
    await tester.pump();
    // Theme wait duration is 350 ms.
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text(message), findsOneWidget);

    // Playback itself stays disabled (Phase 3).
    await tester.tap(ring, warnIfMissed: false);
    await settle(tester);
    expect(find.text(S.waveTitle), findsOneWidget);
  });
}
