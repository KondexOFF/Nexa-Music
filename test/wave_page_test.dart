import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexa_music/app/app.dart';
import 'package:nexa_music/app/navigation.dart';
import 'package:nexa_music/app/strings.dart';
import 'package:nexa_music/core/database/app_database.dart';
import 'package:nexa_music/core/models/listening.dart';
import 'package:nexa_music/features/nexa_dna/dna_picker.dart';
import 'package:nexa_music/features/nexa_dna/dna_providers.dart';
import 'package:nexa_music/features/nexa_wave/wave_controller.dart';
import 'package:nexa_music/features/nexa_wave/wave_page.dart';
import 'package:nexa_music/features/player/player_controller.dart';
import 'package:path/path.dart' as p;

import 'helpers/test_app.dart';

/// NEXA Wave page, NEXA DNA picker and the privacy settings in the app.
void main() {
  late Directory temp;

  Future<AppDatabase> seeded(WidgetTester tester) async {
    final db = memoryDatabase();
    await tester.runAsync(() async {
      temp = Directory.systemTemp.createTempSync('nexa_wave_page');
      final now = DateTime(2026, 10, 19);
      const rows = [
        ('Parallel Lines', 'Arielle', 'Electronic'),
        ('Northern Lights', 'Земфира', 'Rock'),
        ('Glass Rivers', 'Elian', 'Electronic'),
        ('Night Drive', 'Arielle', 'Synthwave'),
        ('Slow Tide', 'Mora', 'Ambient'),
      ];
      for (var i = 0; i < rows.length; i++) {
        final (title, artist, genre) = rows[i];
        final path = p.join(temp.path, '$i.mp3');
        File(path).writeAsStringSync('x');
        await db
            .into(db.tracks)
            .insert(
              TracksCompanion.insert(
                pathKey: path.toLowerCase(),
                path: path,
                title: title,
                artist: artist,
                album: 'Album $i',
                genre: Value(genre),
                fileSize: 1,
                fileModified: now,
                searchText: '$title $artist'.toLowerCase(),
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

  Future<ProviderContainer> pumpApp(
    WidgetTester tester,
    AppDatabase db,
    Size size,
  ) async {
    await loadNexaFonts();
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: testOverrides(database: db),
        child: const NexaApp(ambientMotion: false),
      ),
    );
    await settle(tester);
    return ProviderScope.containerOf(tester.element(find.byType(NexaApp)));
  }

  Future<void> openWave(WidgetTester tester, ProviderContainer c) async {
    c.read(navigationProvider.notifier).go(NexaDestination.wave);
    await settle(tester);
    expect(find.byType(WavePage), findsOneWidget);
  }

  for (final size in [size1280, size1920, size1024]) {
    testWidgets('${size.width.round()}: Wave page lays out without errors '
        'and shows picks with reasons', (tester) async {
      final db = await seeded(tester);
      final container = await pumpApp(tester, db, size);
      await openWave(tester, container);
      expect(find.text(S.waveHeading), findsOneWidget);
      expect(find.text(S.familiarDiscovery), findsOneWidget);
      expect(find.text(S.privateSession), findsOneWidget);
      // Five songs, none played yet: all are "new to you".
      final items = container.read(waveProvider).items;
      expect(items, hasLength(5));
      expect(items.every((i) => i.reason == S.reasonNew), isTrue);
      final scrollable = find
          .descendant(
            of: find.byType(WavePage),
            matching: find.byType(Scrollable),
          )
          .first;
      for (var i = 0; i < 8 && find.text(S.reasonNew).evaluate().isEmpty; i++) {
        await tester.drag(scrollable, const Offset(0, -300));
        await settle(tester);
      }
      expect(find.text(S.reasonNew), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Start Wave plays from the Wave and Now Playing explains why',
      (tester) async {
    final db = await seeded(tester);
    final container = await pumpApp(tester, db, size1280);
    await openWave(tester, container);

    await tester.tap(find.text(S.startWave));
    await settle(tester);
    final state = container.read(playerProvider);
    expect(state.context, PlayContext.wave);
    expect(state.current, isNotNull);
    expect(find.text(S.wavePlaying.toUpperCase()), findsOneWidget);

    await tester.tap(find.byTooltip(S.openNowPlaying).first);
    await settle(tester);
    expect(find.textContaining(S.whyThisTrack), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('NEXA DNA picker: like, exclude and clear a genre; consent '
      'switch; closing marks DNA as set up', (tester) async {
    final db = await seeded(tester);
    final container = await pumpApp(tester, db, size1280);
    await openWave(tester, container);

    await tester.tap(find.text(S.editDna));
    await settle(tester);
    expect(find.byType(DnaPickerDialog), findsOneWidget);
    final chip = find.descendant(
      of: find.byType(DnaPickerDialog),
      matching: find.text('Electronic'),
    );
    expect(chip, findsOneWidget);

    Future<List<TasteChoice>> items() async =>
        (await tester.runAsync(
          () => container.read(tasteRepositoryProvider).getItems(),
        ))!;

    await tester.tap(chip);
    await settle(tester);
    expect((await items()).single.excluded, isFalse, reason: 'liked');
    await tester.tap(chip);
    await settle(tester);
    expect((await items()).single.excluded, isTrue, reason: 'excluded');
    await tester.tap(chip);
    await settle(tester);
    expect(await items(), isEmpty, reason: 'cleared');

    await tester.tap(
      find.descendant(
        of: find.byType(DnaPickerDialog),
        matching: find.byType(Switch),
      ),
    );
    await settle(tester);
    expect(container.read(dnaSettingsProvider).historyConsent, isTrue);

    await tester.tap(find.text(S.done));
    await settle(tester);
    expect(find.byType(DnaPickerDialog), findsNothing);
    expect(container.read(dnaSettingsProvider).onboarded, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Settings: privacy switches and reset are available',
      (tester) async {
    final db = await seeded(tester);
    final container = await pumpApp(tester, db, size1280);
    await tester.tap(find.text(S.navSettings));
    await settle(tester);

    final consent = find.text(S.historyConsent);
    await tester.ensureVisible(consent);
    await settle(tester);
    expect(find.text(S.historyCount(0)), findsOneWidget);

    Finder switchOf(String title) => find.descendant(
      of: find.ancestor(of: find.text(title), matching: find.byType(Row)).first,
      matching: find.byType(Switch),
    );

    await tester.tap(switchOf(S.historyConsent));
    await settle(tester);
    expect(container.read(dnaSettingsProvider).historyConsent, isTrue);

    await tester.tap(switchOf(S.privateSession));
    await settle(tester);
    expect(container.read(dnaSettingsProvider).privateSession, isTrue);
    expect(container.read(dnaSettingsProvider).recordsHistory, isFalse);

    await tester.ensureVisible(find.text(S.resetDna));
    await tester.tap(find.text(S.resetDna));
    await settle(tester);
    await tester.tap(find.text(S.reset));
    await settle(tester);
    expect(tester.takeException(), isNull);
  });
}
