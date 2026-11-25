import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import 'update_source.dart';

/// One entry of a ZIP central directory.
class ZipEntry {
  const ZipEntry({
    required this.name,
    required this.method,
    required this.flags,
    required this.crc32,
    required this.compressedSize,
    required this.size,
    required this.localOffset,
    required this.externalAttributes,
    required this.madeBy,
  });

  final String name;
  final int method;
  final int flags;
  final int crc32;
  final int compressedSize;
  final int size;
  final int localOffset;
  final int externalAttributes;
  final int madeBy;

  bool get isDirectory => name.endsWith('/');
}

/// What a checked update package contains.
class PackageLayout {
  const PackageLayout(this.topFolder, this.entries);

  /// The one folder at the top of the archive (`NEXA_Music_x.y.z_...`).
  final String topFolder;
  final List<ZipEntry> entries;

  int get totalSize => entries.fold(0, (s, e) => s + e.size);
}

Never _unsafe(String why) =>
    throw UpdateException(UpdateProblem.unsafePackage, why);

Never _corrupt(String why) =>
    throw UpdateException(UpdateProblem.corruptPackage, why);

/// Largest unpacked package accepted (the 1.1 Portable folder is ~60 MB).
const int kMaxPackageSize = 1024 * 1024 * 1024;

/// Reads the central directory of [file]. ZIP64, multi-disk archives and
/// anything that does not parse are refused.
List<ZipEntry> readZipDirectory(File file) {
  final raf = file.openSync();
  try {
    final length = raf.lengthSync();
    if (length < 22) {
      _corrupt('too short');
    }
    final tailSize = length < 65557 ? length : 65557;
    raf.setPositionSync(length - tailSize);
    final tail = raf.readSync(tailSize);
    var eocd = -1;
    for (var i = tail.length - 22; i >= 0; i--) {
      if (tail[i] == 0x50 &&
          tail[i + 1] == 0x4b &&
          tail[i + 2] == 0x05 &&
          tail[i + 3] == 0x06) {
        eocd = i;
        break;
      }
    }
    if (eocd < 0) {
      _corrupt('no end of central directory');
    }
    final e = ByteData.sublistView(tail, eocd);
    final disk = e.getUint16(4, Endian.little);
    final cdDisk = e.getUint16(6, Endian.little);
    final countHere = e.getUint16(8, Endian.little);
    final count = e.getUint16(10, Endian.little);
    final cdSize = e.getUint32(12, Endian.little);
    final cdOffset = e.getUint32(16, Endian.little);
    if (disk != 0 || cdDisk != 0 || countHere != count) {
      _unsafe('multi-part archive');
    }
    if (count == 0xFFFF || cdSize == 0xFFFFFFFF || cdOffset == 0xFFFFFFFF) {
      _unsafe('ZIP64 archive');
    }
    if (cdOffset + cdSize > length - tailSize + eocd) {
      _corrupt('central directory out of range');
    }
    raf.setPositionSync(cdOffset);
    final cd = raf.readSync(cdSize);
    final d = ByteData.sublistView(cd);
    final entries = <ZipEntry>[];
    var at = 0;
    for (var n = 0; n < count; n++) {
      if (at + 46 > cd.length || d.getUint32(at, Endian.little) != 0x02014b50) {
        _corrupt('bad central directory entry $n');
      }
      final nameLen = d.getUint16(at + 28, Endian.little);
      final extraLen = d.getUint16(at + 30, Endian.little);
      final commentLen = d.getUint16(at + 32, Endian.little);
      final end = at + 46 + nameLen + extraLen + commentLen;
      if (end > cd.length) {
        _corrupt('entry $n out of range');
      }
      final flags = d.getUint16(at + 8, Endian.little);
      final raw = cd.sublist(at + 46, at + 46 + nameLen);
      final String name;
      try {
        // Bit 11: UTF-8 names. Without it only plain ASCII is accepted, so
        // a name can never mean two different things.
        if (flags & 0x800 == 0 && raw.any((b) => b > 0x7e)) {
          _unsafe('non-UTF-8 name in entry $n');
        }
        name = utf8.decode(raw);
      } on FormatException {
        _unsafe('undecodable name in entry $n');
      }
      final compressed = d.getUint32(at + 20, Endian.little);
      final size = d.getUint32(at + 24, Endian.little);
      final offset = d.getUint32(at + 42, Endian.little);
      if (compressed == 0xFFFFFFFF || size == 0xFFFFFFFF || offset == 0xFFFFFFFF) {
        _unsafe('ZIP64 entry $name');
      }
      entries.add(
        ZipEntry(
          name: name,
          method: d.getUint16(at + 10, Endian.little),
          flags: flags,
          crc32: d.getUint32(at + 16, Endian.little),
          compressedSize: compressed,
          size: size,
          localOffset: offset,
          externalAttributes: d.getUint32(at + 38, Endian.little),
          madeBy: d.getUint16(at + 4, Endian.little),
        ),
      );
      at = end;
    }
    return entries;
  } finally {
    raf.closeSync();
  }
}

