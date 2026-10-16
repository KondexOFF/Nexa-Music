import 'dart:async';

import 'package:media_kit/media_kit.dart';

import 'audio_self_test.dart';

/// Phase 0 adapter: exposes a media_kit [Player] through [ProbePlayer].
class MediaKitProbePlayer implements ProbePlayer {
  MediaKitProbePlayer() : _player = Player() {
    _errorSubscription = _player.stream.error.listen((error) {
      _lastError = error;
    });
  }

  final Player _player;
  late final StreamSubscription<String> _errorSubscription;
  String? _lastError;
  bool _disposed = false;

  @override
  Future<void> open(String path) => _player.open(Media(path), play: false);

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> setVolume(double volume) => _player.setVolume(volume);

  @override
  Duration get position => _player.state.position;

  @override
  Duration get duration => _player.state.duration;

  @override
  bool get playing => _player.state.playing;

  @override
  double get volume => _player.state.volume;

  @override
  String? get lastError => _lastError;

  /// Releases the native player. Safe to call more than once.
  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;
    await _errorSubscription.cancel();
    await _player.dispose();
  }
}
