# NEXA Music — FINAL AUTOTEST REPORT

Дата запуска: 2026-10-25T13:58:48 … 2026-10-25T14:00:38  
Версия приложения: 0.9.0+7, коммит `07202f8` (+ незакоммиченные изменения)  
Среда: Microsoft Windows 11 Pro; Flutter 3.47.7 • channel stable • https://github.com/flutter/flutter.git  
Запуск: `NEXA_AutoTest.cmd` (папка запуска `<root>\_autotest_runs\20261025_135848`)

Статусы: PASS — ожидаемый результат проверен; FAIL — проверено, результат неверный; BLOCKED — проверку не удалось выполнить (причина указана); MANUAL REQUIRED — нужна короткая ручная проверка; NOT RUN — не запускалась.

Уровень каждой автоматической проверки указан отдельно: unit / widget-тесты (FakeEngine) не считаются подтверждением работы Windows-exe; интеграционные тесты используют настоящий media_kit, SQLite, файлы и HTTP (debug-сборка); этап «Release exe» управляет настоящей Portable-сборкой через UI Automation. Звук измеряется записью реального выхода Windows (WASAPI Loopback).

## Примечание к этому отчёту (2026-10-25)

- **Звук.** Проверки звука `AT-06-audio`, `AT-06-id3-flac`, `AT-10-volume`, `AT-11-crossfade-6`, `AT-12-crossfade-0` (BLOCKED) и `AT-12-crossfade-12` (FAIL) не дали результата из-за выключенного звука Windows (mute), а не из-за NEXA:
  - в записях этого прогона первые ~13 секунд и вся цепочка из 24 треков содержат цифровой ноль;
  - когда звук включили, следующие переходы прошли: `AT-13` gapless без паузы и наложения, `AT-14`, `AT-15`, `AT-26`.
- **Те же проверки при включённом звуке (2026-10-22, прогоны 19:43 и 19:57) прошли:**
  - Crossfade 6 / 12 с: наложение 5,7 / 11,5 с, уровень 0,96–1,03;
  - громкость 100 % / 50 % / mute;
  - тишина на паузе.
- **Gapless (TD-20) после исправления:**
  - 22.10 треки 1–9 из 24 прозвучали ровно по 6,00 с, по порядку и без пауз;
  - 25.10 альбомный переход FLAC → FLAC прошёл без паузы и наложения.
  - Цепочку из 24 треков целиком после исправления ещё нужно подтвердить: `NEXA_AutoTest.cmd -Groups playback,mix` при включённом звуке, около 6 минут.
- **Exe-проверки взяты из прогона 20261025_135848**, интеграционные — из прогона 20261025_134106 (строка `SYS-integration-source`).

## Итог

| | FAIL | BLOCKED | MANUAL REQUIRED | PASS | NOT RUN |
|---|---|---|---|---|---|
| Тесты FT (30) | 1 | 3 | 6 | 20 | 0 |
| Отдельные проверки (59) | 1 | 5 | 0 | 53 | 0 |

## FT-01 – FT-30: автоматические и ручные проверки

