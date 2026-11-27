import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/strings.dart';
import '../../app/theme/nexa_theme.dart';
import '../../app/theme/tokens.dart';
import '../../core/models/listening.dart';
import '../../core/models/track.dart';
import '../../ui/isolated_slider.dart';
import '../../ui/nexa_widgets.dart';
import '../discover/source_attribution.dart';
import '../library/library_providers.dart';
import '../library/track_art.dart';
import '../nexa_dna/dna_picker.dart';
import '../nexa_dna/dna_providers.dart';
import '../player/player_controller.dart';
import '../player/player_controls.dart';
import 'dislike_button.dart';
import 'wave_controller.dart';

/// NEXA Wave page: start the Wave, tune Familiar <-> Discovery, private
/// session, NEXA DNA and the next picks with "why this song".
class WavePage extends ConsumerStatefulWidget {
  const WavePage({super.key});

  @override
  ConsumerState<WavePage> createState() => _WavePageState();
}

class _WavePageState extends ConsumerState<WavePage> {
  @override
  void initState() {
    super.initState();
    unawaited(Future.microtask(() {
      if (mounted) {
        return ref.read(waveProvider.notifier).refresh();
      }
    }));
  }

  @override
  Widget build(BuildContext context) {
    final wave = ref.watch(waveProvider);
    final settings = ref.watch(dnaSettingsProvider);
    final trackCount = ref.watch(trackCountProvider).value ?? 0;
    final player = ref.watch(playerProvider);
    final playingWave =
        player.context == PlayContext.wave && player.current != null;
    final controller = ref.read(waveProvider.notifier);

    // While the Wave plays, show the real queue; otherwise a preview.
    final List<(Track, String?, bool)> rows = playingWave
        ? [
            for (final e in player.upNext)
              (e.track, controller.reasonFor(e.track.id), false),
          ]
        : [for (final i in wave.items) (i.track, i.reason, i.fresh)];

    return CustomScrollView(
      key: const PageStorageKey('page-wave'),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
          sliver: SliverList.list(
            children: [
              const Text(S.waveOverlineFull, style: NexaText.overline),
              const SizedBox(height: 16),
              _WaveHeader(
                playingWave: playingWave,
                hasMusic: trackCount > 0,
                privateSession: settings.privateSession,
              ),
              const SizedBox(height: NexaSpace.sm),
              _TuningPanel(
                settings: settings,
                onlineNote: wave.onlineNote,
                onlineReady: wave.onlineReady,
              ),
              if (settings.loaded && !settings.onboarded && trackCount > 0) ...[
                const SizedBox(height: NexaSpace.sm),
                const _DnaSetupCard(),
              ],
              const SizedBox(height: 24),
              SectionHeader(
                title: S.waveNextUp,
                style: NexaText.h3,
                trailing: NexaTextLink(
                  label: S.refreshWave,
                  showArrow: false,
                  onTap: playingWave || trackCount == 0
                      ? null
                      : () => ref.read(waveProvider.notifier).refresh(),
                  disabledReason: playingWave ? S.wavePlaying : null,
                ),
              ),
              const SizedBox(height: 8),
              if (trackCount == 0)
                const _Message(text: S.waveEmptyLibrary)
              else if (rows.isEmpty && wave.message != null)
                _Message(text: wave.message!)
              else if (wave.message != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    wave.message!,
                    key: const ValueKey('wave-note'),
                    style: NexaText.caption.copyWith(color: NexaColors.sky),
                  ),
                ),
            ],
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
          sliver: SliverList.builder(
            itemCount: trackCount == 0 ? 0 : rows.length,
            itemBuilder: (context, i) => _WaveRow(
              key: ValueKey('wave-${rows[i].$1.id}-$i'),
              track: rows[i].$1,
              reason: rows[i].$2,
              fresh: rows[i].$3,
              onPlay: () => _playFrom(rows, i, playingWave),
            ),
          ),
        ),
        const SliverPadding(
          padding: EdgeInsets.fromLTRB(24, 24, 24, 28),
          sliver: SliverToBoxAdapter(child: MyTastePanel()),
        ),
      ],
    );
  }

  Future<void> _playFrom(
    List<(Track, String?, bool)> rows,
    int index,
    bool playingWave,
  ) async {
    final player = ref.read(playerProvider.notifier);
    if (playingWave) {
      final state = ref.read(playerProvider);
      final target = state.upNext[index];
      await player.jumpTo(state.queue.indexOf(target));
      return;
    }
    await player.playTracks(
      [for (final r in rows) r.$1],
      start: index,
      context: PlayContext.wave,
    );
  }
}

