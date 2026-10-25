// NEXA AutoTest - report.
//
// Usage:
//   dart run tools/autotest/make_report.dart <run folder> <repository>
//   dart run tools/autotest/make_report.dart --fingerprint <repository>
//
// The run folder gets results.json (this run only) and the combined report.
// The repository report (reports/FINAL_AUTOTEST_REPORT.md,
// reports/autotest/results.json) combines this run with earlier runs whose
// app code is known: every integration group / the exe stage comes from the
// newest run that executed it, and every result names its run and its build
// (app code fingerprint of lib, windows, assets, pubspec; B1 = this run).
// reports/autotest/runs/<run>.json keeps each run's own results.
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

const statuses = ['FAIL', 'BLOCKED', 'MANUAL REQUIRED', 'PASS', 'NOT RUN'];

/// FT-xx of reports/FINAL_TEST_PLAN.md.
const ftTitles = {
  'FT-01': 'Запуск Portable-сборки',
  'FT-02': 'Импорт библиотеки MP3 / FLAC / WAV',
  'FT-03': 'Сохранение после перезапуска',
  'FT-04': 'Пропавший файл и Rescan',
  'FT-05': 'Поиск, кириллица',
  'FT-06': '20–30 треков подряд',
  'FT-07': 'Пауза, перемотка, назад / вперёд',
  'FT-08': 'Очередь',
  'FT-09': 'Shuffle и Repeat',
  'FT-10': 'Громкость, Mute, устройство вывода',
  'FT-11': 'Crossfade 6 с',
  'FT-12': 'Crossfade 0 с и 12 с',
  'FT-13': 'Gapless внутри альбома',
  'FT-14': 'Smart Mix',
  'FT-15': 'Crossfade между форматами',
  'FT-16': 'Медиаклавиши и медиапанель Windows',
  'FT-17': 'Медиаклавиши рядом с другим плеером',
  'FT-18': 'Горячие клавиши',
  'FT-19': 'NEXA DNA',
  'FT-20': 'NEXA Wave',
  'FT-21': 'Дизлайк',
  'FT-22': 'Знакомое ↔ Открытия',
  'FT-23': 'Private session, Pause learning',
  'FT-24': 'Удаление истории, сброс DNA',
  'FT-25': 'Поиск Audius / Jamendo',
  'FT-26': 'Воспроизведение Audius / Jamendo',
  'FT-27': 'Без интернета',
  'FT-28': 'Доступность (UI Automation, Диктор)',
  'FT-29': 'Изменение размера окна с клиентом доступности (TD-02)',
  'FT-30': 'Минимальный и максимальный размер окна',
};

