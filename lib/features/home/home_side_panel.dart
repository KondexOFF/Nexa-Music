import 'package:flutter/material.dart';

import '../../app/strings.dart';
import '../../app/theme/nexa_theme.dart';
import '../../app/theme/tokens.dart';
import '../../demo/demo_data.dart';
import '../../ui/cover_art.dart';
import '../../ui/nexa_widgets.dart';
import '../nexa_wave/wave_page.dart' show MyTastePanel;
import '../player/up_next_card.dart';

/// Right panel on Home and the placeholder pages: Up Next, My Taste,
/// Discover More (DEMO).
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
          DiscoverMoreCard(),
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

class DiscoverMoreCard extends StatelessWidget {
  const DiscoverMoreCard({super.key});

  @override
  Widget build(BuildContext context) {
    return NexaPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionHeader(
            title: S.discoverMore,
            style: NexaText.h3,
            badges: [StatusBadge.demo()],
            trailing: NexaTextLink(
              label: S.seeAll,
              disabledReason: S.soonBrowse,
            ),
          ),
          const SizedBox(height: NexaSpace.sm),
          Row(
            children: [
              for (var i = 0; i < DemoData.discover.length; i++) ...[
                if (i > 0) const SizedBox(width: NexaSpace.sm),
                Expanded(child: _DiscoverTile(item: DemoData.discover[i])),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _DiscoverTile extends StatelessWidget {
  const _DiscoverTile({required this.item});

  final DemoCollection item;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1.05,
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
                  colors: [Color(0x00000000), Color(0xD90B0C12)],
                  stops: [0.35, 1],
                ),
              ),
            ),
            Positioned(
              left: 10,
              right: 10,
              bottom: 10,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    item.title,
                    style: NexaText.body.copyWith(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    item.subtitle,
                    style: NexaText.caption.copyWith(fontSize: 11.5),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
