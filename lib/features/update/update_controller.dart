import 'dart:async';
import 'dart:io';
import 'dart:ui' show AppExitType;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../app/config.dart';
import '../../core/database/app_database.dart';
import '../../core/database/database_safety.dart';
import '../../core/settings/settings_provider.dart';
import '../../core/settings/settings_repository.dart';
import '../discover/catalog_providers.dart';
import '../library/library_providers.dart';
import 'release.dart';
import 'semver.dart';
import 'update_installer.dart';
import 'update_source.dart';

enum UpdatePhase {
  idle,
  checking,
  upToDate,
  available,
  downloading,
  ready,
  installing,
  error,
}

/// At most one automatic check a day.
bool autoCheckDue(DateTime? lastCheck, DateTime now) =>
    lastCheck == null ||
    now.difference(lastCheck) >= const Duration(hours: 24) ||
    now.isBefore(lastCheck);

@immutable
class UpdateState {
  const UpdateState({
    this.loaded = false,
    this.phase = UpdatePhase.idle,
    this.autoCheck = true,
    this.lastCheck,
    this.skipped,
    this.release,
    this.staged,
    this.downloadPhase = 1,
    this.progress,
    this.problem,
    this.detail = '',
    this.installOnExit = false,
    this.lastResult,
    this.previous = const [],
    this.promptId = 0,
  });

  final bool loaded;
  final UpdatePhase phase;
  final bool autoCheck;
  final DateTime? lastCheck;

  /// "Skip this version".
  final String? skipped;
  final ReleaseInfo? release;
  final StagedUpdate? staged;

  /// 1 download, 2 unpacking.
  final int downloadPhase;
  final double? progress;
  final UpdateProblem? problem;
  final String detail;
  final bool installOnExit;

  /// What the updater did last time (shown once).
  final UpdaterResult? lastResult;

  /// Kept program copies, newest first, older than this version.
  final List<PreviousVersion> previous;

  /// Increases when an automatic check found a version to offer.
  final int promptId;

  bool get isSkipped =>
      release != null && skipped == release!.version.toString();

  UpdateState copyWith({
    bool? loaded,
    UpdatePhase? phase,
    bool? autoCheck,
    DateTime? lastCheck,
    String? skipped,
    ReleaseInfo? release,
    StagedUpdate? staged,
    int? downloadPhase,
    double? progress,
    UpdateProblem? problem,
    String? detail,
    bool? installOnExit,
    UpdaterResult? lastResult,
    List<PreviousVersion>? previous,
    int? promptId,
    bool clearProblem = false,
    bool clearProgress = false,
    bool clearResult = false,
  }) => UpdateState(
    loaded: loaded ?? this.loaded,
    phase: phase ?? this.phase,
    autoCheck: autoCheck ?? this.autoCheck,
    lastCheck: lastCheck ?? this.lastCheck,
    skipped: skipped ?? this.skipped,
    release: release ?? this.release,
    staged: staged ?? this.staged,
    downloadPhase: downloadPhase ?? this.downloadPhase,
    progress: clearProgress ? null : (progress ?? this.progress),
    problem: clearProblem ? null : (problem ?? this.problem),
    detail: clearProblem ? (detail ?? '') : (detail ?? this.detail),
    installOnExit: installOnExit ?? this.installOnExit,
    lastResult: clearResult ? null : (lastResult ?? this.lastResult),
    previous: previous ?? this.previous,
    promptId: promptId ?? this.promptId,
  );
}

/// The daily check runs only in the released app (never in debug runs and
/// tests) and not when `NEXA_UPDATE_AUTO=0` (NEXA AutoTest).
final autoCheckAllowedProvider = Provider<bool>(
  (ref) => kReleaseMode && Platform.environment['NEXA_UPDATE_AUTO'] != '0',
);

/// Database copies (rollback after a migration).
final databaseSafetyProvider = FutureProvider<DatabaseSafety>(
  (ref) => DatabaseSafety.forApp(),
);

/// The folders of the Update Center.
final updatePathsProvider = FutureProvider<UpdatePaths>(
  (ref) => UpdatePaths.forApp(),
);