/// What still needs a person: what the AutoTest already covers, what is
/// left, the steps, the expected result and how long it takes.
const manual = [
  {
    'id': 'MAN-01', 'ft': 'FT-01', 'minutes': '0',
    'title': 'Первый запуск Portable-сборки',
    'covered': 'Release-сборка, Portable-папка, запуск exe, версия 0.9.0.',
    'how': 'Подтверждено владельцем 2026-10-22.',
    'expect': '-',
    'why': 'Первый запуск человеком (SmartScreen).',
  },
  {
    'id': 'MAN-02', 'ft': 'FT-02', 'minutes': '5',
    'title': 'Своя музыка через окно Windows «Add folder» (TD-05)',
    'covered': 'Импорт 36 сгенерированных файлов MP3 / FLAC / WAV: число, теги (кириллица), длительности, обложка, файлы не меняются, повторный Rescan без дубликатов.',
    'how': 'В обычной NEXA (не в тестовом профиле): Library → Add folder → своя папка, лучше 30+ треков разных форматов → дождаться строки «N added». Сверить 3–4 случайных трека с Проводником или другим плеером.',
    'expect': 'Число треков = число MP3 / FLAC / WAV в папке, без дубликатов; название, исполнитель, альбом и обложка совпадают; у файлов не изменилась дата изменения. (Известное ограничение: WAV-теги в кодировке Windows-1251 читаются неверно, TD-04.)',
    'why': 'Ваша настоящая библиотека и системный диалог выбора папки; автотест работает с генерированной библиотекой без диалога.',
  },
  {
    'id': 'MAN-10', 'ft': 'FT-10', 'minutes': '3',
    'title': 'Переключение на другое устройство вывода',
    'covered': 'Громкость 100 % / 50 % и Mute измерены по записи звука; список устройств; выбор System default.',
    'how': 'Только если есть второй выход (наушники, HDMI, USB). Во время игры Settings → Output device → другое устройство; перезапустить NEXA; затем вернуть System default.',
    'expect': 'Звук переходит на выбранное устройство примерно за секунду; после перезапуска выбор сохранён; System default возвращает звук на основное устройство.',
    'why': 'Нужен второй физический выход и человек, который слышит, где звучит.',
  },
  {
    'id': 'MAN-17', 'ft': 'FT-17', 'minutes': '2',
    'title': 'Медиаклавиши рядом с браузером',
    'covered': 'NEXA появляется в медиапанели Windows; Play/Pause, Next, Previous, Stop работают при свёрнутом окне (EX-16).',
    'how': 'NEXA играет → пауза в NEXA. В браузере включить видео (например YouTube). Нажать клавишу Play/Pause на клавиатуре два раза. Затем запустить песню в NEXA и нажать Play/Pause ещё раз.',
    'expect': 'Пока играет браузер, клавиша ставит на паузу и продолжает видео, NEXA остаётся на паузе; после запуска NEXA клавиша управляет NEXA. Браузер свои клавиши не теряет.',
    'why': 'Нужен чужой плеер со своей медиасессией; Windows сама решает, какой сессии отдать клавишу.',
  },
  {
    'id': 'MAN-27', 'ft': 'FT-27', 'minutes': '3',
    'title': 'Отключённый интернет',
    'covered': 'Недоступный адрес каталога даёт сообщение «offline», локальная песня играет (сеть компьютера при этом включена).',
    'how': 'Отключить Wi-Fi или кабель → Discover → поиск «jazz» → Library → запустить свою песню → включить сеть → снова поиск.',
    'expect': 'Без сети — понятное сообщение «Cannot reach the catalog…», NEXA не зависает и не закрывается, своя музыка играет; с сетью поиск снова даёт результаты.',
    'why': 'Автотест не отключает сеть вашего компьютера.',
  },
  {
    'id': 'MAN-28', 'ft': 'FT-28', 'minutes': '5',
    'title': 'Экранный диктор (TD-01, TD-03)',
    'covered': 'С подключённым клиентом доступности (MSAA / UI Automation) открыты все страницы, наведение на Play/Pause, кнопка очереди, Audio test и назад — без сбоя; 0 сбоев в журнале Windows.',
    'how': 'Win+Ctrl+Enter (Диктор). Tab по Home, Now Playing, Wave, Discover, Settings. Навести мышь на Play/Pause, нажать кнопку очереди, Settings → Open audio engine test → Back. Выключить Диктор (Win+Ctrl+Enter).',
    'expect': 'Диктор называет кнопки и поля понятными словами (не просто «кнопка»); NEXA не закрывается.',
    'why': 'Понятность озвучивания оценивает человек.',
  },
  {
    'id': 'MAN-29', 'ft': 'FT-29', 'minutes': '2',
    'title': 'Диктор после изменения размера окна (TD-02)',
    'covered': 'Ресайз и разворачивание с клиентом доступности без сбоя; 0 сообщений «Failed to update ui::AXTree»; дерево доступности следует за переходами.',
    'how': 'Сразу после MAN-28, Диктор включён: развернуть окно на весь экран, вернуть, сузить до упора, затем Tab по 2–3 элементам.',
    'expect': 'Окно не закрывается; Диктор читает новые элементы, а не молчит и не повторяет старые.',
    'why': 'Нужен настоящий Диктор; автотест проверяет дерево доступности, но не речь.',
  },
  {
    'id': 'MAN-30', 'ft': 'FT-30', 'minutes': '3',
    'title': 'Внешний вид на минимальном и полном окне',
    'covered': 'Окно не становится меньше 1024 × 640; все страницы открываются на минимальном и развёрнутом окне без сбоя; сделаны скриншоты.',
    'how': 'Открыть скриншоты 05–12 в папке запуска (`<root>\\_autotest_runs\\<прогон exe-этапа>\\screenshots`) или проверить в NEXA: окно сжать до упора и развернуть на весь экран — Home, Now Playing, Wave, Discover, Settings.',
    'expect': 'Ничего не обрезано и не перекрыто; правая панель и боковое меню перестраиваются.',
    'why': 'Обрезанный или перекрытый интерфейс оценивает человек.',
  },
];

