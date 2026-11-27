// E6 - database migration on a COPY of the owner's data (owner orders D-023,
// D-024, 2026-11-16: "Миграцию базы проверять сначала на копии
// пользовательских данных"). Real SQLite, real migration code:
//
//   flutter test integration_test/migration_copy_test.dart -d windows
//       --dart-define=NEXA_MIG_SRC=<folder with a copy of nexa_library.sqlite>
//
// The folder given is only read: its database is copied again into a
// temporary NEXA data folder, and only that second copy is migrated.
// Only counts and schema numbers are printed - no titles, paths or other
// personal data.
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:nexa_music/core/database/app_database.dart';
import 'package:nexa_music/core/database/database_safety.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

const String source = String.fromEnvironment('NEXA_MIG_SRC');

/// Tables that existed before schema 4 (1.0.0 and E1 / E2 builds).
const List<String> tables = [
  'library_folders',
  'tracks',
  'playlists',
  'playlist_entries',
  'app_settings',
  'listening_events',
  'taste_items',
];

Map<String, Object?> inspect(String path) {
  final db = sqlite3.open(path, mode: OpenMode.readOnly);
  try {
    final names = db
        .select("SELECT name FROM sqlite_master WHERE type = 'table'")
        .map((r) => r['name'] as String)
        .toSet();
    final counts = <String, int>{
      for (final t in tables)
        if (names.contains(t))
          t: db.select('SELECT COUNT(*) AS c FROM "$t"').first['c'] as int,
    };
    return {
      'version': db.select('PRAGMA user_version').first.values.first,
      'integrity': db.select('PRAGMA integrity_check').first.values.first,
      'foreignKeyErrors': db.select('PRAGMA foreign_key_check').length,
      'counts': counts,
      // Schema 5 (D-042): songs removed from the library.
      'exclusionsTable': names.contains('library_exclusions'),
    };
  } finally {
    db.close();
  }
}

String sha(File f) => sha256.convert(f.readAsBytesSync()).toString();

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('E6: owner database copy migrates to schema '
      '${AppDatabase.currentSchemaVersion} without losing rows', (
    tester,
  ) async {
    final original = File(p.join(source, DatabaseSafety.fileName));
    expect(
      source.isNotEmpty && original.existsSync(),
      isTrue,
      reason: 'pass --dart-define=NEXA_MIG_SRC=<folder with a copy>',
    );
    final originalSha = sha(original);
    final temp = Directory.systemTemp.createTempSync('nexa_mig_copy');
    final result = <String, Object?>{};
    try {
      // Second copy (with its write-ahead log, if any) into a temporary
      // data folder; the given folder is never written.
      final dataDir = Directory(p.join(temp.path, 'data'))..createSync();
      for (final suffix in const ['', '-wal', '-shm']) {
        final f = File('${original.path}$suffix');
        if (f.existsSync()) {
          f.copySync(p.join(dataDir.path, '${DatabaseSafety.fileName}$suffix'));
        }
      }
      final safety = DatabaseSafety(dataDir);
      final working = safety.database;
      result['before'] = inspect(working.path);
      final versionBefore = (result['before']! as Map)['version']! as int;
      final beforeSha = sha(working);

      final db = (await tester.runAsync(
        () => openDatabaseSafely(
          safety: safety,
          open: () => AppDatabase(NativeDatabase(working)),
        ),
      ))!;
      // Real use after the migration: the app's own queries.
      final tracks = (await tester.runAsync(
        () => db.select(db.tracks).get(),
      ))!;
      final playlists = (await tester.runAsync(
        () => db.select(db.playlists).get(),
      ))!;
      await tester.runAsync(() => db.close());
      result['appRead'] = {
        'tracks': tracks.length,
        'playlists': playlists.length,
      };

      result['after'] = inspect(working.path);
      final before = result['before']! as Map;
      final after = result['after']! as Map;
      expect(after['version'], AppDatabase.currentSchemaVersion);
      expect(after['integrity'], 'ok');
      expect(after['foreignKeyErrors'], 0);
      expect(after['exclusionsTable'], isTrue);
      final countsBefore = before['counts']! as Map;
      final countsAfter = after['counts']! as Map;
      for (final t in countsBefore.keys) {
        expect(countsAfter[t], countsBefore[t], reason: 'rows of $t');
      }
      expect((result['appRead']! as Map)['tracks'], countsAfter['tracks']);

      // A backup was made before the migration and is the untouched file.
      final copies = safety.list();
      result['backups'] = copies.length;
      if (versionBefore < AppDatabase.currentSchemaVersion) {
        expect(copies, isNotEmpty);
        final backup = copies.first;
        expect(DatabaseSafety.schemaOf(backup), versionBefore);
        expect(sha(backup), beforeSha);
        expect(p.basename(backup.path), contains('_v$versionBefore'));
      }

      // Opening again: no second migration, no new backup.
      final again = await tester.runAsync(
        () => openDatabaseSafely(
          safety: safety,
          open: () => AppDatabase(NativeDatabase(working)),
        ),
      );
      await tester.runAsync(() => again!.close());
      expect(safety.list().length, copies.length);
      expect(inspect(working.path)['counts'], countsAfter);

      // The folder given was only read.
      expect(sha(original), originalSha);
      result['sourceUnchanged'] = true;
    } finally {
      // Counts and versions only (no names, titles or paths).
      // ignore: avoid_print
      print('MIGRESULT ${jsonEncode(result)}');
      try {
        temp.deleteSync(recursive: true);
      } on FileSystemException {
        // Removed by Windows later.
      }
    }
  });
}
