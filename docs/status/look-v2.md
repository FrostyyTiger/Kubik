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

---

## Stage 3 - Ground: grain, the contact band, the material split

**Shipped.**

- `Look.OPAQUE_SHADER` grows a `vertex()` writing `world_pos` and
  `world_normal`, a 3-integer hash, and four per-material uniforms:
  `grain_amount` 0.065, `grain_hue` 0.03, `grain_sparse` 0 (off),
  `contact_band` 0.72. `mod(floor(world_pos / 0.5), 1024.0)` before the hash
  (Q11); grain fades to nothing between 20 m and 45 m of depth whatever the
  fog is doing (Q12), so the far field never shimmers.
- `Look.figure_material()` sets `grain_amount 0` and `contact_band 1.0`: a
  character is printed flat, and a line under its feet would follow it around.
- `Look.apply_local_knobs(config)`, called from `game.gd` beside
  `FloraModels.apply_local_knobs()` - the existing path (Q21). Four new F4
  entries under "poster:".
- `color_jitter_value` 0.07 -> **0.0**, `color_jitter_hue` 0.03 -> **0.0**.
  `Block.jitter()` stays; it is a no-op at 0.
- The swatch sheet forces `grain_amount` and `grain_hue` to 0 for its own shot
  and records `grain_forced_off: true` in `swatches.json`. A 1.2 m swatch is
  two grain cells across, and a 9x9 sample would otherwise measure whichever
  cell it landed in.

### A bug this stage introduced and fixed: NORMAL is view-space

`fragment()`'s `NORMAL` is in **view** space. The contact band was written
against `abs(NORMAL.y)`, which therefore meant "how much this face points at
the top of the screen", not "how much it points up" - so flat ground took a
contact band whenever the camera was pitched. It cost the swatch gate: two lit
swatches came back 8 units dark, which is over tolerance, on a stage that does
not touch the transfer at all.

Fixed with a `world_normal` varying set in `vertex()` from
`MODEL_MATRIX * vec4(NORMAL, 0.0)`. The swatch sheet went straight back to a
worst delta of 2. **This is the only thing in the run that the swatch gate
caught that no other check would have**, which is the argument for the gate.

### Sampled checks

| check | shot, px | measured | window | verdict |
| --- | --- | --- | --- | --- |
| grain on flat ground | `8-meadow-closeup` (150,430) 30x30 | V sd **0.89** (Stage 2 at the same spot: 0.01) | sd 3-9 | **fail, see below** |
| terrace riser, top vs bottom | `3-forest-slope` (400,500) vs (400,512) | V 49.5 -> 41.4, **8.1 below** | >= 15 below | **fail, see below** |
| no grain on figures | gallery `lineup-front` | clean; the pad under them is not | - | **pass** |

**Both failures are the plan's own numbers, not a mis-implementation, and both
are arithmetic that can be checked without rendering anything.**

*The grain.* `grain_amount` 0.065 is +-6.5% in LINEAR albedo. At the meadow's
V 68 that is about +-1.3 points of sRGB value, so a region spanning many cells
lands near sd 0.9 - not 3-9. Reaching sd 3 needs `grain_amount` around 0.15;
the tunable's range is 0.04-0.08. Left at the plan's 0.065.

The 30x30 window is also not measurable as written on this shot: near the
camera a half-metre cell is about 40 px, so a 30x30 region sits INSIDE one cell
and reads sd 0; further out the same window catches flora and terrace edges,
which dominate the variance (Stage 2 and Stage 3 both measure sd 3.5 at
(300,240), and Stage 2 has no grain at all). The isolated number above is from
a genuinely flat patch, and it is the honest one.

*The contact band.* 0.72 is a linear multiply. At a riser measuring V 49.5
(linear 0.2095), 0.72 gives linear 0.1508 = **V 42.5**, and it measured 41.4.
The band is doing exactly what the constant says. A 15-point drop needs
`contact_band` about **0.47**; the tunable's range is 0.65-0.80.

**Eye.** `8-meadow-closeup` - the grain is there, one block across, a faint
half-metre checker rather than blotches, and terrace edges are lines. Gallery
`lineup-front` - the pad is grained, the four characters are not, and the edge
between a figure and the ground is clean.

