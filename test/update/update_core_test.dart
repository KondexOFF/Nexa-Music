import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nexa_music/app/config.dart';
import 'package:nexa_music/features/update/release.dart';
import 'package:nexa_music/features/update/semver.dart';
import 'package:nexa_music/features/update/update_controller.dart';
import 'package:nexa_music/features/update/update_source.dart';

import '../helpers/fake_update_source.dart';

Map<String, Object?> releaseJson(
  String tag, {
  bool draft = false,
  bool prerelease = false,
  bool package = true,
  String? digest =
      'sha256:2bac2e3d0bd82be05a84566f6f43c0d8f41452edf159989806c877a117fe9eb0',
}) {
  final v = tag.startsWith('v') ? tag.substring(1) : tag;
  return {
    'tag_name': tag,
    'name': 'NEXA Music $v',
    'body': 'Notes for $v',
    'draft': draft,
    'prerelease': prerelease,
    'html_url': 'https://github.com/$kUpdateRepo/releases/tag/$tag',
    'published_at': '2026-12-01T10:00:00Z',
    'assets': [
      if (package)
        {
          'id': 100,
          'name': 'NEXA_Music_${v}_Windows_x64.zip',
          'size': 22697391,
          'url': 'https://api.github.com/repos/$kUpdateRepo/releases/assets/100',
          'browser_download_url': 'https://github.com/x.zip',
          'digest': digest,
        },
      {'id': 101, 'name': 'SHA256SUMS.txt', 'size': 211},
    ],
  };
}