const tdMap = {
  'TD-01': ['FT-28'], 'TD-02': ['FT-29'], 'TD-03': ['FT-28'], 'TD-04': ['FT-02'],
  'TD-05': ['FT-02'], 'TD-06': ['FT-16', 'FT-17'], 'TD-07': ['FT-06', 'FT-07', 'FT-08', 'FT-09', 'FT-10'],
  'TD-08': ['FT-14'], 'TD-09': ['FT-11', 'FT-12', 'FT-13', 'FT-15'], 'TD-10': ['FT-20', 'FT-22'],
  'TD-11': ['FT-20'], 'TD-12': ['FT-19'], 'TD-13': ['FT-25'], 'TD-14': ['FT-26'], 'TD-15': ['FT-26'],
  'TD-16': ['FT-16', 'FT-17'], 'TD-17': ['FT-01'], 'TD-18': ['FT-18'],
};

String worst(Iterable<String> s) {
  final list = s.toList();
  if (list.isEmpty) {
    return 'NOT RUN';
  }
  return statuses.firstWhere(list.contains, orElse: () => 'NOT RUN');
}

Map<String, dynamic>? readJson(String path) {
  final f = File(path);
  if (!f.existsSync()) {
    return null;
  }
  return jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
}


/// The app code under test: everything that goes into nexa_music.exe.
const appPaths = ['lib', 'windows', 'assets', 'pubspec.yaml', 'pubspec.lock'];

Future<ProcessResult> git(String repo, List<String> args, {String? stdin}) async {
  final p = await Process.start('git', ['-C', repo, ...args]);
  if (stdin != null) {
    p.stdin.write(stdin);
  }
  await p.stdin.close();
  final out = await p.stdout.transform(utf8.decoder).join();
  final err = await p.stderr.transform(utf8.decoder).join();
  return ProcessResult(p.pid, await p.exitCode, out, err);
}

String fingerprintOf(List<(String, String)> files) {
  final sorted = [...files]..sort((a, b) => a.$1.compareTo(b.$1));
  final text = sorted.map((f) => '${f.$1} ${f.$2}').join('\n');
  return sha256.convert(utf8.encode(text)).toString().substring(0, 12);
}

/// Fingerprint of the app code in the working tree (as built now).
Future<String?> fingerprintWorkingTree(String repo) async {
  final ls = await git(repo, ['ls-files', '-z', '-co', '--exclude-standard', '--', ...appPaths]);
  if (ls.exitCode != 0) {
    return null;
  }
  final paths = (ls.stdout as String).split('\x00').where((x) => x.isNotEmpty).toSet().toList();
  final hashes = await git(repo, ['hash-object', '--stdin-paths'], stdin: '${paths.join('\n')}\n');
  final list = (hashes.stdout as String).split('\n').map((x) => x.trim()).where((x) => x.isNotEmpty).toList();
  if (hashes.exitCode != 0 || list.length != paths.length) {
    return null;
  }
  return fingerprintOf([for (var i = 0; i < paths.length; i++) (paths[i], list[i])]);
}

/// Fingerprint of the app code of a commit.
Future<String?> fingerprintAtCommit(String repo, String commit) async {
  final r = await git(repo, ['ls-tree', '-r', '-z', commit, '--', ...appPaths]);
  if (r.exitCode != 0) {
    return null;
  }
  final files = <(String, String)>[];
  for (final entry in (r.stdout as String).split('\x00').where((x) => x.isNotEmpty)) {
    final tab = entry.indexOf('\t');
    final parts = entry.substring(0, tab).split(' ');
    if (parts.length == 3 && parts[1] == 'blob') {
      files.add((entry.substring(tab + 1), parts[2]));
    }
  }
  return files.isEmpty ? null : fingerprintOf(files);
}

