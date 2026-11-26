import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexa_music/app/database_error_app.dart';
import 'package:nexa_music/core/database/app_database.dart';
import 'package:nexa_music/core/database/database_safety.dart';
import 'package:nexa_music/features/library/library_repository.dart';
import 'package:path/path.dart' as p;

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late Directory temp;
  late DatabaseSafety safety;
  final current = AppDatabase.currentSchemaVersion;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('nexa_db_rollback');
    safety = DatabaseSafety(temp);
  });
  tearDown(() {
    try {
      temp.deleteSync(recursive: true);
    } on FileSystemException {
      // Windows may hold a file a moment longer.
    }
  });

  /// A library file with a playlist [name], marked as [schema].
  Future<void> library(File f, String name, int schema) async {
    final db = AppDatabase(NativeDatabase(f));
    await LibraryRepository(db).createPlaylist(name);
    await db.customStatement('PRAGMA user_version = $schema');
    await db.close();
  }

  String hash(File f) => sha256.convert(f.readAsBytesSync()).toString();

  test('a library from a newer NEXA is not opened and not changed', () async {
    await library(safety.database, 'New data', current + 1);
    final before = hash(safety.database);
    Object? error;
    try {
      await openDatabaseSafely(
        safety: safety,
        open: () => AppDatabase(NativeDatabase(safety.database)),
      );
    } on DatabaseOpenFailed catch (e) {
      error = e;
    }
    expect(error, isA<DatabaseOpenFailed>());
    expect((error! as DatabaseOpenFailed).newerSchema, current + 1);
    expect(hash(safety.database), before);
    expect(DatabaseSafety.schemaOf(safety.database), current + 1);
    expect(safety.list(), isEmpty, reason: 'no copy needed, nothing changed');
  });

  test('copies with the newest data are never pruned', () async {
    await library(safety.database, 'x', current);
    final protected = safety.backup('before_rollback', prune: false)!;
    final restoreCopy = safety.backup('before_restore', prune: false)!;
    for (var i = 0; i < DatabaseSafety.keep + 4; i++) {
      safety.backup('manual');
    }
    expect(protected.existsSync(), isTrue);
    expect(restoreCopy.existsSync(), isTrue);
    expect(
      safety.list().where((f) => !DatabaseSafety.isProtected(f)),
      hasLength(DatabaseSafety.keep),
    );
  });

  test('the newest readable copy: exactly this schema first', () async {
    safety.backups.createSync(recursive: true);
    final older = File(p.join(safety.backups.path, 'nexa_library_v3_1.sqlite'));
    final same = File(p.join(safety.backups.path, 'nexa_library_v${current}_2.sqlite'));
    final newer = File(p.join(safety.backups.path, 'nexa_library_x_3.sqlite'));
    await library(older, 'a', 3);
    await library(same, 'b', current);
    await library(newer, 'c', current + 1);
    expect(safety.newestCopyFor(current)!.path, same.path);
    same.deleteSync();
    expect(safety.newestCopyFor(current)!.path, older.path);
  });

  testWidgets('the error screen puts back the copy, keeping the newer file', (
    tester,
  ) async {
    late DatabaseOpenFailed error;
    await tester.runAsync(() async {
      await library(safety.database, 'Made in the newer version', current + 1);
      safety.backups.createSync(recursive: true);
      await library(
        File(p.join(safety.backups.path, 'nexa_library_v${current}_1.sqlite')),
        'Before the upgrade',
        current,
      );
      try {
        await openDatabaseSafely(safety: safety);
      } on DatabaseOpenFailed catch (e) {
        error = e;
      }
    });
    await tester.pumpWidget(DatabaseErrorApp(error: error));
    expect(find.textContaining('newer NEXARYVE'), findsWidgets);
    await tester.tap(find.byKey(const ValueKey('db-newer-restore')));
    await tester.pump();
    expect(find.byKey(const ValueKey('db-newer-restored')), findsOneWidget);
    expect(DatabaseSafety.schemaOf(safety.database), current);
    final kept = safety.list().where(DatabaseSafety.isProtected).single;
    expect(DatabaseSafety.schemaOf(kept), current + 1);
    await tester.runAsync(() async {
      final db = AppDatabase(NativeDatabase(safety.database));
      final names = await LibraryRepository(db).getPlaylists();
      expect(names.single.name, 'Before the upgrade');
      await db.close();
    });
  });
}
