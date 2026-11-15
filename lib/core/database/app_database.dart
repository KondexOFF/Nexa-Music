import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import '../app_paths.dart';

part 'app_database.g.dart';

/// Folders the user added to the library. Files are never copied or deleted;
/// only their paths and metadata are stored.
@DataClassName('FolderRow')
class LibraryFolders extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get path => text()();

  /// Normalised path (lower case on Windows) used to avoid duplicates.
  TextColumn get pathKey => text().unique()();
  DateTimeColumn get addedAt => dateTime()();
  DateTimeColumn get lastScanAt => dateTime().nullable()();
}

@DataClassName('TrackRow')
class Tracks extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get source => text().withDefault(const Constant('local'))();

  /// Normalised path; one row per file however often it is scanned.
  TextColumn get pathKey => text().unique()();
  TextColumn get path => text()();
  IntColumn get folderId => integer().nullable().references(
    LibraryFolders,
    #id,
    onDelete: KeyAction.setNull,
  )();
  TextColumn get title => text()();
  TextColumn get artist => text()();
  TextColumn get album => text()();
  TextColumn get albumArtist => text().nullable()();
  TextColumn get genre => text().nullable()();
  IntColumn get year => integer().nullable()();
  IntColumn get trackNumber => integer().nullable()();
  IntColumn get discNumber => integer().nullable()();
  IntColumn get durationMs => integer().nullable()();
  IntColumn get fileSize => integer()();
  DateTimeColumn get fileModified => dateTime()();
  TextColumn get artworkPath => text().nullable()();

  /// Lower-cased title, artist, album, genre and file name for search
  /// (SQLite LIKE is case-insensitive only for ASCII).
  TextColumn get searchText => text()();
  BoolColumn get favorite => boolean().withDefault(const Constant(false))();
  DateTimeColumn get favoritedAt => dateTime().nullable()();
  BoolColumn get available => boolean().withDefault(const Constant(true))();
  TextColumn get problem => text().nullable()();
  DateTimeColumn get addedAt => dateTime()();

  /// Explicit dislike (NEXA DNA, schema v3): never suggested by NEXA Wave.
  BoolColumn get disliked => boolean().withDefault(const Constant(false))();
  DateTimeColumn get dislikedAt => dateTime().nullable()();

  // v4 (E2.7): saved catalog songs and YouTube bookmarks live in this table
  // too (source != 'local', path_key = '<source>:<id>', no folder, no file).
  // Library views and the scanner only ever look at source = 'local'.

  /// The user's own name for a saved entry (rename); null = [title].
  TextColumn get userTitle => text().nullable()();

  /// Page of the entry at its source (backlink / "Open on YouTube").
  TextColumn get pageUrl => text().nullable()();

  /// Catalog licence name and link (attribution).
  TextColumn get license => text().nullable()();
  TextColumn get licenseUrl => text().nullable()();

  /// When title / artist / artwork were last received from the source's
  /// API. YouTube data is refreshed or removed within 30 days (YouTube API
  /// Services Developer Policies III.E.4.c); the video id and the user's
  /// own name are kept.
  DateTimeColumn get metaFetchedAt => dateTime().nullable()();
}

@DataClassName('PlaylistRow')
class Playlists extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 120)();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
}

