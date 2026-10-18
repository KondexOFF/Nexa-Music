import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexa_music/core/database/app_database.dart';
import 'package:nexa_music/features/library/library_repository.dart';
import 'package:nexa_music/features/library/library_scanner.dart';
import 'package:nexa_music/features/library/tag_reader.dart';
import 'package:path/path.dart' as p;

import 'helpers/wav.dart';

/// Phase 2 acceptance (Master Plan v1.0): 30+ imported tracks, a playlist
/// and favorites survive a restart; a missing file shows a clear error;
/// rescanning does not create duplicates.
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late Directory temp;
  late Directory music;
  late String dbPath;
  late AppDatabase db;

  AppDatabase openDb() => AppDatabase(NativeDatabase(File(dbPath)));

  LibraryScanner scannerFor(AppDatabase database) => LibraryScanner(
    db: database,
    tagReader: const AudioTagReader(),
    artworkDir: p.join(temp.path, 'artwork'),
  );

  setUp(() {
    temp = Directory.systemTemp.createTempSync('nexa_library_test');
    music = Directory(p.join(temp.path, 'Music'))..createSync();
    dbPath = p.join(temp.path, 'library.sqlite');
    db = openDb();
    for (var i = 1; i <= 35; i++) {
      final sub = i <= 20 ? 'Album One' : p.join('Disc 2', 'Album Two');
      writeWav(
        p.join(music.path, sub, 'track_${i.toString().padLeft(2, '0')}.wav'),
        title: 'Song $i',
        artist: i.isEven ? 'Zemfira' : 'Arielle',
        album: i <= 20 ? 'Album One' : 'Album Two',
      );
    }
    // Not imported: unsupported format.
    File(p.join(music.path, 'notes.txt')).writeAsStringSync('not music');
  });

  tearDown(() async {
    await db.close();
    try {
      temp.deleteSync(recursive: true);
    } on FileSystemException {
      // Best effort on Windows (files may still be locked briefly).
    }
  });

  test('imports 35 files with metadata; favorites and playlist survive a '
      'restart', () async {
    final report = await scannerFor(db).addFolder(music.path);
    expect(report.added, 35);
    expect(report.problems, isEmpty);

    var repo = LibraryRepository(db);
    final tracks = await repo.getTracks(sort: TrackSort.title);
    expect(tracks, hasLength(35));
    final song7 = tracks.firstWhere((t) => t.title == 'Song 7');
    expect(song7.artist, 'Arielle');
    expect(song7.album, 'Album One');
    expect(song7.duration, isNotNull);
    expect(song7.available, isTrue);

    await repo.setFavorite(tracks[0].id, true);
    await repo.setFavorite(tracks[1].id, true);
    final playlistId = await repo.createPlaylist('Road trip');
    await repo.addToPlaylist(playlistId, [
      tracks[2].id,
      tracks[3].id,
      tracks[4].id,
    ]);

    // "Restart": close and reopen the database file.
    await db.close();
    db = openDb();
    repo = LibraryRepository(db);
    expect(await repo.getTracks(), hasLength(35));
    expect(await repo.getTracks(filter: TrackFilter.favorites), hasLength(2));
    final playlists = await repo.watchPlaylists().first;
    expect(playlists.single.name, 'Road trip');
    expect(playlists.single.trackCount, 3);
    final items = await repo.watchPlaylistItems(playlistId).first;
    expect(
      [for (final i in items) i.track.id],
      [tracks[2].id, tracks[3].id, tracks[4].id],
    );
  });

  test('rescanning and re-adding do not create duplicates', () async {
    final scanner = scannerFor(db);
    await scanner.addFolder(music.path);
    final again = await scanner.rescanAll();
    expect(again.added, 0);
    expect(again.unchanged, 35);
    final readd = await scanner.addFolder(music.path);
    expect(readd.added, 0);
    final file = p.join(music.path, 'Album One', 'track_01.wav');
    final loose = await scanner.addFiles([file, file.toUpperCase()]);
    expect(loose.added, 0);
    expect(await LibraryRepository(db).getTracks(), hasLength(35));
  });

  test('a missing file stays in the library with a clear error and comes '
      'back when the file returns', () async {
    final scanner = scannerFor(db);
    await scanner.addFolder(music.path);
    final repo = LibraryRepository(db);
    final track = (await repo.getTracks()).firstWhere(
      (t) => t.title == 'Song 3',
    );
    await repo.setFavorite(track.id, true);

    final file = File(track.path);
    final moved = file.renameSync('${file.path}.moved');
    final report = await scanner.rescanAll();
    expect(report.missing, 1);
    var now = await repo.getTrack(track.id);
    expect(now!.available, isFalse);
    expect(now.problem, LibraryScanner.fileNotFound);
    expect(now.favorite, isTrue, reason: 'favorite kept');

    moved.renameSync(track.path);
    final back = await scanner.rescanAll();
    expect(back.restored, 1);
    now = await repo.getTrack(track.id);
    expect(now!.available, isTrue);
    expect(now.problem, isNull);
    expect(await repo.getTracks(), hasLength(35));
  });

  test('an unplugged / renamed folder marks its songs as unavailable', () async {
    final scanner = scannerFor(db);
    await scanner.addFolder(music.path);
    music.renameSync(p.join(temp.path, 'Music (renamed)'));
    final report = await scanner.rescanAll();
    expect(report.missing, 35);
    final tracks = await LibraryRepository(db).getTracks();
    expect(tracks.every((t) => !t.available), isTrue);
    expect(tracks.first.problem, LibraryScanner.folderNotFound);
  });

  test('a changed file is read again; favorite and id are kept', () async {
    final scanner = scannerFor(db);
    await scanner.addFolder(music.path);
    final repo = LibraryRepository(db);
    final track = (await repo.getTracks()).firstWhere(
      (t) => t.title == 'Song 5',
    );
    await repo.setFavorite(track.id, true);
    writeWav(track.path, title: 'Song 5 (remaster)', artist: 'Arielle');
    File(
      track.path,
    ).setLastModifiedSync(DateTime.now().add(const Duration(minutes: 1)));
    final report = await scanner.rescanAll();
    expect(report.updated, 1);
    final now = await repo.getTrack(track.id);
    expect(now!.title, 'Song 5 (remaster)');
    expect(now.favorite, isTrue);
  });

  test('untagged files use the file name; unsupported files are skipped', () async {
    final untagged = p.join(temp.path, 'Loose', 'My Recording.wav');
    writeWav(untagged);
    final report = await scannerFor(
      db,
    ).addFiles([untagged, p.join(music.path, 'notes.txt')]);
    expect(report.added, 1);
    expect(report.skipped, 1);
    final t = (await LibraryRepository(db).getTracks()).single;
    expect(t.title, 'My Recording');
    expect(t.artist, unknownArtist);
    expect(t.album, unknownAlbum);
  });

  test('search ignores case (also Cyrillic) and matches every word', () async {
    await scannerFor(db).addFolder(music.path);
    final repo = LibraryRepository(db);
    expect(await repo.getTracks(query: 'ZEMF'), hasLength(17));
    // Cyrillic (stored lower-cased by Dart, so case does not matter).
    final now = DateTime.now();
    await db
        .into(db.tracks)
        .insert(
          TracksCompanion.insert(
            pathKey: 'x:/ru.mp3',
            path: 'X:/ru.mp3',
            title: 'Хочешь',
            artist: 'Земфира',
            album: 'Прости меня моя любовь',
            fileSize: 1,
            fileModified: now,
            searchText: 'хочешь земфира прости меня моя любовь',
            addedAt: now,
          ),
        );
    expect(await repo.getTracks(query: 'ЗЕМФ'), hasLength(1));
    expect(await repo.getTracks(query: 'song 1'), hasLength(13));
    expect(await repo.getTracks(query: 'arielle album two'), hasLength(8));
    expect(await repo.getTracks(query: '100%'), isEmpty);
  });

  test('playlist order can be changed; deleting a playlist keeps the songs', () async {
    await scannerFor(db).addFolder(music.path);
    final repo = LibraryRepository(db);
    final t = await repo.getTracks(sort: TrackSort.title);
    final id = await repo.createPlaylist('  ');
    expect((await repo.watchPlaylist(id).first)!.name, 'New playlist');
    await repo.addToPlaylist(id, [t[0].id, t[1].id, t[2].id]);
    var items = await repo.watchPlaylistItems(id).first;
    await repo.moveEntry(items[2].entryId, -1);
    items = await repo.watchPlaylistItems(id).first;
    expect([for (final i in items) i.track.id], [t[0].id, t[2].id, t[1].id]);
    await repo.removeFromPlaylist(items[0].entryId);
    items = await repo.watchPlaylistItems(id).first;
    expect([for (final i in items) i.track.id], [t[2].id, t[1].id]);
    await repo.deletePlaylist(id);
    expect(await repo.watchPlaylists().first, isEmpty);
    expect(await repo.getTracks(), hasLength(35));
  });

  test('removing a folder removes its songs from the library only', () async {
    await scannerFor(db).addFolder(music.path);
    final repo = LibraryRepository(db);
    final folder = (await repo.watchFolders().first).single;
    await repo.removeFolder(folder.id);
    expect(await repo.getTracks(), isEmpty);
    expect(
      File(p.join(music.path, 'Album One', 'track_01.wav')).existsSync(),
      isTrue,
      reason: 'files on disk are never deleted',
    );
  });
}
