import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:media_kit/media_kit.dart';
import 'package:path/path.dart' as p;

import 'audio_analysis.dart';

/// Turns a local audio file into a 16-bit mono WAV file for measuring.
abstract interface class AudioDecoder {
  /// Writes [output]; false when the file could not be decoded.
  Future<bool> decode(String input, String output);
}

/// Decodes with NEXA's own libmpv in a separate, silent player (D-026):
/// the "pcm" output writes a WAV file instead of using a sound device, and
/// "untimed" decodes as fast as possible (about 0.1 s for a 40 s file on
/// the owner's PC, log 265). The playback decks are never touched.
class MpvPcmDecoder implements AudioDecoder {
  const MpvPcmDecoder({this.timeout = const Duration(seconds: 60)});

  final Duration timeout;

  @override
  Future<bool> decode(String input, String output) async {
    final player = Player(
      configuration: const PlayerConfiguration(title: 'NEXA analysis'),
    );
    final failed = Completer<void>();
    final sub = player.stream.error.listen((_) {
      if (!failed.isCompleted) {
        failed.complete();
      }
    });
    try {
      final native = player.platform! as NativePlayer;
      for (final e in {
        'vid': 'no',
        'ao': 'pcm',
        'ao-pcm-file': output,
        'ao-pcm-waveheader': 'yes',
        'untimed': 'yes',
        'audio-samplerate': '${AudioAnalyzer.sampleRate}',
        'audio-channels': 'mono',
        'audio-format': 's16',
        'volume': '100',
      }.entries) {
        await native.setProperty(e.key, e.value);
      }
      if (!(await native.getProperty('ao')).contains('pcm')) {
        return false; // Never decode onto a sound device.
      }
      await player.open(Media(input));
      final end = DateTime.now().add(timeout);
      while (!player.state.completed && !failed.isCompleted) {
        if (DateTime.now().isAfter(end)) {
          return false;
        }
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
      return player.state.completed;
    } on Object {
      return false;
    } finally {
      await sub.cancel();
      await player.dispose();
    }
  }
}

/// Smart Mix file analysis (D-026): measures local files one at a time,
/// apart from playback, and keeps the results in a cache file.
///
/// A result belongs to the file's path, size and modification time; a
/// changed file is measured again. Online sources are never analysed.
class AudioAnalyzer {
  AudioAnalyzer({
    required this.decoder,
    this.cacheDir,
    this.maxDuration = const Duration(minutes: 20),
  });

  /// Rate of the decoded samples (enough for levels and silence).
  static const int sampleRate = 11025;

  /// Name of the cache file in NEXA's data folder.
  static const String cacheName = 'smart_mix_analysis.json';

  /// Most files kept in the cache.
  static const int maxEntries = 5000;

  final AudioDecoder? decoder;
  /// NEXA's data folder (no cache file without it).
  final Future<Directory> Function()? cacheDir;

  /// Longer files (mixes, audiobooks) are not measured.
  final Duration maxDuration;

  final Map<String, _Entry> _entries = {};
  final Set<String> _failed = {};
  final Set<String> _queued = {};
  final StreamController<String> _done = StreamController.broadcast();
  Future<void>? _loading;
  Future<void> _worker = Future.value();
  bool _disposed = false;

  /// Paths whose analysis has just finished.
  Stream<String> get updates => _done.stream;

  /// The measurement of [path] if it is cached and the file is unchanged.
  AudioAnalysis? cached(String path) {
    final e = _entries[path];
    if (e == null) {
      return null;
    }
    final stat = _stat(path);
    if (stat == null || stat.$1 != e.size || stat.$2 != e.modified) {
      return null;
    }
    return e.analysis;
  }

  /// Measures [path] in the background (once; failures are not retried in
  /// this session). Calls for the same file share one measurement.
  void request(String path, {Duration? duration}) {
    if (_disposed ||
        decoder == null ||
        _queued.contains(path) ||
        _failed.contains(path) ||
        (duration != null && duration > maxDuration)) {
      return;
    }
    _queued.add(path);
    _worker = _worker.then((_) => _run(path));
  }

  Future<void> _run(String path) async {
    try {
      await _load();
      if (_disposed || cached(path) != null) {
        return;
      }
      final result = await _measure(path);
      if (_disposed) {
        return;
      }
      final stat = _stat(path);
      if (result == null || stat == null) {
        _failed.add(path);
        return;
      }
      _entries.remove(path);
      _entries[path] = _Entry(stat.$1, stat.$2, result);
      while (_entries.length > maxEntries) {
        _entries.remove(_entries.keys.first);
      }
      await _save();
      _done.add(path);
    } on Object {
      _failed.add(path);
    } finally {
      _queued.remove(path);
    }
  }

  Future<AudioAnalysis?> _measure(String path) async {
    if (!File(path).existsSync()) {
      return null;
    }
    final temp = await Directory.systemTemp.createTemp('nexa_mix');
    try {
      final wav = p.join(temp.path, 'decoded.wav');
      if (!await decoder!.decode(path, wav) || !File(wav).existsSync()) {
        return null;
      }
      return await _measureFile(wav);
    } finally {
      try {
        await temp.delete(recursive: true);
      } on FileSystemException {
        // A leftover temp folder is harmless.
      }
    }
  }

  /// Measured in another isolate: the UI never waits for it. (Static, so
  /// the closure sends only the path.)
  static Future<AudioAnalysis?> _measureFile(String wav) => Isolate.run(
    () => AudioAnalysis.measureWav(File(wav).readAsBytesSync()),
  );

  Future<File?> _cacheFile() async {
    final dir = cacheDir;
    if (dir == null) {
      return null;
    }
    return File(p.join((await dir()).path, cacheName));
  }

  Future<void> _load() => _loading ??= () async {
    try {
      final file = await _cacheFile();
      if (file == null || !file.existsSync()) {
        return;
      }
      final json = jsonDecode(await file.readAsString());
      if (json is! Map || json['v'] != AudioAnalysis.version) {
        return; // Older format: measured again.
      }
      final files = json['files'];
      if (files is! Map) {
        return;
      }
      for (final MapEntry(:key, :value) in files.entries) {
        if (key is! String || value is! Map) {
          continue;
        }
        final a = AudioAnalysis.fromJson(value.cast<String, Object?>());
        final size = value['size'];
        final modified = value['modified'];
        if (a != null && size is int && modified is int) {
          _entries.putIfAbsent(key, () => _Entry(size, modified, a));
        }
      }
    } on Object {
      // A damaged cache is measured again.
    }
  }();

  Future<void> _save() async {
    final file = await _cacheFile();
    if (file == null) {
      return;
    }
    final json = {
      'v': AudioAnalysis.version,
      'files': {
        for (final MapEntry(:key, :value) in _entries.entries)
          key: {
            ...value.analysis.toJson(),
            'size': value.size,
            'modified': value.modified,
          },
      },
    };
    final temp = File('${file.path}.tmp');
    await temp.writeAsString(jsonEncode(json), flush: true);
    await temp.rename(file.path);
  }

  static (int, int)? _stat(String path) {
    try {
      final s = File(path).statSync();
      if (s.type != FileSystemEntityType.file) {
        return null;
      }
      return (s.size, s.modified.millisecondsSinceEpoch);
    } on Object {
      return null;
    }
  }

  /// Waits for the measurements already asked for (tests).
  Future<void> get idle => _worker;

  Future<void> dispose() async {
    _disposed = true;
    await _done.close();
  }
}

class _Entry {
  const _Entry(this.size, this.modified, this.analysis);

  final int size;
  final int modified;
  final AudioAnalysis analysis;
}
