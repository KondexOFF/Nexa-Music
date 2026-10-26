import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'player_controller.dart';

/// A visible player outside NEXA's [PlaybackEngine] (E2: YouTube's own
/// player). Its sound never goes through NEXA's engine or Mix Engine.
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
  ExternalPlayer? _external;

  @override
  PlaybackOwner build() {
    ref.listen(playerProvider.select((s) => s.playing), (_, playing) {
      if (playing) {
        nexaStarted();
      }
    });
    ref.onDispose(() => _external = null);
    return PlaybackOwner.nexa;
  }

  ExternalPlayer? get external => _external;

  /// The external player is on screen (its page opened).
  void attach(ExternalPlayer player) {
    _external = player;
    ref.read(mediaKeyRedirectProvider.notifier).set(_onMediaKey);
    sync();
  }

  /// The external player is gone (its page closed). NEXA owns the keys again.
  void detach(ExternalPlayer player) {
    if (!identical(_external, player)) {
      return;
    }
    _external = null;
    state = PlaybackOwner.nexa;
    ref.read(mediaKeyRedirectProvider.notifier).set(null);
    ref.read(mediaOverlayOverrideProvider.notifier).set(null);
  }

  /// The external player starts or is about to: NEXA pauses first.
  Future<void> externalStarting() async {
    state = PlaybackOwner.external;
    sync();
    if (ref.read(playerProvider).playing) {
      await ref.read(playerProvider.notifier).pause();
    }
  }

  /// NEXA's own player started: the external player pauses.
  void nexaStarted() {
    state = PlaybackOwner.nexa;
    final e = _external;
    if (e != null && e.active) {
      unawaited(e.pause());
    }
    sync();
  }

  /// Updates the Windows media overlay after the external player changed.
  void sync() {
    final e = _external;
    ref
        .read(mediaOverlayOverrideProvider.notifier)
        .set(state == PlaybackOwner.external && e != null ? e.overlay : null);
  }

  Future<bool> _onMediaKey(String key) async {
    final e = _external;
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
        break; // No queue for the external player.
    }
    return true;
  }
}

final playbackArbiterProvider =
    NotifierProvider<PlaybackArbiter, PlaybackOwner>(PlaybackArbiter.new);
