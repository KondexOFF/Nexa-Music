# NEXA Music — FINAL AUTOTEST REPORT

Последний прогон: `20261025_200734` (2026-10-25T20:07:34 … 2026-10-25T20:10:54), группы `library,dna,online`  
Версия приложения: 1.0.0+8; код приложения (lib, windows, assets, pubspec) `30c68c1299b5` — измерен в начале прогона  
Среда: Microsoft Windows 11 Pro; Flutter 3.47.7 • channel stable • https://github.com/flutter/flutter.git  
Запуск: `NEXA_AutoTest.cmd` (папки прогонов `<root>\_autotest_runs\<прогон>`)

Статусы: PASS — ожидаемый результат проверен; FAIL — проверено, результат неверный; BLOCKED — проверку не удалось выполнить (причина указана, например выключенный звук Windows); MANUAL REQUIRED — нужна короткая ручная проверка; NOT RUN — не запускалась.

Уровень каждой автоматической проверки указан отдельно: unit / widget-тесты (FakeEngine) не считаются подтверждением работы Windows-exe; интеграционные тесты используют настоящий media_kit, SQLite, файлы и HTTP (debug-сборка); этап «Release exe» управляет настоящей Portable-сборкой через MSAA / UI Automation. Звук измеряется записью WASAPI process loopback (только звук NEXA); перед записью проверяются устройство, Mute и громкость Windows, и во время каждой записи — Mute и громкость устройства и NEXA в микшере громкости.

## Источники результатов

Для каждой группы проверок взят самый новый прогон, где она выполнялась. У каждого результата указаны прогон и **сборка** — код приложения (lib, windows, assets, pubspec), на котором он получен. **Внимание: результаты получены на 2 сборках** (см. таблицу сборок); 8 прогонов с неизвестным кодом приложения (до 2026-10-25) не использованы.

| Сборка | Код приложения | Что это |
|---|---|---|
| B1 | `30c68c1299b5` | код коммита 417c51c (код последнего прогона) |
| B2 | `cb5886f118de` | код коммита 0dcf12c |

| Прогон | Начало | Коммит | Сборка | Код приложения установлен | Группы / этапы | Проверок взято |
|---|---|---|---|---|---|---|
| `20261025_200734` | 2026-10-25T20:07:34 | `417c51c` | B1 | измерен в начале прогона | группы library,dna,online; unit, integration, exe | 43 |
| `20261025_162405` | 2026-10-25T16:24:05 | `0dcf12c` | B2 | измерен в начале прогона | все группы; unit, integration, exe | 17 |

## Итог

| | FAIL | BLOCKED | MANUAL REQUIRED | PASS | NOT RUN |
|---|---|---|---|---|---|
| Тесты FT (30) | 0 | 0 | 0 | 30 | 0 |
| Отдельные проверки (60) | 0 | 0 | 0 | 60 | 0 |

## FT-01 – FT-30: автоматические и ручные проверки

