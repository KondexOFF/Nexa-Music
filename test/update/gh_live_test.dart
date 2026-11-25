// D-030: the real GitHub account through the owner's signed-in GitHub CLI
// - list the releases, download the published v1.1.0 package through `gh`
// (NEXA never sees the token) and check it like an update: GitHub's
// SHA-256, SHA256SUMS.txt, every ZIP entry. Runs only with
// NEXA_D030_GH=1 (the Windows update-chain run); skipped otherwise.
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexa_music/features/update/semver.dart';
import 'package:nexa_music/features/update/release.dart';
import 'package:nexa_music/features/update/update_installer.dart';
import 'package:nexa_music/features/update/update_source.dart';
import 'package:nexa_music/features/update/zip_package.dart';
import 'package:path/path.dart' as p;

void main() {
  final live = Platform.environment['NEXA_D030_GH'] == '1';

  test('GitHub CLI: releases, download, SHA-256 and ZIP checks', () async {
    final gh = GhCliSource();
    final releases = await gh.releases();
    final v110 = releases.firstWhere((r) => r.tag == 'v1.1.0');
    expect(v110.package!.sha256, hasLength(64));
    expect(newestUpdate(releases, SemVer.tryParse('1.1.1')!), isNull);
    expect(newestUpdate(releases, SemVer.tryParse('1.0.0')!)!.tag, 'v1.1.0');

    final temp = Directory.systemTemp.createTempSync('nexa_gh_live');
    try {
      final installer = UpdateInstaller(
        paths: UpdatePaths(Directory(p.join(temp.path, 'updates'))),
        source: gh,
        appDir: Directory(p.join(temp.path, 'app'))..createSync(),
      );
      expect(await installer.expectedChecksum(v110), v110.package!.sha256);
      final (stream, _) = await gh.download(v110.package!);
      final zip = File(p.join(temp.path, 'v110.zip'));
      final sink = zip.openWrite();
      await sink.addStream(stream);
      await sink.close();
      expect(zip.lengthSync(), v110.package!.size);
      expect(sha256.convert(zip.readAsBytesSync()).toString(), v110.package!.sha256);
      final layout = checkPackage(readZipDirectory(zip));
      expect(layout.topFolder, 'NEXA_Music_1.1.0_Windows_x64');
      final folder = await extractPackage(
        zip,
        layout,
        Directory(p.join(temp.path, 'staging')),
      );
      expect(File(p.join(folder.path, 'nexa_music.exe')).existsSync(), isTrue);
      // ignore: avoid_print
      print('D030GH releases ${releases.length}, v1.1.0 ${zip.lengthSync()} bytes, '
          '${layout.entries.length} entries, SHA-256 verified');
    } finally {
      temp.deleteSync(recursive: true);
    }
  }, skip: live ? false : 'only in the Windows update-chain run (NEXA_D030_GH=1)');
}
