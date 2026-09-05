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

**Where it stands after Stage 3: 21.85 ms** - four warm runs on a quiet box,
21.68 to 22.22, spread 2.5%, with the view at 32 km instead of 3.2. Half the
frame for ten times the country, and still 5.1 ms over the gate. Full numbers
under Stage 3.

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

## Stage 3 - thirty-two kilometres, in persistent pieces

**Green.** The view reaches the horizon, and it costs less than the 3.2 km view
did this morning.

### What shipped

| | what |
| --- | --- |
| `far_field_job.gd`, `far_build.cpp` | `RING_OUTER_M` gains 4,800, 9,600, 19,200 and 38,400 m; `RING_STEP_MULTIPLE` gains 64, 128, 256, 512. Ten rings. |
| `heightmap.gd`, `far_world.h` | `MAX_LEVEL` is the PYRAMID's 5; `TILE_MAX_LEVEL` is the tile store's 9. `far_max_level(bx, bz)` answers which source a position has and every level clamp on the far path goes through it. |
| `far_field_job.gd`, `far_build.cpp` | **The far mesh's world edge is gone.** `if not heightmap.in_bounds(bx0, bz0): continue` had stood since terrain v1 and was the reason four more rings would still have drawn nothing past 3 km. |
| `worldgen_config.gd` | The presets are the reach: Low 8 km, Medium 16, High and Ultra **32**. `far_reach_m` and `fog_end_m` are kept equal by `apply_view_preset`. Camera far plane **40,000 m**, printed at load. |
| `far_field_job.gd`, `far_build.cpp` | `keys`: a build is a set of (ring, sector) pairs. One sink per key, vertices relative to the ring's anchor, `key_anchors` out beside the slices. Empty keys is the whole disc, exactly as before, which is what the probe and the parity harness build. |
| `far_field.gd` | 160 `MeshInstance3D` children keyed (ring, sector), each at its ring's anchor, each replaced on its own out of the upload budget. `_rings_due()` decides the set: rings 0-2 follow the frontier, ring r >= 3 re-centres on `far_ring_recenter_frac` of its inner radius. `_prepare_tiles` builds what the build will read - on the worker, ahead of the mesh. |
| `far_probe.gd` | `--ring-table`. And the flat quad-lookup grid is gone. |
| `screenshot_tour.gd` | `31-horizon-far` lifts its camera 250 m off the ground it lands on. The vantage stood against a cliff; see question 13. |

### The ring table, Ultra, seed 42, at the spawn

```
far_ring_div 2, base step 4 blocks (2.0 m), reach 32,000 m
ring   cell            covers          vertices    ms
0      2.0 m        0 ->    150 m       175,416    48
1      4.0 m      150 ->    300 m       192,624    25
2      8.0 m      300 ->    600 m       238,604    29
3     16.0 m      600 ->  1,200 m       253,988    32
4     32.0 m    1,200 ->  2,400 m       221,092    44
5     64.0 m    2,400 ->  4,800 m       189,576    44
6    128.0 m    4,800 ->  9,600 m       176,356    43
7    256.0 m    9,600 -> 19,200 m       168,748    43
8    512.0 m   19,200 -> 38,400 m       165,732    34
9   1024.0 m       reserve, unused            0     0
TOTAL                                 1,782,136        UNDER the 2.0 M budget
```

**Every ring costs about the same** - 165k to 254k vertices - which is the
design claim of the whole ladder made visible: ring area grows 4x and cell area
grows 4x with it. The four rings that take the view from 4.8 km to 38.4 are
**711,000 vertices between them**, which is a fifth of what the 3.2 km far
country cost this morning.

### `far_ring_div` goes from 4 to 2, and it revisits a decision of Marcel's

Measured at Ultra with `--far-probe --ring-table`:

| | vertices | ring 0's cell |
| --- | --- | --- |
| `far_ring_div` 4 | **6,511,760** | 1 m |
| `far_ring_div` 2 | **1,782,136** | 2 m |

The budget is 2.0 M and only one of these is under it. The plan's own ring
table reads "ring 0 | 2 m ... ring 9 | 1,024 m", which is `far_ring_div` 2
exactly - so the table and the budget agree with each other and disagree with
the plan's parenthetical "(cell = step at `far_ring_div` 4)". Taken as the
table and the budget: two specific, load-bearing statements against one aside.

Marcel's 2026-09-01 ruling put the divisor at 4 because he wanted the cells
smaller. What this spends the halving on is the horizon: the same vertex count,
ten times further out. It is one spinbox on F4 and on `FAR_ONLY_PROPERTIES`, so
he can put it back to 4 standing still and see both; Stage 7 reports the frame
at each. **For Marcel.**

### What the partial rebuild bought

The far country stopped being one disc. Measured at Ultra, 32 km, seed 42:

| | whole disc | per (ring, sector) |
| --- | --- | --- |
| vertices | 1,795,048 | the same - the union is the disc |
| build, worker | 407 ms | **121 ms** for a typical rebuild |
| wall per rebuild | **1,477 ms** | **134 ms** |

Eleven times cheaper, because a rebuild is the rings that moved and not the
thirty-eight kilometres that did not. The Stage 0 baseline's complaint -
seventeen to nineteen rebuilds in a sixty-second sprint at 530 ms each, most of
them superseded before their upload finished - is answered.

### The sprint, and what `far_rebuilds` counts now

Six 60-second sprints at Ultra, 32 km, seed 42, on a quiet box:

| run | median | p99 | worst | over 25 ms | chunks | `far_rebuilds` | `far_ms_median` |
| --- | --- | --- | --- | --- | --- | --- | --- |
| h3q-1 (contended) | 30.00 | 107.15 | 145.89 | 1,214 | 4,989 | 17 | 114 |
| h3q-2 (cold) | 23.33 | 80.56 | 149.74 | 818 | 5,692 | 33 | 110 |
| h3q-3 | **21.88** | 55.24 | 112.62 | 651 | 6,465 | 51 | 114 |
| h3q-4 | **21.82** | 54.80 | 102.66 | 639 | 6,187 | 52 | 115 |
| h3q-5 | **21.68** | 56.67 | 115.82 | 671 | 6,414 | 59 | 120 |
| h3q-6 | **22.22** | 57.98 | 108.23 | 673 | 6,266 | 55 | 117 |

The four warm runs on a quiet box are **21.68 to 22.22 ms, a spread of 2.5%**,
and the median of their medians is **21.85 ms**. h3q-1 shared the box with a
far probe for its first forty seconds and h3q-2 was the first run after a cold
page cache; both are kept in the table and out of the number, and the shape of
the difference - fewer chunks loaded, a higher median - is the same shape in
both.

**Against the morning's baseline: 41.67 ms -> 21.85 ms, while the view went
from 3.2 km to 32.** The gate is 16.7 and this is Stage 7's work, not Stage
3's; what Stage 3 is entitled to say is that ten times the view now costs a
little over half the frame it used to.

**`far_rebuilds` fails its Stage 3 number and the number no longer means what
it meant.** The plan asks for `far_rebuilds <= 12` in 60 s and
`far_ms_median <= 300`. Measured: 51 to 59, and 110 to 120 ms.

- `_rebuilds` counts **uploads that reached the screen**, and after this stage
  an upload is a handful of the 160 keyed meshes, not the whole disc. The
  baseline's 17 to 19 were 530 ms each and each one replaced 38 km of country;
  tonight's 55 are 115 ms each and each one replaces the rings that moved.
  Total worker time over the sprint went from about 9.5 s to about 6.3 s while
  the reach grew tenfold.
- The count went UP for the reason the design intended: rings 0 to 2 follow
  every frontier move, and a warm run loads 6,400 chunks in 60 s where a cold
  one loads 5,000. **The count now tracks how fast the near field streams, not
  how expensive the far field is.**
- `far_ring_recenter_frac` is the tunable in range and it moves rings 3 and
  out only. Measured at 0.5, twice the plan's value: **49 rebuilds against 51 to 59**, median 112 ms, frame
  20.83 ms - about a tenth off the count, which is the size of the share
  rings 3 and out have of it. No value of this knob reaches 12, because
  rings 0 to 2 are frontier-driven by design (plan § 3.2) and the
  frontier moved 543 m.
