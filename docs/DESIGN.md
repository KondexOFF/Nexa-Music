# NEXA Design 04 — UI Handoff

**Authoritative intent:** hybrid of Noir's visual discipline, Prism's atmospheric gradients and Daylight's spacing/legibility.

Approved reference screenshots (currently held by the owner, **not yet included in GitHub**):
- `NEXA_Design_04_Home.png`
- `NEXA_Design_04_Player.png`

Claude must obtain both original PNGs before starting **Phase 1**, compare real Windows screenshots with these references, and report any divergence. **Do not** put screenshots as flat background artwork or mistake concept artwork for actual controls.

## Visual tokens

- Primary surface: graphite `#111319` with subtly differentiated navy-charcoal panels.
- Primary text: `#F0EFEB`.
- Accent: muted lavender `#AD9AFF`.
- Coral / lilac gradients: accents on selected artwork and mix states, not everywhere.
- 8 px rhythm. Sidebar about 220 px, bottom player 80–88 px, optional right panel 275–345 px.
- Home: sidebar, NEXA Wave feature, mood playlists/recent tracks, queue/taste, persistent bottom player.
- Now Playing: legible large artwork and transport, real timeline, queue, Mix Engine controls.
- Windows width targets 1280–1920 px. Right panels collapse before they obstruct controls.

## Explicit interaction rules

- Mark placeholder songs and fake data as **DEMO** until actual sources work.
- No click targets without meaningful behavior or clearly disabled state.
- Playback controls should reflect real playback engine state, not only animated decoration.
- Mix Engine must state whether a current source supports transition effects.

## Optional YouTube visual mode (CR-001; not authorized)

If approved later, add a source-labeled YouTube discovery/player view. Keep the official player **fully visible and unobstructed**, minimum 200×200 px, preferably 480×270 px or larger; no app chrome over video, no hidden audio-only variant, no YouTube background playback after minimizing/switching away. Provide an external YouTube-open fallback.

This proposal must not change Phase 1 screens until CR-001 is approved.
