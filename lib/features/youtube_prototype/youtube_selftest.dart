import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data' as typed;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../app/app.dart';
import '../../core/models/track.dart';
import '../player/player_controller.dart';
import 'youtube_prototype_controller.dart';
import 'youtube_prototype_page.dart';

/// Run folder of the E2.0 prototype test; empty in normal use.
String youtubeSelfTestDir() =>
    Platform.environment['NEXA_E20_SELFTEST']?.trim() ?? '';

/// E2.0 prototype test driven by `tools/e2_0/e2_0_prototype_test.ps1`.
///
/// The script appends commands to `<run>/commands.txt` and performs the
/// Windows actions itself (resize, minimise, media keys, CPU / GPU
/// samples); the app executes the commands and writes every player event,
/// NEXA player change, lifecycle change, media key and frame statistics to
/// `<run>/events.jsonl`. Only active when `NEXA_E20_SELFTEST` is set.
class YouTubeSelfTest {
  YouTubeSelfTest(this.container, this.dir);

  final ProviderContainer container;
  final String dir;
  final Stopwatch _clock = Stopwatch()..start();
  late final IOSink _out;
  final List<ui.FrameTiming> _frames = [];

  YouTubePrototypeController get _yt =>
      container.read(youtubePrototypeProvider.notifier);

  void _write(String type, [Map<String, Object?> data = const {}]) {
    _out.writeln(
      jsonEncode({'t': _clock.elapsedMilliseconds, ...data, 'type': type}),
    );
  }

  Future<void> run() async {
    await Directory(dir).create(recursive: true);
    _out = File(p.join(dir, 'events.jsonl')).openWrite(mode: FileMode.append);
    _write('selftest', {'pid': pid, 'os': Platform.operatingSystemVersion});
    SchedulerBinding.instance.addTimingsCallback(_frames.addAll);
    Timer.periodic(const Duration(seconds: 10), (_) => _flushFrames());
    // Controller entries: type "log", their own kind in "kind" (yt.state,
    // yt.tick, yt.error, lifecycle, mediaKey, command, closed, ...).
    _yt.log.listen((e) => _write('log', {...e, 'kind': e['type']}));
    container.listen(
      playerProvider.select((s) => s.playing),
      (_, playing) => _write('nexaPlaying', {'playing': playing}),
    );
    final commands = File(p.join(dir, 'commands.txt'));
    var handled = 0;
    while (true) {
      await Future<void>.delayed(const Duration(milliseconds: 200));
      if (!commands.existsSync()) {
        continue;
      }
      final lines = commands.readAsLinesSync();
      while (handled < lines.length) {
        final line = lines[handled++].trim();
        if (line.isEmpty) {
          continue;
        }
        try {
          await _exec(line);
          _write('ack', {'cmd': line, 'ok': true});
        } on Object catch (e) {
          _write('ack', {'cmd': line, 'ok': false, 'error': '$e'});
        }
        await _out.flush();
      }
    }
  }

  void _flushFrames() {
    if (_frames.isEmpty) {
      _write('frames', {'count': 0});
      return;
    }
    List<double> ms(Duration Function(ui.FrameTiming) f) =>
        [for (final t in _frames) f(t).inMicroseconds / 1000]..sort();
    final raster = ms((t) => t.rasterDuration);
    final build = ms((t) => t.buildDuration);
    double pct(List<double> v, double q) =>
        v[math.min(v.length - 1, (v.length * q).floor())];
    _write('frames', {
      'count': _frames.length,
      'rasterAvg': raster.reduce((a, b) => a + b) / raster.length,
      'rasterP95': pct(raster, 0.95),
      'rasterMax': raster.last,
      'buildAvg': build.reduce((a, b) => a + b) / build.length,
      'buildP95': pct(build, 0.95),
      'over16ms': raster.where((v) => v > 16.7).length,
    });
    _frames.clear();
  }

  Future<void> _waitFor(bool Function() test, Duration timeout) async {
    final end = DateTime.now().add(timeout);
    while (!test() && DateTime.now().isBefore(end)) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
  }

