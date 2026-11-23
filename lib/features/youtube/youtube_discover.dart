import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/navigation.dart';
import '../../app/strings.dart';
import '../../app/theme/nexa_theme.dart';
import '../../app/theme/tokens.dart';
import '../../ui/time_format.dart' show formatClock;
import '../../integrations/youtube/youtube_data_api.dart';
import '../../integrations/youtube/youtube_link.dart';
import '../../ui/nexa_widgets.dart';
import '../discover/catalog_providers.dart';
import '../library/track_list.dart' show addTracksToPlaylist;
import '../player/player_controller.dart';
import '../player/player_controls.dart' show FavoriteButton;
import 'youtube_settings.dart';
import 'youtube_track.dart';
import 'youtube_watch_page.dart';

/// The YouTube search on the Discover page (E2.3).
@immutable
class YouTubeSearchState {
  const YouTubeSearchState({
    this.query = '',
    this.loading = false,
    this.results = const [],
    this.error,
  });

  final String query;
  final bool loading;
  final List<YouTubeVideo> results;
  final YouTubeApiException? error;
}

/// Searches only when asked (Enter / Search) - never while typing - and
/// keeps the results of recent queries in memory for the session, so going
/// back to a query costs no quota. Nothing is written to disk.
class YouTubeSearchController extends Notifier<YouTubeSearchState> {
  final Map<String, List<YouTubeVideo>> _recent = {};
  static const int _keep = 20;
  int _generation = 0;

  @override
  YouTubeSearchState build() {
    // A new key: earlier answers (e.g. "bad key") no longer apply.
    ref.listen(youtubeSettingsProvider.select((s) => s.apiKey), (_, _) {
      _recent.clear();
      state = const YouTubeSearchState();
    });
    return const YouTubeSearchState();
  }

  /// Number of Data API searches sent in this session (for tests).
  int requests = 0;

  Future<void> search(String query) async {
    final q = query.trim();
    if (q.isEmpty) {
      state = const YouTubeSearchState();
      return;
    }
    final key = q.toLowerCase();
    final cached = _recent[key];
    if (cached != null) {
      state = YouTubeSearchState(query: q, results: cached);
      return;
    }
    final generation = ++_generation;
    state = YouTubeSearchState(query: q, loading: true);
    try {
      requests++;
      final found = await ref.read(youtubeDataApiProvider).search(q);
      if (!ref.mounted || generation != _generation) {
        return;
      }
      _recent[key] = found;
      if (_recent.length > _keep) {
        _recent.remove(_recent.keys.first);
      }
      state = YouTubeSearchState(query: q, results: found);
    } on YouTubeApiException catch (e) {
      if (ref.mounted && generation == _generation) {
        state = YouTubeSearchState(query: q, error: e);
      }
    }
  }
}

final youtubeSearchProvider =
    NotifierProvider<YouTubeSearchController, YouTubeSearchState>(
      YouTubeSearchController.new,
    );

/// Discover -> YouTube: paste a link (no key needed) and, with the owner's
/// Data API key, search YouTube. A section of its own, marked "YouTube";
/// never mixed with the Audius / Jamendo results.
class YouTubeDiscoverSection extends ConsumerStatefulWidget {
  const YouTubeDiscoverSection({super.key});

  @override
  ConsumerState<YouTubeDiscoverSection> createState() =>
      _YouTubeDiscoverSectionState();
}

