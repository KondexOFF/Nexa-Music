import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/player/player_controller.dart';
import '../navigation.dart';

/// App-wide shortcuts (Phase 7, keyboard access):
/// Space play / pause, Ctrl + Right / Left next / previous,
/// Ctrl + Up / Down volume, Ctrl + M mute, Esc leaves a text field;
/// Alt + Left / Right and the mouse's back / forward buttons go back /
/// forward between pages (D-026).
///
/// Keys reach this widget only when nothing below handles them: text fields
/// keep Space and Ctrl + arrows for typing, and Space on a focused button
/// still activates that button.
class KeyboardShortcuts extends ConsumerStatefulWidget {
  const KeyboardShortcuts({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<KeyboardShortcuts> createState() => _KeyboardShortcutsState();
}

class _KeyboardShortcutsState extends ConsumerState<KeyboardShortcuts> {
  final FocusNode _node = FocusNode(debugLabel: 'nexa-shortcuts');

  @override
  void dispose() {
    _node.dispose();
    super.dispose();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final player = ref.read(playerProvider.notifier);
    final key = event.logicalKey;
    final ctrl = HardwareKeyboard.instance.isControlPressed;
    final repeat = event is KeyRepeatEvent;

    if (key == LogicalKeyboardKey.escape) {
      // Leave a text field; any other Esc (closing a drawer or dialog) is
      // not ours.
      final focused = FocusManager.instance.primaryFocus?.context;
      if (focused != null &&
          focused.findAncestorWidgetOfExactType<EditableText>() != null) {
        _node.requestFocus();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }
    if (!ctrl && !repeat && key == LogicalKeyboardKey.space) {
      // Only when no control is focused (then Space belongs to it).
      if (FocusManager.instance.primaryFocus != _node) {
        return KeyEventResult.ignored;
      }
      player.togglePlay();
      return KeyEventResult.handled;
    }
    if (HardwareKeyboard.instance.isAltPressed && !ctrl && !repeat) {
      final nav = ref.read(navigationProvider.notifier);
      if (key == LogicalKeyboardKey.arrowLeft) {
        nav.goBack();
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.arrowRight) {
        nav.goForward();
        return KeyEventResult.handled;
      }
    }
    if (!ctrl) {
      return KeyEventResult.ignored;
    }
    final volume = ref.read(playerProvider).volume;
    if (key == LogicalKeyboardKey.arrowRight && !repeat) {
      player.next();
    } else if (key == LogicalKeyboardKey.arrowLeft && !repeat) {
      player.previous();
    } else if (key == LogicalKeyboardKey.arrowUp) {
      player.setVolume((volume + 0.05).clamp(0.0, 1.0));
    } else if (key == LogicalKeyboardKey.arrowDown) {
      player.setVolume((volume - 0.05).clamp(0.0, 1.0));
    } else if (key == LogicalKeyboardKey.keyM && !repeat) {
      player.toggleMute();
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (e) {
        final nav = ref.read(navigationProvider.notifier);
        if (e.buttons & kBackMouseButton != 0) {
          nav.goBack();
        } else if (e.buttons & kForwardMouseButton != 0) {
          nav.goForward();
        }
      },
      child: Focus(
        focusNode: _node,
        autofocus: true,
        onKeyEvent: _onKey,
        child: widget.child,
      ),
    );
  }
}
