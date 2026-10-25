import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nexa_music/core/database/app_database.dart';
import 'package:nexa_music/core/models/track.dart';
import 'package:nexa_music/features/library/library_providers.dart';
import 'package:path/path.dart' as p;

import '../../test/helpers/audio_analysis.dart';

/// Settings passed by NEXA_AutoTest.ps1 with --dart-define.
abstract final class AutoTestConfig {
  /// Writable copy of the test library (with manifest.json).
  static const String library = String.fromEnvironment('NEXA_AT_LIBRARY');

  /// Folder for results, recordings and the isolated profile.
  static const String out = String.fromEnvironment('NEXA_AT_OUT');

  /// loopback_capture.exe (empty: audio measurements are BLOCKED).
  static const String loopback = String.fromEnvironment('NEXA_AT_LOOPBACK');

  /// File with the owner's Jamendo client id (outside the repository).
  static const String jamendoIdFile = String.fromEnvironment(
    'NEXA_AT_JAMENDO_ID_FILE',
  );

  /// Comma separated groups to run (empty: all).
  static const String groups = String.fromEnvironment('NEXA_AT_GROUPS');

  static bool runs(String group) =>
      groups.trim().isEmpty ||
      groups.split(',').map((g) => g.trim()).contains(group);

  static String get profile => p.join(out, 'profile');
}

/// Collected results of all checks (written as JSON for the report).
class AutoTestResults {
  final List<Map<String, Object?>> checks = [];
  final DateTime started = DateTime.now();

  void add(
    String id,
    String ft,
    String title,
    String status, {
    String detail = '',
    Map<String, Object?>? data,
  }) {
    checks.add({
      'id': id,
      'ft': ft,
      'title': title,
      'status': status,
      'detail': detail,
      'level': 'integration (real media_kit, SQLite, files; debug build)',
      'data': ?data,
    });
    // ignore: avoid_print
    print('AUTOTEST $status $id ($ft) $title ${detail.isEmpty ? '' : '- $detail'}');
  }

  void check(
    String id,
    String ft,
    String title,
    bool ok, {
    String detail = '',
    Map<String, Object?>? data,
  }) => add(id, ft, title, ok ? 'PASS' : 'FAIL', detail: detail, data: data);

  void blocked(String id, String ft, String title, String why) =>
      add(id, ft, title, 'BLOCKED', detail: why);

  Future<void> save(String path) async {
    final file = File(path);
    await file.parent.create(recursive: true);
    await file.writeAsString(
      const JsonEncoder.withIndent(' ').convert({
        'stage': 'integration',
        'startedAt': started.toIso8601String(),
        'finishedAt': DateTime.now().toIso8601String(),
        'checks': checks,
      }),
    );
  }
}

/// manifest.json of the generated test library.
class LibraryManifest {
  LibraryManifest(this.root, this.tracks);

  final String root;
  final List<Map<String, dynamic>> tracks;

  factory LibraryManifest.load(String root) {
    final json =
        jsonDecode(File(p.join(root, 'manifest.json')).readAsStringSync())
            as Map<String, dynamic>;
    return LibraryManifest(root, [
      for (final t in json['tracks'] as List<dynamic>)
        t as Map<String, dynamic>,
    ]);
  }

  Map<String, dynamic> byFile(String rel) =>
      tracks.firstWhere((t) => t['file'] == rel);

  double frequency(String rel) => (byFile(rel)['frequency'] as num).toDouble();

  /// Generated length in seconds (independent of what the app reads).
  double seconds(String rel) => (byFile(rel)['seconds'] as num).toDouble();
}

