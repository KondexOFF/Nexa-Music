import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/strings.dart';
import '../../app/theme/nexa_theme.dart';
import '../../app/theme/tokens.dart';
import '../../core/models/track.dart';
import '../../integrations/soundcloud/soundcloud_link.dart';
import '../../ui/nexa_widgets.dart';
import '../discover/catalog_providers.dart';
import '../discover/source_attribution.dart' show SourceBadge;
import '../library/track_art.dart';
import '../library/track_list.dart' show addTracksToPlaylist;
import '../player/player_controller.dart';
import '../player/player_controls.dart' show FavoriteButton;
import 'soundcloud_player_controller.dart';

/// SoundCloud on the Discover page (E3, CR-002): a pasted track link plays
/// in SoundCloud's official widget. There is no SoundCloud search in this
/// version (the API needs permitted access, CR-002).
class SoundCloudDiscoverSection extends ConsumerStatefulWidget {
  const SoundCloudDiscoverSection({super.key});

  @override
  ConsumerState<SoundCloudDiscoverSection> createState() =>
      _SoundCloudDiscoverSectionState();
}

class _SoundCloudDiscoverSectionState
    extends ConsumerState<SoundCloudDiscoverSection> {
  final TextEditingController _link = TextEditingController();
  String? _problem;
  Track? _track;
  bool _busy = false;

  @override
  void dispose() {
    _link.dispose();
    super.dispose();
  }

  Future<void> _resolve() async {
    final parsed = SoundCloudLink.parse(_link.text);
    final problem = switch (parsed) {
      SoundCloudTrackLink() => null,
      SoundCloudSet() => S.scSetLink,
      SoundCloudProfile() => S.scProfileLink,
      SoundCloudShortLink() => S.scShortLink,
      SoundCloudNotALink() => S.scNotALink,
    };
    if (parsed is! SoundCloudTrackLink) {
      setState(() {
        _problem = problem;
        _track = null;
      });
      return;
    }
    setState(() {
      _busy = true;
      _problem = null;
    });
    final meta = await ref.read(soundcloudOEmbedProvider).fetch(parsed.url);
    if (!mounted) {
      return;
    }
    setState(() {
      _busy = false;
      _track = soundcloudTrack(
        url: parsed.url,
        title: meta?.title,
        user: meta?.author,
        artwork: meta?.thumbnail,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final track = _track;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: const Text(S.scIntro, style: NexaText.bodySecondary),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                key: const ValueKey('sc-link'),
                controller: _link,
                onSubmitted: (_) => unawaited(_resolve()),
                decoration: const InputDecoration(
                  hintText: S.scLinkHint,
                  prefixIcon: Icon(Icons.link_rounded),
                ),
              ),
            ),
            const SizedBox(width: 12),
            NexaPillButton(
              key: const ValueKey('sc-open'),
              label: S.scOpenLink,
              icon: Icons.graphic_eq_rounded,
              height: 44,
              onPressed: _busy ? null : () => unawaited(_resolve()),
              disabledReason: S.scResolving,
            ),
          ],
        ),
        if (_problem != null) ...[
          const SizedBox(height: 10),
          Text(
            _problem!,
            key: const ValueKey('sc-problem'),
            style: NexaText.body.copyWith(color: NexaColors.coral),
          ),
        ],
        if (track != null) ...[
          const SizedBox(height: 14),
          SoundCloudTrackRow(track: track),
        ],
        const SizedBox(height: 18),
        const Text(S.scLimits, style: NexaText.caption),
      ],
    );
  }
}

/// A SoundCloud track: artwork, title, uploader, the SoundCloud mark, Play,
/// add to queue / playlist, like and "Open on SoundCloud".
class SoundCloudTrackRow extends ConsumerWidget {
  const SoundCloudTrackRow({super.key, required this.track});

  final Track track;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final player = ref.read(playerProvider.notifier);
    return SizedBox(
      height: 72,
      child: Row(
        children: [
          TrackArt(artworkPath: track.artworkPath, seed: track.id, size: 56),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  track.title,
                  key: const ValueKey('sc-title'),
                  style: NexaText.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  track.artist,
                  style: NexaText.caption,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SourceBadge(source: TrackSource.soundcloud),
          const SizedBox(width: 8),
          FavoriteButton(track: track, iconSize: 19),
          NexaIconButton(
            icon: Icons.playlist_add_rounded,
            label: '${S.addToPlaylist}...',
            color: NexaColors.textSecondary,
            onPressed: () => addTracksToPlaylist(context, ref, [track]),
          ),
          NexaIconButton(
            key: const ValueKey('sc-queue'),
            icon: Icons.queue_music_rounded,
            label: S.addToQueue,
            color: NexaColors.textSecondary,
            onPressed: () => player.addToQueue([track]),
          ),
          NexaIconButton(
            icon: Icons.open_in_new_rounded,
            label: S.scOpenOnSoundCloud,
            color: NexaColors.textSecondary,
            onPressed: () => ref.read(linkOpenerProvider)(track.path),
          ),
          NexaIconButton(
            key: const ValueKey('sc-play'),
            icon: Icons.play_arrow_rounded,
            label: S.play,
            onPressed: () => player.playTracks([track]),
          ),
        ],
      ),
    );
  }
}
