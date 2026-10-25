import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nexa_music/features/library/tag_reader.dart';
import 'package:path/path.dart' as p;

/// Minimal FLAC header: STREAMINFO (44.1 kHz, mono, 16 bit, [seconds]) and
/// a VORBIS_COMMENT block. No audio frames are needed for the tag reader.
Uint8List _flac(Map<String, String> tags, double seconds) {
  final out = BytesBuilder()..add(ascii.encode('fLaC'));
  final info = ByteData(34);
  info.setUint16(0, 4096);
  info.setUint16(2, 4096);
  const rate = 44100;
  final samples = (seconds * rate).round();
  // 20 bits rate | 3 bits channels-1 | 5 bits bps-1 | 36 bits total samples.
  final packed = (BigInt.from(rate) << 44) | (BigInt.from(15) << 36) | BigInt.from(samples);
  for (var i = 0; i < 8; i++) {
    info.setUint8(10 + i, ((packed >> (8 * (7 - i))) & BigInt.from(0xFF)).toInt());
  }
  out
    ..add([0x00, 0x00, 0x00, 34])
    ..add(info.buffer.asUint8List());
  final comment = BytesBuilder();
  void le32(int v) => comment.add((ByteData(4)..setUint32(0, v, Endian.little)).buffer.asUint8List());
  final vendor = utf8.encode('NEXA test');
  le32(vendor.length);
  comment.add(vendor);
  le32(tags.length);
  tags.forEach((k, v) {
    final entry = utf8.encode('$k=$v');
    le32(entry.length);
    comment.add(entry);
  });
  final body = comment.toBytes();
  out
    ..add([0x84, (body.length >> 16) & 0xFF, (body.length >> 8) & 0xFF, body.length & 0xFF])
    ..add(body);
  return out.toBytes();
}

/// An ID3v2.4 tag with one TIT2 frame, as FFmpeg writes in front of FLAC.
Uint8List _id3() {
  final text = [0x03, ...utf8.encode('ID3 title')];
  final frame = [...ascii.encode('TIT2'), 0, 0, 0, text.length, 0, 0, ...text];
  final size = frame.length + 20; // with padding
  return Uint8List.fromList([
    ...ascii.encode('ID3'), 4, 0, 0,
    (size >> 21) & 0x7F, (size >> 14) & 0x7F, (size >> 7) & 0x7F, size & 0x7F,
    ...frame,
    ...List.filled(20, 0),
  ]);
}

void main() {
  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('nexa_flac_'));
  tearDown(() => dir.deleteSync(recursive: true));

  const tags = {
    'TITLE': 'Песня на кириллице',
    'ARTIST': 'Исполнитель Ё',
    'ALBUM': 'Тестовый альбом',
    'GENRE': 'Поп',
    'TRACKNUMBER': '2',
  };

  void expectTags(TagResult r) {
    expect(r.error, isNull);
    expect(r.title, 'Песня на кириллице');
    expect(r.artist, 'Исполнитель Ё');
    expect(r.album, 'Тестовый альбом');
    expect(r.genre, 'Поп');
    expect(r.trackNumber, 2);
    expect(r.duration, const Duration(seconds: 8));
  }

  test('a standard FLAC file: Vorbis tags and length', () {
    final file = File(p.join(dir.path, 'plain.flac'))..writeAsBytesSync(_flac(tags, 8));
    expectTags(readTags(file.path, ''));
  });

  test('a FLAC file with an ID3v2 tag in front (FFmpeg, some taggers): '
      'the FLAC tags and length are still read', () {
    final file = File(p.join(dir.path, 'id3.flac'))
      ..writeAsBytesSync([..._id3(), ..._flac(tags, 8)]);
    final raf = file.openSync();
    try {
      expect(flacStreamOffset(raf), _id3().length);
    } finally {
      raf.closeSync();
    }
    expectTags(readTags(file.path, ''));
  });

  test('flacStreamOffset: plain FLAC is 0, other files are null', () {
    final plain = File(p.join(dir.path, 'a.flac'))..writeAsBytesSync(_flac(tags, 1));
    final other = File(p.join(dir.path, 'b.flac'))..writeAsBytesSync(List.filled(64, 7));
    for (final (file, expected) in [(plain, 0), (other, null)]) {
      final raf = file.openSync();
      try {
        expect(flacStreamOffset(raf), expected);
      } finally {
        raf.closeSync();
      }
    }
  });
}
