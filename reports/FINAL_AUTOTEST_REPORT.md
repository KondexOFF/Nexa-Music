# NEXA Music — FINAL AUTOTEST REPORT

Последний прогон: `20261123_210045` (2026-11-23T21:00:45 … 2026-11-23T21:02:15)  
Версия приложения: 1.0.0+8; код приложения (lib, windows, assets, pubspec) `8314e95744fe` — измерен в начале прогона  
Среда: Microsoft Windows 11 Pro; Flutter 3.47.7 • channel stable • https://github.com/flutter/flutter.git  
Запуск: `NEXA_AutoTest.cmd` (папки прогонов `<root>\_autotest_runs\<прогон>`)

Статусы: PASS — ожидаемый результат проверен; FAIL — проверено, результат неверный; BLOCKED — проверку не удалось выполнить (причина указана, например выключенный звук Windows); MANUAL REQUIRED — нужна короткая ручная проверка; NOT RUN — не запускалась.

Уровень каждой автоматической проверки указан отдельно: unit / widget-тесты (FakeEngine) не считаются подтверждением работы Windows-exe; интеграционные тесты используют настоящий media_kit, SQLite, файлы и HTTP (debug-сборка); этап «Release exe» управляет настоящей Portable-сборкой через MSAA / UI Automation. Звук измеряется записью WASAPI process loopback (только звук NEXA); перед записью проверяются устройство, Mute и громкость Windows, и во время каждой записи — Mute и громкость устройства и NEXA в микшере громкости.

## Источники результатов

Для каждой группы проверок взят самый новый прогон, где она выполнялась. У каждого результата указаны прогон и **сборка** — код приложения (lib, windows, assets, pubspec), на котором он получен. **Внимание: результаты получены на 2 сборках** (см. таблицу сборок); 8 прогонов с неизвестным кодом приложения (до 2026-10-25) не использованы.

| Сборка | Код приложения | Что это |
|---|---|---|
| B1 | `8314e95744fe` | код коммита cb2e415 (код последнего прогона) |
| B2 | `0d8ac55eb9d2` | код коммита b47f334 |

| Прогон | Начало | Коммит | Сборка | Код приложения установлен | Группы / этапы | Проверок взято |
|---|---|---|---|---|---|---|
| `20261123_210045` | 2026-11-23T21:00:45 | `cb2e415` | B1 | измерен в начале прогона | все группы; unit, integration | 21 |
| `20261026_181556` | 2026-10-26T18:15:56 | `b47f334` | B2 | измерен в начале прогона | все группы; unit, integration, exe | 15 |

## Итог

| | FAIL | BLOCKED | MANUAL REQUIRED | PASS | NOT RUN |
|---|---|---|---|---|---|
| Тесты FT (30) | 0 | 0 | 0 | 13 | 17 |
| Отдельные проверки (36) | 0 | 5 | 0 | 31 | 0 |

## FT-01 – FT-30: автоматические и ручные проверки

