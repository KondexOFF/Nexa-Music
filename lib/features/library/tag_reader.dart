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
    meta = readMetadata(file, getImage: true);
  } on Object {
    // Unreadable or untagged file: still list it with fallback values.
    meta = null;
  }
  final year = meta?.year?.year;
  return TagResult(
    path: path,
    title: _clean(meta?.title) ?? fallbackTitle,
    artist: _clean(meta?.artist) ?? _clean(meta?.albumArtist) ?? unknownArtist,
    album: _clean(meta?.album) ?? unknownAlbum,
    albumArtist: _clean(meta?.albumArtist),
    genre: meta == null || meta.genres.isEmpty ? null : _clean(meta.genres.first),
    year: (year == null || year <= 0) ? null : year,
    trackNumber: meta?.trackNumber,
    discNumber: meta?.discNumber,
    duration: meta?.duration,
    artworkPath:
        _saveEmbeddedCover(meta?.pictures ?? const [], artworkDir) ??
        findFolderCover(p.dirname(path)),
  );
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
