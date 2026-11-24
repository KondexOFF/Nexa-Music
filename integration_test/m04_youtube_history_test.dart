// M-04 (D-028, automated): YouTube history is off by default; with the
// owner's own YouTube Data API key a normal watched video is written to the
// history and a video made for kids is not (Developer Policies III.E.4.j).
//
//   flutter test integration_test/m04_youtube_history_test.dart -d windows
//       --dart-define=NEXA_OWNER_COPY=<folder of a read-only copy of the
//         owner's NEXA data (runner action "ownerbackup")>
//
// The key is read from that copy (never from the owner's live data), used
// only in a temporary profile and never printed. Real WebView2 and YouTube
// player, videos muted (silent run).
import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:media_kit/media_kit.dart' show MediaKit;
import 'package:nexa_music/app/app.dart';
import 'package:nexa_music/core/database/app_database.dart';
import 'package:nexa_music/core/settings/settings_repository.dart';
import 'package:nexa_music/features/library/library_providers.dart';
import 'package:nexa_music/features/nexa_dna/dna_providers.dart';
import 'package:nexa_music/features/youtube/youtube_player_controller.dart';
import 'package:nexa_music/features/youtube/youtube_settings.dart';
import 'package:nexa_music/integrations/youtube/youtube_embed.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

const String ownerCopy = String.fromEnvironment('NEXA_OWNER_COPY');

/// YouTube's own public API demo video: not made for kids.
const String normalVideo = 'M7lc1UVf-VE';

/// "Baby Shark Dance" (Pinkfong): made for kids.
const String kidsVideo = 'XqZsoesa55w';

String? ownerKey() {
  final file = File(p.join(ownerCopy, 'nexa_library.sqlite'));
  if (ownerCopy.isEmpty || !file.existsSync()) {
    return null;
  }
  final temp = Directory.systemTemp.createTempSync('nexa_m04_key');
  try {
    final copy = file.copySync(p.join(temp.path, 'copy.sqlite'));
    final db = sqlite3.open(copy.path, mode: OpenMode.readOnly);
    try {
      final rows = db.select(
        'SELECT value FROM app_settings WHERE key = ?',
        [SettingKeys.youtubeApiKey],
      );
      final key = rows.isEmpty ? '' : '${rows.first['value']}'.trim();
      return key.isEmpty ? null : key;
    } finally {
      db.close();
    }
  } finally {
    temp.deleteSync(recursive: true);
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  testWidgets('M-04: YouTube history off by default; with the key a normal '
      'video is recorded, a video made for kids is not', (tester) async {
    final key = ownerKey();
    final result = <String, Object?>{'ownKey': key != null};
    String clean(Object? o) =>
        key == null ? '$o' : '$o'.replaceAll(key, '<key>');
    expect(key, isNotNull,
        reason: 'no own YouTube Data API key in the copy of your data');

    final temp = Directory.systemTemp.createTempSync('nexa_m04');
    final profile = Directory(p.join(temp.path, 'profile'))..createSync();
    final db = AppDatabase(
      NativeDatabase(File(p.join(profile.path, 'nexa_library.sqlite'))),
    );
    await tester.runAsync(() async {
      final repo = SettingsRepository(db);
      await repo.setBool(SettingKeys.youtubeEnabled, true);
      await repo.setString(SettingKeys.youtubeApiKey, key!);
    });
    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        artworkDirProvider.overrideWith(
          (ref) async => p.join(profile.path, 'artwork'),
        ),
        autoRescanProvider.overrideWithValue(false),
        youtubeEmbedFactoryProvider.overrideWithValue(
          () async =>
              WindowsYouTubeEmbed(profileDir: p.join(profile.path, 'webview2')),
        ),
      ],
    );
    YtStatus yt() => container.read(youtubePlayerProvider);
    YouTubePlayerController player() =>
        container.read(youtubePlayerProvider.notifier);

    Future<bool> waitFor(
      bool Function() test, {
      Duration timeout = const Duration(seconds: 30),
    }) async {
      final end = DateTime.now().add(timeout);
      while (DateTime.now().isBefore(end)) {
        if (test()) {
          return true;
        }
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)),
        );
        await tester.pump(const Duration(milliseconds: 50));
      }
      return test();
    }

    Future<void> watch(String id, Duration time) async {
      await tester.runAsync(() => player().load(id, mute: true));
      expect(
        await waitFor(() => yt().videoId == id && yt().state == YtState.playing),
        isTrue,
        reason: '$id playing; error ${yt().errorCode}',
      );
      await waitFor(() => false, timeout: time);
    }

    Future<List<Map<String, Object?>>> history() async {
      final rows = await tester.runAsync(
        () => db.customSelect(
          'SELECT t.source AS source, t.path AS id '
          'FROM listening_events e JOIN tracks t ON t.id = e.track_id',
        ).get(),
      );
      return [for (final r in rows!) r.data];
    }

    try {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const NexaApp(ambientMotion: false),
        ),
      );
      await waitFor(() => container.read(youtubeSettingsProvider).loaded);
      await waitFor(() => container.read(dnaSettingsProvider).loaded);

      // 1. Off by default: nothing is written.
      final dna = container.read(dnaSettingsProvider);
      result['defaults'] = {
        'history': dna.historyConsent,
        'youtubeHistory': dna.youtubeHistory,
      };
      expect(dna.youtubeHistory, isFalse);
      expect(dna.recordsYouTube, isFalse);
      await tester.runAsync(player().open);
      expect(await waitFor(() => yt().apiLoaded), isTrue);
      await watch(normalVideo, const Duration(seconds: 12));
      await tester.runAsync(player().close);
      await waitFor(() => false, timeout: const Duration(seconds: 2));
      expect(await history(), isEmpty, reason: 'off by default');

      // 2. What YouTube says about the two videos (with the owner's key).
      final kids = await tester.runAsync(
        () => container.read(youtubeDataApiProvider).madeForKids([
          normalVideo,
          kidsVideo,
        ]),
      );
      result['madeForKids'] = kids;
      expect(kids?[normalVideo], isFalse);
      expect(kids?[kidsVideo], isTrue);

      // 3. Switched on: the normal video is written, the kids video not.
      final ctl = container.read(dnaSettingsProvider.notifier);
      await tester.runAsync(() async {
        await ctl.setHistoryConsent(true);
        await ctl.setYouTubeHistory(true);
      });
      expect(container.read(dnaSettingsProvider).recordsYouTube, isTrue);
      await tester.runAsync(player().open);
      expect(await waitFor(() => yt().apiLoaded), isTrue);
      await watch(normalVideo, const Duration(seconds: 12));
      await watch(kidsVideo, const Duration(seconds: 12));
      await tester.runAsync(player().close);
      await waitFor(() => false, timeout: const Duration(seconds: 4));
      final rows = await history();
      result['history'] = rows;
      expect(rows, hasLength(1), reason: 'only the normal video: $rows');
      expect('${rows.single['id']}', contains(normalVideo));
      expect(rows.single['source'], 'youtube');
    } catch (e) {
      result['error'] = clean(e);
      rethrow;
    } finally {
      debugPrint('M04RESULT ${clean(jsonEncode(result))}');
      await tester.runAsync(player().close);
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(() async {
        container.dispose();
        await Future<void>.delayed(const Duration(seconds: 1));
        await db.close();
      });
      try {
        temp.deleteSync(recursive: true);
      } on FileSystemException {
        // WebView2 may still hold its profile for a moment.
      }
    }
  });
}
