import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexa_music/app/app.dart';
import 'package:nexa_music/app/strings.dart';
import 'package:nexa_music/core/database/app_database.dart';
import 'package:nexa_music/features/library/library_actions.dart';
import 'package:nexa_music/features/library/library_page.dart';
import 'package:nexa_music/features/library/library_repository.dart';
import 'package:nexa_music/features/library/playlist_page.dart';
import 'package:nexa_music/features/library/track_list.dart' as tl;

import 'helpers/test_app.dart';

Future<AppDatabase> seededDb(WidgetTester tester) async {
  final db = memoryDatabase();
  await tester.runAsync(() async {
    final now = DateTime(2026, 10, 18);
    const rows = [
      ('Parallel Lines', 'Arielle', 'Skylines'),
      ('Northern Lights', 'Земфира', 'Небо'),
      ('Glass Rivers', 'Elian', 'Skylines'),
    ];
    for (var i = 0; i < rows.length; i++) {
      final (title, artist, album) = rows[i];
      await db
          .into(db.tracks)
          .insert(
            TracksCompanion.insert(
              pathKey: 'c:/music/$i.mp3',
              path: 'C:/Music/$i.mp3',
              title: title,
              artist: artist,
              album: album,
              fileSize: 1000,
              fileModified: now,
              searchText: '$title $artist $album'.toLowerCase(),
              addedAt: now,
              durationMs: const Value(200000),
            ),
          );
    }
    await db
        .into(db.tracks)
        .insert(
          TracksCompanion.insert(
            pathKey: 'c:/music/gone.mp3',
            path: 'C:/Music/gone.mp3',
            title: 'Lost Song',
            artist: 'Arielle',
            album: 'Skylines',
            fileSize: 1000,
            fileModified: now,
            searchText: 'lost song arielle skylines',
            addedAt: now,
            available: const Value(false),
            problem: const Value('File not found'),
          ),
        );
  });
  return db;
}

Future<void> pumpWithDb(
  WidgetTester tester,
  AppDatabase db, {
  List<String>? revealed,
  Size size = size1280,
}) async {
  await loadNexaFonts();
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...testOverrides(database: db),
        if (revealed != null)
          fileRevealerProvider.overrideWithValue((path) async {
            revealed.add(path);
            return RevealResult.file;
          }),
      ],
      child: const NexaApp(ambientMotion: false),
    ),
  );
  await settle(tester);
}

