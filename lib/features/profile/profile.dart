import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Color;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../core/app_paths.dart';
import '../../core/settings/settings_provider.dart';
import '../../core/settings/settings_repository.dart';

/// D-042 Local Profile: a name and picture for this computer, the accent
/// colour and how lively NEXARYVE looks. No account, no server - stored in
/// the local settings table; an own picture is copied into the app's data
/// folder (the original file is only read).

/// How much NEXARYVE moves.
enum MotionLevel {
  /// Every transition and the slow ambient movement.
  full,

  /// Short fades only; nothing loops.
  reduced,

  /// No animation.
  off,
}

/// One accent colour the user can pick.
@immutable
class AccentChoice {
  const AccentChoice(this.id, this.name, this.color, this.deep, this.glow);

  final String id;
  final String name;

  /// Text, icons, selected states.
  final Color color;

  /// Filled buttons and the start of gradients.
  final Color deep;

  /// End of gradients and highlights (pink in the default violet).
  final Color glow;
}

/// Accent presets (the first is the NEXARYVE default from the approved
/// Signature concept: violet into magenta).
const List<AccentChoice> accentChoices = [
  AccentChoice('violet', 'Violet', Color(0xFFB69CFF), Color(0xFF8B5CF6), Color(0xFFE15FED)),
  AccentChoice('indigo', 'Indigo', Color(0xFF9DB2FF), Color(0xFF5B6CF6), Color(0xFF7DD3FC)),
  AccentChoice('magenta', 'Magenta', Color(0xFFF59AE8), Color(0xFFD946EF), Color(0xFFFF8FB3)),
  AccentChoice('coral', 'Coral', Color(0xFFFFA48F), Color(0xFFF26B57), Color(0xFFFFC56E)),
  AccentChoice('aqua', 'Aqua', Color(0xFF7FE3E0), Color(0xFF14B8A6), Color(0xFF60A5FA)),
  AccentChoice('lime', 'Lime', Color(0xFFC6F08A), Color(0xFF65A30D), Color(0xFF34D399)),
];

AccentChoice accentById(String? id) => accentChoices.firstWhere(
  (a) => a.id == id,
  orElse: () => accentChoices.first,
);

/// Number of built-in avatars ([ProfileAvatar] paints them).
const int standardAvatarCount = 8;

@immutable
class ProfileState {
  const ProfileState({
    this.loaded = false,
    this.nickname = '',
    this.avatar = 'preset:0',
    this.accentId = 'violet',
    this.atmosphere = true,
    this.motion = MotionLevel.full,
  });

  final bool loaded;

  /// Empty: no name (the greeting has none).
  final String nickname;

  /// `preset:<n>` or `file:<path of the copy in the data folder>`.
  final String avatar;
  final String accentId;

  /// Light from cover art and the glow behind pages.
  final bool atmosphere;
  final MotionLevel motion;

  AccentChoice get accent => accentById(accentId);

  int? get presetAvatar => avatar.startsWith('preset:')
      ? int.tryParse(avatar.substring(7))?.clamp(0, standardAvatarCount - 1)
      : null;

  String? get avatarFile =>
      avatar.startsWith('file:') ? avatar.substring(5) : null;

  ProfileState copyWith({
    bool? loaded,
    String? nickname,
    String? avatar,
    String? accentId,
    bool? atmosphere,
    MotionLevel? motion,
  }) => ProfileState(
    loaded: loaded ?? this.loaded,
    nickname: nickname ?? this.nickname,
    avatar: avatar ?? this.avatar,
    accentId: accentId ?? this.accentId,
    atmosphere: atmosphere ?? this.atmosphere,
    motion: motion ?? this.motion,
  );
}

abstract final class ProfileKeys {
  static const String nickname = 'profile.nickname';
  static const String avatar = 'profile.avatar';
  static const String accent = 'profile.accent';
  static const String atmosphere = 'profile.atmosphere';
  static const String motion = 'profile.motion';
}

/// Where an own avatar picture is copied to. Tests override this.
final profileDirProvider = FutureProvider<Directory>(
  (ref) async => Directory(p.join((await appDataDirectory()).path, 'profile')),
);

/// Longest nickname kept.
const int nicknameMaxLength = 32;

/// Largest own avatar picture accepted (bytes).
const int avatarMaxBytes = 8 * 1024 * 1024;

const Set<String> avatarExtensions = {'.png', '.jpg', '.jpeg', '.webp', '.gif', '.bmp'};

class ProfileController extends Notifier<ProfileState> {
  @override
  ProfileState build() {
    unawaited(_restore());
    return const ProfileState();
  }

