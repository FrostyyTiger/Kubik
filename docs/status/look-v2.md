# Look v2 - status

The run of `docs/plans/look-v2.md` and `docs/plans/look-v2-tech.md`.
Branch `feat/look-v2`. Updated at the end of every stage.

---

## BLOCKING - for Marcel, before anything else

**1. This run never rendered a Forward+ frame.**

The plan and the tech plan are written for the Windows box (RTX 5080, Forward+,
with `--rendering-driver opengl3` as the second renderer). This run executed on
**ganymede**, which has no Vulkan ICD at all - `/usr/share/vulkan` does not
exist, and Godot logs `Required Vulkan instance extension VK_KHR_surface not
found` and falls back to **OpenGL Compatibility on Mesa llvmpipe (software)**.

So every number, every swatch and every frame in this document is
**Compatibility, software-rasterised**. The tech plan's Q2/Q3 gate - "green on
Forward+, and the two renderers within 6 units of each other" - was not run and
cannot be run here. Hard rule 4 is unproven, not met.

**2. The Stage 0 finding is renderer-shaped, and this is the part to check
first.**

Stage 0 found *two* independent errors, measured (not inferred). The second one
may be Compatibility-only, and if it is, the fix for it is wrong on Forward+ in
a way that will be obvious in one frame.

What was measured, on Compatibility, with a grey ramp drawn through the real
material (`--sheet swatch-ramp`, kept in the gallery for exactly this purpose):

| what was drawn | result |
| --- | --- |
| `unshaded`, `ALBEDO = v` | on screen = `v`, exactly. Identity. |
| custom `light()` writing a flat `vec3(1.0)`, `ALBEDO = v` | on screen = `v`, exactly |
| the real ramp, `DIFFUSE_LIGHT += ALBEDO * light` | on screen = `linear_to_srgb(srgb_to_linear(v)^2 * light)` |
| the real ramp with the `ALBEDO` factor removed | on screen = `linear_to_srgb(srgb_to_linear(v) * light)` |

The third row is a **square** on the albedo. That is the "every palette entry
lands on screen at double its saturation" of `art-direction.md` section 0 - the
symptom the research named correctly and attributed to a double linearisation.

The second row is what pins the mechanism: with `light()` writing a flat white
and nothing else, the frame comes back as the albedo that was pushed. So on
this renderer

    final_linear = srgb_to_linear(ALBEDO) * DIFFUSE_LIGHT

- the engine decodes `ALBEDO` from sRGB itself, and it multiplies by that
decoded albedo **after** `light()` returns. Our `light()` also multiplied by
`ALBEDO`, so the albedo was applied twice, and un-decoded the second time.

**Why this needs your eyes.** Godot's documented contract for a custom
`light()` is `DIFFUSE_LIGHT += ... * ALBEDO` - the light function is supposed to
own the albedo. That is the opposite of what Compatibility does here. If
Forward+ follows the documentation, then removing the `ALBEDO` factor (which is
what makes the swatch sheet green on this box) will render every surface at the
**light's** colour with no albedo at all on your machine, and it will be
unmistakable in the first frame of the first tour.

**The check, in one command on the Windows box:**

    <godot> --path . scenes/character/gallery.tscn -- --sheet swatches --strict
    <godot> --path . scenes/character/gallery.tscn -- --sheet swatch-ramp

If the swatch sheet is green on Forward+ too, the fix is right on both and this
finding closes. If it is not, the one line to look at is `Look.RAMP`'s
`light()`, and `docs/plans/look-v2-tech.md` section 5.3 applies.

**3. Consequence for the rest of the run.** Every colour decision after Stage 0
is judged through the Stage 0 transfer. If Forward+ disagrees with finding 2,
every stage after it needs re-judging on your box - the code is right either
way, but the *numbers* were chosen by looking at software-rendered frames.
Nothing here is merged to `main`; the branch is `feat/look-v2`.

---

## Stage 0 - The transfer

**Shipped.**

- `Look.predict()` - a static mirror of `RAMP`, so the sheet and the shader
  cannot drift (Q6).
- A `swatches` gallery sheet: eight authored colours in a lit row and a shade
  row, sampled out of the frame that was just shot, compared with
  `Look.predict()`, written to `swatches.json`, and with `--strict` an exit
  code. The pad, the wall and the swatch quads go through
  `Look.opaque_material()` (Q8).
- A `swatch-ramp` gallery sheet - **not in the plan**, added to measure the
  transfer rather than guess at it, and kept because it is the instrument that
  resolves the blocking finding above on Forward+.
