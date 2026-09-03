# Light v1 - phase 1 of the reconciliation: real light

The work order for phase 1 of `RECONCILIATION.md` section 9 ("Real light"),
written in the shape of `docs/plans/look-v2-tech.md` so that one agent can
execute it unattended: exact edits, exact checks, exact numbers, what the
agent may decide alone, what it may not, what to do when a check fails, and
what Marcel finds in the morning.

The direction is the bible: `../Kubik-bible/00-TONE.md`,
`style-bible/00-pillars.md` (pillar 2: real light on flat cubes, through a
film lens), `style-bible/10-color-and-light.md` (the lighting model, the
lens, the hours, eerie, the materials, the fog), `style-bible/20-world-and-terrain.md`
(fog in the valleys, water reflects, snow line), and decisions D5, D6, D7,
D8, D16, D18, D40, D41, D52, D56. The audit that names every line this plan
rips is `docs/reconciliation/02-world-render.md`, section 0 (C1) and
section 2. Read those before this file.

**What phase 1 is.** The renderer is a toon poster: three hard light bands,
ambient off, fog quantised into four steps, a painted sky with Deco rays,
flat non-reflective water, no glow, no volumetric fog, no post chain, a
linear tonemapper. Pillar 2 asks for the opposite of every one. This plan
replaces it with the engine's own light - a real sun with soft sky-tinted
shadows, sky ambient, a physical sky, volumetric fog, a filmic tonemap -
re-authors the hours to the bible's four plus eerie, gives fog its three
jobs, enters the bible palette and strips the mesher's paint, puts the D40
lens on top, and makes water reflect. It touches nothing that decides what
the world IS: the worldgen probe prints the same four numbers after every
stage.

**What phase 1 is not.** No campfire, no characters, no buildings, no
weather system, no clouds, no C++ edits, no bible edits, no world-truth
change. Those are phases 1b to 5 and they are not pulled forward.

The three habits apply: the hours are a table (habit 1); nothing here touches
the journal or the mutation path.

---

## 0. The contract

**Who and where.** One agent, on one of two boxes, **Forward+ only** (grill
Q1):

- **ganymede** (Ubuntu 24.04, RTX 3070 Ti 8 GB, NVIDIA driver 595.84), the
  box every overnight run since distance v4 has used. `~/bin/godot`
  (4.7.2), `~/Kubik`, `~/godot-cpp` (pinned `26fb7ab`, API dumped),
  `~/bin/scons` (a venv at `~/.venvs/scons`; neither is on a
  non-interactive PATH); the tour and the sheets run under
  `xvfb-run -a -s "-screen 0 1280x720x24"` with `XDG_RUNTIME_DIR` set to
  a writable directory. Verified 2026-09-03: Godot starts as `Vulkan 1.4 -
  Forward+ - Using Device #0: NVIDIA GeForce RTX 3070 Ti` under Xvfb. The
  look v2 status's "ganymede has no Vulkan" describes the box before
  2026-08-27, when `libnvidia-gl-595` was installed beside the compute-only
  driver (`STATUS.md` item 6); every run since has been Forward+ there. The
  audio errors it prints are the missing sound card and mean nothing.
- **Marcel's Windows 11 box** (RTX 5080), Godot 4.7.2 at
  `%LOCALAPPDATA%\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64_console.exe`,
  where the brief's cost line is finally measured.

`<godot>` below is whichever binary the run uses. Tours and gallery sheets
open a window; that is expected overnight. Python 3 with PIL is present on
both.

**Branch.** `feat/light-v1` (grill Q2). One commit per stage minimum, pushed
to `origin` after every stage. Merged to `main` by Marcel after the morning
review, as trees v3 and v4 were. **The agent never force-pushes, never
rewrites history, never reverts anyone else's commit, never touches `main`
directly, and never edits `../Kubik-bible` or `../Kubik-assets`.** Findings
for the bible go in the status doc under "For the bible" and become D57
onward from that side.

**Delivered by morning.** `feat/light-v1`, pushed; `docs/status/light-v1.md`
updated at the end of every stage (a run that dies at 04:00 still leaves a
record); tour and gallery sets per stage; comparison strips in
`build/tour/compare/`; a final message in the shape of section 6.

**Never.** No new textures (a code-generated night-sky image is not a texture
asset and is the one exception, Q6). No worldgen change: the probe proves it
after every stage. No tree re-bake. The only edit under `gdext/` is Stage
3's far-paint strip (Q15); the heightmap tiles, the far geometry and the
seam discipline do not move. No campfire, no window, no building, no
character work. No Compatibility branch in any shader. No
palette hex changed away from section 3's values. No bible file edited. No
question left unrecorded.

**Reading order, before the first edit.** `CLAUDE.md`, `RECONCILIATION.md`
(sections 1, 5, 6, 7, 9), `docs/reconciliation/02-world-render.md` (section 0
C1 and section 2), the bible files named at the top, `docs/plans/look-v2-tech.md`
(the shape and the discipline; its numbers are dead), `docs/status/look-v2.md`
(the transfer findings; the swatch gate), this file. Then
`scripts/world/look.gd` (all of it), `sky_cycle.gd`, `block.gd`,
`chunk_mesher.gd`, `lakes.gd`, `flora/flora_models.gd`, `flora/tree_palette.gd`,
`far_field.gd`, `flora/tree_field.gd`, `tools/character_gallery.gd` (the
swatch sheets), `tools/screenshot_tour.gd`, `tools/selftest.gd`
(`_test_day_cycle`, the far parity tests), `ui/debug_hud.gd` (the F4 table),
`scenes/game.tscn`, `project.godot`.

**Time budget** (wall clock, guidance): setup 0.5 h; Stage 0 3 h; Stage 1
2.5 h; Stage 2 3 h; Stage 3 4 h (two of them the C++ strip and rebuild);
Stage 4 2 h; Stage 5 2 h; Stage 6 1 h. Eighteen hours: **two nights** (grill
Q3). Night one is setup and stages 0 to 3; night two is stages 4 to 6, after
Marcel has looked at night one's strips. If night one wraps inside Stage 3,
night two begins by finishing it.
A stage that runs past 1.5x its budget is wrapped at its last green commit
and the next stage starts; what was left undone goes in the status doc.
**Stage 0 is the exception**: it is never wrapped early, and if it cannot be
made green the run stops there (section 5).

---

## 1. The grill - questions asked before the run, answers taken

STATUS: **BOUND, 2026-09-03.** Marcel answered all twenty-two one by one.
Twenty as recommended; Q15 (strip the far paint from the C++ now, not by
knob) and Q18 (a hand-off brief for the document rewrites) differ from the
recommendation and the plan below follows the answers. **An answer here is
binding.**

Night-two rulings Q23 to Q28 were bound on the evening of 2026-09-03 by
Fable, on Marcel's instruction to go with the recommendations from night
one's morning message; they are binding in the same way.

