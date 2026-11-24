import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'playback_engine.dart';

/// NEXA Mix Engine (Phase 4): two decks, so the next file can be preloaded
/// and overlapped with an equal-power crossfade.
///
/// * Cut: the active deck plays its file to the end ([completed]).
/// * Gapless: handled inside the active deck (preloaded playlist entry),
///   no overlap.
/// * Crossfade: the idle deck preloads the next file paused; when the active
///   file reaches `duration - fade`, both play and the gains follow
///   cos / sin (equal power, constant loudness). Afterwards the old deck
///   stops and the decks swap. If preloading fails, the transition falls
///   back to a normal cut.
///
/// Only one file is audible at a time except during a crossfade.
class MixingEngine implements PlaybackEngine {
  MixingEngine({
    required PlaybackEngine Function() createDeck,
    DateTime Function()? clock,
    Duration tick = const Duration(milliseconds: 40),
    bool autoTick = true,
  }) : _decks = [createDeck(), createDeck()],
       _clock = clock ?? DateTime.now {
    for (var i = 0; i < 2; i++) {
      final deck = _decks[i];
      _subs
        ..add(deck.states.listen((s) => _onDeckState(i, s)))
        ..add(deck.completed.listen((_) => _onDeckCompleted(i)))
        ..add(deck.errors.listen((e) => _onDeckError(i, e)))
        ..add(deck.advanced.listen((p) => _onDeckAdvanced(i, p)));
    }
    _subs.add(_decks[0].devices.listen(_devices.add));
    if (autoTick) {
      _timer = Timer.periodic(tick, (_) => onTick());
    }
  }

  final List<PlaybackEngine> _decks;
  final DateTime Function() _clock;
  final List<StreamSubscription<Object?>> _subs = [];
  Timer? _timer;

  final _states = StreamController<EngineState>.broadcast(sync: true);
  final _completed = StreamController<void>.broadcast(sync: true);
  final _errors = StreamController<String>.broadcast(sync: true);
  final _advanced = StreamController<String>.broadcast(sync: true);
  final _devices = StreamController<List<OutputDevice>>.broadcast();

  int _active = 0;
  int get _idle => 1 - _active;
  double _volume = 1;

  String? _nextPath;
  TransitionPlan _nextPlan = TransitionPlan.cut;

  /// The idle deck holds [_nextPath], paused, ready for a crossfade.
  bool _preloaded = false;

  /// Crossfade in progress: start time and length.
  DateTime? _fadeStart;
  Duration _fadeLength = Duration.zero;

  bool _disposed = false;

  @visibleForTesting
  PlaybackEngine get activeDeck => _decks[_active];

  @visibleForTesting
  PlaybackEngine get idleDeck => _decks[_idle];

  /// True while both decks are audible.
  bool get isFading => _fadeStart != null;

  /// Equal-power gains (outgoing, incoming) at fade progress [t] (0..1).
  static (double, double) equalPowerGains(double t) {
    final x = t.clamp(0.0, 1.0) * math.pi / 2;
    return (math.cos(x), math.sin(x));
  }

  /// Deck volume for a user volume and an amplitude gain. The deck volume
  /// is perceptual (mpv applies a cubic curve), so the gain enters as its
  /// cube root: the resulting amplitude is `volume^3 * gain`.
  static double deckVolume(double volume, double gain) =>
      volume * math.pow(gain.clamp(0.0, 1.0), 1 / 3).toDouble();

  // ---- deck events ----

  void _onDeckState(int deck, EngineState s) {
    if (deck == _active && !_states.isClosed) {
      _states.add(s);
    }
  }

  void _onDeckCompleted(int deck) {
    if (deck != _active || isFading) {
      return;
    }
    // A crossfade that never started (e.g. very short file): play the
    // preloaded next file right away.
    if (_preloaded && _nextPath != null) {
      unawaited(_swapToPreloaded());
      return;
    }
    _completed.add(null);
  }

  void _onDeckAdvanced(int deck, String path) {
    if (deck != _active) {
      return;
    }
    _nextPath = null;
    _nextPlan = TransitionPlan.cut;
    _advanced.add(path);
  }

  void _onDeckError(int deck, String error) {
    if (deck == _active) {
      _errors.add(error);
    } else {
      // Preloading failed: fall back to a normal transition.
      _preloaded = false;
    }
  }

  // ---- crossfade ----

  /// Checks whether a crossfade must start or advance. Called by a timer;
  /// tests call it directly with a controlled clock.
  @visibleForTesting
  void onTick() {
    if (_disposed) {
      return;
    }
    final start = _fadeStart;
    if (start != null) {
      final elapsed = _clock().difference(start);
      final t = _fadeLength.inMicroseconds == 0
          ? 1.0
          : elapsed.inMicroseconds / _fadeLength.inMicroseconds;
      if (t >= 1) {
        unawaited(_finishFade());
      } else {
        unawaited(_applyFadeGains(t));
      }
      return;
    }
    if (!_preloaded || _nextPlan.kind != TransitionKind.crossfade) {
      return;
    }
    final s = activeDeck.state;
    if (!s.playing || s.duration <= Duration.zero) {
      return;
    }
    // Smart Mix may end the current file early (silent tail, faded outro).
    final planEnd = _nextPlan.endAt;
    final end = planEnd != null && planEnd > Duration.zero && planEnd < s.duration
        ? planEnd
        : s.duration;
    final fade = _nextPlan.fade < end ? _nextPlan.fade : end;
    if (end - s.position <= fade) {
      final left = end - s.position;
      unawaited(_startFade(left > Duration.zero ? left : Duration.zero));
    }
  }

