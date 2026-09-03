# Light v1 - phase 1 of the reconciliation: real light

Status of the run of `docs/plans/light-v1-tech.md`, written at the end of every
stage so a run that dies at 04:00 still leaves a record.

Branch `feat/light-v1`, from `origin/main` at `d4fb81f`. Night one is setup and
stages 0 to 3; night two is stages 4 to 6, after Marcel's review.

**BLOCKING findings: none so far.**

---

## The box, and the first console line

Every render in this run is ganymede under
`xvfb-run -a -s "-screen 0 1280x720x24"` with `XDG_RUNTIME_DIR` exported to a
writable scratch directory. The first console line of the first tour:

```
Vulkan 1.4.329 - Forward+ - Using Device #0: NVIDIA - NVIDIA GeForce RTX 3070 Ti
```

Forward+ on the GPU, as `CLAUDE.md` says it has been since 2026-08-27. The ALSA
errors under it are the missing sound card and mean nothing.

Tools: `~/bin/godot` 4.7.2, `~/bin/scons`, `~/godot-cpp`, and
`~/.venvs/kubik/bin/python` for anything using PIL - the system `python3` on
this box has no PIL, and `tools/compare_sheets.py` says so in its own header.

---

## The baseline, and the one place the plan is stale

`light-base`, taken 2026-09-03 on `feat/light-v1` at `d4fb81f` before the first
edit.

| | plan says (trees v3) | measured today | |
| --- | --- | --- | --- |
| heightmap hash | `4782edac` | **`4782edac`** | matches |
| spawn | `(-44, -124)` | **`(-44, -124)`** | matches |
| lakes | 53 | **53**, 65,632 m2 | matches |
| trees | 28,383 | **15,218** | **differs** |
| config hash | (not stated) | **`c18af99d`** | trees v3 recorded `3d45b8fc` |

**Why the tree count differs, and why it is not a red gate.** The plan's
baseline row was copied from `docs/status/trees-v3.md`, and one epic has landed
since: `e8fb823`, *trees v4 - every tree at every distance, and no two crowns in
the same place*, merged as `d4eb7f7` before the reconciliation commits. Its
second half is a ruling, not a bug fix: crown radius now comes off the model's
own bounding box and a hashed-priority rule kills any candidate standing within
two radii of an accepted neighbour. That removes trees by design. It touched
`worldgen_config.gd`, which is what moved the config hash from `3d45b8fc` to
`c18af99d`. The heightmap, the spawn and the lakes are untouched by it and all
three still match, which is exactly the signature of a placement change rather
than a terrain change.

So the invariant this run holds itself to is **today's `main`**, not the plan's
transcription of a document written one epic earlier:

> heightmap `4782edac`, spawn `(-44, -124)`, 53 lakes, 15,218 trees, config
> `c18af99d` - reprinted unchanged after every stage.

Recorded under "Questions taken alone" and under "For Marcel".

---

## Stage 0 - Real light: the environment, the sun, the materials

**Shipped.** The poster renderer is out and the engine lights the world.

- `scripts/world/look.gd` rewritten, 1,128 lines to 559. Gone: the three-band
  toon ramp and its `light()`, `poster_band`, `LIT_BLEACH`, `predict()`, the
  banded-fog function and its per-material `FOG` write, the whole poster sky
  shader, the far-field splice with its two asserted anchors and the 4x4 Bayer
  dissolve, `accent_color()`, `shade_ink()` and the contact band. Kept:
  `to_wire()`, `luma()`, the material cache and its mutex, the tree vertex
  splice, `apply_local_knobs()`, `apply_tree_knobs()`.
- New `Look.configure_environment(env, sun)`, called by `SkyCycle.setup()` and
  so by the gallery's setup too - **one decision lights the game and the
  sheets**. It sets: background SKY on a `PhysicalSkyMaterial`; ambient source
  SKY at contribution 1.0; reflected light SKY; tonemap **AgX** at exposure 1.0,
  white 1.0; SSAO on at radius 1.0, intensity 2.0, power 1.5; SSIL, glow,
  adjustments, volumetric fog and SSR explicitly off (they are stages 2, 4 and
  5); the far term as **exponential** fog at day density 0.0006 with
  `fog_aerial_perspective` 0.6 and `fog_sky_affect` 0.3; and on the sun
  `light_angular_distance` 1.0 deg, `shadow_blur` 1.0, PSSM 4 splits,
  `directional_shadow_max_distance` 250 m, fade start 0.8, `shadow_normal_bias`
  2.0, `shadow_bias` 0.05, `light_specular` back to 1.0.
