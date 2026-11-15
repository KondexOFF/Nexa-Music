import 'dart:async';
import 'dart:ui' show AppExitResponse;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/home/home_page.dart';
import '../../features/home/home_side_panel.dart';
import '../../features/library/library_page.dart';
import '../../features/library/library_providers.dart';
import '../../features/library/playlist_page.dart';
import '../../features/player/player_controller.dart';
import '../../features/mix_engine/mix_engine_panel.dart';
import '../../features/nexa_wave/wave_page.dart';
import '../../features/discover/discover_page.dart';
import '../../features/pages/settings_page.dart';
import '../../features/player/now_playing_page.dart';
import '../../features/player/up_next_card.dart';
import '../../features/youtube/youtube_dock.dart';
import '../../features/youtube/youtube_player_controller.dart';
import '../../features/youtube/youtube_watch_page.dart';
import '../navigation.dart';
import '../theme/tokens.dart';
import 'bottom_player.dart';
import 'sidebar.dart';
import 'top_bar.dart';

/// Adaptive desktop shell: sidebar, top bar, page area, optional right panel
/// and the persistent bottom player.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key, this.ambientMotion = true});

  /// False disables decorative looping animation (tests).
  final bool ambientMotion;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  AppLifecycleListener? _exit;

  /// Closing the window: stop and release the audio players (libmpv) and
  /// the YouTube web view before the Flutter engine shuts down. Without this
  /// libmpv threads could still deliver events into the stopped engine and
  /// crash the process on exit (access violation seen 2026-10-29 when NEXA
  /// was closed while a song played).
  Future<AppExitResponse> _beforeExit() async {
    try {
      await ref
          .read(youtubePlayerProvider.notifier)
          .close()
          .timeout(const Duration(seconds: 2));
    } on Object {
      // Nothing open, or WebView2 already gone.
    }
    try {
      await ref
          .read(playbackEngineProvider)
          .dispose()
          .timeout(const Duration(seconds: 3));
    } on Object {
      // Exit anyway; the operating system frees what is left.
    }
    return AppExitResponse.exit;
  }

  @override
  void dispose() {
    _exit?.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    // Pick up new, changed and missing files from the library folders.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(libraryScanProvider.notifier).rescanIfLibraryExists();
        // Saved YouTube entries open in YouTube's own visible player.
        ref
            .read(externalTrackLauncherProvider.notifier)
            .set(
              (t) => openYouTubeWatch(
                ref,
                videoId: t.sourceTrackId,
                title: t.title,
                channel: t.artist,
              ),
            );
      }
    });
    bindMediaKeys(ref);
    _exit = AppLifecycleListener(onExitRequested: _beforeExit);
  }

  @override
  Widget build(BuildContext context) {
    final nav = ref.watch(navigationProvider);
    final panelWanted = ref.watch(rightPanelVisibleProvider);
    // Player notices (skipped missing file, playback error) as a snack bar.
    ref.listen(playerProvider.select((p) => p.noticeId), (previous, next) {
      final text = ref.read(playerProvider).notice;
      final messenger = ScaffoldMessenger.maybeOf(context);
      if (text != null && messenger != null) {
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(text),
              behavior: SnackBarBehavior.floating,
              width: 420,
            ),
          );
      }
    });

    if (ref.watch(miniWindowProvider)) {
      // Mini window: NEXA's window shrunk to the YouTube player, on top.
      return const Scaffold(
        backgroundColor: NexaColors.background,
        body: Stack(children: [YouTubeDock(fillWindow: true)]),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final rail = width < NexaBreakpoints.sidebarRail;
        final roomForPanel = width >= NexaBreakpoints.rightPanel;
        final showPanel = roomForPanel && panelWanted;
        final panelWidth = width >= NexaBreakpoints.wideRightPanel
            ? NexaSizes.rightPanelWide
            : NexaSizes.rightPanelNarrow;
        final onNowPlaying = nav.current == NexaDestination.nowPlaying;

        void toggleQueue() {
          if (roomForPanel) {
            ref.read(rightPanelVisibleProvider.notifier).toggle();
          } else {
            _scaffoldKey.currentState?.openEndDrawer();
          }
        }

        return Scaffold(
          key: _scaffoldKey,
          backgroundColor: NexaColors.background,
          endDrawer: Drawer(
            width: NexaSizes.rightPanelWide,
            backgroundColor: NexaColors.background,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 0, 0),
                child: onNowPlaying
                    ? const SingleChildScrollView(
                        key: PageStorageKey('drawer-queue'),
                        padding: EdgeInsets.only(right: NexaSpace.md),
                        child: UpNextCard(),
                      )
                    : const HomeSidePanel(),
              ),
            ),
          ),
          body: Stack(
            children: [
              Column(
            children: [
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    NexaSidebar(compact: rail),
                    Expanded(
                      child: Column(
                        children: [
                          const TopBar(),
                          Expanded(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(
                                  child: _PageArea(
                                    location: nav.location,
                                    inlineMixEngine: !showPanel,
                                    ambientMotion: widget.ambientMotion,
                                  ),
                                ),
                                AnimatedSize(
                                  duration: NexaMotion.normal,
                                  curve: NexaMotion.curve,
                                  alignment: Alignment.centerLeft,
                                  child: showPanel
                                      ? SizedBox(
                                          width: panelWidth,
                                          child: _RightPanel(
                                            nowPlaying: onNowPlaying,
                                          ),
                                        )
                                      : const SizedBox(width: 0),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              BottomPlayer(onToggleQueue: toggleQueue),
            ],
          ),
              // The one YouTube player above the pages (E2.6).
              YouTubeDock(
                bottomInset: NexaSizes.bottomPlayer,
                rightInset: showPanel ? panelWidth : 0,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PageArea extends StatelessWidget {
  const _PageArea({
    required this.location,
    required this.inlineMixEngine,
    required this.ambientMotion,
  });

  final NexaLocation location;
  final bool inlineMixEngine;
  final bool ambientMotion;

  Widget _page() => switch (location.destination) {
    NexaDestination.home => HomePage(ambientMotion: ambientMotion),
    NexaDestination.nowPlaying => NowPlayingPage(
      inlineMixEngine: inlineMixEngine,
    ),
    NexaDestination.wave => const WavePage(),
    NexaDestination.discover => const DiscoverPage(),
    NexaDestination.library => const LibraryPage(),
    NexaDestination.playlist => PlaylistPage(
      playlistId: location.playlistId ?? -1,
    ),
    NexaDestination.settings => const SettingsPage(),
    NexaDestination.youtube => const YouTubePage(),
  };

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: NexaMotion.normal,
      switchInCurve: NexaMotion.curve,
      switchOutCurve: Curves.easeIn,
      layoutBuilder: (current, previous) => Stack(
        fit: StackFit.expand,
        children: [...previous, ?current],
      ),
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.012),
            end: Offset.zero,
          ).animate(animation),
          child: child,
        ),
      ),
      child: KeyedSubtree(key: ValueKey(location), child: _page()),
    );
  }
}

class _RightPanel extends StatelessWidget {
  const _RightPanel({required this.nowPlaying});

  final bool nowPlaying;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: NexaMotion.normal,
      layoutBuilder: (current, previous) => Stack(
        fit: StackFit.expand,
        children: [...previous, ?current],
      ),
      child: nowPlaying
          ? const SingleChildScrollView(
              key: PageStorageKey('panel-mix'),
              padding: EdgeInsets.fromLTRB(0, 0, NexaSpace.md, NexaSpace.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  MixEnginePanel(),
                  SizedBox(height: NexaSpace.sm),
                  UpNextCard(maxItems: 4),
                ],
              ),
            )
          : const HomeSidePanel(key: ValueKey('panel-home')),
    );
  }
}
