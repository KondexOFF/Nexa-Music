// D-030 update-chain test: test profiles for NEXA Update Center - a library
// with songs, playlists, favourites, listening history, a taste profile and
// settings, written by NEXA's own repositories (schema of this build).
//
//   NEXA_D030_SEED_DIR=<folder> flutter test integration_test/d030_seed_test.dart -d windows
//
// Creates <folder>/main, <folder>/err (both the same data) and
// <folder>/off (the same, with the daily update check switched off). Every
// song is a short silent WAV inside the profile; invented names only.
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:nexa_music/core/database/app_database.dart';
import 'package:nexa_music/core/models/listening.dart';
import 'package:nexa_music/core/settings/settings_repository.dart';
import 'package:nexa_music/features/library/library_repository.dart';
import 'package:nexa_music/features/nexa_dna/taste_repository.dart';
import 'package:path/path.dart' as p;

void silentWav(String path) {
  const rate = 8000;
  const n = rate;
  final h = ByteData(44)
    ..setUint32(0, 0x46464952, Endian.little)
    ..setUint32(4, 36 + n * 2, Endian.little)
    ..setUint32(8, 0x45564157, Endian.little)
    ..setUint32(12, 0x20746d66, Endian.little)
    ..setUint32(16, 16, Endian.little)
    ..setUint16(20, 1, Endian.little)
    ..setUint16(22, 1, Endian.little)
    ..setUint32(24, rate, Endian.little)
    ..setUint32(28, rate * 2, Endian.little)
    ..setUint16(32, 2, Endian.little)
    ..setUint16(34, 16, Endian.little)
    ..setUint32(36, 0x61746164, Endian.little)
    ..setUint32(40, n * 2, Endian.little);
  File(path).writeAsBytesSync([...h.buffer.asUint8List(), ...Uint8List(n * 2)]);
}

Future<void> seed(Directory profile, {required bool autoCheck}) async {
  final music = Directory(p.join(profile.path, 'music'))..createSync(recursive: true);
  final db = AppDatabase(NativeDatabase(File(p.join(profile.path, 'nexa_library.sqlite'))));
  try {
    final ids = <int>[];
    const songs = ['Harbor Lights', 'Paper Moon Drive', 'Glass Rivers', 'Night Tram', 'Lantern Song', 'Blue Hour'];
    for (final (i, title) in songs.indexed) {
      final path = p.join(music.path, '${i + 1}.wav');
      silentWav(path);
      ids.add(
        await db
            .into(db.tracks)
            .insert(
              TracksCompanion.insert(
                pathKey: p.normalize(path).toLowerCase(),
                path: path,
                title: title,
                artist: i.isEven ? 'Test Artist North' : 'Test Artist South',
                album: 'D-030 Album',
                genre: const Value('Ambient'),
                durationMs: const Value(1000),
                fileSize: File(path).lengthSync(),
                fileModified: DateTime(2026),
                searchText: title.toLowerCase(),
                addedAt: DateTime(2026, 11, 1).add(Duration(hours: i)),
              ),
            ),
      );
    }
    final lib = LibraryRepository(db);
    for (final i in [0, 2, 5]) {
      await lib.setFavorite(ids[i], true);
    }
    final a = await lib.createPlaylist('Update Night Mix');
    await lib.addToPlaylist(a, [ids[0], ids[3], ids[1]]);
    final b = await lib.createPlaylist('Rollback Morning');
    await lib.addToPlaylist(b, [ids[4], ids[5]]);
    final taste = TasteRepository(db);
    await taste.setItem(TasteKind.genre, 'Ambient');
    await taste.setItem(TasteKind.artist, 'Test Artist North');
    final now = DateTime.now();
    for (var k = 0; k < 7; k++) {
      await taste.recordEvent(
        ListeningEvent(
          trackId: ids[k % ids.length],
          startedAt: now.subtract(Duration(hours: 3 + k)),
          listened: const Duration(seconds: 1),
          reason: EndReason.completed,
          context: PlayContext.library,
        ),
      );
    }
    final settings = SettingsRepository(db);
    await settings.setDouble(SettingKeys.mixSeconds, 7);
    await settings.setBool(SettingKeys.historyConsent, true);
    await settings.setBool(SettingKeys.dnaOnboarded, true);
    await settings.setString('d030.marker', 'kept-through-updates');
    if (!autoCheck) {
      await settings.setBool(SettingKeys.updateAutoCheck, false);
    }
  } finally {
    await db.close();
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  testWidgets('D-030 test profiles', (tester) async {
    final dir = Platform.environment['NEXA_D030_SEED_DIR']?.trim() ?? '';
    expect(dir, isNotEmpty, reason: 'NEXA_D030_SEED_DIR is not set');
    await tester.runAsync(() async {
      for (final (name, auto) in [('main', true), ('err', true), ('off', false)]) {
        final profile = Directory(p.join(dir, name));
        expect(profile.existsSync(), isFalse, reason: 'never overwritten');
        profile.createSync(recursive: true);
        await seed(profile, autoCheck: auto);
      }
    });
  });
}
