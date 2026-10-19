import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/library/library_providers.dart';
import 'settings_repository.dart';

/// Local key-value settings (player, Mix Engine ...).
final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => SettingsRepository(ref.watch(appDatabaseProvider)),
);
