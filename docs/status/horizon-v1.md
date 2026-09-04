# Horizon v1 - status

The run of `docs/plans/horizon-v1.md`, on ganymede, in `~/Kubik-horizon-v1` on
`feat/horizon-v1`, started 2026-09-04. Three nights back to back in one
session, unattended, with `docs/plans/mesher-v1.md` running in the other lane
on the same box.

Written at the end of **every stage**, not at the end of the night, so a run
that dies at 04:00 still leaves a record.

---

## BLOCKING

**THE FRAME. `main` runs the sprint line at 41.67 ms median on ganymede at
Ultra; the north star's gate is 16.7 ms.** Measured for the first time tonight
by the instrument Stage 0 exists to build - three runs on a quiet box, spread
6.6%, 1,249 frames of 1,518 over the 25 ms hitch threshold. This is not a
regression this lane caused; it is the state of `main`, and it is what Stage 7
has to move. Full numbers under Stage 0.

---

## The canonical world line

Reprinted after every stage. One changed character is a red gate (plan § 0).

```
heightmap 4782edac   spawn (-44, -124)   53 lakes   15218 trees   config 1d7c18c7
```

**The plan's copy of this line says `c18af99d` and that is stale, not wrong.**
`docs/plans/horizon-v1.md` § "What horizon v1 is not" and § 2 both quote
`c18af99d` from `docs/status/light-v1.md`'s **Stage 0** table. Light v1's own
Stage 1 moved it to `1d7c18c7` and said so under the heading "The config hash
moved, and it was supposed to": D52 took `day_seconds` from 480 to 2400, and
`day_seconds` is deliberately a HASHED field because two machines running
different clocks would disagree about the hour for a whole session. `main` at
`f8ef45c` carries that change, this branch is cut from `main`, and the baseline
below measures `1d7c18c7` on the untouched tree.

So the invariant is unchanged and the number it is checked against is the one
measured here today. The four world-truth values - heightmap, spawn, lakes,
trees - are the plan's, character for character. Recorded under "Questions
taken alone" and in "For Marcel".

---

## The baseline, 2026-09-04, before the first edit

Taken on the tree at `f8d1588`, the tip of `main`, with the assets mounted and
the GDExtension built (`class exists: true`, C++ 19x GDScript on the seam
bench).

| instrument | result |
| --- | --- |
| `scenes/selftest.tscn` | **SELFTEST: all passed** |
| `worldgen_probe --seed 42` | heightmap `4782edac`, 53 lakes, **15,218 trees**, config `1d7c18c7` |
| `selftest.gd` canonical world | `heightmap 4782edac, spawn (-44, -124), 53 lakes, c++ builder`, both legs agreeing |
| heightmap build | 1500x1500 cells, 4 blocks per cell, 4,793 ms, 12 x 12 tiles of 512 blocks, median 10 ms |
| first far build (High) | 3,514,404 vertices, 673 ms job, 676 ms wall, c++ mesher |

---

## Stage 0 - the instruments, and the way to get anywhere

**Green.** Everything the plan's 0.1 to 0.5 asks for exists, exits, and is
measured below. Nothing visual changed, so this stage's tour is also the
baseline sheet.

### What shipped

| | what |
| --- | --- |
| `scripts/tools/sprint_probe.gd` | NEW. `--sprint-probe`, `--seconds`, `--label`. Sixty seconds of held sprint from spawn along `+X`, one flushed progress line per second to `build/probe/sprint-<label>.txt`, one machine-parseable summary, a 120 s watchdog that quits(2). **It exits.** |
| `scripts/tools/selftest_horizon.gd` + `scenes/selftest_horizon.tscn` | NEW. This lane's gate file, plus the one allowed line in `selftest.gd` that runs it inside the main suite. |
| `scripts/tools/far_probe.gd` | `--rings a-b`; the HANDOVER table; the C++ mesher by default with `--gdscript` to force the reference leg; two real bugs fixed, below. |
| `scripts/tools/screenshot_tour.gd` | `30-horizon-peak`, `31-horizon-far`, `32-horizon-walk`. |
| `scripts/game/game.gd` | `--sprint-probe`, `--tp X Z`, `--fog off`, `teleport_to()`; the ground wait now watches the player's own column. |
| `scripts/physics/locomotion.gd` | `FLY_SPEED` becomes `Locomotion.fly_speed`, written from the config on the main thread. |
| `scripts/world/sky_cycle.gd` | `SkyCycle.fog_off` - one switch, honoured in all four places fog is written. |
| `scripts/world/worldgen_config.gd` | Seven LOCAL, unhashed knobs; six of them inert until their stage. |
| `scripts/ui/debug_hud.gd` | Seven `horizon:` rows and a teleport row (two spinboxes and a button). |
| `scripts/tools/stream_probe.gd` | Retirement note at the top (Q22). Nothing else touched; `--stream-probe` still runs. |
| `scripts/world/flora/tree_field.gd` | `rebuild_count()`, for the sprint probe's line. |

### The canonical line

```
heightmap 4782edac   spawn (-44, -124)   53 lakes   15218 trees   config 1d7c18c7
```

Unchanged, both builder legs, `c++` and `gdscript`, in the same run.

### THE FRAME BASELINE - the number this whole plan exists to move