| FT | Сценарий | Статус | Автоматически | Вручную |
|---|---|---|---|---|
| FT-01 | Запуск Portable-сборки | **PASS** | SYS-package: PASS<br>EX-01-start: PASS<br>EX-01-version: PASS | MAN-01: PASS |
| FT-02 | Импорт библиотеки MP3 / FLAC / WAV | **MANUAL REQUIRED** | AT-02-count: PASS<br>AT-02-tags: PASS<br>AT-02-wav-cyrillic: PASS<br>AT-02-durations: PASS<br>AT-02-cover: PASS<br>AT-02-files-unchanged: PASS<br>AT-02-rescan: PASS<br>EX-02-library: PASS | MAN-02: MANUAL REQUIRED |
| FT-03 | Сохранение после перезапуска | **PASS** | AT-03-restart: PASS<br>EX-03-restart: PASS |  |
| FT-04 | Пропавший файл и Rescan | **PASS** | AT-04-missing: PASS |  |
| FT-05 | Поиск, кириллица | **PASS** | AT-05-search: PASS<br>EX-05-search: PASS |  |
| FT-06 | 20–30 треков подряд | **BLOCKED** | AT-06-order: PASS<br>AT-06-audio: BLOCKED<br>AT-06-id3-flac: BLOCKED |  |
| FT-07 | Пауза, перемотка, назад / вперёд | **PASS** | AT-07-transport: PASS<br>AT-07-pause-silence: PASS |  |
| FT-08 | Очередь | **PASS** | AT-08-queue: PASS |  |
| FT-09 | Shuffle и Repeat | **PASS** | AT-09-shuffle: PASS<br>AT-09-repeat: PASS |  |
| FT-10 | Громкость, Mute, устройство вывода | **BLOCKED** | AT-10-volume: BLOCKED<br>AT-10-devices: PASS | MAN-10: MANUAL REQUIRED |
| FT-11 | Crossfade 6 с | **BLOCKED** | AT-11-crossfade-6: BLOCKED |  |
| FT-12 | Crossfade 0 с и 12 с | **FAIL** | AT-12-crossfade-0: BLOCKED<br>AT-12-crossfade-12: FAIL |  |
| FT-13 | Gapless внутри альбома | **PASS** | AT-13-album-gapless: PASS |  |
| FT-14 | Smart Mix | **PASS** | AT-14-smart-mix: PASS |  |
| FT-15 | Crossfade между форматами | **PASS** | AT-15-mp3-flac: PASS<br>AT-15-flac-wav: PASS |  |
| FT-16 | Медиаклавиши и медиапанель Windows | **PASS** | EX-16-session: PASS<br>EX-16-keys: PASS |  |
| FT-17 | Медиаклавиши рядом с другим плеером | **MANUAL REQUIRED** |  | MAN-17: MANUAL REQUIRED |
| FT-18 | Горячие клавиши | **PASS** | EX-18-keyboard: PASS |  |
| FT-19 | NEXA DNA | **PASS** | AT-19-dna: PASS |  |
| FT-20 | NEXA Wave | **PASS** | AT-20-wave: PASS |  |
| FT-21 | Дизлайк | **PASS** | AT-21-dislike: PASS |  |
| FT-22 | Знакомое ↔ Открытия | **PASS** | AT-22-discovery: PASS |  |
| FT-23 | Private session, Pause learning | **PASS** | AT-23-privacy: PASS |  |
| FT-24 | Удаление истории, сброс DNA | **PASS** | AT-24-reset: PASS |  |
| FT-25 | Поиск Audius / Jamendo | **PASS** | AT-25-audius: PASS<br>AT-25-jamendo: PASS |  |
| FT-26 | Воспроизведение Audius / Jamendo | **PASS** | AT-26-audius: PASS<br>AT-26-jamendo: PASS<br>AT-26-no-mix: PASS |  |
| FT-27 | Без интернета | **MANUAL REQUIRED** | AT-27-unreachable: PASS | MAN-27: MANUAL REQUIRED |
| FT-28 | Доступность (UI Automation, Диктор) | **MANUAL REQUIRED** | SYS-eventlog: PASS<br>EX-28-a11y: PASS<br>EX-flutter-errors: PASS | MAN-28: MANUAL REQUIRED |
| FT-29 | Изменение размера окна с клиентом доступности (TD-02) | **MANUAL REQUIRED** | EX-29-resize: PASS<br>EX-29-axtree-log: PASS | MAN-29: MANUAL REQUIRED |
| FT-30 | Минимальный и максимальный размер окна | **MANUAL REQUIRED** | EX-30-minsize: PASS | MAN-30: MANUAL REQUIRED |

## Технический долг TD-01 – TD-18

