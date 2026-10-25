import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

/// Audio formats imported in v1.0 (Master Plan: MP3, FLAC, WAV).
const Set<String> kSupportedAudioExtensions = {'.mp3', '.flac', '.wav'};

bool isSupportedAudioFile(String path) =>
    kSupportedAudioExtensions.contains(p.extension(path).toLowerCase());

/// Normalised key of a file or folder path, used to recognise the same file
/// across scans (Windows paths are case-insensitive).
String pathKeyOf(String path) {
  final normalised = p.normalize(p.absolute(path));
  return Platform.isWindows ? normalised.toLowerCase() : normalised;
}

/// Metadata read from one audio file. Missing tags fall back to the file
/// name / "Unknown ..." so that every file can still be listed.
class TagResult {
  const TagResult({
    required this.path,
    required this.title,
    required this.artist,
    required this.album,
    this.albumArtist,
    this.genre,
    this.year,
    this.trackNumber,
    this.discNumber,
    this.duration,
    this.artworkPath,
    this.error,
  });

  final String path;
  final String title;
  final String artist;
  final String album;
  final String? albumArtist;
  final String? genre;
  final int? year;
  final int? trackNumber;
  final int? discNumber;
  final Duration? duration;
  final String? artworkPath;

  /// Set when the file could not be opened at all.
  final String? error;
}

/// Reads tags and cover art. Replaceable in tests.
abstract interface class TagReader {
  /// Reads [paths]; embedded covers are saved into [artworkDir].
  Future<List<TagResult>> readAll(List<String> paths, String artworkDir);
}

/// [TagReader] based on the pure-Dart `audio_metadata_reader` package.
/// Parsing runs in a background isolate so the UI stays responsive.
class AudioTagReader implements TagReader {
  const AudioTagReader();

  @override
  Future<List<TagResult>> readAll(List<String> paths, String artworkDir) {
    if (paths.isEmpty) {
      return Future.value(const []);
    }
    return Isolate.run(() => [for (final path in paths) readTags(path, artworkDir)]);
  }
}

const String unknownArtist = 'Unknown artist';
const String unknownAlbum = 'Unknown album';

String? _clean(String? value) {
  final v = value?.replaceAll('\u0000', '').trim();
  return (v == null || v.isEmpty) ? null : v;
}

/// Reads one file synchronously (call from an isolate).
TagResult readTags(String path, String artworkDir) {
  final file = File(path);
  final fallbackTitle = p.basenameWithoutExtension(path);
  if (!file.existsSync()) {
    return TagResult(
      path: path,
      title: fallbackTitle,
      artist: unknownArtist,
      album: unknownAlbum,
      error: 'File not found',
    );
  }
  AudioMetadata? meta;
  try {
    meta = readAudioMetadata(file, getImage: true);
  } on Object {
    // Unreadable or untagged file: still list it with fallback values.
    meta = null;
  }
  final year = meta?.year?.year;
  // WAV (RIFF INFO) text is decoded as Latin-1 by the package; most tools
  // write UTF-8 there (TD-04), so such text is decoded again as UTF-8.
  final isWav = p.extension(path).toLowerCase() == '.wav';
  String? text(String? value) => _clean(isWav ? repairUtf8(value) : value);
  return TagResult(
    path: path,
    title: text(meta?.title) ?? fallbackTitle,
    artist: text(meta?.artist) ?? text(meta?.albumArtist) ?? unknownArtist,
    album: text(meta?.album) ?? unknownAlbum,
    albumArtist: text(meta?.albumArtist),
    genre: meta == null || meta.genres.isEmpty ? null : text(meta.genres.first),
    year: (year == null || year <= 0) ? null : year,
    trackNumber: meta?.trackNumber,
    discNumber: meta?.discNumber,
    duration: meta?.duration,
    artworkPath:
        _saveEmbeddedCover(meta?.pictures ?? const [], artworkDir) ??
        findFolderCover(p.dirname(path)),
  );
}

/// [value] read as Latin-1 although its bytes are UTF-8 ("ÐÐµÑÐ½Ñ" for
/// "Песня"): returns the UTF-8 text. Anything else (plain ASCII, real
/// Latin-1 such as "Café", text with characters above U+00FF, bytes that are
/// not valid UTF-8) is returned unchanged.
String? repairUtf8(String? value) {
  if (value == null || !value.codeUnits.any((u) => u >= 0x80)) {
    return value;
  }
  if (value.codeUnits.any((u) => u > 0xFF)) {
    return value;
  }
  try {
    return utf8.decode(latin1.encode(value));
  } on FormatException {
    return value;
  }
}

