# NEXARYVE — Visual Evolution 1.2 (concept)

Direction (D-035): a premium dark music interface. Graphite and deep dark surfaces, soft colour accents, light that comes from the artwork, careful typography, smooth motion and little visual noise. NEXARYVE has its own look and copies neither Spotify nor Apple Music. There is no theme engine: one dark look.

## 1. Principles

1. **Graphite, not navy.** Surfaces are neutral graphite. Colour comes only from accents and from the music itself (artwork light).
2. **The song lights the room.** The playing song's artwork colour softly tints the top of the page, Now Playing and the player bar. The tint changes smoothly with the song, never flashes, and falls back to NEXARYVE lavender when there is no artwork.
3. **One accent at a time.** Lavender (`#AD9AFF`) is the interactive colour. Coral (`#FF8A74`) appears only next to lavender: in the brand ribbon and in "live" moments such as the playing indicator and progress highlights.
4. **Quiet structure.** Fewer borders and boxes; space and light separate sections. Long helper sentences move into tooltips or empty states.
5. **Calm motion.** Short and soft: 160 / 260 / 420 ms, easing out. Pages cross-fade with a slight rise. Hover lifts a card by light, not by jumping. Nothing loops except what is playing.
6. **Readable numbers.** Times and counters use tabular figures, so they never jitter while playing.

## 2. Tokens (`lib/app/theme/tokens.dart`)

| Role | Before (Design 04) | NEXARYVE 1.2 |
|---|---|---|
| background | `#111319` | `#0F1013` graphite |
| sidebar | `#0F1117` | `#0B0C0F` |
| player bar | `#0D0F14` | `#0B0C0F` + artwork light |
| panel | `#161922` | `#15161B` |
| panel raised | `#1D2130` | `#1B1D23` |
| panel hover | `#242A3B` | `#23252D` |
| selected nav | `#2E2950` | lavender 14 % over graphite |
| border | white 8 % | white 6 % |
| text | `#F0EFEB` / `#A6A8B6` / `#6F7282` | `#F2F1EE` / `#A3A5B0` / `#6B6D78` |
| accent | `#AD9AFF` | `#AD9AFF` (kept: the brand) |
| live | `#FF7E6E` | `#FF8A74` (brand coral) |

Radius: 10 / 14 / 18 / 24 for chips / rows / cards / hero. Spacing: unchanged 8 px rhythm.

## 3. Typography (Manrope)

| Style | Use | Size / weight |
|---|---|---|
| display | hero titles, Now Playing title | 46 / 800, -1.0 tracking |
| h1 | page titles | 30 / 800, -0.4 |
| h2 | section titles | 20 / 700 |
| title / body / caption | rows, text, meta | 15 / 14 / 12.5 |
| eyebrow | small capitals above titles | 11.5 / 700, 2.6 tracking (calmer than 5) |
| numbers | times, counts | tabular figures |

## 4. Components

- **AmbientLight**: colour taken from the playing song's artwork (embedded or folder cover, measured once in an isolate and cached by path). Generated covers use their own palette colour. A wide, very soft radial gradient sits behind the page top and Now Playing (no more than 18 % opacity) and animates over 600 ms.
- **Surface**: one component for panels with three levels (flat, raised, glass). Glass means a faint white top edge plus 4 % artwork tint; there is no blur, so it stays cheap on every PC.
- **Cards**: artwork first, title and subtitle below. On hover: a slight light lift and the play button appearing. On press: 98 % scale.
- **Navigation**: a sidebar with the brand mark and quiet items. The selected item is a soft lavender pill with a 3 px lavender indicator. Playlists show small artwork.
- **Player bar**: artwork, title and artist on the left; controls in the centre with a calm play button; a thin progress line that turns coral where the song plays. The colour light comes from the artwork.

## 5. Screens (order of D-035)

1. **Home / navigation**: a greeting and the Wave hero lit by the current artwork colour; playlists as artwork cards; Recently Played as quiet rows; Up Next and Taste in the right column without heavy boxes.
2. **Now Playing / mini-player**: large artwork with its own light, title in display type, Mix Engine and the "why this song" note as small chips; the mini-player uses the same light.
3. **Wave / Library**: the Wave slider as one calm line with a glow; the Library as dense, quiet rows with tabular durations, and albums as artwork grids.
4. **Discover / Settings / Update Center**: the same surfaces and spacing; Settings in clear groups; the Update Center card shows its status as a small line with a progress light.

Screenshots of each implemented screen go to the owner for feedback (not an acceptance).
