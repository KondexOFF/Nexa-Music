import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../core/models/track.dart';

/// Why a catalog request failed.
enum CatalogErrorKind {
  /// No network / the provider cannot be reached.
  offline,

  /// The provider limits how often it may be asked.
  rateLimited,

  /// A key / client id is missing or was rejected.
  notConfigured,

  /// Anything else the provider answered with.
  provider,
}

class CatalogException implements Exception {
  const CatalogException(this.kind, [this.detail]);

  final CatalogErrorKind kind;
  final String? detail;

  @override
  String toString() => 'CatalogException($kind${detail == null ? '' : ': $detail'})';
}

/// An official online catalog (Master Plan v1.0, Phase 6; D-017).
///
/// Implementations return [Track]s whose [Track.path] is the stream URL the
/// provider's API hands out for playback, and mark tracks the provider does
/// not allow to stream as unavailable with a reason - they are shown, never
/// promised.
abstract interface class MusicSource {
  TrackSource get source;

  /// False when the source needs a key the owner has not entered.
  bool get configured;

  Future<List<Track>> search(String query, {int limit = 20});
}

/// Shared JSON GET with the error mapping every catalog uses.
Future<Object?> getJson(
  http.Client client,
  Uri uri, {
  Map<String, String> headers = const {},
  Duration timeout = const Duration(seconds: 12),
}) async {
  final http.Response response;
  try {
    response = await client.get(uri, headers: headers).timeout(timeout);
  } on SocketException catch (e) {
    throw CatalogException(CatalogErrorKind.offline, e.message);
  } on TimeoutException {
    throw const CatalogException(CatalogErrorKind.offline, 'timeout');
  } on http.ClientException catch (e) {
    throw CatalogException(CatalogErrorKind.offline, e.message);
  }
  switch (response.statusCode) {
    case 200:
      break;
    case 429:
      throw const CatalogException(CatalogErrorKind.rateLimited);
    case 401 || 403:
      throw CatalogException(
        CatalogErrorKind.notConfigured,
        'HTTP ${response.statusCode}',
      );
    default:
      throw CatalogException(
        CatalogErrorKind.provider,
        'HTTP ${response.statusCode}',
      );
  }
  try {
    return jsonDecode(utf8.decode(response.bodyBytes));
  } on FormatException {
    throw const CatalogException(CatalogErrorKind.provider, 'invalid JSON');
  }
}

/// Small JSON helpers (provider answers are untrusted input).
String? jsonString(Object? v) => v is String && v.trim().isNotEmpty ? v.trim() : null;

int? jsonInt(Object? v) => switch (v) {
  int i => i,
  double d => d.round(),
  String s => int.tryParse(s),
  _ => null,
};
