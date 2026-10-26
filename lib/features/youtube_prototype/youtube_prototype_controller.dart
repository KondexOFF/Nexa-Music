import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../app/strings.dart';
import '../../core/app_paths.dart';
import '../player/player_controller.dart';
import 'youtube_embed.dart';

/// IFrame API player states (`onStateChange`).
abstract final class YtState {
  static const int unstarted = -1;
  static const int ended = 0;
  static const int playing = 1;
  static const int paused = 2;
  static const int buffering = 3;
  static const int cued = 5;
}

/// What the prototype page shows (E2.0).
@immutable
class YtStatus {
  const YtStatus({
    this.open = false,
    this.unavailable,
    this.runtimeVersion,
    this.pageOrigin,
    this.apiLoaded = false,
    this.apiLoadFailed = false,
    this.videoId,
    this.state = YtState.unstarted,
    this.errorCode,
    this.autoplayBlocked = false,
    this.quality,
    this.time = 0,
    this.duration = 0,
    this.muted = false,
    this.fullScreen = false,
  });

  final bool open;

  /// Why the embedded player cannot run here (no WebView2, ...).
  final String? unavailable;
  final String? runtimeVersion;

  /// Origin of the player page as the page itself reports it.
  final String? pageOrigin;
  final bool apiLoaded;

  /// The IFrame API script could not be loaded (offline).
  final bool apiLoadFailed;
  final String? videoId;
  final int state;
  final int? errorCode;
  final bool autoplayBlocked;
  final String? quality;
  final double time;
  final double duration;
  final bool muted;
  final bool fullScreen;

  /// The video makes (or is about to make) sound.
  bool get active => state == YtState.playing || state == YtState.buffering;

  YtStatus copyWith({
    bool? open,
    String? unavailable,
    String? runtimeVersion,
    String? pageOrigin,
    bool? apiLoaded,
    bool? apiLoadFailed,
    String? videoId,
    int? state,
    int? errorCode,
    bool clearError = false,
    bool? autoplayBlocked,
    String? quality,
    double? time,
    double? duration,
    bool? muted,
    bool? fullScreen,
  }) => YtStatus(
    open: open ?? this.open,
    unavailable: unavailable ?? this.unavailable,
    runtimeVersion: runtimeVersion ?? this.runtimeVersion,
    pageOrigin: pageOrigin ?? this.pageOrigin,
    apiLoaded: apiLoaded ?? this.apiLoaded,
    apiLoadFailed: apiLoadFailed ?? this.apiLoadFailed,
    videoId: videoId ?? this.videoId,
    state: state ?? this.state,
    errorCode: clearError ? null : (errorCode ?? this.errorCode),
    autoplayBlocked: autoplayBlocked ?? this.autoplayBlocked,
    quality: quality ?? this.quality,
    time: time ?? this.time,
    duration: duration ?? this.duration,
    muted: muted ?? this.muted,
    fullScreen: fullScreen ?? this.fullScreen,
  );
}

/// Plain text for an IFrame API error code.
String youtubeErrorText(int code) => switch (code) {
  2 => S.ytError2,
  5 => S.ytError5,
  100 => S.ytError100,
  101 || 150 => S.ytErrorNotEmbeddable,
  153 => S.ytError153,
  _ => S.ytErrorOther(code),
};

/// Creates the embedded player (tests replace it with a fake).
final youtubeEmbedFactoryProvider = Provider<Future<YouTubeEmbed> Function()>(
  (ref) => () async => WindowsYouTubeEmbed(
    profileDir: p.join((await appDataDirectory()).path, 'webview2'),
  ),
);

/// E2.0 prototype controller: one YouTube player, never at the same time as
/// NEXA's own playback, paused whenever it is not visible.
///
/// * YouTube starts playing -> NEXA's player pauses; NEXA starts -> YouTube
///   pauses (documented IFrame API `pauseVideo`).
/// * The window is minimised / hidden, or the page is closed -> YouTube
///   pauses (no background playback, Developer Policies III.I.9).
/// * While YouTube is the source the user played last, the Windows media
///   keys that reach NEXA control YouTube instead of NEXA's queue.
class YouTubePrototypeController extends Notifier<YtStatus> {
  YouTubeEmbed? _embed;
  final List<StreamSubscription<Object?>> _subs = [];
  AppLifecycleListener? _lifecycle;
  final _log = StreamController<Map<String, Object?>>.broadcast();