String? _saveEmbeddedCover(List<Picture> pictures, String artworkDir) {
  if (pictures.isEmpty || artworkDir.isEmpty) {
    return null;
  }
  final picture = pictures.firstWhere(
    (pic) => pic.pictureType == PictureType.coverFront,
    orElse: () => pictures.first,
  );
  final Uint8List bytes = picture.bytes;
  if (bytes.isEmpty) {
    return null;
  }
  final ext = picture.mimetype.contains('png') ? 'png' : 'jpg';
  final out = File(p.join(artworkDir, '${sha1.convert(bytes)}.$ext'));
  try {
    if (!out.existsSync()) {
      out.parent.createSync(recursive: true);
      out.writeAsBytesSync(bytes, flush: true);
    }
    return out.path;
  } on FileSystemException {
    return null;
  }
}

const List<String> _folderCoverNames = [
  'cover.jpg',
  'cover.png',
  'folder.jpg',
  'folder.png',
  'front.jpg',
  'front.png',
];

/// A cover image file next to the music (cover.jpg, folder.jpg, ...).
String? findFolderCover(String directory) {
  for (final name in _folderCoverNames) {
    final candidate = File(p.join(directory, name));
    if (candidate.existsSync()) {
      return candidate.path;
    }
  }
  return null;
}

/// `readMetadata` plus FLAC files that start with an ID3v2 tag (written by
/// some taggers and by FFmpeg). The package picks its parser from the first
/// bytes, so such a file went to the MP3 parser: no tags and a wrong length.
/// For them the FLAC blocks after the ID3 tag are parsed instead.
AudioMetadata readAudioMetadata(File file, {bool getImage = false}) {
  if (p.extension(file.path).toLowerCase() == '.flac') {
    final raf = file.openSync();
    try {
      final offset = flacStreamOffset(raf);
      if (offset != null && offset > 0) {
        final vorbis = FlacParser(fetchImage: getImage).parse(_OffsetFile(raf, offset));
        return AudioMetadata(
            file: file,
            album: vorbis.album.firstOrNull,
            albumArtist: vorbis.albumArtist.firstOrNull,
            artist: vorbis.artist.firstOrNull,
            bitrate: vorbis.bitrate,
            discNumber: vorbis.discNumber,
            duration: vorbis.duration,
            language: vorbis.language.firstOrNull,
            lyrics: vorbis.lyric,
            sampleRate: vorbis.sampleRate,
            title: vorbis.title.firstOrNull,
            totalDisc: vorbis.discTotal,
            trackNumber: vorbis.trackNumber.firstOrNull,
            trackTotal: vorbis.trackTotal,
            year: vorbis.date.firstOrNull,
          )
          ..genres = vorbis.genres
          ..pictures = vorbis.pictures;
      }
    } finally {
      raf.closeSync();
    }
  }
  return readMetadata(file, getImage: getImage);
}

/// Position of the `fLaC` marker after any leading ID3v2 tags, or null.
int? flacStreamOffset(RandomAccessFile raf) {
  var pos = 0;
  final length = raf.lengthSync();
  while (pos + 10 <= length) {
    raf.setPositionSync(pos);
    final head = raf.readSync(10);
    if (head.length < 10) {
      return null;
    }
    if (head[0] == 0x66 && head[1] == 0x4C && head[2] == 0x61 && head[3] == 0x43) {
      return pos; // "fLaC"
    }
    if (head[0] != 0x49 || head[1] != 0x44 || head[2] != 0x33) {
      return null; // neither "ID3" nor "fLaC"
    }
    final size = (head[6] & 0x7F) << 21 | (head[7] & 0x7F) << 14 | (head[8] & 0x7F) << 7 | (head[9] & 0x7F);
    final footer = (head[5] & 0x10) != 0 ? 10 : 0;
    pos += 10 + size + footer;
  }
  return null;
}

/// Read-only view of [_raf] that starts at [_offset] (only the calls the
/// FLAC parser makes are supported).
class _OffsetFile implements RandomAccessFile {
  _OffsetFile(this._raf, this._offset);

  final RandomAccessFile _raf;
  final int _offset;

  @override
  RandomAccessFile setPositionSync(int position) {
    _raf.setPositionSync(position + _offset);
    return this;
  }

  @override
  int positionSync() => _raf.positionSync() - _offset;

  @override
  int lengthSync() => _raf.lengthSync() - _offset;

  @override
  Uint8List readSync(int count) => _raf.readSync(count);

  @override
  int readIntoSync(List<int> buffer, [int start = 0, int? end]) => _raf.readIntoSync(buffer, start, end);

  @override
  String get path => _raf.path;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('Not supported by the FLAC offset reader');
}
