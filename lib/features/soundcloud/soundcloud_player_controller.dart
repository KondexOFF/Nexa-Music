import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../app/strings.dart';
import '../../core/app_paths.dart';
import '../../core/models/listening.dart';
import '../../core/models/track.dart';
import '../../integrations/soundcloud/soundcloud_link.dart';
import '../../integrations/youtube/youtube_embed.dart';
import '../discover/catalog_providers.dart';
import '../library/library_providers.dart';
import '../nexa_dna/dna_providers.dart';
import '../player/playback_arbiter.dart';
import '../player/player_controller.dart';
import '../privacy/ad_block.dart';

/// State of SoundCloud's widget in NEXA (E3).
class ScStatus {
  const ScStatus({
    this.open = false,
    this.url,
    this.title,
    this.user,
    this.artwork,
    this.playing = false,
    this.position = Duration.zero,
    this.duration,
    this.autoplayBlocked = false,
    this.error,
    this.unavailable,
  });

  /// The widget is on screen (its dock).
  final bool open;

  /// Canonical link of the track in the widget.
  final String? url;
  final String? title;
  final String? user;
  final String? artwork;
  final bool playing;
  final Duration position;
  final Duration? duration;

  /// The widget did not start by itself: "Continue".
  final bool autoplayBlocked;

  /// The track cannot be played (removed, private, region, offline).
  final String? error;

  /// WebView2 cannot show the widget.
  final String? unavailable;

  ScStatus copyWith({
    bool? open,
    String? url,
    String? title,
    String? user,
    String? artwork,
    bool? playing,
    Duration? position,
    Duration? duration,
    bool? autoplayBlocked,
    String? error,
    bool clearError = false,
    String? unavailable,
  }) => ScStatus(
    open: open ?? this.open,
    url: url ?? this.url,
    title: title ?? this.title,
    user: user ?? this.user,
    artwork: artwork ?? this.artwork,
    playing: playing ?? this.playing,
    position: position ?? this.position,
    duration: duration ?? this.duration,
    autoplayBlocked: autoplayBlocked ?? this.autoplayBlocked,
    error: clearError ? null : error ?? this.error,
    unavailable: unavailable ?? this.unavailable,
  );
}

/// Creates the widget's web view (tests replace it with a fake).
final soundcloudEmbedFactoryProvider =
    Provider<Future<YouTubeEmbed> Function()>(
      (ref) => () async => WindowsYouTubeEmbed(
        profileDir: p.join((await appDataDirectory()).path, 'webview2'),
        page: 'soundcloud.html',
        extension: adBlockRequest(ref.read(adBlockProvider)),
        onExtension: (reply) =>
            unawaited(ref.read(adBlockProvider.notifier).report(reply)),
      ),
    );

final soundcloudOEmbedProvider = Provider<SoundCloudOEmbed>(
  (ref) => SoundCloudOEmbed(ref.watch(httpClientProvider)),
);

/// A SoundCloud link (track, playlist or profile) as a [Track] entry: the
/// link, its title and uploader - never audio (CR-002). A playlist or a
/// profile is one entry that the widget plays through (D-026).
Track soundcloudTrack({
  required String url,
  String? title,
  String? user,
  String? artwork,
  Duration? duration,
  String? album,
}) {
  final name = (title ?? '').trim();
  return Track(
    id: Track.onlineId(TrackSource.soundcloud, url),
    source: TrackSource.soundcloud,
    sourceTrackId: url,
    path: url,
    title: name.isEmpty ? S.scUnnamed : name,
    artist: user ?? '',
    album: album ?? TrackSource.soundcloud.label,
    duration: duration,
    artworkPath: artwork,
    addedAt: DateTime.now(),
    pageUrl: url,
  );
}

