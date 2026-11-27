import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/navigation.dart';
import '../../app/strings.dart';
import '../../app/theme/nexa_theme.dart';
import '../../app/theme/tokens.dart';
import '../../core/models/track.dart';
import '../../ui/time_format.dart' show formatClock;
import '../../ui/nexa_widgets.dart';
import '../discover/source_attribution.dart' show SourceBadge;
import '../library/library_providers.dart';
import '../library/track_art.dart';
import '../nexa_dna/dna_providers.dart';
import '../nexa_dna/taste_repository.dart';
import '../player/player_controller.dart';
import '../player/player_controls.dart' show FavoriteButton;
import '../soundcloud/soundcloud_player_controller.dart';
import '../youtube/youtube_watch_page.dart';

/// Continues [entry] from where it was left: a YouTube video in YouTube's
/// own player, a song in NEXA's player.
Future<void> continueEntry(WidgetRef ref, HistoryEntry entry) async {
  final t = entry.track;
  if (t.source == TrackSource.soundcloud) {
    await ref
        .read(soundcloudPlayerProvider.notifier)
        .playLink(
          t.sourceTrackId,
          title: t.title,
          user: t.artist,
          artwork: t.artworkPath,
          start: entry.listened,
        );
    return;
  }
  if (t.source.isExternal) {
    await openYouTubeWatch(
      ref,
      videoId: t.sourceTrackId,
      title: t.title,
      channel: t.artist,
      start: entry.listened,
    );
    return;
  }
  final player = ref.read(playerProvider.notifier);
  await player.playTracks([t]);
  await player.seek(entry.listened);
}

/// Home (E2.7b): "Continue listening" (long tracks and videos left in the
/// middle) and "Recently played" from the local listening history - only
/// what the history settings allow; made-for-kids videos never appear.
class RecentlyPlayedSection extends ConsumerWidget {
  const RecentlyPlayedSection({super.key});

  static const int _shown = 10;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(recentHistoryProvider).value ?? const [];
    final settings = ref.watch(dnaSettingsProvider);
    final resume = [for (final e in entries) if (e.canContinue) e];
    final recent = entries.take(_shown).toList();
    final currentId = ref.watch(playerProvider.select((p) => p.current?.id));

    void play(int i) {
      final t = recent[i];
      if (t.track.source == TrackSource.youtube) {
        unawaited(
          openYouTubeWatch(
            ref,
            videoId: t.track.sourceTrackId,
            title: t.track.title,
            channel: t.track.artist,
          ),
        );
        return;
      }
      // The list plays on from the chosen song (videos in their turn in
      // YouTube's player, E2.8).
      unawaited(
        ref
            .read(playerProvider.notifier)
            .playTracks([for (final e in recent) e.track], start: i),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (resume.isNotEmpty) ...[
          const Text(S.continueListening, style: NexaText.h2),
          const SizedBox(height: NexaSpace.sm),
          SizedBox(
            height: 92,
            child: ListView.separated(
              key: const PageStorageKey('continue-listening'),
              scrollDirection: Axis.horizontal,
              itemCount: resume.length,
              separatorBuilder: (_, _) => const SizedBox(width: NexaSpace.sm),
              itemBuilder: (context, i) => _ContinueCard(
                key: ValueKey('continue-${resume[i].track.id}'),
                entry: resume[i],
                onTap: () => unawaited(continueEntry(ref, resume[i])),
              ),
            ),
          ),
          const SizedBox(height: NexaSpace.xl - 4),
        ],
        const Text(S.recentlyPlayed, style: NexaText.h2),
        const SizedBox(height: NexaSpace.sm),
        const Divider(height: 1, color: NexaColors.divider),
        if (recent.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: NexaSpace.md),
            child: Wrap(
              spacing: 12,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  settings.recordsHistory ? S.recentEmpty : S.recentOff,
                  key: const ValueKey('recent-empty'),
                  style: NexaText.bodySecondary,
                ),
                if (!settings.recordsHistory)
                  NexaTextLink(
                    label: S.openSettings,
                    onTap: () => ref
                        .read(navigationProvider.notifier)
                        .go(NexaDestination.settings),
                  ),
              ],
            ),
          )
        else
          for (var i = 0; i < recent.length; i++)
            _RecentRow(
              key: ValueKey('recent-${recent[i].track.id}'),
              index: i + 1,
              entry: recent[i],
              isCurrent: recent[i].track.id == currentId,
              onPlay: () => play(i),
            ),
      ],
    );
  }
}

class _ContinueCard extends ConsumerWidget {
  const _ContinueCard({super.key, required this.entry, required this.onTap});

  final HistoryEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = savedOrSelf(ref, entry.track);
    final total = entry.duration!;
    final progress = entry.listened.inMilliseconds / total.inMilliseconds;
    return SizedBox(
      width: 300,
      child: NexaPanel(
        padding: const EdgeInsets.all(10),
        child: NexaTappable(
          onTap: onTap,
          semanticLabel:
              '${S.continueFrom(formatClock(entry.listened))} ${t.title}',
          borderRadius: BorderRadius.circular(NexaRadius.sm),
          child: Row(
            children: [
              TrackArt(artworkPath: t.artworkPath, seed: t.id, size: 64),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      t.title,
                      style: NexaText.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      S.continueFrom(formatClock(entry.listened)),
                      style: NexaText.caption,
                      maxLines: 1,
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: progress.clamp(0.0, 1.0),
                        minHeight: 3,
                        color: NexaColors.accent,
                        backgroundColor: NexaColors.divider,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecentRow extends ConsumerWidget {
  const _RecentRow({
    super.key,
    required this.index,
    required this.entry,
    required this.isCurrent,
    required this.onPlay,
  });

  final int index;
  final HistoryEntry entry;
  final bool isCurrent;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Track t = entry.track.isOnline
        ? savedOrSelf(ref, entry.track)
        : ref.watch(trackProvider(entry.track.id)).value ?? entry.track;
    final duration = entry.duration ?? t.duration;
    return Container(
      height: 52,
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: NexaColors.divider)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 32,
            child: isCurrent
                ? const Icon(
                    Icons.graphic_eq_rounded,
                    size: 18,
                    color: NexaColors.accent,
                  )
                : Text('$index', style: NexaText.caption),
          ),
          Expanded(
            child: NexaTappable(
              onTap: onPlay,
              semanticLabel: '${S.play} ${t.title}',
              borderRadius: BorderRadius.circular(NexaRadius.sm),
              child: Row(
                children: [
                  Opacity(
                    opacity: t.available ? 1 : 0.45,
                    child: TrackArt(
                      artworkPath: t.artworkPath,
                      seed: t.id,
                      size: 36,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 3,
                    child: Text(
                      t.title,
                      style: NexaText.body.copyWith(
                        fontWeight: FontWeight.w600,
                        color: !t.available
                            ? NexaColors.textTertiary
                            : isCurrent
                            ? NexaColors.accent
                            : NexaColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      t.artist,
                      style: NexaText.bodySecondary,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (t.isOnline) ...[
                    SourceBadge(source: t.source),
                    const SizedBox(width: 8),
                  ],
                  SizedBox(
                    width: 96,
                    child: Text(
                      S.playedWhen(entry.playedAt, DateTime.now()),
                      style: NexaText.caption,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  SizedBox(
                    width: 56,
                    child: Text(
                      duration == null ? '' : formatClock(duration),
                      style: NexaText.caption.copyWith(fontFeatures: NexaText.numbers),
                    ),
                  ),
                ],
              ),
            ),
          ),
          FavoriteButton(track: t, iconSize: 18, boxSize: 36),
        ],
      ),
    );
  }
}
