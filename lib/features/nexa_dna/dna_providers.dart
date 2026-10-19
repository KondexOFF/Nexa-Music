import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/listening.dart';
import '../../core/settings/settings_provider.dart';
import '../../core/settings/settings_repository.dart';
import '../library/library_providers.dart';
import '../library/tag_reader.dart' show unknownArtist;
import 'taste_repository.dart';

final tasteRepositoryProvider = Provider<TasteRepository>(
  (ref) => TasteRepository(ref.watch(appDatabaseProvider)),
);

/// NEXA DNA privacy and Wave settings.
@immutable
class DnaSettings {
  const DnaSettings({
    this.loaded = false,
    this.historyConsent = false,
    this.learningPaused = false,
    this.privateSession = false,
    this.onboarded = false,
    this.discovery = defaultDiscovery,
  });

  static const double defaultDiscovery = 0.3;

  final bool loaded;

  /// The user allowed NEXA to keep a local listening history.
  final bool historyConsent;

  /// History recording is paused (consent kept).
  final bool learningPaused;

  /// "Do not count this session": nothing is recorded until the app closes.
  /// Never saved, so every start is a normal session again.
  final bool privateSession;

  /// The first NEXA DNA choice was made or skipped.
  final bool onboarded;

  /// 0 = familiar only ... 1 = discoveries first.
  final double discovery;

  /// Whether a finished listening may be written to the history.
  bool get recordsHistory => historyConsent && !learningPaused && !privateSession;

  DnaSettings copyWith({
    bool? loaded,
    bool? historyConsent,
    bool? learningPaused,
    bool? privateSession,
    bool? onboarded,
    double? discovery,
  }) => DnaSettings(
    loaded: loaded ?? this.loaded,
    historyConsent: historyConsent ?? this.historyConsent,
    learningPaused: learningPaused ?? this.learningPaused,
    privateSession: privateSession ?? this.privateSession,
    onboarded: onboarded ?? this.onboarded,
    discovery: discovery ?? this.discovery,
  );
}

class DnaSettingsController extends Notifier<DnaSettings> {
  @override
  DnaSettings build() {
    unawaited(_restore());
    return const DnaSettings();
  }

  SettingsRepository get _repo => ref.read(settingsRepositoryProvider);

  Future<void> _restore() async {
    try {
      final consent = await _repo.getBool(SettingKeys.historyConsent);
      final paused = await _repo.getBool(SettingKeys.learningPaused);
      final onboarded = await _repo.getBool(SettingKeys.dnaOnboarded);
      final discovery = await _repo.getDouble(SettingKeys.waveDiscovery);
      if (!ref.mounted) {
        return;
      }
      state = state.copyWith(
        loaded: true,
        historyConsent: consent,
        learningPaused: paused,
        onboarded: onboarded,
        discovery: discovery?.clamp(0.0, 1.0).toDouble(),
      );
    } on Object {
      if (ref.mounted) {
        state = state.copyWith(loaded: true);
      }
    }
  }

  Future<void> _save(Future<void> Function() write) async {
    try {
      await write();
    } on Object {
      // The in-memory value still applies for this session.
    }
  }

  Future<void> setHistoryConsent(bool value) async {
    state = state.copyWith(historyConsent: value);
    await _save(() => _repo.setBool(SettingKeys.historyConsent, value));
  }

  Future<void> setLearningPaused(bool value) async {
    state = state.copyWith(learningPaused: value);
    await _save(() => _repo.setBool(SettingKeys.learningPaused, value));
  }

  /// Not saved on purpose: a private session ends when the app closes.
  void setPrivateSession(bool value) =>
      state = state.copyWith(privateSession: value);

  Future<void> setOnboarded(bool value) async {
    state = state.copyWith(onboarded: value);
    await _save(() => _repo.setBool(SettingKeys.dnaOnboarded, value));
  }

  Future<void> setDiscovery(double value) async {
    final v = value.clamp(0.0, 1.0).toDouble();
    state = state.copyWith(discovery: v);
    await _save(() => _repo.setDouble(SettingKeys.waveDiscovery, v));
  }

  /// Resets the Wave settings (consent and pause stay as chosen).
  Future<void> resetPreferences() async {
    state = state.copyWith(
      discovery: DnaSettings.defaultDiscovery,
      onboarded: false,
    );
    await _save(() async {
      await _repo.setDouble(
        SettingKeys.waveDiscovery,
        DnaSettings.defaultDiscovery,
      );
      await _repo.setBool(SettingKeys.dnaOnboarded, false);
    });
  }
}

final dnaSettingsProvider = NotifierProvider<DnaSettingsController, DnaSettings>(
  DnaSettingsController.new,
);

final tasteItemsProvider = StreamProvider<List<TasteChoice>>(
  (ref) => ref.watch(tasteRepositoryProvider).watchItems(),
);

final listeningEventCountProvider = StreamProvider<int>(
  (ref) => ref.watch(tasteRepositoryProvider).watchEventCount(),
);

/// Genres and artists found in the library (for the NEXA DNA picker), most
/// common first.
@immutable
class LibraryTags {
  const LibraryTags({this.genres = const [], this.artists = const []});

  final List<String> genres;
  final List<String> artists;
}

final libraryTagsProvider = StreamProvider<LibraryTags>((ref) {
  final repo = ref.watch(libraryRepositoryProvider);
  return repo.watchTracks().map((tracks) {
    final genres = <String, (String, int)>{};
    final artists = <String, (String, int)>{};
    void count(Map<String, (String, int)> map, String value) {
      final key = tasteKey(value);
      if (key.isEmpty || key == tasteKey(unknownArtist)) {
        return;
      }
      final old = map[key];
      map[key] = (old?.$1 ?? value.trim(), (old?.$2 ?? 0) + 1);
    }

    for (final t in tracks) {
      for (final g in genreTokens(t.genre)) {
        count(genres, g);
      }
      count(artists, t.artist);
    }
    List<String> top(Map<String, (String, int)> map, int limit) {
      final list = map.values.toList()
        ..sort((a, b) {
          final byCount = b.$2.compareTo(a.$2);
          return byCount != 0
              ? byCount
              : a.$1.toLowerCase().compareTo(b.$1.toLowerCase());
        });
      return [for (final e in list.take(limit)) e.$1];
    }

    return LibraryTags(genres: top(genres, 40), artists: top(artists, 60));
  });
});

/// Writes finished listenings to the history - only when allowed.
class ListeningRecorder {
  ListeningRecorder(this._ref);

  final Ref _ref;

  Future<void> record(ListeningEvent event) async {
    if (!_ref.read(dnaSettingsProvider).recordsHistory) {
      return;
    }
    try {
      await _ref.read(tasteRepositoryProvider).recordEvent(event);
    } on Object {
      // History is optional; playback must never fail because of it.
    }
  }
}

final listeningRecorderProvider = Provider<ListeningRecorder>(
  ListeningRecorder.new,
);
