import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/strings.dart';
import '../../core/audio/media_kit_engine.dart';
import '../../core/audio/mixing_engine.dart';
import '../../core/audio/playback_engine.dart';
import '../../core/models/listening.dart';
import '../../core/models/track.dart';
import '../../core/settings/settings_provider.dart';
import '../../core/settings/settings_repository.dart';
import '../mix_engine/mix_settings.dart';
import '../nexa_dna/dna_providers.dart';
import '../mix_engine/transition_planner.dart';

enum PlayerRepeat { off, all, one }

/// One place in the queue. [uid] keeps duplicates of a track apart.
@immutable
class QueueEntry {
  const QueueEntry(this.uid, this.track);

  final int uid;
  final Track track;
}

@immutable
class PlayerState {
  const PlayerState({
    this.queue = const [],
    this.cursor = -1,
    this.playing = false,
    this.volume = 0.8,
    this.muted = false,
    this.shuffle = false,
    this.repeat = PlayerRepeat.off,
    this.context = PlayContext.library,
    this.notice,
    this.noticeId = 0,
  });

  /// Queue in play order (shuffled when [shuffle] is on).
  final List<QueueEntry> queue;

  /// Index of the current entry in [queue]; -1 when nothing is loaded.
  final int cursor;
  final bool playing;
  final double volume;
  final bool muted;
  final bool shuffle;
  final PlayerRepeat repeat;

  /// What started the current queue (Library or NEXA Wave).
  final PlayContext context;

  /// Last message for the user (e.g. a skipped missing file).
  final String? notice;
  final int noticeId;

  QueueEntry? get currentEntry =>
      cursor >= 0 && cursor < queue.length ? queue[cursor] : null;
  Track? get current => currentEntry?.track;
  List<QueueEntry> get upNext =>
      cursor < 0 ? queue : queue.sublist(math.min(cursor + 1, queue.length));
  bool get hasNext => cursor + 1 < queue.length || repeat == PlayerRepeat.all;

  /// The entry that follows automatically (null: playback stops or the
  /// current song repeats).
  QueueEntry? get nextEntry {
    if (cursor < 0 || repeat == PlayerRepeat.one) {
      return null;
    }
    if (cursor + 1 < queue.length) {
      return queue[cursor + 1];
    }
    if (repeat == PlayerRepeat.all && queue.length > 1) {
      return queue[0];
    }
    return null;
  }

  PlayerState copyWith({
    List<QueueEntry>? queue,
    int? cursor,
    bool? playing,
    double? volume,
    bool? muted,
    bool? shuffle,
    PlayerRepeat? repeat,
    PlayContext? context,
    String? notice,
    int? noticeId,
  }) => PlayerState(
    queue: queue ?? this.queue,
    cursor: cursor ?? this.cursor,
    playing: playing ?? this.playing,
    volume: volume ?? this.volume,
    muted: muted ?? this.muted,
    shuffle: shuffle ?? this.shuffle,
    repeat: repeat ?? this.repeat,
    context: context ?? this.context,
    notice: notice ?? this.notice,
    noticeId: noticeId ?? this.noticeId,
  );
}

/// The audio engine. Tests override this with a fake.
final playbackEngineProvider = Provider<PlaybackEngine>((ref) {
  // Two media_kit decks: preloading, gapless and crossfade (Phase 4).
  final engine = MixingEngine(createDeck: MediaKitEngine.new);
  ref.onDispose(engine.dispose);
  return engine;
});

/// Engine position / duration (separate so that only progress widgets
/// rebuild several times per second).
final engineStateProvider = StreamProvider<EngineState>((ref) {
  final engine = ref.watch(playbackEngineProvider);
  return engine.states;
});

final outputDevicesProvider = StreamProvider<List<OutputDevice>>((ref) async* {
  final engine = ref.watch(playbackEngineProvider);
  yield engine.availableDevices;
  yield* engine.devices;
});

/// Queue, transport, shuffle / repeat and volume (Phase 3).
class PlayerController extends Notifier<PlayerState> {
  late PlaybackEngine _engine;
  final List<StreamSubscription<Object?>> _subs = [];
  final math.Random _random = math.Random();
  int _nextUid = 1;

  /// Order before shuffling (to restore it when shuffle is switched off).
  List<QueueEntry> _original = const [];

  // The listening in progress (for the NEXA DNA history).
  Track? _listenTrack;
  DateTime? _listenStart;
  PlayContext _listenContext = PlayContext.library;
  Duration _listenPosition = Duration.zero;
  Duration? _listenDuration;

  /// Catalog streams skipped in a row because they failed (E1); reset as
  /// soon as a song really plays.
  int _failedStreams = 0;