/// Relative, forward-slash path of [track] inside the test library.
String relPath(String root, String path) =>
    p.relative(path, from: root).replaceAll(r'\', '/');

/// SHA-256 of every file below [root] (relative path -> hash).
Map<String, String> hashTree(String root) => {
  for (final f
      in Directory(root).listSync(recursive: true).whereType<File>())
    relPath(root, f.path): sha256.convert(f.readAsBytesSync()).toString(),
};

/// Always answers with the test library (no Windows dialog).
class FixedPicker implements LibraryPicker {
  const FixedPicker(this.folder);

  final String folder;

  @override
  Future<String?> pickFolder() async => folder;

  @override
  Future<List<String>> pickFiles() async => const [];
}

/// Container with the real engine, the real HTTP client and a database
/// file in the isolated AutoTest profile.
ProviderContainer autoTestContainer() {
  final profile = AutoTestConfig.profile;
  Directory(profile).createSync(recursive: true);
  return ProviderContainer(
    overrides: [
      appDatabaseProvider.overrideWith((ref) {
        final db = AppDatabase(
          NativeDatabase(File(p.join(profile, 'nexa_library.sqlite'))),
        );
        ref.onDispose(db.close);
        return db;
      }),
      artworkDirProvider.overrideWith((ref) async => p.join(profile, 'artwork')),
      autoRescanProvider.overrideWithValue(false),
      libraryPickerProvider.overrideWithValue(
        FixedPicker(AutoTestConfig.library),
      ),
    ],
  );
}

Future<bool> waitUntil(
  bool Function() test, {
  Duration timeout = const Duration(seconds: 10),
}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    if (test()) {
      return true;
    }
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
  return test();
}

Future<void> pause(double seconds) =>
    Future<void>.delayed(Duration(milliseconds: (seconds * 1000).round()));

/// WASAPI loopback recordings through loopback_capture.exe.
class Loopback {
  Loopback(this.exe, this.dir);

  final String exe;
  final String dir;
  String? lastError;

  /// The recorder's READY line (device rate / channels / sample format).
  String? deviceInfo;
  int _count = 0;

  bool get available => exe.isNotEmpty && File(exe).existsSync();

  /// Records [seconds] of the Windows output while [during] runs (started
  /// once the recorder is ready). Null when recording failed.
  Future<Recording?> record(
    String name,
    double seconds,
    Future<void> Function() during, {
    bool expectSound = true,
  }) async {
    if (!available) {
      lastError = 'loopback_capture.exe not available';
      await during();
      return null;
    }
    final file = p.join(dir, '${(++_count).toString().padLeft(2, '0')}_$name.wav');
    await Directory(dir).create(recursive: true);
    // With this process id the recorder captures only NEXA's own audio
    // (process loopback), so other programs cannot disturb the measurement.
    final proc = await Process.start(exe, [file, '$seconds', '$pid']);
    final ready = Completer<void>();
    final errors = StringBuffer();
    proc.stdout.transform(utf8.decoder).transform(const LineSplitter()).listen((
      line,
    ) {
      if (line.startsWith('READY') && !ready.isCompleted) {
        deviceInfo = line.substring(5).trim();
        ready.complete();
      }
    });
    proc.stderr.transform(utf8.decoder).listen(errors.write);
    try {
      await ready.future.timeout(const Duration(seconds: 10));
    } on TimeoutException {
      proc.kill();
      lastError = 'recorder did not start: $errors';
      await during();
      return null;
    }
    await during();
    final code = await proc.exitCode.timeout(
      // [during] may return early; the recorder stops by itself after
      // [seconds] and then writes the file.
      Duration(seconds: seconds.ceil() + 60),
      onTimeout: () {
        proc.kill();
        return -1;
      },
    );
    if (code != 0 || !File(file).existsSync()) {
      lastError = 'recorder exit $code: $errors';
      return null;
    }
    final rec = Recording.readWav(file);
    if (expectSound && !rec.samples.any((v) => v.abs() > 1e-4)) {
      // Nothing at all although NEXA plays: the measurement is impossible
      // (Windows output muted or turned to zero), not a NEXA defect.
      lastError = 'no sound captured - is the Windows output muted or at 0 %? '
          'The AutoTest needs audible output to measure (${p.basename(file)})';
      return null;
    }
    return rec;
  }
}

/// Tracks of the imported test library by relative path.
Map<String, Track> tracksByPath(List<Track> tracks) => {
  for (final t in tracks) relPath(AutoTestConfig.library, t.path): t,
};
