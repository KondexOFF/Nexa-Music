import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/library/library_dialogs.dart';
import '../../features/library/library_providers.dart';
import '../../features/library/track_art.dart';
import '../../ui/brand_mark.dart';
import '../../ui/nexa_widgets.dart';
import '../navigation.dart';
import '../strings.dart';
import '../theme/nexa_theme.dart';
import '../theme/tokens.dart';

class _NavEntry {
  const _NavEntry(this.destination, this.label, this.icon);

  final NexaDestination destination;
  final String label;
  final IconData icon;
}

const List<_NavEntry> _mainEntries = [
  _NavEntry(NexaDestination.home, S.navHome, Icons.home_rounded),
  _NavEntry(NexaDestination.wave, S.navWave, Icons.graphic_eq_rounded),
  _NavEntry(NexaDestination.discover, S.navDiscover, Icons.explore_outlined),
  _NavEntry(
    NexaDestination.library,
    S.navLibrary,
    Icons.library_music_outlined,
  ),
];

const _NavEntry _settingsEntry = _NavEntry(
  NexaDestination.settings,
  S.navSettings,
  Icons.settings_outlined,
);

/// Left navigation. [compact] renders an icon rail for narrow windows.
class NexaSidebar extends ConsumerWidget {
  const NexaSidebar({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(navigationProvider).current;
    void go(NexaDestination d) => ref.read(navigationProvider.notifier).go(d);

    return AnimatedContainer(
      duration: NexaMotion.normal,
      curve: NexaMotion.curve,
      width: compact ? NexaSizes.sidebarCompact : NexaSizes.sidebar,
      decoration: const BoxDecoration(
        color: NexaColors.sidebar,
        border: Border(right: BorderSide(color: NexaColors.divider)),
      ),
      child: ClipRect(
        child: LayoutBuilder(
          builder: (context, box) {
            // While the width animates, show labels only once there is room.
            final rail = compact || box.maxWidth < NexaSizes.sidebar - 2;
            return _SidebarContent(rail: rail, current: current, onGo: go);
          },
        ),
      ),
    );
  }
}

class _SidebarContent extends StatelessWidget {
  const _SidebarContent({
    required this.rail,
    required this.current,
    required this.onGo,
  });

  final bool rail;
  final NexaDestination current;
  final ValueChanged<NexaDestination> onGo;

  @override
  Widget build(BuildContext context) {
    final inset = rail ? 12.0 : 16.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: NexaSizes.topBar + 8,
          child: rail ? const _LogoMark() : const _Logo(),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: inset),
          child: Column(
            children: [
              for (final entry in _mainEntries)
                _NavItem(
                  entry: entry,
                  selected: current == entry.destination,
                  compact: rail,
                  onTap: () => onGo(entry.destination),
                ),
            ],
          ),
        ),
        if (rail) const Spacer() else const Expanded(child: _PlaylistsSection()),
        Padding(
          padding: EdgeInsets.fromLTRB(inset, 8, inset, 12),
          child: _NavItem(
            entry: _settingsEntry,
            selected: current == NexaDestination.settings,
            compact: rail,
            onTap: () => onGo(NexaDestination.settings),
          ),
        ),
      ],
    );
  }
}

class _Logo extends StatelessWidget {
  const _Logo();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.only(left: 26),
    child: Align(
      alignment: Alignment.centerLeft,
      child: NexaryveWordmark(markSize: 30, fontSize: 17),
    ),
  );
}

class _LogoMark extends StatelessWidget {
  const _LogoMark();

