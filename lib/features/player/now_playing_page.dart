import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/navigation.dart';
import '../../app/strings.dart';
import '../../app/theme/nexa_theme.dart';
import '../../app/theme/tokens.dart';
import '../../demo/demo_data.dart';
import '../../ui/cover_art.dart';
import '../../ui/nexa_widgets.dart';
import '../../ui/play_ring_button.dart';
import '../mix_engine/mix_engine_panel.dart';
import 'up_next_card.dart';

/// Full Now Playing screen (Phase 1 layout with DEMO track).
class NowPlayingPage extends ConsumerWidget {
  const NowPlayingPage({super.key, required this.inlineMixEngine});

  /// True when the right panel is collapsed: the Mix Engine is shown below
  /// the player instead.
  final bool inlineMixEngine;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const track = DemoData.nowPlaying;
    return LayoutBuilder(
      builder: (context, constraints) {
        final contentWidth = constraints.maxWidth - 48;
        // Narrow (e.g. while the window shrinks): cover above the details.
        final stacked = contentWidth < 600;
        final coverSize = stacked
            ? contentWidth.clamp(0.0, 320.0).toDouble()
            : (contentWidth * 0.42).clamp(240.0, 440.0).toDouble();
        final cover = Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(NexaRadius.lg),
            boxShadow: const [
              BoxShadow(
                color: Color(0x40AD9AFF),
                blurRadius: 48,
                spreadRadius: -8,
                offset: Offset(0, 18),
              ),
            ],
          ),
          child: CoverArt(
            spec: track.art,
            size: coverSize,
            radius: NexaRadius.lg,
          ),
        );
        return SingleChildScrollView(
          key: const PageStorageKey('page-now-playing'),
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Wrap instead of Row: never overflows, even mid-animation
              // while the window shrinks.
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 16,
                runSpacing: 12,
                children: [
                  const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(S.nowPlaying, style: NexaText.overline),
                      SizedBox(width: 12),
                      StatusBadge.demo(),
                    ],
                  ),
                  _WaveChip(
                    onTap: () => ref
                        .read(navigationProvider.notifier)
                        .go(NexaDestination.wave),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              if (stacked)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [cover, const SizedBox(height: 24), const _TrackDetails()],
                )
              else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    cover,
                    const SizedBox(width: 36),
                    const Expanded(child: _TrackDetails()),
                  ],
                ),
              const SizedBox(height: 28),
              const _WaveformProgress(),
              const SizedBox(height: 18),
              const _NowPlayingTabs(),
              if (inlineMixEngine) ...[
                const SizedBox(height: 24),
                const MixEnginePanel(),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _WaveChip extends StatelessWidget {
  const _WaveChip({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0x33FFFFFF)),
      ),
      child: NexaTappable(
        onTap: onTap,
        tooltip: S.waveChipTooltip,
        semanticLabel: S.waveChip,
        borderRadius: BorderRadius.circular(28),
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 18, vertical: 11),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.auto_awesome_rounded, size: 18, color: NexaColors.accent),
              SizedBox(width: 10),
              Text(S.waveChip, style: NexaText.body),
              SizedBox(width: 8),
              StatusBadge.phase(S.phase5),
              SizedBox(width: 6),
              Icon(Icons.chevron_right_rounded, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _TrackDetails extends StatelessWidget {
  const _TrackDetails();

  @override
  Widget build(BuildContext context) {
    const track = DemoData.nowPlaying;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          track.title,
          style: NexaText.display.copyWith(fontSize: 46),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 6),
        Text(
          track.artist,
          style: NexaText.h2.copyWith(
            fontSize: 22,
            fontWeight: FontWeight.w500,
            color: NexaColors.textSecondary,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 18),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: NexaColors.panel,
              borderRadius: BorderRadius.circular(NexaRadius.sm),
              border: Border.all(color: NexaColors.border),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.graphic_eq_rounded, size: 16, color: NexaColors.accent),
                SizedBox(width: 8),
                Text(
                  DemoData.nowPlayingFormat,
                  style: TextStyle(
                    fontFamily: NexaText.family,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.6,
                    color: NexaColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        const FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ActionCircle(
                icon: Icons.favorite_border_rounded,
                label: S.like,
                reason: S.soonFavorites,
              ),
              SizedBox(width: 14),
              _ActionCircle(
                icon: Icons.add_rounded,
                label: S.addToPlaylist,
                reason: S.soonPlaylists,
              ),
              SizedBox(width: 14),
              _ActionCircle(
                icon: Icons.more_horiz_rounded,
                label: S.moreActions,
                reason: S.soonLibrary,
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),
        const FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _BigIcon(Icons.shuffle_rounded, S.shuffleLabel, 28),
              SizedBox(width: 18),
              _BigIcon(Icons.skip_previous_rounded, S.previous, 40),
              SizedBox(width: 18),
              PlayRingButton(size: 88),
              SizedBox(width: 18),
              _BigIcon(Icons.skip_next_rounded, S.next, 40),
              SizedBox(width: 18),
              _BigIcon(Icons.repeat_rounded, S.repeat, 28),
            ],
          ),
        ),
      ],
    );
  }
}

