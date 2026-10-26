import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexa_music/app/strings.dart';
import 'package:nexa_music/core/database/app_database.dart';
import 'package:nexa_music/core/models/track.dart';
import 'package:nexa_music/features/library/library_providers.dart';
import 'package:nexa_music/features/player/player_controller.dart';
import 'package:nexa_music/features/youtube_prototype/youtube_embed.dart';
import 'package:nexa_music/features/youtube_prototype/youtube_prototype_controller.dart';
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
  final List<bool> pages = [];
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
  Future<void> openPage({bool identified = true}) async => pages.add(identified);
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

  setUp(() async {
    temp = Directory.systemTemp.createTempSync('nexa_yt_proto');
    db = memoryDatabase();
    engine = FakeEngine();
    embed = FakeEmbed();
    container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        ...testOverrides(engine: engine).skip(1),
        youtubeEmbedFactoryProvider.overrideWithValue(() async => embed),
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

  YouTubePrototypeController yt() =>
      container.read(youtubePrototypeProvider.notifier);
  YtStatus status() => container.read(youtubePrototypeProvider);
  PlayerController player() => container.read(playerProvider.notifier);

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

  test('open: the page is loaded from the application host; media keys are '
      'routed through the prototype', () async {
    await yt().open();
    expect(embed.initialized, isTrue);
    expect(embed.pages, [true], reason: 'identified (virtual host) page');
    expect(status().open, isTrue);
    expect(status().runtimeVersion, '140.0.0.0');
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

  test('YouTube and NEXA never play together', () async {
    await yt().open();
    await playLocal();
    expect(container.read(playerProvider).playing, isTrue);

    // Starting a video pauses NEXA first.
    await yt().load('M7lc1UVf-VE');
    expect(container.read(playerProvider).playing, isFalse);
    expect(embed.sent.last, containsPair('cmd', 'load'));
    expect(embed.sent.last, containsPair('play', true));
    embed.emit({'type': 'state', 'state': YtState.playing});
    expect(status().active, isTrue);

    // NEXA starts again -> YouTube is paused.
    await player().togglePlay();
    await pumpEventQueue();
    expect(container.read(playerProvider).playing, isTrue);
    expect(embed.commands.last, 'pause');

    // YouTube reports playing (e.g. the user pressed play inside the
    // YouTube player) -> NEXA is paused.
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
    expect(embed.sent.last['reason'], isNull);
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
  });

  test('media keys go to YouTube only while it is what the user played last',
      () async {
    await yt().open();
    final redirect = container.read(mediaKeyRedirectProvider)!;
    expect(await redirect('playPause'), isFalse, reason: 'NEXA handles it');

    await yt().load('M7lc1UVf-VE');
    embed.emit({'type': 'state', 'state': YtState.playing});
    expect(await redirect('playPause'), isTrue);
    expect(embed.commands.last, 'pause');
    embed.emit({'type': 'state', 'state': YtState.paused});
    expect(await redirect('playPause'), isTrue);
    expect(embed.commands.last, 'play');
    expect(await redirect('next'), isTrue, reason: 'no YouTube queue');

    await playLocal(); // NEXA played last again.
    expect(await redirect('playPause'), isFalse);
  });

  test('the Windows media overlay shows YouTube while YouTube was played '
      'last, so Windows sends Pause / Play for the right player', () async {
    MediaOverlay? overlay() => container.read(mediaOverlayOverrideProvider);
    await yt().open();
    expect(overlay(), isNull, reason: 'NEXA owns the overlay');
    final redirect = container.read(mediaKeyRedirectProvider)!;

    await yt().load('M7lc1UVf-VE');
    embed.emit({'type': 'state', 'state': YtState.playing});
    expect(overlay()?.playing, isTrue);
    expect(overlay()?.title, S.ytOverlayTitle);
    // Windows sends "Pause" for a playing overlay: YouTube pauses.
    expect(await redirect('pause'), isTrue);
    expect(embed.commands.last, 'pause');
    embed.emit({'type': 'state', 'state': YtState.paused});
    expect(overlay()?.playing, isFalse);
    expect(await redirect('play'), isTrue);
    expect(embed.commands.last, 'play');

    await playLocal();
    expect(overlay(), isNull, reason: 'NEXA played last again');
    await yt().play();
    expect(overlay(), isNotNull);
    await yt().close();
    expect(overlay(), isNull);
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
}