- `Look.RAMP`: `vec3 L = LIGHT_COLOR / PI`, and the `ALBEDO` factor removed
  from both branches of `light()` (finding 2).
- `Look.to_wire()` - **the one conversion**. Every mesh builder converts its
  final linear colour to sRGB once, at `push_back`: `chunk_mesher.gd`,
  `character/voxel_model.gd`, `far_field_job.gd`, `flora/far_tree_meshes.gd`,
  `flora/flora_models.gd`, `lakes.gd`, and the gallery's own `_flat_mesh`. No
  palette literal was rewritten; every multiplier (AO, skirt, band, aspect,
  jitter) is still linear and still upstream of the conversion (Q5, Q23).
- `kubik_to_linear()` in `Look.HEADER` and in `FIREFLY_SHADER`, because
  `EMISSION` is not decoded by the engine the way `ALBEDO` is and the glowing
  mushrooms and the fireflies would otherwise emit at their sRGB value.
- `SkyCycle.sun_energy()`: 0.32/0.70 -> **0.75/1.00**.
- `_apply_fog_distances()`: `fog_sky_affect` 0.6 -> **0.0**,
  `fog_aerial_perspective` 0.25 -> **0.0**. `SKY_TOP_DAY` `#4D80D4` ->
  **`#89A1CB`**.

**The swatch tables.** Compatibility / llvmpipe, 1280x720, time frozen at
`day_start` 0.380, sun elevation 0.688, sun `#FFF2D1`, shade `#999EDB`.

*Before anything (the bug, energy 0.70):* worst channel delta **114**.

| swatch | authored | predicted | measured |
| --- | --- | --- | --- |
| `#808080` lit | `#808080` | `#6c6758` | `#0a0906` |
| `#86B04A` lit | `#86B04A` | `#728e31` | `#0e3e00` |
| `#E0AC7E` lit | `#E0AC7E` | `#bf8b56` | `#c93805` |
| `#4C8FBF` shade | `#4C8FBF` | `#2a56a4` | `#000337` |

*After the fix (energy 1.00):* worst channel delta **2**. Tolerance is 6.

| swatch | authored | predicted | measured | delta |
| --- | --- | --- | --- | --- |
| `#FFFFFF` lit | `#FFFFFF` | `#fff2d1` | `#fff2d1` | 0 0 0 |
| `#FFFFFF` shade | `#FFFFFF` | `#999edb` | `#999edb` | 0 0 0 |
| `#808080` lit | `#808080` | `#807968` | `#807968` | 0 0 0 |
| `#808080` shade | `#808080` | `#4a4d6d` | `#4a4d6d` | 0 0 0 |
| `#202020` lit | `#202020` | `#201e18` | `#1e1c16` | -2 -2 -2 |
| `#202020` shade | `#202020` | `#0f0f1a` | `#0d0e18` | -2 -1 -2 |
| `#86B04A` lit | `#86B04A` | `#86a73b` | `#86a73b` | 0 0 0 |
| `#86B04A` shade | `#86B04A` | `#4e6c3e` | `#4e6b3e` | 0 -1 0 |
| `#4E7A32` lit | `#4E7A32` | `#4e7427` | `#4e7425` | 0 0 -2 |
| `#4E7A32` shade | `#4E7A32` | `#2b492a` | `#2b4928` | 0 0 -2 |
| `#BFB48C` lit | `#BFB48C` | `#bfab72` | `#bfab72` | 0 0 0 |
| `#BFB48C` shade | `#BFB48C` | `#716e78` | `#716e78` | 0 0 0 |
| `#E0AC7E` lit | `#E0AC7E` | `#e0a366` | `#e0a365` | 0 0 -1 |
| `#E0AC7E` shade | `#E0AC7E` | `#86696b` | `#86696b` | 0 0 0 |
| `#4C8FBF` lit | `#4C8FBF` | `#4c889c` | `#4c889c` | 0 0 0 |
| `#4C8FBF` shade | `#4C8FBF` | `#2a56a4` | `#2a56a4` | 0 0 0 |

A lit `#FFFFFF` lands on exactly the sun's colour and a lit `#86B04A` lands on
`#86A73B` - which is the number the tech plan's Q24 predicted from the other
direction, before any of this was measured. That agreement is the strongest
evidence the run has that the fix is the intended one.

