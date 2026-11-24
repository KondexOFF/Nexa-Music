import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' show AppExitType;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../app/strings.dart';
import '../../app/theme/nexa_theme.dart';
import '../../app/theme/tokens.dart';
import '../../core/app_paths.dart';
import '../../core/settings/settings_provider.dart';
import '../../ui/nexa_widgets.dart';
import '../discover/catalog_providers.dart' show linkOpenerProvider;
import '../library/library_dialogs.dart';

// Optional ad blocking in NEXA's web players (owner decision D-026, from
// the X1 experiment of D-023): a local unpacked uBlock Origin Lite in the
// WebView2 profile of the YouTube and SoundCloud players.
//
// Off by default. Blocking YouTube ads violates the YouTube API Services
// Developer Policies (III.I.05-06): the API key or access can be revoked,
// YouTube may detect the blocker, playback may break. NEXA does not bundle
// or download the extension, does not promise that any ad is blocked, and
// its own player (library, Audius, Jamendo) never depends on it: only the
// WebView2 players load it.

const String _keyOn = 'privacy.adBlock.on';
const String _keyPath = 'privacy.adBlock.path';
const String _keyId = 'privacy.adBlock.id';

/// Name fragment of the extension (manifest "name").
const String adBlockNameHint = 'uBlock';

/// The official release page of uBlock Origin Lite (its Chromium .zip).
const String adBlockReleasesUrl =
    'https://github.com/uBlockOrigin/uBOL-home/releases';

/// Unpacks [zip] into the empty folder [dest].
typedef ZipUnpacker = Future<void> Function(String zip, String dest);

/// Windows' own PowerShell Expand-Archive (no extra library). The paths go
/// in environment variables, never into the command text.
Future<void> expandArchive(String zip, String dest) async {
  final r = await Process.run(
    'powershell',
    const [
      '-NoProfile',
      '-NonInteractive',
      '-Command',
      r'Expand-Archive -LiteralPath $env:NEXA_ZIP -DestinationPath $env:NEXA_DEST -Force',
    ],
    environment: {'NEXA_ZIP': zip, 'NEXA_DEST': dest},
  );
  if (r.exitCode != 0) {
    throw FileSystemException('${r.stderr}'.trim(), zip);
  }
}

/// Where unpacked copies are kept (NEXA's data folder) and how.
final adBlockStoreProvider =
    Provider<({Future<Directory> Function() dir, ZipUnpacker unpack})>(
      (ref) => (
        dir: () async => Directory(
          p.join((await appDataDirectory()).path, 'adblock'),
        ).create(recursive: true),
        unpack: expandArchive,
      ),
    );

/// The folder in [root] (or one level below) with an extension manifest.
String? findExtensionFolder(String root) {
  if (File(p.join(root, 'manifest.json')).existsSync()) {
    return root;
  }
  final dir = Directory(root);
  if (!dir.existsSync()) {
    return null;
  }
  for (final e in dir.listSync().whereType<Directory>()) {
    if (File(p.join(e.path, 'manifest.json')).existsSync()) {
      return e.path;
    }
  }
  return null;
}

/// The extension's name from its manifest ('' when unreadable). A
/// localized name ("__MSG_extName__") is read from its default locale.
String extensionName(String folder) {
  try {
    final m = jsonDecode(
      File(p.join(folder, 'manifest.json')).readAsStringSync(),
    );
    if (m is! Map) {
      return '';
    }
    final name = '${m['name'] ?? ''}';
    final msg = RegExp(r'^__MSG_(\w+)__$').firstMatch(name);
    if (msg == null) {
      return name;
    }
    final messages = jsonDecode(
      File(
        p.join(folder, '_locales', '${m['default_locale'] ?? 'en'}',
            'messages.json'),
      ).readAsStringSync(),
    );
    if (messages is Map) {
      final key = msg.group(1)!.toLowerCase();
      for (final MapEntry(key: k, :value) in messages.entries) {
        if ('$k'.toLowerCase() == key && value is Map) {
          return '${value['message'] ?? ''}';
        }
      }
    }
    return '';
  } on Object {
    return '';
  }
}

@immutable
class AdBlockState {
  const AdBlockState({
    this.on = false,
    this.path,
    this.id,
    this.removeRequested = false,
    this.status,
    this.loaded = false,
  });

  final bool on;

  /// Folder of the unpacked uBlock Origin Lite (Chromium MV3 build), chosen
  /// by the user.
  final String? path;

  /// WebView2 extension id while it is installed in the profile.
  final String? id;

  /// "Remove": the extension leaves the profile when a player opens next.
  final bool removeRequested;

  /// Last answer of WebView2, in words (shown in Settings).
  final String? status;
  final bool loaded;

  bool get installed => id != null;