| FT | Сценарий | Статус | Автоматически | Прогон (сборка) | Вручную |
|---|---|---|---|---|---|
| FT-01 | Запуск Portable-сборки | **PASS** | SYS-portable-source: PASS<br>SYS-package: PASS<br>EX-01-start: PASS<br>EX-01-version: PASS | `20261025_200734 (B1)` | MAN-01: PASS |
| FT-02 | Импорт библиотеки MP3 / FLAC / WAV | **PASS** | AT-02-count: PASS<br>AT-02-tags: PASS<br>AT-02-wav-cyrillic: PASS<br>AT-02-durations: PASS<br>AT-02-cover: PASS<br>AT-02-files-unchanged: PASS<br>AT-02-rescan: PASS<br>EX-02-library: PASS | `20261025_200734 (B1)` | MAN-02: PASS |
| FT-03 | Сохранение после перезапуска | **PASS** | AT-03-restart: PASS<br>EX-03-restart: PASS | `20261025_200734 (B1)` |  |
| FT-04 | Пропавший файл и Rescan | **PASS** | AT-04-missing: PASS | `20261025_200734 (B1)` |  |
| FT-05 | Поиск, кириллица | **PASS** | AT-05-search: PASS<br>EX-05-search: PASS | `20261025_200734 (B1)` |  |
| FT-06 | 20–30 треков подряд | **PASS** | AT-06-order: PASS<br>AT-06-audio: PASS<br>AT-06-id3-flac: PASS | `20261025_162405 (B2)` |  |
| FT-07 | Пауза, перемотка, назад / вперёд | **PASS** | AT-07-transport: PASS<br>AT-07-pause-silence: PASS | `20261025_162405 (B2)` |  |
| FT-08 | Очередь | **PASS** | AT-08-queue: PASS | `20261025_162405 (B2)` |  |
| FT-09 | Shuffle и Repeat | **PASS** | AT-09-shuffle: PASS<br>AT-09-repeat: PASS | `20261025_162405 (B2)` |  |
| FT-10 | Громкость, Mute, устройство вывода | **PASS** | AT-10-volume: PASS<br>AT-10-devices: PASS | `20261025_162405 (B2)` | MAN-10: PASS |
| FT-11 | Crossfade 6 с | **PASS** | AT-11-crossfade-6: PASS | `20261025_162405 (B2)` |  |
| FT-12 | Crossfade 0 с и 12 с | **PASS** | AT-12-crossfade-0: PASS<br>AT-12-crossfade-12: PASS | `20261025_162405 (B2)` |  |
| FT-13 | Gapless внутри альбома | **PASS** | AT-13-album-gapless: PASS | `20261025_162405 (B2)` |  |
| FT-14 | Smart Mix | **PASS** | AT-14-smart-mix: PASS | `20261025_162405 (B2)` |  |
| FT-15 | Crossfade между форматами | **PASS** | AT-15-mp3-flac: PASS<br>AT-15-flac-wav: PASS | `20261025_162405 (B2)` |  |
| FT-16 | Медиаклавиши и медиапанель Windows | **PASS** | EX-16-session: PASS<br>EX-16-keys: PASS | `20261025_200734 (B1)` |  |
| FT-17 | Медиаклавиши рядом с другим плеером | **PASS** |  |  | MAN-17: PASS |
| FT-18 | Горячие клавиши | **PASS** | EX-18-keyboard: PASS | `20261025_200734 (B1)` |  |
| FT-19 | NEXA DNA | **PASS** | AT-19-dna: PASS | `20261025_200734 (B1)` |  |
| FT-20 | NEXA Wave | **PASS** | AT-20-wave: PASS | `20261025_200734 (B1)` |  |
| FT-21 | Дизлайк | **PASS** | AT-21-dislike: PASS | `20261025_200734 (B1)` |  |
| FT-22 | Знакомое ↔ Открытия | **PASS** | AT-22-discovery: PASS | `20261025_200734 (B1)` |  |
| FT-23 | Private session, Pause learning | **PASS** | AT-23-privacy: PASS | `20261025_200734 (B1)` |  |
| FT-24 | Удаление истории, сброс DNA | **PASS** | AT-24-reset: PASS | `20261025_200734 (B1)` |  |
| FT-25 | Поиск Audius / Jamendo | **PASS** | AT-25-audius: PASS<br>AT-25-jamendo: PASS | `20261025_200734 (B1)` |  |
| FT-26 | Воспроизведение Audius / Jamendo | **PASS** | AT-26-audius: PASS<br>AT-26-jamendo: PASS<br>AT-26-no-mix: PASS | `20261025_200734 (B1)` |  |
| FT-27 | Без интернета | **PASS** | AT-27-unreachable: PASS | `20261025_200734 (B1)` | MAN-27: PASS |
| FT-28 | Доступность (UI Automation, Диктор) | **PASS** | SYS-eventlog: PASS<br>EX-28-a11y: PASS<br>EX-flutter-errors: PASS | `20261025_200734 (B1)` | MAN-28: PASS |
| FT-29 | Изменение размера окна с клиентом доступности (TD-02) | **PASS** | EX-29-resize: PASS<br>EX-29-axtree-log: PASS | `20261025_200734 (B1)` | MAN-29: PASS |
| FT-30 | Минимальный и максимальный размер окна | **PASS** | EX-30-minsize: PASS | `20261025_200734 (B1)` | MAN-30: PASS |

