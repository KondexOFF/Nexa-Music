import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexa_music/app/strings.dart';
import 'package:nexa_music/core/database/app_database.dart';
import 'package:nexa_music/core/models/listening.dart';
import 'package:nexa_music/core/models/track.dart';
import 'package:nexa_music/features/discover/catalog_providers.dart';
import 'package:nexa_music/features/library/library_providers.dart';
import 'package:nexa_music/features/player/playback_arbiter.dart';
import 'package:nexa_music/features/player/player_controller.dart';
import 'package:nexa_music/features/youtube/youtube_history.dart';
import 'package:nexa_music/features/youtube/youtube_player_controller.dart';
import 'package:nexa_music/integrations/youtube/youtube_embed.dart';
import 'package:path/path.dart' as p;

import 'helpers/fake_engine.dart';
import 'helpers/test_app.dart';

/// Stand-in for the WebView2 player page.
class FakeEmbed implements YouTubeEmbed {
  FakeEmbed({this.failInit});

  final Object? failInit;
  final _events = StreamController<Map<String, Object?>>.broadcast(sync: true);
  final _fullScreen = StreamController<bool>.broadcast(sync: true);
  final List<Map<String, Object?>> sent = [];
  int pages = 0;
  bool initialized = false;
  bool disposed = false;

  void emit(Map<String, Object?> e) => _events.add(e);
  void setFullScreen(bool on) => _fullScreen.add(on);
  List<String?> get commands => [for (final c in sent) c['cmd'] as String?];

  @override
  Stream<Map<String, Object?>> get events => _events.stream;
  @override
  Stream<bool> get fullScreen => _fullScreen.stream;
  @override
  Future<void> initialize() async {
    if (failInit != null) {
      throw failInit!;
    }
    initialized = true;
  }

