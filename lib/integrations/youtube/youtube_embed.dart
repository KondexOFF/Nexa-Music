import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:path/path.dart' as p;
import 'package:webview_flutter_windows/webview_flutter_windows.dart';

/// The official YouTube IFrame Player in an embedded web view (E2.1,
/// verified by the E2.0 prototype). The page `assets/youtube/player.html`
/// holds nothing but YouTube's player; this interface sends it documented
/// IFrame API commands and receives its events. Tests use a fake.
abstract interface class YouTubeEmbed {
  /// Events from the page: `{type: page | api | apiLoadError | ready |
  /// state | error | autoplayBlocked | quality | tick | info, ...}` and
  /// `{type: external, url}` when a link in the player asks to leave the
  /// player page (it is then opened in the system browser instead).
  Stream<Map<String, Object?>> get events;

  /// True while YouTube's own full-screen button is active.
  Stream<bool> get fullScreen;

  /// Prepares the web view. Throws [YouTubeEmbedUnavailable].
  Future<void> initialize();

  /// Loads the player page from the application's virtual host.
  Future<void> openPage();

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
/// (Required Minimum Functionality, "Referer format"). Without it YouTube
/// answers with error 153 (verified in E2.0).
const String youtubeAppHost = 'com.kondexoff.nexamusic';

/// URL of the player page on the virtual host.
const String youtubePlayerUrl = 'https://$youtubeAppHost/player.html';

/// True for a page outside the player page (a YouTube / Google link the
/// user clicked in the player).
bool isExternalPage(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null || (uri.scheme != 'https' && uri.scheme != 'http')) {
    return false;
  }
  return uri.host.toLowerCase() != youtubeAppHost;
}

/// Windows: Microsoft Edge WebView2 through `webview_flutter_windows`.
class WindowsYouTubeEmbed implements YouTubeEmbed {
  WindowsYouTubeEmbed({required this.profileDir, this.page = 'player.html'});

  /// WebView2 profile (cookies, cache) inside NEXA's own data folder, so
  /// nothing is written next to the Portable exe.
  final String profileDir;

  /// The bundled page: `player.html` (YouTube) or `soundcloud.html`
  /// (SoundCloud's widget, E3) - same virtual host, same rules.
  final String page;

  String get _pageUrl => 'https://$youtubeAppHost/$page';

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
      throw const YouTubeEmbedUnavailable('YouTube needs Windows.');
    }
    final version = await runtimeVersion();
    if (version == null) {
      throw const YouTubeEmbedUnavailable(
        'Microsoft Edge WebView2 Runtime is not installed.',
      );
    }
    if (!File(p.join(assetFolder(), page)).existsSync()) {
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
    // Links in the player (title, logo, "Watch on YouTube") would open a new
    // web view window. They are shown in this view for a moment instead and
    // handed to the system browser (see [_onUrl]); the player page returns.
    await _controller.setPopupWindowPolicy(WebviewPopupWindowPolicy.sameWindow);
    await _controller.setDefaultContextMenusEnabled(false);
    await _controller.setDevToolsEnabled(false);
    await _controller.setZoomControlEnabled(false);
    await _controller.addVirtualHostNameMapping(
      youtubeAppHost,
      assetFolder(),
      WebviewHostResourceAccessKind.deny,
    );
    _subs
      ..add(
        _controller.webMessage.listen((message) {
          if (message is Map && !_events.isClosed) {
            _events.add(message.cast<String, Object?>());
          }
        }, onError: (Object _) {}),
      )
      ..add(_controller.url.listen(_onUrl, onError: (Object _) {}));
  }

  Future<void> _onUrl(String url) async {
    if (!isExternalPage(url) || _events.isClosed) {
      return;
    }
    _events.add({'type': 'external', 'url': url});
    try {
      await _controller.stop();
      await _controller.loadUrl(_pageUrl);
    } on Object {
      // The page could not be restored; the controller reloads on demand.
    }
  }

  @override
  Future<void> openPage() => _controller.loadUrl(_pageUrl);

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