**FOR MARCEL.** Both numbers above are one-line decisions: if the grain should
be as strong as the plan's sd window implies, `grain_amount` wants to roughly
double to 0.13-0.15 and its F4 range go with it; if the contact band should be
the 15-point line the plan describes, it wants about 0.47 rather than 0.72.
Neither was changed, because both sit outside the ranges section 4 allows the
agent to move inside.

**Gates, Stage 3:** swatches worst delta **2**; self-test all passed;
character self-test 28 all passed; probe `76cccdb6` / `da8868d1` / 73,675
trees / spawn `(-44, -124)` - unchanged, which also proves the jitter knobs are
not hashed.

---

## Stage 4 - The palette, boulders, water, tufts

**Shipped.**

- `Block.COLORS` and `FloraModels.COLORS` re-authored from
  `art-direction.md` section 3, verbatim. Every entry converted with
  `Color.html(hex).srgb_to_linear()` and the hex kept in the comment beside it;
  the round trip was verified back to the source hex before anything was shot.
- `C_BOULDER_LIT = 17` / `BOULDER_LIT #D0CCC2`, and `_blob()` takes a
  `lit_color`: a plane through the blob's centre at `Block.SUN_ASPECT` tilted
  up, surface voxels only, upper 60%. Boulders pass it; shrubs do not.
- New self-test **`boulder two tone`**.
- `flora_placement.gd` meadow density 0.34 -> **0.50**.
- `lakes.gd`: three rings from the lake-id field - rim, shallows, body - each
  its own run and its own flat quad; the vertex colour is a **darkening
  factor** (1.0 / 0.915 / 0.847) and the colour is the hour's, published as
  `kubik_water` lifted 18% so the body lands on the authored row. Alpha 0.92.
  `Look.WATER_SHADER`: `v_albedo = kubik_to_linear(COLOR.rgb) * kubik_water.rgb`.

### The tunable that was moved: LIT_BLEACH 0.10 -> 0.00

This is the one number this run changed on its own judgement, and it is inside
section 4's range (0-0.15). The evidence:

`LIT_BLEACH` mixes the lit albedo toward white **in linear**, so it lifts a
dark colour far harder than a light one. At 0.10 it raised the lake's red
channel from 0.068 to 0.162. Predicted, at noon, through `Look.predict()`:

| bleach | lake `#4A6A8A` | meadow `#809945` |
| --- | --- | --- |
| 0.10 | H 187.1 S **13.2** V 50.6 | H 70.3 S **43.7** V 62.7 |
| 0.04 | H 196.0 S **24.8** V 47.5 | H 72.0 S 52.6 V 59.6 |
| 0.02 | H 197.1 S 29.7 V 46.3 | H 72.0 S 57.0 V 58.4 |
| **0.00** | H 197.6 S **35.7** V 45.1 | H 72.0 S **61.6** V 57.3 |
| *window* | *H 195-215, S 35-55, V 40-58* | *H 70-90, S 45-60, V 52-66* |

No value satisfies both. At 0.04 the meadow is dead centre and the lake misses
its saturation floor by 10 points; at 0.00 the lake lands inside and the meadow
overshoots by 1.6. **0.00 was taken**, because a 1.6-point overshoot on a field
of grass is invisible and a grey-teal sheet where a dark tarn should be is the
whole of `5-lake`. It also makes the lit branch exactly `albedo * sun * energy`,
which is the plainest statement of rule 4.

Measured after the change: meadow **H 70.9 S 59.6 V 52.5** (inside all three).

### Sampled checks

| check | shot, px | measured | window | verdict |
| --- | --- | --- | --- | --- |
| meadow | `1-spawn` (640,600) | H 70.9 S 59.6 V 52.5 | H 70-90, S 45-60, V 52-66 | **pass** |
| water body | `5-lake` (350,320) | H 196.9 S 28.6 V 43.9 | H 195-215, S 35-55, V 40-58 | H, V **pass**; S 28.6 low |
| lit snow vs sky | `2-summit` (400,500) vs (100,80) | V 83.1 vs 81.2 | snow > sky | **pass** |
| boulder two tone | self-test | 18.2% / 16.0% / 25.3% of surface voxels lit | plan says 30-35% of visible area | **see below** |