| TD | Проверяется в | Статус |
|---|---|---|
| TD-01 | FT-28 | MANUAL REQUIRED |
| TD-02 | FT-29 | MANUAL REQUIRED |
| TD-03 | FT-28 | MANUAL REQUIRED |
| TD-04 | FT-02 | MANUAL REQUIRED |
| TD-05 | FT-02 | MANUAL REQUIRED |
| TD-06 | FT-16, FT-17 | MANUAL REQUIRED |
| TD-07 | FT-06, FT-07, FT-08, FT-09, FT-10 | BLOCKED |
| TD-08 | FT-14 | PASS |
| TD-09 | FT-11, FT-12, FT-13, FT-15 | FAIL |
| TD-10 | FT-20, FT-22 | PASS |
| TD-11 | FT-20 | PASS |
| TD-12 | FT-19 | PASS |
| TD-13 | FT-25 | PASS |
| TD-14 | FT-26 | PASS |
| TD-15 | FT-26 | PASS |
| TD-16 | FT-16, FT-17 | MANUAL REQUIRED |
| TD-17 | FT-01 | PASS |
| TD-18 | FT-18 | PASS |

## Ошибки и блокировки

- **BLOCKED AT-06-audio** (FT-06) 24 tracks in a row: audible order, no overlap, no gaps (loopback) — no sound captured - is the Windows output muted or at 0 %? The AutoTest needs audible output to measure (01_ft06_24_tracks.wav)
- **BLOCKED AT-06-id3-flac** (FT-06) Gapless: MP3 -> FLAC with ID3 tag in front -> WAV, all audible — no sound captured - is the Windows output muted or at 0 %? The AutoTest needs audible output to measure (02_ft06_id3_flac.wav)
- **BLOCKED AT-10-volume** (FT-10) Volume and mute change the real output level (loopback) — no sound captured - is the Windows output muted or at 0 %? The AutoTest needs audible output to measure (05_ft10_volume_50.wav)
- **BLOCKED AT-11-crossfade-6** (FT-11) Crossfade 6 s (WAV -> FLAC): smooth overlap, no dip, no clipping — no sound captured - is the Windows output muted or at 0 %? The AutoTest needs audible output to measure (07_AT-11-crossfade-6.wav); planned crossfade 6.0 s ("Crossfade"); engine moved on: true
- **BLOCKED AT-12-crossfade-0** (FT-12) Crossfade 0 s: no overlap, no gap — no sound captured - is the Windows output muted or at 0 %? The AutoTest needs audible output to measure (08_AT-12-crossfade-0.wav); planned gapless 0.0 s ("Crossfade off: no overlap"); engine moved on: true
- **FAIL AT-12-crossfade-12** (FT-12) Crossfade 12 s: long smooth overlap — planned crossfade 12.0 s ("Crossfade"); measured overlap 2.96 s, gap 0.000 s, peak 0.129, level during overlap 0.00-0.00 x; player moved on: true

## Что осталось проверить вручную (≈10–15 минут)

| ID | FT | Что сделать | Почему не автоматизировано | Статус |
|---|---|---|---|---|
| MAN-01 | FT-01 | **Владелец скопировал Portable-папку и запустил exe.** Подтверждено владельцем. | Проверка первого запуска человеком (SmartScreen). | PASS |
| MAN-02 | FT-02 | **Своя музыка через окно Windows «Add folder» (TD-05).** Library → Add folder → своя папка с музыкой; сверить число треков и 3–4 названия. | Ваша настоящая библиотека и системный диалог выбора папки; автотест использует сгенерированную библиотеку без диалога. | MANUAL REQUIRED |
| MAN-10 | FT-10 | **Переключение устройства вывода.** Settings → Output device: другое устройство (наушники / HDMI) → звук там; затем System default. | Нужен второй физический выход и человек, который его слышит. | MANUAL REQUIRED |
| MAN-17 | FT-17 | **Медиаклавиши рядом с браузером.** NEXA на паузе, видео в браузере играет → Play/Pause на клавиатуре управляет браузером. | Нужен чужой плеер (браузер) с его собственной медиасессией. | MANUAL REQUIRED |
| MAN-27 | FT-27 | **Отключённый интернет.** Отключить Wi-Fi / кабель → Discover → поиск → понятное сообщение; своя песня играет. | Автотест не отключает сеть компьютера (имитирует недоступный адрес). | MANUAL REQUIRED |
| MAN-28 | FT-28 | **Экранный диктор.** Win+Ctrl+Enter, Tab по Home, Now Playing, Wave, Discover, Settings; Диктор читает элементы; затем выключить. | Качество озвучивания оценивает человек. | MANUAL REQUIRED |
| MAN-29 | FT-29 | **Диктор после изменения размера окна (TD-02).** С включённым Диктором развернуть / уменьшить окно, затем Tab по 2–3 элементам. | Нужен настоящий Диктор; автотест проверяет только дерево UI Automation. | MANUAL REQUIRED |
| MAN-30 | FT-30 | **Внешний вид на минимальном и максимальном окне.** Открыть скриншоты 11_minimum_size.png и 12_maximised.png (и 05–10) из папки запуска. | Обрезанный или перекрытый интерфейс оценивает человек по скриншотам. | MANUAL REQUIRED |

