import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../app/strings.dart';
import '../../app/theme/nexa_theme.dart';
import '../../app/theme/tokens.dart';
import '../../core/settings/settings_provider.dart';
import '../../ui/nexa_widgets.dart';
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
        await ctl.setPath(dir);
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
          await choose();
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
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(S.adBlockTitle, style: NexaText.title),
                  SizedBox(height: 4),
                  Text(S.adBlockInfo, style: NexaText.caption),
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
                  ? S.adBlockFolder(s.path!)
                  : S.adBlockBadFolder(s.path!),
              style: NexaText.caption.copyWith(
                color: s.path != null && !s.pathValid ? NexaColors.coral : null,
              ),
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
      ],
    );
  }
}