## Технический долг TD-01 – TD-18

| TD | Проверяется в | Статус |
|---|---|---|
| TD-01 | FT-28 | PASS |
| TD-02 | FT-29 | PASS |
| TD-03 | FT-28 | PASS |
| TD-04 | FT-02 | PASS |
| TD-05 | FT-02 | PASS |
| TD-06 | FT-16, FT-17 | PASS |
| TD-07 | FT-06, FT-07, FT-08, FT-09, FT-10 | PASS |
| TD-08 | FT-14 | PASS |
| TD-09 | FT-11, FT-12, FT-13, FT-15 | PASS |
| TD-10 | FT-20, FT-22 | PASS |
| TD-11 | FT-20 | PASS |
| TD-12 | FT-19 | PASS |
| TD-13 | FT-25 | PASS |
| TD-14 | FT-26 | PASS |
| TD-15 | FT-26 | PASS |
| TD-16 | FT-16, FT-17 | PASS |
| TD-17 | FT-01 | PASS |
| TD-18 | FT-18 | PASS |

## Ошибки и блокировки

Нет.

## Ручные проверки — все подтверждены владельцем

Ручные подтверждения берутся из `tools/autotest/manual_results.json`; у каждого указаны дата и сборка, на которой владелец проверял.

Ответ: `MAN-xx OK` или `MAN-xx FAIL: что сделали → что ожидали → что увидели`. MAN-28 и MAN-29 удобно пройти вместе. Если второго устройства вывода нет, ответьте `MAN-10 нет устройства` — пункт останется непроверенным с этой причиной.

