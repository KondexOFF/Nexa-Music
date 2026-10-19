import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/strings.dart';
import '../../app/theme/nexa_theme.dart';
import '../../app/theme/tokens.dart';
import '../../ui/nexa_widgets.dart';
import '../library/library_providers.dart';
import '../nexa_wave/wave_controller.dart';
import '../player/player_controller.dart';

/// NEXA Wave hero: a code-drawn, slowly moving ribbon landscape with the
/// Wave call to action (starts NEXA Wave or shuffles the library).
class WaveHero extends StatefulWidget {
  const WaveHero({super.key, this.animate = true});

  /// False freezes the ribbons (tests, reduced-motion setting).
  final bool animate;

  @override
  State<WaveHero> createState() => _WaveHeroState();
}

class _WaveHeroState extends State<WaveHero>
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
                  child: RepaintBoundary(
                    child: CustomPaint(
                      painter: WaveRibbonPainter(animation: _controller),
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
              color: const Color(0xFFDCD9E6),
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
      color: Color(0xCCF0EFEB),
    );
    return Container(
      padding: const EdgeInsets.only(left: 22),
      decoration: const BoxDecoration(
        border: Border(left: BorderSide(color: Color(0x55FFFFFF))),
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

/// Paints the hero background. [animation] runs 0..1 and loops.
class WaveRibbonPainter extends CustomPainter {
  WaveRibbonPainter({required this.animation}) : super(repaint: animation);

  final Animation<double> animation;

  static const List<Color> _ribbon = [
    Color(0xFFFF8F6B),
    Color(0xFFFF5F9E),
    Color(0xFFC59BFF),
    Color(0xFF8E7BFF),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final t = animation.value * 2 * math.pi;
    final rect = Offset.zero & size;
    final w = size.width;
    final h = size.height;

    // Sky.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF15122E),
            Color(0xFF2A1F57),
            Color(0xFF5A2B6E),
            Color(0xFFB0506E),
          ],
          stops: [0, 0.42, 0.74, 1],
        ).createShader(rect),
    );

    // Stars (fixed positions, gentle twinkle).
    final rnd = math.Random(42);
    final star = Paint();
    for (var i = 0; i < 46; i++) {
      final x = rnd.nextDouble() * w;
      final y = rnd.nextDouble() * h * 0.55;
      final twinkle = 0.35 + 0.35 * math.sin(t * 3 + i);
      star.color = Colors.white.withValues(alpha: twinkle * 0.6);
      canvas.drawCircle(Offset(x, y), 0.6 + rnd.nextDouble() * 0.9, star);
    }

    // Sun.
    final sun = Offset(w * 0.79, h * 0.47);
    final sunR = h * 0.1;
    canvas.drawCircle(
      sun,
      sunR * 3.2,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFFFB37A).withValues(alpha: 0.45),
            const Color(0xFFFFB37A).withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: sun, radius: sunR * 3.2)),
    );
    canvas.drawCircle(
      sun,
      sunR,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFE0A6), Color(0xFFFF8E6E)],
        ).createShader(Rect.fromCircle(center: sun, radius: sunR)),
    );

    // Silk ribbon: a translucent body plus many thin strands that twist
    // slowly along a sweep from bottom-left to the upper middle.
    const samples = 80;
    const strands = 30;
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
          colors: [for (final c in _ribbon) c.withValues(alpha: 0.32)],
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
      final alpha = 0.22 + 0.5 * (1 - edge);
      canvas.drawPath(
        Path()..addPolygon(points, false),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.3
          ..shader = LinearGradient(
            colors: [for (final c in _ribbon) c.withValues(alpha: alpha)],
          ).createShader(rect),
      );
    }

    // Hills and water.
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
    canvas.drawPath(hills, Paint()..color = const Color(0xFF120F26));

    // Readability scrim behind the text column.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          colors: [
            Color(0xE6111319),
            Color(0x99111319),
            Color(0x00111319),
          ],
          stops: [0, 0.38, 0.66],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(WaveRibbonPainter oldDelegate) =>
      oldDelegate.animation != animation;
}