- `OPAQUE_SHADER` is now albedo, roughness, specular, metallic and one emissive
  line. No custom `light()`. The material noise is the bible's own sentence: a
  step up or down on the `grain_sparse` share of half-metre cells, by
  `grain_step`, at every distance - not the old continuous value-and-hue wobble
  faded out by 45 m.
- `WATER_SHADER` is the opaque shader drawn from both sides and through, so
  lakes are flat and matte and nothing is magenta until Stage 5 rebuilds it.
- `FloraModels.SHADER` and `FIREFLY_SHADER` rebuilt on the new base; the plant's
  `fog_dark_mix` is gone (Q14, one surface language) and both emissives now
  multiply by `kubik_warm`.
- `project.godot`: the eight poster globals (`kubik_shade`, `kubik_fog_color`,
  `kubik_fog_start`, `kubik_fog_end`, `kubik_fog_bands`, `kubik_shade_desat`,
  `kubik_fog_dark`, `kubik_water`) deleted; `kubik_night` kept; **`kubik_warm`
  added**, default 1.0, published by `SkyCycle` from the keyframe.
- `WorldgenConfig`: `grain_amount`, `grain_hue`, `contact_band`, `fog_bands`,
  `sky_bands`, `cloud_cover` and `far_dither_m` deleted with their F4 rows;
  `grain_sparse` re-ranged and defaulted to 0.33, `grain_step` added at 0.12,
  both under a `light:` prefix on F4; `ao_strength` 0.45 to **0.0**,
  `canopy_shade` 0.35 to **0.0**, `slope_tint` 0.10 to **0.0**, `aspect_tint`
  0.18 to **0.0**. Every one was LOCAL, and the config hash proves it.
- `TreeField._make_slot()`: **LOD0 casts shadows**, rungs 1 to 3 do not (Q10).
  The rung is read off the slot key, `m<variant>|<lod>`.
- `ColumnJob.shade_ink` and its main-thread capture in `world.gd` deleted with
  `Look.shade_ink()`; the mesher's parameter keeps its default and is inert at
  `canopy_shade` 0.
- The gallery's two sheets replaced `swatches` and `swatch-ramp` - see below.
  `palette-tiers` became a measurement for the same reason.

### The two sheets (Q4)

**Transfer - GATE, and it passes.** Eight authored colours on a private
`unshaded` material, the tonemap forced to LINEAR and glow and adjustments off
for this sheet only and restored after. Tolerance 6 per channel, not widened.

| authored | measured | delta r,g,b |
| --- | --- | --- |
| `#FFFFFF` | `#fefefe` | -1 -1 -1 |
| `#808080` | `#808080` | +0 +0 +0 |
| `#202020` | `#222222` | +2 +2 +2 |
| `#86B04A` | `#86b04b` | +0 +0 +1 |
| `#4E7A32` | `#4f7a32` | +1 +0 +0 |
| `#BFB48C` | `#bfb48c` | +0 +0 +0 |
| `#E0AC7E` | `#e0ac7d` | +0 +0 -1 |
| `#4C8FBF` | `#4d8fbf` | +1 +0 +0 |

**Worst channel delta 2, tolerance 6: PASS.** One conversion between
`push_back` and the frame, exactly as look v2 measured it, through a completely
different renderer. `build/character/light-0/transfer.json`.

**Light - MEASUREMENT, no pass or fail.** The same eight through
`Look.opaque_material()` under the real environment, grain forced off, lit row
normal up and shadow row sky-lit only, at four hours.
`build/character/light-0/light.json`, and `light-{day,evening,dusk,night}.png`.

`day`, t 0.500, elevation +0.944, sun `#fff2d1`, energy 1.00:

| authored | lit | shadow |
| --- | --- | --- |
| `#FFFFFF` | `#ccc8bf` | `#384049` |
| `#808080` | `#817c70` | `#13171c` |
| `#202020` | `#1b1916` | `#020303` |
| `#86B04A` | `#8b9e46` | `#16230a` |
| `#4E7A32` | `#517123` | `#081405` |
| `#BFB48C` | `#b0a37f` | `#252620` |
| `#E0AC7E` | `#c39f77` | `#2e241b` |
| `#4C8FBF` | `#558ca1` | `#061e31` |

`evening`, t 0.740, elevation +0.059, sun `#ebab87`, energy 0.87:

| authored | lit | shadow |
| --- | --- | --- |
| `#FFFFFF` | `#787075` | `#384049` |
| `#808080` | `#342f32` | `#13171b` |
| `#202020` | `#070606` | `#020202` |
| `#86B04A` | `#394314` | `#162309` |
| `#4E7A32` | `#1b290a` | `#081304` |
| `#BFB48C` | `#564838` | `#25261f` |
| `#E0AC7E` | `#674430` | `#2e241a` |
| `#4C8FBF` | `#193953` | `#061e31` |

`dusk`, t 0.790, elevation -0.235, sun `#9aaad0`, energy 0.75:

| authored | lit | shadow |
| --- | --- | --- |
| `#FFFFFF` | `#687689` | `#637083` |
| `#808080` | `#2a323e` | `#272e3a` |
| `#202020` | `#030407` | `#030406` |
| `#86B04A` | `#2f471c` | `#2c4219` |
| `#4E7A32` | `#142b0e` | `#12280c` |
| `#BFB48C` | `#484c46` | `#444741` |
| `#E0AC7E` | `#57483c` | `#534338` |
| `#4C8FBF` | `#0d3e65` | `#0b3a5f` |

`night`, t 0.950, elevation -0.898, sun `#9aaad0`, energy 0.75:

| authored | lit | shadow |
| --- | --- | --- |
| `#FFFFFF` | `#8694a9` | `#576376` |
| `#808080` | `#3b4556` | `#212732` |
| `#202020` | `#05080c` | `#020304` |
| `#86B04A` | `#425f2b` | `#253915` |
| `#4E7A32` | `#1f3c18` | `#0f210a` |
| `#BFB48C` | `#626560` | `#3c3e39` |
| `#E0AC7E` | `#746055` | `#493a31` |
| `#4C8FBF` | `#195586` | `#083154` |

Three things are already worth saying from these four tables, all of them
Stage 1's business and none a Stage 0 failure:

1. **AgX is doing what D40 asked for.** A lit `#FFFFFF` at noon lands at
   `#ccc8bf`, not at `#ffffff`. There is no clipped white anywhere in the
   sheet, which is the "soft highlight roll-off; no clipped whites except the
   sun's disc" line, measured.
2. **The shadow is never black and it is the sky's colour.** Day shadow on
   white is `#384049` - H210 S23 V29, a blue-grey. The bible's day shadow is
   navy `#22294d` (H230 S56 V30). Same family, same value, less saturated. That
   is the RECORD the round 3 report wants and Stage 1's sky grading is what
   moves it.
3. **The hours are still the poster's table.** `night` reads lighter than
   `dusk` because the old keyframe rows put the moon's energy at 0.75 and dusk
   already hands over to it at t 0.79. Stage 1 re-authors the whole table to
   day / evening / dusk / night plus eerie, and these four tables are re-shot
   against it.

### Gates

| gate | result |
| --- | --- |
| full self-test | **green**. Far parity, far slice parity, far layer parity, height tile parity all green; canonical world seed 42, heightmap `4782edac`, spawn `(-44, -124)`, 53 lakes, on both the C++ and the GDScript builders |
| character self-test | **green**, 36 tests |
| worldgen probe | heightmap `4782edac`, spawn `(-44, -124)`, 53 lakes, **15,218 trees**, config **`c18af99d`** - every one identical to `light-base` |
| transfer sheet, `--strict` | **PASS**, worst channel delta 2 of 6 |
| magenta, all 18 tour shots | **0 pixels**. Every shader compiled: the opaque, the water stand-in, the tree splice, the plant and the firefly |

### The sampled checks

Every window is a 9x9 mean, HSV as degrees / percent / percent, on
`build/tour/light-0/`. Coordinates are given so Marcel can re-sample.