- **Taken as: the cost gate is met with a 2.5x margin, the count gate is
  measuring a different quantity than it was written for, and the honest
  replacement is worker milliseconds per second of play.** Recorded under
  "Questions taken alone"; the plan's number is not silently redefined here.

**And no hitch in the sprint is attributable to a far upload.** The probe tags
each second with the far uploads it applied. Over h3q-3's sixty seconds, the
median worst frame in a second that applied a far upload is **48.61 ms**; in a
second that applied none it is **52.16 ms** - the seconds with far work in them
are, if anything, the calmer ones. h3q-2 says the same, 51.97 against 75.00.
Every second of every run has a worst frame over 25 ms; all of them belong to
chunk and tree uploads, which is Stage 7's list and not this stage's.

### Checks

| check | result |
| --- | --- |
| **far key parity** (new, horizon self-test) | **132,400 vertices over 160 keys, 0 bad.** The union of the 160 keyed meshes is the disc, vertex for vertex, in world space with each key's anchor added back - and the GDScript keyed build and the C++ keyed build agree with each other. |
| vertex sum at Ultra | **1,782,136**, under the plan's 2.0 M |
| camera far plane | **40,000 m** - `[Game] view distance ultra: voxel radius 16 chunks (128 m), fog 32000 m, camera far 40000 m` |
| main self-test | **SELFTEST: all passed** - after four fixes, all of them cross-leg and all of them found by the gate |
| horizon self-test | **all passed**, six tests |
| character self-test | **36 tests, all passed** |
| canonical line | **unchanged** - heightmap `4782edac`, spawn `(-44, -124)`, 53 lakes, 15,218 trees, config `1d7c18c7` |
| far probe, twice | **identical.** Two whole runs on a quiet box, each of which internally re-measures itself twice: `tables IDENTICAL` inside each, and the seventy-eight geometry rows of one diff clean against the other. FIZZ, ROUGHNESS, PEAK LOSS and the terrace table for rings 0 to 8, character for character. Both `PASS`. |
| far probe, handover | **fails at 0/1, 2/3, and 3/4 outward.** Recorded in full below with the baseline's own failures beside it; `far_supersample` 4 measured as the plan's remedy. |
| sprint, far cost | `far_ms_median` **110-120 ms**, gate 300. `far_rebuilds` **51-59**, gate 12 - the count now measures near-field streaming; see below and question 12. |
| sprint, far hitches | **none attributable.** The seconds that applied a far upload have a LOWER median worst frame than the seconds that did not (48.61 against 52.16 in h3q-3). |

### The eye check, and grill Q24 was right

`30-horizon-peak`, Stage 1 against Stage 3, from the home region's highest
summit with the camera level and looking `+X`:

| | |
| --- | --- |
| **Stage 1** | The summit, and then grey void. The far mesh culled every quad past the region however far the rings reached. |
| **Stage 3** | **Terrain to the horizon.** A massif fills the left of the frame where there was nothing, with a cube silhouette and a lit wedge in the middle of it. |

**And it is very dark.** Measured, 9 x 9 windows: the far mass reads V 12 at
`(200, 480)`, V 18 at `(400, 420)`, V 22 at `(600, 400)`, against the near
snow's V 69 at `(900, 600)` and the sky's V 51. The hue is the same family
throughout - H 29 to 34 - so this is not a wrong colour table; it is a lit
surface that is barely lit.

Grill Q24 says what to do with that in as many words: *"Stage 3 may [look worse
than before], before Stage 4 gives it colour and Stage 5 gives it air. For any
other stage: check the sampled windows first; if they pass and the eye check
fails, record the sentence and do not revert."* **The sentence: the far country
now reaches the horizon and arrives there almost black.** Stage 4 replaces the
colour path with one material source at every level and Stage 5 puts the air in
front of it; the reading is repeated after both.

### The eye check: `31-horizon-far`, and the vantage had to be lifted

The plan's second Stage 3 eye check is "the home region is visible from 20 km
as a range". At eye level it was not, and the reason was not the far mesh:
outside the home region `wildness_at` clamps to 1.0 until the world-truth
break, so the relief out there is at maximum, and the camera landed against a
200 m wall that filled two thirds of the frame. The vantage now lifts 250 m
(question 13).

**And the answer is yes.** From 20 km the frame is a meadow floor, snow-capped
red-rock ranges left and right, a dark massif in the middle distance, and
terrain that recedes into fog without an edge. Measured, 9 x 9 windows:

| window | H | S | V |
| --- | --- | --- | --- |
| near meadow `(640, 660)` | 69.2 | 38.8 | 42.6 |
| near snow `(150, 420)` | 31.3 | 11.9 | 58.4 |
| mid massif `(600, 470)` | 68.6 | 32.0 | 42.9 |
| far band `(760, 380)` | 47.9 | 2.7 | 39.4 |
| horizon `(900, 360)` | 76.9 | 1.4 | 39.6 |
| sky `(640, 150)` | 128.2 | 0.5 | 42.4 |

**The horizon band and the sky above it are 2.8 V apart** with the fog as it
stands and no ramp yet - which is the number Stage 5's gate wants to be under
3, taken here as a RECORD and re-taken there. Saturation falls from 38.8 in
the near meadow to 1.4 at the horizon, monotonically: the far country loses
colour with distance rather than ending.

**RECORD, for Stage 4 and 5 to answer:** thin horizontal light streaks are
visible in the middle distance on the right of the frame, at about y 370 to
460 - ring skirts seen edge-on from a high vantage. They are not a hole and
not a crack; nothing sky-coloured shows through. Named here so the same band
is looked at again once the colour path is one source.

### The handover, ring by ring, and what it says

The plan's gate: across a 200 m arc centred on each boundary, at 1 m spacing,
the inner and the outer side differ by RMS <= 0.5 x the inner cell's height
step and max <= 1.0 x. `!` marks a fail. From the spawn, Ultra, seed 42:

```
seam  rms  0.46 max   2.19 / 4
0/1   rms  1.87 max   9.66 / 4    max!
1/2   rms  1.88 max   7.26 / 8
2/3   rms  7.16 max  23.03 / 16   max!
3/4   rms 17.44 max  69.36 / 32   both!
4/5   rms 47.91 max 390.64 / 64   both!
5/6   rms 147.90 max 494.78 / 128 both!
6/7   rms 344.02 max 757.64 / 256 both!
7/8   rms 216.08 max 436.87 / 512 rms passes, max passes
```

