import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

/// Writes a small PCM WAV file (16-bit mono sine tone) with optional RIFF
/// INFO tags. Generated test audio: no copyrighted music in the repository.
void writeWav(
  String path, {
  String? title,
  String? artist,
  String? album,
  double seconds = 0.2,
  double frequency = 440,
  int sampleRate = 8000,
}) {
  final samples = (seconds * sampleRate).round();
  final data = ByteData(samples * 2);
  for (var i = 0; i < samples; i++) {
    final v = math.sin(2 * math.pi * frequency * i / sampleRate) * 0.3;
    data.setInt16(i * 2, (v * 32767).round(), Endian.little);
  }

  List<int> chunk(String id, List<int> payload) {
    final header = ByteData(8);
    for (var i = 0; i < 4; i++) {
      header.setUint8(i, id.codeUnitAt(i));
    }
    header.setUint32(4, payload.length, Endian.little);
    return [
      ...header.buffer.asUint8List(),
      ...payload,
      if (payload.length.isOdd) 0,
    ];
  }

  List<int> text(String value) => [...value.codeUnits, 0];

  final fmt = ByteData(16)
    ..setUint16(0, 1, Endian.little) // PCM
    ..setUint16(2, 1, Endian.little) // mono
    ..setUint32(4, sampleRate, Endian.little)
    ..setUint32(8, sampleRate * 2, Endian.little) // byte rate
    ..setUint16(12, 2, Endian.little) // block align
    ..setUint16(14, 16, Endian.little); // bits per sample

  final info = <int>[
    ...'INFO'.codeUnits,
    if (title != null) ...chunk('INAM', text(title)),
    if (artist != null) ...chunk('IART', text(artist)),
    if (album != null) ...chunk('IPRD', text(album)),
  ];
  final body = <int>[
    ...'WAVE'.codeUnits,
    ...chunk('fmt ', fmt.buffer.asUint8List()),
    if (info.length > 4) ...chunk('LIST', info),
    ...chunk('data', data.buffer.asUint8List()),
  ];
  final riff = ByteData(8);
  for (var i = 0; i < 4; i++) {
    riff.setUint8(i, 'RIFF'.codeUnitAt(i));
  }
  riff.setUint32(4, body.length, Endian.little);
  File(path)
    ..parent.createSync(recursive: true)
    ..writeAsBytesSync([...riff.buffer.asUint8List(), ...body]);
}
