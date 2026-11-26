import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/strings.dart';
import '../../app/theme/nexa_theme.dart';
import '../../app/theme/tokens.dart';
import '../../ui/ambient_light.dart';
import '../../ui/nexa_widgets.dart';
import '../library/library_providers.dart';
import '../nexa_wave/wave_controller.dart';
import '../player/player_controller.dart';

/// NEXA Wave hero: a code-drawn, slowly moving ribbon landscape with the
/// Wave call to action (starts NEXA Wave or shuffles the library).
class WaveHero extends ConsumerStatefulWidget {
  const WaveHero({super.key, this.animate = true});

  /// False freezes the ribbons (tests, reduced-motion setting).
  final bool animate;

  @override
  ConsumerState<WaveHero> createState() => _WaveHeroState();
}

class _WaveHeroState extends ConsumerState<WaveHero>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 26),
    value: 0.18,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncMotion();
  }

  @override
  void didUpdateWidget(WaveHero oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncMotion();
  }

  void _syncMotion() {
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final shouldRun = widget.animate && !reduceMotion;
    if (shouldRun && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!shouldRun && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final showTags = constraints.maxWidth >= 760;
        return ClipRRect(
          borderRadius: BorderRadius.circular(NexaRadius.xl),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: 272,
              minWidth: constraints.maxWidth,
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  // NEXARYVE 1.2: the ribbon and the glow take the light of
                  // the playing song's artwork.
                  child: TweenAnimationBuilder<Color?>(
                    tween: ColorTween(end: ref.watch(ambientLightProvider)),
                    duration: NexaMotion.ambient,
                    curve: Curves.easeInOut,
                    builder: (context, light, _) => RepaintBoundary(
                      child: CustomPaint(
                        painter: WaveRibbonPainter(
                          animation: _controller,
                          light: light ?? NexaColors.accent,
                        ),
                      ),
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(36, 34, 36, 32),
                  child: _HeroContent(),
                ),
                if (showTags)
                  const Positioned(top: 34, right: 32, child: _HeroTags()),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _HeroContent extends ConsumerWidget {
  const _HeroContent();

  Future<void> _shuffleLibrary(WidgetRef ref) async {
    final tracks = await ref.read(libraryRepositoryProvider).getTracks();
    await ref.read(playerProvider.notifier).shuffleTracks([
      for (final t in tracks)
        if (t.available && !t.disliked) t,
    ]);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasMusic = (ref.watch(trackCountProvider).value ?? 0) > 0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(S.waveOverline, style: NexaText.overline),
        const SizedBox(height: 14),
        const Text(S.waveTitle, style: NexaText.display),
        const SizedBox(height: 12),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 470),
          child: Text(
            S.waveSubtitle,
            style: NexaText.bodySecondary.copyWith(
              fontSize: 16.5,
              color: const Color(0xFFD9D8DE),
            ),
          ),
        ),
        const SizedBox(height: 24),
        Wrap(
          spacing: NexaSpace.sm,
          runSpacing: NexaSpace.sm,
          children: [
            NexaPillButton(
              label: S.playWave,
              icon: Icons.play_arrow_rounded,
              onPressed: hasMusic
                  ? () => ref.read(waveProvider.notifier).start()
                  : null,
              disabledReason: S.waveEmptyLibrary,
            ),
            NexaPillButton(
              label: S.shuffle,
              icon: Icons.shuffle_rounded,
              variant: PillVariant.secondary,
              onPressed: hasMusic ? () => _shuffleLibrary(ref) : null,
              disabledReason: S.waveEmptyLibrary,
            ),
          ],
        ),
      ],
    );
  }
}

class _HeroTags extends StatelessWidget {
  const _HeroTags();

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(
      fontFamily: NexaText.family,
      fontSize: 10.5,
      fontWeight: FontWeight.w700,
      letterSpacing: 3,
      color: Color(0xB3F2F1EE),
    );
    return Container(
      padding: const EdgeInsets.only(left: 22),
      decoration: const BoxDecoration(
        border: Border(left: BorderSide(color: Color(0x33FFFFFF))),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(S.waveTagFamiliar, style: style),
          SizedBox(height: 14),
          Text(S.waveTagFresh, style: style),
          SizedBox(height: 14),
          Text(S.waveTagYours, style: style),
        ],
      ),
    );
  }
}

/// Paints the hero background. [animation] runs 0..1 and loops; [light] is
/// the playing song's artwork light (lavender when nothing plays).
class WaveRibbonPainter extends CustomPainter {
  WaveRibbonPainter({required this.animation, this.light = NexaColors.accent})
    : super(repaint: animation);

  final Animation<double> animation;
  final Color light;

