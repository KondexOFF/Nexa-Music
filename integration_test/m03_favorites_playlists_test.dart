// M-03 (D-028, automated): like and "add to playlist" from Discover
// (Audius), YouTube and SoundCloud through NEXA's own buttons; the playlist
// is renamed and deleted from its page; everything is in the database file.
//
//   flutter test integration_test/m03_favorites_playlists_test.dart -d windows
//
// The real Audius search API and SoundCloud's oEmbed (internet), the real
// YouTube player in WebView2 (muted); nothing is played otherwise - silent.
// A temporary profile, never the user's data.
import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:media_kit/media_kit.dart' show MediaKit;
import 'package:nexa_music/app/app.dart';
import 'package:nexa_music/app/navigation.dart';
import 'package:nexa_music/app/strings.dart';
import 'package:nexa_music/core/database/app_database.dart';
import 'package:nexa_music/core/models/track.dart';
import 'package:nexa_music/core/settings/settings_repository.dart';
import 'package:nexa_music/features/discover/discover_controller.dart';
import 'package:nexa_music/features/discover/discover_page.dart';
import 'package:nexa_music/features/library/library_providers.dart';
import 'package:nexa_music/features/youtube/youtube_player_controller.dart';
import 'package:nexa_music/features/youtube/youtube_settings.dart';
import 'package:nexa_music/integrations/youtube/youtube_embed.dart';
import 'package:path/path.dart' as p;