const Set<String> _reserved = {
  'con', 'prn', 'aux', 'nul', //
  'com1', 'com2', 'com3', 'com4', 'com5', 'com6', 'com7', 'com8', 'com9',
  'lpt1', 'lpt2', 'lpt3', 'lpt4', 'lpt5', 'lpt6', 'lpt7', 'lpt8', 'lpt9',
};

/// Checks every name and attribute of an update package: no absolute
/// paths, no `..`, no names Windows reads differently (`\`, `:`, trailing
/// dots or spaces, device names), no links, no duplicates (Windows ignores
/// case), no file that is also a folder, no encryption, only stored or
/// deflated data, one top folder with `nexa_music.exe`.
PackageLayout checkPackage(List<ZipEntry> entries) {
  if (entries.isEmpty) {
    _corrupt('empty archive');
  }
  final seen = <String>{};
  final files = <String>{};
  final dirs = <String>{};
  String? top;
  var total = 0;
  for (final e in entries) {
    final name = e.name;
    if (name.isEmpty || name.length > 400) {
      _unsafe('bad name length');
    }
    if (name.contains('\\')) {
      _unsafe('backslash in "$name"');
    }
    if (name.startsWith('/') || RegExp(r'^[A-Za-z]:').hasMatch(name)) {
      _unsafe('absolute path "$name"');
    }
    if (RegExp(r'[\x00-\x1f<>:"|?*]').hasMatch(name)) {
      _unsafe('character not allowed in "$name"');
    }
    final trimmed = e.isDirectory ? name.substring(0, name.length - 1) : name;
    final parts = trimmed.split('/');
    for (final part in parts) {
      if (part.isEmpty || part == '.' || part == '..') {
        _unsafe('path traversal or empty part in "$name"');
      }
      if (part.endsWith('.') || part.endsWith(' ') || part.startsWith(' ')) {
        _unsafe('ambiguous name "$name"');
      }
      if (_reserved.contains(part.split('.').first.toLowerCase())) {
        _unsafe('device name in "$name"');
      }
    }
    if (e.flags & 0x1 != 0) {
      _unsafe('encrypted entry "$name"');
    }
    if (e.method != 0 && e.method != 8) {
      _unsafe('compression method ${e.method} in "$name"');
    }
    final host = e.madeBy >> 8;
    final unixType = (e.externalAttributes >> 16) & 0xF000;
    if ((host == 3 && unixType == 0xA000) ||
        (e.externalAttributes & 0x400) != 0) {
      _unsafe('link "$name"');
    }
    if (e.isDirectory && e.size != 0) {
      _unsafe('folder with data "$name"');
    }
    final key = trimmed.toLowerCase();
    if (!seen.add(key)) {
      _unsafe('duplicate "$name"');
    }
    (e.isDirectory ? dirs : files).add(key);
    final first = parts.first;
    if (top == null) {
      top = first;
    } else if (top.toLowerCase() != first.toLowerCase()) {
      _unsafe('more than one top folder');
    }
    if (!e.isDirectory && parts.length < 2) {
      _unsafe('file outside the top folder "$name"');
    }
    total += e.size;
    if (total > kMaxPackageSize) {
      _unsafe('package too large');
    }
  }
  // A file must never be a folder of another entry.
  for (final key in seen) {
    final parts = key.split('/');
    for (var i = 1; i < parts.length; i++) {
      if (files.contains(parts.take(i).join('/'))) {
        _unsafe('"${parts.take(i).join('/')}" is a file and a folder');
      }
    }
  }
  if (!files.contains('${top!.toLowerCase()}/nexa_music.exe')) {
    _unsafe('no nexa_music.exe in the top folder');
  }
  return PackageLayout(top, entries);
}

/// CRC-32 (ZIP, IEEE 802.3).
class Crc32 {
  static final Uint32List _table = () {
    final t = Uint32List(256);
    for (var n = 0; n < 256; n++) {
      var c = n;
      for (var k = 0; k < 8; k++) {
        c = (c & 1) != 0 ? 0xEDB88320 ^ (c >> 1) : c >> 1;
      }
      t[n] = c;
    }
    return t;
  }();

  int _crc = 0xFFFFFFFF;

  void add(List<int> data) {
    var c = _crc;
    for (final b in data) {
      c = _table[(c ^ b) & 0xFF] ^ (c >> 8);
    }
    _crc = c;
  }

  int get value => (_crc ^ 0xFFFFFFFF) & 0xFFFFFFFF;
}

