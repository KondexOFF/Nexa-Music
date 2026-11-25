import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'zip_builder.dart';

const String top = 'NEXA_Music_1.2.0_Windows_x64';

List<TestEntry> goodEntries({bool withList = true}) {
  final files = <String, List<int>>{
    '$top/nexa_music.exe': utf8.encode('MZ fake exe ' * 300),
    '$top/flutter_windows.dll': List.generate(5000, (i) => i % 251),
    '$top/data/app.so': List.generate(20000, (i) => (i * 7) % 256),
    '$top/data/flutter_assets/assets/fonts/OFL.txt': utf8.encode('licence'),
    '$top/RELEASE_NOTES.md': utf8.encode('# 1.2.0 Nocturne\n'),
  };
  final entries = [
    TestEntry('$top/'),
    TestEntry('$top/data/'),
    for (final e in files.entries) TestEntry(e.key, e.value, e.key.endsWith('.dll')),
  ];
  if (withList) {
    final lines = [
      for (final e in files.entries)
        '${sha256.convert(e.value)}  ${e.key.substring(top.length + 1).replaceAll('/', '\\')}',
    ];
    entries.add(TestEntry('$top/SHA256SUMS.txt', utf8.encode(lines.join('\r\n'))));
  }
  return entries;
}

