import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexa_music/features/update/release.dart';
import 'package:nexa_music/features/update/update_installer.dart';
import 'package:nexa_music/features/update/update_source.dart';
import 'package:nexa_music/features/update/zip_package.dart';
import 'package:path/path.dart' as p;

import '../helpers/fake_update_source.dart';
import '../helpers/update_package.dart';
import '../helpers/zip_builder.dart';

void main() {
  late Directory temp;
  setUp(() => temp = Directory.systemTemp.createTempSync('nexa_upd_pkg'));
  tearDown(() {
    try {
      temp.deleteSync(recursive: true);
    } on FileSystemException {
      // Windows may hold a file a moment longer.
    }
  });

  File zipOf(List<TestEntry> entries, [String name = 'u.zip']) =>
      File(p.join(temp.path, name))..writeAsBytesSync(buildZip(entries));

  Matcher problem(UpdateProblem pr) =>
      throwsA(isA<UpdateException>().having((e) => e.problem, 'problem', pr));

  group('ZIP checks', () {
    test('a good package unpacks, CRC-32 and package list match', () async {
      final zip = zipOf(goodEntries());
      final layout = checkPackage(readZipDirectory(zip));
      expect(layout.topFolder, top);
      final folder = await extractPackage(
        zip,
        layout,
        Directory(p.join(temp.path, 'staging')),
      );
      expect(File(p.join(folder.path, 'nexa_music.exe')).existsSync(), isTrue);
      expect(
        File(p.join(folder.path, 'data', 'app.so')).readAsBytesSync(),
        List.generate(20000, (i) => (i * 7) % 256),
      );
      await checkPackageFiles(folder);
    });

    void refused(String why, List<TestEntry> entries, UpdateProblem pr) {
      test(why, () {
        expect(() => checkPackage(readZipDirectory(zipOf(entries))), problem(pr));
      });
    }

    refused('path traversal', [...goodEntries(), TestEntry('$top/../evil.dll', [1])],
        UpdateProblem.unsafePackage);
    refused('traversal hidden in the middle',
        [...goodEntries(), TestEntry('$top/data/../../evil.dll', [1])],
        UpdateProblem.unsafePackage);
    refused('absolute path', [...goodEntries(), TestEntry('/Windows/evil.dll', [1])],
        UpdateProblem.unsafePackage);
    refused('drive letter', [...goodEntries(), TestEntry('C:/evil.dll', [1])],
        UpdateProblem.unsafePackage);
    refused('backslash name', [...goodEntries(), TestEntry('$top\\evil.dll', [1])],
        UpdateProblem.unsafePackage);
    refused('alternate data stream', [...goodEntries(), TestEntry('$top/a.dll:x', [1])],
        UpdateProblem.unsafePackage);
    refused('trailing dot (Windows drops it)',
        [...goodEntries(), TestEntry('$top/nexa_music.exe.', [1])],
        UpdateProblem.unsafePackage);
    refused('device name', [...goodEntries(), TestEntry('$top/con.txt', [1])],
        UpdateProblem.unsafePackage);
    refused('duplicate that differs only in case',
        [...goodEntries(), TestEntry('$top/NEXA_MUSIC.EXE', [1])],
        UpdateProblem.unsafePackage);
    refused('a file that is also a folder',
        [...goodEntries(), TestEntry('$top/RELEASE_NOTES.md/x.dll', [1])],
        UpdateProblem.unsafePackage);
    refused('two top folders', [...goodEntries(), TestEntry('Other/x.dll', [1])],
        UpdateProblem.unsafePackage);
    refused('no nexa_music.exe', [
      TestEntry('$top/'),
      TestEntry('$top/readme.txt', [1]),
    ], UpdateProblem.unsafePackage);
    refused('empty archive', [], UpdateProblem.corruptPackage);

    test('symbolic link (Unix attributes) and reparse point', () {
      final link = TestEntry('$top/link.dll', utf8.encode('../../Windows'))
        ..madeBy = 3 << 8
        ..externalAttributes = 0xA1FF << 16;
      expect(
        () => checkPackage(readZipDirectory(zipOf([...goodEntries(), link]))),
        problem(UpdateProblem.unsafePackage),
      );
      final reparse = TestEntry('$top/r.dll', [1])..externalAttributes = 0x400;
      expect(
        () => checkPackage(readZipDirectory(zipOf([...goodEntries(), reparse]))),
        problem(UpdateProblem.unsafePackage),
      );
    });

    test('encrypted entry, unknown compression', () {
      final enc = TestEntry('$top/e.dll', [1, 2])..flags = 0x801;
      expect(
        () => checkPackage(readZipDirectory(zipOf([...goodEntries(), enc]))),
        problem(UpdateProblem.unsafePackage),
      );
      final lzma = TestEntry('$top/l.dll', [1, 2])..method = 14;
      expect(
        () => checkPackage(readZipDirectory(zipOf([...goodEntries(), lzma]))),
        problem(UpdateProblem.unsafePackage),
      );
    });

    test('not a ZIP / cut off', () {
      final junk = File(p.join(temp.path, 'junk.zip'))
        ..writeAsBytesSync(List.filled(5000, 7));
      expect(() => readZipDirectory(junk), problem(UpdateProblem.corruptPackage));
      final bytes = buildZip(goodEntries());
      final cut = File(p.join(temp.path, 'cut.zip'))
        ..writeAsBytesSync(bytes.sublist(0, bytes.length ~/ 2));
      expect(() => readZipDirectory(cut), problem(UpdateProblem.corruptPackage));
    });

    test('damaged data is found while unpacking (CRC-32)', () async {
      final entries = goodEntries();
      entries.firstWhere((e) => e.name.endsWith('app.so')).crcOverride = 1234;
      final zip = zipOf(entries);
      final layout = checkPackage(readZipDirectory(zip));
      await expectLater(
        extractPackage(zip, layout, Directory(p.join(temp.path, 's'))),
        problem(UpdateProblem.corruptPackage),
      );
    });

    test('a local header that names another file is refused', () async {
      final entries = goodEntries();
      entries.firstWhere((e) => e.name.endsWith('OFL.txt')).localName =
          '$top/../../evil.txt';
      final zip = zipOf(entries);
      final layout = checkPackage(readZipDirectory(zip));
      await expectLater(
        extractPackage(zip, layout, Directory(p.join(temp.path, 's'))),
        problem(UpdateProblem.unsafePackage),
      );
      expect(File(p.join(temp.path, 'evil.txt')).existsSync(), isFalse);
    });

    test('the package list catches a changed, extra or missing file', () async {
      Future<Directory> unpack(List<TestEntry> entries, String name) async {
        final zip = zipOf(entries, '$name.zip');
        return extractPackage(
          zip,
          checkPackage(readZipDirectory(zip)),
          Directory(p.join(temp.path, name)),
        );
      }

      final changed = goodEntries();
      final i = changed.indexWhere((e) => e.name.endsWith('flutter_windows.dll'));
      changed[i] = TestEntry(changed[i].name, [9, 9, 9]);
      await expectLater(
        checkPackageFiles(await unpack(changed, 'changed')),
        problem(UpdateProblem.corruptPackage),
      );
      await expectLater(
        checkPackageFiles(
          await unpack([...goodEntries(), TestEntry('$top/extra.dll', [1])], 'extra'),
        ),
        problem(UpdateProblem.corruptPackage),
      );
      final missing = goodEntries()
        ..removeWhere((e) => e.name.endsWith('OFL.txt'));
      await expectLater(
        checkPackageFiles(await unpack(missing, 'missing')),
        problem(UpdateProblem.corruptPackage),
      );
    });
  });

  group('download, SHA-256, staging', () {
    late Directory appDir;
    late UpdatePaths paths;
    setUp(() {
      appDir = Directory(p.join(temp.path, 'NEXA_Music_1.1.1_Windows_x64'))
        ..createSync();
      File(p.join(appDir.path, 'nexa_music.exe')).writeAsStringSync('old');
      paths = UpdatePaths(Directory(p.join(temp.path, 'updates')));
    });

    ReleaseInfo release(List<int> zip, {String? digest, bool sums = false, String? sumsHash}) =>
        ReleaseInfo.fromJson({
          'tag_name': 'v1.2.0',
          'name': 'NEXA Music 1.2.0',
          'body': '',
          'assets': [
            {
              'id': 1,
              'name': '$top.zip',
              'size': zip.length,
              'digest': digest == null ? null : 'sha256:$digest',
            },
            if (sums) {'id': 2, 'name': 'SHA256SUMS.txt', 'size': 100},
          ],
        })!;

    UpdateInstaller installer(FakeUpdateSource source, {int? free}) =>
        UpdateInstaller(
          paths: paths,
          source: source,
          appDir: appDir,
          free: (_) async => free,
        );

    test('verified and unpacked outside the program folder', () async {
      final zip = buildZip(goodEntries());
      final hash = sha256.convert(zip).toString();
      final sums = utf8.encode('$hash  $top.zip\n');
      final source = FakeUpdateSource(files: {1: zip, 2: sums});
      final progress = <int>[];
      final staged = await installer(source).prepare(
        release(zip, digest: hash, sums: true),
        onProgress: (phase, done, total) => progress.add(phase),
      );
      expect(staged.sha256, hash);
      expect(p.isWithin(paths.staging.path, staged.folder.path), isTrue);
      expect(p.isWithin(appDir.path, staged.folder.path), isFalse);
      expect(File(p.join(staged.folder.path, 'nexa_music.exe')).existsSync(), isTrue);
      expect(progress, containsAllInOrder([1, 2]));
      // The program folder is not touched before the updater runs.
      expect(File(p.join(appDir.path, 'nexa_music.exe')).readAsStringSync(), 'old');
    });

    test('a release without a SHA-256 is refused before downloading', () async {
      final zip = buildZip(goodEntries());
      final source = FakeUpdateSource(files: {1: zip});
      await expectLater(
        installer(source).prepare(release(zip)),
        problem(UpdateProblem.missingChecksum),
      );
      expect(source.downloads, isEmpty);
    });

    test('SHA256SUMS.txt without the package, or disagreeing', () async {
      final zip = buildZip(goodEntries());
      final hash = sha256.convert(zip).toString();
      await expectLater(
        installer(FakeUpdateSource(files: {1: zip, 2: utf8.encode('${'a' * 64}  other.zip')}))
            .prepare(release(zip, digest: hash, sums: true)),
        problem(UpdateProblem.missingChecksum),
      );
      await expectLater(
        installer(FakeUpdateSource(files: {1: zip, 2: utf8.encode('${'a' * 64}  $top.zip')}))
            .prepare(release(zip, digest: hash, sums: true)),
        problem(UpdateProblem.checksumMismatch),
      );
    });

    test('a download that differs from its SHA-256 is deleted', () async {
      final zip = buildZip(goodEntries());
      final hash = sha256.convert(zip).toString();
      final damaged = [...zip]..[100] ^= 0xFF;
      await expectLater(
        installer(FakeUpdateSource(files: {1: damaged})).prepare(release(zip, digest: hash)),
        problem(UpdateProblem.checksumMismatch),
      );
      final left = paths.downloads.existsSync()
          ? paths.downloads.listSync(recursive: true).whereType<File>().toList()
          : <File>[];
      expect(left, isEmpty);
      expect(paths.staging.existsSync(), isFalse);
    });

    test('an unsafe package with a correct SHA-256 is still refused', () async {
      final zip = buildZip([...goodEntries(), TestEntry('$top/../evil.dll', [1])]);
      final hash = sha256.convert(zip).toString();
      await expectLater(
        installer(FakeUpdateSource(files: {1: zip})).prepare(release(zip, digest: hash)),
        problem(UpdateProblem.unsafePackage),
      );
      expect(File(p.join(temp.path, 'evil.dll')).existsSync(), isFalse);
      expect(File(p.join(paths.root.path, 'evil.dll')).existsSync(), isFalse);
    });

    test('not enough disk space', () async {
      final zip = buildZip(goodEntries());
      final hash = sha256.convert(zip).toString();
      await expectLater(
        installer(FakeUpdateSource(files: {1: zip}), free: 1000)
            .prepare(release(zip, digest: hash)),
        problem(UpdateProblem.noDiskSpace),
      );
    });

    test('the update folder may not be inside the program folder', () async {
      final zip = buildZip(goodEntries());
      final inside = UpdateInstaller(
        paths: UpdatePaths(Directory(p.join(appDir.path, 'updates'))),
        source: FakeUpdateSource(files: {1: zip}),
        appDir: appDir,
        free: (_) async => null,
      );
      await expectLater(
        inside.prepare(release(zip, digest: sha256.convert(zip).toString())),
        problem(UpdateProblem.installFailed),
      );
    });

    test('old downloads are cleaned, fresh ones kept', () {
      final old = Directory(p.join(paths.staging.path, '1.2.0-1'))..createSync(recursive: true);
      final fresh = Directory(p.join(paths.downloads.path, '1.2.0'))..createSync(recursive: true);
      final inst = installer(FakeUpdateSource());
      inst.cleanUp(now: DateTime.now().add(const Duration(hours: 1)));
      expect(old.existsSync(), isTrue);
      inst.cleanUp(now: DateTime.now().add(const Duration(hours: 7)));
      expect(old.existsSync(), isFalse);
      expect(fresh.existsSync(), isFalse);
    });
  });

  test('the updater launcher is passed as -EncodedCommand (UTF-16LE)', () {
    expect(encodePowerShell('ab'), base64.encode([97, 0, 98, 0]));
    final text = 'Start-Process "x y"';
    final bytes = base64.decode(encodePowerShell(text));
    expect(
      String.fromCharCodes([
        for (var i = 0; i < bytes.length; i += 2) bytes[i] | (bytes[i + 1] << 8),
      ]),
      text,
    );
  });

  group('updater files', () {
    test('kept versions, results and the plan', () {
      final paths = UpdatePaths(Directory(p.join(temp.path, 'updates')));
      for (final (v, schema) in [('1.1.1', 4), ('1.1.2', 4), ('1.0.0', 3)]) {
        final dir = Directory(p.join(paths.previous.path, v))..createSync(recursive: true);
        File(p.join(dir.path, 'nexa_music.exe')).writeAsStringSync(v);
        File('${dir.path}.json').writeAsStringSync(
          jsonEncode({'version': v, 'schema': schema, 'savedAt': '2026-12-01T10:00:00'}),
        );
      }
      // A copy without its program is not offered.
      File(p.join(paths.previous.path, '0.9.0.json'))
          .writeAsStringSync(jsonEncode({'version': '0.9.0', 'schema': 2}));
      final list = PreviousVersion.list(paths);
      expect(list.map((v) => '${v.version}'), ['1.1.2', '1.1.1', '1.0.0']);
      expect(list.last.schema, 3);
      UpdateInstaller(paths: paths, source: FakeUpdateSource(), appDir: temp)
          .prunePrevious();
      expect(PreviousVersion.list(paths).map((v) => '${v.version}'), ['1.1.2', '1.1.1']);

      paths.run.createSync(recursive: true);
      paths.result.writeAsStringSync(
        '\uFEFF{"state":"failed_rolled_back","mode":"install","from":"1.1.1",'
        '"to":"1.2.0","detail":"no answer within 90 s"}',
      );
      final r = UpdaterResult.read(paths.result)!;
      expect(r.ok, isFalse);
      expect(r.from, '1.1.1');
      expect(r.detail, contains('90 s'));

      final plan = UpdaterPlan(
        mode: 'install',
        pid: 42,
        appDir: temp.path,
        source: p.join(paths.staging.path, 'x'),
        oldVersion: '1.1.1',
        newVersion: '1.2.0',
        oldSchema: 4,
        paths: paths,
      ).toJson();
      expect(plan['previousDir'], p.join(paths.previous.path, '1.1.1'));
      expect(plan['restoreRequest'], isNull);
      expect(jsonEncode(plan), isNot(contains('token')));
    });
  });
}
