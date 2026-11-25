/// Versions of NEXA releases: `major.minor.patch`, an optional `-pre`
/// part (a prerelease, never offered as an update) and an ignored `+build`.
class SemVer implements Comparable<SemVer> {
  const SemVer(this.major, this.minor, this.patch, [this.pre = '']);

  final int major;
  final int minor;
  final int patch;

  /// Prerelease identifiers ("rc.1"); empty for a release.
  final String pre;

  bool get isPrerelease => pre.isNotEmpty;

  static final RegExp _pattern = RegExp(
    r'^v?(0|[1-9]\d{0,5})\.(0|[1-9]\d{0,5})\.(0|[1-9]\d{0,5})'
    r'(?:-([0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*))?'
    r'(?:\+[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*)?$',
  );

  /// "v1.2.0", "1.2.0", "1.2.0-rc.1", "1.2.0+10"; null for anything else.
  static SemVer? tryParse(String text) {
    final m = _pattern.firstMatch(text.trim());
    if (m == null) {
      return null;
    }
    return SemVer(
      int.parse(m[1]!),
      int.parse(m[2]!),
      int.parse(m[3]!),
      m[4] ?? '',
    );
  }

  @override
  int compareTo(SemVer other) {
    for (final (a, b) in [
      (major, other.major),
      (minor, other.minor),
      (patch, other.patch),
    ]) {
      if (a != b) {
        return a.compareTo(b);
      }
    }
    // A release is newer than its prereleases (SemVer 2.0 §11).
    if (pre == other.pre) {
      return 0;
    }
    if (pre.isEmpty) {
      return 1;
    }
    if (other.pre.isEmpty) {
      return -1;
    }
    final x = pre.split('.');
    final y = other.pre.split('.');
    for (var i = 0; i < x.length && i < y.length; i++) {
      final nx = int.tryParse(x[i]);
      final ny = int.tryParse(y[i]);
      final c = switch ((nx, ny)) {
        (int a, int b) => a.compareTo(b),
        (int _, null) => -1,
        (null, int _) => 1,
        _ => x[i].compareTo(y[i]),
      };
      if (c != 0) {
        return c;
      }
    }
    return x.length.compareTo(y.length);
  }

  bool operator >(SemVer other) => compareTo(other) > 0;
  bool operator <(SemVer other) => compareTo(other) < 0;

  @override
  bool operator ==(Object other) => other is SemVer && compareTo(other) == 0;

  @override
  int get hashCode => Object.hash(major, minor, patch, pre);

  @override
  String toString() => '$major.$minor.$patch${pre.isEmpty ? '' : '-$pre'}';
}
