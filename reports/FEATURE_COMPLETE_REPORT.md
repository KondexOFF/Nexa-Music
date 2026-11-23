# NEXA MUSIC — FEATURE COMPLETE (D-026)

Дата: 2026-11-23
Основание: решение владельца **D-026 «Feature Complete before Debugging»**.
Git: ветка `feature/e2-youtube` (локальная). **Push и merge не выполнялись.** `v1.0.0` не изменялась. Экспериментальная ветка `experiment/x1-ublock-lite` осталась отдельной: код X1 скопирован без git merge.

Статусы:
- **IMPLEMENTED** — функция есть в коде и доступна в приложении. По D-026 полная проверка будет в E6; до E6 проверены только `flutter analyze`, unit- и widget-тесты (commit gate) и, где указано, сборка или реальный запуск.
- **LIMITED** — сделано всё, что технически и по условиям доступно; ограничение названо с причиной.
- **BLOCKED** — нельзя сделать; названа причина.

Колонка «Проверено до E6» не означает, что функция работает в Windows-exe. Это покажет только E6.

## 1. Функции Windows

| Раздел | Функция | Статус | Проверено до E6 / коммит |
|---|---|---|---|
| Library | Папки и файлы MP3 / FLAC / WAV, рекурсивно; файлы не копируются, не перемещаются, не удаляются | IMPLEMENTED | v1.0.0; AutoTest FT-02 PASS (23.11, сборка `cb2e415`) |
| Library | Метаданные (в том числе кириллица), обложки из файла и `cover.jpg`, длительность | IMPLEMENTED | AutoTest FT-02 PASS (23.11) |
| Library | Поиск, вкладки Songs / Favorites / Albums / Artists / Folders, удаление папки, пересканирование | IMPLEMENTED | AutoTest FT-04 / FT-05 PASS (23.11) |
| Favorites | Лайки для всех источников: файлы, Audius, Jamendo, YouTube, SoundCloud | IMPLEMENTED | E2.7a `495e845`; unit |
| Playlists | Создать, переименовать, удалить, порядок, убрать запись; записи всех источников; недоступные — серые и пропускаются | IMPLEMENTED | E2.7a `495e845`; AutoTest FT-03 (перезапуск) PASS |
| History | История по согласию, пауза обучения, приватная сессия, удаление; Recently Played, Continue Listening | IMPLEMENTED | E2.7b `b343bf0`; AutoTest FT-23 / FT-24 PASS |
| History | История YouTube: отдельный переключатель, видео «для детей» не записываются | LIMITED | Нужен свой ключ YouTube Data API: только с ним можно узнать `madeForKids` (Developer Policies III.E.4.j). Без ключа запись не делается, и это объясняется в Settings |
| Home | Wave, ваши плейлисты, Continue listening, Recently Played, Up Next, My Taste, Sources; без DEMO | IMPLEMENTED | E5 `c5d4afc`, `5f1ce1a`; снимки экранов 23.11 |
| Discover | Поиск Audius / Jamendo, вкладки YouTube и SoundCloud в одном порядке: заголовок, вкладки, описание | IMPLEMENTED | E5; порядок разделов — этот этап |
| Now Playing | Обложка, источник и формат, лайк / дизлайк / в плейлист / к альбому / к артисту / «Open on …», очередь, панель Mix Engine | IMPLEMENTED | `4abb3ce`; снимки экранов |
| NEXA DNA | Выбор жанров и артистов (можно пропустить), лайк / дизлайк, сброс | IMPLEMENTED | Phase 5; AutoTest FT-19…FT-24 PASS (23.11) |
| NEXA Wave | Объяснение «почему», дизлайк исключает, недавние не повторяются, бесконечная очередь | IMPLEMENTED | AutoTest FT-20 / FT-21 PASS |
| NEXA Wave | **Full Discover:** «New to you 100 %» = только новые для вас песни; знакомые — лишь когда новых нет, с пояснением | IMPLEMENTED | D-026 `6d3efca`; unit |
| NEXA Wave | **Доля Library / Online** среди новых песен вместо жёсткого лимита 50 %; без онлайн-песен библиотека заполняет пропуск | IMPLEMENTED | D-026 `6d3efca`; unit |
| NEXA Wave | Онлайн-подборки Audius / Jamendo (выключены по умолчанию; в каталоги уходят только понравившиеся жанры и артисты) | IMPLEMENTED | E1; интеграционный тест Wave PASS (23.11, лог 245) |
| Playback | Play / pause / seek / next / previous, громкость, mute, repeat, shuffle, устройство вывода | IMPLEMENTED | AutoTest FT-07…FT-10 PASS (23.11) |
| Playback | Сохранённое устройство вывода применяется при запуске; в Settings видно текущее устройство | IMPLEMENTED | `cb2e415`, `670ee2a`; unit |
| Playback | Медиаклавиши и медиапанель Windows | IMPLEMENTED | v1.0.0 (FT-16); E6 |
| Mix Engine | Crossfade 0–12 с, equal-power, предзагрузка | IMPLEMENTED | v1.0.0; звуковые замеры — E6 |
| Mix Engine | Gapless; альбомы без наложения | IMPLEMENTED | v1.0.0; звуковые замеры — E6 |
| Mix Engine | Crossfade для потоков Audius / Jamendo | IMPLEMENTED | D-025 `537d736`; AutoTest FT-26 исправлен под D-025 (`ed53a25`) |
| Mix Engine | Smart Mix v1: длина трека и альбомы | IMPLEMENTED | Phase 4; unit |
| Mix Engine | Smart Mix v1: тишина и уровень сигнала (Master Plan, этап 4) | LIMITED | Сделано и проверено на реальном libmpv 23.11 (`integration_test/smart_mix_quiet_test.dart`, лог 261). libmpv из `media_kit_libs_windows_audio` не принимает ни один фильтр FFmpeg (`silencedetect`, `astats`): «Audio filter initialized failed!», воспроизведение останавливается. Поэтому код убран, Smart Mix использует только длину и альбомы. Чтобы сделать замер, нужен отдельный декодер для анализа файлов заранее (например, сборка libmpv или FFmpeg с фильтрами). Это новое решение для владельца |
| Mix Engine | Smart Mix: совпадение темпа (BPM) и тональности | BLOCKED | По Master Plan не объявляется в v1, пока не разработано и не проверено. Нужен анализ темпа, которого в libmpv нет |
| YouTube | Официальный плеер в WebView2: ссылка без ключа, поиск со своим ключом | LIMITED | Для поиска нужен свой ключ Data API v3 (квота Google). Без ключа — только вставленная ссылка |
| YouTube | Мини-плеер: компактный в углу, развёрнутый, мини-окно поверх других; позиция сохраняется | IMPLEMENTED | E2.6 `cf62589`; нативный код собирается (`47b99dd`); E6 — ручная проверка M-01 |
| YouTube | Очередь вместе с другими источниками, «Continue», если автозапуск заблокирован, пропуск всегда с причиной | IMPLEMENTED | E2.8 `c86c57f`; интеграционный тест YouTube PASS (23.11, лог 242) |
| YouTube | Закладки: id, ссылка, имя; данные YouTube обновляются или удаляются через 30 дней | IMPLEMENTED | E2.7a |
| YouTube | Crossfade, фоновое или скрытое воспроизведение, скачивание | BLOCKED | Условия YouTube API: только видимый официальный плеер, без доступа к звуку (CLAUDE.md, CR-001) |
| Audius / Jamendo | Поиск, воспроизведение, источник и лицензия, офлайн и лимиты | IMPLEMENTED | AutoTest FT-25…FT-27 PASS (23.11) |
| SoundCloud | Официальный виджет: треки; очередь, избранное, плейлисты, история | IMPLEMENTED | E3 `7adf67e` |
| SoundCloud | **Плейлисты (sets) и профили** — одна запись очереди, виджет играет её до конца; **короткие ссылки** раскрываются | IMPLEMENTED | D-026 `dd3eb93`; unit. Реальный виджет — E6 (M-06) |
| SoundCloud | Поиск SoundCloud | BLOCKED | API SoundCloud требует разрешённого доступа (CR-002). Своего доступа у NEXA нет, поэтому только вставленные ссылки |
| SoundCloud | Crossfade, Wave, скачивание | BLOCKED | Звук доступен только внутри виджета SoundCloud |
| Общая очередь | Все источники в одной очереди: добавить, удалить, порядок, repeat, shuffle, восстановление после перезапуска | IMPLEMENTED | E2.8; unit |
| AdBlock | **Settings → Privacy**: uBlock Origin Lite в плеерах YouTube и SoundCloud. Выключен по умолчанию, предупреждение, папка расширения, выключить или **удалить полностью**. Пока не используется, WebView2 работает без поддержки расширений; локальный плеер не зависит от AdBlock | LIMITED | D-026 `dd3eb93`; unit. Нативная часть собирается (лог 254). Ограничения в разделе 2 |
| Settings | Устройство, медиаклавиши, сочетания клавиш, приватность, AdBlock, резервные копии (сделать / восстановить), каталоги, YouTube, Mix Engine, тест звука | IMPLEMENTED | Снимки экранов 23.11 |
| Сохранение состояния | Громкость, mute, repeat, shuffle, очередь, Mix, Wave, устройство; **размер и положение окна** | IMPLEMENTED | Окно — этот этап, нативная сборка PASS (лог 254) |
| Резервные копии | Копия перед миграцией, ручная копия, восстановление; миграция v3 → v4 на копии ваших данных | IMPLEMENTED | E6: `migration_copy_test` PASS (лог 234), реальный exe PASS (лог 236) |
| Навигация | Боковое меню, назад / вперёд (стрелки, **Alt + ← / →, кнопки мыши**), клавиатура, Tab-порядок | IMPLEMENTED | Этот этап; unit |
| Не в плане | Тексты песен, эквалайзер, ReplayGain, визуализаторы | BLOCKED | Master Plan, раздел 2: только после отдельного утверждения |

