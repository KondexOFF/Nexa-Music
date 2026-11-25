import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:media_kit/media_kit.dart';

import 'app/app.dart';
import 'app/capture/capture_harness.dart';
import 'app/config.dart';
import 'app/database_error_app.dart';
import 'audio_probe/probe_app.dart';
import 'core/database/app_database.dart';
import 'core/database/database_safety.dart';
import 'features/library/library_providers.dart';
import 'features/library/library_repository.dart';
import 'features/youtube/youtube_saved_refresh.dart';
import 'integrations/youtube/youtube_oembed.dart';

Future<void> main() async {
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
  // The database is opened (and migrated) before the app: a copy is made
  // first and put back if the migration fails (E2.7).
  final AppDatabase db;
  try {
    db = await openDatabaseSafely();
  } on DatabaseOpenFailed catch (e) {
    runApp(DatabaseErrorApp(error: e));
    return;
  }
  runApp(
    ProviderScope(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
      child: const NexaApp(),
    ),
  );
  reportHealthToUpdater();
  // Saved YouTube videos: data from YouTube refreshed or removed within
  // 30 days (YouTube Developer Policies III.E.4), in the background.
  final client = http.Client();
  unawaited(
    refreshSavedYouTube(LibraryRepository(db), YouTubeOEmbed(client))
        .then<void>((_) {}, onError: (Object _) {})
        .whenComplete(client.close),
  );
}

/// NEXA Update Center: the updater starts a new (or the previous) version
/// with `NEXA_UPDATE_HEALTH` and waits until that version writes its number
/// there - after its database opened and its first frame. Without it the
/// updater puts the previous program back.
void reportHealthToUpdater() {
  final file = Platform.environment['NEXA_UPDATE_HEALTH']?.trim() ?? '';
  if (file.isEmpty) {
    return;
  }
  WidgetsBinding.instance.addPostFrameCallback((_) {
    try {
      File(file).writeAsStringSync(kAppVersion, flush: true);
    } on FileSystemException {
      // The updater then reports a failed start.
    }
  });
}