/// Unpacks a checked [layout] of [zip] into [target] (which must not
/// exist yet; it is created). Every entry's local header must agree with
/// the central directory, every CRC-32 and size must match, and no file
/// can land outside [target]. Returns the unpacked top folder.
Future<Directory> extractPackage(
  File zip,
  PackageLayout layout,
  Directory target, {
  void Function(int done, int total)? onProgress,
}) async {
  if (target.existsSync()) {
    throw StateError('staging folder exists: ${target.path}');
  }
  target.createSync(recursive: true);
  final root = p.normalize(target.absolute.path);
  final raf = await zip.open();
  var done = 0;
  try {
    for (final e in layout.entries) {
      final out = p.normalize(p.join(root, p.joinAll(e.name.split('/'))));
      if (!p.isWithin(root, out)) {
        _unsafe('"${e.name}" would land outside the staging folder');
      }
      if (e.isDirectory) {
        Directory(out).createSync(recursive: true);
        continue;
      }
      await raf.setPosition(e.localOffset);
      final h = ByteData.sublistView(await raf.read(30));
      if (h.lengthInBytes < 30 || h.getUint32(0, Endian.little) != 0x04034b50) {
        _corrupt('bad local header of "${e.name}"');
      }
      final nameLen = h.getUint16(26, Endian.little);
      final extraLen = h.getUint16(28, Endian.little);
      final localName = utf8.decode(await raf.read(nameLen), allowMalformed: true);
      if (localName != e.name || h.getUint16(8, Endian.little) != e.method) {
        _unsafe('local header differs for "${e.name}"');
      }
      await raf.setPosition(e.localOffset + 30 + nameLen + extraLen);
      Directory(p.dirname(out)).createSync(recursive: true);
      final sink = File(out).openWrite();
      final crc = Crc32();
      var written = 0;
      void write(List<int> chunk) {
        written += chunk.length;
        if (written > e.size) {
          _corrupt('"${e.name}" is larger than declared');
        }
        crc.add(chunk);
        sink.add(chunk);
      }

      try {
        var left = e.compressedSize;
        if (e.method == 0) {
          while (left > 0) {
            final chunk = await raf.read(left < 65536 ? left : 65536);
            if (chunk.isEmpty) {
              _corrupt('"${e.name}" is cut off');
            }
            left -= chunk.length;
            write(chunk);
          }
        } else {
          final inflate = ZLibDecoder(raw: true).startChunkedConversion(
            _ChunkSink(write),
          );
          while (left > 0) {
            final chunk = await raf.read(left < 65536 ? left : 65536);
            if (chunk.isEmpty) {
              _corrupt('"${e.name}" is cut off');
            }
            left -= chunk.length;
            inflate.add(chunk);
          }
          inflate.close();
        }
      } on FormatException catch (x) {
        _corrupt('"${e.name}": ${x.message}');
      } finally {
        await sink.close();
      }
      if (written != e.size || crc.value != e.crc32) {
        _corrupt('"${e.name}" does not match its CRC-32');
      }
      done += e.size;
      onProgress?.call(done, layout.totalSize);
    }
  } on FileSystemException catch (x) {
    // ERROR_DISK_FULL / ERROR_HANDLE_DISK_FULL
    final code = x.osError?.errorCode;
    if (code == 112 || code == 39) {
      throw const UpdateException(UpdateProblem.noDiskSpace);
    }
    rethrow;
  } finally {
    await raf.close();
  }
  return Directory(p.join(root, layout.topFolder));
}

class _ChunkSink implements Sink<List<int>> {
  _ChunkSink(this.onChunk);

  final void Function(List<int>) onChunk;

  @override
  void add(List<int> data) => onChunk(data);

  @override
  void close() {}
}

/// SHA-256 of a file, lower-case hex.
Future<String> sha256OfFile(File f) async =>
    (await sha256.bind(f.openRead()).first).toString();

/// The package's own list of files (`SHA256SUMS.txt` in its top folder),
/// when it has one: every listed file must match and nothing may be
/// missing or extra.
Future<void> checkPackageFiles(Directory folder) async {
  final list = File(p.join(folder.path, 'SHA256SUMS.txt'));
  if (!list.existsSync()) {
    return;
  }
  final expected = <String, String>{};
  for (final line in await list.readAsLines()) {
    final m = RegExp(r'^([0-9a-fA-F]{64}) [ *]?(.+)$').firstMatch(line.trim());
    if (m != null) {
      expected[m[2]!.trim().replaceAll('\\', '/').toLowerCase()] =
          m[1]!.toLowerCase();
    }
  }
  if (expected.isEmpty) {
    _corrupt('SHA256SUMS.txt lists no files');
  }
  final root = p.normalize(folder.absolute.path);
  final present = <String>{};
  for (final f in folder.listSync(recursive: true).whereType<File>()) {
    final rel = p.relative(f.path, from: root).replaceAll('\\', '/');
    if (rel.toLowerCase() == 'sha256sums.txt') {
      continue;
    }
    present.add(rel.toLowerCase());
    final want = expected[rel.toLowerCase()];
    if (want == null) {
      _corrupt('"$rel" is not in the package list');
    }
    if (await sha256OfFile(f) != want) {
      _corrupt('"$rel" differs from the package list');
    }
  }
  final missing = expected.keys.where((k) => !present.contains(k)).toList();
  if (missing.isNotEmpty) {
    _corrupt('missing from the package: ${missing.first}');
  }
}
