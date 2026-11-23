import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../app/strings.dart';
import '../../core/app_paths.dart';
import '../../integrations/youtube/youtube_embed.dart';
import '../../integrations/youtube/youtube_link.dart';
import '../discover/catalog_providers.dart';
import '../player/playback_arbiter.dart';
import '../player/player_controller.dart';
import '../../core/models/listening.dart';
import '../../core/models/track.dart';
import '../library/library_repository.dart' show youtubeUnnamed;
import '../privacy/ad_block.dart';
import 'youtube_history.dart';

/// IFrame API player states (`onStateChange`).
abstract final class YtState {
  static const int unstarted = -1;
  static const int ended = 0;
  static const int playing = 1;
  static const int paused = 2;
  static const int buffering = 3;
  static const int cued = 5;
}

/// What the YouTube page shows.
@immutable
class YtStatus {
  const YtStatus({
    this.open = false,
    this.unavailable,
    this.pageOrigin,
    this.apiLoaded = false,
    this.apiLoadFailed = false,
    this.videoId,
    this.title,
    this.channel,
    this.state = YtState.unstarted,
    this.errorCode,
    this.autoplayBlocked = false,
    this.fullScreen = false,
  });

  final bool open;

  /// Why the embedded player cannot run here (no WebView2, ...).
  final String? unavailable;

  /// Origin of the player page as the page itself reports it.
  final String? pageOrigin;
  final bool apiLoaded;

  /// The IFrame API script could not be loaded (offline).
  final bool apiLoadFailed;
  final String? videoId;
  final String? title;
  final String? channel;
  final int state;
  final int? errorCode;
  final bool autoplayBlocked;
  final bool fullScreen;

  /// The video makes (or is about to make) sound.
  bool get active => state == YtState.playing || state == YtState.buffering;

  YtStatus copyWith({
    bool? open,
    String? unavailable,
    String? pageOrigin,
    bool? apiLoaded,
    bool? apiLoadFailed,
    String? videoId,
    String? title,
    String? channel,
    bool clearTitle = false,
    int? state,
    int? errorCode,
    bool clearError = false,
    bool? autoplayBlocked,
    bool? fullScreen,
  }) => YtStatus(
    open: open ?? this.open,
    unavailable: unavailable ?? this.unavailable,
    pageOrigin: pageOrigin ?? this.pageOrigin,
    apiLoaded: apiLoaded ?? this.apiLoaded,
    apiLoadFailed: apiLoadFailed ?? this.apiLoadFailed,
    videoId: videoId ?? this.videoId,
    title: clearTitle ? title : (title ?? this.title),
    channel: clearTitle ? channel : (channel ?? this.channel),
    state: state ?? this.state,
    errorCode: clearError ? null : (errorCode ?? this.errorCode),
    autoplayBlocked: autoplayBlocked ?? this.autoplayBlocked,
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
    extension: adBlockRequest(ref.read(adBlockProvider)),
    onExtension: (reply) =>
        unawaited(ref.read(adBlockProvider.notifier).report(reply)),
  ),
);

/// Title and channel of a pasted link through YouTube's public oEmbed
/// endpoint (no key, no quota); null when unknown. Shown on the page and in
/// the Windows media overlay only - never stored.
final youtubeTitleLookupProvider =
    Provider<Future<(String, String)?> Function(String videoId)>((ref) {
      final client = ref.watch(httpClientProvider);
      return (videoId) async {
        try {
          final uri = Uri.https('www.youtube.com', '/oembed', {
            'url': youtubeWatchUrl(videoId),
            'format': 'json',
          });
          final r = await client.get(uri).timeout(const Duration(seconds: 8));
          if (r.statusCode != 200) {
            return null;
          }
          final body = jsonDecode(utf8.decode(r.bodyBytes));
          if (body is Map && body['title'] is String) {
            return (
              body['title'] as String,
              body['author_name'] is String ? body['author_name'] as String : '',
            );
          }
        } on Object {
          // Only a nicer title; the player works without it.
        }
        return null;
      };
    });

