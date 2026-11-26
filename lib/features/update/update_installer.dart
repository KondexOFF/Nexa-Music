import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:path/path.dart' as p;

import '../../core/app_paths.dart';
import 'release.dart';
import 'semver.dart';
import 'update_source.dart';
import 'zip_package.dart';

/// Folders of NEXA Update Center. Never inside the program folder; the
/// library, history, playlists and settings (`%APPDATA%`) are not touched.
class UpdatePaths {
  UpdatePaths(this.root);

  /// `%LOCALAPPDATA%\com.kondexoff\nexa_music\updates`, or
  /// `<NEXA_DATA_DIR>\updates` in NEXA AutoTest; debug runs and tests
  /// without a test profile use a temporary folder, never the real one.
  static Future<UpdatePaths> forApp() async {
    final env = Platform.environment;
    final override = env['NEXA_DATA_DIR']?.trim() ?? '';
    final local = env['LOCALAPPDATA']?.trim() ?? '';
    final String root;
    if (!kReleaseMode && override.isEmpty) {
      root = p.join(Directory.systemTemp.path, 'nexa_updates_debug');
    } else if (override.isEmpty && local.isNotEmpty) {
      root = p.join(local, 'com.kondexoff', 'nexa_music', 'updates');
    } else {
      root = p.join((await appDataDirectory()).path, 'updates');
    }
    return UpdatePaths(Directory(root));
  }

  final Directory root;

  Directory get downloads => Directory(p.join(root.path, 'downloads'));
  Directory get staging => Directory(p.join(root.path, 'staging'));
  Directory get previous => Directory(p.join(root.path, 'previous'));
  Directory get run => Directory(p.join(root.path, 'run'));
  File get plan => File(p.join(run.path, 'plan.json'));
  File get script => File(p.join(run.path, 'nexa_updater.ps1'));
  File get log => File(p.join(run.path, 'updater.log'));
  File get result => File(p.join(run.path, 'result.json'));
  File get health => File(p.join(run.path, 'health.txt'));
}

/// A program copy kept by the updater, for a rollback.
class PreviousVersion {
  const PreviousVersion({
    required this.version,
    required this.schema,
    required this.folder,
    this.savedAt,
  });

  final SemVer version;

  /// Database schema that version reads.
  final int schema;
  final Directory folder;
  final DateTime? savedAt;

  static List<PreviousVersion> list(UpdatePaths paths) {
    if (!paths.previous.existsSync()) {
      return const [];
    }
    final out = <PreviousVersion>[];
    for (final f in paths.previous.listSync().whereType<File>()) {
      if (!f.path.endsWith('.json')) {
        continue;
      }
      try {
        final j = jsonDecode(f.readAsStringSync()) as Map;
        final v = SemVer.tryParse('${j['version']}');
        final dir = Directory(p.join(paths.previous.path, '${j['version']}'));
        if (v == null ||
            j['schema'] is! int ||
            !File(p.join(dir.path, 'nexa_music.exe')).existsSync()) {
          continue;
        }
        out.add(
          PreviousVersion(
            version: v,
            schema: j['schema'] as int,
            folder: dir,
            savedAt: DateTime.tryParse('${j['savedAt']}'),
          ),
        );
      } on Object {
        continue;
      }
    }
    out.sort((a, b) => b.version.compareTo(a.version));
    return out;
  }
}

/// A downloaded, verified and unpacked update, ready for the updater.
class StagedUpdate {
  const StagedUpdate(this.release, this.folder, this.sha256);

  final ReleaseInfo release;
  final Directory folder;
  final String sha256;

  SemVer get version => release.version!;
}

/// The last updater run, read at the next start.
class UpdaterResult {
  const UpdaterResult({
    required this.state,
    required this.mode,
    required this.from,
    required this.to,
    this.detail = '',
  });

  /// ok, failed_rolled_back, failed, not_closed
  final String state;

  /// install or rollback
  final String mode;
  final String from;
  final String to;
  final String detail;

  bool get ok => state == 'ok';