| ID | FT | Что сделать | Ожидаемый результат | Уже проверено автоматически | Мин. | Статус |
|---|---|---|---|---|---|---|
| MAN-01 | FT-01 | **Первый запуск Portable-сборки.** Подтверждено владельцем 2026-10-22. | - | Release-сборка, Portable-папка, запуск exe, версия 0.9.0. | 0 | PASS (2026-10-22) |
| MAN-02 | FT-02 | **Своя музыка через окно Windows «Add folder» (TD-05).** В обычной NEXA (не в тестовом профиле): Library → Add folder → своя папка, лучше 30+ треков разных форматов → дождаться строки «N added». Сверить 3–4 случайных трека с Проводником или другим плеером. | Число треков = число MP3 / FLAC / WAV в папке, без дубликатов; название, исполнитель, альбом и обложка совпадают; у файлов не изменилась дата изменения. (Известное ограничение: WAV-теги в кодировке Windows-1251 читаются неверно, TD-04.) | Импорт 36 сгенерированных файлов MP3 / FLAC / WAV: число, теги (кириллица), длительности, обложка, файлы не меняются, повторный Rescan без дубликатов. | 5 | PASS (2026-10-25, сборка 0.9.0, commit 13c260b, app code 83346d1e171c) |
| MAN-10 | FT-10 | **Переключение на другое устройство вывода.** Только если есть второй выход (наушники, HDMI, USB). Во время игры Settings → Output device → другое устройство; перезапустить NEXA; затем вернуть System default. | Звук переходит на выбранное устройство примерно за секунду; после перезапуска выбор сохранён; System default возвращает звук на основное устройство. | Громкость 100 % / 50 % и Mute измерены по записи звука; список устройств; выбор System default. | 3 | PASS (2026-10-25, сборка 0.9.0, commit 13c260b, app code 83346d1e171c) |
| MAN-17 | FT-17 | **Медиаклавиши рядом с браузером.** NEXA играет → пауза в NEXA. В браузере включить видео (например YouTube). Нажать клавишу Play/Pause на клавиатуре два раза. Затем запустить песню в NEXA и нажать Play/Pause ещё раз. | Пока играет браузер, клавиша ставит на паузу и продолжает видео, NEXA остаётся на паузе; после запуска NEXA клавиша управляет NEXA. Браузер свои клавиши не теряет. | NEXA появляется в медиапанели Windows; Play/Pause, Next, Previous, Stop работают при свёрнутом окне (EX-16). | 2 | PASS (2026-10-25, сборка 0.9.0, commit 13c260b, app code 83346d1e171c) |
| MAN-27 | FT-27 | **Отключённый интернет.** Отключить Wi-Fi или кабель → Discover → поиск «jazz» → Library → запустить свою песню → включить сеть → снова поиск. | Без сети — понятное сообщение «Cannot reach the catalog…», NEXA не зависает и не закрывается, своя музыка играет; с сетью поиск снова даёт результаты. | Недоступный адрес каталога даёт сообщение «offline», локальная песня играет (сеть компьютера при этом включена). | 3 | PASS (2026-10-25, сборка 0.9.0, commit 13c260b, app code 83346d1e171c) |
| MAN-28 | FT-28 | **Экранный диктор (TD-01, TD-03).** Win+Ctrl+Enter (Диктор). Tab по Home, Now Playing, Wave, Discover, Settings. Навести мышь на Play/Pause, нажать кнопку очереди, Settings → Open audio engine test → Back. Выключить Диктор (Win+Ctrl+Enter). | Диктор называет кнопки и поля понятными словами (не просто «кнопка»); NEXA не закрывается. | С подключённым клиентом доступности (MSAA / UI Automation) открыты все страницы, наведение на Play/Pause, кнопка очереди, Audio test и назад — без сбоя; 0 сбоев в журнале Windows. | 5 | PASS (2026-10-25, сборка 0.9.0, commit 13c260b, app code 83346d1e171c) |
| MAN-29 | FT-29 | **Диктор после изменения размера окна (TD-02).** Сразу после MAN-28, Диктор включён: развернуть окно на весь экран, вернуть, сузить до упора, затем Tab по 2–3 элементам. | Окно не закрывается; Диктор читает новые элементы, а не молчит и не повторяет старые. | Ресайз и разворачивание с клиентом доступности без сбоя; 0 сообщений «Failed to update ui::AXTree»; дерево доступности следует за переходами. | 2 | PASS (2026-10-25, сборка 0.9.0, commit 13c260b, app code 83346d1e171c) |
| MAN-30 | FT-30 | **Внешний вид на минимальном и полном окне.** Открыть скриншоты 05–12 в папке запуска (`<root>\_autotest_runs\<прогон exe-этапа>\screenshots`) или проверить в NEXA: окно сжать до упора и развернуть на весь экран — Home, Now Playing, Wave, Discover, Settings. | Ничего не обрезано и не перекрыто; правая панель и боковое меню перестраиваются. | Окно не становится меньше 1024 × 640; все страницы открываются на минимальном и развёрнутом окне без сбоя; сделаны скриншоты. | 3 | PASS (2026-10-25, сборка 0.9.0, commit 13c260b, app code 83346d1e171c) |

## Все проверки

