import 'package:flutter_test/flutter_test.dart';
import 'package:nexa_music/audio_probe/audio_self_test.dart';

/// Simulated player: time only moves when the self-test waits.
/// Tests the self-test logic, NOT real audio output.
class FakeProbePlayer implements ProbePlayer {
  FakeProbePlayer({
    this.trackLength = const Duration(minutes: 3),
    this.advances = true,
  });

  final Duration trackLength;
  final bool advances;

  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _playing = false;
  double _volume = 100;

  Future<void> advance(Duration elapsed) async {
    if (_playing && advances) {
      _position += elapsed;
      if (_position > _duration) {
        _position = _duration;
      }
    }
  }

  @override
  Future<void> open(String path) async {
    _duration = trackLength;
    _position = Duration.zero;
  }

  @override
  Future<void> play() async {
    _playing = true;
  }

  @override
  Future<void> pause() async {
    _playing = false;
  }

  @override
  Future<void> seek(Duration position) async {
    _position = position;
  }

  @override
  Future<void> setVolume(double volume) async {
    _volume = volume;
  }

  @override
  Duration get position => _position;

  @override
  Duration get duration => _duration;

  @override
  bool get playing => _playing;

  @override
  double get volume => _volume;

  @override
  String? get lastError => null;
}

void main() {
  test('all steps pass against a well-behaved simulated player', () async {
    final fake = FakeProbePlayer();
    final steps = await AudioSelfTest(fake, delay: fake.advance).run('x.mp3');

    expect(steps.map((s) => s.name), AudioSelfTest.stepNames);
    expect(steps.every((s) => s.passed), isTrue, reason: steps.join('\n'));
    expect(fake.playing, isFalse, reason: 'self-test must end paused');
  });

  test('play and resume fail when position never advances', () async {
    final fake = FakeProbePlayer(advances: false);
    final steps = await AudioSelfTest(fake, delay: fake.advance).run('x.mp3');
    final failed = steps.where((s) => !s.passed).map((s) => s.name);

    expect(failed, ['play', 'resume after seek']);
  });

  test('stops after open when no duration is reported', () async {
    final fake = FakeProbePlayer(trackLength: Duration.zero);
    final steps = await AudioSelfTest(fake, delay: fake.advance).run('x.mp3');

    expect(steps, hasLength(1));
    expect(steps.single.name, 'open');
    expect(steps.single.passed, isFalse);
  });

  test('short tracks are seeked to the middle', () async {
    final fake = FakeProbePlayer(trackLength: const Duration(seconds: 40));
    final steps = await AudioSelfTest(fake, delay: fake.advance).run('x.mp3');
    final seek = steps.firstWhere((s) => s.name == 'seek');

    expect(seek.passed, isTrue);
    expect(seek.detail, startsWith('target 0:20.000'));
  });

  test('formatDuration', () {
    expect(
      formatDuration(const Duration(minutes: 1, seconds: 5, milliseconds: 7)),
      '1:05.007',
    );
    expect(formatDuration(const Duration(milliseconds: -1500)), '-0:01.500');
  });
}
