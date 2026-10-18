import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../demo/demo_data.dart';
import '../../ui/cover_art.dart';
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
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(left: 30),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            S.brandNexa,
            style: TextStyle(
              fontFamily: NexaText.family,
              fontSize: 24,
              fontWeight: FontWeight.w800,
              letterSpacing: 7,
              color: NexaColors.textPrimary,
            ),
          ),
          SizedBox(width: 4),
          Padding(
            padding: EdgeInsets.only(top: 3),
            child: Text(
              S.brandMusic,
              style: TextStyle(
                fontFamily: NexaText.family,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                letterSpacing: 4,
                color: NexaColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LogoMark extends StatelessWidget {
  const _LogoMark();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'N',
        style: TextStyle(
          fontFamily: NexaText.family,
          fontSize: 26,
          fontWeight: FontWeight.w800,
          color: NexaColors.textPrimary,
        ),
      ),
    );
  }
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

class _PlaylistsSection extends StatelessWidget {
  const _PlaylistsSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 30),
          child: Divider(height: 24, color: NexaColors.divider),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(30, 0, 18, 6),
          child: Row(
            children: [
              Text(S.navPlaylists, style: NexaText.bodySecondary),
              SizedBox(width: 10),
              StatusBadge.demo(),
              Spacer(),
              NexaIconButton(
                icon: Icons.add_rounded,
                label: S.newPlaylist,
                disabledReason: S.soonPlaylists,
                boxSize: 30,
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            key: const PageStorageKey('sidebar-playlists'),
            padding: const EdgeInsets.fromLTRB(24, 4, 16, 8),
            itemCount: DemoData.playlists.length,
            itemBuilder: (context, i) =>
                _PlaylistRow(playlist: DemoData.playlists[i]),
          ),
        ),
      ],
    );
  }
}

class _PlaylistRow extends StatelessWidget {
  const _PlaylistRow({required this.playlist});

  final DemoPlaylist playlist;

  @override
  Widget build(BuildContext context) {
    final art = playlist.art;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          if (art == null)
            Container(
              width: 46,
              height: 46,
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
                size: 22,
              ),
            )
          else
            CoverArt(spec: art, size: 46, radius: NexaRadius.sm),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  playlist.name,
                  style: NexaText.body.copyWith(fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${playlist.trackCount} ${S.tracksSuffix}',
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
