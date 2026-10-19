import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/strings.dart';
import '../../core/settings/settings_provider.dart';
import '../../core/settings/settings_repository.dart';

/// Transition modes named in Master Plan v1.0 (Phase 4).
enum TransitionMode { crossfade, smartMix, gapless }

/// MixSettings (Master Plan v1.0, section 3): mode, transition seconds,
/// permission for Smart Mix adjustments, album exception. Saved locally.
@immutable
class MixSettings {
  const MixSettings({
    this.mode = TransitionMode.crossfade,
    this.crossfadeSeconds = 6,
    this.allowSmartAdjust = true,
    this.albumGapless = true,
  });

  static const double minSeconds = 0;
  static const double maxSeconds = 12;

  final TransitionMode mode;
  final double crossfadeSeconds;

  /// Smart Mix may shorten (never lengthen) the transition.
  final bool allowSmartAdjust;

  /// Consecutive tracks of the same album always play gapless, never mixed
  /// (concert and continuous albums).
  final bool albumGapless;

  /// Share (0..0.5) of the preview width where both tracks overlap.
  double get overlapFraction => switch (mode) {
    TransitionMode.gapless => 0,
    TransitionMode.crossfade => crossfadeSeconds / maxSeconds * 0.5,
    TransitionMode.smartMix => crossfadeSeconds / maxSeconds * 0.35,
  };

  /// Label for the Mix Engine chip in the bottom player.
  String get chipLabel => switch (mode) {
    TransitionMode.gapless => S.modeGapless,
    TransitionMode.smartMix => S.modeSmartMix,
    TransitionMode.crossfade =>
      crossfadeSeconds == 0
          ? '${S.modeCrossfade} off'
          : '${S.modeCrossfade} ${crossfadeSeconds.round()}s',
  };

  MixSettings copyWith({
    TransitionMode? mode,
    double? crossfadeSeconds,
    bool? allowSmartAdjust,
    bool? albumGapless,
  }) => MixSettings(
    mode: mode ?? this.mode,
    crossfadeSeconds: crossfadeSeconds ?? this.crossfadeSeconds,
    allowSmartAdjust: allowSmartAdjust ?? this.allowSmartAdjust,
    albumGapless: albumGapless ?? this.albumGapless,
  );

  @override
  bool operator ==(Object other) =>
      other is MixSettings &&
      other.mode == mode &&
      other.crossfadeSeconds == crossfadeSeconds &&
      other.allowSmartAdjust == allowSmartAdjust &&
      other.albumGapless == albumGapless;

  @override
  int get hashCode =>
      Object.hash(mode, crossfadeSeconds, allowSmartAdjust, albumGapless);
}

class MixSettingsController extends Notifier<MixSettings> {
  @override
  MixSettings build() {
    unawaited(_restore());
    return const MixSettings();
  }

  SettingsRepository get _repo => ref.read(settingsRepositoryProvider);

  Future<void> _restore() async {
    try {
      final mode = await _repo.getString(SettingKeys.mixMode);
      final seconds = await _repo.getDouble(SettingKeys.mixSeconds);
      final smart = await _repo.getBool(SettingKeys.mixSmartAdjust);
      final album = await _repo.getBool(SettingKeys.mixAlbumGapless);
      if (!ref.mounted) {
        return;
      }
      state = state.copyWith(
        mode: TransitionMode.values.where((m) => m.name == mode).firstOrNull,
        crossfadeSeconds: seconds == null ? null : _clampSeconds(seconds),
        allowSmartAdjust: smart,
        albumGapless: album,
      );
    } on Object {
      // Defaults are fine.
    }
  }

  static double _clampSeconds(double s) =>
      s.clamp(MixSettings.minSeconds, MixSettings.maxSeconds).roundToDouble();

  Future<void> _save(String key, String value) async {
    try {
      await _repo.setString(key, value);
    } on Object {
      // The change still applies for this session.
    }
  }

  void setMode(TransitionMode mode) {
    state = state.copyWith(mode: mode);
    unawaited(_save(SettingKeys.mixMode, mode.name));
  }

  void setSeconds(double seconds) {
    state = state.copyWith(crossfadeSeconds: _clampSeconds(seconds));
    unawaited(
      _save(SettingKeys.mixSeconds, state.crossfadeSeconds.toString()),
    );
  }

  void setAllowSmartAdjust(bool value) {
    state = state.copyWith(allowSmartAdjust: value);
    unawaited(_save(SettingKeys.mixSmartAdjust, value.toString()));
  }

  void setAlbumGapless(bool value) {
    state = state.copyWith(albumGapless: value);
    unawaited(_save(SettingKeys.mixAlbumGapless, value.toString()));
  }
}

final mixSettingsProvider = NotifierProvider<MixSettingsController, MixSettings>(
  MixSettingsController.new,
);
