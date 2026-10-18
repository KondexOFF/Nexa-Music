import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/home/home_page.dart';
import '../../features/home/home_side_panel.dart';
import '../../features/library/library_page.dart';
import '../../features/library/library_providers.dart';
import '../../features/library/playlist_page.dart';
import '../../features/player/player_controller.dart';
import '../../features/mix_engine/mix_engine_panel.dart';
import '../../features/pages/planned_page.dart';
import '../../features/pages/settings_page.dart';
import '../../features/player/now_playing_page.dart';
import '../../features/player/up_next_card.dart';
import '../navigation.dart';
import '../strings.dart';
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

  @override
  void initState() {
    super.initState();
    // Pick up new, changed and missing files from the library folders.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(libraryScanProvider.notifier).rescanIfLibraryExists();
      }
    });
    bindMediaKeys(ref);
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
          body: Column(
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
    NexaDestination.wave => const PlannedPage(
      overline: S.navWave,
      icon: Icons.waves_rounded,
      heading: S.waveHeading,
      body: S.waveBody,
      phase: S.phase5,
    ),
    NexaDestination.discover => const PlannedPage(
      overline: S.navDiscover,
      icon: Icons.explore_outlined,
      heading: S.discoverHeading,
      body: S.discoverBody,
      phase: S.phase6,
    ),
    NexaDestination.library => const LibraryPage(),
    NexaDestination.playlist => PlaylistPage(
      playlistId: location.playlistId ?? -1,
    ),
    NexaDestination.settings => const SettingsPage(),
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
