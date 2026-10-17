import 'package:flutter/material.dart';

import '../../app/theme/tokens.dart';
import 'home_sections.dart';
import 'wave_hero.dart';

/// Home: NEXA Wave hero, "For Your Moment" and "Recently Played".
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
          WaveHero(animate: ambientMotion),
          const SizedBox(height: NexaSpace.xl - 4),
          const MomentSection(),
          const SizedBox(height: NexaSpace.xl - 4),
          const RecentlyPlayedSection(),
        ],
      ),
    );
  }
}
