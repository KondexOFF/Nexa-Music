import '../../app/strings.dart';
import '../../core/audio/transition.dart';
import '../../core/models/track.dart';
import '../library/tag_reader.dart' show unknownAlbum;
import 'mix_settings.dart';

/// Decides how [current] hands over to [next] (Phase 4, Master Plan v1.0).
///
/// Simple, explainable rules only - no tempo or key analysis:
/// 1. A source that does not allow mixing never overlaps (normal cut).
/// 2. The next track of the same album (track number + 1) plays gapless,
///    so concert and continuous albums are never mixed (setting).
/// 3. Gapless mode: gapless. Crossfade 0 s: gapless (no overlap).
/// 4. Crossfade: the chosen seconds, but at most a third of the shorter
///    track; under 1 s it falls back to gapless.
/// 5. Smart Mix v1: like Crossfade, but with the "allow" switch on it
///    shortens the overlap from the track lengths it knows: 3 s for tracks
///    under one minute, at most a quarter of the shorter track. Silence and
///    signal-level analysis are not implemented yet (TD-07).
TransitionPlan planTransition(MixSettings s, Track current, Track next) {
  if (!current.rights.mix || !next.rights.mix) {
    return const TransitionPlan(TransitionKind.cut, reason: S.planNoMixRights);
  }
  if (s.albumGapless && continuesAlbum(current, next)) {
    return const TransitionPlan(
      TransitionKind.gapless,
      reason: S.planSameAlbum,
    );
  }
  if (s.mode == TransitionMode.gapless) {
    return const TransitionPlan(
      TransitionKind.gapless,
      reason: S.planGaplessMode,
    );
  }
  if (s.crossfadeSeconds <= 0) {
    return const TransitionPlan(
      TransitionKind.gapless,
      reason: S.planCrossfadeOff,
    );
  }

  var fade = Duration(milliseconds: (s.crossfadeSeconds * 1000).round());
  var reason = s.mode == TransitionMode.smartMix
      ? S.planSmartDefault
      : S.planCrossfade;
  final shorter = _shorter(current.duration, next.duration);

  if (s.mode == TransitionMode.smartMix && s.allowSmartAdjust && shorter != null) {
    if (shorter < const Duration(minutes: 1) && fade > _smartShort) {
      fade = _smartShort;
      reason = S.planSmartShortTrack;
    }
    final quarter = shorter ~/ 4;
    if (fade > quarter) {
      fade = quarter;
      reason = S.planSmartShortTrack;
    }
  }
  if (shorter != null) {
    final third = shorter ~/ 3;
    if (fade > third) {
      fade = third;
      reason = S.planLimitedByLength;
    }
  }
  if (fade < const Duration(seconds: 1)) {
    return const TransitionPlan(
      TransitionKind.gapless,
      reason: S.planTooShort,
    );
  }
  return TransitionPlan(
    TransitionKind.crossfade,
    fade: fade,
    reason: reason,
    quietEnd: s.mode == TransitionMode.smartMix && s.allowSmartAdjust,
  );
}

const Duration _smartShort = Duration(seconds: 3);

Duration? _shorter(Duration? a, Duration? b) {
  if (a == null || a <= Duration.zero) {
    return b != null && b > Duration.zero ? b : null;
  }
  if (b == null || b <= Duration.zero) {
    return a;
  }
  return a < b ? a : b;
}

/// [next] is the following track of the same album (and disc).
bool continuesAlbum(Track current, Track next) {
  final album = current.album.trim().toLowerCase();
  if (album.isEmpty ||
      album == unknownAlbum.toLowerCase() ||
      album != next.album.trim().toLowerCase()) {
    return false;
  }
  final a = current.trackNumber;
  final b = next.trackNumber;
  if (a == null || b == null || b != a + 1) {
    return false;
  }
  return (current.discNumber ?? 1) == (next.discNumber ?? 1);
}
