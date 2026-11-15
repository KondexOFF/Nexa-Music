import 'dart:io';

import 'package:path/path.dart' as p;

import '../app_paths.dart';
import 'app_database.dart';

/// Safety around the one database file (E2.7, owner order D-023 / D-024):
/// * a copy is made before NEXA opens an older file (before a migration);
/// * a failed migration puts that copy back, so the user's data is never
///   left half-changed;
/// * Settings can ask to restore a copy at the next start.
///
/// Copies live in `<data>/backups`, the newest [keep] are kept.
class DatabaseSafety {
  DatabaseSafety(this.dataDir);

  final Directory dataDir;

  static const String fileName = 'nexa_library.sqlite';
  static const String restoreRequestName = 'restore_request.txt';
  static const int keep = 10;

  static Future<DatabaseSafety> forApp() async =>
      DatabaseSafety(await appDataDirectory());

  File get database => File(p.join(dataDir.path, fileName));
  Directory get backups => Directory(p.join(dataDir.path, 'backups'));
  File get _restoreRequest => File(p.join(dataDir.path, restoreRequestName));

  /// SQLite `user_version` (the schema version) from the file header, or
  /// null when there is no valid database file.
  static int? schemaOf(File file) {
    if (!file.existsSync() || file.lengthSync() < 100) {
      return null;
    }
    final raf = file.openSync();
    try {
      final header = raf.readSync(100);
      const magic = 'SQLite format 3';
      if (String.fromCharCodes(header.sublist(0, magic.length)) != magic) {
        return null;
      }
      return (header[60] << 24) |
          (header[61] << 16) |
          (header[62] << 8) |
          header[63];
    } finally {
      raf.closeSync();
    }
  }

  /// Copies the database (and its write-ahead log, if any) to [backups].
  File? backup(String reason, {bool prune = true}) {
    if (!database.existsSync()) {
      return null;
    }
    final target = _newCopy(reason);
    database.copySync(target.path);
    for (final suffix in const ['-wal', '-shm']) {
      final side = File('${database.path}$suffix');
      if (side.existsSync()) {
        side.copySync('${target.path}$suffix');
      }
    }
    if (prune) {
      _prune();
    }
    return target;
  }

  File _newCopy(String reason) {
    backups.createSync(recursive: true);
    final stamp = DateTime.now()
        .toIso8601String()
        .replaceAll(RegExp(r'[^0-9]'), '')
        .substring(0, 14);
    var target = File(p.join(backups.path, 'nexa_library_${reason}_$stamp.sqlite'));
    for (var n = 2; target.existsSync(); n++) {
      target = File(
        p.join(backups.path, 'nexa_library_${reason}_${stamp}_$n.sqlite'),
      );
    }
    return target;
  }

  /// Settings - "Back up now": a consistent copy of the open database
  /// (SQLite VACUUM INTO), while NEXA runs.
  Future<File> backupNow(AppDatabase db) async {
    final target = _newCopy('manual');
    await db.customStatement('VACUUM INTO ?', [target.path]);
    _prune();
    return target;
  }

  void _prune() {
    final copies = list();
    for (final old in copies.skip(keep)) {
      for (final suffix in const ['', '-wal', '-shm']) {
        final f = File('${old.path}$suffix');
        if (f.existsSync()) {
          f.deleteSync();
        }
      }
    }
  }

  /// Backups, newest first.
  List<File> list() {
    if (!backups.existsSync()) {
      return const [];
    }
    final files =
        backups
            .listSync()
            .whereType<File>()
            .where((f) => f.path.endsWith('.sqlite'))
            .toList()
          ..sort(
            (a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()),
          );
    return files;
  }

  /// Puts [copy] in place of the database (the current file is kept as a
  /// copy first).
  void restore(File copy) {
    if (!copy.existsSync()) {
      throw FileSystemException('Backup not found', copy.path);
    }
    if (database.existsSync()) {
      backup('before_restore', prune: false);
    }
    for (final suffix in const ['-wal', '-shm']) {
      final side = File('${database.path}$suffix');
      if (side.existsSync()) {
        side.deleteSync();
      }
    }
    copy.copySync(database.path);
    for (final suffix in const ['-wal', '-shm']) {
      final side = File('${copy.path}$suffix');
      if (side.existsSync()) {
        side.copySync('${database.path}$suffix');
      }
    }
  }

  /// Settings: restore [copy] when NEXA starts next time (the database is
  /// open while NEXA runs).
  void requestRestore(File copy) =>
      _restoreRequest.writeAsStringSync(p.basename(copy.path));

  String? get pendingRestore =>
      _restoreRequest.existsSync() ? _restoreRequest.readAsStringSync().trim() : null;

  void cancelRestore() {
    if (_restoreRequest.existsSync()) {
      _restoreRequest.deleteSync();
    }
  }

  /// Before the database is opened: a requested restore, then a copy when
  /// the file is older than this build (a migration will follow). Returns
  /// the copy that a failed migration puts back.
  File? beforeOpen() {
    final requested = pendingRestore;
    if (requested != null) {
      cancelRestore();
      final copy = File(p.join(backups.path, p.basename(requested)));
      if (copy.existsSync()) {
        restore(copy);
      }
    }
    final version = schemaOf(database);
    if (version != null && version < AppDatabase.currentSchemaVersion) {
      return backup('v$version');
    }
    return null;
  }

  /// A migration failed: the copy made by [beforeOpen] goes back.
  void undo(File copy) => restore(copy);
}

/// Opens the app database safely (main.dart): backup before a migration,
/// migration on first use, the backup back on failure. Throws
/// [DatabaseOpenFailed] after restoring.
Future<AppDatabase> openDatabaseSafely({
  DatabaseSafety? safety,
  AppDatabase Function()? open,
}) async {
  safety ??= await DatabaseSafety.forApp();
  final copy = safety.beforeOpen();
  final db = (open ?? AppDatabase.open)();
  try {
    // Opens the file and runs any migration.
    await db.customSelect('SELECT COUNT(*) AS c FROM playlists').get();
    return db;
  } on Object catch (e) {
    try {
      await db.close();
    } on Object {
      // Already closed by the failure.
    }
    if (copy != null) {
      safety.undo(copy);
    }
    throw DatabaseOpenFailed('$e', restoredFrom: copy?.path);
  }
}

class DatabaseOpenFailed implements Exception {
  const DatabaseOpenFailed(this.reason, {this.restoredFrom});

  final String reason;
  final String? restoredFrom;

  @override
  String toString() => reason;
}