  @override
  Future<void> openPage() async => pages++;
  @override
  Future<void> send(Map<String, Object?> command) async => sent.add(command);
  @override
  Widget view() => const ColoredBox(
    key: ValueKey('fake-youtube-view'),
    color: Colors.black,
  );
  @override
  Future<String?> runtimeVersion() async => '140.0.0.0';
  @override
  Future<void> dispose() async {
    disposed = true;
    await _events.close();
    await _fullScreen.close();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late FakeEngine engine;
  late FakeEmbed embed;
  late ProviderContainer container;
  late Directory temp;
  late List<String> opened;
  (String, String)? lookup;

  setUp(() async {
    temp = Directory.systemTemp.createTempSync('nexa_yt');
    db = memoryDatabase();
    engine = FakeEngine();
    embed = FakeEmbed();
    opened = [];
    lookup = null;
    container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        ...testOverrides(engine: engine).skip(1),
        youtubeEmbedFactoryProvider.overrideWithValue(() async => embed),
        youtubeTitleLookupProvider.overrideWithValue((id) async => lookup),
        linkOpenerProvider.overrideWithValue((url) async {
          opened.add(url);
          return true;
        }),
      ],
    );
    container.read(playerProvider);
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

  YouTubePlayerController yt() => container.read(youtubePlayerProvider.notifier);
  YtStatus status() => container.read(youtubePlayerProvider);
  PlayerController player() => container.read(playerProvider.notifier);
  MediaOverlay? overlay() => container.read(mediaOverlayOverrideProvider);

  Future<void> playLocal() async {
    final path = p.join(temp.path, 'song.mp3');
    File(path).writeAsStringSync('x');
    await player().playTracks([
      Track(
        id: 1,
        source: TrackSource.local,
        sourceTrackId: path,
        path: path,
        title: 'Local',
        artist: 'A',
        album: 'B',
        addedAt: DateTime(2026),
      ),
    ]);
    await pumpEventQueue();
  }

  test('open: the page comes from the application host; media keys go '
      'through the arbiter', () async {
    await yt().open();
    expect(embed.initialized, isTrue);
    expect(embed.pages, 1);
    expect(status().open, isTrue);
    expect(container.read(mediaKeyRedirectProvider), isNotNull);
    expect(youtubePlayerUrl, 'https://com.kondexoff.nexamusic/player.html');
  });

  test('no WebView2: a clear reason, nothing else changes', () async {
    embed = FakeEmbed(
      failInit: const YouTubeEmbedUnavailable('WebView2 missing'),
    );
    await yt().open();
    expect(status().unavailable, 'WebView2 missing');
    expect(embed.disposed, isTrue);
    expect(container.read(mediaKeyRedirectProvider), isNull);
    await yt().load('M7lc1UVf-VE');
    expect(embed.sent, isEmpty);
  });

  test('PlaybackArbiter: YouTube and NEXA never play together', () async {
    await yt().open();
    await playLocal();
    expect(container.read(playerProvider).playing, isTrue);

    // Watch: NEXA pauses first, then the video loads.
    await yt().load('M7lc1UVf-VE');
    expect(container.read(playerProvider).playing, isFalse);
    expect(embed.sent.last, containsPair('cmd', 'load'));
    expect(embed.sent.last, containsPair('play', true));
    embed.emit({'type': 'state', 'state': YtState.playing});
    expect(status().active, isTrue);
    expect(container.read(playbackArbiterProvider), PlaybackOwner.external);

    // NEXA starts again -> YouTube pauses.
    await player().togglePlay();
    await pumpEventQueue();
    expect(container.read(playerProvider).playing, isTrue);
    expect(embed.commands.last, 'pause');
    expect(container.read(playbackArbiterProvider), PlaybackOwner.nexa);

    // The user presses play inside YouTube's player -> NEXA pauses.
    embed.emit({'type': 'state', 'state': YtState.playing});
    await pumpEventQueue();
    expect(container.read(playerProvider).playing, isFalse);
  });

  test('a hidden / minimised window pauses YouTube', () async {
    await yt().open();
    await yt().load('M7lc1UVf-VE');
    embed.emit({'type': 'state', 'state': YtState.playing});
    final binding = TestWidgetsFlutterBinding.instance;
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    expect(embed.commands.last, 'load', reason: 'inactive: still visible');
    binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    expect(embed.commands.last, 'pause');
    binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  });

  test('closing the page pauses YouTube and releases the web view', () async {
    await yt().open();
    await yt().load('M7lc1UVf-VE');
    embed.emit({'type': 'state', 'state': YtState.playing});
    await yt().close();
    expect(embed.commands.last, 'pause');
    expect(embed.disposed, isTrue);
    expect(status().open, isFalse);
    expect(container.read(mediaKeyRedirectProvider), isNull);
    expect(overlay(), isNull);
  });

  test('media keys and the Windows overlay follow the player started last',
      () async {
    await yt().open();
    final redirect = container.read(mediaKeyRedirectProvider)!;
    expect(await redirect('playPause'), isFalse, reason: 'NEXA handles it');
    expect(overlay(), isNull, reason: 'NEXA owns the overlay');

    lookup = ('Demo video', 'Google for Developers');
    await yt().load('M7lc1UVf-VE');
    await pumpEventQueue();
    embed.emit({'type': 'state', 'state': YtState.playing});
    expect(overlay()?.playing, isTrue);
    expect(overlay()?.title, 'Demo video');
    expect(overlay()?.artist, 'Google for Developers');
    // Windows sends "Pause" for a playing overlay: YouTube pauses.
    expect(await redirect('pause'), isTrue);
    expect(embed.commands.last, 'pause');
    embed.emit({'type': 'state', 'state': YtState.paused});
    expect(overlay()?.playing, isFalse);
    expect(await redirect('play'), isTrue);
    expect(embed.commands.last, 'play');
    embed.emit({'type': 'state', 'state': YtState.playing});
    expect(await redirect('playPause'), isTrue);
    expect(embed.commands.last, 'pause');
    expect(await redirect('next'), isTrue, reason: 'no YouTube queue');

    await playLocal();
    expect(overlay(), isNull, reason: 'NEXA played last again');
    expect(await redirect('playPause'), isFalse);
  });

  test('a title from search is kept; a pasted link gets oEmbed title or the '
      'plain "YouTube video"', () async {
    await yt().open();
    await yt().load('aaaaaaaaaaa', title: 'From search', channel: 'C');
    expect(status().title, 'From search');
    await yt().load('bbbbbbbbbbb');
    await pumpEventQueue();
    expect(status().title, isNull);
    expect(yt().overlay.title, S.ytOverlayTitle);
  });

  test('links in the player open in the system browser; the page comes back '
      'with the same video, paused', () async {
    await yt().open();
    await yt().load('M7lc1UVf-VE');
    embed.emit({'type': 'api'});
    embed.emit({
      'type': 'external',
      'url': 'https://www.youtube.com/watch?v=M7lc1UVf-VE',
    });
    await pumpEventQueue();
    expect(opened, ['https://www.youtube.com/watch?v=M7lc1UVf-VE']);
    embed.emit({'type': 'external', 'url': 'file:///C:/x'});
    await pumpEventQueue();
    expect(opened, hasLength(1), reason: 'only web pages');
    embed.emit({'type': 'api'}); // the player page reloaded
    expect(embed.sent.last, containsPair('cmd', 'load'));
    expect(embed.sent.last, containsPair('play', false));
    expect(isExternalPage(youtubePlayerUrl), isFalse);
    expect(isExternalPage('https://www.youtube.com/'), isTrue);
  });

  test('player errors become plain messages', () async {
    await yt().open();
    embed.emit({'type': 'error', 'code': 153});
    expect(status().errorCode, 153);
    expect(youtubeErrorText(153), S.ytError153);
    expect(youtubeErrorText(101), S.ytErrorNotEmbeddable);
    expect(youtubeErrorText(150), S.ytErrorNotEmbeddable);
    expect(youtubeErrorText(100), S.ytError100);
    expect(youtubeErrorText(2), S.ytError2);
    expect(youtubeErrorText(5), S.ytError5);
    expect(youtubeErrorText(42), contains('42'));
    await yt().load('M7lc1UVf-VE');
    expect(status().errorCode, isNull, reason: 'a new video clears it');
    embed.emit({'type': 'apiLoadError'});
    expect(status().apiLoadFailed, isTrue);
    embed.emit({'type': 'autoplayBlocked'});
    expect(status().autoplayBlocked, isTrue);
    embed.emit({'type': 'state', 'state': YtState.playing});
    expect(status().autoplayBlocked, isFalse);
    embed.emit({'type': 'page', 'origin': 'https://com.kondexoff.nexamusic'});
    expect(status().pageOrigin, 'https://com.kondexoff.nexamusic');
  });

  test('YouTube full screen is passed to the page', () async {
    await yt().open();
    embed.setFullScreen(true);
    expect(status().fullScreen, isTrue);
    embed.setFullScreen(false);
    expect(status().fullScreen, isFalse);
  });

  test('watching YouTube writes nothing: no history, no queue', () async {
    await yt().open();
    await yt().load('M7lc1UVf-VE');
    embed.emit({'type': 'state', 'state': YtState.playing});
    embed.emit({'type': 'state', 'state': YtState.ended});
    await yt().close();
    await pumpEventQueue();
    expect(await db.select(db.listeningEvents).get(), isEmpty);
    expect(container.read(playerProvider).queue, isEmpty);
    expect(engine.loads, isEmpty, reason: 'YouTube never uses the engine');
  });

  test('E2.7b: a watched video is passed to the history rule with its '
      'position; resuming loads it from there', () async {
    final calls = <Map<String, Object?>>[];
    final c = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        ...testOverrides(engine: engine).skip(1),
        youtubeEmbedFactoryProvider.overrideWithValue(() async => embed),
        youtubeTitleLookupProvider.overrideWithValue((id) async => null),
        youtubeHistoryProvider.overrideWith((ref) => _SpyHistory(ref, calls)),
      ],
    );
    addTearDown(c.dispose);
    final ctl = c.read(youtubePlayerProvider.notifier);
    await ctl.open();
    await ctl.load('M7lc1UVf-VE', title: 'Talk', channel: 'Chan');
    embed.emit({'type': 'state', 'state': YtState.playing, 'time': 1});
    embed.emit({
      'type': 'tick',
      'state': YtState.playing,
      'time': 754.2,
      'duration': 2400,
    });
    // Another video ends the first listening.
    await ctl.load('dQw4w9WgXcQ');
    expect(calls, hasLength(1));
    expect(calls.single['videoId'], 'M7lc1UVf-VE');
    expect(calls.single['listened'], const Duration(milliseconds: 754200));
    expect(calls.single['duration'], const Duration(minutes: 40));
    expect(calls.single['reason'], EndReason.skipped);
    expect(calls.single['title'], 'Talk');

    // Only started: nothing to keep.
    embed.emit({'type': 'state', 'state': YtState.playing, 'time': 2});
    await ctl.close();
    expect(calls, hasLength(1));

    await ctl.watch('M7lc1UVf-VE', start: const Duration(seconds: 754));
    expect(embed.sent.last['start'], 754);
  });
}

class _SpyHistory extends YouTubeHistoryRecorder {
  _SpyHistory(super.ref, this.calls);

  final List<Map<String, Object?>> calls;

  @override
  Future<YtHistoryOutcome> record({
    required String videoId,
    required DateTime startedAt,
    required Duration listened,
    required EndReason reason,
    Duration? duration,
    String? title,
    String? channel,
  }) async {
    calls.add({
      'videoId': videoId,
      'listened': listened,
      'duration': duration,
      'reason': reason,
      'title': title,
    });
    return YtHistoryOutcome.recorded;
  }
}
