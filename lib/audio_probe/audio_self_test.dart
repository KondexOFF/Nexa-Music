import 'dart:async';

/// The small player surface needed by the Phase 0 audio probe.
///
/// Implemented with media_kit on Windows and by a fake in unit tests.
/// This is a Phase 0 prototype only; the real PlaybackEngine interface is
/// designed in Phase 3.
abstract interface class ProbePlayer {
  Future<void> open(String path);
  Future<void> play();
  Future<void> pause();
  Future<void> seek(Duration position);

  /// Volume in the range 0..100.
  Future<void> setVolume(double volume);

  Duration get position;
  Duration get duration;
  bool get playing;
  double get volume;
  String? get lastError;
}

enum ProbeOutcome { pass, fail }

class ProbeStep {
  const ProbeStep(this.name, this.outcome, this.detail);

  final String name;
  final ProbeOutcome outcome;
  final String detail;

  bool get passed => outcome == ProbeOutcome.pass;

  @override
  String toString() => '${passed ? 'PASS' : 'FAIL'}  $name: $detail';
}

typedef ProbeDelay = Future<void> Function(Duration duration);

Future<void> _realDelay(Duration duration) => Future<void>.delayed(duration);

/// Formats a duration as m:ss.mmm (for logs).
String formatDuration(Duration value) {
  final sign = value.isNegative ? '-' : '';
  final d = value.abs();
  final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  final millis = d.inMilliseconds.remainder(1000).toString().padLeft(3, '0');
  return '$sign${d.inMinutes}:$seconds.$millis';
}

/// Runs open -> play -> pause -> seek -> resume -> volume against a player
/// and checks the state the player reports after each step.
///
/// These are player-state checks. Whether sound is actually audible must be
/// confirmed by a person listening.
class AudioSelfTest {
  AudioSelfTest(
    this.player, {
    ProbeDelay? delay,
    this.pollInterval = const Duration(milliseconds: 100),
  }) : _delay = delay ?? _realDelay;

  final ProbePlayer player;
  final Duration pollInterval;
  final ProbeDelay _delay;

  static const List<String> stepNames = [
    'open',
    'play',
    'pause',
    'seek',
    'resume after seek',
    'set volume',
  ];

  Future<bool> _waitUntil(bool Function() condition, Duration timeout) async {
    var waited = Duration.zero;
    while (!condition()) {
      if (waited >= timeout) {
        return false;
      }
      await _delay(pollInterval);
      waited += pollInterval;
    }
    return true;
  }

  ProbeStep _check(String name, bool ok, String detail) =>
      ProbeStep(name, ok ? ProbeOutcome.pass : ProbeOutcome.fail, detail);

  Future<List<ProbeStep>> run(String path) async {
    final steps = <ProbeStep>[];

    // 1. Open without auto-play and wait until the engine reports a duration.
    try {
      await player.open(path);
    } catch (error) {
      steps.add(_check('open', false, 'exception: $error'));
      return steps;
    }
    final loaded = await _waitUntil(
      () => player.duration > Duration.zero,
      const Duration(seconds: 10),
    );
    steps.add(
      _check(
        'open',
        loaded,
        loaded
            ? 'duration ${formatDuration(player.duration)}'
            : 'no duration within 10 s; last engine error: '
                  '${player.lastError ?? 'none'}',
      ),
    );
    if (!loaded) {
      return steps;
    }

    // 2. Play for 3 seconds: position must advance.
    final startPosition = player.position;
    await player.play();
    await _delay(const Duration(seconds: 3));
    final advanced = player.position - startPosition;
    steps.add(
      _check(
        'play',
        player.playing && advanced >= const Duration(seconds: 2),
        'playing=${player.playing}, position advanced '
        '${formatDuration(advanced)} in 3 s',
      ),
    );

    // 3. Pause: position must stay still.
    await player.pause();
    await _delay(const Duration(milliseconds: 300));
    final pausedAt = player.position;
    await _delay(const Duration(milliseconds: 1500));
    final drift = (player.position - pausedAt).abs();
    steps.add(
      _check(
        'pause',
        !player.playing && drift < const Duration(milliseconds: 250),
        'playing=${player.playing}, drift ${formatDuration(drift)} over 1.5 s',
      ),
    );

    // 4. Seek while paused.
    final target = player.duration > const Duration(seconds: 90)
        ? const Duration(seconds: 60)
        : player.duration ~/ 2;
    await player.seek(target);
    final seeked = await _waitUntil(
      () =>
          (player.position - target).abs() <=
          const Duration(milliseconds: 500),
      const Duration(seconds: 5),
    );
    steps.add(
      _check(
        'seek',
        seeked,
        'target ${formatDuration(target)}, '
        'position ${formatDuration(player.position)}',
      ),
    );

    // 5. Resume from the new position.
    await player.play();
    await _delay(const Duration(seconds: 2));
    steps.add(
      _check(
        'resume after seek',
        player.playing && player.position >= target + const Duration(seconds: 1),
        'playing=${player.playing}, position ${formatDuration(player.position)}',
      ),
    );

    // 6. Volume 30 for 2 seconds, then back to 100.
    await player.setVolume(30);
    final lowered = await _waitUntil(
      () => (player.volume - 30).abs() < 0.5,
      const Duration(seconds: 2),
    );
    final loweredValue = player.volume;
    await _delay(const Duration(seconds: 2));
    await player.setVolume(100);
    final restored = await _waitUntil(
      () => (player.volume - 100).abs() < 0.5,
      const Duration(seconds: 2),
    );
    steps.add(
      _check(
        'set volume',
        lowered && restored,
        'set 30 -> reported ${loweredValue.toStringAsFixed(1)}; '
        'set 100 -> reported ${player.volume.toStringAsFixed(1)}',
      ),
    );

    await player.pause();
    return steps;
  }
}
