import 'package:drift/drift.dart';

import '../../core/database/app_database.dart';
import '../../core/models/track.dart';

/// Which subset of the library a list shows.
enum TrackFilter { all, favorites }

enum TrackSort { title, artist, album, recentlyAdded }

/// A playlist with its size (for the sidebar and pages).
class PlaylistInfo {
  const PlaylistInfo({
    required this.id,
    required this.name,
    required this.trackCount,
  });

  final int id;
  final String name;
  final int trackCount;
}

/// One row of a playlist (the same track may appear more than once).
class PlaylistItem {
  const PlaylistItem({required this.entryId, required this.track});

  final int entryId;
  final Track track;
}

/// Album or artist group for the library tabs.
class LibraryGroup {
  const LibraryGroup({
    required this.name,
    required this.subtitle,
    required this.trackCount,
    this.artworkPath,
  });

  final String name;
  final String subtitle;
  final int trackCount;
  final String? artworkPath;
}

/// Queries and changes of the local library. Never touches music files.
class LibraryRepository {
  LibraryRepository(this.db);

  final AppDatabase db;

  static Track toTrack(TrackRow row) => Track(
    id: row.id,
    source: TrackSource.local,
    sourceTrackId: row.pathKey,
    path: row.path,
    title: row.title,
    artist: row.artist,
    album: row.album,
    albumArtist: row.albumArtist,
    genre: row.genre,
    year: row.year,
    trackNumber: row.trackNumber,
    discNumber: row.discNumber,
    duration: row.durationMs == null
        ? null
        : Duration(milliseconds: row.durationMs!),
    artworkPath: row.artworkPath,
    favorite: row.favorite,
    available: row.available,
    problem: row.problem,
    addedAt: row.addedAt,
  );

