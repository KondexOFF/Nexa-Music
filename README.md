# NEXA Music

**Status (2026-10-20):** phases 0–7 implemented; Windows pre-release build **0.9.0** (Phase 7). Full manual testing on the owner's PC (final stage) is still pending — NEXA Music is **not** declared finished before the owner's final acceptance. Progress and known problems: [docs/PROGRESS.md](docs/PROGRESS.md).

NEXA Music is a **private, Windows-first music player** for personal use:
- local library (MP3 / FLAC / WAV), playlists, favorites, search — works offline;
- playback with queue, shuffle / repeat, output device, Windows media keys and media overlay;
- **NEXA Mix Engine**: gapless, crossfade 0–12 s, Smart Mix v1 (local files only);
- **NEXA DNA** (explicit taste, likes / dislikes, consent-based local history) and **NEXA Wave** (local recommendation queue with "why this song");
- **Discover**: Audius and Jamendo through their official APIs (streaming only, source and licence shown).

Approved extension (D-017): NEXA Wave across catalogs, YouTube and SoundCloud official embedded players, macOS / Linux / Android / iOS / Web ports — after the Windows version, see [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

## Running the Windows build (no Flutter SDK needed)

The build is a self-contained folder: `NEXA_Music_0.9.0_Windows_x64` (created by the build steps below; it is not stored in the repository).

1. Copy the whole folder anywhere (e.g. a folder `NEXA Music` in your Documents). Keep all files together — the `.dll` files and the `data` folder are part of the program.
2. Start `nexa_music.exe`. Windows SmartScreen may warn because the exe is not signed (personal build): "More info" → "Run anyway".
3. First start: **Library → Add folder** with your music. Files are read where they are; nothing is copied, moved or deleted.
4. Optional: **Settings → Online catalogs** — Audius works without a key; Jamendo needs your own free client id from devportal.jamendo.com (stored only on this PC).

Requirements: Windows 10/11 x64. The Microsoft Visual C++ runtime is included in the folder. Your library database, settings and listening history live in `%APPDATA%\com.kondexoff\nexa_music` (not in the program folder), so replacing the program folder keeps your data.

Keyboard: Space play / pause · Ctrl + → / ← next / previous · Ctrl + ↑ / ↓ volume · Ctrl + M mute · Esc leaves a text field. Media keys work through the Windows media controls and do not take the keys away from other players.

## Building it yourself

Environment (verified): Windows 11 x64, Flutter 3.47.7 stable / Dart 3.13.5, Visual Studio 2022 17.14 with "Desktop development with C++" and Windows 10 SDK 10.0.26100.0, Windows Developer Mode on (plugin symlinks).

```powershell
flutter pub get
flutter analyze
flutter test
flutter build windows --release
# Result: build\windows\x64\runner\Release\  (copy this whole folder)
```

Developer tools (all outputs must stay outside the repository):

```powershell
flutter run -d windows                                   # debug run
flutter test test/online/audius_live.dart                # live Audius check (network)
flutter test test/online/jamendo_live.dart               # live Jamendo check (client id file outside the repo)
flutter run -d windows "--dart-define=NEXA_CAPTURE_DIR=<folder>"   # screenshots of the Phase 1 layouts
flutter run -d windows --dart-define=NEXA_SELFTEST=true "--dart-define=NEXA_TEST_AUDIO=<own file>" "--dart-define=NEXA_PROBE_LOG_DIR=<folder>"
```

## Automatic final test (NEXA AutoTest)

Double-click `NEXA_AutoTest.cmd` (about 15 minutes; test tones are played). It never touches your own library or settings: everything runs in a separate test profile with a generated test library (`tools/autotest/library/make_test_library.py`, kept outside the repository). Results: `reports/FINAL_AUTOTEST_REPORT.md`, `reports/autotest/results.json`; logs, recordings and screenshots in the run folder `_autotest_runs/<date>` next to the repository. What still needs a person (Narrator, listening impressions, a real network outage, your own music folder) is listed at the end of the report.

Only some groups: `NEXA_AutoTest.cmd -Groups playback,mix` (groups: library, playback, mix, dna, online; the exe stage only with `-WithExe`). The sound must be on: before and during every recording the run checks Windows mute and volume; with no sound the sound checks are reported BLOCKED, not FAIL. The report names the run and the build (app-code fingerprint) of every result.

## Rules for this repository

- Plan: [NEXA_Music_Master_Plan_Claude.md](NEXA_Music_Master_Plan_Claude.md); agent rules: [CLAUDE.md](CLAUDE.md); decisions: [docs/DECISIONS.md](docs/DECISIONS.md); change requests: [docs/CHANGE_REQUESTS.md](docs/CHANGE_REQUESTS.md); reports: [reports/](reports/).
- Never commit music files, databases, listening history, keys / client ids, tokens or personal paths. The repository is private; the app is for personal use.
- Spotify is not an audio source. YouTube / SoundCloud only through their official visible players (approved extension, not implemented yet).
- Every push to GitHub needs the owner's permission.

## Design references

NEXA Design 04 (Home and Player) in `assets/design/` — references only, not bundled. The app icon is original, drawn for NEXA (Phase 7).
