import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/navigation.dart';
import '../../app/strings.dart';
import '../../app/theme/nexa_theme.dart';
import '../../app/theme/tokens.dart';
import '../library/library_providers.dart';
import '../library/library_repository.dart';
import '../player/player_controller.dart';
import '../../ui/cover_art.dart';
import '../../ui/nexa_widgets.dart';

/// Home (E5): Liked Songs and the user's own playlists as cards - real
/// data, replacing the DEMO "For Your Moment" collections.
class PlaylistsSection extends ConsumerWidget {
  const PlaylistsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playlists = ref.watch(playlistsProvider).value ?? const [];
    final favorites = ref.watch(favoriteCountProvider).value ?? 0;
    final nav = ref.read(navigationProvider.notifier);
    final repo = ref.read(libraryRepositoryProvider);
    final player = ref.read(playerProvider.notifier);
    final cards = <_PlaylistCardData>[
      _PlaylistCardData(
        title: S.likedSongs,
        count: favorites,
        liked: true,
        open: () {
          ref.read(libraryTabProvider.notifier).set(LibraryTab.favorites);
          nav.go(NexaDestination.library);
        },
        play: () async => player.playTracks(
          await repo.getTracks(filter: TrackFilter.favorites),
        ),
      ),
      for (final pl in playlists)
        _PlaylistCardData(
          title: pl.name,
          count: pl.trackCount,
          seed: pl.id * 7919,
          open: () => nav.go(NexaDestination.playlist, playlistId: pl.id),
          play: () async => player.playTracks([
            for (final item in await repo.watchPlaylistItems(pl.id).first)
              item.track,
          ]),
        ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: S.yourPlaylists,
          subtitle: S.yourPlaylistsSubtitle,
          trailing: NexaTextLink(
            label: S.openLibrary,
            onTap: () => nav.go(NexaDestination.library),
          ),
        ),
        const SizedBox(height: NexaSpace.md),
        LayoutBuilder(
          builder: (context, constraints) {
            final count =
                (constraints.maxWidth / 190).floor().clamp(2, 4).toInt();
            final shown = cards.take(count).toList();
            return Row(
              children: [
                for (var i = 0; i < count; i++) ...[
                  if (i > 0) const SizedBox(width: NexaSpace.md),
                  Expanded(
                    child: i < shown.length
                        ? _PlaylistCard(data: shown[i])
                        : const SizedBox.shrink(),
                  ),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}

class _PlaylistCardData {
  const _PlaylistCardData({
    required this.title,
    required this.count,
    required this.open,
    required this.play,
    this.seed = 0,
    this.liked = false,
  });

  final String title;
  final int count;
  final int seed;
  final bool liked;
  final VoidCallback open;
  final Future<void> Function() play;
}

class _PlaylistCard extends StatelessWidget {
  const _PlaylistCard({required this.data});

  final _PlaylistCardData data;

  @override
  Widget build(BuildContext context) {
    final palette =
        CoverPalette.values[data.seed.abs() % CoverPalette.values.length];
    return AspectRatio(
      aspectRatio: 1.56,
      child: HoverLift(
        glow: data.liked ? NexaColors.accent : coverLight(palette),
        child: ClipRRect(
        borderRadius: BorderRadius.circular(NexaRadius.md),
        child: NexaTappable(
          onTap: data.open,
          semanticLabel: data.title,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (data.liked)
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFFC4B5FF), Color(0xFF6E58E8)],
                    ),
                  ),
                  child: Align(
                    alignment: Alignment(0.7, -0.4),
                    child: Icon(
                      Icons.favorite_rounded,
                      size: 44,
                      color: Color(0xCCFFFFFF),
                    ),
                  ),
                )
              else
                CoverArt(
                  spec: CoverArtSpec(
                    data.seed,
                    CoverPalette.values[data.seed.abs() %
                        CoverPalette.values.length],
                  ),
                  radius: 0,
                ),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x00000000), Color(0xD90B0C0F)],
                    stops: [0.4, 1],
                  ),
                ),
              ),
              Positioned(
                left: 14,
                right: 56,
                bottom: 12,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      data.title,
                      style: NexaText.title.copyWith(fontSize: 16),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${data.count} ${S.tracksSuffix}',
                      style: NexaText.caption.copyWith(
                        color: const Color(0xFFD5D3DF),
                      ),
                      maxLines: 1,
                    ),
                  ],
                ),
              ),
              Positioned(
                right: 12,
                bottom: 12,
                child: _CardPlayButton(
                  label: '${S.play} ${data.title}',
                  onPressed: data.count == 0 ? null : data.play,
                ),
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }
}

class _CardPlayButton extends StatelessWidget {
  const _CardPlayButton({required this.label, this.onPressed});

  final String label;
  final Future<void> Function()? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return NexaTooltip(
      message: enabled ? label : S.playlistEmpty,
      child: Semantics(
        button: true,
        enabled: enabled,
        label: label,
        child: GestureDetector(
          onTap: enabled ? () => onPressed!() : null,
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: enabled ? NexaColors.accent : const Color(0x66101218),
              border: Border.all(color: const Color(0x38FFFFFF)),
            ),
            child: Icon(
              Icons.play_arrow_rounded,
              size: 20,
              color: enabled ? const Color(0xFF14121F) : const Color(0x73FFFFFF),
            ),
          ),
        ),
      ),
    );
  }
}
