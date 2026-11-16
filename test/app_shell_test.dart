import 'package:flutter_test/flutter_test.dart';
import 'package:nexa_music/app/strings.dart';

import 'helpers/test_app.dart';

void main() {
  for (final size in [size1280, size1920, size1024]) {
    final label = '${size.width.round()}x${size.height.round()}';

    testWidgets('Home renders without layout errors at $label', (
      tester,
    ) async {
      await pumpNexaApp(tester, size);

      expect(tester.takeException(), isNull);
      expect(find.text(S.waveTitle), findsOneWidget);
      expect(find.text(S.yourPlaylists), findsOneWidget);
      expect(find.text(S.recentlyPlayed), findsOneWidget);
      // E5: no DEMO content left on Home.
      expect(find.text(S.demo), findsNothing);
    });

    testWidgets('Now Playing renders without layout errors at $label', (
      tester,
    ) async {
      await pumpNexaApp(tester, size);

      await tester.tap(find.byTooltip(S.openNowPlaying).last);
      await settle(tester);

      expect(tester.takeException(), isNull);
      expect(find.text(S.nowPlaying), findsOneWidget);
      // Mix Engine is either in the right panel or inline below the player.
      expect(find.text(S.mixEngine), findsOneWidget);
    });
  }

  testWidgets('right panel collapses below 1180 px and shows at 1280 px', (
    tester,
  ) async {
    await pumpNexaApp(tester, size1024);
    expect(find.text(S.myTaste), findsNothing);

    await pumpNexaApp(tester, size1280);
    expect(find.text(S.myTaste), findsOneWidget);
  });

  testWidgets(
    'shrinking the window while leaving Now Playing causes no overflow',
    (tester) async {
      await pumpNexaApp(tester, size1920);
      await tester.tap(find.byTooltip(S.openNowPlaying).last);
      await settle(tester);

      // Shrink to the minimum size and go Home in the same moment, then
      // check every frame of the panel / sidebar / page animations.
      tester.view.physicalSize = size1024;
      await tester.tap(find.text(S.navHome));
      for (var i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        expect(tester.takeException(), isNull, reason: 'frame $i');
      }
      expect(find.text(S.waveTitle), findsOneWidget);
    },
  );
}