*(The spawn vantage. Its rows are unchanged by Stage 4's fix to the probe's
mesher - see "Everything that blew up was one uninitialised member" - and the
summit vantage's, which that fix moved a long way, are reported there.)*

**Three readings, and only the third is new.**

1. **The near boundaries are what they were on `main`.** The Stage 0 baseline
   failed 0/1, 2/3 and 3/4 too, on the same arcs with half the cell size
   (`0/1 rms 0.81 max 4.18/2!`, `2/3 rms 2.76 max 10.42/8!`,
   `3/4 rms 5.97 max 19.35/16!`). Handover has never passed this gate in this
   repo; horizon v1 did not break it.
2. **The RMS grows about 2x per ring while the gate grows 2x too**, so the
   ratio is roughly flat from 3/4 outward: 1.1x, 1.5x, 2.3x, 2.7x over the
   gate. It is not a cliff at any one ring; it is one systematic thing seen at
   eight scales - the filtered height at level L and at level L+1 differ by
   more than half a cell in real Alpine relief, which is the LOD chooser's
   business and not the ring ladder's.
3. **`far_supersample` is the tunable the plan names, and it moves the outer
   boundaries only.** Rings 5 and out read the tile store, which is where the
   supersample lives; rings 0 to 3 read the region pyramid, whose levels are
   exact 2x2 reductions and cannot be improved by sampling more. Measured, see
   below.

### `far_supersample` 4, measured, and what it does not reach

The plan says: "Where a boundary fails and `far_supersample` 4 fixes it, take
4 and record." Measured, a whole probe run at Ultra with
`--set far_supersample=4`, diffed against the same run at 2:

**Re-measured in Stage 4** after the probe's C++ mesher was found to be
drawing the summit vantage off the region's clamped rim (see "Everything that
blew up was one uninitialised member"). The conclusion below was reached on
the earlier table; the spawn vantage's rows - the ones it rests on - are
identical in both, and Stage 4's re-run is reported in its own section.

**Three numbers move in seventy-eight rows, and all three are the same
number.** The summit vantage's fizz max goes 34.890 -> 35.239, the 150 m ring
boundary's max fizz goes 34.89 -> 35.24, and its handover RMS goes 36.77 ->
36.81. **Every failing boundary fails by the same amount it did at 2.** Peak
loss is identical to the last digit; so is valley gain; so is every terrace
row.

And it is not free: the 168 tiles the probe holds take **27,891 ms to build
instead of 10,063** - 2.8x for three tenths of a block at one vantage.

**Why it cannot help, which is the useful part.** Supersampling changes how a
tile CELL is averaged. A handover step is the difference between the height
filtered at level L and the same place filtered at level L+1 - two different
box widths over the same terrain - and no amount of sampling inside a cell
makes a 512 m box agree with a 256 m one on a mountain. The boundaries fail
because real Alpine relief has more than half a cell of height in it at every
scale, which is a statement about the terrain and the LOD chooser, not about
the tile store.

**Re-measured in Stage 4 on the repaired probe, and the answer did not
change.** Nineteen lines of seventy-eight move and every one of them is a
tenth: the summit's fizz max `9.61 -> 9.18`, roughness `1.2869 -> 1.2873`, the
seam handover rms `2.38 -> 2.75` (slightly WORSE), and not one boundary
crosses its gate in either direction. Peak loss, valley gain, the colour
handover and every spawn and lake row are identical. Tile build `13.1 s ->
36.5 s`, the same 2.8x.

**Taken as: stay at 2, record the numbers, do not spend 2.8x on nothing.**
The knob keeps its place on F4. The thing that would actually move these rows
is a wider geomorph blend across a ring boundary, or the level chooser
overlapping its bands - both of them look changes with a frame cost, both of
them Stage 5's or a later lane's to weigh, and neither of them named in this
plan.



### Peak loss went from +0.96 to +23.02 blocks, and the cause is the divisor

At 600 m, over the twenty highest summits:

| | mean | worst | over 4 blocks |
| --- | --- | --- | --- |
| Stage 0 baseline, `far_ring_div` 4, 3.2 km | **+0.96** | +2.62 | 0 of 20 |
| Stage 3, `far_ring_div` 2, 32 km | **+23.02** | +64.71 | **12 of 20** |

600 m is where ring 3 begins, and ring 3's cell went from 8 m to 16 m when the
divisor was halved. A summit is a point; the mesh can only draw it if a vertex
lands near it, and `far_peak_gain` buys back what the max pyramid saw within
the filter footprint, not what fell between two vertices 32 blocks apart.
Doubling the lattice spacing at a peak is the one place where a 4x vertex
saving is paid for in a visible way, and it is paid at 600 m - inside the
frontier, on the ridgeline you are walking towards.

**Measured, not argued.** A third whole probe run at Ultra with
`--set far_ring_div=4` - the same ten rings, the same 32 km, the only
difference the base cell:

| at 32 km | peak loss, mean | worst | over 4 blocks | vertices | far build |
| --- | --- | --- | --- | --- | --- |
| `far_ring_div` 2 | +23.02 | +64.71 | 12 of 20 | 1,782,136 | 457 ms |
| `far_ring_div` 4 | **+1.34** | **+2.72** | **0 of 20** | 6,625,522 | 1,618 ms |

The divisor is the whole cause and nothing else is: at 4 the summits come back
to the Stage 0 baseline's +0.96 (the remaining tenth of a block is the ladder
having ten rings now instead of five). It costs 3.7x the vertices - 3.3x over
the plan's budget - and 3.5x the far build.

The near handover improves with it and does not pass either: `2/3` goes from
`rms 7.16 max 23.03/16` to `rms 3.76 max 15.49/8`, `3/4` from `17.44/32` to
`6.88/16`. The coarse boundaries and the summit vantage's 465-block seam are
unchanged, which is the second confirmation that those belong to the region's
rim and not to the ring ladder.

**This is not a red gate.** The plan's Stage 3 check on peak loss is that the
two runs agree, and they do, character for character, at both settings. What
this is, is the price of the horizon written down in the one place it is
visible: **one spinbox, 4.8 M vertices, and 22 blocks off every summit at
600 m.** Stage 7 measures the frame at both. **For Marcel.**

### Everything that blew up was one uninitialised member - CORRECTED IN STAGE 4

**This section said something else when Stage 3 was committed, and it was
wrong.** It read "everything that blew up is at the home region's rim", blamed
the two doors' different fallbacks, and left the seam number as a silence for
the world-truth break. Stage 4's colour handover found the real cause, and it
is worth leaving both the wrong reading and the right one here, because the
wrong one was plausible and specific and it was still wrong.