  bool get pathValid =>
      path != null && File(p.join(path!, 'manifest.json')).existsSync();

  AdBlockState copyWith({
    bool? on,
    String? path,
    String? id,
    bool clearId = false,
    bool? removeRequested,
    String? status,
    bool? loaded,
  }) => AdBlockState(
    on: on ?? this.on,
    path: path ?? this.path,
    id: clearId ? null : id ?? this.id,
    removeRequested: removeRequested ?? this.removeRequested,
    status: status ?? this.status,
    loaded: loaded ?? this.loaded,
  );
}

class AdBlockController extends Notifier<AdBlockState> {
  @override
  AdBlockState build() {
    unawaited(_load());
    return const AdBlockState();
  }

  Future<void> _load() async {
    try {
      final repo = ref.read(settingsRepositoryProvider);
      final on = await repo.getString(_keyOn);
      final path = await repo.getString(_keyPath);
      final id = await repo.getString(_keyId);
      if (!ref.mounted) {
        return;
      }
      state = state.copyWith(
        on: on == 'true',
        path: (path ?? '').isEmpty ? null : path,
        id: (id ?? '').isEmpty ? null : id,
        loaded: true,
      );
    } on Object {
      if (ref.mounted) {
        state = state.copyWith(loaded: true);
      }
    }
  }

  Future<void> _save(String key, String value) async {
    try {
      await ref.read(settingsRepositoryProvider).setString(key, value);
    } on Object {
      // The in-memory value still applies for this session.
    }
  }

  Future<void> setOn(bool on) async {
    state = state.copyWith(
      on: on,
      removeRequested: on ? false : null,
      status: S.adBlockNextPlayer,
    );
    await _save(_keyOn, '$on');
  }

  Future<void> setPath(String path) async {
    state = state.copyWith(path: path, status: S.adBlockNextPlayer);
    await _save(_keyPath, path);
  }

  /// Unpacks the downloaded .zip into NEXA's data folder and uses it.
  /// False (with a message) when it is not an unpacked extension.
  Future<bool> installZip(String zip) async {
    final store = ref.read(adBlockStoreProvider);
    state = state.copyWith(status: S.adBlockUnpacking);
    try {
      final root = await store.dir();
      final stamp = DateTime.now().toIso8601String().replaceAll(
        RegExp('[^0-9]'),
        '',
      );
      final dest = Directory(p.join(root.path, 'ubol_$stamp'));
      await dest.create(recursive: true);
      await store.unpack(zip, dest.path);
      final folder = findExtensionFolder(dest.path);
      if (folder == null) {
        await dest.delete(recursive: true);
        state = state.copyWith(status: S.adBlockNotExtension);
        return false;
      }
      await setPath(folder);
      return true;
    } on Object catch (e) {
      state = state.copyWith(status: S.adBlockUnpackFailed('$e'));
      return false;
    }
  }

  /// Switches it off and takes the extension out of the web players'
  /// profile (when a player opens next).
  Future<void> remove() async {
    state = state.copyWith(
      on: false,
      removeRequested: true,
      status: S.adBlockRemoveNext,
    );
    await _save(_keyOn, 'false');
  }

  /// WebView2's answer after a player opened (YouTube / SoundCloud embeds).
  Future<void> report(Map<String, Object?> reply) async {
    final ok = reply['ok'] == true;
    final id = '${reply['id'] ?? ''}';
    final enabled = reply['enabled'] == true;
    final error = '${reply['error'] ?? ''}';
    if (!ok) {
      state = state.copyWith(
        status: error == 'restart'
            ? S.adBlockRestart
            : S.adBlockRefused(error),
      );
      return;
    }
    if (state.removeRequested) {
      state = state.copyWith(
        clearId: true,
        removeRequested: false,
        status: S.adBlockRemoved,
      );
      await _save(_keyId, '');
      return;
    }
    state = state.copyWith(
      id: id.isEmpty ? null : id,
      clearId: id.isEmpty,
      status: enabled ? S.adBlockLoaded : S.adBlockOff,
    );
    await _save(_keyId, id);
  }
}

final adBlockProvider = NotifierProvider<AdBlockController, AdBlockState>(
  AdBlockController.new,
);

/// What the web player embeds pass to WebView2. Null: nothing to do, and
/// WebView2 runs without extension support.
({String path, String id, bool enabled, bool remove})? adBlockRequest(
  AdBlockState s,
) {
  if (!s.loaded) {
    return null;
  }
  if (s.removeRequested && s.installed) {
    return (path: s.path ?? '', id: s.id!, enabled: false, remove: true);
  }
  if (s.on && s.pathValid) {
    return (path: s.path!, id: s.id ?? '', enabled: true, remove: false);
  }
  if (!s.on && s.installed) {
    return (path: s.path ?? '', id: s.id!, enabled: false, remove: false);
  }
  return null;
}