| # | question | proposed answer | binds |
| --- | --- | --- | --- |
| 1 | One renderer or two? Look v2 gated Forward+ against opengl3 and then never rendered a Forward+ frame. | **Forward+ only.** Volumetric fog, SSAO, SSR, the compositor and soft directional shadows do not exist on Compatibility, and pillar 2 needs all of them. The opengl3 tour and swatch runs are dropped; every "must compile on both renderers" note is retired. Recorded "for the bible" as a proposed engine decision (Forward+ required, like D49's library). | section 0, gates |
| 2 | Branch or `main`? | **`feat/light-v1`**, pushed after every stage, merged after review. Stages 0 to 2 leave the game looking half-built between them, and the assets session pulls the repos in parallel. | section 0 |
| 3 | Who runs it, where, and when? | **Two nights of Opus on ganymede**: setup plus stages 0 to 3, then stages 4 to 6. Ganymede renders Forward+ on its RTX 3070 Ti now (section 0), it is the box trees v3's cost baseline was measured on, and it leaves Marcel's box free. The brief's cost line is re-measured on the 5080 in the morning. Alternative on the table: Fable runs Stage 0 with Marcel in the loop on the Windows box first (it is the stage where the transfer numbers are decided by eye), Opus takes the rest on ganymede. | section 0 |
| 4 | What is the colour gate now that the shader is not a ramp the sheet can mirror? | **Two sheets.** The **transfer gate** stays hard: eight authored colours on `unshaded` quads, tonemap forced to linear for that sheet only, measured within **6 units per sRGB channel** of the authored hex - proves one conversion between `push_back` and the frame. The **light sheet** is a measurement, not a gate: the same eight, lit and in shadow under the real environment at each of the four hours, printed as `authored / measured / delta` and written to JSON for the report. Palette hexes are **not tunable**; exposure, sun energy and ambient energy are (section 4). | section 2, Stage 0 |
| 5 | Three shades per material: authored, or from light? The pillar says "one body colour in three shades plus per-cube noise"; the audit read the shades as light. | **Both, in the bible's own words.** The block carries the bible's **base** hex; the per-cube noise is a **sparse step** toward the material's shade or light value on about a third of cubes (the existing `grain_sparse` mechanism, re-ranged); the third shade comes from light. Tree canopy families map onto the conifer ramp: `CANOPY_A`, `CANOPY_B` to the shade `#575d54`, `CANOPY_C` to the base `#7e8986`, `CANOPY_D` to the light `#9b9f81`, so the pack's inner/outer needle distinction survives as material and not as baked light. Bark and autumn families unchanged. | Stage 3 |
| 6 | Which sky? | **`PhysicalSkyMaterial`**, graded per hour from the keyframe table (rayleigh and mie tints, turbidity, energy, ground colour). It is the engine's own radiance, so the sky ambient, the sky-tinted shadows and the water's reflection all agree by construction, and D6's "real sunset from the lighting, graded a little toward pink first and violet after" is what it does. Night: the material's `night_sky` panorama is **generated in code at startup** (hashed stars on the slate gradient), never a file in `assets/`. **No clouds in phase 1**: D18's cubic clouds are volumes, not a sky parameter, and the round 3 brief does not ask for them. | Stage 1 |
| 7 | Day length is D52: about 40 minutes, the evening six to eight of them. Uniform sun, or a slow evening? | **A warped arc.** `day_seconds` 2400. The sun's angular speed drops by a factor of three between +8 degrees and -12 degrees on the evening side (pink then violet, about 6.5 minutes), by two on the dawn side (about 3 minutes), uniform elsewhere; night is about 15 minutes. `SkyCycle.sun_position(t)` owns the warp so the compass, the tour and the day-cycle self-test all agree. Uniform speed with a wide pink window was rejected: a pink sky under a sun at 40 degrees is not an evening. | Stage 1 |
| 8 | Fog: which mechanism does which job? | **Three layers.** The **far term** is the environment's exponential fog with `fog_aerial_perspective` and `fog_sky_affect`, so distance fades toward the sky in that direction (the bible: "fog always fades to the current sky colour"); the per-material `FOG` write and its band quantiser go; cylindrical distance is dropped unless `6-postcard` shows a bright sky behind a grey peak, in which case it is recorded and a `fog_cylindrical` material term is restored. **Height fog** (`fog_height`, `fog_height_density`) is the valley-bottom term. **Volumetric fog** to `volumetric_fog_length` 1,500 m carries the three jobs: valley bands (a `ValleyFog` node placing `FogVolume`s at the lake and valley-floor altitudes near the player, three bands each lighter than the one below), night pooling (the same volumes, denser and lower), and eerie (thick, and height density inverted so tops vanish). | Stage 2 |
| 9 | Baked AO or SSAO? | **SSAO on, baked AO off** (`ao_strength` 0). When strength is 0 the mesher **skips the corner sampling** and every face carries `AO_OPEN`, so quads merge as far as their colour allows: this is the "material rule proven on screen" D56 asks for before the C++ mesher, and the column-job time is measured before and after. SSIL off by default, on the tunable table. | Stage 0, Stage 3 |
| 10 | Do trees cast shadows? Today no tree does, at any distance. | **Yes, LOD0 within the shadow distance.** `TreeField`'s LOD0 slots get `cast_shadow` on; LOD1 and LOD2 stay off; the canopy ink (`canopy_shade`) goes to 0 because the shadow is now real. The sprint probe's worst frame is the cost gate: if it rises above **45 ms** (trees v3: 35.7 / 33.2), the shadow max distance shrinks first, then LOD0 casting is switched to the nearest slots only, and the number is recorded. | Stage 0, Stage 3 |
| 11 | How is the D40 lens built? | **Engine first, one shader second.** AgX tonemap with the exposure and white on the tunable table; `adjustment_saturation` and `adjustment_contrast` for the muted midtones; the engine's glow for halation, gated by `glow_hdr_threshold` so only emissives cross it (emissive energies are set above it, no lit surface reaches it, the sun disc is kept below it); grain and vignette as one full-screen `canvas_item` shader on a `CanvasLayer` under the HUD, applied after tonemapping as film grain is. No LUT in phase 1 (recorded as the next lens item). `--lens off` on the command line and a toggle on F4 switch all of it off for the brief's comparison shot. | Stage 4 |
| 12 | Water? | **Still, clear, reflective.** Colour from depth: the lake's own depth read from the depth texture tints from shallow `#42c1c9` to deep `#265f6e`; the sky reflects through the sky radiance with a Fresnel term; SSR on for the lit shore and, later, the walls; roughness near zero; no waves, no normal map. The three drawn rings (rim / shelf / body) go; the lake mesh's shape does not change. | Stage 5 |
| 13 | Eerie is weather, and there is no weather system. | **A flag.** `WorldgenConfig.weather` (`"clear"` or `"eerie"`), local and unhashed, on F4, and `--weather eerie` for the tour. It is a modifier on the hour: saturation down, fog thick and inverted, every warm light off through a `kubik_warm` global that the flora, the fireflies and the figure emissive read. No transitions, no rain, no snowfall: that is the weather epic. | Stage 1, Stage 2 |
| 14 | Figures fog darker than the ground today so a character does not dissolve at distance. Keep? | **No.** One surface language; a character fogs like the hill it stands on. `figure_material()` keeps only its emissive uniform. If the tour's `1-spawn` character at 40 m vanishes into the ground, that is a finding for the report, not a special case. | Stage 0 |
| 15 | The far field's paint - altitude bands, riser shade, aspect tint, jitter - lives in `far_build.cpp` as well as in its GDScript twin. Edit the C++? | **Yes: strip the C++ now** (Marcel, against the recommendation of knobs-to-identity). `far_build.cpp`, `far_world.h` and `far_mesher.cpp` lose the paint; the GDScript twin loses it in step; the paint knobs are deleted rather than parked; the Linux library is rebuilt on ganymede inside the run and the Windows one by Marcel in the morning. Stage 3 grows by two hours. | Stage 3 |
| 16 | The moon: the sun's antipode, one directional light that never goes out. The bible says "cool grey moonlight" and nothing about mechanism. | **Keep the antipode**, colour `#b9c2cf`, energy 0.12 (tunable). Recorded for the bible as the repo's choice (audit candidate D48). | Stage 1 |
| 17 | `flora_models.gd` builds its shader from `Look.HEADER + FOG_FN + RAMP` and calls itself "another lane's file". | **It is this lane's file now.** No parallel lane exists in this repo; the plant and firefly shaders are rebuilt on the new base in Stage 0 so nothing draws magenta. | Stage 0 |
| 18 | Which documents does phase 1 rewrite? | **Only its own**, and the pending rewrites get a hand-off brief: `docs/plans/docs-reconciliation.md`, written 2026-09-03, which a separate docs-only session can be pointed at now (Marcel's ask). It reserves two spots for this run: `README.md` § Where it is shot and `docs/DESIGN.md`'s colour-pipeline paragraph, which Stage 6 writes. | Stage 6 |
| 19 | The Windows self-test reports 15 last-bit colour parity misses between the C++ far mesher and its twin (jitter and tint maths). With the paint knobs at identity, do they vanish? | **Measure and record.** If the misses go to zero at identity knobs, say so: it means the hazard was the paint. If not, nothing is relaxed; the ruling stays Marcel's. | Stage 3 |
| 20 | What is "judging by eye" for an agent? | As look v2: every eye check is a binary sentence about a named shot, and wherever possible a sampled 9x9 window (H in degrees, S and V in percent) the agent measures with PIL and names by pixel coordinates in the status doc. The agent reads every PNG it shoots. | all stages |
| 21 | Commit hygiene? | `feat(light):`, `fix(light):`, `docs:`; body says what changed and what shot judged it; the trailers this session's harness prescribes. Every commit passes both self-tests and the probe. | all |
| 22 | If a stage's tour looks worse than before? | Stage 0 is expected to: it is flatter and greyer before the hours and the lens arrive. For any other stage: check the sampled windows; if they pass and the eye check fails, record it, do not revert; if a sampled window fails and no tunable fixes it, revert that stage's visual edit to its last green commit and record. | section 5 |
| 23 | Night one found the stream probe never exits (three tries, 45 to 68 minutes on an idle box). What is night two's cost instrument? | **The tour's own cost line.** `_report_cost` prints the frame cost per shot; night two's cost line is the worst of the five hour shots and `5-lake`, lens on and lens off, SSR on, plus the load line; rule 6's 45 ms applies to that worst per-shot frame. One `--stream-probe` attempt (the real flag; section 2's `--script` form was wrong) under a 20-minute timeout, recorded if it exits and abandoned if not. The hang itself is a bug for phase 1b, not this run. | Stage 4, 5, section 5 |
| 24 | The dusk sky measures H 221 against a window of 235-285 and no permitted lever moves it (finding B1). | **Widen the window to 215-285.** No painted term over the physical sky; B1 stays a finding for the bible. | Stage 1 gate, Stage 4 hour gates |
| 25 | Stage 2's gates 1b (near-versus-far saturation) and 3 (the night pool) are written against assumptions this palette does not meet, and the lakeside postcard is still hazy at every clear hour after the fog pass. | **Both become RECORD.** One more notch on the valley bands before Stage 4: the day and evening band densities at 0.6 of the fog-pass values, kept if gate 1a still passes and the mountains and the sky read in `20-hour-day`; twenty minutes at most, its own commit, before and after in the status doc. | night two setup |
| 26 | The Windows library. | **Rebuilt by Fable on Marcel's box from the branch head** at night two's launch; Q19's Windows count is recorded by Fable in the morning, not by the agent. | - |
| 27 | Baked AO off did not widen the merge (`ao cost` +0.0%). | **Recorded for phase 1b**, not investigated in this run: the C++ mesher plan measures it rather than assuming it. | Stage 3 record |
| 28 | Where does night two run? | **The same session and worktree**, from the branch head after `git pull --ff-only`; stages 4 to 6 as written, with Q18's docs scope; the morning message under "Night two - morning message". | section 0 |

---

## 2. Setup and the gates

```
git checkout main && git pull --ff-only    # ganymede's checkout was at 464f6f3 on 2026-09-03, seven commits behind
git checkout -b feat/light-v1 main
<godot> --headless --path . --import
python scripts/tools/sync_assets.py        # the tree library must be mounted; a treeless tour judges nothing
```

On ganymede every windowed command below is wrapped in
`xvfb-run -a -s "-screen 0 1280x720x24"` with `XDG_RUNTIME_DIR` exported to
a writable directory, and the first tour's console must show
`Vulkan 1.4 - Forward+ - Using Device #0: NVIDIA`; anything else (a
Compatibility fallback, llvmpipe) is a stop-and-record before Stage 0.

**Baselines, same day:**

```
<godot> --path . -- --tour --seed 42 --label light-base
<godot> --path . scenes/character/gallery.tscn -- --label light-base
<godot> --headless --path . --script scripts/tools/worldgen_probe.gd -- --seed 42
<godot> --headless --path . --script scripts/tools/stream_probe.gd -- --seed 42
```

The probe's numbers are copied into the status doc as **the baseline**. They
must match trees v3's: heightmap `4782edac`, spawn `(-44, -124)`, `53`
lakes, `28,383` trees. The `config` hash is copied too and must not move
either: every knob this plan touches is in `LOCAL_PROPERTIES` by its own
comment, and a config hash that moves is a stage that went red. The stream
probe's worst frame and frames-over-33 ms are the cost baseline (trees v3:
35.7 / 33.2 ms, 2 over 33).

**`tools/compare_sheets.py`** exists from look v2 and is used after every
stage: `python tools/compare_sheets.py light-base light-<n-1> light-<n>`.

**The gates, run at the end of every stage, in this order:**

```
<godot> --headless --path . scenes/selftest.tscn
<godot> --headless --path . scenes/character/selftest_character.tscn
<godot> --headless --path . --script scripts/tools/worldgen_probe.gd -- --seed 42
   # heightmap 4782edac, spawn (-44, -124), 53 lakes, 28,383 trees, config unchanged
<godot> --path . scenes/character/gallery.tscn -- --sheet transfer --strict --label light-<n>
<godot> --path . scenes/character/gallery.tscn -- --sheet light --label light-<n>
<godot> --path . -- --tour --seed 42 --label light-<n>
python tools/compare_sheets.py light-base light-<n-1> light-<n>
```

then the stage's sampled checks and eye checks, then the status doc, then
the commit and the push. `--strict` makes the gallery exit non-zero when a
transfer swatch misses. Stage 2 onward also runs the stream probe for the
cost line.

**Magenta is a red gate.** Any shot with a magenta surface is a shader that
failed to compile; the stage is not green until it is gone.

**Sampled check method.** `python` + PIL, 9x9 mean of a region the agent
chooses on the named shot, converted to HSV (H in degrees, S and V in
percent). The region's pixel coordinates go in the status doc so Marcel can
re-sample. **The bible's hexes are starting points, not targets** (its own
words at the top of `10-color-and-light.md`); so a sampled window in this
plan is one of two kinds, and each check says which:

- **GATE**: a fact about ordering or presence that must hold - a shadow is
  never black outdoors, evening is pinker than day, eerie has no orange, the
  gold line reads at 100 m. Failure follows section 5.
- **RECORD**: where real light lands against the bible's hex. Written down
  with the delta; never a failure. The round 3 report is built from these.

---

## 3. The numbers

All sRGB. The bible's hexes from `10-color-and-light.md`, with their HSV so
a sampled window can be compared without a calculator.

**The hours** (`SkyCycle.KEYFRAMES`, re-authored; every row a starting point):

| row | day | evening (pink) | dusk (violet) | night (slate) |
| --- | --- | --- | --- | --- |
| sky horizon | `#d3c2bb` H17 S11 V83 | `#f0d2ec` H308 S13 V94 | `#a281c3` H270 S34 V76 | `#213147` H215 S54 V28 |
| sky high | `#b3e4ef` H191 S25 V94 | `#cca8eb` H272 S29 V92 | `#63559e` H252 S46 V62 | `#0c1722` H210 S65 V13 |
| sun | warm white `#fff4e0`, energy 1.0 | pink-orange `#f9c5a5` H23 S34 V98, energy 0.7 | none: sun below the horizon, fire takes over `#f5c05e` | moon `#b9c2cf`, energy 0.12 |
| shadow (record) | navy `#22294d` H230 S56 V30 | magenta `#813263` H323 S61 V51 | near-black `#0b1123` H225 S69 V14 | `#1a2534` H215 S50 V20 |
| fog | thin, valley bottoms, mornings; colour follows the sky | pink `#e8afc9` H333 S25 V91 | violet bands `#736eb7` H244 S40 V72 | pools at feet `#466477` H203 S41 V47 |
| warm lights (`kubik_warm`) | 0 | 1 | 1 | 1 |
| ambient energy | 1.0 | 0.8 | 0.5 | 0.25 |

**Eerie** (a modifier, D7): sky flat `#c3dce8` H200 S16 V91 to `#e1f2f8`
H196 S9 V97; fog `#97b4c7` H204 S24 V78; `adjustment_saturation` 0.55;
`kubik_warm` 0; volumetric density x4, height density inverted so the top
of anything tall vanishes; "the base of things `#101f26`" is not reproduced
in phase 1 and is recorded.

**Hour anchors** (`SkyCycle.HOURS`, sun elevation, so the tour and the
gallery ask for an hour by name and the warp answers with a time): day
`+0.60`, evening `+0.09`, dusk `-0.15`, night `-0.85`.

**Materials** (`Block.COLORS` base hex; shade / light for the sparse step):

| block ids | material | shade / base / light |
| --- | --- | --- |
| `STONE` | rock | `#3e3734` / **`#5e524b`** / `#8b8a83` |
| `SNOW` | snow | `#cfd6dc` / **`#e6dad1`** / `#f4f1ee` |
| `SHORE` | (bible silent) wet gravel | keep `#91948E`; step +-12% |
| `GRASS`, `ALPINE_GRASS`, `HEATH`, `DIRT`, `FOREST_FLOOR`, `SAND` | (bible silent: "meadow green", greens, grey rock) | **keep the current hex**; step +-12%; recorded as a silence |
| all `LEAVES_*`, `TRUNK*`, `LEAVES_SLIVER` | unused by the terrain since trees v3; left as they are | - |

`TreePalette.FAMILIES`: `CANOPY_A` `#575d54`, `CANOPY_B` `#575d54`,
`CANOPY_C` `#7e8986`, `CANOPY_D` `#9b9f81`; every other family unchanged.
`SNOW` family follows `Block.SNOW`. Lake: shallow `#42c1c9` H184 S67 V79,
deep `#265f6e` H193 S65 V43. Gold, for the lens fence only: `#c9a24a` H42 S63 V79.

**The sun and its shadows.** `light_angular_distance` 1.0 degree;
`shadow_blur` 1.0; PSSM 4 splits; `directional_shadow_max_distance` 250 m;
`directional_shadow_fade_start` 0.8; `shadow_normal_bias` 2.0, `shadow_bias`
0.05 (a voxel world acnes on flat faces first; tune the two together on
`8-meadow-closeup`). Ambient source SKY, `ambient_light_sky_contribution`
1.0. Reflected light source SKY. Tonemap AgX, exposure 1.0, white 1.0.
SSAO radius 1.0 m, intensity 2.0, power 1.5. Materials: `ROUGHNESS 1.0`,
`SPECULAR 0.1`, `METALLIC 0.0`, `diffuse_lambert`.

**Fog.** Far term: exponential, density per hour (day 0.0006, evening
0.0009, dusk 0.0012, night 0.0009, eerie x4), `fog_aerial_perspective` 0.6,
`fog_sky_affect` 0.3. Height: `fog_height` at the local valley floor + 40 m,
`fog_height_density` 0.002 (night 0.004; eerie -0.004). Volumetric: length
1,500 m, density 0.01 base, albedo the hour's fog colour, anisotropy 0.35,
`volumetric_fog_ambient_inject` 0.2, `detail_spread` 2.0; valley bands three
volumes 12 m tall stacked from the floor, densities 0.08 / 0.05 / 0.03.

**The lens.** `glow_hdr_threshold` 1.6, `glow_intensity` 0.6, `glow_bloom`
0.0, blend SOFTLIGHT, levels 3 and 5; emissive energies: mushrooms and
fireflies 4.0 (was 2.0 and 3.0 on top of `kubik_night`), figure rune band
3.0. `adjustment_saturation` 0.9, `adjustment_contrast` 1.05, brightness 1.0.
Grain amplitude 0.035 in display space, monochrome, per-pixel hash re-seeded
per frame; vignette 0.18 at the corners with a wide falloff (`smoothstep(0.4,
1.4, r)`). Per-cube surface grain: `grain_sparse` 0.33, step 0.12 (a step
toward shade or light, sign by the hash).

**Time.** `day_seconds` 2400, `day_start` 0.38 unchanged. Warp: evening
window from +8 to -12 degrees at one third speed, dawn window the same
angles at one half speed, the remainder of the arc at whatever uniform speed
closes the day at 2400 s.

---

## 4. Tunables

The only numbers the agent may change on its own judgement. Everything else
in this file is fixed. Each change: the shot that decided it, before and
after, in the status doc.

| knob | where | start | range | judged on |
| --- | --- | --- | --- | --- |
| `tonemap_exposure` | environment | 1.0 | 0.7-1.4 | transfer and light sheets, 1, 6 |
| sun energy per hour | KEYFRAMES | 1.0 / 0.7 / - / 0.12 | +-30% | light sheet, 1, 6, hours |
| ambient energy per hour | KEYFRAMES | 1.0 / 0.8 / 0.5 / 0.25 | +-0.2 | 7, 12, hours |
| `light_angular_distance` | Sun | 1.0 | 0.5-2.5 | 3, 8 |
| `directional_shadow_max_distance` | Sun | 250 | 150-400 | 1, 9, stream probe |
| `shadow_normal_bias` / `shadow_bias` | Sun | 2.0 / 0.05 | 1-3 / 0.02-0.1 | 8 |
| SSAO intensity / radius | environment | 2.0 / 1.0 | 1-3 / 0.5-2 | 3, 8 |
| SSIL on/off, intensity | environment | off | off, 0.5-1.5 | 7, cost |
| fog density per hour | KEYFRAMES | see section 3 | x0.5-x2 | 6, 14, 9 |
| `fog_aerial_perspective` / `fog_sky_affect` | environment | 0.6 / 0.3 | 0.3-0.9 / 0-0.6 | 6, 2 |
| height fog density / height | KEYFRAMES | 0.002 / floor + 40 | x0.5-x3 / +20-+80 | 4, hours |
| volumetric length / density / band densities | environment, ValleyFog | 1,500 / 0.01 / 0.08-0.03 | 800-2,000 / x0.5-x3 / x0.5-x2 | hours, 6, cost |
| `glow_hdr_threshold` / `glow_intensity` | environment | 1.6 / 0.6 | 1.2-2.5 / 0.3-1.0 | night, 12, lens fence |
| `adjustment_saturation` / `adjustment_contrast` | environment | 0.9 / 1.05 | 0.8-1.0 / 1.0-1.15 | hours, lens-off pair |
| lens grain amplitude / vignette | post shader | 0.035 / 0.18 | 0.02-0.06 / 0.1-0.3 | lens fence, night |
| `grain_sparse` share / step | material + config | 0.33 / 0.12 | 0.2-0.5 / 0.08-0.2 | 8, 2 |
| turbidity / mie per hour | KEYFRAMES | engine defaults | +-50% | hours |
| evening warp factor / window | SkyCycle | 3 / +8..-12 | 2-4 / +6..-15 | day-cycle timing print |
| water Fresnel power / deep depth | water shader | 5.0 / 6 m | 3-8 / 3-10 m | 5, 10 |
| tree shadow distance (LOD0 slots) | TreeField | shadow max distance | 100-250 | stream probe |

---

## 5. Failure protocol

1. **A self-test or the probe goes red:** fix it within the stage; if the fix
   is not obvious in 20 minutes, revert to the stage's last green commit,
   record, and continue with the next stage only if it does not build on the
   reverted work (Stage 1 on 0, Stage 2 on 1, Stage 3 on 0, Stage 4 on 1,
   Stage 5 on 0 and 2).
2. **A transfer swatch misses by more than 6 units:** the stage is not done.
   Find the cause (a conversion applied twice, a sheet drawn through the
   tonemap, a material not switched). No tolerance widening.
3. **A GATE window fails and no tunable in its range fixes it:** revert that
   stage's visual edit, record the numbers measured, continue.
4. **A RECORD window is far from the bible's hex:** that is the finding the
   round 3 brief asks for. Write it down with the delta and move on. Never
   change a palette hex to chase it.
5. **An eye check fails while every window passes:** record it with the shot
   name and your sentence about what you see; do not revert.
6. **The stream probe's worst frame passes 45 ms:** shrink the shadow
   distance, then the volumetric length, then tree shadows, in that order,
   recording each; if it is still over, record it as BLOCKING and continue.
7. **A question this file does not answer:** take the conservative reading
   (smaller change, nearer today's value, fewer files), write the question
   and the reading taken under "Questions taken alone" in the status doc,
   continue.
8. **Stage 0 cannot be made green after the full procedure:** push what
   exists, write the findings, stop the run. Nothing after Stage 0 is
   judgeable without it.
9. **Godot hangs or a tour crashes:** kill it, re-run once; if it repeats,
   record the command and the last console lines, and continue without that
   evidence, saying so.
10. **`origin/feat/light-v1` has moved:** it should not; nobody else is on
    it. `git pull --rebase`, and a conflict is a stop-and-record.

---

## Stage 0 - Real light: the environment, the sun, the materials

**Goal.** Every surface in the game is lit by the engine: a real sun with a
soft sky-tinted shadow, sky ambient, SSAO, a filmic tonemap. The ramp, the
banded fog, the poster sky and the dither are gone. The transfer gate is
green. The tour is flatter and greyer than `light-base`, and that is right.

### 0.1 The environment builder

`scripts/world/look.gd` loses everything under "The ramp", "The shaders"
(all four shader strings), the far-field splice, `accent_color()`,
`shade_ink()` and `predict()`. It keeps `to_wire()`, `luma()`, the material
cache and mutex, `apply_local_knobs()`, `apply_tree_knobs()` and
`publish()`. Its header is rewritten: "Materials over the engine's light.
One shader string for every opaque vertex-coloured mesh, the engine's own
`light()`, sRGB on the wire."

New: `static func configure_environment(env: Environment, sun: DirectionalLight3D) -> void`,
called by `SkyCycle.setup()` **and** by the gallery's setup, so the game and
the sheets are lit by one decision: background SKY with a `PhysicalSkyMaterial`
(Stage 1 grades it; Stage 0 uses the material's defaults), ambient source
SKY at contribution 1.0, reflected light SKY, tonemap AgX (exposure 1.0,
white 1.0), SSAO on (section 3), SSIL off, glow off (Stage 4), volumetric
fog off (Stage 2), the far exponential fog on at day density with
`fog_aerial_perspective` 0.6 and `fog_sky_affect` 0.3; the sun's shadow
settings from section 3. `scenes/game.tscn`'s `Environment` sub-resource
keeps only `background_mode` and `sky` so the builder is the truth.

### 0.2 The opaque shader

`Look.OPAQUE_SHADER` becomes:

```
shader_type spatial;
render_mode cull_back, diffuse_lambert, specular_schlick_ggx;

global uniform float kubik_night;
global uniform float kubik_warm;

uniform float grain_sparse = 0.33;
uniform float grain_step = 0.12;
uniform float figure_emissive = 0.0;

varying vec3 world_pos;

vec3 kubik_to_linear(vec3 c) { ... as today ... }
float hash3(vec3 c) { ... as today ... }

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 albedo = kubik_to_linear(COLOR.rgb);
	// The bible's material noise: one step up or down on random cubes.
	vec3 cell = mod(floor(world_pos / 0.5), 1024.0);
	float h = hash3(cell);
	float stepped = step(1.0 - grain_sparse, h);
	float sign_ = step(0.5, hash3(cell + vec3(17.0))) * 2.0 - 1.0;
	albedo *= 1.0 + stepped * sign_ * grain_step;
	ALBEDO = albedo;
	ROUGHNESS = 1.0;
	SPECULAR = 0.1;
	METALLIC = 0.0;
	EMISSION = kubik_to_linear(COLOR.rgb) * COLOR.a * figure_emissive * 3.0 * kubik_warm;
}
```

No custom `light()`. No `FOG` write. No contact band. No 45 m grain fade:
the step is a material fact and the far field shares it (a 10 m cell at
3 km is the far grain's job and it stays a knob at 0). The tree shader keeps
its `vertex()` splice at the same anchor (`TREE_SWAY_ANCHOR` is the
`world_pos` assignment and survives). The far-field material becomes the
opaque material itself: `far_field_code()`, the two splice constants, the
Bayer function and `far_dither_m` are deleted; `far_grain` stays as an
optional uniform on a copy of the opaque material, default 0. `figure_material()`
keeps only `figure_emissive 1.0`. `far_tree_material()` and `tree_material()`
lose their `fog_dark_mix` / `contact_band` lines.

`WATER_SHADER` is rebuilt in Stage 5; until then it is the opaque shader
with `blend_mix, depth_draw_opaque, cull_disabled`, `ALPHA = COLOR.a`, so
lakes draw flat and matte and nothing is magenta.

`FloraModels.SHADER`: the same header lines, its own `vertex()`, the
fragment reduced to `ALBEDO` from the vertex colour, `ROUGHNESS 1.0`, and
`EMISSION = kubik_to_linear(COLOR.rgb) * COLOR.a * kubik_night * night_life * 4.0 * kubik_warm`.
`FIREFLY_SHADER`: emission `* 4.0 * kubik_warm`. `kubik_warm` is a new
`[shader_globals]` float defaulting to 1.0, published by `SkyCycle`.

### 0.3 The globals and the publish path

`project.godot` `[shader_globals]`: delete `kubik_shade`, `kubik_fog_color`,
`kubik_fog_start`, `kubik_fog_end`, `kubik_fog_bands`, `kubik_shade_desat`,
`kubik_fog_dark`, `kubik_water`; keep `kubik_night`; add `kubik_warm`.
`Look.publish(kf)` writes `kubik_warm` and nothing else; `Look.apply_local_knobs()`
pushes `grain_sparse` and `grain_step` to the opaque, far, tree and flora
materials. `WorldgenConfig`: `grain_amount`, `grain_hue`, `contact_band`,
`fog_bands`, `sky_bands`, `cloud_cover`, `far_dither_m` are **deleted** with
their F4 rows (`debug_hud.gd:79-89`); `grain_sparse` is re-ranged 0-0.5 and
`grain_step` added 0-0.25 under a "light:" prefix; `ao_strength` default
0.0, `canopy_shade` 0.0, `slope_tint` 0.0, `aspect_tint` 0.0 (the mesher
paint, Q9 and Q10 - the code that reads them is stripped in Stage 3).
Deleting an exported knob from `LOCAL_PROPERTIES` must leave the config hash
unchanged; the probe proves it.

`SkyCycle`: `setup()` calls `Look.configure_environment()`; `_apply_fog_distances()`
no longer sets the tonemap or `fog_sky_affect 0`; `apply()` publishes
`kubik_night` and `kubik_warm` (1.0 for now), sets the sun's colour and
energy from the keyframe, and sets the sky material's `sun_disk_scale` and
the environment's fog colour from the keyframe. The old keyframe table stays
for Stage 0 (its colours are wrong for the bible but they light the frame);
Stage 1 replaces it. `shadow_blur 0.25 / light_specular 0.0` at
`sky_cycle.gd:154-159` go; the Sun keeps `shadow_enabled`.

`chunk_mesher.gd`: no edit in Stage 0 beyond what the deleted knobs force
(`_under_canopy` still compiles at `canopy_mix 0`). `ColumnJob.shade_ink`
and its capture in `world.gd` go with `Look.shade_ink()`; the mesher's
`shade_ink` parameter keeps its default.

`TreeField._make_slot()`: LOD0 keys get `cast_shadow ON`; the note at
`tree_field.gd:423-426` is rewritten to say which LOD casts and why.

### 0.4 The two sheets

`scripts/tools/character_gallery.gd`: `_sheet_swatches` and
`_sheet_swatch_ramp` are replaced by two sheets, `"transfer"` and `"light"`,
both over the same `SWATCHES` list.

**`transfer`**: eight quads through a private `unshaded` material
(`render_mode unshaded; ALBEDO = kubik_to_linear(COLOR.rgb)` - the same
decode the real material does), the environment's tonemap set to LINEAR
and glow and adjustments off **for this sheet only** and restored after;
each sampled 9x9 at its projected centre; `authored | measured | delta`;
`transfer.json`; `--strict` exits 1 on any channel over **6**. This is the
gate that says one conversion happens between `push_back` and the frame.

**`light`**: the same eight through `Look.opaque_material()` with the grain
forced off, one lit row (normal up) and one shadow row (a quad standing in
the shadow of a wall the sheet builds), shot at each of the four hour
anchors by `_set_time()`; `authored | measured lit | measured shadow` per
hour; `light.json`. No pass/fail. Its four tables are the report's colour
evidence for "a lit wall, a shadow".

`Look.predict()` and `LIT_BLEACH` are deleted; the gallery's references go
with them.

### 0.5 Checks

- Transfer sheet green. Light sheet written, four tables in the status doc.
- Both self-tests green: `_test_day_cycle` still walks the day through
  `sun_color()` / `fog_color()` / `sun_energy()`; the far parity tests still
  compare the twin against the C++ (nothing in the C++ changed); the tree
  swatch test converts as before.
- Probe: the four numbers and the config hash unchanged.
- GATE `7-forest-interior`, the shaded side of a spruce crown: V >= 8 (never
  black), and its hue within 40 degrees of the sky's hue sampled at the top
  of the frame (the shadow takes the sky's colour).
- GATE `3-forest-slope`: a terrace riser's shadowed face and its lit top
  differ by at least 10 V (real light makes relief), and no acne: a 30x30
  region of flat lit ground has a per-pixel V standard deviation under 10
  with the grain forced off through F4 (record the region).
- GATE `1-spawn`: no magenta anywhere in any tour shot.
- RECORD `1-spawn` meadow lit H S V; `2-summit` lit snow; `5-lake` water.
- Eye: `8-meadow-closeup` - cubes read as cubes through SSAO and the step
  grain, not through a drawn line. `1-spawn` - a tree's shadow lies on the
  ground. `6-postcard` - the far ranges recede into haze toward the sky, no
  bands, no stripes.
- Cost: stream probe worst frame and frames over 33 ms, recorded (the
  shadow map and SSAO are the new cost; Q10's 45 ms rule applies).
- Gates, status doc "Stage 0", commit `feat(light): the engine lights the
  world - real sun, sky ambient, SSAO, AgX; the ramp, the bands, the poster
  sky and the dither are gone`, push.

## Stage 1 - The hours: four plus eerie, a physical sky, a slow evening

### 1.1 The table

`SkyCycle.KEYFRAMES` re-authored to `day / evening / dusk / night`, each a
Dictionary with the rows of section 3 plus the sky parameters: `sun`,
`sun_energy`, `ambient_energy`, `sky_rayleigh`, `sky_mie`, `sky_turbidity`,
`sky_energy`, `sky_ground`, `fog`, `fog_density`, `fog_height_offset`,
`fog_height_density`, `vol_density` (Stage 2 reads it), `warm` (0 or 1),
`saturation`. `EERIE` is one Dictionary of overrides (section 3) applied on
top when `config.weather == "eerie"`. `HOURS` is the elevation anchors.

`keyframe_at(elevation, morning)` blends `night -> day` by `day_amount`,
then toward `evening` and then `dusk` by two windows on the evening side
(evening peaks at +0.09, dusk at -0.15, both with soft shoulders), and
toward a `dawn` set that is the evening set with saturation 0.7 on the
morning side (the bible gives dawn no hour of its own; recorded as a
silence). The wrappers `sun_color()`, `fog_color()`, `sun_energy()` keep
their signatures for the self-test.

### 1.2 The sky

`Look.configure_environment()` builds a `PhysicalSkyMaterial`; `SkyCycle.apply()`
sets `rayleigh_color`, `mie_color`, `turbidity`, `energy_multiplier`,
`ground_color`, `sun_disk_scale` from the keyframe every frame, and the
`night_sky` texture once at setup from `SkyCycle.make_night_panorama()`:
a 1024x512 `Image`, the slate gradient from `#213147` at the horizon to
`#0c1722` overhead, stars from a two-stage hash as the old shader did them,
built in code, never saved. Eerie: rayleigh and mie toward `#c3dce8`,
turbidity high, `fog_sky_affect` 1.0.

### 1.3 The clock

`day_seconds` 2400. `SkyCycle.sun_position(t)` gains the warp of section 3:
`arc_angle(t)` is a monotonic piecewise map from `t` to degrees with the
evening and dawn windows slowed, normalised so `t = 1.0` closes the circle;
`sun_position` reads it. `time_for_elevation(e, evening: bool)` inverts it
by bisection so `HOURS` can be asked for a time. `_test_day_cycle` gains
one line: the evening window (+8 to -12 degrees on the evening side) takes
between 360 and 480 seconds of a 2400 s day.

Warm lights: `kubik_warm` published from the keyframe's `warm`, and 0
under eerie. The moon: `light_direction()` unchanged; the night keyframe's
sun colour is `#b9c2cf` at 0.12.

### 1.4 The tour

`screenshot_tour.gd`: five shots from `6-postcard`'s vantage, named
`20-hour-day`, `21-hour-evening`, `22-hour-dusk`, `23-hour-night`,
`24-hour-eerie` (the last with `"weather": "eerie"`), each `"hour"` naming
an anchor, resolved through `SkyCycle.time_for_elevation()`. The old
`14-postcard-dusk`, `11-forest-dusk`, `12-meadow-night` and `13-meadow-dawn`
keep their vantages and take `"hour"` names instead of raw times. The
`--weather` flag sets `config.weather` before the tour starts.

### 1.5 Checks

- Transfer green. Light sheet at the four hours.
- GATE hue ordering on the five hour shots, sky sampled at 15% frame
  height: evening H in 300-350 or 0-30 (pink family), dusk 235-285, night
  195-235, day either 0-40 or 180-230 (pale pink-grey at the horizon, blue
  higher), eerie S <= 20. Evening's sky is pinker than day's (S higher and
  H nearer 320) and dusk is darker than evening (V lower).
- GATE `24-hour-eerie`: no pixel region with H in 20-50 and S > 40 (no
  orange anywhere); the mushrooms in `12-meadow-night` under eerie do not
  glow.
- GATE the evening lasts 360-480 s (self-test).
- RECORD every row of section 3's hours table against the sampled sky
  horizon, sky high, a lit wall (the swatch sheet's `#BFB48C`), a shadow.
- Eye: `21-hour-evening` - the whole world is tinted, shadows are magenta
  not grey. `22-hour-dusk` - violet, the sun gone, the sky still lighter
  than the ground. `23-hour-night` - slate, not black, stars visible, the
  moonlit hillside is still a hillside. `24-hour-eerie` - the life taken
  out.
- Gates, status, commit `feat(light): the four hours plus eerie, a physical
  sky graded by the table, a forty-minute day with a slow evening`, push.

## Stage 2 - Fog's three jobs

### 2.1 The far and height terms

`SkyCycle.apply()` writes `fog_density`, `fog_height`, `fog_height_density`
from the keyframe (eerie inverts the height density). `fog_height` is
`config.fog_floor_m + keyframe offset`, where `fog_floor_m` is the altitude
of the nearest lake or valley floor to the player, updated by `World` once
per second from `Lakes` (nearest lake level within 600 m) or, with none,
from the heightmap's minimum in a 300 m disc; local, unhashed. Cylindrical
distance: dropped, per Q8; `6-postcard` decides whether it comes back.

### 2.2 The volumes

`Look.configure_environment()`: `volumetric_fog_enabled`, length 1,500,
density 0.01, albedo from the keyframe each frame, anisotropy 0.35,
`ambient_inject` 0.2, `sky_affect` 0.5, `detail_spread` 2.0.

New `scripts/world/valley_fog.gd` (`ValleyFog`, a child of `World`): keeps
three `FogVolume`s (box, `FogMaterial`) per tracked floor, up to two floors
within 800 m, each volume 600 x 12 x 600 m stacked from `fog_floor_m` with
densities from the keyframe scaled 0.08 / 0.05 / 0.03, edge fade 0.4; at
night the stack drops 6 m and doubles; under eerie a fourth volume 200 m
tall sits from `fog_floor_m + 60 m` at 0.06 so tops vanish. Volumes move
with the tracked floor, never with the player, so a band lies in a valley
and not around the camera.

### 2.3 Checks

- GATE `20-hour-day` from `6-postcard`'s vantage: the farthest visible
  range's S <= 25 and its V within 12 of the sky directly above it (fog
  lowers saturation and contrast, and fades to the sky). The nearest range
  has S at least 10 above the farthest (distance still reads).
- GATE `21-hour-evening`: sampling a vertical line up the valley from the
  lake surface, V is monotonic non-decreasing through the band stack and
  the lowest band is lighter than the ground under it.
- GATE `23-hour-night`: a region at the lake shore has V at least 6 above
  the same region at `20-hour-day` minus the day-night sky difference -
  in words: the pooled fog is visible against the dark ground.
- GATE `24-hour-eerie`: the summit in `2-summit` under eerie is not
  visible: the top 20% of the mountain's silhouette region has V within 4
  of the sky beside it.
- GATE cost: stream probe worst frame under 45 ms (rule 6).
- RECORD fog colour per hour against section 3.
- Eye: `4-valley-floor` at evening - three bands lying in the bottom, each
  lighter than the one below, and they lie in the valley, not around the
  camera. `6-postcard` - no bright sky behind a grey peak; if there is,
  record it and restore the cylindrical term as a uniform on the opaque
  material.
- Gates, status, commit `feat(light): fog does its three jobs - aerial
  perspective to the sky, valley bands, night pools, eerie hides the tops`,
  push.

## Stage 3 - The palette, and the paint stripped

### 3.1 The palette

`block.gd` `COLORS`: section 3's base hexes for `STONE` and `SNOW`, linear
as before with the hex in the comment and one line saying which bible
material it is; every other entry unchanged, with a comment naming it a
bible silence. `TreePalette.FAMILIES`: the four canopy rows to the conifer
ramp, `SNOW` following `Block.SNOW`. `selftest.gd`'s tree swatch test
converts the new values; no assertion is loosened.

### 3.2 The mesher's colour path

`chunk_mesher.gd` `_emit_quad` (326-360): the colour is
`Look.to_wire(Block.color_of(id))` and nothing else. `Block.jitter()`,
`Block.aspect_shade()`, `aspect_curve()`, `SUN_ASPECT` and the two salts
are **kept** because `far_field_job.gd` and the C++ still call them at
identity (Q15); their callers in the chunk mesher go, as does
`_under_canopy` and the mesher's `canopy_cover` / `shade_ink` parameters
(`column_job.gd` stops computing the canopy scan: measure the column job
before and after). When `ao_strength == 0.0` the mask carries `AO_OPEN`
without sampling the corners; the merge is then by id alone. `ao_strength`
itself stays a knob so the old look can be photographed for the report.

### 3.3 The far field's paint, stripped from both legs (Q15)

The far vertex colour becomes `to_wire(zone colour)` and nothing else, on
both legs, in one commit, so the parity tests never see them disagree.

- `gdext/src/far_build.cpp`: delete `aspect_curve`, `aspect_shade`,
  `block_jitter`, `treeline_band`, `band_m_at` and `band_color` (the block
  at lines 85-166), the calls at 529 and 548-556 (the vertex colour is the
  zone colour through the one conversion), 718-721 (no band), the riser
  factor at 776-778 (a riser takes its top's colour), and 819.
  `far_world.h`: `far_band_m`, `far_band_step`, `far_riser_shade`,
  `far_riser_lift`, `far_riser_axis`, `slope_tint`, `aspect_tint` and the
  `color_jitter_*` fields leave `Config` and its marshalling; `SUN_ASPECT_*`
  and the two tint salts go. `far_mesher.cpp` / `.h`: the `c_treeline_band`,
  `c_band_color`, `c_aspect_shade` bindings and the jitter helper (104-131)
  go.
- `scripts/world/far_field_job.gd`, in step: `_band_treeline` (625, 639),
  the band call (1013-1016), the riser factor (1108-1125), `_band_color`
  (1382), `treeline_band` and `band_m_at` (1776-1830), the vertex push at
  1703-1710 becomes `Look.to_wire(color)`. `far_mesher.gd` loses the
  matching wrapper methods.
- `scripts/world/block.gd`: `jitter`, `aspect_shade`, `aspect_curve`,
  `SUN_ASPECT` and the two salts go. `flora_models.gd:437` keeps the boulder
  lit-side plane with its own local constant `Vector2(0.0, -1.0)`.
- `WorldgenConfig`: `far_band_m`, `far_band_step`, `far_riser_shade`,
  `far_riser_lift`, `far_riser_axis`, `slope_tint`, `aspect_tint`,
  `color_jitter_value`, `color_jitter_hue`, `color_jitter_blocks`,
  `canopy_shade` deleted with their F4 rows and their `to_dict` entries
  (all local; the config hash must not move). `far_normal_m` stays: a
  flank-averaged normal is a coarse mesh's correct normal under real light.
- `selftest.gd`: `_test_far_zone_parity` (2180-2260) drops its `band_color`,
  `aspect_shade` and jitter rows and compares `Look.to_wire(Block.color_of())`
  against the C++ vertex colour; `_test_far_terrace_knob` (1618) loses any
  band reading; every other far parity test stays as it is and must stay
  green.
- Rebuild the Linux library inside the run:
  `cd ~/Kubik/gdext && ~/bin/scons platform=linux target=editor custom_api_file=../../godot-cpp/extension_api.json -j$(nproc)`;
  the self-test's `far dispatch` line must say the C++ path was taken. **The
  Windows library is not rebuilt by the run**: it is the first "For Marcel"
  item of the morning (recipe: `docs/plans/distance-v4.md` § environment,
  Windows notes in the memory of this box), needed before the 5080 cost line
  and before Q19's Windows re-count. CI's `selftest.yml` builds Linux on the
  branch push and is the second proof.

### 3.4 Checks

- Transfer green. Both self-tests green on ganymede with the rebuilt
  library: the far parity tests compare the stripped twin against the
  stripped C++. **Q19**: the Windows last-bit colour misses are counted by
  Marcel after the Windows rebuild (baseline 15); the status doc carries
  the ganymede count and the request.
- Probe: the four numbers and the config hash unchanged (the deleted knobs
  were local; if the hash moves, a knob was not).
- GATE column job: mean ms per column from the load log, before (trees v3:
  39.03) and after; the mesh share must fall (bigger quads, no canopy scan).
  Record chunks at spawn and vertex count.
- GATE `2-summit` lit snow: H within 15 of 26, S <= 15; `9-treeline` rock:
  H within 20 of 22, S <= 30 (the bible's materials, under real light).
- RECORD `7-forest-interior` lit conifer against `#9b9f81`, shaded against
  `#575d54`.
- Eye: `8-meadow-closeup` - a flat field is flat with a scatter of stepped
  cubes, and a wall reads by its own shadow, not by a painted band.
  `9-treeline` - the far flank has no contour stripes. `7` - the conifers
  are the bible's grey-green, neither the old near-black nor a lime.
- Gates, status, commit `feat(light): the bible palette; the mesher emits one
  flat colour per material, near and far, and the far paint is gone from
  both legs`, push.

**End of night one.** Status doc up to here, the final message of section
6 for night one, and stop. Night two begins after Marcel's review, from
`feat/light-v1`'s head, with any rulings from the morning appended to
section 1 as bound answers.

## Stage 4 - The lens (D40)

### 4.1 Glow and the grade

`Look.configure_environment()`: glow on with section 3's numbers,
adjustments on with the keyframe's saturation and 1.05 contrast. The
mushrooms', fireflies' and figure emission energies to 4.0 / 4.0 / 3.0
(Stage 0 set the code; this stage sets the numbers and judges them). The
sun disc: `sun_disk_scale` such that the disc does not cross the glow
threshold (measure: the sky within 3 degrees of the disc has no halo above
the sky's own value by more than 4 V).

### 4.2 The film pass

New `scripts/ui/lens.gd` on a `CanvasLayer` (layer 5, under the HUD's) with
a full-rect `ColorRect` whose `canvas_item` shader reads
`hint_screen_texture`, adds monochrome grain `(hash(FRAGCOORD.xy, TIME) - 0.5) * amount`
and multiplies a vignette `1.0 - vignette * smoothstep(0.4, 1.4, length(uv - 0.5) * 2.0)`.
`Game` adds it after the HUD. `--lens off` (and F4 "light: lens") hides
the layer and switches glow and adjustments off together, so "lens off" is
one state.

### 4.3 The fence

`screenshot_tour.gd`: a shot `25-lens-fence` places, in `1-spawn`'s meadow,
a temporary `MeshInstance3D` of a 0.5 m x 0.5 m x 10 m gold strip
(`#c9a24a`, through the opaque material, removed after the shot) and
photographs it from **100 m** by day with the lens on, and `26-lens-fence-off`
with it off; `27-hour-night-lens-off` is `23-hour-night` with the lens off.

### 4.4 Checks

- Transfer green (the sheet forces the lens off).
- GATE `25-lens-fence`: the strip's column of pixels has a mean S at least
  20 above the meadow beside it and is at least 2 px wide at 100 m; the
  lens-on and lens-off strips differ in mean V by under 6 (grain never
  hides a gold line at 100 m).
- GATE halation on emissives only: in `23-hour-night`, a glowing mushroom's
  8 px surround has V at least 8 above the same surround in
  `27-hour-night-lens-off`; the snow in `2-summit` by day and the sky beside
  the sun disc show under 4 V of difference between lens on and off.
- GATE no clipped whites: in every hour shot the count of pixels at
  `#FFFFFF` outside the sun disc's region is 0.
- GATE the decided hours keep their colour: the Stage 1 hue windows still
  hold with the lens on.
- RECORD grain: 30x30 flat-ground per-pixel V standard deviation with the
  lens on versus off (target 2-5 higher).
- Eye: `23-hour-night` - the mushrooms and fireflies bloom warm, nothing
  else does. `20-hour-day` beside `26` - muted midtones, and the gold still
  rich. A gentle vignette, noticeable only when switched off.
- Gates, status, commit `feat(light): the film lens - AgX, halation on the
  warm lights only, grain and vignette after the tonemap, one switch`, push.

## Stage 5 - Water that reflects

`Look.WATER_SHADER`: `blend_mix, depth_draw_opaque, cull_disabled,
depth_prepass_alpha`; `hint_depth_texture` to recover the scene depth
behind the surface and the water's own depth `d`; `ALBEDO = mix(shallow,
deep, smoothstep(0.0, deep_m, d))` with the two teals as uniforms
published from the keyframe (the hour tints them by light, not by
repainting: the uniforms are the bible's two hexes and do not move with
the hour); `ALPHA = mix(0.55, 0.96, smoothstep(0.0, deep_m, d))`;
`ROUGHNESS 0.02`, `SPECULAR 0.5`, `METALLIC 0.0`, and a Fresnel term
`pow(1.0 - dot(NORMAL, VIEW), fresnel_power)` raising `ALPHA` toward 1 at
grazing angles so the reflection wins where a real lake mirrors. SSR on in
`configure_environment()` (max steps 64, fade in 0.15, fade out 2.0, depth
tolerance 0.2). `lakes.gd`: the vertex colour carries alpha 1 and white; the
ring split in the run loop goes; `RING_FACTOR` and `WATER_ALPHA` are
deleted; `make_material()` unchanged.

**Checks.**
- Transfer green.
- GATE `5-lake`: the water region's H in 175-200 and the mountain's
  reflection is present - a 20x20 region of water under the peak's
  reflection has V at least 8 above a region of open water reflecting sky
  by day, or the sky's reflection is visibly darker than the sky (record
  which).
- GATE `10-shore`: the shallows (within 3 m of the shore) have V at least 10
  above the body and the lakebed's colour is visible through them (S lower
  than the body's).
- RECORD water against `#42c1c9` / `#265f6e` at day and evening.
- Eye: `6-postcard` - the lake mirrors the mountain and the evening sky;
  it is still. `5-lake` - clear at the edge, teal in the body, no drawn rim.
- Gates, status, commit `feat(light): water is clear and reflects - depth
  tint, Fresnel, SSR, no rings`, push.

## Stage 6 - Docs

`docs/status/light-v1.md` finalised (section 6's shape); `STATUS.md`
replaced by the light v1 status with trees v3's moved under `docs/status/`
if it is not already there; `README.md` § Where it is shot (Forward+ only,
the two sheets, `--lens off`, `--weather eerie`); `docs/DESIGN.md`
colour-pipeline paragraph - these two are the spots
`docs/plans/docs-reconciliation.md` reserves for this run -  (the engine lights, sRGB on the wire, the two sheets, the step
grain, where the hour table lives; the three-band ramp and "distance is
bands" sentences removed); `docs/plans/look-v1.md`, `look-v2.md`,
`look-v2-tech.md` get one line at the top: superseded by this plan. Commit
`docs: light v1 status`, push.

---

## 6. The status doc and the morning message

`docs/status/light-v1.md`, in the shape of `look-v2.md`, updated at the end
of every stage with, per stage: what shipped; the transfer table; the light
sheet's four tables; the probe's numbers and the config hash; the stream
probe's cost line; every tunable changed (was / now / shot); the sampled
checks with region coordinates and measured HSV, marked GATE or RECORD;
eye checks passed / failed with the sentence; "Questions taken alone"; "For
Marcel"; **"For the bible"** (every rule that turned out wrong, too
expensive or impossible, and every silence a choice filled - numbered, in
the words `ROUND-3-BRIEF.md` asks for, so the report can lift them). At the
top, before anything: any BLOCKING finding.

The final message to Marcel, in this order and nothing else first:

1. `feat/light-v1`'s last commit; which stages are green, which were
   wrapped early, which reverted. After night one: the Windows library
   needs rebuilding before anything is judged on the 5080 (Q15).
2. The three comparison strips to open first (paths), and the five hour
   shots side by side.
3. The BLOCKING findings, if any.
4. Every "For Marcel" item, one line each.
5. Every "For the bible" item, one line each.
6. Every tunable moved off its start, one line each.
7. The cost line: worst frame, frames over 33 ms, column job ms, against
   the baseline.
8. What is left.
