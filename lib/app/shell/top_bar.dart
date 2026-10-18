import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/library/library_providers.dart';
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

/// Library search (Phase 2). Typing shows matching songs on the Library
/// page; the query is shared with the Library page's own filter.
class _SearchPlaceholder extends ConsumerStatefulWidget {
  const _SearchPlaceholder();

  @override
  ConsumerState<_SearchPlaceholder> createState() => _SearchFieldState();
}

class _SearchFieldState extends ConsumerState<_SearchPlaceholder> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    ref.read(libraryQueryProvider.notifier).set(value);
    final nav = ref.read(navigationProvider);
    if (value.trim().isNotEmpty && nav.current != NexaDestination.library) {
      final tab = ref.read(libraryTabProvider);
      if (tab != LibraryTab.songs && tab != LibraryTab.favorites) {
        ref.read(libraryTabProvider.notifier).set(LibraryTab.songs);
      }
      ref.read(navigationProvider.notifier).go(NexaDestination.library);
    }
  }

  @override
  Widget build(BuildContext context) {
    final query = ref.watch(libraryQueryProvider);
    ref.listen(libraryQueryProvider, (previous, next) {
      if (next != _controller.text) {
        _controller.value = TextEditingValue(
          text: next,
          selection: TextSelection.collapsed(offset: next.length),
        );
      }
    });
    return Container(
      height: 42,
      padding: const EdgeInsets.only(left: 14, right: 4),
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
            child: TextField(
              controller: _controller,
              onChanged: _onChanged,
              style: NexaText.body,
              cursorColor: NexaColors.accent,
              decoration: InputDecoration(
                isDense: true,
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                hintText: S.searchLibraryHint,
                hintStyle: NexaText.body.copyWith(
                  color: NexaColors.textTertiary,
                ),
              ),
            ),
          ),
          if (query.isNotEmpty)
            NexaIconButton(
              icon: Icons.close_rounded,
              label: S.clearSearch,
              iconSize: 18,
              boxSize: 32,
              onPressed: () => _onChanged(''),
            ),
        ],
      ),
    );
  }
}
