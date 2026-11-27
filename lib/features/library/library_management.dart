import 'dart:io';

import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;

import '../../core/database/app_database.dart';
import 'library_repository.dart' show localSource;
import 'library_scanner.dart';
import 'tag_reader.dart' show pathKeyOf;

/// Removing songs from the library and bringing them back (D-042).
///
/// Only database rows change: music files are never deleted, moved or
/// written. A removed song is remembered in `library_exclusions`, so a
/// rescan does not add it again, and its favourite flag and playlist places
/// are kept there for a restore.
class LibraryManager {
  LibraryManager(this.db);

  final AppDatabase db;

  /// Removed songs, newest first.
  Stream<List<ExclusionRow>> watchExclusions() =>
      (db.select(db.libraryExclusions)..orderBy([
            (e) => OrderingTerm.desc(e.excludedAt),
            (e) => OrderingTerm.desc(e.id),
          ]))
          .watch();

  Future<List<ExclusionRow>> getExclusions() =>
      db.select(db.libraryExclusions).get();

  /// Library songs of a folder (to take them out of the queue first).
  Future<List<int>> trackIdsOfFolder(int folderId) async => [
    for (final r in await (db.select(
      db.tracks,
    )..where((t) => t.folderId.equals(folderId))).get())
      r.id,
  ];

  /// Every library song (not saved catalog songs or YouTube bookmarks).
  Future<List<int>> localTrackIds() async => [
    for (final r in await (db.select(
      db.tracks,
    )..where((t) => t.source.equals(localSource))).get())
      r.id,
  ];

  /// Removes library songs from NEXARYVE (their files stay on the disk).
  /// Saved catalog songs and YouTube bookmarks are left alone. Returns how
  /// many songs were removed.
  Future<int> removeFromLibrary(Iterable<int> trackIds) {
    final ids = trackIds.toSet().toList();
    if (ids.isEmpty) {
      return Future.value(0);
    }
    return db.transaction(() async {
      var removed = 0;
      final touched = <int>{};
      final now = DateTime.now();
      for (var i = 0; i < ids.length; i += 400) {
        final chunk = ids.sublist(i, i + 400 > ids.length ? ids.length : i + 400);
        final rows = await (db.select(db.tracks)..where(
              (t) => t.id.isIn(chunk) & t.source.equals(localSource),
            ))
            .get();
        if (rows.isEmpty) {
          continue;
        }
        final rowIds = [for (final r in rows) r.id];
        final entries = await (db.select(
          db.playlistEntries,
        )..where((e) => e.trackId.isIn(rowIds))).get();
        final places = <int, List<String>>{};
        for (final e in entries) {
          places.putIfAbsent(e.trackId, () => []).add('${e.playlistId}:${e.position}');
          touched.add(e.playlistId);
        }
        for (final r in rows) {
          await db
              .into(db.libraryExclusions)
              .insert(
                LibraryExclusionsCompanion.insert(
                  pathKey: r.pathKey,
                  path: r.path,
                  title: r.title,
                  artist: r.artist,
                  album: r.album,
                  durationMs: Value(r.durationMs),
                  wasFavorite: Value(r.favorite),
                  playlistPlaces: Value((places[r.id] ?? const []).join(',')),
                  excludedAt: now,
                ),
                mode: InsertMode.insertOrReplace,
              );
        }
        // Playlist entries and listening history of these songs go with
        // them (foreign keys, ON DELETE CASCADE).
        await (db.delete(db.tracks)..where((t) => t.id.isIn(rowIds))).go();
        removed += rows.length;
      }
      for (final playlistId in touched) {
        await _renumber(playlistId);
      }
      return removed;
    });
  }

  /// Removes a library folder and its songs from NEXARYVE (not from the
  /// disk). The songs are not added to the removed list: adding the folder
  /// again brings them back. Returns the removed song ids.
  Future<List<int>> removeFolder(int folderId) => db.transaction(() async {
    final ids = await trackIdsOfFolder(folderId);
    final touched = {
      for (final e in await (db.select(
        db.playlistEntries,
      )..where((e) => e.trackId.isIn(ids))).get())
        e.playlistId,
    };
    await (db.delete(db.tracks)..where((t) => t.folderId.equals(folderId))).go();
    await (db.delete(
      db.libraryFolders,
    )..where((f) => f.id.equals(folderId))).go();
    for (final playlistId in touched) {
      await _renumber(playlistId);
    }
    return ids;
  });

  /// Empties the library: every folder and library song leaves NEXARYVE.
  /// Files on the disk, playlists (their saved catalog / YouTube entries),
  /// saved entries and the removed list stay. Returns how many songs left.
  Future<int> clearLibrary() => db.transaction(() async {
    final removed = await db.customUpdate(
      'DELETE FROM tracks WHERE source = ?',
      variables: [Variable.withString(localSource)],
      updates: {db.tracks, db.playlistEntries, db.listeningEvents},
      updateKind: UpdateKind.delete,
    );
    await db.delete(db.libraryFolders).go();
    for (final pl in await db.select(db.playlists).get()) {
      await _renumber(pl.id);
    }
    return removed;
  });

