import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/navigation.dart';
import '../../app/strings.dart';
import '../../app/theme/nexa_theme.dart';
import '../../app/theme/tokens.dart';
import '../../ui/nexa_widgets.dart';
import '../youtube/youtube_dock.dart' show youtubeCompactPlayer, youtubeDockBar;
import '../youtube/youtube_player_controller.dart';
import 'soundcloud_player_controller.dart';

/// Size of SoundCloud's classic widget (artwork, title, uploader, waveform
/// and SoundCloud's branding all visible).
const Size soundcloudWidget = Size(356, 166);

/// SoundCloud's widget in the corner while it is open (E3): visible on
/// every page, next to YouTube's compact player when both are open. Its
/// title bar sits above the widget, never over it.
class SoundCloudDock extends ConsumerWidget {
  const SoundCloudDock({super.key, this.bottomInset = 0, this.rightInset = 0});

  final double bottomInset;
  final double rightInset;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(soundcloudPlayerProvider);
    final controller = ref.read(soundcloudPlayerProvider.notifier);
    final embed = controller.embed;
    if (!status.open) {
      return const SizedBox.shrink();
    }
    final yt = ref.watch(youtubePlayerProvider);
    final ytOnPage =
        ref.watch(navigationProvider.select((n) => n.current)) ==
        NexaDestination.youtube;
    // Beside YouTube's compact player, never under it.
    final besideYouTube = yt.open && yt.unavailable == null && !ytOnPage;
    final right =
        rightInset +
        NexaSpace.md +
        (besideYouTube ? youtubeCompactPlayer.width + NexaSpace.md : 0);
    final title = (status.title ?? '').isEmpty ? S.scUnnamed : status.title!;
    return Positioned(
      right: right,
      bottom: bottomInset + NexaSpace.md,
      child: Material(
        key: const ValueKey('sc-dock'),
        color: NexaColors.panelRaised,
        elevation: 8,
        borderRadius: BorderRadius.circular(NexaRadius.md),
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          width: soundcloudWidget.width,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: youtubeDockBar,
                child: Padding(
                  padding: const EdgeInsets.only(left: 12, right: 4),
                  child: Row(
                    children: [
                      const StatusBadge(
                        label: 'SoundCloud',
                        color: NexaColors.orange,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          title,
                          key: const ValueKey('sc-dock-title'),
                          style: NexaText.caption.copyWith(
                            color: NexaColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (status.autoplayBlocked && !status.playing) ...[
                        NexaPillButton(
                          key: const ValueKey('sc-continue'),
                          label: S.queueContinue,
                          icon: Icons.play_arrow_rounded,
                          height: 30,
                          onPressed: controller.play,
                        ),
                        const SizedBox(width: 4),
                      ],
                      NexaIconButton(
                        key: const ValueKey('sc-dock-close'),
                        icon: Icons.close_rounded,
                        label: S.scClose,
                        onPressed: () => unawaited(controller.close()),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox.fromSize(
                size: soundcloudWidget,
                child: status.unavailable != null
                    ? Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          S.scUnavailable(status.unavailable!),
                          style: NexaText.caption,
                        ),
                      )
                    : embed == null
                    ? const SizedBox.shrink()
                    : embed.view(),
              ),
              if (status.error != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
                  child: Text(
                    status.error!,
                    style: NexaText.caption.copyWith(color: NexaColors.coral),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
