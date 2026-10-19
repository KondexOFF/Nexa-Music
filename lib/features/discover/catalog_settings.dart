import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/strings.dart';
import '../../app/theme/nexa_theme.dart';
import '../../ui/nexa_widgets.dart';
import 'catalog_providers.dart';

const String _jamendoTermsUrl = 'https://devportal.jamendo.com/api_terms_of_use';

/// Settings -> Online catalogs: Audius on/off and the owner's own Jamendo
/// client id (stored only in the local database).
class CatalogSettingsControls extends ConsumerStatefulWidget {
  const CatalogSettingsControls({super.key});

  @override
  ConsumerState<CatalogSettingsControls> createState() =>
      _CatalogSettingsControlsState();
}

class _CatalogSettingsControlsState
    extends ConsumerState<CatalogSettingsControls> {
  final TextEditingController _clientId = TextEditingController();
  bool _filled = false;

  @override
  void dispose() {
    _clientId.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(catalogSettingsProvider);
    if (s.loaded && !_filled) {
      _filled = true;
      _clientId.text = s.jamendoClientId;
    }
    final controller = ref.read(catalogSettingsProvider.notifier);
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
                  Text(S.useAudius, style: NexaText.title),
                  SizedBox(height: 2),
                  Text(S.useAudiusInfo, style: NexaText.caption),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Switch(
              value: s.audiusEnabled,
              onChanged: controller.setAudiusEnabled,
            ),
          ],
        ),
        const SizedBox(height: 14),
        const Text(S.jamendoClientId, style: NexaText.title),
        const SizedBox(height: 2),
        const Text(S.jamendoClientIdInfo, style: NexaText.caption),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _clientId,
                obscureText: true,
                autocorrect: false,
                enableSuggestions: false,
                decoration: const InputDecoration(
                  hintText: S.jamendoClientId,
                  isDense: true,
                ),
                onSubmitted: controller.setJamendoClientId,
              ),
            ),
            const SizedBox(width: 12),
            NexaPillButton(
              label: S.save,
              variant: PillVariant.secondary,
              height: 40,
              onPressed: () => controller.setJamendoClientId(_clientId.text),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: NexaTextLink(
            label: S.jamendoTerms,
            onTap: () => ref.read(linkOpenerProvider)(_jamendoTermsUrl),
          ),
        ),
      ],
    );
  }
}
