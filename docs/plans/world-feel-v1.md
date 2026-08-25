# World feel v1 - the ground keeps up, the forest closes over, the world pushes back

Three things that are wrong in play, in the order they have to be fixed:
chunks arrive slower than a sprint and the world seems to unload behind you;
the trees are correct against the mountain and a third of the size they
should be against the player; and nothing in the world has weight. Written
2026-08-25 after a 26-question session with Marcel; every decision below is
his, every number is a starting value. Two nights, one branch:
`feat/world-feel-v1`, from `main` at `1ed5b69` (look v2 merged, flora
streaming merged).

**Night 1** is streaming and the forest (Stages 0-8). **Night 2** is physics
(Stages 9-13) and starts from night 1's last commit, because bodies are placed
from columns that night 1 rebuilds the streaming of. If night 1 runs long,
night 2 waits; it does not start from `main`.

**Why now, against the Next 3.** The Next 3 are the first enemy, the campfire
and the water. Every one of them is walked to, fought on and camped under this
terrain, and the terrain currently cannot keep up with the player walking to
it: `docs/status/flora-streaming.md` measured a 48 m move at 5-9 s of missing
ground and named chunk streaming as the disease it was not allowed to treat.
The forest is the other half of "THE WORLD IS THE CONTENT" - ranging further
has to feel like ranging into something. And physics here is not a toy: its
first stage is the carried ticket (host-authoritative input, Combat D1) that
`README.md` calls the largest provisional bit in the codebase and that every
combat and creature plan is queued behind. Pulled forward, not jumped.

---

## What was measured, and what was decided

### Streaming (confirmed by reading the code, 2026-08-25)

- Chunk 16 blocks = 8 m; High preset radius 12 chunks = 96 m; ~6-8 chunks per
  column; 3,541 chunks queued at spawn (`worldgen_config.gd:138`,
  `world.gd:948`). Unload at radius + 2 (`world.gd:25`). Hysteresis exists;
  **there is no load/unload thrash.** What is felt as "unloading" is two other
  things, below.
- Sprint 13 m/s = 1.6 columns/s; each column crossed admits ~24 new columns =
  ~170 chunks, so sprint needs ~275 chunks/s, walking ~105/s. **Supply is
  60-150 chunks/s** (`worldgen_config.gd:175`: 3,043 chunks in 20.1 s headless
  at 4 jobs; `docs/status/foliage-v1.md:190`: 15.45 ms gen per chunk with
  trees). Sprinting always accumulates backlog. Walking is break-even on a
  good day.
- Why: gen and mesh are two worker tasks with a main-thread round trip between
  them, sharing one cap of 4, so the pool alternates four gens and four meshes
  with a frame of latency at each hand-off (`world.gd:570-624`). GDScript is
  serialised across worker threads in this build (measured: 6 jobs slower than
  4), so the cap is not the lever; latency bubbles and work per chunk are.
- **Every chunk of a column re-runs the tree scan.** `stamp_chunk()` scans
  `(16 + 2 * max_reach)^2 / cell^2` candidate cells and calls `decide()` for
  each (`tree_placement.gd:182-204`), and the ~7 chunks of a column each do it
  again. Tree stamping is half the gen cost (7.46 -> 15.45 ms when trees
  landed) and it grows with crown radius. Bigger trees on this pipeline would
  make streaming slower. This is why the column becomes the unit of work
  (Stage 2) before any tree grows (Stage 5).
- "Loads slowly then unloads": (a) the far-field hole is cut at radius - 2
  cells = 88 m the moment the centre column changes (`world.gd:739`,
  `far_field_job.gd:158`), so ahead of a moving player the far mesh retreats
  seconds before the voxels arrive - **that is the missing ground**; the
  impostor ring's inner edge does the same (`far_trees.gd:100`), so far trees
  vanish before near trees exist; (b) freed chunks are not kept - turning
  round rebuilds the trail (`world.gd:961-976`); (c) a column crossing does
  ~170 `queue_free`s, a `wanted` dict of ~3,000 entries and a GDScript
  `sort_custom` of the whole backlog in one frame (`world.gd:753-781`).
- **The camera clips at 400 m** (`scenes/player.tscn:30`) while High fog and
  the far field run to 600 m. Nobody has been seeing the far ridge.

### Scale (confirmed)

- Spruce 13-21 blocks = 6.5-10.5 m; eye at 1.5 m: **7:1**. A real spruce is
  25:1. Tree against ridge is 3 % - exactly real. So the trees are right
  against the mountain and 3.5-4x too small against the player, which is the
  1:4-land / 1:0.9-player split `DESIGN.md` accepts in writing.
- `DESIGN.md` ("Scale") has two rows: read against the landscape, 1:4; read
  against the player, 1:1. A tree is read against both - it is the one object
  that bridges the two - and the table has no row for it. This plan adds the
  row.

### Decided (Marcel, 2026-08-25)

