import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/strings.dart';
import '../../app/theme/nexa_theme.dart';
import '../../app/theme/tokens.dart';
import '../../app/navigation.dart';
import '../../core/models/track.dart';
import '../../ui/nexa_widgets.dart';
import '../discover/discover_page.dart' show DiscoverSection, discoverSectionProvider;
import '../discover/source_attribution.dart' show sourceColor, sourceIcon;
import '../nexa_wave/wave_page.dart' show MyTastePanel;
import '../player/up_next_card.dart';

/// Right panel on Home and the other pages: Up Next, My Taste, Sources.
class HomeSidePanel extends StatelessWidget {
  const HomeSidePanel({super.key});

  @override
  Widget build(BuildContext context) {
    return const SingleChildScrollView(
      key: PageStorageKey('panel-home-scroll'),
      padding: EdgeInsets.fromLTRB(0, 0, NexaSpace.md, NexaSpace.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          UpNextCard(),
          SizedBox(height: NexaSpace.sm),
          MyTasteCard(),
          SizedBox(height: NexaSpace.sm),
          SourcesCard(),
        ],
      ),
    );
  }
}

class MyTasteCard extends StatelessWidget {
  const MyTasteCard({super.key});

  @override
  Widget build(BuildContext context) => const MyTastePanel(compact: true);
}

/// Where music comes from (E5, replaces the DEMO "Discover More"): each
/// source opens its part of Discover.
class SourcesCard extends ConsumerWidget {
  const SourcesCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void open(DiscoverSection section) {
      ref.read(discoverSectionProvider.notifier).set(section);
      ref.read(navigationProvider.notifier).go(NexaDestination.discover);
    }

    const sources = [
      (TrackSource.audius, DiscoverSection.catalogs),
      (TrackSource.jamendo, DiscoverSection.catalogs),
      (TrackSource.youtube, DiscoverSection.youtube),
      (TrackSource.soundcloud, DiscoverSection.soundcloud),
    ];
    return NexaPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionHeader(title: S.sourcesTitle, style: NexaText.h3),
          const SizedBox(height: 4),
          const Text(S.sourcesBody, style: NexaText.caption),
          const SizedBox(height: NexaSpace.sm),
          for (var i = 0; i < sources.length; i++) ...[
            if (i > 0) const SizedBox(height: 6),
            _SourceTile(
              source: sources[i].$1,
              onTap: () => open(sources[i].$2),
            ),
          ],
        ],
      ),
    );
  }
}

class _SourceTile extends StatelessWidget {
  const _SourceTile({required this.source, required this.onTap});

  final TrackSource source;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = sourceColor(source);
    return Material(
      color: NexaColors.panelRaised,
      borderRadius: BorderRadius.circular(NexaRadius.md),
      child: NexaTappable(
        key: ValueKey('source-${source.name}'),
        onTap: onTap,
        semanticLabel: '${S.navDiscover}: ${source.label}',
        borderRadius: BorderRadius.circular(NexaRadius.md),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Icon(sourceIcon(source), size: 17, color: color),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  source.label,
                  key: ValueKey('source-label-${source.name}'),
                  style: NexaText.body.copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: NexaColors.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
