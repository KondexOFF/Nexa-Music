import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/strings.dart';
import '../../app/theme/nexa_theme.dart';
import '../../app/theme/tokens.dart';
import '../../core/models/track.dart';
import '../../demo/demo_data.dart' show formatClock;
import '../../ui/nexa_widgets.dart';
import 'library_dialogs.dart';
import '../nexa_dna/dna_providers.dart';
import '../nexa_wave/wave_controller.dart';
import '../player/player_controller.dart';
import 'library_providers.dart';
import 'track_art.dart';

/// Row height of track lists (fixed for fast scrolling of large libraries).
const double kTrackRowHeight = 60;

/// Column header for [SliverTrackList].
class TrackListHeader extends StatelessWidget {
  const TrackListHeader({super.key, required this.showAlbum});

  final bool showAlbum;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: NexaColors.divider)),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 36,
            child: Text('#', style: NexaText.tableHeader),
          ),
          const SizedBox(width: 52),
          const Expanded(
            flex: 5,
            child: Text(S.colTitle, style: NexaText.tableHeader),
          ),
          if (showAlbum)
            const Expanded(
              flex: 4,
              child: Text(S.colAlbum, style: NexaText.tableHeader),
            ),
          const SizedBox(
            width: 64,
            child: Text(S.colDuration, style: NexaText.tableHeader),
          ),
          const SizedBox(width: 84),
        ],
      ),
    );
  }
}

/// Library or playlist rows. With [playlistId], rows also offer remove and
/// move actions ([entryIds] must then match [tracks]).
class SliverTrackList extends ConsumerWidget {
  const SliverTrackList({
    super.key,
    required this.tracks,
    required this.showAlbum,
    this.playlistId,
    this.entryIds,
  });

  final List<Track> tracks;
  final bool showAlbum;
  final int? playlistId;
  final List<int>? entryIds;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentId = ref.watch(
      playerProvider.select((p) => p.current?.id),
    );
    return SliverFixedExtentList(
      itemExtent: kTrackRowHeight,
      delegate: SliverChildBuilderDelegate(
        (context, i) => TrackRow(
          isCurrent: tracks[i].id == currentId,
          // Clicking a song plays this list from that song.
          onPlay: () => ref
              .read(playerProvider.notifier)
              .playTracks(tracks, start: i),
          key: ValueKey(entryIds?[i] ?? tracks[i].id),
          index: i,
          track: tracks[i],
          showAlbum: showAlbum,
          playlistId: playlistId,
          entryId: entryIds?[i],
          isFirst: i == 0,
          isLast: i == tracks.length - 1,
        ),
        childCount: tracks.length,
      ),
    );
  }
}

enum _RowAction {
  playNext,
  addToQueue,
  addToPlaylist,
  favorite,
  dislike,
  rename,
  deleteSaved,
  remove,
  moveUp,
  moveDown,
}

class TrackRow extends ConsumerWidget {
  const TrackRow({
    super.key,
    required this.index,
    required this.track,
    required this.showAlbum,
    this.playlistId,
    this.entryId,
    this.isFirst = false,
    this.isLast = false,
    this.isCurrent = false,
    this.onPlay,
  });

  final int index;
  final Track track;
  final bool showAlbum;
  final int? playlistId;
  final int? entryId;
  final bool isFirst;
  final bool isLast;
  final bool isCurrent;
  final VoidCallback? onPlay;

