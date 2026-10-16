# AGENTS.md — NEXA Music

Read `NEXA_Music_Master_Plan_Claude.md`, `CLAUDE.md` and `docs/CHANGE_REQUESTS.md` before reviewing. These instructions guide **Codex Code Review**; they do not grant development, merge or phase-transition permission.

## Code Review Rules

### Phase isolation and owner gate
Flag consequential changes that implement work from a phase not explicitly authorized by the owner, change the Master Plan without an owner-approved change request, or bypass the end-of-phase stop. The safe path is to change only the currently approved phase, provide `reports/PHASE_XX_REPORT.md` with actual evidence, and wait for KondexOff to accept the phase and authorize the next one.

### Music provider and privacy boundaries
Flag any code that extracts, downloads, mixes or bypasses protected Spotify/YouTube audio or ads, silently records personal listening data, or commits music, listening histories, databases, device paths or credentials. Spotify is an external handoff, not a raw NEXA audio source. YouTube CR-001 remains DRAFT; until approved, no YouTube integration. The safe path is approved local audio and provider-specific, policy-compliant integrations.

### Playback correctness and honest evidence
Flag functional regressions in Windows playback, play/pause/seek/volume, queue or future crossfade ownership (e.g., unintended concurrent playback), and unsupported claims of successful tests or manual listening. CI can confirm analysis, unit tests and compilation, **not audible output**; Windows manual checks and any limitations must be disclosed in the phase report.

Codex findings are advisory. Only KondexOff can approve a phase, authorize the next phase or merge a PR. Never interpret a green CI check or Codex review as that approval.
