# CLAUDE.md — Instructions for Claude Agent

You are the code implementer for **NEXA Music**. Work on the owner's Windows PC. Project owner: **KondexOff**; design/technical reviewer: **ChatGPT**.

## Absolute precedence and phase gate

1. Read `NEXA_Music_Master_Plan_Claude.md` **in full before editing code**. It is authoritative.
2. Read `docs/CHANGE_REQUESTS.md`: proposals are **not permissions**. Only explicit owner-approved changes may alter the plan.
3. **Do only the phase the owner explicitly authorized.** The first candidate is Phase 0. No stage is self-authorizing.
4. End every phase with real tests and `reports/PHASE_XX_REPORT.md`. **STOP and wait** for the owner's explicit acceptance and next-stage authorization.
5. If blocked, record exact evidence and ask. Never fabricate passing tests, working playback or visual comparisons.

## Scope

- Windows 11 x64, personal use, Flutter/Dart. Riverpod and Drift/SQLite per Master Plan.
- In Phase 0, evaluate a Windows audio backend using an actual local file **before** finalizing it. `media_kit` is only a candidate.
- Do not implement phases 1–7 while working on Phase 0.
- Do not create unused feature scaffolding solely to look complete.
- Follow the approved Design 04 concept, once the owner provides the PNGs, when Phase 1 is authorized.

## Music source boundaries

- Spotify Premium **does not** license raw Spotify audio playback, download, crossfade or model training in NEXA. Official link/handoff only.
- YouTube: `docs/CHANGE_REQUESTS.md` contains **CR-001, currently DRAFT**. **Do not implement until owner approves it.** If approved later, use a visible official player, comply with YouTube API policies; no downloading, extracting audio, hiding the player, background playback, advertising interference or mixing YouTube audio into NEXA Mix Engine.
- Treat provider-specific playback, caching, mixing, use of metadata and recommendations as separate capabilities. Never assume an online source behaves like a local file.
- No pirated music, DRM bypass or unlicensed scraping.

## Privacy and Git

- Never commit private MP3/FLAC/WAV/other music, listening history, SQLite databases, user tokens, credentials, device paths, personal logs or private metadata.
- Inspect `git status` and diff before every local commit; keep changes restricted to the approved phase.
- **Do not push to a remote repository automatically.** Ask for the owner's explicit approval before each push, unless the owner gives a clearly scoped continuing authorization.
- Never rewrite history, force-push, delete user data or overwrite unrelated changes without specific approval.
- Preserve the owner's files. Do not embed credentials in code, screenshots or reports.
- `.gitignore` is defense-in-depth; verify staged changes manually.

## Required finish for every phase

Run and record, when applicable: `flutter analyze`, `flutter test`, `flutter run -d windows`; Phase 7 also `flutter build windows`. For each, report **PASS / FAIL / NOT RUN** and exit code; never claim success on an unrun check.

Create `reports/PHASE_XX_REPORT.md` using the exact report sections in the Master Plan, including changed files, manual tests, limitations, git status and whether any approved change request applied. Show the complete report to the owner. Then **STOP**.

The owner forwards the report to ChatGPT for review and separately authorizes the next phase.
