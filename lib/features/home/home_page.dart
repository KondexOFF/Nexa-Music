import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/navigation.dart';
import '../../app/strings.dart';
import '../../app/theme/nexa_theme.dart';
import '../../app/theme/tokens.dart';
import '../../ui/nexa_widgets.dart';
import '../profile/profile.dart';
import '../profile/profile_avatar.dart';
import '../profile/profile_page.dart' show greetingWithName;
import 'home_sections.dart';
import 'recent_section.dart';
import 'wave_hero.dart';

/// Home: NEXA Wave hero, your playlists, Continue listening and Recently
/// Played.
class HomePage extends StatelessWidget {
  const HomePage({super.key, this.ambientMotion = true});

  final bool ambientMotion;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      key: const PageStorageKey('page-home'),
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const HomeGreeting(),
          const SizedBox(height: NexaSpace.md),
          WaveHero(animate: ambientMotion),
          const SizedBox(height: NexaSpace.xl - 4),
          const PlaylistsSection(),
          const SizedBox(height: NexaSpace.xl - 4),
          const RecentlyPlayedSection(),
        ],
      ),
    );
  }
}

/// "Good evening, Dmytro" with the profile picture (D-042); opens the
/// profile.
class HomeGreeting extends ConsumerWidget {
  const HomeGreeting({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nickname = ref.watch(profileProvider.select((p) => p.nickname));
    return Align(
      alignment: Alignment.centerLeft,
      child: NexaTappable(
        key: const ValueKey('home-greeting'),
        onTap: () =>
            ref.read(navigationProvider.notifier).go(NexaDestination.profile),
        semanticLabel: S.profileOpen,
        borderRadius: BorderRadius.circular(28),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(2, 2, 14, 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const ProfileAvatar(size: 40),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  greetingWithName(DateTime.now(), nickname),
                  style: NexaText.h2,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
