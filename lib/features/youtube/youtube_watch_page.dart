import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/navigation.dart';
import '../../app/strings.dart';
import '../../app/theme/nexa_theme.dart';
import '../../app/theme/tokens.dart';
import '../../integrations/youtube/youtube_link.dart';
import '../../ui/nexa_widgets.dart';
import '../discover/catalog_providers.dart';
import 'youtube_player_controller.dart';
import 'youtube_settings.dart';

/// Smallest player NEXA shows: YouTube's recommended 16:9 minimum on the
/// YouTube page (Required Minimum Functionality: never below 200 x 200).
const Size youtubeMinPlayer = Size(480, 270);

/// Where the YouTube page wants the player. The one player of the app
/// ([YouTubeDock] in the shell) follows this place while the page is shown,
/// so moving between sections never recreates or reloads the video (E2.6).
final LayerLink youtubeSlotLink = LayerLink();

/// Size of the place on the YouTube page (null when the page is not shown).
final ValueNotifier<Size?> youtubeSlotSize = ValueNotifier<Size?>(null);

/// Watch [videoId] in NEXA: the YouTube section of the app shows it.
Future<void> openYouTubeWatch(
  WidgetRef ref, {
  required String videoId,
  String? title,
  String? channel,
}) async {
  ref.read(navigationProvider.notifier).go(NexaDestination.youtube);
  await ref
      .read(youtubePlayerProvider.notifier)
      .watch(videoId, title: title, channel: channel);
}

/// The YouTube section (E2.1 / E2.6): YouTube's own visible player with its
/// controls, branding and ads; nothing is drawn over it. Leaving the section
/// keeps the video playing in the compact player; "Close player" stops it.
class YouTubePage extends ConsumerStatefulWidget {
  const YouTubePage({super.key});

  @override
  ConsumerState<YouTubePage> createState() => _YouTubePageState();
}

class _YouTubePageState extends ConsumerState<YouTubePage> {
  final TextEditingController _link = TextEditingController();
  String? _linkProblem;

  @override
  void dispose() {
    _link.dispose();
    super.dispose();
  }

  Future<void> _watchLink() async {
    final id = youtubeVideoId(_link.text);
    setState(() => _linkProblem = id == null ? S.ytBadLink : null);
    if (id != null) {
      _link.clear();
      await ref.read(youtubePlayerProvider.notifier).watch(id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(youtubePlayerProvider);
    final open = ref.read(linkOpenerProvider);
    final error = status.errorCode;
    final message = status.unavailable != null
        ? S.ytUnavailable(status.unavailable!)
        : status.apiLoadFailed
        ? S.ytApiLoadFailed
        : error != null
        ? youtubeErrorText(error)
        : status.autoplayBlocked
        ? S.ytAutoplayBlocked
        : null;
    final videoId = status.videoId;
    final title = status.title ?? '';
    final channel = status.channel ?? '';
    return SingleChildScrollView(
      key: const PageStorageKey('youtube-page'),
      padding: const EdgeInsets.fromLTRB(28, 20, 28, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const StatusBadge(label: 'YouTube', color: NexaColors.coral),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title.isEmpty ? S.ytPageTitle : title,
                  key: const ValueKey('yt-title'),
                  style: NexaText.h2,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (status.open)
                NexaPillButton(
                  key: const ValueKey('yt-close-player'),
                  label: S.ytClosePlayer,
                  icon: Icons.close_rounded,
                  variant: PillVariant.secondary,
                  height: 40,
                  onPressed: () =>
                      ref.read(youtubePlayerProvider.notifier).close(),
                ),
            ],
          ),
          if (channel.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(channel, style: NexaText.bodySecondary),
          ],
          const SizedBox(height: 16),
          if (status.open && status.unavailable == null)
            const YouTubePlayerSlot()
          else
            _Placeholder(text: status.open ? '' : S.ytNothingPlaying),
          const SizedBox(height: 12),
          if (message != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                message,
                key: const ValueKey('yt-message'),
                style: NexaText.body.copyWith(color: NexaColors.coral),
              ),
            ),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (videoId != null)
                NexaTextLink(
                  key: const ValueKey('yt-open-on-youtube'),
                  label: S.ytOpenOnYouTube,
                  onTap: () => open(youtubeWatchUrl(videoId)),
                ),
              NexaTextLink(
                label: S.ytTerms,
                showArrow: false,
                onTap: () => open(youtubeTermsUrl),
              ),
              NexaTextLink(
                label: S.ytGooglePrivacy,
                showArrow: false,
                onTap: () => open(googlePrivacyUrl),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: TextField(
                  key: const ValueKey('yt-page-link'),
                  controller: _link,
                  decoration: InputDecoration(
                    hintText: S.ytLinkHint,
                    errorText: _linkProblem,
                    prefixIcon: const Icon(Icons.link_rounded),
                  ),
                  onSubmitted: (_) => _watchLink(),
                ),
              ),
              const SizedBox(width: 12),
              NexaPillButton(
                label: S.ytWatch,
                icon: Icons.play_arrow_rounded,
                variant: PillVariant.secondary,
                onPressed: _watchLink,
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(S.ytLimits, style: NexaText.caption),
        ],
      ),
    );
  }
}

/// The place of the player on the YouTube page, 16:9, never smaller than
/// [youtubeMinPlayer]. The player itself is drawn by the shell's
/// [YouTubeDock] exactly here, with nothing in front of it.
class YouTubePlayerSlot extends StatefulWidget {
  const YouTubePlayerSlot({super.key});

  @override
  State<YouTubePlayerSlot> createState() => _YouTubePlayerSlotState();
}

class _YouTubePlayerSlotState extends State<YouTubePlayerSlot> {
  Size? _reported;

  void _report(Size size) {
    if (_reported == size) {
      return;
    }
    _reported = size;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        youtubeSlotSize.value = size;
      }
    });
  }

  @override
  void dispose() {
    final reported = _reported;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (youtubeSlotSize.value == reported) {
        youtubeSlotSize.value = null;
      }
    });
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      // As wide as the page: a large player lets YouTube choose HD.
      final width = math.max(youtubeMinPlayer.width, constraints.maxWidth);
      final size = Size(width, width * 9 / 16);
      _report(size);
      return CompositedTransformTarget(
        link: youtubeSlotLink,
        child: SizedBox(
          key: const ValueKey('yt-player'),
          width: size.width,
          height: size.height,
          child: const ColoredBox(color: Colors.black),
        ),
      );
    },
  );
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final width = math.max(youtubeMinPlayer.width, constraints.maxWidth);
      return Container(
        width: width,
        height: width * 9 / 16,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(NexaRadius.md),
        ),
        child: Text(text, style: NexaText.bodySecondary),
      );
    },
  );
}
