# Light v1 - phase 1 of the reconciliation: real light

Status of the run of `docs/plans/light-v1-tech.md`, written at the end of every
stage so a run that dies at 04:00 still leaves a record.

Branch `feat/light-v1`, from `origin/main` at `d4fb81f`. Night one is setup and
stages 0 to 3; night two is stages 4 to 6, after Marcel's review.

**BLOCKING findings: none.** One gap, at the top because it is the thing to
read first: **the stream probe did not complete in three attempts (45, 68 and
52 minutes, idle box), so night one has no cost line.** The plan's 45 ms rule
and its Q10 tree-shadow gate are unmeasured. See the end of Stage 2.

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

## Stage 2 - Fog's three jobs

**Shipped.** Fog lies in the valley, pools at night, and hides the tops under
eerie. Two of the four sampled gates pass, one passes with a caveat, one fails
and is recorded with the measurement that explains it.

- `Look.configure_environment()`: **volumetric fog on**, length 1,500 m,
  density 0.01, anisotropy 0.35, `sky_affect` 0.5, `detail_spread` 2.0. The far
  exponential term stays what it was: aerial perspective and nothing else.
- **`World.fog_floor_m` / `fog_floor_at`** - the altitude of the valley floor
  near the player and where on the map it is. The nearest lake within 600 m
  wins outright (a lake IS the floor, and its surface is flat and known);
  failing that, the lowest ground in a 300 m disc. One strided pass over the
  coarse heightmap answers both, once a second, every eighth cell - an
  exhaustive 600 m scan is 360,000 cells of GDScript on the main thread to
  answer a question whose answer moves at walking pace.