| # | kind | shot | region (x,y) | measured | verdict |
| --- | --- | --- | --- | --- | --- |
| 1 | **GATE** | `5-lake` | shadowed ground `(1180,470)` against sky `(200,25)` | shadow H206.5 S23.4 **V17.6**; sky H214.0 S13.7 V43.5 | **PASS** - a shadow outdoors is never black and its hue is **8 degrees** off the sky's, against a 40-degree allowance |
| 2 | **GATE** | `6-postcard` | terrace risers and tops, `x=950`, `y=370..425` | lit tops V 48.4 / 48.6 / 49.0 / 48.7 / 49.1 / 49.2; shadowed risers V 33.6 / 38.2 / 32.4 / 34.7 | **PASS** - **about 15 V** between a riser and its top, against a 10 V floor. Real light makes relief |
| 3 | **GATE** | `5-lake` | flat lit shore, 30x30 at `(430,470)`, `(520,545)`, `(300,650)` | per-pixel V **sd 3.33 / 2.26 / 3.69**, mean V 49.5 / 49.9 / 49.3 | **PASS** - no acne, against a 10 sd ceiling. Measured with the grain **on**, which is strictly the harder test: the grain only adds variance, so grain-off is at most this |
| 4 | **GATE** | `7-forest-interior` | shaded spruce crowns `(600,200)`, `(300,120)`, `(1050,180)` | **V 2.5 / 1.6 / 2.0** | **FAIL** against the V >= 8 floor - see below |
| 5 | RECORD | `1-spawn` | lit meadow `(640,430)`, `(300,470)` | H68.0 S61.2 V42.1; H69.2 S60.9 V35.3 | against `GRASS` `#809945` = H79 S55 V60 |
| 6 | RECORD | `5-lake` | lit snow `(640,110)` | H37.0 S7.6 V61.2 | against `SNOW` `#F2F0E8` = H44 S4 V95; the bible's snow base `#e6dad1` is H26 S9 V90 |
| 7 | RECORD | `6-postcard` | water body `(640,620)`, shallows `(300,500)` | body H183.3 S43.2 V32.9; shallows H173.8 S44.1 V60.4 | against the bible's deep `#265f6e` = H193 S65 V43 and shallow `#42c1c9` = H184 S67 V79 |
| 8 | RECORD | `6-postcard` | sky at 15% frame height `(640,108)` | H213.7 S14.6 V45.6 | the physical sky at the tour's frozen hour, before Stage 1 grades it |

**Check 2 was taken on `6-postcard`, not on `3-forest-slope` as the plan
says.** That shot's vantage is pitched steeply down onto the slope, which
foreshortens every riser to a few pixels; sampling a vertical line through it
returns the ground either side of a riser rather than the riser. `6-postcard`
shows the same terraces side-on at 950 px, and the alternation is unambiguous.
Recorded rather than quietly substituted.

### The one gate that fails: the forest interior

`7-forest-interior`, the shaded side of a spruce crown, measures **V 1.6 to
2.5** against the plan's floor of 8. It is recorded, not reverted, and here is
the whole of the reasoning.

**It is not the ambient.** The property the gate exists to test - D8's "shadows
are never black outdoors; they take the sky colour" - passes decisively in the
open, at check 1: a tree's cast shadow on open ground reads V 17.6 at H206.5
against a sky at H214.0. Sky ambient is on, at full contribution, and it is
doing exactly what pillar 2 asks of it.

**It is the canopy albedo, and a closed canopy.** Two things multiply. The
canopy families are still the poster's, authored near-black to survive a ramp
that lifted them with a shade ink: `CANOPY_A` `#2F4F3E` (V 31), `CANOPY_B`
`#385C48` (V 36), `CANOPY_C` `#4F7A3A` (V 48), `CANOPY_D` `#5F8A46` (V 54). And
a closed forest interior genuinely occludes the sky - the open shadow keeps
about 30% of the sky's value, the crown interior about 8%, with SSAO on top.

**No tunable in range reaches it.** Ambient energy may move +-0.2 (a fifth),
exposure 0.7 to 1.4, sun energy +-30%. Applied together they take V 2.5 to
roughly V 4, still half the floor, and they would blow out the meadow, the
snow and the sky to get there - which fails checks 5 to 8 and pre-empts Stage
1's grading. The failure protocol's rule 3 asks for a revert of "that stage's
visual edit" when no tunable fixes a gate; here that edit is the whole of
Stage 0, and rule 8 says nothing after Stage 0 is judgeable without it.

