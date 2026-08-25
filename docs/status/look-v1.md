# Look v1 — run status

Run of `docs/plans/look-v1.md` on 2026-08-25, on Marcel's Windows box (RTX
5080, Forward+), on `feat/look-v1`, branched from `main` at `9e1b62a`
(character v1 merged). The world half ran in the main session; the character
re-author and the UI theme ran in parallel worktrees and were merged in.

---

## Read this first

```
git checkout feat/look-v1
<godot> --headless --path . --import      # once: new class, new fonts
<godot> --path . -- --host --seed 42
```

The menu is a poster. Host, and the meadow is a flat green field with drifts
of one colour of flower on it; the hill on your right is stepped terraces with
a blue-violet shadow side; the far ranges are stacked bands fading to the sky
in flat steps; the sky has clouds with a hard edge and a shaded underside.
Press F4 and everything under "poster:" is a knob. Wait for dusk: the sun grows
rays as it goes down, the shade turns violet, and the night is moonlit rather
than black.

Then press the character button and look at the new bodies.

---

## What shipped, by stage

| Stage | What | Evidence |
| --- | --- | --- |
| 1 | `Look`: one lighting ramp (lit / half / shade, shade is a colour) under terrain, far field, far trees, characters, plants and water; stepped depth fog; five new shader globals published by `SkyCycle`; the sun stays up all night as the moon; ambient off; hard shadows; poster water | `build/tour/look-1-light`, `build/character/look-1-light` |
| 2 | The sky shader: banded gradient, sun disc with rays, hard-edged clouds with a dark underside, moon and stars. `SkyCycle` drives it; the `ProceduralSkyMaterial` in the scenes is now the fallback | `build/tour/look-2-sky` |
| 3 | Far field as a backdrop: one altitude band per quad, lighting by the flank's slope over 96 m rather than the facet's, zone colour on a 24 m cell beyond the first ring | `build/tour/look-5-meadow`, `look-5b-far` |
| 4 | Ground: jitter 0.05 → 0.07 (tried 0.10, see below), hue 0.02 → 0.03, cell 12 → 6 blocks; `Block.aspect_curve()` picks a side; aspect 0.06 → 0.12 | `build/tour/look-5-meadow` |
| 5 | Meadow as a colour field: tuft colours moved onto the meadow green; meadow density 0.50 → 0.34; half of what grows in a flower patch is flowers (was 0.30) | `build/tour/look-5-meadow/8-meadow-closeup.png` |
| 6 | Characters at 1/16 of a block, stocky, chamfered, generated — see the section below | `build/character/look-6-characters` |
| 7 | UI: `assets/ui/deco_theme.tres`, Limelight / Josefin Sans / Poiret One bundled under OFL, the menu with a sunburst and stepped ranges, the creation screen as a framed print | `build/ui/look-7` |
| 8 | Docs: this file, `DESIGN.md` "Art direction", `IDEAS.md`, `README.md` | — |

The baselines, shot on `main` at `9e1b62a` before anything changed, are
`build/tour/artstyle` and `build/character/artstyle`. Same seed, same twelve
vantages, same lineup.

## The world did not move

Hard rule 5. Probe on seed 42, after every world-side change:

| | `main` (foliage v1 status) | look v1 |
| --- | --- | --- |
| Heightmap hash | `76cccdb6` | `76cccdb6` — unchanged |
| Config hash | `da8868d1` | `da8868d1` — every new knob is local, none is hashed |
| Trees | 73,675 | 73,675 |
| Spawn | (-44, -124), 28 m | (-44, -124), 28 m, slope 0.1° |
| Lakes | 53 | 53 |

Ground cover is deliberately fewer in the meadow (Stage 5), and that is the
only count that changed.

## Numbers judged on the tour, and what they were before

