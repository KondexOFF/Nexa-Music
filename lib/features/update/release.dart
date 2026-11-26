import 'semver.dart';

/// A file of a GitHub release.
class ReleaseAsset {
  const ReleaseAsset({
    required this.id,
    required this.name,
    required this.size,
    required this.apiUrl,
    required this.downloadUrl,
    this.sha256,
  });

  final int id;
  final String name;
  final int size;

  /// `.../releases/assets/<id>` (download with `Accept: octet-stream`).
  final String apiUrl;
  final String downloadUrl;

  /// SHA-256 that GitHub itself computed for the upload (the asset's
  /// `digest`), lower-case hex; null when GitHub gave none.
  final String? sha256;

  static ReleaseAsset? fromJson(Object? json) {
    if (json is! Map) {
      return null;
    }
    final id = json['id'];
    final name = json['name'];
    final size = json['size'];
    if (id is! int || name is! String || size is! int) {
      return null;
    }
    final digest = json['digest'];
    String? sha;
    if (digest is String) {
      final m = RegExp(r'^sha256:([0-9a-fA-F]{64})$').firstMatch(digest);
      sha = m?[1]!.toLowerCase();
    }
    return ReleaseAsset(
      id: id,
      name: name,
      size: size,
      apiUrl: json['url'] is String ? json['url'] as String : '',
      downloadUrl: json['browser_download_url'] is String
          ? json['browser_download_url'] as String
          : '',
      sha256: sha,
    );
  }
}

/// A published NEXA release as GitHub describes it.
class ReleaseInfo {
  const ReleaseInfo({
    required this.tag,
    required this.version,
    required this.name,
    required this.notes,
    required this.draft,
    required this.prerelease,
    required this.assets,
    this.publishedAt,
    this.pageUrl = '',
  });

  final String tag;

  /// Null when the tag is not a version.
  final SemVer? version;
  final String name;
  final String notes;
  final bool draft;
  final bool prerelease;
  final List<ReleaseAsset> assets;
  final DateTime? publishedAt;
  final String pageUrl;

  /// The Windows Portable archive of this release: `NEXARYVE_<v>_Windows_x64.zip`
  /// (D-034), or the name installed 1.1.1 copies look for,
  /// `NEXA_Music_<v>_Windows_x64.zip` - releases keep publishing that name.
  ReleaseAsset? get package {
    final v = version;
    if (v == null) {
      return null;
    }
    for (final wanted in [
      'NEXARYVE_${v}_Windows_x64.zip',
      'NEXA_Music_${v}_Windows_x64.zip',
    ]) {
      final found = assets
          .where((a) => a.name.toLowerCase() == wanted.toLowerCase())
          .firstOrNull;
      if (found != null) {
        return found;
      }
    }
    return null;
  }

  ReleaseAsset? get checksums => assets
      .where((a) => a.name.toLowerCase() == 'sha256sums.txt')
      .firstOrNull;

  static ReleaseInfo? fromJson(Object? json) {
    if (json is! Map) {
      return null;
    }
    final tag = json['tag_name'];
    if (tag is! String) {
      return null;
    }
    final assets = json['assets'];
    return ReleaseInfo(
      tag: tag,
      version: SemVer.tryParse(tag),
      name: json['name'] is String ? json['name'] as String : tag,
      notes: json['body'] is String ? json['body'] as String : '',
      draft: json['draft'] == true,
      prerelease: json['prerelease'] == true,
      assets: [
        if (assets is List)
          for (final a in assets) ?ReleaseAsset.fromJson(a),
      ],
      publishedAt: json['published_at'] is String
          ? DateTime.tryParse(json['published_at'] as String)
          : null,
      pageUrl: json['html_url'] is String ? json['html_url'] as String : '',
    );
  }

  static List<ReleaseInfo> listFromJson(Object? json) => [
    if (json is List)
      for (final r in json) ?ReleaseInfo.fromJson(r),
  ];
}

/// The newest release that is newer than [current]: drafts, prereleases
/// (by GitHub's flag or by a `-pre` version), tags that are not versions
/// and releases without a Windows package are never offered.
ReleaseInfo? newestUpdate(List<ReleaseInfo> releases, SemVer current) {
  ReleaseInfo? best;
  for (final r in releases) {
    final v = r.version;
    if (r.draft || r.prerelease || v == null || v.isPrerelease) {
      continue;
    }
    if (r.package == null || !(v > current)) {
      continue;
    }
    if (best == null || v > best.version!) {
      best = r;
    }
  }
  return best;
}

/// The SHA-256 a `SHA256SUMS.txt` gives for [fileName], or null.
String? checksumFor(String sums, String fileName) {
  for (final line in sums.split(RegExp(r'\r?\n'))) {
    final m = RegExp(r'^([0-9a-fA-F]{64}) [ *]?(.+)$').firstMatch(line.trim());
    if (m != null && m[2]!.trim().toLowerCase() == fileName.toLowerCase()) {
      return m[1]!.toLowerCase();
    }
  }
  return null;
}
