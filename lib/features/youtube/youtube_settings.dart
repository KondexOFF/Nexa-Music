import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/strings.dart';
import '../../app/theme/nexa_theme.dart';
import '../../app/theme/tokens.dart';
import '../../core/settings/settings_provider.dart';
import '../../core/settings/settings_repository.dart';
import '../../integrations/youtube/youtube_data_api.dart';
import '../../ui/nexa_widgets.dart';
import '../discover/catalog_providers.dart';

const String youtubeTermsUrl = 'https://www.youtube.com/t/terms';
const String googlePrivacyUrl = 'https://policies.google.com/privacy';
const String youtubeApiKeyHelpUrl =
    'https://developers.google.com/youtube/v3/getting-started';

/// Result of "Check key".
enum KeyCheck { checking, ok, failed }

/// YouTube settings (E2.4). Off by default; turned on only after the
/// consent screen. The owner's Data API key is stored only in NEXA's local
/// database, never in the repository, reports or logs.
@immutable
class YouTubeSettings {
  const YouTubeSettings({
    this.loaded = false,
    this.enabled = false,
    this.apiKey = '',
    this.keyCheck,
    this.keyError,
  });

  final bool loaded;
  final bool enabled;
  final String apiKey;
  final KeyCheck? keyCheck;
  final YouTubeApiError? keyError;

  bool get hasKey => apiKey.trim().isNotEmpty;

  YouTubeSettings copyWith({
    bool? loaded,
    bool? enabled,
    String? apiKey,
    KeyCheck? keyCheck,
    YouTubeApiError? keyError,
    bool clearCheck = false,
  }) => YouTubeSettings(
    loaded: loaded ?? this.loaded,
    enabled: enabled ?? this.enabled,
    apiKey: apiKey ?? this.apiKey,
    keyCheck: clearCheck ? null : (keyCheck ?? this.keyCheck),
    keyError: clearCheck ? null : (keyError ?? this.keyError),
  );
}

class YouTubeSettingsController extends Notifier<YouTubeSettings> {
  @override
  YouTubeSettings build() {
    unawaited(_restore());
    return const YouTubeSettings();
  }

  SettingsRepository get _repo => ref.read(settingsRepositoryProvider);

  Future<void> _restore() async {
    try {
      final enabled = await _repo.getBool(SettingKeys.youtubeEnabled);
      final key = await _repo.getString(SettingKeys.youtubeApiKey);
      if (ref.mounted) {
        state = state.copyWith(
          loaded: true,
          enabled: enabled ?? false,
          apiKey: key ?? '',
        );
      }
    } on Object {
      if (ref.mounted) {
        state = state.copyWith(loaded: true);
      }
    }
  }

  /// Call with true only after the user agreed on the consent screen.
  Future<void> setEnabled(bool value) async {
    state = state.copyWith(enabled: value);
    await _repo.setBool(SettingKeys.youtubeEnabled, value);
  }

  Future<void> setApiKey(String value) async {
    final v = value.trim();
    state = state.copyWith(apiKey: v, clearCheck: true);
    await _repo.setString(SettingKeys.youtubeApiKey, v);
  }

  Future<void> deleteApiKey() => setApiKey('');

  /// Asks YouTube whether the saved key works (1 quota unit).
  Future<void> checkKey() async {
    state = state.copyWith(clearCheck: true).copyWith(
      keyCheck: KeyCheck.checking,
    );
    try {
      // Not through [youtubeDataApiProvider]: it depends on this provider.
      await YouTubeDataApi(
        ref.read(httpClientProvider),
        apiKey: state.apiKey,
      ).checkKey();
      if (ref.mounted) {
        state = state.copyWith(keyCheck: KeyCheck.ok);
      }
    } on YouTubeApiException catch (e) {
      if (ref.mounted) {
        state = state.copyWith(keyCheck: KeyCheck.failed, keyError: e.error);
      }
    }
  }
}

final youtubeSettingsProvider =
    NotifierProvider<YouTubeSettingsController, YouTubeSettings>(
      YouTubeSettingsController.new,
    );

/// The Data API client with the owner's key.
final youtubeDataApiProvider = Provider<YouTubeDataApi>((ref) {
  final key = ref.watch(youtubeSettingsProvider.select((s) => s.apiKey));
  return YouTubeDataApi(ref.watch(httpClientProvider), apiKey: key);
});

/// Plain text for a Data API problem.
String youtubeApiErrorText(YouTubeApiError e) => switch (e) {
  YouTubeApiError.badKey => S.ytApiBadKey,
  YouTubeApiError.apiDisabled => S.ytApiDisabled,
  YouTubeApiError.quotaExceeded => S.ytApiQuota,
  YouTubeApiError.rateLimited => S.ytApiRateLimited,
  YouTubeApiError.offline => S.ytApiOffline,
  YouTubeApiError.provider => S.ytApiProvider,
};

