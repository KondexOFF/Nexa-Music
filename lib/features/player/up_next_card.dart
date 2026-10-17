import 'package:flutter/material.dart';

import '../../app/strings.dart';
import '../../app/theme/nexa_theme.dart';
import '../../app/theme/tokens.dart';
import '../../demo/demo_data.dart';
import '../../ui/cover_art.dart';
import '../../ui/nexa_widgets.dart';

/// "Up Next" queue card (DEMO rows; queue logic arrives in Phase 3).
class UpNextCard extends StatelessWidget {
  const UpNextCard({super.key, this.maxItems = 5, this.framed = true});

  final int maxItems;

  /// False renders the list without the panel frame (Queue tab).
  final bool framed;

  @override
  Widget build(BuildContext context) {
    final items = DemoData.upNext.take(maxItems).toList();
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (framed) ...[
          const SectionHeader(
            title: S.upNext,
            style: NexaText.h3,
            badges: [StatusBadge.demo()],
            trailing: NexaTextLink(
              label: S.clear,
              disabledReason: S.soonQueue,
              showArrow: false,
            ),
          ),
          const SizedBox(height: NexaSpace.sm),
        ],
        for (var i = 0; i < items.length; i++)
          UpNextRow(index: i + 1, track: items[i], highlighted: i == 0),
      ],
    );
    if (!framed) {
      return content;
    }
    return NexaPanel(
      padding: const EdgeInsets.fromLTRB(16, 16, 12, 10),
      child: content,
    );
  }
}

class UpNextRow extends StatelessWidget {
  const UpNextRow({
    super.key,
    required this.index,
    required this.track,
    this.highlighted = false,
  });

  final int index;
  final DemoTrack track;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 58,
      margin: const EdgeInsets.only(bottom: 2),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: highlighted ? NexaColors.panelRaised : null,
        borderRadius: BorderRadius.circular(NexaRadius.sm + 2),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 18,
            child: Text(
              '$index',
              style: NexaText.caption.copyWith(
                color: highlighted
                    ? NexaColors.accent
                    : NexaColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 8),
          CoverArt(spec: track.art, size: 42, radius: 6),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  track.title,
                  style: NexaText.body.copyWith(fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  track.artist,
                  style: NexaText.caption,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(formatClock(track.duration), style: NexaText.caption),
          const SizedBox(width: 4),
          const NexaIconButton(
            icon: Icons.more_horiz_rounded,
            label: S.moreActions,
            disabledReason: S.soonQueue,
            boxSize: 30,
            iconSize: 18,
          ),
        ],
      ),
    );
  }
}