| # | Decision |
| --- | --- |
| S1 | Hard rule: **never a hole** - the far field covers whatever the voxels have not reached, at any speed. Stretch: sprint sees full voxels 48 m ahead. |
| S2 | GDScript this plan. A GDExtension for gen + mesh is **named in the status doc as the next lever, not built.** |
| S3 | Far-field hole and impostor inner edge follow the **loaded** frontier. |
| S4 | Chunk LRU cache, hidden and kept, **3,000 chunks**. |
| S5 | Velocity-biased queue: in front of a moving player first. |
| S6 | 96 m stays the High target; **80 m is the fallback** only if the probe still shows the stretch failing. |
| S7 | A streaming probe is the gate. |
| S8 | Crossing hitch spread over frames: no frame over 33 ms. |
| T1 | Bigger trees + closed canopy + wider spacing. **The world is not rescaled.** `world_scale` stays 4. |
| T2 | Common forest **x2** (spruce 13-21 m, ~12:1). Old growth **x3** (spruce 20-32 m, ~20:1). |
| T3 | "Envelop" = height AND canopy closure: no sky overhead, trunks as columns, a shaded understorey. |
| T4 | Trunk width tied to height. |
| T5 | Old growth is a **grove type**, about a third of groves. Contrast is what makes huge read. |
| T6 | Fewer, bigger trees: lattice 4 -> 8 blocks. ~73,675 -> roughly 25-35k on seed 42 is expected. |
| T7 | Camera far plane fixed. High fog **600 -> 800 m**. |
| T8 | Opus amends `DESIGN.md` "Scale"; Marcel approves in the morning. |
| T9 | Spruce, beech, larch, hero scale; birch x1.5; **krummholz and snag unchanged.** |
| T10 | Understorey: a cheap shade under closed canopy, tuned blind, knob on F4. |
| P1 | Night 2: authority + boulders/logs as co-op tools + subtle slope momentum. Felled trees and ragdoll are **written as follow-on stages, not built.** |
| P2 | Physics starts with the carried ticket: **host simulates every body, players included; clients send input and interpolate.** |
| P3 | Jolt, set explicitly. |
| P4 | Foundation + one co-op demo. No stats, no attack, no enemy. |
| P5 | **Breaking terrain is settled: NO for v1.** Voxels never move. Written into `DESIGN.md` in Stage 13. |
| P7 | **One can rock it, two can roll it.** Push thresholds are a data table. |
| P8 | Bodies are a seeded subset of the worldgen boulders (and snags, for logs). No new placement system. |
| P9 | Momentum is subtle: sprint carries; steep scree and snow slide you. Meadow walking feels unchanged. |
| L3 | Morning test: (1) sprint spawn -> nearest forest, no holes, no frame over 33 ms; (2) stand in an old-growth grove, no sky overhead, mountain still framed from the meadow; (3) with a friend, push a boulder over the network and both see the same thing. |

---

## How to use this document

Execute top to bottom. One commit per stage on `feat/world-feel-v1`, named
`feat(world-feel): stage N - <title>`. Every number is a starting value to be
judged with the probes and the tour, not a law - but the hard rules are. Where
a judgement call remains, keep the game running and record the choice in
`docs/status/world-feel-v1.md`.