class _YouTubeDiscoverSectionState
    extends ConsumerState<YouTubeDiscoverSection> {
  final TextEditingController _link = TextEditingController();
  late final TextEditingController _query;
  String? _linkProblem;

  @override
  void initState() {
    super.initState();
    _query = TextEditingController(text: ref.read(youtubeSearchProvider).query);
  }

  @override
  void dispose() {
    _link.dispose();
    _query.dispose();
    super.dispose();
  }

  void _watchLink() {
    final id = youtubeVideoId(_link.text);
    setState(() => _linkProblem = id == null ? S.ytBadLink : null);
    if (id != null) {
      unawaited(openYouTubeWatch(ref, videoId: id));
    }
  }

  void _search() =>
      unawaited(ref.read(youtubeSearchProvider.notifier).search(_query.text));

  void _openSettings() =>
      ref.read(navigationProvider.notifier).go(NexaDestination.settings);

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(youtubeSettingsProvider);
    if (!settings.enabled) {
      return Column(
        key: const ValueKey('yt-discover-off'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: const Text(S.ytDiscoverOff, style: NexaText.bodySecondary),
          ),
          const SizedBox(height: 12),
          NexaPillButton(
            label: S.openSettings,
            icon: Icons.settings_outlined,
            variant: PillVariant.secondary,
            height: 42,
            onPressed: _openSettings,
          ),
        ],
      );
    }
    final search = ref.watch(youtubeSearchProvider);
    return Column(
      key: const ValueKey('yt-discover'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: const Text(S.ytDiscoverInfo, style: NexaText.bodySecondary),
        ),
        const SizedBox(height: 14),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextField(
                key: const ValueKey('yt-link'),
                controller: _link,
                onSubmitted: (_) => _watchLink(),
                decoration: InputDecoration(
                  hintText: S.ytLinkHint,
                  errorText: _linkProblem,
                  prefixIcon: const Icon(Icons.link_rounded),
                ),
              ),
            ),
            const SizedBox(width: 12),
            NexaPillButton(
              key: const ValueKey('yt-link-watch'),
              label: S.ytWatch,
              icon: Icons.play_arrow_rounded,
              height: 44,
              onPressed: _watchLink,
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (!settings.hasKey)
          Wrap(
            key: const ValueKey('yt-no-key'),
            spacing: 12,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text(S.ytNoKey, style: NexaText.bodySecondary),
              NexaTextLink(label: S.openSettings, onTap: _openSettings),
            ],
          )
        else ...[
          Row(
            children: [
              Expanded(
                child: TextField(
                  key: const ValueKey('yt-query'),
                  controller: _query,
                  onSubmitted: (_) => _search(),
                  textInputAction: TextInputAction.search,
                  decoration: const InputDecoration(
                    hintText: S.ytSearchHint,
                    prefixIcon: Icon(Icons.search_rounded),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              NexaPillButton(
                key: const ValueKey('yt-search'),
                label: S.search,
                icon: Icons.travel_explore_rounded,
                height: 44,
                onPressed: search.loading ? null : _search,
                disabledReason: S.searching,
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(S.ytQuotaNote, style: NexaText.caption),
          const SizedBox(height: 12),
          if (search.loading)
            const Text(S.searching, style: NexaText.caption)
          else if (search.error != null)
            Wrap(
              spacing: 12,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  youtubeApiErrorText(search.error!.error),
                  key: const ValueKey('yt-search-error'),
                  style: NexaText.bodySecondary.copyWith(
                    color: NexaColors.coral,
                  ),
                ),
                if (search.error!.error == YouTubeApiError.badKey ||
                    search.error!.error == YouTubeApiError.apiDisabled)
                  NexaTextLink(label: S.openSettings, onTap: _openSettings),
              ],
            )
          else if (search.query.isNotEmpty && search.results.isEmpty)
            const Text(S.noCatalogResults, style: NexaText.caption),
          for (final v in search.results)
            YouTubeResultRow(key: ValueKey('yt-result-${v.id}'), video: v),
        ],
      ],
    );
  }
}

/// One search result: thumbnail, title, channel, length, the YouTube mark,
/// "Watch in NEXA" and "Open on YouTube".
class YouTubeResultRow extends ConsumerWidget {
  const YouTubeResultRow({super.key, required this.video});

  final YouTubeVideo video;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final open = ref.read(linkOpenerProvider);
    final details = [
      video.channel,
      if (video.live)
        S.ytLive
      else if (video.duration != null)
        formatClock(video.duration!),
    ].where((s) => s.isNotEmpty).join('  ·  ');
    final track = youtubeTrack(
      videoId: video.id,
      title: video.title,
      channel: video.channel,
      thumbnail: video.thumbnailUrl,
    );
    void watch() => unawaited(
      openYouTubeWatch(
        ref,
        videoId: video.id,
        title: video.title,
        channel: video.channel,
      ),
    );
    return SizedBox(
      height: 76,
      child: NexaTappable(
        onTap: watch,
        semanticLabel: '${S.ytWatchInNexa} ${video.title}',
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(NexaRadius.sm),
                child: SizedBox(
                  width: 96,
                  height: 54,
                  child: video.thumbnailUrl == null
                      ? const ColoredBox(color: Colors.black)
                      : Image.network(
                          video.thumbnailUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) =>
                              const ColoredBox(color: Colors.black),
                        ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      video.title,
                      style: NexaText.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      details,
                      style: NexaText.caption,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              const StatusBadge(label: 'YouTube', color: NexaColors.coral),
              const SizedBox(width: 8),
              NexaIconButton(
                icon: Icons.open_in_new_rounded,
                label: S.ytOpenOnYouTube,
                color: NexaColors.textSecondary,
                onPressed: () => open(youtubeWatchUrl(video.id)),
              ),
              // Bookmark: a like or a playlist saves the video (E2.7).
              FavoriteButton(track: track, iconSize: 19),
              NexaIconButton(
                icon: Icons.playlist_add_rounded,
                label: '${S.addToPlaylist}...',
                color: NexaColors.textSecondary,
                onPressed: () => addTracksToPlaylist(context, ref, [track]),
              ),
              NexaIconButton(
                key: ValueKey('yt-queue-${video.id}'),
                icon: Icons.queue_music_rounded,
                label: S.addToQueue,
                color: NexaColors.textSecondary,
                onPressed: () {
                  ref.read(playerProvider.notifier).addToQueue([track]);
                  ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                    const SnackBar(
                      content: Text(S.addedToQueue),
                      behavior: SnackBarBehavior.floating,
                      width: 420,
                    ),
                  );
                },
              ),
              NexaIconButton(
                icon: Icons.smart_display_outlined,
                label: S.ytWatchInNexa,
                onPressed: watch,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
