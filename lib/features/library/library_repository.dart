import 'package:drift/drift.dart';

import '../../core/database/app_database.dart';
import '../../core/models/track.dart';
import 'library_management.dart';

/// tracks.source of the user's own files.
const String localSource = 'local';

/// Title of a saved YouTube video whose data from YouTube had to be
/// removed (no own name given).
const String youtubeUnnamed = 'YouTube video';

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

  static Track toTrack(TrackRow row) {
    final source = TrackSource.parse(row.source);
    final saved = source != TrackSource.local;
    // Saved catalog / YouTube entries: path_key = '<source>:<id>'. They get
    // the same stable id as the live catalog track (Track.onlineId), so a
    // song is one song whether it comes from Discover or from a playlist.
    final sourceId = saved
        ? row.pathKey.substring(row.pathKey.indexOf(':') + 1)
        : row.pathKey;
    return Track(
      id: saved ? Track.onlineId(source, sourceId) : row.id,
      source: source,
      sourceTrackId: sourceId,
      path: row.path,
      title: (row.userTitle ?? '').trim().isNotEmpty ? row.userTitle! : row.title,
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
      disliked: row.disliked,
      available: row.available,
      problem: row.problem,
      addedAt: row.addedAt,
      pageUrl: row.pageUrl,
      license: row.license,
      licenseUrl: row.licenseUrl,
    );
  }

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
      // Library views show the local files; Favourites also show saved
      // catalog songs and YouTube bookmarks (E2.7).
      Expression<bool> e = filter == TrackFilter.favorites
          ? const Constant(true)
          : t.source.equals(localSource);
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

  Stream<Track?> watchTrack(int id) =>
      (db.select(db.tracks)..where((t) => t.id.equals(id)))
          .watchSingleOrNull()
          .map((row) => row == null ? null : toTrack(row));

  Stream<int> watchTrackCount({TrackFilter filter = TrackFilter.all}) {
    final count = db.tracks.id.count();
    final q = db.selectOnly(db.tracks)..addColumns([count]);
    if (filter == TrackFilter.favorites) {
      q.where(db.tracks.favorite.equals(true));
    } else {
      q.where(db.tracks.source.equals(localSource));
    }
    return q.watchSingle().map((row) => row.read(count) ?? 0);
  }

  Stream<List<LibraryGroup>> watchAlbums() {
    final count = db.tracks.id.count();
    final cover = db.tracks.artworkPath.max();
    final q = db.selectOnly(db.tracks)
      ..addColumns([db.tracks.album, db.tracks.artist, count, cover])
      ..where(db.tracks.source.equals(localSource))
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
      ..where(db.tracks.source.equals(localSource))
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

  /// A like also removes an explicit dislike (NEXA DNA).
  Future<void> setFavorite(int trackId, bool favorite) =>
      (db.update(db.tracks)..where((t) => t.id.equals(trackId))).write(
        TracksCompanion(
          favorite: Value(favorite),
          favoritedAt: Value(favorite ? DateTime.now() : null),
          disliked: favorite ? const Value(false) : const Value.absent(),
          dislikedAt: favorite ? const Value(null) : const Value.absent(),
        ),
      );

  // ---- saved catalog songs and YouTube bookmarks (E2.7) ----

  /// Saves [track] (an Audius / Jamendo song or a YouTube video) so it can
  /// be a favourite or in a playlist; returns its database id. A local
  /// track already has one; an entry saved before keeps its row (the
  /// user's own name, favourite state and data date are not touched).
  Future<int> save(Track track) async {
    if (track.source == TrackSource.local) {
      return track.id;
    }
    final key = track.savedKey;
    final existing = await _savedRow(key);
    if (existing != null) {
      return existing.id;
    }
    final now = DateTime.now();
    return db
        .into(db.tracks)
        .insert(
          TracksCompanion(
            source: Value(track.source.name),
            pathKey: Value(key),
            path: Value(track.path),
            title: Value(track.title),
            artist: Value(track.artist),
            album: Value(track.album),
            genre: Value(track.genre),
            durationMs: Value(track.duration?.inMilliseconds),
            artworkPath: Value(track.artworkPath),
            pageUrl: Value(track.pageUrl),
            license: Value(track.license),
            licenseUrl: Value(track.licenseUrl),
            available: Value(track.available),
            problem: Value(track.problem),
            metaFetchedAt: Value(now),
            fileSize: const Value(0),
            fileModified: Value(now),
            searchText: Value(
              '${track.title} ${track.artist} ${track.album}'.toLowerCase(),
            ),
            addedAt: Value(now),
          ),
        );
  }

  /// Saved YouTube entries whose data from YouTube is older than [maxAge]
  /// (or has no date): refreshed or removed (Developer Policies III.E.4).
  Future<List<TrackRow>> staleYouTube(Duration maxAge) {
    final limit = DateTime.now().subtract(maxAge);
    return (db.select(db.tracks)..where(
          (t) =>
              t.source.equals(TrackSource.youtube.name) &
              (t.metaFetchedAt.isNull() |
                  t.metaFetchedAt.isSmallerThanValue(limit)),
        ))
        .get();
  }

  /// New data from YouTube for a saved video (or none: [title] null keeps
  /// only the video id and the user's own name).
  Future<void> refreshYouTube(
    int rowId, {
    String? title,
    String? channel,
    String? thumbnail,
    bool? available,
    String? problem,
  }) =>
      (db.update(db.tracks)..where((t) => t.id.equals(rowId))).write(
        TracksCompanion(
          title: Value(title ?? youtubeUnnamed),
          artist: Value(channel ?? ''),
          artworkPath: Value(thumbnail),
          metaFetchedAt: Value(title == null ? null : DateTime.now()),
          available: available == null ? const Value.absent() : Value(available),
          problem: Value(problem),
          searchText: Value('${title ?? ''} ${channel ?? ''} youtube'.toLowerCase()),
        ),
      );

  Future<TrackRow?> _savedRow(String key) => (db.select(
    db.tracks,
  )..where((t) => t.pathKey.equals(key))).getSingleOrNull();

  /// Favourite for any track: library files directly, others saved first.
  Future<void> setFavoriteFor(Track track, bool favorite) async {
    if (track.source == TrackSource.local) {
      return setFavorite(track.id, favorite);
    }
    final id = await save(track);
    await setFavorite(id, favorite);
  }

  /// The user's own name for a saved entry; empty = the source's title.
  Future<void> renameSaved(Track track, String name) async {
    final id = await save(track);
    final v = name.trim();
    await (db.update(db.tracks)..where((t) => t.id.equals(id))).write(
      TracksCompanion(userTitle: Value(v.isEmpty ? null : v)),
    );
  }

  /// Removes a saved entry (from favourites and every playlist).
  Future<void> deleteSaved(Track track) async {
    if (track.source == TrackSource.local) {
      return;
    }
    await (db.delete(
      db.tracks,
    )..where((t) => t.pathKey.equals(track.savedKey))).go();
  }

  /// Removes saved YouTube entries nothing refers to any more: not a
  /// favourite, in no playlist, not in the history (E2.7b). Returns how
  /// many were removed.
  Future<int> pruneOrphanYouTube() => db.customUpdate(
    'DELETE FROM tracks WHERE source = ? AND favorite = 0 '
    'AND id NOT IN (SELECT track_id FROM playlist_entries) '
    'AND id NOT IN (SELECT track_id FROM listening_events)',
    variables: [Variable.withString(TrackSource.youtube.name)],
    updates: {db.tracks},
    updateKind: UpdateKind.delete,
  );

  /// Saved (non-library) entries by their stable id - live favourite state
  /// for catalog songs shown in Discover, Wave or the player.
  Stream<Map<int, Track>> watchSaved() =>
      (db.select(db.tracks)..where((t) => t.source.equals(localSource).not()))
          .watch()
          .map((rows) => {for (final r in rows) toTrack(r).id: toTrack(r)});

  /// Adds any tracks (library, catalog, YouTube) to a playlist.
  Future<void> addTracksToPlaylist(int playlistId, List<Track> tracks) async {
    final ids = <int>[];
    for (final t in tracks) {
      ids.add(await save(t));
    }
    await addToPlaylist(playlistId, ids);
  }

  // ---- folders ----

  Stream<List<FolderRow>> watchFolders() =>
      (db.select(db.libraryFolders)
            ..orderBy([(f) => OrderingTerm.asc(f.path.collate(Collate.noCase))]))
          .watch();

  /// Removes a folder and its tracks from the library (playlist entries of
  /// those tracks too). Files on disk are not touched.
  Future<void> removeFolder(int folderId) =>
      LibraryManager(db).removeFolder(folderId);

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