| FT | Сценарий | Статус | Автоматически | Прогон (сборка) | Вручную |
|---|---|---|---|---|---|
| FT-01 | Запуск Portable-сборки | **PASS** | SYS-portable-source: PASS<br>SYS-package: PASS<br>EX-01-start: PASS<br>EX-01-version: PASS | `20261026_181556 (B2)` | MAN-01: PASS |
| FT-02 | Импорт библиотеки MP3 / FLAC / WAV | **PASS** | AT-02-count: PASS<br>AT-02-tags: PASS<br>AT-02-wav-cyrillic: PASS<br>AT-02-durations: PASS<br>AT-02-cover: PASS<br>AT-02-files-unchanged: PASS<br>AT-02-rescan: PASS<br>EX-02-library: PASS | `20261026_181556 (B2)`<br>`20261123_210045 (B1)` | MAN-02: PASS |
| FT-03 | Сохранение после перезапуска | **PASS** | AT-03-restart: PASS<br>EX-03-restart: PASS | `20261026_181556 (B2)`<br>`20261123_210045 (B1)` |  |
| FT-04 | Пропавший файл и Rescan | **PASS** | AT-04-missing: PASS | `20261123_210045 (B1)` |  |
| FT-05 | Поиск, кириллица | **PASS** | AT-05-search: PASS<br>EX-05-search: PASS | `20261026_181556 (B2)`<br>`20261123_210045 (B1)` |  |
| FT-06 | 20–30 треков подряд | **NOT RUN** |  |  |  |
| FT-07 | Пауза, перемотка, назад / вперёд | **NOT RUN** |  |  |  |
| FT-08 | Очередь | **NOT RUN** |  |  |  |
| FT-09 | Shuffle и Repeat | **NOT RUN** |  |  |  |
| FT-10 | Громкость, Mute, устройство вывода | **PASS** |  |  | MAN-10: PASS |
| FT-11 | Crossfade 6 с | **NOT RUN** |  |  |  |
| FT-12 | Crossfade 0 с и 12 с | **NOT RUN** |  |  |  |
| FT-13 | Gapless внутри альбома | **NOT RUN** |  |  |  |
| FT-14 | Smart Mix | **NOT RUN** |  |  |  |
| FT-15 | Crossfade между форматами | **NOT RUN** |  |  |  |
| FT-16 | Медиаклавиши и медиапанель Windows | **PASS** | EX-16-session: PASS<br>EX-16-keys: PASS | `20261026_181556 (B2)` |  |
| FT-17 | Медиаклавиши рядом с другим плеером | **PASS** |  |  | MAN-17: PASS |
| FT-18 | Горячие клавиши | **PASS** | EX-18-keyboard: PASS | `20261026_181556 (B2)` |  |
| FT-19 | NEXA DNA | **NOT RUN** |  |  |  |
| FT-20 | NEXA Wave | **NOT RUN** |  |  |  |
| FT-21 | Дизлайк | **NOT RUN** |  |  |  |
| FT-22 | Знакомое ↔ Открытия | **NOT RUN** |  |  |  |
| FT-23 | Private session, Pause learning | **NOT RUN** |  |  |  |
| FT-24 | Удаление истории, сброс DNA | **NOT RUN** |  |  |  |
| FT-25 | Поиск Audius / Jamendo | **NOT RUN** |  |  |  |
| FT-26 | Воспроизведение Audius / Jamendo | **NOT RUN** |  |  |  |
| FT-27 | Без интернета | **PASS** |  |  | MAN-27: PASS |
| FT-28 | Доступность (UI Automation, Диктор) | **PASS** | SYS-eventlog: PASS<br>EX-28-a11y: PASS<br>EX-flutter-errors: PASS | `20261026_181556 (B2)`<br>`20261123_210045 (B1)` | MAN-28: PASS |
| FT-29 | Изменение размера окна с клиентом доступности (TD-02) | **PASS** | EX-29-resize: PASS<br>EX-29-axtree-log: PASS | `20261026_181556 (B2)` | MAN-29: PASS |
| FT-30 | Минимальный и максимальный размер окна | **PASS** | EX-30-minsize: PASS | `20261026_181556 (B2)` | MAN-30: PASS |

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
| TD-08 | FT-14 | NOT RUN |
| TD-09 | FT-11, FT-12, FT-13, FT-15 | NOT RUN |
| TD-10 | FT-20, FT-22 | NOT RUN |
| TD-11 | FT-20 | NOT RUN |
| TD-12 | FT-19 | NOT RUN |
| TD-13 | FT-25 | NOT RUN |
| TD-14 | FT-26 | NOT RUN |
| TD-15 | FT-26 | NOT RUN |
| TD-16 | FT-16, FT-17 | PASS |
| TD-17 | FT-01 | PASS |
| TD-18 | FT-18 | PASS |

## Ошибки и блокировки

