# Change Requests — NEXA Music

A request written here is **NOT approved** until the project owner explicitly accepts it. Claude must not implement draft requests.

## CR-001 — YouTube listening option

- **Proposed:** 2026-10-16 (user asked whether YouTube can be a listening alternative).
- **Status:** **DRAFT — feasibility and owner approval pending**.
- **Candidate phase:** Phase 6, after original providers or a separately approved amendment.
- **Do not modify:** Master Plan v1.0, phase 0–5 scope, local Mix Engine, Spotify restrictions.

### Desired value

Let the owner find music videos/songs on YouTube from NEXA, play videos via the official visible YouTube player in a dedicated view, save links/references in permitted local playlists (subject to provider policy), and open the original in YouTube.

### Suggested delivery (if owner approves)

**Preferred:** official YouTube IFrame Player API in a visible, unobstructed OS WebView (Windows WebView2 evaluation required); use YouTube Data API for search when configured and permitted. Display accurate YouTube attribution. Respect minimum 200×200 px viewport; target at least 480×270 px. Show clear errors and a button to open the video in YouTube/browser if embed is denied or technically blocked.

**Fallback:** search/open officially in the system browser, without embedded playback.

### Non-negotiable restrictions

- No hidden, tiny/offscreen or background-only YouTube player, including minimized/closed-window playback.
- No stripping audio from video, downloading/caching tracks, `yt-dlp`/unofficial YouTube Music extraction, ad bypass, fake Premium status, player UI obstruction or controls interception.
- No routing YouTube audio to native PlaybackEngine; **no gapless, crossfade or Smart Mix with YouTube audio**.
- No YouTube metadata blended into NEXA DNA/Wave learning or across-source datasets without separate terms/privacy approval.
- Ensure YouTube source labeling, player branding, ad behavior, client identity and credentials, WebView compatibility and proper visibility. A personal project is not exempt from provider terms.

### Acceptance tests to propose

1. Verified official embedded video starts from a deliberate user action while player is visible; controls, branding and ads remain intact.
2. Closing/minimizing/leaving the YouTube player view stops or pauses YouTube playback.
3. Embed-blocked and no-network errors show a clear external YouTube fallback.
4. Local file playback works independently; never overlaps accidentally with YouTube.
5. No extraction/download or request to undocumented endpoints; no API keys or user data committed.

### Owner decision required

- [ ] Approve visible YouTube embed + search as optional Phase 6 addition, **subject to feasibility**.
- [ ] Approve external-browser links only.
- [ ] Reject / defer.

Until explicitly selected, Claude **must not implement CR-001**.

### Official references

- https://developers.google.com/youtube/iframe_api_reference
- https://developers.google.com/youtube/terms/required-minimum-functionality
- https://developers.google.com/youtube/terms/developer-policies
- https://developers.google.com/youtube/terms/developer-policies-guide
- https://developers.google.com/youtube/v3/docs/search/list

## CR-002 — GitHub CI and Codex Code Review automation (process only)

- **Requested by owner:** 2026-10-16.
- **Status:** **APPROVED FOR CONFIGURATION ONLY** by explicit owner request to prepare automatic Claude + GitHub + Codex Code Review with manual phase acceptance.
- **Scope:** add `.github/workflows/nexa-windows-ci.yml`, root `AGENTS.md`, pull request template, `docs/AUTOMATION.md`, and a narrowly scoped clarification in `CLAUDE.md`.
- **Unchanged:** Master Plan v1.0, phases 0–7, existing Phase 0 code, draft CR-001 and all music-source restrictions.
- **Gate:** Codex GitHub review activation and GitHub branch/ruleset protection are manual account settings, not automatically configured by this change. Every phase still requires real test evidence, a report, explicit owner acceptance, owner merge and separately authorized next phase.
- **No new permissions:** no bot credentials or automated merges. Claude may push only within a phase-specific scope explicitly authorized by the owner.