**Stage 3 is where it is re-measured.** Stage 3 re-authors precisely these four
rows onto the bible's conifer ramp - `CANOPY_A`/`CANOPY_B` to `#575d54`,
`CANOPY_C` to `#7e8986`, `CANOPY_D` to `#9b9f81` - which lifts the canopy
albedo by 13 to 18% in value and, more to the point, is the change the eye
check there is written for ("the conifers are the bible's grey-green, neither
the old near-black nor a lime"). The gate is re-run at Stage 3 with the numbers
put beside these. **If it still fails there, it is a finding for the bible**:
the interior of a real-size closed spruce stand at the tree grain may simply be
a dark place, and "V >= 8 everywhere" may be a rule written for a poster.

### Eye checks

| shot | the sentence | verdict |
| --- | --- | --- |
| `8-meadow-closeup` | cubes read as cubes through SSAO and the step grain, not through a drawn line | **pass**. The ground is a flat field with a scatter of stepped cells and no line anywhere; the contact band that used to draw one under every vertical face is gone |
| `1-spawn` | a tree's shadow lies on the ground | **pass**. The central tree lays a soft shadow across the meadow, and the hillside on the right carries the shadows of its own trees |
| `6-postcard` | the far ranges recede into haze toward the sky, no bands, no stripes | **pass**, and it is the clearest single difference in the whole comparison set. `light-base` has four hard fog steps and an altitude-banded mountain; `light-0` has continuous aerial perspective to the sky |
| `2-summit` | (no sentence in the plan) | **recorded**: at the tour's frozen hour the summit faces away from the sun and the whole shot is a sky-lit shadow, so there is no lit snow in it. The lit-snow RECORD was taken from `5-lake` instead. Stage 1's `20-hour-day` shot re-takes it |

### Tunables moved off their start

None. Every value in `Look.configure_environment()` is the plan's section 3
starting number, and no gate needed one moved.

### One thing Stage 0 had to fix that the plan did not foresee

**The lake drew white.** `lakes.gd` pushed a per-ring *darkening factor* - a
grey - and the colour itself arrived as the global `kubik_water`, published per
hour by `SkyCycle`. Deleting that global with the rest of the poster's publish
path left a factor with no colour behind it, and the first Stage 0 postcard came
back with a pale sheet where the lake is.

Fixed in `lakes.gd` by giving the rings the bible's two lake hexes directly
(`10-color-and-light.md`: Lake `#265f6e` / `#42c1c9`), mapped the way the bible
implies - the rim is the shallows and takes the light teal, the body is deep and
takes the dark one, the shelf sits between. That is the same fact Stage 5 will
compute per pixel from the depth buffer, and these three rings are what it
replaces. The hour tints the water by **lighting** it now rather than by
repainting it, which is pillar 2's "never from repainting a thing".

The tour was re-shot after the fix; every number above is from the re-shot set.

---

## Stage 1 - The hours: four plus eerie, a physical sky, a slow evening

**Shipped.** The keyframe table is the bible's, the sky is the engine's own,
the day is forty minutes with an evening you can watch happen, and eerie is a
flag.

- `SkyCycle.KEYFRAMES` re-authored from dawn / noon / dusk / night to
  **day / evening / dusk / night**. D6 is why: evening and dusk are two hours of
  one evening, "pink first, violet after", and the old table carried the whole
  evening as a single orange row called dusk - so the pink was never a colour
  the world passed through. Each row now carries the sun, its energy, the
  ambient energy, the bible's shade and sky hexes (kept for the record, not
  published), the physical sky's rayleigh, mie, turbidity, energy, ground and
  sky-affect, the fog's colour and density, the height-fog rows Stage 2 reads,
  the volumetric density Stage 2 reads, `warm`, and `saturation`.
- **`EERIE` is one dictionary of overrides applied after the blend** (D7, Q13),
  never a fifth hour: "the difference between night and eerie is only the fog
  and the lights". Its two `_scale` entries multiply rather than replace, so an
  eerie noon and an eerie night are both four times their own fog.
- `HOURS` holds the four elevation anchors, and `time_for_elevation()` inverts
  the arc by bisecting `sun_position()` itself. The tour, the light sheet and
  the keyframe table now all name an hour and get the same sun, so none of them
  can drift when the day length or the warp changes.
- **`keyframe_at()`** blends night to day by daylight, then pulls toward the
  evening set and the dusk set through two shouldered windows peaking at +0.09
  and -0.15. On the morning side the evening set is replaced by a **dawn set**,
  which is the evening set desaturated to 0.70 - the bible gives dawn no hour of
  its own, so this is a silence filled and it is recorded as one.
- **The night sky is generated in code** (Q6): a 1024 x 512 `Image`, the night
  row's own two hexes as the gradient, stars from a two-stage hash, handed to
  `PhysicalSkyMaterial.night_sky` once at setup and never written to `assets/`.
- **`day_seconds` 480 to 2400** (D52), and the warp that makes it mean
  something: `SkyCycle.arc_angle()` slows the sun threefold across the evening
  window (+8 to -12 degrees) and twofold across the dawn window, uniform
  elsewhere, normalised so the circle still closes. Measured: the evening takes
  **360 s of a 2400 s day**. At a uniform speed the same passage takes 133 s.
- `WorldgenConfig.weather` ("clear" or "eerie"), LOCAL and unhashed, with
  `--weather eerie` on the command line; the tour resolves hours by name and a
  shot may carry its own weather.
