import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/strings.dart';
import '../../app/theme/tokens.dart';
import '../../core/models/track.dart';
import '../../ui/nexa_widgets.dart';
import '../library/library_providers.dart';
import '../nexa_dna/dna_providers.dart';
import 'wave_controller.dart';

/// Thumbs-down for a library track (live state). A dislike is the strongest
/// negative NEXA DNA signal: the song is never suggested by NEXA Wave, and a
/// Wave song that is playing is skipped. For a catalog song (E1) it is
/// "Not for me": hidden from the Wave until NEXA closes, nothing saved.
class DislikeButton extends ConsumerWidget {
  const DislikeButton({
    super.key,
    required this.track,
    this.iconSize = 20,
    this.boxSize = 36,
  });

  final Track? track;
  final double iconSize;
  final double boxSize;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = track;
    if (t == null) {
      return NexaIconButton(
        icon: Icons.thumb_down_off_alt_rounded,
        label: S.dislike,
        disabledReason: S.nothingToPlay,
        iconSize: iconSize,
        boxSize: boxSize,
      );
    }
    if (t.isOnline) {
      // E1: catalog songs are not saved, so "Not for me" only hides the
      // song from the Wave for this session.
      return NexaIconButton(
        icon: Icons.thumb_down_off_alt_rounded,
        label: '${S.hideOnline} - ${S.hideOnlineInfo}',
        color: NexaColors.textSecondary,
        iconSize: iconSize,
        boxSize: boxSize,
        onPressed: () => ref.read(waveProvider.notifier).dislike(t),
      );
    }
    final live = ref.watch(trackProvider(t.id)).value ?? t;
    return NexaIconButton(
      icon: live.disliked
          ? Icons.thumb_down_alt_rounded
          : Icons.thumb_down_off_alt_rounded,
      label: live.disliked ? S.undislike : '${S.dislike} - ${S.dislikeInfo}',
      color: live.disliked ? NexaColors.coral : NexaColors.textSecondary,
      iconSize: iconSize,
      boxSize: boxSize,
      onPressed: () => live.disliked
          ? ref.read(tasteRepositoryProvider).setDisliked(t.id, false)
          : ref.read(waveProvider.notifier).dislike(live),
    );
  }
}