@DataClassName('PlaylistEntryRow')
class PlaylistEntries extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get playlistId =>
      integer().references(Playlists, #id, onDelete: KeyAction.cascade)();
  IntColumn get trackId =>
      integer().references(Tracks, #id, onDelete: KeyAction.cascade)();
  IntColumn get position => integer()();
  DateTimeColumn get addedAt => dateTime()();
}

/// Small local settings (volume, shuffle, repeat, output device ...).
@DataClassName('SettingRow')
class AppSettings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

/// One listening of a track (schema v3). Written only with the user's
/// consent, never in a private session or while learning is paused.
@DataClassName('ListeningEventRow')
class ListeningEvents extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get trackId =>
      integer().references(Tracks, #id, onDelete: KeyAction.cascade)();
  DateTimeColumn get startedAt => dateTime()();

  /// How far the track was played (position when it ended).
  IntColumn get listenedMs => integer()();
  IntColumn get durationMs => integer().nullable()();

  /// completed / skipped / stopped ([EndReason] name).
  TextColumn get endReason => text()();

  /// library / wave ([PlayContext] name).
  TextColumn get mode => text()();
}

/// Explicit NEXA DNA choices: liked or excluded genres and artists.
@DataClassName('TasteItemRow')
class TasteItems extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// genre / artist ([TasteKind] name).
  TextColumn get kind => text()();
  TextColumn get value => text()();

  /// Lower-cased [value] (one row per kind and value).
  TextColumn get valueKey => text()();
  RealColumn get weight => real().withDefault(const Constant(1.0))();

  /// True: never suggest tracks with this genre / artist.
  BoolColumn get excluded => boolean().withDefault(const Constant(false))();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  List<Set<Column>> get uniqueKeys => [
    {kind, valueKey},
  ];
}

/// Local SQLite database (Drift). Schema changes must add a migration step
/// in [migration] and bump [schemaVersion].
@DriftDatabase(
  tables: [
    LibraryFolders,
    Tracks,
    Playlists,
    PlaylistEntries,
    AppSettings,
    ListeningEvents,
    TasteItems,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  /// The app's database file in the Windows application-data folder.
  factory AppDatabase.open() => AppDatabase(
    driftDatabase(
      name: 'nexa_library',
      native: const DriftNativeOptions(
        databaseDirectory: appDataDirectory,
      ),
    ),
  );

  @override
  int get schemaVersion => currentSchemaVersion;

  /// Schema of this build (database_safety.dart backs up older files).
  static const int currentSchemaVersion = 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await customStatement(
        'CREATE INDEX IF NOT EXISTS idx_tracks_folder ON tracks (folder_id)',
      );
      await customStatement(
        'CREATE INDEX IF NOT EXISTS idx_entries_playlist '
        'ON playlist_entries (playlist_id, position)',
      );
      await _createHistoryIndex();
    },
    onUpgrade: (m, from, to) async {
      // One step per schema version; never edit a released step.
      if (from < 2) {
        // v2 (Phase 3): player settings.
        await m.createTable(appSettings);
      }
      if (from < 3) {
        // v3 (Phase 5): NEXA DNA - dislikes, listening history, taste.
        await m.addColumn(tracks, tracks.disliked);
        await m.addColumn(tracks, tracks.dislikedAt);
        await m.createTable(listeningEvents);
        await m.createTable(tasteItems);
        await _createHistoryIndex();
      }
      if (from < 4) {
        // v4 (E2.7): saved catalog songs and YouTube bookmarks. One
        // transaction; playlists, their entries and favourites are counted
        // before and after - any difference undoes the whole step.
        await transaction(() async {
          final before = await _keptCounts();
          final existing = {
            for (final r in await customSelect(
              'PRAGMA table_info(tracks)',
            ).get())
              r.read<String>('name'),
          };
          for (final column in [
            tracks.userTitle,
            tracks.pageUrl,
            tracks.license,
            tracks.licenseUrl,
            tracks.metaFetchedAt,
          ]) {
            if (!existing.contains(column.name)) {
              await m.addColumn(tracks, column);
            }
          }
          final after = await _keptCounts();
          if (before.toString() != after.toString()) {
            throw StateError('Migration v4 changed saved data: $before -> $after');
          }
        });
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  /// Counts that a migration must never change.
  Future<Map<String, int>> _keptCounts() async {
    Future<int> count(String sql) async =>
        (await customSelect(sql).getSingle()).read<int>('c');
    return {
      'playlists': await count('SELECT COUNT(*) AS c FROM playlists'),
      'entries': await count('SELECT COUNT(*) AS c FROM playlist_entries'),
      'favorites': await count(
        'SELECT COUNT(*) AS c FROM tracks WHERE favorite = 1',
      ),
      'tracks': await count('SELECT COUNT(*) AS c FROM tracks'),
    };
  }

  Future<void> _createHistoryIndex() async {
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_events_track '
      'ON listening_events (track_id)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_events_started '
      'ON listening_events (started_at)',
    );
  }
}
