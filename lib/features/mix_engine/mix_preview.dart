import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/strings.dart';

/// Transition modes named in Master Plan v1.0 (Phase 4).
enum TransitionMode { crossfade, smartMix, gapless }

/// UI-only preview of the Mix Engine controls (Phase 1).
///
/// Nothing here touches audio and nothing is persisted; the real
/// MixSettings model, persistence and the audio behaviour arrive in Phase 4.
@immutable
class MixPreview {
  const MixPreview({
    this.mode = TransitionMode.crossfade,
    this.crossfadeSeconds = 6,
    this.allowSmartAdjust = true,
  });

  static const double minSeconds = 0;
  static const double maxSeconds = 12;

  final TransitionMode mode;
  final double crossfadeSeconds;
  final bool allowSmartAdjust;

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

  MixPreview copyWith({
    TransitionMode? mode,
    double? crossfadeSeconds,
    bool? allowSmartAdjust,
  }) {
    return MixPreview(
      mode: mode ?? this.mode,
      crossfadeSeconds: crossfadeSeconds ?? this.crossfadeSeconds,
      allowSmartAdjust: allowSmartAdjust ?? this.allowSmartAdjust,
    );
  }
}

class MixPreviewController extends Notifier<MixPreview> {
  @override
  MixPreview build() => const MixPreview();

  void setMode(TransitionMode mode) => state = state.copyWith(mode: mode);

  void setSeconds(double seconds) => state = state.copyWith(
    crossfadeSeconds: seconds
        .clamp(MixPreview.minSeconds, MixPreview.maxSeconds)
        .roundToDouble(),
  );

  void setAllowSmartAdjust(bool value) =>
      state = state.copyWith(allowSmartAdjust: value);
}

final mixPreviewProvider = NotifierProvider<MixPreviewController, MixPreview>(
  MixPreviewController.new,
);
