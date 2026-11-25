// D-030 update-chain test: what of the user's data is in a NEXA library
// file, read-only and independent of its schema version.
//
//   dart run tools/d030/db_fingerprint.dart <nexa_library.sqlite>
//
// Prints one JSON line: schema, tables, playlists with their songs,
// favourites, listening history, taste profile and the settings the test
// profile set. Never used on the owner's library.
import 'dart:convert';
import 'dart:io';

import 'package:sqlite3/sqlite3.dart';

void main(List<String> args) {
  final db = sqlite3.open(args.single, mode: OpenMode.readOnly);
  try {
    List<Map<String, Object?>> rows(String sql) =>
        [for (final r in db.select(sql)) Map<String, Object?>.from(r)];
    final tables = [
      for (final r in rows("SELECT name FROM sqlite_master WHERE type = 'table' "
          "AND name NOT LIKE 'sqlite_%' ORDER BY name"))
        r['name'],
    ];
    final out = {
      'schema': db.userVersion,
      'tables': tables,
      'tracks': rows('SELECT COUNT(*) AS n FROM tracks').single['n'],
      'playlists': [
        for (final r in rows(
          'SELECT p.name AS name, GROUP_CONCAT(t.title, \'|\') AS songs '
          'FROM playlists p LEFT JOIN (SELECT e.playlist_id, t.title FROM '
          'playlist_entries e JOIN tracks t ON t.id = e.track_id ORDER BY '
          'e.playlist_id, e.position) t ON t.playlist_id = p.id '
          'GROUP BY p.id ORDER BY p.name',
        ))
          '${r['name']}: ${r['songs'] ?? ''}',
      ],
      'favorites': [
        for (final r in rows(
          'SELECT title FROM tracks WHERE favorite = 1 ORDER BY title',
        ))
          r['title'],
      ],
      'history': rows('SELECT COUNT(*) AS n FROM listening_events').single['n'],
      'taste': [
        for (final r in rows(
          'SELECT kind, value FROM taste_items ORDER BY kind, value',
        ))
          '${r['kind']}:${r['value']}',
      ],
      'settings': {
        for (final r in rows(
          "SELECT key, value FROM app_settings WHERE key LIKE 'd030.%' "
          "OR key IN ('mix.seconds', 'mix.mode', 'dna.historyConsent') "
          'ORDER BY key',
        ))
          '${r['key']}': r['value'],
      },
    };
    stdout.writeln(jsonEncode(out));
  } finally {
    db.close();
  }
}