  @override
  PlayerState build() {
    _engine = ref.watch(playbackEngineProvider);
    _subs
      ..add(_engine.completed.listen((_) => _onCompleted()))
      ..add(_engine.errors.listen(_onError))
      ..add(_engine.advanced.listen(_onAdvanced))
      ..add(
        _engine.states.listen((s) {
          final listening = _listenTrack;
          if (listening != null && s.path == listening.path) {
            _listenPosition = s.position;
            if (s.duration > Duration.zero) {
              _listenDuration = s.duration;
            }
          }
          if (s.playing != state.playing) {
            state = state.copyWith(playing: s.playing);
          }
          if (s.playing && s.position > const Duration(seconds: 1)) {
            _failedStreams = 0;
          }
        }),
      );
    ref.onDispose(() {
      for (final s in _subs) {
        s.cancel();
      }
      _subs.clear();
    });
    // Re-plan the next transition when the Mix settings or the queue change.
    ref.listen(mixSettingsProvider, (_, _) => unawaited(_prepareNext()));
    listenSelf((previous, next) {
      if (previous == null ||
          previous.currentEntry?.uid != next.currentEntry?.uid ||
          previous.nextEntry?.uid != next.nextEntry?.uid ||
          previous.repeat != next.repeat) {
        unawaited(_prepareNext());
      }
    });
    unawaited(_restoreSettings());
    return const PlayerState();
  }

  SettingsRepository get _settings => ref.read(settingsRepositoryProvider);

  Future<void> _restoreSettings() async {
    try {
      final volume = await _settings.getDouble(SettingKeys.volume);
      final muted = await _settings.getBool(SettingKeys.muted);
      final shuffle = await _settings.getBool(SettingKeys.shuffle);
      final repeat = await _settings.getString(SettingKeys.repeat);
      final device = await _settings.getString(SettingKeys.audioDevice);
      if (!ref.mounted) {
        return;
      }
      state = state.copyWith(
        volume: volume?.clamp(0.0, 1.0).toDouble(),
        muted: muted,
        shuffle: shuffle,
        repeat: PlayerRepeat.values.where((m) => m.name == repeat).firstOrNull,
      );
      await _applyVolume();
      if (device != null && device != 'auto') {
        await _engine.setDevice(OutputDevice(device, ''));
      }
    } on Object {
      // Settings are a convenience; defaults are fine.
    }
  }

  /// Tells the engine what follows and how (Mix Engine plan).
  Future<void> _prepareNext() async {
    final current = state.current;
    if (current == null || _engine.state.path != current.path) {
      return; // Prepared again after the current file is loaded.
    }
    final next = state.nextEntry?.track;
    if (next == null || !_playable(next)) {
      await _engine.prepareNext(null, TransitionPlan.cut);
      return;
    }
    await _engine.prepareNext(
      next.path,
      planTransition(ref.read(mixSettingsProvider), current, next),
    );
  }

  /// The engine moved to the prepared next file (gapless or crossfade).
  void _onAdvanced(String path) {
    final next = state.nextEntry;
    if (next == null) {
      return;
    }
    _endListening(EndReason.completed);
    state = state.copyWith(cursor: state.queue.indexOf(next));
    _beginListening();
  }

  /// Local files must exist; catalog streams are checked by the engine.
  static bool _playable(Track t) => t.isOnline || File(t.path).existsSync();

  // ---- listening history (NEXA DNA, recorded only with consent) ----

  void _beginListening() {
    if (_listenTrack != null) {
      _endListening(EndReason.skipped);
    }
    final track = state.current;
    // Only library songs are part of the history (catalog tracks: D-017,
    // no history of online tracks without a terms review).
    if (track == null || track.isOnline) {
      return;
    }
    _listenTrack = track;
    _listenStart = DateTime.now();
    _listenContext = state.context;
    _listenPosition = Duration.zero;
    _listenDuration = track.duration;
  }

  void _endListening(EndReason reason) {
    final track = _listenTrack;
    final start = _listenStart;
    _listenTrack = null;
    _listenStart = null;
    if (track == null || start == null) {
      return;
    }
    final duration = _listenDuration;
    final listened = reason == EndReason.completed && duration != null
        ? duration
        : _listenPosition;
    unawaited(
      ref
          .read(listeningRecorderProvider)
          .record(
            ListeningEvent(
              trackId: track.id,
              startedAt: start,
              listened: listened,
              duration: duration,
              reason: reason,
              context: _listenContext,
            ),
          ),
    );
  }

  Future<void> _applyVolume() =>
      _engine.setVolume(state.muted ? 0 : state.volume);

