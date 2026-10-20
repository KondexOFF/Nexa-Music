import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexa_music/app/app.dart';
import 'package:nexa_music/core/models/track.dart';
import 'package:nexa_music/features/player/player_controller.dart';

import 'helpers/fake_engine.dart';
import 'helpers/test_app.dart';

/// Phase 7 keyboard access: playback shortcuts work app-wide, but never
/// while typing in a text field.
void main() {
  Track stream(int i) => Track(
    id: Track.onlineId(TrackSource.audius, '$i'),
    source: TrackSource.audius,
    sourceTrackId: '$i',
    path: 'https://stream.example/$i.mp3',
    title: 'Song $i',
    artist: 'Artist',
    album: 'Audius',
    addedAt: DateTime(2026),
  );

  Future<(ProviderContainer, FakeEngine)> start(WidgetTester tester) async {
    final engine = FakeEngine();
    await loadNexaFonts();
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size1280;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: testOverrides(engine: engine),
        child: const NexaApp(ambientMotion: false),
      ),
    );
    await settle(tester);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(NexaApp)),
    );
    await container
        .read(playerProvider.notifier)
        .playTracks([stream(1), stream(2), stream(3)]);
    await settle(tester);
    return (container, engine);
  }

  testWidgets('Space, Ctrl + arrows and Ctrl + M control playback',
      (tester) async {
    final (container, engine) = await start(tester);
    PlayerState state() => container.read(playerProvider);
    expect(state().playing, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await settle(tester);
    expect(state().playing, isFalse, reason: 'Space pauses');
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await settle(tester);
    expect(state().playing, isTrue, reason: 'Space resumes');

    Future<void> ctrl(LogicalKeyboardKey key) async {
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(key);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await settle(tester);
    }

    await ctrl(LogicalKeyboardKey.arrowRight);
    expect(state().current!.sourceTrackId, '2');
    await ctrl(LogicalKeyboardKey.arrowLeft);
    expect(state().current!.sourceTrackId, '1');

    final volume = state().volume;
    await ctrl(LogicalKeyboardKey.arrowDown);
    expect(state().volume, closeTo(volume - 0.05, 1e-9));
    await ctrl(LogicalKeyboardKey.keyM);
    expect(state().muted, isTrue);
    expect(engine.volume, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('typing a space in a text field does not pause', (tester) async {
    final (container, _) = await start(tester);
    final field = find.byType(TextField).first;
    await tester.tap(field);
    await settle(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await settle(tester);
    expect(container.read(playerProvider).playing, isTrue);

    // Esc leaves the field; then Space controls playback again.
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await settle(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await settle(tester);
    expect(container.read(playerProvider).playing, isFalse);
  });
}
