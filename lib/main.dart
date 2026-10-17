import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';

import 'app/app.dart';
import 'app/capture/capture_harness.dart';
import 'app/config.dart';
import 'audio_probe/probe_app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

  if (kRunSelfTest) {
    // Phase 0 regression path: audio self-test, then exit.
    runApp(const AudioProbeApp());
    return;
  }
  if (kCaptureDir.isNotEmpty) {
    // Phase 1 evidence: render fixed window sizes to PNG, then exit.
    runApp(const CaptureHarness(outDir: kCaptureDir));
    return;
  }
  runApp(const ProviderScope(child: NexaApp()));
}
