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