/// Settings - Privacy: ad blocking in the web players.
class AdBlockControls extends ConsumerWidget {
  const AdBlockControls({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(adBlockProvider);
    final ctl = ref.read(adBlockProvider.notifier);

    Future<void> choose() async {
      final dir = await FilePicker.getDirectoryPath(
        dialogTitle: S.adBlockChooseTitle,
      );
      if (dir != null) {
        await ctl.setPath(findExtensionFolder(dir) ?? dir);
      }
    }

    Future<void> chooseZip() async {
      final files = await FilePicker.pickFiles(
        dialogTitle: S.adBlockChooseZipTitle,
        type: FileType.custom,
        allowedExtensions: const ['zip'],
      );
      final zip = files.firstOrNull?.path;
      if (zip != null) {
        await ctl.installZip(zip);
      }
    }

    Future<void> toggle(bool on) async {
      if (on) {
        final ok = await confirmAction(
          context,
          title: S.adBlockWarningTitle,
          body: S.adBlockWarningBody,
          action: S.adBlockSwitchOn,
        );
        if (!ok) {
          return;
        }
        if (!ref.read(adBlockProvider).pathValid) {
          // The simplest way: the .zip from the official release page.
          await chooseZip();
          if (!ref.read(adBlockProvider).pathValid) {
            return;
          }
        }
      }
      await ctl.setOn(on);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(S.adBlockTitle, style: NexaText.title),
                  const SizedBox(height: 4),
                  const Text(S.adBlockInfo, style: NexaText.caption),
                  if (!s.pathValid) ...[
                    const SizedBox(height: 4),
                    const Text(
                      S.adBlockSteps,
                      key: ValueKey('adblock-steps'),
                      style: NexaText.caption,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            Switch(
              key: const ValueKey('adblock-switch'),
              value: s.on,
              onChanged: s.loaded ? (v) => unawaited(toggle(v)) : null,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 16,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              s.path == null
                  ? S.adBlockNoFolder
                  : s.pathValid
                  ? S.adBlockFolder(_described(s.path!))
                  : S.adBlockBadFolder(s.path!),
              style: NexaText.caption.copyWith(
                color: s.path != null && !s.pathValid ? NexaColors.coral : null,
              ),
            ),
            NexaTextLink(
              key: const ValueKey('adblock-get'),
              label: S.adBlockGet,
              showArrow: false,
              onTap: () => unawaited(
                ref.read(linkOpenerProvider)(adBlockReleasesUrl),
              ),
            ),
            NexaTextLink(
              key: const ValueKey('adblock-zip'),
              label: S.adBlockChooseZip,
              showArrow: false,
              onTap: () => unawaited(chooseZip()),
            ),
            NexaTextLink(
              key: const ValueKey('adblock-folder'),
              label: S.adBlockChoose,
              showArrow: false,
              onTap: () => unawaited(choose()),
            ),
            if (s.installed && !s.removeRequested)
              NexaTextLink(
                key: const ValueKey('adblock-remove'),
                label: S.adBlockRemove,
                showArrow: false,
                onTap: () => unawaited(ctl.remove()),
              ),
          ],
        ),
        if (s.status != null) ...[
          const SizedBox(height: 6),
          Text(
            s.status!,
            key: const ValueKey('adblock-status'),
            style: NexaText.caption.copyWith(color: NexaColors.sky),
          ),
        ],
        if (s.status == S.adBlockRestart) ...[
          const SizedBox(height: 6),
          NexaTextLink(
            key: const ValueKey('adblock-restart'),
            label: S.adBlockRestartNow,
            showArrow: false,
            onTap: () => unawaited(restartNexa()),
          ),
        ],
      ],
    );
  }
}

/// "Name (folder)" for the Settings line.
String _described(String folder) {
  final name = extensionName(folder);
  return name.isEmpty ? folder : '$name - $folder';
}

/// Starts NEXA again (WebView2 decides about extension support once per
/// run): a new copy starts two seconds later, this one closes the normal
/// way (players released first, see AppShell).
Future<void> restartNexa() async {
  if (!Platform.isWindows) {
    return;
  }
  await Process.start(
    'powershell',
    const [
      '-NoProfile',
      '-NonInteractive',
      '-WindowStyle',
      'Hidden',
      '-Command',
      r'Start-Sleep -Seconds 2; Start-Process -FilePath $env:NEXA_EXE',
    ],
    environment: {'NEXA_EXE': Platform.resolvedExecutable},
    mode: ProcessStartMode.detached,
  );
  await ServicesBinding.instance.exitApplication(AppExitType.cancelable);
}