  void _notice(String text) =>
      state = state.copyWith(notice: text, noticeId: state.noticeId + 1);

  List<QueueEntry> _entries(List<Track> tracks) => [
    for (final t in tracks) QueueEntry(_nextUid++, t),
  ];

  // ---- starting playback ----

  /// Plays [tracks] starting at [start] (the queue is replaced).
  Future<void> playTracks(
    List<Track> tracks, {
    int start = 0,
    PlayContext context = PlayContext.library,
  }) async {
    if (tracks.isEmpty) {
      return;
    }
    _endListening(EndReason.skipped);
    final entries = _entries(tracks);
    _original = entries;
    final first = entries[start.clamp(0, entries.length - 1)];
    var queue = entries;
    var cursor = entries.indexOf(first);
    if (state.shuffle) {
      queue = [first, ..._shuffled(entries.where((e) => e != first))];
      cursor = 0;
    }
    state = state.copyWith(queue: queue, cursor: cursor, context: context);
    await _loadCurrent(play: true);
  }

  /// Plays [tracks] in random order.
  Future<void> shuffleTracks(List<Track> tracks) async {
    if (tracks.isEmpty) {
      return;
    }
    if (!state.shuffle) {
      await toggleShuffle();
    }
    await playTracks(tracks, start: _random.nextInt(tracks.length));
  }

  List<QueueEntry> _shuffled(Iterable<QueueEntry> entries) =>
      entries.toList()..shuffle(_random);

  /// Inserts [tracks] right after the current song.
  void playNext(List<Track> tracks) {
    final entries = _entries(tracks);
    final at = state.cursor + 1;
    final queue = [...state.queue]..insertAll(at, entries);
    final currentUid = state.currentEntry?.uid;
    final originalAt = currentUid == null
        ? _original.length
        : _original.indexWhere((e) => e.uid == currentUid) + 1;
    _original = [..._original]..insertAll(originalAt, entries);
    state = state.copyWith(queue: queue);
    if (state.cursor < 0) {
      unawaited(jumpTo(0));
    }
  }

  /// Appends [tracks] to the end of the queue.
  void addToQueue(List<Track> tracks) {
    final entries = _entries(tracks);
    _original = [..._original, ...entries];
    state = state.copyWith(queue: [...state.queue, ...entries]);
    if (state.cursor < 0) {
      unawaited(jumpTo(0));
    }
  }

  void removeFromQueue(int uid) {
    final index = state.queue.indexWhere((e) => e.uid == uid);
    if (index < 0 || index == state.cursor) {
      return;
    }
    final queue = [...state.queue]..removeAt(index);
    _original = _original.where((e) => e.uid != uid).toList();
    state = state.copyWith(
      queue: queue,
      cursor: index < state.cursor ? state.cursor - 1 : state.cursor,
    );
  }

  /// Removes everything except the current song.
  void clearUpNext() {
    final current = state.currentEntry;
    _original = current == null ? const [] : [current];
    state = state.copyWith(
      queue: current == null ? const [] : [current],
      cursor: current == null ? -1 : 0,
    );
  }

  /// Plays the queue entry at [index].
  Future<void> jumpTo(int index) async {
    if (index < 0 || index >= state.queue.length) {
      return;
    }
    _endListening(EndReason.skipped);
    state = state.copyWith(cursor: index);
    await _loadCurrent(play: true);
  }

  // ---- transport ----

  Future<void> togglePlay() async {
    if (state.current == null) {
      if (state.queue.isNotEmpty) {
        await jumpTo(0);
      }
      return;
    }
    if (_engine.state.path == null) {
      // Stopped at the end of the queue: start the current song again.
      await _loadCurrent(play: true);
    } else if (state.playing) {
      await _engine.pause();
    } else {
      await _engine.play();
    }
  }

  Future<void> pause() => _engine.pause();

  Future<void> stop() async {
    _endListening(EndReason.stopped);
    await _engine.stop();
    state = state.copyWith(playing: false);
  }

  Future<void> seek(Duration position) => _engine.seek(position);

  Future<void> next() => _advance(auto: false);

  Future<void> previous() async {
    if (state.current == null) {
      return;
    }
    if (_engine.state.position > const Duration(seconds: 3)) {
      await _engine.seek(Duration.zero);
      return;
    }
    if (state.cursor > 0) {
      _endListening(EndReason.skipped);
      state = state.copyWith(cursor: state.cursor - 1);
      await _loadCurrent(play: true);
    } else if (state.repeat == PlayerRepeat.all && state.queue.length > 1) {
      _endListening(EndReason.skipped);
      state = state.copyWith(cursor: state.queue.length - 1);
      await _loadCurrent(play: true);
    } else {
      await _engine.seek(Duration.zero);
    }
  }