/// SoundCloud's official widget in NEXA (E3, CR-002): one widget, never
/// together with NEXA's own playback or YouTube ([PlaybackArbiter]); its
/// sound never goes through NEXA's engine or Mix Engine. A track of NEXA's
/// queue plays here in its turn ([QueueExternalPlayer]).
class SoundCloudPlayerController extends Notifier<ScStatus>
    implements ExternalPlayer, QueueExternalPlayer {
  YouTubeEmbed? _embed;
  final List<StreamSubscription<Object?>> _subs = [];
  late PlaybackArbiter _arbiter;
  Duration? _seekOnPlay;

  // For the local history (when history is on).
  String? _sessionUrl;
  DateTime? _sessionStart;

  YouTubeEmbed? get embed => _embed;

  PlayerController get _queue => ref.read(playerProvider.notifier);

  @override
  ScStatus build() {
    _arbiter = ref.read(playbackArbiterProvider.notifier);
    ref.onDispose(() => unawaited(close()));
    return const ScStatus();
  }

  @override
  bool get active => state.playing;

  @override
  MediaOverlay get overlay => (
    playing: state.playing,
    title: (state.title ?? '').isEmpty ? S.scUnnamed : state.title!,
    artist: (state.user ?? '').isEmpty ? 'SoundCloud' : state.user!,
  );

  Future<void> _open() async {
    if (_embed != null) {
      return;
    }
    state = const ScStatus(open: true);
    final embed = await ref.read(soundcloudEmbedFactoryProvider)();
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
    _subs.add(embed.events.listen(_onEvent));
    _arbiter.attach(this);
    await embed.openPage();
  }

  /// Plays [url] (a canonical track link) in the widget, from [start].
  Future<void> playLink(
    String url, {
    String? title,
    String? user,
    String? artwork,
    Duration? start,
  }) async {
    await _open();
    if (state.unavailable != null) {
      state = state.copyWith(url: url, title: title, user: user);
      return;
    }
    if (url != _sessionUrl) {
      _endSession(EndReason.skipped);
    }
    state = ScStatus(
      open: true,
      url: url,
      title: title,
      user: user,
      artwork: artwork,
    );
    _seekOnPlay = start != null && start > Duration.zero ? start : null;
    await _arbiter.externalStarting(this);
    await _embed?.send({'cmd': 'load', 'url': url, 'play': true});
  }

  @override
  Future<String?> start(Track track) async {
    await playLink(
      track.sourceTrackId,
      title: track.title == S.scUnnamed ? null : track.title,
      user: track.artist.isEmpty ? null : track.artist,
      artwork: track.artworkPath,
    );
    final why = state.unavailable;
    return why == null ? null : S.scUnavailable(why);
  }

  @override
  Future<void> play() async {
    if (_embed == null || state.url == null) {
      return;
    }
    state = state.copyWith(autoplayBlocked: false);
    await _arbiter.externalStarting(this);
    await _embed!.send({'cmd': 'play'});
  }

  @override
  Future<void> resume() => play();

  @override
  Future<void> pause() async {
    await _embed?.send({'cmd': 'pause'});
  }

  /// Closes the widget: pause, then release WebView2.
  Future<void> close() async {
    final embed = _embed;
    if (embed == null) {
      if (ref.mounted && state.open) {
        state = const ScStatus();
      }
      return;
    }
    _endSession(EndReason.stopped);
    try {
      await embed.send({'cmd': 'pause'});
    } on Object {
      // Closing anyway.
    }
    if (ref.mounted) {
      _arbiter.detach(this);
    }
    for (final s in _subs) {
      unawaited(s.cancel());
    }
    _subs.clear();
    _embed = null;
    await embed.dispose();
    if (ref.mounted) {
      state = const ScStatus();
      _queue.externalClosed(TrackSource.soundcloud);
    }
  }

  void _onEvent(Map<String, Object?> e) {
    if (!ref.mounted) {
      return;
    }
    final url = state.url;
    switch (e['type']) {
      case 'sound':
        final title = e['title'];
        final user = e['user'];
        final art = e['artwork'];
        final ms = e['duration'];
        state = state.copyWith(
          title: title is String && title.isNotEmpty ? title : null,
          user: user is String && user.isNotEmpty ? user : null,
          artwork: art is String && art.startsWith('https://') ? art : null,
          duration: ms is num && ms > 0
              ? Duration(milliseconds: ms.toInt())
              : null,
        );
        _arbiter.sync();
      case 'state':
        final playing = e['playing'] == true;
        final pos = e['position'];
        state = state.copyWith(
          playing: playing,
          autoplayBlocked: playing ? false : null,
          clearError: playing,
          position: pos is num ? Duration(milliseconds: pos.toInt()) : null,
        );
        if (playing) {
          if (_sessionUrl != url) {
            _endSession(EndReason.skipped);
            _sessionUrl = url;
            _sessionStart = DateTime.now();
          }
          unawaited(_arbiter.externalStarting(this));
          final seek = _seekOnPlay;
          if (seek != null) {
            _seekOnPlay = null;
            unawaited(_embed?.send({'cmd': 'seek', 'ms': seek.inMilliseconds}));
          }
        } else {
          _arbiter.sync();
        }
        _queue.externalStatus(TrackSource.soundcloud, url, active: playing);
      case 'progress':
        final pos = e['position'];
        if (pos is num) {
          state = state.copyWith(position: Duration(milliseconds: pos.toInt()));
        }
      case 'finish':
        state = state.copyWith(playing: false, position: state.duration);
        _arbiter.sync();
        _endSession(EndReason.completed);
        unawaited(_queue.externalEnded(TrackSource.soundcloud, url));
      case 'autoplayBlocked':
        if (!state.playing) {
          state = state.copyWith(autoplayBlocked: true);
          _queue.externalStatus(
            TrackSource.soundcloud,
            url,
            active: false,
            blocked: true,
          );
        }
      case 'error':
        state = state.copyWith(playing: false, error: S.scTrackError);
        _arbiter.sync();
        unawaited(
          _queue.externalFailed(TrackSource.soundcloud, url, S.scTrackError),
        );
      case 'apiLoadError':
        state = state.copyWith(error: S.scApiLoadFailed);
        unawaited(
          _queue.externalFailed(TrackSource.soundcloud, url, S.scApiLoadFailed),
        );
      case 'external':
        // A link in the widget: shown in the system browser
        // (see YouTube's page for the same rule).
        final link = '${e['url']}';
        if (isExternalPage(link)) {
          unawaited(ref.read(linkOpenerProvider)(link));
        }
    }
  }

  /// The local history (only when history is on; CR-002 allows listening
  /// history in NEXA): the track is saved as an entry with its link.
  void _endSession(EndReason reason) {
    final url = _sessionUrl;
    final start = _sessionStart;
    _sessionUrl = null;
    _sessionStart = null;
    if (url == null || start == null || !ref.mounted) {
      return;
    }
    final listened = reason == EndReason.completed && state.duration != null
        ? state.duration!
        : state.position;
    if (listened < const Duration(seconds: 10) ||
        !ref.read(dnaSettingsProvider).recordsHistory) {
      return;
    }
    final track = soundcloudTrack(
      url: url,
      title: state.title,
      user: state.user,
      artwork: state.artwork,
    );
    final duration = state.duration;
    unawaited(() async {
      try {
        final id = await ref.read(libraryRepositoryProvider).save(track);
        await ref
            .read(tasteRepositoryProvider)
            .recordEvent(
              ListeningEvent(
                trackId: id,
                startedAt: start,
                listened: listened,
                duration: duration,
                reason: reason,
                context: PlayContext.soundcloud,
              ),
            );
      } on Object {
        // History is optional.
      }
    }());
  }
}

final soundcloudPlayerProvider =
    NotifierProvider<SoundCloudPlayerController, ScStatus>(
      SoundCloudPlayerController.new,
    );
