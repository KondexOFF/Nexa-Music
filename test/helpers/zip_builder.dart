import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:nexa_music/features/update/zip_package.dart';

/// One entry for [buildZip]; everything a hostile archive could fake.
class TestEntry {
  TestEntry(
    this.name, [
    List<int>? data,
    this.deflate = true,
  ]) : data = data ?? const [];

  final String name;
  final List<int> data;
  final bool deflate;
  int flags = 0x800;
  int madeBy = 20;
  int externalAttributes = 0;
  int? crcOverride;
  String? localName;
  int? method;
}

/// A ZIP archive as bytes (stored / deflated entries, central directory).
Uint8List buildZip(List<TestEntry> entries) {
  final out = BytesBuilder();
  final central = BytesBuilder();
  for (final e in entries) {
    final name = utf8.encode(e.name);
    final local = utf8.encode(e.localName ?? e.name);
    final crc = (Crc32()..add(e.data)).value;
    final method = e.method ?? (e.deflate && e.data.isNotEmpty ? 8 : 0);
    final body = method == 8
        ? ZLibEncoder(raw: true).convert(e.data)
        : e.data;
    final offset = out.length;
    final h = ByteData(30)
      ..setUint32(0, 0x04034b50, Endian.little)
      ..setUint16(4, 20, Endian.little)
      ..setUint16(6, e.flags, Endian.little)
      ..setUint16(8, method, Endian.little)
      ..setUint32(14, e.crcOverride ?? crc, Endian.little)
      ..setUint32(18, body.length, Endian.little)
      ..setUint32(22, e.data.length, Endian.little)
      ..setUint16(26, local.length, Endian.little);
    out
      ..add(h.buffer.asUint8List())
      ..add(local)
      ..add(body);
    final c = ByteData(46)
      ..setUint32(0, 0x02014b50, Endian.little)
      ..setUint16(4, e.madeBy, Endian.little)
      ..setUint16(6, 20, Endian.little)
      ..setUint16(8, e.flags, Endian.little)
      ..setUint16(10, method, Endian.little)
      ..setUint32(16, e.crcOverride ?? crc, Endian.little)
      ..setUint32(20, body.length, Endian.little)
      ..setUint32(24, e.data.length, Endian.little)
      ..setUint16(28, name.length, Endian.little)
      ..setUint32(38, e.externalAttributes, Endian.little)
      ..setUint32(42, offset, Endian.little);
    central
      ..add(c.buffer.asUint8List())
      ..add(name);
  }
  final cdOffset = out.length;
  final cd = central.toBytes();
  out.add(cd);
  final end = ByteData(22)
    ..setUint32(0, 0x06054b50, Endian.little)
    ..setUint16(8, entries.length, Endian.little)
    ..setUint16(10, entries.length, Endian.little)
    ..setUint32(12, cd.length, Endian.little)
    ..setUint32(16, cdOffset, Endian.little);
  out.add(end.buffer.asUint8List());
  return out.toBytes();
}