  Future<void> _onAction(
    BuildContext context,
    WidgetRef ref,
    _RowAction action,
  ) async {
    final repo = ref.read(libraryRepositoryProvider);
    final player = ref.read(playerProvider.notifier);
    switch (action) {
      case _RowAction.playNext:
        player.playNext([track]);
      case _RowAction.addToQueue:
        player.addToQueue([track]);
      case _RowAction.addToPlaylist:
        await addTracksToPlaylist(context, ref, [track]);
      case _RowAction.favorite:
        await repo.setFavoriteFor(track, !track.favorite);
      case _RowAction.dislike:
        if (track.disliked) {
          await ref.read(tasteRepositoryProvider).setDisliked(track.id, false);
        } else {
          await ref.read(waveProvider.notifier).dislike(track);
        }
      case _RowAction.rename:
        final name = await askPlaylistName(
          context,
          title: S.renameSaved,
          initial: track.title,
          action: S.save,
        );
        if (name != null) {
          await repo.renameSaved(track, name);
        }
      case _RowAction.deleteSaved:
        final ok = await confirmAction(
          context,
          title: '${S.deleteSaved} "${track.title}"?',
          body: S.deleteSavedBody,
          action: S.delete,
        );
        if (ok) {
          await repo.deleteSaved(track);
        }
      case _RowAction.remove:
        await repo.removeFromPlaylist(entryId!);
      case _RowAction.moveUp:
        await repo.moveEntry(entryId!, -1);
      case _RowAction.moveDown:
        await repo.moveEntry(entryId!, 1);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dim = !track.available;
    final titleStyle = NexaText.body.copyWith(
      fontWeight: FontWeight.w600,
      color: dim
          ? NexaColors.textTertiary
          : isCurrent
          ? NexaColors.accent
          : NexaColors.textPrimary,
    );
    final duration = track.duration;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: NexaColors.divider)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 36,
            child: dim
                ? NexaTooltip(
                    message:
                        '${track.problem ?? S.unavailable}\n${track.path}',
                    child: const Icon(
                      Icons.error_outline_rounded,
                      size: 18,
                      color: NexaColors.coral,
                    ),
                  )
                : isCurrent
                ? const Icon(
                    Icons.graphic_eq_rounded,
                    size: 18,
                    color: NexaColors.accent,
                  )
                : Text('${index + 1}', style: NexaText.caption),
          ),
          Expanded(
            child: NexaTappable(
              onTap: onPlay,
              semanticLabel: '${S.play} ${track.title}',
              borderRadius: BorderRadius.circular(NexaRadius.sm),
              child: Row(
                children: [
                  Opacity(
                    opacity: dim ? 0.45 : 1,
                    child: TrackArt(
                      artworkPath: track.artworkPath,
                      seed: track.id,
                      size: 40,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 5,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          track.title,
                          style: titleStyle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          dim
                              ? '${track.problem ?? S.unavailable} - ${track.artist}'
                              : track.isOnline
                              ? '${track.artist} - ${track.source.label}'
                              : track.artist,
                          style: NexaText.caption.copyWith(
                            color: dim ? NexaColors.coral : null,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  if (showAlbum)
                    Expanded(
                      flex: 4,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: Text(
                          track.album,
                          style: NexaText.bodySecondary,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          SizedBox(
            width: 64,
            child: Text(
              duration == null ? '--:--' : formatClock(duration),
              style: NexaText.caption,
            ),
          ),
          NexaIconButton(
            icon: track.favorite
                ? Icons.favorite_rounded
                : Icons.favorite_border_rounded,
            label: track.favorite ? S.unlike : S.like,
            color: track.favorite
                ? NexaColors.accent
                : NexaColors.textSecondary,
            iconSize: 19,
            onPressed: () => ref
                .read(libraryRepositoryProvider)
                .setFavoriteFor(track, !track.favorite),
          ),
          const SizedBox(width: 4),
          PopupMenuButton<_RowAction>(
            tooltip: S.songActions,
            icon: const Icon(
              Icons.more_horiz_rounded,
              color: NexaColors.textSecondary,
            ),
            color: NexaColors.panelRaised,
            onSelected: (a) => _onAction(context, ref, a),
            itemBuilder: (context) => [
              // YouTube entries play only in YouTube's player (E2.8 adds
              // them to the one queue).
              if (track.rights.play) ...[
                const PopupMenuItem(
                  value: _RowAction.playNext,
                  child: Text(S.playNext),
                ),
                const PopupMenuItem(
                  value: _RowAction.addToQueue,
                  child: Text(S.addToQueue),
                ),
                const PopupMenuDivider(),
              ],
              const PopupMenuItem(
                value: _RowAction.addToPlaylist,
                child: Text('${S.addToPlaylist}...'),
              ),
              PopupMenuItem(
                value: _RowAction.favorite,
                child: Text(track.favorite ? S.unlike : S.like),
              ),
              if (!track.isOnline)
                PopupMenuItem(
                  value: _RowAction.dislike,
                  child: Text(track.disliked ? S.undislike : S.dislike),
                ),
              if (track.isOnline) ...[
                const PopupMenuItem(
                  value: _RowAction.rename,
                  child: Text(S.renameSaved),
                ),
                const PopupMenuItem(
                  value: _RowAction.deleteSaved,
                  child: Text(S.deleteSaved),
                ),
              ],
              if (entryId != null) ...[
                const PopupMenuDivider(),
                PopupMenuItem(
                  value: _RowAction.moveUp,
                  enabled: !isFirst,
                  child: const Text(S.moveUp),
                ),
                PopupMenuItem(
                  value: _RowAction.moveDown,
                  enabled: !isLast,
                  child: const Text(S.moveDown),
                ),
                const PopupMenuItem(
                  value: _RowAction.remove,
                  child: Text(S.removeFromPlaylist),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// Lets the user pick a playlist (or create one) and adds [tracks] to it
/// (library files, catalog songs and YouTube videos; online ones are saved).
Future<void> addTracksToPlaylist(
  BuildContext context,
  WidgetRef ref,
  List<Track> tracks,
) async {
  final repo = ref.read(libraryRepositoryProvider);
  final playlists = await repo.getPlaylists();
  if (!context.mounted) {
    return;
  }
  const newPlaylist = -1;
  final chosen = await showDialog<int>(
    context: context,
    builder: (context) => SimpleDialog(
      backgroundColor: NexaColors.panelRaised,
      title: const Text(S.addToPlaylist, style: NexaText.h3),
      children: [
        for (final pl in playlists)
          SimpleDialogOption(
            onPressed: () => Navigator.of(context).pop(pl.id),
            child: Text(pl.name, style: NexaText.body),
          ),
        SimpleDialogOption(
          onPressed: () => Navigator.of(context).pop(newPlaylist),
          child: Text(
            '+ ${S.newPlaylist}',
            style: NexaText.body.copyWith(color: NexaColors.accent),
          ),
        ),
      ],
    ),
  );
  if (chosen == null || !context.mounted) {
    return;
  }
  var playlistId = chosen;
  if (chosen == newPlaylist) {
    final name = await askPlaylistName(context);
    if (name == null) {
      return;
    }
    playlistId = await repo.createPlaylist(name);
  }
  await repo.addTracksToPlaylist(playlistId, tracks);
}
