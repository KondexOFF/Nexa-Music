import 'dart:async';

import 'package:nexa_music/core/audio/playback_engine.dart';

/// In-memory [PlaybackEngine] for tests (no native audio).
class FakeEngine implements PlaybackEngine {
  final _states = StreamController<EngineState>.broadcast(sync: true);
  final _completed = StreamController<void>.broadcast(sync: true);
  final _errors = StreamController<String>.broadcast(sync: true);
  final _devices = StreamController<List<OutputDevice>>.broadcast(sync: true);
  final _advanced = StreamController<String>.broadcast(sync: true);

  /// Last [prepareNext] call (path, plan).
  String? preparedPath;
  TransitionPlan? preparedPlan;
  int prepareCalls = 0;
  EngineState _state = const EngineState();

  /// Every file passed to [load], in order.
  final List<String> loads = [];
  double volume = 1;
  OutputDevice? device;

  /// How many files are "playing" at the same time (must never exceed 1).
  int get activeFiles => _state.path != null && _state.playing ? 1 : 0;

  void _emit(EngineState s) {
    _state = s;
    _states.add(s);
  }

  /// Simulates the end of the current file.
  void finishCurrent() {
    _emit(_state.copyWith(position: _state.duration, playing: false));
    _completed.add(null);
  }

  void setPosition(Duration position) =>
      _emit(_state.copyWith(position: position));

  void fail(String message) => _errors.add(message);

  /// Simulates mpv moving on to the gapless file that was prepared.
  void advanceGapless() {
    final next = preparedPath!;
    preparedPath = null;
    _emit(
      EngineState(
        path: next,
        playing: _state.playing,
        duration: const Duration(minutes: 3),
      ),
    );
    _advanced.add(next);
  }

  @override
  Stream<String> get advanced => _advanced.stream;

  @override
  Future<void> prepareNext(String? path, TransitionPlan plan) async {
    prepareCalls++;
    preparedPath = path;
    preparedPlan = plan;
  }

  @override
  Stream<EngineState> get states => _states.stream;
  @override
  Stream<void> get completed => _completed.stream;
  @override
  Stream<String> get errors => _errors.stream;
  @override
  EngineState get state => _state;

  @override
  Future<void> load(String path, {bool play = true}) async {
    loads.add(path);
    _emit(
      EngineState(
        path: path,
        playing: play,
        duration: const Duration(minutes: 3),
      ),
    );
  }

  @override
  Future<void> play() async => _emit(_state.copyWith(playing: true));
  @override
  Future<void> pause() async => _emit(_state.copyWith(playing: false));
  @override
  Future<void> seek(Duration position) async => setPosition(position);
  @override
  Future<void> setVolume(double v) async => volume = v;
  @override
  Future<void> stop() async => _emit(const EngineState());

  @override
  Stream<List<OutputDevice>> get devices => _devices.stream;
  @override
  List<OutputDevice> get availableDevices => const [
    OutputDevice('auto', 'System default'),
    OutputDevice('wasapi/speakers', 'Speakers'),
  ];
  @override
  Future<void> setDevice(OutputDevice d) async => device = d;

  @override
  Future<void> dispose() async {
    await _states.close();
    await _completed.close();
    await _errors.close();
    await _devices.close();
    await _advanced.close();
  }
}
