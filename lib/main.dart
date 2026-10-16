import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';

import 'audio_probe/probe_screen.dart';

// Phase 0 configuration is passed with --dart-define so that no personal
// file paths are stored in the repository.
const String kTestAudioPath = String.fromEnvironment('NEXA_TEST_AUDIO');
const bool kRunSelfTest = bool.fromEnvironment('NEXA_SELFTEST');
const String kProbeLogDir = String.fromEnvironment('NEXA_PROBE_LOG_DIR');

final GlobalKey _captureKey = GlobalKey();

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  runApp(const NexaPhase0App());
}

class NexaPhase0App extends StatelessWidget {
  const NexaPhase0App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NEXA Music - Phase 0',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFAD9AFF),
          brightness: Brightness.dark,
        ),
      ),
      home: RepaintBoundary(
        key: _captureKey,
        child: ProbeScreen(
          initialPath: kTestAudioPath,
          selfTest: kRunSelfTest,
          logDir: kProbeLogDir,
          captureKey: _captureKey,
        ),
      ),
    );
  }
}
