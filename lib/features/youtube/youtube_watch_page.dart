import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/strings.dart';
import '../../app/theme/nexa_theme.dart';
import '../../app/theme/tokens.dart';
import '../../integrations/youtube/youtube_link.dart';
import '../../ui/nexa_widgets.dart';
import '../discover/catalog_providers.dart';
import 'youtube_player_controller.dart';
import 'youtube_settings.dart';

/// Smallest player NEXA shows: YouTube's recommended 16:9 minimum (the
/// required minimum is 200 x 200).
const Size youtubeMinPlayer = Size(480, 270);

/// Opens the YouTube page for [videoId] (Watch in NEXA).
Future<void> openYouTubeWatch(
  BuildContext context, {
  required String videoId,
  String? title,
  String? channel,
}) => Navigator.of(context).push(
  MaterialPageRoute<void>(
    builder: (_) =>
        YouTubeWatchPage(videoId: videoId, title: title, channel: channel),
  ),
);

/// The YouTube page (E2.1): YouTube's own visible player with its controls,
/// branding and ads; nothing is drawn over it. The video stops when the page
/// is left and pauses when the window is minimised.
class YouTubeWatchPage extends ConsumerStatefulWidget {
  const YouTubeWatchPage({
    super.key,
    required this.videoId,
    this.title,
    this.channel,
  });

  final String videoId;
  final String? title;
  final String? channel;

  @override
  ConsumerState<YouTubeWatchPage> createState() => _YouTubeWatchPageState();
}

class _YouTubeWatchPageState extends ConsumerState<YouTubeWatchPage> {
  final TextEditingController _link = TextEditingController();
  late final YouTubePlayerController _controller;
  String? _linkProblem;

  @override
  void initState() {
    super.initState();
    _controller = ref.read(youtubePlayerProvider.notifier);
    // Providers must not change while widgets build: open right after.
    unawaited(
      Future.microtask(() async {
        await _controller.open();
        await _controller.load(
          widget.videoId,
          title: widget.title,
          channel: widget.channel,
        );
      }),
    );
  }

  @override
  void dispose() {
    // Leaving the page stops YouTube: never playing in the background.
    unawaited(Future.microtask(_controller.close));
    _link.dispose();
    super.dispose();
  }

  Future<void> _watchLink() async {
    final id = youtubeVideoId(_link.text);
    setState(() => _linkProblem = id == null ? S.ytBadLink : null);
    if (id != null) {
      _link.clear();
      await _controller.load(id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(youtubePlayerProvider);
    final open = ref.read(linkOpenerProvider);
    final player = _PlayerArea(status: status);
    if (status.fullScreen) {
      // YouTube's own full-screen button: the player takes the whole page;
      // Esc (handled by YouTube) returns.
      return Scaffold(backgroundColor: Colors.black, body: player);
    }
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
    final videoId = status.videoId ?? widget.videoId;
    final title = status.title ?? '';
    final channel = status.channel ?? '';
    return Scaffold(
      backgroundColor: NexaColors.background,
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                NexaIconButton(
                  icon: Icons.arrow_back_rounded,
                  label: S.ytBack,
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
                const SizedBox(width: 12),
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
              ],
            ),
            if (channel.isNotEmpty) ...[
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.only(left: 56),
                child: Text(channel, style: NexaText.bodySecondary),
              ),
            ],
            const SizedBox(height: 16),
            player,
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
                  onPressed: status.unavailable == null ? _watchLink : null,
                  disabledReason: status.unavailable,
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Text(S.ytLimits, style: NexaText.caption),
          ],
        ),
      ),
    );
  }
}

/// The YouTube player, 16:9, never smaller than [youtubeMinPlayer], with
/// nothing in front of it.
class _PlayerArea extends ConsumerWidget {
  const _PlayerArea({required this.status});

  final YtStatus status;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final embed = ref.read(youtubePlayerProvider.notifier).embed;
    final ready = embed != null && status.unavailable == null;
    if (status.fullScreen && ready) {
      return SizedBox.expand(child: embed.view());
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        // As wide as the page: a large player lets YouTube choose HD.
        final width = math.max(youtubeMinPlayer.width, constraints.maxWidth);
        return SizedBox(
          key: const ValueKey('yt-player'),
          width: width,
          height: width * 9 / 16,
          child: ready
              ? embed.view()
              : DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(NexaRadius.md),
                  ),
                  child: Center(
                    child: Text(
                      status.unavailable == null ? S.ytStarting : '',
                      style: NexaText.bodySecondary,
                    ),
                  ),
                ),
        );
      },
    );
  }
}
