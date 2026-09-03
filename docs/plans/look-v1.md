# Look v1 - the poster

> **SUPERSEDED by `docs/plans/light-v1-tech.md`** (phase 1 of
> `RECONCILIATION.md`, run 2026-09-03). The poster this plan builds - the
> three-band toon ramp, the banded fog, the painted sky, flat water, the
> dither and the linear tonemapper - was replaced wholesale by the engine's
> own light under bible pillar 2. Kept for its arguments and its
> measurements, which is why light v1 could be written; not for its numbers,
> which are dead. The run that replaced it is `docs/status/light-v1.md`.


The art direction, decided, and the pass that puts it on screen. Runs on
`feat/look-v1`, branched from `main` at `9e1b62a` (character v1 merged).

Decided in a design session on 2026-08-25. Every choice below was made by
Marcel; where the plan says "decided", it means by him.

**Why now, against the Next 3.** An art direction is not a feature. It is the
same kind of thing as the art pipeline in `DESIGN.md`: cheap to decide, and
more expensive to retrofit with every part, plant and screen authored under
the old look. The urgent half is the character proportions - the first enemy
and the first gear are parts, and every part authored at the old resolution
is a part to redo. The world half is a look pass over decisions that already
exist (flat vertex colour, linear tonemap, baked AO), not new systems.

---

## The direction: Art Deco Alpine poster

The 1920s-30s railway and resort posters of the Alps - Roger Broders' PLM
series above all, and the Swiss lithographs of the same decade. Flat colour
fields. Mountains as stacked bands of value. **Warm sun, cool violet shade.**
Stepped, faceted, geometric forms. One gold accent. A sun with rays.

It is the *travel poster* strand of Deco, not the Manhattan strand. No
chrome, no glamour, no city. The world stays cozy-Alpine; Deco is how it is
drawn.

Why this and not "Cube World but ours": Cube World was unique because four
rules governed everything (tiny voxels, colour jitter instead of texture,
chibi bodies, candy palette), not because of any one of them. Ours come from
what the game already is. Deco is built from steps and facets - which is what
a voxel terrace and a low-poly far mountain already *are*. Today they read as
artefacts; under a Deco colour language they read as the vocabulary.

### The rules

Everything drawn obeys all five. A feature that cannot is drawn differently.

1. **Two tones and a shade.** A surface is lit, half-lit, or in shade - three
   flat bands, quantised, no gradient across a face. Shade is a COLOUR (cool
   blue-violet), never "darker". Shadows are hard-edged and the same cool
   colour. This is pillar 2 made visible: warmth is safety, and the campfire
   will be the only warm thing in a cool night.
2. **No texture, no specular, no gradient.** Already true. Stays true. Colour
   variation is per-block jitter and altitude/aspect banding, never a map.
3. **Distance is bands, not haze.** Fog steps in flat bands toward the sky
   colour. The far field is a stacked backdrop; the near field is a solid
   voxel world. The seam is owned, not hidden.
4. **Forms are stepped and chamfered.** Heads lose their vertical edges to a
   chamfer; shoulders step; hair is a geometric mass, not a texture. Trees
   (later) are cones and ziggurats, not stacked squares.
5. **One accent.** Gold `#C9A24A` - UI rules, the sun disc, the campfire's
   light later. Nothing else in the world is gold.

### The palette

Sun by time of day (already in `SkyCycle`, re-tuned): noon `#FFF1D0`, dusk
`#FF9A4A`, night (moon) `#6E7FB8` at low energy.

Shade colour (NEW, published as a global uniform): day `#5C6BA8` at ~0.45,
dusk `#4A3A78`, night `#141A33`.

Ground palette in `Block.COLORS` stays. It was authored for this.

UI: paper `#F2E8D0`, ink `#1E2430`, gold `#C9A24A`, alpine blue `#2F5D8A`,
sun `#E8863A`.

---

## How to use this document

Execute top to bottom. Every number is a starting value to be judged with
the tour and the gallery, not a law - but the RULES above are. Where a
judgement call remains, keep the game running and record the choice in
`docs/status/look-v1.md`.

