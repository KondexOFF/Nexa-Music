import 'dart:io';

import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;

import '../../core/database/app_database.dart';
import 'library_repository.dart' show localSource;
import 'tag_reader.dart';

/// Result of an import or rescan, shown to the user.
class ScanReport {
  int added = 0;
  int updated = 0;
  int unchanged = 0;
  int missing = 0;
  int restored = 0;
  int skipped = 0;

  /// Files the user removed from the library (D-042): not added again.
  int excluded = 0;

  /// Removed songs brought back by the user (restore).
  int returned = 0;
  final List<String> problems = [];

  int get total => added + updated + unchanged;
}

/// Progress callback: files looked at so far / files found.
typedef ScanProgress = void Function(int done, int total);

/// Indexes local MP3/FLAC/WAV files into the database.
///
/// Rules (Master Plan v1.0, Phase 2): files are never copied, moved or
/// deleted; a file is stored once (by normalised path) however often it is
/// scanned; a file that disappears is kept in the library but marked
/// unavailable with a readable reason, so favourites and playlists survive.
class LibraryScanner {
  LibraryScanner({
    required this.db,
    required this.tagReader,
    required this.artworkDir,
  });

  final AppDatabase db;
  final TagReader tagReader;
  final String artworkDir;

  static const String fileNotFound = 'File not found';
  static const String folderNotFound = 'Folder not found or not connected';

  /// Adds a folder (and everything below it) to the library.
  Future<ScanReport> addFolder(String path, {ScanProgress? onProgress}) async {
    final key = pathKeyOf(path);
    var folder = await (db.select(
      db.libraryFolders,
    )..where((f) => f.pathKey.equals(key))).getSingleOrNull();
    if (folder == null) {
      final id = await db
          .into(db.libraryFolders)
          .insert(
            LibraryFoldersCompanion.insert(
              path: p.normalize(p.absolute(path)),
              pathKey: key,
              addedAt: DateTime.now(),
            ),
          );
      folder = await (db.select(
        db.libraryFolders,
      )..where((f) => f.id.equals(id))).getSingle();
    }
    return scanFolder(folder, onProgress: onProgress);
  }

  /// Adds single files (not tied to a library folder).
  Future<ScanReport> addFiles(
    List<String> paths, {
    ScanProgress? onProgress,
  }) async {
    final report = ScanReport();
    final files = <String>[];
    for (final path in paths) {
      if (isSupportedAudioFile(path)) {
        files.add(p.normalize(p.absolute(path)));
      } else {
        report.skipped++;
        report.problems.add('${p.basename(path)}: format not supported');
      }
    }
    // Files picked one by one are wanted: a removed one comes back.
    final keys = [for (final f in files) pathKeyOf(f)];
    for (var i = 0; i < keys.length; i += 500) {
      final chunk = keys.sublist(i, i + 500 > keys.length ? keys.length : i + 500);
      await (db.delete(
        db.libraryExclusions,
      )..where((e) => e.pathKey.isIn(chunk))).go();
    }
    await _index(files, null, report, onProgress);
    return report;
  }

  /// Reads [files] again into the library (restore of removed songs),
  /// in the library folder [folderId] or as single files.
  Future<ScanReport> indexFiles(List<String> files, int? folderId) async {
    final report = ScanReport();
    await _index(files, folderId, report, null);
    return report;
  }

  /// Rescans every library folder and re-checks single files.
  Future<ScanReport> rescanAll({ScanProgress? onProgress}) async {
    final total = ScanReport();
    final folders = await db.select(db.libraryFolders).get();
    for (final folder in folders) {
      final r = await scanFolder(folder, onProgress: onProgress);
      total
        ..added += r.added
        ..updated += r.updated
        ..unchanged += r.unchanged
        ..missing += r.missing
        ..restored += r.restored
        ..skipped += r.skipped
        ..excluded += r.excluded
        ..problems.addAll(r.problems);
    }
    // Files added one by one (no folder).
    // Files added one by one - never saved catalog / YouTube entries.
    final loose = await (db.select(db.tracks)..where(
          (t) => t.folderId.isNull() & t.source.equals(localSource),
        ))
        .get();
    final present = <String>[];
    for (final row in loose) {
      if (File(row.path).existsSync()) {
        present.add(row.path);
      } else if (row.available) {
        await _markMissing([row.id], fileNotFound);
        total.missing++;
      }
    }
    await _index(present, null, total, onProgress);
    return total;
  }

  /// Scans one folder recursively.
  Future<ScanReport> scanFolder(
    FolderRow folder, {
    ScanProgress? onProgress,
  }) async {
    final report = ScanReport();
    final dir = Directory(folder.path);
    final known = await (db.select(
      db.tracks,
    )..where((t) => t.folderId.equals(folder.id))).get();

    if (!dir.existsSync()) {
      // Drive unplugged or folder renamed: keep the tracks, mark them.
      final ids = [
        for (final t in known)
          if (t.available) t.id,
      ];
      await _markMissing(ids, folderNotFound);
      report
        ..missing += ids.length
        ..problems.add('${folder.path}: $folderNotFound');
      return report;
    }

    final files = <String>[];
    var complete = true;
    try {
      await for (final entity in dir.list(
        recursive: true,
        followLinks: false,
      )) {
        if (entity is File && isSupportedAudioFile(entity.path)) {
          files.add(entity.path);
        }
      }
    } on FileSystemException catch (e) {
      // Listing stopped early (e.g. no permission for a sub-folder): index
      // what was found, but do not mark the rest as missing.
      complete = false;
      report.problems.add('${folder.path}: ${e.message}');
    }

    await _index(files, folder.id, report, onProgress);

    final seen = {for (final f in files) pathKeyOf(f)};
    final gone = [
      if (complete)
        for (final t in known)
          if (t.available && !seen.contains(t.pathKey)) t.id,
    ];
    await _markMissing(gone, fileNotFound);
    report.missing += gone.length;

    await (db.update(db.libraryFolders)..where((f) => f.id.equals(folder.id)))
        .write(LibraryFoldersCompanion(lastScanAt: Value(DateTime.now())));
    return report;
  }

