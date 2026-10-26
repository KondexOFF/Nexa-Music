import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';

import 'app/app.dart';
import 'app/capture/capture_harness.dart';
import 'app/config.dart';
import 'audio_probe/probe_app.dart';
import 'features/youtube_prototype/youtube_selftest.dart';

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

  if (Platform.environment['NEXA_DATA_DIR']?.isNotEmpty ?? false) {
    // NEXA AutoTest: marks the log so the test knows output is captured.
    // ignore: avoid_print
    print('NEXA AutoTest profile active');
  }
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
  final youtubeTest = youtubeSelfTestDir();
  if (youtubeTest.isNotEmpty) {
    // E2.0 YouTube prototype test (tools/e2_0): the normal app plus a
    // command-driven test of the prototype page.
    final container = ProviderContainer();
    runApp(
      UncontrolledProviderScope(container: container, child: const NexaApp()),
    );
    unawaited(YouTubeSelfTest(container, youtubeTest).run());
    return;
  }
  runApp(const ProviderScope(child: NexaApp()));
}