- The tour gains **`20-hour-day`, `21-hour-evening`, `22-hour-dusk`,
  `23-hour-night`, `24-hour-eerie`**, all five from `6-postcard`'s eye so the
  only thing that differs between them is the light. `11-forest-dusk`,
  `12-meadow-night` and `14-postcard-dusk` take hour names instead of raw times.
- `_test_day_cycle` gains three assertions: the evening window takes 360 to
  480 s, the arc never runs backwards over 2,000 steps, and every hour anchor
  resolves to a time that puts the sun back at it.

### The config hash moved, and it was supposed to

| | Stage 0 | Stage 1 |
| --- | --- | --- |
| heightmap | `4782edac` | **`4782edac`** |
| spawn | `(-44, -124)` | **`(-44, -124)`** |
| lakes | 53 | **53** |
| trees | 15,218 | **15,218** |
| config hash | `c18af99d` | **`1d7c18c7`** |

**What a seed produces is byte-identical; the config fingerprint is not.** The
only hashed field this stage touches is `day_seconds`, which D52 takes from 480
to 2400. It was left in `PROPERTIES` deliberately rather than moved to the
local list to keep the hash still: it does not change what a seed produces, but
two machines running different clocks would disagree about the hour for a whole
session, and the hour is what every light in the world is a function of. That
is exactly the class of disagreement the join handshake exists to refuse.
Stage 0's rule - "if the hash moves, a knob was not local" - is about the knobs
that stage **deleted**, and all of those were local. This is a hashed knob
changing value, which is a different event and a correct one.

### Gates

| gate | result |
| --- | --- |
| transfer sheet, `--strict` | **PASS**, worst channel delta 2 of 6 |
| light sheet | four tables written, `build/character/light-1/light.json`; hours resolved through the anchors |
| full self-test | **green**, including the three new day-cycle assertions |
| character self-test | **green**, 36 tests |
| worldgen probe | the four world numbers unchanged; config hash moved as above |
| magenta, all 23 shots | **0 pixels**, and 0 across the 23 eerie shots too |
| **the evening lasts 360-480 s** | **PASS at 360 s** (self-test, measured through `time_for_elevation`) |

### The hue windows, sky sampled at 15% of frame height on the five hour shots

| hour | window | measured `(640,108)` | verdict |
| --- | --- | --- | --- |
| day | H 0-40 or 180-230 | **H 183.5** S 1.1 V 47.1 | **PASS** |
| evening | H 300-350 or 0-30 | **H 345.9** S 10.1 V 49.6 | **PASS** |
| dusk | H 235-285 | **H 221.2** S 30.1 V 43.4 | **FAIL by 14 degrees** - see below |
| night | H 195-235 | **H 205.0** S 31.2 V 35.4 | **PASS** |
| eerie | S <= 20 | H 202.3 **S 8.7** V 55.9 | **PASS** |

| ordering gate | measured | verdict |
| --- | --- | --- |
| evening pinker than day: S higher and H nearer 320 | evening S 10.1 at H 345.9 against day S 1.1 at H 183.5 | **PASS** |
| dusk darker than evening: V lower | dusk V 43.4 against evening V 49.6 | **PASS** |

| eerie gate | measured | verdict |
| --- | --- | --- |
| no orange anywhere in `24-hour-eerie` (no pixel with H 20-50 and S > 40) | **0 pixels**, against ~3,700 in `20-hour-day` from the same vantage | **PASS** |
| the mushrooms in `12-meadow-night` do not glow under eerie | **0 warm pixels** against **~2,368** in clear weather at the same hour; the amber mushroom band at `(70,395)` goes from H63.9 S70.8 to H173.6 S9.4 | **PASS** |

### The one gate that fails: the dusk sky is blue-violet, not violet

`22-hour-dusk`'s sky measures **H 221.2 S 30.1**, against the bible's violet
`#63559e` (H 252) to `#a281c3` (H 270) and the plan's window of 235 to 285.

**Everything permitted was tried, and it is recorded as a finding rather than
chased further.** A fast sky probe was written for this
(`build/` is not involved; it renders the environment alone at each hour in
about thirty seconds, so a grading change could be judged without a
twelve-minute tour) and it walked the levers:

| what was tried | dusk sky hue |
| --- | --- |
| the plan's starting values (`fog_sky_affect` 0.3, turbidity 18, sky energy 0.80) | H 208.6 |
| `fog_sky_affect` per hour, dusk at 0.60 - the top of its tunable range | H 218.3 |
| plus turbidity 18 to 26 (+44%, inside the +-50% the table allows) and sky energy 0.80 to 0.45 | **H 221.2** |

