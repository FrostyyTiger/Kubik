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
