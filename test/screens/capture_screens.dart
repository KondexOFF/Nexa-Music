// E5 visual review tool - not a test of the gate (no `_test.dart` suffix,
// so `flutter test` skips it). Run on its own:
//   flutter test test/screens/capture_screens.dart
// Renders every section with sample data (no private data) and writes PNGs
// to build/nexa_screens/ (ignored by git).
import 'dart:io';
import 'dart:ui' as ui;

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexa_music/app/app.dart';
import 'package:nexa_music/app/navigation.dart';
import 'package:nexa_music/core/database/app_database.dart';
import 'package:nexa_music/core/models/listening.dart';
import 'package:nexa_music/features/library/library_repository.dart';
import 'package:nexa_music/features/nexa_dna/dna_providers.dart';
import 'package:nexa_music/features/player/player_controller.dart';
import 'package:nexa_music/features/soundcloud/soundcloud_player_controller.dart';
import 'package:nexa_music/features/youtube/youtube_track.dart';

import '../helpers/fake_engine.dart';
import '../helpers/test_app.dart';

const _boundary = ValueKey('capture-root');

Future<void> _loadIcons() async {
  final loader = FontLoader('MaterialIcons')
    ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
  await loader.load();
}

Future<void> _seed(AppDatabase db) async {
  final now = DateTime.now();
  final dir = Directory.systemTemp.createTempSync('nexa_capture');
  final songs = [
    ('Midnight Avenue', 'Lumen Drive', 'City Lights', 214),
    ('Glass Horizon', 'Aurora Fields', 'Northern', 247),
    ('Slow Orbit', 'Kepler Sound', 'Satellites', 189),
    ('Paper Boats', 'Maren Lee', 'Harbour', 201),
    ('Neon Rain', 'Lumen Drive', 'City Lights', 232),
    ('Warm Static', 'Tidal Room', 'Low Tide', 263),
    ('Late Train Mix', 'DJ Halden', 'Sessions', 3120),
  ];
  final ids = <int>[];
  for (final (title, artist, album, secs) in songs) {
    final file = File('${dir.path}/$title.flac')..writeAsStringSync('x');
    ids.add(
      await db
          .into(db.tracks)
          .insert(
            TracksCompanion.insert(
              pathKey: file.path.toLowerCase(),
              path: file.path,
              title: title,
              artist: artist,
              album: album,
              fileSize: 1,
              fileModified: now,
              searchText: '$title $artist'.toLowerCase(),
              addedAt: now,
              durationMs: Value(secs * 1000),
              favorite: Value(title.startsWith('G') || title.startsWith('N')),
            ),
          ),
    );
  }
  final repo = LibraryRepository(db);
  final pl = await repo.createPlaylist('Evening drive');
  await repo.addTracksToPlaylist(pl, [
    (await repo.getTrack(ids[0]))!,
    youtubeTrack(videoId: 'dQw4w9WgXcQ', title: 'Live session', channel: 'Studio'),
    soundcloudTrack(
      url: 'https://soundcloud.com/artist/night-drive',
      title: 'Night Drive',
      user: 'Artist',
    ),
    (await repo.getTrack(ids[4]))!,
  ]);
  await repo.createPlaylist('Focus');
  for (var i = 0; i < ids.length; i++) {
    await db
        .into(db.listeningEvents)
        .insert(
          ListeningEventsCompanion.insert(
            trackId: ids[i],
            startedAt: now.subtract(Duration(hours: i * 5)),
            listenedMs: i == 6 ? 1500000 : songs[i].$4 * 1000,
            durationMs: Value(songs[i].$4 * 1000),
            endReason: i == 6 ? EndReason.stopped.name : EndReason.completed.name,
            mode: PlayContext.library.name,
          ),
        );
  }
}

void main() {
  final out = Directory('build/nexa_screens')..createSync(recursive: true);

  for (final size in const [Size(1280, 720), Size(1920, 1080)]) {
    testWidgets('capture ${size.width.toInt()}', (tester) async {
      await loadNexaFonts();
      await _loadIcons();
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      addTearDown(tester.view.reset);
      final db = memoryDatabase();
      await tester.runAsync(() => _seed(db));
      final engine = FakeEngine();
      await tester.pumpWidget(
        RepaintBoundary(
          key: _boundary,
          child: ProviderScope(
            overrides: testOverrides(database: db, engine: engine),
            child: const NexaApp(ambientMotion: false),
          ),
        ),
      );
      await settle(tester);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(NexaApp)),
      );
      await container
          .read(dnaSettingsProvider.notifier)
          .setHistoryConsent(true);
      await settle(tester);

      Future<void> shot(String name) async {
        await settle(tester);
        await tester.runAsync(() async {
          await Future<void>.delayed(const Duration(milliseconds: 200));
        });
        await settle(tester);
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(_boundary),
        );
        await tester.runAsync(() async {
          final ui.Image image = await boundary.toImage();
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          File(
            '${out.path}/${name}_${size.width.toInt()}.png',
          ).writeAsBytesSync(data!.buffer.asUint8List());
        });
      }

      final nav = container.read(navigationProvider.notifier);
      await shot('01_home');
      nav.go(NexaDestination.wave);
      await shot('02_wave');
      nav.go(NexaDestination.discover);
      await shot('03_discover');
      await tester.tap(find.byKey(const ValueKey('discover-youtube')));
      await shot('04_discover_youtube');
      await tester.tap(find.byKey(const ValueKey('discover-soundcloud')));
      await shot('05_discover_soundcloud');
      nav.go(NexaDestination.library);
      await shot('06_library');
      nav.go(NexaDestination.playlist, playlistId: 1);
      await shot('07_playlist');

      // Something playing: bottom player, queue, Now Playing.
      final tracks = await tester.runAsync(
        () => LibraryRepository(db).getTracks(),
      );
      await container.read(playerProvider.notifier).playTracks([
        ...tracks!.take(3),
        youtubeTrack(videoId: 'dQw4w9WgXcQ', title: 'Live session', channel: 'Studio'),
        soundcloudTrack(
          url: 'https://soundcloud.com/artist/night-drive',
          title: 'Night Drive',
          user: 'Artist',
        ),
        ...tracks.skip(3),
      ]);
      nav.go(NexaDestination.home);
      await shot('08_home_playing');
      nav.go(NexaDestination.nowPlaying);
      await shot('09_now_playing');
      nav.go(NexaDestination.settings);
      await shot('10_settings');
      await tester.drag(
        find.byKey(const PageStorageKey('page-settings')),
        Offset(0, -size.height * 0.75),
      );
      await shot('11_settings_more');
      await tester.drag(
        find.byKey(const PageStorageKey('page-settings')),
        Offset(0, -size.height * 0.75),
      );
      await shot('12_settings_end');

      await tester.pumpWidget(const SizedBox());
      await settle(tester);
    });
  }
}
