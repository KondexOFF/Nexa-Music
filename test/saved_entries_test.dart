import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show MigrationStrategy, Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nexa_music/core/database/app_database.dart';
import 'package:nexa_music/core/database/database_safety.dart';
import 'package:nexa_music/core/models/track.dart';
import 'package:nexa_music/features/library/library_repository.dart';
import 'package:nexa_music/features/youtube/youtube_saved_refresh.dart';
import 'package:nexa_music/features/youtube/youtube_track.dart';
import 'package:nexa_music/integrations/youtube/youtube_oembed.dart';
import 'package:path/path.dart' as p;

/// E2.7a: saved catalog songs and YouTube bookmarks, the v4 migration with
/// its backup, and the 30-day refresh of YouTube data.
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late Directory temp;

  setUp(() => temp = Directory.systemTemp.createTempSync('nexa_saved_test'));
  tearDown(() {
    try {
      temp.deleteSync(recursive: true);
    } on FileSystemException {
      // Best effort on Windows.
    }
  });

  final now = DateTime(2026, 11, 15);

  Future<int> addLocal(AppDatabase db, String name, {bool favorite = false}) =>
      db
          .into(db.tracks)
          .insert(
            TracksCompanion.insert(
              pathKey: 'c:/m/$name.mp3',
              path: 'C:/m/$name.mp3',
              title: name,
              artist: 'Artist',
              album: 'Album',
              fileSize: 1,
              fileModified: now,
              searchText: name.toLowerCase(),
              addedAt: now,
              favorite: Value(favorite),
            ),
          );

  Track audius(String id) => Track(
    id: Track.onlineId(TrackSource.audius, id),
    source: TrackSource.audius,
    sourceTrackId: id,
    path: 'https://api.audius.co/v1/tracks/$id/stream',
    title: 'Catalog $id',
    artist: 'Someone',
    album: 'Audius',
    addedAt: now,
    pageUrl: 'https://audius.co/x/$id',
  );

  Track video(String id) => youtubeTrack(
    videoId: id,
    title: 'Video $id',
    channel: 'Channel',
    thumbnail: 'https://i.ytimg.com/vi/$id/hqdefault.jpg',
  );

  group('migration to schema v4', () {
    test('a copy is made first, playlists and favourites are kept', () async {
      final safety = DatabaseSafety(temp);
      final db = AppDatabase(NativeDatabase(safety.database));
      final a = await addLocal(db, 'A', favorite: true);
      final b = await addLocal(db, 'B');
      final repo = LibraryRepository(db);
      final pl = await repo.createPlaylist('Mine');
      await repo.addToPlaylist(pl, [a, b]);
      // Turn it into a schema v3 database (the 1.0.0 / E2 format).
      for (final sql in [
        'ALTER TABLE tracks DROP COLUMN user_title',
        'ALTER TABLE tracks DROP COLUMN page_url',
        'ALTER TABLE tracks DROP COLUMN license',
        'ALTER TABLE tracks DROP COLUMN license_url',
        'ALTER TABLE tracks DROP COLUMN meta_fetched_at',
        'DROP TABLE library_exclusions',
        'PRAGMA user_version = 3',
      ]) {
        await db.customStatement(sql);
      }
      await db.close();
      expect(DatabaseSafety.schemaOf(safety.database), 3);

      final copy = safety.beforeOpen();
      expect(copy, isNotNull);
      expect(p.basename(copy!.path), startsWith('nexa_library_v3_'));
      expect(DatabaseSafety.schemaOf(copy), 3);

      final upgraded = AppDatabase(NativeDatabase(safety.database));
      final repo2 = LibraryRepository(upgraded);
      final playlists = await repo2.getPlaylists();
      expect(playlists.single.name, 'Mine');
      expect(playlists.single.trackCount, 2);
      final favs = await repo2.getTracks(filter: TrackFilter.favorites);
      expect(favs.map((t) => t.title), ['A']);
      // New columns work.
      await repo2.renameSaved(video('dQw4w9WgXcQ'), 'My name');
      await upgraded.close();
      expect(
        DatabaseSafety.schemaOf(safety.database),
        AppDatabase.currentSchemaVersion,
      );
      // Opening a current file makes no further copy.
      expect(safety.beforeOpen(), isNull);
    });

    test('a failed migration puts the copy back', () async {
      final safety = DatabaseSafety(temp);
      final db = AppDatabase(NativeDatabase(safety.database));
      final a = await addLocal(db, 'A', favorite: true);
      final repo = LibraryRepository(db);
      await repo.addToPlaylist(await repo.createPlaylist('Mine'), [a]);
      for (final sql in [
        'ALTER TABLE tracks DROP COLUMN user_title',
        'ALTER TABLE tracks DROP COLUMN page_url',
        'ALTER TABLE tracks DROP COLUMN license',
        'ALTER TABLE tracks DROP COLUMN license_url',
        'ALTER TABLE tracks DROP COLUMN meta_fetched_at',
        'DROP TABLE library_exclusions',
        'PRAGMA user_version = 3',
      ]) {
        await db.customStatement(sql);
      }
      await db.close();

      DatabaseOpenFailed? failure;
      try {
        await openDatabaseSafely(
          safety: safety,
          open: () => _FailingUpgrade(NativeDatabase(safety.database)),
        );
      } on DatabaseOpenFailed catch (e) {
        failure = e;
      }
      expect(failure?.restoredFrom, isNotNull);
      // The old file is back, byte for byte (opening it with this build
      // would migrate it again, so it is compared, not opened).
      expect(DatabaseSafety.schemaOf(safety.database), 3);
      expect(
        safety.database.readAsBytesSync(),
        File(failure!.restoredFrom!).readAsBytesSync(),
      );

      // The next start with a working build migrates the same file.
      final ok = await openDatabaseSafely(
        safety: safety,
        open: () => AppDatabase(NativeDatabase(safety.database)),
      );
      final favs = await LibraryRepository(ok).getTracks(
        filter: TrackFilter.favorites,
      );
      expect(favs.map((t) => t.title), ['A']);
      await ok.close();
    });

    test('undo puts the copy back', () async {
      final safety = DatabaseSafety(temp);
      final db = AppDatabase(NativeDatabase(safety.database));
      await addLocal(db, 'Kept');
      await db.close();
      final copy = safety.backup('test')!;
      safety.database.writeAsStringSync('broken');
      safety.undo(copy);
      final reopened = AppDatabase(NativeDatabase(safety.database));
      addTearDown(reopened.close);
      final rows = await reopened.select(reopened.tracks).get();
      expect(rows.single.title, 'Kept');
      // The broken file was kept too, as a copy.
      expect(
        safety.list().any((f) => p.basename(f.path).contains('before_restore')),
        isTrue,
      );
    });

    test('a restore requested in Settings happens at the next start', () async {
      final safety = DatabaseSafety(temp);
      var db = AppDatabase(NativeDatabase(safety.database));
      await addLocal(db, 'Old');
      final copy = await safety.backupNow(db);
      await addLocal(db, 'New');
      await db.close();
      safety.requestRestore(copy);
      expect(safety.pendingRestore, p.basename(copy.path));

      safety.beforeOpen();
      expect(safety.pendingRestore, isNull);
      db = AppDatabase(NativeDatabase(safety.database));
      addTearDown(db.close);
      final rows = await db.select(db.tracks).get();
      expect(rows.map((r) => r.title), ['Old']);
    });

    test('only the newest copies are kept', () async {
      final safety = DatabaseSafety(temp);
      final db = AppDatabase(NativeDatabase(safety.database));
      await addLocal(db, 'X');
      await db.close();
      for (var i = 0; i < DatabaseSafety.keep + 3; i++) {
        safety.backup('n$i');
      }
      expect(safety.list(), hasLength(DatabaseSafety.keep));
    });
  });

  group('saved entries', () {
    late AppDatabase db;
    late LibraryRepository repo;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      repo = LibraryRepository(db);
    });
    tearDown(() => db.close());

    test('liked online songs and videos are favourites, not library songs',
        () async {
      await addLocal(db, 'Local');
      await repo.setFavoriteFor(audius('1'), true);
      await repo.setFavoriteFor(video('dQw4w9WgXcQ'), true);

      final library = await repo.getTracks();
      expect(library.map((t) => t.title), ['Local']);
      final favs = await repo.getTracks(filter: TrackFilter.favorites);
      expect(favs.map((t) => t.source), {
        TrackSource.audius,
        TrackSource.youtube,
      });
      // The same stable id as the live catalog track.
      final saved = await repo.watchSaved().first;
      expect(saved[audius('1').id]?.favorite, isTrue);
      expect(saved[video('dQw4w9WgXcQ').id]?.source, TrackSource.youtube);

      await repo.setFavoriteFor(saved[audius('1').id]!, false);
      expect(
        (await repo.watchSaved().first)[audius('1').id]?.favorite,
        isFalse,
      );
    });

    test('playlists hold library, catalog and YouTube entries', () async {
      final a = await addLocal(db, 'Local');
      final pl = await repo.createPlaylist('Mixed');
      final local = (await repo.getTrack(a))!;
      await repo.addTracksToPlaylist(pl, [
        local,
        audius('7'),
        video('dQw4w9WgXcQ'),
      ]);
      // Saving twice keeps one row.
      await repo.addTracksToPlaylist(pl, [video('dQw4w9WgXcQ')]);
      final items = await repo.watchPlaylistItems(pl).first;
      expect(items.map((i) => i.track.source), [
        TrackSource.local,
        TrackSource.audius,
        TrackSource.youtube,
        TrackSource.youtube,
      ]);
      expect(items[2].track.id, items[3].track.id);
      expect(items[2].track.rights.play, isFalse);
      expect(
        (await db.select(db.tracks).get()).length,
        3,
        reason: 'one row per song',
      );

      await repo.renameSaved(video('dQw4w9WgXcQ'), '  Morning song ');
      var named = await repo.watchPlaylistItems(pl).first;
      expect(named[2].track.title, 'Morning song');
      await repo.renameSaved(named[2].track, '');
      named = await repo.watchPlaylistItems(pl).first;
      expect(named[2].track.title, 'Video dQw4w9WgXcQ');

      await repo.deleteSaved(video('dQw4w9WgXcQ'));
      final left = await repo.watchPlaylistItems(pl).first;
      expect(left.map((i) => i.track.title), ['Local', 'Catalog 7']);
    });
  });

  group('30-day refresh of YouTube data', () {
    late AppDatabase db;
    late LibraryRepository repo;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      repo = LibraryRepository(db);
    });
    tearDown(() => db.close());

    Future<void> age(String videoId, int days) async {
      await (db.update(db.tracks)
            ..where((t) => t.pathKey.equals('youtube:$videoId')))
          .write(
            TracksCompanion(
              metaFetchedAt: Value(DateTime.now().subtract(Duration(days: days))),
            ),
          );
    }

    YouTubeOEmbed oembed(Map<String, http.Response> answers) => YouTubeOEmbed(
      MockClient((request) async {
        final url = request.url.queryParameters['url'] ?? '';
        return answers.entries
                .where((e) => url.endsWith(e.key))
                .map((e) => e.value)
                .firstOrNull ??
            http.Response('', 500);
      }),
    );

    test('recent data is not fetched again', () async {
      await repo.setFavoriteFor(video('aaaaaaaaaaa'), true);
      final checked = await refreshSavedYouTube(repo, oembed({}));
      expect(checked, 0);
    });

    test('old data is refreshed; removed videos are marked', () async {
      await repo.setFavoriteFor(video('aaaaaaaaaaa'), true);
      await repo.setFavoriteFor(video('bbbbbbbbbbb'), true);
      await age('aaaaaaaaaaa', 26);
      await age('bbbbbbbbbbb', 26);
      final checked = await refreshSavedYouTube(
        repo,
        oembed({
          'aaaaaaaaaaa': http.Response(
            jsonEncode({
              'title': 'New title',
              'author_name': 'New channel',
              'thumbnail_url': 'https://i.ytimg.com/vi/aaaaaaaaaaa/hq.jpg',
            }),
            200,
          ),
          'bbbbbbbbbbb': http.Response('Not Found', 404),
        }),
      );
      expect(checked, 2);
      final saved = await repo.watchSaved().first;
      final a = saved[video('aaaaaaaaaaa').id]!;
      expect(a.title, 'New title');
      expect(a.artist, 'New channel');
      expect(a.available, isTrue);
      final b = saved[video('bbbbbbbbbbb').id]!;
      expect(b.available, isFalse);
      expect(b.title, youtubeUnnamed);
    });

    test('data older than 30 days is removed when YouTube cannot be reached',
        () async {
      await repo.setFavoriteFor(video('ccccccccccc'), true);
      await repo.setFavoriteFor(video('ddddddddddd'), true);
      await repo.renameSaved(video('ccccccccccc'), 'My own name');
      await age('ccccccccccc', 31);
      await age('ddddddddddd', 27);
      await refreshSavedYouTube(repo, oembed({}));
      final saved = await repo.watchSaved().first;
      final c = saved[video('ccccccccccc').id]!;
      expect(c.title, 'My own name', reason: "the user's own name stays");
      expect(c.artist, isEmpty);
      expect(c.artworkPath, isNull);
      final d = saved[video('ddddddddddd').id]!;
      expect(d.title, 'Video ddddddddddd', reason: 'still within 30 days');
    });
  });
}

/// A build whose migration to v4 fails after its first steps.
class _FailingUpgrade extends AppDatabase {
  _FailingUpgrade(super.e);

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: super.migration.onCreate,
    beforeOpen: super.migration.beforeOpen,
    onUpgrade: (m, from, to) async {
      await super.migration.onUpgrade(m, from, to);
      throw StateError('simulated migration failure');
    },
  );
}
