// D-030: a release package checked exactly as NEXA Update Center checks an
// update - ZIP central directory, unpacking with CRC-32, the package's own
// SHA256SUMS.txt. Runs only for the release kit (NEXA_D030_PACKAGE=<zip>);
// skipped otherwise.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nexa_music/features/update/zip_package.dart';
import 'package:path/path.dart' as p;

void main() {
  final zip = Platform.environment['NEXA_D030_PACKAGE']?.trim() ?? '';

  test('the release package passes the Update Center checks', () async {
    final layout = checkPackage(readZipDirectory(File(zip)));
    final temp = Directory.systemTemp.createTempSync('nexa_pkg_check');
    try {
      final folder = await extractPackage(
        File(zip),
        layout,
        Directory(p.join(temp.path, 'staging')),
      );
      await checkPackageFiles(folder);
      expect(File(p.join(folder.path, 'SHA256SUMS.txt')).existsSync(), isTrue);
      // ignore: avoid_print
      print('D030PKG ${layout.topFolder}: ${layout.entries.length} entries, '
          '${layout.totalSize} bytes, package list verified');
    } finally {
      temp.deleteSync(recursive: true);
    }
  }, skip: zip.isEmpty ? 'only for the release kit (NEXA_D030_PACKAGE)' : false);
}
