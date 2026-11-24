import 'dart:math' as math;
import 'dart:typed_data';

/// What Smart Mix knows about a local file's sound (D-026): measured once,
/// apart from playback, from the decoded samples, and cached.
///
/// All values are explainable: where the sound starts after a silent
/// intro, where the last sound ends before a silent tail, where a fading
/// outro has become quiet, and how loud the song is.
class AudioAnalysis {
  const AudioAnalysis({
    required this.duration,
    required this.soundStart,
    required this.soundEnd,
    required this.quietEnd,
    required this.loudnessDb,
    required this.peakDb,
  });

  /// Format of the cache; a change makes NEXA measure again.
  static const int version = 1;

  /// Silence: below this level (dBFS, RMS of a 50 ms window).
  static const double silenceDb = -50;

  /// A fading outro counts as quiet this far below the song's loudness.
  static const double quietBelowSongDb = 18;

  final Duration duration;

  /// First sound after a silent intro (zero without one).
  final Duration soundStart;

  /// End of the last sound before a silent tail (the duration without one).
  final Duration soundEnd;

  /// Where a fading outro becomes quiet: after this point the song stays
  /// [quietBelowSongDb] below its own loudness until [soundEnd].
  final Duration quietEnd;

  /// RMS loudness of the sounding part (dBFS).
  final double loudnessDb;

  /// Highest 50 ms RMS window (dBFS).
  final double peakDb;

  bool get silentTail => duration - soundEnd >= const Duration(milliseconds: 500);

  /// Measures 16-bit mono [samples] at [rate] Hz.
  static AudioAnalysis? measure(Int16List samples, int rate) {
    if (rate <= 0 || samples.length < rate ~/ 2) {
      return null;
    }
    final window = math.max(1, rate ~/ 20); // 50 ms
    final count = samples.length ~/ window;
    if (count == 0) {
      return null;
    }
    final levels = Float64List(count);
    for (var w = 0; w < count; w++) {
      var sum = 0.0;
      final from = w * window;
      for (var i = from; i < from + window; i++) {
        final v = samples[i] / 32768.0;
        sum += v * v;
      }
      final rms = math.sqrt(sum / window);
      levels[w] = rms <= 1e-6 ? -120 : 20 * math.log(rms) / math.ln10;
    }
    Duration at(int w) => Duration(microseconds: w * window * 1000000 ~/ rate);
    final duration = Duration(
      microseconds: samples.length * 1000000 ~/ rate,
    );
    var first = -1;
    var last = -1;
    var energy = 0.0;
    var sounding = 0;
    var peak = -120.0;
    for (var w = 0; w < count; w++) {
      final l = levels[w];
      if (l > peak) {
        peak = l;
      }
      if (l > silenceDb) {
        if (first < 0) {
          first = w;
        }
        last = w;
        energy += math.pow(10, l / 10);
        sounding++;
      }
    }
    if (first < 0) {
      // Silent file: nothing to adjust.
      return AudioAnalysis(
        duration: duration,
        soundStart: Duration.zero,
        soundEnd: duration,
        quietEnd: duration,
        loudnessDb: -120,
        peakDb: peak,
      );
    }
    final loudness = 10 * math.log(energy / sounding) / math.ln10;
    final quietLevel = loudness - quietBelowSongDb;
    var quiet = last;
    while (quiet > first && levels[quiet] < quietLevel) {
      quiet--;
    }
    // Sound up to the last (whole) window: the file's own end.
    final soundEnd = last == count - 1 || at(last + 1) >= duration
        ? duration
        : at(last + 1);
    final quietEnd = quiet == last || at(quiet + 1) >= soundEnd
        ? soundEnd
        : at(quiet + 1);
    return AudioAnalysis(
      duration: duration,
      soundStart: at(first),
      soundEnd: soundEnd,
      quietEnd: quietEnd,
      loudnessDb: loudness,
      peakDb: peak,
    );
  }

  /// Reads a 16-bit PCM WAV (mono or the first channel) and measures it.
  static AudioAnalysis? measureWav(Uint8List bytes) {
    if (bytes.length < 44) {
      return null;
    }
    final data = ByteData.sublistView(bytes);
    if (data.getUint32(0, Endian.big) != 0x52494646 || // RIFF
        data.getUint32(8, Endian.big) != 0x57415645) {
      return null;
    }
    var rate = 0;
    var channels = 1;
    var bits = 16;
    var offset = 12;
    while (offset + 8 <= bytes.length) {
      final id = data.getUint32(offset, Endian.big);
      var size = data.getUint32(offset + 4, Endian.little);
      final body = offset + 8;
      if (id == 0x666d7420) {
        // "fmt "
        channels = data.getUint16(body + 2, Endian.little);
        rate = data.getUint32(body + 4, Endian.little);
        bits = data.getUint16(body + 14, Endian.little);
      } else if (id == 0x64617461) {
        // "data" (a streamed writer may leave its size open)
        if (size == 0 || size == 0xFFFFFFFF || body + size > bytes.length) {
          size = bytes.length - body;
        }
        if (bits != 16 || channels < 1) {
          return null;
        }
        final frames = size ~/ (2 * channels);
        final mono = Int16List(frames);
        for (var i = 0; i < frames; i++) {
          mono[i] = data.getInt16(body + i * 2 * channels, Endian.little);
        }
        return measure(mono, rate);
      }
      offset = body + size + (size.isOdd ? 1 : 0);
    }
    return null;
  }

  Map<String, Object> toJson() => {
    'v': version,
    'duration': duration.inMilliseconds,
    'soundStart': soundStart.inMilliseconds,
    'soundEnd': soundEnd.inMilliseconds,
    'quietEnd': quietEnd.inMilliseconds,
    'loudness': double.parse(loudnessDb.toStringAsFixed(1)),
    'peak': double.parse(peakDb.toStringAsFixed(1)),
  };

  static AudioAnalysis? fromJson(Map<String, Object?> j) {
    if (j['v'] != version) {
      return null;
    }
    Duration ms(String k) => Duration(milliseconds: (j[k]! as num).toInt());
    try {
      return AudioAnalysis(
        duration: ms('duration'),
        soundStart: ms('soundStart'),
        soundEnd: ms('soundEnd'),
        quietEnd: ms('quietEnd'),
        loudnessDb: (j['loudness']! as num).toDouble(),
        peakDb: (j['peak']! as num).toDouble(),
      );
    } on Object {
      return null;
    }
  }
}
