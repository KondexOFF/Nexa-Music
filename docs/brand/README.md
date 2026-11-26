# NEXARYVE — brand (D-034)

NEXARYVE is the new name of NEXA Music (owner decision D-035, 2026-11-26).

## Mark

`nexaryve_mark.svg` — an **N drawn as one ribbon**. Its diagonal is a sound wave: music in motion, one line from the first song to the next. The ribbon runs from lavender into coral on a graphite tile.

- Geometry on a 512 grid:
  - tile: 480 × 480, radius 116;
  - ribbon: `M150 362 V150 C 262 150, 250 362, 362 362 V150`, width 46, round caps.
- Ribbon colours: `#C4B5FF` → `#9C8BFF` (55 %) → `#FF8A74`.
- Tile: `#20232F` → `#0E1016`, with a soft lavender light at the top right.
- In the app the mark is painted by `NexaryveMark` (`lib/ui/brand_mark.dart`), using the same geometry and colours. The Windows icon `windows/runner/resources/app_icon.ico` is made from the SVG in sizes 16–256.

## Wordmark

**NEXARYVE** in Manrope ExtraBold, capitals, letter spacing about 0.28 em, set next to the mark (`NexaryveWordmark`). Tagline: *Your sound, in motion.*

## What changed and what deliberately stays

| Changed (what the user reads) | Stays (identifiers - changing them needs a migration) |
|---|---|
| App and window title, Windows file description, texts in the app (NEXARYVE Wave, NEXARYVE DNA, NEXARYVE Mix Engine, NEXARYVE Update Center) | Data folder `%APPDATA%\com.kondexoff\nexa_music` and update folder `%LOCALAPPDATA%\com.kondexoff\nexa_music` (Windows company / product name in the exe stay `com.kondexoff` / `nexa_music`) |
| Logo, app icon, README banner | `nexa_music.exe` — the installed updater replaces and starts exactly this file |
| | GitHub repository `KondexOFF/Nexa-Music`, the Update Center source |
| | Release package name `NEXA_Music_<version>_Windows_x64.zip`: installed 1.1.1 copies look for it, so every release keeps an asset with this name. NEXARYVE builds also accept `NEXARYVE_<version>_Windows_x64.zip` |
| | Settings keys, database tables, environment variables (`NEXA_*`), Dart package `nexa_music` and the Audius app name |

A later move of these identifiers is possible only together with a migration: copy the data folder, keep the old one, and update in two steps. That would be a separate decision.