/// The YouTube player of NEXA (E2.1): one official player on the YouTube
/// page, never together with NEXA's own playback ([PlaybackArbiter]),
/// paused whenever it is not visible (minimised window, page left; YouTube
/// API Services Developer Policies III.I.9). What is watched never reaches
/// NEXA Wave / DNA; a local history only when the user switched it on and
/// the video is not made for kids ([YouTubeHistoryRecorder], E2.7b).
class YouTubePlayerController extends Notifier<YtStatus>
    implements ExternalPlayer, QueueExternalPlayer {
  YouTubeEmbed? _embed;
  final List<StreamSubscription<Object?>> _subs = [];
  AppLifecycleListener? _lifecycle;
  late PlaybackArbiter _arbiter;

  // The video being watched, for the optional local history (E2.7b).
  String? _sessionVideo;
  String? _sessionTitle;
  String? _sessionChannel;
  DateTime? _sessionStart;
  Duration _sessionTime = Duration.zero;
  Duration? _sessionDuration;

  YouTubeEmbed? get embed => _embed;

  @override
  YtStatus build() {
    _arbiter = ref.read(playbackArbiterProvider.notifier);
    ref.onDispose(() => unawaited(close()));
    return const YtStatus();
  }

  @override
  bool get active => state.active;

  @override
  MediaOverlay get overlay => (
    playing: state.active,
    title: (state.title ?? '').isEmpty ? S.ytOverlayTitle : state.title!,
    artist: (state.channel ?? '').isEmpty ? S.ytOverlayArtist : state.channel!,
  );

  /// Opens the player page (call when the YouTube page is shown).
  Future<void> open() async {
    if (_embed != null) {
      return;
    }
    state = const YtStatus(open: true);
    final embed = await ref.read(youtubeEmbedFactoryProvider)();
    _embed = embed;
    try {
      await embed.initialize();
    } on Object catch (e) {
      if (ref.mounted) {
        state = state.copyWith(
          unavailable: e is YouTubeEmbedUnavailable ? e.reason : '$e',
        );
      }
      _embed = null;
      await embed.dispose();
      return;
    }
    if (!ref.mounted || !identical(_embed, embed)) {
      return;
    }
    _subs
      ..add(embed.events.listen(_onEvent))
      ..add(
        embed.fullScreen.listen((on) {
          if (ref.mounted) {
            state = state.copyWith(fullScreen: on);
          }
        }),
      );
    _lifecycle = AppLifecycleListener(onStateChange: _onLifecycle);
    _arbiter.attach(this);
    await embed.openPage();
  }

  /// Closes the player (page left): pause first, then release WebView2.
  Future<void> close() async {
    final embed = _embed;
    if (embed == null) {
      if (ref.mounted && state.open) {
        state = const YtStatus(); // e.g. after "WebView2 unavailable"
      }
      return;
    }
    _endSession(EndReason.stopped);
    // After the provider is disposed its state is gone: pause anyway.
    if (!ref.mounted || state.active) {
      await _command({'cmd': 'pause'});
    }
    _lifecycle?.dispose();
    _lifecycle = null;
    if (ref.mounted) {
      _arbiter.detach(this);
    }
    // Not awaited: a cancelled subscription has nothing left to deliver.
    for (final s in _subs) {
      unawaited(s.cancel());
    }
    _subs.clear();
    _embed = null;
    await embed.dispose();
    if (ref.mounted) {
      state = const YtStatus();
      _queue.externalClosed(TrackSource.youtube);
    }
  }

  /// Watch [videoId] (Watch / Watch in NEXA): opens the one player of the
  /// app if needed and loads the video. The player stays open while the
  /// user moves between sections (E2.6 mini-player) until it is closed.
  Future<void> watch(
    String videoId, {
    String? title,
    String? channel,
    Duration? start,
  }) async {
    if (_embed == null) {
      await open();
    }
    if (state.unavailable != null) {
      // Keep the id for "Open on YouTube".
      state = state.copyWith(videoId: videoId, title: title, channel: channel);
      return;
    }
    await load(videoId, title: title, channel: channel, start: start);
  }

  /// Loads [videoId]. [play]: start at once (the user pressed Watch);
  /// otherwise only cue it. [mute]: start without sound (automated tests).
  Future<void> load(
    String videoId, {
    String? title,
    String? channel,
    bool play = true,
    bool mute = false,
    Duration? start,
  }) async {
    if (videoId != _sessionVideo) {
      _endSession(EndReason.skipped);
    }
    final known = state.videoId == videoId && title == null;
    state = state.copyWith(
      videoId: videoId,
      title: known ? state.title : title,
      channel: known ? state.channel : channel,
      clearTitle: !known,
      clearError: true,
      autoplayBlocked: false,
    );
    if (play) {
      await _arbiter.externalStarting(this);
    }
    await _command({
      'cmd': 'load',
      'videoId': videoId,
      'play': play,
      'mute': mute,
      'unmute': !mute,
      if (start != null && start > Duration.zero) 'start': start.inSeconds,
    });
    if (state.title == null) {
      unawaited(_lookUpTitle(videoId));
    }
  }

  Future<void> _lookUpTitle(String videoId) async {
    final found = await ref.read(youtubeTitleLookupProvider)(videoId);
    if (found != null && ref.mounted && state.videoId == videoId) {
      state = state.copyWith(title: found.$1, channel: found.$2);
      _arbiter.sync();
    }
  }

  /// E2.8: a YouTube entry of NEXA's queue, shown in the one visible
  /// player (the compact player when the YouTube page is not open).
  @override
  Future<String?> start(Track track) async {
    final title = track.title == youtubeUnnamed ? null : track.title;
    await watch(
      track.sourceTrackId,
      title: title,
      channel: track.artist.isEmpty ? null : track.artist,
    );
    final why = state.unavailable;
    return why == null ? null : S.ytUnavailable(why);
  }

  @override
  Future<void> resume() => play();

  @override
  Future<void> play() async {
    if (state.videoId == null) {
      return;
    }
    await _arbiter.externalStarting(this);
    await _command({'cmd': 'play'});
  }

  @override
  Future<void> pause() => _command({'cmd': 'pause'});

  Future<void> _command(Map<String, Object?> command) async {
    final embed = _embed;
    if (embed == null) {
      return;
    }
    try {
      await embed.send(command);
    } on Object {
      // The page is gone (closing); nothing plays without it.
    }
  }

  void _onEvent(Map<String, Object?> e) {
    if (!ref.mounted) {
      return;
    }
    switch (e['type']) {
      case 'page':
        state = state.copyWith(pageOrigin: '${e['origin']}');
      case 'api':
        final reload = state.apiLoaded;
        state = state.copyWith(apiLoaded: true);
        // The page came back after a link was opened in the browser: show
        // the same video again, paused.
        final id = state.videoId;
        if (reload && id != null) {
          unawaited(
            _command({'cmd': 'load', 'videoId': id, 'play': false}),
          );
        }
      case 'apiLoadError':
        state = state.copyWith(apiLoadFailed: true);
        unawaited(_queue.externalFailed(TrackSource.youtube, state.videoId, S.ytApiLoadFailed));
      case 'error':
        final code = e['code'];
        state = state.copyWith(errorCode: code is num ? code.toInt() : -1);
        unawaited(
          _queue.externalFailed(TrackSource.youtube, state.videoId, youtubeErrorText(state.errorCode!)),
        );
      case 'autoplayBlocked':
        state = state.copyWith(autoplayBlocked: true);
        _queue.externalStatus(TrackSource.youtube, state.videoId, active: false, blocked: true);
      case 'external':
        final url = '${e['url']}';
        if (isExternalPage(url)) {
          // The player's own links (title, logo, "Watch on YouTube") open
          // in the system browser; YouTube there is not NEXA's business.
          unawaited(ref.read(linkOpenerProvider)(url));
        }
      case 'ready' || 'state' || 'tick' || 'info':
        final s = e['state'];
        final newState = s is num ? s.toInt() : state.state;
        _followSession(e, newState);
        state = state.copyWith(
          state: newState,
          autoplayBlocked: newState == YtState.playing
              ? false
              : state.autoplayBlocked,
        );
        if (e['type'] == 'state' && newState == YtState.playing) {
          unawaited(_arbiter.externalStarting(this));
        } else {
          _arbiter.sync();
        }
        _queue.externalStatus(
          TrackSource.youtube,
          state.videoId,
          active: state.active,
          blocked: state.autoplayBlocked,
        );
        if (e['type'] == 'state' && newState == YtState.ended) {
          unawaited(_queue.externalEnded(TrackSource.youtube, state.videoId));
        }
    }
  }

  /// Follows the watched video for the optional history: a session starts
  /// when a video plays and ends when it finishes, another video is loaded
  /// or the player closes.
  void _followSession(Map<String, Object?> e, int newState) {
    final time = e['time'];
    final duration = e['duration'];
    if (newState == YtState.playing && _sessionVideo != state.videoId) {
      _endSession(EndReason.skipped);
      _sessionVideo = state.videoId;
      _sessionStart = DateTime.now();
      _sessionTime = Duration.zero;
      _sessionDuration = null;
    }
    if (_sessionVideo == null) {
      return;
    }
    if (time is num && time >= 0) {
      _sessionTime = Duration(milliseconds: (time * 1000).round());
    }
    if (duration is num && duration > 0) {
      _sessionDuration = Duration(milliseconds: (duration * 1000).round());
    }
    if ((state.title ?? '').isNotEmpty) {
      _sessionTitle = state.title;
      _sessionChannel = state.channel;
    }
    if (newState == YtState.ended) {
      _endSession(EndReason.completed);
    }
  }

  void _endSession(EndReason reason) {
    final videoId = _sessionVideo;
    final start = _sessionStart;
    _sessionVideo = null;
    _sessionStart = null;
    if (videoId == null || start == null) {
      return;
    }
    final duration = _sessionDuration;
    final listened = reason == EndReason.completed && duration != null
        ? duration
        : _sessionTime;
    final title = _sessionTitle;
    final channel = _sessionChannel;
    _sessionTitle = null;
    _sessionChannel = null;
    if (!ref.mounted || listened < YouTubeHistoryRecorder.minListen) {
      return; // NEXA is closing, or the video was only started.
    }
    unawaited(
      ref
          .read(youtubeHistoryProvider)
          .record(
            videoId: videoId,
            startedAt: start,
            listened: listened,
            duration: duration,
            reason: reason,
            title: title,
            channel: channel,
          ),
    );
  }

  PlayerController get _queue => ref.read(playerProvider.notifier);

  void _onLifecycle(AppLifecycleState s) {
    if ((s == AppLifecycleState.hidden ||
            s == AppLifecycleState.paused ||
            s == AppLifecycleState.detached) &&
        state.active) {
      unawaited(pause());
    }
  }
}

final youtubePlayerProvider =
    NotifierProvider<YouTubePlayerController, YtStatus>(
      YouTubePlayerController.new,
    );
