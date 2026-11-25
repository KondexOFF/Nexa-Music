// Screenshots for the README: the real app with a demo library of invented
// songs and artists (no real people, no user data), captured from Flutter's
// own picture of the window - nothing from the desktop around it.
//
//   flutter test integration_test/readme_screenshots_test.dart -d windows
//
// Writes PNG files to ../_readme_shots next to the repository. A temporary
// profile; every demo file is silence (silent run). Not part of AutoTest.
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:media_kit/media_kit.dart' show MediaKit;
import 'package:nexa_music/app/app.dart';
import 'package:nexa_music/app/navigation.dart';
import 'package:nexa_music/core/database/app_database.dart';
import 'package:nexa_music/core/models/listening.dart';
import 'package:nexa_music/features/library/library_providers.dart';
import 'package:nexa_music/features/library/library_repository.dart';
import 'package:nexa_music/features/nexa_dna/dna_providers.dart';
import 'package:nexa_music/features/nexa_wave/wave_controller.dart';
import 'package:nexa_music/features/player/player_controller.dart';
import 'package:path/path.dart' as p;

/// (title, artist, album, genre, seconds)
const List<(String, String, String, String, int)> demo = [
  ('Neon Harbor', 'Aurora Vale', 'Afterglow City', 'Synthwave', 214),
  ('Midnight Lanes', 'Aurora Vale', 'Afterglow City', 'Synthwave', 231),
  ('Chrome Hearts', 'Aurora Vale', 'Afterglow City', 'Synthwave', 198),
  ('Static Sunrise', 'Aurora Vale', 'Afterglow City', 'Synthwave', 245),
  ('Paper Lanterns', 'Kiro Sato', 'Rainy Window', 'Lo-fi', 152),
  ('Tea at Four', 'Kiro Sato', 'Rainy Window', 'Lo-fi', 167),
  ('Slow Tram', 'Kiro Sato', 'Rainy Window', 'Lo-fi', 143),
  ('Bookshop Hum', 'Kiro Sato', 'Rainy Window', 'Lo-fi', 171),
  ('Wildfire Bloom', 'The Velvet Atlas', 'Northern Lines', 'Indie', 224),
  ('Satellites', 'The Velvet Atlas', 'Northern Lines', 'Indie', 203),
  ('Glass Coast', 'The Velvet Atlas', 'Northern Lines', 'Indie', 256),
  ('Low Tide', 'Mira Lune', 'Deep Blue Hours', 'Ambient', 312),
  ('Drift Signal', 'Mira Lune', 'Deep Blue Hours', 'Ambient', 287),
  ('Polar Light', 'Mira Lune', 'Deep Blue Hours', 'Ambient', 341),
  ('Pulse Runner', 'Volt District', 'Overdrive', 'Electronic', 219),
  ('Gridlock', 'Volt District', 'Overdrive', 'Electronic', 207),
  ('Night Shift', 'Volt District', 'Overdrive', 'Electronic', 236),
  ('Golden Hour', 'Sol & Sea', 'Coastline', 'Pop', 189),
  ('Postcards', 'Sol & Sea', 'Coastline', 'Pop', 176),
  ('Summer Static', 'Sol & Sea', 'Coastline', 'Pop', 194),
];