**Why it stops there.** `PhysicalSkyMaterial` is a daylight scattering model,
and its zenith and anti-solar sky sit near H 200 to 210 whatever
`rayleigh_color` is set to - the tint biases the scattering, it does not paint
the sky. The violet in this hour comes from the **fog**, whose colour is the
bible's own `#736eb7` (H 244) and which is not a tunable, so the sky's hue is
pinned to a blend of about H 205 and H 244 at a mixing weight capped at 0.6.
That arithmetic lands at H 221, which is what was measured.

Reaching H 244 needs either a `fog_sky_affect` above its range or a painted
term on top of the physical sky, and pillar 2 forbids the second in as many
words: "Real sky with cubic clouds (D18). **No painted skies.**"

**The eye check for this hour passes anyway**, which is the interesting part:
`22-hour-dusk` reads as violet - the ranges are mauve-violet, the fog is
violet, the sun is gone and the sky is still lighter than the ground. What is
blue is the sky alone. Recorded for the bible below.

### Eye checks

| shot | the sentence | verdict |
| --- | --- | --- |
| `21-hour-evening` | the whole world is tinted, shadows are magenta not grey | **pass**. Every range, the fog and the ground are pink-mauve; this is the frame where D6's "the world is tinted as a whole" is most obviously true |
| `22-hour-dusk` | violet, the sun gone, the sky still lighter than the ground | **pass** - see the note above about the sky's own hue |
| `23-hour-night` | slate, not black, stars visible, the moonlit hillside is still a hillside | **pass**. The generated star field reads, the ranges keep their shape, and nothing is crushed |
| `24-hour-eerie` | the life taken out | **pass**, and against `20-hour-day` from the same eye it is the clearest pair in the set |

### Tunables moved off their start

| knob | start | now | judged on |
| --- | --- | --- | --- |
| `fog_sky_affect` | 0.3, one value for every hour | **per hour: day 0.30, evening 0.60, dusk 0.60, night 0.50, eerie 1.00** | the five hour shots. At one flat 0.3 the evening sky measured H 56.6 - an olive grey - because the physical sky's own scattering dominated the hour's grading. Per hour it measures H 345.9. Eerie at 1.00 is the plan's own number (section 1.2) |
| dusk `sky_turbidity` | 18.0 | **26.0** (+44%, inside +-50%) | `22-hour-dusk`, and the sky probe: H 218.3 to H 221.2 |
| dusk `sky_energy` | 0.80 | **0.45** | the same, to let the violet fog carry more of the sky |

---

## Questions taken alone

Rule 7 of the failure protocol: the conservative reading, written down.

1. **The plan's baseline tree count is one epic stale.** It asks for 28,383
   trees; `main` produces 15,218 because trees v4's crown-separation ruling
   (`e8fb823`) landed after trees v3 and removes trees by design. Taken: today's
   `main` is the baseline, and the four numbers plus the config hash `c18af99d`
   are what every stage must reprint. The three numbers the plan names that do
   NOT depend on placement - heightmap, spawn, lakes - all match it exactly,
   which is what makes this a stale transcription rather than a red gate.
2. **The plan's stream-probe command does not exist.** Section 2 gives
   `<godot> --headless --path . --script scripts/tools/stream_probe.gd -- --seed 42`;
   `stream_probe.gd` is a `class_name StreamProbe` that `Game` instantiates, not
   a `SceneTree`, so Godot answers *"Can't load the script ... as it doesn't
   inherit from SceneTree or MainLoop"*. Taken: the probe is driven the way
   `game.gd:229` drives it, `<godot> --path . -- --stream-probe --seed 42`,
   under Xvfb because it needs a frame.
3. **The light sheet's shadow row has no wall.** The plan asks for "a quad
   standing in the shadow of a wall the sheet builds". Taken: the existing
   geometry - the shade row's normal faces the camera, and the sun's z is
   negative at every hour, so the quad never has the sun on it and is lit by
   sky ambient alone. Under a directional sun that is what a cast shadow IS for
   a Lambert surface, and it needs no caster; a built wall would measure the
   same sky-lit surface with the wall's own occlusion added on top, which is a
   worse measurement of the thing the gate is about. Smaller change, fewer
   files.
4. **`palette-tiers` lost its predictor.** It held every race's five tiers
   against `Look.predict()` at a tolerance of 6, and there is no prediction
   under real light. Taken: it becomes a measurement in the light sheet's shape
   (authored against measured), and the gate that still covers those colours is
   the transfer sheet, which measures the conversion they travel through. The
   value-tier ladder under it is arithmetic on authored hexes and never needed a
   frame.