| Knob | Was | Now | Why |
| --- | --- | --- | --- |
| Sun energy, day | 0.85 | 0.70 | With no ambient underneath, the lit band at 0.85 put #86B04A meadow on screen as neon. The palette was authored for a lit surface landing near 1.0 in total. |
| Sun energy, night (the moon) | 0.04 | 0.32 | The moon lights the lit side alone now. 0.16 was the first value and the night sheet was unreadable. |
| Shade colour, day | — | `#999EDB` | Started at `#8A92C4`; the first forest interior was dark green rather than violet. |
| Shade colour, night | — | `#2E3861` | Started at `#1C2440`; twice lifted with the moon. |
| `color_jitter_value` | 0.05 | 0.07 | Tried 0.10. Per-vertex tint on greedy quads interpolates as soft blotches, not grain; doubling it doubled the blotches. |
| `far_normal_m` | — | 96 | Started at 24; a couple of 8–16 m quads is not a flank. |
| Water | `#4A90A4` α 0.65, roughness 0.15 | `#4C8FBF` α 0.85, matte | Without the highlight and the sky ambient it read as a grey-green sheet over the lake bed. |

## Tuned blind — check in play

Every number above was judged on tour screenshots at one time of day, not in
motion. Things worth a walk before trusting:

- **The far field's altitude bands** (`far_band_step` 0.06). Under six fog
  bands they are subtle in the postcard; they may want to be stronger, or
  fewer fog bands. Both are on F4.
- **The half-lit band** (`BAND_HALF_LEVEL` 0.55 in `Look.RAMP`). It is what
  the side of a terrace and the side of a face get; if faces look flat, this
  is the number.
- **The clouds.** Static, 35 % cover, cut at a hard threshold. Their scale
  was chosen on one screenshot.
- **The rays.** 16 wedges, strongest at dusk. Not yet seen at dusk in play —
  shot 11 is inside a forest.
- **Night.** The moon at 0.32 is a guess between "readable" and "not day".
  Pillar 2 wants darkness to mean something; that argument starts with the
  first enemy, not here.
- **Meadow saturation.** The ground at spawn is a flat, saturated green. A
  poster would likely take it a step toward olive. That is a `Block.COLORS`
  decision, which the plan said to leave alone; it is the first palette
  change to consider.

## Characters

CHARACTER_SECTION

## UI

Fonts fetched (Limelight, Josefin Sans variable 500/600, Poiret One), each
with its OFL under `assets/fonts/`. The chamfer is `corner_detail = 1` on a
`StyleBoxFlat` rather than a two-step notch, which needs no texture. The
nametag keeps its per-peer hue as a darkened outline under paper text. The F4
and F8 panels inherit the theme but were not restyled beyond the title line.
`--shot-ui <label>` is the new dev flag: it shoots the menu and the creation
screen to `build/ui/<label>/` and quits.

Gotcha, recorded by the UI agent: a project theme that references fonts whose
`.import` files are not yet present makes `--import` abort. The `.import`
files are committed, so a fresh clone imports cleanly.

## Departures from the plan

- **Shade values.** The plan's `#5C6BA8` (day) was the *hue*; at that value
  multiplied into the albedo the shade was under 20 % of the lit tone. The
  shipped shade colours keep the hue and sit around 45 %.
- **`source_color` hints were not used.** The plan implied them; the globals
  and sky uniforms are plain `vec4` in LINEAR, converted by `SkyCycle` before
  publishing, so there is one colour-space convention in the game and no hint
  for the Compatibility renderer to ignore.
- **Jitter landed at 0.07, not 0.10** — see the table.
- **Far zone cell** (`far_zone_cell_m`, 24 m) was not in the plan. The flank
  normal fixed the lighting patchwork on the far peaks and exposed the colour
  patchwork under it.

## What is left

- **Trees.** Rule 4 says cones and ziggurats; the spruce is still five tiers
  of squares. Content work, parked behind items 2 and 3 in `IDEAS.md`.
- **The campfire's light** will be the first point light through the ramp.
  `Look.RAMP` handles `!LIGHT_IS_DIRECTIONAL` already; nothing has exercised
  it.
- **Compatibility renderer.** Every shader here was written to compile on
  both, and none has been run on the Linux box. The tour there is the proof.
- **The lean human** is gone. If it is ever wanted back it is a part set,
  not a system.