- `SkyCycle.apply()` writes `fog_height` (floor + the hour's offset),
  `fog_height_density`, `volumetric_fog_density` and `volumetric_fog_albedo`
  from the keyframe. With no world to ask - a gallery sheet, a self-test - the
  height term stays off, which is right: a swatch pad has no valley.
- **New `scripts/world/valley_fog.gd`** (`ValleyFog`, a child of `World`):
  three `FogVolume` boxes 600 x 12 x 600 m stacked from the tracked floor, plus
  a fourth 200 m lid under eerie. **The volumes move with the floor and never
  with the player** - that is the whole design and the easy thing to get wrong,
  because parenting them to the camera is a two-line implementation that
  produces exactly the artefact the feature exists to avoid. At night the stack
  drops 6 m, scaled by `night_amount` so it slides rather than snapping.
- The transfer sheet now switches the **atmosphere** off as well as the tonemap
  and the grade, and restores it after: with volumetric fog on, the worst
  channel delta measured **4** instead of 2 - inside the tolerance, but
  measuring the air rather than the conversion. With it off: **delta 1**, the
  cleanest reading of the run.

### Gates

| gate | result |
| --- | --- |
| full self-test | **green** |
| character self-test | **green**, 36 tests |
| worldgen probe | four world numbers unchanged, config `1d7c18c7` unchanged from Stage 1 |
| transfer sheet, `--strict` | **PASS**, worst channel delta **1** of 6 |
| magenta | **0 pixels** across 23 clear shots and 23 eerie shots |

| # | kind | shot | measured | verdict |
| --- | --- | --- | --- | --- |
| 1a | **GATE** | `20-hour-day`, farthest range `(700,70)` against the sky above it `(700,12)` | range **S 9.2** (<= 25), **V 46.3** against sky **V 47.0** - a difference of **0.7** against an allowance of 12 | **PASS**. The far range fades to the sky almost exactly |
| 1b | **GATE** | the nearest range `(1180,160)` against the farthest | near **S 10.4**, far **S 9.2**: a difference of **1.2**, against a required 10 | **FAIL as written** - see below |
| 2 | **GATE** | `21-hour-evening`, a vertical line at `x=640` from the lake surface up | V 17.7, 17.9, 18.0, 17.8, 18.8, [22.9], 20.9, 20.6, 20.7, 20.7, 21.2, 23.2, 27.9 from `y=640` up to `y=300` | **PASS with a caveat**. Non-decreasing from 17.7 to 27.9 apart from 0.2-unit noise; the bracketed 22.9 at `y=470` is the lake's bright shallows rim, not a band. The lowest band (20.6) is lighter than the water under it (17.7) |
| 3 | **GATE** | `23-hour-night` lake shore `(640,430)` against `20-hour-day` | day shore **V 39.2**, day sky **V 47.0**; night shore **V 17.2**, night sky **V 28.4**. Sky difference 18.6, so the gate wants night shore >= 39.2 - 18.6 + 6 = **26.6**; measured **17.2** | **FAIL** - see below |
| 4 | **GATE** | `2-summit` under eerie: the peak's top against the sky beside it | peak tip **V 50.6** against sky **V 54.1**, a difference of **3.5**; peak upper **V 55.0** against sky **V 54.0**, a difference of **1.0**. Allowance 4 | **PASS**. The summit is not visible |

**Gate 1b, and why the gate is the thing that is wrong.** It asks the nearest
range to hold 10 more points of saturation than the farthest. At `6-postcard`'s
eye BOTH ranges are hundreds of metres out and already deep in the haze, and
the rock palette is authored near **S 10** - so there are not 10 points of
saturation in the material to lose. Measured against the nearest terrain
actually in frame, the lake at `(640,620)` at **S 35.3** against the far range's
**S 9.2**, the difference is **26 points** and distance reads emphatically.
Recorded as a gate written for the old saturated poster palette rather than as
a fog failure.

**Gate 3, and the lever that runs backwards.** Fog's second job is pooling that
is visible against dark ground, so the obvious response to a shore that is too
dark is more fog. Three night densities were shot and measured:

| night `vol_density` | lake shore V |
| --- | --- |
| 0.020 (the plan's) | the ranges vanish entirely; frame unusable |
| 0.014 | **15.4** |
| 0.009 (shipped) | **17.2** |

**Denser fog makes this hour darker, not milkier.** At a 0.12 moon and a 0.25
ambient there is almost no light in the air to scatter, so extra density only
extinguishes the brighter background behind it. The lever this actually wants is
LIGHT IN THE FOG rather than more of it - the night keyframe's ambient energy
(0.25, tunable to 0.45) and `volumetric_fog_ambient_inject` (already raised from
the plan's 0.2 to 0.5 this stage) both move it. Both are night two's, because
the lens changes the night frame anyway. Shipped at the value that measures
best of the three; the gate still fails by 9.4 V and is not claimed as a pass.

**Gate 4's caveat.** It passes at 3.5 against an allowance of 4, but the same
pixels in CLEAR weather measure a difference of 4.6 - so the gate barely
separates the two at this vantage, because `2-summit` looks steeply up at a
backlit peak that is already hazy. By eye the two frames are not close: the
eerie one is a flat grey sheet with the peak's silhouette nearly gone. A
vantage that looks ACROSS at a summit would test this properly and none exists.

### Eye checks

| shot | the sentence | verdict |
| --- | --- | --- |
| `4-valley-floor` | three bands lying in the bottom, each lighter than the one below, and they lie in the valley, not around the camera | **pass on the second half, fail on the first.** The fog is unambiguously a thing lying in the valley: the foreground meadow is clear and lit, and the far half of the same flat field goes into a bank. It does NOT read as three layers - at these densities the stack reads as one graded bank. Recorded |
| `6-postcard` | no bright sky behind a grey peak | **pass.** `fog_aerial_perspective` 0.6 with the per-hour `fog_sky_affect` fades the ranges toward the sky in their own direction; the far range and the sky above it differ by 0.7 V (gate 1a). The cylindrical fog term the plan held in reserve for this is **not needed and stays dropped** |

### Tunables moved off their start

| knob | start | now | judged on |
| --- | --- | --- | --- |
| **`ValleyFog.BAND_DENSITY`** | 0.08 / 0.05 / 0.03 | **0.0020 / 0.00125 / 0.00075** - the plan's 8:5:3 ratio, scaled by about 1/40 | `20-hour-day` and `4-valley-floor`. A `FogMaterial` density is extinction per unit length and a band is 600 m across, so the plan's 0.08 is an optical depth near **fifty** - not a layer of mist, a wall. The first Stage 2 tour came back with `20-hour-day` a featureless brown haze, no lake and no ranges. These give the bottom band an optical depth near 1.2 across its own width |
| `ValleyFog.EERIE_LID_DENSITY` | 0.06 | **0.007** | the same arithmetic over the lid's 200 m box |
| `volumetric_fog_ambient_inject` | 0.2 | **0.5** | the evening and dusk shots. At 0.2 the bands went to V 10-18 at the hours where the sun is low and swallowed the pink and violet the hour had just been graded to |
| day `fog_height_density` | 0.002 | **0.001** (x0.5, in range) | `20-hour-day`. The bible's day fog is the one hour explicitly not a bank: "thin, valley bottoms only, mornings" |
| day `vol_density` | 0.010 | **0.005** (x0.5, in range) | the same |
| evening `vol_density` | 0.014 | **0.007** | `21-hour-evening`: midground V 18.3 to 27.9 |
| dusk `vol_density` | 0.018 | **0.008** | `22-hour-dusk`: midground V 10.2 to 19.1 |
| night `vol_density` | 0.020 | **0.009** | `23-hour-night`: see the table under gate 3 |

### The fog pass (after Stage 3, on Marcel's judgement of the Stage 2 shots)

**The call:** from the postcard vantage the fog was too thick at day, evening,
dusk and night - the ranges and the sky drowned and the hours lost the colour
Stage 1 had given them. The bible agrees: day fog is "thin, valley bottoms only,
mornings", and D40's fence says the lens never flattens the decided hours. Eerie
was right and is untouched.

One pass, everything toward the low end of its own range:

| knob | Stage 2 | after the pass |
| --- | --- | --- |
| far `fog_density`, day / evening / dusk / night | 0.0006 / 0.0009 / 0.0012 / 0.0009 | **0.0003 / 0.00045 / 0.0006 / 0.00045** (x0.5, the low end) |
| `fog_height_density`, day / evening / dusk / night | 0.001 / 0.002 / 0.003 / 0.004 | **0.0005 / 0.001 / 0.0015 / 0.002** (halved) |
| `vol_density`, day / evening / dusk / night | 0.005 / 0.007 / 0.008 / 0.009 | **0.005 / 0.005 / 0.006 / 0.006** |
| `ValleyFog.BAND_DENSITY` | 0.0020 / 0.00125 / 0.00075 | **0.0010 / 0.000625 / 0.000375** (halved) |
| `volumetric_fog_length` | 1,500 m | **1,200 m** |

**Measured, before and after, on the five hour shots.** The midground at
`(640,300)` is the number that says how much of the frame the fog has eaten:

| hour | midground V before | after | sky hue before | after |
| --- | --- | --- | --- | --- |
| day | 38.3 | **37.9** | H 43.5 S 4.1 | H 43.1 S 4.3 |
| evening | 27.9 | **28.3** | H 355.3 | **H 357.9** |
| dusk | 19.1 | **19.7** | H 224.6 | **H 225.3** |
| night | 15.6 | **17.9** | H 205.3 | **H 204.9** |
| eerie | 38.6 | **39.0** | S 8.9 | S 8.9 |

**Gate count is unchanged** - 1a passes before and after (far range within 0.5 V
of the sky above it, against an allowance of 12), 1b and 3 fail before and
after for the reasons already written up - so the tie is broken on the eye, and
on the eye the thinner set is plainly the one: at day the ranges have their
shape back and the lake is teal rather than a brown wash; at evening the whole
frame is pink again with the peaks legible behind it, which is what Stage 1
measured and Stage 2 had buried. Kept.

The night pool (gate 3) is 4.2 V under its target after the pass against 3.4 V
under before - marginally worse on that one gate, and it is the gate whose
lever is light in the fog rather than fog, as the table above it records.

### The Q25 notch, and what it taught (night two, before Stage 4)

Q25 binds "the day and evening band densities at 0.6 of the fog-pass values,
kept if gate 1a still passes and the mountains and the sky read in
`20-hour-day`". Implemented as a per-hour **`band_scale`** row so the notch
touches the VALLEY BANDS alone and not the ambient volumetric field they sit in
- which is the literal reading and the smaller change. Day and evening 0.6;
dusk and night keep 1.0, because those are the hours the bands are for; eerie
keeps 1.0, because Marcel's night-one review said eerie reads right.

**Kept - and it changed almost nothing, which is the finding.**

| | before (`light-3`) | after (`light-3b`) |
| --- | --- | --- |
| `20-hour-day` far range `(700,70)` | H 39.8 S 9.9 **V 47.0** | H 39.9 S 9.9 **V 47.0** |
| `20-hour-day` sky above it `(700,12)` | H 46.0 S 3.5 **V 47.5** | H 46.0 S 3.5 **V 47.5** |
| `20-hour-day` near range `(1180,160)` | H 32.1 S 11.4 V 41.3 | H 32.0 S 11.4 V 41.3 |
| `20-hour-day` midground `(640,300)` | H 45.9 S 10.7 **V 37.9** | H 45.0 S 10.7 **V 37.9** |
| `21-hour-evening` midground `(640,300)` | H 16.1 S 12.6 **V 28.3** | H 16.3 S 12.6 **V 28.2** |

Gate 1a still passes - the farthest range sits **0.5 V** from the sky directly
above it against an allowance of 12, and its saturation is 9.9 against a
ceiling of 25 - and the mountains and the sky read. So the notch is kept.

**But the lakeside haze is not the bands.** Halving the bands again moved every
sampled window by under one unit, because a band is a 600 x 12 x 600 m box
sitting at the tracked valley floor, and what hazes the postcard vantage is the
**ambient volumetric field** over 1,200 m plus the exponential far term - two
knobs Q25 does not name. That is worth knowing before anyone spends another
pass on the bands: they are doing very little at any vantage that is not
standing in one. Left as a finding rather than widened into a change Q25 did
not authorise.

### Q25 extended: the two knobs that actually do haze the postcard

The notch above changed nothing because the bands are not what hazes a lakeside
vantage. Q25 was extended on that finding, after Stage 4 was pushed: **the
ambient volumetric density and the far exponential density, at day and evening
only, at 0.6 of the fog-pass values.** Dusk, night and eerie untouched.

| knob | before | after |
| --- | --- | --- |
| day `fog_density` | 0.0003 | **0.00018** |
| day `vol_density` | 0.005 | **0.003** |
| evening `fog_density` | 0.00045 | **0.00027** |
| evening `vol_density` | 0.005 | **0.003** |

**Kept. Both conditions met.**

| | before (`light-4`) | after (`light-4c`) |
| --- | --- | --- |
| `20-hour-day` far range `(700,70)` | H 38.2 **S 9.6 V 41.6** | H 38.8 **S 8.8 V 38.1** |
| `20-hour-day` sky above it `(700,12)` | **V 41.3** | **V 39.8** |
| gate 1a: range against the sky above it | 0.3 V | **1.7 V** (allowance 12) |
| `20-hour-day` near range `(1180,160)` | H 31.8 S 11.1 V 33.6 | H 25.4 **S 14.0** V 30.0 |
| `20-hour-day` midground `(640,300)` | V 35.7 | V 30.5 |
| `21-hour-evening` midground | V 27.4 | V 24.8 |
| `4-valley-floor` bank `(640,250)` | V 42.9 | **V 39.1** |
| `4-valley-floor` foreground `(640,600)` | V 40.0 | **V 41.0** |

Gate 1a still passes at 1.7 V against an allowance of 12, at S 8.8 against a
ceiling of 25. **The mountains and the sky read**, and better than before: the
near range's saturation goes UP, 11.1 to 14.0, and by eye the right-hand slope
recovers its rock and its treeline where the previous frame had them under a
wash. **`4-valley-floor` keeps its bands** - the bank is still there at V 39.1
against a clear, lit foreground at V 41.0, and trees still recede into it.

**Thinning fog made the frame DARKER, not brighter, and that is worth knowing.**
Every sampled window dropped 3 to 5 V. The volumetric field is lit by the sky
ambient, so it was adding scattered light as well as veiling contrast; less of
it means less light in the air. That is the right trade here - the contrast it
was costing was worth more than the light it was adding - but it means the fog
knobs and the exposure are coupled, and anyone reaching for exposure next
should know the fog moved first.

### The hour hue windows, re-measured with fog on

Stage 1's windows were measured before there was fog in front of them. The
plan's sample point - the sky at 15% of frame height - is **fog rather than sky**
on this vantage from Stage 2 onward, so both are given.

| hour | at 15% height `(640,108)` | at the clearest sky `(700,12)` | Stage 1 verdict | now |
| --- | --- | --- | --- | --- |
| day | H 43.5 S 4.1 | H 46.5 **S 3.4** | PASS | the sky is **neutral** at S 3.4, where hue is not a meaningful quantity; it reads H 46.5 against a window of 0-40 or 180-230. Recorded as undefined rather than claimed either way |
| evening | H 355.3 | **H 350.2** | PASS | **PASS** (300-350, at its edge) |
| dusk | H 224.6 | H 225.3 | FAIL | **FAIL**, unchanged: finding B1 |
| night | H 205.3 | **H 205.1** | PASS | **PASS** |
| eerie | S 8.9 | **S 9.1** | PASS | **PASS** |

### The cost line was not measured, and that is the one gap in night one

**The stream probe did not complete in three attempts**, at 45, 68 and 52
minutes of wall clock, on an idle box with nothing else running. It was
progressing throughout - 80% CPU and 65% GPU, memory stable, no error - and its
output is buffered to the file until exit, so a killed run leaves nothing. The
probe's own note records a 25-minute run; this build is slower, and the honest
guesses are trees v4's fourth level-of-detail rung, LOD0 trees casting real
shadows (Q10), SSAO and a 250 m four-split shadow map, all of which arrived
after that note was written.

**What this means.** The plan's rule 6 - worst frame under 45 ms, and the
shrink order if it is over - **could not be evaluated for night one**. The
plan's own Q10 gate on tree shadows is unmeasured with it. It is not BLOCKING
for the work, because every visual gate stands on its own, but it is the number
Marcel most needs before night two turns on glow and SSR, and it is the first
"For Marcel" item.

---

## Stage 3 - The palette, and the paint stripped from both legs

**Shipped.** The bible's three named materials are in the table, five paint
operations are gone from the C++ and its GDScript twin in one commit, and the
far parity tests compare the stripped legs and find them identical.

- **`Block.COLORS`**: `STONE` `#ADA9A1` to **`#5E524B`** and `SNOW` `#F2F0E8`
  to **`#E6DAD1`** - the bases of the bible's Rock and Snow, each "one body
  colour in three shades" whose other two shades now come from light and from
  the per-cube step (Q5). Every other row is a **bible silence** and is kept
  exactly as look v2 authored it, marked as such in its own comment.
- **`TreePalette.FAMILIES`**: the four canopy indices map onto the bible's
  conifer ramp - `CANOPY_A` and `CANOPY_B` to the shade `#575D54`, `CANOPY_C`
  to the base `#7E8986`, `CANOPY_D` to the light `#9B9F81`. The pack's
  inner/outer needle distinction survives as **material** and not as baked
  light. `SNOW` follows `Block.SNOW`.
- **The C++ lost the paint** (Q15): `aspect_curve`, `aspect_shade`,
  `block_jitter`, `treeline_band`, `band_m_at` and `band_color` are gone from
  `far_build.cpp`; `far_band_m`, `far_band_step`, the three `far_riser_*`,
  `slope_tint`, `aspect_tint`, the three `color_jitter_*`, `SUN_ASPECT_*` and
  the two tint salts left `far_world.h` and its marshalling; four of the five
  `c_*` micro-gate bindings left `far_mesher`. `c_vertex` survives and is now
  one line: `Look.to_wire` on the zone colour.
- **The GDScript twin lost it in step**, in the same commit, so the parity
  tests never saw the two legs disagree.
- `Block.jitter`, `aspect_shade`, `aspect_curve`, `SUN_ASPECT` and the salts are
  deleted outright; `flora_models.gd`'s boulder keeps its lit-side plane and
  owns the constant now.
- `chunk_mesher.gd` emits `Look.to_wire(Block.color_of(id))` and nothing else.
  `_under_canopy` and the canopy scan are gone; **`ColumnJob` stopped calling
  `TreePlacement.cover_column()` on the streaming path**, which was a full
  candidate walk per column feeding a value nothing reads any more.
  `cover_column()` itself stays - the worldgen probe measures grove density with
  it and the self-test proves it deterministic.
- Eleven config knobs deleted with their F4 rows, their `to_dict` entries and
  their places in the two far-mesher marshalling lists. **All were LOCAL and
  the config hash did not move**: `1d7c18c7` before and after.

### The library was rebuilt inside the run

`~/bin/scons platform=linux target=editor custom_api_file=~/godot-cpp/extension_api.json -j6`,
clean, no warnings, 17:49. The self-test's `far dispatch` line reads **"c++
present, three legs, meshes identical"**, so the rebuilt library is the one
being tested.

### Q19 answered, on ganymede

The plan asks whether the 15 last-bit colour parity misses the Windows
self-test reports vanish once the paint is at identity. Stripped rather than
parked, on ganymede:

```
far zone parity: 10000 samples x 3 functions, all identical
far parity: 5 checks, colours compared
far slice parity: 4 checks, c++ compared
far layer parity: the geomorph CHANGES the mesh, the detail layer CHANGES the mesh, c++ compared
```

**Zero misses.** The parity harness went from seven compared functions to three
because four of them no longer exist on either leg; what is left is the whole
of what a far vertex travels through. **The Windows count is still Marcel's to
take** after the Windows rebuild - it is the first "For Marcel" item - but the
ganymede result says the hazard was the paint.

### Gates

| gate | result |
| --- | --- |
| full self-test | **green**, with the rebuilt library |
| character self-test | **green**, 36 tests |
| worldgen probe | heightmap `4782edac`, spawn `(-44, -124)`, 53 lakes, 15,218 trees, config **`1d7c18c7`** - unchanged |
| transfer sheet, `--strict` | **PASS**, worst channel delta **1** of 6 |
| magenta | **0 pixels** across all 23 shots |

| # | kind | shot | measured | verdict |
| --- | --- | --- | --- | --- |
| 1 | **GATE** | `2-summit` lit snow `(900,300)` | **H 34.7 S 5.5** V 59.7 | **PASS** - H within 15 of 26 (window 11-41), S <= 15 |
| 2 | **GATE** | `2-summit` lit rock flank `(700,500)` | **H 39.0 S 11.1** V 37.9 | **PASS** - H within 20 of 22 (window 2-42), S <= 30 |
| 3 | RECORD | `7-forest-interior` lit conifer `(700,430)` against `#9b9f81` (H68 S22 V62) | H 100.0 S 11.1 **V 10.6** | the hue is the conifer family's; the value is a forest interior's |
| 4 | RECORD | the same, shaded crown `(600,200)` against `#575d54` (H100 S9 V36) | **H 105.7 S 9.8** V 8.7 | the hue lands within 6 degrees of the authored shade |

### The Stage 0 gate that failed, re-measured

Stage 0's `7-forest-interior` gate wanted a shaded spruce crown at V >= 8 and
measured **V 2.5 / 1.6 / 2.0** on the old near-black canopy. On the bible's
conifer ramp, at the same three pixels:

| pixel | Stage 0 | Stage 3 |
| --- | --- | --- |
| `(600,200)` | V 2.5, H 164.6 | **V 8.7**, H 105.7 |
| `(300,120)` | V 1.6, H 0.0 | **V 4.3**, H 24.0 |
| `(1050,180)` | V 2.0, H 2.3 | **V 7.1**, H 30.0 |

**Three to four times the value, and a hue that means something.** At Stage 0
those three hues - 164, 0, 2 - were noise off a near-black pixel; the brightest
sample now clears the gate outright and reads as the conifer's own grey-green.
The other two do not, and the Stage 0 argument stands for them: a closed spruce
interior at real tree size genuinely occludes the sky, and "V >= 8 everywhere
in a wood" may be a rule written for a poster. Logged as B5 for the bible.

### Eye checks

| shot | the sentence | verdict |
| --- | --- | --- |
| `8-meadow-closeup` | a flat field is flat with a scatter of stepped cubes, and a wall reads by its own shadow, not by a painted band | **pass**. Unchanged from Stage 0, which is the point: the mesher stopped painting and nothing about the ground got worse |
| `9-treeline` | the far flank has no contour stripes | **pass**. The stepped rock either side of this shot is clean; the altitude bands that drew contour lines across a far mountain are gone from both legs |
| `7-forest-interior` | the conifers are the bible's grey-green, neither the old near-black nor a lime | **pass**. The crowns read grey-green: the lit crown at H 100.0 S 11.1 and the shaded at H 105.7 S 9.8, against an authored shade of H 100 S 9 |

### Column job, before and after

| | trees v3 | light v1 Stage 3 |
| --- | --- | --- |
| gen per chunk, on workers | 9.51 ms | **3.06 ms** |
| main-thread upload per chunk | 0.23 ms | **0.10 ms** |
| chunks at spawn | 2,369 | 2,222 |
| flora per column, on workers | - | 8.62 ms |

Read with care: trees v3's line was measured on a different config (trees v4 has
landed since) and on a different view preset, so this is **not** a controlled
before/after and is not claimed as one. What can be said is that no cost was
added: the mesher stopped sampling AO corners at `ao_strength` 0, stopped
computing aspect and jitter per vertex, and `ColumnJob` stopped walking the
canopy scan. The self-test's own `ao cost` line, which IS controlled, reads
**3,973 to 3,973 quads (+0.0%)** - the merge did not widen, because at this
world's quad sizes the AO codes were already constant along almost every run.
That is a finding: the plan expected bigger quads from dropping baked AO and on
this terrain there were none to win.

---

# Night two

Bound answers Q23 to Q28 were pulled at `1579d21` before any edit. They settle
the cost instrument, the dusk window, Stage 2's gates 1b and 3, the Windows
library, the AO merge finding and this continuation.

## Stage 4 - The lens (D40)

**Shipped.** Halation on the emissives, a muted grade, grain and a vignette
after the tonemap, and one switch that turns all of it off.

- **`Look.configure_environment(env, sun, lens)`** gained the engine's two
  thirds: glow at `glow_hdr_threshold` 1.6, intensity 0.6, `glow_bloom` 0.0,
  SOFTLIGHT, levels 3 and 5 only; and the colour adjustment at saturation 0.9,
  contrast 1.05.
- **New `scripts/ui/lens.gd`** - the film pass, a `canvas_item` shader on a
  `CanvasLayer`: monochrome zero-mean grain from a per-frame hash and a
  vignette at 0.18 over a wide falloff. It is a canvas pass and not a spatial
  one because both must land AFTER the tonemap - grain written into the linear
  HDR buffer would be graded by AgX, and a vignette written there would be
  tonemapped into something that is not a vignette. **Layer -1, not the plan's
  5**: every `CanvasLayer` in `game.tscn` leaves `layer` at 0, so 5 would have
  grained and vignetted the whole interface.
- **`--lens off`** and `Game.set_lens()` turn the film pass, the glow and the
  grade off together, so "lens off" is one state.
- **The hour owns the grade's value, the lens owns its switch.** D40 is
  explicit that the lens applies "after the hour and region grading, never
  instead of it", so the two multiply: `Look.ADJUST_SATURATION` times the
  hour's own, which is 1.0 everywhere but eerie's 0.55. The grade stays on with
  the lens off wherever the HOUR asks for it, so `--lens off` cannot put the
  life back into an eerie frame.
- **`_report_cost` measures a frame** (Q23): 20 frames at each settled vantage,
  worst and median. This is night two's cost instrument.

### The cost line (Q23)

Twenty frames per vantage, settled, far mesh applied. **Nothing else was
running on this box for either tour** - `pgrep godot` was zero before each.

| shot | lens ON worst / median | lens OFF worst / median |
| --- | --- | --- |
| `20-hour-day` | 14.3 / 13.4 | 16.1 / 13.3 |
| `21-hour-evening` | 16.3 / 13.6 | 14.5 / 13.7 |
| `22-hour-dusk` | 15.6 / 13.8 | 14.4 / 13.5 |
| `23-hour-night` | 14.0 / 13.3 | 15.2 / 13.1 |
| `24-hour-eerie` | 14.1 / 13.5 | 14.4 / 13.5 |
| `5-lake` | **17.0** / 13.6 | 14.5 / 13.2 |
| `25-lens-fence` | 16.9 / 15.0 | 15.5 / 14.7 |

**Worst per-shot frame across the five hours and `5-lake`: 17.0 ms with the
lens on, 16.1 ms with it off, against rule 6's 45 ms. PASS, with 28 ms of
headroom.** The medians sit at 13.1 to 13.8 ms everywhere, lens or no lens:
**the lens is inside the noise.** Its cost is not measurable at this
resolution - the worst-frame column swaps which side is higher from shot to
shot, which is what a difference smaller than the sampling noise looks like.

Load line, same run: **2,222 chunks in 19,105 ms wall, 539 ms main thread,
3.28 ms gen per chunk on workers, 0.11 ms main-thread upload per chunk.**

**One bounded `--stream-probe` attempt** was made under Q23's 20-minute cap,
on an idle box, with the real flag. Recorded below with whatever it produced.

### Gates

| gate | result |
| --- | --- |
| full self-test | **green** |
| character self-test | **green**, 36 tests |
| worldgen probe | heightmap `4782edac`, spawn `(-44, -124)`, 53 lakes, 15,218 trees, config `1d7c18c7` - unchanged |
| transfer sheet, `--strict` | **PASS**, worst channel delta **1** of 6 (the sheet forces the lens off for itself) |

| # | kind | measurement | verdict |
| --- | --- | --- | --- |
| 1 | **GATE** | `25-lens-fence`: the gold strip's best column against the meadow either side, over `y` 300-345 | **PASS on all three halves.** Strip mean **S 46.0** against meadow **S 22.4** - a difference of **+23.6**, against a required +20. **4 px wide** at 100 m, against a required 2. Lens on against lens off, the strip's mean V is **52.9 against 54.1**, a difference of **1.2 V** against an allowance of 6. D40's grain fence holds: the grain never hides the gold line at 100 m |
| 2 | **GATE** | no clipped whites: pure `#FFFFFF` outside the sun disc, in every hour shot | **PASS, and emphatically.** **Zero** pure-white pixels in all five hour shots and in `2-summit` and `5-lake` - and zero pixels even at 250 or above on all three channels. AgX's roll-off is doing exactly what D40 asked for |
| 3 | **GATE** | halation on emissives ONLY: mid-frame non-emissive surfaces, lens on against lens off | **PASS.** `2-summit` snow **+0.1 V**, its mid-frame sky **+0.2 V** and **-0.3 V** at a second point; `20-hour-day` snow **-0.7 V**, mid-frame sky **-0.8 V** and **-0.9 V**. Every one inside 1 V against an allowance of 4. The lens does not bloom the sky and does not bloom the snow |
| 4 | **GATE** | the decided hours keep their colour with the lens on | **PASS at four of five, with the widened window.** evening **H 353.9** (pink family), **dusk H 226.5 - inside Q24's 215-285**, night **H 204.6** (195-235), eerie **S 8.6** (<= 20). Day's sky is neutral at **S 3.2**, where hue is not a meaningful quantity, and is recorded rather than claimed either way - as it was on night one |
| 5 | RECORD | halation on emissives, the other half: does a mushroom actually bloom | **the letter fails, the spirit passes** - see below |

**Gate 5, measured properly, because a per-pixel diff cannot do it.** The plan
asks that a glowing mushroom's 8 px surround sit at least 8 V above the same
surround with the lens off. A straight difference image between the two runs is
useless here: the **fireflies drift**, so the biggest positive and negative
differences in the frame are both about 70 V and both are a firefly that moved.
Measured instead as a region over the static mushroom band, against a bare
patch of the same meadow:

| region, `12-meadow-night` | lens on | lens off |
| --- | --- | --- |
| mushroom band, mean V | 11.87 | 13.87 |
| mushroom band, **max V** | **89.41** | 87.45 |
| mushroom band, **warm pixels** (H 20-50, S > 40) | **422** | 373 |
| bare meadow, mean V | 16.20 | 18.54 |
| bare meadow, **warm pixels** | **0** | **0** |

The band's mean drops 2.0 V and the bare meadow's drops 2.3 V - that is the
grade and the vignette, applied evenly to both, and it is why a mean is the
wrong statistic here. What the glow actually does is add **49 warm pixels, 13%
more**, and lift the band's peak by **2 V**, while the bare meadow gains
**none**. So halation is landing on the emissives and on nothing else, which is
D40's rule; it is simply **subtler than +8 V**. The lever is
`glow_intensity`, currently 0.6 of a 0.3-1.0 range, and it is left at the
plan's value rather than moved to chase a number - Marcel can see the pair and
say.

### Eye checks

| shot | the sentence | verdict |
| --- | --- | --- |
| `23-hour-night` beside `light-4-lensoff/23-hour-night` | the mushrooms and fireflies bloom warm, nothing else does | **pass.** The warm band is warmer and wider with the lens on and the bare meadow beside it is unchanged; the sky, the ranges and the water are the same frame |
| `20-hour-day` beside its lens-off twin | muted midtones, and the gold still rich | **pass.** The fence's gold holds S 46.0 with the lens on against 47.6 without it, while the meadow's saturation drops with everything else |
| the vignette | gentle, noticeable only when switched off | **pass**, and it is measurable: at 12 px from the top of the frame the lens costs 5.0 to 5.6 V, and at the middle of the same frame it costs 0.0 to 0.2 V |

### Tunables moved off their start

**None.** Two were moved during the stage and both were **put back**, which is
worth recording because the measurement that moved them was wrong. A sky sample
taken 12 px from the top of the frame reads about 5 V darker with the lens on;
that was read first as the glow blend darkening the frame (so SOFTLIGHT was
swapped for SCREEN) and then as the contrast term (so 1.05 was taken to 1.0).
Neither changed it, because **it is the vignette**, doing exactly what a
vignette does at the edge of a frame. Sampled where the gate means - near the
middle - the difference is 0.0 to 0.2 V. Both knobs are back at the plan's
bound values and the sampling method is the thing that changed.

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
3. **The stream probe does not finish on this build.** Three attempts, 45 / 68
   / 52 minutes, idle box, progressing the whole time (80% CPU, 65% GPU), no
   output because Godot buffers stdout to a file until exit. Its own note
   records 25 minutes. Night one therefore has **no cost line at all**, and the
   plan's 45 ms rule and Q10's tree-shadow gate are unmeasured. This is the
   first thing to fix before night two: either the probe needs to print
   unbuffered and incrementally so a long run is still readable, or the sprint
   needs shortening, or the cost gate needs a cheaper instrument.
4. **The dusk sky is the one Stage 1 gate that fails**, at H 221 against a
   window of 235-285, and it cannot be fixed with anything the plan permits.
   The ruling is yours: widen the window, move the bible's dusk sky hex toward
   what a physical sky can do, or accept a painted term over the physical sky -
   which pillar 2 currently forbids. See the Stage 1 note for the three
   gradings tried and what each measured.
5. **Two Stage 2 gates need your ruling.** Gate 1b asks the nearest range to
   hold 10 more points of saturation than the farthest, and the rock palette is
   authored at S 10 so there are not 10 to lose; measured against the nearest
   terrain in frame it is 26 points. Gate 3 asks the night pool to be 6 V above
   plain darkening and it measures 9.4 V under, because denser fog at a 0.12
   moon darkens rather than lightens. Both are written up with their numbers.

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

**B5. A closed spruce interior at real tree size may simply be a dark place.**
The plan gates the shaded side of a spruce crown at V >= 8, "never black". On
the poster's near-black canopy it measured V 1.6 to 2.5; on the bible's own
conifer ramp the same three pixels measure **V 8.7 / 4.3 / 7.1** - three to four
times better, with hues that went from noise to the conifer's grey-green - and
one of the three clears the gate while two do not. Sky ambient is demonstrably
working: the same test on open ground passes at V 17.6 with the shadow's hue 8
degrees off the sky's. What is left is geometry: a closed canopy of 25 m trees
occludes the sky, and SSAO deepens it. Either the rule is "no shadow is black
where the sky can reach it" - which is what D8 actually says - or a forest
interior needs its own light, which is a design decision and not a rendering
one.

**B6. Seven of the palette's rows are silences the bible has not filled.**
`10-color-and-light.md` names Rock, Snow and Conifer, and this repo now carries
all three. It says nothing about dirt, meadow grass, sand, forest floor, wet
gravel shore, alpine turf or heath beyond "meadow green", "greens, grey rock"
and "natural by default". Those seven keep look v2's hexes, each marked in
`block.gd` as a silence rather than as a decision. They are most of what the
ground of this world is made of.

**B4. A day's night is half of it, not fifteen minutes.** The plan's prose says
"night is about 15 minutes" of a forty-minute day. A circular sun arc is
symmetric by construction, so with `day_seconds` 2400 and the warp the sun is
below the horizon for **1,236 s, about 20.6 minutes**. Getting to 15 would need
an asymmetric arc, which nothing decides. The bible's own rule - "the night
long enough to want the fire" - is satisfied either way; the 15-minute figure
should be dropped or the arc should be decided.

---

## Night one - morning message

**1. Where it is.** `feat/light-v1`, last commit `be9cd2c`, pushed. Five
commits: Stage 0 `1ef52a6`, Stage 1 `fd7d525`, Stage 2 `14bec13`, Stage 3
`294000e`, the fog pass `be9cd2c`.

**Stages 0, 1, 2 and 3 are all green and none was wrapped early or reverted.**
Every stage's self-tests, character self-tests, worldgen probe and transfer gate
passed. Four sampled gates across the four stages fail and are recorded with
their numbers rather than chased: the forest interior's V floor (Stage 0,
improved 3-4x by Stage 3's palette and re-measured there), the dusk sky's hue
(Stage 1), and two of Stage 2's fog gates. No visual edit was reverted.

**The Windows library needs rebuilding before anything is judged on the 5080**
(Q15). The Linux one was rebuilt inside the run and the self-test's `far
dispatch` line confirms the C++ path is the one being tested; the Windows `.so`
on your box is still the one with the paint in it, and the far parity tests will
disagree until it is rebuilt. Recipe: `docs/plans/distance-v4.md` § environment.

**2. What to open first.**

Three strips, in `build/tour/compare/`, all five labels side by side:

- `6-postcard-light-base-vs-light-0-vs-light-1-vs-light-2-vs-light-3.png` - the
  whole arc in one frame: the poster's banded violet mountains and painted sky,
  then real light, then the hours, then fog, then the palette.
- `5-lake-light-base-vs-light-0-vs-light-1-vs-light-2-vs-light-3.png` - the
  water going from a flat blue sheet to the bible's teal, and the valley fog
  arriving.
- `7-forest-interior-light-base-vs-light-0-vs-light-1-vs-light-2-vs-light-3.png`
  - the near-black canopy becoming the conifer ramp.

Then the five hours, in `build/tour/light-3/`: `20-hour-day`,
`21-hour-evening`, `22-hour-dusk`, `23-hour-night`, `24-hour-eerie` - all five
from one vantage, so the only thing that differs between them is the light. The
eerie pair to look at together is `20-hour-day` and `24-hour-eerie`. A whole
eerie tour is in `build/tour/light-2-eerie/`.

**3. BLOCKING findings.** None. One gap, and it is the thing to read first:
**there is no cost line for night one.** The stream probe did not complete in
three attempts - 45, 68 and 52 minutes on an idle box, progressing throughout at
80% CPU and 65% GPU, output buffered to file until an exit that never came. Its
own note records a 25-minute run. So the plan's rule 6 (worst frame under 45 ms)
and its Q10 gate on tree shadows are **unmeasured**.

**4. For Marcel.**

1. **The stream probe needs to finish, or the cost gate needs a cheaper
   instrument.** Nothing after this is judgeable on cost until it does, and
   night two turns on glow and SSR.
2. **Rebuild the Windows library**, then re-count Q19's 15 last-bit colour
   parity misses. On ganymede, stripped, the count is **zero**.
3. **The plan's baseline table is one epic stale**: it asks for 28,383 trees and
   `main` produces 15,218, because trees v4's crown-separation ruling landed
   after trees v3. Heightmap, spawn and lakes all match.
4. **The plan's stream-probe command does not exist** as written; it is
   `--path . -- --stream-probe`, not `--script`.
5. **The dusk sky is the one Stage 1 gate that cannot be fixed with anything the
   plan permits** - H 221 against a window of 235-285. Your ruling: widen the
   window, move the bible's dusk sky hex, or allow a painted term over the
   physical sky, which pillar 2 currently forbids.
6. **Two Stage 2 fog gates are written against assumptions this world does not
   meet** - one wants 10 points of saturation to lose from a palette authored at
   S 10, the other wants a night pool that gets darker the more fog you add.
   Both are written up with their measurements.
7. **`5-lake` at the tour's default mid-morning hour is greyer than it was at
   Stage 1**, because a lakeside vantage is inside the valley fog by
   construction. Defensible under "fog sits in the valleys in the morning", but
   it is the remaining open judgement on fog and it is yours.

**5. For the bible.** Six findings, numbered in the shape the round 3 brief
asks for, written up in full above: **B1** a physical sky cannot be made violet
at dusk; **B2** the bible gives dawn no hour; **B3** eerie's "base of things
#101f26" is not reproducible without repainting a material; **B4** a circular
sun arc makes the night half the day, not 15 minutes; **B5** a closed spruce
interior at real tree size may simply be a dark place; **B6** seven of the
palette's rows are silences the bible has not filled.

**6. Tunables moved off their start.** Stage 0: none. Stage 1:
`fog_sky_affect` became per hour (0.30 / 0.60 / 0.60 / 0.50, eerie 1.00), dusk
turbidity 18 to 26, dusk sky energy 0.80 to 0.45. Stage 2 and the fog pass:
the three band densities from the plan's 0.08 / 0.05 / 0.03 to 0.0010 /
0.000625 / 0.000375 (the plan's numbers are an optical depth near fifty across
a 600 m box), the eerie lid 0.06 to 0.007, `volumetric_fog_ambient_inject` 0.2
to 0.5, the far fog density halved at all four hours, the height density
halved, `vol_density` to 0.005-0.006, and the froxel field 1,500 m to 1,200 m.
Every one has its before, its after and the shot that decided it in the section
above.

**7. The cost line.** Not measured - see 3. What exists: the tour's own load
line reads **3.06 ms gen per chunk on workers** and **0.10 ms main-thread
upload per chunk** over 2,222 chunks at spawn, against trees v3's 9.51 and 0.23
- but on a different config and a different preset, so it is not a controlled
comparison and is not offered as one. The self-test's controlled `ao cost` line
reads **3,973 to 3,973 quads, +0.0%**: dropping baked AO did not widen the
merge, against the plan's expectation that it would.

**8. What is left.** Night two, from this head: Stage 4 the film lens (AgX
grade, glow gated to emissives, grain and vignette, `--lens off`), Stage 5
water that reflects (depth tint, Fresnel, SSR), Stage 6 the documents. Before
they start: the cost instrument, the Windows rebuild, and your rulings on items
5 and 6 above, which the plan says are appended to section 1 as bound answers.