  static String _likePattern(String query) {
    final escaped = query
        .trim()
        .toLowerCase()
        .replaceAll(r'\', r'\\')
        .replaceAll('%', r'\%')
        .replaceAll('_', r'\_');
    return '%$escaped%';
  }

  SimpleSelectStatement<$TracksTable, TrackRow> _tracksQuery({
    String query = '',
    TrackFilter filter = TrackFilter.all,
    TrackSort sort = TrackSort.artist,
    String? album,
    String? artist,
  }) {
    final q = db.select(db.tracks);
    q.where((t) {
      Expression<bool> e = const Constant(true);
      if (query.trim().isNotEmpty) {
        // Every word must match somewhere (title, artist, album, genre, file).
        for (final word in query.trim().split(RegExp(r'\s+'))) {
          e = e &
              t.searchText.like(_likePattern(word), escapeChar: r'\');
        }
      }
      if (filter == TrackFilter.favorites) {
        e = e & t.favorite.equals(true);
      }
      if (album != null) {
        e = e & t.album.equals(album);
      }
      if (artist != null) {
        e = e & t.artist.equals(artist);
      }
      return e;
    });
    q.orderBy(switch (sort) {
      TrackSort.title => [(t) => OrderingTerm.asc(t.title.collate(Collate.noCase))],
      TrackSort.artist => [
        (t) => OrderingTerm.asc(t.artist.collate(Collate.noCase)),
        (t) => OrderingTerm.asc(t.album.collate(Collate.noCase)),
        (t) => OrderingTerm.asc(t.discNumber),
        (t) => OrderingTerm.asc(t.trackNumber),
        (t) => OrderingTerm.asc(t.title.collate(Collate.noCase)),
      ],
      TrackSort.album => [
        (t) => OrderingTerm.asc(t.album.collate(Collate.noCase)),
        (t) => OrderingTerm.asc(t.discNumber),
        (t) => OrderingTerm.asc(t.trackNumber),
      ],
      TrackSort.recentlyAdded => [
        (t) => OrderingTerm.desc(t.addedAt),
        (t) => OrderingTerm.desc(t.id),
      ],
    });
    return q;
  }

  Stream<List<Track>> watchTracks({
    String query = '',
    TrackFilter filter = TrackFilter.all,
    TrackSort sort = TrackSort.artist,
    String? album,
    String? artist,
  }) => _tracksQuery(
    query: query,
    filter: filter,
    sort: sort,
    album: album,
    artist: artist,
  ).watch().map((rows) => rows.map(toTrack).toList());

  Future<List<Track>> getTracks({
    String query = '',
    TrackFilter filter = TrackFilter.all,
    TrackSort sort = TrackSort.artist,
  }) async => (await _tracksQuery(
    query: query,
    filter: filter,
    sort: sort,
  ).get()).map(toTrack).toList();

  Future<Track?> getTrack(int id) async {
    final row = await (db.select(
      db.tracks,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    return row == null ? null : toTrack(row);
  }

  Stream<int> watchTrackCount({TrackFilter filter = TrackFilter.all}) {
    final count = db.tracks.id.count();
    final q = db.selectOnly(db.tracks)..addColumns([count]);
    if (filter == TrackFilter.favorites) {
      q.where(db.tracks.favorite.equals(true));
    }
    return q.watchSingle().map((row) => row.read(count) ?? 0);
  }

  Stream<List<LibraryGroup>> watchAlbums() {
    final count = db.tracks.id.count();
    final cover = db.tracks.artworkPath.max();
    final q = db.selectOnly(db.tracks)
      ..addColumns([db.tracks.album, db.tracks.artist, count, cover])
      ..groupBy([db.tracks.album])
      ..orderBy([OrderingTerm.asc(db.tracks.album.collate(Collate.noCase))]);
    return q.watch().map(
      (rows) => [
        for (final r in rows)
          LibraryGroup(
            name: r.read(db.tracks.album)!,
            subtitle: r.read(db.tracks.artist) ?? '',
            trackCount: r.read(count) ?? 0,
            artworkPath: r.read(cover),
          ),
      ],
    );
  }

  Stream<List<LibraryGroup>> watchArtists() {
    final count = db.tracks.id.count();
    final albums = db.tracks.album.count(distinct: true);
    final cover = db.tracks.artworkPath.max();
    final q = db.selectOnly(db.tracks)
      ..addColumns([db.tracks.artist, count, albums, cover])
      ..groupBy([db.tracks.artist])
      ..orderBy([OrderingTerm.asc(db.tracks.artist.collate(Collate.noCase))]);
    return q.watch().map(
      (rows) => [
        for (final r in rows)
          LibraryGroup(
            name: r.read(db.tracks.artist)!,
            subtitle: '${r.read(albums) ?? 0}',
            trackCount: r.read(count) ?? 0,
            artworkPath: r.read(cover),
          ),
      ],
    );
  }

  Future<void> setFavorite(int trackId, bool favorite) =>
      (db.update(db.tracks)..where((t) => t.id.equals(trackId))).write(
        TracksCompanion(
          favorite: Value(favorite),
          favoritedAt: Value(favorite ? DateTime.now() : null),
        ),
      );

  // ---- folders ----

  Stream<List<FolderRow>> watchFolders() =>
      (db.select(db.libraryFolders)
            ..orderBy([(f) => OrderingTerm.asc(f.path.collate(Collate.noCase))]))
          .watch();

  /// Removes a folder and its tracks from the library (playlist entries of
  /// those tracks too). Files on disk are not touched.
  Future<void> removeFolder(int folderId) => db.transaction(() async {
    await (db.delete(db.tracks)..where((t) => t.folderId.equals(folderId))).go();
    await (db.delete(
      db.libraryFolders,
    )..where((f) => f.id.equals(folderId))).go();
  });

  // ---- playlists ----

  Stream<List<PlaylistInfo>> watchPlaylists() {
    final (q, count) = _playlistsQuery();
    return q.watch().map((rows) => _toPlaylistInfos(rows, count));
  }

  Future<List<PlaylistInfo>> getPlaylists() async {
    final (q, count) = _playlistsQuery();
    return _toPlaylistInfos(await q.get(), count);
  }

  List<PlaylistInfo> _toPlaylistInfos(
    List<TypedResult> rows,
    Expression<int> count,
  ) => [
    for (final r in rows)
      PlaylistInfo(
        id: r.readTable(db.playlists).id,
        name: r.readTable(db.playlists).name,
        trackCount: r.read(count) ?? 0,
      ),
  ];

  (JoinedSelectStatement<HasResultSet, dynamic>, Expression<int>)
  _playlistsQuery() {
    final count = db.playlistEntries.id.count();
    final q = db.select(db.playlists).join([
      leftOuterJoin(
        db.playlistEntries,
        db.playlistEntries.playlistId.equalsExp(db.playlists.id),
        useColumns: false,
      ),
    ])
      ..addColumns([count])
      ..groupBy([db.playlists.id])
      ..orderBy([OrderingTerm.asc(db.playlists.createdAt), OrderingTerm.asc(db.playlists.id)]);
    return (q, count);
  }

  Stream<PlaylistRow?> watchPlaylist(int id) =>
      (db.select(db.playlists)..where((p) => p.id.equals(id)))
          .watchSingleOrNull();

  Future<int> createPlaylist(String name) {
    final now = DateTime.now();
    return db
        .into(db.playlists)
        .insert(
          PlaylistsCompanion.insert(
            name: _playlistName(name),
            createdAt: now,
            updatedAt: now,
          ),
        );
  }

  static String _playlistName(String name) {
    final trimmed = name.trim();
    final safe = trimmed.isEmpty ? 'New playlist' : trimmed;
    return safe.length > 120 ? safe.substring(0, 120) : safe;
  }

  Future<void> renamePlaylist(int id, String name) =>
      (db.update(db.playlists)..where((p) => p.id.equals(id))).write(
        PlaylistsCompanion(
          name: Value(_playlistName(name)),
          updatedAt: Value(DateTime.now()),
        ),
      );

  /// Deletes the playlist only; tracks stay in the library.
  Future<void> deletePlaylist(int id) =>
      (db.delete(db.playlists)..where((p) => p.id.equals(id))).go();

  Future<void> addToPlaylist(int playlistId, List<int> trackIds) =>
      db.transaction(() async {
        final maxPos = db.playlistEntries.position.max();
        final row = await (db.selectOnly(db.playlistEntries)
              ..addColumns([maxPos])
              ..where(db.playlistEntries.playlistId.equals(playlistId)))
            .getSingle();
        var next = (row.read(maxPos) ?? -1) + 1;
        final now = DateTime.now();
        for (final trackId in trackIds) {
          await db
              .into(db.playlistEntries)
              .insert(
                PlaylistEntriesCompanion.insert(
                  playlistId: playlistId,
                  trackId: trackId,
                  position: next++,
                  addedAt: now,
                ),
              );
        }
        await _touch(playlistId);
      });

  Future<void> removeFromPlaylist(int entryId) => db.transaction(() async {
    final entry = await (db.select(
      db.playlistEntries,
    )..where((e) => e.id.equals(entryId))).getSingleOrNull();
    if (entry == null) {
      return;
    }
    await (db.delete(
      db.playlistEntries,
    )..where((e) => e.id.equals(entryId))).go();
    await _renumber(entry.playlistId);
    await _touch(entry.playlistId);
  });

  /// Moves an entry one place up (-1) or down (+1).
  Future<void> moveEntry(int entryId, int delta) => db.transaction(() async {
    final entry = await (db.select(
      db.playlistEntries,
    )..where((e) => e.id.equals(entryId))).getSingleOrNull();
    if (entry == null) {
      return;
    }
    final entries = await _entries(entry.playlistId);
    final index = entries.indexWhere((e) => e.id == entryId);
    final target = index + delta;
    if (target < 0 || target >= entries.length) {
      return;
    }
    final moved = entries.removeAt(index);
    entries.insert(target, moved);
    for (var i = 0; i < entries.length; i++) {
      await (db.update(db.playlistEntries)
            ..where((e) => e.id.equals(entries[i].id)))
          .write(PlaylistEntriesCompanion(position: Value(i)));
    }
    await _touch(entry.playlistId);
  });

  Future<List<PlaylistEntryRow>> _entries(int playlistId) =>
      (db.select(db.playlistEntries)
            ..where((e) => e.playlistId.equals(playlistId))
            ..orderBy([(e) => OrderingTerm.asc(e.position), (e) => OrderingTerm.asc(e.id)]))
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

  Future<void> _touch(int playlistId) =>
      (db.update(db.playlists)..where((p) => p.id.equals(playlistId))).write(
        PlaylistsCompanion(updatedAt: Value(DateTime.now())),
      );

  Stream<List<PlaylistItem>> watchPlaylistItems(int playlistId) {
    final q = db.select(db.playlistEntries).join([
      innerJoin(db.tracks, db.tracks.id.equalsExp(db.playlistEntries.trackId)),
    ])
      ..where(db.playlistEntries.playlistId.equals(playlistId))
      ..orderBy([
        OrderingTerm.asc(db.playlistEntries.position),
        OrderingTerm.asc(db.playlistEntries.id),
      ]);
    return q.watch().map(
      (rows) => [
        for (final r in rows)
          PlaylistItem(
            entryId: r.readTable(db.playlistEntries).id,
            track: toTrack(r.readTable(db.tracks)),
          ),
      ],
    );
  }
}
