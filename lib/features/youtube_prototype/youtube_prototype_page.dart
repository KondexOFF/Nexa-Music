import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/strings.dart';
import '../../app/theme/nexa_theme.dart';
import '../../app/theme/tokens.dart';
import '../../ui/nexa_widgets.dart';
import '../discover/catalog_providers.dart';
import 'youtube_link.dart';
import 'youtube_prototype_controller.dart';

/// Smallest player NEXA shows: YouTube's recommended 16:9 minimum (the
/// required minimum is 200 x 200).
const Size youtubeMinPlayer = Size(480, 270);

/// E2.0 prototype page (developer tool in Settings): paste a link, watch it
/// in YouTube's own visible player. Nothing is drawn over the player.
class YouTubePrototypePage extends ConsumerStatefulWidget {
  const YouTubePrototypePage({super.key});

  @override
  ConsumerState<YouTubePrototypePage> createState() =>
      _YouTubePrototypePageState();
}

class _YouTubePrototypePageState extends ConsumerState<YouTubePrototypePage> {
  final TextEditingController _link = TextEditingController();
  late final YouTubePrototypeController _controller;
  String? _linkProblem;

  @override
  void initState() {
    super.initState();
    _controller = ref.read(youtubePrototypeProvider.notifier);
    // Providers must not change while widgets build: open right after.
    unawaited(Future.microtask(_controller.open));
  }

  @override
  void dispose() {
    // Leaving the page stops YouTube: never playing in the background.
    unawaited(Future.microtask(_controller.close));
    _link.dispose();
    super.dispose();
  }

  Future<void> _play() async {
    final id = youtubeVideoId(_link.text);
    setState(() => _linkProblem = id == null ? S.ytBadLink : null);
    if (id != null) {
      await _controller.load(id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(youtubePrototypeProvider);
    final open = ref.read(linkOpenerProvider);
    final player = _PlayerArea(status: status);
    if (status.fullScreen) {
      // YouTube's own full-screen button: the player takes the whole page.
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
    final videoId = status.videoId;
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
                const Text(S.ytPrototype, style: NexaText.h2),
              ],
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: const Text(S.ytPrototypeInfo, style: NexaText.bodySecondary),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const ValueKey('yt-link'),
                    controller: _link,
                    decoration: InputDecoration(
                      hintText: S.ytLinkHint,
                      errorText: _linkProblem,
                    ),
                    onSubmitted: (_) => _play(),
                  ),
                ),
                const SizedBox(width: 12),
                NexaPillButton(
                  label: S.ytLoad,
                  icon: Icons.play_arrow_rounded,
                  onPressed: status.unavailable == null ? _play : null,
                  disabledReason: status.unavailable,
                ),
              ],
            ),
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
                const StatusBadge(label: 'YouTube', color: NexaColors.coral),
                if (videoId != null)
                  NexaTextLink(
                    label: S.ytOpenOnYouTube,
                    onTap: () => open(youtubeWatchUrl(videoId)),
                  ),
                NexaTextLink(
                  label: S.ytTerms,
                  showArrow: false,
                  onTap: () => open('https://www.youtube.com/t/terms'),
                ),
                NexaTextLink(
                  label: S.ytGooglePrivacy,
                  showArrow: false,
                  onTap: () => open('https://policies.google.com/privacy'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(S.ytLimits, style: NexaText.caption),
            const SizedBox(height: 4),
            Text(
              'WebView2 ${status.runtimeVersion ?? '-'} - page '
              '${status.pageOrigin ?? '-'} - state ${status.state} - '
              'quality ${status.quality ?? '-'}',
              key: const ValueKey('yt-diagnostics'),
              style: NexaText.caption,
            ),
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
    final embed = ref.read(youtubePrototypeProvider.notifier).embed;
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
