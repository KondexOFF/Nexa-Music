// M-05 / M-06 (D-028, automated): one queue across sources with the real
// players - Library -> YouTube -> SoundCloud -> Library in a row, "Continue"
// when Windows blocks autoplay, the queue back after a restart; SoundCloud
// track, playlist (set) and profile links in SoundCloud's own widget.
//
//   flutter test integration_test/m05_mixed_queue_test.dart -d windows
//
// Real WebView2 with the official YouTube player and SoundCloud widget,
// media_kit / libmpv, a SQLite file database in a temporary profile. The
// YouTube and SoundCloud entries make sound (the queue plays them normally),
// so the run happens only at a time agreed with the owner. NEXA's own songs
// are tones at volume 0.
import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:media_kit/media_kit.dart' show MediaKit;
import 'package:nexa_music/app/app.dart';
import 'package:nexa_music/core/database/app_database.dart';
import 'package:nexa_music/core/models/track.dart';
import 'package:nexa_music/core/settings/settings_repository.dart';
import 'package:nexa_music/features/library/library_providers.dart';
import 'package:nexa_music/features/library/library_repository.dart';
import 'package:nexa_music/features/player/player_controller.dart';
import 'package:nexa_music/features/soundcloud/soundcloud_player_controller.dart';
import 'package:nexa_music/features/youtube/youtube_player_controller.dart';
import 'package:nexa_music/features/youtube/youtube_settings.dart';
import 'package:nexa_music/features/youtube/youtube_track.dart';
import 'package:nexa_music/integrations/youtube/youtube_embed.dart';
import 'package:path/path.dart' as p;

import '../test/helpers/wav.dart';

/// "Me at the zoo" - the first YouTube video (19 s, embeddable).
const String shortVideo = 'jNQXAC9IVRw';

