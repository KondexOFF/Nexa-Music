import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexa_music/app/strings.dart';
import 'package:nexa_music/audio_probe/audio_self_test.dart';
import 'package:nexa_music/audio_probe/probe_screen.dart';
import 'package:nexa_music/ui/play_ring_button.dart';

import 'helpers/semantics_checker.dart';
import 'helpers/test_app.dart';

/// Regression tests for the Phase 1 crash: with an accessibility client
/// active (Windows UI Automation), NEXA Music sent semantics updates that
/// Windows rejected ("N will not be in the tree"), and the app then closed
/// with an access violation in flutter_windows.dll when the queue button,
/// the audio engine test or a tooltip was used.
///
/// These tests turn semantics on (as Windows does when an accessibility
/// client connects) and check every update the way the Windows bridge does.
void main() {
  final binding = SemanticsCheckingBinding();
  final checker = binding.checker;

  late SemanticsHandle semantics;
  late TestGesture mouse;

  /// Starts the app. With [a11yLater], accessibility is switched on while
  /// the app is already running and a tooltip is open - as on the owner's PC, where
  /// Windows turns it on when a UI Automation client connects.
  Future<void> start(
    WidgetTester tester,
    Size size, {
    bool a11yLater = false,
  }) async {
    checker.reset();
    if (!a11yLater) {
      semantics = tester.ensureSemantics();
    }
    await pumpNexaApp(tester, size);
    mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: const Offset(1, 1));
    await tester.pump();
    if (a11yLater) {
      await mouse.moveTo(tester.getCenter(find.byType(PlayRingButton)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      semantics = tester.ensureSemantics();
      await settle(tester);
    }
  }

  Future<void> finish(WidgetTester tester) async {
    await mouse.removePointer();
    await tester.pump();
    semantics.dispose();
    expect(checker.updates, greaterThan(0), reason: 'semantics were on');
    expect(checker.errors, isEmpty, reason: checker.errors.join('\n'));
    expect(tester.takeException(), isNull);
  }

  /// Hovers like a person: move onto the widget and wait for the tooltip.
  Future<void> hover(WidgetTester tester, Finder finder) async {
    checker.step = 'hover ${finder.describeMatch(Plurality.one)}';
    await mouse.moveTo(tester.getCenter(finder));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pump(const Duration(milliseconds: 150));
  }

  /// Hovers every tooltip currently on screen, one after another.
  Future<void> hoverAllTooltips(WidgetTester tester, Size window) async {
    final count = find.byType(Tooltip).evaluate().length;
    for (var i = 0; i < count; i++) {
      final tooltips = find.byType(Tooltip);
      if (i >= tooltips.evaluate().length) {
        break;
      }
      final target = tooltips.at(i);
      final center = tester.getCenter(target);
      if (center.dx < 0 ||
          center.dy < 0 ||
          center.dx > window.width ||
          center.dy > window.height) {
        continue;
      }
      await hover(tester, target);
    }
  }

  Future<void> click(WidgetTester tester, Finder finder) async {
    await hover(tester, finder);
    checker.step = 'click ${finder.describeMatch(Plurality.one)}';
    await tester.tap(finder);
    await settle(tester);
  }

  for (final (size, a11yLater) in [
    (size1280, false),
    (size1024, false),
    (size1280, true),
    (size1024, true),
  ]) {
    final label =
        '${size.width.round()}x${size.height.round()}'
        '${a11yLater ? ' (accessibility switched on later)' : ''}';

    testWidgets('$label: hovering every tooltip on Home and Now Playing '
        'keeps the accessibility tree valid', (tester) async {
      await start(tester, size, a11yLater: a11yLater);
      await hoverAllTooltips(tester, size);
      await click(tester, find.byTooltip(S.mixChipTooltip));
      await hoverAllTooltips(tester, size);
      await finish(tester);
    });

    testWidgets('$label: Play / Pause tooltip, then Mix chip (owner crash '
        'sequence)', (tester) async {
      await start(tester, size, a11yLater: a11yLater);
      await hover(tester, find.byType(PlayRingButton));
      expect(find.text('${S.playPause} - ${S.soonPlayback}'), findsOneWidget);
      await click(tester, find.byTooltip(S.mixChipTooltip));
      expect(find.text(S.waveTitle), findsNothing, reason: 'on Now Playing');
      await finish(tester);
    });

    testWidgets('$label: queue button keeps the accessibility tree valid', (
      tester,
    ) async {
      await start(tester, size, a11yLater: a11yLater);
      final queue = find.byTooltip(S.toggleQueue);
      await click(tester, queue);
      if (size == size1024) {
        // Narrow: the drawer is open; close it like a keyboard user.
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await settle(tester);
      }
      await click(tester, queue);
      await click(tester, find.byTooltip(S.mixChipTooltip));
      await click(tester, queue);
      await click(tester, queue);
      await finish(tester);
    });
  }

  for (final a11yLater in [false, true]) {
    testWidgets(
      'resizing the window across all breakpoints keeps the accessibility '
      'tree valid${a11yLater ? ' (accessibility switched on later)' : ''}',
      (tester) async {
        await start(tester, size1280, a11yLater: a11yLater);
        for (final destination in [S.mixChipTooltip, null]) {
          if (destination != null) {
            await click(tester, find.byTooltip(destination));
          }
          for (final size in [size1024, size1920, size1280, size1024]) {
            checker.step = 'resize to $size';
            tester.view.physicalSize = size;
            await settle(tester);
            await hover(tester, find.byType(PlayRingButton).last);
          }
          tester.view.physicalSize = size1280;
          await settle(tester);
        }
        await finish(tester);
      },
    );

    testWidgets(
      'Settings: audio engine test opens and returns, accessibility tree '
      'valid${a11yLater ? ' (accessibility switched on later)' : ''}',
      (tester) async {
        debugProbePlayerFactory = _SilentProbePlayer.new;
        addTearDown(() => debugProbePlayerFactory = null);
        await start(tester, size1280, a11yLater: a11yLater);
        await click(tester, find.text(S.navSettings));
        await click(tester, find.text(S.openAudioTest));
        expect(find.byType(ProbeScreen), findsOneWidget);

        await click(tester, find.byType(BackButton));
        expect(find.byType(ProbeScreen), findsNothing);
        expect(
          find.text(S.openAudioTest),
          findsOneWidget,
          reason: 'back in app',
        );
        await finish(tester);
      },
    );
  }
}

/// Player stand-in for the audio test screen (no native audio in tests).
class _SilentProbePlayer implements ProbePlayer {
  @override
  Future<void> open(String path) async {}
  @override
  Future<void> play() async {}
  @override
  Future<void> pause() async {}
  @override
  Future<void> seek(Duration position) async {}
  @override
  Future<void> setVolume(double volume) async {}
  @override
  Duration get position => Duration.zero;
  @override
  Duration get duration => Duration.zero;
  @override
  bool get playing => false;
  @override
  double get volume => 100;
  @override
  String? get lastError => null;
}
