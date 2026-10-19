import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexa_music/app/app.dart';
import 'package:nexa_music/app/navigation.dart';
import 'package:nexa_music/app/strings.dart';
import 'package:nexa_music/core/models/track.dart';
import 'package:nexa_music/features/discover/catalog_providers.dart';
import 'package:nexa_music/features/discover/discover_controller.dart';
import 'package:nexa_music/features/discover/discover_page.dart';
import 'package:nexa_music/features/nexa_dna/dna_providers.dart';
import 'package:nexa_music/features/player/player_controller.dart';
import 'package:nexa_music/integrations/music_source.dart';

import 'helpers/fake_engine.dart';
import 'helpers/test_app.dart';

/// Catalog stand-in (no network in tests).
class FakeSource implements MusicSource {
  FakeSource(this.source, {this.tracks = const [], this.error});

  @override
  final TrackSource source;
  final List<Track> tracks;
  final CatalogException? error;
  final List<String> queries = [];

  @override
  bool get configured => true;

  @override
  Future<List<Track>> search(String query, {int limit = 20}) async {
    queries.add(query);
    if (error != null) {
      throw error!;
    }
    return tracks;
  }
}

Track online(TrackSource source, String id, {bool available = true}) => Track(
  id: Track.onlineId(source, id),
  source: source,
  sourceTrackId: id,
  path: available ? 'https://stream.example/$id.mp3' : '',
  title: 'Online $id',
  artist: 'Artist $id',
  album: source.label,
  duration: const Duration(minutes: 3),
  available: available,
  problem: available ? null : 'Gated by the artist',
  addedAt: DateTime(2026),
  pageUrl: 'https://page.example/$id',
  license: source == TrackSource.jamendo ? 'CC BY 4.0' : null,
);

void main() {
  group('Discover search', () {
    late ProviderContainer container;
    late FakeSource audius;
    late FakeSource jamendo;

    setUp(() {
      audius = FakeSource(
        TrackSource.audius,
        tracks: [online(TrackSource.audius, 'a1')],
      );
      jamendo = FakeSource(
        TrackSource.jamendo,
        error: const CatalogException(CatalogErrorKind.offline),
      );
      container = ProviderContainer(
        overrides: [
          ...testOverrides(),
          musicSourcesProvider.overrideWithValue([audius, jamendo]),
        ],
      );
    });

    tearDown(() => container.dispose());

    test('one failing catalog does not hide the others', () async {
      await container.read(discoverProvider.notifier).search('night');
      final s = container.read(discoverProvider);
      expect(s.searching, isFalse);
      expect(s.results[TrackSource.audius]!.tracks, hasLength(1));
      expect(s.results[TrackSource.audius]!.error, isNull);
      expect(
        s.results[TrackSource.jamendo]!.error!.kind,
        CatalogErrorKind.offline,
      );
    });

    test('a filter asks only that catalog; an empty query clears', () async {
      final c = container.read(discoverProvider.notifier);
      c.setFilter(TrackSource.audius);
      await c.search('x');
      expect(audius.queries, ['x']);
      expect(jamendo.queries, isEmpty);
      await c.search('  ');
      expect(container.read(discoverProvider).results, isEmpty);
    });
  });

  test('catalog tracks play as streams and are not written to the history',
      () async {
    final engine = FakeEngine();
    final db = memoryDatabase();
    final container = ProviderContainer(
      overrides: [...testOverrides(database: db, engine: engine)],
    );
    addTearDown(container.dispose);
    container.read(playerProvider);
    await container.read(dnaSettingsProvider.notifier).setHistoryConsent(true);
    final tracks = [
      online(TrackSource.audius, 'a1'),
      online(TrackSource.jamendo, 'j1'),
    ];
    await container.read(playerProvider.notifier).playTracks(tracks);
    expect(engine.loads, ['https://stream.example/a1.mp3']);
    expect(container.read(playerProvider).notice, isNull);
    await container.read(playerProvider.notifier).next();
    engine.finishCurrent();
    await pumpEventQueue();
    expect(engine.loads.last, 'https://stream.example/j1.mp3');
    expect(await db.select(db.listeningEvents).get(), isEmpty);
    expect(
      engine.preparedPlan?.kind.name ?? 'cut',
      'cut',
      reason: 'never mixed',
    );
  });

  testWidgets('Discover page: search, source labels, unplayable results, '
      'play and attribution link', (tester) async {
    final opened = <String>[];
    final audius = FakeSource(
      TrackSource.audius,
      tracks: [
        online(TrackSource.audius, 'a1'),
        online(TrackSource.audius, 'a2', available: false),
      ],
    );
    final jamendo = FakeSource(
      TrackSource.jamendo,
      error: const CatalogException(CatalogErrorKind.notConfigured),
    );
    await loadNexaFonts();
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size1280;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...testOverrides(),
          musicSourcesProvider.overrideWithValue([audius, jamendo]),
          linkOpenerProvider.overrideWithValue((url) async {
            opened.add(url);
            return true;
          }),
        ],
        child: const NexaApp(ambientMotion: false),
      ),
    );
    await settle(tester);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(NexaApp)),
    );
    container.read(navigationProvider.notifier).go(NexaDestination.discover);
    await settle(tester);
    expect(find.byType(DiscoverPage), findsOneWidget);
    expect(find.text(S.discoverEmpty), findsOneWidget);

    await tester.enterText(
      find.descendant(
        of: find.byType(DiscoverPage),
        matching: find.byType(TextField),
      ),
      'night',
    );
    await tester.tap(find.text(S.search));
    await settle(tester);

    expect(audius.queries, ['night']);
    expect(find.text('Online a1'), findsOneWidget);
    expect(find.text(S.streamHere), findsOneWidget);
    expect(
      find.text('${S.notPlayableHere}: Gated by the artist'),
      findsOneWidget,
    );
    expect(find.text(S.jamendoNotConfigured), findsOneWidget);

    await tester.tap(find.byTooltip('${S.openPage} ${S.onSource('Audius')}').first);
    await settle(tester);
    expect(opened, ['https://page.example/a1']);

    await tester.tap(find.text('Online a1'));
    await settle(tester);
    final state = container.read(playerProvider);
    expect(state.current?.sourceTrackId, 'a1');
    expect(state.queue, hasLength(1), reason: 'unplayable results not queued');

    container.read(navigationProvider.notifier).go(NexaDestination.nowPlaying);
    await settle(tester);
    expect(find.text(S.noMixOnline), findsOneWidget);
    expect(find.textContaining(S.onSource('Audius')), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
