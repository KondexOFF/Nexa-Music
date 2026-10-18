import 'package:flutter/material.dart';

import '../../app/strings.dart';
import '../../app/theme/nexa_theme.dart';
import '../../app/theme/tokens.dart';
import '../../demo/demo_data.dart';
import '../../ui/cover_art.dart';
import '../../ui/nexa_widgets.dart';

/// "For Your Moment" collection cards (DEMO).
class MomentSection extends StatelessWidget {
  const MomentSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          title: S.forYourMoment,
          subtitle: S.forYourMomentSubtitle,
          badges: [StatusBadge.demo()],
          trailing: NexaTextLink(
            label: S.seeAll,
            disabledReason: S.soonBrowse,
          ),
        ),
        const SizedBox(height: NexaSpace.md),
        LayoutBuilder(
          builder: (context, constraints) {
            final count =
                (constraints.maxWidth / 190).floor().clamp(2, 4).toInt();
            final items = DemoData.moments.take(count).toList();
            return Row(
              children: [
                for (var i = 0; i < items.length; i++) ...[
                  if (i > 0) const SizedBox(width: NexaSpace.md),
                  Expanded(child: _MomentCard(item: items[i])),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}

class _MomentCard extends StatelessWidget {
  const _MomentCard({required this.item});

  final DemoCollection item;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1.56,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(NexaRadius.md),
        child: Stack(
          fit: StackFit.expand,
          children: [
            CoverArt(spec: item.art, radius: 0),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x00000000), Color(0xCC0B0C12)],
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
                    item.title,
                    style: NexaText.title.copyWith(fontSize: 16),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.subtitle,
                    style: NexaText.caption.copyWith(
                      color: const Color(0xFFD5D3DF),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Positioned(
              right: 12,
              bottom: 12,
              child: _CardPlayButton(),
            ),
          ],
        ),
      ),
    );
  }
}

class _CardPlayButton extends StatelessWidget {
  const _CardPlayButton();

  @override
  Widget build(BuildContext context) {
    return NexaTooltip(
      message: '${S.play} - ${S.soonLibrary}',
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0x66101218),
          border: Border.all(color: const Color(0x38FFFFFF)),
        ),
        child: const Icon(
          Icons.play_arrow_rounded,
          size: 20,
          color: Color(0x73FFFFFF),
        ),
      ),
    );
  }
}

/// "Recently Played" table with working tabs over DEMO rows.
class RecentlyPlayedSection extends StatefulWidget {
  const RecentlyPlayedSection({super.key});

  @override
  State<RecentlyPlayedSection> createState() => _RecentlyPlayedSectionState();
}

class _RecentlyPlayedSectionState extends State<RecentlyPlayedSection> {
  RecentTab _tab = RecentTab.all;

  static const Map<RecentTab, String> _labels = {
    RecentTab.all: S.tabAll,
    RecentTab.tracks: S.tabTracks,
    RecentTab.artists: S.tabArtists,
    RecentTab.albums: S.tabAlbums,
    RecentTab.playlists: S.tabPlaylists,
  };

  static List<String> _headers(RecentTab tab) => switch (tab) {
    RecentTab.all || RecentTab.tracks => const [
      S.colTitle,
      S.colArtist,
      S.colAlbum,
    ],
    RecentTab.artists => const [S.colArtist, S.colGenre, S.colTopTrack],
    RecentTab.albums => const [S.colAlbum, S.colArtist, S.colYear],
    RecentTab.playlists => const [S.colPlaylist, S.colMood, S.colTracks],
  };