Ultra, seed 42, ganymede, **the mesher lane quiet** (it finished its Stage 4
before these were taken), three runs back to back:

| run | median | p99 | worst | over 25 ms | chunks | far rebuilds | far ms | tree rebuilds | moved | jumps |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| q1 | 41.67 | 75.34 | 87.64 | 1249 | 7827 | 19 | 530 | 3 | 543 m | 9 |
| q2 | 41.76 | 84.84 | 130.35 | 1253 | 7465 | 17 | 528 | 3 | 543 m | 10 |
| q3 | 39.17 | 80.30 | 115.76 | 1284 | 7711 | 18 | 532 | 3 | 543 m | 9 |

**Median of medians 41.67 ms, spread 6.6%. The gate is 16.7 ms. `main` runs
this walk at 24 FPS.** Frames over 25 ms: 1,249 of 1,518 - the run is over the
hitch threshold four fifths of the time.

That is the north star's third line, measured for the first time, and it is
BLOCKING at the top of this document until Stage 7 says otherwise. The far
field is the obvious suspect and the instrument already names it: **17 to 19
far rebuilds in sixty seconds at 530 ms each**, which is a rebuild every three
seconds and one of them in flight most of the time. Stage 3's "only what moved
is rebuilt" is aimed at exactly this.

### The determinism of the walk, and what the plan's Stage 0 check has to become

The plan asks that two back-to-back runs agree EXACTLY on `chunks`,
`far_rebuilds` and `tree_rebuilds`, and within 10% on `median_ms`. Measured:

| | q1 | q2 | q3 | spread |
| --- | --- | --- | --- | --- |
| `moved_m` | 543 | 543 | 543 | **0%** |
| `jumps` | 9 | 10 | 9 | one press |
| `tree_rebuilds` | 3 | 3 | 3 | **0%** |
| `far_rebuilds` | 19 | 17 | 18 | 11% |
| `chunks` | 7827 | 7465 | 7711 | 4.8% |
| `median_ms` | 41.67 | 41.76 | 39.17 | 6.6% |

**`chunks` and `far_rebuilds` cannot agree exactly and it is not noise in the
measurement - it is the measurement.** Chunk building is a per-frame time
budget (`World.BUILD_BUDGET_MS`) and a far rebuild is requested when the
frontier moves, so both are counts of what happened in however many FRAMES the
run got. A run that is 4% faster builds 4% more chunks. Asking them to be
identical is asking the frame time to be identical, which is the thing being
measured.

What IS exactly reproducible is the WALK: `moved_m` is 543 m in all three
runs, to the metre, and `jumps` differs by one press. So the check this
document holds itself to from here on is: **`moved_m` identical, `jumps` within
one, `tree_rebuilds` identical, `median_ms` within 10%** - and `chunks` and
`far_rebuilds` reported as load, not as gates. Recorded under "Questions taken
alone" and "For Marcel".

### The sprint probe jumps, and the plan did not ask it to

The first two Ultra baselines were taken exactly as 0.1 specifies - `wish =
(1, 0)` and the sprint bit, nothing else - and **both wedged against a rise
354 m out at second 43 and then measured seventeen seconds of standing still**:

```
s=43 frames=21 median_ms=48.15 ... moved_m=354 chunks=5377
s=53 frames=57 median_ms=17.52 ... moved_m=354 chunks=6219
s=60 frames=58 median_ms=17.12 ... moved_m=354 chunks=6219
```

Those trailing 17 ms frames are a stationary player with an empty chunk queue,
and they were dragging the median down into the sample the 60 FPS gate is read
off: 20.00 ms wedged against 41.67 ms actually moving. A frame gate measured on
a standing player is not a frame gate.