  Future<void> _exec(String line) async {
    final parts = line.split(RegExp(r'\s+'));
    YtStatus status() => container.read(youtubePrototypeProvider);
    switch (parts.first) {
      case 'open':
        unawaited(
          nexaNavigatorKey.currentState!.push(
            MaterialPageRoute<void>(builder: (_) => const YouTubePrototypePage()),
          ),
        );
        await _waitFor(
          () => _yt.embed != null || status().unavailable != null,
          const Duration(seconds: 20),
        );
        _write('opened', {
          'embed': _yt.embed != null,
          'unavailable': status().unavailable,
          'runtime': status().runtimeVersion,
        });
      case 'leave':
        await nexaNavigatorKey.currentState!.maybePop();
        await _waitFor(() => _yt.embed == null, const Duration(seconds: 10));
        _write('left', {'embed': _yt.embed != null});
      case 'load':
        final muted = parts.length > 2 && parts[2] == 'muted';
        final cue = parts.length > 3 && parts[3] == 'cue';
        await _yt.load(parts[1], play: !cue, mute: muted);
      case 'play':
        await _yt.play();
      case 'pause':
        await _yt.pause();
      case 'info':
        await _yt.requestInfo();
      case 'unidentified':
        await _yt.openUnidentified();
      case 'identified':
        await _yt.openIdentified();
      case 'localplay':
        final file = File(p.join(dir, 'local_tone.wav'));
        if (!file.existsSync()) {
          _writeTone(file);
        }
        final player = container.read(playerProvider.notifier);
        await player.setVolume(0); // Silent: only the switching is tested.
        await player.playTracks([
          Track(
            id: 999999,
            source: TrackSource.local,
            sourceTrackId: file.path,
            path: file.path,
            title: 'E2.0 test tone',
            artist: 'NEXA',
            album: 'Test',
            duration: const Duration(seconds: 60),
            addedAt: DateTime.now(),
          ),
        ]);
      case 'localpause':
        await container.read(playerProvider.notifier).pause();
      case 'status':
        final s = status();
        _write('status', {
          'ytState': s.state,
          'ytActive': s.active,
          'error': s.errorCode,
          'quality': s.quality,
          'time': s.time,
          'nexaPlaying': container.read(playerProvider).playing,
          'pageOrigin': s.pageOrigin,
          'fullScreen': s.fullScreen,
        });
      case 'frames':
        _flushFrames();
      case 'exit':
        _flushFrames();
        _write('exit');
        await _out.flush();
        await _out.close();
        exit(0);
      default:
        throw ArgumentError('unknown command');
    }
  }

  /// 60 s quiet 440 Hz tone, 16-bit mono (played at volume 0).
  static void _writeTone(File file) {
    const rate = 22050;
    const seconds = 60;
    const samples = rate * seconds;
    final data = typed.ByteData(44 + samples * 2);
    void str(int at, String s) {
      for (var i = 0; i < s.length; i++) {
        data.setUint8(at + i, s.codeUnitAt(i));
      }
    }

    str(0, 'RIFF');
    data.setUint32(4, 36 + samples * 2, typed.Endian.little);
    str(8, 'WAVE');
    str(12, 'fmt ');
    data
      ..setUint32(16, 16, typed.Endian.little)
      ..setUint16(20, 1, typed.Endian.little)
      ..setUint16(22, 1, typed.Endian.little)
      ..setUint32(24, rate, typed.Endian.little)
      ..setUint32(28, rate * 2, typed.Endian.little)
      ..setUint16(32, 2, typed.Endian.little)
      ..setUint16(34, 16, typed.Endian.little);
    str(36, 'data');
    data.setUint32(40, samples * 2, typed.Endian.little);
    for (var i = 0; i < samples; i++) {
      final v = math.sin(2 * math.pi * 440 * i / rate) * 0.1;
      data.setInt16(44 + i * 2, (v * 32767).round(), typed.Endian.little);
    }
    file.writeAsBytesSync(data.buffer.asUint8List());
  }
}
