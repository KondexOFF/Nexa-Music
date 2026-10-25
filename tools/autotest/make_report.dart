// NEXA AutoTest - merges the stage results of one run into
// results.json and FINAL_AUTOTEST_REPORT.md (run folder + repository).
//
// Usage: dart run tools/autotest/make_report.dart <run folder> <repository>
import 'dart:convert';
import 'dart:io';

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

/// What still needs a person, and why it cannot be automated reliably.
const manual = [
  {'id': 'MAN-01', 'ft': 'FT-01', 'title': 'Владелец скопировал Portable-папку и запустил exe', 'how': 'Подтверждено владельцем.', 'why': 'Проверка первого запуска человеком (SmartScreen).'},
  {'id': 'MAN-02', 'ft': 'FT-02', 'title': 'Своя музыка через окно Windows «Add folder» (TD-05)', 'how': 'Library → Add folder → своя папка с музыкой; сверить число треков и 3–4 названия.', 'why': 'Ваша настоящая библиотека и системный диалог выбора папки; автотест использует сгенерированную библиотеку без диалога.'},
  {'id': 'MAN-10', 'ft': 'FT-10', 'title': 'Переключение устройства вывода', 'how': 'Settings → Output device: другое устройство (наушники / HDMI) → звук там; затем System default.', 'why': 'Нужен второй физический выход и человек, который его слышит.'},
  {'id': 'MAN-17', 'ft': 'FT-17', 'title': 'Медиаклавиши рядом с браузером', 'how': 'NEXA на паузе, видео в браузере играет → Play/Pause на клавиатуре управляет браузером.', 'why': 'Нужен чужой плеер (браузер) с его собственной медиасессией.'},
  {'id': 'MAN-27', 'ft': 'FT-27', 'title': 'Отключённый интернет', 'how': 'Отключить Wi-Fi / кабель → Discover → поиск → понятное сообщение; своя песня играет.', 'why': 'Автотест не отключает сеть компьютера (имитирует недоступный адрес).'},
  {'id': 'MAN-28', 'ft': 'FT-28', 'title': 'Экранный диктор', 'how': 'Win+Ctrl+Enter, Tab по Home, Now Playing, Wave, Discover, Settings; Диктор читает элементы; затем выключить.', 'why': 'Качество озвучивания оценивает человек.'},
  {'id': 'MAN-29', 'ft': 'FT-29', 'title': 'Диктор после изменения размера окна (TD-02)', 'how': 'С включённым Диктором развернуть / уменьшить окно, затем Tab по 2–3 элементам.', 'why': 'Нужен настоящий Диктор; автотест проверяет только дерево UI Automation.'},
  {'id': 'MAN-30', 'ft': 'FT-30', 'title': 'Внешний вид на минимальном и максимальном окне', 'how': 'Открыть скриншоты 11_minimum_size.png и 12_maximised.png (и 05–10) из папки запуска.', 'why': 'Обрезанный или перекрытый интерфейс оценивает человек по скриншотам.'},
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

void main(List<String> args) {
  final run = args[0];
  final repo = args[1];
  final root = Directory(repo).parent.path;
  String clean(Object? v) => '$v'
      .replaceAll(run, '<run>')
      .replaceAll(repo, '<repo>')
      .replaceAll(root, '<root>')
      .replaceAll(run.replaceAll(r'\', '/'), '<run>')
      .replaceAll(root.replaceAll(r'\', '/'), '<root>');

  final system = readJson('$run/system.json');
  final integration = readJson('$run/it/integration.json');
  final exe = readJson('$run/exe.json');
  final meta = (system?['meta'] as Map<String, dynamic>?) ?? {};
  final checks = <Map<String, dynamic>>[
    for (final src in [system, integration, exe])
      if (src != null)
        for (final c in src['checks'] as List<dynamic>)
          {
            ...(c as Map<String, dynamic>),
            'detail': clean(c['detail']),
          },
  ];

  final confirmations =
      readJson('$repo/tools/autotest/manual_results.json') ?? const {};
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
      'manual': [for (final m in man) '${m['id']}: ${m['status']}'],
    };
  }
  final ftCounts = {for (final s in statuses) s: ft.values.where((x) => x['status'] == s).length};
  final checkCounts = {for (final s in statuses) s: checks.where((c) => c['status'] == s).length};

  final results = {
    'meta': meta,
    'statusLegend': statuses,
    'summary': {'ft': ftCounts, 'checks': checkCounts},
    'ft': ft,
    'checks': checks,
    'manual': manualItems,
    'td': {
      for (final e in tdMap.entries)
        e.key: {'ft': e.value, 'status': worst(e.value.map((f) => ft[f]!['status'] as String))},
    },
  };
  final json = const JsonEncoder.withIndent(' ').convert(results);

  final md = StringBuffer()
    ..writeln('# NEXA Music — FINAL AUTOTEST REPORT')
    ..writeln()
    ..writeln('Дата запуска: ${meta['startedAt'] ?? '-'} … ${meta['finishedAt'] ?? '-'}  ')
    ..writeln('Версия приложения: ${meta['appVersion'] ?? '-'}, коммит `${meta['commit'] ?? '-'}`'
        '${meta['uncommitted'] == true ? ' (+ незакоммиченные изменения)' : ''}  ')
    ..writeln('Среда: ${meta['windows'] ?? '-'}; ${meta['flutter'] ?? '-'}  ')
    ..writeln('Запуск: `NEXA_AutoTest.cmd` (папка запуска `<root>\\_autotest_runs\\${meta['run'] ?? ''}`)')
    ..writeln()
    ..writeln('Статусы: PASS — ожидаемый результат проверен; FAIL — проверено, результат неверный; '
        'BLOCKED — проверку не удалось выполнить (причина указана); MANUAL REQUIRED — нужна короткая ручная проверка; '
        'NOT RUN — не запускалась.')
    ..writeln()
    ..writeln('Уровень каждой автоматической проверки указан отдельно: unit / widget-тесты (FakeEngine) не считаются '
        'подтверждением работы Windows-exe; интеграционные тесты используют настоящий media_kit, SQLite, файлы и HTTP '
        '(debug-сборка); этап «Release exe» управляет настоящей Portable-сборкой через UI Automation. '
        'Звук измеряется записью реального выхода Windows (WASAPI Loopback)'
        '${meta['loopback'] == true ? '' : ' — в этом запуске запись была НЕДОСТУПНА'}.')
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
    ..writeln('| FT | Сценарий | Статус | Автоматически | Вручную |')
    ..writeln('|---|---|---|---|---|');
  for (final e in ft.entries) {
    md.writeln('| ${e.key} | ${e.value['title']} | **${e.value['status']}** | '
        '${(e.value['automated'] as List).join('<br>')} | ${(e.value['manual'] as List).join('<br>')} |');
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
    md.writeln('- **${c['status']} ${c['id']}** (${c['ft']}) ${c['title']} — ${c['detail']}');
  }
  md
    ..writeln()
    ..writeln('## Что осталось проверить вручную (≈10–15 минут)')
    ..writeln()
    ..writeln('| ID | FT | Что сделать | Почему не автоматизировано | Статус |')
    ..writeln('|---|---|---|---|---|');
  for (final m in manualItems) {
    md.writeln('| ${m['id']} | ${m['ft']} | **${m['title']}.** ${m['how']} | ${m['why']} | ${m['status']} |');
  }
  md
    ..writeln()
    ..writeln('## Все проверки')
    ..writeln()
    ..writeln('| ID | FT | Проверка | Уровень | Статус | Подробности |')
    ..writeln('|---|---|---|---|---|---|');
  for (final c in checks) {
    final detail = '${c['detail']}'.replaceAll('\n', ' ').replaceAll('|', '/');
    md.writeln('| ${c['id']} | ${c['ft']} | ${c['title']} | ${c['level'] ?? ''} | ${c['status']} | $detail |');
  }
  md
    ..writeln()
    ..writeln('## Артефакты запуска (вне репозитория)')
    ..writeln()
    ..writeln('`<root>\\_autotest_runs\\${meta['run'] ?? ''}\\`: `autotest.log`, `unit.log`, `integration.log`, '
        '`it\\integration.json`, `it\\recordings\\*.wav` (записи выхода Windows), `exe.json`, `exe_app.log`, '
        '`screenshots\\*.png`, `crash_records.txt` (если были сбои), `results.json`.');

  final summary = StringBuffer('FT: ');
  summary.write(ftCounts.entries.where((e) => e.value > 0).map((e) => '${e.value} ${e.key}').join(', '));
  summary.write('\nChecks: ');
  summary.write(checkCounts.entries.where((e) => e.value > 0).map((e) => '${e.value} ${e.key}').join(', '));
  for (final c in problems) {
    summary.write('\n  ${c['status']} ${c['id']} ${c['title']}');
  }

  File('$run/results.json').writeAsStringSync(json);
  File('$run/FINAL_AUTOTEST_REPORT.md').writeAsStringSync(md.toString());
  File('$run/summary.txt').writeAsStringSync(summary.toString());
  Directory('$repo/reports/autotest').createSync(recursive: true);
  File('$repo/reports/autotest/results.json').writeAsStringSync(json);
  File('$repo/reports/FINAL_AUTOTEST_REPORT.md').writeAsStringSync(md.toString());
  stdout.writeln(summary);
}
