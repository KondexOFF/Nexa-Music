import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/strings.dart';
import '../../app/theme/nexa_theme.dart';
import '../../app/theme/tokens.dart';
import '../../core/database/app_database.dart';
import '../../ui/nexa_widgets.dart';
import 'library_dialogs.dart';
import 'library_providers.dart';
import 'library_repository.dart';
import 'library_scanner.dart';
import 'track_art.dart';
import 'track_list.dart';

/// Local library: import, search, songs, favorites, albums, artists, folders.
class LibraryPage extends ConsumerWidget {
  const LibraryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(libraryTabProvider);
    final group = ref.watch(groupFilterProvider);
    return LayoutBuilder(
      builder: (context, box) {
        final showAlbum = box.maxWidth > 640;
        return CustomScrollView(
          key: const PageStorageKey('page-library'),
          slivers: [
            const SliverPadding(
              padding: EdgeInsets.fromLTRB(24, 8, 24, 0),
              sliver: SliverToBoxAdapter(child: _LibraryHeader()),
            ),
            const SliverPadding(
              padding: EdgeInsets.fromLTRB(24, 14, 24, 0),
              sliver: SliverToBoxAdapter(child: _ScanStatus()),
            ),
            const SliverPadding(
              padding: EdgeInsets.fromLTRB(24, 14, 24, 8),
              sliver: SliverToBoxAdapter(child: _Tabs()),
            ),
            if (!group.isEmpty)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                sliver: SliverToBoxAdapter(child: _GroupChip(group: group)),
              ),
            ...switch (tab) {
              LibraryTab.songs || LibraryTab.favorites => [
                _TrackSlivers(showAlbum: showAlbum),
              ],
              LibraryTab.albums => [const _GroupGrid(albums: true)],
              LibraryTab.artists => [const _GroupGrid(albums: false)],
              LibraryTab.folders => [const _FolderList()],
            },
            const SliverToBoxAdapter(child: SizedBox(height: 28)),
          ],
        );
      },
    );
  }
}

class _LibraryHeader extends ConsumerWidget {
  const _LibraryHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(trackCountProvider).value ?? 0;
    final scan = ref.watch(libraryScanProvider);
    final scanner = ref.read(libraryScanProvider.notifier);
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      alignment: WrapAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(S.libraryTitle, style: NexaText.display),
            const SizedBox(height: 4),
            Text('$count ${S.tracksSuffix}', style: NexaText.bodySecondary),
          ],
        ),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            NexaPillButton(
              label: S.addFolder,
              icon: Icons.create_new_folder_outlined,
              height: 42,
              onPressed: scan.running ? null : scanner.addFolder,
              disabledReason: S.scanning,
            ),
            NexaPillButton(
              label: S.addFiles,
              icon: Icons.audio_file_outlined,
              variant: PillVariant.secondary,
              height: 42,
              onPressed: scan.running ? null : scanner.addFiles,
              disabledReason: S.scanning,
            ),
            NexaTooltip(
              message: scan.running ? null : S.rescanTooltip,
              child: NexaPillButton(
                label: S.rescan,
                icon: Icons.refresh_rounded,
                variant: PillVariant.secondary,
                height: 42,
                onPressed: scan.running ? null : scanner.rescan,
                disabledReason: S.scanning,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ScanStatus extends ConsumerWidget {
  const _ScanStatus();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scan = ref.watch(libraryScanProvider);
    if (scan.running) {
      final progress = scan.total == 0 ? null : scan.done / scan.total;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            scan.total == 0
                ? '${scan.label}...'
                : '${scan.label}: ${scan.done} / ${scan.total}',
            style: NexaText.caption,
          ),
          const SizedBox(height: 6),
          LinearProgressIndicator(
            value: progress,
            minHeight: 3,
            color: NexaColors.accent,
            backgroundColor: NexaColors.border,
          ),
        ],
      );
    }
    final report = scan.lastReport;
    if (report == null) {
      return const SizedBox.shrink();
    }
    return _ReportLine(report: report);
  }
}

