import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nexa_music/core/database/app_database.dart';
import 'package:nexa_music/core/models/track.dart';
import 'package:nexa_music/features/library/library_providers.dart';
import 'package:nexa_music/features/nexa_dna/dna_providers.dart';
import 'package:nexa_music/features/player/playback_arbiter.dart';
import 'package:nexa_music/features/player/player_controller.dart';
import 'package:nexa_music/features/soundcloud/soundcloud_player_controller.dart';
import 'package:nexa_music/features/youtube/youtube_player_controller.dart';
import 'package:nexa_music/features/youtube/youtube_track.dart';
import 'package:nexa_music/integrations/soundcloud/soundcloud_link.dart';
import 'package:path/path.dart' as p;

import 'helpers/fake_engine.dart';
import 'helpers/test_app.dart';
import 'youtube_player_test.dart' show FakeEmbed;

/// E3 (CR-002): SoundCloud links in SoundCloud's official widget - one
/// sound at a time with NEXA and YouTube, in the one queue, never in
/// NEXA Wave.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('links', () {
    String? url(String s) => switch (SoundCloudLink.parse(s)) {
      SoundCloudTrackLink(:final url) => url,
      _ => null,
    };

    test('track links become one canonical link', () {
      const canonical = 'https://soundcloud.com/artist-name/track-name';
      expect(url('https://soundcloud.com/artist-name/track-name'), canonical);
      expect(url('soundcloud.com/artist-name/track-name?si=abc&utm=x'), canonical);
      expect(url('https://m.soundcloud.com/artist-name/track-name/'), canonical);
      expect(url('https://www.soundcloud.com/artist-name/track-name'), canonical);
      expect(
        url('https://soundcloud.com/artist-name/track-name/s-AbCdE'),
        'https://soundcloud.com/artist-name/track-name/s-AbCdE',
        reason: 'private link keeps its token',
      );
    });

    test('other links are named, never played', () {
      expect(SoundCloudLink.parse('https://soundcloud.com/a/sets/b'),
          isA<SoundCloudSet>());
      expect(SoundCloudLink.parse('https://soundcloud.com/artist'),
          isA<SoundCloudProfile>());
      expect(SoundCloudLink.parse('https://soundcloud.com/artist/tracks'),
          isA<SoundCloudProfile>());
      expect(SoundCloudLink.parse('https://on.soundcloud.com/xYz'),
          isA<SoundCloudShortLink>());
      expect(SoundCloudLink.parse('https://soundcloud.com/discover/sets/x'),
          isA<SoundCloudNotALink>());
      expect(SoundCloudLink.parse('https://example.org/a/b'),
          isA<SoundCloudNotALink>());
      expect(SoundCloudLink.parse('hello'), isA<SoundCloudNotALink>());
    });

    test('oEmbed gives title and uploader', () async {
      final oembed = SoundCloudOEmbed(
        MockClient(
          (r) async => http.Response(
            '{"title":"Night Drive by Some Artist","author_name":"Some Artist",'
            '"thumbnail_url":"https://i1.sndcdn.com/a.jpg"}',
            200,
          ),
        ),
      );
      final meta = await oembed.fetch('https://soundcloud.com/a/b');
      expect(meta?.title, 'Night Drive');
      expect(meta?.author, 'Some Artist');
      expect(meta?.thumbnail, 'https://i1.sndcdn.com/a.jpg');
      final gone = SoundCloudOEmbed(
        MockClient((r) async => http.Response('', 404)),
      );
      expect(await gone.fetch('https://soundcloud.com/a/b'), isNull);
    });
  });

  group('widget', () {
    late AppDatabase db;
    late FakeEngine engine;
    late FakeEmbed sc;
    late FakeEmbed ytEmbed;
    late ProviderContainer container;
    late Directory temp;

    setUp(() async {
      temp = Directory.systemTemp.createTempSync('nexa_sc');
      db = memoryDatabase();
      engine = FakeEngine();
      sc = FakeEmbed();
      ytEmbed = FakeEmbed();
      container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          ...testOverrides(engine: engine).skip(1),
          // A new web view each time the widget opens (like WebView2).
          soundcloudEmbedFactoryProvider.overrideWithValue(
            () async => sc = FakeEmbed(),
          ),
          youtubeEmbedFactoryProvider.overrideWithValue(() async => ytEmbed),
          youtubeTitleLookupProvider.overrideWithValue((id) async => null),
        ],
      );
      container.read(playerProvider);
      container.read(externalQueuePlayerProvider.notifier)
        ..set(TrackSource.youtube, container.read(youtubePlayerProvider.notifier))
        ..set(
          TrackSource.soundcloud,
          container.read(soundcloudPlayerProvider.notifier),
        );
      await pumpEventQueue();
    });

    tearDown(() async {
      container.dispose();
      await pumpEventQueue();
      await db.close();
      try {
        temp.deleteSync(recursive: true);
      } on FileSystemException {
        // Best effort on Windows.
      }
    });

    SoundCloudPlayerController ctl() =>
        container.read(soundcloudPlayerProvider.notifier);
    ScStatus status() => container.read(soundcloudPlayerProvider);
    PlayerController player() => container.read(playerProvider.notifier);
    PlayerState state() => container.read(playerProvider);

    Track local(String name) {
      final path = p.join(temp.path, '$name.mp3');
      File(path).writeAsStringSync('x');
      return Track(
        id: name.hashCode & 0xffff,
        source: TrackSource.local,
        sourceTrackId: path,
        path: path,
        title: name,
        artist: 'A',
        album: 'B',
        addedAt: DateTime(2026),
      );
    }

    final track = soundcloudTrack(
      url: 'https://soundcloud.com/artist/night-drive',
      title: 'Night Drive',
      user: 'Artist',
    );

    test('plays in the widget; NEXA and YouTube pause for it', () async {
      await player().playTracks([local('Song')]);
      expect(state().playing, isTrue);

      await ctl().playLink(track.path, title: 'Night Drive', user: 'Artist');
      expect(sc.sent.last, {
        'cmd': 'load',
        'url': 'https://soundcloud.com/artist/night-drive',
        'play': true,
      });
      sc.emit({'type': 'state', 'playing': true});
      await pumpEventQueue();
      expect(state().playing, isFalse, reason: 'one sound at a time');
      expect(status().playing, isTrue);
      expect(container.read(mediaOverlayOverrideProvider)?.title, 'Night Drive');

      // YouTube starts: SoundCloud pauses.
      final yt = container.read(youtubePlayerProvider.notifier);
      await yt.watch('dQw4w9WgXcQ');
      ytEmbed.emit({'type': 'state', 'state': 1});
      await pumpEventQueue();
      expect(sc.commands.last, 'pause');
      expect(engine.activeFiles, 0);
    });

    test('in the one queue: Local -> SoundCloud -> YouTube -> Local', () async {
      final a = local('A');
      final b = local('B');
      final video = youtubeTrack(videoId: 'dQw4w9WgXcQ', title: 'Video');
      await player().playTracks([a, track, video, b]);
      engine.finishCurrent();
      await pumpEventQueue();
      expect(state().current!.title, 'Night Drive');
      expect(sc.sent.last['url'], track.path);
      expect(engine.preparedPath, isNull, reason: 'no crossfade');

      sc.emit({'type': 'state', 'playing': true});
      expect(state().sounding, isTrue);
      sc.emit({'type': 'finish'});
      await pumpEventQueue();
      expect(state().current!.title, 'Video');
      expect(ytEmbed.sent.any((c) => c['videoId'] == 'dQw4w9WgXcQ'), isTrue);

      ytEmbed.emit({'type': 'state', 'state': 1});
      ytEmbed.emit({'type': 'state', 'state': 0});
      await pumpEventQueue();
      expect(state().current!.title, 'B');
      expect(engine.loads.last, b.path);
    });

    test('a track SoundCloud cannot play is skipped with its reason',
        () async {
      final b = local('B');
      await player().playTracks([track, b]);
      final uid = state().currentEntry!.uid;
      sc.emit({'type': 'error'});
      await pumpEventQueue();
      expect(state().skipped[uid], isNotEmpty);
      expect(state().current!.title, 'B');
    });

    test('autoplay blocked: the queue waits for Continue', () async {
      await player().playTracks([track, local('B')]);
      sc.emit({'type': 'autoplayBlocked'});
      expect(status().autoplayBlocked, isTrue);
      expect(state().waitingForUser, isTrue);
      await player().togglePlay();
      expect(sc.commands.last, 'play');
      expect(state().current!.title, 'Night Drive');
    });

    test('kept in the history only when history is on; never in Wave',
        () async {
      await ctl().playLink(track.path, title: 'Night Drive', user: 'Artist');
      sc.emit({'type': 'state', 'playing': true});
      sc.emit({'type': 'progress', 'position': 60000});
      await ctl().close();
      await pumpEventQueue();
      final taste = container.read(tasteRepositoryProvider);
      expect(await taste.eventCount(), 0, reason: 'history is off');

      await container.read(dnaSettingsProvider.notifier).setHistoryConsent(true);
      await ctl().playLink(track.path, title: 'Night Drive', user: 'Artist');
      sc.emit({'type': 'state', 'playing': true});
      sc.emit({'type': 'progress', 'position': 60000});
      await ctl().close();
      await pumpEventQueue();
      expect(await taste.eventCount(), 1);
      expect(await taste.trackStats(), isEmpty, reason: 'not NEXA Wave');
      final recent = await taste.watchRecent().first;
      expect(recent.single.track.source, TrackSource.soundcloud);
      expect(recent.single.track.title, 'Night Drive');
    });

    test('closing the widget frees the keys; the queue stops waiting',
        () async {
      await player().playTracks([track]);
      sc.emit({'type': 'state', 'playing': true});
      await ctl().close();
      expect(sc.disposed, isTrue);
      expect(state().externalActive, isFalse);
      expect(container.read(playbackArbiterProvider), PlaybackOwner.nexa);
      expect(container.read(mediaOverlayOverrideProvider), isNull);
    });
  });
}