  @override
  Widget build(BuildContext context) =>
      const Center(child: NexaryveMark(size: 34));
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.entry,
    required this.selected,
    required this.compact,
    required this.onTap,
  });

  final _NavEntry entry;
  final bool selected;
  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? NexaColors.textPrimary : NexaColors.textSecondary;
    final item = AnimatedContainer(
      duration: NexaMotion.normal,
      curve: NexaMotion.curve,
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(NexaRadius.md),
        gradient: selected
            ? const LinearGradient(
                colors: [Color(0xFF3A3170), NexaColors.navSelected],
              )
            : null,
      ),
      child: NexaTappable(
        onTap: onTap,
        semanticLabel: entry.label,
        child: SizedBox(
          height: 48,
          child: Row(
            mainAxisAlignment: compact
                ? MainAxisAlignment.center
                : MainAxisAlignment.start,
            children: [
              if (!compact) const SizedBox(width: 16),
              Icon(
                entry.icon,
                size: 22,
                color: selected ? NexaColors.accent : color,
              ),
              if (!compact) ...[
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    entry.label,
                    style: NexaText.body.copyWith(
                      fontSize: 15.5,
                      color: color,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
    if (compact) {
      return NexaTooltip(message: entry.label, child: item);
    }
    return item;
  }
}

class _PlaylistsSection extends ConsumerWidget {
  const _PlaylistsSection();

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final name = await askPlaylistName(context);
    if (name == null) {
      return;
    }
    final id = await ref.read(libraryRepositoryProvider).createPlaylist(name);
    ref
        .read(navigationProvider.notifier)
        .go(NexaDestination.playlist, playlistId: id);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playlists = ref.watch(playlistsProvider).value ?? const [];
    final favorites = ref.watch(favoriteCountProvider).value ?? 0;
    final nav = ref.watch(navigationProvider);
    final libraryTab = ref.watch(libraryTabProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 30),
          child: Divider(height: 24, color: NexaColors.divider),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(30, 0, 18, 6),
          child: Row(
            children: [
              const Text(S.navPlaylists, style: NexaText.bodySecondary),
              const Spacer(),
              NexaIconButton(
                icon: Icons.add_rounded,
                label: S.newPlaylist,
                boxSize: 30,
                onPressed: () => _create(context, ref),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            key: const PageStorageKey('sidebar-playlists'),
            padding: const EdgeInsets.fromLTRB(16, 4, 12, 8),
            children: [
              _PlaylistRow(
                name: S.likedSongs,
                count: favorites,
                liked: true,
                selected:
                    nav.current == NexaDestination.library &&
                    libraryTab == LibraryTab.favorites,
                onTap: () {
                  ref.read(libraryTabProvider.notifier).set(LibraryTab.favorites);
                  ref
                      .read(navigationProvider.notifier)
                      .go(NexaDestination.library);
                },
              ),
              for (final pl in playlists)
                _PlaylistRow(
                  name: pl.name,
                  count: pl.trackCount,
                  seed: pl.id * 7919,
                  selected:
                      nav.current == NexaDestination.playlist &&
                      nav.playlistId == pl.id,
                  onTap: () => ref
                      .read(navigationProvider.notifier)
                      .go(NexaDestination.playlist, playlistId: pl.id),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PlaylistRow extends StatelessWidget {
  const _PlaylistRow({
    required this.name,
    required this.count,
    required this.onTap,
    this.selected = false,
    this.liked = false,
    this.seed = 0,
  });

  final String name;
  final int count;
  final VoidCallback onTap;
  final bool selected;
  final bool liked;
  final int seed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: selected ? NexaColors.navSelected : Colors.transparent,
        borderRadius: BorderRadius.circular(NexaRadius.md),
        child: NexaTappable(
          onTap: onTap,
          semanticLabel: name,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              children: [
                if (liked)
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(NexaRadius.sm),
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFFC4B4FF), Color(0xFF7D5CFF)],
                      ),
                    ),
                    child: const Icon(
                      Icons.favorite_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  )
                else
                  TrackArt(
                    artworkPath: null,
                    seed: seed,
                    size: 42,
                    radius: NexaRadius.sm,
                  ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: NexaText.body.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text('$count ${S.tracksSuffix}', style: NexaText.caption),
                    ],
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