  Future<void> _onCompleted() => _advance(auto: true);

  Future<void> _advance({required bool auto}) async {
    if (state.current == null) {
      return;
    }
    final reason = auto ? EndReason.completed : EndReason.skipped;
    if (auto && state.repeat == PlayerRepeat.one) {
      _endListening(reason);
      await _loadCurrent(play: true);
      return;
    }
    if (state.cursor + 1 < state.queue.length) {
      _endListening(reason);
      state = state.copyWith(cursor: state.cursor + 1);
      await _loadCurrent(play: true);
    } else if (state.repeat == PlayerRepeat.all && state.queue.isNotEmpty) {
      _endListening(reason);
      state = state.copyWith(cursor: 0);
      await _loadCurrent(play: true);
    } else if (auto) {
      // End of the queue: stop on the last song - but only after the audio
      // still buffered in Windows has played. Stopping at once cut ~0.3 s
      // off the end of the last song (measured by NEXA AutoTest, FT-06).
      _endListening(reason);
      state = state.copyWith(playing: false);
      final entry = state.currentEntry;
      await Future<void>.delayed(endOfQueueDrain);
      if (ref.mounted && state.currentEntry == entry && !state.playing) {
        await _engine.stop();
      }
    }
  }

  /// How long the end of the last song may still sound after the engine
  /// reported its end (Windows audio buffer).
  static const Duration endOfQueueDrain = Duration(milliseconds: 600);

  /// Loads the current entry; missing files are skipped with a notice.
  Future<void> _loadCurrent({required bool play}) async {
    var skipped = 0;
    while (state.current != null) {
      final track = state.current!;
      if (_playable(track)) {
        _beginListening();
        await _engine.load(track.path, play: play);
        await _applyVolume();
        await _prepareNext();
        return;
      }
      _notice('Skipped "${track.title}": file not found');
      skipped++;
      if (skipped >= state.queue.length) {
        await _engine.stop();
        state = state.copyWith(playing: false);
        _notice('No playable file in the queue');
        return;
      }
      if (state.cursor + 1 < state.queue.length) {
        state = state.copyWith(cursor: state.cursor + 1);
      } else if (state.repeat == PlayerRepeat.all) {
        state = state.copyWith(cursor: 0);
      } else {
        await _engine.stop();
        state = state.copyWith(playing: false);
        return;
      }
    }
  }

  void _onError(String message) {
    final title = state.current?.title;
    _notice(
      title == null
          ? 'Playback error: $message'
          : 'Cannot play "$title": $message',
    );
    final entry = state.currentEntry;
    if (entry != null && entry.track.isOnline) {
      unawaited(_skipFailedStream(entry, _engine.state.position));
    }
  }

  /// How long a failed catalog stream may still recover (or the engine
  /// report its end) before NEXA moves on by itself.
  static const Duration failedStreamGrace = Duration(milliseconds: 500);

  /// E1: a catalog song that cannot be streamed (removed, gated meanwhile,
  /// network gone) is skipped, so the Wave keeps going - once per failure,
  /// never in an endless loop over a queue of dead streams.
  Future<void> _skipFailedStream(QueueEntry entry, Duration at) async {
    await Future<void>.delayed(failedStreamGrace);
    if (!ref.mounted || state.currentEntry?.uid != entry.uid) {
      return; // Already moved on (e.g. the engine reported the end).
    }
    final s = _engine.state;
    if (s.path == entry.track.path && s.playing && s.position > at) {
      return; // The stream recovered and plays.
    }
    _failedStreams++;
    final hasNext =
        state.cursor + 1 < state.queue.length ||
        (state.repeat == PlayerRepeat.all && state.queue.length > 1);
    if (!hasNext) {
      return; // Nothing follows: the error notice stays, as before.
    }
    if (_failedStreams >= state.queue.length) {
      _failedStreams = 0;
      _endListening(EndReason.stopped);
      await _engine.stop();
      state = state.copyWith(playing: false);
      _notice(S.noPlayableStream);
      return;
    }
    _notice(S.skippedStream(entry.track.title));
    await _advance(auto: false);
  }

  // ---- modes and volume ----