  /// YouTube (not NEXA's player) is what the user played last.
  bool _youtubeLast = false;

  /// Everything that happened, for the prototype's self-test log.
  Stream<Map<String, Object?>> get log => _log.stream;

  YouTubeEmbed? get embed => _embed;

  @override
  YtStatus build() {
    ref.listen(playerProvider.select((s) => s.playing), (_, playing) {
      _emit('nexa', {'playing': playing});
      if (playing) {
        _youtubeLast = false;
        _syncOverlay();
        if (state.active) {
          unawaited(_command({'cmd': 'pause'}, reason: 'nexa-started'));
        }
      }
    });
    ref.onDispose(() {
      unawaited(close());
      unawaited(_log.close());
    });
    return const YtStatus();
  }

  /// While YouTube is what the user played last, the Windows media overlay
  /// shows YouTube's state: Windows turns the Play/Pause key into "Play" or
  /// "Pause" from the overlay, so a NEXA overlay saying "paused" while
  /// YouTube plays would turn the key into a useless "Play".
  void _syncOverlay() {
    if (!ref.mounted) {
      return;
    }
    ref
        .read(mediaOverlayOverrideProvider.notifier)
        .set(
          _youtubeLast && _embed != null
              ? (
                  playing: state.active,
                  title: S.ytOverlayTitle,
                  artist: S.ytOverlayArtist,
                )
              : null,
        );
  }

  void _emit(String type, [Map<String, Object?> data = const {}]) {
    if (!_log.isClosed) {
      // The kind of entry always wins over a "type" field in [data].
      _log.add({...data, 'type': type});
    }
  }

  /// Opens the player page (call when the prototype page is shown).
  Future<void> open() async {
    if (_embed != null) {
      return;
    }
    state = const YtStatus(open: true);
    final embed = await ref.read(youtubeEmbedFactoryProvider)();
    _embed = embed;
    final version = await embed.runtimeVersion();
    _emit('runtime', {'version': version});
    try {
      await embed.initialize();
    } on YouTubeEmbedUnavailable catch (e) {
      _emit('unavailable', {'reason': e.reason});
      if (ref.mounted) {
        state = state.copyWith(unavailable: e.reason, runtimeVersion: version);
      }
      await embed.dispose();
      _embed = null;
      return;
    } on Object catch (e) {
      _emit('unavailable', {'reason': '$e'});
      if (ref.mounted) {
        state = state.copyWith(
          unavailable: S.ytUnavailable('$e'),
          runtimeVersion: version,
        );
      }
      await embed.dispose();
      _embed = null;
      return;
    }
    if (!ref.mounted) {
      return;
    }
    state = state.copyWith(runtimeVersion: version);
    _subs
      ..add(embed.events.listen(_onEvent))
      ..add(
        embed.fullScreen.listen((on) {
          _emit('fullScreen', {'on': on});
          state = state.copyWith(fullScreen: on);
        }),
      );
    _lifecycle = AppLifecycleListener(onStateChange: _onLifecycle);
    ref.read(mediaKeyRedirectProvider.notifier).set(_onMediaKey);
    await embed.openPage();
  }

  /// Reloads the same page without the application identity (prototype
  /// negative control for error 153).
  Future<void> openUnidentified() async {
    state = state.copyWith(
      apiLoaded: false,
      clearError: true,
      state: YtState.unstarted,
    );
    await _embed?.openPage(identified: false);
  }

  /// Reloads the page from the virtual host (after [openUnidentified]).
  Future<void> openIdentified() async {
    state = state.copyWith(
      apiLoaded: false,
      clearError: true,
      state: YtState.unstarted,
    );
    await _embed?.openPage();
  }

  /// Closes the player (page left): pause first, then release WebView2.
  Future<void> close() async {
    final embed = _embed;
    if (embed == null) {
      return;
    }
    // After the provider is disposed its state is gone: pause anyway.
    if (!ref.mounted || state.active) {
      await _command({'cmd': 'pause'}, reason: 'page-closed');
    }
    _lifecycle?.dispose();
    _lifecycle = null;
    if (ref.mounted) {
      ref.read(mediaKeyRedirectProvider.notifier).set(null);
    }
    // Not awaited: a cancelled subscription has nothing left to deliver.
    for (final s in _subs) {
      unawaited(s.cancel());
    }
    _subs.clear();
    _embed = null;
    _youtubeLast = false;
    _syncOverlay();
    await embed.dispose();
    _emit('closed');
    if (ref.mounted) {
      state = const YtStatus();
    }
  }

