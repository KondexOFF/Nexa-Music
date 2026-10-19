import 'dart:async';

import 'package:media_kit/media_kit.dart';

import 'playback_engine.dart';

/// [PlaybackEngine] on media_kit / libmpv (engine approved in Phase 0, D-002).
class MediaKitEngine implements PlaybackEngine {
  MediaKitEngine() : _player = Player() {
    final platform = _player.platform;
    if (platform is NativePlayer) {
      // Gapless (Phase 4): read the next playlist entry ahead and keep the
      // audio output open between compatible files.
      unawaited(platform.setProperty('prefetch-playlist', 'yes'));
      unawaited(platform.setProperty('gapless-audio', 'weak'));
    }
    _subs = [
      _player.stream.playing.listen((v) => _emit(_state.copyWith(playing: v))),
      _player.stream.position.listen(
        (v) => _emit(_state.copyWith(position: v)),
      ),
      _player.stream.duration.listen(
        (v) => _emit(_state.copyWith(duration: v)),
      ),
      _player.stream.buffering.listen(
        (v) => _emit(_state.copyWith(buffering: v)),
      ),
      _player.stream.completed.listen((done) {
        if (done && _state.path != null) {
          _completed.add(null);
        }
      }),
      _player.stream.error.listen(_errors.add),
      _player.stream.playlist.listen(_onPlaylist),
      _player.stream.audioDevices.listen(
        (list) => _devices.add(_availableFrom(list)),
      ),
    ];
  }

  final Player _player;
  late final List<StreamSubscription<Object?>> _subs;
  final _states = StreamController<EngineState>.broadcast();
  final _completed = StreamController<void>.broadcast();
  final _errors = StreamController<String>.broadcast();
  final _devices = StreamController<List<OutputDevice>>.broadcast();
  final _advanced = StreamController<String>.broadcast();
  EngineState _state = const EngineState();

  /// File appended to the mpv playlist for a gapless transition.
  String? _gaplessNext;
  bool _disposed = false;

  void _emit(EngineState next) {
    _state = next;
    if (!_states.isClosed) {
      _states.add(next);
    }
  }

  static List<OutputDevice> _availableFrom(List<AudioDevice> list) => [
    for (final d in list)
      OutputDevice(d.name, d.name == 'auto' ? 'System default' : d.description),
  ];

  @override
  Stream<EngineState> get states => _states.stream;

  @override
  Stream<void> get completed => _completed.stream;

  @override
  Stream<String> get errors => _errors.stream;

  @override
  EngineState get state => _state;

  @override
  Stream<String> get advanced => _advanced.stream;

  void _onPlaylist(Playlist playlist) {
    final next = _gaplessNext;
    if (next == null || playlist.index < 1) {
      return;
    }
    // mpv moved on to the appended file without a gap.
    _gaplessNext = null;
    _emit(
      EngineState(path: next, playing: _state.playing, duration: Duration.zero),
    );
    if (!_advanced.isClosed) {
      _advanced.add(next);
    }
    unawaited(_player.remove(0));
  }

  Future<void> _dropGaplessNext() async {
    if (_gaplessNext == null) {
      return;
    }
    _gaplessNext = null;
    final count = _player.state.playlist.medias.length;
    if (count > 1) {
      await _player.remove(count - 1);
    }
  }

  @override
  Future<void> prepareNext(String? path, TransitionPlan plan) async {
    await _dropGaplessNext();
    if (path == null ||
        plan.kind != TransitionKind.gapless ||
        _state.path == null) {
      return;
    }
    _gaplessNext = path;
    await _player.add(Media(path));
  }

  @override
  Future<void> load(String path, {bool play = true}) async {
    _gaplessNext = null;
    _emit(
      EngineState(path: path, duration: Duration.zero, position: Duration.zero),
    );
    await _player.open(Media(path), play: play);
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> setVolume(double volume) =>
      _player.setVolume((volume.clamp(0.0, 1.0) * 100).toDouble());

  @override
  Future<void> stop() async {
    _gaplessNext = null;
    await _player.stop();
    _emit(const EngineState());
  }

  @override
  Stream<List<OutputDevice>> get devices => _devices.stream;

  @override
  List<OutputDevice> get availableDevices =>
      _availableFrom(_player.state.audioDevices);

  @override
  Future<void> setDevice(OutputDevice device) async {
    final match = _player.state.audioDevices.where((d) => d.name == device.id);
    await _player.setAudioDevice(
      match.isEmpty ? AudioDevice.auto() : match.first,
    );
  }

  @override
  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;
    for (final s in _subs) {
      await s.cancel();
    }
    await _player.dispose();
    await _states.close();
    await _completed.close();
    await _errors.close();
    await _devices.close();
    await _advanced.close();
  }
}
