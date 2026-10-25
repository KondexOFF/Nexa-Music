import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nexa_music/features/library/tag_reader.dart';
import 'package:path/path.dart' as p;

import 'helpers/wav.dart';

/// The WAV helper writes each character as one byte, so passing the UTF-8
/// bytes as Latin-1 characters writes UTF-8 text into the RIFF INFO chunk,
/// as FFmpeg and most current taggers do.
String _utf8Bytes(String s) => latin1.decode(utf8.encode(s));

void main() {
  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('nexa_wav_'));
  tearDown(() => dir.deleteSync(recursive: true));

  test('Cyrillic UTF-8 RIFF INFO tags in a WAV file are read correctly (TD-04)', () {
    final path = p.join(dir.path, 'cyr.wav');
    writeWav(
      path,
      title: _utf8Bytes('Песня WAV'),
      artist: _utf8Bytes('Исполнитель Ё'),
      album: _utf8Bytes('Альбом WAV'),
    );
    final r = readTags(path, '');
    expect(r.title, 'Песня WAV');
    expect(r.artist, 'Исполнитель Ё');
    expect(r.album, 'Альбом WAV');
  });

  test('plain ASCII WAV tags are unchanged', () {
    final path = p.join(dir.path, 'ascii.wav');
    writeWav(path, title: 'Track One', artist: 'Band', album: 'Album');
    final r = readTags(path, '');
    expect((r.title, r.artist, r.album), ('Track One', 'Band', 'Album'));
  });

  test('repairUtf8 only changes text that really is UTF-8 read as Latin-1', () {
    expect(repairUtf8(null), isNull);
    expect(repairUtf8('Seq 01'), 'Seq 01');
    expect(repairUtf8('Café'), 'Café'); // real Latin-1: not valid UTF-8
    expect(repairUtf8('Песня'), 'Песня'); // already decoded
    expect(repairUtf8(_utf8Bytes('Тестовая песня')), 'Тестовая песня');
    expect(repairUtf8(_utf8Bytes('Café')), 'Café');
  });
}