class _ActionCircle extends StatelessWidget {
  const _ActionCircle({
    required this.icon,
    required this.label,
    required this.reason,
  });

  final IconData icon;
  final String label;
  final String reason;

  /// Non-functional in Phase 1: same muted style for every action, no fake
  /// "liked" state; the tooltip says which phase brings it.
  @override
  Widget build(BuildContext context) {
    return NexaTooltip(
      message: '$label - $reason',
      child: Semantics(
        button: true,
        enabled: false,
        label: label,
        child: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0x08FFFFFF),
            border: Border.all(color: const Color(0x1FFFFFFF)),
          ),
          child: Icon(icon, size: 24, color: NexaColors.textDisabled),
        ),
      ),
    );
  }
}

class _BigIcon extends StatelessWidget {
  const _BigIcon(this.icon, this.label, this.size);

  final IconData icon;
  final String label;
  final double size;

  @override
  Widget build(BuildContext context) {
    return NexaIconButton(
      icon: icon,
      label: label,
      disabledReason: S.soonPlayback,
      iconSize: size,
      boxSize: size + 20,
    );
  }
}

/// Code-drawn waveform with the DEMO position. Seeking arrives in Phase 3.
class _WaveformProgress extends StatelessWidget {
  const _WaveformProgress();

  @override
  Widget build(BuildContext context) {
    const position = DemoData.nowPlayingPosition;
    final duration = DemoData.nowPlaying.duration;
    final fraction = position.inMilliseconds / duration.inMilliseconds;
    return NexaTooltip(
      message: S.soonSeek,
      child: Column(
        children: [
          SizedBox(
            height: 56,
            width: double.infinity,
            child: CustomPaint(painter: WaveformPainter(progress: fraction)),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(formatClock(position), style: NexaText.caption),
              const Spacer(),
              Text(formatClock(duration), style: NexaText.caption),
            ],
          ),
        ],
      ),
    );
  }
}

class WaveformPainter extends CustomPainter {
  WaveformPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final count = (size.width / 7).floor().clamp(40, 220).toInt();
    final step = size.width / count;
    final mid = size.height / 2;
    final played = Paint()
      ..color = NexaColors.accent.withValues(alpha: 0.7)
      ..strokeCap = StrokeCap.round
      ..strokeWidth = math.max(2.0, step * 0.45);
    final rest = Paint()
      ..color = const Color(0x40FFFFFF)
      ..strokeCap = StrokeCap.round
      ..strokeWidth = math.max(2.0, step * 0.45);
    for (var i = 0; i < count; i++) {
      final xn = i / count;
      final envelope = 0.35 + 0.65 * math.sin(math.pi * xn).abs();
      final detail = 0.55 +
          0.45 *
              (math.sin(i * 0.9) * 0.5 + math.sin(i * 0.37 + 1.3) * 0.5).abs();
      final h = mid * 0.95 * envelope * detail;
      final x = (i + 0.5) * step;
      canvas.drawLine(
        Offset(x, mid - h),
        Offset(x, mid + h),
        xn <= progress ? played : rest,
      );
    }
    final px = size.width * progress;
    canvas.drawLine(
      Offset(px, 0),
      Offset(px, size.height),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.55)
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(WaveformPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _NowPlayingTabs extends StatelessWidget {
  const _NowPlayingTabs();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(4, 8, 12, 10),
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: NexaColors.accent, width: 2),
                ),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.format_list_bulleted_rounded,
                    size: 18,
                    color: NexaColors.accent,
                  ),
                  SizedBox(width: 10),
                  Text(
                    S.queueTab,
                    style: TextStyle(
                      fontFamily: NexaText.family,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: NexaColors.accent,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 24),
            const Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: NexaTooltip(
                  message: S.lyricsNotInV1,
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(4, 8, 12, 10),
                    child: Row(
                      children: [
                        Icon(
                          Icons.notes_rounded,
                          size: 18,
                          color: NexaColors.textDisabled,
                        ),
                        SizedBox(width: 10),
                        Text(
                          S.lyricsTab,
                          style: TextStyle(
                            fontFamily: NexaText.family,
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: NexaColors.textDisabled,
                          ),
                        ),
                        SizedBox(width: 8),
                        StatusBadge(
                          label: S.notInV1,
                          color: NexaColors.textTertiary,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const Divider(height: 1, color: NexaColors.divider),
        const SizedBox(height: 10),
        const UpNextCard(maxItems: 3, framed: false),
      ],
    );
  }
}