class _ReportLine extends StatelessWidget {
  const _ReportLine({required this.report});

  final ScanReport report;

  @override
  Widget build(BuildContext context) {
    final parts = [
      '${report.added} added',
      if (report.updated > 0) '${report.updated} updated',
      '${report.unchanged} unchanged',
      if (report.restored > 0) '${report.restored} found again',
      if (report.missing > 0) '${report.missing} missing',
      if (report.skipped > 0) '${report.skipped} skipped',
    ];
    final problems = report.problems;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: NexaColors.panel,
        borderRadius: BorderRadius.circular(NexaRadius.md),
        border: Border.all(color: NexaColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            problems.isEmpty
                ? Icons.check_circle_outline_rounded
                : Icons.info_outline_rounded,
            size: 18,
            color: problems.isEmpty ? NexaColors.accent : NexaColors.coral,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(parts.join(' - '), style: NexaText.caption),
                for (final p in problems.take(4))
                  Text(
                    p,
                    style: NexaText.caption.copyWith(color: NexaColors.coral),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                if (problems.length > 4)
                  Text(
                    '+ ${problems.length - 4} more',
                    style: NexaText.caption,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Tabs extends ConsumerWidget {
  const _Tabs();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(libraryTabProvider);
    final favorites = ref.watch(favoriteCountProvider).value ?? 0;
    const labels = {
      LibraryTab.songs: S.tabSongs,
      LibraryTab.favorites: S.tabFavorites,
      LibraryTab.albums: S.tabAlbums,
      LibraryTab.artists: S.tabArtists,
      LibraryTab.folders: S.tabFolders,
    };
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final entry in labels.entries)
          ChoiceChip(
            label: Text(
              entry.key == LibraryTab.favorites && favorites > 0
                  ? '${entry.value} ($favorites)'
                  : entry.value,
            ),
            selected: tab == entry.key,
            showCheckmark: false,
            selectedColor: NexaColors.navSelected,
            backgroundColor: NexaColors.panel,
            side: const BorderSide(color: NexaColors.border),
            labelStyle: NexaText.body.copyWith(
              fontSize: 13.5,
              color: tab == entry.key
                  ? NexaColors.textPrimary
                  : NexaColors.textSecondary,
            ),
            onSelected: (_) {
              ref.read(libraryTabProvider.notifier).set(entry.key);
              if (entry.key != LibraryTab.songs) {
                ref.read(groupFilterProvider.notifier).set(const GroupFilter());
              }
            },
          ),
      ],
    );
  }
}

class _GroupChip extends ConsumerWidget {
  const _GroupChip({required this.group});

  final GroupFilter group;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final label = group.album ?? group.artist ?? '';
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.only(left: 14, right: 4),
        decoration: BoxDecoration(
          color: NexaColors.panelRaised,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: NexaColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: NexaText.body.copyWith(fontSize: 13.5)),
            NexaIconButton(
              icon: Icons.close_rounded,
              label: S.showAll,
              iconSize: 16,
              boxSize: 30,
              onPressed: () => ref
                  .read(groupFilterProvider.notifier)
                  .set(const GroupFilter()),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrackSlivers extends ConsumerWidget {
  const _TrackSlivers({required this.showAlbum});

  final bool showAlbum;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tracks = ref.watch(libraryTracksProvider);
    final total = ref.watch(trackCountProvider).value ?? 0;
    final tab = ref.watch(libraryTabProvider);
    final query = ref.watch(libraryQueryProvider);
    return tracks.when(
      loading: () => const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
      error: (e, _) => SliverToBoxAdapter(
        child: Text('$e', style: NexaText.bodySecondary),
      ),
      data: (list) {
        if (list.isEmpty) {
          final message = total == 0
              ? null
              : tab == LibraryTab.favorites && query.isEmpty
              ? S.favoritesEmpty
              : '${S.noResults} "$query"';
          return SliverToBoxAdapter(
            child: message == null
                ? const _EmptyLibrary()
                : Padding(
                    padding: const EdgeInsets.all(32),
                    child: Center(
                      child: Text(message, style: NexaText.bodySecondary),
                    ),
                  ),
          );
        }
        return SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          sliver: SliverMainAxisGroup(
            slivers: [
              SliverToBoxAdapter(child: TrackListHeader(showAlbum: showAlbum)),
              SliverTrackList(tracks: list, showAlbum: showAlbum),
            ],
          ),
        );
      },
    );
  }
}

class _EmptyLibrary extends ConsumerWidget {
  const _EmptyLibrary();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: NexaPanel(
        padding: const EdgeInsets.all(32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.library_music_outlined,
              color: NexaColors.accent,
              size: 36,
            ),
            const SizedBox(height: 16),
            const Text(S.libraryEmptyTitle, style: NexaText.h2),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: const Text(
                S.libraryEmptyBody,
                style: NexaText.bodySecondary,
              ),
            ),
            const SizedBox(height: 20),
            NexaPillButton(
              label: S.addFolder,
              icon: Icons.create_new_folder_outlined,
              height: 44,
              onPressed: ref.read(libraryScanProvider.notifier).addFolder,
            ),
          ],
        ),
      ),
    );
  }
}

