import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/navigation.dart';
import '../../app/strings.dart';
import '../../app/theme/nexa_theme.dart';
import '../../app/theme/tokens.dart';
import '../../demo/demo_data.dart' show formatClock;
import '../../ui/nexa_widgets.dart';
import 'library_dialogs.dart';
import 'library_providers.dart';
import 'track_art.dart';
import 'track_list.dart';

/// One user playlist.
class PlaylistPage extends ConsumerWidget {
  const PlaylistPage({super.key, required this.playlistId});

  final int playlistId;

  Future<void> _rename(BuildContext context, WidgetRef ref, String name) async {
    final newName = await askPlaylistName(
      context,
      title: S.renamePlaylist,
      initial: name,
      action: S.save,
    );
    if (newName != null && newName.isNotEmpty) {
      await ref.read(libraryRepositoryProvider).renamePlaylist(playlistId, newName);
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, String name) async {
    final ok = await confirmAction(
      context,
      title: '${S.deletePlaylist} "$name"?',
      body: S.deletePlaylistBody,
      action: S.delete,
    );
    if (ok) {
      ref.read(navigationProvider.notifier).leavePlaylist(playlistId);
      await ref.read(libraryRepositoryProvider).deletePlaylist(playlistId);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playlist = ref.watch(playlistProvider(playlistId)).value;
    final items = ref.watch(playlistItemsProvider(playlistId)).value ?? const [];
    final name = playlist?.name ?? '';
    final total = items.fold<Duration>(
      Duration.zero,
      (sum, item) => sum + (item.track.duration ?? Duration.zero),
    );
    return LayoutBuilder(
      builder: (context, box) {
        final showAlbum = box.maxWidth > 640;
        return CustomScrollView(
          key: PageStorageKey('page-playlist-$playlistId'),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
              sliver: SliverToBoxAdapter(
                child: Row(
                  children: [
                    TrackArt(
                      artworkPath: items.isEmpty ? null : items.first.track.artworkPath,
                      seed: playlistId * 7919,
                      size: 112,
                      radius: NexaRadius.lg,
                    ),
                    const SizedBox(width: 22),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('PLAYLIST', style: NexaText.overline),
                          const SizedBox(height: 6),
                          Text(
                            name,
                            style: NexaText.display,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${items.length} ${S.tracksSuffix} - '
                            '${formatClock(total)}',
                            style: NexaText.bodySecondary,
                          ),
                        ],
                      ),
                    ),
                    NexaIconButton(
                      icon: Icons.edit_outlined,
                      label: S.renamePlaylist,
                      onPressed: playlist == null
                          ? null
                          : () => _rename(context, ref, name),
                    ),
                    const SizedBox(width: 6),
                    NexaIconButton(
                      icon: Icons.delete_outline_rounded,
                      label: S.deletePlaylist,
                      onPressed: playlist == null
                          ? null
                          : () => _delete(context, ref, name),
                    ),
                  ],
                ),
              ),
            ),
            if (items.isEmpty)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Text(S.playlistEmpty, style: NexaText.bodySecondary),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                sliver: SliverMainAxisGroup(
                  slivers: [
                    SliverToBoxAdapter(
                      child: TrackListHeader(showAlbum: showAlbum),
                    ),
                    SliverTrackList(
                      tracks: [for (final i in items) i.track],
                      entryIds: [for (final i in items) i.entryId],
                      playlistId: playlistId,
                      showAlbum: showAlbum,
                    ),
                  ],
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 28)),
          ],
        );
      },
    );
  }
}
