import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nexa_music/app/config.dart';
import 'package:nexa_music/app/strings.dart';

/// The version shown in Settings must be the version the exe is built with.
void main() {
  test('kAppVersion equals the version in pubspec.yaml', () {
    final line = File('pubspec.yaml')
        .readAsLinesSync()
        .firstWhere((l) => l.startsWith('version:'));
    final version = line.substring('version:'.length).trim().split('+').first;
    expect(kAppVersion, version);
  });

  test('the version line names the version only', () {
    expect(S.versionLine('1.0.0'), 'Version 1.0.0');
  });
}
