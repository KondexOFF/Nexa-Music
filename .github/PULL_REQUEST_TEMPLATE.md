## NEXA Music — pull request

**Type:** <!-- Phase 00/01/.../07 or infrastructure-only -->

**Approved scope:** <!-- Owner's phase authorization, or approved CR reference -->

**Base / target branch:** <!-- e.g. main; explain stacked PRs -->

### Changes and evidence

- Main changes:
- Report: <!-- reports/PHASE_XX_REPORT.md; for infrastructure explain "not a phase" -->
- Relevant approved change requests:
- Tests with real PASS / FAIL / NOT RUN (and reasons):
  - [ ] `flutter analyze`
  - [ ] `flutter test`
  - [ ] `flutter build windows --release`
  - [ ] `flutter run -d windows` (local, manual; CI cannot verify sound)
- Manual Windows playback and visual checks: <!-- results, environment, limitations -->

### Safety and review

- [ ] No music files, personal listening data, databases, tokens or secrets committed.
- [ ] Master Plan unchanged (or separately approved change is clearly documented).
- [ ] No work from an unapproved later phase.
- [ ] CI results read; Codex findings addressed or documented.
- [ ] Affected functionality and regressions checked.
- [ ] No automatic merge or automatic start of the next phase.

### Owner's manual gate

- [ ] **KondexOff has explicitly ACCEPTED this phase** (link/quote/date).
- [ ] **KondexOff has separately authorized the next phase** (link/quote/date).

**Until those decisions, leave the phase PR open.** For infrastructure-only PRs, owner merge approval is required; it does not accept Phase 0 or authorize Phase 1.