  Future<void> _markMissing(List<int> ids, String reason) async {
    if (ids.isEmpty) {
      return;
    }
    await (db.update(db.tracks)..where((t) => t.id.isIn(ids))).write(
      TracksCompanion(available: const Value(false), problem: Value(reason)),
    );
  }

  /// Inserts new files, refreshes changed ones, skips unchanged ones.
  Future<void> _index(
    List<String> files,
    int? folderId,
    ScanReport report,
    ScanProgress? onProgress,
  ) async {
    // The same file may be picked twice; index it once.
    final unique = <String, String>{};
    for (final f in files) {
      unique.putIfAbsent(pathKeyOf(f), () => f);
    }
    // Songs the user removed from the library stay out (D-042).
    final allKeys = unique.keys.toList();
    for (var i = 0; i < allKeys.length; i += 500) {
      final chunk = allKeys.sublist(
        i,
        i + 500 > allKeys.length ? allKeys.length : i + 500,
      );
      final removed = await (db.select(
        db.libraryExclusions,
      )..where((e) => e.pathKey.isIn(chunk))).get();
      for (final r in removed) {
        if (unique.remove(r.pathKey) != null) {
          report.excluded++;
        }
      }
    }
    files = unique.values.toList();
    if (files.isEmpty) {
      onProgress?.call(0, 0);
      return;
    }
    final keys = unique.keys.toList();
    final existing = <String, TrackRow>{};
    for (var i = 0; i < keys.length; i += 500) {
      final chunk = keys.sublist(i, i + 500 > keys.length ? keys.length : i + 500);
      final rows = await (db.select(
        db.tracks,
      )..where((t) => t.pathKey.isIn(chunk))).get();
      for (final r in rows) {
        existing[r.pathKey] = r;
      }
    }

    final toRead = <String>[];
    final stats = <String, FileStat>{};
    for (final f in files) {
      final stat = File(f).statSync();
      stats[f] = stat;
      final row = existing[pathKeyOf(f)];
      final unchanged =
          row != null &&
          row.fileSize == stat.size &&
          row.fileModified.millisecondsSinceEpoch ~/ 1000 ==
              stat.modified.millisecondsSinceEpoch ~/ 1000;
      if (unchanged) {
        if (!row.available || (folderId != null && row.folderId != folderId)) {
          await (db.update(db.tracks)..where((t) => t.id.equals(row.id))).write(
            TracksCompanion(
              available: const Value(true),
              problem: const Value(null),
              folderId: folderId == null
                  ? const Value.absent()
                  : Value(folderId),
            ),
          );
          if (!row.available) {
            report.restored++;
          }
        }
        report.unchanged++;
      } else {
        toRead.add(f);
      }
    }

    var done = files.length - toRead.length;
    onProgress?.call(done, files.length);
    const batch = 40;
    for (var i = 0; i < toRead.length; i += batch) {
      final chunk = toRead.sublist(
        i,
        i + batch > toRead.length ? toRead.length : i + batch,
      );
      final results = await tagReader.readAll(chunk, artworkDir);
      await db.transaction(() async {
        for (final tag in results) {
          await _store(tag, folderId, stats[tag.path], existing, report);
        }
      });
      done += chunk.length;
      onProgress?.call(done, files.length);
    }
  }

  Future<void> _store(
    TagResult tag,
    int? folderId,
    FileStat? stat,
    Map<String, TrackRow> existing,
    ScanReport report,
  ) async {
    final key = pathKeyOf(tag.path);
    final row = existing[key];
    final available = tag.error == null;
    if (!available) {
      report.problems.add('${p.basename(tag.path)}: ${tag.error}');
    }
    final search = [
      tag.title,
      tag.artist,
      tag.album,
      tag.albumArtist ?? '',
      tag.genre ?? '',
      p.basename(tag.path),
    ].join(' ').toLowerCase();
    final companion = TracksCompanion(
      path: Value(tag.path),
      title: Value(tag.title),
      artist: Value(tag.artist),
      album: Value(tag.album),
      albumArtist: Value(tag.albumArtist),
      genre: Value(tag.genre),
      year: Value(tag.year),
      trackNumber: Value(tag.trackNumber),
      discNumber: Value(tag.discNumber),
      durationMs: Value(tag.duration?.inMilliseconds),
      fileSize: Value(stat?.size ?? 0),
      fileModified: Value(stat?.modified ?? DateTime.now()),
      artworkPath: Value(tag.artworkPath),
      searchText: Value(search),
      available: Value(available),
      problem: Value(tag.error),
    );
    if (row == null) {
      // Removed from the library while this scan was running: stays out.
      final removed = await (db.select(
        db.libraryExclusions,
      )..where((e) => e.pathKey.equals(key))).getSingleOrNull();
      if (removed != null) {
        report.excluded++;
        return;
      }
      await db
          .into(db.tracks)
          .insert(
            companion.copyWith(
              pathKey: Value(key),
              folderId: Value(folderId),
              addedAt: Value(DateTime.now()),
            ),
          );
      report.added++;
    } else {
      // Keep favourite flag, playlists and the original "added" date.
      await (db.update(db.tracks)..where((t) => t.id.equals(row.id))).write(
        companion.copyWith(
          folderId: folderId == null ? const Value.absent() : Value(folderId),
        ),
      );
      if (!row.available && available) {
        report.restored++;
      }
      report.updated++;
    }
  }
}
