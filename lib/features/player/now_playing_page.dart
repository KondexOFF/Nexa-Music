import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/navigation.dart';
import '../../app/strings.dart';
import '../../app/theme/nexa_theme.dart';
import '../../app/theme/tokens.dart';
import '../../core/models/track.dart';
import '../../ui/time_format.dart' show formatClock;
import '../library/library_providers.dart';
import '../library/track_art.dart';
import '../discover/catalog_providers.dart' show linkOpenerProvider;
import '../library/track_list.dart';
import '../../ui/ambient_light.dart';
import '../../ui/nexa_widgets.dart';
import '../mix_engine/mix_engine_panel.dart';
import '../discover/source_attribution.dart';
import '../nexa_wave/dislike_button.dart';
import '../nexa_wave/wave_page.dart' show WaveReasonLine;
import 'player_controller.dart';
import 'player_controls.dart';
import 'up_next_card.dart';

/// Full Now Playing screen: the current song, transport, position, queue.
class NowPlayingPage extends ConsumerWidget {
  const NowPlayingPage({super.key, required this.inlineMixEngine});

  /// True when the right panel is collapsed: the Mix Engine is shown below
  /// the player instead.
  final bool inlineMixEngine;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final track = ref.watch(playerProvider.select((p) => p.current));
    final light = ref.watch(ambientLightProvider);
    // NEXARYVE 1.2: the artwork lights the page around it.
    return AmbientBackdrop(
      strength: 0.24,
      alignment: const Alignment(-0.55, -0.45),
      radius: 1.1,
      child: LayoutBuilder(
      builder: (context, constraints) {
        final contentWidth = constraints.maxWidth - 48;
        // Narrow (e.g. while the window shrinks): cover above the details.
        final stacked = contentWidth < 600;
        final coverSize = stacked
            ? contentWidth.clamp(0.0, 320.0).toDouble()
            : (contentWidth * 0.42).clamp(240.0, 440.0).toDouble();
        final cover = AnimatedContainer(
          duration: NexaMotion.ambient,
          curve: Curves.easeInOut,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(NexaRadius.lg),
            boxShadow: [
              // The artwork's own light under it.
              BoxShadow(
                color: light.withValues(alpha: 0.42),
                blurRadius: 70,
                spreadRadius: -10,
                offset: const Offset(0, 24),
              ),
              const BoxShadow(
                color: Color(0x66000000),
                blurRadius: 24,
                spreadRadius: -12,
                offset: Offset(0, 14),
              ),
            ],
          ),
          child: TrackArt(
            artworkPath: track?.artworkPath,
            seed: track?.id ?? 0,
            size: coverSize,
            radius: NexaRadius.lg,
          ),
        );
        return SingleChildScrollView(
          key: const PageStorageKey('page-now-playing'),
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Wrap instead of Row: never overflows, even mid-animation
              // while the window shrinks.
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 16,
                runSpacing: 12,
                children: [
                  const Text(S.nowPlaying, style: NexaText.overline),
                  _WaveChip(
                    onTap: () => ref
                        .read(navigationProvider.notifier)
                        .go(NexaDestination.wave),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              if (stacked)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    cover,
                    const SizedBox(height: 24),
                    _TrackDetails(track: track),
                  ],
                )
              else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    cover,
                    const SizedBox(width: 36),
                    Expanded(child: _TrackDetails(track: track)),
                  ],
                ),
              const SizedBox(height: 28),
              const SeekBar(compact: false),
              const SizedBox(height: 18),
              const _NowPlayingTabs(),
              if (inlineMixEngine) ...[
                const SizedBox(height: 24),
                const MixEnginePanel(),
              ],
            ],
          ),
        );
      },
      ),
    );
  }
}

