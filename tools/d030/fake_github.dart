// D-030 update-chain test: a stand-in for the GitHub releases API on this
// computer only (127.0.0.1), so NEXA Update Center can be tested end to end
// with packages built here - nothing is published anywhere.
//
//   dart tools/d030/fake_github.dart <folder>
//
// <folder>/status.txt     200 (default), 404, 403-ratelimit, 500
// <folder>/releases.json  the answer of GET /repos/<repo>/releases
// <folder>/assets/<id>    the file of GET /repos/<repo>/releases/assets/<id>
// <folder>/requests.log   one line per request; "auth=yes" would mean NEXA
//                         sent an Authorization header (it never may)
// <folder>/port.txt       written once the server listens
import 'dart:io';

Future<void> main(List<String> args) async {
  final dir = Directory(args.single);
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  final log = File('${dir.path}/requests.log');
  File('${dir.path}/port.txt').writeAsStringSync('${server.port}');
  await for (final req in server) {
    // One bad request must never stop the server.
    try {
      await _answer(req, dir, log);
    } on Object catch (e) {
      log.writeAsStringSync('ERROR $e\n', mode: FileMode.append);
      try {
        await req.response.close();
      } on Object {
        // Already closed.
      }
    }
  }
}

const String prefix = '/repos/KondexOFF/Nexa-Music/releases';

Future<void> _answer(HttpRequest req, Directory dir, File log) async {
  final auth = req.headers.value('authorization') != null ||
      req.headers.value('cookie') != null;
  final path = req.uri.path;
  final statusFile = File('${dir.path}/status.txt');
  final wanted = statusFile.existsSync() ? statusFile.readAsStringSync().trim() : '200';
  var status = 200;
  List<int> body = const [];
  File? stream;
  final headers = <String, String>{};
  if (path == prefix) {
    if (wanted == '403-ratelimit') {
      status = 403;
      headers['x-ratelimit-remaining'] = '0';
      body = '{"message":"API rate limit exceeded"}'.codeUnits;
    } else if (wanted != '200') {
      status = int.parse(wanted);
      body = '{"message":"test"}'.codeUnits;
    } else {
      headers['content-type'] = 'application/json';
      body = File('${dir.path}/releases.json').readAsBytesSync();
    }
  } else if (path.startsWith('$prefix/assets/')) {
    final id = path.substring('$prefix/assets/'.length);
    final f = File('${dir.path}/assets/$id');
    if (RegExp(r'^\d+$').hasMatch(id) && f.existsSync()) {
      headers['content-type'] = 'application/octet-stream';
      stream = f;
    } else {
      status = 404;
    }
  } else {
    status = 404;
  }
  // Status and headers first, then the body.
  req.response.statusCode = status;
  headers.forEach(req.response.headers.set);
  if (stream != null) {
    req.response.contentLength = stream.lengthSync();
    await req.response.addStream(stream.openRead());
  } else {
    req.response.add(body);
  }
  await req.response.close();
  log.writeAsStringSync(
    '${DateTime.now().toIso8601String()} ${req.method} $path -> $status '
    'auth=${auth ? 'yes' : 'no'} accept=${req.headers.value('accept')}\n',
    mode: FileMode.append,
  );
}
