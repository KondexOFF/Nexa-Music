import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/mix_engine/mix_settings.dart';
import '../../features/library/track_art.dart';
import '../../features/player/player_controller.dart';
import '../../features/player/player_controls.dart';
import '../../ui/ambient_light.dart';
import '../../ui/nexa_widgets.dart';
import '../navigation.dart';
import '../strings.dart';
import '../theme/nexa_theme.dart';
import '../theme/tokens.dart';

/// Persistent bottom player: current song, transport, seek, Mix chip,
/// volume, queue and Now Playing toggles.
class BottomPlayer extends ConsumerWidget {
  const BottomPlayer({super.key, required this.onToggleQueue});

  final VoidCallback onToggleQueue;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nav = ref.watch(navigationProvider);
    final controller = ref.read(navigationProvider.notifier);
    final mix = ref.watch(mixSettingsProvider);
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
        // NEXARYVE 1.2: graphite bar lit from the left by the artwork.
        return ColoredBox(
          color: NexaColors.playerBar,
          child: AmbientBackdrop(
          strength: 0.12,
          alignment: const Alignment(-1.05, 0.2),
          radius: 2.4,
          child: Container(
          height: NexaSizes.bottomPlayer,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: const BoxDecoration(
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
              const TransportControls(ringSize: 54),
              const SizedBox(width: 20),
              const Expanded(child: SeekBar()),
              const SizedBox(width: 16),
              _MixChip(
                label: mix.chipLabel,
                compact: compact,
                onTap: () => controller.go(NexaDestination.nowPlaying),
              ),
              const _VerticalRule(),
              VolumeControl(showSlider: !compact),
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
          ),
          ),
        );
      },
    );
  }
}

class _TrackInfo extends ConsumerWidget {
  const _TrackInfo({required this.onOpen});

  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final track = ref.watch(playerProvider.select((p) => p.current));
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
                  TrackArt(
                    artworkPath: track?.artworkPath,
                    seed: track?.id ?? 0,
                    size: 56,
                    radius: 8,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          track?.title ?? S.nothingPlaying,
                          style: NexaText.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          track?.artist ?? S.pickASong,
                          style: NexaText.caption,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        FavoriteButton(track: track),
      ],
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
              Icon(
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