  @override
  Widget build(BuildContext context) {
    final rows = DemoData.recentFor(_tab);
    final showTrackColumns =
        _tab == RecentTab.all || _tab == RecentTab.tracks;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(S.recentlyPlayed, style: NexaText.h2),
            const SizedBox(width: NexaSpace.lg),
            Flexible(
              child: SingleChildScrollView(
                key: const PageStorageKey('recent-tabs'),
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final tab in RecentTab.values)
                      _TabLabel(
                        label: _labels[tab]!,
                        selected: tab == _tab,
                        onTap: () => setState(() => _tab = tab),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: NexaSpace.sm),
            const StatusBadge.demo(),
            const SizedBox(width: NexaSpace.sm),
            const NexaTextLink(label: S.seeAll, disabledReason: S.soonBrowse),
          ],
        ),
        const SizedBox(height: NexaSpace.sm),
        const Divider(height: 1, color: NexaColors.divider),
        AnimatedSwitcher(
          duration: NexaMotion.normal,
          switchInCurve: NexaMotion.curve,
          child: Column(
            key: ValueKey(_tab),
            children: [
              _TableHeader(
                headers: _headers(_tab),
                showTrackColumns: showTrackColumns,
              ),
              for (var i = 0; i < rows.length; i++)
                _TableRow(
                  index: i + 1,
                  row: rows[i],
                  showTrackColumns: showTrackColumns,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TabLabel extends StatelessWidget {
  const _TabLabel({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return NexaTappable(
      onTap: onTap,
      borderRadius: BorderRadius.circular(NexaRadius.sm),
      semanticLabel: label,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedDefaultTextStyle(
              duration: NexaMotion.fast,
              style: NexaText.body.copyWith(
                fontSize: 15,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected
                    ? NexaColors.accent
                    : NexaColors.textSecondary,
              ),
              child: Text(label),
            ),
            const SizedBox(height: 6),
            AnimatedContainer(
              duration: NexaMotion.normal,
              curve: NexaMotion.curve,
              height: 2,
              width: selected ? 32 : 0,
              decoration: BoxDecoration(
                color: NexaColors.accent,
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

const double _indexWidth = 32;
const double _coverWidth = 48;
const double _timeWidth = 64;
const double _iconWidth = 44;

class _TableHeader extends StatelessWidget {
  const _TableHeader({required this.headers, required this.showTrackColumns});

  final List<String> headers;
  final bool showTrackColumns;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: Row(
        children: [
          const SizedBox(
            width: _indexWidth,
            child: Text('#', style: NexaText.tableHeader),
          ),
          const SizedBox(width: _coverWidth),
          Expanded(
            flex: 3,
            child: Text(headers[0], style: NexaText.tableHeader),
          ),
          Expanded(
            flex: 2,
            child: Text(headers[1], style: NexaText.tableHeader),
          ),
          Expanded(
            flex: 2,
            child: Text(headers[2], style: NexaText.tableHeader),
          ),
          if (showTrackColumns) ...[
            const SizedBox(
              width: _timeWidth,
              child: Icon(
                Icons.schedule_rounded,
                size: 16,
                color: NexaColors.textTertiary,
              ),
            ),
            const SizedBox(
              width: _iconWidth,
              child: Icon(
                Icons.favorite_border_rounded,
                size: 16,
                color: NexaColors.textTertiary,
              ),
            ),
          ],
          const SizedBox(width: _iconWidth),
        ],
      ),
    );
  }
}

class _TableRow extends StatelessWidget {
  const _TableRow({
    required this.index,
    required this.row,
    required this.showTrackColumns,
  });

  final int index;
  final DemoRecentRow row;
  final bool showTrackColumns;

  @override
  Widget build(BuildContext context) {
    const cell = NexaText.body;
    return Container(
      height: 44,
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: NexaColors.divider)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: _indexWidth,
            child: Text('$index', style: NexaText.caption),
          ),
          SizedBox(
            width: _coverWidth,
            child: Align(
              alignment: Alignment.centerLeft,
              child: CoverArt(spec: row.art, size: 32, radius: 6),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              row.title,
              style: cell.copyWith(fontWeight: FontWeight.w600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              row.second,
              style: NexaText.bodySecondary,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              row.third,
              style: NexaText.bodySecondary,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (showTrackColumns) ...[
            SizedBox(
              width: _timeWidth,
              child: Center(
                child: Text(
                  row.duration == null ? '' : formatClock(row.duration!),
                  style: NexaText.caption,
                ),
              ),
            ),
            SizedBox(
              width: _iconWidth,
              child: NexaTooltip(
                message: S.soonFavorites,
                child: const Icon(
                  Icons.favorite_border_rounded,
                  size: 18,
                  color: NexaColors.textDisabled,
                ),
              ),
            ),
          ],
          const SizedBox(
            width: _iconWidth,
            child: NexaIconButton(
              icon: Icons.more_horiz_rounded,
              label: S.moreActions,
              disabledReason: S.soonLibrary,
              boxSize: 32,
              iconSize: 18,
            ),
          ),
        ],
      ),
    );
  }
}