void main() {
  testWidgets('library lists songs, marks missing files, toggles favorites '
      'and searches from the top bar', (tester) async {
    final db = await seededDb(tester);
    await pumpWithDb(tester, db);

    await tester.tap(find.text(S.navLibrary));
    await settle(tester);
    expect(find.byType(LibraryPage), findsOneWidget);
    expect(find.text('Parallel Lines'), findsOneWidget);
    expect(find.text('Northern Lights'), findsOneWidget);
    expect(find.text('File not found - Arielle'), findsOneWidget);

    // Favorite via the heart of the first row.
    await tester.tap(find.byTooltip(S.like).first);
    await settle(tester);
    expect(find.byTooltip(S.unlike), findsOneWidget);

    // Search (Cyrillic, any case) from the top bar.
    await tester.enterText(find.byType(TextField).first, 'ЗЕМ');
    await settle(tester);
    expect(find.text('Northern Lights'), findsOneWidget);
    expect(find.text('Parallel Lines'), findsNothing);

    await tester.tap(find.byTooltip(S.clearSearch));
    await settle(tester);
    expect(find.text('Parallel Lines'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a playlist is created from the sidebar and songs are added '
      'from the song menu', (tester) async {
    final db = await seededDb(tester);
    await pumpWithDb(tester, db);

    await tester.tap(find.byTooltip(S.newPlaylist));
    await settle(tester);
    await tester.enterText(find.byType(TextField).last, 'Evening');
    await tester.tap(find.text(S.create));
    await settle(tester);
    expect(find.byType(PlaylistPage), findsOneWidget);
    expect(find.text(S.playlistEmpty), findsOneWidget);

    await tester.tap(find.text(S.navLibrary));
    await settle(tester);
    await tester.tap(find.byTooltip(S.songActions).first);
    await settle(tester);
    await tester.tap(find.text('${S.addToPlaylist}...'));
    await settle(tester);
    expect(find.text(S.addToPlaylist), findsOneWidget, reason: 'dialog open');
    await tester.tap(find.text('Evening').last);
    await settle(tester);

    final repo = LibraryRepository(db);
    late List<PlaylistInfo> playlists;
    await tester.runAsync(() async {
      playlists = await repo.getPlaylists();
    });
    expect(playlists.single.name, 'Evening');
    expect(playlists.single.trackCount, 1);

    await tester.tap(find.text('Evening').first);
    await settle(tester);
    expect(find.byType(PlaylistPage), findsOneWidget);
    expect(find.text('Lost Song'), findsOneWidget, reason: 'first library row');
    expect(tester.takeException(), isNull);
  });

  testWidgets('D-042: remove a song (file kept), show it in its folder, '
      'restore it from Removed', (tester) async {
    final db = await seededDb(tester);
    final revealed = <String>[];
    await pumpWithDb(tester, db, revealed: revealed, size: size1920);
    await tester.tap(find.text(S.navLibrary));
    await settle(tester);

    // Show in folder: Explorer opens at the file.
    final row = find.ancestor(
      of: find.text('Glass Rivers'),
      matching: find.byType(tl.TrackRow),
    );
    await tester.tap(
      find.descendant(of: row, matching: find.byTooltip(S.songActions)),
    );
    await settle(tester);
    await tester.tap(find.text(S.showInFolder));
    await settle(tester);
    expect(revealed, ['C:/Music/2.mp3']);

    await tester.tap(
      find.descendant(of: row, matching: find.byTooltip(S.songActions)),
    );
    await settle(tester);
    await tester.tap(find.text('${S.removeFromLibrary}...'));
    await settle(tester);
    expect(find.text(S.removeSongsTitle(1)), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, S.remove));
    await settle(tester);
    expect(find.text('Glass Rivers'), findsNothing);
    expect(find.text(S.removedSongs(1)), findsOneWidget);
    expect(find.text('${S.tabRemoved} (1)'), findsOneWidget);

    await tester.tap(find.text('${S.tabRemoved} (1)'));
    await settle(tester);
    expect(find.text('Glass Rivers'), findsOneWidget);
    expect(find.text(S.removedIntro), findsOneWidget);
    await tester.tap(find.text(S.restore));
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump(const Duration(milliseconds: 50));
    }
    await settle(tester);
    expect(find.text(S.removedEmpty), findsOneWidget);
    late List<String> titles;
    await tester.runAsync(() async {
      titles = [
        for (final t in await LibraryRepository(db).getTracks()) t.title,
      ];
    });
    expect(titles, contains('Glass Rivers'));
    expect(find.text(S.restoredSongs(1)), findsWidgets);

    await tester.tap(find.text(S.tabSongs));
    await settle(tester);
    expect(find.text('Glass Rivers'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('D-042: select several songs and remove them at once',
      (tester) async {
    final db = await seededDb(tester);
    await pumpWithDb(tester, db, size: size1920);
    await tester.tap(find.text(S.navLibrary));
    await settle(tester);

    await tester.tap(find.byKey(const ValueKey('library-select')));
    await settle(tester);
    expect(find.byKey(const ValueKey('library-selection-bar')), findsOneWidget);
    expect(find.text(S.selectedCount(0)), findsOneWidget);
    // In selection mode a click picks the song instead of playing it.
    await tester.tap(find.text('Parallel Lines'));
    await settle(tester);
    await tester.tap(find.text('Northern Lights'));
    await settle(tester);
    expect(find.text(S.selectedCount(2)), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('selection-remove')));
    await settle(tester);
    expect(find.text(S.removeSongsTitle(2)), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, S.remove));
    await settle(tester);
    expect(find.text('Parallel Lines'), findsNothing);
    expect(find.text('Northern Lights'), findsNothing);
    expect(find.text('Glass Rivers'), findsOneWidget);
    expect(find.byKey(const ValueKey('library-selection-bar')), findsNothing);
    expect(find.text('${S.tabRemoved} (2)'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('D-042: Clear library empties it after a backup', (tester) async {
    final db = await seededDb(tester);
    await pumpWithDb(tester, db);
    await tester.tap(find.text(S.navLibrary));
    await settle(tester);
    await tester.tap(find.text(S.tabFolders));
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('library-clear')));
    await settle(tester);
    expect(find.text(S.clearLibraryBody), findsOneWidget);
    await tester.runAsync(() async {
      await tester.tap(find.widgetWithText(FilledButton, S.clearLibrary));
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await settle(tester);
    expect(find.text(S.removedSongs(4)), findsOneWidget);
    await tester.tap(find.text(S.tabSongs));
    await settle(tester);
    expect(find.text(S.libraryEmptyTitle), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
