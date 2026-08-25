# Look v2 - the poster, refined

The second pass over the art direction decided in look v1. Same direction -
the Art Deco Alpine travel poster, the travel-poster strand - with its details
refined against the evidence in `docs/research/art-direction.md`. That
document is the argument; this one is the work. Read it first.

Runs on `main` (Marcel's call, 2026-08-25: docs and code both land on
`main`; he approved all sixteen refinements the same day). Branched from `main` at `de7a424` (look v1
merged).

**Why now, against the Next 3.** Look v1 put the poster on screen and tuned
it blind against a colour transfer that was not what anyone thought it was:
the vertex colour is linearised twice and the lit band carries a factor of
PI, so every palette entry in the game lands on screen at double its
saturation and every tuned constant was chosen to cancel an error nobody had
written down. That is the first stage here, and it is cheap; but every
colour authored after it - the first enemy's palette, the campfire's light,
the gear - would otherwise be authored against the same error and redone.
The rest of this plan is the research's ranked list, top down, with the
stages that touch worldgen or trees left out by rule.

---

## The refinements

Ranked in the research document, section 5. In this plan:

1. Fix the colour transfer (research section 0) - Stage 0.
2. Dusk exists; shade is an ink; the complete time-of-day sets - Stage 1.
3. Fog is not the horizon; the far field bands monotonic; figures fog darker;
   the sky's three stops, dawn, clouds, rays, the moon - Stage 2.
4. Grain in the fragment shader, the contact band, the material split -
   Stage 3.