**`FarMesher.setup()`'s first parameter is named `heightmap` and shadows the
member of the same name, and `setup` never assigns the member.** So a mesher
whose caller does not assign it by hand is handed the store's tiles ONCE, at
setup, and never again: `build()`'s `_new_tiles(heightmap)` reads a null
member and sends nothing. `far_field.gd` assigns it (Stage 3 found the same
bug in the game's path and fixed it there); `far_probe.gd` and
`selftest_horizon.gd` did not.

**What that did to the probe.** At the spawn vantage nothing, because the
world had already been loaded around the player and setup carried those tiles.
At the summit vantage - 1.4 km away, at the region's edge - the C++ leg had no
tiles at all for the ground it was drawing, so it fell back to the region's
clamped rim and drew an extruded edge where there is a mountain.

| the summit vantage | before | after |
| --- | --- | --- |
| seam against the voxel surface, max | **465.33 blocks** | **17.45** |
| seam, rms | 160.93 | **3.57** |
| handover `seam@0` rms | 20.50 | **2.38** |
| handover `0/1` rms | 36.77 | **12.37** |
| handover `1/2` rms | 83.03 | **25.39** |
| rock and snow quads not painted their own palette colour | 2,399 | **0** |

**The spawn and lake vantages are unchanged, character for character**, which
is the confirmation: the bug was never about the rim, it was about which
vantage the mesher had been told about. The coarse-ring handover failures at
those two vantages - `4/5`, `5/6`, `6/7` - are therefore real and stand as
written above.

**The game was never affected.** `far_field.gd` sets the member; the far
parity gate and the horizon self-test both build meshes at the origin, where
setup's tiles cover everything. It was the INSTRUMENTS that were blind, which
is the worse of the two places for it to be and the reason the fix is written
up at this length.

### The far probe had to be taught the reach twice

Two of its constants were written against a 3.2 km disc and are quadratic in it:

1. **The quad lookup grid**, `2 * far_radius / 8` on a side - 15 MB at 3.2 km,
   **1.5 GB at 32**. Replaced by the exact per-step index (above).
2. **The fizz lattice.** `FIZZ_STEP_BLOCKS` is 13 and covers the whole disc, so
   the sample count is quadratic too: 1.4 M samples at 3.2 km and **139 million
   at 32**. The probe would still have been running in the morning. The spacing
   is now `13 * m` with `m` ODD, scaled to keep the count near what it was -
   odd times thirteen still shares no factor with any power of two, which is
   the whole property the 13 was chosen for.

Neither is a horizon-v1 bug; both are what a constant chosen for one reach does
when the reach moves by a factor of ten, and both would have failed silently as
"the probe is slow" or "the probe died".

### The race that made a gate report a different number each run

Far parity went red with the shape of a real bug and the smell of a bad one:
**the GDScript leg's vertex count changed between runs of the same build** -
133,392, then 133,424, then 135,088 - while the C++ leg sat at 132,640. A gate
that varies is not a gate, and the cause is worth writing down in full because
it is a class of mistake this lane could make again.

`Heightmap.publish_far_view()` REPLACES the two dictionaries the far mesh
reads. Stage 3 put it on a WORKER, inside the build task, right after the tile
preparation - which looked right, because the preparation and the build belong
together. But a far build has two legs and they take their tiles at different
moments: the GDScript job read `_far_tiles` per sample, and the C++ leg is
handed its tiles by `FarMesher.build` at the top of its own build. So a publish
landing between the two handed them views from either side of the same
replacement. Two different mountains, intermittently.

Two fixes, and both are the design rather than a patch:

1. **A job captures the view once.** `FarFieldJob._view = heightmap.far_view()`
   at the top of `run()`, held for the whole build, threaded down through every
   far door and through `detail_at`, `_slope_zone` and `surface_zone_at`. The
   `far := false` flag those three gained in Stage 1 becomes "which view do you
   read", which is the question that was actually being asked. That is exactly
   the deal the C++ leg has always had, made explicit on this side.
2. **`publish_far_view` only ever runs on the main thread.** The far build is
   two tasks now: a worker prepares the tiles, `_process` sees it finish,
   publishes, and submits the mesh. The harness that builds both legs runs
   synchronously, so nothing can interleave; in the game there is one
   `FarField` and one build at a time.

After both: all five far-parity cases at `pos 0.000000000 normal 0.000000000
colour 0.000000000`, run after run.

And a third thing the two-phase build broke, which is the same lesson from the
other side: **`_task == -1` is what every waiter in this project reads as "the
far field is idle"** - `selftest.gd`'s `_pump_far_field` returns the moment it
sees it. A second task handle for the prepare left a window where the far field
looked idle with nothing built, and the far-terrace-knob gate measured zero
vertices and zero rebuilds. `_task` carries both phases and is never -1 between
them; the transition happens inside one `_process` call.

And the last one, which had been latent since Stage 1: **`FarMesher.heightmap`
was never assigned.** `FarMesher.build` marshals the tiles the C++ side has not
seen and reads them off that member; `far_field.gd` sets `config`, `center`,
`frontier` and `slice` on the mesher before every build and never set the
heightmap, because until Stage 1 there was nothing to send and `setup()` took
the heightmap as a parameter. So the C++ leg received the tiles marshalled at
setup and **nothing after** - it drew the region's rim wherever the GDScript
leg drew prepared ground. The far dispatch gate reported it as one leg emitting
135,088 vertices against another's 132,640, and it survived three earlier
rounds of fixing because the parity harness builds its jobs by hand and never
prepares a tile.

**And `parsecheck` is not a gate.** The throwaway script this run used to check
syntax reports `ok` for a script that fails to compile - `ResourceLoader.load`
returns a non-null Resource with a compile error attached. Every parse check
from here is a real scene run.

### The far probe's lookup grid had to go

`Surface`'s flat grid was `2 * far_radius / LOOKUP_CELL_BLOCKS` on a side. At
3.2 km that is 1,922 square - 15 MB, fine. At 32 km it is **19,204 square,
1.5 GB**, and the probe would have died on its first allocation the moment the
reach moved. It is replaced by the exact per-step index Stage 0 added for the
inner rings, extended to every ring: one entry per ground quad, bounded by the
mesh rather than by the reach, and a lookup walks the steps finest-first and
takes the first hit. `LOOKUP_CELL_BLOCKS` is retired with it.

---

## Stage 4 - one colour at every distance

**Green.** The far country's colour is a lookup, and what it looks up is the
same material the chunk mesher would put on the top face.

### What shipped

| | what |
| --- | --- |
| `heightmap.gd` | **The material pyramid.** `materials` is level 0 over the region grid, one byte per cell, from `surface_zone_at`; `_mat_levels` is 1 to 5, each the MODE of its four children with ties to the lower id. Per tile, the same byte per cell, the mode over the `far_supersample` sub-samples. |
| `heightmap.gd` | **The forest cover.** One byte per `COVER_STRIDE` cells - four - region and tiles, from `TreePlacement.cover_at`. Read nearest, like the material. |
| `terrain_generator.gd` | `surface_zone_with` and `slope_zone_with`: `surface_zone_at` with the slope handed in. Same answer, one argument instead of four height reads. |
| `tree_placement.gd` | `cover_at`: the placement probability without the crown-spacing pass, normalised by `max_probability`. |
| `height_tiles.{h,cpp}`, `height_tiles.gd` | `setup_zones` and `build_materials`: the material grid in C++, using a second instance of the far mesher's own `World` for the zone rules rather than a third copy of them. |
| `far_field_job.gd`, `far_build.cpp` | The quad's colour is `material_at` then the forest blend. **`_far_zone`, `_zone_vote`, `_vote_memo`, `_vote_level`, `VOTE_SPLIT`, `_voting` and their C++ twins are deleted** - about 250 lines between the two legs. |
| `far_field_job.gd` | `canopy_color()`: the mean canopy colour of the mounted tree library, with `TreeModels`' own fallback when there is none. No asset colour is committed (D50). |
| `far_probe.gd` | The colour handover table: the mesh's own vertex colours either side of every ring boundary, per material. |
| `far_field.gd`, `debug_hud.gd` | `far_vote`, `far_zone_cell_m` and `far_zone_cell_ratio` leave `FAR_ONLY_PROPERTIES` and the F4 panel. Nothing reads them. |

### What the far colour used to be, and it is worth writing down

Five mechanisms, four knobs, none of them the rule the voxels use:

1. `surface_zone_at` at ring 0 - the exact voxel rule, with its jitter and its
   per-patch dither.
2. `backdrop_zone` past ring 0 - altitude alone, no jitter, a dither of exactly
   0.5.
3. A zone cell that grew with distance (`far_zone_cell_m`,
   `far_zone_cell_ratio`), so the paint was sampled on a coarser grid than the
   geometry.
4. Distance v3's four-sample majority vote (`far_vote`), memoised per zone
   cell, to stop the result fizzing.
5. All of it re-derived from the height the far mesh had just drawn - so a
   terrace that moved the ground moved the snow line with it.

**All five were ways of guessing what a coarse cell is made of.** The pyramid
knows: the cell's material is the mode of the materials under it, computed once
when the pyramid or the tile was built. It cannot fizz, because nothing is
resampled per frame; it agrees with the voxels at level 0, because level 0 IS
`surface_zone_at`; and the colour of a 512 m cell is the commonest thing
actually in it rather than a sample of the middle.

### Level 0 is the mesher's own choice, ten thousand times

`material parity`, the new horizon self-test:

```
material parity: 10000 level-0 cells exact,
                 2000 level-1 cells are a child of their four,
                 1435 ms to build
```

**And it is a cross-leg test without looking like one.** The pyramid's level 0
is filled by `KubikHeightTiles.build_materials` - C++ - and `surface_zone_at`
is GDScript. Ten thousand cells, exact, means the two zone implementations
agree; the far parity gate then means both legs read the same bytes.

The outermost ring of cells is excluded from the test and says why: its slope
is clamped, because its neighbour is outside the region where `height_at` goes
to the tile store. Six thousand cells of two and a quarter million, all of them
at the rim the world-truth break deletes, and **both legs clamp identically** -
which is the property the test needs.

### The cost, measured twice, and one of them sent a loop to C++

The horizon self-test's tile-store case builds 1,041 tiles. Before and after:

| | 1,041 tiles | region pyramid |
| --- | --- | --- |
| Stage 3 | **10.5 s** | - |
| material, first spelling (GDScript tally) | **74.0 s** | - |
| material, in C++ | **13.8 s** | 631 ms |
| material + forest cover | **24.9 s** | 1,435 ms |

**The material went to C++ and the cover did not, and the difference is a
port.** The zone rules already exist in this project's C++ - `zone_at`,
`_slope_zone`, `wildness_at`, all on the far mesher's `World` struct - so
`KubikHeightTiles` holds a second INSTANCE of that struct and the loop moved
with no new implementation to keep in step. The tree placement does not exist
in C++ at all, and porting it is a different epic; so the cover stays in
GDScript and pays for it by being COARSE - one sample per four cells, which is
16 blocks in the region. That is the whole of `COVER_STRIDE`, and it is
defensible on its own terms: a material is an id and a wrong one is a wrong
colour, while cover is a blend weight and 8 m of it looks exactly like 2 m of
it from a kilometre away.

### The cover recursed until the stack ran out

`TreePlacement.cover_at` asked `_ground_ok`, which asks `_slope_ok`, which asks
`heightmap.slope_deg_at`, which outside the region reads the tile store, which
builds the tile - **which is what was calling `cover_at`**. A thousand frames
of `_build_tile_cells` in the backtrace.

The slope is handed in now, from the grid the tile is already building. It is
the same number, computed once instead of four times, and it cannot re-enter
the store. The same split had already been made for the material an hour
earlier and for the same reason; the second one is written down here because
the failure mode - a self-test that runs for eleven minutes and then dies in
the flora - looks nothing like the first.

### `backdrop_zone` survives, and it should not

Both legs keep `FarFieldJob.backdrop_zone` / `World::backdrop_zone`, unused by
anything that draws. `scripts/tools/selftest.gd` has a cross-leg parity test
that calls it on eight hundred positions, and **this lane may add exactly one
line to that file** (plan § 0). Deleting the function would turn a green gate
red in a file it may not fix. Written up under "For the merge".

The same file's `vote` case - `far_vote = 1.0` - now exercises nothing: both
legs ignore the knob. It still passes, because it is a comparison of the two
legs and they agree; it is simply no longer a test of anything. Same request.

### The colour across a boundary, and what it caught

The plan's gate: |dH| <= 6 degrees and |dV| <= 8 points either side of every
ring boundary, per material. Measured off the mesh's own vertex colours - see
question 16 for why not off pixels - at three vantages, every boundary the
rings reach:

```
spawn            150 m  meadow dH 0.0 dV 0.0   forest dH 0.5 dV 2.2   alpine dH 0.1 dV 0.1   heath dH 0.0 dV 0.0
spawn            300 m  shore dH 0.0 dV 0.0   meadow dH 0.0 dV 0.0   forest dH 0.0 dV 0.0   alpine dH 0.0 dV 0.0   heath dH 0.0 dV 0.0
spawn            600 m  meadow dH 0.1 dV 0.1   forest dH 0.0 dV 0.0   alpine dH 0.0 dV 0.0   heath dH 0.0 dV 0.0   rock dH 0.0 dV 0.0
spawn           1200 m  meadow dH 0.1 dV 0.1   forest dH 0.0 dV 0.0   alpine dH 0.0 dV 0.0   heath dH 0.0 dV 0.0   rock dH 0.0 dV 0.0
spawn           2400 m  shore dH 0.0 dV 0.0   meadow dH 0.5 dV 0.3   forest dH 0.1 dV 0.4   alpine dH 0.9 dV 0.5   heath dH 0.0 dV 0.0   snow dH 0.0 dV 0.0
spawn           4800 m  meadow dH 0.9 dV 0.7
spawn           9600 m  meadow dH 0.4 dV 0.3
spawn          19200 m  meadow dH 0.1 dV 0.1
summit           150 m  forest dH 0.5 dV 2.2   alpine dH 0.1 dV 0.1   heath dH 0.0 dV 0.0   rock dH 0.0 dV 0.0   snow dH 0.0 dV 0.0
summit           300 m  forest dH 0.0 dV 0.0   alpine dH 0.0 dV 0.0   heath dH 0.0 dV 0.0   rock dH 0.0 dV 0.0   snow dH 0.0 dV 0.0
summit           600 m  shore dH 0.1 dV 0.0   meadow dH 0.0 dV 0.0   forest dH 0.0 dV 0.0   alpine dH 0.7 dV 0.5   heath dH 0.0 dV 0.0   rock dH 0.0 dV 0.0   snow dH 0.0 dV 0.0
summit          1200 m  shore dH 0.0 dV 0.0   meadow dH 0.1 dV 0.1   forest dH 0.1 dV 0.4   alpine dH 0.0 dV 0.0   heath dH 0.0 dV 0.0   rock dH 0.0 dV 0.0   snow dH 0.0 dV 0.0
summit          2400 m  meadow dH 0.2 dV 0.2   forest dH 0.1 dV 0.4   alpine dH 1.4 dV 0.9   heath dH 0.0 dV 0.0   snow dH 0.0 dV 0.0
summit          4800 m  meadow dH 0.5 dV 0.3   forest dH 0.1 dV 0.6
lake             150 m  shore dH 0.0 dV 0.0   meadow dH 0.0 dV 0.0
lake             300 m  meadow dH 0.1 dV 0.0   forest dH 0.0 dV 0.2   alpine dH 0.0 dV 0.0
lake             600 m  meadow dH 0.2 dV 0.1   forest dH 0.1 dV 0.4   alpine dH 0.0 dV 0.0   heath dH 0.0 dV 0.0   rock dH 0.0 dV 0.0   snow dH 0.0 dV 0.0
lake            1200 m  shore dH 0.0 dV 0.0   meadow dH 0.1 dV 0.1   forest dH 0.1 dV 0.3   alpine dH 0.0 dV 0.0   heath dH 0.0 dV 0.0   rock dH 0.0 dV 0.0
lake            2400 m  meadow dH 0.0 dV 0.0   forest dH 0.1 dV 0.5   alpine dH 0.2 dV 0.2   heath dH 0.1 dV 0.0
lake            4800 m  shore dH 4.6 dV 0.2   meadow dH 0.2 dV 0.1   forest dH 0.0 dV 0.3
lake            9600 m  meadow dH 0.4 dV 0.3
```

**The first run of it failed, and what it had found was not a colour.** Snow at
the summit vantage: `dV 11.7` at 150 m, `33.5` at 300 m, `13.6` at 600 m, and
nothing else anywhere over 4.6. A material is one flat colour, so two snow
quads cannot differ - unless one of them is not snow.

The table grew a second number to answer that: how many rock or snow quads -
the two materials the forest blend never touches, so their colour must be
exactly their palette's - are painted something else. **2,399 at the summit,
none at the spawn or the lake.** That is not a look fault; it is the mesher
and the probe disagreeing about what a cell is made of, and it led to
`FarMesher.setup()`'s shadowed parameter, written up under Stage 3.

**After the fix: zero strays, and every boundary passes** - the worst number
anywhere is `dH 0.7` and `dV 2.2`, against gates of 6 and 8.

Three smaller things were fixed on the way, all of them real and none of them
the cause:

1. **The forest blend is never applied to rock or snow.** The cover grid is
   coarser than the material, so a snow cell beside a forest read the forest's
   sample and came out tinted. `TreePlacement.cover_at` already answers 0 on
   rock and snow; this says it again where the coarse read could smear it.
2. **The C++ leg is told what the published view no longer holds.** Tiles are
   sent incrementally and nothing ever told it about an EVICTION, so the two
   legs drifted apart the moment the store evicted anything - one reading the
   region's rim for a tile that was gone, the other still holding it.
   `tile_keep` carries the view's whole key set and `World::prune_tiles`
   applies it.
3. **`_sent_tiles` forgets what is no longer published**, unconditionally. The
   first spelling guarded it with `if size > size`, and a view that evicts two
   tiles and gains two has the same size and a different set.

### And the probe had to be made deterministic again

Fixing the mesher's tile set made the probe's own table depend on history: it
evicted at twice the radius it prepared, as the game does, so a tile between r
and 2r survived from the previous vantage and run 2 of the determinism check
started with tiles run 1 did not have. Measured: roughness `1.0340` against
`1.0344`, and four terrace quads.

The probe now evicts at exactly the radius it prepares, which makes the
published view a pure function of the vantage. It costs time - a full table
went from 85 s to 416 s per run, because every vantage rebuilds its own tiles -
and it buys the one property the instrument exists for. **Tables identical.**

### Checks

| check | result |
| --- | --- |
| **material parity** (new, horizon self-test) | **10,000 level-0 cells exact**, 2,000 level-1 cells are a child of their four. Cross-leg: the pyramid is filled in C++ and the reference is GDScript's `surface_zone_at`. |
| **colour handover** (new, far probe) | **every boundary, every material, every vantage passes.** Worst anywhere: `dH 4.6` (shore at 4.8 km from the lake) and `dV 2.2` (forest at 150 m from the spawn), against gates of 6 and 8. **0 rock or snow quads off palette**, from 2,399. |
| far probe, twice | **identical**, and each run internally identical across its own two passes. Both `PASS`. |
| far parity, far pyramid, zone, slice, layer, dispatch | **green** - `SELFTEST: all passed` |
| horizon self-test | **all passed**, eight tests |
| character self-test | **36 tests, all passed** |
| canonical line | **unchanged** - heightmap `4782edac`, spawn `(-44, -124)`, 53 lakes, 15,218 trees, config `1d7c18c7` |
| the summit's seam | **17.45 blocks** from 465.33, rms **3.57** from 160.93 - the uninitialised member, above |
| peak loss at 600 m | +22.97 mean (was +23.02 with the broken probe); the divisor's bill is unchanged and is question 8's |

### The eye check, fog off, and the far country is dark for a reason

`30-horizon-peak`, `--fog off`, 9 x 9 windows:

| window | H | S | V |
| --- | --- | --- | --- |
| lit snow, near `(760, 560)` | 29.5 | 9.6 | **73.4** |
| lit snow, mid `(980, 470)` | 28.7 | 10.0 | **72.2** |
| lit snow, far `(1180, 395)` | 28.3 | 13.0 | 42.5 |
| shadowed flank `(200, 480)` | 24.8 | 36.9 | **4.8** |
| shadowed flank `(400, 430)` | 23.4 | 10.5 | 18.3 |
| horizon ridge `(700, 357)` | 39.6 | 3.0 | 44.6 |
| sky `(640, 120)` | 3.7 | 1.3 | 50.2 |

**The plan asks whether the same flank at 500 m, 2 km and 8 km is within the
same window. Lit snow at three distances: V 73.4, 72.2, 42.5 and H within
1.2 degrees.** The first two are the same surface; the third is a flank turned
further from the sun as well as further away, which is what the shot has to
offer - a mountain does not present the same face at three ranges. **The
rigorous version of this question is the probe's colour handover**, which asks
it of the same material either side of every ring boundary out to 19 km and
answers within 4.6 degrees of hue and 2.2 points of value everywhere.

**And the far country's darkness is not fog.** Stage 3 recorded "the far
country reaches the horizon and arrives there almost black" and left it for
Stage 5 to answer with air. With the fog switched off entirely the shadowed
flank still reads **V 4.8**, and the lit ground beside it reads **73.4**. So
the darkness is the sun: it is the shaded side of a massif at 09:00, drawn
with a flank normal, and it is correct. What Stage 5 can change is how much
of the AIR sits in front of it - which will raise the shadowed flank towards
the fog colour rather than leave it at 4.8 - and the sentence to re-read after
Stage 5 is that one, not "the colour table is wrong".

**Against Stage 3, same shot, fog on:** the far mass reads V 11.9 / 19.9 /
14.7 at the three sampled windows against Stage 3's 11.6 / 17.8 / 22.4, and
the near snow and the sky are unmoved (V 68.9 and 53.1). The material pyramid
did not change what the far country is made of - it changed how it is decided,
and the picture agrees.



---

## Stage 5 - the air

**Green.** The fog is a ramp on the draw distance, and the day is clear for
twelve kilometres before it starts.

### What shipped

| | what |
| --- | --- |
| `project.godot` | Three shader globals: `kubik_far_ramp` (the hour's switch), `kubik_fog_color` (the hour's fog after `fog_sky_affect`), `kubik_far_reach` (R). |
| `look.gd` | The ramp in `OPAQUE_SHADER`: `t = clamp((d - 0.4R)/0.6R, 0, 1)`, `f = 1 - exp(-(2.5t)^2)`, the surface faded out by `f` and the air added unlit. |
| `sky_cycle.gd` | `far_ramp` in every keyframe - **1 at day and evening, 0 at dusk, night and eerie** - and 0 under eerie whatever the hour. The three globals written once a frame beside `kubik_night` and `kubik_warm`. Day and evening `fog_density` **0.00018 and 0.00027 -> 0.00003**. |
| `game.gd` | R follows the preset, at load and on every config change. |

### The curve, and why it is not a density

The engine's exponential fog is a density: it thickens with distance forever
and has no idea where the world stops. At a 3.2 km view that was fine - the
mesh ended before the fog did. At 32 km it had become the thing the north star
forbids: "fog as a ramp on that distance and **never a wall**". At the old day
density of 0.00018 a hillside at 8 km was already 76% air.

The ramp is normalised to R instead, so the air is a fact about **where the
world ends** rather than about how far a photon travels: nothing at all before
0.4 R, 0.22 at 20 km, 0.63 at 26, and 0.998 at 32 - which is exactly where the
far mesh's own outer edge sits inside the fog rather than against the sky.

The exponential term is not deleted, it is demoted: 0.00003 is the aerial tint
that makes a ridge at 3 km sit BEHIND one at 1 km, and `fog_aerial_perspective`
0.6 still fades it toward the sky in that direction. The volumetric field, the
height term and the valley bands are untouched - they are fog's other two jobs
(light v1) and they are about places, not distances.

### `FOG` does nothing in this renderer, and that cost an hour

The obvious spelling is the built-in: write `FOG = vec4(colour, amount)` in
`fragment()` and the engine blends it after lighting. **It has no effect
here.** A tour frame with `FOG = vec4(1.0, 0.0, 0.0, 0.5)` forced on every
fragment came back with no red in it at all, on Forward+, with
`fog_enabled` true and `FOG_MODE_EXPONENTIAL` on the environment - and the
same frame with `ALBEDO` forced green came back green, so the shader was the
one running.

So the mix is done by hand, and the pair of lines is what makes it correct
rather than merely close:

```
albedo *= 1.0 - far_f;              // the surface's LIT contribution goes with it
far_air = kubik_fog_color * far_f;  // and the air is added UNLIT
```

At `f = 1` the fragment is the air's colour at the air's own brightness,
whatever light happens to fall on that slope. A mix into `ALBEDO` alone would
have left a fogged mountain black at night and a white blaze at noon.

**Verified before it was trusted**, because a ramp that starts at 12.8 km is
invisible in any frame this tour takes: the same shot at `far_reach_m` 200 m,
where the massif on the left of `30-horizon-peak` fogs out to a flat pale wall
and the summit plateau under the camera does not. `build/tour/ramp200`.

### The gate, on `30-horizon-peak`, fog on against fog off

Both shots from the same build, `--fog off` zeroing the ramp with everything
else. A skyline detector walks each column down from the sky, finds the first
row that differs from it by more than 6 V, and takes a 9 x 9 window across the
edge; the contrast is that window's V range.

| | |
| --- | --- |
| **ridges well below the horizon line** (289 columns) | **median 86.0% of the fog-off contrast kept** |
| named: `x=1100, y=365` | off 37.6, on 36.9 - **97.9%** |
| named: `x=900, y=364` | off 36.1, on 29.8 - **82.6%** |
| named: `x=720, y=356` | off 31.0, on 31.4 - **101.3%** |
| the horizon line itself (20 km and beyond) | 59% to 69% - **the ramp doing its job** |

**The gate is 85% and the median is 86.0%.** The columns that lose a third of
their contrast are the ones the ramp is FOR: terrain on the horizon line, which
at this vantage is twenty kilometres and further, where the plan's curve is
0.22 and rising. A screenshot cannot label a ridge with a distance, which is
the honest limit of this instrument; **the rigorous version of "the same rock
is the same colour at two distances" is the far probe's colour handover**, and
it answers within 4.6 degrees of hue and 2.2 points of value at every ring
boundary out to 19 km.

### And the far mesh's edge is invisible

The plan: at 32 km a 9 x 9 window straddling the edge differs from the sky
beside it by less than 3 V. Over 317 sampled columns of `30-horizon-peak`:

- **34 columns are within 3 V of the sky, the best of them 0.1** - those are
  the sightlines where the ground reaches far enough for the ramp to be full,
  and they are exactly where the mesh's own rim would be if it were visible.
- The median column is 13.4 V from the sky, and it should be: it is a ridge
  at five or ten kilometres, and a ridge you cannot see is not a horizon.
- **Nowhere in the frame is there a straight horizontal edge.** The skyline is
  terrain in every column of the frame.

### The hours are unmoved, and the tour's sky window is not a stable instrument

`20-hour-day` to `24-hour-eerie`, 9 x 9 windows, Stage 4 against Stage 5:

| shot | ground dV | mid dV |
| --- | --- | --- |
| day | -0.2 | +0.2 |
| evening | +0.2 | +0.1 |
| dusk | **-0.7** | **-1.5** |
| night | **+0.2** | **-0.2** |
| eerie | **-0.1** | **-1.5** |

**Dusk, night and eerie are within 1.5 V, against a gate of 2.** Evening is
+0.2 and +0.1, RECORDED as the plan asks.

**The sky window at `(640, 120)` moved +7 V at every hour including the three
where the ramp is off, which is not this stage.** The control says so: the same
window is `38.5 -> 31.5 -> 38.6` across Stage 3, Stage 4 and Stage 5 at day and
`22.6 -> 15.6 -> 22.5` at night - Stage 5 lands back on Stage 3's number to a
tenth, and Stage 4's tour is the outlier by seven points at all four hours at
once. A whole-frame offset that size, identical across hours, is an exposure
difference between tour runs and not a colour change. **Recorded rather than
chased**: no gate in this plan reads that window, and the ground and mid
windows - which do measure the world - agree to a tenth across all three
stages. **For Marcel**, as a caveat on any sky number taken from a single tour.

### `31-horizon-far`, and this is the shot to open first

Twenty kilometres out, looking back. **Stage 4 and Stage 5 side by side is the
clearest picture this lane has produced of what the old fog was costing.**

| | |
| --- | --- |
| **Stage 4**, day density 0.00018 | grey. A meadow in the foreground, a white smear where a range is, and nothing else. The world ends about four hundred metres from the camera. |
| **Stage 5**, density 0.00003 and the ramp | **A country.** Snow and red rock on the left, a green valley floor running away to the middle distance, ridges behind ridges, and the fog taking over only at the horizon. |

**RECORD, and it is not this stage's**: a long pale horizontal slab sits at
about `y 370` across the middle distance, with a grey vertical column under it
near `x 530`. It is in the Stage 4 frame too, at the same place, which is what
says it is geometry and not air - almost certainly a far-mesh SKIRT seen
edge-on from a vantage 250 m above the ground, which is a sightline no shot in
this tour had before Stage 3 lifted `31-horizon-far`. Stage 3's eye check
recorded "thin horizontal light streaks... ring skirts seen edge-on"; this is
the same thing with the haze taken off it. Named here so it can be looked at:
`build/tour/horizon-5/31-horizon-far.png`, and the skirt rule is
`far_field_job.gd`'s `SKIRT_DEPTH_CELLS`. **For Marcel.**

### Checks

| check | result |
| --- | --- |
| main self-test | **SELFTEST: all passed** |
| horizon self-test | **all passed**, eight tests |
| character self-test | **36 tests, all passed** |
| canonical line | **unchanged** - heightmap `4782edac`, spawn `(-44, -124)`, 53 lakes, 15,218 trees, config `1d7c18c7`. The keyframes are in `sky_cycle.gd`, not in the config, so a fog density is not a hashed field. |
| far probe | **PASS**, tables identical across its two runs and **identical to Stage 4's table**, row for row - the air is a shader and the mesh does not know about it |
| skyline contrast, fog on vs off | **median 86.0%** over 289 ridges, gate 85% |
| the mesh's edge against the sky | **0.1 V at best**, 34 of 317 columns within the gate's 3 |
| dusk, night, eerie | **within 1.5 V**, gate 2 |

---

## The amendment, 2026-09-04 evening

Marcel, relayed by Fable, overriding the plan's "never touch `main`" for the
final step only: **when the run is complete and every gate of the last stage is
green, this branch merges itself into `main` and pushes.** `git fetch origin`,
`git merge origin/main`, resolve only trivial docs conflicts by keeping both
sides' substance and otherwise abort and stop, re-run the gates if any code
file changed in the merge, then `git push origin HEAD:main`; once more if the
push is rejected. Never force-push, never rewrite history, never merge a red or
wrapped-early stage. `main` carries `feat/mesher-v1` (merged `2b93471`) and the
docs commits to `c1bd01d`, so the merge brings the chunk mesher in and the
GDExtension is rebuilt before the gates re-run.

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
6. **The plan's ring cell table and its "cell = step at `far_ring_div` 4"
   parenthetical contradict each other.** The table reads "ring 0 | 2 m ...
   ring 9 | 1,024 m", which is `far_ring_div` 2; at 4 the cells are half that
   and the vertex sum is 6.5 M against the plan's own 2.0 M budget. Taken as
   the table and the budget - two specific statements against one aside - and
   measured both ways before deciding. Stage 3 has the numbers.
7. **Level 0 tiles are never supersampled.** The plan applies
   `far_supersample` at every level; taken as level 1 and up only, because at
   level 0 it would put a metre-high filter step around the whole home region
   where the tile store meets the array. Reasoning and measurement under
   Stage 1.
8. **`far_supersample` is applied by calling `build_tile` s-squared times at
   sub-cell offsets, not by adding a `supersample` argument to
   `KubikHeightTiles`.** Same samples, same means, same quantisation, and
   `gdext/src/height_tiles.{h,cpp}` is untouched - which is the smaller change
   and keeps the one class in this seam that decides WORLD TRUTH out of this
   lane's diff. The offsets are `cstep * (2k + 1) / 2s`, whole blocks at every
   level the store uses.
9. **The far mesh reads a frozen view of the tile store and never builds.**
   The plan does not say what a far-mesh read does on a missing tile; taken as
   "the region's clamped rim", because the C++ leg cannot build one and the two
   legs must agree. `FarField` publishes the view before each build. See
   Stage 1.
10. **ENet's default port is taken by the other lane.** `24565` is held by the
   mesher lane's tour for as long as it runs, so every hosted run in this lane
   passes `--port 24566`. Nothing in the plan's command lines changes meaning;
   the flag is recorded here so a reader reproducing a number uses the same
   one. No file the other lane owns was touched to get this.
11. **Grill Q21 contradicts itself on the presets' reach.** "All presets see
   R = 32 km; they differ in the near" is followed immediately by "Low: ...
   R 8 km. Medium: ... 16 km." Taken as the explicit per-preset table, which is
   the more specific of the two and the only one that can be implemented.
   Ultra is 32 km either way, and Ultra is what every gate in this plan is
   measured at, so no gate depends on the reading. Lands in Stage 3.
12. **`far_rebuilds <= 12` cannot be met and no longer measures what it was
   written to measure.** Taken as: report the number, report the cost beside
   it, and do not redefine the gate. A rebuild after Stage 3 is a partial - a
   handful of the 160 keyed meshes - so the count follows how fast the near
   field streams (55 rebuilds against 6,300 chunks warm, 33 against 5,700
   cold) while the cost per rebuild fell from 530 ms to 115 ms and the total
   worker time over a sprint fell from about 9.5 s to about 6.3 s at ten times
   the reach. `far_ring_recenter_frac` at 0.5 takes 55 to 49 and no further,
   because rings 0 to 2 follow the frontier by design. The conservative
   reading is that this is a green stage with one number that needs rewriting,
   not a red one: the quantity the gate exists to bound - far work per second
   of play - improved by a third. **For Marcel.**
13. **The plan's Stage 3 eye check for `31-horizon-far` could not be answered
   by the vantage as first written.** "The home region is visible from 20 km
   as a range" was photographed standing at eye level on ground that, outside
   the home region, is generated at wildness 1.0 and so is at maximum relief:
   the camera stood against a cliff and two thirds of the frame was the wall
   in front of it. Taken as: lift THAT ONE vantage 250 m, in
   `screenshot_tour.gd`, and say so in its note. Conservative in the sense
   that matters - it changes where the camera stands, never what the world is,
   and every other vantage in the file is untouched.
14. **"Level L = mode of four children" cannot be taken literally in a tile.**
   A level-8 tile cell has 65,536 level-0 cells under it and no level-0 tiles
   to read them from - the store builds on demand from the seed and a true
   reduction would build the whole world at level 0. Taken as: **inside the
   region, where the pyramid IS a reduction, the mode is exact over the four
   children; in a tile, the `far_supersample` sub-samples ARE the children** and
   the mode is over those - four of them at the shipped value, which is the
   plan's own number. The one place the two differ is written here rather than
   hidden behind a shared phrase.
15. **The forest cover is one coarse grid, not a pyramid.** The plan says "one
   byte per cell" beside the material. Taken as: one byte per FOUR cells
   (`COVER_STRIDE`), one grid per source, read nearest, no levels. Two
   reasons, both measured: it is the expensive one (three noise samples per
   evaluation against the material's one, and no C++ leg because porting the
   tree placement is a different epic), and it is a blend weight rather than an
   id, so 8 m of it looks exactly like 2 m from a kilometre away. The knob is
   one constant and the stride is stated wherever the grid is.
16. **The colour handover is measured off the mesh, not off pixels.** The plan
   asks for 9 x 9 windows either side of a boundary on a fog-off tour shot, for
   rock, meadow, snow and forest. A screenshot cannot answer it: it does not
   know where ring 6 ends, it does not know which pixels are snow, and it has
   the sun, the tonemap and the lens between the colour and the number. Taken
   as: the far probe reads the vertex colours the mesher WROTE, either side of
   a boundary whose radius it knows, grouped by the material the cell actually
   is, with the plan's own thresholds (|dH| 6, |dV| 8). The tour keeps its
   fog-off eye check beside it, and the status doc reports both.
17. **There IS a parse gate, and Stage 0 said there was not.** Stage 0 recorded
   that `parsecheck.gd` is not one: `ResourceLoader.load` returns a non-null
   Resource for a script with compile errors, so it printed "ok" for broken
   files. `godot --headless --path . --check-only --script <file>` does report
   a real `Parse Error` with its line, and it is the gate this lane needed -
   `far_probe.gd` has now cost two long runs to a parse error found only when a
   thirty-minute probe hung on it, once in Stage 3 and once in Stage 4
   (`var r := FarFieldJob.RING_OUTER_M[i] / bs`: an untyped Array's element has
   no inferred type). The COMPILE errors it also prints are noise - autoloads
   are not registered in that mode, so every script that names `Net` reports
   one - so the gate is `grep -c 'Parse Error'` and nothing else. Used before
   every long run from here on. **For Marcel:** worth putting in `README.md`
   § The probes beside `parsecheck`.
18. **`scripts/world/flora/tree_placement.gd` is in neither column of the
   ownership table.** Taken as: editable, additively. It is flora - three of
   its siblings are in this lane's OWNS column - the mesher lane has not
   touched it on `origin/feat/mesher-v1`, and the change is one new static
   function with no existing behaviour altered. Flagged under "For the merge"
   rather than assumed silently.

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
6. **`far_ring_div` goes from 4 to 2, which revisits your 2026-09-01 ruling.**
   At 32 km the divisor decides whether the far country is 1.8 M vertices or
   6.5 M, and the plan's budget is 2.0 M. The halving you asked for in the near
   field is spent on the four rings that reach the horizon instead. One spinbox
   on F4 puts it back, standing still. Full numbers under Stage 3.
7. **The view distance presets are now the reach**: Low 8 km, Medium 16 km,
   High and Ultra 32 km, and Ultra's tree ring goes from 1,000 m to 800 (the
   plan's Q21). Camera far plane 40 km.
8. **The divisor's bill, measured: summits at 600 m lose 23.02 blocks at
   `far_ring_div` 2 and 1.34 at 4.** Twelve of the twenty highest summits are
   cut by more than four blocks where none was before, and a third probe run
   at 4 puts all twenty back. It costs 6.6 M vertices against 1.8 M - 3.3x
   over the plan's budget - and a far build of 1,618 ms against 457. This is
   the argument against item 6 and it is on the ridgeline you walk towards,
   not on the horizon. Stage 7 reports the frame at each; the choice is yours
   and it is one spinbox.
9. **The sprint's `far_rebuilds` gate is unmeetable and, after this stage,
   meaningless.** 55 partial rebuilds at 115 ms have replaced 18 whole ones at
   530, and the plan asks for 12. The quantity worth bounding is far worker
   time per second of play, which fell by a third while the reach grew
   tenfold. Question 12 has the numbers.
10. **The far country's darkness is the sun, not the fog.** Stage 3 recorded
   it as "almost black" and left it for Stage 5's air. Stage 4 measured the
   same shot with the fog switched off: the shadowed flank is still V 4.8 and
   the lit ground beside it is 73.4. It is the shaded side of a massif at
   09:00, and it is correct. Stage 5 will raise it towards the fog colour;
   it will not "fix" it, because nothing is broken.
11. **The far probe's instruments were blind at every vantage but the
   player's, and had been since the tile store landed.** One shadowed
   parameter in `FarMesher.setup()`. Every number this lane published for the
   summit vantage before Stage 4 is wrong and is corrected in place. The game
   was never affected. It is the argument for the colour handover table
   existing at all: it was the only instrument that could see it.
12. **`docs/status/light-v1.md`'s and this document's far-probe numbers for
   the summit vantage are not comparable across Stage 4.** Anything quoting
   "summit" from before tonight was measured on a mesh built from the region's
   clamped rim.

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
7. **The two doors outside the region have different fallbacks.** `height_at`
   reads the LIVE tile store and may build the tile it needs; the far mesh
   reads the FROZEN view and may not, so when a tile is missing from the view
   it answers `_region_clamped` - the home region's edge cell, extruded. The
   honest fallback would be the coarsest tile the view DOES hold over that
   position, and only the region after that. **The 465-block seam this item
   originally cited as its evidence was a different bug** - see "Everything
   that blew up was one uninitialised member" under Stage 3 - so what is left
   here is the design point without a measurement behind it: no number in this
   run is known to be caused by it. The world-truth break deletes the region
   and with it the whole fallback chain.
   `scripts/world/heightmap.gd`, `_tile_bilinear`.

---

## For the merge

One-line requests into files this lane may not edit. Nothing here is done by
this lane.

1. **`scripts/tools/selftest.gd`: retire the `backdrop_zone` cross-leg case.**
   Horizon v1 Stage 4 replaced the far colour with a material-pyramid lookup;
   `FarFieldJob.backdrop_zone` and `World::backdrop_zone` are kept ALIVE IN
   BOTH LEGS solely because that test calls them, and this lane may add exactly
   one line to that file. Delete the case and both functions in the same
   commit.
2. **`scripts/tools/selftest.gd`: the `vote` case tests nothing now.**
   `far_vote` is read by neither leg after Stage 4, so the case compares two
   legs that both ignore it. It passes and is no longer evidence. Retire it
   with item 1, and `far_vote`, `far_zone_cell_m` and `far_zone_cell_ratio`
   with it - they stay in `worldgen_config.gd` for one epic so a saved file
   does not lose fields on load.
3. **`scripts/world/flora/tree_placement.gd` gained `cover_at`**, and that file
   is in neither column of the plan's ownership table. It is flora, the mesher
   lane has not touched it on `origin/feat/mesher-v1`, and the function is
   additive - no existing behaviour changed. Flagged rather than assumed.

---

## For the bible

*(none yet)*
