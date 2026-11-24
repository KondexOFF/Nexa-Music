import 'package:flutter/foundation.dart';

/// How the engine moves from the current file to the next one.
enum TransitionKind {
  /// Normal end of file, then the next file starts (no preloading).
  cut,

  /// Next file is preloaded and follows without added silence or overlap.
  gapless,

  /// End and start overlap; equal-power fade over [TransitionPlan.fade].
  crossfade,
}

/// A decided transition plus the reason shown to the user.
@immutable
class TransitionPlan {
  const TransitionPlan(
    this.kind, {
    this.fade = Duration.zero,
    this.reason = '',
    this.endAt,
    this.startAt,
  });

  static const TransitionPlan cut = TransitionPlan(TransitionKind.cut);

  final TransitionKind kind;
  final Duration fade;

  /// Short explanation ("Same album: gapless").
  final String reason;

  /// Smart Mix (crossfade only): the current file counts as ended here -
  /// the crossfade finishes at this point instead of the file's end (a
  /// silent tail or a faded-out outro is skipped). Null: the file's end.
  final Duration? endAt;

  /// Smart Mix (crossfade only): the next file starts here (after a silent
  /// intro). Null: from the start.
  final Duration? startAt;

  @override
  bool operator ==(Object other) =>
      other is TransitionPlan &&
      other.kind == kind &&
      other.fade == fade &&
      other.reason == reason &&
      other.endAt == endAt &&
      other.startAt == startAt;

  @override
  int get hashCode => Object.hash(kind, fade, reason, endAt, startAt);

  @override
  String toString() =>
      'TransitionPlan($kind, $fade, $reason, end: $endAt, start: $startAt)';
}