## 2. AdBlock — ограничения

- **Правила YouTube.** Блокировка рекламы в плеере YouTube нарушает YouTube API Services Developer Policies (III.I.05–06). Возможны отзыв ключа или доступа, обнаружение блокировщика, остановка видео. Функция только для личного использования.
- **Нет гарантии.** В X1 (WebView2 157) расширение установилось, включалось и выключалось. Запрос рекламной статистики YouTube был заблокирован. Две общие рекламные адреса со страницы about:blank не блокировались. Блокирует ли оно рекламу внутри плеера YouTube, не измерить: плеер — чужой iframe.
- **Не входит в NEXA.** uBlock Origin Lite (GPLv3) не входит в NEXA и не скачивается. Вы выбираете распакованную Chromium-сборку. Обновления — вручную.
- **Применение.** Включение, выключение и удаление срабатывают при следующем открытии плеера. Если плееры этого запуска стартовали без поддержки расширений, Settings просят перезапустить NEXA.
- **Профиль общий.** Расширение работает в профиле WebView2, общем для YouTube и SoundCloud.

## 3. Что сделано в D-026 (коммиты)

| Коммит | Содержание |
|---|---|
| `6d3efca` | Full Discover в логике Wave; доля Library / Online; запись D-026 |
| `dd3eb93` | SoundCloud: плейлисты, профили, короткие ссылки. AdBlock в Settings → Privacy: форк `webview_flutter_windows` с удалением расширения, скопирован из X1 без merge |
| `670ee2a` | Устройство вывода видно в Settings; тексты Settings; `lib/demo` убран |
| `d4a5cc2` | Размер и положение окна; назад / вперёд через Alt и кнопки мыши |
| `113d47a` | Smart Mix «тихий конец» (с фильтром FFmpeg); единый порядок разделов Discover; тексты |
| (этот коммит) | Smart Mix «тихий конец» убран: libmpv этой сборки не поддерживает фильтры (лог 261); тексты Mix Engine честные; FEATURE_COMPLETE_REPORT |

Проверка по D-026, пункт 4: каждый коммит прошёл `flutter analyze` и все unit- и widget-тесты (commit gate). Нативный код (форк WebView2 с удалением расширения, окно) собран через `flutter build windows` (лог 254). Полную регрессию, долгие звуковые тесты и ручную приёмку по D-026 не запускал.

## 4. Что дальше (E6, после вашего решения)

По D-026, раздел 6:
1. Полный `flutter analyze` и `flutter test`.
2. Windows integration.
3. Полный NEXA AutoTest.
4. Реальные звуковые замеры Crossfade, Gapless и громкости. Они слышны, поэтому их нужно запускать, когда вас нет за ПК.
5. Проверка WebView2, YouTube, SoundCloud (плейлисты), AdBlock (`integration_test/ad_block_test.dart`).
6. Миграция на копии базы.
7. UI, медиаклавиши, вся очередь.
8. Исправления.
9. Одна финальная Portable-сборка и одна итоговая ручная приёмка.
10. Затем Windows 1.1.0.