  @override
  void paint(Canvas canvas, Size size) {
    final t = animation.value * 2 * math.pi;
    final rect = Offset.zero & size;
    final w = size.width;
    final h = size.height;
    final ribbon = [light, NexaColors.accent, NexaColors.live];

    // Graphite, lit from the right by the song.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF121318), Color(0xFF17181E)],
        ).createShader(rect),
    );
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0.55, -0.2),
          radius: 1.1,
          colors: [
            light.withValues(alpha: 0.42),
            light.withValues(alpha: 0.12),
            light.withValues(alpha: 0),
          ],
          stops: const [0, 0.45, 1],
        ).createShader(rect),
    );

    // A few quiet stars.
    final rnd = math.Random(42);
    final star = Paint();
    for (var i = 0; i < 18; i++) {
      final x = w * 0.35 + rnd.nextDouble() * w * 0.65;
      final y = rnd.nextDouble() * h * 0.5;
      final twinkle = 0.3 + 0.3 * math.sin(t * 3 + i);
      star.color = Colors.white.withValues(alpha: twinkle * 0.45);
      canvas.drawCircle(Offset(x, y), 0.6 + rnd.nextDouble() * 0.7, star);
    }

    // The glow: a soft orb in the song's light.
    final orb = Offset(w * 0.8, h * 0.44);
    final orbR = h * 0.11;
    canvas.drawCircle(
      orb,
      orbR * 3.4,
      Paint()
        ..shader = RadialGradient(
          colors: [
            Color.lerp(light, Colors.white, 0.25)!.withValues(alpha: 0.38),
            light.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: orb, radius: orbR * 3.4)),
    );
    canvas.drawCircle(
      orb,
      orbR,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color.lerp(light, Colors.white, 0.55)!, NexaColors.live],
        ).createShader(Rect.fromCircle(center: orb, radius: orbR)),
    );

    // Silk ribbon: a translucent body plus thin strands that twist slowly
    // along a sweep from bottom-left to the upper middle.
    const samples = 80;
    const strands = 26;
    double sweep(double xn) => math.exp(-math.pow((xn - 0.55) / 0.3, 2));
    double centre(double xn) =>
        h * (0.95 - 0.62 * sweep(xn)) +
        h * 0.06 * math.sin(xn * math.pi * 2.1 + t);
    double halfWidth(double xn) =>
        h * (0.04 + 0.17 * sweep(xn)) *
        (1 + 0.18 * math.sin(t * 0.8 + xn * 4.2));

    final body = <Offset>[];
    final bodyBottom = <Offset>[];
    for (var i = 0; i <= samples; i++) {
      final xn = i / samples;
      body.add(Offset(xn * w, centre(xn) - halfWidth(xn)));
      bodyBottom.add(Offset(xn * w, centre(xn) + halfWidth(xn)));
    }
    canvas.drawPath(
      Path()..addPolygon([...body, ...bodyBottom.reversed], true),
      Paint()
        ..shader = LinearGradient(
          colors: [for (final c in ribbon) c.withValues(alpha: 0.24)],
        ).createShader(rect),
    );

    for (var s = 0; s < strands; s++) {
      final f = s / (strands - 1);
      final points = <Offset>[];
      for (var i = 0; i <= samples; i++) {
        final xn = i / samples;
        final twist = h * 0.014 * math.sin(xn * 9 + t * 1.3 + f * 3.1);
        points.add(
          Offset(xn * w, centre(xn) + (f - 0.5) * 2 * halfWidth(xn) + twist),
        );
      }
      final edge = (f - 0.5).abs() * 2;
      final alpha = 0.18 + 0.48 * (1 - edge);
      canvas.drawPath(
        Path()..addPolygon(points, false),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..shader = LinearGradient(
            colors: [for (final c in ribbon) c.withValues(alpha: alpha)],
          ).createShader(rect),
      );
    }

    // Graphite hills.
    final hills = Path()
      ..moveTo(0, h)
      ..lineTo(0, h * 0.86)
      ..lineTo(w * 0.12, h * 0.8)
      ..lineTo(w * 0.22, h * 0.88)
      ..lineTo(w * 0.62, h * 0.9)
      ..lineTo(w * 0.7, h * 0.78)
      ..lineTo(w * 0.8, h * 0.84)
      ..lineTo(w * 0.9, h * 0.76)
      ..lineTo(w, h * 0.82)
      ..lineTo(w, h)
      ..close();
    canvas.drawPath(hills, Paint()..color = const Color(0xFF0C0D11));

    // Readability scrim behind the text column.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          colors: [
            Color(0xEB0F1013),
            Color(0x990F1013),
            Color(0x000F1013),
          ],
          stops: [0, 0.38, 0.66],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(WaveRibbonPainter oldDelegate) =>
      oldDelegate.animation != animation || oldDelegate.light != light;
}