Before starting read `CLAUDE.md`, `README.md`, `docs/DESIGN.md` ("Art
pipeline", "Camera", "World"), `docs/IDEAS.md`, `STATUS.md` and
`docs/status/character-v1.md` ("Tuned blind").

Godot 4.7.2. On Marcel's Windows box:
`%LOCALAPPDATA%\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64_console.exe`.
`<godot>` below means that. After any pull that adds `class_name` scripts:
`<godot> --headless --path . --import`.

### Evidence

Every visual stage ends with a labelled tour and, where characters are
involved, a labelled gallery. The `main` baselines were shot before any
change on 2026-08-25:

```
build/tour/artstyle/          # 11 shots, seed 42, main at 9e1b62a
build/character/artstyle/     # the lineup, sheets and masks, same commit
```

```
<godot> --path . -- --tour --seed 42 --label look-<stage>
<godot> --path . scenes/character/gallery.tscn -- --label look-<stage>
<godot> --path . scenes/character/gallery.tscn -- --sheet masks-40 --label look-<stage>
<godot> --headless --path . scenes/selftest.tscn
<godot> --headless --path . scenes/character/selftest_character.tscn
```

The self-tests must pass at the end of every stage that touches their
subject. A stage that leaves one red is not done.

---

## Stage 1 - Poster light

One shader for everything opaque: terrain (`ChunkMesher`), far field
(`FarFieldJob`), far trees (`FarTreeMeshes`), characters (`VoxelModel`) and,
by sharing the lighting function, plants (`FloraModels.SHADER`).

- New `scripts/world/look.gd` (`class_name Look`). Owns the shader source as
  constants and the shared `ShaderMaterial`s. The lighting function is ONE
  string constant, concatenated into every shader, so there is exactly one
  place the ramp lives. (Not `#include`: it must work for shaders built from
  code at runtime on both renderers.)
- `render_mode ambient_light_disabled, specular_disabled, diffuse_lambert`.
  `light()` does the ramp:
  - For the directional light: `n = clamp(dot(NORMAL, LIGHT), 0, 1) *
    ATTENUATION`, banded to three levels (lit / half / shade) with narrow
    smoothsteps so far-field facets do not alias. Contribution is
    `ALBEDO * mix(kubik_shade, LIGHT_COLOR, band)` - so the unlit side is the
    shade colour, not black, and the shadow is the shade colour too.
  - For any other light (`!LIGHT_IS_DIRECTIONAL`): plain banded lambert
    times `LIGHT_COLOR * ATTENUATION`, adding nothing where it does not
    reach. This is what the campfire will use.
- `fragment()` sets `ALBEDO = COLOR.rgb` and overrides `FOG` with STEPPED
  depth fog: `f = smoothstep(fog_start, fog_end, depth)`, quantised to
  `kubik_fog_bands` (start at 6), colour `kubik_fog_color`. The environment
  fog stays on for the sky only.
- Global uniforms, declared in `project.godot` under
  `[shader_globals]` and written by `SkyCycle.apply()` every frame:
  `kubik_shade` (color), `kubik_fog_color` (color), `kubik_fog_start`,
  `kubik_fog_end`, `kubik_fog_bands` (floats). `kubik_night` already exists.
- THE SUN NEVER GOES OUT. `SkyCycle` keeps the `DirectionalLight3D` visible
  all night, flipped to the moon's position (the antipode of the sun's arc)
  with the night colour at low energy, so `light()` always runs and the
  night is moon-lit two-tone rather than black. `ambient_light_energy` goes
  to 0 - the ramp owns the shade.
- Baked AO stays exactly as it is. It multiplies albedo, so it darkens the
  shade colour as much as the lit colour, which is what a poster does.
- Water: `Lakes.make_material()` becomes a poster shader too - flat colour,
  alpha as now, NO roughness 0.15, and a one-band lighter rim is a later
  stage. Rule 2.

Evidence: tour `look-1-light`, gallery `look-1-light`. The character sheets
are where the ramp is easiest to judge; the forest interior is where the
shade colour is.

## Stage 2 - Poster sky

Replace the `ProceduralSkyMaterial` in `scenes/game.tscn` with a
`ShaderMaterial` running `shader_type sky`, source in `Look`.

- Gradient from horizon (= fog colour, by construction, as now) to zenith,
  quantised into `sky_bands` (start at 5) flat bands.
- Sun: a hard disc, gold-white by day, orange at dusk; `sun_size`. Around it,
  RAYS: `N` alternating wedges (start at 16) fading with angular distance,
  strongest at dusk and dawn (`dusk_amount`), faint at noon. Sunburst is the
  single most Deco thing in the sky; do not make it subtle.
- Clouds: flat shapes from a thresholded 2-octave value noise on the view
  direction, hard-edged, one tone lighter than the band they sit in, with a
  one-band darker underside. Static (no drift). `cloud_cover` uniform.
