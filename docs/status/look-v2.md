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