  /// Brings removed songs back: files that exist are read again (in their
  /// library folder, if one contains them); missing files come back marked
  /// "File not found". Favourite and playlist places are put back
  /// (playlists deleted meanwhile are skipped). Returns how many.
  Future<int> restore(Iterable<int> exclusionIds, LibraryScanner scanner) async {
    final ids = exclusionIds.toSet().toList();
    if (ids.isEmpty) {
      return 0;
    }
    final rows = await (db.select(
      db.libraryExclusions,
    )..where((e) => e.id.isIn(ids))).get();
    if (rows.isEmpty) {
      return 0;
    }
    await (db.delete(
      db.libraryExclusions,
    )..where((e) => e.id.isIn(ids))).go();

    final folders = await db.select(db.libraryFolders).get();
    final byFolder = <int?, List<String>>{};
    final absent = <ExclusionRow>[];
    for (final r in rows) {
      if (File(r.path).existsSync()) {
        byFolder.putIfAbsent(folderOf(r.pathKey, folders), () => []).add(r.path);
      } else {
        absent.add(r);
      }
    }
    for (final entry in byFolder.entries) {
      await scanner.indexFiles(entry.value, entry.key);
    }
    final now = DateTime.now();
    for (final r in absent) {
      await db
          .into(db.tracks)
          .insert(
            TracksCompanion.insert(
              pathKey: r.pathKey,
              path: r.path,
              folderId: Value(folderOf(r.pathKey, folders)),
              title: r.title,
              artist: r.artist,
              album: r.album,
              durationMs: Value(r.durationMs),
              fileSize: 0,
              fileModified: r.excludedAt,
              searchText: '${r.title} ${r.artist} ${r.album} ${p.basename(r.path)}'
                  .toLowerCase(),
              available: const Value(false),
              problem: const Value(LibraryScanner.fileNotFound),
              addedAt: now,
            ),
            mode: InsertMode.insertOrIgnore,
          );
    }

    // Favourites and playlist places, in their old order.
    final playlistIds = {
      for (final pl in await db.select(db.playlists).get()) pl.id,
    };
    final places = <(int playlistId, int position, int trackId)>[];
    await db.transaction(() async {
      for (final r in rows) {
        final track = await (db.select(
          db.tracks,
        )..where((t) => t.pathKey.equals(r.pathKey))).getSingleOrNull();
        if (track == null) {
          continue;
        }
        if (r.wasFavorite && !track.favorite) {
          await (db.update(db.tracks)..where((t) => t.id.equals(track.id))).write(
            TracksCompanion(favorite: const Value(true), favoritedAt: Value(now)),
          );
        }
        for (final place in parsePlaces(r.playlistPlaces)) {
          if (playlistIds.contains(place.$1)) {
            places.add((place.$1, place.$2, track.id));
          }
        }
      }
      places.sort((a, b) => a.$2.compareTo(b.$2));
      for (final (playlistId, position, trackId) in places) {
        await _insertAt(playlistId, trackId, position, now);
      }
    });
    return rows.length;
  }

  /// "playlistId:position,..." of [LibraryExclusions.playlistPlaces].
  static List<(int, int)> parsePlaces(String text) => [
    for (final part in text.split(','))
      if (part.contains(':'))
        if ((int.tryParse(part.split(':')[0]), int.tryParse(part.split(':')[1]))
            case (final int id, final int pos))
          (id, pos),
  ];

  /// The library folder that contains [pathKey] (the innermost one), or
  /// null for a single file.
  static int? folderOf(String pathKey, List<FolderRow> folders) {
    FolderRow? best;
    for (final f in folders) {
      final inside =
          pathKey.startsWith('${f.pathKey}${p.separator}') ||
          pathKey.startsWith('${f.pathKey}/') ||
          pathKey == f.pathKey;
      if (inside && (best == null || f.pathKey.length > best.pathKey.length)) {
        best = f;
      }
    }
    return best?.id;
  }

  /// Whether [path] was removed from the library by the user.
  Future<bool> isExcluded(String path) async =>
      await (db.select(db.libraryExclusions)
            ..where((e) => e.pathKey.equals(pathKeyOf(path))))
          .getSingleOrNull() !=
      null;

  Future<void> _insertAt(
    int playlistId,
    int trackId,
    int position,
    DateTime now,
  ) async {
    final entries = await _entries(playlistId);
    final at = position.clamp(0, entries.length);
    final id = await db
        .into(db.playlistEntries)
        .insert(
          PlaylistEntriesCompanion.insert(
            playlistId: playlistId,
            trackId: trackId,
            position: at,
            addedAt: now,
          ),
        );
    final order = [for (final e in entries) e.id]..insert(at, id);
    for (var i = 0; i < order.length; i++) {
      await (db.update(db.playlistEntries)..where((e) => e.id.equals(order[i])))
          .write(PlaylistEntriesCompanion(position: Value(i)));
    }
  }

  Future<List<PlaylistEntryRow>> _entries(int playlistId) =>
      (db.select(db.playlistEntries)
            ..where((e) => e.playlistId.equals(playlistId))
            ..orderBy([
              (e) => OrderingTerm.asc(e.position),
              (e) => OrderingTerm.asc(e.id),
            ]))
          .get();

  Future<void> _renumber(int playlistId) async {
    final entries = await _entries(playlistId);
    for (var i = 0; i < entries.length; i++) {
      if (entries[i].position != i) {
        await (db.update(db.playlistEntries)
              ..where((e) => e.id.equals(entries[i].id)))
            .write(PlaylistEntriesCompanion(position: Value(i)));
      }
    }
  }
}
