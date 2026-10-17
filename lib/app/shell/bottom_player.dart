import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../demo/demo_data.dart';
import '../../features/mix_engine/mix_preview.dart';
import '../../ui/cover_art.dart';
import '../../ui/nexa_widgets.dart';
import '../../ui/play_ring_button.dart';
import '../navigation.dart';
import '../strings.dart';
import '../theme/nexa_theme.dart';
import '../theme/tokens.dart';

/// Persistent bottom player. Shows DEMO track data; transport, seek and
/// volume are visibly disabled until the Playback Engine (Phase 3).
/// Navigation actions (Now Playing, Mix Engine, Up Next) work.
class BottomPlayer extends ConsumerWidget {
  const BottomPlayer({super.key, required this.onToggleQueue});

  final VoidCallback onToggleQueue;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nav = ref.watch(navigationProvider);
    final controller = ref.read(navigationProvider.notifier);
    final mix = ref.watch(mixPreviewProvider);
    final onNowPlaying = nav.current == NexaDestination.nowPlaying;

    void toggleNowPlaying() {
      if (onNowPlaying) {
        if (nav.canGoBack) {
          controller.goBack();
        } else {
          controller.go(NexaDestination.home);
        }
      } else {
        controller.go(NexaDestination.nowPlaying);
      }
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < NexaBreakpoints.compactPlayerBar;
        return Container(
          height: NexaSizes.bottomPlayer,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: const BoxDecoration(
            color: NexaColors.playerBar,
            border: Border(top: BorderSide(color: NexaColors.divider)),
          ),
          child: Row(
            children: [
              SizedBox(
                width: compact ? 230 : 300,
                child: _TrackInfo(
                  onOpen: () => controller.go(NexaDestination.nowPlaying),
                ),
              ),
              const SizedBox(width: 16),
              const _Transport(),
              const SizedBox(width: 24),
              const Expanded(child: _ProgressDemo()),
              const SizedBox(width: 20),
              _MixChip(
                label: mix.chipLabel,
                compact: compact,
                onTap: () => controller.go(NexaDestination.nowPlaying),
              ),
              const _VerticalRule(),
              const NexaIconButton(
                icon: Icons.volume_up_rounded,
                label: S.volume,
                disabledReason: S.soonVolume,
              ),
              if (!compact)
                const SizedBox(
                  width: 120,
                  child: Tooltip(
                    message: S.soonVolume,
                    child: Slider(value: 0.65, onChanged: null),
                  ),
                ),
              const _VerticalRule(),
              NexaIconButton(
                icon: Icons.queue_music_rounded,
                label: S.toggleQueue,
                onPressed: onToggleQueue,
              ),
              NexaIconButton(
                icon: onNowPlaying
                    ? Icons.close_fullscreen_rounded
                    : Icons.open_in_full_rounded,
                label: onNowPlaying ? S.closeNowPlaying : S.openNowPlaying,
                iconSize: 18,
                selected: onNowPlaying,
                onPressed: toggleNowPlaying,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TrackInfo extends StatelessWidget {
  const _TrackInfo({required this.onOpen});

  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    const track = DemoData.nowPlaying;
    return Row(
      children: [
        Expanded(
          child: NexaTappable(
            onTap: onOpen,
            tooltip: S.openNowPlaying,
            borderRadius: BorderRadius.circular(NexaRadius.md),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Row(
                children: [
                  CoverArt(spec: track.art, size: 56),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          track.title,
                          style: NexaText.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                track.artist,
                                style: NexaText.caption,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const StatusBadge.demo(),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const NexaIconButton(
          icon: Icons.favorite_border_rounded,
          label: S.like,
          disabledReason: S.soonFavorites,
        ),
      ],
    );
  }
}

class _Transport extends StatelessWidget {
  const _Transport();

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        NexaIconButton(
          icon: Icons.shuffle_rounded,
          label: S.shuffleLabel,
          disabledReason: S.soonPlayback,
        ),
        SizedBox(width: 6),
        NexaIconButton(
          icon: Icons.skip_previous_rounded,
          label: S.previous,
          disabledReason: S.soonPlayback,
          iconSize: 28,
          boxSize: 40,
        ),
        SizedBox(width: 8),
        PlayRingButton(size: 54),
        SizedBox(width: 8),
        NexaIconButton(
          icon: Icons.skip_next_rounded,
          label: S.next,
          disabledReason: S.soonPlayback,
          iconSize: 28,
          boxSize: 40,
        ),
        SizedBox(width: 6),
        NexaIconButton(
          icon: Icons.repeat_rounded,
          label: S.repeat,
          disabledReason: S.soonPlayback,
        ),
      ],
    );
  }
}

class _ProgressDemo extends StatelessWidget {
  const _ProgressDemo();

  @override
  Widget build(BuildContext context) {
    const position = DemoData.nowPlayingPosition;
    final duration = DemoData.nowPlaying.duration;
    final fraction = position.inMilliseconds / duration.inMilliseconds;
    return Tooltip(
      message: S.soonSeek,
      child: Row(
        children: [
          Text(formatClock(position), style: NexaText.caption),
          const SizedBox(width: 12),
          Expanded(
            child: LayoutBuilder(
              builder: (context, c) => SizedBox(
                height: 14,
                child: Stack(
                  alignment: Alignment.centerLeft,
                  children: [
                    Container(
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0x1FFFFFFF),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Container(
                      width: c.maxWidth * fraction,
                      height: 4,
                      decoration: BoxDecoration(
                        color: NexaColors.accent.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Positioned(
                      left: (c.maxWidth * fraction - 6)
                          .clamp(0.0, c.maxWidth)
                          .toDouble(),
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0x80BDB6D6),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(formatClock(duration), style: NexaText.caption),
        ],
      ),
    );
  }
}

class _MixChip extends StatelessWidget {
  const _MixChip({
    required this.label,
    required this.compact,
    required this.onTap,
  });

  final String label;
  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: NexaColors.panelRaised,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: NexaColors.border),
      ),
      child: NexaTappable(
        onTap: onTap,
        tooltip: S.mixChipTooltip,
        semanticLabel: S.mixChipTooltip,
        borderRadius: BorderRadius.circular(28),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 12 : 16,
            vertical: 10,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.graphic_eq_rounded,
                size: 20,
                color: NexaColors.accent,
              ),
              if (!compact) ...[
                const SizedBox(width: 10),
                AnimatedSwitcher(
                  duration: NexaMotion.fast,
                  child: Text(
                    label,
                    key: ValueKey(label),
                    style: NexaText.body.copyWith(fontSize: 13),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _VerticalRule extends StatelessWidget {
  const _VerticalRule();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 28,
      margin: const EdgeInsets.symmetric(horizontal: 12),
      color: NexaColors.divider,
    );
  }
}