- Night: the moon disc (small, cool), stars as hashed points above the
  horizon, no rays.
- `SkyCycle` sets the uniforms instead of the `ProceduralSkyMaterial`
  properties. `_sky` becomes a `ShaderMaterial`. `sun_angle_max` goes.

Evidence: tour `look-2-sky`. Shot 11 (dusk) is the acceptance shot.

## Stage 3 - Far field as a backdrop

`FarFieldJob._push_quad`:

- ALTITUDE BANDS. Every `far_band_m` (start at 40 m) of altitude, step the
  colour's value by `far_band_step` (start at 0.05), alternating lighter /
  darker, so a mountain reads as stacked contour bands. Applied to the far
  field only - the voxels near the player show their own terraces.
- The stepped fog from Stage 1 does the rest.
- Skirts keep `SKIRT_SHADE`.

Both numbers on `WorldgenConfig` and the F4 panel.

Evidence: tour `look-3-far`. Shot 6 (postcard) is the acceptance shot.

## Stage 4 - Ground

`Block` and `WorldgenConfig` defaults:

- `color_jitter_value` 0.05 -> 0.10, `color_jitter_hue` 0.02 -> 0.04,
  `color_jitter_blocks` 12 -> 6. A hillside gets visible grain.
- `Block.aspect_curve()` - do the TODO: `smoothstep(-0.4, 0.4, dot) * 2 - 1`.
  `aspect_tint` 0.06 -> 0.12. A slope picks a side.
- `slope_tint` stays.

Judge each against the previous tour; back any one of them off if it reads
as noise rather than as grain.

Evidence: tour `look-4-ground`.

## Stage 5 - Meadow as a colour field

`FloraModels` palette and `FloraPlacement`:

- Tuft blade colours move toward the meadow ground (`#86B04A`): the tuft is
  a slightly darker and a slightly lighter meadow, not a different green.
  `C_GRASS_BLADE`, `C_GRASS_BLADE_DRY`, `C_GRASS_ALPINE` re-authored.
- Tuft density in meadow down by a third; flower patches unchanged in size
  but denser INSIDE the patch, so flowers come as drifts on a plain field.
- Boulders: two tones, lit and shade, nothing else.

Evidence: tour `look-5-meadow`. Shot 8 (meadow close-up) is the acceptance
shot: a field with drifts of one colour, not confetti.

## Stage 6 - Characters at a finer voxel

**Decided:** one model voxel becomes **1/16 of a block, 3.125 cm**. A human
is **64 voxels = 2.00 m**. The crown heights in `DESIGN.md` do not change.
Ground plants stay at 1/8; `DESIGN.md`'s "same size of material" line is
amended to say characters are one step finer than the plants they walk
through, deliberately, because a face needs it and a tuft does not.

**Decided:** every race is STOCKY. The lean scheme is retired:
`Races.HAS_LEAN` all false, `parts_human_lean.gd` deleted, the `build` byte
stays on the wire (always 0) so `WIRE_VERSION` does not bump.

**Proportions, in model voxels.** Head about a third of the height - the
Cube World read, kept on the "stocky" side rather than the doll side. Big
hands, big boots, no neck except the elf's.

| Race | Total | Legs | Pelvis | Torso | Head | Torso w x d | Head w x d | Arm w x len | Leg w |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Human | 64 | 16 | 6 | 20 | 22 | 20 x 11 | 18 x 17 | 6 x 20 | 7 |
| Elf | 72 | 24 | 6 | 20 | 22 (3 neck) | 12 x 8 | 16 x 16 | 4 x 24 | 5 |
| Dwarf | 48 | 10 | 0 | 18 | 20 | 26 x 14 | 20 x 17 | 8 x 16 | 8 |
| Lizardfolk | 60 | 18 | 4 | 20 | 18 | 20 x 11 | 16 x 24 (snout 8) | 6 x 20 | 7 |

Elf ears 6 out per side; lizardfolk crest 8 tall, tail segments 10 / 10 / 8;
dwarf beards to the belt.

**Forms (rule 4).** Heads: vertical edges chamfered 2 voxels (octagonal in
plan), crown edges chamfered 1. Torso: shoulders stepped in by 1 on the top
two rows. Hands: the bottom 6 of the arm one voxel wider all round than the
sleeve. Boots: one voxel wider and two deeper than the leg. Hair and beards:
stepped masses with a hard fringe line - a Deco bob, a stepped braid, a
crest as a fan of steps.

