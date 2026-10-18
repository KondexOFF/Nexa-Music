import 'dart:io';
import 'dart:ui' as ui;

import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../features/library/library_providers.dart';
import '../app.dart';
import '../navigation.dart';
import '../theme/tokens.dart';

/// Final verdict of a capture run: PASS only if there were no Flutter errors
/// and every required screenshot was saved.
bool captureRunPassed({
  required int flutterErrors,
  required int failedCaptures,
}) => flutterErrors == 0 && failedCaptures == 0;

/// Renders the real app at fixed logical sizes, saves PNG screenshots and a
/// log (including any Flutter layout errors such as overflows), then exits.
///
/// Started with `--dart-define=NEXA_CAPTURE_DIR=...`. Used to produce
/// Phase 1 visual evidence on Windows; not part of normal app use.
class CaptureHarness extends StatefulWidget {
  const CaptureHarness({super.key, required this.outDir});

  final String outDir;

  static const List<Size> sizes = [
    Size(1280, 720),
    Size(1920, 1080),
    Size(1024, 640),
  ];

  @override
  State<CaptureHarness> createState() => _CaptureHarnessState();
}

class _CaptureHarnessState extends State<CaptureHarness> {
  // Screenshots never read or change the user's library: empty in-memory
  // database.
  final ProviderContainer _container = ProviderContainer(
    overrides: [
      appDatabaseProvider.overrideWith((ref) {
        final db = AppDatabase(NativeDatabase.memory());
        ref.onDispose(db.close);
        return db;
      }),
      artworkDirProvider.overrideWith((ref) async => ''),
    ],
  );
  final GlobalKey _boundaryKey = GlobalKey();
  final List<String> _errors = [];

  /// Required screenshots that could not be saved. Any entry makes the
  /// whole run FAIL (a missing screenshot is missing evidence).
  final List<String> _failedCaptures = [];
  Size _size = CaptureHarness.sizes.first;
  FlutterExceptionHandler? _previousHandler;

  @override
  void initState() {
    super.initState();
    _previousHandler = FlutterError.onError;
    FlutterError.onError = (details) {
      _errors.add(details.exceptionAsString().split('\n').first);
      _previousHandler?.call(details);
    };
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  Future<void> _settle() async {
    await Future<void>.delayed(const Duration(milliseconds: 1200));
    await WidgetsBinding.instance.endOfFrame;
  }

  Future<void> _run() async {
    final log = StringBuffer()
      ..writeln('NEXA Music - Phase 1 - screen capture')
      ..writeln('Started: ${DateTime.now().toIso8601String()}')
      ..writeln('OS: ${Platform.operatingSystemVersion}')
      ..writeln('Dart: ${Platform.version}');
    final dir = Directory(widget.outDir)..createSync(recursive: true);
    final logFile = File(
      '${dir.path}${Platform.pathSeparator}phase01_capture_log.txt',
    );
    // Written after every step so a crash still leaves evidence.
    void flush() => logFile.writeAsStringSync(log.toString());
    flush();
    final nav = _container.read(navigationProvider.notifier);
    const screens = {
      'home': NexaDestination.home,
      'player': NexaDestination.nowPlaying,
    };

    for (final size in CaptureHarness.sizes) {
      for (final entry in screens.entries) {
        final errorsBefore = _errors.length;
        setState(() => _size = size);
        nav.go(entry.value);
        await _settle();
        final name =
            'phase01_${entry.key}_${size.width.round()}x${size.height.round()}.png';
        final ok = await _capture('${dir.path}${Platform.pathSeparator}$name');
        if (!ok) {
          _failedCaptures.add(name);
        }
        log.writeln(
          '${ok ? 'SAVED' : 'FAILED'}  $name  '
          'layout errors during this screen: ${_errors.length - errorsBefore}',
        );
        flush();

        // Now Playing on the smaller sizes: also capture the end of every
        // vertical scroll area, to show it is reachable above the player.
        if (entry.value == NexaDestination.nowPlaying && size.width < 1500) {
          _scrollAll(toEnd: true);
          await _settle();
          final endName =
              'phase01_player_end_${size.width.round()}x${size.height.round()}.png';
          final endOk = await _capture(
            '${dir.path}${Platform.pathSeparator}$endName',
          );
          if (!endOk) {
            _failedCaptures.add(endName);
          }
          log.writeln('${endOk ? 'SAVED' : 'FAILED'}  $endName');
          flush();
          _scrollAll(toEnd: false);
          await _settle();
        }
      }
    }

    final passed = captureRunPassed(
      flutterErrors: _errors.length,
      failedCaptures: _failedCaptures.length,
    );
    log
      ..writeln('Total Flutter errors: ${_errors.length}')
      ..writeAll(_errors.map((e) => '  - $e\n'))
      ..writeln('Screenshots not saved: ${_failedCaptures.length}')
      ..writeAll(_failedCaptures.map((e) => '  - $e\n'))
      ..writeln('RESULT: ${passed ? 'PASS' : 'FAIL'}')
      ..writeln('Finished: ${DateTime.now().toIso8601String()}');
    flush();

    FlutterError.onError = _previousHandler;
    _container.dispose();
    exit(passed ? 0 : 1);
  }

  /// Jumps every vertical scroll view in the app to its end (or start).
  void _scrollAll({required bool toEnd}) {
    void visit(Element element) {
      if (element is StatefulElement && element.state is ScrollableState) {
        final position = (element.state as ScrollableState).position;
        if (position.axis == Axis.vertical) {
          position.jumpTo(toEnd ? position.maxScrollExtent : 0);
        }
      }
      element.visitChildren(visit);
    }

    _boundaryKey.currentContext?.visitChildElements(visit);
  }

  /// Saves the current frame as PNG. Returns false (never throws) if the
  /// image could not be produced or written; the caller records it as FAIL.
  Future<bool> _capture(String path) async {
    try {
      final boundary = _boundaryKey.currentContext?.findRenderObject();
      if (boundary is! RenderRepaintBoundary) {
        return false;
      }
      final image = await boundary.toImage(pixelRatio: 1);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (data == null) {
        return false;
      }
      File(path).writeAsBytesSync(data.buffer.asUint8List());
      return File(path).existsSync();
    } on Object catch (error) {
      _errors.add('screenshot $path: $error');
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Rendered at 1:1 scale (no FittedBox): the part larger than the window
    // is simply off-screen, and RepaintBoundary.toImage still captures the
    // whole boundary. The earlier scaled version exited during capture on
    // the test PC (cause not confirmed).
    return ClipRect(
      child: ColoredBox(
        color: NexaColors.background,
        child: OverflowBox(
          alignment: Alignment.topLeft,
          minWidth: _size.width,
          maxWidth: _size.width,
          minHeight: _size.height,
          maxHeight: _size.height,
          child: RepaintBoundary(
            key: _boundaryKey,
            // Not meant for screen readers; the Windows accessibility bridge
            // reported errors for the off-screen part.
            // IgnorePointer: the real mouse cursor must not trigger hover
            // states or tooltips in the screenshots.
            child: IgnorePointer(
              child: ExcludeSemantics(
                child: UncontrolledProviderScope(
                  container: _container,
                  child: const NexaApp(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