**Deviation from the written procedure.** The tech plan's Stage 0.3 prescribes
Experiment A - push the swatch colours as sRGB and see whether the lit row comes
good - and, if it does, "convert at the push". Experiment A on its own would
have **failed here**, and it would have failed for a reason that does not point
at the cause: the squaring is downstream of `ALBEDO` and no push-side change can
reach it. A uniform-fed albedo bends exactly as a vertex-fed one does (the ramp
sheet's `vertex` and `uniform` rows are byte-identical), which is what ruled the
vertex path out. The push conversion is still in - it is genuinely needed, and it
is the plan's fix - but it is one of two fixes, not the fix.

**Questions taken alone.**

- *The baseline tour set (`look2-base`) was not shot before the code changed.*
  The gates on `main` took longer than budgeted and the transfer work started
  first. The baseline is shot from a worktree at `main` instead, which is the
  same commit and the same frames. Recorded because it is a departure from the
  setup section's order.
- *`swatch-ramp` is a sheet the plan does not ask for.* Kept, because finding 2
  is unresolvable without it and it costs one gallery run.
- *`Look.to_wire()` rather than a bare `linear_to_srgb()` at each call site.*
  One named function so the conversion is greppable and there is exactly one
  place to change if Forward+ disagrees. Same arithmetic.

**Probe, after Stage 0:** heightmap `76cccdb6`, config `da8868d1`, 73,675
trees, spawn `(-44, -124)`. Unchanged.

**Sampled checks.** `1-spawn`, 1280x720, 9x9 means.

| region | px | measured | window | verdict |
| --- | --- | --- | --- | --- |
| sky, clear band mid-height | (430,120) | `#819cc3` H 215.2 S 33.9 V 76.6 | H 210-225, S 28-38, V 76-84 | pass |
| meadow, near | (640,600) | `#85a53a` H 77.9 S 64.8 V 64.7 | - | see below |

The near meadow measured **`#85a53a`**. The authored `Block.GRASS` is `#86B04A`
and `Look.predict()` says a lit `#86B04A` at noon lands on `#86A73B`. It landed
on `#85A53A`, in the real world, through the real mesher, with baked AO and the
aspect tint on it. That is the fourth pillar's "what is authored is what is on
screen" holding outside the test rig.

**Eye check.** `build/tour/look2-0-transfer/1-spawn.png` - flatter and paler
than look v1, exactly as the plan says Stage 0 must be. The far ranges are
washed out to near-white (V 98, S 17 at (200,150)); that is Stage 2's job and
is not touched here.

---

## Stage 1 - Light: shade as ink, dusk that exists, the sets

**Shipped.**

- `SkyCycle.KEYFRAMES` - the four time-of-day sets as a **table** (habit 1),
  hex as authored, converted to linear once on first use and cached.
  `fog_dark` is derived (`mix(fog, black, 0.18)`), not authored.
- `keyframe_at(elevation, morning)` blends night -> noon by `day_amount()`,
  then toward the horizon keyframe by `dusk_amount()` **at weight 1.0**. Look
  v1's 0.85 / 0.75 are gone, which is the whole of "dusk exists": the dusk set
  was previously never reached.
- `sun_color()`, `fog_color()`, `shade_color()`, `sun_energy()` are now
  one-line wrappers over the table with a `morning` argument defaulting to
  false, so `_test_day_cycle` kept its shape and still passes.
- `apply()` reads one Dictionary and publishes everything from it, and computes
  `morning := time_of_day < 0.5`. Dawn is live from this stage, not Stage 2.
- `Look.RAMP`: `BAND_HALF` 0.12 -> **0.22**, `LIT_BLEACH` **0.10**, and the
  luminance-keeping shade mix through `kubik_shade_desat`.
- New globals in `project.godot`, `Look.HEADER` and `Look.publish()`:
  `kubik_shade_desat` (float), `kubik_fog_dark` (vec4), `kubik_water` (vec4).
  `publish()` takes the keyframe Dictionary instead of five arguments.

**The change the plan did not ask for, and why.**

Stage 1's ink formula needs the albedo in a form that is not a plain scale - it
*desaturates* it - so `light()` has to own the whole expression. Written the way
the plan spells it (`DIFFUSE_LIGHT += mix(shade_alb * kubik_shade.rgb, ...)`)
that would have re-introduced the Stage 0 squaring on this renderer, because
the engine multiplies whatever `light()` writes by `ALBEDO` again.

So every `fragment()` now sets **`ALBEDO = vec3(1.0)`** and hands the real
linear colour to `light()` through a `varying vec3 v_albedo`.

This is worth Marcel's attention because **it makes the ramp correct whichever
way that renderer question goes.** With `ALBEDO` white, `ALBEDO * DIFFUSE_LIGHT`
and `DIFFUSE_LIGHT` are the same thing, so the "is the albedo applied twice"
disagreement in BLOCKING finding 2 can no longer produce a wrong picture. What
is left of that finding is one narrower question - whether the renderer decodes
an 8-bit vertex colour before `COLOR` reaches the fragment shader. On
Compatibility it does not (the ramp sheet's `vertex` and `uniform` rows are
byte-identical, and the `uniform` row is definitionally raw), so the shader
decodes it itself with `kubik_to_linear(COLOR.rgb)`.

**If Forward+ decodes vertex colour on its own, the fix is one line in one
place:** delete the `kubik_to_linear(...)` call in `Look.OPAQUE_SHADER`'s and
`Look.WATER_SHADER`'s `fragment()` and read `COLOR.rgb` straight into
`v_albedo`. `Look.to_wire()` stays either way. The `swatch-ramp` sheet answers
it in one run.

**The swatch table.** Compatibility, worst channel delta **1**, tolerance 6.
Sun `#FFF2D1`, shade `#7A7396`, desat 0.55, bleach 0.10.

| swatch | predicted | measured | | swatch | predicted | measured |
| --- | --- | --- | --- | --- | --- | --- |
| `#FFFFFF` lit | `#fff2d1` | `#fff2d1` | | `#FFFFFF` shade | `#7a7396` | `#7a7396` |
| `#808080` lit | `#948c78` | `#948c78` | | `#808080` shade | `#3a3649` | `#3a3649` |
| `#202020` lit | `#5e594c` | `#5e594c` | | `#202020` shade | `#09080e` | `#09080e` |
| `#86B04A` lit | `#98b05a` | `#98b05a` | | `#86B04A` shade | `#454a4b` | `#454a4b` |
| `#4E7A32` lit | `#728851` | `#728851` | | `#4E7A32` shade | `#2a3031` | `#2a3031` |
| `#BFB48C` lit | `#c7b380` | `#c7b380` | | `#BFB48C` shade | `#574f5e` | `#564f5e` |
| `#E0AC7E` lit | `#e3ad77` | `#e3ad76` | | `#E0AC7E` shade | `#5f4e5c` | `#5f4e5c` |
| `#4C8FBF` lit | `#7197a2` | `#7197a2` | | `#4C8FBF` shade | `#333c5f` | `#333c5e` |

**For Marcel.** `LIT_BLEACH` 0.10 is a mix toward white in LINEAR, so it lifts
dark colours much harder than light ones in perceptual terms: a lit `#202020`
now lands on `#5e594c`. That is the tunable's start value from the plan and it
is inside its range, but it is the number to look at first if the leaves and
the spruce read as washed out on your machine. Range is 0-0.15; 0 turns it off.

**Stage 1 tour.** `build/tour/look2-1-light/`, 12 shots, Compatibility.

| check | shot, px | measured | window | verdict |
| --- | --- | --- | --- | --- |
| shaded rock | `2-summit` (640,500) | H 256.4 S 23.9 V 31.0 | H 230-280, V 25-45 | **pass** |
| shaded rock | `2-summit` (450,550) | H 248.5 S 24.3 V 43.0 | H 230-280, V 25-45 | **pass** |
| lit ground, night | `12-meadow-night` (640,600) | S 27.1 | S <= 60 (was 87) | **pass** |
| shaded spruce | `7-forest-interior` (540,150) | H 193.4 S 13.9 V 20.7 | H 200-280, S 20-50 | **fail** |
| dusk sky | `11-forest-dusk` (300,120) | V 33.7 | V >= 60 | **fail** |

**The two failures, and what was done about them.**

*Shaded spruce, H 193 S 14 against a window of H 200-280 S 20-50.* The shade
lands between the leaf's own green (H 152) and the ink's violet (H 252) and the
two cancel each other's saturation on the way. `shade_desat` is a tunable
(0.55, +-0.10) and raising it moves the hue toward the ink - but the noon ink
`#7A7396` is itself only 23% saturated, so no value in range reaches S 20-50
*and* H 200-280 at once. The window and the ink are in tension, and the ink is
not tunable (Q4). Left at 0.55, recorded, per protocol 6. Stage 4 re-authors
`LEAVES` and `LEAVES_SPRUCE_B` and this is re-measured there.

*Dusk sky V 34 against a window of V >= 60.* Stage 1 publishes `sky_top` from
the table but still hands the sky its old horizon (`kf["fog"]`), and the
three-stop band, the horizon row and `cloud_lit` are all Stage 2's. Not chased
here; re-measured after Stage 2, which is where the sky is actually built.

**The eye, on `11-forest-dusk`:** navy-blue tree masses with internal steps, a
mauve sky, gold on the lit edges and orange where the sun reaches through. It
reads as a printed dusk rather than as a dimmed noon, which is the sentence
Stage 1 exists for. `7-forest-interior` is the weaker shot - milky rather than
navy - and that is the `LIT_BLEACH` note above plus the old pale fog.

**A bug this run introduced and fixed.** `FloraModels.SHADER` has its own
`fragment()`. Stage 1 moved the albedo out of `ALBEDO` into a varying in
`Look`'s two shaders and missed that third one, so every tuft, fern and
mushroom in the world drew **pure black** - visible in the first
`7-forest-interior` shot of the stage. Fixed, and the tour re-shot before any
of the numbers above were taken.

**Gates, Stage 1:** self-test all passed; character self-test 28 tests all
passed (the `part AO` assertions now decode the wire before measuring the AO
multiplier, per Q22 - converted, not loosened); probe `76cccdb6` / `da8868d1` /
73,675 trees / spawn `(-44, -124)`.

**A finding about the light curve, for Marcel.** `dusk_amount()` is
`clamp(1 - |elevation| * 4.5)`, which is non-zero only for `|elevation| <
0.222`. On this world's arc that is roughly `time_of_day` 0.71-0.79 and its
mirror at dawn. So:

- `--time 0.82`, which every character gallery sheet calls "dusk", has
  elevation **-0.402** and lands on the **night** keyframe with `dusk = 0.00`.
  The dusk sheets in the character gallery have never been shot at dusk.
- The tour's `11-forest-dusk` is at **0.74** (elevation +0.059, `dusk` 0.73)
  and is at dusk. `screenshot_tour.gd` already carries a comment explaining
  why it is not 0.85 - look v1 found half of this and did not generalise it.

Left alone deliberately (protocol 6: fewer files, nearer today's value) -
widening `dusk_amount` would move every hour of the day, and the gallery's
`--time` is not this plan's to change. **Recommend for a later plan:** the
gallery's dusk sheets should be shot at 0.74, not 0.82.

---

## Stage 2 - Sky and distance

**Shipped.**

- `Look.FOG_FN`: `poster_fog(view_vertex, albedo)` - the target is the
  fragment's OWN colour desaturated and lifted, then mixed toward the fog, so
  hue is held across the bands and a far hillside still reads as a hillside.
  A per-material `fog_dark_mix` blends toward `kubik_fog_dark`.
- `Look.figure_material()` - the same shader with `fog_dark_mix 1.0`.
  `VoxelModel` and `FarTreeMeshes` return it; `FloraModels` sets the uniform on
  its own material. Terrain keeps `opaque_material()`.
- `Look.SKY_SHADER` rewritten: `sky_mid` and a two-segment band mix, the
  horizon row instead of the fog, `kubik_fog_color` below the horizon,
  `poster_wedges()` (24 pairs, alternating long/short, tapering to 0.15 of base
  width), a sun halo that only takes the sun's colour at dusk, a moon halo and
  a gold `moon_color` disc, and clouds sampled in polar coordinates with
  `cloud_lit`.
- `far_field_job.gd` `_band_color()`: monotonic, keyed to the band the treeline
  falls in, read once per job from `generator.zone_thresholds[ZONE_FOREST]`.
- `worldgen_config.gd`: `fog_bands` 6 -> 4, `FOG_START_RATIO` 0.6 -> 0.4,
  `far_band_m` 40 -> 60, `far_band_step` 0.06 -> 0.03, `aspect_tint` 0.12 ->
  0.18. All four already on F4.
- `screenshot_tour.gd`: `13-meadow-dawn` (0.24) and `14-postcard-dusk` (0.74).
  The tour is 14 shots from here on.

### The sky was never sRGB-encoded, and that is a look v1 bug

**Measured.** At noon the visible sky band mixes to a linear
`(0.428, 0.514, 0.663)`. Its sRGB encoding is `#B0BFDA`. Written out as raw
bytes it is `#6D83A9`. The frame came back **`#6A7FA8`**.

So a sky shader's `COLOR` goes to the framebuffer **without** the linear-to-sRGB
conversion every other surface gets, and every sky colour in this game has been
displayed as its raw linear value since look v1. It is why `SKY_TOP_DAY` had to
be `#4D80D4` - a colour nothing like the poster - to arrive as something that
looked like one, and it is why the dawn keyframe's pale peach `#F3C79E` horizon
first rendered as a dark rust brown.

Fixed with `kubik_to_srgb()` in the sky shader, applied once to `col` on the way
out. Every sky uniform stays linear, like every other palette in the game.

**This is worth checking on Forward+ too** - it is the same class of question as
BLOCKING finding 2 and the `13-meadow-dawn` shot answers it by eye in one run:
a pale peach dawn is right, a rust-brown one means Forward+ encodes and this
conversion is one too many.

### Two cloud fixes

- **The underside offset.** The plan says a constant radial offset of 0.35
  polar units. Measured, a cloud in this field is about half a unit across
  radially, so 0.35 swallowed the whole shape: every cloud drew as its own
  underside - dark brown blobs. `CLOUD_LIP` is **0.08**, which is a lip.
  (The plan's sign is negative; positive radius is *down* the sky in this
  projection, so the lip is `+`.)
- **The second night term.** Look v1 derived a cloud's lit colour from the sky
  band and then darkened it by up to 0.35 after dark. `cloud_lit` is an
  authored keyframe row now - `#FFE2C8` at dawn, `#6F7C9E` at night - so the
  hour is already in it, and multiplying again turned a warm dawn cloud into a
  taupe smudge. Removed.

### Sampled checks

| check | shot, px | measured | window | verdict |
| --- | --- | --- | --- | --- |
| far flank monotonic | `9-treeline` (640,300/220/150) | V 30.6 -> 49.4 -> 81.2 | non-decreasing | **pass** |
| dusk sky | `11-forest-dusk` (300,120) | H 249.8 S 28.2 V 68.2 | H 240-290, V 55-85 | **pass** |
| dusk sky | `11-forest-dusk` (420,80) | H 263.1 V 66.3 | H 240-290, V 55-85 | **pass** |
| range sat | `6-postcard` (615,255) | S 20.8 | S <= 25 | **pass** |
| range sat | `6-postcard` (400,230) | S 4.7 | S <= 25 | **pass** |
| night sky vs ground | `12-meadow-night` (640,330) | V 41.6, ground V 42.0 | V >= 35 **and** > ground | **pass / marginal fail** |
| range vs sky above | `6-postcard` (615,255) vs (640,20) | V 75.7 vs 83.1 = 7.4 below | >= 8 below | **marginal fail** |
| range vs sky above | `6-postcard` (400,230) vs (640,20) | V 64.8 vs 83.1 = 18.3 below | >= 8 below | **pass** |

The two marginals are 7.4 against 8 and 41.6 against 42.0. Both are inside a
rounding of the window and neither has a tunable that would move it without
moving something the plan fixes; recorded, not chased.

**Eye.** `9-treeline` - **the red zigzag is gone.** The far ranges are stacked
mauve planes, each lighter than the one below, cut hard against a pale blue
sky, and cream lozenge clouds sit along the top. `6-postcard` - opaque stacked
planes against a cream horizon. `11-forest-dusk` - a three-stop lilac dusk sky.
`13-meadow-dawn` - a pale peach dawn that could not have existed before this
stage, because dawn had no keyframe and the sky had no encoding.

**FOR MARCEL - the one eye check that fails.** `1-spawn`, noon: **the clouds
are close to invisible.** With the sky encoded correctly the noon sky is pale -
a cream horizon into a pale blue - which is what the keyframe table actually
says; look v1's rich blue was the un-encoded accident. But `cloud_lit`
`#F2E8D0` (V 95) against a cream horizon (V 92) has three points of contrast,
and the plan's own check for this shot is "clouds are lozenges along the
horizon". They read at dawn, at dusk and higher in the sky at noon; along the
noon horizon they do not.

`cloud_lit` is a keyframe row and therefore not tunable by the agent (Q4), and
the honest fix is a decision, not a tuning: either the noon `cloud_lit` goes
lighter than `#F2E8D0`, or the noon `horizon` goes down from `#EBDFC8`, or the
cloud takes a floor of one band above whatever sky it sits on. Recorded per
protocol 5 rather than invented.

**Gates, Stage 2:** self-test all passed; character self-test 28 all passed;
swatches worst channel delta **1**; probe `76cccdb6` / `da8868d1` / 73,675
trees / spawn `(-44, -124)`.