Future<void> printFingerprint(String repo) async {
  final fp = await fingerprintWorkingTree(repo);
  final last = await git(repo, ['log', '-1', '--format=%h', '--', ...appPaths]);
  final status = await git(repo, ['status', '--porcelain', '--', ...appPaths]);
  final changed = [
    for (final l in (status.stdout as String).split('\n'))
      if (l.trim().length > 3) l.substring(3).trim(),
  ];
  stdout.writeln(jsonEncode({
    'fingerprint': fp,
    'appCommit': (last.stdout as String).trim(),
    'dirty': changed.isNotEmpty,
    'changed': changed,
  }));
}

const allIntegrationGroups = ['library', 'playback', 'mix', 'dna', 'online'];

/// Integration group of a check id (null: not an integration check).
String? groupOf(String id) {
  if (id.startsWith('PROBE-')) {
    return 'probe';
  }
  if (!id.startsWith('AT-')) {
    return null;
  }
  final named = RegExp(r'^AT-([a-z]+)-(crash|timeout)$').firstMatch(id);
  if (named != null) {
    return named.group(1);
  }
  final n = id.length < 5 ? -1 : int.tryParse(id.substring(3, 5)) ?? -1;
  const ranges = {'library': (2, 5), 'playback': (6, 10), 'mix': (11, 15), 'dna': (19, 24), 'online': (25, 27)};
  for (final e in ranges.entries) {
    if (n >= e.value.$1 && n <= e.value.$2) {
      return e.key;
    }
  }
  return 'other';
}

/// One run folder: its own results and how its app code is known.
class RunInfo {
  RunInfo(this.name, this.dir, this.meta, this.checks, this.fingerprint, this.howKnown);

  final String name;
  final String dir;
  final Map<String, dynamic> meta;
  final List<Map<String, dynamic>> checks;
  final String? fingerprint;
  final String howKnown;

  String get commit => '${meta['commit'] ?? '-'}${meta['uncommitted'] == true ? ' (+ uncommitted changes)' : ''}';

  /// Integration groups this run executed itself.
  Set<String> get integrationGroups {
    if (!checks.any((c) => groupOf(c['id'] as String) != null)) {
      return {};
    }
    final g = '${meta['groups'] ?? ''}'.trim();
    return g.isEmpty ? allIntegrationGroups.toSet() : g.split(',').map((x) => x.trim()).toSet();
  }

  bool get ranExe => checks.any((c) => (c['id'] as String).startsWith('EX-'));

  /// What app code this run tested, in words.
  String get buildText {
    final app = meta['appSource'];
    if (app is Map && app['appCommit'] != null) {
      final changed = (app['changed'] as List<dynamic>? ?? const []).join(', ');
      return 'код коммита ${app['appCommit']}${changed.isEmpty ? '' : ' + незакоммиченные изменения: $changed'}';
    }
    return howKnown;
  }
  String get date => '${meta['startedAt'] ?? name}';
}

/// The run's own checks (results copied in from other runs are skipped).
List<Map<String, dynamic>> ownChecks(String dir) {
  final system = readJson('$dir/system.json');
  final copied = (system?['checks'] as List<dynamic>? ?? const [])
      .any((c) => (c as Map<String, dynamic>)['id'] == 'SYS-integration-source');
  return [
    for (final src in [system, if (!copied) readJson('$dir/it/integration.json'), readJson('$dir/exe.json')])
      if (src != null)
        for (final c in (src['checks'] as List<dynamic>).cast<Map<String, dynamic>>())
          if (c['id'] != 'SYS-integration-source') c,
  ];
}