  /// Loads [videoId]. [play]: start at once (a deliberate user action);
  /// otherwise only cue it. [mute] is used by the automated prototype run.
  Future<void> load(String videoId, {bool play = true, bool mute = false}) async {
    state = state.copyWith(
      videoId: videoId,
      clearError: true,
      autoplayBlocked: false,
    );
    if (play) {
      await _pauseNexa('youtube-load');
      _youtubeLast = true;
      _syncOverlay();
    }
    await _command({
      'cmd': 'load',
      'videoId': videoId,
      'play': play,
      'mute': mute,
      'unmute': !mute,
    }, reason: 'load');
  }

  Future<void> play() async {
    await _pauseNexa('youtube-play');
    _youtubeLast = true;
    _syncOverlay();
    await _command({'cmd': 'play'}, reason: 'play');
  }

  Future<void> pause() => _command({'cmd': 'pause'}, reason: 'pause');

  Future<void> requestInfo() => _command({'cmd': 'info'}, reason: 'info');

  Future<void> _pauseNexa(String reason) async {
    if (ref.read(playerProvider).playing) {
      _emit('pauseNexa', {'reason': reason});
      await ref.read(playerProvider.notifier).pause();
    }
  }

  Future<void> _command(
    Map<String, Object?> command, {
    required String reason,
  }) async {
    final embed = _embed;
    if (embed == null) {
      return;
    }
    _emit('command', {...command, 'reason': reason});
    try {
      await embed.send(command);
    } on Object catch (e) {
      _emit('commandFailed', {'error': '$e'});
    }
  }

  void _onEvent(Map<String, Object?> e) {
    _emit('yt.${e['type']}', e);
    if (!ref.mounted) {
      return;
    }
    double toDouble(Object? v) => v is num ? v.toDouble() : 0;
    switch (e['type']) {
      case 'page':
        state = state.copyWith(pageOrigin: '${e['origin']}');
      case 'api':
        state = state.copyWith(apiLoaded: true);
      case 'apiLoadError':
        state = state.copyWith(apiLoadFailed: true);
      case 'error':
        final code = e['code'];
        state = state.copyWith(errorCode: code is num ? code.toInt() : -1);
      case 'autoplayBlocked':
        state = state.copyWith(autoplayBlocked: true);
      case 'quality':
        state = state.copyWith(quality: '${e['quality']}');
      case 'ready' || 'state' || 'tick' || 'info':
        final s = e['state'];
        final newState = s is num ? s.toInt() : state.state;
        state = state.copyWith(
          state: newState,
          time: toDouble(e['time']),
          duration: toDouble(e['duration']),
          muted: e['muted'] == true,
          quality: e['quality'] is String ? e['quality'] as String : null,
        );
        if (e['type'] == 'state' && newState == YtState.playing) {
          _youtubeLast = true;
          if (ref.read(playerProvider).playing) {
            _emit('pauseNexa', {'reason': 'youtube-playing'});
            unawaited(ref.read(playerProvider.notifier).pause());
          }
        }
        _syncOverlay();
    }
  }

  void _onLifecycle(AppLifecycleState s) {
    _emit('lifecycle', {'state': s.name});
    if ((s == AppLifecycleState.hidden ||
            s == AppLifecycleState.paused ||
            s == AppLifecycleState.detached) &&
        state.active) {
      unawaited(_command({'cmd': 'pause'}, reason: 'window-${s.name}'));
    }
  }

  /// Media keys reaching NEXA while the YouTube page is open.
  Future<bool> _onMediaKey(String key) async {
    _emit('mediaKey', {'key': key, 'youtubeLast': _youtubeLast});
    if (!_youtubeLast) {
      return false; // NEXA's own player handles it.
    }
    switch (key) {
      case 'playPause':
        await (state.active ? pause() : play());
      case 'play':
        await play();
      case 'pause' || 'stop':
        await pause();
      default:
        break; // No queue for YouTube in the prototype.
    }
    return true;
  }
}

final youtubePrototypeProvider =
    NotifierProvider<YouTubePrototypeController, YtStatus>(
      YouTubePrototypeController.new,
    );