/// The informed-consent screen shown every time YouTube is turned on.
/// Returns true when the user agrees.
Future<bool> showYouTubeConsent(BuildContext context, WidgetRef ref) async {
  final open = ref.read(linkOpenerProvider);
  final agreed = await showDialog<bool>(
    context: context,
    builder: (context) => Dialog(
      backgroundColor: NexaColors.panelRaised,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            key: const ValueKey('yt-consent'),
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(S.ytConsentTitle, style: NexaText.h2),
              const SizedBox(height: 14),
              for (final line in S.ytConsentPoints)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: EdgeInsets.only(top: 7, right: 10),
                        child: Icon(
                          Icons.circle,
                          size: 6,
                          color: NexaColors.accent,
                        ),
                      ),
                      Expanded(child: Text(line, style: NexaText.body)),
                    ],
                  ),
                ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 16,
                runSpacing: 8,
                children: [
                  NexaTextLink(
                    label: S.ytTerms,
                    onTap: () => open(youtubeTermsUrl),
                  ),
                  NexaTextLink(
                    label: S.ytGooglePrivacy,
                    onTap: () => open(googlePrivacyUrl),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 12,
                runSpacing: 8,
                children: [
                  NexaPillButton(
                    key: const ValueKey('yt-consent-cancel'),
                    label: S.cancel,
                    variant: PillVariant.secondary,
                    height: 42,
                    onPressed: () => Navigator.of(context).pop(false),
                  ),
                  NexaPillButton(
                    key: const ValueKey('yt-consent-agree'),
                    label: S.ytConsentAgree,
                    height: 42,
                    onPressed: () => Navigator.of(context).pop(true),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
  return agreed ?? false;
}

/// Settings -> YouTube: on / off (with consent), the Data API key (enter,
/// change, check, delete) and the links to YouTube's and Google's terms.
class YouTubeSettingsControls extends ConsumerStatefulWidget {
  const YouTubeSettingsControls({super.key});

  @override
  ConsumerState<YouTubeSettingsControls> createState() =>
      _YouTubeSettingsControlsState();
}

class _YouTubeSettingsControlsState
    extends ConsumerState<YouTubeSettingsControls> {
  final TextEditingController _key = TextEditingController();
  bool _filled = false;

  @override
  void dispose() {
    _key.dispose();
    super.dispose();
  }

  Future<void> _toggle(bool on) async {
    final controller = ref.read(youtubeSettingsProvider.notifier);
    if (!on) {
      await controller.setEnabled(false);
      return;
    }
    if (await showYouTubeConsent(context, ref)) {
      await controller.setEnabled(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(youtubeSettingsProvider);
    if (s.loaded && !_filled) {
      _filled = true;
      _key.text = s.apiKey;
    }
    final controller = ref.read(youtubeSettingsProvider.notifier);
    final open = ref.read(linkOpenerProvider);
    final check = switch (s.keyCheck) {
      KeyCheck.checking => S.ytKeyChecking,
      KeyCheck.ok => S.ytKeyOk,
      KeyCheck.failed => youtubeApiErrorText(
        s.keyError ?? YouTubeApiError.provider,
      ),
      null => s.hasKey ? S.ytKeySaved : S.ytKeyNone,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(S.ytUse, style: NexaText.title),
                  SizedBox(height: 2),
                  Text(S.ytUseInfo, style: NexaText.caption),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Switch(
              key: const ValueKey('yt-enabled'),
              value: s.enabled,
              onChanged: s.loaded ? _toggle : null,
            ),
          ],
        ),
        const SizedBox(height: 14),
        const Text(S.ytApiKey, style: NexaText.title),
        const SizedBox(height: 2),
        const Text(S.ytApiKeyInfo, style: NexaText.caption),
        const SizedBox(height: 8),
        TextField(
          key: const ValueKey('yt-key'),
          controller: _key,
          obscureText: true,
          autocorrect: false,
          enableSuggestions: false,
          decoration: const InputDecoration(
            hintText: S.ytApiKey,
            isDense: true,
          ),
          onSubmitted: controller.setApiKey,
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            NexaPillButton(
              key: const ValueKey('yt-key-save'),
              label: S.save,
              variant: PillVariant.secondary,
              height: 40,
              onPressed: () => controller.setApiKey(_key.text),
            ),
            NexaPillButton(
              key: const ValueKey('yt-key-check'),
              label: S.ytKeyCheck,
              variant: PillVariant.secondary,
              height: 40,
              onPressed: s.hasKey && s.keyCheck != KeyCheck.checking
                  ? controller.checkKey
                  : null,
              disabledReason: S.ytKeyNone,
            ),
            NexaPillButton(
              key: const ValueKey('yt-key-delete'),
              label: S.ytKeyDelete,
              variant: PillVariant.secondary,
              height: 40,
              onPressed: s.hasKey
                  ? () {
                      _key.clear();
                      unawaited(controller.deleteApiKey());
                    }
                  : null,
              disabledReason: S.ytKeyNone,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          check,
          key: const ValueKey('yt-key-status'),
          style: NexaText.caption.copyWith(
            color: s.keyCheck == KeyCheck.failed
                ? NexaColors.coral
                : NexaColors.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 16,
          runSpacing: 8,
          children: [
            NexaTextLink(
              label: S.ytKeyHelp,
              onTap: () => open(youtubeApiKeyHelpUrl),
            ),
            NexaTextLink(label: S.ytTerms, onTap: () => open(youtubeTermsUrl)),
            NexaTextLink(
              label: S.ytGooglePrivacy,
              onTap: () => open(googlePrivacyUrl),
            ),
          ],
        ),
      ],
    );
  }
}