**Faces.** Eyes 4 wide x 4 tall, white with a 2 x 2 iris low and inboard
(looking at you), 2 apart; a one-row `s` brow above; a 2 x 3 x 1 nose; an
8-wide mouth. Everything readable at 15 m at 75 degrees FOV on 720 lines.

**How they are authored.** Parts stay ASCII slices in slot letters
(`VoxelModel.SLOT_CHARS`) - that is the runtime contract and the `.vox`
drop-in depends on it. At this resolution a head is 22 slices of 17 rows of
18 characters, so the ASCII is WRITTEN BY A GENERATOR:
`tools/parts_author/` (Python 3, no dependencies), one module per race,
emitting the `scripts/character/parts/parts_*.gd` files complete with their
docstrings. Both are committed. The header of every generated file names the
generator. Hand edits to the ASCII are legal and must be followed by a note
in the file header saying the generator is behind.

**What must still hold.**

- `Races.TABLE` in the new numbers; `V = VoxelModel.VOXEL_M = 0.03125`;
  `eye_height_m` from the stack; `Animator.REFERENCE_LEG_M` re-derived from
  the human's legs (16 voxels), so the stride does not halve.
- Every self-test in `selftest_character.gd`. The height test, the
  eyes-forward test, the gear placement test (placeholders in
  `parts_gear.gd` re-authored at the new scale, clear of every body) and
  the critter (scaled x2, same proportions - it is a test rig).
- Gallery `masks-40`: every pair of races under the 0.75 IoU threshold at
  40 m. The silhouettes must survive the re-author, and at a third-of-height
  head that is not automatic - the ears, the beard, the tail and the width
  do the work.
- Triangles per character recorded in the status doc against the old
  numbers; the budget line in `CharacterConfig` raised to fit with the
  reason stated.
- `character_creation.gd` frames the preview from `height_m(true)` already;
  check it still does.

Evidence: gallery `look-6-characters` (all sheets), `masks-40`, and the
tour's shot 1 with the player in it.

## Stage 7 - UI in Deco

A `Theme` resource, `assets/ui/deco_theme.tres`, set as the project theme in
`project.godot`, so every Control inherits it.

- Paper, ink, gold, alpine blue, sun - the UI palette above.
- Type: a geometric Deco display face for titles (OFL, bundled under
  `assets/fonts/` with its licence - Poiret One or Limelight; if neither can
  be fetched, Godot's default with uppercase and +4 tracking), a plain
  geometric sans for body.
- Titles uppercase, tracked. Gold double rule lines above and below a
  title. Buttons: paper on ink, gold on hover, no rounded corners - a
  stepped corner (a 2-step notch) drawn with a `StyleBoxFlat` and a border,
  or a small generated nine-patch.
- Applied to the main menu, the character creation screen, the nametag
  (`Label3D`) and the debug HUD's title line. The HUD body stays monospace;
  it is a tool.

Evidence: a screenshot of the main menu and of the creation screen in
`build/ui/look-7/`.

## Stage 8 - Docs

- `DESIGN.md`: a new "Art direction" section holding the rules and the
  palette; "Art pipeline" amended for 1/16 and the retired lean scheme; the
  race table's voxel heights doubled.
- `README.md`: the `--import` note under "Running it".
- `docs/status/look-v1.md`: what shipped, the numbers, "Tuned blind" for
  anything judged on the tour rather than in play, and what is left.
- `STATUS.md`: replaced by the look v1 status, with the foliage one moved to
  `docs/status/foliage-v1.md`.
- `docs/IDEAS.md`: a line under Next 3 recording that the look pass ran and
  why, in the same shape as the character v1 note.

---

## Hard rules

1. The five rules of the direction outrank every number in this file.
2. No new textures. None. A material that needs one is the wrong material.
3. Both renderers. The tour runs on Compatibility on the Linux box. Every
   shader compiles on both or the tour turns magenta and the stage is not
   done.
4. `player.gd` reads no number from `Races`. Still.
5. The world does not move. Same seed, same heightmap hash, same spawn, same
   tree count before and after. A look pass that changes worldgen is a bug.
6. Parts are data. The generator is a tool that writes data.
7. Nothing on the Next 3 gets built here. No enemy, no campfire, no
   gathering. The campfire's light is a point light the Stage 1 shader
   already handles; that is as far as this goes.
