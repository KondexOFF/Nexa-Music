import 'package:flutter/material.dart';

import '../../app/strings.dart';
import '../../app/theme/nexa_theme.dart';
import '../../app/theme/tokens.dart';
import '../../demo/demo_data.dart';
import '../../ui/cover_art.dart';
import '../../ui/nexa_widgets.dart';
import '../player/up_next_card.dart';

/// Right panel on Home and the placeholder pages: Up Next, My Taste,
/// Discover More (all DEMO).
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
  Widget build(BuildContext context) {
    return NexaPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionHeader(
            title: S.myTaste,
            style: NexaText.h3,
            trailing: StatusBadge.phase(
              S.phase5,
              tooltip: S.myTasteTooltip,
            ),
          ),
          const SizedBox(height: 4),
          const Text(S.myTasteNote, style: NexaText.caption),
          const SizedBox(height: NexaSpace.sm),
          for (final item in DemoData.taste) _TasteRow(item: item),
        ],
      ),
    );
  }
}

class _TasteRow extends StatelessWidget {
  const _TasteRow({required this.item});

  final DemoTaste item;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(item.icon, size: 18, color: item.color),
          const SizedBox(width: 10),
          SizedBox(
            width: 88,
            child: Text(
              item.label,
              style: NexaText.body.copyWith(fontSize: 13),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: item.value),
              duration: const Duration(milliseconds: 900),
              curve: NexaMotion.curve,
              builder: (context, value, _) => _Bar(value: value, color: item.color),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 38,
            child: Text(
              '${(item.value * 100).round()}%',
              textAlign: TextAlign.right,
              style: NexaText.caption,
            ),
          ),
        ],
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.value, required this.color});

  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 6,
      decoration: BoxDecoration(
        color: const Color(0x14FFFFFF),
        borderRadius: BorderRadius.circular(3),
      ),
      alignment: Alignment.centerLeft,
      child: FractionallySizedBox(
        widthFactor: value.clamp(0.0, 1.0).toDouble(),
        child: Container(
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
      ),
    );
  }
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