  Future<void> _startFade(Duration remaining) async {
    _fadeStart = _clock();
    _fadeLength = remaining > Duration.zero ? remaining : Duration.zero;
    await _applyFadeGains(0);
    // Smart Mix: the next file starts after its silent intro (sought here:
    // by now the preloaded file is open).
    final start = _nextPlan.startAt;
    if (start != null && start > Duration.zero) {
      await idleDeck.seek(start);
    }
    await idleDeck.play();
  }

  Future<void> _applyFadeGains(double t) async {
    final (out, inc) = equalPowerGains(t);
    await activeDeck.setVolume(deckVolume(_volume, out));
    await idleDeck.setVolume(deckVolume(_volume, inc));
  }

  Future<void> _finishFade() async {
    _fadeStart = null;
    final old = activeDeck;
    final path = _nextPath;
    _active = _idle;
    _preloaded = false;
    _nextPath = null;
    _nextPlan = TransitionPlan.cut;
    await activeDeck.setVolume(_volume);
    await old.stop();
    await old.setVolume(_volume);
    if (path != null) {
      _advanced.add(path);
    }
    _states.add(activeDeck.state);
  }

  Future<void> _swapToPreloaded() async {
    final old = activeDeck;
    final path = _nextPath!;
    _active = _idle;
    _preloaded = false;
    _nextPath = null;
    _nextPlan = TransitionPlan.cut;
    await activeDeck.setVolume(_volume);
    await activeDeck.play();
    await old.stop();
    _advanced.add(path);
  }

  Future<void> _cancelFade() async {
    if (_fadeStart == null) {
      return;
    }
    // Finish immediately on the incoming deck.
    await _finishFade();
  }

  // ---- PlaybackEngine ----

  @override
  Stream<EngineState> get states => _states.stream;

  @override
  Stream<void> get completed => _completed.stream;

  @override
  Stream<String> get errors => _errors.stream;

  @override
  Stream<String> get advanced => _advanced.stream;

  @override
  EngineState get state => activeDeck.state;

  @override
  Future<void> load(String path, {bool play = true}) async {
    _fadeStart = null;
    _preloaded = false;
    _nextPath = null;
    _nextPlan = TransitionPlan.cut;
    await idleDeck.stop();
    await idleDeck.setVolume(_volume);
    await activeDeck.setVolume(_volume);
    await activeDeck.load(path, play: play);
  }

  @override
  Future<void> prepareNext(String? path, TransitionPlan plan) async {
    if (isFading) {
      return; // The running transition decides.
    }
    if (path == _nextPath && plan == _nextPlan) {
      return;
    }
    _nextPath = path;
    _nextPlan = path == null ? TransitionPlan.cut : plan;
    _preloaded = false;
    await idleDeck.stop();
    await activeDeck.prepareNext(
      _nextPlan.kind == TransitionKind.gapless ? path : null,
      _nextPlan,
    );
    if (path != null && _nextPlan.kind == TransitionKind.crossfade) {
      await idleDeck.setVolume(0);
      await idleDeck.load(path, play: false);
      _preloaded = idleDeck.state.path == path;
    }
  }

  @override
  Future<void> play() async {
    await activeDeck.play();
    if (isFading) {
      await idleDeck.play();
    }
  }

  @override
  Future<void> pause() async {
    await activeDeck.pause();
    if (isFading) {
      await idleDeck.pause();
    }
  }

  @override
  Future<void> seek(Duration position) async {
    await _cancelFade();
    await activeDeck.seek(position);
  }

  @override
  Future<void> setVolume(double volume) async {
    _volume = volume.clamp(0.0, 1.0);
    if (isFading) {
      return; // Applied on the next tick.
    }
    await activeDeck.setVolume(_volume);
    if (!_preloaded) {
      await idleDeck.setVolume(_volume);
    }
  }

  @override
  Future<void> stop() async {
    _fadeStart = null;
    _preloaded = false;
    _nextPath = null;
    _nextPlan = TransitionPlan.cut;
    await idleDeck.stop();
    await activeDeck.stop();
  }

  @override
  Stream<List<OutputDevice>> get devices => _devices.stream;

  @override
  List<OutputDevice> get availableDevices => _decks[0].availableDevices;

  @override
  Future<void> setDevice(OutputDevice device) async {
    for (final d in _decks) {
      await d.setDevice(device);
    }
  }

  @override
  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;
    _timer?.cancel();
    for (final s in _subs) {
      await s.cancel();
    }
    for (final d in _decks) {
      await d.dispose();
    }
    await _states.close();
    await _completed.close();
    await _errors.close();
    await _advanced.close();
    await _devices.close();
  }
}
