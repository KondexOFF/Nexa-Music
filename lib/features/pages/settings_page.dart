import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/config.dart';
import '../../app/strings.dart';
import '../../app/theme/nexa_theme.dart';
import '../../app/theme/tokens.dart';
import '../../audio_probe/probe_screen.dart';
import '../../core/audio/playback_engine.dart';
import '../discover/catalog_settings.dart';
import '../nexa_dna/privacy_controls.dart';
import '../player/player_controller.dart';
import '../youtube/youtube_settings.dart';
import '../../ui/nexa_widgets.dart';

/// Settings: output device, media keys, planned settings and the Phase 0
/// audio engine test (kept as a developer tool).
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  void _openAudioTest(BuildContext context) {
    // Never two players at once: pause NEXA before the test screen plays.
    ProviderScope.containerOf(context).read(playerProvider.notifier).pause();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ProbeScreen(
          initialPath: kTestAudioPath,
          selfTest: false,
          logDir: '',
          captureKey: GlobalKey(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      key: const PageStorageKey('page-settings'),
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(S.settingsHeading, style: NexaText.display),
          const SizedBox(height: 24),
          _SettingsCard(
            icon: Icons.info_outline_rounded,
            title: S.settingsAbout,
            body: '${S.settingsAboutBody}\n${S.versionLine(kAppVersion)}',
            action: NexaPillButton(
              label: S.licences,
              icon: Icons.description_outlined,
              variant: PillVariant.secondary,
              height: 42,
              onPressed: () => showLicensePage(
                context: context,
                applicationName: S.appTitle,
                applicationVersion: kAppVersion,
              ),
            ),
          ),
          const _SettingsCard(
            icon: Icons.speaker_outlined,
            title: S.outputDevice,
            body: S.outputDeviceBody,
            action: _OutputDevicePicker(),
          ),
          const _SettingsCard(
            icon: Icons.music_note_outlined,
            title: 'Media keys',
            body: S.mediaKeysBody,
          ),
          const _SettingsCard(
            icon: Icons.keyboard_outlined,
            title: S.keyboardTitle,
            body: S.keyboardBody,
          ),
          const _SettingsCard(
            icon: Icons.privacy_tip_outlined,
            title: S.settingsPrivacy,
            body: S.settingsPrivacyBody,
            action: PrivacyControls(),
          ),
          const _SettingsCard(
            icon: Icons.public_rounded,
            title: S.settingsCatalogs,
            body: S.settingsCatalogsBody,
            action: CatalogSettingsControls(),
          ),
          const _SettingsCard(
            icon: Icons.smart_display_outlined,
            title: S.ytSettingsTitle,
            body: S.ytSettingsBody,
            action: YouTubeSettingsControls(),
          ),
          const _SettingsCard(
            icon: Icons.graphic_eq_rounded,
            title: S.settingsMix,
            body: S.settingsMixBody,
          ),
          _SettingsCard(
            icon: Icons.build_outlined,
            title: S.settingsDev,
            body: S.settingsDevBody,
            action: NexaPillButton(
              label: S.openAudioTest,
              icon: Icons.play_circle_outline_rounded,
              variant: PillVariant.secondary,
              height: 42,
              onPressed: () => _openAudioTest(context),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({
    required this.icon,
    required this.title,
    required this.body,
    this.action,
  });

  final IconData icon;
  final String title;
  final String body;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: NexaSpace.sm),
      child: NexaPanel(
        padding: const EdgeInsets.all(20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: NexaColors.accent, size: 24),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: NexaText.h3),
                  const SizedBox(height: 6),
                  Text(body, style: NexaText.bodySecondary),
                  if (action != null) ...[
                    const SizedBox(height: 14),
                    action!,
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OutputDevicePicker extends ConsumerWidget {
  const _OutputDevicePicker();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final devices =
        ref.watch(outputDevicesProvider).value ??
        const [OutputDevice('auto', 'System default')];
    return DropdownButtonHideUnderline(
      child: DropdownButton<OutputDevice>(
        value: null,
        hint: const Text(S.outputDevice, style: NexaText.body),
        dropdownColor: NexaColors.panelRaised,
        items: [
          for (final d in devices)
            DropdownMenuItem(
              value: d,
              child: Text(
                d.description.isEmpty ? d.id : d.description,
                style: NexaText.body,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
        onChanged: (d) {
          if (d != null) {
            ref.read(playerProvider.notifier).setOutputDevice(d);
          }
        },
      ),
    );
  }
}
