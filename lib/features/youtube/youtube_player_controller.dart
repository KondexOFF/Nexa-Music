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
/// API Services Developer Policies III.I.9). Nothing about what is watched
/// is recorded: no history, no NEXA Wave / DNA, no statistics.
class YouTubePlayerController extends Notifier<YtStatus>
    implements ExternalPlayer {
  YouTubeEmbed? _embed;
  final List<StreamSubscription<Object?>> _subs = [];
  AppLifecycleListener? _lifecycle;
  late PlaybackArbiter _arbiter;

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
    }
  }

  /// Watch [videoId] (Watch / Watch in NEXA): opens the one player of the
  /// app if needed and loads the video. The player stays open while the
  /// user moves between sections (E2.6 mini-player) until it is closed.
  Future<void> watch(String videoId, {String? title, String? channel}) async {
    if (_embed == null) {
      await open();
    }
    if (state.unavailable != null) {
      // Keep the id for "Open on YouTube".
      state = state.copyWith(videoId: videoId, title: title, channel: channel);
      return;
    }
    await load(videoId, title: title, channel: channel);
  }

  /// Loads [videoId]. [play]: start at once (the user pressed Watch);
  /// otherwise only cue it. [mute]: start without sound (automated tests).
  Future<void> load(
    String videoId, {
    String? title,
    String? channel,
    bool play = true,
    bool mute = false,
  }) async {
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
      await _arbiter.externalStarting();
    }
    await _command({
      'cmd': 'load',
      'videoId': videoId,
      'play': play,
      'mute': mute,
      'unmute': !mute,
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

  @override
  Future<void> play() async {
    if (state.videoId == null) {
      return;
    }
    await _arbiter.externalStarting();
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
      case 'error':
        final code = e['code'];
        state = state.copyWith(errorCode: code is num ? code.toInt() : -1);
      case 'autoplayBlocked':
        state = state.copyWith(autoplayBlocked: true);
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
        state = state.copyWith(
          state: newState,
          autoplayBlocked: newState == YtState.playing
              ? false
              : state.autoplayBlocked,
        );
        if (e['type'] == 'state' && newState == YtState.playing) {
          unawaited(_arbiter.externalStarting());
        } else {
          _arbiter.sync();
        }
    }
  }

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