Before starting read `CLAUDE.md`, `README.md`, `docs/DESIGN.md` ("Scale",
"Camera", "Multiplayer", "Art direction"), `docs/status/flora-streaming.md`
(all of it - it is the case history), `docs/status/foliage-v1.md` ("What the
numbers were"), `docs/plans/terrain-v2.md` (Stages 3 and 7), and the comment
blocks at the top of `world.gd`, `gen_job.gd`, `mesh_job.gd`, `chunk_node.gd`
and `tree_placement.gd`. They contain the measurements this plan is built on.

Godot 4.7.2. On the overnight box (ganymede, headless, llvmpipe, no Vulkan)
everything visual is tuned blind and the status doc says so, section by
section; every streaming number is CPU and is meaningful there. On Marcel's
Windows box:
`%LOCALAPPDATA%\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64_console.exe`.
`<godot>` below means whichever applies. After any pull that adds `class_name`
scripts: `<godot> --headless --path . --import`.

### Evidence

```
<godot> --headless --path . -- --host --seed 42 --stream-probe                 # Stage 0 on
<godot> --headless --path . -- --host --seed 42 --flora-probe
<godot> --headless --path . -- --host --seed 42 --traversal-probe
<godot> --headless --path . --script scripts/tools/worldgen_probe.gd -- --seed 42
<godot> --headless --path . --script scripts/tools/worldgen_probe.gd -- --seed 42 --canopy   # Stage 6 on
<godot> --headless --path . scenes/selftest.tscn
<godot> --headless --path . scenes/character/selftest_character.tscn
<godot> --path . -- --tour --seed 42 --label feel-<stage>
<godot> --path . -- --tour --seed 42 --label feel-<stage>-gl --rendering-driver opengl3
<godot> --headless --path . -- --pair-probe --seed 42                          # Stage 10 on
```

The baselines are look v2's: `build/tour/look2-7-*` (12 shots, seed 42) and
the flora probe's table in `docs/status/flora-streaming.md`. The worldgen
probe must print heightmap hash **`76cccdb6`** and spawn **(-44, -124)** after
every stage of both nights; the config hash `da8868d1` and the tree count
73,675 hold through Stage 4, move once in Stage 5 and once in Stage 6, are
recorded in the status doc each time, and hold from there on. A stage that
moves the heightmap, or moves the trees when it was not one of those two, is
not done.

The self-tests pass at the end of every stage. The traversal probe passes at
the end of Stages 5, 6, 9 and 12. The stream probe runs at the end of every
stage of night 1 and its table goes into the status doc, one column per stage.

---

# Night 1 - the ground keeps up, the forest closes over

## Stage 0 - Measure first, and one bug

Nothing is tuned before it is measured. The flora probe measures a teleport;
this one also walks, because a hole is a real-time thing.

**`scripts/tools/stream_probe.gd`, `--stream-probe`.** Modelled on
`flora_probe.gd` (same wiring in `game.gd`, same wall-clock discipline). Two
parts, on seed 42 from spawn, physics off on the player:

1. **The jumps.** The flora probe's twelve 48 m jumps along +X, out and back,
   timing `terrain settle` (queue, gen and mesh all empty) and counting
   `chunks built` per jump. On the way back this is where the cache shows up
   as zero.
2. **The sprint.** Move the player at exactly 13.0 m/s along +X for 240 m,
   then turn and come 240 m back, in real frames. Sample every 0.25 s:
   - `frontier_m`: distance ahead, along the direction of travel, to the
     nearest **wanted** column that is not yet collidable
     (`World.is_chunk_collidable()` on its surface chunk). Report min and
     the 10th percentile.
   - `hole`: a wanted column inside the voxel radius that is neither
     collidable nor covered by the far mesh - "covered" meaning outside the
     far field's current exclusion radius in that column's direction (the
     probe reads `FarField` for it; Stage 3 makes that per sector). Report
     the number of samples with any hole, and the worst count.
   - `frame_ms`: max frame time and the count of frames over 33 ms.
   - `built/s`: chunks uploaded per second of wall clock over the sprint.
   - `rebuilt on return`: chunks built during the return leg.

   Prints one table, then quits non-zero if `--strict` and any hole was seen
   (Stage 3 on) or any frame exceeded 33 ms (Stage 4 on).

**F4 counters** (`debug_hud.gd`): gen and mesh in flight; chunks freed and
`refresh_region` ms on the last crossing; max frame ms over the last 2 s;
cache size. The existing gen/mesh ms are cumulative averages since load; add
a rolling 2 s average beside them.

**The bug.** `Camera3D.far` in `scenes/player.tscn` is 400 m. Set it from the
config at load - `fog_end_m * 1.25` - in `player.gd` where the SpringArm is
configured, and remove the literal from the scene. The tour's vantage that
looks at the far ridge is the check; before this stage it is cut off at 400 m
on High and Ultra.

**Evidence:** the stream probe's table, run three times, medians recorded as
the **baseline column** in the status doc before anything else changes. Tour
`feel-0` (ridge vantage). Self-tests.

**Verify:** the probe runs to completion on ganymede within the settle
timeout; the baseline shows a non-zero hole count and frontier min < 0 (the
player is ahead of the ground) at sprint - if it does not, the probe is not
measuring what the playtest felt, and that is the first thing to fix.

## Stage 1 - One task per chunk

Remove the round trip. A chunk's voxels and its mesh are one worker task.

- **`scripts/world/chunk_job.gd`** replaces `GenJob` + `MeshJob` for the
  streaming path: `generate_into()`, then `ChunkMesher.build_arrays()` on
  the same thread, then the **collision faces** - the `PackedVector3Array`
  that `create_trimesh_shape()` would derive - built on the worker too, so
  the main thread does `ConcavePolygonShape3D.new(); set_faces()` and nothing
  else. (`ArrayMesh` and the physics server stay on the main thread; a
  `Resource` built from arrays does not touch either.)
- Neighbours for the mesher: loaded neighbour chunks if they exist at submit
  time, the generator otherwise - exactly today's fallback. The edit-replay
  point moves with the publish: the chunk is published, edits replayed, and
  **if any edit landed, the chunk is remeshed** (today's `rebuild()` path)
  rather than the job's arrays used. The comment block that explains the
  replay point in `world.gd` moves with it.
- One cap, one in-flight set. `max_jobs_in_flight` keeps its meaning (chunks
  out at the pool) and its measured value 4; re-measure 3, 4 and 6 with the
  probe and keep the best. Flora's over-cap lane is untouched.
- `GenJob` and `MeshJob` stay for the edit path (`rebuild`) and the self-tests
  until nothing calls them; delete what is dead at the end of the stage.

**Evidence:** stream probe (`built/s` is the number), self-tests, tour
`feel-1` unchanged from `feel-0`.

**Verify:** `built/s` up by at least 1.5x on ganymede against the baseline;
48 m settle down accordingly. Heightmap hash, config hash, tree count and spawn
unchanged. Below 1.5x, the status doc records why with the per-phase timings
before Stage 2 starts - Stage 2 is the bigger lever and this one must not be
tuned in its shadow.

## Stage 2 - The column is the unit of work

Everything the world already reasons about is a column: `wanted`, free, flora,
the cache to come. Only the jobs were chunks. This stage makes the job a
column too, and it is what makes bigger trees affordable.

- **`ColumnJob`** (in `chunk_job.gd` or beside it): one task builds every
  chunk of a column - `column_surface_range()` from the bottom to the sky
  reserve - generating rock chunks by fill (as `generate_into()` already
  short-circuits), the surface chunks properly, and **stamping the column's
  trees once** through a writer that spans all its chunks, instead of once per
  chunk with the border scan each time (`tree_placement.gd:182`). The
  candidate scan for a column is `(16 + 2 * max_reach)^2 / cell^2` calls of
  `decide()` - once, not seven times.
- **The sky reserve is a ceiling, not a build list.** After stamping, the
  column knows the highest solid block it actually contains. Chunks above it
  are all air: they get no node, no mesh, no collider and no entry in
  `_chunks` (the mesher's neighbour fallback already answers "air" for a
  chunk that is not there, and the generator's `is_solid_at` agrees). This
  is what stops a 42 m hero on a meadow from costing five sky chunks on
  every column within its crown radius. `World.is_chunk_collidable()` for a
  chunk that was skipped as air answers true once its column has landed,
  because there is nothing to stand on and nothing missing.
- Upload is still per chunk under `BUILD_BUDGET_MS`; a column's chunks may
  land over two or three frames, bottom first.
- `_column_chunk_range()` stays as the *maximum* extent for the job; the
  job returns the actual one.
- The debug readout gains `columns built` and `ms per column`.

**Evidence:** stream probe, flora probe (unchanged or better - the grass never
needed the chunks), self-tests (the "sky reserve" test still passes: the
ceiling is unchanged, only what is built below it), tour `feel-2` unchanged.

**Verify:** `built/s` (counting chunks that got a mesh) up again; chunks per
column at spawn down from ~7 toward ~4-5; total chunks queued at spawn
recorded. Hashes, count and spawn unchanged. Sum of Stages 1 and 2: the 48 m
settle on ganymede at or under **3.0 s** at High (baseline 5-9 s). If it is
not, record the number, do not compensate with the radius yet (that is S6 and
comes after Stage 4), and go on.

## Stage 3 - The frontier

The far mesh and the impostors retreat only where the voxels have arrived.
After this stage there is never a hole, by construction, at any speed.

- **`World.loaded_frontier()`**: for 16 angular sectors around the centre,
  the radius (in chunks) out to which every wanted column is collidable.
  Cheap: maintained incrementally as columns land and are freed, not
  recomputed by scan. Exposed for the probe and the HUD.
- **`FarFieldJob`** takes that 16-entry array instead of one `exclude`
  radius (`far_field_job.gd:158`): a quad is skipped only if it lies inside
  the frontier of its sector, minus the same two-cell overlap. The far mesh
  is requested for rebuild when any sector's frontier advances or retreats
  by a chunk, not only on a centre crossing - `request_rebuild()` already
  coalesces, so this costs one worker rebuild per frontier change at most.
- **`FarTreesJob`** takes the same array for its inner edge
  (`far_trees.gd:100`): impostors stay until the real tree under them has
  landed. A far tree and a real tree overlapping for a second is invisible;
  a gap is not.
- Behind the player the frontier is simply the unload radius; nothing
  changes there.
- The far mesh already sits half a `detail_amp` below the voxel surface
  through the overlap; check that a two-second overlap of a whole leading
  edge does not z-fight in the tour. If it does, the far mesh drops by the
  full `detail_amp` inside the frontier band only.

**Evidence:** stream probe with `--strict` (holes must be zero on both
legs), tour `feel-3` (a shot taken 1 s after a 48 m jump, added to the tour
as vantage `frontier`: the seam is a far-mesh step, not sky).

**Verify:** `hole` samples = 0 across three probe runs. Far-field rebuilds
per 48 m of sprint recorded (expect a handful, not one per frame). Hashes,
count, spawn unchanged.

## Stage 4 - The cache, the queue and the crossing

- **Chunk cache.** Columns leaving the unload ring are not freed. Their
  nodes are hidden (`visible = false`, collider `disabled = true`) and moved
  with their `Chunk` to `_column_cache`, LRU, **`CHUNK_CACHE_CHUNKS := 3000`**
  counted in chunks (about 600 columns, a few 48 m steps). Eviction frees
  the oldest. On return a cached column is shown, its collider enabled, and
  **edits accepted since it was cached are replayed** - the invariant: a
  cached chunk is not in `_chunks`, receives no edits directly, and is
  restored through the same replay point Stage 1 moved. Memory on the render
  and physics servers is measured and recorded; if 3,000 chunks exceeds 250
  MB on ganymede the constant drops and the status doc says to what.
- **Velocity bias.** `_nearer_to_centre` becomes a key: `d^2 - bias *
  dot(offset, heading) * |offset|`, heading the player's horizontal velocity
  direction when speed > 2 m/s, else zero (so a standing player is
  nearest-first exactly as today). `STREAM_HEADING_BIAS := 6` chunks,
  starting value, probe-tuned: the number that puts the 10th-percentile
  `frontier_m` at its best without starving the sides.
- **The crossing.** Three things happen in one frame today. Spread them:
  frees (now cache moves) at most 32 nodes per frame from a pending list;
  the `wanted` scan builds only the **ring that changed** (the columns that
  entered and left, computed from the old and new centre, not the whole disc
  - the disc is 450 columns, the ring is ~24); and the queue is kept in
  **distance buckets** (an array of arrays keyed by integer `d^2` bucket)
  so a crossing re-buckets the ~170 new entries instead of sorting the
  backlog. Together: no frame over 33 ms on a crossing, on ganymede, at
  sprint.
- **The prune radius** for stale queue entries drops from unload to load
  radius (`world.gd:986`); a chunk in the trailing band that was never built
  should not be built when the player pauses.
- Flora's cache and margin are untouched; their constants stay theirs.

**Evidence:** stream probe with `--strict` (holes 0, frames over 33 ms = 0,
`rebuilt on return` = 0 until the cache overflows), flora probe, self-tests
(add a test: cache a column with an edit pending, restore, the edit is there),
tour `feel-4`.

**Verify:** this is where S1's stretch is judged: 10th-percentile
`frontier_m` at sprint, on ganymede. Record it. **If it is under 0 m (the
player is ahead of the voxels a tenth of the time) after the bias is tuned,
apply S6**: `VIEW_PRESETS` high radius 12 -> 10 (80 m), re-run, record both.
The far mesh covers the difference either way (Stage 3), so the game is
playable at both; the status doc tells Marcel which he is running and why.
Hashes, count, spawn unchanged - the last stage of which that is true.

## Stage 5 - Trees at 1:2

The forest scales. The land does not.

- **`WorldgenConfig`**: a new PROPERTIES knob **`tree_read_scale := 2.0`**
  ("the tree is read against the player as well as the land; this is how
  much closer to the player's scale it is drawn"). `tree_size_scale` stays
  what `apply_world_scale()` derives from the land (1.0 at `world_scale` 4)
  and is **not** multiplied; the two compose in `TreeSpecies.table()`, below.
  `REF_TREE_MAX_BLOCKS` and `REF_MAX_TREE_BLOCKS` stay in table units, and
  the "sky reserve" self-test and `apply_world_scale()`'s ceiling both take
  the composed maximum (`tree_size_scale * tree_read_scale`). The ceiling,
  `world_height_blocks`, moves; check it lands where the derivation says
  (`max_altitude + 84 + 3 + 16`, rounded up to 16).
- **Per-species read scale, as data.** `TreeSpecies.SPECIES` gains a
  `"read"` field, 0 to 1: how much of `tree_read_scale` the species takes.
  Each row's factor is `tree_size_scale * (1 + (tree_read_scale - 1) *
  read)`, applied to heights and crowns both in `table()`. Spruce, beech,
  larch, hero **1.0** (x2); birch **0.5** (x1.5); krummholz and snag **0.0**
  (x1 - unchanged in the world). The hero row scales like its parents and is
  now 32-84 blocks (16-42 m), one per 300 x 300 m of meadow, as before.
- **Trunks.** `THICK_TRUNK_HEIGHT` becomes a tier table in `TreeSpecies`,
  data not code: total height >= 16 blocks -> 2x2; >= 32 -> 3x3; >= 48 ->
  4x4. Heroes at least 3x3. The writer's trunk routine takes a width.
- **The lattice.** `tree_cell_blocks` 4 -> **8**, `tree_jitter_blocks` 1 ->
  **2** (min trunk gap 4 blocks = 2 m, walkable); `tree_base_forest` 0.45 ->
  **0.80** and `tree_base_forest_edge` 0.10 -> **0.20** on the coarser
  lattice (a candidate is now 16 m^2, and a closed canopy of 3 m crowns needs
  about one tree per 20 m^2 in a grove); `grove_floor` 0.35 stays, so between
  groves the wood opens to the sky - that is the contrast Stage 6 builds on.
  Meadow, shore and alpine bases are halved (0.004, 0.03, 0.025) so their
  tree counts per hectare stay where they were on the wider lattice.
- Far trees scale by construction (`far_trees_job.gd:172` carries real
  height and 2x crown in the transform) - verify in the tour that the
  impostor of a x2 spruce matches the real one at the handover.
- `flora_placement.gd`'s glade and grove masks are untouched; the flora under
  a bigger crown is Stage 6's business.
- The traversal probe is the walkability gate: spawn to the four corners,
  no 90 s stall. If a forest blocks it, `tree_jitter_blocks` goes back to 1
  before anything else moves.

**Evidence:** worldgen probe (**new** config hash and tree count, recorded;
heightmap hash and spawn unchanged), stream probe (chunks per column and
`built/s` recorded - expect the count to rise a little; if `48 m settle`
regresses by more than 20 % against Stage 4, that is a finding for Marcel,
not a reason to shrink the trees), flora probe, traversal probe, self-tests,
tour `feel-5` on both renderers plus a new vantage `under-canopy` at the
centre of the densest grove within 300 m of spawn, camera at the player's
eye, pitched up 30 degrees.

**Verify:** the tour's forest vantages show trunks at 12 player heights and a
canopy over the camera at the `under-canopy` vantage. Tree count on seed 42
within 25,000-40,000 - outside that, the lattice or the base is wrong, not
the seed.

## Stage 6 - Old growth, and the understorey

- **Grove type.** `grove_freq`'s mask already decides where groves are. A
  second hash per grove cell (`SALT_GROVE_KIND`) makes about a third of them
  **old growth** (`old_growth_share := 0.33`, PROPERTIES). Inside one: the
  species' read factor is raised so the tree is **x3** against today (spruce
  39-63 blocks, 19.5-31.5 m; beech 30-48; larch 36-60); `FOREST_WEIGHTS`
  shift toward spruce and beech and away from birch; snags 2x their weight
  (an old wood has dead wood in it); and candidates are thinned by hash to
  `old_growth_keep := 0.55` so trunks average ~11 blocks apart with crowns
  of 6-12 that touch. Krummholz and snag heights never change.
- **Canopy closure, measured.** `worldgen_probe.gd --canopy`: for the 20
  densest old-growth groves and the 20 densest ordinary groves within 600 m
  of spawn (found through `decide()`), stamp the columns around the grove's
  centre into a scratch writer and cast 64 rays from eye height (1.5 m) in a
  cone 60 degrees from vertical through the voxels; closure = the fraction
  that hit leaves. Prints per-grove and the means. Targets: old growth
  **>= 0.85**, ordinary grove **>= 0.60**, between groves **<= 0.20**. This
  is the "no sky overhead" of Marcel's morning test, run blind.
- **The understorey is shade, and shade is an ink** (look v2 rule 1). Each
  column's canopy cover - crown area over column area from its own tree list,
  clamped to 1 - is known to the column job for free. The turf vertex colour
  (through the same path AO takes in `ChunkMesher`) and the flora column's
  instance colour are mixed toward `kubik_shade`'s hue at
  `cover * canopy_shade`, luminance kept - **`canopy_shade := 0.35`**, a
  local knob on F4, tuned blind. Not a multiply; the swatch rule (look v2
  rule 4) is unaffected because this is a vertex-colour authoring step, not a
  transfer change. Fireflies under an old-growth canopy at dusk are the
  flora shader's existing night path; nothing to add.
- Ground cover under closed canopy: the grass share drops and ferns and
  mushrooms rise, through the placement product's existing zone gates - one
  more term, `canopy_cover`, in `flora_placement.gd`. Small, and it is what
  makes the floor read as a wood.

**Evidence:** `--canopy` (the three numbers), worldgen probe (**new** config
hash and tree count, recorded - the last time they move), stream, flora and
traversal probes, self-tests, tour `feel-6` on both renderers with
`under-canopy` moved to the nearest old-growth grove and a second
`old-growth-edge` vantage looking from open wood into it.

**Verify:** closure targets met; traversal probe green; tour shows the
contrast. If `canopy_shade` at 0.35 reads as mud on the Compatibility shot,
0.25 - record it.

## Stage 7 - The view

- `VIEW_PRESETS`: high `fog_end` 600 -> **800**; ultra 800 -> **1000**;
  low and medium unchanged. `FOG_START_RATIO` stays 0.4. Far-field vertices
  at High recorded (LOD rings make it roughly logarithmic; expect ~100k).
- `far_tree_m` becomes a preset field: low 200, medium 300, high **400**,
  ultra 500. The impostor rebuild is a serialised GDScript worker task like
  everything else: if the stream probe's `48 m settle` regresses by more than
  10 % against Stage 6 with High at 400, high goes back to 300 and the status
  doc says so.
- The camera far plane follows (Stage 0 made it `fog_end_m * 1.25`).
- The tour's ridge vantage on both renderers, and one new vantage,
  `postcard`, from spawn looking at the mountain that the spawn search
  guarantees is there - the "mountain still framed from the meadow" half of
  Marcel's test, before and after.

**Evidence:** tour `feel-7`, stream probe, F4 far-field and impostor counts.

**Verify:** the ridge is not clipped; the postcard frames peak, forest and
lake at 800 m; the stream probe holds Stage 6's numbers within 10 %.

## Stage 8 - Docs, night 1

- `DESIGN.md` "Scale": the table gains its third row - **read against both:
  trees, at 1:2** - with the argument in this plan's "Scale" section written
  as design, the old-growth tier, and the sentence "the land is not rescaled,
  and was not relitigated". The "Rendering is voxels near the player" line
  gains the frontier rule.
- `README.md`: "Chunk generation is on the main thread" under provisional
  bits is stale since terrain v2 and is removed; the stream probe joins
  "Running it"; the far-field seam line is rewritten (the frontier).
- `docs/status/world-feel-v1.md` (night 1 half): what shipped, the probe
  table with one column per stage from baseline to Stage 7, the hashes and
  counts at each move, memory of the cache, "Tuned blind" for everything
  visual, the S6 decision if it was taken, and **the GDExtension lever**
  named with the per-phase timings that would justify it.
- `docs/IDEAS.md`: a line under Next 3 in the shape of the look v2 note.
  `TODO.md`: the night 1 box ticked. `STATUS.md`: pointer replaced.

---

# Night 2 - the world pushes back

Starts from night 1's last commit. Read `docs/status/world-feel-v1.md` first:
the column job and the cache are what bodies stream with.

## Stage 9 - Jolt, and nothing else moves

- `project.godot`: `[physics] 3d/physics_engine="Jolt Physics"`. Physics tick
  stays 60. Nothing else in the section.
- The chunk collider is already a `ConcavePolygonShape3D` from worker-built
  faces (Stage 1). Confirm `backface_collision` is off and that the
  `StaticBody3D` per chunk is created asleep-cheap under Jolt; the F4
  readout gains physics-server body count.
- Cached columns keep their collider `disabled` (Stage 4); verify with Jolt
  that a disabled shape leaves the broadphase, by count.
- **The traversal probe is the gate for the player under Jolt.**
  `CharacterBody3D` behaves slightly differently on Jolt (floor snap, the
  `test_move` step-up in `player.gd:284`, `floor_max_angle`). Corners
  reached, no stall, no fall-through at spawn (`game.gd`'s release-on-collision
  path). A regression here is fixed in `player.gd` only if the fix is one
  constant; anything else is a recorded finding and the stage stops there.

**Evidence:** traversal probe, self-tests, stream probe (unchanged), a headless
run that spawns and stands for 30 s printing the body count.

**Verify:** traversal green; spawn release works; no chunk numbers moved.

## Stage 10 - The carried ticket

Client sends input; the host simulates; the host broadcasts. The table, the
RPC shape and the appearance path stay as they are (`game.gd:47-60`); only
the payload and where the simulation runs change.

- **`scripts/physics/locomotion.gd`**: the movement rules pulled out of
  `player.gd` into one static/RefCounted step - wish direction, speed
  multipliers, gravity, jump, `_step_up`, `move_and_slide` - taking a
  `CharacterBody3D` and an input snapshot. `player.gd` calls it for the
  local body; the host calls it for every remote body. One code path, so
  what the client predicts is what the host computes. `player.gd` still
  reads no number from `Races`.
- **Input up.** `_srv_report_state` becomes **`_srv_report_input`**:
  `{"w": Vector2 wish, "b": int bits (sprint, jump, precision, fly), "l":
  float look yaw}` at 30 Hz, `unreliable_ordered`. Fly stays a debug tool
  and the host honours it for any peer; this is written down as a debug
  allowance, not a rule.
- **Host sim.** One invisible `CharacterBody3D` per remote peer
  (`scripts/physics/player_sim.gd`, capsule from `DESIGN.md`: r 0.4, h 2.0),
  stepped in the host's physics tick with the last input received (held for
  up to 200 ms, then zero wish). Its position, yaw, velocity and state byte
  write into the authoritative table row exactly where the reported ones did.
- **Ground under a remote player.** The host loads columns around its own
  player only, so a remote player 500 m away has nothing to stand on. The
  host therefore streams a **collision-only ring** of `sim_radius_chunks :=
  4` (32 m) around every remote peer through the same column jobs - the
  column job gets a `mesh: bool` flag; with it false the arrays are built
  (the faces need them) but no `ArrayMesh` is uploaded and the node is a bare
  `StaticBody3D`. These columns join the cache like any other. `wanted`
  becomes the union of the host's disc and the peers' rings; the frontier
  (Stage 3) is per centre. This is the cost of authority and it is recorded:
  chunks per second with one remote peer sprinting away from the host, in the
  pair probe.
- **Client side.** The local player keeps predicting with the same
  `Locomotion` step (no input latency on your own body). When the host's
  position for you arrives: within 0.25 m, nothing; up to 2 m, ease over 100
  ms; over 2 m, snap. No rollback - written as provisional in `README.md`,
  with the shape a rollback would take. Remote players interpolate as today
  (`remote_player.gd`).
- **Solo is a host with zero clients** and does not change: the local
  player *is* the host's body.
- **`--pair-probe`** (`scripts/tools/pair_probe.gd`): launches a second
  headless Godot as a client (`OS.create_process`, `--join 127.0.0.1 --seed
  42 --pair-client`), waits for the join, has the client sprint 100 m along
  +X while the host's own player stands still, and prints per second: the
  host's row for the client, the client's own predicted position, the error
  between them, and host chunks built for the client's ring. Then the client
  walks back and the host confirms it arrived. Quits non-zero if the error
  ever exceeds 2 m after the first second, or the client fell below the
  surface.

**Evidence:** pair probe, self-tests, stream probe (the host's own numbers
must not regress with no client connected), traversal probe.

**Verify:** the pair probe passes; a client's reported error is under 0.5 m
median on loopback; `README.md` provisional bits and roadmap updated in Stage
13. The **journal** (habit 2): if no `Journal` exists, add
`scripts/game/journal.gd` - a host-side in-memory list with `log(event:
Dictionary)` and `dump()`, nothing else - and log `peer_joined`,
`peer_left`. Session v1 will give it a file.

## Stage 11 - Bodies

- **`scripts/physics/body_table.gd`**: the data, like `Races`:

  | kind | model | mass kg | hold N | sleeps |
  | --- | --- | --- | --- | --- |
  | boulder_m | `FloraModels.BOULDER_M` | 250 | 400 | yes |
  | boulder_l | `FloraModels.BOULDER_L` | 900 | 1000 | yes |
  | log | snag trunk, 6-10 blocks long, lying | 120 | 150 | yes |

  `hold` is the sum of player push force that starts it moving (Stage 12).
  A player pushes with **`PUSH_FORCE_N := 600`**: one player moves a
  boulder_m or a log; a boulder_l needs two. Starting values.
- **`scripts/physics/world_body.gd`**: a `RigidBody3D` with a convex hull
  from the model's voxels, **host only**. Clients have `WorldBodyView`
  (`Node3D` + the same mesh) interpolated like a remote player. One mesh
  per kind, shared.
- **Promotion, seeded.** In the column job, on every peer, each
  `BOULDER_M` / `BOULDER_L` decoration instance whose placement hash is under
  **`body_fraction := 0.15`** (PROPERTIES) is not drawn as decoration
  (`remove_flora_local` semantics, but decided at build, not stored) and
  becomes a body at its rest pose - the host creates the `RigidBody3D`
  asleep, a client the view. `SNAG` instances under `log_fraction := 0.10`
  become a log lying beside the stump. Body id = `WorldHash` of column and
  instance index, so every peer names the same rock the same thing.
- **Streaming.** A body belongs to its column. When the column leaves the
  host's range the body's transform is kept in `_body_state` **only if it
  ever moved** (otherwise it regenerates identically); on return it is
  restored. A body that has rolled into another column re-homes to it. Bodies
  in cached columns are frozen (`freeze = true`), not freed.
- **Replication.** The authoritative table gains `"b"`: `{id: [pos, quat]}`
  for bodies that are **awake** or moved in the last second, within 128 m of
  any peer, at most 32 per packet, `unreliable_ordered` with the players.
  A body that has gone to sleep is sent once more and then not at all.
  A client whose column loads asks nothing: it builds the rest pose, and if
  the host has a moved state for that id the next table packet corrects it
  (moved bodies are re-sent for 3 s whenever a peer's column containing them
  loads - the host knows, it built that peer's ring).
- **Everything through the one mutation path.** Clients never apply a force.
  A client's push is an *input* (it is walking into the rock); the host
  measures the contact and applies the impulse. No RPC exists that moves a
  body.
- Journal events, host: `body_moved` (id, kind, from column, to column,
  pushers), `body_settled`.

**Evidence:** self-tests (a new one: promote, sleep, cache the column, restore,
same transform; and determinism: two `WorldgenConfig`s with the same seed
promote the same ids), a headless run that counts bodies in the High disc at
spawn (expect a few dozen), pair probe extended to print body count on both
sides and that they agree.

**Verify:** body ids agree host and client; bodies asleep cost nothing
measurable in the stream probe (the number is recorded); the physics body
count on F4 matches.

## Stage 12 - The push, and the slope

- **The push, host.** Per physics tick, for each simulated player (the host's
  own included) every `get_slide_collision()` against a `WorldBody` while
  the player's wish has a component into it contributes `PUSH_FORCE_N` along
  the horizontal contact normal into that body's accumulator. Then per body:
  sum **>= `hold`** -> `apply_central_impulse(sum * dt)` at the contact and
  the body wakes; sum **< hold** -> the body stays asleep and **rocks**: a
  visual-only tilt of up to 3 degrees toward the push, on the view, on every
  peer (it is in the table as a one-byte `rock` flag for that body while a
  push is under way). A player walking into a boulder_l alone feels it give
  and not go. Two do, and it goes.
- Rolling, settling and sleeping are Jolt's. `linear_damp` / `angular_damp`
  starting at 0.3 / 0.5 so a boulder on a 30-degree meadow slope stops within
  ~10 m; on scree it keeps going (per-zone friction below).
- **Zone friction.** The chunk collider gets a `PhysicsMaterial` per zone
  band from a small table: meadow 0.9, forest 0.8, rock 0.7, scree/alpine
  0.45, snow 0.3. One material per chunk from its column's surface zone;
  chunks are already one zone almost always.
- **Momentum, `Locomotion`.** Horizontal velocity approaches `wish * speed`
  at **`ACCEL := 40`** m/s^2 and leaves it at **`DECEL := 30`** on the ground
  (0 to 13 m/s in a third of a second, sprint to stop in ~2.8 m); in the
  air, `AIR_CONTROL := 0.35` of that. Walking on a meadow does not feel
  different; a sprinting player carries. **Slope slide:** on the floor, with
  the floor angle over **`SLIDE_ANGLE_DEG := 45`** and the column's zone in
  scree/alpine or snow, add `GRAVITY * sin(angle) * SLIDE_FACTOR` downhill
  each tick, `SLIDE_FACTOR := 0.5`, capped at 8 m/s; `_step_up` is skipped
  while sliding. Meadow, forest and rock do not slide. The traversal probe is
  the gate again: corners reached, and now also **no corner reached only
  by sliding** - the probe reports the fraction of its path spent sliding
  (under 5 %).
- All of it on F4 as local knobs (they are simulation constants on the host;
  a client's copies affect only its prediction, and the host wins).

**Evidence:** pair probe extended: the client alone walks into the nearest
boulder_l for 5 s (it must not move more than 0.1 m and the rock flag was
set), then host and client push it together (it must move at least 2 m and
both sides agree on where it ended within 0.5 m); traversal probe; self-tests;
a headless run of the host's own player sprinting onto a scree slope from the
tour's `scree` vantage, printing the slide.

**Verify:** the three pair-probe assertions pass; traversal green with sliding
under 5 %; no chunk number moved.

## Stage 13 - The demo, and docs, night 2

- The tour gains vantage `boulder`: the nearest promoted boulder_l to spawn,
  a player beside it, shot on both renderers.
- **`DESIGN.md`**, new section "Physics": what is a body (the table), the
  push rule and why it is a co-op rule (pillar 1), momentum and the slide,
  the zone friction table, host authority for all of it, and the settled
  sentence: **"Terrain does not move. Breaking terrain is decided: no, in v1.
  Voxels are edited through the request path and never simulated."** The
  "Multiplayer" section: clients send input; the reconciliation rule.
- **`README.md`**: the carried ticket closed under provisional bits (and the
  new provisional: no rollback); `--pair-probe` under "Running it"; the
  roadmap line struck.
- **`docs/ROADMAP.md`**: D1 done here; the two follow-on stages written
  into their epics as specs, not built: **felled trees** (G. Items: a
  gathered tree is a `log` body spawned at the stump, the trunk removed from
  the column through the edit path) and **ragdoll / knockback** (D. Combat:
  the downed pose becomes a body for 2 s). `TODO.md`: D1 ticked, night 2
  box ticked.
- **`docs/status/world-feel-v1.md`** (night 2 half): what shipped, the pair
  probe's numbers, the host's chunk cost per remote peer, body counts, the
  push thresholds and what they felt like in the probe, "Tuned blind" for
  every physics constant (all of them - nobody has pushed a rock yet), and
  what is left. `STATUS.md` pointer updated.

---

## Hard rules

1. **The heightmap does not move.** Hash `76cccdb6`, spawn (-44, -124),
   every stage of both nights. The config hash and the tree count move in
   Stages 5 and 6 only, and are recorded when they do.
2. **GDScript only.** No GDExtension is built. It is named in the status doc
   with the numbers that would justify it.
3. **Voxels never move.** No physics touches a chunk's voxels; no body is a
   block. Breaking terrain is settled as no.
4. **One mutation path.** Bodies are simulated on the host and nowhere else.
   No RPC moves a body. A client's push is an input.
5. **The determinism contract holds.** A knob that changes what is generated
   (`tree_read_scale`, `old_growth_share`, `old_growth_keep`, `body_fraction`,
   `log_fraction`, the lattice) is in PROPERTIES and hashed. A knob that
   changes only what a machine keeps or shows (cache size, budgets, heading
   bias, fog, `canopy_shade`, physics constants) is local and is not.
6. **Never a hole.** From Stage 3 on the stream probe's `--strict` passes at
   the end of every stage. A stage that reintroduces a hole is not done.
7. **No frame over 33 ms on a crossing** at High, at sprint, from Stage 4 on,
   on ganymede. The absolute is judged again on the Windows box; the ratio
   against baseline is the overnight number.
8. **Night 2 starts from night 1's last commit**, never from `main`.
9. **Nothing on the Next 3 is built.** No enemy, no campfire, no water. Combat
   D1 is pulled forward as the authority path only: no stats table, no
   attack, no HUD bar.
10. `player.gd` reads no number from `Races`. Still. `Locomotion` does not
    either.
11. **Every starting value in this file is on F4 and in the status doc** with
    what it was, what it is and why.
12. **Self-tests green at the end of every stage; traversal probe green after
    Stages 5, 6, 9 and 12.** A red one stops the run at that stage with the
    output in the status doc.

## Acceptance

Marcel, in the morning after each night, on the Windows box at High:

**Night 1.** Sprint from spawn to the nearest forest. Never a hole; the far
ridge is visible the whole way; no hitch on chunk boundaries (F4 max frame
under 33). Turn round and sprint back: the trail is there. Walk into an
old-growth grove: trunks are columns, there is no sky overhead, the floor is
in shade; step out to the edge and the ordinary wood is visibly smaller and
lighter. From the meadow at spawn the mountain, its forest and the lake frame
in one view at 800 m.

**Night 2.** With a friend on the network: both walk, jump and sprint and
neither sees the other stutter. Find a big boulder. Push it alone: it rocks
and stays. Push it together: it rolls, and both of you see it end up in the
same place. Sprint down a scree slope: you slide; on the meadow you do not.

If either night misses its test, the status doc says which line and why, and
that is what the next session works from.

## Handoff

`docs/status/world-feel-v1.md`, in the shape of `docs/status/flora-streaming.md`
grown to two nights: the case, the probe tables (baseline through Stage 7;
pair probe through Stage 12), every hash and count at every move, every
starting value with its final value, "Tuned blind", the S6 decision if taken,
the GDExtension lever, and what is left. `STATUS.md` becomes a pointer to it.
