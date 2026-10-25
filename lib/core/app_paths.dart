import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Folder for NEXA's own data (library database, cached covers).
///
/// Normally the Windows application-data folder. `NEXA_DATA_DIR` points it
/// to another folder - used only by NEXA AutoTest, so automated runs never
/// touch the owner's library, playlists, history or settings.
Future<Directory> appDataDirectory() async {
  final override = Platform.environment['NEXA_DATA_DIR']?.trim() ?? '';
  if (override.isNotEmpty) {
    return Directory(override).create(recursive: true);
  }
  return getApplicationSupportDirectory();
}