## Все проверки

| ID | FT | Проверка | Уровень | Статус | Подробности |
|---|---|---|---|---|---|
| SYS-library | - | Test library present and unchanged (SHA-256) | Windows system | PASS | 36 tracks |
| SYS-loopback | - | WASAPI loopback recorder built | Windows system | PASS | exit 0 |
| SYS-package | FT-01 | Release build copied to a Portable folder with every required file | Windows system | PASS | 49 MB |
| SYS-integration-source | - | Integration results taken from an earlier run (stage skipped in this run) | Windows system | PASS | integration stage of run 20261025_135337; this run: unit / exe stages only |
| SYS-eventlog | FT-28 | Windows Event Log: no crash of nexa_music.exe during the whole run | Windows system | PASS | 0 crash records |
| UNIT-analyze | - | flutter analyze | static analysis | PASS | exit 0 |
| UNIT-tests | - | Existing unit / widget tests (FakeEngine, in-memory database) | unit / widget tests | PASS | exit 0; +139: All tests passed! |
| AT-02-count | FT-02 | Import: every test file is in the library once | integration (real media_kit, SQLite, files; debug build) | PASS | library 36 / expected 36; problems: [] |
| AT-02-tags | FT-02 | Import: titles, artists, albums incl. Cyrillic MP3 / FLAC | integration (real media_kit, SQLite, files; debug build) | PASS | all tags as written |
| AT-02-wav-cyrillic | FT-02 | Import: Cyrillic RIFF INFO tags in WAV (known issue TD-04) | integration (real media_kit, SQLite, files; debug build) | PASS | read correctly |
| AT-02-durations | FT-02 | Import: durations within 0.3 s of the generated length | integration (real media_kit, SQLite, files; debug build) | PASS | largest deviation 0.071 s |
| AT-02-cover | FT-02 | Import: folder cover.jpg used as artwork | integration (real media_kit, SQLite, files; debug build) | PASS | 4 of 4 tracks in meta/ have a cover |
| AT-02-files-unchanged | FT-02 | Import never changes, moves or adds music files | integration (real media_kit, SQLite, files; debug build) | PASS | 38 files compared by SHA-256 |
| AT-02-rescan | FT-02 | Rescan adds no duplicates | integration (real media_kit, SQLite, files; debug build) | PASS | 36 tracks after rescan |
| AT-03-restart | FT-03 | After a restart: library, playlist, likes, Mix mode and volume restored | integration (real media_kit, SQLite, files; debug build) | PASS | tracks 36, playlist 3 songs, favorites 2, mode gapless, volume 0.6 |
| AT-04-missing | FT-04 | Renamed file: unavailable with a reason, available again after renaming back | integration (real media_kit, SQLite, files; debug build) | PASS | while renamed: unavailable "File not found"; after: available; available tracks 36 (the renamed copy stays listed as missing by design) |
| AT-05-search | FT-05 | Search: words, letter case and Cyrillic | integration (real media_kit, SQLite, files; debug build) | PASS | "seq 0" 11 (11), "тестовая" 1 (>=1), "ТЕСТОВЫЙ" 2 (>=2), "live band" 3 (3) |
| AT-06-order | FT-06 | 24 tracks in a row: each started once, in order (engine) | integration (real media_kit, SQLite, files; debug build) | PASS | 24 tracks started; engine errors: none |
| AT-06-audio | FT-06 | 24 tracks in a row: audible order, no overlap, no gaps (loopback) | integration (real media_kit, SQLite, files; debug build) | BLOCKED | no sound captured - is the Windows output muted or at 0 %? The AutoTest needs audible output to measure (01_ft06_24_tracks.wav) |
| AT-06-id3-flac | FT-06 | Gapless: MP3 -> FLAC with ID3 tag in front -> WAV, all audible | integration (real media_kit, SQLite, files; debug build) | BLOCKED | no sound captured - is the Windows output muted or at 0 %? The AutoTest needs audible output to measure (02_ft06_id3_flac.wav) |
| AT-07-transport | FT-07 | Pause holds the position, resume, seek, previous (restart / previous track), next | integration (real media_kit, SQLite, files; debug build) | PASS | pause 1040->1040 ms, resume -> 2260 ms, seek 20 s -> 20435 ms, restart true, next true, previous true |
| AT-07-pause-silence | FT-07 | Silence while paused (loopback, tone of the paused song) | integration (real media_kit, SQLite, files; debug build) | PASS | 440 Hz level while paused 0.00000 (playing at 100 %: about 0.12); other sound on the PC: peak 0.0000 |
| AT-08-queue | FT-08 | Play next, Add to queue, Remove, Clear; the engine plays the inserted song | integration (real media_kit, SQLite, files; debug build) | PASS | play next/add true, remove true, engine played inserted true, clear true |
| AT-09-shuffle | FT-09 | Shuffle plays each song once; switching it off restores the order | integration (real media_kit, SQLite, files; debug build) | PASS | 10 different files played; order restored true |
| AT-09-repeat | FT-09 | Repeat this song replays it; Repeat all wraps to the first song | integration (real media_kit, SQLite, files; debug build) | PASS | repeat one true, repeat all wrap true |
| AT-10-volume | FT-10 | Volume and mute change the real output level (loopback) | integration (real media_kit, SQLite, files; debug build) | BLOCKED | no sound captured - is the Windows output muted or at 0 %? The AutoTest needs audible output to measure (05_ft10_volume_50.wav) |
| AT-10-devices | FT-10 | Output devices are listed; "System default" can be selected | integration (real media_kit, SQLite, files; debug build) | PASS | 5 devices reported by the engine |
| AT-11-crossfade-6 | FT-11 | Crossfade 6 s (WAV -> FLAC): smooth overlap, no dip, no clipping | integration (real media_kit, SQLite, files; debug build) | BLOCKED | no sound captured - is the Windows output muted or at 0 %? The AutoTest needs audible output to measure (07_AT-11-crossfade-6.wav); planned crossfade 6.0 s ("Crossfade"); engine moved on: true |
| AT-12-crossfade-0 | FT-12 | Crossfade 0 s: no overlap, no gap | integration (real media_kit, SQLite, files; debug build) | BLOCKED | no sound captured - is the Windows output muted or at 0 %? The AutoTest needs audible output to measure (08_AT-12-crossfade-0.wav); planned gapless 0.0 s ("Crossfade off: no overlap"); engine moved on: true |
| AT-12-crossfade-12 | FT-12 | Crossfade 12 s: long smooth overlap | integration (real media_kit, SQLite, files; debug build) | FAIL | planned crossfade 12.0 s ("Crossfade"); measured overlap 2.96 s, gap 0.000 s, peak 0.129, level during overlap 0.00-0.00 x; player moved on: true |
| AT-13-album-gapless | FT-13 | Same album with Crossfade on: gapless, no overlap (FLAC) | integration (real media_kit, SQLite, files; debug build) | PASS | planned gapless 0.0 s ("Same album: gapless"); measured overlap 0.00 s, gap 0.000 s, peak 0.106, level during overlap 0.00-0.00 x; player moved on: true |
| AT-14-smart-mix | FT-14 | Smart Mix shortens the overlap for short tracks and says why | integration (real media_kit, SQLite, files; debug build) | PASS | planned crossfade 3.0 s ("Smart Mix: shorter for a short track"); measured overlap 2.78 s, gap 0.000 s, peak 0.139, level during overlap 0.98-1.01 x; player moved on: true |
| AT-15-mp3-flac | FT-15 | Crossfade 6 s MP3 -> FLAC | integration (real media_kit, SQLite, files; debug build) | PASS | planned crossfade 6.0 s ("Crossfade"); measured overlap 5.66 s, gap 0.000 s, peak 0.146, level during overlap 0.98-1.07 x; player moved on: true |
| AT-15-flac-wav | FT-15 | Crossfade 6 s FLAC -> WAV | integration (real media_kit, SQLite, files; debug build) | PASS | planned crossfade 6.0 s ("Crossfade"); measured overlap 5.70 s, gap 0.000 s, peak 0.142, level during overlap 0.99-1.01 x; player moved on: true |
| AT-19-dna | FT-19 | NEXA DNA offers the library genres / artists and stores liked / excluded choices | integration (real media_kit, SQLite, files; debug build) | PASS | genres Electronic, Rock, Поп, Ambient, Jazz; 2 choices stored |
| AT-20-wave | FT-20 | Wave: liked artist among the first picks, reasons shown, excluded genre never, refills itself, skips recorded | integration (real media_kit, SQLite, files; debug build) | PASS | queue 8 (liked first true, excluded genre 0, reasons 8), refilled true to 16, history 0->3 |
| AT-21-dislike | FT-21 | Dislike skips the playing Wave song and excludes it | integration (real media_kit, SQLite, files; debug build) | PASS | skipped true, suggested again false |
| AT-22-discovery | FT-22 | Familiar picks played songs first; Discovery picks unplayed songs first | integration (real media_kit, SQLite, files; debug build) | PASS | familiar: 4 of top 4 known; discovery: 4 of top 4 new (4 known songs by different artists) |
| AT-23-privacy | FT-23 | Private session and Pause learning add nothing to the history; normal listening does | integration (real media_kit, SQLite, files; debug build) | PASS | added: private 0, paused 0, normal 2 |
| AT-24-reset | FT-24 | Delete history and Reset DNA; likes and playlists stay; private session ends with the app | integration (real media_kit, SQLite, files; debug build) | PASS | private after restart false, events 0, choices 0, dislikes 0, favorites 2->2, playlists 1, discovery 0.3 |
| AT-25-audius | FT-25 | Audius: search returns results with source and playability | integration (real media_kit, SQLite, files; debug build) | PASS | "lofi": 10 results, 9 playable |
| AT-25-jamendo | FT-25 | Jamendo: search returns results with source and playability | integration (real media_kit, SQLite, files; debug build) | PASS | "jazz": 10 results, 10 playable, licence CC BY-NC-SA 3.0 |
| AT-26-audius | FT-26 | Audius: stream plays through the real engine and is audible (loopback) | integration (real media_kit, SQLite, files; debug build) | PASS | position > 3 s: true; output RMS 0.0763 |
| AT-26-jamendo | FT-26 | Jamendo: stream plays through the real engine and is audible (loopback) | integration (real media_kit, SQLite, files; debug build) | PASS | position > 3 s: true; output RMS 0.0811 |
| AT-26-no-mix | FT-26 | Catalog tracks are never crossfaded; not written to the history | integration (real media_kit, SQLite, files; debug build) | PASS | plan cut "Source does not allow mixing"; history 0->0 |
| AT-27-unreachable | FT-27 | Unreachable catalog gives the "offline" message; the local library still plays | integration (real media_kit, SQLite, files; debug build) | PASS | error kind offline; local playback true (simulated with an unreachable address, real network still on) |
| EX-01-start | FT-01 | Portable exe starts with an isolated test profile; its accessibility tree is visible | Windows Release exe (Portable build, UI Automation) | PASS | window 'NEXA Music', 114 named elements via MSAA; exe_app.log start: MSAA nodes 166, UI Automation elements 1 |
| EX-01-version | FT-01 | Settings - About shows version 0.9.0 | Windows Release exe (Portable build, UI Automation) | PASS | NEXA Music - personal Windows music player. Local library, playback, NEXA Mix Engine, NEXA DNA, NEXA Wave, Audius and Jamendo. Version 0.9.0 - pre-release build (Phase 7), final testing pending. |
| EX-02-library | FT-02 | Release exe shows the imported test library from its database | Windows Release exe (Portable build, UI Automation) | PASS | 'Seq 01' visible in Library - Songs |
| EX-16-session | FT-16 | Windows media overlay shows NEXA with song, artist and Playing | Windows Release exe (Portable build, UI Automation) | PASS | 'Seq 01' / 'AutoTest Band' Playing (current session) |
| EX-16-keys | FT-16 | Media keys with NEXA minimised: Play/Pause, Next, Previous, Stop | Windows Release exe (Portable build, UI Automation) | PASS | play/pause -> Paused -> Playing; next -> 'Seq 04'; previous -> 'Seq 01'; stop -> Paused |
| EX-18-keyboard | FT-18 | Space toggles playback, Ctrl+Right plays the next song (Release exe) | Windows Release exe (Portable build, UI Automation) | PASS | space: Paused -> Playing -> Paused; ctrl+right: 'Seq 01' -> 'Seq 04' |
| EX-28-a11y | FT-28 | With a UI Automation client attached: all pages, Now Playing, Play/Pause hover, queue button, audio test and back - no crash | Windows Release exe (Portable build, UI Automation) | PASS | pages Home:ok, Wave:ok, Discover:ok, Library:ok, Settings:ok; now playing True; hover tooltip True; queue True/True; audio test True, back True, returned True; alive True |
| EX-29-resize | FT-29 | Resize / maximise with a UI Automation client: no crash, tree still updates | Windows Release exe (Portable build, UI Automation) | PASS | sizes min 1024x640, max 1936x1048; tree follows navigation after resizing True; alive True |
| EX-30-minsize | FT-30 | Window cannot be made smaller than 1024 x 640 | Windows Release exe (Portable build, UI Automation) | PASS | smallest window 1024x640 (dpi 96) |
| EX-05-search | FT-05 | Release exe: the search field finds the Cyrillic song (typed in Cyrillic) | Windows Release exe (Portable build, UI Automation) | PASS | search 'тестовая': found '1 / Play Тестовая песня / Тестовая песня / Тестовый исполнитель / Тестовый альбом / 0:08' |
| EX-03-restart | FT-03 | Release exe restarted: library and playlist still there | Windows Release exe (Portable build, UI Automation) | PASS | restarted True, test song visible True, playlist visible True |
| EX-29-axtree-log | FT-29 | No "Failed to update ui::AXTree" messages after resizing (TD-02) | Windows Release exe (Portable build, UI Automation) | PASS | 0 messages in the app output |
| EX-flutter-errors | FT-28 | No Flutter exceptions in the Release exe output | Windows Release exe (Portable build, UI Automation) | PASS | 0 error blocks |

## Артефакты запуска (вне репозитория)

`<root>\_autotest_runs\20261025_135848\`: `autotest.log`, `unit.log`, `integration.log`, `it\integration.json`, `it\recordings\*.wav` (записи выхода Windows), `exe.json`, `exe_app.log`, `screenshots\*.png`, `crash_records.txt` (если были сбои), `results.json`.
