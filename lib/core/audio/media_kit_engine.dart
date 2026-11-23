import 'dart:async';

import 'package:media_kit/media_kit.dart';

import 'playback_engine.dart';

/// [PlaybackEngine] on media_kit / libmpv (engine approved in Phase 0, D-002).
class MediaKitEngine implements PlaybackEngine, QuietDetector {
  MediaKitEngine() : _player = Player() {
    final platform = _player.platform;
    if (platform is NativePlayer) {
      // Gapless (Phase 4): read the next playlist entry ahead and keep the
      // audio output open between compatible files.
      unawaited(platform.setProperty('prefetch-playlist', 'yes'));
      unawaited(platform.setProperty('gapless-audio', 'weak'));
      // Smart Mix v1 (D-026): FFmpeg's silencedetect measures, while the
      // file plays, where its level stays below -40 dBFS for 1.5 s. It only
      // reads the samples (no change to the sound); the result is read
      // from mpv's af-metadata. A failure leaves playback as it is.
      unawaited(
        platform
            .setProperty('af', '@$_quietLabel:lavfi=[silencedetect=n=-40dB:d=1.5]')
            .catchError((Object _) {}),
      );
    }
    _subs = [
      _player.stream.playing.listen((v) {
        // End of one file inside a gapless chain: mpv goes on with the
        // appended file by itself, so this is not a pause.
        if (!v && _player.state.completed && _inGaplessChain) {
          return;
        }
        _emit(_state.copyWith(playing: v));
      }),
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
        if (!done || _state.path == null) {
          return;
        }
        if (!_inGaplessChain) {
          _completed.add(null);
          return;
        }
        // mpv reports the end of every file, also when it continues with
        // the appended next file without a gap. Reacting to that (loading
        // the next song again) cut ~0.2 s off every song, left a short
        // silence and skipped every third song (NEXA AutoTest, FT-06).
        // Only a real end - mpv did not go on - counts.
        _endCheck?.cancel();
        _endCheck = Timer(const Duration(milliseconds: 1500), () {
          if (_disposed || !_player.state.completed || _player.state.playing) {
            return;
          }
          _gaplessNext = null;
          _gaplessIndex = null;
          _emit(_state.copyWith(playing: false));
          _completed.add(null);
        });
      }),
      _player.stream.error.listen(_errors.add),
      _player.stream.playlist.listen(_onPlaylist),
      _player.stream.audioDevices.listen((list) {
        _devices.add(_availableFrom(list));
        // A device chosen before mpv listed it (the saved device at start).
        final wanted = _wantedDevice;
        if (wanted != null) {
          final match = list.where((d) => d.name == wanted);
          if (match.isNotEmpty) {
            _wantedDevice = null;
            unawaited(_player.setAudioDevice(match.first));
          }
        }
      }),
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

  static const String _quietLabel = 'nexaquiet';

  @override
  Future<Duration?> quietSince() async {
    final platform = _player.platform;
    if (platform is! NativePlayer) {
      return null;
    }
    try {
      final text = await platform.getProperty('af-metadata/$_quietLabel');
      return parseQuietSince(text);
    } on Object {
      return null;
    }
  }

  /// Reads silencedetect's metadata ("lavfi.silence_start", and
  /// "lavfi.silence_end" once the sound is back) as mpv prints it.
  static Duration? parseQuietSince(String text) {
    double? value(String key) {
      final m = RegExp('$key["\']?\\s*[:=]\\s*["\']?(-?[0-9.]+)').firstMatch(text);
      return m == null ? null : double.tryParse(m.group(1)!);
    }

    final start = value('silence_start');
    if (start == null || start < 0) {
      return null;
    }
    final end = value('silence_end');
    if (end != null && end >= start) {
      return null; // The sound came back.
    }
    return Duration(milliseconds: (start * 1000).round());
  }

  /// Device asked for but not (yet) in mpv's list.
  String? _wantedDevice;

  /// File appended to the mpv playlist for a gapless transition, and its
  /// index in that playlist.
  String? _gaplessNext;
  int? _gaplessIndex;
  Media? _gaplessMedia;

  /// When mpv last moved on to an appended file by itself.
  DateTime? _lastGaplessAdvance;
  Timer? _endCheck;

  bool get _inGaplessChain =>
      _gaplessNext != null ||
      (_lastGaplessAdvance != null &&
          DateTime.now().difference(_lastGaplessAdvance!) <
              const Duration(milliseconds: 1500));
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
    final index = _gaplessIndex;
    if (next == null ||
        index == null ||
        playlist.index != index ||
        index >= playlist.medias.length ||
        playlist.medias[index] != _gaplessMedia) {
      return;
    }
    // mpv moved on to the appended file without a gap.
    _gaplessNext = null;
    _gaplessIndex = null;
    _lastGaplessAdvance = DateTime.now();
    _emit(
      EngineState(path: next, playing: _state.playing, duration: Duration.zero),
    );
    if (!_advanced.isClosed) {
      _advanced.add(next);
    }
    // Finished entries stay in mpv's playlist (it is reset by the next
    // load). Removing them shifted the indices while mpv was still
    // reporting the old position, which skipped every third song in a row
    // (found by NEXA AutoTest, FT-06).
  }

  Future<void> _dropGaplessNext() async {
    final index = _gaplessIndex;
    if (_gaplessNext == null || index == null) {
      return;
    }
    _gaplessNext = null;
    _gaplessIndex = null;
    final playlist = _player.state.playlist;
    // Only an entry that has not started yet.
    if (index < playlist.medias.length && index > playlist.index) {
      await _player.remove(index);
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
    // The playlist only grows while playing, so this index stays valid.
    _gaplessIndex = _player.state.playlist.medias.length;
    final media = Media(path);
    _gaplessMedia = media;
    await _player.add(media);
  }

  @override
  Future<void> load(String path, {bool play = true}) async {
    _endCheck?.cancel();
    _lastGaplessAdvance = null;
    _gaplessNext = null;
    _gaplessIndex = null;
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
    _endCheck?.cancel();
    _lastGaplessAdvance = null;
    _gaplessNext = null;
    _gaplessIndex = null;
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
    // Not listed yet (mpv reports its devices shortly after start): applied
    // as soon as it is; until then the Windows default device plays.
    _wantedDevice = match.isEmpty && !device.isAuto ? device.id : null;
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
    _endCheck?.cancel();
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