5. **The dusk sun is "none" in the bible and 0.18 here.** The hours table says
   of the dusk sun: "none; fire takes over #f5c05e". Taken as a very low energy
   rather than as zero, because `_test_day_cycle` asserts the light never goes
   out - and it is right to: a directional light at zero energy is a different
   frame from one at 0.18, not a darker one, and there is no fire in the game
   yet to take over (that is phase 2). At ambient 0.50 against sun 0.18 the sky
   does the lighting, which is what "the sun is gone" reads as.
6. **`day_seconds` stayed hashed.** D52 changes it and the config fingerprint
   moves with it. Moving it to the local list would have held the hash still,
   and was rejected: two machines running different clocks would disagree about
   the hour for a whole session. See the Stage 1 note.
7. **Dawn is the evening set desaturated to 0.70.** The bible's hours table has
   four rows and none of them is sunrise. Filled rather than left, because the
   morning side of the arc has to blend toward something; recorded as a silence.
8. **`far_grain` survives as a knob.** The plan deletes `far_field_code()`, the
   splice anchors, the Bayer function and `far_dither_m`, and says `far_grain`
   "stays as an optional uniform on a copy of the opaque material, default 0".
   Taken: the uniform and its lattice code live in `OPAQUE_SHADER` itself,
   inert at 0, and `far_field_material()` is a second `ShaderMaterial` on the
   same source - which keeps the draw-group seam the far field needs and keeps
   `config.far_grain` meaningful. `far_grain` is on neither this stage's nor
   Stage 3's delete list.

---

## For Marcel

1. **The plan's baseline table should be corrected to trees v4's numbers**
   before night two: 15,218 trees, config `c18af99d`. See question 1.
2. **The plan's stream-probe command should be corrected** to
   `--path . -- --stream-probe`. See question 2.
3. **The dusk sky is the one Stage 1 gate that fails**, at H 221 against a
   window of 235-285, and it cannot be fixed with anything the plan permits.
   The ruling is yours: widen the window, move the bible's dusk sky hex toward
   what a physical sky can do, or accept a painted term over the physical sky -
   which pillar 2 currently forbids. See the Stage 1 note for the three
   gradings tried and what each measured.

---

## For the bible

Numbered in the words `ROUND-3-BRIEF.md` asks for, so the report can lift them.

**B1. A physical sky cannot be made violet at dusk, and the bible's dusk sky
hexes assume a painted one.** `10-color-and-light.md` gives dusk a sky of
`#63559e` (H 252) to `#a281c3` (H 270). `PhysicalSkyMaterial` graded as far as
the plan allows - rayleigh and mie tinted to those two hexes, turbidity +44%,
sky energy down to 0.45, `fog_sky_affect` at the top of its range - measures
**H 221**. Its zenith and anti-solar sky sit near H 205 whatever the tint is
set to, because the tint biases scattering rather than painting the sky, and
the violet reaching the frame comes from the fog. The hour still READS as
violet, because the ranges and the fog carry it; it is the sky alone that stays
blue. Either the dusk sky rows are starting points that land at H 221 and the
bible should say so, or the sky needs a painted term, which pillar 2 forbids in
as many words ("No painted skies"). **The evening's pink survives the same
treatment and lands at H 346**, so this is specific to violet at that
elevation and not a general failure of the approach.

**B2. The bible gives dawn no hour.** Its hours table has four rows - day,
evening, dusk, night - and the world passes through sunrise twice a day. This
run fills the silence with "the evening set desaturated to 0.70" and records
it; the bible should either name a dawn or say in writing that dawn is a paler
evening.

**B3. "The base of things `#101f26`" is not reproduced.** The eerie entry asks
for it. It is a per-material floor rather than a light - it repaints a
material, which pillar 2 forbids - and there is no mechanism in phase 1 that
could apply it without becoming exactly the kind of paint this phase removed.
Recorded as unbuilt.

**B4. A day's night is half of it, not fifteen minutes.** The plan's prose says
"night is about 15 minutes" of a forty-minute day. A circular sun arc is
symmetric by construction, so with `day_seconds` 2400 and the warp the sun is
below the horizon for **1,236 s, about 20.6 minutes**. Getting to 15 would need
an asymmetric arc, which nothing decides. The bible's own rule - "the night
long enough to want the fire" - is satisfied either way; the 15-minute figure
should be dropped or the arc should be decided.
