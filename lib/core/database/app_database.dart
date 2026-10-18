import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:path_provider/path_provider.dart';

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

/// Local SQLite database (Drift). Schema changes must add a migration step
/// in [migration] and bump [schemaVersion].
@DriftDatabase(
  tables: [LibraryFolders, Tracks, Playlists, PlaylistEntries, AppSettings],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  /// The app's database file in the Windows application-data folder.
  factory AppDatabase.open() => AppDatabase(
    driftDatabase(
      name: 'nexa_library',
      native: const DriftNativeOptions(
        databaseDirectory: getApplicationSupportDirectory,
      ),
    ),
  );

  @override
  int get schemaVersion => 2;

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
    },
    onUpgrade: (m, from, to) async {
      // One step per schema version; never edit a released step.
      if (from < 2) {
        // v2 (Phase 3): player settings.
        await m.createTable(appSettings);
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