class _WaveChip extends StatelessWidget {
  const _WaveChip({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0x33FFFFFF)),
      ),
      child: NexaTappable(
        onTap: onTap,
        tooltip: S.waveChipTooltip,
        semanticLabel: S.waveChip,
        borderRadius: BorderRadius.circular(28),
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 18, vertical: 11),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.auto_awesome_rounded, size: 18, color: NexaColors.accent),
              SizedBox(width: 10),
              Text(S.waveChip, style: NexaText.body),
              SizedBox(width: 8),
              Icon(Icons.chevron_right_rounded, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _TrackDetails extends ConsumerWidget {
  const _TrackDetails({required this.track});

  final Track? track;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = track;
    final duration = t?.duration;
    final format = t == null
        ? S.navLibrary.toUpperCase()
        : [
            t.fileExtension,
            if (duration != null) formatClock(duration),
          ].join(' · ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          t?.title ?? S.nothingPlaying,
          style: NexaText.display.copyWith(fontSize: 46),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 6),
        Text(
          t == null ? S.nothingToPlay : '${t.artist} · ${t.album}',
          style: NexaText.h2.copyWith(
            fontSize: 22,
            fontWeight: FontWeight.w500,
            color: NexaColors.textSecondary,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        if (t != null) WaveReasonLine(track: t),
        if (t != null && t.isOnline) SourceAttribution(track: t),
        const SizedBox(height: 18),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: NexaColors.panel,
              borderRadius: BorderRadius.circular(NexaRadius.sm),
              border: Border.all(color: NexaColors.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.graphic_eq_rounded,
                  size: 16,
                  color: NexaColors.accent,
                ),
                const SizedBox(width: 8),
                Text(
                  format,
                  style: const TextStyle(
                    fontFamily: NexaText.family,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.6,
                    color: NexaColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: t == null
              ? NexaPillButton(
                  label: S.goToLibrary,
                  icon: Icons.library_music_outlined,
                  height: 44,
                  onPressed: () => ref
                      .read(navigationProvider.notifier)
                      .go(NexaDestination.library),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _Circle(child: FavoriteButton(track: t, iconSize: 24, boxSize: 52)),
                    const SizedBox(width: 14),
                    _Circle(
                      child: DislikeButton(track: t, iconSize: 24, boxSize: 52),
                    ),
                    const SizedBox(width: 14),
                    _Circle(
                      child: NexaIconButton(
                        icon: Icons.add_rounded,
                        label: S.addToPlaylist,
                        iconSize: 24,
                        boxSize: 52,
                        color: NexaColors.textSecondary,
                        onPressed: () => addTracksToPlaylist(context, ref, [t]),
                      ),
                    ),
                    const SizedBox(width: 14),
                    // E5 audit: library songs open their album / artist;
                    // online songs open their page at the source instead
                    // of showing disabled buttons.
                    if (!t.isOnline) ...[
                      _Circle(
                        child: NexaIconButton(
                          icon: Icons.album_outlined,
                          label: S.goToAlbum,
                          iconSize: 24,
                          boxSize: 52,
                          color: NexaColors.textSecondary,
                          onPressed: () => _goToGroup(ref, album: t.album),
                        ),
                      ),
                      const SizedBox(width: 14),
                      _Circle(
                        child: NexaIconButton(
                          icon: Icons.person_outline_rounded,
                          label: S.goToArtist,
                          iconSize: 24,
                          boxSize: 52,
                          color: NexaColors.textSecondary,
                          onPressed: () => _goToGroup(ref, artist: t.artist),
                        ),
                      ),
                    ] else if ((t.pageUrl ?? '').isNotEmpty)
                      _Circle(
                        child: NexaIconButton(
                          key: const ValueKey('np-open-source'),
                          icon: Icons.open_in_new_rounded,
                          label: S.openOnSource(t.source.label),
                          iconSize: 24,
                          boxSize: 52,
                          color: NexaColors.textSecondary,
                          onPressed: () =>
                              ref.read(linkOpenerProvider)(t.pageUrl!),
                        ),
                      ),
                  ],
                ),
        ),
        const SizedBox(height: 28),
        const FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: TransportControls(
            ringSize: 88,
            skipSize: 40,
            modeSize: 28,
            gap: 14,
          ),
        ),
      ],
    );
  }

  void _goToGroup(WidgetRef ref, {String? album, String? artist}) {
    ref
        .read(groupFilterProvider.notifier)
        .set(GroupFilter(album: album, artist: artist));
    ref.read(libraryTabProvider.notifier).set(LibraryTab.songs);
    ref.read(libraryQueryProvider.notifier).set('');
    ref.read(navigationProvider.notifier).go(NexaDestination.library);
  }
}

class _Circle extends StatelessWidget {
  const _Circle({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0x08FFFFFF),
        border: Border.all(color: const Color(0x1FFFFFFF)),
      ),
      child: child,
    );
  }
}

class _NowPlayingTabs extends StatelessWidget {
  const _NowPlayingTabs();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(4, 8, 12, 10),
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: NexaColors.accent, width: 2),
                ),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.format_list_bulleted_rounded,
                    size: 18,
                    color: NexaColors.accent,
                  ),
                  SizedBox(width: 10),
                  Text(
                    S.queueTab,
                    style: TextStyle(
                      fontFamily: NexaText.family,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: NexaColors.accent,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const Divider(height: 1, color: NexaColors.divider),
        const SizedBox(height: 10),
        const UpNextCard(maxItems: 8, framed: false),
      ],
    );
  }
}
