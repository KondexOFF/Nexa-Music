import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../core/database/app_database.dart';
import '../../core/models/track.dart';
import '../pages/database_backup_controls.dart' show databaseSafetyProvider;
import '../player/player_controller.dart';
import 'library_management.dart';
import 'library_providers.dart';

/// D-042 library management: removing songs from the library (never from
/// the disk), the removed list, restore, folders and "Clear library".
final libraryManagerProvider = Provider<LibraryManager>(
  (ref) => LibraryManager(ref.watch(appDatabaseProvider)),
);

final exclusionsProvider = StreamProvider<List<ExclusionRow>>(
  (ref) => ref.watch(libraryManagerProvider).watchExclusions(),
);

/// Library songs only (saved catalog songs and YouTube bookmarks have
/// their own "Delete saved").
List<int> localIdsOf(Iterable<Track> tracks) => [
  for (final t in tracks)
    if (t.source == TrackSource.local) t.id,
];

/// Removes [tracks] from the library: out of the queue first (the playing
/// one stops), then out of the database. Returns how many were removed.
Future<int> removeTracksFromLibrary(WidgetRef ref, Iterable<Track> tracks) async {
  final ids = localIdsOf(tracks);
  if (ids.isEmpty) {
    return 0;
  }
  await ref.read(playerProvider.notifier).forgetLibraryTracks(ids.toSet());
  return ref.read(libraryManagerProvider).removeFromLibrary(ids);
}

/// A copy of the database before a change that "Restore" cannot undo
/// (folder removal, clearing the library). Throws when no copy could be
/// made - the change is then not made.
Future<void> backupBefore(WidgetRef ref, String reason) async {
  final safety = await ref.read(databaseSafetyProvider.future);
  await safety.backupNow(ref.read(appDatabaseProvider), reason: reason);
}

/// Removes a library folder and its songs (backup first).
Future<int> removeFolderFromLibrary(WidgetRef ref, int folderId) async {
  await backupBefore(ref, 'before_folder_removal');
  final manager = ref.read(libraryManagerProvider);
  final ids = await manager.trackIdsOfFolder(folderId);
  await ref.read(playerProvider.notifier).forgetLibraryTracks(ids.toSet());
  return (await manager.removeFolder(folderId)).length;
}

/// Empties the library (backup first); files stay on the disk.
Future<int> clearWholeLibrary(WidgetRef ref) async {
  await backupBefore(ref, 'before_clear_library');
  final manager = ref.read(libraryManagerProvider);
  final ids = await manager.localTrackIds();
  await ref.read(playerProvider.notifier).forgetLibraryTracks(ids.toSet());
  return manager.clearLibrary();
}

/// What "Show in folder" did.
enum RevealResult { file, folder, notFound }

/// Opens Windows Explorer at a file (selected) or its folder. Tests
/// override this.
typedef FileRevealer = Future<RevealResult> Function(String path);

final fileRevealerProvider = Provider<FileRevealer>((ref) => revealInExplorer);

Future<RevealResult> revealInExplorer(String path) async {
  final file = p.normalize(path);
  if (Directory(file).existsSync()) {
    if (Platform.isWindows) {
      await Process.start('explorer.exe', [file]);
    }
    return RevealResult.folder;
  }
  if (File(file).existsSync()) {
    if (Platform.isWindows) {
      // "explorer /select, <file>" opens the folder with the file selected.
      await Process.start('explorer.exe', ['/select,', file]);
    }
    return RevealResult.file;
  }
  final dir = p.dirname(file);
  if (Directory(dir).existsSync()) {
    if (Platform.isWindows) {
      await Process.start('explorer.exe', [dir]);
    }
    return RevealResult.folder;
  }
  return RevealResult.notFound;
}

/// Songs picked in the library list for one action (null: not selecting).
/// Shift extends from the last picked song.
class TrackSelection extends Notifier<Set<int>?> {
  int? _anchor;

  @override
  Set<int>? build() => null;

  void start() {
    _anchor = null;
    state = <int>{};
  }

  void stop() {
    _anchor = null;
    state = null;
  }

  void toggle(int id, {List<int> order = const [], bool range = false}) {
    final next = {...?state};
    final anchor = _anchor;
    if (range && anchor != null) {
      final a = order.indexOf(anchor);
      final b = order.indexOf(id);
      if (a >= 0 && b >= 0) {
        final from = a < b ? a : b;
        final to = a < b ? b : a;
        next.addAll(order.sublist(from, to + 1));
        state = next;
        return;
      }
    }
    if (!next.remove(id)) {
      next.add(id);
    }
    _anchor = id;
    state = next;
  }

  void setAll(Iterable<int> ids) => state = ids.toSet();
}

final trackSelectionProvider = NotifierProvider<TrackSelection, Set<int>?>(
  TrackSelection.new,
);