So the probe presses Space when it has not moved half a metre in half a second,
through `Player.jump_override` - the traversal probe's own hook, and the one
`player.gd` documents for this exact case ("a probe that never jumps measures a
world nobody plays in"). It still does not steer, fly or teleport: the line is
still straight along `+X`, a genuine wall still wedges it, and `moved_m` plus a
warning still say so. `jumps` is in the summary line because two runs that
jumped different numbers of times crossed different ground.

Recorded as a deviation under "Questions taken alone".

### Two bugs in the far probe, both older than this lane

1. **The far probe has crashed on its own header since light v1 merged.** Light
   v1 Stage 3 deleted `far_riser_shade`, `far_band_m` and `far_band_step` from
   the config with the paint path they belonged to, and left `_go()` printing
   all three: `Invalid access to property or key 'far_riser_shade'`. The probe
   then **hangs** - the coroutine aborts, `quit()` is never reached, and the
   process sits in its main loop forever. Every far-probe run since light v1
   merged has produced no table. Fixed: the header now prints the geometry
   knobs that survived.

2. **The probe's quad lookup could not see rings 0 and 1, and never could.**
   `LOOKUP_CELL_BLOCKS` is 8, with a comment reading "far_step is the finest
   ring's step, so one cell is covered by at most one quad of every ring" -
   true at `far_step` 8 with no divisor. `far_ring_div` has been 4 since
   2026-09-01, so ring 0's quad is 2 blocks: sixteen of them share one lookup
   cell, the claim loop keeps whichever it reaches last, and `height_at`
   returns NAN for fifteen sixteenths of the samples. It went unnoticed because
   fizz and roughness sample a sparse lattice over the whole disc where the
   coarse rings carry the count, and peak loss reads a summit at 600 m, which
   is ring 3. **The handover measurement is the first thing that asks about the
   seam**, and the seam is ring 0 - it came back "no samples" everywhere.
   Fixed: quads finer than the lookup cell are keyed exactly by their own
   corner at their own step, which is an index rather than a search.

Both are recorded here rather than only fixed, because the second one means
**no distance-v5-era number taken at the seam or at the 150 m and 300 m
boundaries can be trusted**, and the first means no far-probe table exists
anywhere between light v1 and tonight.

### The far probe now runs the C++ mesher by default

At `fog_end_m` 3,200 and `far_ring_div` 4 a far mesh is 3.44 M vertices and
most of a minute in GDScript; the probe builds 49 per run and runs twice. One
GDScript run was measured at over 90 minutes on this box and was abandoned.
The C++ leg does the same table in **71 s per run**. `far_cpp` defaults to 1,
so C++ is what the game draws; the GDScript leg is still reachable with
`--gdscript`, and that the two agree is asserted three ways in `selftest.gd`
(far parity, far slice parity, far layer parity, all green tonight).

### The far probe's table, `main`, Ultra config at High preset, C++ leg

```
vantage         fizz rms  fizz max  roughness
spawn              0.746    61.000     8.6779
summit             1.216    39.000    12.7263
lake               0.785    39.000    10.2934
ALL                0.975    61.000    11.1573   (514,700 samples)

ring boundary max fizz (+/- 25 m)
  150 m: max  7.00 rms 0.433 over  2811
  300 m: max 11.00 rms 0.842 over  3738
  600 m: max 32.00 rms 2.413 over  6459
 1200 m: max 48.00 rms 2.648 over 15287
 2400 m: max 39.00 rms 4.563 over  3551

peak loss   over 20: mean +0.96, worst +2.62, best +0.68, 0 over 4 blocks
valley gain over 20: mean -1.15, worst -0.73, best -2.13, 0 over 4 blocks

handover (rms / max, blocks; ! = over the gate; @N is the bearing used)
spawn   seam@0   0.36 / 1.61  |0/1@0   0.81 / 4.18 ! |1/2@180 0.80 / 1.71  |2/3@0   2.76 / 10.42 ! |3/4@0   5.97 / 19.35 !
summit  seam@90  0.69 / 1.71  |0/1@90  3.15 / 9.27 ! |1/2@90  8.33 / 31.62 !|2/3@90  1.95 / 6.86   |3/4@90 15.69 / 56.76 ! |4/5@180 13.82 / 90.97 !
lake    seam@0   0.08 / 0.17  |0/1@0   0.43 / 1.12  |1/2@0   1.18 / 4.52 ! |2/3@0   2.92 / 9.31 ! |3/4@0   0.77 / 2.39

far meshes: 98 built, 591 ms each, 3,436,848 vertices each
determinism: run 1 in 70,766 ms, run 2 in 71,328 ms, tables IDENTICAL - PASS
```

**The handover fails at most ring boundaries on `main` today.** That is the
baseline Stage 3 and Stage 4 are measured against, not a regression: this is
the first time the number has existed. The seam itself is comfortably inside
the gate at all three vantages, which is the one boundary distance v3 Stage 7
spent a stage on.

### Checks

| check | result |
| --- | --- |
| sprint probe exits 0, 60 progress lines | **PASS**, five runs, every one |
| sprint probe run twice: the walk identical | **PASS** - `moved_m` 543 in all three, `tree_rebuilds` 3 in all three, `median_ms` within 6.6%. `chunks` and `far_rebuilds` are load, not gates - see above |
| frame baseline recorded | **41.67 ms median**, and it is BLOCKING |
| `--tp 20000 0` then the far probe: exits 0, both runs identical | **PASS** - `[Game] teleport to (20000, 0) m, ground 326.3 m`, tables IDENTICAL, exit 0. The 326.3 m is the region's clamped edge height, which is exactly what Stage 1 removes |
| `--rings a-b` | present; narrows what is printed, never what is measured |
| horizon self-test | **PASS**, 4 tests |
| main self-test | **SELFTEST: all passed**, including `horizon` |
| character self-test | **36 tests, all passed** |
| far probe twice, identical | **PASS** |

### Tunables moved

None. Every knob added in this stage is at its plan value.

---

## Stage 1 - the tile store

**Green.** The height map has no edge. `height_at` answers everywhere, from the
seed, in tiles anchored to the origin - and the home region's 1500 x 1500 array
is still inside it, bit for bit, which the canonical line proves.

### What shipped

| | what |
| --- | --- |
| `scripts/world/heightmap.gd` | The store: `_tiles` / `_tiles_max` keyed `(level, tx, tz)`, a mutex, `ensure_tile`, `ensure_disc`, `evict_beyond`, `tile_stats`. `height_at` and `_bilinear` route outside the region to it. `in_bounds` renamed `in_home_region`. Five `far_*` doors that never build. |
| `scripts/world/terrain_generator.gd` | Hands the store its builder; `detail_at`, `_slope_zone` and `surface_zone_at` gain a `far` flag that picks the height door. |
| `scripts/world/far_field_job.gd` | Reads the far doors, and passes `far` down to the three generator calls. |
| `scripts/world/far_field.gd` | `publish_far_view()` on the main thread before every build. |
| `scripts/world/far_mesher.gd` | Marshals the tiles C++ has not seen, once per tile. |
| `gdext/src/far_world.{h,cpp}` | `TileKey` / `Tile`, the tile map, `material_tiles` named and empty for Stage 4, `tile_bilinear`, `add_tile` / `add_tiles`; `height_at` and `bilinear` route outside the region. |
| `gdext/src/far_build.cpp` | Takes the new tiles off the wire at the top of a build. |
| `scripts/world/world.gd` | `_evict_height_tiles()` on every frontier crossing. |
| `scripts/tools/sprint_probe.gd`, `far_probe.gd`, `debug_hud.gd` | The tile line: how many are held, how much they weigh, how many were built. |

### The canonical line

```
heightmap 4782edac   spawn (-44, -124)   53 lakes   15218 trees   config 1d7c18c7
```

Unchanged, both builder legs.

### The store, measured

From the horizon self-test, seed 42:

```
tile store:   4 cell probes worst 0.000000
              10 km reads 210.5 blocks, 20 km reads 104.1 - not the rim any more
              1000 samples in a 40 km disc, all finite and in [min_altitude, max_altitude]
              1020 tiles / 129.5 MB built in 10,354 ms
tile threads: 16,641 cells, 0 differing, one tile built by four workers at once
```

**`height_at` outside the region equals `height_at_block` to zero error** at
every cell-aligned probe out to 40 km. That is stronger than "close": a level-0
tile is one sample per cell on a grid anchored to the origin at multiples of
`step`, and `min_block` is `-world_blocks_xz / 2`, itself a multiple of `step`
- so the tile grid is the region grid continued and the bilinear is continuous
across the rim with nothing to hide.

10 ms and 133 KB per level-0 tile, which is the same cost the region's own
tiles have had since distance v5 - the store is the same builder pointed
somewhere else.

### Level 0 is never supersampled, and that is a ruling

The plan says a level-L cell is the mean of a `far_supersample` square of
`raw_height`. Applied to level 0 that would make the ground OUTSIDE the region
a filtered version of the ground INSIDE it, and the two meet at the rim: a step
of however much a 2 m box filter removes, which on a steep flank is about a
metre of cliff running round the whole home region.

Level 0 is the surface the voxels are built from and it has to be one function
everywhere. So it is one sample per cell - which is the plan's own
"supersample = 1 is bit-identical to today", read as the rule for level 0
rather than as an aside - and supersampling, which is a FILTER, belongs to the
levels that are filters. `far_supersample` therefore applies from level 1 up.
Recorded under "Questions taken alone".

### Far parity caught a real divergence, and it is worth writing down

The first Stage 1 run of the main suite came back:

```
ring_div 4   gd 391656 verts / cpp 391640, VERTEX COUNTS DIFFER
far zone parity: 10000 samples x 3 functions, 1 FUNCTIONS DIFFER
far slice parity: ... 3458 unmatched ... FAILED
```

**The far mesh has two legs and only one of them can build a tile.** The
GDScript leg reads this store live; the C++ leg is handed a map of tiles once
per build and has no generator. Pointing `FarFieldJob` at doors that never
build was not enough, because it reaches the height map through the generator
as well: `detail_at` samples `slope_deg_at` and `height_at` for the shore fade,
and `_slope_zone` samples `slope_deg_at`. Those went through the BUILDING door,
so on a quad near the rim the GDScript leg conjured a tile and read real ground
while C++ read the rim - four quads' worth at `far_ring_div` 4, and the parity
gate found every one of them.

So the `far` flag is threaded all the way down - `detail_at`, `_slope_zone`,
`surface_zone_at`, `slope_deg_at` - defaulted false so nothing that was here
before changes, and passed true by the far mesh at its three call sites. It
mirrors the port exactly: `far_world.h` has ONE height door and everything in
it reads that one.

This is failure protocol item 3 in its intended form, and the gate did its job
on the first run.

### The rim is prepared at load, and two more things the gate found

Fixing the `far` flag was not enough and the gate said so twice more.

**The pyramid's near door was building tiles.** `height_filtered`,
`height_max_filtered`, `height_at_level` and `height_max_at_level` have exactly
one caller between them outside `heightmap.gd` - `selftest.gd`'s parity harness
- because the pyramid exists FOR the far mesh. A "near" door onto it was a door
nothing walks through that could still disagree with C++, so above level 0 the
near door reads the frozen view too and the two are now the same function.
Level 0 keeps its building door: the voxel world reads it and the ground has to
follow the player.

**The region's rim is built at load.** A quad at the region's edge samples up
to `RIDGE_SPAN_BLOCKS` past it, so both legs need real ground there.
`Heightmap.ensure_region_rim()` builds the forty-four level-0 tiles that
straddle the rim and publishes them, once, in `build_heightmap`. Level 0 only:
above it both legs fall back to the same clamped pyramid whether or not a tile
exists, so preparing levels 1 to 5 would cost two seconds a world load to
change nothing. Measured cost at seed 42: 44 tiles, under half a second on a
25-second load.

**And the marshal was sending nothing at setup.** `FarMesher.setup`'s first
parameter is named `heightmap` and shadows the member of the same name; the
member is not assigned until `far_field.gd` submits a build. So `_new_tiles()`
reached for the member, found null, and returned an empty Array - the C++ leg
started every world with an empty tile map while the GDScript leg read the rim
tiles it had just built. The gate reported it as 391,840 vertices against
391,640. `_new_tiles` now takes the heightmap explicitly.

After all three: **far pyramid parity max diff 0.00000000000000000 over 10,000
samples x 5 functions**, far zone parity all identical, far parity, far slice
parity, far layer parity and far dispatch green, and the suite passes.

### And eviction was throwing the rim away

The first pinned-less run reported `height tiles: 0 held, 44 built` at spawn:
`World._evict_height_tiles` drops level-0 tiles more than about a thousand
blocks from the player, the rim is three kilometres from spawn, and the forty
four tiles built at load were gone by the player's first chunk crossing. Not
wrong - both legs still read the published view and still agreed - but the half
second spent building them bought one frame of correct edge.

The rim is pinned. Forty-four tiles, 5.6 MB, fixed for the life of a world, and
the far probe now reports `44 held` at spawn. Stage 3 takes the pin over as the
ring table starts deciding what the far mesh reads.

### The far view is published, not read live

A tile can appear WHILE a far build runs - every chunk column job outside the
region builds one - so a store read live by the GDScript leg and marshalled
once to the C++ leg would disagree on a race that reproduces about once a
night. `FarField` calls `Heightmap.publish_far_view()` on the main thread
immediately before submitting, the far doors read that frozen copy, and the
marshal reads the same copy. Shallow: a `PackedFloat32Array` is copy-on-write
and nothing writes into a published tile, so the copy is a few dozen
references.

### Checks

| check | result |
| --- | --- |
| canonical line | **unchanged**, both legs |
| `height tile parity` | **unchanged** - 10,000 samples, 0 differing, one 64x64 tile 0 cells differing |
| far parity / far zone / far slice / far layer / far dispatch | **green** after the fix above |
| `height_at(10 km)` equals `build_tile` for that cell, and is not the rim | **PASS**, worst error 0.000000 |
| 1,000 positions in a 40 km disc finite and in range | **PASS** |
| the same call twice is the same float | **PASS** |
| a tile from a worker and from the main thread are byte-identical | **PASS**, 16,641 cells, 0 differing |
| memory: the tile store under 300 MB | **129.5 MB** for a thousand tiles scattered over a 40 km disc, which is a stress case and not a play case; `--tp 20000 0` holds one tile, because `world.gd` still refuses columns outside the region. **The real memory reading is Stage 2's**, where the voxel world follows the player. |
| far probe, twice, identical | **PASS** at spawn (`44 held, 5.6 MB, 44 built in 446 ms`) and at `--tp 20000 0` (`16 held, 2.0 MB, 60 built`, ground read 155.1 m rather than the rim's 326.3 m) |
| sprint probe, Ultra, quiet box | h1-1 **40.65** ms median, h1-2 **41.67** - against the Stage 0 baseline's 41.67 / 41.76 / 39.17. **The tile store costs nothing on the frame**, and `moved_m` is 543 m in both, to the metre, as in every run of this walk. `tiles=44 tile_mb=6` - only the pinned rim, because the voxel world is still bounded until Stage 2 |

### The tour cannot be compared numerically between two runs, and it never could

Stage 1 was expected to change one thing in a picture - the ground just past
the region's rim - and the first pixel diff of `horizon-0` against `horizon-1`
came back with **every one of the twenty-seven shots changed on 50 to 60% of
its pixels**. That is not what this stage did, and the cause is worth writing
down once for the rest of the lane:

1. **The film grain is re-seeded from `TIME` every frame.** `ui/lens.gd` says
   so in as many words - "a grain that does not move is a dirty lens, not film"
   - at `grain_amount` 0.035, which is +/- 9 of 255 in display space. So no two
   tour runs can produce identical pixels anywhere in the frame, by design.
   Measured on `17-rim`, a shot with no foliage and no water: max |dL| **9**,
   mean L 96.26 against 96.25 - the same picture with a different noise
   realisation.
2. **The wind phase is `TIME` too.** `Look.TREE_SWAY` is
   `TIME * 0.6 + tree_at.x * 0.11 + ...`, so two runs photograph the forest at
   different points in the wind cycle. Every shot with crowns in it - the two
   forest interiors, the canopy, the treeline, the summit - differs by whole
   crowns.
3. **The water and the sky are temporally accumulated.** SSR and the volumetric
   froxels carry history, so `10-shore` moves too.

So a per-pixel diff between two tour runs measures the grain, the wind and the
reprojection, and nothing else. **`tools/compare_sheets.py`'s strips stay the
instrument for the eye, and the numeric instrument is the plan's own: a 9 x 9
window mean, on a named region, chosen on ground that does not sway.** A 9 x 9
mean averages the grain from +/- 9 down to about +/- 1.

Re-measured that way, `horizon-0` against `horizon-1`:

| shot | mean | worst window | reading |
| --- | --- | --- | --- |
| `17-rim`, `6-postcard`, `1-spawn`, the five hour shots | 0.29 - 0.41 | 1.2 - 7.6 | **unchanged** - grain residue |
| `32-horizon-walk`, `3-forest-slope`, `25-lens-fence` | 0.50 - 0.67 | 9 - 13 | unchanged; a crown or two moved |
| `30-horizon-peak` | 0.64 | 65 | four windows, all foliage: the worst goes H 47 S 5 V 33 to H 25 S 30 V 8, which is a trunk swaying into it, and the next goes V 41 to V 52, a crown swaying out |
| `31-horizon-far` | 4.18 | 79 | **expected**: the camera stands on ground at 155 m instead of the rim's 326 m, so the framing moved |
| the foliage and water shots | 2.1 - 8.7 | 71 - 125 | wind and SSR - see the control below |

**The control, and what it says.** Two runs of the SAME code, one shot each
(`--only 7-forest-interior`): mean |dL| **2.84**, worst 9 x 9 window **27.35**.
`horizon-1` against that same control, also the same code: **2.65**. So the
noise floor between two runs is already a mean of about 2.7 and a worst window
of 27 - a crown swaying through it.

`horizon-0` against `horizon-1` on that shot is 10.97, which is higher, and the
reason is that the control UNDER-SAMPLES the noise rather than that the picture
changed. The wind's period is `2 pi / 0.6`, about ten and a half seconds. A
one-shot tour reaches its shutter at nearly the same `TIME` every run, so the
two control frames were photographed at nearly the same wind phase; in a full
tour `7-forest-interior` is the fifteenth vantage and its shutter is minutes
in, so its phase is effectively uniform random between runs. A better control
would be two FULL tours, which is eighty minutes of this box.

It is not needed, because the question is answered by arithmetic rather than by
pixels: **`far pyramid parity` is 0.00000000000000000 over 10,000 samples x
five functions, `far zone parity` is all identical, `height tile parity` is 0
differing, and the canonical world line has not moved.** Every read inside the
home region is bit-identical to `main`, so a forest interior inside the region
cannot have changed. The shots that CAN change are the two this table already
names, and only one of those is really this stage. `30-horizon-peak`'s four
changed windows were read individually and every one of them is a crown or a
trunk moving through it, and `7-forest-interior` was looked at side by side:
**the same trunks, the same ground, the same snow patches, the crowns in
different positions.** That is the wind and nothing else.

### The eye check: `31-horizon-far`

This is what Stage 1 looks like.

| | |
| --- | --- |
| **Stage 0** | Twenty kilometres out: an empty grey void. `0.01 M primitives in frame, 0 chunks`. The heightmap clamped at the region's rim, so there was nothing to stand on and nothing to draw. |
| **Stage 1** | A forest, standing on ground, at twenty kilometres. |

The impostor ring is the first system in the game to ask the store for ground
outside the home region, and it got some: `TreeFieldJob` places from
`heightmap.height_at`, which now answers everywhere, so the trees appeared the
moment the edge went.

**They are standing on nothing.** There is no voxel terrain under them - that
is Stage 2 - and no far mesh behind them - that is Stage 3. A forest floating
at 20 km is the honest intermediate state of a lane that removes the world's
edge one layer at a time, and it is the clearest picture of what Stage 1 did.

**And there is a way to make the tour comparable exactly.** With the two `TIME`
terms removed - `--lens off --set tree_sway=0` - two runs of the same code
produce **mean |dL| 0.0237 over 3,484 pixels of 921,600**, which is a rounding
difference in the froxels and nothing else. The tour harness is deterministic;
the noise was the grain and the wind, both of which are `TIME` by design.

Recorded for the rest of the lane:

- **A per-pixel tour diff between two ordinary runs is not an instrument in
  this build.** The floor is a mean |dL| of about 2.7 and rises with how far
  into the tour a shot sits, because the wind phase drifts.
- **A 9 x 9 window is an instrument only where the window sits on ground that
  does not sway** - rock, snow, meadow, water's far shore.
- **`--lens off --set tree_sway=0` makes a pixel diff exact**, and that is how
  a stage from here on proves it changed only what it meant to.

### Tunables moved

None.

---

## Stage 2 - voxels anywhere

**Green.** The playable world follows the player. There is no position in this
world you cannot stand on.

### What shipped, and it is four lines of deletion

| | what |
| --- | --- |
| `scripts/world/world.gd` `refresh_region` | The world-edge cull is gone: `if cx < lo or cx > hi ... continue # outside the bounded world`. That was the last place the VOXEL world knew it had an edge. The disc is the disc, wherever the centre is. |
| `scripts/world/world.gd` `_sim_ring_columns` | The same cull, for the peers' collision rings. A friend outside the home region is a friend who needs ground under them. |
| `scripts/world/world.gd` `_update_fog_floor` | The scan was clipped to `cells` with `maxi(.., 0)` and `mini(.., cols - 1)`, so outside the region the window collapsed to nothing and the fog floor kept the altitude of a valley the player had left three kilometres ago. Unclipped, and reading `height_at` instead of `cell_height` - the same number at a cell centre inside the region, real ground outside it. The LAKE branch keeps its index guard, because there are no lakes to find. |
| `scripts/world/world.gd` `_world_chunk_min` / `_world_chunk_max` | Kept and no longer culling. "Is this column inside the 3 km the lakes and the spawn were computed over" is still a question worth being able to ask; the world-truth break will ask it. |

Nothing else needed changing, and that is worth saying: `surface_at`,
`detail_at`, `surface_zone_at`, `column_surface_range`, `is_solid_at` and
`generate_into` all read `heightmap.height_at`, which stopped clamping in
Stage 1, so the generator was already unbounded the moment the store landed.
`_cell_index` returns -1 outside the region and every caller of it - the shore
fade in `detail_at`, the shore rules in `flora_placement` and `tree_placement`
- already treats that as "no shore here", which is correct: there are no lakes
out there. **`column_job.gd`, `chunk_node.gd` and `chunk_mesher.gd` were
checked by grep and carry no world-edge assumption at all**, so there is
nothing to request from the mesher lane.

### Checks

| check | result |
| --- | --- |
| canonical line | **unchanged** - heightmap `4782edac`, spawn `(-44, -124)`, 53 lakes, 15,218 trees, config `1d7c18c7` |
| main self-test | **SELFTEST: all passed** |
| horizon self-test | **all passed** |
| `--tp 5000 5000`, 30 s sprint | ground **108.7 m**; 1,749 chunks; 202 m moved; 77 tiles / 10 MB; median 13.79 ms; no `NO SPAWN`; exit 0 |
| `--tp -12000 3000`, 30 s sprint | ground **281.2 m**; 1,297 chunks; **387 m moved, 0 jumps**; 71 tiles / 9 MB; median 12.12 ms; exit 0 |
| `--tp 20000 0`, 60 s sprint | ground **155.1 m**; 2,153 chunks; **774 m moved, 0 jumps** - a full, unobstructed sprint twenty kilometres from the origin, on ground that did not exist this morning; 73 tiles / 9 MB; median 15.28 ms |
| memory at 20 km | **9 MB of tiles**, 279 MB static. Failure protocol item 12 is a long way off. |
| the sprint that crosses the old edge | `--tp 1000 2675`, 60 s, **778 m moved, 0 jumps**, crossing `x = 1500 m` - the region's rim - at about `s=39`. The per-second medians either side: 12.96, 18.33, 16.02, **16.01**, 15.28, 15.15, against the run's own 15.96, and the crossing second's worst frame is 31.41 ms against a run that is between 30 and 55 ms all the way through. **No spike attributable to the crossing.** The line was chosen by scanning the heightmap for a `z` where the ground from `x = 1000` to `1800 m` has no step over 0.06 m - two earlier attempts wedged on cliffs at 62 m, which the probe's `moved_m` said out loud. 218 tiles / 28 MB by the end. |

The three teleports are the stage: before tonight `--tp 20000 0` built **no
chunks at all** - `refresh_region` culled every column outside the region - and
the player stood frozen forever because the ground it was waiting for could
never arrive.

*(The crossing run was taken after Stage 3's ring table and 32 km presets had
already landed in the working tree, so its frame numbers are the 32 km build's
and not Stage 2's. It answers the question it was asked - is there a spike at
the rim - and is the stronger test for having been taken at the longer reach.)*

---

## Questions taken alone

Failure protocol item 7: the conservative reading, written down.

1. **The plan's canonical config hash `c18af99d` is stale.** Taken as
   `1d7c18c7`, measured on the untouched tree today. See "The canonical world
   line" above for the full reasoning. The conservative reading is that the
   invariant is "it does not move from what `main` produces", which is what
   every gate in this document checks.
2. **The commit trailers.** The plan (grill Q23) names
   `Co-Authored-By: Claude Fable 5.1` and Fable's session URL, because Fable
   wrote the plan. The commits in this branch are made by a different agent in
   a different session, and a trailer that names the wrong one is a false
   record of who did the work. Taken as: the same two trailer KEYS, carrying
   this session's own author and URL. The shape Q23 asks for is kept; the
   values are true.
3. **The sprint probe jumps when it is stuck, and the plan says wish and the
   sprint bit only.** Taken as: press Space when the body has not moved half a
   metre in half a second, through the traversal probe's existing
   `jump_override` hook. Reason and evidence under Stage 0 - without it both
   Ultra baselines wedged at 354 m and spent the last seventeen seconds of the
   sample measuring a standing player, which halved the median the 60 FPS gate
   is read off. It does not steer, fly or teleport; a real wall still wedges
   it and the summary still says so. Conservative in the sense that matters:
   the alternative was to report a frame number that flattered the build.
4. **The plan's Stage 0 determinism check cannot be met as written.** "`chunks`,
   `far_rebuilds` and `tree_rebuilds` agree exactly" is asking the frame time
   to be identical, because all three are counts of what happened in however
   many frames the run got. Taken as: **`moved_m` identical, `jumps` within
   one, `tree_rebuilds` identical, `median_ms` within 10%**, with `chunks` and
   `far_rebuilds` reported as the load the frame was carrying. Measured
   evidence under Stage 0.
5. **The far probe now runs the C++ mesher by default.** At `far_ring_div` 4 a
   GDScript run is over ninety minutes and Stage 3 would make it a day; the
   game draws the C++ mesh (`far_cpp` defaults to 1) and the two legs are
   asserted identical three ways in `selftest.gd`. `--gdscript` forces the
   reference leg.
6. **Level 0 tiles are never supersampled.** The plan applies
   `far_supersample` at every level; taken as level 1 and up only, because at
   level 0 it would put a metre-high filter step around the whole home region
   where the tile store meets the array. Reasoning and measurement under
   Stage 1.
7. **`far_supersample` is applied by calling `build_tile` s-squared times at
   sub-cell offsets, not by adding a `supersample` argument to
   `KubikHeightTiles`.** Same samples, same means, same quantisation, and
   `gdext/src/height_tiles.{h,cpp}` is untouched - which is the smaller change
   and keeps the one class in this seam that decides WORLD TRUTH out of this
   lane's diff. The offsets are `cstep * (2k + 1) / 2s`, whole blocks at every
   level the store uses.
8. **The far mesh reads a frozen view of the tile store and never builds.**
   The plan does not say what a far-mesh read does on a missing tile; taken as
   "the region's clamped rim", because the C++ leg cannot build one and the two
   legs must agree. `FarField` publishes the view before each build. See
   Stage 1.
9. **ENet's default port is taken by the other lane.** `24565` is held by the
   mesher lane's tour for as long as it runs, so every hosted run in this lane
   passes `--port 24566`. Nothing in the plan's command lines changes meaning;
   the flag is recorded here so a reader reproducing a number uses the same
   one. No file the other lane owns was touched to get this.
4. **Grill Q21 contradicts itself on the presets' reach.** "All presets see
   R = 32 km; they differ in the near" is followed immediately by "Low: ...
   R 8 km. Medium: ... 16 km." Taken as the explicit per-preset table, which is
   the more specific of the two and the only one that can be implemented.
   Ultra is 32 km either way, and Ultra is what every gate in this plan is
   measured at, so no gate depends on the reading. Lands in Stage 3.

---

## For Marcel

1. **The sprint line on `main` is 41.67 ms at Ultra - 24 FPS, not 60.** First
   time it has been measured. Stage 7 is where it is answered; Stage 3 is the
   change most likely to answer it.
2. **The far probe has been dead since light v1 merged** - it crashed on its
   own header print and then hung rather than exiting. Fixed. No far-probe
   table exists anywhere between light v1 and tonight.
3. **The far probe could never see rings 0 and 1**, so no seam number and no
   150 m or 300 m boundary number from the distance v5 era can be trusted.
   Fixed.
4. The plan's canonical line quotes a pre-light-v1 config hash. The world
   itself is untouched; see the section above. Nothing to do unless you want
   the plan's copy corrected.
5. The plan's Stage 0 determinism check and the sprint probe's jump are both
   deviations, both recorded above with their measurements.

---

## For the world-truth break

The silences - things this lane deliberately leaves wrong outside the home
region, for D44/D45's lane to fix. Each is a thing the plan names and this lane
does NOT change, because changing it would change what a seed produces.

1. **`wildness_at` and `danger_at` still measure from the middle of the home
   region and clamp at its half-width.** So everything past 3 km is at
   wildness 1.0: the mountain layer's `wildness_relief` boost is at maximum,
   `rock_slope_deg - wildness_rock_deg` is at its lowest, and `danger_at`
   reads 1.0 everywhere. D44 measures both from the Engineers' capital in
   rings; that is the world-truth break's to write, and it changes what a seed
   produces, which is exactly what this lane may not do.
   `scripts/world/terrain_generator.gd`, `wildness_at`.
2. **`_resolve_zone_thresholds` is a histogram of the home region's
   altitudes.** The seven zone shares are percentiles of 2.25 M cells inside
   3 km, and every column in the world - at 3 km or at 30 - is coloured against
   those six thresholds. Outside the region the shares are therefore whatever
   the terrain out there happens to give, not the authored ones.
   `scripts/world/terrain_generator.gd`, `_resolve_zone_thresholds`.
3. **Lakes and the spawn are the home region's, and only its.** `Lakes.compute`
   floods `heightmap.cells`; `find_spawn` scans it. So there is no water
   outside 3 km at all - not a dry basin, no water - and `detail_at`'s shore
   fade and the flora placement's shore rules are inert there because
   `_cell_index` returns -1. `scripts/world/lakes.gd`,
   `scripts/world/terrain_generator.gd` `find_spawn`, and the `_cell_index`
   guard.
4. **`_update_fog_floor`'s lake branch keeps its region index guard**, for the
   same reason: there are no lakes to find. Its LOWEST-GROUND branch was
   unclipped in Stage 2 and follows the player anywhere.
5. **The far mesh reads the region's PYRAMID above level 0 wherever the region
   answers, and level-L tiles outside it.** The two are box means of the same
   terrain anchored half a cell apart, and `min_block` is not a multiple of
   `4 << L` above L = 1, so they cannot be made to line up without moving the
   pyramid. The seam is look-only and only at the rim; the world-truth break
   replaces the pyramid with tiles everywhere and it goes.
6. **The zone shares, the lakes, the spawn and the thresholds are all
   recomputed from `world_blocks_xz`**, so the home region is still a
   configured size. D44's ringed content replaces the whole idea; until then
   it is bookkeeping, and no system culls against it any more.

---

## For the merge

One-line requests into files the mesher lane owns. Nothing here is done by
this lane.

*(none yet)*

---

## For the bible

*(none yet)*