| ID | FT | Проверка | Уровень | Статус | Прогон | Сборка | Подробности |
|---|---|---|---|---|---|---|---|
| SYS-library | - | Test library present and unchanged (SHA-256) | Windows system | PASS | `20261025_200734` | B1 | 36 tracks |
| SYS-loopback | - | WASAPI loopback recorder built | Windows system | PASS | `20261025_200734` | B1 | exit 0 |
| SYS-audio | - | Sound can be measured: output device present, not muted, volume above 0 %, loopback capture available | Windows system | PASS | `20261025_200734` | B1 | device 'Speakers (Logitech PRO X Gaming Headset)', mute off, volume 52 %, process loopback ok, system loopback ok |
| SYS-portable-source | FT-01 | The tested Portable folder was built from the same app code as this run | Windows system | PASS | `20261025_200734` | B1 | folder NEXA_Music_1.0.0_Windows_x64_417c51c; built from commit 417c51ccd21e65690e9110703cfe765fe62b8e9f, app code 30c68c1299b5; this run: app code 30c68c1299b5 |
| SYS-package | FT-01 | Portable folder with every required file (NEXA_Music_1.0.0_Windows_x64_417c51c) | Windows system | PASS | `20261025_200734` | B1 | 49.1 MB |
| SYS-eventlog | FT-28 | Windows Event Log: no crash of nexa_music.exe during the whole run | Windows system | PASS | `20261025_200734` | B1 | 0 crash records |
| UNIT-analyze | - | flutter analyze | static analysis | PASS | `20261025_200734` | B1 | exit 0 |
| UNIT-tests | - | Existing unit / widget tests (FakeEngine, in-memory database) | unit / widget tests | PASS | `20261025_200734` | B1 | exit 0; +175: All tests passed! |
| AT-02-count | FT-02 | Import: every test file is in the library once | integration (real media_kit, SQLite, files; debug build) | PASS | `20261025_200734` | B1 | library 36 / expected 36; problems: [] |
| AT-02-tags | FT-02 | Import: titles, artists, albums incl. Cyrillic MP3 / FLAC | integration (real media_kit, SQLite, files; debug build) | PASS | `20261025_200734` | B1 | all tags as written |
| AT-02-wav-cyrillic | FT-02 | Import: Cyrillic RIFF INFO tags in WAV (known issue TD-04) | integration (real media_kit, SQLite, files; debug build) | PASS | `20261025_200734` | B1 | read correctly |
| AT-02-durations | FT-02 | Import: durations within 0.3 s of the generated length | integration (real media_kit, SQLite, files; debug build) | PASS | `20261025_200734` | B1 | largest deviation 0.071 s |
| AT-02-cover | FT-02 | Import: folder cover.jpg used as artwork | integration (real media_kit, SQLite, files; debug build) | PASS | `20261025_200734` | B1 | 4 of 4 tracks in meta/ have a cover |
| AT-02-files-unchanged | FT-02 | Import never changes, moves or adds music files | integration (real media_kit, SQLite, files; debug build) | PASS | `20261025_200734` | B1 | 38 files compared by SHA-256 |
| AT-02-rescan | FT-02 | Rescan adds no duplicates | integration (real media_kit, SQLite, files; debug build) | PASS | `20261025_200734` | B1 | 36 tracks after rescan |
| AT-03-restart | FT-03 | After a restart: library, playlist, likes, Mix mode and volume restored | integration (real media_kit, SQLite, files; debug build) | PASS | `20261025_200734` | B1 | tracks 36, playlist 3 songs, favorites 2, mode gapless, volume 0.6 |
| AT-04-missing | FT-04 | Renamed file: unavailable with a reason, available again after renaming back | integration (real media_kit, SQLite, files; debug build) | PASS | `20261025_200734` | B1 | while renamed: unavailable "File not found"; after: available; available tracks 36 (the renamed copy stays listed as missing by design) |
| AT-05-search | FT-05 | Search: words, letter case and Cyrillic | integration (real media_kit, SQLite, files; debug build) | PASS | `20261025_200734` | B1 | "seq 0" 11 (11), "тестовая" 1 (>=1), "ТЕСТОВЫЙ" 2 (>=2), "live band" 3 (3) |
| AT-19-dna | FT-19 | NEXA DNA offers the library genres / artists and stores liked / excluded choices | integration (real media_kit, SQLite, files; debug build) | PASS | `20261025_200734` | B1 | genres Electronic, Rock, Поп, Ambient, Jazz; 2 choices stored |
| AT-20-wave | FT-20 | Wave: liked artist among the first picks, reasons shown, excluded genre never, refills itself, skips recorded | integration (real media_kit, SQLite, files; debug build) | PASS | `20261025_200734` | B1 | queue 8 (liked first true, excluded genre 0, reasons 8), refilled true to 16, history 0->3 |
| AT-21-dislike | FT-21 | Dislike skips the playing Wave song and excludes it | integration (real media_kit, SQLite, files; debug build) | PASS | `20261025_200734` | B1 | skipped true, suggested again false |
| AT-22-discovery | FT-22 | Familiar picks played songs first; Discovery picks unplayed songs first | integration (real media_kit, SQLite, files; debug build) | PASS | `20261025_200734` | B1 | familiar: 3 of top 4 known; discovery: 4 of top 4 new (4 known songs by different artists) |
| AT-23-privacy | FT-23 | Private session and Pause learning add nothing to the history; normal listening does | integration (real media_kit, SQLite, files; debug build) | PASS | `20261025_200734` | B1 | added: private 0, paused 0, normal 2 |
| AT-24-reset | FT-24 | Delete history and Reset DNA; likes and playlists stay; private session ends with the app | integration (real media_kit, SQLite, files; debug build) | PASS | `20261025_200734` | B1 | private after restart false, events 0, choices 0, dislikes 0, favorites 2->2, playlists 1, discovery 0.3 |
| AT-25-audius | FT-25 | Audius: search returns results with source and playability | integration (real media_kit, SQLite, files; debug build) | PASS | `20261025_200734` | B1 | "lofi": 10 results, 9 playable |
| AT-25-jamendo | FT-25 | Jamendo: search returns results with source and playability | integration (real media_kit, SQLite, files; debug build) | PASS | `20261025_200734` | B1 | "chill": 10 results, 10 playable, licence CC BY 3.0 |
| AT-26-audius | FT-26 | Audius: stream plays through the real engine and is audible (loopback) | integration (real media_kit, SQLite, files; debug build) | PASS | `20261025_200734` | B1 | position > 3 s: true; output RMS 0.0750 |
| AT-26-jamendo | FT-26 | Jamendo: stream plays through the real engine and is audible (loopback) | integration (real media_kit, SQLite, files; debug build) | PASS | `20261025_200734` | B1 | position > 3 s: true; output RMS 0.1166 |
| AT-26-no-mix | FT-26 | Catalog tracks are never crossfaded; not written to the history | integration (real media_kit, SQLite, files; debug build) | PASS | `20261025_200734` | B1 | plan cut "Source does not allow mixing"; history 0->0 |
| AT-27-unreachable | FT-27 | Unreachable catalog gives the "offline" message; the local library still plays | integration (real media_kit, SQLite, files; debug build) | PASS | `20261025_200734` | B1 | error kind offline; local playback true (simulated with an unreachable address, real network still on) |
| EX-01-start | FT-01 | Portable exe starts with an isolated test profile; its accessibility tree is visible | Windows Release exe (Portable build, UI Automation) | PASS | `20261025_200734` | B1 | window 'NEXA Music', 114 named elements via MSAA; exe_app.log start: MSAA nodes 166, UI Automation elements 1 |
| EX-01-version | FT-01 | Settings - About shows version 1.0.0 (pubspec.yaml) | Windows Release exe (Portable build, UI Automation) | PASS | `20261025_200734` | B1 | NEXA Music - personal Windows music player. Local library, playback, NEXA Mix Engine, NEXA DNA, NEXA Wave, Audius and Jamendo. Version 1.0.0 |
| EX-02-library | FT-02 | Release exe shows the imported test library from its database | Windows Release exe (Portable build, UI Automation) | PASS | `20261025_200734` | B1 | 'Seq 01' visible in Library - Songs |
| EX-16-session | FT-16 | Windows media overlay shows NEXA with song, artist and Playing | Windows Release exe (Portable build, UI Automation) | PASS | `20261025_200734` | B1 | 'Seq 01' / 'AutoTest Band' Playing (current session) |
| EX-16-keys | FT-16 | Media keys with NEXA minimised: Play/Pause, Next, Previous, Stop | Windows Release exe (Portable build, UI Automation) | PASS | `20261025_200734` | B1 | play/pause -> Paused -> Playing; next -> 'Seq 04'; previous -> 'Seq 01'; stop -> Paused |
| EX-18-keyboard | FT-18 | Space toggles playback, Ctrl+Right plays the next song (Release exe) | Windows Release exe (Portable build, UI Automation) | PASS | `20261025_200734` | B1 | space: Paused -> Playing -> Paused; ctrl+right: 'Seq 01' -> 'Seq 04' |
| EX-28-a11y | FT-28 | With a UI Automation client attached: all pages, Now Playing, Play/Pause hover, queue button, audio test and back - no crash | Windows Release exe (Portable build, UI Automation) | PASS | `20261025_200734` | B1 | pages Home:ok, Wave:ok, Discover:ok, Library:ok, Settings:ok; now playing True; hover tooltip True; queue True/True; audio test True, back True, returned True; alive True |
| EX-29-resize | FT-29 | Resize / maximise with a UI Automation client: no crash, tree still updates | Windows Release exe (Portable build, UI Automation) | PASS | `20261025_200734` | B1 | sizes min 1024x640, max 1936x1048; tree follows navigation after resizing True; alive True |
| EX-30-minsize | FT-30 | Window cannot be made smaller than 1024 x 640 | Windows Release exe (Portable build, UI Automation) | PASS | `20261025_200734` | B1 | smallest window 1024x640 (dpi 96) |
| EX-05-search | FT-05 | Release exe: the search field finds the Cyrillic song (typed in Cyrillic) | Windows Release exe (Portable build, UI Automation) | PASS | `20261025_200734` | B1 | search 'тестовая': found '1 / Play Тестовая песня / Тестовая песня / Тестовый исполнитель / Тестовый альбом / 0:08' |
| EX-03-restart | FT-03 | Release exe restarted: library (and playlist, if the profile has one) still there | Windows Release exe (Portable build, UI Automation) | PASS | `20261025_200734` | B1 | restarted True, test song visible True, playlist before / after restart True / True |
| EX-29-axtree-log | FT-29 | No "Failed to update ui::AXTree" messages after resizing (TD-02) | Windows Release exe (Portable build, UI Automation) | PASS | `20261025_200734` | B1 | 0 messages in the app output |
| EX-flutter-errors | FT-28 | No Flutter exceptions in the Release exe output | Windows Release exe (Portable build, UI Automation) | PASS | `20261025_200734` | B1 | 0 error blocks |
| AT-06-order | FT-06 | 24 tracks in a row: each started once, in order (engine) | integration (real media_kit, SQLite, files; debug build) | PASS | `20261025_162405` | B2 | 24 tracks started; engine errors: none |
| AT-06-audio | FT-06 | 24 tracks in a row: audible order, full length, never two at once, no gaps (loopback) | integration (real media_kit, SQLite, files; debug build) | PASS | `20261025_162405` | B2 | heard 24 of 24 tones in the right order; largest overlap 0.020 s, largest gap 0.000 s, shortest song heard 5.96 s of 6.00 s |
| AT-06-id3-flac | FT-06 | Gapless: MP3 -> FLAC with ID3 tag in front -> WAV, all audible | integration (real media_kit, SQLite, files; debug build) | PASS | `20261025_162405` | B2 | heard 520 Hz -> 2800 Hz -> 740 Hz (expected 520 Hz -> 2800 Hz -> 740 Hz) |
| AT-07-transport | FT-07 | Pause holds the position, resume, seek, previous (restart / previous track), next | integration (real media_kit, SQLite, files; debug build) | PASS | `20261025_162405` | B2 | pause 1000->1000 ms, resume -> 2260 ms, seek 20 s -> 20439 ms, restart true, next true, previous true |
| AT-07-pause-silence | FT-07 | Silence while paused (loopback, tone of the paused song) | integration (real media_kit, SQLite, files; debug build) | PASS | `20261025_162405` | B2 | 440 Hz level while paused 0.00000 (playing at 100 %: about 0.12); other sound on the PC: peak 0.0000 |
| AT-08-queue | FT-08 | Play next, Add to queue, Remove, Clear; the engine plays the inserted song | integration (real media_kit, SQLite, files; debug build) | PASS | `20261025_162405` | B2 | play next/add true, remove true, engine played inserted true, clear true |
| AT-09-shuffle | FT-09 | Shuffle plays each song once; switching it off restores the order | integration (real media_kit, SQLite, files; debug build) | PASS | `20261025_162405` | B2 | 10 different files played; order restored true |
| AT-09-repeat | FT-09 | Repeat this song replays it; Repeat all wraps to the first song | integration (real media_kit, SQLite, files; debug build) | PASS | `20261025_162405` | B2 | repeat one true, repeat all wrap true |
| AT-10-volume | FT-10 | Volume and mute change the real output level (loopback) | integration (real media_kit, SQLite, files; debug build) | PASS | `20261025_162405` | B2 | 440 Hz level at 100 %: 0.1059, 50 %: 0.0132, mute: 0.00000; recorder mode=process rate=48000 channels=2 float=1 bits=32 device="Speakers (Logitech PRO X Gaming Headset)" endpoint_mute=0 endpoint_volume=0.520 session=1 session_mute=0 session_volume=1.000 |
| AT-10-devices | FT-10 | Output devices are listed; "System default" can be selected | integration (real media_kit, SQLite, files; debug build) | PASS | `20261025_162405` | B2 | 5 devices reported by the engine |
| AT-11-crossfade-6 | FT-11 | Crossfade 6 s (WAV -> FLAC): smooth overlap, no dip, no clipping | integration (real media_kit, SQLite, files; debug build) | PASS | `20261025_162405` | B2 | planned crossfade 6.0 s ("Crossfade"); measured overlap 5.74 s, gap 0.000 s, peak 0.143, level during overlap 0.96-1.03 x; player moved on: true |
| AT-12-crossfade-0 | FT-12 | Crossfade 0 s: no overlap, no gap | integration (real media_kit, SQLite, files; debug build) | PASS | `20261025_162405` | B2 | planned gapless 0.0 s ("Crossfade off: no overlap"); measured overlap 0.02 s, gap 0.000 s, peak 0.106, level during overlap 1.00-1.00 x; player moved on: true |
| AT-12-crossfade-12 | FT-12 | Crossfade 12 s: long smooth overlap | integration (real media_kit, SQLite, files; debug build) | PASS | `20261025_162405` | B2 | planned crossfade 12.0 s ("Crossfade"); measured overlap 11.52 s, gap 0.000 s, peak 0.149, level during overlap 0.96-1.03 x; player moved on: true |
| AT-13-album-gapless | FT-13 | Same album with Crossfade on: gapless, no overlap (FLAC) | integration (real media_kit, SQLite, files; debug build) | PASS | `20261025_162405` | B2 | planned gapless 0.0 s ("Same album: gapless"); measured overlap 0.02 s, gap 0.000 s, peak 0.106, level during overlap 1.00-1.00 x; player moved on: true |
| AT-14-smart-mix | FT-14 | Smart Mix shortens the overlap for short tracks and says why | integration (real media_kit, SQLite, files; debug build) | PASS | `20261025_162405` | B2 | planned crossfade 3.0 s ("Smart Mix: shorter for a short track"); measured overlap 2.78 s, gap 0.000 s, peak 0.139, level during overlap 0.99-1.01 x; player moved on: true |
| AT-15-mp3-flac | FT-15 | Crossfade 6 s MP3 -> FLAC | integration (real media_kit, SQLite, files; debug build) | PASS | `20261025_162405` | B2 | planned crossfade 6.0 s ("Crossfade"); measured overlap 5.66 s, gap 0.000 s, peak 0.143, level during overlap 0.98-1.07 x; player moved on: true |
| AT-15-flac-wav | FT-15 | Crossfade 6 s FLAC -> WAV | integration (real media_kit, SQLite, files; debug build) | PASS | `20261025_162405` | B2 | planned crossfade 6.0 s ("Crossfade"); measured overlap 5.68 s, gap 0.000 s, peak 0.142, level during overlap 0.99-1.01 x; player moved on: true |

## Артефакты прогонов (вне репозитория)

`<root>\_autotest_runs\<прогон>\`: `autotest.log`, `unit.log`, `integration.log`, `it\integration.json`, `it\recordings\*.wav` (записи звука NEXA), `exe.json`, `exe_app.log`, `screenshots\*.png`, `crash_records.txt` (если были сбои), `results.json`. Результаты каждого прогона отдельно: `reports/autotest/runs/<прогон>.json`.
