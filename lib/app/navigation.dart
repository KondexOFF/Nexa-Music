import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Top-level screens of the shell.
enum NexaDestination {
  home,
  wave,
  discover,
  library,
  settings,
  nowPlaying,

  /// A user playlist ([NavigationState.playlistId]).
  playlist,
}

/// A place in the app: a screen plus, for playlists, which one.
@immutable
class NexaLocation {
  const NexaLocation(this.destination, {this.playlistId});

  final NexaDestination destination;
  final int? playlistId;

  @override
  bool operator ==(Object other) =>
      other is NexaLocation &&
      other.destination == destination &&
      other.playlistId == playlistId;

  @override
  int get hashCode => Object.hash(destination, playlistId);
}

/// Current screen plus back / forward history (top bar arrows).
@immutable
class NavigationState {
  const NavigationState({
    required this.location,
    this.back = const [],
    this.forward = const [],
  });

  final NexaLocation location;
  final List<NexaLocation> back;
  final List<NexaLocation> forward;

  NexaDestination get current => location.destination;
  int? get playlistId => location.playlistId;

  bool get canGoBack => back.isNotEmpty;
  bool get canGoForward => forward.isNotEmpty;
}

class NavigationController extends Notifier<NavigationState> {
  static const int maxHistory = 50;

  @override
  NavigationState build() =>
      const NavigationState(location: NexaLocation(NexaDestination.home));

  void go(NexaDestination destination, {int? playlistId}) {
    final target = NexaLocation(destination, playlistId: playlistId);
    if (target == state.location) {
      return;
    }
    final back = [...state.back, state.location];
    if (back.length > maxHistory) {
      back.removeAt(0);
    }
    state = NavigationState(location: target, back: back);
  }

  void goBack() {
    if (!state.canGoBack) {
      return;
    }
    final back = [...state.back];
    final previous = back.removeLast();
    state = NavigationState(
      location: previous,
      back: back,
      forward: [state.location, ...state.forward],
    );
  }

  void goForward() {
    if (!state.canGoForward) {
      return;
    }
    final forward = [...state.forward];
    final next = forward.removeAt(0);
    state = NavigationState(
      location: next,
      back: [...state.back, state.location],
      forward: forward,
    );
  }

  /// Leaves a playlist page that no longer exists (e.g. after deleting it).
  void leavePlaylist(int playlistId) {
    bool keep(NexaLocation l) =>
        !(l.destination == NexaDestination.playlist &&
            l.playlistId == playlistId);
    final back = state.back.where(keep).toList();
    final forward = state.forward.where(keep).toList();
    final location = keep(state.location)
        ? state.location
        : (back.isNotEmpty
              ? back.removeLast()
              : const NexaLocation(NexaDestination.library));
    state = NavigationState(location: location, back: back, forward: forward);
  }
}

final navigationProvider =
    NotifierProvider<NavigationController, NavigationState>(
      NavigationController.new,
    );

/// Whether the optional right panel is shown on wide windows.
class RightPanelController extends Notifier<bool> {
  @override
  bool build() => true;

  void toggle() => state = !state;
}

final rightPanelVisibleProvider = NotifierProvider<RightPanelController, bool>(
  RightPanelController.new,
);
