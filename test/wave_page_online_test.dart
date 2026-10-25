import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexa_music/app/app.dart';
import 'package:nexa_music/app/navigation.dart';
import 'package:nexa_music/app/strings.dart';
import 'package:nexa_music/core/database/app_database.dart';
import 'package:nexa_music/core/models/track.dart';
import 'package:nexa_music/features/discover/catalog_providers.dart';
import 'package:nexa_music/features/nexa_dna/dna_providers.dart';
import 'package:nexa_music/features/nexa_wave/wave_controller.dart';
import 'package:nexa_music/features/nexa_wave/wave_page.dart';
import 'package:nexa_music/integrations/music_source.dart';
import 'package:path/path.dart' as p;

import 'helpers/test_app.dart';

class _Catalog implements MusicSource {
  _Catalog({this.error});

  final CatalogException? error;

  @override
  TrackSource get source => TrackSource.audius;

  @override
  bool get configured => true;

  @override
  Future<List<Track>> search(String query, {int limit = 20}) async =>
      const [];

  @override
  Future<List<WaveCandidate>> waveCandidates(WaveRequest request) async {
    if (error != null) {
      throw error!;
    }
    return [
      for (var i = 1; i <= 5; i++)
        WaveCandidate(
          Track(
            id: Track.onlineId(TrackSource.audius, 'w$i'),
            source: TrackSource.audius,
            sourceTrackId: 'w$i',
            path: 'https://stream.example/w$i',
            title: 'Catalog song $i',
            artist: 'Catalog artist $i',
            album: 'Audius',
            duration: const Duration(minutes: 3),
            addedAt: DateTime(2026),
          ),
          S.basisPopular('Audius'),
        ),
    ];
  }
}

/// E1 on the Wave page: the switch, the source badge of catalog picks and
/// the note when the catalogs cannot be reached.
void main() {
  Future<AppDatabase> seeded(WidgetTester tester) async {
    final db = memoryDatabase();
    late Directory temp;
    await tester.runAsync(() async {
      temp = Directory.systemTemp.createTempSync('nexa_wave_online_page');
      final now = DateTime(2026, 10, 25);
      for (var i = 0; i < 6; i++) {
        final path = p.join(temp.path, '$i.mp3');
        File(path).writeAsStringSync('x');
        await db
            .into(db.tracks)
            .insert(
              TracksCompanion.insert(
                pathKey: path.toLowerCase(),
                path: path,
                title: 'Library song $i',
                artist: 'Artist $i',
                album: 'Album $i',
                genre: const Value('Electronic'),
                fileSize: 1,
                fileModified: now,
                searchText: 'library song $i',
                addedAt: now,
                durationMs: const Value(200000),
              ),
            );
      }
    });
    addTearDown(() async {
      await tester.runAsync(() async {
        try {
          temp.deleteSync(recursive: true);
        } on FileSystemException {
          // Best effort on Windows.
        }
      });
    });
    return db;
  }

  Future<ProviderContainer> pumpWave(
    WidgetTester tester,
    AppDatabase db,
    MusicSource catalog,
  ) async {
    await loadNexaFonts();
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1280, 800);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...testOverrides(database: db),
          musicSourcesProvider.overrideWith((ref) => [catalog]),
        ],
        child: const NexaApp(ambientMotion: false),
      ),
    );
    await settle(tester);
    final c = ProviderScope.containerOf(tester.element(find.byType(NexaApp)));
    c.read(navigationProvider.notifier).go(NexaDestination.wave);
    await settle(tester);
    expect(find.byType(WavePage), findsOneWidget);
    return c;
  }

  Future<void> switchOn(WidgetTester tester) async {
    final toggle = find.byKey(const ValueKey('wave-online-switch'));
    await tester.ensureVisible(toggle);
    await settle(tester);
    await tester.tap(toggle);
    await settle(tester);
  }

  testWidgets('the switch adds catalog picks with their source badge',
      (tester) async {
    final db = await seeded(tester);
    final c = await pumpWave(tester, db, _Catalog());
    expect(find.text(S.waveOnline), findsOneWidget);
    expect(c.read(dnaSettingsProvider).waveOnline, isFalse);
    expect(
      c.read(waveProvider).items.any((i) => i.track.isOnline),
      isFalse,
    );

    await switchOn(tester);
    expect(c.read(dnaSettingsProvider).waveOnline, isTrue);
    final items = c.read(waveProvider).items;
    final online = items.where((i) => i.track.isOnline).toList();
    expect(online, isNotEmpty);
    expect(items.first.track.isOnline, isFalse);
    expect(online.first.reason, S.basisPopular('Audius'));
    expect(find.text(S.waveOnlineCount(5)), findsOneWidget);

    final row = find.text(online.first.track.title);
    await tester.scrollUntilVisible(
      row,
      300,
      scrollable: find
          .descendant(
            of: find.byType(WavePage),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await settle(tester);
    expect(find.text('AUDIUS'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('offline catalogs: a clear note, the Wave stays local',
      (tester) async {
    final db = await seeded(tester);
    final c = await pumpWave(
      tester,
      db,
      _Catalog(error: const CatalogException(CatalogErrorKind.offline)),
    );
    await switchOn(tester);
    expect(find.byKey(const ValueKey('wave-online-note')), findsOneWidget);
    expect(
      find.text(S.waveOnlineUnavailable(S.waveOnlineWhyOffline)),
      findsOneWidget,
    );
    final items = c.read(waveProvider).items;
    expect(items, isNotEmpty);
    expect(items.any((i) => i.track.isOnline), isFalse);
    expect(tester.takeException(), isNull);
  });
}