/// The program folder (the folder of the running nexa_music.exe).
final appProgramDirProvider = Provider<Directory>(
  (ref) => File(Platform.resolvedExecutable).parent,
);

/// Where releases come from: `NEXA_UPDATE_API` (a local test server),
/// `NEXA_UPDATE_SOURCE=gh|anonymous`, otherwise the public API first and
/// the owner's GitHub CLI for a private repository.
final updateSourceProvider = Provider<UpdateSource>((ref) {
  final client = ref.watch(httpClientProvider);
  final testApi = GitHubApiSource.overrideFromEnvironment();
  if (testApi != null) {
    return GitHubApiSource(client, base: testApi, appVersion: kAppVersion);
  }
  final anonymous = GitHubApiSource(client, appVersion: kAppVersion);
  return switch (Platform.environment['NEXA_UPDATE_SOURCE']?.trim()) {
    'gh' => GhCliSource(),
    'anonymous' => anonymous,
    _ => AutoSource(anonymous, GhCliSource()),
  };
});

/// The updater script (an asset of the app).
final updaterScriptProvider = Provider<Future<String> Function()>(
  (ref) => () => rootBundle.loadString('assets/updater/nexa_updater.ps1'),
);

/// Closes NEXA the normal way (players released first, see AppShell).
final appExitProvider = Provider<Future<void> Function()>(
  (ref) => () async {
    await ServicesBinding.instance.exitApplication(AppExitType.cancelable);
  },
);

/// Starts the updater (tests replace it).
final updaterLauncherProvider =
    Provider<Future<void> Function(UpdaterPlan plan, String script)>(
      (ref) => startUpdater,
    );

final updateProvider = NotifierProvider<UpdateController, UpdateState>(
  UpdateController.new,
);

class UpdateController extends Notifier<UpdateState> {
  @override
  UpdateState build() {
    unawaited(_load());
    return const UpdateState();
  }

  SettingsRepository get _repo => ref.read(settingsRepositoryProvider);
  SemVer get _current => SemVer.tryParse(kAppVersion) ?? const SemVer(0, 0, 0);
  bool _busy = false;

  Future<UpdateInstaller> _installer() async => UpdateInstaller(
    paths: await ref.read(updatePathsProvider.future),
    source: ref.read(updateSourceProvider),
    appDir: ref.read(appProgramDirProvider),
  );

  Future<void> _load() async {
    var auto = true;
    DateTime? last;
    String? skipped;
    try {
      auto = await _repo.getBool(SettingKeys.updateAutoCheck) ?? true;
      last = DateTime.tryParse(
        await _repo.getString(SettingKeys.updateLastCheck) ?? '',
      );
      skipped = await _repo.getString(SettingKeys.updateSkipped);
    } on Object {
      // Defaults.
    }
    UpdaterResult? result;
    var previous = const <PreviousVersion>[];
    try {
      final paths = await ref.read(updatePathsProvider.future);
      result = _takeResult(paths);
      if (result == null &&
          (Platform.environment['NEXA_UPDATE_HEALTH'] ?? '').isNotEmpty) {
        // Started by the updater: it writes its result only after this
        // version reported that it runs.
        unawaited(_awaitResult(paths));
      }
      previous = _olderCopies(paths);
      (await _installer()).cleanUp();
    } on Object {
      // No update folder yet.
    }
    if (!ref.mounted) {
      return;
    }
    state = state.copyWith(
      loaded: true,
      autoCheck: auto,
      lastCheck: last,
      skipped: skipped,
      lastResult: result,
      previous: previous,
    );
    if (auto &&
        ref.read(autoCheckAllowedProvider) &&
        autoCheckDue(last, DateTime.now())) {
      await check(auto: true);
    }
  }

  /// The updater's result, shown once (the file stays next to its log).
  static UpdaterResult? _takeResult(UpdatePaths paths) {
    final result = UpdaterResult.read(paths.result);
    if (result != null) {
      final shown = File(p.join(paths.run.path, 'result_shown.json'));
      if (shown.existsSync()) {
        shown.deleteSync();
      }
      paths.result.renameSync(shown.path);
    }
    return result;
  }