void main() {
  group('SemVer', () {
    test('parses tags and versions', () {
      expect(SemVer.tryParse('v1.2.0').toString(), '1.2.0');
      expect(SemVer.tryParse('1.1.1+10').toString(), '1.1.1');
      expect(SemVer.tryParse('1.2.0-rc.1')!.isPrerelease, isTrue);
      for (final bad in ['', '1.2', 'v1', '1.2.x', '01.2.3', 'nexa', '1.2.3.4']) {
        expect(SemVer.tryParse(bad), isNull, reason: bad);
      }
    });

    test('orders versions and prereleases (SemVer 2.0)', () {
      final order = [
        '1.0.0-alpha',
        '1.0.0-alpha.1',
        '1.0.0-alpha.beta',
        '1.0.0-beta',
        '1.0.0-beta.2',
        '1.0.0-beta.11',
        '1.0.0-rc.1',
        '1.0.0',
        '1.0.1',
        '1.1.0',
        '1.1.1',
        '1.2.0',
        '1.10.0',
        '2.0.0',
      ].map((v) => SemVer.tryParse(v)!).toList();
      for (var i = 1; i < order.length; i++) {
        expect(order[i] > order[i - 1], isTrue, reason: '${order[i]} > ${order[i - 1]}');
      }
      expect(SemVer.tryParse('v1.1.1'), SemVer.tryParse('1.1.1+10'));
    });

    test('this build is 1.1.1', () {
      expect(SemVer.tryParse(kAppVersion).toString(), '1.1.1');
    });
  });

  group('choosing an update', () {
    final current = SemVer.tryParse('1.1.1')!;
    List<ReleaseInfo> list(List<Map<String, Object?>> json) =>
        ReleaseInfo.listFromJson(json);

    test('the newest published release that is newer', () {
      final r = newestUpdate(
        list([releaseJson('v1.1.0'), releaseJson('v1.2.0'), releaseJson('v1.1.2')]),
        current,
      );
      expect(r!.tag, 'v1.2.0');
      expect(r.package!.sha256, hasLength(64));
      expect(r.checksums!.id, 101);
    });

    test('drafts, prereleases, -pre versions, odd tags and releases without '
        'a Windows package are ignored', () {
      final r = newestUpdate(
        list([
          releaseJson('v2.0.0', draft: true),
          releaseJson('v1.9.0', prerelease: true),
          releaseJson('v1.8.0-rc.1'),
          releaseJson('nightly'),
          releaseJson('v1.7.0', package: false),
          releaseJson('v1.1.1'),
        ]),
        current,
      );
      expect(r, isNull);
    });

    test('a digest that is not SHA-256 counts as none', () {
      final r = list([releaseJson('v1.2.0', digest: 'md5:abc')]).single;
      expect(r.package!.sha256, isNull);
    });

    test('SHA256SUMS.txt lines', () {
      const sums =
          '2bac2e3d0bd82be05a84566f6f43c0d8f41452edf159989806c877a117fe9eb0  NEXA_Music_1.2.0_Windows_x64.zip\r\n'
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa *other.zip\n';
      expect(
        checksumFor(sums, 'nexa_music_1.2.0_windows_x64.zip'),
        startsWith('2bac2e3d'),
      );
      expect(checksumFor(sums, 'other.zip'), startsWith('aaaa'));
      expect(checksumFor(sums, 'missing.zip'), isNull);
    });
  });

  group('daily check', () {
    final now = DateTime(2026, 12, 2, 12);
    test('at most once a day', () {
      expect(autoCheckDue(null, now), isTrue);
      expect(autoCheckDue(now.subtract(const Duration(hours: 23)), now), isFalse);
      expect(autoCheckDue(now.subtract(const Duration(hours: 24)), now), isTrue);
      // A clock set back: check again rather than never.
      expect(autoCheckDue(now.add(const Duration(days: 3)), now), isTrue);
    });
  });

  group('GitHub API without authorization', () {
    test('lists releases; never sends a token', () async {
      late http.Request seen;
      final client = MockClient((r) async {
        seen = r;
        return http.Response(jsonEncode([releaseJson('v1.2.0')]), 200);
      });
      final source = GitHubApiSource(client, appVersion: '1.1.1');
      final list = await source.releases();
      expect(list.single.tag, 'v1.2.0');
      expect(seen.url.toString(),
          'https://api.github.com/repos/KondexOFF/Nexa-Music/releases?per_page=30');
      expect(seen.headers.keys.map((k) => k.toLowerCase()),
          isNot(contains('authorization')));
      expect(seen.headers['User-Agent'], 'NEXA-Music/1.1.1');
    });

    test('downloads by asset id from this repository only', () async {
      late http.BaseRequest seen;
      final client = MockClient.streaming((r, _) async {
        seen = r;
        return http.StreamedResponse(Stream.value([1, 2, 3]), 200, contentLength: 3);
      });
      final asset = ReleaseAsset(
        id: 77,
        name: 'x.zip',
        size: 3,
        apiUrl: 'https://evil.example/steal',
        downloadUrl: 'https://evil.example/x.zip',
      );
      final (stream, total) = await GitHubApiSource(client).download(asset);
      expect(await stream.expand((c) => c).toList(), [1, 2, 3]);
      expect(total, 3);
      expect(seen.url.toString(),
          'https://api.github.com/repos/KondexOFF/Nexa-Music/releases/assets/77');
      expect(seen.headers['Accept'], 'application/octet-stream');
    });

    test('maps HTTP answers to problems', () async {
      Future<UpdateProblem> problem(int status, [Map<String, String>? h]) async {
        final s = GitHubApiSource(
          MockClient((_) async => http.Response('{}', status, headers: h ?? {})),
        );
        try {
          await s.releases();
        } on UpdateException catch (e) {
          return e.problem;
        }
        fail('no error for $status');
      }

      expect(await problem(404), UpdateProblem.notFound);
      expect(await problem(401), UpdateProblem.accessDenied);
      expect(await problem(403), UpdateProblem.accessDenied);
      expect(await problem(403, {'x-ratelimit-remaining': '0'}),
          UpdateProblem.rateLimited);
      expect(await problem(429), UpdateProblem.rateLimited);
      expect(await problem(500), UpdateProblem.badResponse);
      final offline = GitHubApiSource(
        MockClient((_) async => throw http.ClientException('no route')),
      );
      expect(
        () => offline.releases(),
        throwsA(isA<UpdateException>().having(
          (e) => e.problem, 'problem', UpdateProblem.offline)),
      );
    });
  });

  group('GitHub CLI', () {
    test('its messages become problems', () {
      UpdateProblem of(String s) => GhCliSource.problemFromGh(s).problem;
      expect(of('To get started with GitHub CLI, please run:  gh auth login'),
          UpdateProblem.notLoggedIn);
      expect(of('gh: Not Found (HTTP 404)'), UpdateProblem.accessDenied);
      expect(of('gh: API rate limit exceeded (HTTP 403)'), UpdateProblem.rateLimited);
      expect(of('error connecting to api.github.com'), UpdateProblem.offline);
      expect(of('something else'), UpdateProblem.badResponse);
    });

    test('a missing gh is reported, nothing else breaks', () async {
      final gh = GhCliSource(executable: null);
      if (GhCliSource.find() != null) {
        return; // gh installed on this computer: covered by the Windows run.
      }
      expect(
        gh.releases,
        throwsA(isA<UpdateException>().having(
          (e) => e.problem, 'problem', UpdateProblem.noGitHubCli)),
      );
    });
  });

  group('public first, then GitHub CLI', () {
    test('private repository (404) -> GitHub CLI', () async {
      final anonymous = FakeUpdateSource(
        error: const UpdateException(UpdateProblem.notFound),
      );
      final cli = FakeUpdateSource(
        list: ReleaseInfo.listFromJson([releaseJson('v1.2.0')]),
      );
      final auto = AutoSource(anonymous, cli);
      expect((await auto.releases()).single.tag, 'v1.2.0');
      expect(cli.checks, 1);
    });

    test('no network: GitHub CLI is not tried', () async {
      final anonymous = FakeUpdateSource(
        error: const UpdateException(UpdateProblem.offline),
      );
      final cli = FakeUpdateSource();
      expect(
        AutoSource(anonymous, cli).releases(),
        throwsA(isA<UpdateException>()),
      );
      await Future<void>.delayed(Duration.zero);
      expect(cli.checks, 0);
    });
  });
}
