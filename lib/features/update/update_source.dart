import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'release.dart';

/// The repository NEXA updates come from.
const String kUpdateRepo = 'KondexOFF/Nexa-Music';

/// What went wrong with a check, a download or an installation.
enum UpdateProblem {
  offline,
  noGitHubCli,
  notLoggedIn,
  accessDenied,
  rateLimited,
  notFound,
  badResponse,
  missingChecksum,
  checksumMismatch,
  corruptPackage,
  unsafePackage,
  noDiskSpace,
  installFailed,
  startFailed,
}

class UpdateException implements Exception {
  const UpdateException(this.problem, [this.detail = '']);

  final UpdateProblem problem;

  /// Technical detail for the status line - never a token or a header.
  final String detail;

  @override
  String toString() =>
      'UpdateException(${problem.name}${detail.isEmpty ? '' : ': $detail'})';
}

/// Where release information and files come from.
abstract interface class UpdateSource {
  /// "GitHub" or "GitHub CLI" for the status line.
  String get label;

  Future<List<ReleaseInfo>> releases();

  /// The bytes of [asset]; [total] may be unknown (null).
  Future<(Stream<List<int>>, int?)> download(ReleaseAsset asset);
}

/// The GitHub REST API without any authorization - for a public
/// repository. No token, key or cookie is ever sent. `NEXA_UPDATE_API`
/// points it to a local test server (http only on this computer).
class GitHubApiSource implements UpdateSource {
  GitHubApiSource(this.client, {String? base, this.repo = kUpdateRepo, this.appVersion = ''})
    : base = base ?? 'https://api.github.com';

  final http.Client client;
  final String base;
  final String repo;
  final String appVersion;

  @override
  String get label => 'GitHub';

  /// The API base from `NEXA_UPDATE_API`, when it is allowed: any https
  /// address, or http on this computer only (NEXA AutoTest).
  static String? overrideFromEnvironment() {
    final value = Platform.environment['NEXA_UPDATE_API']?.trim() ?? '';
    if (value.isEmpty) {
      return null;
    }
    final uri = Uri.tryParse(value);
    final local = uri != null &&
        uri.scheme == 'http' &&
        (uri.host == '127.0.0.1' || uri.host == 'localhost');
    if (uri == null || !(uri.scheme == 'https' || local)) {
      return null;
    }
    return value.endsWith('/') ? value.substring(0, value.length - 1) : value;
  }

  Map<String, String> _headers(String accept) => {
    'Accept': accept,
    'X-GitHub-Api-Version': '2022-11-28',
    'User-Agent': 'NEXA-Music/${appVersion.isEmpty ? 'dev' : appVersion}',
  };

  static UpdateProblem _problemFor(int status, Map<String, String> headers) {
    if (status == 429 ||
        (status == 403 && headers['x-ratelimit-remaining'] == '0')) {
      return UpdateProblem.rateLimited;
    }
    return switch (status) {
      401 || 403 => UpdateProblem.accessDenied,
      404 => UpdateProblem.notFound,
      _ => UpdateProblem.badResponse,
    };
  }

  @override
  Future<List<ReleaseInfo>> releases() async {
    final http.Response r;
    try {
      r = await client
          .get(
            Uri.parse('$base/repos/$repo/releases?per_page=30'),
            headers: _headers('application/vnd.github+json'),
          )
          .timeout(const Duration(seconds: 20));
    } on SocketException catch (e) {
      throw UpdateException(UpdateProblem.offline, e.message);
    } on http.ClientException catch (e) {
      throw UpdateException(UpdateProblem.offline, e.message);
    } on TimeoutException {
      throw const UpdateException(UpdateProblem.offline, 'timeout');
    } on HandshakeException catch (e) {
      throw UpdateException(UpdateProblem.offline, e.message);
    }
    if (r.statusCode != 200) {
      throw UpdateException(_problemFor(r.statusCode, r.headers), 'HTTP ${r.statusCode}');
    }
    try {
      return ReleaseInfo.listFromJson(jsonDecode(utf8.decode(r.bodyBytes)));
    } on FormatException {
      throw const UpdateException(UpdateProblem.badResponse, 'not JSON');
    }
  }

  @override
  Future<(Stream<List<int>>, int?)> download(ReleaseAsset asset) async {
    // The address is built here from the asset id - never taken from the
    // response, so it always goes to this API and this repository.
    final request = http.Request(
      'GET',
      Uri.parse('$base/repos/$repo/releases/assets/${asset.id}'),
    )..headers.addAll(_headers('application/octet-stream'));
    final http.StreamedResponse r;
    try {
      r = await client.send(request).timeout(const Duration(seconds: 30));
    } on SocketException catch (e) {
      throw UpdateException(UpdateProblem.offline, e.message);
    } on http.ClientException catch (e) {
      throw UpdateException(UpdateProblem.offline, e.message);
    } on TimeoutException {
      throw const UpdateException(UpdateProblem.offline, 'timeout');
    }
    if (r.statusCode != 200) {
      await r.stream.drain<void>();
      throw UpdateException(_problemFor(r.statusCode, r.headers), 'HTTP ${r.statusCode}');
    }
    return (r.stream, r.contentLength);
  }
}

/// The owner's own, already authorized GitHub CLI (`gh`) - for a private
/// repository. NEXA never sees, stores or logs the token: `gh` keeps it in
/// Windows Credential Manager and sends it only to github.com.
class GhCliSource implements UpdateSource {
  GhCliSource({this.repo = kUpdateRepo, this.executable});