const String demoVideo = 'M7lc1UVf-VE';
const String scTrack = 'https://soundcloud.com/forss/flickermood';
const String listName = 'M-03 list';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  testWidgets('M-03: like and add to a playlist from Discover, YouTube and '
      'SoundCloud; rename and delete the playlist', (tester) async {
    final temp = Directory.systemTemp.createTempSync('nexa_m03');
    final profile = Directory(p.join(temp.path, 'profile'))..createSync();
    final db = AppDatabase(
      NativeDatabase(File(p.join(profile.path, 'nexa_library.sqlite'))),
    );
    await tester.runAsync(
      () => SettingsRepository(db).setBool(SettingKeys.youtubeEnabled, true),
    );
    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        artworkDirProvider.overrideWith(
          (ref) async => p.join(profile.path, 'artwork'),
        ),
        autoRescanProvider.overrideWithValue(false),
        youtubeEmbedFactoryProvider.overrideWithValue(
          () async =>
              WindowsYouTubeEmbed(profileDir: p.join(profile.path, 'webview2')),
        ),
      ],
    );
    final result = <String, Object?>{};

    Future<bool> waitFor(
      bool Function() test, {
      Duration timeout = const Duration(seconds: 30),
    }) async {
      final end = DateTime.now().add(timeout);
      while (DateTime.now().isBefore(end)) {
        if (test()) {
          return true;
        }
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)),
        );
        await tester.pump(const Duration(milliseconds: 50));
      }
      return test();
    }

    Future<void> idle([int ms = 500]) =>
        waitFor(() => false, timeout: Duration(milliseconds: ms));

    /// Like + add to [listName] with the buttons inside [row].
    Future<void> likeAndAdd(Finder row, {bool create = false}) async {
      await tester.ensureVisible(row);
      await tester.pump();
      await tester.tap(
        find.descendant(of: row, matching: find.byTooltip(S.like)).first,
      );
      await idle();
      await tester.tap(
        find
            .descendant(
              of: row,
              matching: find.byTooltip('${S.addToPlaylist}...'),
            )
            .first,
      );
      await idle();
      if (create) {
        await tester.tap(find.text('+ ${S.newPlaylist}'));
        await idle();
        await tester.enterText(find.byType(TextField).last, listName);
        await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text(S.create),
        ),
      );
      } else {
        await tester.tap(
          find.descendant(
            of: find.byType(SimpleDialog),
            matching: find.text(listName),
          ),
        );
      }
      await idle(800);
    }

    Future<List<Map<String, Object?>>> rows(String sql) async {
      final r = await tester.runAsync(() => db.customSelect(sql).get());
      return [for (final x in r!) x.data];
    }

    try {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const NexaApp(ambientMotion: false),
        ),
      );
      await waitFor(() => container.read(youtubeSettingsProvider).loaded);

      // 1. Discover (Audius): first result.
      container.read(navigationProvider.notifier).go(NexaDestination.discover);
      await idle(600);
      await tester.runAsync(
        () => container.read(discoverProvider.notifier).search('lofi'),
      );
      final resultKey = RegExp(r'^discover--?\d+$');
      final audiusRow = find.byWidgetPredicate(
        (w) =>
            w.key is ValueKey<String> &&
            resultKey.hasMatch((w.key! as ValueKey<String>).value),
      );
      expect(
        await waitFor(() => audiusRow.evaluate().isNotEmpty,
            timeout: const Duration(seconds: 30)),
        isTrue,
        reason: 'Audius search results',
      );
      await likeAndAdd(audiusRow.first, create: true);

      // 2. YouTube: the watch page of a video (muted).
      final yt = container.read(youtubePlayerProvider.notifier);
      container.read(navigationProvider.notifier).go(NexaDestination.youtube);
      await idle(600);
      await tester.runAsync(yt.open);
      expect(
        await waitFor(() => container.read(youtubePlayerProvider).apiLoaded),
        isTrue,
      );
      await tester.runAsync(
        () => yt.load(demoVideo, title: 'YouTube Developers Live', mute: true),
      );
      await idle(1500);
      await tester.tap(find.byKey(const ValueKey('yt-like')));
      await idle();
      await tester.tap(find.byKey(const ValueKey('yt-add-to-playlist')));
      await idle();
      await tester.tap(
          find.descendant(
            of: find.byType(SimpleDialog),
            matching: find.text(listName),
          ),
        );
      await idle(800);
      await tester.runAsync(yt.close);

      // 3. SoundCloud: a pasted track link (not played).
      container.read(navigationProvider.notifier).go(NexaDestination.discover);
      await idle(600);
      // The page keeps its scroll position from step 1 (the tab buttons are
      // out of view): the SoundCloud section as its tab button sets it.
      container
          .read(discoverSectionProvider.notifier)
          .set(DiscoverSection.soundcloud);
      await idle(600);
      await tester.ensureVisible(find.byKey(const ValueKey('sc-link')));
      await tester.pump();
      await tester.enterText(find.byKey(const ValueKey('sc-link')), scTrack);
      await tester.tap(find.byKey(const ValueKey('sc-open')));
      expect(
        await waitFor(
          () => find.byKey(const ValueKey('sc-title')).evaluate().isNotEmpty,
        ),
        isTrue,
        reason: 'SoundCloud link resolved',
      );
      await likeAndAdd(
        find.ancestor(
          of: find.byKey(const ValueKey('sc-title')),
          matching: find.byType(Row),
        ).last,
      );

      // In the database: three favourites, one of each source, all three
      // in the playlist.
      final favs = await rows(
        'SELECT source, title FROM tracks WHERE favorite = 1 ORDER BY source',
      );
      result['favorites'] = favs;
      expect(
        {for (final f in favs) f['source']},
        {
          TrackSource.audius.name,
          TrackSource.youtube.name,
          TrackSource.soundcloud.name,
        },
      );
      final lists = await rows('SELECT id, name FROM playlists');
      expect(lists, hasLength(1));
      final listId = lists.single['id']! as int;
      final entries = await rows(
        'SELECT t.source AS source FROM playlist_entries e '
        'JOIN tracks t ON t.id = e.track_id WHERE e.playlist_id = $listId',
      );
      result['playlist'] = entries;
      expect(entries, hasLength(3));

      // 4. Rename and delete on the playlist page.
      container
          .read(navigationProvider.notifier)
          .go(NexaDestination.playlist, playlistId: listId);
      await idle(800);
      await tester.tap(find.byTooltip(S.renamePlaylist));
      await idle();
      await tester.enterText(find.byType(TextField).last, 'M-03 renamed');
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text(S.save),
        ),
      );
      await idle(800);
      expect(
        (await rows('SELECT name FROM playlists')).single['name'],
        'M-03 renamed',
      );
      await tester.tap(find.byTooltip(S.deletePlaylist));
      await idle();
      await tester.tap(find.widgetWithText(FilledButton, S.delete));
      await idle(800);
      expect(await rows('SELECT id FROM playlists'), isEmpty);
      expect(
        await rows('SELECT id FROM playlist_entries'),
        isEmpty,
        reason: 'entries go with the playlist',
      );
      expect(
        await rows('SELECT id FROM tracks WHERE favorite = 1'),
        hasLength(3),
        reason: 'favourites stay',
      );
      result['renamedDeleted'] = true;
    } finally {
      debugPrint('M03RESULT ${jsonEncode(result)}');
      await tester.runAsync(
        container.read(youtubePlayerProvider.notifier).close,
      );
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(() async {
        container.dispose();
        await Future<void>.delayed(const Duration(seconds: 1));
        await db.close();
      });
      try {
        temp.deleteSync(recursive: true);
      } on FileSystemException {
        // WebView2 may still hold its profile for a moment.
      }
    }
  });
}
