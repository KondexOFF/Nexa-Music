import 'dart:io';

import 'package:drift/drift.dart' show DatabaseConnection, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:nexa_music/app/app.dart';
import 'package:nexa_music/core/audio/audio_analyzer.dart';
import 'package:nexa_music/core/database/app_database.dart';
import 'package:nexa_music/features/library/library_providers.dart';
import 'package:nexa_music/features/player/player_controller.dart';
import 'package:nexa_music/features/update/update_controller.dart';
import 'package:nexa_music/features/update/update_installer.dart';

import 'fake_engine.dart';
import 'fake_update_source.dart';

/// In-memory database for widget tests. Streams close synchronously, so no
/// drift timer is left pending when a test ends.
AppDatabase memoryDatabase() => AppDatabase(
  DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true),
);

/// Provider overrides for widget tests: an empty in-memory database instead
/// of the user's library file, and no real app-data folder.
List<Override> testOverrides({AppDatabase? database, FakeEngine? engine}) {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  return [
    appDatabaseProvider.overrideWith((ref) {
      final db = database ?? memoryDatabase();
      ref.onDispose(db.close);
      return db;
    }),
    artworkDirProvider.overrideWith((ref) async => ''),
    autoRescanProvider.overrideWithValue(false),
    // Smart Mix analysis: no decoder (no media_kit player in widget tests).
    audioAnalyzerProvider.overrideWith((ref) {
      final a = AudioAnalyzer(decoder: null);
      ref.onDispose(a.dispose);
      return a;
    }),
    playbackEngineProvider.overrideWith((ref) {
      final e = engine ?? FakeEngine();
      ref.onDispose(e.dispose);
      return e;
    }),
    // NEXA Update Center: no network, no real update folder.
    updateSourceProvider.overrideWithValue(const NoReleasesSource()),
    updatePathsProvider.overrideWith(
      (ref) async {
        final dir = Directory.systemTemp.createTempSync('nexa_updates_test');
        ref.onDispose(() {
          try {
            dir.deleteSync(recursive: true);
          } on FileSystemException {
            // Left for the system to clean.
          }
        });
        return UpdatePaths(dir);
      },
    ),
  ];
}

bool _fontsLoaded = false;

/// Loads the bundled Manrope font so layout tests measure real text widths
/// (the default test font is much wider and would distort overflow checks).
Future<void> loadNexaFonts() async {
  if (_fontsLoaded) {
    return;
  }
  final loader = FontLoader('Manrope');
  for (final weight in [
    'Regular',
    'Medium',
    'SemiBold',
    'Bold',
    'ExtraBold',
  ]) {
    loader.addFont(rootBundle.load('assets/fonts/Manrope-$weight.ttf'));
  }
  await loader.load();
  _fontsLoaded = true;
}

/// Pumps the full app at a logical window [size] with looping decoration
/// animations disabled.
Future<void> pumpNexaApp(WidgetTester tester, Size size) async {
  await loadNexaFonts();
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: testOverrides(),
      child: const NexaApp(ambientMotion: false),
    ),
  );
  await settle(tester);
}

/// Lets transitions and entry animations finish (the app has no endless
/// animation when ambientMotion is false, but pumpAndSettle is avoided to
/// keep the tests deterministic).
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

const Size size1280 = Size(1280, 720);
const Size size1920 = Size(1920, 1080);
const Size size1024 = Size(1024, 640);
