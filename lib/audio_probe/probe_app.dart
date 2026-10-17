import 'package:flutter/material.dart';

import '../app/config.dart';
import 'probe_screen.dart';

final GlobalKey _captureKey = GlobalKey();

/// Phase 0 audio self-test app (unchanged behaviour, moved out of main.dart
/// in Phase 1). Started when NEXA_SELFTEST=true.
class AudioProbeApp extends StatelessWidget {
  const AudioProbeApp({super.key});

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
