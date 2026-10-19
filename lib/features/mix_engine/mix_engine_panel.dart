import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/strings.dart';
import '../../app/theme/nexa_theme.dart';
import '../../app/theme/tokens.dart';
import '../../ui/isolated_slider.dart';
import '../../ui/nexa_widgets.dart';
import '../../core/audio/transition.dart';
import '../player/player_controller.dart';
import 'mix_settings.dart';
import 'transition_planner.dart';

/// NEXA Mix Engine panel (Phase 4): the settings are applied to playback and
/// saved; the panel also explains the next transition.
class MixEnginePanel extends ConsumerWidget {
  const MixEnginePanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mix = ref.watch(mixSettingsProvider);
    final controller = ref.read(mixSettingsProvider.notifier);
    final sliderEnabled = mix.mode != TransitionMode.gapless;

    return NexaPanel(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              Expanded(
                child: Text(
                  S.mixEngine,
                  style: NexaText.overline,
                  maxLines: 1,
                  overflow: TextOverflow.fade,
                  softWrap: false,
                ),
              ),
              Icon(Icons.graphic_eq_rounded, color: NexaColors.accent),
            ],
          ),
          const SizedBox(height: 12),
          const _MixNote(),
          const SizedBox(height: 12),
          const _NextTransition(),
          const Divider(height: 28, color: NexaColors.divider),
          const Row(
            children: [
              Text(S.transitions, style: NexaText.h3),
              SizedBox(width: 8),
              NexaTooltip(
                message: S.transitionsInfo,
                child: Icon(
                  Icons.info_outline_rounded,
                  size: 18,
                  color: NexaColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _ModeSelector(value: mix.mode, onChanged: controller.setMode),
          const SizedBox(height: 16),
          Row(
            children: [
              const Text('0s', style: NexaText.caption),
              Expanded(
                child: IsolatedSlider(
                  child: Slider(
                    value: mix.crossfadeSeconds,
                    min: MixSettings.minSeconds,
                    max: MixSettings.maxSeconds,
                    divisions: 12,
                    label: '${mix.crossfadeSeconds.round()} s',
                    onChanged: sliderEnabled ? controller.setSeconds : null,
                  ),
                ),
              ),
              const Text('12s', style: NexaText.caption),
            ],
          ),
          Align(
            alignment: Alignment.centerRight,
            child: AnimatedSwitcher(
              duration: NexaMotion.fast,
              child: Text(
                _secondsLabel(mix),
                key: ValueKey(_secondsLabel(mix)),
                style: NexaText.title,
              ),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 76,
            child: TweenAnimationBuilder<double>(
              tween: Tween(end: mix.overlapFraction),
              duration: NexaMotion.slow,
              curve: NexaMotion.curve,
              builder: (context, overlap, _) => CustomPaint(
                painter: TransitionPreviewPainter(overlap: overlap),
              ),
            ),
          ),
          const SizedBox(height: 10),
          const Row(
            children: [
              _LegendDot(color: NexaColors.coral),
              SizedBox(width: 6),
              Flexible(
                child: Text(
                  S.outgoingTrack,
                  style: NexaText.caption,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              SizedBox(width: 12),
              _LegendDot(color: NexaColors.accent),
              SizedBox(width: 6),
              Flexible(
                child: Text(
                  S.incomingTrack,
                  style: NexaText.caption,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const Divider(height: 32, color: NexaColors.divider),
          Row(
            children: [
              const Text(S.smartMixTitle, style: NexaText.h3),
              const SizedBox(width: 8),
              const NexaTooltip(
                message: S.smartMixInfo,
                child: Icon(
                  Icons.info_outline_rounded,
                  size: 18,
                  color: NexaColors.textSecondary,
                ),
              ),
              const Spacer(),
              Switch(
                value: mix.allowSmartAdjust,
                onChanged: controller.setAllowSmartAdjust,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: NexaColors.panelRaised,
                  border: Border.all(color: NexaColors.border),
                ),
                child: const Icon(
                  Icons.graphic_eq_rounded,
                  size: 22,
                  color: NexaColors.accent,
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Text(
                  S.smartMixDescription,
                  style: NexaText.bodySecondary,
                ),
              ),
            ],
          ),
          const Divider(height: 32, color: NexaColors.divider),
          Row(
            children: [
              const Flexible(
                child: Text(
                  S.albumGaplessTitle,
                  style: NexaText.h3,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              const NexaTooltip(
                message: S.albumGaplessInfo,
                child: Icon(
                  Icons.info_outline_rounded,
                  size: 18,
                  color: NexaColors.textSecondary,
                ),
              ),
              const Spacer(),
              Switch(
                value: mix.albumGapless,
                onChanged: controller.setAlbumGapless,
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _secondsLabel(MixSettings mix) {
    if (mix.mode == TransitionMode.gapless) {
      return S.gaplessNote;
    }
    final s = mix.crossfadeSeconds.round();
    if (s == 0) {
      return S.crossfadeOff;
    }
    return s == 1 ? '1 second' : '$s seconds';
  }
}

class _MixNote extends StatelessWidget {
  const _MixNote();

  @override
  Widget build(BuildContext context) {
    return Text(
      S.mixNote,
      style: NexaText.caption.copyWith(color: NexaColors.textSecondary),
    );
  }
}

/// The plan for the upcoming transition, from the real queue.
final _nextTransitionProvider = Provider<TransitionPlan?>((ref) {
  final player = ref.watch(playerProvider);
  final settings = ref.watch(mixSettingsProvider);
  final current = player.current;
  final next = player.nextEntry?.track;
  if (current == null || next == null) {
    return null;
  }
  return planTransition(settings, current, next);
});

class _NextTransition extends ConsumerWidget {
  const _NextTransition();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plan = ref.watch(_nextTransitionProvider);
    final text = switch (plan) {
      null => S.noNextTrack,
      TransitionPlan(
        kind: TransitionKind.crossfade,
        :final fade,
        :final reason,
      ) =>
        '$reason - ${(fade.inMilliseconds / 1000).toStringAsFixed(1)} s',
      TransitionPlan(:final reason) => reason,
    };
    return Row(
      children: [
        const Icon(Icons.swap_horiz_rounded, size: 18, color: NexaColors.accent),
        const SizedBox(width: 8),
        Text('${S.nextTransition}: ', style: NexaText.caption),
        Expanded(
          child: Text(
            text,
            style: NexaText.caption.copyWith(color: NexaColors.textPrimary),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _ModeSelector extends StatelessWidget {
  const _ModeSelector({required this.value, required this.onChanged});

  final TransitionMode value;
  final ValueChanged<TransitionMode> onChanged;

  static const Map<TransitionMode, String> _labels = {
    TransitionMode.crossfade: S.modeCrossfade,
    TransitionMode.smartMix: S.modeSmartMix,
    TransitionMode.gapless: S.modeGapless,
  };

  @override
  Widget build(BuildContext context) {
    const modes = TransitionMode.values;
    final index = modes.indexOf(value);
    return Container(
      height: 46,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: NexaColors.panelRaised,
        borderRadius: BorderRadius.circular(NexaRadius.md),
        border: Border.all(color: NexaColors.border),
      ),
      child: Stack(
        children: [
          AnimatedAlign(
            duration: NexaMotion.normal,
            curve: NexaMotion.curve,
            alignment: Alignment(-1 + index * (2 / (modes.length - 1)), 0),
            child: FractionallySizedBox(
              widthFactor: 1 / modes.length,
              heightFactor: 1,
              child: Container(
                decoration: BoxDecoration(
                  color: NexaColors.accent,
                  borderRadius: BorderRadius.circular(NexaRadius.sm + 1),
                ),
              ),
            ),
          ),
          Row(
            children: [
              for (final mode in modes)
                Expanded(
                  child: NexaTappable(
                    onTap: () => onChanged(mode),
                    semanticLabel: _labels[mode],
                    borderRadius: BorderRadius.circular(NexaRadius.sm + 1),
                    hoverColor: mode == value
                        ? Colors.transparent
                        : NexaColors.accentFaint,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: AnimatedDefaultTextStyle(
                            duration: NexaMotion.fast,
                            style: NexaText.body.copyWith(
                              fontSize: 14,
                              fontWeight: mode == value
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: mode == value
                                  ? Colors.white
                                  : NexaColors.textSecondary,
                            ),
                            child: Text(_labels[mode]!),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

/// Draws outgoing (coral) and incoming (lavender) level bars with an
/// equal-power overlap region of width [overlap] (0..0.5 of the width).
/// A visual explanation only; no audio is analysed in Phase 1.
class TransitionPreviewPainter extends CustomPainter {
  TransitionPreviewPainter({required this.overlap});

  final double overlap;

  static const int _bars = 64;

  double _level(int i, double salt) {
    final v = math.sin(i * 12.9898 + salt) * 43758.5453;
    return 0.35 + 0.65 * (v - v.floorToDouble());
  }

  @override
  void paint(Canvas canvas, Size size) {
    final mid = size.height / 2;
    final step = size.width / _bars;
    final barWidth = math.max(1.5, step * 0.42);
    final start = 0.5 - overlap / 2;
    final end = 0.5 + overlap / 2;

    final outPaint = Paint()
      ..color = NexaColors.coral
      ..strokeCap = StrokeCap.round
      ..strokeWidth = barWidth;
    final inPaint = Paint()
      ..color = NexaColors.accent
      ..strokeCap = StrokeCap.round
      ..strokeWidth = barWidth;

    for (var i = 0; i < _bars; i++) {
      final xn = (i + 0.5) / _bars;
      final x = xn * size.width;
      double outGain;
      double inGain;
      if (overlap <= 0.001) {
        outGain = xn < 0.5 ? 1 : 0;
        inGain = xn < 0.5 ? 0 : 1;
      } else {
        final p = ((xn - start) / (end - start)).clamp(0.0, 1.0).toDouble();
        outGain = math.cos(p * math.pi / 2);
        inGain = math.sin(p * math.pi / 2);
      }
      final outH = mid * 0.92 * _level(i, 1.7) * outGain;
      final inH = mid * 0.92 * _level(i, 4.1) * inGain;
      if (outH > 0.5) {
        canvas.drawLine(
          Offset(x - barWidth * 0.3, mid - outH),
          Offset(x - barWidth * 0.3, mid + outH),
          outPaint,
        );
      }
      if (inH > 0.5) {
        canvas.drawLine(
          Offset(x + barWidth * 0.3, mid - inH),
          Offset(x + barWidth * 0.3, mid + inH),
          inPaint,
        );
      }
    }

    if (overlap > 0.001) {
      // Lens outline of the overlap (equal-power crossfade region).
      final x0 = start * size.width;
      final x1 = end * size.width;
      final cx = (x0 + x1) / 2;
      final lens = Path()
        ..moveTo(x0, mid)
        ..quadraticBezierTo(cx, -size.height * 0.15, x1, mid)
        ..quadraticBezierTo(cx, size.height * 1.15, x0, mid)
        ..close();
      canvas.drawPath(
        lens,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = Colors.white.withValues(alpha: 0.32),
      );
    } else {
      canvas.drawLine(
        Offset(size.width / 2, 4),
        Offset(size.width / 2, size.height - 4),
        Paint()
          ..strokeWidth = 1
          ..color = Colors.white.withValues(alpha: 0.35),
      );
    }
  }

  @override
  bool shouldRepaint(TransitionPreviewPainter oldDelegate) =>
      oldDelegate.overlap != overlap;
}
