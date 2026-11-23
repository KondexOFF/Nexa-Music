import 'dart:async';

import 'package:flutter/foundation.dart';

import 'transition.dart';

export 'transition.dart';

/// An audio output device reported by the engine.
@immutable
class OutputDevice {
  const OutputDevice(this.id, this.description);

  /// Engine id; 'auto' follows the Windows default device.
  final String id;
  final String description;

  bool get isAuto => id == 'auto';

  @override
  bool operator ==(Object other) => other is OutputDevice && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// Snapshot of what the engine is doing.
@immutable
class EngineState {
  const EngineState({
    this.path,
    this.playing = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.buffering = false,
  });

  final String? path;
  final bool playing;
  final Duration position;
  final Duration duration;
  final bool buffering;

  EngineState copyWith({
    String? path,
    bool? playing,
    Duration? position,
    Duration? duration,
    bool? buffering,
  }) => EngineState(
    path: path ?? this.path,
    playing: playing ?? this.playing,
    position: position ?? this.position,
    duration: duration ?? this.duration,
    buffering: buffering ?? this.buffering,
  );
}

/// The single audio interface of NEXA Music (Master Plan v1.0, section 3:
/// core/audio). Exactly one track plays at a time; the Mix Engine
/// (Phase 4) builds on this.
abstract interface class PlaybackEngine {
  /// State changes (position updates several times per second).
  Stream<EngineState> get states;

  /// Fires when the current file has played to its end.
  Stream<void> get completed;

  /// Readable engine errors (file cannot be decoded, device lost ...).
  Stream<String> get errors;

  /// Fires with the path that became current through a prepared transition
  /// (gapless or crossfade); [completed] does not fire in that case.
  Stream<String> get advanced;

  /// Tells the engine what follows the current file and how ([path] null:
  /// nothing prepared, the file ends normally). Phase 4 Mix Engine.
  Future<void> prepareNext(String? path, TransitionPlan plan);

  EngineState get state;

  /// Replaces the current file. Never plays two files at once.
  Future<void> load(String path, {bool play = true});
  Future<void> play();
  Future<void> pause();
  Future<void> seek(Duration position);

  /// 0.0 (silent) to 1.0 (full).
  Future<void> setVolume(double volume);

  /// Stops and unloads the current file.
  Future<void> stop();

  Stream<List<OutputDevice>> get devices;
  List<OutputDevice> get availableDevices;
  Future<void> setDevice(OutputDevice device);

  Future<void> dispose();
}