/// The examples of SoundCloud's own Widget API documentation.
const String scTrack = 'https://soundcloud.com/forss/flickermood';
const String scSet = 'https://soundcloud.com/forss/sets/soulhack';
const String scProfile = 'https://soundcloud.com/forss';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  testWidgets('M-05 / M-06: Library -> YouTube -> SoundCloud -> Library; '
      'Continue; restored after a restart; SoundCloud set and profile', (
    tester,
  ) async {
    final temp = Directory.systemTemp.createTempSync('nexa_m05');
    final profile = Directory(p.join(temp.path, 'profile'))..createSync();
    final dbFile = File(p.join(profile.path, 'nexa_library.sqlite'));
    final result = <String, Object?>{};
    var db = AppDatabase(NativeDatabase(dbFile));

    /// A short tone as a real library song (in the database, as after an
    /// import), so the queue can restore it after a restart.
    Future<Track> tone(String name) async {
      final path = p.join(temp.path, '$name.wav');
      writeWav(path, title: name, seconds: 4, frequency: 440, sampleRate: 22050);
      final id = await db
          .into(db.tracks)
          .insert(
            TracksCompanion.insert(
              pathKey: p.normalize(path).toLowerCase(),
              path: path,
              title: name,
              artist: 'Test',
              album: name,
              fileSize: File(path).lengthSync(),
              fileModified: DateTime(2026),
              searchText: name.toLowerCase(),
              addedAt: DateTime(2026),
              durationMs: const Value(4000),
            ),
          );
      return (await LibraryRepository(db).getTrack(id))!;
    }

    final first = (await tester.runAsync(() => tone('First')))!;
    final last = (await tester.runAsync(() => tone('Last')))!;
    final video = youtubeTrack(videoId: shortVideo, title: 'Me at the zoo');
    final sound = soundcloudTrack(url: scTrack, title: 'Flickermood');

    List<Override> overrides(AppDatabase db) => [
      appDatabaseProvider.overrideWithValue(db),
      artworkDirProvider.overrideWith(
        (ref) async => p.join(profile.path, 'artwork'),
      ),
      autoRescanProvider.overrideWithValue(false),
      youtubeEmbedFactoryProvider.overrideWithValue(
        () async =>
            WindowsYouTubeEmbed(profileDir: p.join(profile.path, 'webview2')),
      ),
      soundcloudEmbedFactoryProvider.overrideWithValue(
        () async => WindowsYouTubeEmbed(
          profileDir: p.join(profile.path, 'webview2'),
          page: 'soundcloud.html',
        ),
      ),
    ];

    await tester.runAsync(
      () => SettingsRepository(db).setBool(SettingKeys.youtubeEnabled, true),
    );
    var container = ProviderContainer(overrides: overrides(db));
    PlayerState queue() => container.read(playerProvider);
    PlayerController ctl() => container.read(playerProvider.notifier);
    YtStatus yt() => container.read(youtubePlayerProvider);
    ScStatus sc() => container.read(soundcloudPlayerProvider);
    var continues = 0;

    Future<bool> waitFor(
      bool Function() test, {
      Duration timeout = const Duration(seconds: 30),
    }) async {
      final end = DateTime.now().add(timeout);
      while (DateTime.now().isBefore(end)) {
        if (test()) {
          return true;
        }
        // "Continue" when Windows did not let the player start by itself.
        if (container.read(playerProvider).waitingForUser) {
          continues++;
          await tester.runAsync(ctl().togglePlay);
        }
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)),
        );
        await tester.pump(const Duration(milliseconds: 50));
      }
      return test();
    }

    Future<void> app() async {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const NexaApp(ambientMotion: false),
        ),
      );
      await waitFor(() => container.read(youtubeSettingsProvider).loaded);
    }

    Future<void> close() async {
      await tester.runAsync(() async {
        await ctl().stop();
        await container.read(youtubePlayerProvider.notifier).close();
        await container.read(soundcloudPlayerProvider.notifier).close();
      });
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(() async {
        container.dispose();
        await Future<void>.delayed(const Duration(seconds: 1));
        await db.close();
      });
    }

    try {
      await app();
      await tester.runAsync(() => ctl().setVolume(0));

      // M-05: four sources' entries in one queue.
      await tester.runAsync(
        () => ctl().playTracks([first, video, sound, last]),
      );
      expect(
        await waitFor(() => queue().cursor == 0 && queue().playing),
        isTrue,
        reason: 'library song plays',
      );
      expect(
        await waitFor(
          () => queue().cursor == 1 && yt().state == YtState.playing,
          timeout: const Duration(seconds: 45),
        ),
        isTrue,
        reason: 'YouTube entry plays after the library song; '
            'yt state ${yt().state}, error ${yt().errorCode}, '
            'skipped ${queue().skipped}',
      );
      expect(queue().playing, isFalse, reason: 'never two sounds');
      result['youtube'] = 'played';
      expect(
        await waitFor(
          () => queue().cursor == 2 && sc().playing,
          timeout: const Duration(seconds: 60),
        ),
        isTrue,
        reason: 'SoundCloud entry plays after the video; ${sc().error} '
            '${sc().unavailable} skipped ${queue().skipped}',
      );
      expect(yt().state, isNot(YtState.playing));
      result['soundcloud'] = {'title': sc().title, 'user': sc().user};
      // Near its end (the widget's own seek), so the run stays short.
      expect(await waitFor(() => sc().duration != null), isTrue);
      await tester.runAsync(
        () => container.read(soundcloudPlayerProvider.notifier).embed!.send({
          'cmd': 'seek',
          'ms': sc().duration!.inMilliseconds - 5000,
        }),
      );
      expect(
        await waitFor(
          () => queue().cursor == 3 && queue().playing,
          timeout: const Duration(seconds: 40),
        ),
        isTrue,
        reason: 'library song after SoundCloud; skipped ${queue().skipped}',
      );
      expect(sc().playing, isFalse, reason: 'never two sounds');
      expect(queue().skipped, isEmpty);
      result['continues'] = continues;

      // The queue comes back after a restart (not playing).
      await close();
      db = AppDatabase(NativeDatabase(dbFile));
      container = ProviderContainer(overrides: overrides(db));
      await app();
      expect(
        await waitFor(() => queue().queue.length == 4),
        isTrue,
        reason: 'queue restored: ${queue().queue.length} entries',
      );
      expect(
        [for (final e in queue().queue) e.track.source],
        [
          TrackSource.local,
          TrackSource.youtube,
          TrackSource.soundcloud,
          TrackSource.local,
        ],
      );
      expect(queue().cursor, 3);
      expect(queue().playing, isFalse);
      result['restored'] = queue().queue.length;

      // M-06: a playlist (set) and a profile play in SoundCloud's widget.
      for (final link in [scSet, scProfile]) {
        await tester.runAsync(
          () => container
              .read(soundcloudPlayerProvider.notifier)
              .playLink(link),
        );
        expect(
          await waitFor(
            () => sc().playing && (sc().title ?? '').isNotEmpty,
            timeout: const Duration(seconds: 40),
          ),
          isTrue,
          reason: '$link: ${sc().error} ${sc().unavailable}',
        );
        result[link == scSet ? 'set' : 'profile'] = sc().title;
        await tester.runAsync(
          container.read(soundcloudPlayerProvider.notifier).pause,
        );
        await waitFor(() => !sc().playing, timeout: const Duration(seconds: 5));
      }
    } finally {
      debugPrint('M05RESULT ${jsonEncode(result)}');
      await close();
      try {
        temp.deleteSync(recursive: true);
      } on FileSystemException {
        // WebView2 may still hold its profile for a moment.
      }
    }
  });
}
