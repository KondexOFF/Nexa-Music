import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/strings.dart';
import '../../app/theme/nexa_theme.dart';
import '../../app/theme/tokens.dart';
import '../../ui/time_format.dart' show formatClock;
import '../../ui/nexa_widgets.dart';
import '../discover/source_attribution.dart' show SourceIcon;
import '../library/track_art.dart';
import 'player_controller.dart';

/// "Up Next": the songs after the current one in the play queue.
class UpNextCard extends ConsumerWidget {
  const UpNextCard({super.key, this.maxItems = 5, this.framed = true});

  final int maxItems;

  /// False renders the list without the panel frame (Queue tab).
  final bool framed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final player = ref.watch(playerProvider);
    final controller = ref.read(playerProvider.notifier);
    final upNext = player.upNext;
    final items = upNext.take(maxItems).toList();
    final firstIndex = player.cursor + 1;
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (framed) ...[
          SectionHeader(
            title: S.upNext,
            style: NexaText.h3,
            trailing: NexaTextLink(
              label: S.clear,
              showArrow: false,
              onTap: upNext.isEmpty ? null : controller.clearUpNext,
              disabledReason: S.queueEmpty,
            ),
          ),
          const SizedBox(height: NexaSpace.sm),
        ],
        if (player.waitingForUser) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 10),
            child: Row(
              children: [
                const Expanded(
                  child: Text(S.queueWaiting, style: NexaText.caption),
                ),
                const SizedBox(width: 8),
                NexaPillButton(
                  key: const ValueKey('queue-continue'),
                  label: S.queueContinue,
                  icon: Icons.play_arrow_rounded,
                  height: 36,
                  onPressed: controller.togglePlay,
                ),
              ],
            ),
          ),
        ],
        if (items.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            child: Text(S.queueEmpty, style: NexaText.bodySecondary),
          ),
        for (var i = 0; i < items.length; i++)
          UpNextRow(
            index: i + 1,
            entry: items[i],
            highlighted: i == 0,
            skipped: player.skipped[items[i].uid],
            onPlay: () => controller.jumpTo(firstIndex + i),
            onRemove: () => controller.removeFromQueue(items[i].uid),
          ),
        if (upNext.length > items.length)
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 4),
            child: Text(
              '+ ${upNext.length - items.length} ${S.tracksSuffix}',
              style: NexaText.caption,
            ),
          ),
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
    required this.entry,
    required this.onPlay,
    required this.onRemove,
    this.highlighted = false,
    this.skipped,
  });

  final int index;
  final QueueEntry entry;
  final VoidCallback onPlay;
  final VoidCallback onRemove;
  final bool highlighted;

  /// Why this entry was skipped (E2.8: never silently).
  final String? skipped;

  @override
  Widget build(BuildContext context) {
    final track = entry.track;
    final duration = track.duration;
    return Container(
      height: 58,
      margin: const EdgeInsets.only(bottom: 2),
      decoration: BoxDecoration(
        color: highlighted ? NexaColors.panelRaised : null,
        borderRadius: BorderRadius.circular(NexaRadius.sm + 2),
      ),
      child: Row(
        children: [
          Expanded(
            child: NexaTappable(
              onTap: onPlay,
              semanticLabel: '${S.play} ${track.title}',
              borderRadius: BorderRadius.circular(NexaRadius.sm + 2),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
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
                    TrackArt(
                      artworkPath: track.artworkPath,
                      seed: track.id,
                      size: 42,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            track.title,
                            style: NexaText.body.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            skipped == null
                                ? track.artist
                                : '${S.skipped}: $skipped',
                            style: NexaText.caption.copyWith(
                              color: skipped == null ? null : NexaColors.coral,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    if (track.isOnline) ...[
                      const SizedBox(width: 8),
                      SourceIcon(source: track.source),
                    ],
                    const SizedBox(width: 8),
                    Text(
                      duration == null ? '' : formatClock(duration),
                      style: NexaText.caption,
                    ),
                  ],
                ),
              ),
            ),
          ),
          NexaIconButton(
            icon: Icons.close_rounded,
            label: S.removeFromQueue,
            boxSize: 30,
            iconSize: 16,
            color: NexaColors.textSecondary,
            onPressed: onRemove,
          ),
        ],
      ),
    );
  }
}
