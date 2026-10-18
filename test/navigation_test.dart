import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexa_music/app/navigation.dart';
import 'package:nexa_music/app/strings.dart';
import 'package:nexa_music/features/library/library_page.dart';

import 'helpers/test_app.dart';

void main() {
  group('NavigationController', () {
    late ProviderContainer container;
    late NavigationController nav;

    setUp(() {
      container = ProviderContainer();
      nav = container.read(navigationProvider.notifier);
    });
    tearDown(() => container.dispose());

    NavigationState state() => container.read(navigationProvider);

    test('starts on Home with empty history', () {
      expect(state().current, NexaDestination.home);
      expect(state().canGoBack, isFalse);
      expect(state().canGoForward, isFalse);
    });

    test('go / back / forward keep a browser-like history', () {
      nav.go(NexaDestination.library);
      nav.go(NexaDestination.nowPlaying);
      expect(state().current, NexaDestination.nowPlaying);

      nav.goBack();
      expect(state().current, NexaDestination.library);
      expect(state().canGoForward, isTrue);

      nav.goForward();
      expect(state().current, NexaDestination.nowPlaying);

      nav.goBack();
      nav.go(NexaDestination.settings);
      expect(state().canGoForward, isFalse, reason: 'new route clears forward');
    });

    test('going to the current screen does not add history', () {
      nav.go(NexaDestination.home);
      expect(state().canGoBack, isFalse);
    });
  });

  testWidgets('sidebar and top bar arrows navigate between pages', (
    tester,
  ) async {
    await pumpNexaApp(tester, size1280);

    await tester.tap(find.text(S.navLibrary));
    await settle(tester);
    expect(find.byType(LibraryPage), findsOneWidget);

    await tester.tap(find.text(S.navSettings));
    await settle(tester);
    expect(find.text(S.openAudioTest), findsOneWidget);

    await tester.tap(find.byTooltip(S.navBack));
    await settle(tester);
    expect(find.byType(LibraryPage), findsOneWidget);

    await tester.tap(find.byTooltip(S.navBack));
    await settle(tester);
    expect(find.text(S.waveTitle), findsOneWidget);

    await tester.tap(find.byTooltip(S.navForward));
    await settle(tester);
    expect(find.byType(LibraryPage), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('with nothing to play, Play does nothing and explains why', (
    tester,
  ) async {
    await pumpNexaApp(tester, size1280);

    final play = find.byTooltip('${S.playPause} - ${S.nothingToPlay}');
    expect(play, findsOneWidget);
    await tester.tap(play, warnIfMissed: false);
    await settle(tester);

    // Still on Home, nothing started.
    expect(find.text(S.waveTitle), findsOneWidget);
    expect(find.text(S.nothingPlaying), findsOneWidget);
  });

  testWidgets('Recently Played tabs switch the table', (tester) async {
    await pumpNexaApp(tester, size1280);

    expect(find.text(S.colAlbum), findsOneWidget);
    await tester.tap(find.text(S.tabArtists));
    await settle(tester);
    expect(find.text(S.colGenre), findsOneWidget);
    expect(find.text(S.colTopTrack), findsOneWidget);
  });
}
