import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nexa_music/core/audio/playback_engine.dart';
import 'package:nexa_music/core/database/app_database.dart';
import 'package:nexa_music/core/models/track.dart';
import 'package:nexa_music/features/library/library_providers.dart';
import 'package:nexa_music/features/player/player_controller.dart';
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

  /// Set by NEXA_AutoTest.ps1 when its sound check before the run found the
  /// output muted, at 0 % or without loopback: every sound measurement is
  /// then BLOCKED with this reason (playback itself is still tested).
  static const String audioBlocked = String.fromEnvironment('NEXA_AT_AUDIO_BLOCKED');

  /// Endpoint id of the output device nobody listens to (NEXA_AutoTest.ps1
  /// -OutputDevice): NEXA plays there and only that device is recorded, so
  /// the test tones are not heard (owner request 2026-11-23). 'none': the
  /// device asked for was not found. Empty: Windows default device.
  static const String device = String.fromEnvironment('NEXA_AT_DEVICE');

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

/// The silent output device of this run ([AutoTestConfig.device]).
abstract final class TestOutput {
  /// Description of the device NEXA plays on (null: Windows default).
  static String? chosen;

  /// Why the silent device could not be used. Then nothing may play: the
  /// tones would be heard on the speakers.
  static String? problem;

  static bool get blocked => problem != null;
}

/// Sends NEXA's sound to the silent device (and saves it in the profile, so
/// the exe stage, which copies this profile, plays there too).
Future<void> useTestOutput(ProviderContainer c) async {
  final want = AutoTestConfig.device.trim().toLowerCase();
  if (want.isEmpty || TestOutput.blocked) {
    return;
  }
  if (want == 'none') {
    TestOutput.problem = 'the silent output device given to NEXA_AutoTest.ps1 was not found';
    return;
  }
  final engine = c.read(playbackEngineProvider);
  OutputDevice? match;
  await waitUntil(() {
    match = engine.availableDevices
        .where((d) => d.id.toLowerCase().endsWith(want))
        .firstOrNull;
    return match != null;
  }, timeout: const Duration(seconds: 10));
  if (match == null) {
    TestOutput.problem =
        'the audio engine does not offer the silent output device '
        '(${engine.availableDevices.map((d) => d.description).join(', ')})';
    return;
  }
  await c.read(playerProvider.notifier).setOutputDevice(match!);
  TestOutput.chosen = match!.description;
}

/// Container with the real engine, the real HTTP client and a database
/// file in the isolated AutoTest profile; NEXA plays on the silent output
/// device when one is set.
Future<ProviderContainer> autoTestContainer() async {
  final c = _container();
  await useTestOutput(c);
  return c;
}

ProviderContainer _container() {
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

  /// The recorder's DONE line of the last recording (mute / volume seen).
  String? doneInfo;
  int _count = 0;

  bool get available =>
      AutoTestConfig.audioBlocked.isEmpty && exe.isNotEmpty && File(exe).existsSync();

  /// `key=value` pairs of a READY / DONE line (values may be "quoted").
  static Map<String, String> fields(String line) => {
    for (final m in RegExp(r'(\w+)=("[^"]*"|\S+)').allMatches(line))
      m.group(1)!: m.group(2)!.replaceAll('"', ''),
  };

  /// Why a finished recording cannot be used: the Windows output (device or
  /// NEXA's own Volume-mixer slider) was muted or at 0 % at some moment.
  static String? outputProblem(String doneLine) {
    final f = fields(doneLine);
    double? volume(String key) {
      final v = double.tryParse(f[key] ?? '');
      return v == null || v < 0 ? null : v;
    }

    final endpoint = volume('min_endpoint_volume');
    final session = f['session_seen'] == '1' ? volume('min_session_volume') : null;
    if (f['muted_seen'] == '1') {
      return 'Windows sound was muted during the recording';
    }
    if (endpoint != null && endpoint < 0.01) {
      return 'Windows volume was at ${(endpoint * 100).round()} % during the recording';
    }
    if (session != null && session < 0.01) {
      return 'NEXA was at ${(session * 100).round()} % in the Windows Volume mixer during the recording';
    }
    return null;
  }

  /// Records [seconds] of the Windows output while [during] runs (started
  /// once the recorder is ready). Null when recording failed.
  Future<Recording?> record(
    String name,
    double seconds,
    Future<void> Function() during, {
    bool expectSound = true,
  }) async {
    if (TestOutput.blocked) {
      lastError = 'silent output device: ${TestOutput.problem}';
      return null;
    }
    if (!available) {
      lastError = AutoTestConfig.audioBlocked.isNotEmpty
          ? 'sound check before the run: ${AutoTestConfig.audioBlocked}'
          : 'loopback_capture.exe not available';
      await during();
      return null;
    }
    final file = p.join(dir, '${(++_count).toString().padLeft(2, '0')}_$name.wav');
    doneInfo = null;
    await Directory(dir).create(recursive: true);
    // With this process id the recorder captures only NEXA's own audio
    // (process loopback), so other programs cannot disturb the measurement.
    // With a silent output device only that device is recorded (nothing else
    // plays there).
    final proc = await Process.start(exe, [
      file,
      '$seconds',
      '$pid',
      if (AutoTestConfig.device.isNotEmpty) AutoTestConfig.device,
    ]);
    final ready = Completer<void>();
    final errors = StringBuffer();
    proc.stdout.transform(utf8.decoder).transform(const LineSplitter()).listen((
      line,
    ) {
      if (line.startsWith('READY') && !ready.isCompleted) {
        deviceInfo = line.substring(5).trim();
        ready.complete();
      } else if (line.startsWith('DONE')) {
        doneInfo = line.substring(4).trim();
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
    // stdout is read asynchronously: give the DONE line a moment.
    for (var i = 0; i < 20 && doneInfo == null; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    final problem = outputProblem(doneInfo ?? '');
    if (problem != null) {
      lastError = '$problem - the measurement is not possible, not a NEXA result '
          '(${p.basename(file)}; recorder: ${doneInfo ?? '-'})';
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
