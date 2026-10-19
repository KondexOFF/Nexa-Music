import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/navigation.dart';
import '../../app/strings.dart';
import '../../app/theme/nexa_theme.dart';
import '../../app/theme/tokens.dart';
import '../../core/models/track.dart';
import '../../demo/demo_data.dart' show formatClock;
import '../../integrations/music_source.dart';
import '../../ui/nexa_widgets.dart';
import '../library/track_art.dart';
import '../player/player_controller.dart';
import 'catalog_providers.dart';
import 'discover_controller.dart';
import 'source_attribution.dart';

/// Discover: one search over the permitted online catalogs (Phase 6).
class DiscoverPage extends ConsumerStatefulWidget {
  const DiscoverPage({super.key});

  @override
  ConsumerState<DiscoverPage> createState() => _DiscoverPageState();
}

class _DiscoverPageState extends ConsumerState<DiscoverPage> {
  late final TextEditingController _query = TextEditingController(
    text: ref.read(discoverProvider).query,
  );

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  void _search() => ref.read(discoverProvider.notifier).search(_query.text);

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(discoverProvider);
    final settings = ref.watch(catalogSettingsProvider);
    final sources = [TrackSource.audius, TrackSource.jamendo];
    return CustomScrollView(
      key: const PageStorageKey('page-discover'),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
          sliver: SliverList.list(
            children: [
              const Text(S.discoverOverline, style: NexaText.overline),
              const SizedBox(height: 16),
              Text(S.discoverTitle, style: NexaText.h2.copyWith(fontSize: 26)),
              const SizedBox(height: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 680),
                child: const Text(
                  S.discoverIntro,
                  style: NexaText.bodySecondary,
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _query,
                      onSubmitted: (_) => _search(),
                      textInputAction: TextInputAction.search,
                      decoration: const InputDecoration(
                        hintText: S.discoverSearchHint,
                        prefixIcon: Icon(Icons.search_rounded),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  NexaPillButton(
                    label: S.search,
                    icon: Icons.travel_explore_rounded,
                    height: 44,
                    onPressed: _search,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _FilterChip(
                    label: S.allSources,
                    selected: state.filter == null,
                    onTap: () {
                      ref.read(discoverProvider.notifier).setFilter(null);
                      _search();
                    },
                  ),
                  for (final s in sources)
                    _FilterChip(
                      label: s.label,
                      selected: state.filter == s,
                      onTap: () {
                        ref.read(discoverProvider.notifier).setFilter(s);
                        _search();
                      },
                    ),
                ],
              ),
              const SizedBox(height: 20),
              if (state.query.isEmpty)
                const Text(S.discoverEmpty, style: NexaText.bodySecondary),
            ],
          ),
        ),
        for (final s in sources)
          if (state.query.isNotEmpty &&
              (state.filter == null || state.filter == s))
            ..._sourceSection(
              s,
              state.results[s],
              disabled: s == TrackSource.audius && !settings.audiusEnabled,
            ),
        const SliverToBoxAdapter(child: SizedBox(height: 28)),
      ],
    );
  }

  List<Widget> _sourceSection(
    TrackSource source,
    SourceResults? results, {
    required bool disabled,
  }) {
    final tracks = results?.tracks ?? const <Track>[];
    final playable = [
      for (final t in tracks)
        if (t.available) t,
    ];
    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
        sliver: SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  SourceBadge(source: source),
                  const SizedBox(width: 10),
                  Text(source.label, style: NexaText.h3),
                  if (results?.loading ?? false) ...[
                    const SizedBox(width: 12),
                    const Text(S.searching, style: NexaText.caption),
                  ],
                ],
              ),
              const SizedBox(height: 6),
              if (disabled)
                const Text(S.catalogDisabled, style: NexaText.caption)
              else if (results?.error != null)
                _CatalogError(source: source, error: results!.error!)
              else if (results != null && !results.loading && tracks.isEmpty)
                const Text(S.noCatalogResults, style: NexaText.caption),
            ],
          ),
        ),
      ),
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        sliver: SliverList.builder(
          itemCount: tracks.length,
          itemBuilder: (context, i) {
            final t = tracks[i];
            return _ResultRow(
              key: ValueKey('discover-${t.id}'),
              track: t,
              onPlay: t.available
                  ? () => ref
                        .read(playerProvider.notifier)
                        .playTracks(playable, start: playable.indexOf(t))
                  : null,
            );
          },
        ),
      ),
    ];
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: selected ? NexaColors.accentSoft : const Color(0x0AFFFFFF),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: selected ? NexaColors.accent : NexaColors.border,
        ),
      ),
      child: NexaTappable(
        onTap: onTap,
        semanticLabel: label,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Text(
            label,
            style: NexaText.body.copyWith(
              fontSize: 13.5,
              color: selected ? NexaColors.textPrimary : NexaColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _CatalogError extends ConsumerWidget {
  const _CatalogError({required this.source, required this.error});

  final TrackSource source;
  final CatalogException error;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = switch (error.kind) {
      CatalogErrorKind.offline => S.catalogOffline,
      CatalogErrorKind.rateLimited => S.catalogRateLimited,
      CatalogErrorKind.notConfigured => switch (source) {
        TrackSource.jamendo =>
          error.detail == null ? S.jamendoNotConfigured : S.jamendoBadKey,
        _ => S.audiusNotConfigured,
      },
      CatalogErrorKind.provider =>
        '${S.catalogProviderError}${error.detail == null ? '' : ' (${error.detail})'}.',
    };
    return Wrap(
      spacing: 12,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(text, style: NexaText.bodySecondary),
        if (error.kind == CatalogErrorKind.notConfigured)
          NexaTextLink(
            label: S.openSettings,
            onTap: () => ref
                .read(navigationProvider.notifier)
                .go(NexaDestination.settings),
          ),
      ],
    );
  }
}

class _ResultRow extends ConsumerWidget {
  const _ResultRow({super.key, required this.track, required this.onPlay});

  final Track track;
  final VoidCallback? onPlay;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final open = ref.read(linkOpenerProvider);
    final page = track.pageUrl;
    final duration = track.duration;
    final mode = track.available
        ? S.streamHere
        : '${S.notPlayableHere}: ${track.problem ?? ''}';
    final details = [
      track.artist,
      if (track.license != null) track.license!,
      if (duration != null) formatClock(duration),
    ].join('  ·  ');
    return SizedBox(
      height: 68,
      child: NexaTappable(
        onTap: onPlay,
        semanticLabel: '${S.play} ${track.title}',
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              Opacity(
                opacity: track.available ? 1 : 0.45,
                child: TrackArt(
                  artworkPath: track.artworkPath,
                  seed: track.id,
                  size: 46,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      track.title,
                      style: NexaText.title.copyWith(
                        color: track.available
                            ? NexaColors.textPrimary
                            : NexaColors.textTertiary,
                      ),
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
              Expanded(
                child: Row(
                  children: [
                    SourceBadge(source: track.source),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        mode,
                        style: NexaText.caption.copyWith(
                          color: track.available
                              ? NexaColors.textSecondary
                              : NexaColors.coral,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              if (page != null)
                NexaIconButton(
                  icon: Icons.open_in_new_rounded,
                  label: '${S.openPage} ${S.onSource(track.source.label)}',
                  color: NexaColors.textSecondary,
                  onPressed: () => open(page),
                ),
              NexaIconButton(
                icon: Icons.play_arrow_rounded,
                label: S.play,
                onPressed: onPlay,
                disabledReason: S.notPlayableHere,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
