import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:path/path.dart' as p;
import 'package:webview_flutter_windows/webview_flutter_windows.dart';

/// E2.0 prototype: the official YouTube IFrame Player in an embedded web
/// view. The page `assets/youtube/player.html` holds nothing but the
/// YouTube player; this interface sends it the documented IFrame API
/// commands and receives its events. Tests use a fake.
abstract interface class YouTubeEmbed {
  /// Events from the page: `{type: page | api | apiLoadError | ready |
  /// state | error | autoplayBlocked | quality | tick | info, ...}`.
  Stream<Map<String, Object?>> get events;

  /// True while YouTube's own full-screen button is active.
  Stream<bool> get fullScreen;

  /// Prepares the web view. Throws [YouTubeEmbedUnavailable].
  Future<void> initialize();

  /// Loads the player page. [identified]: served from the application's
  /// virtual host (normal case). False only for the prototype's negative
  /// control: the same page without an origin, which YouTube should refuse
  /// with error 153.
  Future<void> openPage({bool identified = true});

  /// One IFrame API command: `{cmd: load | play | pause | stop | mute |
  /// unmute | info, ...}`.
  Future<void> send(Map<String, Object?> command);

  /// The visible web view.
  Widget view();

  /// WebView2 Runtime version (null when missing).
  Future<String?> runtimeVersion();

  Future<void> dispose();
}

class YouTubeEmbedUnavailable implements Exception {
  const YouTubeEmbedUnavailable(this.reason);

  final String reason;

  @override
  String toString() => reason;
}

/// The application identity YouTube receives as HTTP Referer: a stable
/// reverse-DNS id of NEXA Music, without version or architecture
/// (Required Minimum Functionality, "Referer format").
const String youtubeAppHost = 'com.kondexoff.nexamusic';

/// URL of the player page on the virtual host.
const String youtubePlayerUrl = 'https://$youtubeAppHost/player.html';

/// Windows: Microsoft Edge WebView2 through `webview_flutter_windows`.
class WindowsYouTubeEmbed implements YouTubeEmbed {
  WindowsYouTubeEmbed({required this.profileDir});

  /// WebView2 profile (cookies, cache) inside NEXA's own data folder, so
  /// nothing is written next to the Portable exe.
  final String profileDir;

  final WebviewController _controller = WebviewController();
  final _events = StreamController<Map<String, Object?>>.broadcast();
  final List<StreamSubscription<Object?>> _subs = [];
  static bool _environmentSet = false;

  @override
  Stream<Map<String, Object?>> get events => _events.stream;

  @override
  Stream<bool> get fullScreen => _controller.containsFullScreenElementChanged;

  /// Folder of the bundled player page (inside the build's flutter_assets).
  static String assetFolder() => p.join(
    File(Platform.resolvedExecutable).parent.path,
    'data',
    'flutter_assets',
    'assets',
    'youtube',
  );

  @override
  Future<String?> runtimeVersion() async {
    try {
      return await WebviewController.getWebViewVersion();
    } on Object {
      return null;
    }
  }

  @override
  Future<void> initialize() async {
    if (!Platform.isWindows) {
      throw const YouTubeEmbedUnavailable('Only on Windows in this prototype.');
    }
    final version = await runtimeVersion();
    if (version == null) {
      throw const YouTubeEmbedUnavailable(
        'Microsoft Edge WebView2 Runtime is not installed.',
      );
    }
    if (!File(p.join(assetFolder(), 'player.html')).existsSync()) {
      throw const YouTubeEmbedUnavailable('Player page missing in the build.');
    }
    if (!_environmentSet) {
      try {
        await Directory(profileDir).create(recursive: true);
        await WebviewController.initializeEnvironment(userDataPath: profileDir);
        _environmentSet = true;
      } on PlatformException {
        // Already created by an earlier controller in this process.
        _environmentSet = true;
      }
    }
    await _controller.initialize();
    if (!_controller.value.isInitialized) {
      throw const YouTubeEmbedUnavailable('WebView2 could not be started.');
    }
    // YouTube links in the player (logo, title) open YouTube in its own
    // window - the player's functions stay as YouTube made them.
    await _controller.setPopupWindowPolicy(WebviewPopupWindowPolicy.allow);
    await _controller.setDefaultContextMenusEnabled(false);
    await _controller.setDevToolsEnabled(false);
    await _controller.setZoomControlEnabled(false);
    await _controller.addVirtualHostNameMapping(
      youtubeAppHost,
      assetFolder(),
      WebviewHostResourceAccessKind.deny,
    );
    _subs.add(
      _controller.webMessage.listen((message) {
        if (message is Map) {
          _events.add(message.cast<String, Object?>());
        }
      }, onError: (Object _) {}),
    );
  }

  @override
  Future<void> openPage({bool identified = true}) async {
    if (identified) {
      await _controller.loadUrl(youtubePlayerUrl);
    } else {
      final html = await File(
        p.join(assetFolder(), 'player.html'),
      ).readAsString();
      await _controller.loadStringContent(html);
    }
  }

  @override
  Future<void> send(Map<String, Object?> command) =>
      _controller.postWebMessage(jsonEncode(command));

  @override
  Widget view() => Webview(_controller);

  @override
  Future<void> dispose() async {
    for (final s in _subs) {
      unawaited(s.cancel());
    }
    _subs.clear();
    await _events.close();
    await _controller.dispose();
  }
}