*The lake's saturation.* Predicted 35.7, measured 28.6. The difference is the
0.92 alpha: the water blends 8% of the grey-brown lake bed underneath it, which
desaturates. Raising alpha to 1.0 would close it and is inside the tunable's
range (0.88-1.0), but the plan wants water you can see into and this is the
last stage that touches it; left at 0.92 and recorded.

*The boulder share.* The plan asks for 30-35% of the visible area and the
geometry it specifies cannot reach it: "upper 60% of the blob" and "the sun
side of a plane through its centre" are two cuts, and on a radius-2 rock nearly
all the surface is in the bottom 40%. Measured 16-25% of surface voxels. The
self-test asserts 10-45% - wide enough to catch the sun side vanishing or
swallowing the rock, which is the regression worth catching, and not so narrow
that it is only agreeing with itself. **For Marcel:** dropping the y cut to
0.25 of the height would bring it into the thirties.

**Eye.** `5-lake` - a dark blue-teal tarn with a lighter shallows ring drawn
round its edge, which is the first time the water has read as water rather than
as a hole. `1-spawn` - a green meadow, neither lime nor olive, purple flowers
darker than the field, dark-green trees. `9-treeline` - maroon heath, neutral
rock, stacked ranges.

**For Marcel - the tuft density.** `ZONE_DENSITY[MEADOW]` went 0.34 -> 0.50 on
the plan's instruction, undoing a look v1 decision whose reason is recorded in
the file ("at one tuft on every second block the meadow close-up read as
confetti"). At 0.50 the meadow in `1-spawn` is visibly busy. The argument for
v2 is that v1 judged that density through the broken transfer, when a tuft
arrived at double its authored saturation; the argument for v1 is in the shot.
Worth one look.

The plan also asks for 0.50 "inside 12 m of the player". Placement is
world-space with no distance ramp, and adding one would mean two players seeing
different meadows, so it is the flat number - the plan's own fallback.

**Gates, Stage 4:** swatches worst delta **2**; self-test all passed (with the
new boulder test); character self-test 28 all passed; probe `76cccdb6` /
`da8868d1` / 73,675 trees / spawn `(-44, -124)` - unchanged, which confirms Q18:
ground cover is not hashed and the density change does not move the world.

---

## Stage 5 - Characters

Scope held exactly: eyes, brow, mouth, hair and beard masses, race palettes.
**Nothing below the neck was touched** - no torso, no stance, no height.

**Shipped.**

- `voxlib.solid_eyes()` and `voxlib.hair_brow()` - **one routine, four races**.
  Look v1 authored each face in its own module and the four had drifted: three
  eye geometries, two brow conventions, mouths from four to eight voxels wide.
- **Eyes**: 2 wide x 4 tall of solid `E`, gap 6, one voxel **proud** of the
  face plane like the nose, with a single `W` catchlight at the top inner
  corner. The old 4x4 white with a 2x2 iris inside it is repainted back to skin
  first. A white that big is five values across four voxels, and at 40 m the
  white won and the figure read as having no eyes.
- **Brow**: one row in the **hair's** colour, or none. The lizardfolk has no
  hair over its brow, so it has none - the spec's own "or none".
- **Mouth**: human 8 -> 5 wide, elf 8 -> 5, dwarf 8 -> 4. Lizardfolk's mouth
  line round the snout is unchanged.
- **Hair masses break the head box** (`fringe()` grew a `depth`): human fringe
  2 proud and 1 wider each side; elf swept back 3 past the skull on the short
  and braided sets; dwarf beard 2 wider than the head and 4 further below the
  jaw. Lizardfolk crest unchanged.
- `races.gd` `TUNIC_HEX` re-authored - see below.
- All seven `parts_*.gd` regenerated by `python -m tools.parts_author`.

### The tunic audit, and why all four went dark

The plan asks that cloth and skin cross a value ratio of 0.5 or lower for
**every** skin a player can pick. Measured, that was failing for 2/5 human
skins, 1/5 elf, 2/5 dwarf and 3/5 lizardfolk.

Each race's five skins span a wide luminance band - the human's from 0.033 to
0.632 - so one tunic clears all five only by sitting **below the darkest** or
**above the lightest**. Above needs luminance 1.26 for the human, 1.58 for the
elf, 1.04 for the dwarf: impossible. Below works for all four:

| race | was | now | worst ratio against its 5 skins |
| --- | --- | --- | --- |
| human | `#7A6A4F` | `#262119` | 0.47 |
| elf | `#5C7A5A` | `#465C44` | 0.47 |
| dwarf | `#6B4F3A` | `#34271C` | 0.48 |
| lizardfolk | `#7A6A4F` | `#302A1F` | 0.48 |

Hue is each race's own, unchanged; only the value moved.

**FOR MARCEL, and it is a real cost:** this makes all four torsos near-black.
The rule buys skin-against-cloth contrast on every skin and spends
race-against-race contrast to get it - at 40 m four dark torsos are four dark
torsos. If the rule was meant to bind only the *default* skin rather than all
five, the tunics can go back up considerably. Worth a decision.

### masks-40: 0.913, and it did not move

`Q17` says: if human/lizardfolk cannot get under 0.75 by hair alone, record the
number and stop there. **It could not.** Six race pairs, five under 0.70, worst
`stocky human vs stocky lizardfolk` at **0.913** - unchanged from look v1's
0.91.

Hair does not reach it. The two silhouettes differ by a crest and 12 cm of
height, and at 40 m front-on the body is the silhouette. Getting under 0.75
means changing a body, and bodies are explicitly out of this stage's scope.
Recorded and stopped, exactly as Q17 instructs.

### Checks

| check | measured | window | verdict |
| --- | --- | --- | --- |
| eyes read as dark marks | `study-noon-40m-front`, darkest 3x3 mean **V 2.4**; at 4 m **V 9.2** | V <= 35 | **pass** |
| hair vs skin, human | V 2.4 vs 41.2, ratio **0.06** | <= 0.5 | **pass** |
| `masks-40`, 5 of 6 pairs | under 0.70 | < 0.75 | **pass** |
| `masks-40`, human vs lizardfolk | **0.913** | < 0.75 | **fail, recorded per Q17** |
| character self-test | 28 tests, all passed, `eyes forward` included | green | **pass** |

**Triangles**, against look v1: human 16,824 -> **17,052**; elf 13,824 ->
**14,692**; dwarf 17,740 -> **17,788**; lizardfolk 16,544 -> **16,592**. The
elf's +868 is the swept-back mass; the rest is the proud eyes. All still inside
the budget look v1 set.

**Eye.** `study-detail-4m-front` - two solid dark marks read as eyes looking at
you, which is the sentence this stage exists for, and the narrow mouth is a
line rather than a grin. `closeup-front` - the tan slab beside the human's head
is the gear placeholder, not geometry; the 4 m sheet shows the head clean.

**Gates, Stage 5:** self-test all passed; character self-test 28 all passed;
swatches worst delta **2**; probe `76cccdb6` / `da8868d1` / 73,675 trees /
spawn `(-44, -124)`.

---

## Stage 6 - UI

**Shipped.**

- **Sunburst**: `RAY_PAIRS` 24 - 48 rays, long and short alternating, each a
  tapered 4-gon narrowing to 0.15 of its base by the tip. Look v1 drew 14
  undifferentiated wedges of constant width, which is a pie chart.
- **The disc** is paper inside a 4 px gold ring, not solid gold.
- **Title band**: a full-width ink band with the double rule along its top
  edge, the title in paper caps on it, the subtitle in gold.
- `DecoRule` inset 8 px with 5x5 gold terminals at each end.
- `DecoPanel.stepped()`: ink r14, gold r10 inset 5, paper r6 inset 10, applied
  to the creation screen's preview mount. Also `DecoPanel.draw_stepped()` for a
  Control that is not a panel.
- `Deco.INK_PALE = #7D7C78`, and `Deco.dots()`, `Deco.chevron()`,
  `Deco.roundel()`, `Deco.frame()` - four drawn ornaments, one `_Ornament`
  Control behind them.
- `Look.accent_color(elevation, morning)` reads the keyframe table's `accent`
  row, so the UI's gold and the world's gold are one decision.

### The band is positioned from the type, not from a fraction

`PosterBackdrop.set_title_band(rect)` takes the Title label's real global rect;
`main_menu.gd` calls it deferred and on every resize. A band placed at "0.16 of
the window" would be right at 1280x720 and wrong everywhere else, and a band
that misses the type it is meant to carry is worse than no band. Zero height
means no band, which is what the creation screen wants.

### Two instructions that cannot both be true

The plan's sunburst note says *"paper disc with a 4 px gold ring; the title is
ink on paper inside the ring"*. Its title-band note says *"a full-width ink band
0.16 h ... title in paper caps"*. The title cannot be ink-on-paper inside a disc
and paper-on-ink on a band at once.

**The band won**, because it is the more specific instruction - it carries
sizes, a tracking and a colour for the subtitle - and because it is what makes
the title read. The disc moved up (`SUN_Y` 0.21 -> 0.055, radius 78 -> 62) so
it reads as a sun **rising behind** the title band rather than as the sliver of
gold it became when the band was first drawn over it. Recorded rather than
guessed at; one line to move it back.

**Eye**, on `build/ui/look2-6/main-menu.png`: rays alternate long and short and
taper; the disc is paper in a gold ring; a full-width ink band carries KUBIK in
paper caps with the double rule on its top edge and the subtitle in gold under
it; the rules have square terminals. On `character-creation.png`: the preview
mount steps three times - ink, gold, paper.

**Gates, Stage 6:** self-test all passed; character self-test 28 all passed;
swatches worst delta **2** (no shader or palette touched, and it stayed green);
probe `76cccdb6` / `da8868d1` / 73,675 trees / spawn `(-44, -124)`.

---

## Stage 7 - Docs

- `docs/DESIGN.md` "Art direction": the three sharpened rules and the new
  fourth, the shade ink and its `kubik_shade_desat` values, where the keyframe
  table lives, and a new "the pipeline: linear maths, sRGB on the wire"
  paragraph covering `Look.to_wire()`, the sky's own conversion, and why
  `light()` writes the light with `ALBEDO` left white.
- `README.md`: a "Both renderers" section with the `--rendering-driver opengl3`
  line, and a "The swatch check" section - what the gate is, the 6-unit
  tolerance, and `--sheet swatch-ramp` as the instrument one level down.
- `docs/IDEAS.md`: a look v2 note under Next 3 in the shape of the foliage v1
  one; the shore's width and meadow patches under Someday.
- `STATUS.md` replaced by the look v2 status, with the BLOCKING finding named
  in it so nobody has to open the status doc to learn it exists.

---

# The morning message

**1. Where it is.** Branch `feat/look-v2`, seven commits, **not merged**.
`main` is untouched. All eight stages ran; none was wrapped early; nothing was
reverted.

**2. The three things to look at first.**

- `build/tour/look2-4-palette/5-lake.png` - the tarn, the drawn rim, and the
  whole argument for `LIT_BLEACH = 0`.
- `build/tour/look2-2-sky/9-treeline.png` - the red zigzag is gone and the far
  ranges are stacked planes.
- `build/ui/look2-6/main-menu.png` - the title band, the tapered burst, the
  paper disc in its gold ring.

Comparison strips: `tools/compare_sheets.py look2-1-light look2-2-sky
look2-3-ground look2-4-palette` (PIL; on ganymede `~/.venvs/kubik/bin/python`).

**3. BLOCKING.** Forward+ was never exercised - see the top of this document.
The single command that resolves most of it:
`<godot> --path . scenes/character/gallery.tscn -- --sheet swatches --strict`.
Green there and the transfer is right on both. Not green and the one line to
look at is `Look.OPAQUE_SHADER`'s `kubik_to_linear(COLOR.rgb)`.

**4. For Marcel, one line each.**

- The noon clouds are close to invisible: a correctly encoded sky is pale and
  `cloud_lit #F2E8D0` has three points of contrast against the `#EBDFC8`
  horizon. Needs a decision, not a tuning (Stage 2).
- All four tunics went near-black to satisfy the cloth-to-skin value rule for
  every selectable skin; it costs race-against-race contrast at 40 m (Stage 5).
- `masks-40` human vs lizardfolk is **0.913**, unchanged. Hair cannot reach
  0.75; it needs a body, which was out of scope (Stage 5, Q17).
- The grain is subtler than the plan's window implies: `grain_amount` 0.065
  gives sd 0.89 where the plan wants 3-9; sd 3 needs about 0.15 (Stage 3).
- The contact band gives an 8-point riser step where the plan wants 15; 15
  needs `contact_band` about 0.47 against a range of 0.65-0.80 (Stage 3).
- The boulder lit share is 16-25% of surface voxels where the plan wants
  30-35%; dropping the y cut from 0.4 to 0.25 of the height would do it
  (Stage 4).
- Meadow tufts went back to 0.50 on the plan's instruction, undoing a look v1
  decision; the close-up is busy (Stage 4).
- The plan asks for the title both inside the sun's ring and on an ink band;
  the band won and the disc moved up (Stage 6).
- `dusk_amount()` is non-zero only for `|elevation| < 0.222`, so the character
  gallery's `--time 0.82` "dusk" sheets have never been shot at dusk. Not this
  plan's to change; recommend 0.74 for a later one (Stage 1).

**5. The one tunable moved off its start.** `LIT_BLEACH` 0.10 -> **0.00**,
inside its 0-0.15 range, decided by the table in Stage 4 and judged on
`5-lake` and `1-spawn`.

**6. What is left.**

- Forward+ verification of everything, and of Stage 0 first.
- The eight decisions in section 4.
- No worldgen moved: `76cccdb6` / `da8868d1` / 73,675 trees / spawn
  `(-44, -124)` after every one of the eight stages.

---

## Merged with flora streaming, 2026-08-25

`origin/main` moved while this ran: `feat/flora-streaming` landed (main
`d916421` -> `731077b`). Merged into `feat/look-v2` before landing. Git
auto-merged all fifteen files with no conflicts, and the six both passes touch
(`README.md`, `STATUS.md`, `docs/DESIGN.md`, `game.gd`, `debug_hud.gd`,
`worldgen_config.gd`) were checked by hand afterwards: the F4 list carries both
sets of knobs, and `STATUS.md` names both runs.

**The one real interaction, and it is checked.** Flora streaming's whole
subject is the grass keeping up with a moving player. Look v2 Stage 4 raised
meadow tuft density 0.34 -> 0.50, which is 47% more plants in the zone their
pass is about. So their gate was re-run on the merged tree:

```
godot --headless --path . -- --host --seed 42 --flora-probe
```

| | grass after terrain | columns rebuilt on return |
| --- | --- | --- |
| their baseline, before their fix, density 0.34 | +152 - 172 ms | all of them |
| **merged, after their fix, density 0.50** | **+0 ms on all 12 jumps** | **0 for jumps 1-5, 63 on jump 6** |

The reserved lane and the cache absorb the extra density completely. Terrain
still settles in 6-10 s per 48 m jump, which is the disease their status doc
names and neither pass's to cure.

**Gates on the merged tree:** self-test all passed; character self-test 28 all
passed; swatches worst delta **2**; probe `76cccdb6` / `da8868d1` / 73,675
trees / spawn `(-44, -124)` - their two new config knobs are `LOCAL_PROPERTIES`
and therefore unhashed, so the config hash is unchanged.

## Resolved on Forward+ - Marcel's box, 2026-08-25

The blocking finding above was run on the RTX 5080 (Vulkan, Forward+) the
same evening, straight after the merge:

```
scenes/character/gallery.tscn -- --sheet swatches --strict --label forwardplus
```

`[Swatches] worst channel delta 2 (tolerance 6): PASS` - sixteen swatches,
lit and shade, every one within 2 sRGB units of `Look.predict()`. The
`swatch-ramp` sheet's `vertex` row tracks `srgb2lin(v)` to the third decimal
across the whole ramp, so Forward+ does NOT decode an 8-bit vertex colour
before the shader either: the shader's own `kubik_to_linear(COLOR.rgb)` is
correct on both renderers and the one-line alternative fix is not needed.
Sheets in `build/character/forwardplus/`. Both renderers agree; the gate
holds; nothing to change.