  static UpdaterResult? read(File f) {
    if (!f.existsSync()) {
      return null;
    }
    try {
      final text = f.readAsStringSync().replaceFirst('﻿', '');
      final j = jsonDecode(text) as Map;
      return UpdaterResult(
        state: '${j['state']}',
        mode: '${j['mode']}',
        from: '${j['from']}',
        to: '${j['to']}',
        detail: j['detail'] == null ? '' : '${j['detail']}',
      );
    } on Object {
      return null;
    }
  }
}

/// Free bytes on the drive of [path] (Windows), or null when unknown.
Future<int?> freeSpace(String path) async {
  if (!Platform.isWindows) {
    return null;
  }
  try {
    final drive = p.rootPrefix(p.absolute(path));
    final r = await Process.run('powershell', [
      '-NoProfile',
      '-NonInteractive',
      '-Command',
      '([System.IO.DriveInfo]::new(\$env:NEXA_DRIVE)).AvailableFreeSpace',
    ], environment: {'NEXA_DRIVE': drive}).timeout(const Duration(seconds: 15));
    return int.tryParse('${r.stdout}'.trim());
  } on Object {
    return null;
  }
}

/// Size of all files under [dir].
int folderSize(Directory dir) => dir.existsSync()
    ? dir
          .listSync(recursive: true)
          .whereType<File>()
          .fold(0, (s, f) => s + f.lengthSync())
    : 0;

class _DigestSink implements Sink<Digest> {
  Digest? value;

  @override
  void add(Digest data) => value = data;

  @override
  void close() {}
}

/// Download -> SHA-256 -> ZIP checks -> unpack -> package list.
class UpdateInstaller {
  UpdateInstaller({
    required this.paths,
    required this.source,
    required this.appDir,
    this.free = freeSpace,
  });

  final UpdatePaths paths;
  final UpdateSource source;

  /// The program folder (where `nexa_music.exe` runs from).
  final Directory appDir;
  final Future<int?> Function(String path) free;

  /// The checksum the release must have: GitHub's own digest of the
  /// asset, and - when the release has a `SHA256SUMS.txt` - the same value
  /// there. A missing checksum is never accepted.
  Future<String> expectedChecksum(ReleaseInfo release) async {
    final asset = release.package!;
    final digest = asset.sha256;
    if (digest == null) {
      throw const UpdateException(
        UpdateProblem.missingChecksum,
        'GitHub gave no SHA-256 for the package',
      );
    }
    final sums = release.checksums;
    if (sums != null) {
      if (sums.size > 64 * 1024) {
        throw const UpdateException(UpdateProblem.badResponse, 'SHA256SUMS.txt too large');
      }
      final (stream, _) = await source.download(sums);
      final bytes = <int>[];
      await for (final c in stream) {
        bytes.addAll(c);
        if (bytes.length > 64 * 1024) {
          throw const UpdateException(UpdateProblem.badResponse, 'SHA256SUMS.txt too large');
        }
      }
      final listed = checksumFor(utf8.decode(bytes, allowMalformed: true), asset.name);
      if (listed == null) {
        throw const UpdateException(
          UpdateProblem.missingChecksum,
          'SHA256SUMS.txt does not list the package',
        );
      }
      if (listed != digest) {
        throw const UpdateException(
          UpdateProblem.checksumMismatch,
          'SHA256SUMS.txt and GitHub disagree',
        );
      }
    }
    return digest;
  }

