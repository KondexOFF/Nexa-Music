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

/// SoundCloud's own search page in the browser (an official hand-off).
/// The words are only used when they are not a link.
String soundCloudSearchUrl(String words) {
  final q = words.trim();
  if (q.isEmpty || q.contains('soundcloud.com') || q.contains('on.soundcloud')) {
    return 'https://soundcloud.com/search';
  }
  return Uri.https('soundcloud.com', '/search', {'q': q}).toString();
}

/// SoundCloud on the Discover page (E3, CR-002): a pasted track link plays
/// in SoundCloud's official widget. There is no search inside NEXA: the API
/// needs paid credentials (Artist Pro, 2026) and its terms conflict with
/// NEXA's unified queue and cache (reports/FEATURE_COMPLETE_REPORT.md).
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
    setState(() {
      _busy = true;
      _problem = null;
    });
    final parsed = await expandSoundCloudLink(
      _link.text,
      ref.read(httpClientProvider),
    );
    if (!mounted) {
      return;
    }
    // A track, a playlist (set) or a profile: all play in the widget.
    final (String? url, String kind) = switch (parsed) {
      SoundCloudTrackLink(:final url) => (url, S.scKindTrack),
      SoundCloudSet(:final url) => (url, S.scKindSet),
      SoundCloudProfile(:final url) => (url, S.scKindProfile),
      SoundCloudShortLink() => (null, S.scShortLink),
      SoundCloudNotALink() => (null, S.scNotALink),
    };
    if (url == null) {
      setState(() {
        _busy = false;
        _problem = kind;
        _track = null;
      });
      return;
    }
    final meta = await ref.read(soundcloudOEmbedProvider).fetch(url);
    if (!mounted) {
      return;
    }
    setState(() {
      _busy = false;
      _track = soundcloudTrack(
        url: url,
        title: meta?.title,
        user: meta?.author,
        artwork: meta?.thumbnail,
        album: kind,
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
        const SizedBox(height: 6),
        NexaTextLink(
          key: const ValueKey('sc-search-site'),
          label: S.scSearchOnSite,
          onTap: () => unawaited(
            ref.read(linkOpenerProvider)(soundCloudSearchUrl(_link.text)),
          ),
        ),
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