class _WaveHeader extends ConsumerWidget {
  const _WaveHeader({
    required this.playingWave,
    required this.hasMusic,
    required this.privateSession,
  });

  final bool playingWave;
  final bool hasMusic;
  final bool privateSession;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return NexaPanel(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(S.waveHeading, style: NexaText.h2.copyWith(fontSize: 26)),
              if (playingWave) const StatusBadge.phase(S.wavePlaying),
              if (privateSession)
                const StatusBadge(
                  label: S.privateSessionOn,
                  color: NexaColors.sky,
                ),
            ],
          ),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: const Text(S.waveSubtitleLive, style: NexaText.bodySecondary),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: NexaSpace.sm,
            runSpacing: NexaSpace.sm,
            children: [
              NexaPillButton(
                label: S.startWave,
                icon: Icons.play_arrow_rounded,
                onPressed: hasMusic
                    ? () => ref.read(waveProvider.notifier).start()
                    : null,
                disabledReason: S.waveEmptyLibrary,
              ),
              NexaPillButton(
                label: S.editDna,
                icon: Icons.tune_rounded,
                variant: PillVariant.secondary,
                onPressed: hasMusic ? () => showDnaPicker(context) : null,
                disabledReason: S.waveEmptyLibrary,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TuningPanel extends ConsumerWidget {
  const _TuningPanel({
    required this.settings,
    this.onlineNote,
    this.onlineReady = 0,
  });

  final DnaSettings settings;

  /// E1: why online picks are missing, if so.
  final String? onlineNote;
  final int onlineReady;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dna = ref.read(dnaSettingsProvider.notifier);
    final slider = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const InfoTitle(
          title: S.familiarDiscovery,
          info: S.familiarDiscoveryInfo,
        ),
        IsolatedSlider(
          child: Slider(
            value: settings.discovery,
            divisions: 10,
            label: '${(settings.discovery * 100).round()}%',
            semanticFormatterCallback: (v) =>
                '${S.discovery} ${(v * 100).round()}%',
            onChanged: (v) => dna.setDiscovery(v),
            onChangeEnd: (_) => ref.read(waveProvider.notifier).refresh(),
          ),
        ),
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(S.familiar, style: NexaText.caption),
            Text(S.waveOnlineOnlyEnd, style: NexaText.caption),
          ],
        ),
      ],
    );
    final private = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InfoTitle(title: S.privateSession, info: S.privateSessionInfo),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Switch(
          value: settings.privateSession,
          onChanged: dna.setPrivateSession,
        ),
      ],
    );
    final note = onlineNote;
    final online = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const InfoTitle(title: S.waveOnline, info: S.waveOnlineInfo),
              if (settings.waveOnline && note != null) ...[
                const SizedBox(height: 6),
                Text(
                  note,
                  key: const ValueKey('wave-online-note'),
                  style: NexaText.caption.copyWith(color: NexaColors.coral),
                ),
              ] else if (settings.waveOnline && onlineReady > 0) ...[
                const SizedBox(height: 6),
                Text(
                  S.waveOnlineCount(onlineReady),
                  style: NexaText.caption.copyWith(color: NexaColors.sky),
                ),
              ],
              if (settings.waveOnline) ...[
                const SizedBox(height: 14),
                const InfoTitle(
                  title: S.waveOnlineShare,
                  info: S.waveOnlineShareInfo,
                ),
                IsolatedSlider(
                  child: Slider(
                    key: const ValueKey('wave-online-share'),
                    value: settings.onlineShare,
                    divisions: 10,
                    label: S.waveOnlineShareValue(settings.onlineShare),
                    semanticFormatterCallback: S.waveOnlineShareValue,
                    onChanged: (v) => dna.setOnlineShare(v),
                    onChangeEnd: (_) =>
                        ref.read(waveProvider.notifier).refresh(),
                  ),
                ),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(S.waveShareLibrary, style: NexaText.caption),
                    Text(S.waveShareOnline, style: NexaText.caption),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 12),
        Switch(
          key: const ValueKey('wave-online-switch'),
          value: settings.waveOnline,
          onChanged: (v) async {
            await dna.setWaveOnline(v);
            await ref.read(waveProvider.notifier).refresh();
          },
        ),
      ],
    );
    return NexaPanel(
      padding: const EdgeInsets.all(20),
      child: LayoutBuilder(
        builder: (context, constraints) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (constraints.maxWidth < 640) ...[
              slider,
              const SizedBox(height: 18),
              private,
            ] else
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 3, child: slider),
                  const SizedBox(width: 32),
                  Expanded(flex: 2, child: private),
                ],
              ),
            const SizedBox(height: 18),
            online,
          ],
        ),
      ),
    );
  }
}