5. The palette pass, boulders, water - Stage 4.
6. Characters (only on Marcel's yes) - Stage 5.
7. UI - Stage 6.
8. Docs - Stage 7.

### The rules

The five rules of look v1 stand unchanged (`DESIGN.md`, "Art direction").
Three are sharpened by the research, and the sharpenings bind here:

1. **Shade is an ink.** Rule 1 said shade is a colour, never a darkness. It
   is more than that: the shade side keeps the surface's *luminance* and
   takes the ink's *hue*. A multiply cannot do it; the ramp does (Stage 1).
2. **The horizon is not the fog.** Rule 3 said distance is bands to the sky's
   horizon colour. The bands go to a fog colour a step *darker* than the sky's
   lowest band, so a far range is a cut-out against the sky, never glass over
   it (Stage 2).
3. **Warmth is in the light, coolness is in the shade, and the albedo has
   neither.** A palette entry is the thing's colour in flat noon light; the
   sun makes it warm and the ink makes it cool. Nothing bakes a cast into an
   albedo (Stage 4).

And one new rule, from section 0 of the research:

4. **What is authored is what is on screen.** An authored hex, lit, at noon,
   lands on screen at `authored * sun * energy` and nowhere else. A stage
   that changes a colour path proves it with the swatch sheet (Stage 0)
   before anyone judges a colour through it.

### The palette

The time-of-day sets and the block and flora palettes are tables in the
research document (sections 2.11 and 3). This plan repeats the numbers
inside the stage that lands them, so the stage is self-contained; the
research document holds the reasons.

---

## How to use this document

Execute top to bottom. Every number is a starting value to be judged with
the tour and the gallery, not a law - but the rules above are. Where a
judgement call remains, keep the game running and record the choice in
`docs/status/look-v2.md`.

Before starting read `CLAUDE.md`, `README.md`, `docs/DESIGN.md` ("Art
direction", "Art pipeline"), `docs/plans/look-v1.md`, `docs/status/look-v1.md`
("Tuned blind"), and `docs/research/art-direction.md` (all of it; section 0
before touching anything).

Godot 4.7.2. On Marcel's Windows box:
`%LOCALAPPDATA%\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64_console.exe`.
`<godot>` below means that. After any pull that adds `class_name` scripts:
`<godot> --headless --path . --import`.

### Evidence

Every visual stage ends with a labelled tour and, where characters or the
swatch sheet are involved, a labelled gallery. The baselines are look v1's
own: `build/tour/look-5-meadow` (12 shots, seed 42) and
`build/character/look-6-characters`, shot on `main` at `de7a424`.

```
<godot> --path . -- --tour --seed 42 --label look2-<stage>
<godot> --path . -- --tour --seed 42 --label look2-<stage>-gl --rendering-driver opengl3
<godot> --path . scenes/character/gallery.tscn -- --label look2-<stage>
<godot> --path . scenes/character/gallery.tscn -- --sheet swatches --label look2-<stage>
<godot> --path . scenes/character/gallery.tscn -- --sheet swatches --label look2-<stage>-gl --rendering-driver opengl3
<godot> --path . -- --shot-ui look2-<stage>
<godot> --headless --path . scenes/selftest.tscn
<godot> --headless --path . scenes/character/selftest_character.tscn
<godot> --headless --path . --script scripts/tools/worldgen_probe.gd -- --seed 42
```

Both renderers, on this box: the Compatibility renderer runs on Windows with
`--rendering-driver opengl3`, so the "tuned on the wrong renderer" problem of
look v1 ends here - every stage that touches a colour path shoots the swatch
sheet on both and the two must agree.

The self-tests must pass at the end of every stage that touches their
subject. The worldgen probe must print the same heightmap hash `76cccdb6`,
config hash `da8868d1`, 73,675 trees and spawn (-44, -124) after every stage.
A stage that leaves one red, or moves the world, is not done.

---

## Stage 0 - The transfer

Make the authored colour the on-screen colour. Nothing after this can be
judged before it.

**The swatch sheet.** A new gallery sheet, `swatches`, beside `testcube` in
`scripts/tools/character_gallery.gd`: eight flat quads facing the camera and
the sun (n.l well over `BAND_LIT`), each a known authored colour through
`Look.opaque_material()` - `#FFFFFF`, `#808080`, `#202020`, `#86B04A`,
`#4E7A32`, `#BFB48C`, `#E0AC7E`, `#4C8FBF` - plus the same eight on a second
row turned into full shade, and a strip of `SNOW` beside `GRASS`. The sun
frozen at the tour's `day_start`. Beside the sheet a small Python script,
`tools/swatch_check.py` (no dependencies beyond PIL), that reads the PNG,
samples each swatch and prints authored / predicted / measured / delta, where
predicted is `linear_to_srgb(srgb_to_linear(authored) * sun_linear * energy)`
for the lit row and `... * shade_ink` (Stage 1's formula once it lands; the
multiply until then). Delta over 6 units on any channel fails. Run on both
renderers.

**The fix.** Two errors, both measured in the research (section 0):

- `LIGHT_COLOR` carries PI. In `Look.RAMP`, `vec3 L = LIGHT_COLOR / PI;` and
  use `L` where `LIGHT_COLOR` was. Then `SkyCycle.sun_energy()`: day 0.70 ->
  **1.0**, night 0.32 -> **0.75** (starting; Stage 1 sets the full set).
- The vertex colour is linearised twice. Find where. Candidates, in order:
  Godot 4.7's `ARRAY_COLOR` path treating 8-bit vertex colours as sRGB for a
  `ShaderMaterial` (check the 4.7 changelog and the mesh storage flags; if so
  the fix is to author the palettes in sRGB - drop the manual
  `srgb_to_linear()` in `Block`, `FloraModels`, `Races`, `VoxLoader`, the
  critter and the test cube - and say so in every header comment that
  currently says "stored linear"); or something in `ChunkMesher` /
  `VoxelModel` / `FarFieldJob` / `FarTreeMeshes` / `Lakes` / `FloraModels`. The
  swatch sheet decides: the fix is the one that makes the prediction hold to
  within 6 units on both renderers with no per-renderer branch. If the two
  renderers disagree after the fix, that is the finding - record it and stop
  the stage; do not add a renderer branch to a palette.
- `_env.fog_sky_affect` 0.6 -> **0.0** and `fog_aerial_perspective` -> 0. The
  poster sky owns its horizon. Then `SKY_TOP_DAY` `#4D80D4` -> **`#89A1CB`** so
  what is on screen today stays on screen.

**Evidence:** gallery `swatches` on both renderers, `testcube`, tour
`look2-0-transfer` on both. Expect the tour to look *worse* at the end of
this stage - flatter and paler, the meadow `#86A73B`-ish rather than neon -
because every constant downstream was tuned against the error. That is
correct and is not to be fixed here.

## Stage 1 - Light: shade as ink, dusk that exists, the sets

`scripts/world/look.gd` `RAMP`:

```
const float BAND_LIT = 0.50;
const float BAND_HALF = 0.22;          // was 0.12, see research 2.1
const float BAND_HALF_LEVEL = 0.55;
const float BAND_EDGE = 0.03;
const float LIT_BLEACH = 0.10;         // lit band pushed toward white, 0 = off

void light() {
    float ndl = clamp(dot(NORMAL, LIGHT), 0.0, 1.0) * ATTENUATION;
    float band = poster_band(ndl);
    vec3 L = LIGHT_COLOR / PI;
    if (LIGHT_IS_DIRECTIONAL) {
        float lum = dot(ALBEDO, vec3(0.2126, 0.7152, 0.0722));
        vec3 shade_alb = mix(ALBEDO, vec3(lum), kubik_shade_desat);
        vec3 lit_alb = mix(ALBEDO, vec3(1.0), LIT_BLEACH);
        DIFFUSE_LIGHT += mix(shade_alb * kubik_shade.rgb, lit_alb * L, band);
    } else {
        DIFFUSE_LIGHT += ALBEDO * L * band;
    }
}
```

New global `kubik_shade_desat` (float) in `project.godot` `[shader_globals]`
and in `Look.HEADER` and `Look.publish()`.

`scripts/world/sky_cycle.gd`:

- **Dusk is reached.** The three dusk lerp weights (`0.85` in `sun_color`,
  `0.75` in `fog_color` and `shade_color`) -> **1.0**. `sun_energy()` gets the
  same shape as the others with a dusk term. A `SKY_TOP_DUSK` and a
  `SKY_MID_*` set, blended the same way. The keyframe functions stay pure.
- **The sets.** Constants (sRGB in the file as today; the code converts):

| | DAWN (Stage 2) | NOON | DUSK | NIGHT |
| --- | --- | --- | --- | --- |
| SUN | `#FFC7A0` | `#FFF2D1` | `#FCA55A` | `#9AAAD0` |
| energy | 0.85 | 1.00 | 0.90 | 0.75 |
| SHADE | `#9A97BE` | `#7A7396` | `#4A6FB4` | `#39456E` |
| shade desat | 0.55 | 0.55 | 0.65 | 0.75 |
| FOG | `#E4CDB8` | `#C9C3C4` | `#D9C4B0` | `#223A5E` |
| HORIZON | `#F3C79E` | `#EBDFC8` | `#F4CBA0` | `#25406E` |
| SKY_MID | `#E4C9C2` | `#B4C1D6` | `#9A8CC0` | `#1D3764` |
| SKY_TOP | `#BBD5DC` | `#89A1CB` | `#6C68A4` | `#152A55` |
| WATER | `#B6BCCE` | `#4A6A8A` | `#6E7396` | `#2C3E63` |

  This stage lands NOON, DUSK and NIGHT for SUN, energy, SHADE, desat and
  SKY_TOP; FOG / HORIZON / SKY_MID / WATER land in Stage 2 and Stage 4 where
  their shaders are. Until then the fog stays the horizon.

- The moon's disc keeps the moon's light colour in this stage; the gold moon
  is a Stage 2 option.

**Judge:** `7-forest-interior` - the forest's dark side goes navy-violet with
internal steps, not black-green; `2-summit` - shaded rock is violet-slate;
`11-forest-dusk` - a dusk sky at V63 or above, never V40; `12-meadow-night` -
the ground stops being day-grass dimmed. The swatch sheet's shade row must
match the new prediction. Back `BAND_HALF` to 0.12 if the middle tone reads
as a third material rather than as the side of one.

**Evidence:** tour `look2-1-light` (both renderers), gallery `look2-1-light`
and `swatches`.

## Stage 2 - Sky and distance

`scripts/world/look.gd`:

- **`FOG_FN`**: the target is the fragment's own colour desaturated and
  lifted, blended with the fog colour, so hue is held across the bands:

  ```
  vec4 poster_fog(vec3 view_vertex, vec3 albedo) {
      float depth = length(view_vertex);
      float f = smoothstep(kubik_fog_start, kubik_fog_end, depth);
      f = floor(f * kubik_fog_bands + 0.5) / kubik_fog_bands;
      float lum = dot(albedo, vec3(0.2126, 0.7152, 0.0722));
      vec3 self = mix(albedo, vec3(lum), 0.5) * 1.25;
      vec3 target = mix(self, kubik_fog_color.rgb, 0.6);
      return vec4(mix(target, kubik_fog_dark.rgb, fog_dark_mix), f);
  }
  ```

  `fog_dark_mix` is a per-material uniform (0 terrain, 1 figures) and
  `kubik_fog_dark` a new global (Stage 3 splits the material; until then it
  is 0 everywhere and the global is published anyway).
- **`SKY_SHADER`**: `sky_mid` uniform and a two-segment band mix; `sky_horizon`
  is now the HORIZON row, not the fog; below the horizon the sky is the FOG
  colour so the far mesh's last band and the ground of the sky agree. Rays:
  `ray_count` 16 -> 24 pairs, alternating long (extent 1.0) and short (0.45)
  wedges that taper (wedge half-width shrinking with angular distance); the
  halo colour is the sky band lifted (`mix(col, vec3(1.0), 0.08)`) by day and
  takes `sun_color` only by `dusk`. A moon halo: `ray_strength` 0.10,
  `ray_extent` 0.5, gated on `night`. Clouds: sample `clouds()` in polar
  coordinates of the plane projection (`vec2(atan(uv.y, uv.x) * 7.0,
  length(uv) * 2.2)`), underside as a constant radial offset (`-0.35`); lit
  colour a `cloud_lit` uniform (the CLOUD LIT row), underside
  `mix(col, sky_horizon.rgb, 0.35) * 0.86`.
- **Option, on Marcel's yes:** a `moon_color` uniform drawn on the disc
  (night accent `#E8892E`), the light staying `#9AAAD0`.

`scripts/world/sky_cycle.gd`:

- Publish FOG, HORIZON, SKY_MID, `kubik_fog_dark` (`#8E9AA8` day; the fog
  colour a band darker at every hour), `cloud_lit`.
- **DAWN.** A fourth keyframe set (the DAWN column) and a morning flag:
  `morning := time_of_day < 0.5`, an argument on the pure functions; dawn
  blends where dusk did, by the same `dusk_amount()`. The day-cycle self-test
  walks a whole day and must still pass.

`scripts/world/worldgen_config.gd`: `fog_bands` 6 -> **4**; `FOG_START_RATIO`
0.6 -> **0.4**; `far_band_m` 40 -> **60**; `far_band_step` 0.06 -> **0.03**;
`aspect_tint` 0.12 -> 0.18 as an experiment. None is hashed; the probe proves
it.

`scripts/world/far_field_job.gd` `_band_color()`: **monotonic**, not
alternating - `k = clamp(1.0 + step * (band - band_treeline), 0.85, 1.25)`,
where `band_treeline` is the band the treeline altitude falls in (from the
generator's zone thresholds, read once), so the ranges get lighter with
altitude and the fog bands carry the distance. Off at `far_band_step 0`, as
now.

**Judge:** `6-postcard` and `2-summit` - the ranges are opaque stacked
planes, each lighter and greyer, cut against a cream horizon, no stripes;
`9-treeline` - the red zigzag is gone; `11-forest-dusk` - a three-stop dusk
sky; a new `13-meadow-dawn` (`time_of_day` 0.24, framed like `1-spawn`) and
`14-postcard-dusk` (shot 6's framing at 0.74) added to the tour for this and
every later stage. `1-spawn` - clouds are lozenges along the horizon with one
fixed-width shade lip.

**Evidence:** tour `look2-2-sky` (both renderers; 14 shots from here on).

## Stage 3 - Ground: grain, the contact band, the material split

`scripts/world/look.gd`:

- `Look.opaque_material()` stays the terrain's; a new `Look.figure_material()`
  is the same shader with `fog_dark_mix = 1.0` and `grain_amount = 0.0`, used
  by `VoxelModel`, `FloraModels`, `FarTreeMeshes` and the boulders. Two
  materials, one shader string; the batching cost is one extra draw group.
- `OPAQUE_SHADER`: a `vertex()` writing `varying vec3 world_pos` from
  `MODEL_MATRIX * vec4(VERTEX, 1.0)`; in `fragment()`:

  ```
  vec3 cell = floor(world_pos / 0.5);
  float h = hash3(cell);                      // 3-int hash, no texture
  float g = (h * 2.0 - 1.0) * grain_amount;   // 0.065 terrain
  float t = (hash3(cell + 17.0) * 2.0 - 1.0) * grain_hue;   // 0.03
  vec3 grained = ALBEDO * (1.0 + g) * vec3(1.0 + t, 1.0, 1.0 - t);
  float far = poster_fog(VERTEX, ALBEDO).a;
  ALBEDO = mix(grained, ALBEDO, far);         // grain fades with the fog
  float up = abs(NORMAL.y);
  float fy = fract(world_pos.y / 0.5);
  ALBEDO *= mix(1.0, mix(0.72, 1.0, step(0.25, fy)), 1.0 - up);   // contact band
  ```

  `grain_amount`, `grain_hue`, `contact_band` (0.72) as per-material uniforms
  with `WorldgenConfig` knobs on F4. Optional: `grain_sparse` gating the hash
  to 15% of blocks at ±0.12 for the flattest materials, judged on `10-shore`.
- Compiles and runs on both renderers; `MODEL_MATRIX` and varyings exist on
  both; no derivatives, no depth reads.

`scripts/world/worldgen_config.gd`: `color_jitter_value` 0.07 -> **0.0**,
`color_jitter_hue` 0.03 -> **0.0**. `Block.jitter()` stays (it is off at 0).
Baked AO stays.

**Judge:** `8-meadow-closeup` - grain, one block across, not blotches; a
terrace edge is a line; `3-forest-slope` - the corduroy; `2-summit` - stone
and snow have a surface; `9-treeline` at the far end - no shimmer. Gallery
`lineup-front` - characters have no grain and a clean edge against the pad.
`1-spawn` with a character at 40 m - the figure stays a step darker than the
ground it fogs against.

**Evidence:** tour `look2-3-ground` (both renderers), gallery `look2-3-ground`.

## Stage 4 - The palette, boulders, water

Only now. `scripts/world/block.gd` `COLORS` and
`scripts/world/flora/flora_models.gd` `COLORS`, the research's section 3
tables, verbatim, each entry's comment updated with the reason. The two
tables are reproduced here so the stage is self-contained:

`Block.COLORS`: STONE `#ADA9A1`, DIRT `#7A5F47`, GRASS `#809945`, SAND
`#C7C0AB`, SNOW keep, FOREST_FLOOR `#70583D`, LEAVES `#2F4F3E`, TRUNK
`#5E4238`, SHORE `#91948E`, ALPINE_GRASS `#9C9D68`, HEATH `#6B3933`,
LEAVES_SPRUCE_B `#385C48`, LEAVES_BEECH `#4F7A3A` / `#5F8A46`, LEAVES_LARCH
`#BD994B` / `#C9A75D`, LEAVES_PINE `#3F5E35` / `#4D6B40`, LEAVES_BIRCH
`#84A85B` / `#92B268`, TRUNK_BIRCH keep, TRUNK_DEAD `#9E9990`.

`FloraModels.COLORS`: GRASS_BLADE `#4E6E30`, GRASS_BLADE_DRY `#9BB65A`,
GRASS_ALPINE `#ACB276`, STEM `#6E8C47`, FERN `#4D7A3B`, MUSHROOM_STEM keep,
MUSHROOM_CAP `#CC503D`, SHRUB_HEATH `#805245` / `#8F6153`, BOULDER `#B2B0A8`,
**BOULDER_LIT `#D0CCC2` (new)**, REED `#8F8859`, FIREFLY keep, FLOWER_WHITE
keep, FLOWER_YELLOW `#EDC834`, FLOWER_PURPLE `#67479E`, FLOWER_RED `#C2487B`,
FLOWER_ALPINE keep.

- **Boulders:** `_blob()` takes a second colour and assigns `BOULDER_LIT` to
  every surface voxel on the sun side of a plane through the blob's centre
  oriented at `Block.SUN_ASPECT`, in the upper 60% of the blob - one plane,
  one straight edge, 30-35% of the visible area. Two tones, nothing else.
- **Tufts:** meadow density in `flora_placement.gd` 0.34 -> **0.50** inside
  12 m of the player (a distance ramp if the placement has one; otherwise
  the flat number, judged). Ground cover is a decoration layer and is not
  hashed; the probe's tree count does not move.
- **Water:** `lakes.gd` takes its colour from a new global `kubik_water`
  published by SkyCycle (the WATER row), alpha **0.92**; the mesh emits three
  colours from the shore field it already has - a rim ring one cell wide
  (2 blocks, +18% value), a shallows ring (8 blocks, +8%), the body - each
  ring its own quads, one flat colour per quad. `WATER_SHADER` unchanged
  beyond the fog signature.

**Judge:** every shot against the research's section 2, and specifically:
`1-spawn` (a valley meadow, green, not lime, not olive; purple flowers darker
than the field); `5-lake` and `10-shore` (a dark tarn, a grey shore, a drawn
rim); `7-forest-interior` (near-black spruce over a brown floor, the larch
the warm accent); `9-treeline` (maroon heath, olive turf, neutral rock,
boulders in two tones). Lit snow lighter than the sky in `2-summit`.

**Evidence:** tour `look2-4-palette` (both renderers), gallery `swatches`
(the predictions for the NEW hexes must hold).

## Stage 5 - Characters (on Marcel's yes only)

Revises look v1's face spec, which Marcel decided; runs only if he says so.
`tools/parts_author/` and a re-author of the seven `parts_*.gd`:

- **Eyes:** 2 wide x 4 tall, solid `E` iris colour, no `W` white, one 1x1
  catchlight at the top-inner corner at most; gap 6; one voxel proud of the
  face plane like the nose. **Brow:** one row in `H` hair colour, or none.
  **Mouth:** 4-5 wide, one value step darker than skin. **Nose:** unchanged.
- **Hair and beards** overhang the head box, per race: human fringe 2 proud
  and 1 wider each side; elf swept back 3 past the skull; dwarf beard 4 below
  the jaw and 2 wider than the head; lizardfolk keeps the crest. The fringe
  line stays hard at `BROW_Y`.
- **Palettes** in `races.gd`: no part more than two entries; hair-to-skin and
  cloth-to-skin each cross a value ratio of 0.5 or lower; trim as a
  single-voxel accent in a colour used nowhere else on the figure.
- Everything in look v1 Stage 6's "What must still hold" holds: the heights,
  the self-tests, `masks-40` under 0.75 for every pair (this stage's job is
  to bring human/lizardfolk under it from 0.91), the triangle budget.

**Evidence:** gallery `look2-5-characters` (all sheets), `masks-40`.

## Stage 6 - UI

`scripts/ui/poster_backdrop.gd`, `scripts/ui/deco.gd`, `scripts/ui/deco_rule.gd`,
`assets/ui/deco_theme.tres`, the menu scene:

- **Sunburst:** 24 long + 24 short rays as tapered 4-gons (tip 0.15 of base
  width; long reach `1.4 * max(w, h)`, short 0.45); paper disc with a 4 px
  gold ring; the title is ink on paper inside the ring.
- **Title band:** a full-width ink band `0.16 h` carrying the double rule on
  its top edge; title in paper caps, subtitle in gold; `Deco.INK_PALE =
  #7D7C78` for secondary lines; sizes 0.45 / 1.00 / 0.55 / 0.35, one
  tracking.
- **Stepped corner:** a `DecoPanel` variation of three nested `StyleBoxFlat`s
  (ink r14 / gold r10 inset 5 / paper r6 inset 10), and `Deco.frame()`.
- **Rules and ornaments:** `DecoRule` inset 8 px with 5x5 gold terminals;
  `Deco.dots()`, `Deco.chevron()` (three across, amplitude 7, apex ~95
  degrees, 3 px), `Deco.roundel()` (paper disc, double gold ring, Limelight
  monogram) as small `Control`s. Used on the menu and the creation screen
  where a rule is today.
- `Look.accent_color(elevation)` (dawn `#F2A80D`, noon `#C9A24A`, dusk
  `#E8A02E`, night `#E8892E`) exists for the sun disc and the nametag's gold,
  and later the campfire.

**Evidence:** `build/ui/look2-6/main-menu.png`, `character-creation.png`.

## Stage 7 - Docs

- `DESIGN.md` "Art direction": the three sharpened rules and the new fourth;
  the shade ink values; the sets table's location; the palette's colour
  space after Stage 0.
- `README.md`: the `--rendering-driver opengl3` line under "Running it", and
  the swatch check.
- `docs/status/look-v2.md`: what shipped, the numbers, the swatch deltas on
  both renderers, "Tuned blind" for anything not seen in play, what is left.
- `docs/IDEAS.md`: a line under Next 3 in the shape of the look v1 note; the
  shore width and the meadow-patch idea under Someday.
- `STATUS.md` replaced by the look v2 status; look v1's moved to
  `docs/status/`.

---

## Hard rules

1. The five rules of the direction, and the four sharpenings above, outrank
   every number in this file.
2. **Stage 0 first, and nothing is judged before it.** A colour tuned against
   the old transfer is a colour tuned against a bug.
3. No new textures. None. The grain is a hash, the contact band is
   arithmetic, the clouds are noise on a direction.
4. Both renderers, on this box. Every stage that touches a colour path
   shoots the swatch sheet on Forward+ and on `--rendering-driver opengl3`
   and the two agree to within 6 units. No per-renderer branch in a palette
   or a shader; if the renderers disagree, that is a finding and the stage
   stops there.
5. **The world does not move.** Same seed, same heightmap hash `76cccdb6`,
   same config hash `da8868d1`, same 73,675 trees, same spawn. The probe runs
   after every stage. No knob added here is hashed. Tree shapes, zones, the
   shore's width and where any block goes are worldgen and are not touched.
6. **No trees are built.** The tree vocabulary in the research is a spec for
   a later plan.
7. Parts are data; the generator writes them. Stage 5 runs on Marcel's yes
   and not otherwise.
8. `player.gd` reads no number from `Races`. Still.
9. Nothing on the Next 3 gets built here. The campfire's light, its smoke
   and the marker are specs in the research document; the ramp's point-light
   branch is exercised by nothing until the campfire plan.
10. Every starting value in this file is on F4 and in `docs/status/look-v2.md`
    with what it was, what it is and why.