  /// Downloads and checks [release]; [onProgress] gets (bytes, total) of
  /// the download, then of the unpacking (phase 2).
  Future<StagedUpdate> prepare(
    ReleaseInfo release, {
    void Function(int phase, int done, int total)? onProgress,
  }) async {
    final asset = release.package;
    if (asset == null || release.version == null) {
      throw const UpdateException(UpdateProblem.notFound, 'no Windows package');
    }
    final appRoot = p.normalize(appDir.absolute.path);
    final rootPath = p.normalize(paths.root.absolute.path);
    if (p.equals(appRoot, rootPath) || p.isWithin(appRoot, rootPath)) {
      throw const UpdateException(
        UpdateProblem.installFailed,
        'update folder inside the program folder',
      );
    }
    final want = await expectedChecksum(release);

    // Room for the download, the unpacked copy, the copy kept for a
    // rollback and the new program next to the old one.
    final needed = asset.size + 3 * (folderSize(appDir) + asset.size * 3);
    final room = await free(paths.root.path);
    if (room != null && room < needed) {
      throw UpdateException(
        UpdateProblem.noDiskSpace,
        '${needed ~/ (1024 * 1024)} MB needed, ${room ~/ (1024 * 1024)} MB free',
      );
    }

    final version = release.version.toString();
    final dlDir = Directory(p.join(paths.downloads.path, version))
      ..createSync(recursive: true);
    final zip = File(p.join(dlDir.path, asset.name));
    final part = File('${zip.path}.part');
    for (final f in [zip, part]) {
      if (f.existsSync()) {
        f.deleteSync();
      }
    }
    final digestSink = _DigestSink();
    final hasher = sha256.startChunkedConversion(digestSink);
    final (stream, total) = await source.download(asset);
    final sink = part.openWrite();
    var got = 0;
    try {
      await for (final chunk in stream) {
        got += chunk.length;
        if (got > asset.size) {
          throw const UpdateException(
            UpdateProblem.corruptPackage,
            'download larger than the release file',
          );
        }
        hasher.add(chunk);
        sink.add(chunk);
        onProgress?.call(1, got, total ?? asset.size);
      }
    } on FileSystemException catch (e) {
      final code = e.osError?.errorCode;
      throw UpdateException(
        code == 112 || code == 39 ? UpdateProblem.noDiskSpace : UpdateProblem.installFailed,
        e.message,
      );
    } on SocketException catch (e) {
      throw UpdateException(UpdateProblem.offline, e.message);
    } finally {
      await sink.close();
    }
    hasher.close();
    final have = digestSink.value.toString();
    if (got != asset.size || have != want) {
      part.deleteSync();
      throw UpdateException(
        UpdateProblem.checksumMismatch,
        got != asset.size ? 'size $got of ${asset.size}' : 'SHA-256 differs',
      );
    }
    part.renameSync(zip.path);

    final layout = checkPackage(readZipDirectory(zip));
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final target = Directory(p.join(paths.staging.path, '$version-$stamp'));
    final Directory folder;
    try {
      folder = await extractPackage(
        zip,
        layout,
        target,
        onProgress: (d, t) => onProgress?.call(2, d, t),
      );
      await checkPackageFiles(folder);
    } on Object {
      _remove(target);
      rethrow;
    }
    return StagedUpdate(release, folder, have);
  }

  /// Removes downloads and unpacked folders older than [minAge] (a second
  /// NEXA window may be preparing one right now).
  void cleanUp({Duration minAge = const Duration(hours: 6), DateTime? now}) {
    final limit = (now ?? DateTime.now()).subtract(minAge);
    for (final dir in [paths.downloads, paths.staging]) {
      if (!dir.existsSync()) {
        continue;
      }
      for (final e in dir.listSync()) {
        try {
          if (e.statSync().modified.isAfter(limit)) {
            continue;
          }
        } on FileSystemException {
          continue;
        }
        _remove(e);
      }
    }
  }

  /// Only the [keep] newest program copies stay.
  void prunePrevious({int keep = 2}) {
    final all = PreviousVersion.list(paths);
    for (final old in all.skip(keep)) {
      _remove(old.folder);
      _remove(File('${old.folder.path}.json'));
    }
  }

  static void _remove(FileSystemEntity e) {
    try {
      if (e.existsSync()) {
        e.deleteSync(recursive: true);
      }
    } on FileSystemException {
      // Removed at a later start.
    }
  }
}

/// What the Windows updater (`nexa_updater.ps1`) is asked to do.
class UpdaterPlan {
  const UpdaterPlan({
    required this.mode,
    required this.pid,
    required this.appDir,
    required this.source,
    required this.oldVersion,
    required this.newVersion,
    required this.oldSchema,
    required this.paths,
    this.restoreRequest,
    this.restoreBackup,
  });

  /// install or rollback
  final String mode;
  final int pid;
  final String appDir;

  /// The folder that becomes the program: the unpacked update, or the
  /// kept previous version.
  final String source;
  final String oldVersion;
  final String newVersion;