/// A mono 16-bit WAV of silence.
void silentWav(String path, int seconds) {
  const rate = 8000;
  final n = rate * seconds;
  final h = ByteData(44)
    ..setUint32(0, 0x46464952, Endian.little)
    ..setUint32(4, 36 + n * 2, Endian.little)
    ..setUint32(8, 0x45564157, Endian.little)
    ..setUint32(12, 0x20746d66, Endian.little)
    ..setUint32(16, 16, Endian.little)
    ..setUint16(20, 1, Endian.little)
    ..setUint16(22, 1, Endian.little)
    ..setUint32(24, rate, Endian.little)
    ..setUint32(28, rate * 2, Endian.little)
    ..setUint16(32, 2, Endian.little)
    ..setUint16(34, 16, Endian.little)
    ..setUint32(36, 0x61746164, Endian.little)
    ..setUint32(40, n * 2, Endian.little);
  File(path).writeAsBytesSync([...h.buffer.asUint8List(), ...Uint8List(n * 2)]);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  testWidgets('README screenshots', (tester) async {
    final out = Directory(
      p.normalize(p.join(Directory.current.path, '..', '_readme_shots')),
    )..createSync(recursive: true);
    final temp = Directory.systemTemp.createTempSync('nexa_shots');
    final music = Directory(p.join(temp.path, 'Music'))..createSync();
    final db = AppDatabase(
      NativeDatabase(File(p.join(temp.path, 'nexa_library.sqlite'))),
    );
    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        artworkDirProvider.overrideWith(
          (ref) async => p.join(temp.path, 'artwork'),
        ),
        autoRescanProvider.overrideWithValue(false),
      ],
    );
    final boundary = GlobalKey();
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;

    Future<void> settle([int ms = 900]) async {
      final end = DateTime.now().add(Duration(milliseconds: ms));
      while (DateTime.now().isBefore(end)) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 60)),
        );
        await tester.pump(const Duration(milliseconds: 30));
      }
    }

    Future<void> shot(String name) async {
      await settle(1200);
      final render =
          boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final bytes = await tester.runAsync(() async {
        final image = await render.toImage(pixelRatio: 2);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        return data!.buffer.asUint8List();
      });
      File(p.join(out.path, '$name.png')).writeAsBytesSync(bytes!);
      debugPrint('SHOT $name ${bytes.length} bytes');
    }

    try {
      // The demo library, as after an import.
      final ids = <int>[];
      await tester.runAsync(() async {
        for (final (i, (title, artist, album, genre, seconds)) in demo.indexed) {
          final path = p.join(music.path, '${i + 1}.wav');
          silentWav(path, i == 0 ? seconds : 1);
          ids.add(
            await db
                .into(db.tracks)
                .insert(
                  TracksCompanion.insert(
                    pathKey: p.normalize(path).toLowerCase(),
                    path: path,
                    title: title,
                    artist: artist,
                    album: album,
                    genre: Value(genre),
                    trackNumber: Value(i % 4 + 1),
                    year: const Value(2025),
                    durationMs: Value(seconds * 1000),
                    fileSize: File(path).lengthSync(),
                    fileModified: DateTime(2026),
                    searchText: '$title $artist $album'.toLowerCase(),
                    addedAt: DateTime(2026, 11, 1).add(Duration(hours: i)),
                  ),
                ),
          );
        }
        final lib = LibraryRepository(db);
        for (final i in [0, 4, 8, 11, 17]) {
          await lib.setFavorite(ids[i], true);
        }
        final night = await lib.createPlaylist('Night Drive');
        await lib.addToPlaylist(night, [ids[0], ids[1], ids[14], ids[16], ids[3]]);
        final focus = await lib.createPlaylist('Focus Flow');
        await lib.addToPlaylist(focus, [ids[4], ids[5], ids[11], ids[12], ids[6]]);
        final sunday = await lib.createPlaylist('Sunday Morning');
        await lib.addToPlaylist(sunday, [ids[17], ids[8], ids[18], ids[9]]);
        final taste = container.read(tasteRepositoryProvider);
        for (final g in ['Synthwave', 'Lo-fi', 'Ambient']) {
          await taste.setItem(TasteKind.genre, g);
        }
        await taste.setItem(TasteKind.artist, 'Aurora Vale');
        await taste.setItem(TasteKind.artist, 'Mira Lune');
        final now = DateTime.now();
        for (final (k, i) in [0, 4, 1, 11, 8, 5, 14, 12].indexed) {
          await taste.recordEvent(
            ListeningEvent(
              trackId: ids[i],
              startedAt: now.subtract(Duration(hours: 2 + k * 5)),
              listened: Duration(seconds: demo[i].$5 - 5),
              reason: EndReason.completed,
              context: PlayContext.library,
            ),
          );
        }
      });

      await tester.pumpWidget(
        RepaintBoundary(
          key: boundary,
          child: UncontrolledProviderScope(
            container: container,
            child: const NexaApp(ambientMotion: false),
          ),
        ),
      );
      await settle(1500);
      await tester.runAsync(() async {
        final dna = container.read(dnaSettingsProvider.notifier);
        await dna.setHistoryConsent(true);
        await dna.setOnboarded(true);
        final player = container.read(playerProvider.notifier);
        // The demo files are silence: a normal volume shows nicely and
        // still makes no sound.
        await player.setVolume(0.8);
        final lib = LibraryRepository(db);
        final tracks = [for (final id in ids) (await lib.getTrack(id))!];
        await player.playTracks(tracks);
        await Future<void>.delayed(const Duration(seconds: 2));
        await player.seek(const Duration(seconds: 83));
      });
      await settle(1500);

      final nav = container.read(navigationProvider.notifier);
      nav.go(NexaDestination.home);
      await shot('home');
      nav.go(NexaDestination.library);
      await shot('library');
      await tester.runAsync(container.read(waveProvider.notifier).refresh);
      nav.go(NexaDestination.wave);
      await shot('wave');
      nav.go(NexaDestination.nowPlaying);
      await shot('now_playing');
      nav.go(NexaDestination.settings);
      await shot('settings');
    } finally {
      await tester.runAsync(() => container.read(playerProvider.notifier).stop());
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(() async {
        container.dispose();
        await Future<void>.delayed(const Duration(seconds: 1));
        await db.close();
      });
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      try {
        temp.deleteSync(recursive: true);
      } on FileSystemException {
        // Removed later.
      }
    }
  });
}
