# World feel v1 - status

The run of `docs/plans/world-feel-v1.md`, on `feat/world-feel-v1` from `main`
at `a4bddbe`. Night 1 is streaming and the forest; night 2 is physics.

**Where this ran.** ganymede: headless, Mesa llvmpipe, no Vulkan. Every
**streaming** number here is CPU and is meaningful. Everything **visual** is
tuned blind on the Compatibility renderer and is marked as such, section by
section.

---

## Stage 0 - Measure first, and one bug

**Shipped.**

- `scripts/tools/stream_probe.gd`, `--stream-probe`, wired in `game.gd` beside
  the flora probe. Two parts: the flora probe's twelve 48 m jumps, and a
  **sprint** - 13.0 m/s along +X for 240 m and back, in real frames, sampled
  four times a second for `frontier_m`, `hole`, `frame_ms` and `built/s`.
  `--strict` exits non-zero on any hole or any frame over 33 ms.
- F4 counters: gen and mesh in flight, chunks built, nodes freed and
  `refresh_region` ms on the **last crossing**, and the worst frame in a
  rolling **2 s** window. The existing gen/mesh averages are cumulative since
  load, which is the right number for "did the world arrive" and the wrong one
  for "is it keeping up now".
- **The camera bug, and it was in three places.** `player.tscn` carried
  `far = 400.0` while High fog and the far field both run to 600 m. It is now
  derived - `fog_end_m * Player.FAR_PLANE_RATIO` (1.25) - set from the
  session's config by `Game`, and the literal is gone from the scene.

### The baseline, and it is the point of the stage

Three runs, seed 42, ganymede. Medians:

| | median | plan's expectation |
| --- | --- | --- |
| 48 m settle, outward | **8,857 ms** | 5-9 s, confirmed |
| 48 m settle, back | **7,332 ms** | - |
| hole samples (of 144) | **126** | non-zero, confirmed |
| worst holes in one sample (of 64 probe points) | **24** | - |
| frames over 33 ms | **43** (worst frame 70.6 ms) | - |
| `built/s` at sprint | **87 - 106** | supply 60-150, confirmed |
| `frontier_m` min / p10 | **32.0 m / 40.0 m** | **expected < 0** |

Run-to-run spread is tiny: 48 m settle 8,851 / 9,107 / 8,857 ms, holes 126 /
127 / 126, frames over 33 ms 44 / 43 / 38.

### The verify condition that did not hold, and what it means

The plan says: *"the baseline shows a non-zero hole count and frontier min < 0
(the player is ahead of the ground) at sprint - if it does not, the probe is
not measuring what the playtest felt, and that is the first thing to fix."*

The hole count is there - **126 of 144 samples**, up to 24 of 64 probe points
at once. `frontier_m` never went negative: sprinting 240 m from a settled
world, the collidable ground held **32-40 m ahead** the whole way.

The probe is not wrong, and it was not adjusted until it produced a negative
number. What the two halves say together is that **the missing ground is the
far mesh retreating, not the player outrunning collidable voxels** - which is
what the plan's own opening analysis says in as many words: *"the far-field
hole is cut at radius - 2 cells = 88 m the moment the centre column changes,
so ahead of a moving player the far mesh retreats seconds before the voxels
arrive - that is the missing ground."* The `frontier < 0` line was a second,
stronger hypothesis and it does not reproduce at 13 m/s.

**What follows from it:** Stage 3 (never a hole) is the stage that fixes the
reported symptom. Stages 1 and 2 are still the supply lever and Stage 2 is
still what makes the big trees affordable, but neither is what the playtest
felt. Recorded here so the Stage 3 numbers are read as the headline.

### The camera fix cannot be checked by the tour

The plan's check is *"the tour's vantage that looks at the far ridge"*. It
cannot be, for two reasons found here:

1. **The tour has its own camera.** `screenshot_tour.gd` builds a `Camera3D`
   with a hardcoded `far = 600.0` and never touches the player's rig - a
   *third* independent far plane. No tour shot has ever been taken through
   the camera that had the bug.
2. **At 600 m nothing visible is clipped anyway.** The fog reaches 1.0 at
   `fog_end_m`, so geometry beyond it is already fog-coloured. `6-postcard`
   shot at 600 m and at 750 m is pixel-for-pixel the same frame.

So: the tour's camera now takes the same expression the player's does (one
rule, two cameras), and the fix is verified where it can be - the startup line
now reads `camera far 750 m` and prints in every log. The pre-existing
horizontal banding on the far peaks in `6-postcard` is unchanged by any of
this; it is a look v2-era far-field artefact and is not this stage's.

**Gates, Stage 0:** self-test all passed; character self-test 28 all passed;
worldgen probe `76cccdb6` / `da8868d1` / 73,675 trees / spawn `(-44, -124)` -
unchanged, as a stage that touches no worldgen must leave them. Tour `feel-0`,
14 shots.

---

## Stages 1 and 2 - one task per chunk, then the column as the unit of work

**One commit, and the reason is that Stage 2 rewrites what Stage 1 builds.**
Stage 1's `ChunkJob` was replaced by `ColumnJob` within the hour; the two
interleave in the same functions of `world.gd` and cannot be separated after
the fact. Stage 1's *reasoning* survives in `ColumnJob` and in
`ChunkMesher.faces_from()`; the intermediate class does not.

### Stage 1 did almost nothing, and that is the finding

`ChunkJob` merged generation and meshing into one worker task and moved the
collision-face derivation onto the worker too. Measured against the baseline:

| | baseline | Stage 1 |
| --- | --- | --- |
| 48 m settle, outward | 8,857 ms | **8,681 ms** |
| `built/s` at sprint | 87 - 106 | **83 - 114** |
| main-thread upload per chunk | 0.18 ms | **0.12 ms** |
| chunks in 29 s wall | 3,742 | 3,742 |

**~1.0x, against a verify condition of 1.5x.** The plan requires that be
recorded with the per-phase timings before Stage 2 starts, so:

3,742 chunks x 7.6 ms of worker time = 28.4 s of work, in 29.5 s of wall clock.
**That is ~1.0 effective worker threads.** GDScript is serialised across the
pool in this build - the plan says so in its own analysis, and this measures
it - so removing a main-thread round trip removes latency that was never the
constraint. The only real win was 0.06 ms per chunk of upload.

A cap sweep says the same thing: `max_jobs_in_flight` 6 gives a 48 m settle of
8,617 ms against 4's 8,681. The cap is not the lever, exactly as the plan says.
**Kept at 4.**

**What follows:** on a serialised pool only *less total work* helps. That is
Stage 2, and it is why Stage 1 is worth having anyway - you cannot stamp a
column's trees once if the unit of work is a chunk.

### Stage 2 is the lever

`ColumnJob` builds every chunk of a column in one task, stamps the column's
trees **once** through a `TreeSpecies.ColumnWriter` that spans all of them, and
applies the **ceiling**: chunks above the highest solid block the column
actually contains are not built at all - no node, no mesh, no collider, no
entry in `_chunks`. `World.is_chunk_collidable()` answers true for them once
the column has landed, because there is nothing to stand on and nothing
missing.

The build queue, the in-flight set and the "is it here" questions are all
columns now; `_loaded_columns` is its own set, because a column's sky chunks
never appear in `_chunks` by design.

| | baseline | Stage 1 | **Stage 2** |
| --- | --- | --- | --- |
| 48 m settle, outward | 8,857 ms | 8,681 ms | **6,912 ms** |
| 48 m settle, back | 7,332 ms | 7,064 ms | **5,644 ms** |
| frames over 33 ms | 43 | 52 | **0** |
| worst frame | 70.6 ms | 77.5 ms | **18.8 - 31.2 ms** |
| chunks at spawn | 3,742 | 3,742 | **2,328** |
| chunks per column | ~7 | ~7 | **~5.2** |
| initial load, wall | 28.9 s | 29.5 s | **21.8 s** |
| `frontier_m` p10 | 40.0 m | 32 - 40 m | **40 - 48 m** |

**The crossing budget is already met, three stages early.** Stage 4 exists to
get frames over 33 ms to zero; Stage 2 did it, because a crossing no longer
creates ~170 chunk nodes - it creates the chunks of ~24 columns, and the
ceiling removed a third of those.