- **BLOCKED AT-playback-output** (-, прогон `20261123_210045`, B1) Group "playback" not run — silent output device: the audio engine does not offer the silent output device (System default, Speakers (Logitech PRO X Gaming Headset), Digital Output (High Definition Audio Device), 24G4 (NVIDIA High Definition Audio), Default (openal))
- **BLOCKED AT-mix-output** (-, прогон `20261123_210045`, B1) Group "mix" not run — silent output device: the audio engine does not offer the silent output device (System default, Speakers (Logitech PRO X Gaming Headset), Digital Output (High Definition Audio Device), 24G4 (NVIDIA High Definition Audio), Default (openal))
- **BLOCKED AT-dna-output** (-, прогон `20261123_210045`, B1) Group "dna" not run — silent output device: the audio engine does not offer the silent output device (System default, Speakers (Logitech PRO X Gaming Headset), Digital Output (High Definition Audio Device), 24G4 (NVIDIA High Definition Audio), Default (openal))
- **BLOCKED AT-online-output** (-, прогон `20261123_210045`, B1) Group "online" not run — silent output device: the audio engine does not offer the silent output device (System default, Speakers (Logitech PRO X Gaming Headset), Digital Output (High Definition Audio Device), 24G4 (NVIDIA High Definition Audio), Default (openal))
- **BLOCKED AT-output** (-, прогон `20261123_210045`, B1) Test tones played on the silent output device (not on the speakers / headset) — the audio engine does not offer the silent output device (System default, Speakers (Logitech PRO X Gaming Headset), Digital Output (High Definition Audio Device), 24G4 (NVIDIA High Definition Audio), Default (openal))

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
| SYS-library | - | Test library present and unchanged (SHA-256) | Windows system | PASS | `20261123_210045` | B1 | 36 tracks |
| SYS-loopback | - | WASAPI loopback recorder built | Windows system | PASS | `20261123_210045` | B1 | exit 0 |
| SYS-audio | - | Sound can be measured: output device present, not muted, volume above 0 %, loopback capture available | Windows system | PASS | `20261123_210045` | B1 | device 'Digital Output (High Definition Audio Device)', mute off, volume 100 %, process loopback ok, system loopback ok |
| SYS-eventlog | FT-28 | Windows Event Log: no crash of nexa_music.exe during the whole run | Windows system | PASS | `20261123_210045` | B1 | 0 crash records |
| UNIT-analyze | - | flutter analyze | static analysis | PASS | `20261123_210045` | B1 | exit 0 |
| UNIT-tests | - | Existing unit / widget tests (FakeEngine, in-memory database) | unit / widget tests | PASS | `20261123_210045` | B1 | exit 0; +261: All tests passed! |
| AT-02-count | FT-02 | Import: every test file is in the library once | integration (real media_kit, SQLite, files; debug build) | PASS | `20261123_210045` | B1 | library 36 / expected 36; problems: [] |
| AT-02-tags | FT-02 | Import: titles, artists, albums incl. Cyrillic MP3 / FLAC | integration (real media_kit, SQLite, files; debug build) | PASS | `20261123_210045` | B1 | all tags as written |
| AT-02-wav-cyrillic | FT-02 | Import: Cyrillic RIFF INFO tags in WAV (known issue TD-04) | integration (real media_kit, SQLite, files; debug build) | PASS | `20261123_210045` | B1 | read correctly |
| AT-02-durations | FT-02 | Import: durations within 0.3 s of the generated length | integration (real media_kit, SQLite, files; debug build) | PASS | `20261123_210045` | B1 | largest deviation 0.071 s |
| AT-02-cover | FT-02 | Import: folder cover.jpg used as artwork | integration (real media_kit, SQLite, files; debug build) | PASS | `20261123_210045` | B1 | 4 of 4 tracks in meta/ have a cover |
| AT-02-files-unchanged | FT-02 | Import never changes, moves or adds music files | integration (real media_kit, SQLite, files; debug build) | PASS | `20261123_210045` | B1 | 38 files compared by SHA-256 |
| AT-02-rescan | FT-02 | Rescan adds no duplicates | integration (real media_kit, SQLite, files; debug build) | PASS | `20261123_210045` | B1 | 36 tracks after rescan |
| AT-03-restart | FT-03 | After a restart: library, playlist, likes, Mix mode and volume restored | integration (real media_kit, SQLite, files; debug build) | PASS | `20261123_210045` | B1 | tracks 36, playlist 3 songs, favorites 2, mode gapless, volume 0.6 |
| AT-04-missing | FT-04 | Renamed file: unavailable with a reason, available again after renaming back | integration (real media_kit, SQLite, files; debug build) | PASS | `20261123_210045` | B1 | while renamed: unavailable "File not found"; after: available; available tracks 36 (the renamed copy stays listed as missing by design) |
| AT-05-search | FT-05 | Search: words, letter case and Cyrillic | integration (real media_kit, SQLite, files; debug build) | PASS | `20261123_210045` | B1 | "seq 0" 11 (11), "тестовая" 1 (>=1), "ТЕСТОВЫЙ" 2 (>=2), "live band" 3 (3) |
| AT-playback-output | - | Group "playback" not run | integration (real media_kit, SQLite, files; debug build) | BLOCKED | `20261123_210045` | B1 | silent output device: the audio engine does not offer the silent output device (System default, Speakers (Logitech PRO X Gaming Headset), Digital Output (High Definition Audio Device), 24G4 (NVIDIA High Definition Audio), Default (openal)) |
| AT-mix-output | - | Group "mix" not run | integration (real media_kit, SQLite, files; debug build) | BLOCKED | `20261123_210045` | B1 | silent output device: the audio engine does not offer the silent output device (System default, Speakers (Logitech PRO X Gaming Headset), Digital Output (High Definition Audio Device), 24G4 (NVIDIA High Definition Audio), Default (openal)) |
| AT-dna-output | - | Group "dna" not run | integration (real media_kit, SQLite, files; debug build) | BLOCKED | `20261123_210045` | B1 | silent output device: the audio engine does not offer the silent output device (System default, Speakers (Logitech PRO X Gaming Headset), Digital Output (High Definition Audio Device), 24G4 (NVIDIA High Definition Audio), Default (openal)) |
| AT-online-output | - | Group "online" not run | integration (real media_kit, SQLite, files; debug build) | BLOCKED | `20261123_210045` | B1 | silent output device: the audio engine does not offer the silent output device (System default, Speakers (Logitech PRO X Gaming Headset), Digital Output (High Definition Audio Device), 24G4 (NVIDIA High Definition Audio), Default (openal)) |
| AT-output | - | Test tones played on the silent output device (not on the speakers / headset) | integration (real media_kit, SQLite, files; debug build) | BLOCKED | `20261123_210045` | B1 | the audio engine does not offer the silent output device (System default, Speakers (Logitech PRO X Gaming Headset), Digital Output (High Definition Audio Device), 24G4 (NVIDIA High Definition Audio), Default (openal)) |
| SYS-portable-source | FT-01 | The tested Portable folder was built from the same app code as this run | Windows system | PASS | `20261026_181556` | B2 | folder NEXA_Music_1.0.0_Windows_x64_b47f334_2; built from commit b47f334357aa3167d2362e58456a048964e2d21a, app code 0d8ac55eb9d2; this run: app code 0d8ac55eb9d2 |
| SYS-package | FT-01 | Portable folder with every required file (NEXA_Music_1.0.0_Windows_x64_b47f334_2) | Windows system | PASS | `20261026_181556` | B2 | 49.9 MB |
| EX-01-start | FT-01 | Portable exe starts with an isolated test profile; its accessibility tree is visible | Windows Release exe (Portable build, UI Automation) | PASS | `20261026_181556` | B2 | window 'NEXA Music', 114 named elements via MSAA; exe_app.log start: MSAA nodes 166, UI Automation elements 1 |
| EX-01-version | FT-01 | Settings - About shows version 1.0.0 (pubspec.yaml) | Windows Release exe (Portable build, UI Automation) | PASS | `20261026_181556` | B2 | NEXA Music - personal Windows music player. Local library, playback, NEXA Mix Engine, NEXA DNA, NEXA Wave, Audius and Jamendo. Version 1.0.0 |
| EX-02-library | FT-02 | Release exe shows the imported test library from its database | Windows Release exe (Portable build, UI Automation) | PASS | `20261026_181556` | B2 | 'Seq 01' visible in Library - Songs |
| EX-16-session | FT-16 | Windows media overlay shows NEXA with song, artist and Playing | Windows Release exe (Portable build, UI Automation) | PASS | `20261026_181556` | B2 | 'Seq 01' / 'AutoTest Band' Playing (current session) |
| EX-16-keys | FT-16 | Media keys with NEXA minimised: Play/Pause, Next, Previous, Stop | Windows Release exe (Portable build, UI Automation) | PASS | `20261026_181556` | B2 | play/pause -> Paused -> Playing; next -> 'Seq 04'; previous -> 'Seq 01'; stop -> Paused |
| EX-18-keyboard | FT-18 | Space toggles playback, Ctrl+Right plays the next song (Release exe) | Windows Release exe (Portable build, UI Automation) | PASS | `20261026_181556` | B2 | space: Paused -> Playing -> Paused; ctrl+right: 'Seq 01' -> 'Seq 04' |
| EX-28-a11y | FT-28 | With a UI Automation client attached: all pages, Now Playing, Play/Pause hover, queue button, audio test and back - no crash | Windows Release exe (Portable build, UI Automation) | PASS | `20261026_181556` | B2 | pages Home:ok, Wave:ok, Discover:ok, Library:ok, Settings:ok; now playing True; hover tooltip True; queue True/True; audio test True, back True, returned True; alive True |
| EX-29-resize | FT-29 | Resize / maximise with a UI Automation client: no crash, tree still updates | Windows Release exe (Portable build, UI Automation) | PASS | `20261026_181556` | B2 | sizes min 1024x640, max 1936x1048; tree follows navigation after resizing True; alive True |
| EX-30-minsize | FT-30 | Window cannot be made smaller than 1024 x 640 | Windows Release exe (Portable build, UI Automation) | PASS | `20261026_181556` | B2 | smallest window 1024x640 (dpi 96) |
| EX-05-search | FT-05 | Release exe: the search field finds the Cyrillic song (typed in Cyrillic) | Windows Release exe (Portable build, UI Automation) | PASS | `20261026_181556` | B2 | search 'тестовая': found '1 / Play Тестовая песня / Тестовая песня / Тестовый исполнитель / Тестовый альбом / 0:08' |
| EX-03-restart | FT-03 | Release exe restarted: library (and playlist, if the profile has one) still there | Windows Release exe (Portable build, UI Automation) | PASS | `20261026_181556` | B2 | restarted True, test song visible True, playlist before / after restart True / True |
| EX-29-axtree-log | FT-29 | No "Failed to update ui::AXTree" messages after resizing (TD-02) | Windows Release exe (Portable build, UI Automation) | PASS | `20261026_181556` | B2 | 0 messages in the app output |
| EX-flutter-errors | FT-28 | No Flutter exceptions in the Release exe output | Windows Release exe (Portable build, UI Automation) | PASS | `20261026_181556` | B2 | 0 error blocks |

## Артефакты прогонов (вне репозитория)

`<root>\_autotest_runs\<прогон>\`: `autotest.log`, `unit.log`, `integration.log`, `it\integration.json`, `it\recordings\*.wav` (записи звука NEXA), `exe.json`, `exe_app.log`, `screenshots\*.png`, `crash_records.txt` (если были сбои), `results.json`. Результаты каждого прогона отдельно: `reports/autotest/runs/<прогон>.json`.
