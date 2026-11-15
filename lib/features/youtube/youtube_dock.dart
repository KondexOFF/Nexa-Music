import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/navigation.dart';
import '../../app/strings.dart';
import '../../app/theme/nexa_theme.dart';
import '../../app/theme/tokens.dart';
import '../../ui/nexa_widgets.dart';
import 'youtube_player_controller.dart';
import 'youtube_watch_page.dart';

/// Compact player (E2.6): 16:9 at 200 px high - YouTube's player is never
/// smaller than 200 x 200 (Required Minimum Functionality), and at this
/// size its play button, progress bar, full screen and logo stay visible.
const Size youtubeCompactPlayer = Size(356, 200);

/// Client size of the "mini window": NEXA's window shrunk to the player, on
/// top of other apps. Still visible - not background playback.
const Size youtubeMiniWindow = Size(420, 276);

/// Height of the bar above the compact / mini player (never over it).
const double youtubeDockBar = 40;

/// Keeps the one web view element while the player moves between the
/// YouTube page, the compact player, full screen and the mini window.
final GlobalKey youtubeViewKey = GlobalKey(debugLabel: 'youtube-view');

/// Shrinks NEXA's window to the player and keeps it on top of other apps
/// ("mini window"), or restores it (windows/runner, "nexa/window").
class MiniWindowController extends Notifier<bool> {
  static const MethodChannel _channel = MethodChannel('nexa/window');

  @override
  bool build() => false;

  Future<void> set(bool on) async {
    if (on == state) {
      return;
    }
    if (Platform.isWindows && Platform.environment['FLUTTER_TEST'] != 'true') {
      try {
        await _channel.invokeMethod<bool>('setMini', {
          'on': on,
          'width': youtubeMiniWindow.width.round(),
          'height': youtubeMiniWindow.height.round(),
        });
      } on Object {
        return; // Window could not be changed: stay as it is.
      }
    }
    state = on;
  }
}

final miniWindowProvider = NotifierProvider<MiniWindowController, bool>(
  MiniWindowController.new,
);

/// The one YouTube player of NEXA, drawn by the shell above the pages:
/// * on the YouTube page - exactly at the page's player place;
/// * elsewhere - a compact player in the corner (with a bar above it to
///   open the page, use the mini window or close it);
/// * YouTube's own full screen - the whole window;
/// * mini window - the whole (small, on-top) window.
/// The same web view is moved between these places: the video is never
/// reloaded and keeps its position.
class YouTubeDock extends ConsumerWidget {
  const YouTubeDock({
    super.key,
    this.bottomInset = 0,
    this.rightInset = 0,
    this.fillWindow = false,
  });

  /// Space kept free at the bottom (NEXA's own player bar).
  final double bottomInset;

  /// Space kept free on the right (an open side panel).
  final double rightInset;

  /// Mini window: the player fills the window.
  final bool fillWindow;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(youtubePlayerProvider);
    final controller = ref.read(youtubePlayerProvider.notifier);
    final embed = controller.embed;
    if (!status.open || embed == null || status.unavailable != null) {
      return const SizedBox.shrink();
    }
    final view = KeyedSubtree(key: youtubeViewKey, child: embed.view());
    if (status.fullScreen) {
      return Positioned.fill(
        child: ColoredBox(color: Colors.black, child: view),
      );
    }
    if (fillWindow) {
      return Positioned.fill(
        child: ColoredBox(
          color: NexaColors.background,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _DockBar(status: status, miniWindow: true),
              Expanded(child: view),
            ],
          ),
        ),
      );
    }
    final onPage =
        ref.watch(navigationProvider.select((n) => n.current)) ==
        NexaDestination.youtube;
    return ValueListenableBuilder<Size?>(
      valueListenable: youtubeSlotSize,
      builder: (context, slot, _) {
        if (onPage && slot != null) {
          return Positioned(
            left: 0,
            top: 0,
            child: CompositedTransformFollower(
              link: youtubeSlotLink,
              showWhenUnlinked: false,
              child: SizedBox.fromSize(size: slot, child: view),
            ),
          );
        }
        return Positioned(
          right: rightInset + NexaSpace.md,
          bottom: bottomInset + NexaSpace.md,
          child: Material(
            key: const ValueKey('yt-compact'),
            color: NexaColors.panelRaised,
            elevation: 8,
            borderRadius: BorderRadius.circular(NexaRadius.md),
            clipBehavior: Clip.antiAlias,
            child: SizedBox(
              width: youtubeCompactPlayer.width,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _DockBar(status: status, miniWindow: false),
                  SizedBox.fromSize(size: youtubeCompactPlayer, child: view),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Title and buttons above the compact / mini player - never over it.
class _DockBar extends ConsumerWidget {
  const _DockBar({required this.status, required this.miniWindow});

  final YtStatus status;
  final bool miniWindow;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final title = (status.title ?? '').isEmpty ? S.ytPageTitle : status.title!;
    Future<void> close() async {
      if (miniWindow) {
        await ref.read(miniWindowProvider.notifier).set(false);
      }
      await ref.read(youtubePlayerProvider.notifier).close();
    }

    return SizedBox(
      height: youtubeDockBar,
      child: Padding(
        padding: const EdgeInsets.only(left: 12, right: 4),
        child: Row(
          children: [
            const StatusBadge(label: 'YouTube', color: NexaColors.coral),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                key: const ValueKey('yt-dock-title'),
                style: NexaText.caption.copyWith(
                  color: NexaColors.textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (status.autoplayBlocked && !status.active) ...[
              // YouTube did not start by itself (autoplay blocked): the
              // queue waits - never skipped, never stuck (E2.8).
              NexaPillButton(
                key: const ValueKey('yt-continue'),
                label: S.queueContinue,
                icon: Icons.play_arrow_rounded,
                height: 30,
                onPressed: () => ref.read(youtubePlayerProvider.notifier).play(),
              ),
              const SizedBox(width: 4),
            ],
            if (miniWindow)
              NexaIconButton(
                key: const ValueKey('yt-mini-restore'),
                icon: Icons.open_in_full_rounded,
                label: S.ytMiniRestore,
                onPressed: () =>
                    ref.read(miniWindowProvider.notifier).set(false),
              )
            else ...[
              NexaIconButton(
                key: const ValueKey('yt-dock-expand'),
                icon: Icons.open_in_full_rounded,
                label: S.ytDockExpand,
                onPressed: () => ref
                    .read(navigationProvider.notifier)
                    .go(NexaDestination.youtube),
              ),
              NexaIconButton(
                key: const ValueKey('yt-mini-window'),
                icon: Icons.picture_in_picture_alt_rounded,
                label: S.ytMiniWindow,
                onPressed: () =>
                    ref.read(miniWindowProvider.notifier).set(true),
              ),
            ],
            NexaIconButton(
              key: const ValueKey('yt-dock-close'),
              icon: Icons.close_rounded,
              label: S.ytClosePlayer,
              onPressed: () => unawaited(close()),
            ),
          ],
        ),
      ),
    );
  }
}