class _GroupGrid extends ConsumerWidget {
  const _GroupGrid({required this.albums});

  final bool albums;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groups = ref.watch(albums ? albumsProvider : artistsProvider);
    final list = groups.value ?? const <LibraryGroup>[];
    if (list.isEmpty) {
      return const SliverToBoxAdapter(child: _EmptyLibrary());
    }
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 200,
          mainAxisExtent: 250,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        delegate: SliverChildBuilderDelegate((context, i) {
          final g = list[i];
          return NexaTappable(
            onTap: () {
              ref
                  .read(groupFilterProvider.notifier)
                  .set(
                    albums
                        ? GroupFilter(album: g.name)
                        : GroupFilter(artist: g.name),
                  );
              ref.read(libraryTabProvider.notifier).set(LibraryTab.songs);
            },
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LayoutBuilder(
                    builder: (context, box) => TrackArt(
                      artworkPath: g.artworkPath,
                      seed: g.name.hashCode,
                      size: box.maxWidth,
                      radius: albums ? NexaRadius.md : box.maxWidth / 2,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    g.name,
                    style: NexaText.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    albums
                        ? '${g.subtitle} - ${g.trackCount} ${S.tracksSuffix}'
                        : '${g.trackCount} ${S.tracksSuffix}',
                    style: NexaText.caption,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          );
        }, childCount: list.length),
      ),
    );
  }
}

class _FolderList extends ConsumerWidget {
  const _FolderList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final folders = ref.watch(foldersProvider).value ?? const <FolderRow>[];
    if (folders.isEmpty) {
      return const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(S.foldersEmpty, style: NexaText.bodySecondary),
        ),
      );
    }
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      sliver: SliverList.builder(
        itemCount: folders.length,
        itemBuilder: (context, i) {
          final f = folders[i];
          final scanned = f.lastScanAt;
          return Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: NexaColors.divider)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.folder_outlined,
                  color: NexaColors.textSecondary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        f.path,
                        style: NexaText.body,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (scanned != null)
                        Text(
                          'Last scan ${_formatDate(scanned)}',
                          style: NexaText.caption,
                        ),
                    ],
                  ),
                ),
                NexaIconButton(
                  icon: Icons.remove_circle_outline_rounded,
                  label: S.removeFolder,
                  color: NexaColors.textSecondary,
                  onPressed: () async {
                    final ok = await confirmAction(
                      context,
                      title: S.removeFolder,
                      body: '${f.path}\n\n${S.removeFolderBody}',
                      action: S.remove,
                    );
                    if (ok) {
                      await ref
                          .read(libraryRepositoryProvider)
                          .removeFolder(f.id);
                    }
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

String _formatDate(DateTime d) {
  String two(int v) => v.toString().padLeft(2, '0');
  return '${d.year}-${two(d.month)}-${two(d.day)} ${two(d.hour)}:${two(d.minute)}';
}
