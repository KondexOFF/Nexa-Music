import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../ui/isolated_slider.dart';
import 'audio_self_test.dart';
import 'media_kit_probe_player.dart';
import 'probe_results_view.dart';

/// Test hook: creates the player instead of media_kit, whose native library
/// is not available in widget tests. Null in the app.
@visibleForTesting
ProbePlayer Function()? debugProbePlayerFactory;

/// Phase 0 technical screen for testing the Windows audio engine.
/// Not the NEXA user interface (that is Phase 1).
class ProbeScreen extends StatefulWidget {
  const ProbeScreen({
    super.key,
    required this.initialPath,
    required this.selfTest,
    required this.logDir,
    required this.captureKey,
  });

  final String initialPath;
  final bool selfTest;
  final String logDir;
  final GlobalKey captureKey;

  @override
  State<ProbeScreen> createState() => _ProbeScreenState();
}

class _ProbeScreenState extends State<ProbeScreen> {
  final ProbePlayer _player =
      debugProbePlayerFactory?.call() ?? MediaKitProbePlayer();

  Future<void> _disposePlayer() async {
    final player = _player;
    if (player is MediaKitProbePlayer) {
      await player.dispose();
    }
  }
  late final TextEditingController _pathController = TextEditingController(
    text: widget.initialPath,
  );
  Timer? _ticker;
  String? _openedName;
  String _status = 'No file opened.';
  final List<ProbeStep> _steps = [];
  bool _selfTestRunning = false;
  double? _dragSeconds;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (mounted) {
        setState(() {});
      }
    });
    if (widget.selfTest) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _runSelfTest());
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _pathController.dispose();
    unawaited(_disposePlayer());
    super.dispose();
  }

  static String _fileName(String path) => path.split(RegExp(r'[\\/]')).last;

  Future<void> _runSelfTest() async {
    final path = widget.initialPath;
    final log = StringBuffer()
      ..writeln('NEXA Music - Phase 0 - media_kit audio self-test')
      ..writeln('Started: ${DateTime.now().toIso8601String()}')
      ..writeln('OS: ${Platform.operatingSystemVersion}')
      ..writeln('Dart: ${Platform.version}')
      ..writeln('File name: ${_fileName(path)}');
    setState(() {
      _selfTestRunning = true;
      _openedName = _fileName(path);
      _status = 'Self-test running...';
    });

    var code = 1;
    if (path.isEmpty || !File(path).existsSync()) {
      _steps.add(
        const ProbeStep(
          'open',
          ProbeOutcome.fail,
          'test file not found (NEXA_TEST_AUDIO)',
        ),
      );
    } else {
      try {
        final steps = await AudioSelfTest(
          _player,
        ).run(path).timeout(const Duration(seconds: 90));
        _steps.addAll(steps);
        final allPassed =
            steps.length == AudioSelfTest.stepNames.length &&
            steps.every((step) => step.passed);
        code = allPassed ? 0 : 1;
      } on TimeoutException {
        _steps.add(
          const ProbeStep('self-test', ProbeOutcome.fail, 'timed out after 90 s'),
        );
        code = 2;
      }
    }

    if (!mounted) {
      return;
    }
    setState(() {
      _selfTestRunning = false;
      _status = code == 0 ? 'Self-test PASS' : 'Self-test FAIL';
    });
    await WidgetsBinding.instance.endOfFrame;

    for (final step in _steps) {
      log.writeln(step);
    }
    log
      ..writeln('Last engine error: ${_player.lastError ?? 'none'}')
      ..writeln('RESULT: ${code == 0 ? 'PASS' : 'FAIL'} (exit code $code)')
      ..writeln(
        'Note: player-state checks only; audible output must be confirmed '
        'by a person.',
      )
      ..writeln('Finished: ${DateTime.now().toIso8601String()}');

    if (widget.logDir.isNotEmpty) {
      final dir = Directory(widget.logDir)..createSync(recursive: true);
      final sep = Platform.pathSeparator;
      File('${dir.path}${sep}03_audio_selftest.txt')
          .writeAsStringSync(log.toString());
      await _capture('${dir.path}${sep}03_audio_selftest.png');
    }

    await _player.pause();
    await _disposePlayer();
    exit(code);
  }

  Future<void> _capture(String filePath) async {
    final boundary = widget.captureKey.currentContext?.findRenderObject();
    if (boundary is! RenderRepaintBoundary) {
      return;
    }
    final image = await boundary.toImage(pixelRatio: 1);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    if (data != null) {
      File(filePath).writeAsBytesSync(data.buffer.asUint8List());
    }
  }

  Future<void> _open() async {
    final path = _pathController.text.trim();
    if (path.isEmpty || !File(path).existsSync()) {
      setState(() => _status = 'File not found.');
      return;
    }
    try {
      await _player.open(path);
      if (!mounted) {
        return;
      }
      setState(() {
        _openedName = _fileName(path);
        _status = 'Opened. Press Play.';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _status = 'Open failed: $error');
    }
  }

  Future<void> _togglePlay() =>
      _player.playing ? _player.pause() : _player.play();

  Future<void> _seekTo(double seconds) async {
    await _player.seek(Duration(milliseconds: (seconds * 1000).round()));
    if (mounted) {
      setState(() => _dragSeconds = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final duration = _player.duration;
    final position = _player.position;
    final hasMedia = duration > Duration.zero;
    final interactive = hasMedia && !_selfTestRunning;
    final maxSeconds = hasMedia ? duration.inMilliseconds / 1000.0 : 1.0;
    final positionSeconds =
        (_dragSeconds ?? position.inMilliseconds / 1000.0)
            .clamp(0.0, maxSeconds)
            .toDouble();
    final volume = _player.volume.clamp(0.0, 100.0).toDouble();
    final lastError = _player.lastError;

    return Scaffold(
      appBar: AppBar(title: const Text('NEXA Music - Phase 0 audio prototype')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text(
            'Technical test of the Windows audio engine (media_kit). '
            'This is not the NEXA user interface.',
          ),
          const SizedBox(height: 16),
          if (!widget.selfTest)
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _pathController,
                    decoration: const InputDecoration(
                      labelText: 'Local audio file path',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton(onPressed: _open, child: const Text('Open')),
              ],
            ),
          const SizedBox(height: 16),
          Text('File: ${_openedName ?? '-'}'),
          Text(
            'State: ${_player.playing ? 'playing' : 'paused / stopped'}  |  '
            '${formatDuration(position)} / ${formatDuration(duration)}  |  '
            'volume ${volume.toStringAsFixed(0)}',
          ),
          Text('Status: $_status'),
          if (lastError != null)
            Text(
              'Engine error: $lastError',
              style: const TextStyle(color: Colors.redAccent),
            ),
          const SizedBox(height: 16),
          Row(
            children: [
              FilledButton.icon(
                onPressed: interactive ? _togglePlay : null,
                icon: Icon(_player.playing ? Icons.pause : Icons.play_arrow),
                label: Text(_player.playing ? 'Pause' : 'Play'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text('Position'),
          IsolatedSlider(
            child: Slider(
              value: positionSeconds,
              max: maxSeconds,
              onChanged: interactive
                  ? (value) => setState(() => _dragSeconds = value)
                  : null,
              onChangeEnd: interactive ? _seekTo : null,
            ),
          ),
          const Text('Volume'),
          IsolatedSlider(
            child: Slider(
              value: volume,
              max: 100,
              divisions: 20,
              label: volume.toStringAsFixed(0),
              onChanged: _selfTestRunning ? null : _player.setVolume,
            ),
          ),
          const Divider(height: 32),
          Text('Self-test', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          ProbeResultsView(steps: _steps, running: _selfTestRunning),
        ],
      ),
    );
  }
}
