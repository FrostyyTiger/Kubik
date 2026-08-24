# Foliage v1 - what grows on the land

Overnight implementation plan. Successor to `terrain-v2.md`, which landed on
`main` as "Merge terrain v2: the shape of the land". This is the first half of
what v2 called Plan B; **water and rivers are deliberately NOT here** and get
their own plan later. Reeds at the water's edge are the one exception, because
`Lakes.shore_level` was built for them and they cost nothing.

This plan is **what grows on the land**: seven kinds of tree with real shapes,
a forest that is dense inside and thins at its edges, ground cover in every
zone, distant forests that do not vanish at 96 m, and a little life after dark.

Decided in a design session on 2026-08-24. Every choice below was made by
Marcel; where the plan says "decided", it means by him, not by this file.

---

## How to use this document

Execute it in one pass, top to bottom. **Do not stop to ask questions.** Every
number below is already decided; where a judgement call remains, the rule for
making it is stated. If something is genuinely ambiguous, pick the option that
keeps the game running and record the choice in `STATUS.md`.

Before starting, read `CLAUDE.md`, `README.md`, `docs/DESIGN.md`,
`docs/IDEAS.md` and the tail of `STATUS.md` ("What Plan B will need from this
work"). The design pillars outrank anything in this file.

Godot 4.7.2. On the Linux box it is `godot` on PATH; on Marcel's Windows box it
is the full WinGet path recorded in `terrain-v2.md`. `<godot>` below means
whichever applies.

### Before touching anything

The terrain Claude's work - threaded heightmap, detail damping on flats, the
chunk queue, collision gating at spawn - **lands on `main` before this run
starts.** Branch from that `main`:

```
git checkout main && git pull
git checkout -b feat/foliage-v1
<godot> --headless --editor --quit --path .
<godot> --headless --path . scenes/selftest.tscn
<godot> --headless --path . --script scripts/tools/worldgen_probe.gd -- --seed 42
<godot> --headless --path . --quit-after 2500 -- --host --seed 42
```

Expect zero script errors, `SELFTEST: all passed`, and a probe that reports
trees for seed 42. **Record the baseline numbers** - tree count, boot time to
`is_idle()` at High, main-thread ms, far-field vertices - because every
performance budget below is relative to them, and the terrain work will have
moved them since `STATUS.md` was written.

If `main` does not contain the terrain work when you start (look for
`detail_flat_damp` in `WorldgenConfig`), branch anyway, keep every new file
under `scripts/world/flora/`, keep the hooks into the hot files to the minimum
this plan names, and say so in `STATUS.md`. Do not wait.

---

## What v2 left for this plan, and what it taught us

**1. Trees exist, ground cover does not.** A tree is one hardcoded function -
`TerrainGenerator._stamp_tree()` - drawing a 1-block trunk of 8-14 blocks and
a cone of `LEAVES`. One species, one green. There are ~35,000 of them on seed
42 at one candidate per 4 x 4 blocks and 12% in the middle of the forest band,
and they read as evenly scattered cones. A meadow is one flat quad. Heath is a
colour. Nothing grows anywhere else.

**2. The border-safe stamp is the pattern, and it is correct.** Every chunk a
tree touches iterates candidate cells over a region wider than itself by the
largest reach a tree has, and writes only the blocks that land inside it. The
tree is hashed from its cell, never drawn from a stream, so every chunk
computes the same tree. `_test_tree_borders` proves it. **Every new species
uses this stamp.** The margin (`config.tree_canopy_max`) and the sky reserve
(`max_tree_height()`) both grow with the biggest species and must be derived,
not typed.

**3. Forests vanish at 96 m.** The far field draws the coarse heightmap
coloured by zone, so beyond the voxel radius a forest is a flat dark-green
slope. Nobody noticed under thick fog. Dense forest will make it obvious
from the first meadow.

**4. Greedy meshing and per-block variation do not mix**, and the two ways
round it are both in `ChunkMesher` with the reasoning written down: move the
variation into the vertices, or let the code join the merge mask. **Ground
cover takes neither route.** It lives on a separate decoration layer that
never enters the chunk, the mesher, or the edit dictionary.

**5. The design already has two voxel scales.** `DESIGN.md`: characters are
model voxels 6-8x finer than world blocks - "two systems, not one". Plants join
the character system, not the terrain one.

**6. Determinism is the contract and the hash is the proof.** `WorldgenConfig.
PROPERTIES` is half the join handshake. v2 found three shape knobs missing
from it - the world would have desynced while the handshake reported a match.
Every knob this plan adds is sorted into shared or local below, on purpose.

---

## Hard rules

1. **Determinism is sacred.** Every tree, every blade of grass, every firefly
   derives from `(seed, coordinates, config)`. No `randf()`, no `randi()`, no
   unseeded RNG anywhere in worldgen or flora. No dependence on `Dictionary`
   iteration order. Salt every new use of `WorldHash`.
2. **Every new SHAPE knob joins `WorldgenConfig.PROPERTIES`.** A shape knob is
   anything that decides whether a block or a flora instance EXISTS, where,
   or which kind. Every new LOOK knob joins `LOCAL_PROPERTIES` instead - draw
   fraction, radius, wind, glow. The test: if two machines disagreed about it,
   would one player pick a flower the other cannot see? Then it is shape.
3. **Do not touch the net protocol.** Not the RPC surface, not the join
   handshake, not the edit dictionary's wire format. Stage 9 builds the
   gatherable hook up to - and not including - the RPC.
4. **Do not change the design pillars.** If a stage seems to need one bent,
   stop that stage, write the argument into `STATUS.md`, move on.
5. **Do not rewrite or delete `TODO(marcel)` exercises.** New ones follow the
   same shape: a working fallback, a hint, no dependency on being done.
6. **No unverified performance claims.** Every number in `STATUS.md` is
   measured or says "not measured".
7. **GDScript only.** No plugins, no GDExtension. `FastNoiseLite` for noise,
   `WorldHash` for scatter. Shaders are Godot shading language and **must
   compile on both Forward+ and Compatibility** - the tour runs on the second,
   Marcel plays on the first.
8. **Commit after every stage.** Never leave the tree dirty between stages.
9. **Verify after every stage.** Self-tests pass. Three fix attempts, then
   commit what works, record the failure, continue to the next independent
   stage.
10. **Third person only.**
11. **New code goes in new files under `scripts/world/flora/`.** The hooks
    into `terrain_generator.gd`, `world.gd`, `worldgen_config.gd` and
    `chunk_node.gd` are named per stage below and are the ONLY edits to those
    files. The terrain Claude may be working in them again tomorrow.
12. **Dense never means unwalkable.** Trunks stand on a lattice with jitter,
    and the jitter is bounded so two trunks are never closer than 2 blocks
    (1 m) face to face. The player is 1.2 blocks wide.
13. **Block ids are appended, never renumbered.** They are the wire format.

### The renderer caveat, again

This box has no display. Godot falls back to OpenGL Compatibility on Mesa
llvmpipe under Xvfb. **Marcel runs Forward+ on an RTX 5080.** v2's palette
arrived on his screen looking different from every screenshot taken here.

You are cleared to tune values anyway. In exchange:

- **Every value chosen by eye goes in `WorldgenConfig`**, reachable from the
  F4 panel, never hardcoded.
- **Every visual decision is listed in one `STATUS.md` section** titled
  "Tuned blind - re-check these first", with before/after and the knob name.
- Never delete a previous value. Record it beside the new one.
- **The model gallery (Stage 1) is what you tune models against**, not the
  world. One screenshot, every species, side by side, a known camera.

---

## Fixed numbers

### Scale

Two scales, and this plan adds the second one to `DESIGN.md` in Stage 5.

| Thing | Scale | Why |
| --- | --- | --- |
| Terrain, lakes, mountains | 1:4 | unchanged |
| **Trees** | **1:4** | they are landscape, read from the valley floor |
| Player | 1:1 | the existing exception |
| **Ground plants, boulders** | **1:1** | read next to the player; a 1:4 grass tuft is 12 cm and invisible from the camera |

Blocks are 0.5 m. **Plant models are built at 8 model voxels per block**,
6.25 cm each - the character voxel scale in `DESIGN.md`, so a plant and a
player look like the same material.

### Tree species

Seven. Heights are TOTAL height in blocks (trunk + crown), at 1:4. `crown r`
is the crown's widest radius in blocks. Trunk is 1 block square, **2 x 2 when
total height is 16 or more**. Each species is a shape function with hashed
parameters, in `scripts/world/flora/tree_species.gd`.

| # | Species | Height (blk) | Crown r | Shape | Leaf palette | Where |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | **Spruce** | 13-21 | 2-4 | layered cone with whorls: radius alternates r, r-1 every layer so the silhouette steps | dark green (existing `LEAVES`) | forest, all altitudes; dominant |
| 2 | **Beech** | 10-16 | 4-6 | dome: ellipsoid crown starting at 40% of height, slightly wider than tall | mid green, lighter than spruce | lower forest, meadow edge |
| 3 | **Larch** | 12-20 | 2-3 | sparse cone: same cone as spruce but each leaf block exists with hashed probability 0.6, so light comes through | yellow-gold | upper forest, treeline |
| 4 | **Krummholz** | 3-6 | 3-5 | low irregular mound, wider than tall, short trunk; may lean | pine green, bluish | top edge of forest band, heath, into alpine |
| 5 | **Birch** | 10-16 | 2-3 | slender, small loose crown, sparse (probability 0.7) | light yellow-green | shore band, meadow margins |
| 6 | **Snag** | 6-14 | 0 | bare trunk, 1-3 single-block stubs jutting sideways at hashed heights, no leaves | none; trunk grey-silver | forest and heath, more with wildness |
| 7 | **Hero** | 1.6-2.0x spruce or beech | up to 8 | the parent species scaled; always 2 x 2 trunk | parent's | meadow only, ~1 per 300 x 300 m |

Spruce at its old parameters must reproduce today's world - see Stage 2.

**Blocks to append** in `Block`, ids 12 upward, in this order:

```
LEAVES_SPRUCE_B, LEAVES_BEECH, LEAVES_BEECH_B, LEAVES_LARCH, LEAVES_LARCH_B,
LEAVES_PINE, LEAVES_PINE_B, LEAVES_BIRCH, LEAVES_BIRCH_B,
TRUNK_BIRCH, TRUNK_DEAD
```

The `_B` variants are the per-tree colour jitter: each tree hashes a shade
variant, A or B, a few percent apart in value and hue. Two block ids per
species costs zero mesher change and is why a grove is not one exact green.
`LEAVES` is spruce A and `TRUNK` is every brown trunk; both keep their ids.
Author every colour as sRGB hex in the comment and store it LINEAR, exactly
as `Block.COLORS` does now.

### Tree placement

Candidate lattice stays at `tree_cell_blocks` = 4. Each candidate hashes a
jitter of -1, 0 or +1 blocks on each axis, which is the bound in hard rule 12.

Probability at a candidate is a PRODUCT:

```
p = base(zone, altitude-in-band) * grove(wx, wz) * glade(wx, wz)
    * slope_ok(slope) * bench_ok(wx, wz) * spawn_ok(wx, wz)
```

| Term | Value |
| --- | --- |
| `base`, forest band | peaks at **0.45** in the middle of the band, tapers to 0.10 at the edges (was a flat 0.12 peak) |
| `base`, meadow | 0.008, beech/birch/hero only |
| `base`, shore band | 0.06 within 12 blocks of a lake's shore level, birch only |
| `base`, heath and alpine | 0.05 fading to 0 halfway up the alpine band, krummholz only |
| `grove` | fbm, wavelength ~90 m, remapped so 35% of forest area is "grove" at 1.0, the rest 0.35 - forest clumps |
| `glade` | fbm, wavelength ~160 m, 0 where the mask is in its top 12% - clearings inside the forest; flowers go there in Stage 6 |
| `slope_ok` | 1 below `tree_max_slope_deg` **40**, 0 above; krummholz uses **55** |
| `bench_ok` | 0 on a bench or plateau cell (`_bench_placement()` above 0.5), 1 elsewhere |
| `spawn_ok` | 0 within **24 m** of `spawn_block`, ramps to 1 at 60 m |

Species at an accepted candidate is a second hash against a weight table that
depends on altitude-within-band, zone and `wildness_at()`:

| Position in forest band | spruce | beech | larch | krummholz | snag |
| --- | --- | --- | --- | --- | --- |
| bottom quarter | 0.45 | 0.45 | 0.00 | 0.00 | 0.10 |
| second quarter | 0.65 | 0.20 | 0.10 | 0.00 | 0.05 |
| third quarter | 0.60 | 0.05 | 0.30 | 0.00 | 0.05 |
| top quarter | 0.30 | 0.00 | 0.35 | 0.30 | 0.05 |

Blend linearly between rows so it is a gradient and not stripes. **Wildness
adds** to the snag weight (up to +0.15 at wildness 1) and to krummholz in the
top row (+0.15), taken from spruce. Hero is a separate rare roll in meadow
only: hash < `hero_probability` 0.0004 per candidate, 60% beech, 40% spruce.

Tree counts on seed 42 will roughly double or triple from 34,915. That is
intended. Record the number.

### Ground cover

Every item is a small voxel model in `scripts/world/flora/flora_models.gd`,
placed by rules in `flora_placement.gd`, drawn by the decoration layer. Sizes
are at 1:1 in cm, then in model voxels (6.25 cm).

| Model | Size | Voxels (approx) | Notes |
| --- | --- | --- | --- |
| Grass tuft | 30 cm tall | 6-10 | three or four blade columns, top voxels offset; **two variants** |
| Grass, short | 15 cm | 4-6 | alpine and shore turf |
| Flower | 35 cm | 8-12 | stem + a 2x2 or 3x3 head; head colour is per-INSTANCE, not per model |
| Fern | 55 cm | 20-30 | 4-6 fronds fanning out and drooping |
| Mushroom | 20 cm | 8-12 | stem + wider cap; cap voxels flagged EMISSIVE (see Stage 8) |
| Heath shrub | 50 cm tall, 90 cm wide | 30-50 | rusty low blob, ragged top; **two variants** |
| Alpine flower | 15 cm | 4-6 | small bright head close to the ground |
| Boulder | 1.0 / 1.8 / 3.0 m | 24 / 48 / 96 | three sizes, irregular, grey with slight per-instance tint |
| Scree stone | 30-50 cm | 6-12 | flat angular chips |
| Reed | 120 cm | 8-12 | tall thin, 2-3 stems, tan-green |
| Firefly | 12 cm | 1-2 | emissive yellow point; Stage 8 |

Placement is evaluated **per block column** inside each 16 x 16 chunk column,
hashed from `(seed, bx, bz, salt)`, so identity is stable. Densities are the
probability that a block carries one instance. Rules per zone:

| Zone | Rule |
| --- | --- |
| Meadow | grass tuft 0.35; flowers 0.15 **inside flower patches only** (fbm wavelength ~40 m, top 30%); each patch picks ONE head colour from {white, yellow, purple, red} by hashing the patch cell |
| Forest | grass 0.10; fern 0.12, multiplied by an fbm damp mask (wavelength ~25 m) so ferns clump; mushroom 0.02 everywhere, 0.15 within 2 blocks of a trunk |
| Glade (forest, glade mask 0) | as meadow |
| Alpine | short grass 0.20; alpine flower 0.04 |
| Heath | shrub 0.25 clumped by fbm (wavelength ~20 m); boulder 0.01 |
| Rock | scree stone 0.06; boulder 0.015 |
| Shore | reed 0.20 on cells within 1 block of altitude above the shore level; short grass 0.15 on the rest of the band |
| Snow | boulder 0.005, nothing else |

Everywhere: **no instance on a block occupied by a trunk**, none where the
surface block is `TRUNK`/`LEAVES`, none on slopes above 50 deg, none under
water. Every instance hashes a yaw (0-360), a scale (0.85-1.15), and a small
per-instance value tint (+/-6%) applied through the MultiMesh colour.

### The decoration layer

One `FloraColumn` node per **chunk column** (cx, cz), not per chunk - the
surface crosses a column once. Each holds one `MultiMeshInstance3D` per model
type present. Built by a `FloraJob` on the worker pool that returns a
`PackedFloat32Array` buffer per model type; the main thread sets
`instance_count` then `buffer`. Same shape as `MeshJob`, for the same reason:
the worker touches no scene state.

Local knobs, in `LOCAL_PROPERTIES`:

| Knob | Default | Meaning |
| --- | --- | --- |
| `flora_radius_m` | 64 | columns further than this from the player carry no flora node at all |
| `flora_draw_fraction` | 1.0 | an instance is drawn only if its hash < this; identity is unaffected, so every machine at the same fraction hides the same instances |
| `far_tree_m` | 300 | outer edge of the far-tree ring |
| `wind_strength` | 1.0 | 0 disables the sway shader |
| `night_life` | 1.0 | 0 disables fireflies and glow |

**Triangle budget: at most 1.5 M flora triangles in frame at High**, measured
with `Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)`
from a meadow-edge vantage. If it cannot be met by models alone, lower
`flora_radius_m` first, then `flora_draw_fraction`, and record both.

### Far trees

A ring from the voxel edge to `far_tree_m`, rebuilt on a worker when the
player moves more than 16 m, like `FarField`. Iterates the same tree
candidates with the same hash, so a tree you walk up to is the tree you saw.
One `MultiMesh` per species; impostor meshes of 6-12 triangles - a cone for
spruce/larch, a squat cone for krummholz, a stacked-octahedron dome for
beech/birch/hero, a thin box for snags - coloured by the species' A palette.
Height from `surface_at()`. No ground cover at distance, ever.

### Performance budget

At the High preset, measured against the baseline recorded before Stage 1:

- Boot to `is_idle()`: **at most +10%**.
- Main-thread ms during load: **at most +10%**.
- Frame time: **no regression** on this box; Marcel checks the 5080. If the
  triangle budget above is met, this follows.

If a budget cannot be met, the fix is the local knobs, in the order given, and
a line in `STATUS.md`. Never a stage skipped.

---

## Stages

Order matters. Instruments first, then trees (which are blocks and change the
world), then the decoration layer, then distance, then night, then the hooks,
then the budget, then the handoff.

### Stage 1 - instruments

Nothing here changes the world.

- **Model gallery.** `scenes/gallery.tscn` + `scripts/tools/model_gallery.gd`,
  headless. Lays out every tree species at its min, mid and max size on a
  flat pad - stamped straight through the species stamper into scratch chunks
  and meshed with `ChunkMesher`, not placed by the world - and every plant
  model beside them at 1:1 with the player capsule for scale. Fixed camera,
  frozen noon light. Writes `build/gallery/<label>/gallery.png` plus one
  close-up per species. Run as
  `<godot> --path . scenes/gallery.tscn -- --label some-name`.
  Until Stage 3 it shows one species; that is fine, shoot it anyway.
- **Tour vantage points.** Add to `screenshot_tour.gd`, derived from the
  world like the six that exist: `7-forest-interior` (eye 1.7 m up inside the
  densest forest cell), `8-meadow-closeup` (eye 3 m up, looking down 30 deg
  at meadow), `9-treeline` (mid-slope below the top of the forest band,
  looking up), `10-shore` (2 m from a lake edge, looking along it). Add a
  `--time` argument that pins `SkyCycle` to a fraction of the day, and shoot
  `11-forest-dusk` at 0.85 from the same spot as 7.
- **Probe lines.** `worldgen_probe.gd` reports: trees per species, total
  trees, glade share of the forest band, flora instances per zone (sampled
  on a stride, scaled up, and say so), and per-column flora build ms once
  Stage 5 exists.
- Shoot `foliage-baseline` with the tour and the gallery.

*Verify:* probe twice on seed 42, every line identical. Baseline sets exist.

### Stage 2 - the species framework

Move `_stamp_tree()` and its two helpers into
`scripts/world/flora/tree_species.gd` as a species table plus a stamper.
`TerrainGenerator._place_trees()` becomes the one hook that calls it - that is
the only edit to `terrain_generator.gd` in this stage.

- A species is a `Dictionary` or small class: height range, crown radius
  range, shape function, leaf ids A and B, trunk id, slope limit.
- `max_tree_height()` and the canopy margin are derived from the table's
  maxima, never typed.
- Spruce alone, at the old parameters (trunk 8-14, crown 4-6, the old cone).

*Verify:* **the seed 42 tree count is exactly the baseline's, and the chunk
determinism self-test passes.** If the refactor moved a single tree, it is
wrong. Then, and only then, change the parameters to the table.

### Stage 3 - seven species

Implement every shape function in the species table, the `_B` shade variants,
the new block ids, 2 x 2 trunks at height 16 and above, hero scaling.

- Whorls on the spruce. A crown that alternates r, r-1 per layer is what
  separates a spruce from a Christmas-tree cone.
- Sparse leaves for larch and birch are a per-block hash against the species'
  fill probability, salted, so the same tree is sparse the same way in every
  chunk that draws it.
- Krummholz may lean: the trunk offsets one block sideways at its top half.
- A snag's stubs are single blocks; at most three.
- Hero is the parent function with a scale factor and the 2 x 2 rule forced.

*Verify:* gallery shot of all seven at three sizes. `_test_tree_borders`
extended to stamp every species and pass with the widest margin. Self-tests
pass. Record which shapes were tuned blind.

### Stage 4 - placement

The product formula and the species table from Fixed Numbers, in
`scripts/world/flora/tree_placement.gd`. `_place_trees()` calls it.

- Groves, glades, slope, bench and spawn terms, each behind a config knob that
  disables it at 0, all in `PROPERTIES`.
- Trees in meadow, at the shore, and krummholz into heath and alpine.
- Species by altitude within the band, blended, with wildness.
- The trunk jitter and its bound.

*Verify:* probe reports trees per species and glade share on seeds 42, 7 and
12345. Tour shots 7, 9 and 10 against baseline. **Walk it:** the traversal
probe at `--view low` must still make its first 30 s at 75% or better of the
baseline's speed made good - dense forest that stops the probe dead is a
placement bug, not a feature. Self-tests pass.

### Stage 5 - the decoration layer

The infrastructure, with ONE model - the grass tuft - so it can be judged on
its own before the rest arrive.

- `flora_models.gd`: a voxel-model format - a list of
  `(x, y, z, colour, emissive)` at 8 voxels per block - and a builder that
  turns one into an `ArrayMesh` with hidden faces culled and vertex colours
  linear. Built once per model type and shared.
- `flora_placement.gd`: the per-column rules, returning `(model, x, y, z,
  yaw, scale, tint)` tuples. Y is the top face of the surface block.
- `flora_job.gd`: worker-side, calls placement and packs one buffer per
  model type. `flora_column.gd`: main-thread node, one `MultiMeshInstance3D`
  per model type, `use_colors = true`.
- `World`: submit a `FloraJob` per column inside `flora_radius_m` when the
  column's surface chunk is published; free the node with the column. **The
  only edits to `world.gd`:** the submit, the collect, the free, and a
  `_flora_dirty(column)` hook that Stage 9 uses. Keep the job under the same
  in-flight cap as gen and mesh; do not add a second pool.
- The material: one `ShaderMaterial`, `vertex_color_use_as_albedo` behaviour
  reproduced in the shader (`ALBEDO = COLOR.rgb`), roughness 1, no specular,
  plus the wind: bend `VERTEX.xz` by `sin(TIME * 1.3 + world_pos.x * 0.7 +
  world_pos.z * 0.4) * VERTEX.y * wind_strength * 0.08`. Height-weighted so
  roots stay planted. Must compile on Compatibility.
- **Amend `docs/DESIGN.md` in this commit**: the scale section gains the
  second exception - ground plants and boulders at 1:1, with the reason from
  Fixed Numbers.
- F3 shows flora instance count and columns; F4 gains the local knobs.

*Verify:* a new self-test builds one column twice and asserts identical
buffers. Meadow close-up tour shot. Triangle count and boot delta recorded
against the baseline.

### Stage 6 - ground cover

Every model and every zone rule from Fixed Numbers.

- Models in the gallery first; tune there, then place.
- Flower patches pick one head colour per patch.
- Ferns clump; mushrooms crowd trunks; shrubs clump; reeds follow the shore
  level via `Lakes.shore_level_at_cell()`.
- Boulders get a per-instance tint and the three sizes.

*Verify:* gallery shot with every model. Tour shots 7, 8, 9, 10 against
Stage 5. Probe reports instances per zone. Triangle budget checked at the
meadow edge; if over, apply the knob order and record it.

### Stage 7 - far trees

`scripts/world/flora/far_trees.gd` + `far_trees_job.gd`, following
`FarField` / `FarFieldJob` exactly: rebuilt on a worker when the centre moves
16 m, the ring from voxel edge to `far_tree_m`, one `MultiMesh` per species,
impostors from Fixed Numbers. Add the node in `game.tscn` beside `FarField`.

Do not draw impostors inside the voxel radius - the real trees are there. Do
not draw them past fog end.

*Verify:* postcard and treeline shots before and after. Impostor count and
rebuild ms recorded at High. A walk from meadow into forest shows no visible
pop where the impostors hand over to voxels - if it does, fade the impostor's
scale to zero over the last 16 m of the ring and say so.

### Stage 8 - night

- A global shader parameter `kubik_night`, 0 by day and 1 at night, set once
  per frame by `SkyCycle` from its own sun elevation with a smoothstep over
  civil twilight. Register it in `project.godot` under shader globals.
- **Glowing mushrooms:** the model's cap voxels carry `emissive = 1`, stored
  in the vertex colour alpha. The flora shader adds
  `EMISSION = COLOR.rgb * COLOR.a * kubik_night * night_life * 2.0`.
- **Fireflies:** a firefly model placed in meadow at 0.004 per block, only in
  columns that are meadow at the centre. In the shader, drift the vertex by
  `+/- 0.4 m` on a slow per-instance sine (hash the instance from its world
  position), blink with a second sine, and **scale the vertex to zero by
  day** - `VERTEX *= kubik_night` - so there is no alpha to sort and nothing
  to see at noon.

*Verify:* `11-forest-dusk` and a new `12-meadow-night` shot at time 0.95.
Both shaders compile on Compatibility (the tour is the proof) - and state
that Forward+ was NOT checked.

### Stage 9 - gatherable-ready

Gathering is a launch skill in `DESIGN.md`. Nothing is gathered tonight; the
identity and the removal path are built so that it is one RPC later.

- Every flora instance has a 64-bit identity: model id in the top 8 bits,
  sub-index 8, then cell x and z at 24 bits each, signed. Computed in
  placement, never stored per instance.
- `World._flora_removed: Dictionary` (id -> true), host-owned, in the same
  spirit as `_edits`. `World.remove_flora_local(id)` adds it and calls
  `_flora_dirty(column)`, which resubmits that column's job; placement skips
  removed ids.
- A block edit in a column also calls `_flora_dirty(column)`, so a broken
  surface block never leaves grass floating over the hole. The G test slab
  exercises this today.
- **No RPC, no handshake change.** Leave a comment at `remove_flora_local()`
  naming what the RPC will look like, mirroring `request_set_block()`.

*Verify:* a self-test removes an instance, rebuilds the column, and asserts
the buffer is exactly one instance shorter and every other instance is
unchanged. The G slab removes the grass under it.

### Stage 10 - the budget

Measure everything at High against the baseline: boot, main-thread ms,
triangles at four vantages, impostor count, per-column flora ms. Apply the
knob order until the budgets in Fixed Numbers hold. If a budget cannot be met
by knobs, the defaults ship at whatever meets it and `STATUS.md` says which
budget forced it.

Then the seeds: 1, 7, 42, 99, 123, 512, 2024, 31337, 65535, 999999. Every one
boots, spawns clear of trees, and reports a non-zero count for every species.
Report a seed with zero larch rather than adjusting the table.

*Verify:* the table of numbers in `STATUS.md`. Two headless peers, one at
High and one at Low, join and report the same config hash.

### Stage 11 - handoff

- Refresh every tour set and the gallery on the finished branch, labelled
  `foliage-final`.
- Rewrite `STATUS.md` completely. It must contain: every measured number;
  the **"Tuned blind - re-check these first"** section with every model and
  colour judged from the gallery; every departure from this plan with its
  reasoning; what was NOT done and why; the exact next step; and what the
  water and rivers plan will need from this work.
- `docs/IDEAS.md`: foliage v1 is done on its branch, water and rivers is the
  remaining half of Plan B.
- Leave **two or three new `TODO(marcel)` exercises**, each with a working
  fallback and a hint. Good candidates: the glade mask (noise picks
  districts, but a glade is where the ground is flat and the aspect is
  sunny, and the terrain knows both); the species blend curve; the firefly
  blink.

---

## If something goes wrong

- Three fix attempts per stage, then commit what works and move on.
- Never leave the repo uncommitted or the game unable to launch.
- A stage that cannot be completed is not a failure of the run - an
  unfinished branch with no `STATUS.md` is.
- If the frame or load budget cannot be met, **turn the local knobs down**
  rather than abandoning a stage, and say so. They exist so density is a
  dial, not a rewrite.
- If a stage would require touching the net protocol or bending a pillar,
  stop that stage and write the argument down instead.
- If the wind or night shader will not compile on Compatibility after three
  attempts, ship the layer without that shader feature, behind its knob at 0,
  and record it. The models matter more than the sway.

## The acceptance test

> Standing inside the forest at dusk, it reads as a forest: trunks around
> you, undergrowth at your feet, canopy overhead, and the treeline visible as
> a thinning to twisted pines above. From the meadow below, that same forest
> is still there at 300 m.

`11-forest-dusk.png` is the first sentence. `6-postcard.png` and
`9-treeline.png` are the second. Three additions:

- **A meadow is not one quad.** Grass moves, flowers come in fields of one
  colour, a lone beech stands somewhere in the frame.
- **Every species is tellable from the others in the gallery** without
  reading the label.
- **Nothing moved that should not have.** Seed 42's terrain, lakes, zone
  shares and spawn are identical to the baseline probe, line for line, in
  every line that is not about trees or flora.

Nothing in this plan matters more than those four.
