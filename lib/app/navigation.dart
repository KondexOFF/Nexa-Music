import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Top-level screens of the Phase 1 shell.
enum NexaDestination { home, wave, discover, library, settings, nowPlaying }

/// Current screen plus back / forward history (top bar arrows).
@immutable
class NavigationState {
  const NavigationState({
    required this.current,
    this.back = const [],
    this.forward = const [],
  });

  final NexaDestination current;
  final List<NexaDestination> back;
  final List<NexaDestination> forward;

  bool get canGoBack => back.isNotEmpty;
  bool get canGoForward => forward.isNotEmpty;
}

class NavigationController extends Notifier<NavigationState> {
  static const int maxHistory = 50;

  @override
  NavigationState build() =>
      const NavigationState(current: NexaDestination.home);

  void go(NexaDestination destination) {
    if (destination == state.current) {
      return;
    }
    final back = [...state.back, state.current];
    if (back.length > maxHistory) {
      back.removeAt(0);
    }
    state = NavigationState(current: destination, back: back);
  }

  void goBack() {
    if (!state.canGoBack) {
      return;
    }
    final back = [...state.back];
    final previous = back.removeLast();
    state = NavigationState(
      current: previous,
      back: back,
      forward: [state.current, ...state.forward],
    );
  }

  void goForward() {
    if (!state.canGoForward) {
      return;
    }
    final forward = [...state.forward];
    final next = forward.removeAt(0);
    state = NavigationState(
      current: next,
      back: [...state.back, state.current],
      forward: forward,
    );
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