  Future<void> _awaitResult(UpdatePaths paths) async {
    for (var i = 0; i < 60; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 500));
      if (!ref.mounted) {
        return;
      }
      final result = _takeResult(paths);
      if (result != null) {
        state = state.copyWith(lastResult: result, previous: _olderCopies(paths));
        return;
      }
    }
  }

  List<PreviousVersion> _olderCopies(UpdatePaths paths) => [
    for (final v in PreviousVersion.list(paths))
      if (v.version < _current) v,
  ];

  Future<void> setAutoCheck(bool on) async {
    state = state.copyWith(autoCheck: on);
    await _repo.setBool(SettingKeys.updateAutoCheck, on);
  }

  /// Settings > About "Check for updates", or the daily automatic check.
  Future<void> check({bool auto = false}) async {
    if (_busy ||
        state.phase == UpdatePhase.downloading ||
        state.phase == UpdatePhase.installing) {
      return;
    }
    _busy = true;
    state = state.copyWith(phase: UpdatePhase.checking, clearProblem: true);
    try {
      final releases = await ref.read(updateSourceProvider).releases();
      final now = DateTime.now();
      await _repo.setString(SettingKeys.updateLastCheck, now.toIso8601String());
      final found = newestUpdate(releases, _current);
      if (!ref.mounted) {
        return;
      }
      if (found == null) {
        state = state.copyWith(phase: UpdatePhase.upToDate, lastCheck: now);
        return;
      }
      final skippedIt = state.skipped == found.version.toString();
      state = state.copyWith(
        phase: UpdatePhase.available,
        release: found,
        lastCheck: now,
        promptId: auto && !skippedIt ? state.promptId + 1 : null,
      );
    } on UpdateException catch (e) {
      if (e.problem != UpdateProblem.offline) {
        await _repo.setString(
          SettingKeys.updateLastCheck,
          DateTime.now().toIso8601String(),
        );
      }
      if (ref.mounted) {
        state = state.copyWith(
          phase: UpdatePhase.error,
          problem: e.problem,
          detail: e.detail,
        );
      }
    } on Object catch (e) {
      if (ref.mounted) {
        state = state.copyWith(
          phase: UpdatePhase.error,
          problem: UpdateProblem.badResponse,
          detail: '$e',
        );
      }
    } finally {
      _busy = false;
    }
  }

  Future<void> skip() async {
    final v = state.release?.version?.toString();
    if (v == null) {
      return;
    }
    state = state.copyWith(skipped: v);
    await _repo.setString(SettingKeys.updateSkipped, v);
  }

  /// "Update now": download, SHA-256, ZIP checks, unpack.
  Future<void> download() async {
    final release = state.release;
    if (release == null || _busy) {
      return;
    }
    _busy = true;
    state = state.copyWith(
      phase: UpdatePhase.downloading,
      downloadPhase: 1,
      progress: 0,
      clearProblem: true,
    );
    try {
      final installer = await _installer();
      if (!canReplace(installer.appDir)) {
        throw const UpdateException(UpdateProblem.installFailed, 'read-only');
      }
      final staged = await installer.prepare(
        release,
        onProgress: (phase, done, total) {
          if (ref.mounted) {
            state = state.copyWith(
              downloadPhase: phase,
              progress: total <= 0 ? null : (done / total).clamp(0, 1),
            );
          }
        },
      );
      if (ref.mounted) {
        state = state.copyWith(
          phase: UpdatePhase.ready,
          staged: staged,
          clearProgress: true,
        );
      }
    } on UpdateException catch (e) {
      if (ref.mounted) {
        state = state.copyWith(
          phase: UpdatePhase.error,
          problem: e.problem,
          detail: e.detail,
          clearProgress: true,
        );
      }
    } on Object catch (e) {
      if (ref.mounted) {
        state = state.copyWith(
          phase: UpdatePhase.error,
          problem: UpdateProblem.installFailed,
          detail: '$e',
          clearProgress: true,
        );
      }
    } finally {
      _busy = false;
    }
  }

  Future<UpdaterPlan?> _installPlan() async {
    final staged = state.staged;
    if (staged == null) {
      return null;
    }
    final paths = await ref.read(updatePathsProvider.future);
    return UpdaterPlan(
      mode: 'install',
      pid: pid,
      appDir: ref.read(appProgramDirProvider).path,
      source: staged.folder.path,
      oldVersion: kAppVersion,
      newVersion: staged.version.toString(),
      oldSchema: AppDatabase.currentSchemaVersion,
      paths: paths,
    );
  }

  /// "Restart and install": the updater starts, NEXA closes.
  Future<void> installNow() async {
    final plan = await _installPlan();
    if (plan == null) {
      return;
    }
    state = state.copyWith(phase: UpdatePhase.installing, installOnExit: false);
    try {
      await ref.read(updaterLauncherProvider)(
        plan,
        await ref.read(updaterScriptProvider)(),
      );
    } on Object catch (e) {
      state = state.copyWith(
        phase: UpdatePhase.error,
        problem: UpdateProblem.installFailed,
        detail: '$e',
      );
      return;
    }
    await ref.read(appExitProvider)();
  }

  /// "Install when I close NEXA".
  void installOnExit() => state = state.copyWith(installOnExit: true);

  /// AppShell, when NEXA closes: starts the updater if the user chose
  /// "Install when I close NEXA".
  Future<void> onExit() async {
    if (!state.installOnExit || state.phase != UpdatePhase.ready) {
      return;
    }
    final plan = await _installPlan();
    if (plan != null) {
      state = state.copyWith(installOnExit: false);
      await ref.read(updaterLauncherProvider)(
        plan,
        await ref.read(updaterScriptProvider)(),
      );
    }
  }

  /// The library copy a rollback to [target] must put back: null when the
  /// library is still readable by it. Throws when it is not and no copy
  /// from before the upgrade exists.
  Future<File?> rollbackCopy(PreviousVersion target) async {
    final safety = await ref.read(databaseSafetyProvider.future);
    final now = DatabaseSafety.schemaOf(safety.database);
    if (now == null || now <= target.schema) {
      return null;
    }
    final copy = safety.list().where((f) {
      return !DatabaseSafety.isProtected(f) &&
          DatabaseSafety.schemaOf(f) == target.schema;
    }).firstOrNull;
    if (copy == null) {
      throw UpdateException(
        UpdateProblem.installFailed,
        'no library copy for schema ${target.schema}',
      );
    }
    return copy;
  }

  /// Rolls back to [target] (confirmed by the user). When the library was
  /// upgraded, the current library is saved first (a protected backup) and
  /// the copy from before the upgrade is requested for the next start of
  /// the older version.
  Future<void> rollback(PreviousVersion target) async {
    try {
      final copy = await rollbackCopy(target);
      final safety = await ref.read(databaseSafetyProvider.future);
      if (copy != null) {
        await safety.backupNow(
          ref.read(appDatabaseProvider),
          reason: 'before_rollback',
        );
      }
      final paths = await ref.read(updatePathsProvider.future);
      state = state.copyWith(phase: UpdatePhase.installing);
      await ref.read(updaterLauncherProvider)(
        UpdaterPlan(
          mode: 'rollback',
          pid: pid,
          appDir: ref.read(appProgramDirProvider).path,
          source: target.folder.path,
          oldVersion: kAppVersion,
          newVersion: target.version.toString(),
          oldSchema: AppDatabase.currentSchemaVersion,
          paths: paths,
          restoreRequest: copy == null
              ? null
              : p.join(safety.dataDir.path, DatabaseSafety.restoreRequestName),
          restoreBackup: copy == null ? null : p.basename(copy.path),
        ),
        await ref.read(updaterScriptProvider)(),
      );
    } on UpdateException catch (e) {
      state = state.copyWith(
        phase: UpdatePhase.error,
        problem: e.problem,
        detail: e.detail,
      );
      return;
    } on Object catch (e) {
      state = state.copyWith(
        phase: UpdatePhase.error,
        problem: UpdateProblem.installFailed,
        detail: '$e',
      );
      return;
    }
    await ref.read(appExitProvider)();
  }

  void dismissResult() => state = state.copyWith(clearResult: true);
}
