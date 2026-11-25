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
  const prefix = '/repos/KondexOFF/Nexa-Music/releases';
  await for (final req in server) {
    final auth = req.headers.value('authorization') != null ||
        req.headers.value('cookie') != null;
    final path = req.uri.path;
    var status = 200;
    try {
      final wanted = File('${dir.path}/status.txt').existsSync()
          ? File('${dir.path}/status.txt').readAsStringSync().trim()
          : '200';
      if (path == prefix) {
        if (wanted == '403-ratelimit') {
          status = 403;
          req.response.headers.set('x-ratelimit-remaining', '0');
          req.response.write('{"message":"API rate limit exceeded"}');
        } else if (wanted != '200') {
          status = int.parse(wanted);
          req.response.write('{"message":"test"}');
        } else {
          req.response.headers.contentType = ContentType.json;
          req.response.add(File('${dir.path}/releases.json').readAsBytesSync());
        }
      } else if (path.startsWith('$prefix/assets/')) {
        final id = path.substring('$prefix/assets/'.length);
        final f = File('${dir.path}/assets/$id');
        if (RegExp(r'^\d+$').hasMatch(id) && f.existsSync()) {
          req.response.headers.contentType = ContentType.binary;
          req.response.contentLength = f.lengthSync();
          await req.response.addStream(f.openRead());
        } else {
          status = 404;
        }
      } else {
        status = 404;
      }
    } on Object catch (e) {
      status = 500;
      req.response.write('$e');
    }
    req.response.statusCode = status;
    log.writeAsStringSync(
      '${DateTime.now().toIso8601String()} ${req.method} $path -> $status '
      'auth=${auth ? 'yes' : 'no'} accept=${req.headers.value('accept')}\n',
      mode: FileMode.append,
    );
    await req.response.close();
  }
}