Future<RunInfo> loadRun(String dir, String repo, Map<String, dynamic> notes) async {
  final name = dir.replaceAll(r'\', '/').split('/').last;
  final meta = (readJson('$dir/system.json')?['meta'] as Map<String, dynamic>?) ?? {};
  String? fp;
  var how = 'неизвестен';
  final app = meta['appSource'];
  final note = notes[name] as Map<String, dynamic>?;
  if (app is Map && app['fingerprint'] != null) {
    fp = app['fingerprint'] as String;
    how = 'измерен в начале прогона';
  } else if (meta['uncommitted'] == false && meta['commit'] != null) {
    fp = await fingerprintAtCommit(repo, meta['commit'] as String);
    how = 'по коммиту ${meta['commit']} (без незакоммиченных изменений)';
  } else if (note != null && note['appCommit'] != null) {
    fp = await fingerprintAtCommit(repo, note['appCommit'] as String);
    how = 'по коммиту ${note['appCommit']}, по записи в run_notes.json: ${note['note']}';
  }
  return RunInfo(name, dir, meta, ownChecks(dir), fp, how);
}

Future<void> main(List<String> args) async {
  if (args.isNotEmpty && args.first == '--fingerprint') {
    await printFingerprint(args[1]);
    return;
  }
  final run = args[0];
  final repo = args[1];
  final root = Directory(repo).parent.path;
  // No personal paths in reports: plain, forward-slash and file:/// forms.
  String uri(String path) => 'file:///${path.replaceAll(r'\', '/').replaceAll(' ', '%20')}';
  String clean(Object? v) => '$v'
      .replaceAll(uri(run), '<run>')
      .replaceAll(uri(repo), '<repo>')
      .replaceAll(uri(root), '<root>')
      .replaceAll(run, '<run>')
      .replaceAll(repo, '<repo>')
      .replaceAll(root, '<root>')
      .replaceAll(run.replaceAll(r'\', '/'), '<run>')
      .replaceAll(repo.replaceAll(r'\', '/'), '<repo>')
      .replaceAll(root.replaceAll(r'\', '/'), '<root>');

  final notes = readJson('$repo/tools/autotest/run_notes.json') ?? const {};
  final current = await loadRun(run, repo, notes);
  final runsDir = Directory(run).parent;
  final others = <RunInfo>[];
  final dirs = runsDir.listSync().whereType<Directory>().toList()
    ..sort((a, b) => b.path.compareTo(a.path));
  for (final d in dirs) {
    final name = d.path.replaceAll(r'\', '/').split('/').last;
    if (name == current.name || !File('${d.path}/system.json').existsSync()) {
      continue;
    }
    others.add(await loadRun(d.path, repo, notes));
  }
  final fp = current.fingerprint;
  // Runs whose app code is known; results of different app code (builds)
  // are labelled B1 (this run's code), B2, ... next to every result.
  final same = [for (final r in others) if (r.fingerprint != null) r];
  final excluded = others.length - same.length;
  final builds = <String, String>{};
  for (final r in [current, ...same]) {
    final f = r.fingerprint ?? 'unknown';
    builds.putIfAbsent(f, () => 'B${builds.length + 1}');
  }
  String buildOf(RunInfo r) => builds[r.fingerprint ?? 'unknown']!;

  // Newest result of every check from runs with the same app code. A whole
  // integration group (and the whole exe stage) always comes from one run:
  // once a newer run executed a group, older results of that group (also
  // old "group stopped" entries) are not used.
  final merged = <String, Map<String, dynamic>>{};
  final used = <String>{};
  final takenGroups = <String>{};
  var exeTaken = false;
  for (final r in [current, ...same]) {
    for (final c in r.checks) {
      final id = c['id'] as String;
      final isExe = id.startsWith('EX-');
      final group = groupOf(id);
      if (merged.containsKey(id) || (isExe && exeTaken) || (group != null && takenGroups.contains(group))) {
        continue;
      }
      merged[id] = {...c, 'detail': clean(c['detail']), 'run': r.name, 'build': buildOf(r), 'appCode': r.fingerprint};
      used.add(r.name);
    }
    takenGroups.addAll(r.integrationGroups);
    exeTaken = exeTaken || r.ranExe;
  }
  final checks = merged.values.toList();
  final sources = [for (final r in [current, ...same]) if (used.contains(r.name)) r];
  final usedBuilds = {for (final r in sources) buildOf(r): r};

  final confirmations = readJson('$repo/tools/autotest/manual_results.json') ?? const {};
  final manualItems = [
    for (final m in manual)
      {
        ...m,
        'status': (confirmations[m['id']] as Map?)?['status'] ?? 'MANUAL REQUIRED',
        'confirmed': confirmations[m['id']],
      },
  ];

  final ft = <String, Map<String, Object?>>{};
  for (final id in ftTitles.keys) {
    final auto = checks.where((c) => c['ft'] == id).toList();
    final man = manualItems.where((m) => m['ft'] == id).toList();
    final all = [...auto.map((c) => c['status'] as String), ...man.map((m) => m['status'] as String)];
    ft[id] = {
      'title': ftTitles[id],
      'status': worst(all),
      'automated': [for (final c in auto) '${c['id']}: ${c['status']}'],
      'runs': {for (final c in auto) '${c['run']} (${c['build']})'}.toList()..sort(),
      'manual': [for (final m in man) '${m['id']}: ${m['status']}'],
    };
  }
  final ftCounts = {for (final s in statuses) s: ft.values.where((x) => x['status'] == s).length};
  final checkCounts = {for (final s in statuses) s: checks.where((c) => c['status'] == s).length};

  Map<String, Object?> runJson(RunInfo r) => {
    'run': r.name,
    'startedAt': r.meta['startedAt'],
    'commit': r.meta['commit'],
    'uncommitted': r.meta['uncommitted'],
    'appVersion': r.meta['appVersion'],
    'appCode': r.fingerprint,
    'build': buildOf(r),
    'appCodeKnown': r.howKnown,
    'groups': r.meta['groups'],
    'stages': r.meta['stages'],
  };
  final results = {
    'meta': current.meta,
    'appCode': fp,
    'statusLegend': statuses,
    'sources': [for (final r in sources) runJson(r)],
    'summary': {'ft': ftCounts, 'checks': checkCounts},
    'ft': ft,
    'checks': checks,
    'manual': manualItems,
    'td': {
      for (final e in tdMap.entries)
        e.key: {'ft': e.value, 'status': worst(e.value.map((f) => ft[f]!['status'] as String))},
    },
  };
  final ownResults = {
    'run': runJson(current),
    'checks': [for (final c in current.checks) {...c, 'detail': clean(c['detail'])}],
  };

  final meta = current.meta;
  final md = StringBuffer()
    ..writeln('# NEXA Music — FINAL AUTOTEST REPORT')
    ..writeln()
    ..writeln('Последний прогон: `${current.name}` (${meta['startedAt'] ?? '-'} … ${meta['finishedAt'] ?? '-'})'
        '${(meta['groups'] ?? '').toString().isNotEmpty ? ', группы `${meta['groups']}`' : ''}  ')
    ..writeln('Версия приложения: ${meta['appVersion'] ?? '-'}; код приложения (lib, windows, assets, pubspec) '
        '`${fp ?? 'неизвестен'}` — ${current.howKnown}  ')
    ..writeln('Среда: ${meta['windows'] ?? '-'}; ${meta['flutter'] ?? '-'}  ')
    ..writeln('Запуск: `NEXA_AutoTest.cmd` (папки прогонов `<root>\\_autotest_runs\\<прогон>`)')
    ..writeln()
    ..writeln('Статусы: PASS — ожидаемый результат проверен; FAIL — проверено, результат неверный; '
        'BLOCKED — проверку не удалось выполнить (причина указана, например выключенный звук Windows); '
        'MANUAL REQUIRED — нужна короткая ручная проверка; NOT RUN — не запускалась.')
    ..writeln()
    ..writeln('Уровень каждой автоматической проверки указан отдельно: unit / widget-тесты (FakeEngine) не считаются '
        'подтверждением работы Windows-exe; интеграционные тесты используют настоящий media_kit, SQLite, файлы и HTTP '
        '(debug-сборка); этап «Release exe» управляет настоящей Portable-сборкой через MSAA / UI Automation. '
        'Звук измеряется записью WASAPI process loopback (только звук NEXA); перед записью проверяются устройство, '
        'Mute и громкость Windows, и во время каждой записи — Mute и громкость устройства и NEXA в микшере громкости.')
    ..writeln()
    ..writeln('## Источники результатов')
    ..writeln()
    ..writeln('Для каждой группы проверок взят самый новый прогон, где она выполнялась. У каждого результата указаны '
        'прогон и **сборка** — код приложения (lib, windows, assets, pubspec), на котором он получен. '
        '${usedBuilds.length > 1 ? '**Внимание: результаты получены на ${usedBuilds.length} сборках** (см. таблицу сборок); ' : 'Все результаты получены на одной сборке. '}'
        '${excluded > 0 ? '$excluded прогонов с неизвестным кодом приложения (до 2026-10-25) не использованы.' : ''}')
    ..writeln()
    ..writeln('| Сборка | Код приложения | Что это |')
    ..writeln('|---|---|---|');
  for (final e in usedBuilds.entries) {
    md.writeln('| ${e.key} | `${e.value.fingerprint ?? '-'}` | ${e.value.buildText}'
        '${e.value.fingerprint == fp ? ' (код последнего прогона)' : ''} |');
  }
  md
    ..writeln()
    ..writeln('| Прогон | Начало | Коммит | Сборка | Код приложения установлен | Группы / этапы | Проверок взято |')
    ..writeln('|---|---|---|---|---|---|---|');
  for (final r in sources) {
    final st = r.meta['stages'];
    final stages = st is Map
        ? [for (final e in st.entries) if (e.value == true) e.key].join(', ')
        : 'unit / integration / exe (по файлам)';
    final ranIntegration = st is Map ? st['integration'] == true : r.integrationGroups.isNotEmpty;
    final groups = !ranIntegration
        ? 'без интеграционных групп'
        : ('${r.meta['groups'] ?? ''}'.isEmpty ? 'все группы' : 'группы ${r.meta['groups']}');
    md.writeln('| `${r.name}` | ${r.date} | `${r.commit}` | ${buildOf(r)} | ${r.howKnown} | $groups; $stages | '
        '${checks.where((c) => c['run'] == r.name).length} |');
  }
  md
    ..writeln()
    ..writeln('## Итог')
    ..writeln()
    ..writeln('| | FAIL | BLOCKED | MANUAL REQUIRED | PASS | NOT RUN |')
    ..writeln('|---|---|---|---|---|---|')
    ..writeln('| Тесты FT (30) | ${ftCounts['FAIL']} | ${ftCounts['BLOCKED']} | ${ftCounts['MANUAL REQUIRED']} | ${ftCounts['PASS']} | ${ftCounts['NOT RUN']} |')
    ..writeln('| Отдельные проверки (${checks.length}) | ${checkCounts['FAIL']} | ${checkCounts['BLOCKED']} | ${checkCounts['MANUAL REQUIRED']} | ${checkCounts['PASS']} | ${checkCounts['NOT RUN']} |')
    ..writeln()
    ..writeln('## FT-01 – FT-30: автоматические и ручные проверки')
    ..writeln()
    ..writeln('| FT | Сценарий | Статус | Автоматически | Прогон (сборка) | Вручную |')
    ..writeln('|---|---|---|---|---|---|');
  for (final e in ft.entries) {
    md.writeln('| ${e.key} | ${e.value['title']} | **${e.value['status']}** | '
        '${(e.value['automated'] as List).join('<br>')} | ${(e.value['runs'] as List).map((r) => '`$r`').join('<br>')} | '
        '${(e.value['manual'] as List).join('<br>')} |');
  }
  md
    ..writeln()
    ..writeln('## Технический долг TD-01 – TD-18')
    ..writeln()
    ..writeln('| TD | Проверяется в | Статус |')
    ..writeln('|---|---|---|');
  for (final e in (results['td'] as Map<String, dynamic>).entries) {
    md.writeln('| ${e.key} | ${(e.value['ft'] as List).join(', ')} | ${e.value['status']} |');
  }
  md
    ..writeln()
    ..writeln('## Ошибки и блокировки')
    ..writeln();
  final problems = checks.where((c) => c['status'] == 'FAIL' || c['status'] == 'BLOCKED').toList();
  if (problems.isEmpty) {
    md.writeln('Нет.');
  }
  for (final c in problems) {
    md.writeln('- **${c['status']} ${c['id']}** (${c['ft']}, прогон `${c['run']}`, ${c['build']}) ${c['title']} — ${c['detail']}');
  }
  final open = manualItems.where((m) => m['status'] != 'PASS').toList();
  final minutes = open.fold<int>(0, (s, m) => s + (int.tryParse('${m['minutes']}') ?? 0));
  md
    ..writeln()
    ..writeln('## Что действительно нужно проверить вручную (≈$minutes мин)')
    ..writeln()
    ..writeln('Ответ: `MAN-xx OK` или `MAN-xx FAIL: что сделали → что ожидали → что увидели`. '
        'MAN-28 и MAN-29 удобно пройти вместе. Если второго устройства вывода нет, ответьте `MAN-10 нет устройства` — '
        'пункт останется непроверенным с этой причиной.')
    ..writeln()
    ..writeln('| ID | FT | Что сделать | Ожидаемый результат | Уже проверено автоматически | Мин. | Статус |')
    ..writeln('|---|---|---|---|---|---|---|');
  for (final m in manualItems) {
    md.writeln('| ${m['id']} | ${m['ft']} | **${m['title']}.** ${m['how']} | ${m['expect']} | ${m['covered']} | '
        '${m['minutes']} | ${m['status']} |');
  }
  md
    ..writeln()
    ..writeln('## Все проверки')
    ..writeln()
    ..writeln('| ID | FT | Проверка | Уровень | Статус | Прогон | Сборка | Подробности |')
    ..writeln('|---|---|---|---|---|---|---|---|');
  for (final c in checks) {
    final detail = '${c['detail']}'.replaceAll('\n', ' ').replaceAll('|', '/');
    md.writeln('| ${c['id']} | ${c['ft']} | ${c['title']} | ${c['level'] ?? ''} | ${c['status']} | `${c['run']}` | ${c['build']} | $detail |');
  }
  md
    ..writeln()
    ..writeln('## Артефакты прогонов (вне репозитория)')
    ..writeln()
    ..writeln('`<root>\\_autotest_runs\\<прогон>\\`: `autotest.log`, `unit.log`, `integration.log`, '
        '`it\\integration.json`, `it\\recordings\\*.wav` (записи звука NEXA), `exe.json`, `exe_app.log`, '
        '`screenshots\\*.png`, `crash_records.txt` (если были сбои), `results.json`. '
        'Результаты каждого прогона отдельно: `reports/autotest/runs/<прогон>.json`.');

  final summary = StringBuffer('FT: ');
  summary.write(ftCounts.entries.where((e) => e.value > 0).map((e) => '${e.value} ${e.key}').join(', '));
  summary.write('\nChecks: ');
  summary.write(checkCounts.entries.where((e) => e.value > 0).map((e) => '${e.value} ${e.key}').join(', '));
  summary.write('\nSources: ${sources.map((r) => '${r.name} (${buildOf(r)})').join(', ')}; this run app code ${fp ?? '-'}');
  for (final c in problems) {
    summary.write('\n  ${c['status']} ${c['id']} ${c['title']} [${c['run']} ${c['build']}]');
  }

  const enc = JsonEncoder.withIndent(' ');
  File('$run/results.json').writeAsStringSync(enc.convert(ownResults));
  File('$run/results_combined.json').writeAsStringSync(enc.convert(results));
  File('$run/FINAL_AUTOTEST_REPORT.md').writeAsStringSync(md.toString());
  File('$run/summary.txt').writeAsStringSync(summary.toString());
  Directory('$repo/reports/autotest/runs').createSync(recursive: true);
  File('$repo/reports/autotest/runs/${current.name}.json').writeAsStringSync(enc.convert(ownResults));
  File('$repo/reports/autotest/results.json').writeAsStringSync(enc.convert(results));
  File('$repo/reports/FINAL_AUTOTEST_REPORT.md').writeAsStringSync(md.toString());
  stdout.writeln(summary);
}
