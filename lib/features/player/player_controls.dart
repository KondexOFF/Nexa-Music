import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/strings.dart';
import '../../app/theme/nexa_theme.dart';
import '../../app/theme/tokens.dart';
import '../../core/models/track.dart';
import '../../demo/demo_data.dart' show formatClock;
import '../../ui/isolated_slider.dart';
import '../../ui/nexa_widgets.dart';
import '../../ui/play_ring_button.dart';
import '../library/library_providers.dart';
import 'player_controller.dart';

/// Shuffle, previous, play / pause, next, repeat.
class TransportControls extends ConsumerWidget {
  const TransportControls({
    super.key,
    required this.ringSize,
    this.skipSize = 28,
    this.modeSize = 20,
    this.gap = 6,
  });

  final double ringSize;
  final double skipSize;
  final double modeSize;
  final double gap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final player = ref.watch(playerProvider);
    final controller = ref.read(playerProvider.notifier);
    final hasTrack = player.current != null;
    final repeatIcon = player.repeat == PlayerRepeat.one
        ? Icons.repeat_one_rounded
        : Icons.repeat_rounded;
    final repeatLabel = switch (player.repeat) {
      PlayerRepeat.off => S.repeatOff,
      PlayerRepeat.all => S.repeatAll,
      PlayerRepeat.one => S.repeatOne,
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        NexaIconButton(
          icon: Icons.shuffle_rounded,
          label: player.shuffle ? S.shuffleOn : S.shuffleOff,
          iconSize: modeSize,
          boxSize: modeSize + 16,
          selected: player.shuffle,
          color: NexaColors.textSecondary,
          onPressed: controller.toggleShuffle,
        ),
        SizedBox(width: gap),
        NexaIconButton(
          icon: Icons.skip_previous_rounded,
          label: S.previous,
          disabledReason: S.nothingToPlay,
          iconSize: skipSize,
          boxSize: skipSize + 12,
          onPressed: hasTrack ? controller.previous : null,
        ),
        SizedBox(width: gap + 2),
        PlayRingButton(
          size: ringSize,
          playing: player.sounding,
          onPressed: hasTrack || player.queue.isNotEmpty
              ? controller.togglePlay
              : null,
        ),
        SizedBox(width: gap + 2),
        NexaIconButton(
          icon: Icons.skip_next_rounded,
          label: S.next,
          disabledReason: S.nothingToPlay,
          iconSize: skipSize,
          boxSize: skipSize + 12,
          onPressed: hasTrack && player.hasNext ? controller.next : null,
        ),
        SizedBox(width: gap),
        NexaIconButton(
          icon: repeatIcon,
          label: repeatLabel,
          iconSize: modeSize,
          boxSize: modeSize + 16,
          selected: player.repeat != PlayerRepeat.off,
          color: NexaColors.textSecondary,
          onPressed: controller.cycleRepeat,
        ),
      ],
    );
  }
}

/// Position slider with elapsed / total time. Dragging seeks on release.
class SeekBar extends ConsumerStatefulWidget {
  const SeekBar({super.key, this.compact = true});

  /// Compact: times left and right of the bar (bottom player); otherwise
  /// times below the bar (Now Playing).
  final bool compact;

  @override
  ConsumerState<SeekBar> createState() => _SeekBarState();
}

class _SeekBarState extends ConsumerState<SeekBar> {
  double? _dragMs;

  @override
  Widget build(BuildContext context) {
    final external = ref.watch(
      playerProvider.select((p) => p.current?.source.isExternal ?? false),
    );
    if (external) {
      // A YouTube entry: its own player has the position and seek bar.
      return Center(
        child: Text(
          S.queueInYouTube,
          key: const ValueKey('seek-external'),
          style: NexaText.caption,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      );
    }
    final engine = ref.watch(engineStateProvider).value;
    final hasTrack = ref.watch(playerProvider.select((p) => p.current != null));
    final duration = engine?.duration ?? Duration.zero;
    final maxMs = duration.inMilliseconds.toDouble();
    final positionMs = (_dragMs ?? engine?.position.inMilliseconds.toDouble() ?? 0)
        .clamp(0.0, maxMs <= 0 ? 0.0 : maxMs)
        .toDouble();
    final enabled = hasTrack && maxMs > 0;
    final slider = IsolatedSlider(
      child: Semantics(
        label: S.seek,
        child: SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 4,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
          ),
          child: Slider(
            value: enabled ? positionMs : 0,
            max: enabled ? maxMs : 1,
            onChanged: enabled ? (v) => setState(() => _dragMs = v) : null,
            onChangeEnd: enabled
                ? (v) async {
                    await ref
                        .read(playerProvider.notifier)
                        .seek(Duration(milliseconds: v.round()));
                    if (mounted) {
                      setState(() => _dragMs = null);
                    }
                  }
                : null,
          ),
        ),
      ),
    );
    final elapsed = Text(
      formatClock(Duration(milliseconds: positionMs.round())),
      style: NexaText.caption,
    );
    final total = Text(
      hasTrack ? formatClock(duration) : '--:--',
      style: NexaText.caption,
    );
    if (widget.compact) {
      return Row(
        children: [
          elapsed,
          const SizedBox(width: 6),
          Expanded(child: slider),
          const SizedBox(width: 6),
          total,
        ],
      );
    }
    return Column(
      children: [
        slider,
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(children: [elapsed, const Spacer(), total]),
        ),
      ],
    );
  }
}

/// Mute button and volume slider.
class VolumeControl extends ConsumerWidget {
  const VolumeControl({super.key, this.showSlider = true});

  final bool showSlider;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final volume = ref.watch(playerProvider.select((p) => p.volume));
    final muted = ref.watch(playerProvider.select((p) => p.muted));
    final controller = ref.read(playerProvider.notifier);
    final icon = muted || volume == 0
        ? Icons.volume_off_rounded
        : volume < 0.5
        ? Icons.volume_down_rounded
        : Icons.volume_up_rounded;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        NexaIconButton(
          icon: icon,
          label: muted ? S.unmute : S.mute,
          onPressed: controller.toggleMute,
        ),
        if (showSlider)
          SizedBox(
            width: 120,
            child: IsolatedSlider(
              child: Semantics(
                label: S.volume,
                child: Slider(
                  value: muted ? 0 : volume,
                  onChanged: controller.setVolume,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Heart for a library track (live favorite state).
class FavoriteButton extends ConsumerWidget {
  const FavoriteButton({
    super.key,
    required this.track,
    this.iconSize = 20,
    this.boxSize = 36,
  });

  final Track? track;
  final double iconSize;
  final double boxSize;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = track;
    if (t == null) {
      return NexaIconButton(
        icon: Icons.favorite_border_rounded,
        label: S.like,
        disabledReason: S.nothingToPlay,
        iconSize: iconSize,
        boxSize: boxSize,
      );
    }
    // Library files by their row; catalog songs and YouTube videos are
    // saved with their first like (E2.7).
    final live = t.isOnline
        ? savedOrSelf(ref, t)
        : ref.watch(trackProvider(t.id)).value ?? t;
    return NexaIconButton(
      icon: live.favorite
          ? Icons.favorite_rounded
          : Icons.favorite_border_rounded,
      label: live.favorite ? S.unlike : S.like,
      color: live.favorite ? NexaColors.accent : NexaColors.textSecondary,
      iconSize: iconSize,
      boxSize: boxSize,
      onPressed: () => ref
          .read(libraryRepositoryProvider)
          .setFavoriteFor(live, !live.favorite),
    );
  }
}