  final String repo;

  /// `gh` on PATH unless given (tests).
  final String? executable;

  @override
  String get label => 'GitHub CLI';

  /// gh.exe on PATH or in its usual installation folders.
  static String? find() {
    final env = Platform.environment;
    final names = Platform.isWindows ? const ['gh.exe'] : const ['gh'];
    final dirs = [
      ...?env['PATH']?.split(Platform.isWindows ? ';' : ':'),
      if (Platform.isWindows) ...[
        if (env['ProgramFiles'] != null) '${env['ProgramFiles']}\\GitHub CLI',
        if (env['LOCALAPPDATA'] != null)
          '${env['LOCALAPPDATA']}\\Programs\\GitHub CLI',
      ],
    ];
    for (final d in dirs) {
      if (d.trim().isEmpty) {
        continue;
      }
      for (final n in names) {
        final f = File('${d.trim()}${Platform.pathSeparator}$n');
        if (f.existsSync()) {
          return f.path;
        }
      }
    }
    return null;
  }

  String _gh() {
    final gh = executable ?? find();
    if (gh == null) {
      throw const UpdateException(UpdateProblem.noGitHubCli);
    }
    return gh;
  }

  /// Arguments of `gh api` for this repository on github.com only.
  List<String> _api(String path, String accept) => [
    'api',
    '--hostname',
    'github.com',
    '-H',
    'Accept: $accept',
    '-H',
    'X-GitHub-Api-Version: 2022-11-28',
    path,
  ];

  static UpdateException problemFromGh(String stderr) {
    final s = stderr.toLowerCase();
    // gh's own words: never copied whole into the status (no tokens are in
    // them, but keep the line short).
    final first = stderr.trim().split('\n').first;
    final detail = first.length > 160 ? first.substring(0, 160) : first;
    if (s.contains('gh auth login') || s.contains('not logged in') ||
        s.contains('authentication required') || s.contains('http 401')) {
      return UpdateException(UpdateProblem.notLoggedIn, detail);
    }
    if (s.contains('rate limit')) {
      return UpdateException(UpdateProblem.rateLimited, detail);
    }
    if (s.contains('http 404')) {
      return UpdateException(UpdateProblem.accessDenied, detail);
    }
    if (s.contains('http 403')) {
      return UpdateException(UpdateProblem.accessDenied, detail);
    }
    if (s.contains('error connecting') || s.contains('no such host') ||
        s.contains('dial tcp') || s.contains('timeout')) {
      return UpdateException(UpdateProblem.offline, detail);
    }
    return UpdateException(UpdateProblem.badResponse, detail);
  }

  @override
  Future<List<ReleaseInfo>> releases() async {
    final gh = _gh();
    final ProcessResult r;
    try {
      r = await Process.run(
        gh,
        _api('repos/$repo/releases?per_page=30', 'application/vnd.github+json'),
        stdoutEncoding: utf8,
        stderrEncoding: utf8,
      ).timeout(const Duration(seconds: 40));
    } on ProcessException catch (e) {
      throw UpdateException(UpdateProblem.noGitHubCli, e.message);
    } on TimeoutException {
      throw const UpdateException(UpdateProblem.offline, 'timeout');
    }
    if (r.exitCode != 0) {
      throw problemFromGh('${r.stderr}');
    }
    try {
      return ReleaseInfo.listFromJson(jsonDecode('${r.stdout}'));
    } on FormatException {
      throw const UpdateException(UpdateProblem.badResponse, 'not JSON');
    }
  }

  @override
  Future<(Stream<List<int>>, int?)> download(ReleaseAsset asset) async {
    final gh = _gh();
    final Process p;
    try {
      p = await Process.start(
        gh,
        _api('repos/$repo/releases/assets/${asset.id}', 'application/octet-stream'),
      );
    } on ProcessException catch (e) {
      throw UpdateException(UpdateProblem.noGitHubCli, e.message);
    }
    final errors = StringBuffer();
    final errDone = p.stderr
        .transform(utf8.decoder)
        .forEach(errors.write);
    final out = StreamController<List<int>>();
    p.stdout.listen(
      out.add,
      onError: out.addError,
      onDone: () async {
        final code = await p.exitCode;
        await errDone;
        if (code != 0) {
          out.addError(problemFromGh(errors.toString()));
        }
        await out.close();
      },
    );
    out.onCancel = () => p.kill();
    return (out.stream, asset.size);
  }
}

/// Public repository first; when GitHub answers "not found" (a private
/// repository looks like that without authorization) the GitHub CLI.
class AutoSource implements UpdateSource {
  AutoSource(this.anonymous, this.cli);

  final UpdateSource anonymous;
  final UpdateSource cli;
  UpdateSource? _used;

  @override
  String get label => (_used ?? anonymous).label;

  @override
  Future<List<ReleaseInfo>> releases() async {
    try {
      final list = await anonymous.releases();
      _used = anonymous;
      return list;
    } on UpdateException catch (e) {
      if (e.problem != UpdateProblem.notFound &&
          e.problem != UpdateProblem.accessDenied) {
        rethrow;
      }
    }
    final list = await cli.releases();
    _used = cli;
    return list;
  }

  @override
  Future<(Stream<List<int>>, int?)> download(ReleaseAsset asset) =>
      (_used ?? anonymous).download(asset);
}
