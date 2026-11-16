import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'player_controller.dart';

/// A visible player outside NEXA's [PlaybackEngine] (YouTube's own player,
/// SoundCloud's widget). Its sound never goes through NEXA's engine or Mix Engine.
abstract interface class ExternalPlayer {
  /// Making sound, or about to (playing / buffering).
  bool get active;

  /// What the Windows media overlay shows while this player owns it.
  MediaOverlay get overlay;

  Future<void> play();

  Future<void> pause();
}

/// Which player the user started last.
enum PlaybackOwner { nexa, external }

/// One sound at a time (E2.1): NEXA's own player and an [ExternalPlayer]
/// never play together, and the Windows media keys and overlay belong to the
/// one the user started last (behaviour verified on Windows in E2.0).
///
/// * The external player starts -> NEXA pauses.
/// * NEXA starts -> the external player pauses.
/// * While the external player was started last, the Play / Pause key
///   controls it, Next / Previous do nothing (it has no queue in NEXA), and
///   the overlay shows its state: Windows turns the Play / Pause key into
///   "Play" or "Pause" from the overlay, so the overlay must describe the
///   player the key is meant for.
class PlaybackArbiter extends Notifier<PlaybackOwner> {
  /// Visible external players on screen (YouTube, SoundCloud - E3).
  final List<ExternalPlayer> _externals = [];

  /// The external player started last: it owns the keys and the overlay
  /// while [PlaybackOwner.external].
  ExternalPlayer? _last;

  @override
  PlaybackOwner build() {
    ref.listen(playerProvider.select((s) => s.playing), (_, playing) {
      if (playing) {
        nexaStarted();
      }
    });
    ref.onDispose(() {
      _externals.clear();
      _last = null;
    });
    return PlaybackOwner.nexa;
  }

  /// The external player that owns (or would own) the keys.
  ExternalPlayer? get external =>
      _last ?? (_externals.isEmpty ? null : _externals.last);

  /// An external player is on screen (its page or dock opened).
  void attach(ExternalPlayer player) {
    if (!_externals.any((e) => identical(e, player))) {
      _externals.add(player);
    }
    ref.read(mediaKeyRedirectProvider.notifier).set(_onMediaKey);
    sync();
  }

  /// An external player is gone. NEXA owns the keys again when it was the
  /// one started last.
  void detach(ExternalPlayer player) {
    if (!_externals.any((e) => identical(e, player))) {
      return;
    }
    _externals.removeWhere((e) => identical(e, player));
    if (identical(_last, player)) {
      _last = null;
      state = PlaybackOwner.nexa;
    }
    if (_externals.isEmpty) {
      ref.read(mediaKeyRedirectProvider.notifier).set(null);
      ref.read(mediaOverlayOverrideProvider.notifier).set(null);
    } else {
      sync();
    }
  }

  /// An external player ([player], or the one attached last) starts or is
  /// about to: NEXA and every other external player pause first.
  Future<void> externalStarting([ExternalPlayer? player]) async {
    _last = player ?? external;
    state = PlaybackOwner.external;
    for (final e in _externals) {
      if (!identical(e, _last) && e.active) {
        unawaited(e.pause());
      }
    }
    sync();
    if (ref.read(playerProvider).playing) {
      await ref.read(playerProvider.notifier).pause();
    }
  }

  /// NEXA's own player started: every external player pauses.
  void nexaStarted() {
    state = PlaybackOwner.nexa;
    for (final e in _externals) {
      if (e.active) {
        unawaited(e.pause());
      }
    }
    sync();
  }

  /// Updates the Windows media overlay after an external player changed.
  void sync() {
    final e = external;
    ref
        .read(mediaOverlayOverrideProvider.notifier)
        .set(state == PlaybackOwner.external && e != null ? e.overlay : null);
  }

  Future<bool> _onMediaKey(String key) async {
    final e = external;
    if (state != PlaybackOwner.external || e == null) {
      return false; // NEXA's own player handles it.
    }
    switch (key) {
      case 'playPause':
        await (e.active ? e.pause() : e.play());
      case 'play':
        await e.play();
      case 'pause' || 'stop':
        await e.pause();
      default:
        // Next / Previous: NEXA's queue when the video is one of its
        // entries (E2.8); otherwise nothing (a video watched on its own).
        final queueVideo =
            ref.read(playerProvider).current?.source.isExternal ?? false;
        return !queueVideo; // false: NEXA's queue handles the key.
    }
    return true;
  }
}

final playbackArbiterProvider =
    NotifierProvider<PlaybackArbiter, PlaybackOwner>(PlaybackArbiter.new);