  SettingsRepository get _repo => ref.read(settingsRepositoryProvider);

  Future<void> _restore() async {
    try {
      final nickname = await _repo.getString(ProfileKeys.nickname);
      final avatar = await _repo.getString(ProfileKeys.avatar);
      final accent = await _repo.getString(ProfileKeys.accent);
      final atmosphere = await _repo.getBool(ProfileKeys.atmosphere);
      final motion = await _repo.getString(ProfileKeys.motion);
      if (!ref.mounted) {
        return;
      }
      var picture = avatar ?? state.avatar;
      if (picture.startsWith('file:') && !File(picture.substring(5)).existsSync()) {
        picture = 'preset:0'; // The copy was removed outside NEXARYVE.
      }
      state = state.copyWith(
        loaded: true,
        nickname: nickname,
        avatar: picture,
        accentId: accentById(accent).id,
        atmosphere: atmosphere,
        motion: MotionLevel.values.asNameMap()[motion],
      );
    } on Object {
      if (ref.mounted) {
        state = state.copyWith(loaded: true); // No database (tests).
      }
    }
  }

  Future<void> _save(String key, String value) async {
    try {
      await _repo.setString(key, value);
    } on Object {
      // No database (tests) - the change still applies for this session.
    }
  }

  Future<void> setNickname(String value) async {
    var name = value.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (name.length > nicknameMaxLength) {
      name = name.substring(0, nicknameMaxLength).trimRight();
    }
    state = state.copyWith(nickname: name);
    await _save(ProfileKeys.nickname, name);
  }

  Future<void> setStandardAvatar(int index) async {
    final old = state.avatarFile;
    state = state.copyWith(avatar: 'preset:${index.clamp(0, standardAvatarCount - 1)}');
    await _save(ProfileKeys.avatar, state.avatar);
    await _deleteOwnCopy(old);
  }

  /// Copies the picture at [source] into the profile folder and uses it.
  /// Returns an error text, or null when done.
  Future<String?> setOwnAvatar(String source) async {
    final file = File(source);
    final ext = p.extension(source).toLowerCase();
    if (!avatarExtensions.contains(ext)) {
      return 'Choose a PNG, JPG, WEBP, GIF or BMP picture';
    }
    if (!file.existsSync()) {
      return 'The picture was not found';
    }
    if (file.lengthSync() > avatarMaxBytes) {
      return 'The picture is larger than 8 MB';
    }
    final dir = await ref.read(profileDirProvider.future);
    await dir.create(recursive: true);
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final copy = await file.copy(p.join(dir.path, 'avatar_$stamp$ext'));
    final old = state.avatarFile;
    state = state.copyWith(avatar: 'file:${copy.path}');
    await _save(ProfileKeys.avatar, state.avatar);
    await _deleteOwnCopy(old);
    return null;
  }

  /// Removes NEXARYVE's own copy of an earlier avatar (only files inside
  /// the profile folder, never the picture the user chose).
  Future<void> _deleteOwnCopy(String? path) async {
    if (path == null) {
      return;
    }
    try {
      final dir = await ref.read(profileDirProvider.future);
      if (p.isWithin(dir.path, path) && p.basename(path).startsWith('avatar_')) {
        final f = File(path);
        if (f.existsSync()) {
          f.deleteSync();
        }
      }
    } on Object {
      // Left in place; harmless.
    }
  }

  Future<void> setAccent(String id) async {
    state = state.copyWith(accentId: accentById(id).id);
    await _save(ProfileKeys.accent, state.accentId);
  }

  Future<void> setAtmosphere(bool on) async {
    state = state.copyWith(atmosphere: on);
    await _save(ProfileKeys.atmosphere, '$on');
  }

  Future<void> setMotion(MotionLevel level) async {
    state = state.copyWith(motion: level);
    await _save(ProfileKeys.motion, level.name);
  }

  /// "Reset appearance": accent, atmosphere and motion back to the
  /// defaults. Music, playlists, history, NEXARYVE DNA, the name and the
  /// picture are not touched.
  Future<void> resetAppearance() async {
    const defaults = ProfileState();
    state = state.copyWith(
      accentId: defaults.accentId,
      atmosphere: defaults.atmosphere,
      motion: defaults.motion,
    );
    await _save(ProfileKeys.accent, defaults.accentId);
    await _save(ProfileKeys.atmosphere, '${defaults.atmosphere}');
    await _save(ProfileKeys.motion, defaults.motion.name);
  }
}

final profileProvider = NotifierProvider<ProfileController, ProfileState>(
  ProfileController.new,
);
