import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexa_music/core/database/app_database.dart';
import 'package:nexa_music/core/database/database_safety.dart';
import 'package:nexa_music/core/models/track.dart';
import 'package:nexa_music/features/library/library_management.dart';
import 'package:nexa_music/features/library/library_repository.dart';
import 'package:nexa_music/features/library/library_scanner.dart';
import 'package:nexa_music/features/library/tag_reader.dart';
import 'package:path/path.dart' as p;

import 'helpers/wav.dart';

/// D-042 Local Library Management: songs leave the library (never the
/// disk), stay out after a rescan, come back with favourite and playlist
/// places; folders and the whole library can be removed; schema v5.
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late Directory temp;
  late Directory music;
  late AppDatabase db;
  late LibraryRepository repo;
  late LibraryManager manager;
  late LibraryScanner scanner;

  String wav(String name) => p.join(music.path, 'Album', '$name.wav');

  setUp(() async {
    temp = Directory.systemTemp.createTempSync('nexa_manage_test');
    music = Directory(p.join(temp.path, 'Music'))..createSync();
    for (var i = 1; i <= 6; i++) {
      writeWav(wav('song_$i'), title: 'Song $i', artist: 'Artist', album: 'Album');
    }
    db = AppDatabase(NativeDatabase(File(p.join(temp.path, 'lib.sqlite'))));
    repo = LibraryRepository(db);
    manager = LibraryManager(db);
    scanner = LibraryScanner(
      db: db,
      tagReader: const AudioTagReader(),
      artworkDir: p.join(temp.path, 'artwork'),
    );
    await scanner.addFolder(music.path);
  });

  tearDown(() async {
    await db.close();
    try {
      temp.deleteSync(recursive: true);
    } on FileSystemException {
      // Best effort on Windows.
    }
  });

  Future<Track> song(String title) async =>
      (await repo.getTracks()).firstWhere((t) => t.title == title);

  Future<List<String>> titles() async => [
    for (final t in await repo.getTracks(sort: TrackSort.title)) t.title,
  ];

  Future<List<String>> playlistTitles(int id) async => [
    for (final i in await repo.watchPlaylistItems(id).first) i.track.title,
  ];

  test('removed songs leave the library, never the disk, and stay out of a '
      'rescan', () async {
    final s2 = await song('Song 2');
    final s3 = await song('Song 3');
    expect(await manager.removeFromLibrary([s2.id, s3.id]), 2);

    expect(await titles(), ['Song 1', 'Song 4', 'Song 5', 'Song 6']);
    expect(File(wav('song_2')).existsSync(), isTrue, reason: 'file kept');
    expect(File(wav('song_3')).existsSync(), isTrue, reason: 'file kept');
    final removed = await manager.getExclusions();
    expect(removed.map((r) => r.title).toSet(), {'Song 2', 'Song 3'});

    final report = await scanner.rescanAll();
    expect(report.excluded, 2);
    expect(report.added, 0);
    expect(await titles(), ['Song 1', 'Song 4', 'Song 5', 'Song 6']);
    // Adding the same folder again does not bring them back either.
    await scanner.addFolder(music.path);
    expect((await repo.getTracks()).length, 4);
  });

  test('restore brings favourite and playlist places back in order', () async {
    final s1 = await song('Song 1');
    final s2 = await song('Song 2');
    final s3 = await song('Song 3');
    final s4 = await song('Song 4');
    await repo.setFavorite(s2.id, true);
    final pl = await repo.createPlaylist('Mix');
    await repo.addToPlaylist(pl, [s1.id, s2.id, s3.id, s4.id]);

    await manager.removeFromLibrary([s2.id, s3.id]);
    expect(await playlistTitles(pl), ['Song 1', 'Song 4']);
    expect((await repo.getTracks(filter: TrackFilter.favorites)), isEmpty);

    final ids = [for (final r in await manager.getExclusions()) r.id];
    expect(await manager.restore(ids, scanner), 2);
    expect(await manager.getExclusions(), isEmpty);
    expect((await repo.getTracks()).length, 6);
    expect(
      (await repo.getTracks(filter: TrackFilter.favorites)).map((t) => t.title),
      ['Song 2'],
    );
    expect(await playlistTitles(pl), ['Song 1', 'Song 2', 'Song 3', 'Song 4']);
    // Back in its library folder: a rescan keeps it (no duplicate).
    final report = await scanner.rescanAll();
    expect(report.added, 0);
    expect((await repo.getTracks()).length, 6);
  });

  test('a removed song whose file is gone comes back marked "not found"',
      () async {
    final s5 = await song('Song 5');
    await manager.removeFromLibrary([s5.id]);
    File(wav('song_5')).deleteSync(); // Deleted outside NEXARYVE.
    final ids = [for (final r in await manager.getExclusions()) r.id];
    await manager.restore(ids, scanner);
    final back = await song('Song 5');
    expect(back.available, isFalse);
    expect(back.problem, LibraryScanner.fileNotFound);
  });

  test('a removed file picked again with "Add files" is added again', () async {
    final s6 = await song('Song 6');
    await manager.removeFromLibrary([s6.id]);
    final report = await scanner.addFiles([wav('song_6')]);
    expect(report.added, 1);
    expect(await manager.getExclusions(), isEmpty);
    expect(await titles(), contains('Song 6'));
  });

  test('saved catalog songs are not touched by "Remove from library"',
      () async {
    final saved = await repo.save(
      Track(
        id: Track.onlineId(TrackSource.audius, 'x1'),
        source: TrackSource.audius,
        sourceTrackId: 'x1',
        path: 'https://example.invalid/x1',
        title: 'Catalog',
        artist: 'Someone',
        album: 'Audius',
        addedAt: DateTime(2026),
      ),
    );
    expect(await manager.removeFromLibrary([saved]), 0);
    expect(await manager.getExclusions(), isEmpty);
  });

  test('clear library: folders and songs leave, files, playlists and saved '
      'entries stay', () async {
    final s1 = await song('Song 1');
    final pl = await repo.createPlaylist('Kept');
    await repo.addToPlaylist(pl, [s1.id]);
    await repo.addTracksToPlaylist(pl, [
      Track(
        id: Track.onlineId(TrackSource.audius, 'x2'),
        source: TrackSource.audius,
        sourceTrackId: 'x2',
        path: 'https://example.invalid/x2',
        title: 'Catalog 2',
        artist: 'Someone',
        album: 'Audius',
        addedAt: DateTime(2026),
      ),
    ]);
    await manager.removeFromLibrary([(await song('Song 2')).id]);

    expect(await manager.clearLibrary(), 5);
    expect(await repo.getTracks(), isEmpty);
    expect(await db.select(db.libraryFolders).get(), isEmpty);
    expect(await playlistTitles(pl), ['Catalog 2']);
    expect((await repo.getPlaylists()).single.trackCount, 1);
    for (var i = 1; i <= 6; i++) {
      expect(File(wav('song_$i')).existsSync(), isTrue, reason: 'song_$i kept');
    }
    // The removed list stays: adding the folder again skips Song 2.
    final report = await scanner.addFolder(music.path);
    expect(report.added, 5);
    expect(report.excluded, 1);
  });

  test('removing a folder renumbers the playlists it was in', () async {
    final other = Directory(p.join(temp.path, 'Other'))..createSync();
    writeWav(p.join(other.path, 'x.wav'), title: 'Other', artist: 'A', album: 'B');
    await scanner.addFolder(other.path);
    final pl = await repo.createPlaylist('Both');
    await repo.addToPlaylist(pl, [
      (await song('Song 1')).id,
      (await song('Other')).id,
    ]);
    final folder = (await repo.watchFolders().first).firstWhere(
      (f) => f.path == p.normalize(p.absolute(music.path)),
    );
    final ids = await manager.removeFolder(folder.id);
    expect(ids.length, 6);
    expect(await playlistTitles(pl), ['Other']);
    final entries = await db.select(db.playlistEntries).get();
    expect(entries.single.position, 0);
    expect(File(wav('song_1')).existsSync(), isTrue);
  });

  test('folder of a path: the innermost library folder', () {
    FolderRow f(int id, String key) => FolderRow(
      id: id,
      path: key,
      pathKey: key,
      addedAt: DateTime(2026),
    );
    final folders = [f(1, p.join('m')), f(2, p.join('m', 'a')), f(3, p.join('ma'))];
    expect(LibraryManager.folderOf(p.join('m', 'a', 'x.mp3'), folders), 2);
    expect(LibraryManager.folderOf(p.join('m', 'y.mp3'), folders), 1);
    expect(LibraryManager.folderOf(p.join('mab', 'y.mp3'), folders), isNull);
    expect(LibraryManager.parsePlaces('3:0,4:12,bad,5:'), [(3, 0), (4, 12)]);
  });

  group('schema v5 migration', () {
    test('a v4 library gets a copy first and keeps every row', () async {
      final s1 = await song('Song 1');
      await repo.setFavorite(s1.id, true);
      await repo.addToPlaylist(await repo.createPlaylist('Mine'), [s1.id]);
      await db.close();
      // Move the database into a data folder and make it a v4 file.
      final dataDir = Directory(p.join(temp.path, 'data'))..createSync();
      final safety = DatabaseSafety(dataDir);
      File(p.join(temp.path, 'lib.sqlite')).copySync(safety.database.path);
      final v4 = AppDatabase(NativeDatabase(safety.database));
      await v4.customStatement('DROP TABLE library_exclusions');
      await v4.customStatement('PRAGMA user_version = 4');
      await v4.close();

      final upgraded = await openDatabaseSafely(
        safety: safety,
        open: () => AppDatabase(NativeDatabase(safety.database)),
      );
      final copy = safety.list().single;
      expect(p.basename(copy.path), startsWith('nexa_library_v4_'));
      expect(DatabaseSafety.schemaOf(copy), 4);
      final repo2 = LibraryRepository(upgraded);
      expect((await repo2.getTracks()).length, 6);
      expect((await repo2.getTracks(filter: TrackFilter.favorites)).length, 1);
      expect((await repo2.getPlaylists()).single.trackCount, 1);
      // The new table works.
      final m2 = LibraryManager(upgraded);
      expect(await m2.removeFromLibrary([s1.id]), 1);
      expect((await m2.getExclusions()).single.wasFavorite, isTrue);
      await upgraded.close();
      expect(
        DatabaseSafety.schemaOf(safety.database),
        AppDatabase.currentSchemaVersion,
      );
      // Reopen db for tearDown.
      db = AppDatabase(NativeDatabase.memory());
    });

    test('backups: the newest copy of an older schema is never pruned',
        () async {
      final dataDir = Directory(p.join(temp.path, 'data2'))..createSync();
      final safety = DatabaseSafety(dataDir);
      final live = AppDatabase(NativeDatabase(safety.database));
      await live.into(live.appSettings).insert(
        AppSettingsCompanion.insert(key: 'k', value: 'v'),
      );
      await live.customStatement('PRAGMA user_version = 4');
      final old = await safety.backupNow(live, reason: 'v4');
      await live.customStatement(
        'PRAGMA user_version = ${AppDatabase.currentSchemaVersion}',
      );
      // Older than every later copy.
      old.setLastModifiedSync(DateTime(2026, 1, 1));
      for (var i = 0; i < DatabaseSafety.keep + 3; i++) {
        await safety.backupNow(live, reason: 'before_clear_library');
      }
      await live.close();
      final left = safety.list();
      expect(left.length, DatabaseSafety.keep + 1);
      expect(left.map((f) => f.path), contains(old.path));
      expect(DatabaseSafety.schemaOf(old), 4);
    });
  });
}
