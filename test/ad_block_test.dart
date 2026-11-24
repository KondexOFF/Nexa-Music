import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexa_music/app/strings.dart';
import 'package:nexa_music/core/database/app_database.dart';
import 'package:nexa_music/features/library/library_providers.dart';
import 'package:nexa_music/features/privacy/ad_block.dart';
import 'package:path/path.dart' as p;

import 'helpers/test_app.dart';

/// D-026: optional ad blocking in the web players - off by default, only
/// with a real unpacked extension, switched off or removed completely, and
/// nothing requested (no extension support) while it is not used.
void main() {
  late AppDatabase db;
  late ProviderContainer c;
  late Directory ext;

  setUp(() async {
    db = memoryDatabase();
    c = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
    );
    ext = Directory.systemTemp.createTempSync('nexa_ubol');
    File(p.join(ext.path, 'manifest.json')).writeAsStringSync('{}');
    c.read(adBlockProvider);
    await Future<void>.delayed(const Duration(milliseconds: 50));
  });

  tearDown(() async {
    c.dispose();
    await db.close();
    ext.deleteSync(recursive: true);
  });

  AdBlockController ctl() => c.read(adBlockProvider.notifier);
  AdBlockState state() => c.read(adBlockProvider);

  test('off by default: no request, so WebView2 runs without extensions',
      () {
    expect(state().loaded, isTrue);
    expect(state().on, isFalse);
    expect(adBlockRequest(state()), isNull);
  });

  test('on needs a real unpacked extension (manifest.json)', () async {
    await ctl().setOn(true);
    expect(adBlockRequest(state()), isNull, reason: 'no folder yet');
    await ctl().setPath(p.join(ext.path, 'missing'));
    expect(state().pathValid, isFalse);
    expect(adBlockRequest(state()), isNull);
    await ctl().setPath(ext.path);
    final r = adBlockRequest(state())!;
    expect(r.enabled, isTrue);
    expect(r.remove, isFalse);
    expect(r.path, ext.path);
  });

  test('installed, then off: switched off by id; remove takes it out', () async {
    await ctl().setPath(ext.path);
    await ctl().setOn(true);
    await ctl().report({'ok': true, 'id': 'abc', 'name': 'uBlock Origin Lite', 'enabled': true});
    expect(state().id, 'abc');
    expect(state().status, S.adBlockLoaded);

    await ctl().setOn(false);
    final off = adBlockRequest(state())!;
    expect(off.enabled, isFalse);
    expect(off.remove, isFalse);
    expect(off.id, 'abc');
    await ctl().report({'ok': true, 'id': 'abc', 'enabled': false});
    expect(state().status, S.adBlockOff);

    await ctl().remove();
    final rm = adBlockRequest(state())!;
    expect(rm.remove, isTrue);
    expect(rm.id, 'abc');
    await ctl().report({'ok': true, 'id': '', 'enabled': false});
    expect(state().installed, isFalse);
    expect(state().removeRequested, isFalse);
    expect(state().status, S.adBlockRemoved);
    expect(adBlockRequest(state()), isNull, reason: 'fully gone');
  });

  test('settings survive a restart; a refused request is explained',
      () async {
    await ctl().setPath(ext.path);
    await ctl().setOn(true);
    await ctl().report({'ok': true, 'id': 'abc', 'enabled': true});
    final c2 = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
    );
    addTearDown(c2.dispose);
    c2.read(adBlockProvider);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    final s = c2.read(adBlockProvider);
    expect(s.on, isTrue);
    expect(s.path, ext.path);
    expect(s.id, 'abc');

    await ctl().report({'ok': false, 'error': 'restart'});
    expect(state().status, S.adBlockRestart);
    await ctl().report({'ok': false, 'error': 'AddBrowserExtension 0x8'});
    expect(state().status, S.adBlockRefused('AddBrowserExtension 0x8'));
  });

  group('install from the downloaded .zip', () {
    late Directory store;
    late ProviderContainer z;

    ProviderContainer withUnpacker(ZipUnpacker unpack) {
      final c = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          adBlockStoreProvider.overrideWithValue((
            dir: () async => store,
            unpack: unpack,
          )),
        ],
      );
      addTearDown(c.dispose);
      return c;
    }

    setUp(() => store = Directory.systemTemp.createTempSync('nexa_ubol_store'));
    tearDown(() => store.deleteSync(recursive: true));

    test('unpacked into NEXA\'s folder (one folder level is found)', () async {
      z = withUnpacker((zip, dest) async {
        final inner = Directory(p.join(dest, 'uBOLite.chromium'))
          ..createSync();
        File(p.join(inner.path, 'manifest.json'))
            .writeAsStringSync('{"name": "uBlock Origin Lite"}');
      });
      z.read(adBlockProvider);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      final ok = await z.read(adBlockProvider.notifier).installZip('x.zip');
      expect(ok, isTrue);
      final s = z.read(adBlockProvider);
      expect(s.pathValid, isTrue);
      expect(p.isWithin(store.path, s.path!), isTrue);
      expect(extensionName(s.path!), 'uBlock Origin Lite');
      expect(s.status, S.adBlockNextPlayer);
    });

    test('a localized name is read from the default locale', () {
      final f = Directory(p.join(store.path, 'loc'))..createSync();
      File(p.join(f.path, 'manifest.json')).writeAsStringSync(
        '{"name": "__MSG_extName__", "default_locale": "en"}',
      );
      Directory(p.join(f.path, '_locales', 'en')).createSync(recursive: true);
      File(p.join(f.path, '_locales', 'en', 'messages.json')).writeAsStringSync(
        '{"extName": {"message": "uBlock Origin Lite"}}',
      );
      expect(extensionName(f.path), 'uBlock Origin Lite');
    });

    test('a .zip without an extension is refused and removed', () async {
      z = withUnpacker((zip, dest) async {
        File(p.join(dest, 'readme.txt')).writeAsStringSync('no extension');
      });
      z.read(adBlockProvider);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(await z.read(adBlockProvider.notifier).installZip('x.zip'), isFalse);
      expect(z.read(adBlockProvider).status, S.adBlockNotExtension);
      expect(z.read(adBlockProvider).path, isNull);
      expect(store.listSync(), isEmpty);
    });

    test('Windows Expand-Archive unpacks a real .zip', () async {
      final src = Directory(p.join(store.path, 'src'))..createSync();
      File(p.join(src.path, 'manifest.json')).writeAsStringSync('{"name": "uBlock"}');
      final zip = p.join(store.path, 'ext.zip');
      final made = await Process.run('powershell', [
        '-NoProfile',
        '-NonInteractive',
        '-Command',
        r'Compress-Archive -Path (Join-Path $env:SRC "*") -DestinationPath $env:ZIP',
      ], environment: {'SRC': src.path, 'ZIP': zip});
      expect(made.exitCode, 0, reason: '${made.stderr}');
      final dest = Directory(p.join(store.path, 'out'))..createSync();
      await expandArchive(zip, dest.path);
      expect(findExtensionFolder(dest.path), dest.path);
    }, skip: !Platform.isWindows);
  });
}
