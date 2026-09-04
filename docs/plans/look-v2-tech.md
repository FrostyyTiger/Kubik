# Look v2 - tech plan for an autonomous overnight run

> **SUPERSEDED by `docs/plans/light-v1-tech.md`** (phase 1 of
> `RECONCILIATION.md`, run 2026-09-03). The poster this plan builds - the
> three-band toon ramp, the banded fog, the painted sky, flat water, the
> dither and the linear tonemapper - was replaced wholesale by the engine's
> own light under bible pillar 2. Kept for its arguments and its
> measurements, which is why light v1 could be written; not for its numbers,
> which are dead. The run that replaced it is `docs/status/light-v1.md`.
>
> **Its SHAPE is still the work-order template** (`CLAUDE.md` § Working
> order): contract, binding pre-run answers, tunable versus not, failure
> protocol, gates. `light-v1-tech.md`, `mesher-v1.md` and `horizon-v1.md`
> are all written in it.


This is the work order for `docs/plans/look-v2.md`, written so that one agent
(Opus, unattended, on Marcel's Windows box) can execute it end to end without
asking anyone anything. `docs/research/art-direction.md` is the argument,
`look-v2.md` is the plan, this is the procedure: exact edits, exact checks,
exact numbers, what the agent may decide alone, what it may not, what to do
when a check fails, and what Marcel finds in the morning.

Marcel approved all sixteen refinements on 2026-08-25. The questions an
overnight run would otherwise have to guess at were asked and answered
before it started; section 1 records them. **An answer there is binding.**
Where the agent meets a question section 1 does not answer, the failure
protocol (section 5) says what to do: the default is to record it in the
status doc and take the conservative path, never to widen the scope.

The fourth pillar and its three habits (`CLAUDE.md`) apply: the time-of-day
keyframes become a table, not twelve constants; nothing here touches the
journal or the mutation path.

---

## 0. The contract

**Who and where.** One agent, Marcel's Windows 11 box (RTX 5080), Godot 4.7.2
at `%LOCALAPPDATA%\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64_console.exe`
(`<godot>` below). Tours and gallery sheets open a window; that is expected
overnight. Python 3 with PIL is present (`python -c "import PIL"`).

**Branch.** `main`, directly - Marcel's call (2026-08-25): the code lands on
`main` as the docs did. One commit per stage minimum, pushed to `origin`
after every stage, fast-forward only. **The agent never force-pushes, never
rewrites history, never reverts anyone else's commit.** If `origin/main` has
moved, `git pull --rebase` before pushing; a conflict in a file this plan does
not touch is not the agent's to resolve - stop and record it.

**Delivered by morning.** `main`, pushed; `docs/status/look-v2.md`
updated at the end of every stage (so a run that dies at 04:00 still leaves a
record); tour and gallery sets per stage on both renderers; comparison
strips in `build/tour/compare/`; a final message in the shape of section 6.

**Never.** No new textures. No worldgen change (the probe proves it after
every stage). No tree shapes. No enemy, campfire, marker, smoke. No change to
`player.gd`. No per-renderer branch in any palette or shader. No force-push, no
history rewrite. No palette hex changed away from section 3's values except through
the Stage 0 transfer finding. No question left unrecorded.

**Reading order, before the first edit.** `CLAUDE.md`, `README.md`,
`docs/DESIGN.md` ("Art direction", "Art pipeline"), `docs/plans/look-v1.md`,
`docs/status/look-v1.md`, `docs/research/art-direction.md` (all of it, section
0 first), `docs/plans/look-v2.md`, this file. Then `scripts/world/look.gd`,
`sky_cycle.gd`, `block.gd`, `chunk_mesher.gd`, `far_field_job.gd`,
`flora/flora_models.gd`, `lakes.gd`, `character/voxel_model.gd`,
`tools/character_gallery.gd`, `tools/screenshot_tour.gd`, `tools/selftest.gd`.

**Time budget** (wall clock, guidance): setup 0.5 h; Stage 0 2 h; Stage 1
1 h; Stage 2 1.5 h; Stage 3 1.5 h; Stage 4 1 h; Stage 5 2 h; Stage 6 1 h;
Stage 7 0.5 h. A stage that runs past 1.5x its budget is wrapped at its last
green commit and the next stage starts; what was left undone goes in the
status doc. **Stage 0 is the exception**: it is never wrapped early, and if
it cannot be made green the run stops there (section 5).

---

## 1. The grill - questions asked before the run, answers taken

| # | question | answer taken | binds |
| --- | --- | --- | --- |
| 1 | Branch or main for the code? | `main`, directly, pushed after every stage - Marcel's decision, asked and confirmed. Every push is fast-forward only; every commit is green on the gates before it is pushed, because there is no review step between the agent and `main`. | section 0 |
| 2 | Both renderers - how, on one box? | `--rendering-driver opengl3` on every tour and swatch run. Stage 0 must be green on Forward+; if opengl3 disagrees by more than the tolerance, that is a recorded blocking finding for Marcel and the run **continues on Forward+**, still shooting both. | gates, Stage 0 |
| 3 | What counts as passing a colour check? | The swatch sheet: every swatch within **6 units per sRGB channel** of prediction; the two renderers within 6 of each other. Tour sample checks: hue / saturation / value inside the window the stage states. | section 2 |
| 4 | What may the agent tune alone? | Only the knobs in section 4's tunable table, inside their ranges, each change recorded with the shot that decided it. Palette hexes, the shade inks, the sky sets and the sun colours are **not tunable** - if one looks wrong, it is recorded "for Marcel" and left. | section 4 |
| 5 | Where is the second linearisation? | Unknown; the procedure in Stage 0 finds it. Preferred fix if it is downstream of the mesh push: keep every palette and every multiplier linear as today and convert **once at the push** (`linear_to_srgb()` on the final vertex colour in every mesh builder). Never a rewrite of the palette literals. | Stage 0 |
| 6 | How is the prediction computed so the sheet and the shader cannot drift? | One static function, `Look.predict(albedo_linear, lit: bool) -> Color`, that mirrors `RAMP` line for line and reads the same published values; the swatch sheet calls it, the shader is it. | Stage 0 |
| 7 | Is Godot's `LIGHT_COLOR` really energy x PI on both renderers? | Per the shader spec, yes. The swatch lit row proves it: after `/ PI` the lit prediction must hold on both. If opengl3 differs by ~PI, see Q2. | Stage 0 |
| 8 | The gallery pad is a `StandardMaterial3D` - keep? | No. Pad, wall and swatches go through `Look.opaque_material()` so every gallery sheet shows the real ground and the prediction applies. | Stage 0 |
| 9 | Vertex colour alpha is taken (flora emissive) - how are figures flagged for the darker fog and no grain? | Per-material uniforms, not vertex alpha: `Look.figure_material()` (same shader, `fog_dark_mix 1.0`, `grain_amount 0.0`) for `VoxelModel` and `FarTreeMeshes`; `FloraModels.SHADER` sets the same uniforms itself. Terrain keeps `opaque_material()`. | Stage 2-3 |
| 10 | Water colour by time of day when the vertex colour carries the colour today? | A global `kubik_water` (linear) published by SkyCycle; the vertex colour becomes a **darkening factor**: rim 1.0, shelf 0.915, body 0.847, and the published colour is the rim's (lightest) so no factor exceeds 1.0 in 8 bits. `WATER_SHADER`: `ALBEDO = COLOR.rgb * kubik_water.rgb`. | Stage 4 |
| 11 | Does a per-fragment hash work on Compatibility? | `fract(sin(dot(...)))` on highp floats does; keep the argument small with `mod(cell, 1024.0)` before the dot so world coordinates up to +-1500 blocks do not lose precision. No derivatives, no depth reads. | Stage 3 |
| 12 | Grain on the far field? | It gets the terrain material and therefore grain; grain fades to zero between 20 and 45 m of depth regardless of fog (Cube World: gone by 30 m), so the far field never shows it. | Stage 3 |
| 13 | Keyframes: constants or data? | Data. `SkyCycle.KEYFRAMES` is a table keyed `dawn / noon / dusk / night`, each a Dictionary of the rows in section 3; `keyframe_at(elevation, morning)` blends; the old pure functions become thin wrappers so `_test_day_cycle` keeps its shape. Habit 1. | Stage 1 |
| 14 | Dawn needs a morning flag - where? | `morning := time_of_day < 0.5` in `apply()`, passed as an argument to `keyframe_at`; dawn blends where dusk did, by `dusk_amount()`. `_test_day_cycle` passes `t < 0.5`. | Stage 2 |
| 15 | New tour shots? | `13-meadow-dawn` (shot 1's vantage, `time` 0.24) and `14-postcard-dusk` (shot 6's vantage, `time` 0.74), added in Stage 2 and shot by every stage after. The tour script is a tool; editing it is allowed. | Stage 2 |
| 16 | The gold moon disc - in or out? | In (Marcel approved all sixteen; it was in 12). A `moon_color` uniform on the disc, the light stays `#9AAAD0`. It bends rule 5 by one object; the status doc says so, and it is one uniform to turn off. | Stage 2 |
| 17 | Stage 5 (faces, hair) - approved? | Yes. Scope is eyes, brow, mouth, hair and beard masses, race palettes. **Bodies, torsos, stances, heights are not touched.** If human/lizardfolk `masks-40` cannot get under 0.75 by hair alone, record the number for Marcel and stop there. | Stage 5 |
| 18 | The meadow tuft density - is placement worldgen? | Ground cover is a decoration layer that never touches a chunk and is not hashed; density is a look knob. The probe's tree count and hashes must still match. | Stage 4 |
| 19 | What is "judging by eye" for an agent? | Every eye check in this file is a binary sentence about a named shot, and wherever possible a sampled window (hue / sat / val) the agent measures with PIL over a 9x9 region it chooses and names in the status doc. The agent reads every PNG it shoots (the Read tool shows images). | all stages |
| 20 | How does Marcel review in the morning? | `tools/compare_sheets.py` builds side-by-side strips per shot: baseline / stage N-1 / stage N, both renderers, into `build/tour/compare/`. The final message names the three strips to look at first. | setup, section 6 |
| 21 | F4 knobs for new values? | Every new `WorldgenConfig` export lands in the F4 list (`worldgen_config.gd` ~line 941 and `debug_hud.gd` ~line 79 under "poster:"). | each stage |
| 22 | Self-tests touched by the transfer fix? | `selftest_character.gd` reads `ARRAY_COLOR` (~lines 259-305, 1647). After "sRGB on the wire" those assertions compare sRGB values; update them to convert, never loosen them. | Stage 0 |
| 23 | What if the AO / skirt / band multipliers now act on sRGB values? | They do not: all multiplier maths stays linear; the single conversion is the last thing before `push_back`. That is why Q5 chose "convert at the push". | Stage 0 |
| 24 | Sun energy after `/ PI`: what makes the meadow land near its authored value? | Noon 1.0 with `#FFF2D1` puts a lit `#86B04A` at `#86A73B`. That is the intent: authored = lit at noon, warmed by the sun. | Stage 0-1 |
| 25 | Commit hygiene? | Conventional prefix per stage (`feat(look):`, `fix(look):`, `docs:`), body says what changed and what shot judged it, `Co-Authored-By` trailer as the repo does. Every commit passes both self-tests and the probe. | all |
| 26 | If a stage's tour looks worse than before? | Stage 0 is expected to. For any other stage: check the sampled windows; if they pass and the eye check fails, record it, do not revert; if a sampled window fails and no tunable fixes it, revert that stage's edits to its last green commit and record. | section 5 |

---

## 2. Setup and the gates

```
git checkout main && git pull --ff-only
<godot> --headless --path . --import
```

**Baselines, same day, both renderers** (the look v1 sets were Forward+ only):

```
<godot> --path . -- --tour --seed 42 --label look2-base
<godot> --path . -- --tour --seed 42 --label look2-base-gl --rendering-driver opengl3
<godot> --path . scenes/character/gallery.tscn -- --label look2-base
```

**`tools/compare_sheets.py`** (new, PIL only): `python tools/compare_sheets.py
look2-base look2-0-transfer [more labels]` tiles each shot name found in
`build/tour/<label>/` side by side with a caption strip, writes
`build/tour/compare/<shots>-<labels>.png`; a `--gl` flag does the `-gl` sets.
Ten minutes of work; used after every stage.

**The gates, run at the end of every stage, in this order:**

```
<godot> --headless --path . scenes/selftest.tscn
<godot> --headless --path . scenes/character/selftest_character.tscn
<godot> --headless --path . --script scripts/tools/worldgen_probe.gd -- --seed 42
   # must print heightmap 76cccdb6, config da8868d1, trees 73675, spawn (-44, -124)
<godot> --path . scenes/character/gallery.tscn -- --sheet swatches --strict --label look2-<n>
<godot> --path . scenes/character/gallery.tscn -- --sheet swatches --strict --label look2-<n>-gl --rendering-driver opengl3
<godot> --path . -- --tour --seed 42 --label look2-<n>
<godot> --path . -- --tour --seed 42 --label look2-<n>-gl --rendering-driver opengl3
python tools/compare_sheets.py look2-base look2-<n-1> look2-<n>
```

then the stage's sampled checks and eye checks, then the status doc, then
the commit and the push. `--strict` makes the gallery exit non-zero when a
swatch misses. The probe's four numbers are copied into the status doc every
stage.

**Sampled check method.** `python` + PIL, 9x9 mean of a region the agent
chooses on the named shot, converted to HSV (H in degrees, S and V in
percent). The region's pixel coordinates go in the status doc so Marcel can
re-sample. The window is the check; the eye sentence is the intent.

---

## 3. The numbers

Copied from the research so this file is self-contained. All sRGB.

**Time-of-day sets** (`SkyCycle.KEYFRAMES`):

| row | dawn | noon | dusk | night |
| --- | --- | --- | --- | --- |
| sun | `#FFC7A0` | `#FFF2D1` | `#FCA55A` | `#9AAAD0` |
| energy | 0.85 | 1.00 | 0.90 | 0.75 |
| shade | `#9A97BE` | `#7A7396` | `#4A6FB4` | `#39456E` |
| shade_desat | 0.55 | 0.55 | 0.65 | 0.75 |
| fog | `#E4CDB8` | `#C9C3C4` | `#D9C4B0` | `#223A5E` |
| fog_dark | fog one band darker: `mix(fog, black, 0.18)` at every hour | | | |
| horizon | `#F3C79E` | `#EBDFC8` | `#F4CBA0` | `#25406E` |
| sky_mid | `#E4C9C2` | `#B4C1D6` | `#9A8CC0` | `#1D3764` |
| sky_top | `#BBD5DC` | `#89A1CB` | `#6C68A4` | `#152A55` |
| water | `#B6BCCE` | `#4A6A8A` | `#6E7396` | `#2C3E63` |
| cloud_lit | `#FFE2C8` | `#F2E8D0` | `#F2C489` | `#6F7C9E` |
| accent | `#F2A80D` | `#C9A24A` | `#E8A02E` | `#E8892E` |

**`Block.COLORS`** (Stage 4): STONE `#ADA9A1`, DIRT `#7A5F47`, GRASS `#809945`,
SAND `#C7C0AB`, SNOW keep `#F2F0E8`, FOREST_FLOOR `#70583D`, LEAVES `#2F4F3E`,
TRUNK `#5E4238`, SHORE `#91948E`, ALPINE_GRASS `#9C9D68`, HEATH `#6B3933`,
LEAVES_SPRUCE_B `#385C48`, LEAVES_BEECH `#4F7A3A`, LEAVES_BEECH_B `#5F8A46`,
LEAVES_LARCH `#BD994B`, LEAVES_LARCH_B `#C9A75D`, LEAVES_PINE `#3F5E35`,
LEAVES_PINE_B `#4D6B40`, LEAVES_BIRCH `#84A85B`, LEAVES_BIRCH_B `#92B268`,
TRUNK_BIRCH keep `#D5D2C4`, TRUNK_DEAD `#9E9990`.

**`FloraModels.COLORS`** (Stage 4): GRASS_BLADE `#4E6E30`, GRASS_BLADE_DRY
`#9BB65A`, GRASS_ALPINE `#ACB276`, STEM `#6E8C47`, FERN `#4D7A3B`,
MUSHROOM_STEM keep, MUSHROOM_CAP `#CC503D`, SHRUB_HEATH `#805245`,
SHRUB_HEATH_B `#8F6153`, BOULDER `#B2B0A8`, BOULDER_LIT `#D0CCC2` (new index
17), REED `#8F8859`, FIREFLY keep, FLOWER_WHITE keep, FLOWER_YELLOW `#EDC834`,
FLOWER_PURPLE `#67479E`, FLOWER_RED `#C2487B`, FLOWER_ALPINE keep.

The files store linear; the conversion is `Color.html(hex).srgb_to_linear()`
at authoring and the hex stays in the comment beside each entry, as now.

---

## 4. Tunables

The only numbers the agent may change on its own judgement. Everything else
in this file is fixed. Each change: the shot that decided it, before and
after, in the status doc.

| knob | where | start | range | judged on |
| --- | --- | --- | --- | --- |
| `sun energy` noon / dusk / dawn / night | KEYFRAMES | 1.0 / 0.9 / 0.85 / 0.75 | +-0.15 each | swatches, 1, 11, 12 |
| `BAND_HALF` | Look.RAMP | 0.22 | {0.12, 0.17, 0.22} | 3, 2 |
| `LIT_BLEACH` | Look.RAMP | 0.10 | 0-0.15 | 1, 2 |
| `shade_desat` per keyframe | KEYFRAMES | 0.55 / 0.65 / 0.75 | +-0.10 | 7, 11, 12 |
| `fog_bands` | WorldgenConfig | 4 | {4, 5, 6} | 6, 2 |
| `FOG_START_RATIO` | WorldgenConfig | 0.4 | 0.3-0.5 | 6 |
| `far_band_step` / `far_band_m` | WorldgenConfig | 0.03 / 60 | 0.02-0.04 / 40-80 | 6, 9 |
| `aspect_tint` | WorldgenConfig | 0.18 | 0.12-0.20 | 1, 3 |
| `grain_amount` / `grain_hue` | material uniform + config | 0.065 / 0.03 | 0.04-0.08 / 0.02-0.04 | 8 |
| `grain_sparse` (on/off, share, step) | uniform + config | off | 0.15 share, 0.12 step | 10, 8 |
| `contact_band` | uniform + config | 0.72 | 0.65-0.80 | 3, 1 |
| meadow tuft density (near) | flora_placement | 0.50 | 0.40-0.55 | 8 |
| `cloud_cover` | WorldgenConfig | 0.35 | 0.25-0.45 | 1, 2 |
| ray extents / strength | sky uniforms | 1.0 & 0.45 / 0.22-0.6 | +-30% | 2, 14 |
| water rim / shelf widths | lakes.gd | 2 / 8 blocks | 1-3 / 6-10 | 5, 10 |
| water alpha | lakes.gd | 0.92 | 0.88-1.0 | 5 |

---

## 5. Failure protocol

1. **A self-test or the probe goes red:** fix it within the stage; if the fix
   is not obvious in 20 minutes, revert to the stage's last green commit,
   record, and continue with the next stage only if it does not build on the
   reverted work (Stage 3 on 2, Stage 4 on 0-3, Stage 5 on 0).
2. **A swatch misses by more than 6 units on Forward+:** the stage is not
   done. Find the cause (a multiplier applied after the conversion, a
   material not switched, a uniform not published). No tolerance widening.
3. **Forward+ and opengl3 disagree by more than 6 units:** record which
   swatches and by how much, mark the finding "BLOCKING - for Marcel" at the
   top of the status doc, keep going on Forward+, keep shooting both.
4. **A sampled window fails and no tunable in its range fixes it:** revert
   that stage's visual edit, record the numbers measured, continue.
5. **An eye check fails while every sampled window passes:** record it with
   the shot name and your sentence about what you see; do not revert.
6. **A question this file does not answer:** take the conservative reading
   (smaller change, nearer today's value, fewer files), write the question
   and the reading taken under "Questions taken alone" in the status doc,
   continue.
7. **Stage 0 cannot be made green on Forward+ after the full procedure:**
   push what exists, write the findings, stop the run. Nothing after Stage 0
   is judgeable without it.
8. **Godot hangs or a tour crashes:** kill it, re-run once; if it repeats,
   record the command and the last console lines, and continue without that
   evidence, saying so.

---

## Stage 0 - The transfer

**Goal.** An authored colour, lit, at noon, lands on screen at
`authored * sun * energy`, on both renderers, proven by a sheet.

### 0.1 The prediction function and the swatch sheet

`scripts/world/look.gd`:

```
## What RAMP puts on screen for a linear albedo, in sRGB, for the sun state
## SkyCycle last published. Mirrors RAMP line for line: change one, change both.
static func predict(albedo_linear: Color, lit: bool,
        sun_linear: Color, energy: float, shade_linear: Color,
        shade_desat: float, lit_bleach: float) -> Color
```

The lit branch: `mix(albedo, WHITE, lit_bleach) * sun_linear * energy`; the
shade branch: `mix(albedo, luma(albedo), shade_desat) * shade_linear`; result
`linear_to_srgb()`. In Stage 0 `shade_desat` and `lit_bleach` are 0 and the
function IS today's multiply; Stage 1 changes both places together.

`scripts/tools/character_gallery.gd`: `"swatches": _sheet_swatches` after
`"testcube"`. Two rows of eight 1.2 m quads through `Look.opaque_material()`:
row A normal `Vector3.UP` (lit: n.l = the frozen sun's elevation 0.688 >
`BAND_LIT`), row B normal toward the camera (`+Z`; n.l < 0, shade band).
Colours, authored sRGB and converted once as the palettes are: `#FFFFFF`,
`#808080`, `#202020`, `#86B04A`, `#4E7A32`, `#BFB48C`, `#E0AC7E`, `#4C8FBF`.
Camera pitched ~30 degrees down so both rows fill the frame. After
`_shoot()`, sample the viewport image (`get_viewport().get_texture().get_image()`)
at each quad's projected centre (9x9 mean), compare with `Look.predict()`
using the values SkyCycle published for the frozen time, print a table
`name | authored | predicted | measured | delta`, write
`build/character/<label>/swatches.json`, and with `--strict` exit 1 on any
channel delta over 6. The pad (`_build_pad`), wall and `_flat_mesh` switch
to `Look.opaque_material()` (Q8).

Run it as-is, both renderers. **Expected: every swatch misses**, the lit row
near `predict(lin(lin(A)) * PI)`. Record the table - it is the baseline of
the bug.

### 0.2 PI

`Look.RAMP`: `vec3 L = LIGHT_COLOR / PI;` and `L` where `LIGHT_COLOR` was, both
branches. `SkyCycle.sun_energy()`: `lerpf(0.75, 1.0, day)` for now (Stage 1
replaces it with the table). Re-run the sheet: the lit row should now miss by
the double conversion alone (measured darker and more saturated than
predicted; `#808080` measures near `#555555`-ish).

### 0.3 The second linearisation - find it, then fix at the push

Confirm first that our own code does not convert twice: `grep -rn
srgb_to_linear scripts` - the palettes convert once at authoring, `color_of`
returns the stored value, the meshers multiply and push. If that holds, the
extra conversion is between `push_back` and `ALBEDO`.

**Experiment A.** In `_sheet_swatches` only, push the swatch colours as sRGB
(skip the conversion). If the lit row now matches `predict()` to within 6:
the engine linearises 8-bit vertex colour. **Fix:** every mesh builder
converts its final linear colour once at the push - `chunk_mesher.gd` (~line
333), `character/voxel_model.gd` (~376), `far_field_job.gd` (`_push_quad` /
`_push_skirt`), `flora/far_tree_meshes.gd`, `flora/flora_models.gd` (~565),
`lakes.gd` (~391), `character_gallery.gd` (`_flat_mesh`, testcube, swatches).
All multiplier maths (AO, skirt, band, aspect, jitter) stays linear before it.
Header comments in `block.gd`, `flora_models.gd`, `look.gd` and
`project.godot` that say "stored linear" get one added sentence: "converted
to sRGB at the push; the renderer linearises 8-bit vertex colour". Update
`selftest_character.gd`'s `ARRAY_COLOR` assertions to convert (Q22).

**Experiment B** (only if A fails). Put the colour in `ARRAY_CUSTOM0` as
`ARRAY_CUSTOM_RGBA_FLOAT` on the swatch mesh and read `CUSTOM0` in a test
copy of the shader. If that matches: the 8-bit path is the cause and the
sRGB push of A should also have worked - re-check A. If neither matches,
protocol 7.

Remove the swatch-only shortcut from A once the push conversion is in; the
sheet must pass through the normal path. Both renderers, `--strict`.

### 0.4 The sky's own transfer

`sky_cycle.gd` `_apply_fog_distances()`: `fog_sky_affect` 0.6 -> 0.0,
`fog_aerial_perspective` 0.25 -> 0.0. `SKY_TOP_DAY` `Color(0.30, 0.50, 0.83)`
-> `Color(0.537, 0.631, 0.796)` (`#89A1CB`).

### 0.5 Checks

- Swatches green on Forward+; opengl3 green or recorded (Q2).
- `testcube`: lit top within 6 of `predict()`, shade side within 6.
- Sampled: `1-spawn` sky top region hue 210-225, sat 28-38, val 76-84
  (unchanged from today by construction).
- Eye: the tour is flatter and paler than `look2-base`. Expected. Note it.
- Gates, status doc section "Stage 0" with the three swatch tables (broken,
  after PI, after the fix), commit `fix(look): one colour transfer - convert
  at the push, LIGHT_COLOR / PI, sky owns its horizon`, push.

## Stage 1 - Light: shade as ink, dusk that exists, the sets

### 1.1 The keyframe table

`sky_cycle.gd`: replace `SUN_*`, `SHADE_*`, `FOG_*`, `SKY_TOP_*` with

```
const KEYFRAMES := {
    "dawn":  {"sun": Color.html("#FFC7A0"), "energy": 0.85, "shade": ..., "shade_desat": 0.55,
              "fog": ..., "horizon": ..., "sky_mid": ..., "sky_top": ..., "water": ..., "cloud_lit": ..., "accent": ...},
    "noon":  {...}, "dusk": {...}, "night": {...},
}
```

(section 3's rows; `fog_dark` derived), and

```
static func keyframe_at(elevation: float, morning: bool) -> Dictionary
```

which lerps every row `night -> noon` by `day_amount(elevation)` and then
toward `dusk` (or `dawn` when `morning`) by `dusk_amount(elevation)` **at
weight 1.0** - never 0.75 again. `sun_color()`, `fog_color()`,
`shade_color()`, `sun_energy()` become one-line wrappers over it so
`_test_day_cycle` keeps compiling; add `morning` to their signatures with a
default of `false` and pass `t < 0.5` from the test. `apply()` reads one
Dictionary and publishes everything from it. Dawn's values exist now; Stage
2 wires `morning`.

Add to `project.godot` `[shader_globals]` with clear-day defaults, to
`Look.HEADER`, and to `Look.publish()` (which takes the keyframe Dictionary
instead of five arguments): `kubik_shade_desat` (float), `kubik_fog_dark`
(vec4), `kubik_water` (vec4). `kubik_fog_dark` and `kubik_water` are used from
Stage 2 and 4; publishing them now keeps `publish()` stable.

### 1.2 The ramp

`Look.RAMP` exactly as `look-v2.md` Stage 1 shows: `BAND_HALF 0.22`,
`LIT_BLEACH 0.10`, the luminance-keeping shade mix with `kubik_shade_desat`,
`L = LIGHT_COLOR / PI`. `Look.predict()` updated in the same edit (Q6).

### 1.3 Checks

- Swatches green both renderers with the ink formula (the shade row now
  predicts through desat 0.55).
- Sampled: `7-forest-interior`, the shaded side of a spruce crown: hue
  200-280, sat 20-50 (was hue ~100). `2-summit`, shaded rock: hue 230-280,
  val 25-45. `11-forest-dusk`, sky: val >= 60. `12-meadow-night`, lit ground:
  sat <= 60 (was 87).
- Eye: `7-forest-interior` - the dark side of a tree is a navy-violet mass
  with internal steps, not black-green. `3-forest-slope` - the terrace riser
  is the middle tone, not the shade tone (if not, `BAND_HALF` 0.17 then
  0.12).
- Gates, status, commit `feat(look): shade as ink, keyframes as a table, dusk
  reached`, push.

## Stage 2 - Sky and distance

### 2.1 Fog

`Look.FOG_FN` takes `(vec3 view_vertex, vec3 albedo)` and returns the
hue-holding target (`look-v2.md` Stage 2) blended toward `kubik_fog_dark` by a
per-material `uniform float fog_dark_mix = 0.0`. Update the three callers:
`OPAQUE_SHADER`, `WATER_SHADER`, `FloraModels.SHADER` (which sets
`fog_dark_mix = 1.0` in its own uniform block). `Look.figure_material()`: same
shader string as opaque, `fog_dark_mix 1.0`, built under the same mutex;
`voxel_model.gd:259` and `far_tree_meshes.gd:189` return it.

`worldgen_config.gd`: `fog_bands` 4, `FOG_START_RATIO` 0.4, `far_band_m` 60,
`far_band_step` 0.03, `aspect_tint` 0.18. F4 entries exist for the first
four; add `aspect_tint` if missing.

`far_field_job.gd` `_band_color()`: monotonic:

```
var band := int(floor(y_m / config.far_band_m))
var k := clampf(1.0 + step_amount * float(band - _band_treeline), 0.85, 1.25)
```

`_band_treeline` computed once per job from the generator's treeline altitude
(the zone threshold `TerrainGenerator` exposes; read it, do not re-derive).

### 2.2 Sky

`Look.SKY_SHADER`: uniforms `sky_mid`, `cloud_lit`, `moon_color`,
`ray_extent_short`. Band colour: `band < 0.5 ? mix(horizon, mid, band * 2) :
mix(mid, top, (band - 0.5) * 2)`. Below the horizon: `kubik_fog_color` (the
sky shader may read the global) so the far mesh's last band agrees with the
sky's ground. Rays: 24 pairs; even wedges reach `ray_extent`, odd wedges
`ray_extent_short` (0.45 x); wedge half-width tapers linearly to 0.15 of its
base at the tip (`wedge = step(taper(ang), fract(phi * ray_count / TAU))`
where `taper` narrows the on-fraction with `ang`); halo colour
`mix(col, vec3(1.0), 0.08)` by day and `mix(that, sun_color, dusk)`. Moon
halo: same wedges around `moon_dir`, `ray_strength 0.10`, `ray_extent 0.5`,
gated on `night`. Moon disc: `moon_color`. Clouds: polar sampling and the
constant radial underside offset per `look-v2.md` Stage 2; lit colour
`cloud_lit`, underside `mix(col, sky_horizon.rgb, 0.35) * 0.86`.

`sky_cycle.gd apply()`: publish `sky_mid`, `cloud_lit`, `moon_color`
(`accent` of the night keyframe), the horizon as `sky_horizon`, the fog as
`kubik_fog_color`, `fog_dark`; `morning := time_of_day < 0.5` into
`keyframe_at`.

### 2.3 Tour

`screenshot_tour.gd`: `13-meadow-dawn` (shot 1's vantage, `"time": 0.24`) and
`14-postcard-dusk` (shot 6's, `"time": 0.74`) appended to the shot table.

### 2.4 Checks

- Swatches green (fog does not touch the sheet; they must stay green).
- Sampled: `6-postcard`, the farthest visible range vs the sky directly above
  it: range val at least 8 below the sky's, and the range's sat <= 25.
  `9-treeline`, the far flank: no alternating stripes - sample three points
  up one flank, value must be monotonic non-decreasing. `11-forest-dusk` sky
  mid-height: hue 240-290 (lilac), val 55-85. `13-meadow-dawn` horizon band:
  sat >= 60 in a band under 10% of the frame height; sky above it val >= 80.
  `12-meadow-night`: sky horizon val >= 35 and greater than the ground's val.
  `1-spawn` with a character placed at 40 m (the tour's shot 1 has the
  player): the character's darkest region at least 10 val below the ground
  behind it.
- Eye: `6-postcard` - opaque stacked planes cut against a cream horizon.
  `1-spawn` - clouds are lozenges along the horizon with one fixed-width
  shade lip; `2-summit` - rays alternate long/short and taper. `12` - the
  moon is a gold disc with a faint halo.
- Gates, status, commit `feat(look): fog is not the horizon, far bands
  monotonic, dawn, three-stop sky, clouds, rays, the moon`, push.

## Stage 3 - Ground: grain, contact band

`Look.OPAQUE_SHADER`: uniforms `grain_amount 0.065`, `grain_hue 0.03`,
`grain_sparse 0.0`, `contact_band 0.72`; `vertex()` with `varying vec3
world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;`; `fragment()` per
`look-v2.md` Stage 3 with these additions: `vec3 cell = mod(floor(world_pos /
0.5), 1024.0);` before the hash (Q11); grain fades by depth
`1.0 - smoothstep(20.0, 45.0, length(VERTEX))` as well as by fog (Q12); with
`grain_sparse > 0` the grain applies only where `h > 1.0 - grain_sparse` at a
fixed +-0.12. `figure_material()` sets `grain_amount 0`, `contact_band 1.0`.
`FloraModels.SHADER` does not take grain (it has its own fragment; leave it).
`WorldgenConfig`: `grain_amount`, `grain_hue`, `grain_sparse`, `contact_band`
exports, F4 entries, pushed to the terrain material's uniforms by whatever
already pushes `fog_bands` to `Look.publish` (SkyCycle or World - follow the
existing path). `color_jitter_value` 0.0, `color_jitter_hue` 0.0.

**Checks.**
- Swatches green (flat quads: grain shows as +-6% on a swatch! - so the
  swatch sheet renders with `grain_amount` forced to 0 through a gallery
  flag, and says so in its header).
- Sampled: `8-meadow-closeup` flat ground, 30x30 region: per-pixel sRGB
  value standard deviation between 3 and 9 (grain present, not blotch); the
  same region's mean within 6 of the Stage 2 mean. `3-forest-slope`: the
  bottom quarter of a terrace riser at least 15 val below its top quarter.
  `9-treeline` far end: two shots 0.1 s apart differ by < 1 val mean
  (no shimmer - the tour shoots once; take the second from a re-run).
- Eye: `8-meadow-closeup` - grain one block across; terrace edges are lines.
  Gallery `lineup-front` - no grain on characters; `1-spawn` - the far field
  shows none.
- Gates, status, commit `feat(look): grain in the fragment shader, the
  contact band, jitter off`, push.

## Stage 4 - The palette, boulders, water, tufts

- `block.gd` `COLORS` and `flora_models.gd` `COLORS`: section 3 verbatim, the
  hex in each comment, the reason in one line per changed entry (from
  `art-direction.md` section 3). `C_BOULDER_LIT = 17` in the enum.
- `flora_models.gd` `_blob()`: takes `lit_color`; a plane through the blob's
  centre with normal `Vector3(Block.SUN_ASPECT.x, 0.6, Block.SUN_ASPECT.y).normalized()`;
  surface voxels on its positive side and with `y >= 0.4 * height` take
  `lit_color`. Check the lit share is 25-40% of the surface voxels by
  counting in a self-test line (`selftest.gd` has flora model tests; add one
  assertion).
- `flora_placement.gd`: meadow tuft density 0.34 -> 0.50 (the constant look
  v1 lowered; if a near/far ramp exists, the near value). Probe unchanged.
- `lakes.gd`: colour from `kubik_water` (Q10): vertex colour = darkening
  factor per ring from the shore field (rim 1.0 for cells within 2 blocks of
  `shore_near`, shelf 0.915 within 8, body 0.847), alpha 0.92; the published
  `water` row is multiplied by 1.18 in SkyCycle so the rim lands at +18% and
  the body at the row's value. `Look.WATER_SHADER`: `ALBEDO = COLOR.rgb *
  kubik_water.rgb`. Runs (`run`) split where the ring class changes.

**Checks.**
- Swatches green (the sheet's colours are fixed and independent of the
  palette).
- Sampled: `1-spawn` meadow: hue 70-90, sat 45-60, val 52-66. `5-lake` water
  body: val 40-58, sat 35-55, hue 195-215; shore: sat <= 15. `7-forest-
  interior` lit spruce: val <= 40, hue 140-190; floor: hue 20-40. `9-
  treeline` heath: hue 350-15, val <= 45; boulder: two distinct values at
  least 15 apart. `8-meadow-closeup` purple flower: val < the surrounding
  meadow's val. `2-summit` lit snow val > the sky's val at the same height.
- Eye: `5-lake` - a dark tarn with a drawn rim; `7` - the larch is the warm
  accent; `1` - a green meadow, neither lime nor olive, with drifts of
  yellow and white.
- Gates, status, commit `feat(look): the palette pass, two-tone boulders,
  water by time of day with a drawn shore, tufts`, push.

## Stage 5 - Characters

`tools/parts_author/`: in `voxlib.py` / each race module (Q17 scope):

- Eyes: 2 wide x 4 tall solid `E`, gap 6, one `W` voxel at the top-inner
  corner only, one voxel proud (`z = 0` like the nose). Brow: one row of `H`,
  or none where the race has no hair over the brow (lizardfolk: none).
  Mouth: 4-5 wide, one row, `M`. Nose: unchanged.
- `hair.py`: overhang per race - human fringe 2 proud (+z) and 1 wider each
  side; elf mass 3 past the skull (-z), ears unchanged; dwarf beard 4 below
  the jaw and 2 wider than the head; lizardfolk crest unchanged. Fringe stays
  at `BROW_Y`.
- `races.gd` palettes: audit every race so hair/skin and cloth/skin value
  ratios are <= 0.5 and no part has more than two entries; the human's cloth
  moves away from its hair's value; record the before/after hexes.
- `python -m tools.parts_author` rewrites the seven `parts_*.gd`; headers
  name the generator (they do).

**Checks.**
- `selftest_character` green (height, eyes-forward, gear placement -
  placeholders may need one voxel of clearance from the proud eyes; move the
  placeholder, not the eye).
- Gallery `look2-5-characters` all sheets; `masks-40`: every pair under 0.75,
  human/lizardfolk recorded whatever it lands at.
- Sampled: `study-noon-40m-front`, the eye region of the human: darkest 3x3
  mean val <= 35 (was a light smudge). `closeup-front`: hair mass vs skin
  val ratio <= 0.5 on every race.
- Eye: `study-detail-4m-three-quarter` - two solid dark marks read as eyes
  looking at you; `silhouettes-40` - four different outlines at the top.
- Gates, status (triangles per character vs look v1's numbers; the budget
  line), commit `feat(character): solid eyes, hair masses that break the head
  box, palette audit`, push.

## Stage 6 - UI

`scripts/ui/poster_backdrop.gd`, `deco.gd`, `deco_rule.gd`,
`assets/ui/deco_theme.tres`, the menu and creation scenes, exactly as
`look-v2.md` Stage 6 lists; `Look.accent_color(elevation)` reads the keyframe
table's `accent` row. `--shot-ui look2-6`.

**Checks.** Eye on `build/ui/look2-6/main-menu.png`: rays alternate and
taper; the title is ink on paper inside a gold ring; a full-width ink band
carries the title block; rules have square terminals. `character-
creation.png`: the panel corner steps three times. Gates (no shader or
palette touched - swatches still run), status, commit `feat(ui): tapered
sunburst, title band, stepped corners, rule terminals`, push.

## Stage 7 - Docs

`DESIGN.md` "Art direction" (the three sharpened rules and the fourth, the
ink values, "authored is on screen", where the keyframe table lives; and the
"stored linear" pipeline note gains "sRGB on the wire"); `README.md`
(`--rendering-driver opengl3`, the swatch gate); `docs/status/look-v2.md`
finalised (section 6's shape); `docs/IDEAS.md` (a Next 3 note in the shape of
look v1's; the shore width and the meadow patches under Someday); `STATUS.md`
replaced by the look v2 status with look v1's moved to `docs/status/`.
Commit `docs: look v2 status`, push.

---

## 6. The status doc and the morning message

`docs/status/look-v2.md`, in the shape of `look-v1.md`, updated at the end of
every stage with, per stage: what shipped; the swatch table (both
renderers); the probe's four numbers; every tunable changed (was / now /
shot); the sampled checks with region coordinates and measured HSV; eye
checks passed / failed with the sentence; "Questions taken alone"; "For
Marcel". At the top, before anything: any BLOCKING finding.

The final message to Marcel, in this order and nothing else first:

1. `main`'s last commit; which stages are green, which were wrapped early,
   which reverted.
2. The three comparison strips to open first (paths).
3. The BLOCKING findings, if any (opengl3 disagreement, Stage 0 findings).
4. Every "For Marcel" item, one line each.
5. Every tunable moved off its start, one line each.
6. What is left.
