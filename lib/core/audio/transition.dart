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
  const TransitionPlan(this.kind, {this.fade = Duration.zero, this.reason = ''});

  static const TransitionPlan cut = TransitionPlan(TransitionKind.cut);

  final TransitionKind kind;
  final Duration fade;

  /// Short explanation ("Same album: gapless").
  final String reason;

  @override
  bool operator ==(Object other) =>
      other is TransitionPlan &&
      other.kind == kind &&
      other.fade == fade &&
      other.reason == reason;

  @override
  int get hashCode => Object.hash(kind, fade, reason);

  @override
  String toString() => 'TransitionPlan($kind, $fade, $reason)';
}
