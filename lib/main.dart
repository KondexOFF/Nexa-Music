import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';

import 'app/app.dart';
import 'app/capture/capture_harness.dart';
import 'app/config.dart';
import 'audio_probe/probe_app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  // The bundled Manrope font (SIL OFL 1.1) in the licence list.
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks(
      const ['Manrope font'],
      await rootBundle.loadString('assets/fonts/OFL.txt'),
    );
  });

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
