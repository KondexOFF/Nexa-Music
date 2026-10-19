import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../../core/settings/settings_provider.dart';
import '../../core/settings/settings_repository.dart';
import '../../integrations/audius/audius_source.dart';
import '../../integrations/jamendo/jamendo_source.dart';
import '../../integrations/music_source.dart';

/// HTTP client for the catalog APIs (tests use a mock).
final httpClientProvider = Provider<http.Client>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return client;
});

/// Opens a provider page in the system browser (attribution backlinks).
final linkOpenerProvider = Provider<Future<bool> Function(String url)>(
  (ref) =>
      (url) => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
);

/// Which catalogs the owner uses and their keys (stored only in the local
/// database, never in the repository).
@immutable
class CatalogSettings {
  const CatalogSettings({
    this.loaded = false,
    this.audiusEnabled = true,
    this.jamendoClientId = '',
  });

  final bool loaded;
  final bool audiusEnabled;
  final String jamendoClientId;

  bool get jamendoEnabled => jamendoClientId.trim().isNotEmpty;

  CatalogSettings copyWith({
    bool? loaded,
    bool? audiusEnabled,
    String? jamendoClientId,
  }) => CatalogSettings(
    loaded: loaded ?? this.loaded,
    audiusEnabled: audiusEnabled ?? this.audiusEnabled,
    jamendoClientId: jamendoClientId ?? this.jamendoClientId,
  );
}

class CatalogSettingsController extends Notifier<CatalogSettings> {
  @override
  CatalogSettings build() {
    unawaited(_restore());
    return const CatalogSettings();
  }

  SettingsRepository get _repo => ref.read(settingsRepositoryProvider);

  Future<void> _restore() async {
    try {
      final audius = await _repo.getBool(SettingKeys.audiusEnabled);
      final jamendo = await _repo.getString(SettingKeys.jamendoClientId);
      if (ref.mounted) {
        state = state.copyWith(
          loaded: true,
          audiusEnabled: audius,
          jamendoClientId: jamendo,
        );
      }
    } on Object {
      if (ref.mounted) {
        state = state.copyWith(loaded: true);
      }
    }
  }

  Future<void> setAudiusEnabled(bool value) async {
    state = state.copyWith(audiusEnabled: value);
    await _repo.setBool(SettingKeys.audiusEnabled, value);
  }

  Future<void> setJamendoClientId(String value) async {
    final v = value.trim();
    state = state.copyWith(jamendoClientId: v);
    await _repo.setString(SettingKeys.jamendoClientId, v);
  }
}

final catalogSettingsProvider =
    NotifierProvider<CatalogSettingsController, CatalogSettings>(
      CatalogSettingsController.new,
    );

/// The catalog adapters, in display order. Disabled / unconfigured ones are
/// still listed so the page can say why they are not searched.
final musicSourcesProvider = Provider<List<MusicSource>>((ref) {
  final client = ref.watch(httpClientProvider);
  final settings = ref.watch(catalogSettingsProvider);
  return [
    if (settings.audiusEnabled) AudiusSource(client),
    JamendoSource(client, clientId: settings.jamendoClientId),
  ];
});