  /// Schema the running (old) version reads, kept with its copy.
  final int oldSchema;
  final UpdatePaths paths;

  /// Rollback after a migration: `restore_request.txt` in the data folder
  /// and the backup name it asks for - written only once the older
  /// program is in place.
  final String? restoreRequest;
  final String? restoreBackup;

  Map<String, Object?> toJson() => {
    'mode': mode,
    'pid': pid,
    'appDir': appDir,
    'exeName': 'nexa_music.exe',
    'source': source,
    'oldVersion': oldVersion,
    'newVersion': newVersion,
    'oldSchema': oldSchema,
    'previousDir': p.join(paths.previous.path, oldVersion),
    'previousInfo': p.join(paths.previous.path, '$oldVersion.json'),
    'safetyDir': p.join(paths.run.path, 'current_copy'),
    'healthFile': paths.health.path,
    'resultFile': paths.result.path,
    'logFile': paths.log.path,
    'startTimeoutSeconds': 90,
    'restoreRequest': restoreRequest,
    'restoreBackup': restoreBackup,
  };
}

/// Starts the updater script with its own hidden window; the paths come in
/// as environment variables, never inside the command text.
const String _launcher = r'''
$ErrorActionPreference = 'Stop'
$a = @('-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Bypass',
  '-File', ('"' + $env:NEXA_UPD_SCRIPT + '"'), '-Plan', ('"' + $env:NEXA_UPD_PLAN + '"'))
Start-Process -FilePath powershell -WindowStyle Hidden -WorkingDirectory $env:NEXA_UPD_RUN -ArgumentList $a
exit 0
''';

/// PowerShell's -EncodedCommand: Base64 of UTF-16LE.
String encodePowerShell(String command) {
  final bytes = <int>[];
  for (final unit in command.codeUnits) {
    bytes
      ..add(unit & 0xFF)
      ..add(unit >> 8);
  }
  return base64.encode(bytes);
}

/// Writes the plan and starts the updater; NEXA then closes and
/// the updater waits for it. [script] is the updater's text (an asset).
Future<void> startUpdater(UpdaterPlan plan, String script) async {
  final paths = plan.paths..run.createSync(recursive: true);
  for (final f in [paths.result, paths.health]) {
    if (f.existsSync()) {
      f.deleteSync();
    }
  }
  // UTF-8 with BOM: Windows PowerShell 5.1 reads it as UTF-8.
  paths.script.writeAsStringSync('﻿$script');
  paths.plan.writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert(plan.toJson()),
  );
  // A short PowerShell starts the updater with Start-Process (its own hidden
  // window, independent of NEXA) and ends; its exit code says the updater
  // started. A PowerShell started directly as a detached process ends at
  // once without running anything (found in the Windows update-chain test).
  final r = await Process.run(
    'powershell',
    [
      '-NoProfile',
      '-NonInteractive',
      '-ExecutionPolicy',
      'Bypass',
      // Encoded: no quoting rules of the Windows command line in between.
      '-EncodedCommand',
      encodePowerShell(_launcher),
    ],
    environment: {
      'NEXA_UPD_RUN': paths.run.path,
      'NEXA_UPD_SCRIPT': paths.script.path,
      'NEXA_UPD_PLAN': paths.plan.path,
    },
    // Not the program folder: a process whose current folder is inside it
    // would keep Windows from renaming it.
    workingDirectory: paths.run.path,
  ).timeout(const Duration(seconds: 30));
  if (r.exitCode != 0) {
    throw UpdateException(
      UpdateProblem.installFailed,
      'the updater did not start (${'${r.stderr}'.trim()})',
    );
  }
}

/// Whether NEXA can replace its own folder (Portable): the folder must be
/// writable (when the folder above it is not, the updater copies in place).
bool canReplace(Directory appDir) {
  for (final dir in [appDir]) {
    final probe = File(p.join(dir.path, '.nexa_write_test_$pid'));
    try {
      probe.writeAsStringSync('x');
      probe.deleteSync();
    } on FileSystemException {
      return false;
    }
  }
  return true;
}
