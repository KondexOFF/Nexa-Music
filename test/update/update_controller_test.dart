import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexa_music/core/database/app_database.dart';
import 'package:nexa_music/core/database/database_safety.dart';
import 'package:nexa_music/core/settings/settings_repository.dart';
import 'package:nexa_music/features/library/library_providers.dart';
import 'package:nexa_music/features/library/library_repository.dart';
import 'package:nexa_music/features/update/release.dart';
import 'package:nexa_music/features/update/update_controller.dart';
import 'package:nexa_music/features/update/update_installer.dart';
import 'package:nexa_music/features/update/update_source.dart';
import 'package:path/path.dart' as p;

import '../helpers/fake_update_source.dart';
import '../helpers/update_package.dart';
import '../helpers/zip_builder.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late Directory temp;
  late UpdatePaths paths;
  late Directory appDir;
  late Directory dataDir;
  late FakeUpdateSource source;
  late List<UpdaterPlan> launched;
  late int exits;
  late AppDatabase db;
  late List<int> zip;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('nexa_upd_ctl');
    paths = UpdatePaths(Directory(p.join(temp.path, 'updates')));
    appDir = Directory(p.join(temp.path, 'NEXA_Music_1.1.1_Windows_x64'))..createSync();
    File(p.join(appDir.path, 'nexa_music.exe')).writeAsStringSync('1.1.1');
    dataDir = Directory(p.join(temp.path, 'data'))..createSync();
    zip = buildZip(goodEntries());
    source = FakeUpdateSource(
      list: ReleaseInfo.listFromJson([
        {
          'tag_name': 'v1.2.0',
          'name': 'NEXA Music 1.2.0 Nocturne',
          'body': 'Night theme',
          'assets': [
            {
              'id': 1,
              'name': '$top.zip',
              'size': zip.length,
              'digest': 'sha256:${sha256.convert(zip)}',
            },
          ],
        },
        {'tag_name': 'v1.1.0', 'assets': []},
      ]),
      files: {1: zip},
    );
    launched = [];
    exits = 0;
    db = AppDatabase(NativeDatabase(File(p.join(dataDir.path, DatabaseSafety.fileName))));
  });

  tearDown(() async {
    await db.close();
    try {
      temp.deleteSync(recursive: true);
    } on FileSystemException {
      // Windows may hold a file a moment longer.
    }
  });

  ProviderContainer container({bool autoAllowed = true}) {
    final c = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        updateSourceProvider.overrideWithValue(source),
        updatePathsProvider.overrideWith((ref) async => paths),
        appProgramDirProvider.overrideWithValue(appDir),
        autoCheckAllowedProvider.overrideWithValue(autoAllowed),
        databaseSafetyProvider.overrideWith((ref) async => DatabaseSafety(dataDir)),
        updaterScriptProvider.overrideWithValue(() async => '# updater'),
        updaterLauncherProvider.overrideWithValue((plan, script) async {
          launched.add(plan);
        }),
        appExitProvider.overrideWithValue(() async => exits++),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  Future<UpdateState> settle(ProviderContainer c, bool Function(UpdateState) done) async {
    for (var i = 0; i < 400; i++) {
      final s = c.read(updateProvider);
      if (done(s)) {
        return s;
      }
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    fail('state not reached: ${c.read(updateProvider).phase}');
  }

  test('the daily check offers 1.2.0 once, then not again the same day', () async {
    final c = container();
    final s = await settle(c, (s) => s.phase == UpdatePhase.available);
    expect(s.release!.tag, 'v1.2.0');
    expect(s.promptId, 1);
    expect(source.checks, 1);
    expect(
      DateTime.tryParse(
        await SettingsRepository(db).getString(SettingKeys.updateLastCheck) ?? '',
      ),
      isNotNull,
    );
    final again = container();
    await settle(again, (s) => s.loaded);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(source.checks, 1, reason: 'at most once a day');
    // The manual check always runs.
    await again.read(updateProvider.notifier).check();
    expect(source.checks, 2);
    expect(again.read(updateProvider).promptId, 0, reason: 'manual: no popup');
  });

  test('switched off: no automatic check at all', () async {
    await SettingsRepository(db).setBool(SettingKeys.updateAutoCheck, false);
    final c = container();
    final s = await settle(c, (s) => s.loaded);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(s.autoCheck, isFalse);
    expect(source.checks, 0);
  });

  test('"Skip this version": no popup for it, still visible in About', () async {
    final c = container();
    await settle(c, (s) => s.phase == UpdatePhase.available);
    await c.read(updateProvider.notifier).skip();
    expect(await SettingsRepository(db).getString(SettingKeys.updateSkipped), '1.2.0');
    await SettingsRepository(db).setString(SettingKeys.updateLastCheck, '2000-01-01T00:00:00');
    final next = container();
    final s = await settle(next, (s) => s.phase == UpdatePhase.available);
    expect(s.promptId, 0);
    expect(s.isSkipped, isTrue);
  });

  test('problems are shown, local music keeps working', () async {
    source.error = const UpdateException(UpdateProblem.noGitHubCli);
    final c = container();
    final s = await settle(c, (s) => s.phase == UpdatePhase.error);
    expect(s.problem, UpdateProblem.noGitHubCli);
    expect(s.promptId, 0);
    // The library is untouched and usable.
    expect(await LibraryRepository(db).getPlaylists(), isEmpty);
  });

  test('"Update now" -> download -> "Restart and install"', () async {
    final c = container();
    await settle(c, (s) => s.phase == UpdatePhase.available);
    final ctl = c.read(updateProvider.notifier);
    await ctl.download();
    final s = c.read(updateProvider);
    expect(s.phase, UpdatePhase.ready, reason: '${s.problem} ${s.detail}');
    expect(s.staged!.version.toString(), '1.2.0');
    await ctl.installNow();
    expect(launched.single.mode, 'install');
    expect(launched.single.newVersion, '1.2.0');
    expect(launched.single.oldVersion, '1.1.1');
    expect(launched.single.oldSchema, AppDatabase.currentSchemaVersion);
    expect(launched.single.appDir, appDir.path);
    expect(launched.single.source, s.staged!.folder.path);
    expect(exits, 1);
  });

  test('"Install when I close NEXA"', () async {
    final c = container();
    await settle(c, (s) => s.phase == UpdatePhase.available);
    final ctl = c.read(updateProvider.notifier);
    await ctl.download();
    ctl.installOnExit();
    expect(launched, isEmpty);
    await ctl.onExit();
    expect(launched.single.mode, 'install');
    expect(exits, 0, reason: 'NEXA is closing already');
  });

  test('a damaged download is never installed', () async {
    source.files = {1: [...zip]..[10] ^= 1};
    final c = container();
    await settle(c, (s) => s.phase == UpdatePhase.available);
    await c.read(updateProvider.notifier).download();
    expect(c.read(updateProvider).problem, UpdateProblem.checksumMismatch);
    await c.read(updateProvider.notifier).installNow();
    expect(launched, isEmpty);
  });

  test('the last updater result is shown once', () async {
    paths.run.createSync(recursive: true);
    paths.result.writeAsStringSync(
      jsonEncode({'state': 'ok', 'mode': 'install', 'from': '1.1.0', 'to': '1.1.1'}),
    );
    final c = container(autoAllowed: false);
    final s = await settle(c, (s) => s.loaded);
    expect(s.lastResult!.ok, isTrue);
    expect(paths.result.existsSync(), isFalse);
  });

  group('rollback', () {
    void keep(String version, int schema) {
      final dir = Directory(p.join(paths.previous.path, version))..createSync(recursive: true);
      File(p.join(dir.path, 'nexa_music.exe')).writeAsStringSync(version);
      File('${dir.path}.json')
          .writeAsStringSync(jsonEncode({'version': version, 'schema': schema}));
    }

    Future<void> schemaFile(File f, int version) async {
      final d = AppDatabase(NativeDatabase(f));
      await d.customSelect('SELECT 1').get();
      await d.customStatement('PRAGMA user_version = $version');
      await d.close();
    }

    test('no migration since: the program only', () async {
      keep('1.1.0', AppDatabase.currentSchemaVersion);
      keep('1.1.1', AppDatabase.currentSchemaVersion); // this version: not offered
      await LibraryRepository(db).createPlaylist('Mine');
      final c = container(autoAllowed: false);
      final s = await settle(c, (s) => s.loaded);
      expect(s.previous.map((v) => '${v.version}'), ['1.1.0']);
      final ctl = c.read(updateProvider.notifier);
      expect(await ctl.rollbackCopy(s.previous.single), isNull);
      await ctl.rollback(s.previous.single);
      expect(launched.single.mode, 'rollback');
      expect(launched.single.newVersion, '1.1.0');
      expect(launched.single.restoreBackup, isNull);
      expect(exits, 1);
    });

    test('after a migration: the copy from before it, current data saved', () async {
      final safety = DatabaseSafety(dataDir);
      await LibraryRepository(db).createPlaylist('Added after the update');
      // The live library is one schema newer than the kept version reads.
      final current = AppDatabase.currentSchemaVersion;
      await db.customStatement('PRAGMA user_version = ${current + 1}');
      keep('1.1.0', current);
      safety.backups.createSync(recursive: true);
      final before = File(p.join(safety.backups.path, 'nexa_library_v${current}_20261201.sqlite'));
      await schemaFile(before, current);
      final c = container(autoAllowed: false);
      final s = await settle(c, (s) => s.loaded);
      final ctl = c.read(updateProvider.notifier);
      expect((await ctl.rollbackCopy(s.previous.single))!.path, before.path);
      await ctl.rollback(s.previous.single);
      final plan = launched.single;
      expect(plan.restoreBackup, p.basename(before.path));
      expect(plan.restoreRequest, p.join(dataDir.path, DatabaseSafety.restoreRequestName));
      // The current library is saved first, as a protected copy.
      final saved = safety.list().where(DatabaseSafety.isProtected).toList();
      expect(saved, hasLength(1));
      expect(p.basename(saved.single.path), contains('_before_rollback_'));
      // Read it as this schema (the copy says one newer).
      final readable = File(p.join(temp.path, 'check.sqlite'));
      final bytes = saved.single.readAsBytesSync();
      bytes[63] = current;
      readable.writeAsBytesSync(bytes);
      final check = AppDatabase(NativeDatabase(readable));
      final names = await check.customSelect('SELECT name FROM playlists').get();
      expect(names.map((r) => r.read<String>('name')), ['Added after the update']);
      await check.close();
    });

    test('after a migration without any older copy: refused', () async {
      await db.customStatement(
        'PRAGMA user_version = ${AppDatabase.currentSchemaVersion + 1}',
      );
      keep('1.1.0', AppDatabase.currentSchemaVersion);
      final c = container(autoAllowed: false);
      final s = await settle(c, (s) => s.loaded);
      await expectLater(
        c.read(updateProvider.notifier).rollbackCopy(s.previous.single),
        throwsA(isA<UpdateException>()),
      );
      await c.read(updateProvider.notifier).rollback(s.previous.single);
      expect(launched, isEmpty);
      expect(exits, 0);
    });
  });
}
