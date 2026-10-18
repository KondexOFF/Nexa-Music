import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../core/database/app_database.dart';
import '../../core/models/track.dart';
import 'library_repository.dart';
import 'library_scanner.dart';
import 'tag_reader.dart';

/// The app database. Tests override this with an in-memory database.
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase.open();
  ref.onDispose(db.close);
  return db;
});

final libraryRepositoryProvider = Provider<LibraryRepository>(
  (ref) => LibraryRepository(ref.watch(appDatabaseProvider)),
);

/// Folder for cached cover images (inside the app data folder).
final artworkDirProvider = FutureProvider<String>((ref) async {
  final support = await getApplicationSupportDirectory();
  return p.join(support.path, 'artwork');
});

final tagReaderProvider = Provider<TagReader>((ref) => const AudioTagReader());

/// System dialogs for choosing music. Tests override this.
abstract interface class LibraryPicker {
  Future<String?> pickFolder();
  Future<List<String>> pickFiles();
}

class SystemLibraryPicker implements LibraryPicker {
  const SystemLibraryPicker();

  @override
  Future<String?> pickFolder() =>
      FilePicker.getDirectoryPath(dialogTitle: 'Add a music folder');

  @override
  Future<List<String>> pickFiles() async {
    final files = await FilePicker.pickFiles(
      dialogTitle: 'Add music files',
      type: FileType.custom,
      allowedExtensions: const ['mp3', 'flac', 'wav'],
    );
    return [
      for (final f in files)
        if (f.path != null) f.path!,
    ];
  }
}

final libraryPickerProvider = Provider<LibraryPicker>(
  (ref) => const SystemLibraryPicker(),
);

/// Library search text (top bar and library page share it).
class LibraryQuery extends Notifier<String> {
  @override
  String build() => '';

  void set(String value) => state = value;
}

final libraryQueryProvider = NotifierProvider<LibraryQuery, String>(
  LibraryQuery.new,
);

enum LibraryTab { songs, favorites, albums, artists, folders }

class LibraryTabController extends Notifier<LibraryTab> {
  @override
  LibraryTab build() => LibraryTab.songs;

  void set(LibraryTab tab) => state = tab;
}

final libraryTabProvider = NotifierProvider<LibraryTabController, LibraryTab>(
  LibraryTabController.new,
);

/// Optional album / artist filter chosen from the Albums / Artists tabs.
class GroupFilter {
  const GroupFilter({this.album, this.artist});

  final String? album;
  final String? artist;

  bool get isEmpty => album == null && artist == null;
}

class GroupFilterController extends Notifier<GroupFilter> {
  @override
  GroupFilter build() => const GroupFilter();

  void set(GroupFilter value) => state = value;
}

final groupFilterProvider =
    NotifierProvider<GroupFilterController, GroupFilter>(
      GroupFilterController.new,
    );

final libraryTracksProvider = StreamProvider<List<Track>>((ref) {
  final repo = ref.watch(libraryRepositoryProvider);
  final query = ref.watch(libraryQueryProvider);
  final tab = ref.watch(libraryTabProvider);
  final group = ref.watch(groupFilterProvider);
  return repo.watchTracks(
    query: query,
    filter: tab == LibraryTab.favorites ? TrackFilter.favorites : TrackFilter.all,
    album: group.album,
    artist: group.artist,
  );
});

final trackProvider = StreamProvider.family<Track?, int>(
  (ref, id) => ref.watch(libraryRepositoryProvider).watchTrack(id),
);

final trackCountProvider = StreamProvider<int>(
  (ref) => ref.watch(libraryRepositoryProvider).watchTrackCount(),
);

final favoriteCountProvider = StreamProvider<int>(
  (ref) => ref
      .watch(libraryRepositoryProvider)
      .watchTrackCount(filter: TrackFilter.favorites),
);

final albumsProvider = StreamProvider<List<LibraryGroup>>(
  (ref) => ref.watch(libraryRepositoryProvider).watchAlbums(),
);

final artistsProvider = StreamProvider<List<LibraryGroup>>(
  (ref) => ref.watch(libraryRepositoryProvider).watchArtists(),
);

final foldersProvider = StreamProvider<List<FolderRow>>(
  (ref) => ref.watch(libraryRepositoryProvider).watchFolders(),
);

final playlistsProvider = StreamProvider<List<PlaylistInfo>>(
  (ref) => ref.watch(libraryRepositoryProvider).watchPlaylists(),
);

final playlistProvider = StreamProvider.family<PlaylistRow?, int>(
  (ref, id) => ref.watch(libraryRepositoryProvider).watchPlaylist(id),
);

final playlistItemsProvider = StreamProvider.family<List<PlaylistItem>, int>(
  (ref, id) => ref.watch(libraryRepositoryProvider).watchPlaylistItems(id),
);

/// Whether the library is rescanned when the app starts (off in tests).
final autoRescanProvider = Provider<bool>((ref) => true);

/// State of the running / last import.
class ScanState {
  const ScanState({
    this.running = false,
    this.done = 0,
    this.total = 0,
    this.label = '',
    this.lastReport,
  });

  final bool running;
  final int done;
  final int total;
  final String label;
  final ScanReport? lastReport;
}

/// Runs imports and rescans one at a time.
class LibraryScanController extends Notifier<ScanState> {
  @override
  ScanState build() => const ScanState();

  Future<LibraryScanner> _scanner() async => LibraryScanner(
    db: ref.read(appDatabaseProvider),
    tagReader: ref.read(tagReaderProvider),
    artworkDir: await ref.read(artworkDirProvider.future),
  );

  Future<ScanReport?> _run(
    String label,
    Future<ScanReport> Function(LibraryScanner s, ScanProgress p) job,
  ) async {
    if (state.running) {
      return null;
    }
    state = ScanState(running: true, label: label, lastReport: state.lastReport);
    try {
      final scanner = await _scanner();
      final report = await job(scanner, (done, total) {
        state = ScanState(
          running: true,
          label: label,
          done: done,
          total: total,
          lastReport: state.lastReport,
        );
      });
      state = ScanState(lastReport: report);
      return report;
    } on Object catch (e) {
      final report = ScanReport()..problems.add('$label failed: $e');
      state = ScanState(lastReport: report);
      return report;
    }
  }

  Future<ScanReport?> addFolder() async {
    final folder = await ref.read(libraryPickerProvider).pickFolder();
    if (folder == null) {
      return null;
    }
    return _run(
      'Adding ${p.basename(folder)}',
      (s, progress) => s.addFolder(folder, onProgress: progress),
    );
  }

  Future<ScanReport?> addFiles() async {
    final files = await ref.read(libraryPickerProvider).pickFiles();
    if (files.isEmpty) {
      return null;
    }
    return _run(
      'Adding files',
      (s, progress) => s.addFiles(files, onProgress: progress),
    );
  }

  /// Startup check: rescans only when folders were added before.
  Future<ScanReport?> rescanIfLibraryExists() async {
    if (!ref.read(autoRescanProvider)) {
      return null;
    }
    final db = ref.read(appDatabaseProvider);
    final folder = await (db.select(db.libraryFolders)..limit(1)).get();
    final loose = await (db.select(db.tracks)
          ..where((t) => t.folderId.isNull())
          ..limit(1))
        .get();
    if (folder.isEmpty && loose.isEmpty) {
      return null;
    }
    return rescan();
  }

  Future<ScanReport?> rescan() =>
      _run('Rescanning', (s, progress) => s.rescanAll(onProgress: progress));
}

final libraryScanProvider = NotifierProvider<LibraryScanController, ScanState>(
  LibraryScanController.new,
);
