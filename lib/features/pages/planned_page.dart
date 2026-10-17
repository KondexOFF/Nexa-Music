import 'package:flutter/material.dart';

import '../../app/strings.dart';
import '../../app/theme/nexa_theme.dart';
import '../../app/theme/tokens.dart';
import '../../ui/nexa_widgets.dart';

/// Honest page for a section whose functionality belongs to a later phase.
class PlannedPage extends StatelessWidget {
  const PlannedPage({
    super.key,
    required this.overline,
    required this.icon,
    required this.heading,
    required this.body,
    required this.phase,
  });

  final String overline;
  final IconData icon;
  final String heading;
  final String body;
  final String phase;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      key: PageStorageKey('page-$overline'),
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(overline.toUpperCase(), style: NexaText.overline),
          const SizedBox(height: 24),
          NexaPanel(
            padding: const EdgeInsets.all(32),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: NexaColors.accentSoft,
                    border: Border.all(color: NexaColors.border),
                  ),
                  child: Icon(icon, size: 30, color: NexaColors.accent),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(heading, style: NexaText.h2.copyWith(fontSize: 24)),
                      const SizedBox(height: 10),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 620),
                        child: Text(body, style: NexaText.bodySecondary),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          const Text(S.plannedFor, style: NexaText.caption),
                          const SizedBox(width: 10),
                          StatusBadge.phase(phase),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
