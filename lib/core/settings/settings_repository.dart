import '../database/app_database.dart';

/// Key-value settings stored in the local database.
class SettingsRepository {
  SettingsRepository(this.db);

  final AppDatabase db;

  Future<String?> getString(String key) async {
    final row = await (db.select(
      db.appSettings,
    )..where((s) => s.key.equals(key))).getSingleOrNull();
    return row?.value;
  }

  Future<void> setString(String key, String value) => db
      .into(db.appSettings)
      .insertOnConflictUpdate(
        AppSettingsCompanion.insert(key: key, value: value),
      );

  Future<double?> getDouble(String key) async =>
      double.tryParse(await getString(key) ?? '');

  Future<bool?> getBool(String key) async => switch (await getString(key)) {
    'true' => true,
    'false' => false,
    _ => null,
  };

  Future<void> setDouble(String key, double value) =>
      setString(key, value.toString());

  Future<void> setBool(String key, bool value) =>
      setString(key, value.toString());
}

/// Setting keys (one place, so they never drift apart).
abstract final class SettingKeys {
  static const String volume = 'player.volume';
  static const String muted = 'player.muted';
  static const String shuffle = 'player.shuffle';
  static const String repeat = 'player.repeat';
  static const String audioDevice = 'player.audioDevice';
  static const String mixMode = 'mix.mode';
  static const String mixSeconds = 'mix.seconds';
  static const String mixSmartAdjust = 'mix.smartAdjust';
  static const String mixAlbumGapless = 'mix.albumGapless';
  static const String historyConsent = 'dna.historyConsent';
  static const String learningPaused = 'dna.learningPaused';
  static const String dnaOnboarded = 'dna.onboarded';
  static const String waveDiscovery = 'wave.discovery';
  static const String waveOnline = 'wave.online';
  static const String audiusEnabled = 'catalog.audius.enabled';
  static const String jamendoClientId = 'catalog.jamendo.clientId';
  static const String youtubeEnabled = 'youtube.enabled';
  static const String youtubeApiKey = 'youtube.apiKey';
}