class _DnaSetupCard extends ConsumerWidget {
  const _DnaSetupCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return NexaPanel(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          const Icon(Icons.auto_awesome_rounded, color: NexaColors.accent),
          const SizedBox(width: 16),
          const Expanded(child: Text(S.dnaIntro, style: NexaText.bodySecondary)),
          const SizedBox(width: 16),
          TextButton(
            onPressed: () =>
                ref.read(dnaSettingsProvider.notifier).setOnboarded(true),
            child: const Text(S.skip),
          ),
          const SizedBox(width: 8),
          NexaPillButton(
            label: S.setUpDna,
            height: 40,
            onPressed: () => showDnaPicker(context),
          ),
        ],
      ),
    );
  }
}

/// Real NEXA DNA summary: liked and excluded genres / artists.
class MyTastePanel extends ConsumerWidget {
  const MyTastePanel({super.key, this.compact = false});

  /// Narrow layout for the right panel.
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final choices = ref.watch(tasteItemsProvider).value ?? const [];
    final hasMusic = (ref.watch(trackCountProvider).value ?? 0) > 0;
    final liked = choices.where((c) => !c.excluded).toList();
    final excluded = choices.where((c) => c.excluded).toList();
    return NexaPanel(
      padding: EdgeInsets.all(compact ? 16 : 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionHeader(
            title: S.myTaste,
            style: NexaText.h3,
            trailing: NexaTextLink(
              label: choices.isEmpty ? S.setUpDna : S.editDna,
              showArrow: false,
              onTap: hasMusic ? () => showDnaPicker(context) : null,
              disabledReason: S.waveEmptyLibrary,
            ),
          ),
          const SizedBox(height: 10),
          if (choices.isEmpty)
            const Text(S.myTasteEmpty, style: NexaText.caption)
          else ...[
            if (liked.isNotEmpty) ...[
              const Text(S.myTasteLiked, style: NexaText.caption),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final c in liked.take(compact ? 8 : 24))
                    TasteChip(label: c.value, choice: c),
                ],
              ),
            ],
            if (excluded.isNotEmpty) ...[
              const SizedBox(height: 10),
              const Text(S.myTasteExcluded, style: NexaText.caption),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final c in excluded.take(compact ? 6 : 24))
                    TasteChip(label: c.value, choice: c),
                ],
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Text(text, style: NexaText.bodySecondary),
    );
  }
}

class _WaveRow extends ConsumerWidget {
  const _WaveRow({
    super.key,
    required this.track,
    required this.reason,
    required this.fresh,
    required this.onPlay,
  });

  final Track track;
  final String? reason;
  final bool fresh;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final live = ref.watch(trackProvider(track.id)).value ?? track;
    return SizedBox(
      height: 64,
      child: NexaTappable(
        onTap: onPlay,
        semanticLabel: '${S.play} ${live.title}',
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              TrackArt(
                artworkPath: live.artworkPath,
                seed: live.id,
                size: 44,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            live.title,
                            style: NexaText.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (live.isOnline) ...[
                          const SizedBox(width: 8),
                          SourceBadge(source: live.source),
                        ] else if (fresh) ...[
                          const SizedBox(width: 8),
                          const StatusBadge(
                            label: S.fresh,
                            color: NexaColors.sky,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      live.artist,
                      style: NexaText.caption,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (reason != null) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: Row(
                    children: [
                      const Icon(
                        Icons.auto_awesome_rounded,
                        size: 14,
                        color: NexaColors.accent,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          reason!,
                          style: NexaText.caption,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(width: 8),
              FavoriteButton(track: live),
              DislikeButton(track: live),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Why this song" line for Now Playing (only for songs from the Wave).
class WaveReasonLine extends ConsumerWidget {
  const WaveReasonLine({super.key, required this.track});

  final Track track;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wave = ref.watch(
      playerProvider.select((p) => p.context == PlayContext.wave),
    );
    final reason = wave
        ? ref.read(waveProvider.notifier).reasonFor(track.id)
        : null;
    if (reason == null) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.auto_awesome_rounded,
            size: 16,
            color: NexaColors.accent,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              '${S.whyThisTrack}: $reason',
              style: NexaText.bodySecondary,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
