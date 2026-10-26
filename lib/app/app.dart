import 'package:flutter/material.dart';

import 'shell/app_shell.dart';
import 'shell/keyboard_shortcuts.dart';
import 'strings.dart';
import 'theme/nexa_theme.dart';

/// The app's navigator (the E2.0 prototype self-test opens its page with it).
final GlobalKey<NavigatorState> nexaNavigatorKey = GlobalKey<NavigatorState>();

/// Root widget of NEXA Music. Expects a ProviderScope above it.
class NexaApp extends StatelessWidget {
  const NexaApp({super.key, this.ambientMotion = true});

  /// False disables decorative looping animation (tests).
  final bool ambientMotion;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: nexaNavigatorKey,
      title: S.appTitle,
      debugShowCheckedModeBanner: false,
      theme: buildNexaTheme(),
      home: KeyboardShortcuts(child: AppShell(ambientMotion: ambientMotion)),
    );
  }
}
