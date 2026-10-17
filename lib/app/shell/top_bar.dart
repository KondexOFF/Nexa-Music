import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ui/nexa_widgets.dart';
import '../navigation.dart';
import '../strings.dart';
import '../theme/nexa_theme.dart';
import '../theme/tokens.dart';

/// Greeting for the current time of day (no accounts in NEXA Music).
String greetingFor(DateTime time) {
  final h = time.hour;
  if (h >= 5 && h < 12) {
    return S.greetingMorning;
  }
  if (h >= 12 && h < 18) {
    return S.greetingAfternoon;
  }
  if (h >= 18 && h < 23) {
    return S.greetingEvening;
  }
  return S.greetingNight;
}

class TopBar extends ConsumerWidget {
  const TopBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nav = ref.watch(navigationProvider);
    final controller = ref.read(navigationProvider.notifier);
    return SizedBox(
      height: NexaSizes.topBar,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
        child: Row(
          children: [
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 840),
                  child: const _SearchPlaceholder(),
                ),
              ),
            ),
            const SizedBox(width: 16),
            NexaIconButton(
              icon: Icons.chevron_left_rounded,
              label: S.navBack,
              iconSize: 24,
              onPressed: nav.canGoBack ? controller.goBack : null,
            ),
            NexaIconButton(
              icon: Icons.chevron_right_rounded,
              label: S.navForward,
              iconSize: 24,
              onPressed: nav.canGoForward ? controller.goForward : null,
            ),
            const SizedBox(width: 24),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  greetingFor(DateTime.now()),
                  style: NexaText.title.copyWith(fontSize: 14),
                ),
                const Text(S.greetingSubtitle, style: NexaText.caption),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Search field placeholder. It is not an input: search needs the library
/// (Phase 2), so it is shown as clearly unavailable.
class _SearchPlaceholder extends StatelessWidget {
  const _SearchPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: S.soonSearch,
      child: Container(
        height: 42,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: NexaColors.panel,
          borderRadius: BorderRadius.circular(NexaRadius.md),
          border: Border.all(color: NexaColors.border),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.search_rounded,
              size: 20,
              color: NexaColors.textTertiary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                S.searchHint,
                style: NexaText.body.copyWith(color: NexaColors.textTertiary),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            const StatusBadge.phase(S.phase2),
          ],
        ),
      ),
    );
  }
}
