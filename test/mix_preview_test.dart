import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexa_music/app/strings.dart';
import 'package:nexa_music/features/mix_engine/mix_preview.dart';

import 'helpers/test_app.dart';

void main() {
  group('MixPreviewController (UI preview only)', () {
    late ProviderContainer container;

    setUp(() => container = ProviderContainer());
    tearDown(() => container.dispose());

    MixPreview state() => container.read(mixPreviewProvider);
    MixPreviewController ctrl() => container.read(mixPreviewProvider.notifier);

    test('defaults to Crossfade 6 s', () {
      expect(state().mode, TransitionMode.crossfade);
      expect(state().crossfadeSeconds, 6);
      expect(state().chipLabel, 'Crossfade 6s');
    });

    test('seconds are clamped to 0..12 and rounded', () {
      ctrl().setSeconds(15);
      expect(state().crossfadeSeconds, 12);
      ctrl().setSeconds(-3);
      expect(state().crossfadeSeconds, 0);
      expect(state().chipLabel, 'Crossfade off');
      ctrl().setSeconds(4.4);
      expect(state().crossfadeSeconds, 4);
    });

    test('gapless has no overlap; crossfade overlap grows with seconds', () {
      ctrl().setMode(TransitionMode.gapless);
      expect(state().overlapFraction, 0);
      expect(state().chipLabel, S.modeGapless);

      ctrl().setMode(TransitionMode.crossfade);
      ctrl().setSeconds(12);
      expect(state().overlapFraction, closeTo(0.5, 1e-9));
      ctrl().setSeconds(0);
      expect(state().overlapFraction, 0);
    });
  });

  testWidgets('choosing Gapless in the panel updates the player chip', (
    tester,
  ) async {
    await pumpNexaApp(tester, size1280);
    expect(find.text('Crossfade 6s'), findsOneWidget);

    await tester.tap(find.byTooltip(S.openNowPlaying).last);
    await settle(tester);
    await tester.tap(find.text(S.modeGapless));
    await settle(tester);

    expect(find.text(S.modeGapless), findsNWidgets(2));
    expect(find.text(S.gaplessNote), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