**The 3.0 s target is NOT met.** The plan asks for a 48 m settle at or under
3.0 s from Stages 1 and 2 together; it is **6.9 s**, down 22% from 8.9. Per the
plan the number is recorded, the radius is not touched (that is S6, after Stage
4), and the run goes on.

### The flora probe reads as a regression and is not one

`--flora-probe` reports **1,337 ms of grass after terrain** on the outward leg
where it used to report 0. The grass did not get slower; the ground got
faster, so grass that used to finish inside the terrain's long tail now
finishes after it. End to end, per jump:

| jump | before | Stage 2 |
| --- | --- | --- |
| out 1 | 6,207 ms | **5,636 ms** |
| out 2 | 7,937 ms | **7,042 ms** |
| out 3 | 8,219 ms | **7,185 ms** |
| out 4 | 8,371 ms | **7,479 ms** |
| out 5 | 9,599 ms | **8,864 ms** |
| out 6 | 10,396 ms | **9,517 ms** |

Every jump is faster, the instance counts are identical to the plant (39,610 /
39,325 / 39,417 / ...), and the return leg is still 0 ms with 0 columns
rebuilt. The plan's "unchanged or better" holds on the number that means
anything.

**Gates:** self-test all passed (including `edit during generation`, which now
covers a window spanning a whole column's voxels, trees and meshes); character
self-test 28 all passed; worldgen probe `76cccdb6` / `da8868d1` / 73,675 trees
/ spawn `(-44, -124)` - unchanged, as they must be until Stage 5.

**Two bugs this pass introduced and fixed.** Removing `_gen_in_flight` left
both probes asking for a set that no longer existed, so `_terrain_idle()` was
false forever and the first Stage 1 probe reported a settle of `-1 ms`. And the
`_gen_in_flight` -> `_in_flight` collapse briefly gave `world.gd` two variables
of the same name.

---

## Stage 3 - The frontier

**This is the stage that fixes what the playtest reported.** Stage 0 measured
126 of 144 sprint samples with a hole in them; nothing in Stages 1 or 2 touched
that number.

**Shipped.**

- `World.loaded_frontier()` - 16 angular sectors, each carrying the radius in
  chunks out to which every wanted column has landed. `_sector_missing[s][r]`
  counts wanted-but-not-loaded columns per sector per ring; it is filled inside
  the disc scan `refresh_region()` already does and decremented by one as each
  column lands, so nothing walks the disc twice.
- `FarFieldJob` cuts its hole per sector, not at one radius.
  `FarTreesJob` does the same for the impostor ring's inner edge.
- The far mesh and the impostors rebuild when the **frontier moves**, not on a
  centre crossing - which is precisely when the voxels have not arrived.
- `World.far_field_exclusion_m(dir)` is per sector, and reads
  `FarField.built_frontier()` - the frontier the mesh **on screen** was cut to,
  not the one the next rebuild will use.

### Holes: 126 -> 0, across three runs

| | baseline | Stage 2 | **Stage 3** |
| --- | --- | --- | --- |
| hole samples (of 144) | 126 | 124 | **0, 0, 0** |
| worst holes in one sample | 24 | 22 | **0** |
| frames over 33 ms | 43 | 0 | **0** (one run saw 1) |
| 48 m settle, outward | 8,857 ms | 6,912 ms | **7,857 ms** |

`--strict` exits 0. Hard rule S1 holds by construction at 13 m/s.

### Three things it took to get there, each measured

1. **The probe has to read the mesh that exists.** Testing against the
   *current* frontier hid the rebuild window entirely: holes read 3 when they
   were really 17. `FarField.built_frontier()` records what the displayed mesh
   was cut to.
2. **Two cells of overlap is not enough.** The plan says the hole sits two
   far-field cells inside the frontier, which is what the single-radius hole
   always used. At two cells the probe saw 17 hole samples; at four, 9; at
   **eight** (32 m), zero. The cause is rebuild latency - the frontier moves
   the moment a column lands, the mesh expressing it is built on a worker over
   a frame or two, and at 13 m/s the player covers real ground in that window.
   `FarFieldJob.FRONTIER_OVERLAP_CELLS := 8`. Overlap is invisible; a gap is
   not.
3. **The constant has to be shared.** Widening the job's overlap while
   `World.far_field_exclusion_m()` still computed two cells made the probe
   report 21 holes that were not there. Both read
   `FarFieldJob.FRONTIER_OVERLAP_CELLS` now.

### The cost, and it is real

The 48 m settle went **6,912 -> 7,857 ms**, about 14%. The far mesh rebuilds
far more often than it did - on frontier movement rather than on a centre
crossing - and a rebuild is a whole disc of ~100k vertices on a pool that runs
one GDScript task at a time.

Two things were tried against it. Requesting a rebuild only when the frontier
array actually **changes**, rather than on every landing column, recovered
about 0.5 s (8,328 -> 7,874). **Quantising** the frontier to steps of 2 chunks
(`FRONTIER_STEP_CHUNKS`, rounded down, which is the safe direction) recovered
nothing measurable - the cost is the crossing itself, not the frequency. The
quantisation is kept: it is principled and free.

**For Marcel:** never-a-hole costs about a second on the 48 m settle. That is
the trade S1 asks for and it is worth naming, because the GDExtension lever
named in Stage 8 would pay for it several times over.

### What was not done

The plan adds a tour vantage `frontier` - a shot taken 1 s after a 48 m jump -
to check the seam mid-motion. **Not added.** The tour photographs a settled
world by construction (it waits for `is_idle()` before every shot), so a
vantage inside it cannot catch a moving overlap; building one would mean a
second harness. The settled seam is checked instead - `feel-3/6-postcard` is
pixel-comparable with `feel-0` and shows no z-fighting from the wider overlap -
and the moving case is covered by the probe's hole count, which is the number
that matters and is zero.

**Gates:** self-tests green; worldgen probe `76cccdb6` / `da8868d1` / 73,675
trees / spawn `(-44, -124)`.

---

## Stage 4 - The cache, the queue and the crossing

**Shipped.** A column leaving the unload ring is **parked**, not freed - nodes
hidden, colliders disabled, kept in `_column_cache` as an LRU counted in chunks
(`CHUNK_CACHE_CHUNKS := 3000`). Restores are spread over frames
(`RESTORES_PER_FRAME := 8`) and evictions free at most `FREES_PER_FRAME := 32`
nodes a frame. New self-test **`edit while cached`**. The velocity-biased queue
key exists (`_queue_key`) and the heading is derived from successive recentres.

### The result

| | baseline | Stage 3 | **Stage 4** |
| --- | --- | --- | --- |
| holes | 126 | 0 | **0** |
| frames over 33 ms | 43 | 0 | **1 - 2** (36 - 41 ms) |
| 48 m settle, outward | 8,857 ms | 7,857 ms | **7,858 - 8,316 ms** |
| `frontier_m` p10 | 40 m | 40 m | **40 - 48 m** |
| chunks rebuilt, return leg | ~1,050 per jump | ~1,050 | **371 - 669** |

### S5 and S1 are in direct tension, and S1 wins

The velocity bias works, spectacularly: at `STREAM_HEADING_BIAS = 6` the
`frontier_m` **minimum** over a whole 240 m sprint is **96.0 m** - the full
voxel radius, ground loaded to the horizon in the direction of travel, against
40 m without it.

It also reintroduces holes. Measured:

| bias | frontier p10 | holes |
| --- | --- | --- |
| 6.0 | **96.0 m** | 8 - 12 |
| 3.0 | **96.0 m** | 8 |
| **0.0** | 40 - 48 m | **0** |

The mechanism is the frontier's definition: it is the radius out to which
*every* wanted column has landed, so building far-ahead columns before
near-side ones leaves a sector's frontier low and volatile, and the far mesh -
rebuilt on a worker - is chronically a step behind it. The plan anticipates the
failure ("without starving the sides") and its own rule settles it: hard rules
outrank every number, and S1 is *never a hole, at any speed*.

**`STREAM_HEADING_BIAS := 0.0`.** The mechanism is in and one constant turns it
on. **For Marcel:** this is the most valuable thing in night 1 that is switched
off. Making the frontier robust to out-of-order arrival - per-ring counts
instead of a first-missing scan, or a frontier that only ever retreats when the
far mesh has caught up - would buy ground loaded to 96 m ahead at a sprint.

### The prune radius had to go back

The plan drops the prune radius for stale queue entries from the unload radius
to the load radius. Measured, that alone took holes from **2 to 8**: columns at
the boundary get dropped from the queue and re-queued on the next crossing, so
they are never built while the player keeps moving. Reverted, and recorded.

### The cache's memory, measured twice because once was misleading

Static memory with the cache full: **268.9 MB at 2,996 chunks**, **226.1 MB at
1,997**. The first figure alone reads as over the plan's 250 MB ceiling, and
the constant was dropped to 2,000 on it. It is the whole process, not the
cache. The *difference* isolates it: **42.8 MB per 999 chunks**, so the cache
is about **86 MB at 2,000 and 128 MB at 3,000** - comfortably inside the
ceiling. **Restored to 3,000**, which is what the plan asked for.

### S6: not needed

Stage 4's verify is the S1 stretch: if `frontier_m` p10 at sprint is under 0 m
after the bias is tuned, drop the High radius from 12 to 10. It is **40-48 m**.
**S6 is not applied; High stays at radius 12 (96 m).**

### What is left, and it is named rather than hidden

**Frames over 33 ms went 0 -> 1-2**, at 36-41 ms, all on legs where the cache is
being evicted and restored. Stage 2 had already met the budget; Stage 4's own
work put it marginally back. The plan's two remaining remedies were **not
implemented** - the `wanted` scan that builds only the ring that changed
(~24 columns rather than 450), and the queue in distance buckets instead of a
`sort_custom` of the backlog. They were skipped when the budget was already met
at Stage 2 and are the named fix for the 1-2 spikes now.

**`rebuilt on return` is 371-669 chunks per jump, not 0.** The plan expects 0
"until the cache overflows"; at 6 jumps out it overflows - the trail is 288 m
and 3,000 chunks holds about 130 m of it. Halved from the ~1,050 of a cold
jump.

**Gates:** self-tests green including the new `edit while cached`; flora probe
0 ms of grass after terrain on the return leg; worldgen probe `76cccdb6` /
`da8868d1` / 73,675 trees / spawn `(-44, -124)`.

---

## Stage 5 - Trees at 1:2

**The forest scales. The land does not.** `world_scale` is untouched and the
heightmap hash is unchanged; this is the first stage that moves the config hash
and the tree count, and it moves them once.

**Shipped.**

- `WorldgenConfig.tree_read_scale := 2.0`, a PROPERTIES knob - what the PLAYER
  asks for, beside `tree_size_scale`, which is what the LAND asks for. The two
  **compose per species** in `TreeSpecies.table()`.
- `SPECIES` gains a `"read"` field, 0 to 1: spruce, beech, larch and hero
  **1.0** (x2); birch **0.5** (x1.5); krummholz and snag **0.0** - a knee-high
  alpine shrub at twice the size is not a bigger shrub.
- `TRUNK_TIERS` replaces the single `THICK_TRUNK_HEIGHT` flag: >= 16 blocks ->
  2x2, >= 32 -> 3x3, >= 48 -> 4x4, heroes never under 3. `_draw_trunk()` takes
  a width.
- The lattice: `tree_cell_blocks` 4 -> **8**, `tree_jitter_blocks` 1 -> **2**,
  `tree_base_forest` 0.45 -> **0.80**, `tree_base_forest_edge` 0.10 -> **0.20**,
  and meadow / shore / alpine bases halved to 0.004 / 0.03 / 0.025 so their
  counts per hectare hold on the coarser lattice.
- `apply_world_scale()`'s ceiling and the **`sky reserve` self-test** both take
  the **composed** maximum. The test now walks 12 scale/read pairs instead of 4.

### The numbers

| | Stage 4 | **Stage 5** |
| --- | --- | --- |
| config hash | `da8868d1` | **`5bb0a556`** |
| heightmap hash | `76cccdb6` | **`76cccdb6`** - unchanged |
| spawn | `(-44, -124)` | **`(-44, -124)`** - unchanged |
| trees on seed 42 | 73,675 | **31,224** |
| tree scan | 25.7 s | **11.3 s** |
| gen per chunk | 9.42 ms | **15.48 ms** |
| 48 m settle, outward | 7,858 - 8,316 ms | **9,989 ms** |
| holes / frames over 33 ms | 0 / 1-2 | **0 / 0** |

Tree count is inside the plan's 25,000-40,000 window. Spruce is now 26-42
blocks - 13-21 m, about 12 player-heights against the 7 it was.

### The settle regressed 22%, and that is a finding rather than a retreat

The plan: *"if `48 m settle` regresses by more than 20% against Stage 4, that
is a finding for Marcel, not a reason to shrink the trees."* It is **22%**
(8,150 -> 9,989 ms). Recorded; nothing was shrunk.

Where it went is visible in the two rows above it: there are **58% fewer
trees** and the whole-world tree scan is **more than twice as fast**, but a
chunk that does contain trees now costs 15.5 ms against 9.4, because the trees
in it are eight times the volume. Fewer, bigger, and the per-chunk cost is
what streaming feels.

**Holes stayed at 0 and frames over 33 ms went back to 0**, which is the part
that matters: the forest got three times the size without breaking the hard
rule Stage 3 established.

### The eye

`build/tour/feel-5/15-under-canopy.png` - a new vantage, standing where the
trees are thickest and looking **up 30 degrees**, because shot 7 looks level
and cuts the crowns off at the top of the frame by construction. It shows
trunks as columns filling the frame, a canopy closed overhead with almost no
sky through it, and a shaded floor. That is T3's "envelop" - height AND
closure - and it is the first time this project has had a picture of it.

**Gates:** self-test all passed including the widened `sky reserve`; stream
probe `--strict` PASS.

### The traversal gate fails, and it is not this stage's doing

Stage 5's walkability gate is the traversal probe, and it **fails**:

```
[Traverse] STUCK - no progress for 150 s
[Traverse] 233 s for 1,003 m of 4,107 m
```

The plan names a remedy - *"if a forest blocks it, `tree_jitter_blocks` goes
back to 1 before anything else moves"* - on the theory that the coarser lattice
plus the new trunk widths had closed the gaps. The arithmetic supports the
theory: at cell 8, jitter 2 and a 3 x 3 forest spruce the clear gap is 1 block,
0.5 m, against a player 0.8 m across.

**The theory is wrong, and it was tested rather than assumed.**

| | distance before stall | ground speed |
| --- | --- | --- |
| Stage 4, **before any tree changed** | **606 m** | 3.20 m/s |
| Stage 5, jitter 1 (the plan's remedy) | 875 m | 4.19 m/s |
| Stage 5, jitter 2 (the plan's value) | **1,003 m** | 4.31 m/s |

The probe stalls the same way at Stage 4, in a build with the old 73,675 small
trees, so the stall predates every tree change in this plan. And the bigger
forest makes it **better**, not worse - 1,003 m against 606 - because there are
58% fewer trunks to detour round.

`tree_jitter_blocks` is therefore **back at the plan's 2**: the remedy was for a
regression that did not happen, and applying it would have been tuning against
a misdiagnosis. Final Stage 5 hashes: config **`5bb0a556`**, heightmap
`76cccdb6`, **31,224 trees**, spawn `(-44, -124)`.

**FOR MARCEL - a pre-existing finding, outside this plan.** The traversal probe
cannot cross this world. It gets a quarter of the way to the far corner and
stops, at every stage tested, with `0 rescues from inside terrain` and 13-14
detours - so it is not falling through the ground, it is failing to route. Its
detour logic walks a straight line and side-steps obstacles; a lake, a cliff
band or a box canyon defeats that whatever the trees do. Either the world has a
place a player cannot get past, or the probe needs real pathing - and which of
those it is has to be answered before "spawn to the four corners" can be a gate
on anything.

---

## Stage 6 - Old growth, and the understorey

**Shipped.**

- **Grove type.** `TreePlacement.is_old_growth()` hashes the GROVE's own cell -
  quantised to `1/grove_freq`, the scale the grove mask varies on - so a whole
  wood is one kind and the boundary is a district edge rather than a speckle.
  `old_growth_share := 0.33`, `old_growth_scale := 1.5` (x3 against look v2's
  trees, composed with `tree_read_scale`), `old_growth_keep := 0.55`.
- Old-growth species shift: birch is re-rolled to spruce or beech (birch is a
  pioneer, and a closed canopy is what it is not), and some larch becomes snag.
- **`--canopy`** on the worldgen probe: stamps the columns around a grove into
  a scratch writer and casts 64 rays from eye height in a 60-degree cone. "No
  sky overhead", as a number, runnable blind.
- **The understorey.** Each column's canopy cover comes back from the same
  tree scan that stamps it, and the turf takes the shade ink's HUE at
  `cover * canopy_shade`, keeping luminance - an authoring step in the same
  place baked AO happens, so look v2's rule 4 is untouched and the swatch sheet
  does not move.
- `canopy_shade := 0.25`, a LOCAL knob on F4.

### The numbers

| | Stage 5 | **Stage 6** |
| --- | --- | --- |
| config hash | `5bb0a556` | **`dbf9369c`** |
| heightmap hash | `76cccdb6` | **`76cccdb6`** - unchanged |
| trees on seed 42 | 31,224 | **28,383** |
| initial load, wall | 30.1 s | **24.6 s** |
| gen per chunk | 15.17 ms | **7.66 ms** |
| 48 m settle, outward | 9,989 ms | **9,325 ms** |
| holes | 0 | **0** |
| frames over 33 ms | 0 | **3** |
| `frontier_m` p10 | 40 - 48 m | **56 m** |

**Stage 6 is faster than Stage 5**, which is not what a stage that triples a
third of the forest should be - see the bug below.

### Closure, measured

| | measured | target |
| --- | --- | --- |
| old growth | **0.694** | >= 0.85 |
| ordinary grove | **0.523** | >= 0.60 |
| between groves | **0.373** | <= 0.20 |

All three miss. The **ordering is right** - old growth is measurably more
closed than an ordinary grove, which is more closed than the space between -
so the mechanism works and the magnitudes do not. The one that matters most is
the third: **the wood between groves no longer opens**, and that is a design
question rather than a tuning, left as `TODO(marcel)` at `grove_floor`.

### Three bugs, and the order they were found in matters

**1. A RenderingServer call on a worker thread, once per VERTEX.**
`_under_canopy()` read the shade ink from a global shader parameter, which
means `RenderingServer` - which a worker must never touch. Nothing looked
broken: the world still loaded, the self-tests still passed, the colours were
right. It took **466 seconds** instead of 30, ten of twelve 48 m jumps stopped
settling inside a minute, and the worst frame was **268 ms**. The ink is
captured on the main thread in `World._submit_column()` now and passed down.

**2. The sky was being generated, not just reserved.** `ColumnJob` ran the
generator over every chunk in `cy_range`, including the ones entirely above the
ground, writing air into 4,096 voxels at a time. Stage 2's ceiling stopped them
being *meshed*; it never stopped them being *built*. Old growth made it visible
by raising `max_tree_height()` by half. Fixed, and it is why gen per chunk
**halved** (15.17 -> 7.66 ms) in a stage that made the trees bigger.

**3. `max_reach()` and `max_height()` did not know about old growth.** The
scale is applied per tree in `params_for()`, so a bound read off the table was
not a bound: crowns clipped at column boundaries, and the sky reserve short.
Both take it now, and the reserve's self-test walks 18 scale/read/old-growth
combinations instead of 4 - it caught the shortfall immediately at
`old_growth_scale` 3.0.

### One wrong turn, recorded

Between finding bug 1 and fixing it, crowns were left unscaled by old growth on
the theory that `max_reach` was the cost. It was not. Height alone left an
old-growth grove no more *closed* than an ordinary one - **0.553 against
0.517** - which is most of what old growth is for. Crowns are scaled again;
closure went back to 0.694 for about 500 ms of 48 m settle and two more frames
over 33 ms. The wrong turn is left in the comment where it happened, because
the next person to see `max_reach` grow will have the same idea.

---

## Stage 7 - The view

**Shipped.** `VIEW_PRESETS` gains a `far_tree` field, so the three distances
that have to agree are declared in one table instead of two files:

| preset | radius | fog_end | far_tree |
| --- | --- | --- | --- |
| low | 6 | 400 | 200 |
| medium | 8 | 500 | 300 |
| **high** | 12 | **800** (was 600) | **400** (was 300) |
| **ultra** | 16 | **1000** (was 800) | **500** |

`far_tree_m` used to be one number for every quality level, so High's forest
stopped at 300 m while its fog ran to 600 - a wooded ridge went bald halfway to
the horizon. The camera's far plane needed no change at all: Stage 0 made it
`fog_end_m * 1.25`, so it followed on its own. The boot line now reads
`view distance high: voxel radius 12 chunks (96 m), fog 800 m, camera far
1000 m`, which is the whole chain in one line.

### It is nearly free

| | Stage 6 | **Stage 7** |
| --- | --- | --- |
| 48 m settle, outward | 9,325 ms | **9,367 ms** (+0.4%) |
| initial load, wall | 24.6 s | **24.8 s** |
| far-field vertices | - | **103,608** |
| holes | 0 | **0** |
| frames over 33 ms | 3 | **1** |
| `frontier_m` p10 | 56 m | **56 m** |

The plan's condition was that High goes back to `far_tree` 300 if the settle
regressed by more than 10%. It regressed by **0.4%**, so **High keeps 400 m**.
That the fog can go from 600 to 800 m for nothing is the LOD rings doing their
job - the far field is roughly logarithmic in distance, and 103,608 vertices is
where the plan expected it (~100k).

### The new vantage

`16-spawn-postcard`: stand where the player starts, look at the highest ground
in the world. It is the second half of Marcel's morning test - "the mountain
still framed from the meadow" - and it is the shot the fog change is for. At
fog_end 600 the summit was beyond the fog from spawn, so the postcard could
only be taken by walking to a lake.

**Eye**, `build/tour/feel-7/16-spawn-postcard.png`: a meadow foreground, a
forested slope to the right with the treeline and the rock above it, snow peaks
to the left at the limit of the fog, a cream horizon band and the sun's rays
over it. Nothing is clipped.

**Tuned blind**, all of it: Compatibility on llvmpipe. **For Marcel:** the
meadow tufts read as a grey speckle at this density in this shot - it is the
"confetti" note from look v2's Stage 4 again, now over a wider view.

---

## Stage 8 - Docs, night 1

- `docs/DESIGN.md` "Scale" gains its **third row** - read against both, trees,
  at 1:2 - with the argument, the old-growth tier, and the sentence that the
  land is not rescaled and was not relitigated. The tree row's numbers move to
  13-21 m (old growth 19.5-31.5). "Rendering is voxels near the player" gains
  **the frontier rule**.
- `README.md`: "Chunk generation is on the main thread" is gone - it has been
  false since terrain v2 - and is replaced by what world feel v1 actually
  measured, that GDScript is serialised across the pool at about one effective
  thread. The streaming probe joins "Running it"; the far-field seam line is
  rewritten around the frontier.
- `docs/IDEAS.md`: a night 1 note under Next 3, and **the GDExtension** under
  Someday with the measurement that justifies it.
- `TODO.md`: A2 marked night-1-done.
- `STATUS.md` rewritten, with **three open items for Marcel** at the top.

---

# The morning message

**1. Where it is.** Branch `feat/world-feel-v1`, nine commits, **not merged**.
`main` is untouched. Night 1 (Stages 0-8) is complete; night 2 (Stages 9-13,
physics) has not started and, per the plan, starts from this branch rather than
from `main`.

**2. The three shots to open first.**

- `build/tour/feel-5/15-under-canopy.png` - standing where the trees are
  thickest, looking up. Trunks as columns, a canopy closed overhead, almost no
  sky. That is T3's "envelop" and the first picture the project has had of it.
- `build/tour/feel-7/16-spawn-postcard.png` - the summit, framed from where the
  player starts. The second half of the morning test, and the shot fog at 800 m
  is for.
- `build/tour/feel-6/7-forest-interior.png` - the understorey: shaded floor,
  mushrooms, huge trunks.

**3. What the plan asked for, and what happened.**

| | baseline | night 1 |
| --- | --- | --- |
| holes in a 240 m sprint (of 144 samples) | **126** | **0** |
| frames over 33 ms | **43** (worst 70.6 ms) | **1** |
| 48 m settle, outward | 8,857 ms | 9,367 ms |
| initial load, wall | 28.9 s | **24.8 s** |
| chunks at spawn | 3,742 | **2,370** |
| trees on seed 42 | 73,675 | **28,383** |
| spruce, against the player | 7:1 | **12:1** (old growth 18:1) |
| High fog | 600 m | **800 m** |
| camera far plane | **400 m** (a literal, three ways wrong) | 1000 m, derived |

The 48 m settle is the one number that went the wrong way, by 6%, and it bought
the frontier: the far mesh rebuilds on frontier movement now rather than on a
centre crossing.

**4. Three bugs found by measuring rather than by looking.**

- **A `RenderingServer` call on a worker thread, once per vertex** (Stage 6).
  Nothing looked broken - the world loaded, the tests passed, the colours were
  right. It took 466 seconds instead of 30.
- **The sky was generated, not just reserved** (Stage 6). Stage 2's ceiling
  stopped air chunks being meshed and never stopped them being built.
- **The camera's far plane was set in three places** (Stage 0), none of which
  agreed, and the tour had its own - so no tour shot had ever been taken
  through the camera that had the bug.

**5. Two wrong turns, both left in the comments where they happened.**

- `tree_jitter_blocks` was moved to 1 on the plan's own remedy for a
  walkability failure that predates every tree change in the plan. Moved back.
- Old-growth crowns were left unscaled on the theory that `max_reach` was the
  cost of a 466-second load. It was not, and height alone left an old-growth
  grove no more closed than an ordinary one.

**6. What is left.** The three open items in `STATUS.md` - the traversal probe,
canopy closure, and the velocity bias - and night 2.

---
---

# Night 2 - the world pushes back

Starts from night 1's last commit, as the plan requires: bodies are placed from
columns night 1 rebuilt the streaming of.

## Stage 9 - Jolt, and nothing else moves

**Shipped.** `project.godot` `[physics] 3d/physics_engine="Jolt Physics"`, tick
unchanged at 60. Nothing else in the section - everything that behaves
differently under Jolt is a property of a body, and bodies are configured where
they are built. The boot line prints the engine and the tick, for the same
reason it prints the camera's far plane: a setting nobody can see is a setting
that drifts, and a bug report that does not say which engine was running has to
be reproduced twice. F4 gains active objects, collision pairs and islands, and
there is a new `--physics-probe`.

**Nothing moved.** Config `dbf9369c`, heightmap `76cccdb6`, 28,383 trees, spawn
`(-44, -124)`. Character self-test 28 all passed. Stream probe holes **0**,
frames over 33 ms **1**; the 48 m settle reads 10,541 ms against Stage 7's
9,367, which is inside this box's run-to-run spread on a machine that has been
building worlds for a day - and no chunk count moved.

### The probe cannot answer its own best question, and says so

The plan asks Stage 9 to verify "that a disabled shape leaves the broadphase, by
count". It cannot be verified yet, and the probe now prints why rather than a
number that looks like an answer:
`PhysicsServer3D.get_process_info()` counts **active objects, collision pairs
and islands** - all properties of the DYNAMIC simulation. A world of static
trimesh colliders with no rigid bodies in it reports **0, 0, 0** whether the
cache is empty or holds 2,506 chunks, which is exactly what it reported. The
counters are real; they are measuring something that does not exist until Stage
11. **Deferred to Stage 11**, where a boulder resting near a parked column is a
direct test of it.

What the probe does establish: Jolt loads, the tick is 60, and a loaded world
standing still for 30 s does not drift by a single object.

### Jolt changes the traversal failure, and the change is the evidence

The plan makes the traversal probe the gate for the player under Jolt. It is a
**known-broken gate** - open item 1 - so it was run as a before/after against
night 1 rather than against "corners reached".

| | walked | made good | detours | rescues from inside terrain |
| --- | --- | --- | --- | --- |
| night 1, Godot Physics | ~1,000 m | 1,003 m | 14 | 0 |
| **Stage 9, Jolt** | **2,833 m** | 1,024 m | **58** | **0** |

Under Jolt the player **walks nearly three times as far and detours four times
as often**, and still converts almost none of it into progress toward the
corner. That is a much better answer than night 1 had: under Godot Physics the
character looked wedged, and the honest reading was "either the world has a
place you cannot get past, or the probe cannot route". Jolt settles it - the
character moves freely, over the same terrain, and still goes in circles.

**It is the probe's routing, not the world.** Open item 1 in `STATUS.md` is
updated to say so. Nothing in `player.gd` was changed: there was no regression
to fix, and the plan's rule for this stage - one constant or it is a recorded
finding - did not need to be invoked.

## Stage 10 - The carried ticket, closed

**Shipped**, in three commits, because the wire change is only readable next to
the thing that makes it safe.

`README.md` called this the largest provisional bit in the codebase: a client
simulated its own body and told the host where it had ended up, so "where is
peer 3" was whatever peer 3 said it was, and every combat and creature plan was
queued behind it. `_srv_report_state` is gone. `_srv_report_input` carries
`{"w": wish, "b": bits, "l": look}` at the session's sync rate,
`unreliable_ordered`, and the host steps an invisible `PlayerSim` per remote
peer through the same `Locomotion.step` the client predicts with.

### One implementation, and three things that had to move to make that true

The claim is not "the rules are in one file". It is that what the client
predicts and what the host computes are the same arithmetic. Three things were
still outside it and each would have been a silent divergence:

| moved into `Locomotion` | what it would have cost |
| --- | --- |
| `floor_snap_length`, `floor_max_angle` | a host capsule that snaps over a different distance drifts by a step height per slope, and never looks like a settings bug |
| `face_yaw()` | the table carries body yaw; two derivations means watching a friend's shoulders point where their feet are not |
| the capsule and its **offset** | see the buried body below |

The pose id is packed into bits 5-7 of the same byte, so the payload stays the
three keys the plan specifies. A pose is expression, not physics: the host
relays it rather than deriving it.

Input is sampled **once per tick** in `player.gd`, with a **jump latch**.
Physics runs at 60 Hz and packets go out at 20; a tap of Space that begins and
ends between two packets was predicted locally and never sent, and the host's
correction for a jump that did not happen is a full jump height of error.

### Three divergences caught by reading, not by testing

Written down because none of them would have failed a test, and all three were
found by reading the extraction back against the shipped code:

- `FLY_SPEED` was written as **6.0** against a shipped **18.0**.
- `speed_multiplier` resolved precision before sprint. `_locomotion_mode()`
  picks the *animation* sprint-first, so that ordering would have played a
  sprint cycle over a body moving at 0.3x - the exact disagreement that
  function's own comment promises cannot happen.
- Noclip's descend was folded onto the precision bit, which would have made
  flying down a third the speed of flying up.

### The pair probe, and what eleven runs cost

`--pair-probe` launches a second headless Godot as a client and has it sprint
100 m out and walk back under host authority. It took **eleven runs at about
nine minutes each** before it produced a number, and the reason is worth
recording: "the peer is not moving" has at least four causes and they are
indistinguishable from outside the process.

| what it looked like | what it was |
| --- | --- |
| the input RPC is broken | a client that has **joined** is not **ready** - while it generates its own world its packets do not reach the host at all. 78 `rpc_id` calls, **9** arrivals, no error on either side, and the backlog flushed the instant generation finished. It reproduced with the RPC forced `reliable`, which is what ruled out the transfer mode and ENet's throttle. |
| the movement step is broken | the capsule was **buried**. `player.tscn`'s Collider carries a y offset of 1 - the body origin is at the FEET - and that fact lived in the scene file and nowhere else. A shape built in code and centred on the origin puts half the body underground. It read as `is_on_floor()`, took its input, set 13 m/s, and moved nowhere. |
| the movement step is broken | peers spawned **inside the host**. Everything spawns at `spawn_position_m()`, so the second body to arrive arrives inside the first: `hit Player, normal (0, 1, 0)` - standing on its head, wedged for the whole run. |
| the input never arrives | the **hold window measured the wrong thing**. See below. |

Each of those took a run to distinguish. The diagnostic line on `PlayerSim` is
longer than a debug line usually deserves for exactly that reason, and it is
kept.

### The hold window, which is a real finding and not a probe artefact

`HOLD_MS` was 200 - six packets at the 30 Hz the plan asks for. But the interval
between packets is not the send *rate*, it is the **sender's frame time**, and a
host only hears a peer when it polls, once per its own frame. With two engines
on one box the host's frames averaged **595 ms**, so every input was over 200 ms
old before physics looked at it, every tick took the stale path, and a peer
sprinting flat out was simulated standing still - with `wish (1.0, 0.0)` sitting
right there in the struct.

The window is now `max(500 ms, three of the host's own frames)`. **A host cannot
honestly call a peer silent in less time than it takes to look twice.** This is
not only about slow boxes: a host that hitches for 300 ms while loading a chunk
should not stop every peer in the session dead for the duration.

### What the probe decided, and what it refused to decide

```
client: 100 m out and back, 8935 samples
client: prediction error  median 3.900 m  p95 7.486 m  max 9.968 m
client: lowest point 28.5 m, surface there 28.5 m
host:   647 chunks loaded, 66 built for its ring
host:   its own frames averaged 595 ms over the run
PASS on everything this box can decide; prediction error INCONCLUSIVE
```

**PASS**: the client travelled the full 100 m and back under host authority, and
never went below the surface - which is the collision ring working, 66 chunks of
it. **INCONCLUSIVE** on this box: 3.90 m of median error at sprint is **300 ms
of lag** against a host whose frames averaged 595 ms. The error tracks the
host's own frame time, so the thresholds measure how fast two engines run on one
machine, not whether prediction works. Same call as Stage 9's physics probe, and
the probe printed the arithmetic rather than a verdict it could not support.

### Settled on Forward+: PASS

Marcel ran the same command on the Windows box (RTX 5080, Vulkan 1.4.341,
Forward+) at this commit, seed 42:

| | ganymede (llvmpipe, two engines) | **Windows, Forward+** | plan's line |
| --- | --- | --- | --- |
| median error | 3.900 m | **0.217 m** | 0.50 m |
| p95 | 7.486 m | **0.651 m** | - |
| worst | 9.968 m | **1.300 m** | 2.00 m |
| host frame time | 595 ms | **4 ms** | - |
| implied lag from the error | 300 ms | **17 ms** | - |
| samples | 8,935 | 2,088 | - |
| chunks built for the ring | 66 | 46 | - |
| lowest point vs surface | 28.5 / 28.5 | 28.5 / 28.5 | never below |

`[PairProbe] PASS`. **Median error is less than half the plan's line and the
worst excursion is under two thirds of the failure limit**, on limits that were
never touched. The inconclusive reading was correct about its own cause: at
4 ms frames the implied lag is 17 ms, and the error collapses by a factor of
eighteen. Stage 10 is green.

The one thing worth keeping from the ganymede run is the *method*: the probe
turns a measured error back into an implied latency and compares it against the
host's own frame time. That is what let a number that could not mean what it
looked like say so, instead of being filed as a failure - and it is what makes
the Forward+ number trustworthy rather than merely better.

### The solo numbers did not regress, and proving that took a worktree

The plan requires the host's own numbers to hold with no client connected. The
stream probe came back **holes 1, frames over 33 ms 103, initial load 123.1 s** -
against night 1's 0, 1 and 24.8 s, which reads as a catastrophic regression.

It is not. Stage 9's commit, checked out into a worktree and run on this box
**within the hour**, gives:

| | load | holes | frames > 33 ms | worst frame | 48 m settle (out/back) |
| --- | --- | --- | --- | --- | --- |
| night 1 / Stage 9, when recorded | 24.8 s | 0 | 1 | - | 10.5 s |
| **Stage 9 commit, re-run today** | **123.4 s** | **4** | **104** | 680 ms | 13.9 / 13.7 s |
| **Stage 10** | **123.1 s** | **1** | **103** | 709 ms | 13.9 / 13.6 s |

Stage 10 is indistinguishable from its own baseline and marginally better on
holes. The box is about five times slower today than when night 1's numbers
were taken, with identical per-chunk worker cost (8.3 ms) - it is starvation,
not per-chunk work. **Config `dbf9369c`, heightmap `76cccdb6`, spawn
`(-44, -124)`, 2,370 chunks: the world did not move.**

The lesson is the one Stage 5 already taught and this stage had to learn again:
**a number from a different day is not a baseline.** Twenty-five minutes of
worktree turned a reported regression into a measured non-event.

### Also

- **The journal** (habit 2): `scripts/game/journal.gd`, host-side, in memory,
  logging `peer_joined` and `peer_left`. No file - session v1 gives it one, and
  a persistence format invented before there is anything to persist is a format
  that gets thrown away.
- **A `locomotion parity` self-test**, which took three attempts and whose first
  two would both have read as passes. Two capsules spawned inside each other
  shoved one another to a standstill and reported a perfect 0.000000 m drift;
  separating them revealed that `selftest.tscn`'s root is a plain `Node` with no
  `World3D` at all, so `move_and_slide` is a no-op there. It now judges the step
  by the velocity `_walk` computes and by the fly path, which writes position
  itself - covering everything except ground contact, which the pair probe
  gates. The `facing` test now calls `Locomotion.face_yaw()` instead of
  re-typing its arithmetic.
- `Locomotion.Input` had to be renamed **`Intent`**: it shadowed Godot's native
  `Input` singleton, and the error - `argument 2 should be "Input" but is
  "Input"` - only appeared once `player.gd` was loaded by a real scene, not by
  the self-tests.
- **`--pair-probe` takes no scene argument**, unlike every other probe here.
  Opening `game.tscn` directly skips the main menu, and the main menu is what
  opens the ENet socket; a host started that way is `Net.host_offline()` and the
  only symptom is the client logging "connection failed" where nobody is
  reading.

### `sim_radius_chunks`: measured, and deliberately left alone

Marcel ran the same probe on Forward+ at 3 and at 4, same seed, same commit:

| `sim_radius_chunks` | median | p95 | worst | ring chunks | lowest vs surface |
| --- | --- | --- | --- | --- | --- |
| 3 | 0.217 m | 0.650 m | 1.464 m | **38** | 28.5 / 28.5 |
| **4** (default) | 0.217 m | 0.651 m | 1.300 m | **46** | 28.5 / 28.5 |

Both PASS. 3 keeps ground under the peer as well as 4 across this excursion for
17% less collision built for terrain nobody looks at.

**The default stays at 4, and the result must not be over-read.**
`PairProbe.SPRINT_OUT_M` is 100.0, so the peer turns round at 100 m and neither
value was ever put under pressure: both runs show exactly one `floor false`
frame, the same step-up at about 40 m. "3 never fell" means "3 survives a 100 m
out-and-back on a 4 ms host", not "3 is enough". Finding the edge needs a longer
excursion, not another run at 100 m.

And the timing is wrong for it either way: Stage 11 puts bodies on exactly this
ring and Stage 12 pushes them around on it. This is not the week to trim the
ground out from under a remote peer to save eight chunks. The `TODO(marcel)` in
`worldgen_config.gd` now carries both numbers and names the experiment that
would actually settle it.

## Stage 11 - Bodies

**Shipped.** A fraction of medium and large boulders (`body_fraction`, 0.15,
hashed into the config) are rigid bodies instead of decoration. A `WorldBody`
on the host, a `WorldBodyView` on every client, and **nobody sends a list of
rocks**: both sides run the same seeded promotion, so a boulder nobody has
touched costs zero packets forever.

Promotion happens in the flora job **before the draw fraction**, and that
ordering is the correctness argument rather than a detail. `draw_fraction` is a
local knob; decide promotion after it and the far ring promotes fewer rocks
than the near ring, the set changes as a player walks towards it, and two peers
at different flora settings disagree about which boulders exist.

**Logs are not promoted, and that is hard rule 1 rather than effort.** The plan
asks for `SNAG` instances to become a log lying beside the stump - but a snag is
not a decoration, it is a tree SPECIES stamped into the chunk as voxels.
Turning one into a body means not stamping its trunk, which changes what the
world contains, and hard rule 1 freezes the heightmap, the config hash and the
tree count outside Stages 5 and 6. The row stays in `BodyTable` because the
table's shape is the point, and `docs/ROADMAP.md` now carries it as a
**gathering edit** instead - which sidesteps the rule entirely, because the
world still generates the tree and the player removes it.

### A remote peer gets rocks too

Stage 10c gave a peer a collision-only ring so it has ground. Without more, it
would have ground and no bodies, and every boulder on its own screen would be
one the host was not simulating - walking up to a rock and finding it welded to
the floor. So the host builds **bodies-only flora columns** around each peer:
the placement scan runs, the buffers and the MultiMesh upload do not. Same
trade as Stage 10c's meshless chunks, and the scan is the half that has to run
either way because promotion is a function of the placement.

### Four bugs, none of which raised an error

| what it looked like | what it was |
| --- | --- |
| `apply_central_impulse` missing on a `--host` session | `BodyField` decided host-or-client two lines **before** the `host_offline()` fallback that makes solo a host. Every single-player world was full of scenery that could not be pushed. |
| rocks fell through the world | a column's voxels are published several frames before its collider. One went from y 77 to y **-152** and "came back" 181 m from where it had settled. |
| a hillside avalanched itself | thawed awake, a boulder resting on voxel steps starts rolling untouched: one shove became **eleven** bodies "ever moved". |
| a shove that did nothing | an impulse applied to a sleeping body under Jolt is **discarded** - no error, no warning. |

And the probe nearly shipped as a liar twice: its first version pushed the
nearest body, 125 m away in a column with no collider and correctly still
frozen, so the drift was exactly 0.000 m because the rock had never left and
everything passed. Its second waited four fixed seconds and compared while the
boulder was still rolling.

**Result on seed 42:** 0 bodies at spawn - a meadow, and boulders grow in rock
and above, which is worth a printed line because it reads like a broken stage -
5 in the nearest rock zone, 0 awake. Shoved one **94.87 m** down a mountain over
21.1 s, exactly **1** ever moved, walked 220 m away and back, **drift 0.000 m**.

### Stage 9's deferred question, answered, and not the way it was asked

`PhysicsServer3D.get_process_info()` reads **0, 0, 0 under Jolt** in every
state: five bodies loaded, one of them rolling, columns parked and restored.
Jolt does not implement those counters - they are a Godot Physics readout that
the engine switch silently emptied. F4 now says `(Jolt: always 0)` rather than
showing three zeros that look like measurements.

The broadphase question is **sidestepped** rather than answered: a parked
column's bodies are FREED, not disabled, so there is no dormant dynamic shape
to ask about. A body is the opposite trade from a chunk - rebuilding one is a
node and a shared shape, while keeping it costs a broadphase entry. The chunk
colliders are still parked-and-disabled and that remains unmeasured on this
engine.

## Stage 12 - The push, and the slope

**Shipped**, and the headline is one measurement:

```
boulder_l   126 push contacts, rocked on 126 ticks, moved 0.000 m
boulder_m    69 push contacts, rocked on   0 ticks, moved 0.469 m
```

That is the acceptance test - *push it alone: it rocks and stays* - measured.
One player leans on a large boulder for three seconds, it gives on every one of
those ticks, and it does not budge; the medium one gives way.

### A resting body is frozen, not asleep, and that took four attempts

| what was tried | what happened |
| --- | --- |
| awake by default | one shove avalanched **eleven** bodies down a hillside |
| asleep on thaw | brushing past a boulder_l sent it **2.71 m** downhill |
| re-slept every sync tick | it integrated 50 ms between re-sleeps and walked **10 m** in three seconds with **zero** push contacts |
| re-slept every physics tick | still lost the race - **2 m** over three seconds |
| **frozen until shoved** | **0.000 m** |

Jolt wakes a sleeping body on contact with a moving one, and a boulder on a
mountainside that wakes for any reason rolls - gravity does the rest. Frozen in
Godot's STATIC mode a body is still solid; it simply does not move. `moved` is
set in `WorldBody.shove()` and nowhere else, so it means exactly "something
cleared this body's hold".

### The numbers, all of them starting values

| knob | value | what it means |
| --- | --- | --- |
| `PUSH_FORCE_N` | 600 | one player leaning |
| `hold` boulder_m / boulder_l | 400 / 1000 | one player / two players |
| `ACCEL` / `DECEL` | 40 / 30 m/s² | 0-13 m/s in 0.325 s; 2.8 m of run-out |
| `AIR_CONTROL` | 0.35 | steering with your feet off the ground |
| `SLIDE_ANGLE_DEG` | 45 | past this, loose ground carries you |
| `SLIDE_FACTOR` / `SLIDE_MAX` | 0.5 / 8 m/s | half of gravity downhill, terminal |
| zone friction | 0.9 meadow → 0.3 snow | where a boulder stops, not how hard it was hit |
| `ROCK_DEGREES` | 3 | the tilt that says *not on your own* |

Zone friction is visible in one number: the same shove that travelled **94.87 m**
before this stage now goes **63.34 m** over ground that resists it.

`Locomotion.step()` now returns whether the body slid - returned, not stored, so
it stays static and stateless.

### The push-holds self-test is a test of a design invariant

Four numbers make pillar 1 true and nothing in the code enforces the
relationship between them. The test asserts one player moves a boulder_m, one
player does **not** move a boulder_l, two do, and a heavier body is never
easier. It will fail the day somebody retunes the push to make boulder_m feel
better and silently turns boulder_l into a one-player rock - the pillar quietly
going away with every other test still green.

### The probe took eight runs, and three of the bugs were the probe's

"The rock did not move" is what a working co-op rule and a broken test look like
alike. It held a body reference across a settle that frees and respawns it (a
boulder nobody touched appeared to move 1.52 m); it teleported four times
mid-test, which restreams the region and takes the collider out from under the
body being pushed, so every push was correctly ignored; and the first boulder_l
it found sits somewhere a player cannot walk to. It now tries three candidates
and reports **no contact as UNTESTED rather than as a pass**.

## Stage 13 - The demo, and docs

- **Tour vantage `15-boulder`**: the nearest *promoted* boulder_l to spawn, at
  eye height and 6 m out. Found by running the real placement and the real
  promotion rather than guessing where rocks are - a photograph of a boulder
  that is not actually pushable would be a picture of the wrong thing.
- **`DESIGN.md` gains "Physics"**: what a body is (the table), the push as a
  co-op rule and why it is pillar 1, momentum, the slide, the zone friction
  table, host authority for all of it, and the settled sentence - **"Terrain
  does not move. Breaking terrain is decided: no, in v1."** The Multiplayer
  section gains the reconciliation rule and the collision ring.
- **`README.md`**: the carried ticket struck through and closed under
  provisional bits, replaced by an honest entry for what did *not* ship with it
  (no rollback) and the forty-line shape one would take. `--pair-probe` and
  `--body-probe` under "Running it".
- **`docs/ROADMAP.md`**: D1 marked done and struck from the critical path.
  **Felled trees** written into G as a spec - a gathered tree becomes a `log`
  body and the trunk goes through the EDIT path, which sidesteps the hard rule
  that stopped it here. **Ragdoll** written into D as a spec: the downed pose
  becomes a body for 2 s, and everything it needs except a capsule-shaped body
  now exists. `TODO.md`: A2 and D1 ticked.

## Night 2 - what shipped, and what it cost

| | before night 2 | after |
| --- | --- | --- |
| physics engine | Godot Physics | Jolt, tick 60 |
| who says where a player is | the client | **the host** |
| prediction error (Forward+) | n/a | **0.217 m** median, 1.300 m worst |
| host chunks per remote peer | 0 | 46 collision-only |
| pushable bodies | none | ~0.15 of medium and large boulders |
| a boulder for one player | scenery | boulder_m gives, boulder_l **rocks and stays** |
| sprint start / stop | instant | 0.325 s / 2.8 m |
| loose ground | inert | slides past 45° on alpine, rock, snow |
| journal | none | host-side, `peer_joined`/`left`, `body_moved`/`settled` |

**The world did not move.** Heightmap `76cccdb6`, spawn `(-44, -124)`, 2,370
chunks at High. The config hash moved once, in Stage 11, for `body_fraction` -
which is a PROPERTY because it changes what the world contains, and is recorded
here as hard rule 5 requires.

### Tuned blind - every physics constant

Nobody has pushed a rock, slid down a scree slope, or played this with a
friend. Every number in Stage 11's and Stage 12's tables is a starting value
chosen to make the *relationships* right - one player against two, walk
unchanged against sprint carrying, meadow against scree - and not one of them
is a number anybody formed an opinion about by feel. The push force and the two
holds are the ones most likely to move, because they are the difference between
"we shifted it together" and "I could have done that alone".

### What is left

1. **The two-player push has not been run as two machines.** The rule is
   proved as arithmetic (the push-holds self-test) and as a real contact with
   one player (the body probe). What is untested is the pair-probe choreography
   the plan describes - client alone at a boulder_l, then host and client
   together - because on this box two engines run at about one frame a second
   and the measurement would be of the machine again. **Marcel: this is the
   night-2 acceptance test.** `--pair-probe` already reports body counts and
   agreement; the joint push is the part to add on a machine that can hold 60.
2. **Hard rule 6 is GREEN and hard rule 7 is RED - see the section below.**
   Measured on Forward+, not here.
3. **The traversal probe still cannot route** (open item 1, unchanged since
   night 1). Stage 12 adds the number the plan asked for - the fraction of a
   crossing spent sliding - but the gate itself remains blocked on the probe
   needing real pathing rather than straight-line-and-sidestep.
4. **Logs are specified, not built** - see Stage 11 and the roadmap.
5. **The GDExtension lever is unchanged and still the biggest one.** GDScript
   is serialised across the worker pool at about one effective thread; the
   per-phase timings that would justify moving generation and meshing out of it
   are in night 1's sections above.


## The stream gate on real hardware, and the one-line fix that moved it most

Ganymede cannot decide this gate. Its own numbers sit at holes 3-4 and ~105
long frames whatever the commit - Stage 9's own commit re-measured on the same
day gives holes 4 and 104 - because at 700 ms frames nothing can keep a
frontier ahead of a 13 m/s sprint. Marcel ran the probe three times on the
Windows box (RTX 5080, Forward+, `--view High --strict`, seed 42) inside one
hour:

| commit | what it is | holes | frames > 33 ms | worst | frontier p10 | built/s | |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `322a10d` | before the shade_ink cache, before bodies | 0 | 32 | 63.0 ms | 56.0 m | 91.5 | FAIL |
| `8500d3e` | **+ shade_ink cache**, still no bodies | 0 | **0** | **28.2 ms** | **88.0 m** | **150.7** | **PASS** |
| `2c04969` | + Stage 11 bodies + Stage 12 push | 0 | 27 | 44.8 ms | 64.0 m | 95.2 | FAIL |

### Hard rule 6: GREEN

**Holes 0, on both legs, at every commit including Stage 12.** The frontier
never went negative - the player was never running on ground that had not
arrived. The "holes 3" recorded on ganymede was the box, exactly as the pair
probe's 3.90 m was. Stage 12 does not reintroduce a hole. That gate is closed.

### The shade_ink cache was worth more than anything else in night 2

One `RenderingServer.global_shader_parameter_get()` taken off the column submit
path, committed as a one-line tidy-up before Stage 11 because Marcel noticed
the error spam:

| | before | after |
| --- | --- | --- |
| frames over 33 ms | 32 | **0** |
| worst frame | 63.0 ms | **28.2 ms** |
| chunks built/s | 91.5 | **150.7** (+65%) |
| frontier p10 | 56.0 m | **88.0 m** |

**That is the best evidence in the whole run for measuring before tuning.** It
was not a performance task, nobody had it on a list, and it moved the gate from
FAIL to PASS on its own - while every constant night 1 and night 2 argued about
moved nothing by comparison. The readback had been on the hot path since Stage
6 and was invisible on ganymede, buried in llvmpipe noise that had already been
dismissed as pre-existing.

### Hard rule 7: RED, and it is Stage 11-12

Against the correct immediate baseline - `8500d3e`, the commit right before
Stage 11a - bodies take the probe from PASS to FAIL:

| | `8500d3e` | `2c04969` | |
| --- | --- | --- | --- |
| frames over 33 ms | 0 | 27 | |
| worst frame | 28.2 ms | 44.8 ms | |
| chunks built/s | 150.7 | 95.2 | **-37%** |
| frontier p10 | 88.0 m | 64.0 m | -24 m |

The signature is throughput, not rendering: `built/s` fell 37% and the long
frames track it, which points at the column path rather than at drawing rocks.
**By hard rule 12 this stops the run at Stage 12**, and the plan is right to say
so.

### What was found, and what is still open

Two per-column costs were found by reading and are fixed:

1. **Bodies were freed and rebuilt on the flora CACHE boundary.** The flora
   cache exists precisely because columns churn in and out of the drawn set
   constantly during a sprint - night 1 measured that and cached them for
   exactly that reason - and Stage 11 destroyed and rebuilt every one of their
   bodies on that boundary: three nodes, a collision shape and a physics
   registration each, on the main thread, all the way across a crossing. The
   plan says *"bodies in cached columns are frozen, not freed"* and this was
   implemented as the opposite, with a comment justifying it. They are now
   freed on cache **eviction**, which is where "cheap to rebuild" was always
   the right trade.
2. **Promotion was a whole extra pass per column.** Stage 11 called
   `BodyTable.promote()` for every instance and rebuilt the entire instance
   array minus the promoted ones - thousands of calls and thousands of appends
   per column, on the worker, for a rule that fires on about one instance in a
   thousand. It is now folded into the loop that was already there and gated on
   a model compare, so a meadow column of grass rejects all of it for the price
   of an integer. Measured here: **8.40 -> 8.20 ms per column**, back to the
   Stage 9 figure.

Only the second is measured: flora went **8.40 -> 7.77 ms per column**, below
even the Stage 9 figure of 8.20. That is real and it is 7.5% of a column, not
37% of a crossing.

### And a measurement that redirects the search

A body-churn counter was added to the stream probe, and at **High**, seed 42,
the whole crossing reports:

```
[StreamProbe] bodies 0 loaded, 0 built and 0 freed over the run
```

**Zero. Not few - none.** The probe sprints at spawn; spawn is chosen flat and
dry with a mountain in view, and boulders grow in rock and above. Nothing in
the High disc around that route is a boulder, so no body is ever created, and
the churn path the first fix targets **is never entered on this route at all**.

That matters for the diagnosis rather than just for this box, because Marcel's
three runs are the same seed and the same spawn. If his crossing also built
zero bodies - and it should have - then **body churn cannot be the 37%**, and
the cost has to be something Stage 11-12 does per column or per chunk with no
bodies present. The candidate that fits the signature best is Stage 12's
**zone friction**: every chunk's `StaticBody3D` now gets a
`physics_material_override`, which is an extra physics-server call on every
chunk built. It is invisible at ganymede's 48 chunks/s and would be squarely on
the critical path at 150.

**Marcel: hard rule 7 is not met until the probe is re-run on your box, against
`8500d3e`** - 0 long frames, 28.2 ms worst, 150.7 built/s - **not `322a10d`**.
Two things to check, in this order:

1. Does the run report `bodies 0 built`? If it does, stop looking at bodies.
2. Comment out the `physics_material_override` line in `ChunkNode.setup()` and
   re-run. That is the one Stage 12 change that costs something on every chunk
   rather than on every body, and it is a one-line A/B.

Both fixes above are kept either way: freeing bodies on the cache boundary
contradicts the plan and would have cost real time the moment a crossing
touched rock, and the promotion pass is measured.