  Future<void> toggleShuffle() async {
    final on = !state.shuffle;
    final current = state.currentEntry;
    if (on) {
      final rest = state.queue.where((e) => e != current);
      final queue = [?current, ..._shuffled(rest)];
      state = state.copyWith(
        shuffle: true,
        queue: queue,
        cursor: current == null ? -1 : 0,
      );
    } else {
      final queue = _original.isEmpty ? state.queue : _original;
      state = state.copyWith(
        shuffle: false,
        queue: queue,
        cursor: current == null
            ? -1
            : queue.indexWhere((e) => e.uid == current.uid),
      );
    }
    await _settings.setBool(SettingKeys.shuffle, on);
  }

  Future<void> cycleRepeat() async {
    final next = PlayerRepeat.values[(state.repeat.index + 1) % 3];
    state = state.copyWith(repeat: next);
    await _settings.setString(SettingKeys.repeat, next.name);
  }

  Future<void> setVolume(double volume) async {
    state = state.copyWith(volume: volume.clamp(0.0, 1.0), muted: false);
    await _applyVolume();
    await _settings.setDouble(SettingKeys.volume, state.volume);
    await _settings.setBool(SettingKeys.muted, false);
  }

  Future<void> toggleMute() async {
    state = state.copyWith(muted: !state.muted);
    await _applyVolume();
    await _settings.setBool(SettingKeys.muted, state.muted);
  }

  Future<void> setOutputDevice(OutputDevice device) async {
    await _engine.setDevice(device);
    await _settings.setString(SettingKeys.audioDevice, device.id);
  }

  /// Media keys from the Windows runner ("nexa/media_keys").
  Future<void> handleMediaKey(String key) => switch (key) {
    'playPause' => togglePlay(),
    'play' => state.playing ? Future<void>.value() : togglePlay(),
    'pause' => pause(),
    'next' => next(),
    'previous' => previous(),
    'stop' => stop(),
    _ => Future<void>.value(),
  };
}

final playerProvider = NotifierProvider<PlayerController, PlayerState>(
  PlayerController.new,
);

/// Handles a Windows media key before NEXA's own player does; returns true
/// when it took the key. Set only while another visible player owns the
/// keys (E2.0 prototype: the YouTube page).
typedef MediaKeyRedirect = Future<bool> Function(String key);

class MediaKeyRedirectController extends Notifier<MediaKeyRedirect?> {
  @override
  MediaKeyRedirect? build() => null;

  void set(MediaKeyRedirect? redirect) => state = redirect;
}

final mediaKeyRedirectProvider =
    NotifierProvider<MediaKeyRedirectController, MediaKeyRedirect?>(
      MediaKeyRedirectController.new,
    );

/// What the Windows media overlay shows.
typedef MediaOverlay = ({bool playing, String title, String artist});

/// Set while another visible player owns the media keys, so the Windows
/// overlay shows that player's state. Windows turns the Play/Pause key into
/// "Play" or "Pause" from the overlay's state, so the overlay must describe
/// the player the key is meant for.
class MediaOverlayOverrideController extends Notifier<MediaOverlay?> {
  @override
  MediaOverlay? build() => null;

  void set(MediaOverlay? overlay) {
    if (overlay != state) {
      state = overlay;
    }
  }
}

final mediaOverlayOverrideProvider =
    NotifierProvider<MediaOverlayOverrideController, MediaOverlay?>(
      MediaOverlayOverrideController.new,
    );

/// Connects the Windows media keys and the Windows media overlay (System
/// Media Transport Controls, see windows/runner/media_session.cpp) to the
/// player: button presses come in, playing state and song go out (TD-06).
void bindMediaKeys(WidgetRef ref) {
  const channel = MethodChannel('nexa/media_keys');
  channel.setMethodCallHandler((call) async {
    final redirect = ref.read(mediaKeyRedirectProvider);
    if (redirect != null && await redirect(call.method)) {
      return;
    }
    await ref.read(playerProvider.notifier).handleMediaKey(call.method);
  });
  if (!Platform.isWindows || Platform.environment['FLUTTER_TEST'] == 'true') {
    return; // The media controls live in the Windows runner only.
  }
  Future<void> push() async {
    final p = ref.read(playerProvider);
    final o =
        ref.read(mediaOverlayOverrideProvider) ??
        (
          playing: p.playing,
          title: p.current?.title ?? '',
          artist: p.current?.artist ?? '',
        );
    try {
      await channel.invokeMethod<bool>('update', {
        'playing': o.playing,
        'title': o.title,
        'artist': o.artist,
      });
    } on Object {
      // The overlay is a convenience; playback never depends on it.
    }
  }

  ref
    ..listenManual(
      playerProvider.select(
        (p) => (p.playing, p.current?.title ?? '', p.current?.artist ?? ''),
      ),
      (_, _) => push(),
      fireImmediately: true,
    )
    ..listenManual(mediaOverlayOverrideProvider, (_, _) => push());
}
