# Distance v4 - status

The run of `docs/plans/distance-v4.md`, on `feat/distance-v4` from `main` at
`0c1fafa` (distance v3 merged, the C++ doorway scaffolded, the block-lattice
ruling landed). One night, unattended, on ganymede.
**The far mesher crosses to C++, and it is the same mesh.**

Distance v2 made the far country block-SHAPED, v3 made it block-SURFACED and
visible to the rim. Neither could be afforded: on the evening's ruling the far
mesh cost **6.4 seconds a rebuild at `far_ring_div` 2 and 24.7 seconds at 4**,
which is the whole game's worst number and the reason 1 m far cells were a
screenshot mode. Tonight the mesher is a GDExtension and those become
**158 ms and 661 ms**.

**The number to read first is not the speedup.** It is that the C++ mesher and
the GDScript one emit **byte-identical arrays** - same vertex count, zero max
component difference on positions, normals and colours, zero index differences
- across five configurations, and produce **72 identical far-probe geometry
rows** over 98 meshes. The port is a transcription, not a rewrite, and every
gate in this document exists to say so.

**The GDScript mesher did not go away and is not going to.** It is the
reference implementation (decision 1) and the fallback: `far_field_job.gd` is
**not in this branch's diff at all**. On a checkout with no compiled library
the game runs, plays, streams without a hole and passes the whole self-test.

---

## Provenance

Distance v1 introduced this column and v2 and v3 kept it. Kept again unchanged.

| provenance | means |
| --- | --- |
| `ganymede, deterministic` | the far probe, the worldgen probe or the self-test's parity gate. Pure geometry from a seeded generator: same number on any box, every run. |
| `ganymede, single run` | one wall-clock measurement. A smoke alarm, not evidence of a delta. |
| `ganymede, ABAB median` | interleaved, three runs each, median with spread, run order recorded. The only kind of number this document compares two implementations with. |
| `ganymede, eye` | a judgement made by looking at a tour shot taken here, on the RTX 3070 Ti, Forward+ under `xvfb-run`. |

ganymede varies about 9% run to run on wall clock. Every comparative number
below was taken here, on the editor target, headless unless it is a picture.

**Every per-pixel number says which ROWS it came from**, and Stage 8 is where
that convention earned its keep twice in one night.

---

## Five things worth reading even if you read nothing else

1. **The port is 37-43x, and the plan's 30x prediction was the right shape.**
   Interleaved ABAB on this box, editor target, three meshes per vantage per
   leg: the mesher's own time goes **6,129 ms -> 144 ms at `far_ring_div` 2**
   and **23,864 ms -> 580 ms at 4**. Stage 0's trivial `bench_sum` measured
   18x here (17x on Marcel's Mac) and the plan called that a floor; the
   call-heavy loops cleared it comfortably. The whole far probe went from
   313 s a table to 27 s.

2. **`far_ring_div 4` earned its default flip, and the thing that decides
   whether you keep it is not the rebuild.** Decision 5's gate was the C++
   rebuild at div 4 under 1.5 s wall: it measures **661 ms**. But div 4 is
   **3,266,076 vertices**, and uploading them through
   `ChunkMesher.arrays_to_mesh` costs **224 ms on the main thread**, every
   rebuild. That is STATUS items 11 and 17, it is untouched by this port, and
   after tonight it is the far country's binding cost rather than a footnote.
   One number on F4 puts it back: `far_ring_div` 2.

3. **The port made the CHUNK streamer faster without being asked to.** Stream
   probe, seed 42: the collidable ground reaches **40 m -> 56 m** ahead at the
   sprint's worst, and chunks/s go **79.2 -> 99.8** on the out leg. The far
   mesher had been monopolising a worker pool that runs one GDScript task at a
   time; it stopped. Nobody predicted this and it is worth more than it looks.

4. **Long frames went from 4 to 118, and it is arithmetic rather than a
   regression.** Same stream probe: 15 far rebuilds became **297**, and every
   completed rebuild pays the main-thread upload above. GDScript did not have
   this problem because at 11.3 s a rebuild it barely ever finished one. The
   honest sentence is not "the port made frames worse" - it is "the far country
   now actually keeps up, and the price of keeping up is one upload per
   rebuild". See item 2 for the lever.

5. **Stage 8's gate was red, and the fault was in the instrument.** The far
   band came back at mean |dL| **12.59** on `6-postcard` between the two
   meshers - and a second C++ tour diffed against the first measured
   **0.0000** on that same shot. `screenshot_tour.gd` waited for CHUNKS before
   the shutter and never for the far field, so an eight-frame settle was
   photographing a settled far mesh against one built for a vantage two stops
   ago. That was always wrong and only a 42x latency difference made it
   visible. The tour now waits; Stage 8 has the before and after.

**Nothing about the world moved.** Worldgen probe identical to `origin/main`
line for line, heightmap `76cccdb6`, config `3d45b8fc` (unchanged - `far_cpp`
is LOCAL and `hash_key()` walks `PROPERTIES`), spawn `(-44, -124)`, 53 lakes,
28,383 trees.

**`far_field_job.gd`, `world.gd`, `chunk_mesher.gd`, `terrain_generator.gd`,
`lakes.gd`, `look.gd` and `block.gd` do not appear in the diff.** `game.gd`
needed nothing.

---

## Stage 0 - the toolchain proves itself on linux

The whole committed diff is three lines in `kubik.gdextension`. The rest of
the stage is bring-up, recorded here because the next rung of the C++
transformation starts from it:

* **scons 4.11.1 in a venv** at `~/.venvs/scons`, symlinked to `~/bin/scons`.
  A venv rather than `apt` because Ubuntu 24.04's pip is PEP 668
  externally-managed and this box has a hard rule about `sudo`. Nothing
  system-wide was touched all night.
* **godot-cpp master `26fb7ab`** at `~/godot-cpp`, built `target=editor`
  against `extension_api.json` dumped from **this binary** -
  `4.7.2.stable.official.ed1daf0bf` - and not from a close-enough one.
* `GODOT_CPP=~/godot-cpp scons platform=linux target=editor
  custom_api_file=$HOME/godot-cpp/extension_api.json`.

| gate | result | provenance |
| --- | --- | --- |
| `-s gdext/check.gd` exits 0 | class exists true, ping answers | ganymede, single run |
| the trivial bench | **18x** - 10,961 us against GDScript's 199,590 on 10 M floats | ganymede, single run |
| full self-test with the library loaded | green | ganymede, deterministic |

The second gate is the one that matters: the `.gdextension` load must break
nothing headless before any port code exists.

---

## Stage 1 - the parity harness exists before the port

Three files, no port code, and that ordering is the stage. `far_mesher.gd` is
the seam; `heightmap.gd` gains three accessors so marshalling the pyramid does
not mean reaching into `_levels` from another file; `selftest.gd` gains
`far parity`, appended and registered at the end of the list.

Tonight it printed `far parity: c++ mesher absent/stub, 0 checks` and compared
nothing. **That is the point.** A gate that silently passes when its subject is
missing is how a 30x speedup that draws a slightly different mountain ships,
and by the time the pictures show it there are eight stages of C++ to bisect.

**The four cases were chosen for what the far probe CANNOT see**, and a fifth
was added in Stage 4:

| case | what only it exercises |
| --- | --- |
| `far_terrace 0.0` | the smooth mesh, hard rule 1's way back: no cell cache, no riser in the whole build |
| `far_terrace 1.0` | the ridge test, the risers, the `_t_full` fast path the shipped config takes |
| `far_ring_div 4` | the cell this whole night is for, at four times the quads and a different base step in every derived radius |
| a **non-empty frontier** | `_sector_exclude` is filled only when one is passed, and the far probe builds with an empty one - which is exactly how distance v2 shipped a moved inner edge past seven stages of "identical on every geometry row" (STATUS item 12) |
| `far_vote 1` + colour jitter | `far_vote` ships at 0.0 and both colour-jitter knobs ship at 0.0, so the mode vote, its memo and `Block.jitter`'s entire hash path are **dead code in every mesh this project has ever built** |

---

## Stage 2 - the pyramid crosses, exactly

The heightmap, its two pyramids, `height_at`, the bilinear and trilinear
reads, `slope_deg_at`, and `FarFieldJob.filtered_height`'s peak-gain
expression.

| gate | samples | max diff | provenance |
| --- | --- | --- | --- |
| 5 functions x random (x, z, level) triples | 10,000 | **0.00000000000000000** | ganymede, deterministic |

A quarter of the samples land off the map on each axis, because a clamp is
exactly the kind of edge a transcription gets subtly wrong - `mini(i0 + 1,
cols - 1)` against `i0 + 1 < cols - 1 ? ... : ...` are the same function and
only one of them is obviously so. Half the levels land on an integer, which is
`_trilinear`'s early-out.

`World::setup` **copies** the pyramid - about 3 MB, once per world load -
rather than holding a `PackedFloat32Array` and paying its copy-on-write check
on every one of tens of millions of reads a rebuild.

---

## Stage 3 - geometry crosses, and it is exact

The whole ring walk: six rings and their snapped grids, the cell cache, the
terrace quantisation and the ridge sub-step, the seam band and its detail
sample, the risers, the ring-boundary skirts, the per-sector frontier
exclusion. Positions, normals and indices only; every colour white, and
`has_colors()` says so, so the harness compares the rows that are meant to
match and no others.

| case | vertices | max pos diff | max normal diff | indices differing |
| --- | --- | --- | --- | --- |
| `far_terrace 0.0` | 36,928 | 0.000000000 | 0.000000000 | 0 |
| `far_terrace 1.0` | 127,800 | 0.000000000 | 0.000000000 | 0 |
| `far_ring_div 4` | 391,872 | 0.000000000 | 0.000000000 | 0 |
| non-empty frontier | 127,800 | 0.000000000 | 0.000000000 | 0 |

**Three places where exactness needed the GDScript's accidents transcribed
rather than tidied.** They are the whole content of this stage and they are
what "identical, not close" costs:

1. **The cell cache is `float32`.** `_t_h`, `_t_hq` and `_t_t` are
   `PackedFloat32Array`s, so a value stored and read back is TRUNCATED.
2. **`_cell_h` returns a `double` on the compute path and a `float` on a cache
   hit.** The GDScript returns the local `v` the first time and `_t_h[at]`
   every time after. That asymmetry is visible in `_is_ridge`'s comparisons,
   so **the walk order is part of the output** and is preserved exactly.
3. **Vertex and normal maths goes through `godot::Vector3`**, whose arithmetic
   is `float32` in a single-precision build. A cross product done in double and
   rounded at the end is a different normal, and the difference survives
   `normalized()`.

An "improved" expression here is a failed gate; a silently improved one is
worse.

---

## Stage 4 - zone and colour cross, and the gate goes total

**Decision 4's ladder landed on rung (a).** `backdrop_zone`, `zone_at`,
`_slope_zone`, `wildness_at`, `band_color`, `band_m_at`, `treeline_band`,
`Block.color_of`, `Block.aspect_shade`, `Block.jitter` and `Look.to_wire` are
pure functions of altitude, a slope read off level 0, a hash and config
scalars. They are ported. **No zone grid is precomputed and rung (b) is not
spent**, so there is no load-time cost to report.

**One function is not pure, and it crossed on a rung the plan did not name.**
Ring 0's `surface_zone_at` needs `zone_jitter_at`, which is a `FastNoiseLite`
sample; `_corner_y`'s seam band needs `detail_at`, which is another.
`FastNoiseLite` is an **engine class**, so the mesher holds the very same
`Ref<FastNoiseLite>` the generator built and calls `get_noise_2d` on it
natively.

* Decision 2's *"never calls back into GDScript during a build"* holds exactly:
  no GDScript frame is entered.
* No grid is precomputed, so it is not rung (b) either.
* And it is the RIGHT answer rather than merely a permitted one: the noise is
  bit-identical **by construction** rather than by a reimplementation somebody
  has to keep in step with the engine's.

Both are confined to ring 0, which is a few hundred quads of a hundred
thousand. Recorded here because it is a seam the next rungs will meet again:
the chunk mesher reaches for the same two objects.

**Micro-gates, 10,000 samples per function, all exact:** `backdrop_zone`,
`surface_zone_at`, `treeline_band`, `band_m_at`, `band_color`, `aspect_shade`,
and the whole per-vertex tail of `_push_quad` (aspect shade, jitter,
`to_wire`).

**The whole-mesh gate is now colour-inclusive and total:**

| case | vertices | pos | normal | **colour** | indices |
| --- | --- | --- | --- | --- | --- |
| `far_terrace 0.0` | 36,928 | 0 | 0 | **0** | 0 |
| `far_terrace 1.0` | 127,800 | 0 | 0 | **0** | 0 |
| `far_ring_div 4` | 391,872 | 0 | 0 | **0** | 0 |
| non-empty frontier | 127,800 | 0 | 0 | **0** | 0 |
| `far_vote` + jitter | 127,800 | 0 | 0 | **0** | 0 |

---

## Stage 5 - the dispatch, and it is judgeable standing still

`far_field.gd` owns the choice, as hard rule 4 says it must. It marshals the
world into one `FarMesher` at `setup()` - a `RefCounted` the node holds and
drops with itself, hard rule 5 - and every rebuild goes to whichever of the two
the knob names. Both objects present the same five members, so nothing below
the branch knows which built the mesh.

**`far_cpp`** is a LOCAL knob on F4, 0/1, default 1, on
`FAR_ONLY_PROPERTIES` - so it redraws the far country in place with the player
standing still. It is **not a look knob**: the two meshers emit identical
arrays and the gate asserts it every stage. It exists because "identical" is a
claim, and a claim you can turn off standing still is one Marcel can check with
his own eyes instead of taking from a gate.

F3 gains `far mesher: c++` / `gdscript (no c++ library)`.

**A bug this stage found in itself:** `far_cpp` was declared as an `@export`
and left off `LOCAL_PROPERTIES`, which meant `World.setup()`'s clone dropped it
and `--set far_cpp=...` was rejected as "no such config field". Same failure
the flora and AO knobs are guarded against. Caught while wiring Stage 7's
probe runs, not by a test - there is no test that a knob is on that list.

**The gate is both ways, and both are green:**

| | far_cpp 1 | far_cpp 0 | far_cpp 1 |
| --- | --- | --- | --- |
| with the library | c++, 127,800 verts, **23 ms** | gdscript, 127,800 verts, 1,018 ms | c++, 127,800 verts, 24 ms |
| library moved aside | gdscript, 127,800 | gdscript, 127,800 | gdscript, 127,800 |

Meshes identical on every leg, read back off the `Mesh` Godot is holding
rather than off the job. With the library moved aside the whole suite is green
and the three parity tests correctly self-skip.

**One thing to know about the no-library case.** The engine prints three
`ERROR` lines of its own when `kubik.gdextension` names a library that is not
there, which is louder than hard rule 1's "one load warning". They come from
Godot's extension loader, not from this code, they are not fatal, and **they
are not new tonight**: `origin/main` prints the same three on linux already,
as `No GDExtension library found for current OS and architecture`, because
that file has had macOS and Windows entries since Stage 0's scaffold.

---

## Stage 6 - the numbers

`far_probe` gains `--bench`, appended. Three measurements because there are
three questions, and conflating them is how a port gets credited with a
speedup it did not deliver or blamed for a hitch it did not cause.

**Ganymede, editor target, headless, seed 42, view high (`fog_end` 3,200 m),
interleaved ABAB alternating mesh by mesh, three meshes per vantage per leg
over three vantages.**

| | gdscript | c++ | speedup | vertices |
| --- | --- | --- | --- | --- |
| div 2, job | 6,129 ms (3,781-6,261) | **144 ms** (90-160) | **42.6x** | 888,244 both |
| div 2, wall | 6,430 ms (6,404-6,437) | **158 ms** (144-172) | **40.7x** | 941,724 |
| div 4, job | 23,864 ms (14,694-24,333) | **580 ms** (373-638) | **41.1x** | 3,060,928 both |
| div 4, wall | 24,722 ms (24,703-24,723) | **661 ms** (654-668) | **37.4x** | 3,266,076 |

*job* is the mesher's own work on the main thread with nothing else happening -
the honest measure of THE PORT. *wall* is `rebuild_in_place()` called the way
the F4 panel calls it, with the pool idle: the worker handoff and the
main-thread upload included, which is the number a person standing still
actually waits.

**World load changed shape too.** The first far build is now **181 ms of job**
against seconds, and a session summary reads `39 rebuilds: median 180 ms wall`.

### And the thing that got worse

| | `arrays_to_mesh`, main thread | at |
| --- | --- | --- |
| div 2 | **56.17 ms** (55.99-56.40) | 941,144 vertices |
| div 4 | **224.16 ms** (220.34-226.76) | 3,271,568 vertices |

This port does not touch the upload. It makes the mesh it uploads 3.5x bigger
at div 4 and makes it arrive 40x more often at every divisor. **The far
country's cost has moved from a worker thread to the main thread**, which is
STATUS items 11 and 17 promoted from a footnote to the binding constraint.
The lever is an upload off the frame thread or an incremental one - not a
constant.

---

## Stage 7 - the probes

### The far probe: 72 geometry rows, identical

`--cpp` takes the whole table through the C++ mesher. `Surface.build()` loses
its `FarFieldJob` type annotation and takes either - both present `center` and
`arrays`, which is all it reads - and no assertion in that file changes.

| | gdscript | c++ |
| --- | --- | --- |
| meshes built | 98 | 98 |
| vertices each | 945,392 | 945,392 |
| ms each | 5,981 | **141** |
| whole table | 313,455 ms | **27,236 ms** |
| geometry rows | **identical, character for character** | |

Fizz (rms, max, per-100 m band), roughness, per-ring-boundary fizz, terrace
compliance on every ring's step grid, seam agreement against the voxel
surface, and shelf stability over a 200 m walk - at three vantages, run twice
each, self-checked for determinism, `PASS` both ways.

**This is a stronger statement than the self-test's array diff**, and it is
worth saying why the night ran both: these rows are read off the TRIANGLES the
mesher emitted, through the probe's own quad index and barycentric lookup. A
mesh can match array-for-array and still be *read* wrong.

### The worldgen probe: identical to `origin/main`

Line for line, with a single 738-vs-734 ms timing value between them.
Heightmap `76cccdb6`, config `3d45b8fc`, spawn `(-44, -124)`, 53 lakes,
16,414 cells flooded, 28,383 trees, memory 36.5 MB. Nothing about the world
moved, at any stage.

### The stream probe: holes 0, four runs, hard rule 3 met

Seed 42, both legs each, `--set far_cpp` and `--set far_ring_div`:

| run | front min (out/back) | worst frame | frames > 33 ms | chunks/s | far rebuilds | **holes** |
| --- | --- | --- | --- | --- | --- | --- |
| c++ div 2 | 56 / 64 m | 79.9 / 84.5 ms | 118 | 99.8 / 110.7 | 297 | **0** |
| c++ div 4 | 56 / 56 m | 247.8 / 258.8 ms | 41 | 94.9 / 102.2 | 135 | **0** |
| gdscript div 2 | 40 / 48 m | 63.0 / 76.0 ms | 4 | 79.2 / 87.2 | 15 | **0** |
| gdscript div 4 | 40 / 48 m | 27.0 / 35.6 ms | 1 | 75.2 / 80.8 | 3 | **0** |

**Hard rule 3 is met: holes 0 on every run, both legs, at `far_ring_div` 2 and
4.**

Two findings the plan did not predict, and they point in opposite directions.

**The good one.** The collidable ground reaches further ahead with the port in
- front min 40 m to 56 m - and chunks/s go up about 26%. The far mesher had
been monopolising a worker pool that runs one GDScript task at a time, and it
stopped. The port bought the chunk streamer a quarter of its throughput back
without a line being written for it.

**The one to rule on.** Long frames go from 4 to 118 at div 2. The mechanism is
arithmetic, not a regression in the mesher: **15 rebuilds became 297**, and
every completed rebuild runs `arrays_to_mesh` on the main thread at 56 ms.
GDScript did not have this problem because at 11.3 s a rebuild it barely ever
finished one.

**And a caveat on the gdscript div 4 row, because it reads better than it is.**
That run rebuilt the far mesh **three times in the whole probe, 45.4 s each**,
and `[World] far field 0 vertices` says the first had not landed when the world
reported. Its holes-0 is the exclusion radius being honoured, not a far mesh
being there. It is recorded as evidence that a no-library checkout at div 4
still runs and still has no holes - **hard rule 1** - and not as evidence that
it looks right.

---

## Stage 8 - the far band photographed, and the instrument was wrong

The plan's gate: a tour per mesher, same seed, the far band (rows 0-300)
diffed exactly, zero differing pixels. It came back **red**, and the whole
value of this stage is what the red turned out to be.

### The first run, and the control that saved it

| shot | c++ vs gdscript | **c++ vs c++, same code** |
| --- | --- | --- |
| `6-postcard` | **12.5859** | **0.0000** |
| `14-postcard-dusk` | 10.5216 | 0.0000 |
| `13-meadow-dawn` | 5.8666 | 0.0000 |
| `1-spawn` | 6.1843 | 0.1536 |

*(mean |dL| over rows 0-300)*

Two tours of the SAME code differ by nothing on exactly the shots the two
meshers differed by twelve luma levels on. So the difference was not the
meshers - and by then the self-test had five whole-mesh cases at zero and the
far probe had 72 identical geometry rows, so it could not have been.

**`screenshot_tour.gd` waited for CHUNKS before the shutter and never for the
far field.** `_wait_for_world()` polls `_world.is_idle()`, then the tour counts
eight settle frames - about 130 ms - and opens the shutter. A far rebuild is
169 ms in C++ and **10,894 ms in GDScript** on this box. The GDScript leg was
being photographed with a far mesh built for a vantage two stops ago, every
time.

That was always wrong. It only became visible tonight because nothing before
tonight put two far meshers 42x apart in the same harness. **The tour now waits
for the far field**, bounded by the same `MAX_WAIT_FRAMES` the chunk wait uses,
with a warning if it gives up - none fired in three tours.

### The gate, re-run with the instrument fixed

Three tours: C++, GDScript, and a second C++ as the control.

| shot | c++ vs gdscript | c++ vs c++ (control) | flora at the shutter | impostors at the shutter |
| --- | --- | --- | --- | --- |
| `6-postcard` | **0.0000** | 0.0000 | same | same (313) |
| `14-postcard-dusk` | **0.0000** | 0.0000 | same | same |
| `13-meadow-dawn` | **0.0000** | 0.0000 | same | same |
| `12-meadow-night` | **0.0000** | 0.0000 | same | same |
| `17-rim` | **0.0000** | 0.0000 | same | same (468) |
| `2-summit` | 0.0001 (2 px) | 0.0002 (3 px) | | |
| `9-treeline` | 0.0007 | 0.0010 | | |
| `3-forest-slope` | 0.0010 | 0.0070 | | |
| `5-lake` | 0.0091 | 0.0127 | | |
| `4-valley-floor` | 0.0854 | 0.1325 | | |
| `1-spawn` | 0.1129 | 0.1365 | | |
| `15-boulder` | 0.9315 | 1.2844 | | |
| `8-meadow-closeup` | 3.4187 | 3.9667 | | |
| `7-forest-interior` | 0.0160 | **0.0000** | 200 vs 797 cols | **769 vs 707** |
| `11-forest-dusk` | 0.0104 | **0.0000** | 194 vs 797 cols | **769 vs 707** |
| `15-under-canopy` | 0.0633 | **0.0000** | same | same count, 89 vs 120 rebuilds mid-shot |

**`6-postcard` went 12.5859 to exactly zero.** So did the dusk postcard, the
dawn meadow, the night meadow and the rim - **every shot whose rows 0-300 are
actually the far country**. Eight more sit at or below their own control, which
is the flora non-determinism distance v2 wrote down and not a finding.

### What the gate is, honestly

**The gate is met on the far band, and it is not met as a blanket statement
over all eighteen shots.** Three forest-interior shots differ by 0.010-0.063
mean |dL| where their control is zero, and the differing pixels are a
52-column strip and an 86-column strip - canopy gaps, not sky. The cause is
**the impostor ring**, which the tour does not wait for either and which is
**rebuilding 70-120 times during a single stationary shot**: with the GDScript
mesher holding the worker pool for eleven seconds at a time it lands on 707
impostors where the C++ runs land on 769.

So the residual is the foreground, measured through a hole in the canopy, and
it moves with the pool contention rather than with the mesh. The mesh identity
this stage exists to make visible is established three independent ways -
five whole-mesh array comparisons at zero, 72 far-probe geometry rows identical,
and now every settled far-band shot at zero differing pixels.

**And the impostor ring rebuilding 120 times while the player stands still is
a finding in its own right.** It is not this epic's to fix and it is carried.

---

## Stage 9 - the geomorph: NOT TAKEN, deliberately

Decision 6 makes it optional and conditional: *"only if the port lands early
... Stages 0-8 green with hours left"*. Stages 0-8 are green. It was still not
taken, and the reason is the re-verification rather than the implementation.

The fix itself is small and known - blend the SAMPLE POSITION from the fine
ring's cell centre to the coarse ring's across the last two cells before a
boundary, which is STATUS item 9's own measured conclusion. But decision 6 also
says **both meshers, in the same commit, or neither** - and the moment the mesh
output moves, every gate this branch is merged on has to be taken again: the
five parity cases, the 72 far-probe rows (27 minutes for the C++ table, 313
seconds a table for the GDScript one), four stream probes, and three tours for
the far band. That is the whole night's measuring budget spent a second time,
on a stage whose absence is not a merge condition.

**Carried forward with the arithmetic already done** - see the last section.
STATUS items 9 and 18 stay open and are unchanged by tonight: max fizz 80.00
blocks at the 400 m boundary, 128.00 at 960 m, 256.00 at 1,920 m. The far
probe's `--cpp` mode makes measuring the fix 11x cheaper than it was this
morning, which is the practical thing this night did for it.

---

## Stage 10 - the landing

### The default flip, and what it costs

`far_ring_div` **2.0 -> 4.0**. Decision 5's gate is the measured C++ rebuild at
div 4 under 1.5 s of wall; it measures **661 ms**. So the 1 m far cell stops
being a screenshot mode, and it is the fresh checkout and the co-op partner
that get it - Marcel's own machine reads his saved `user://worldgen.tres` and
his morning knob is his own.

**What the flip costs is not the rebuild:**

| | div 2 | div 4 |
| --- | --- | --- |
| vertices | 941,724 | **3,266,076** |
| C++ rebuild, wall | 158 ms | 661 ms |
| **`arrays_to_mesh`, main thread** | 56.17 ms | **224.16 ms** |
| static memory (stream probe) | 326.2 MB | **449.9 MB** |
| worst frame in a sprint | 79.9 / 84.5 ms | **247.8 / 258.8 ms** |
| holes | 0 | 0 |

Putting it back is one number on F4, or `--set far_ring_div=2`.

### Acceptance

| merge condition (plan, decision 7) | result |
| --- | --- |
| full self-test WITH the C++ mesher | **green** |
| full self-test WITHOUT it (library moved aside) | **green**, parity tests correctly self-skipping |
| exact parity | **5 whole-mesh cases at zero**, 12 micro-gated functions at zero, 72 far-probe geometry rows identical |
| stream probe holes 0 at `far_ring_div` 2 | **0**, both legs |
| stream probe holes 0 at `far_ring_div` 4 | **0**, both legs |
| far-band pixel diff at zero | **0 differing pixels on every far-band shot**; see Stage 8 for the three forest-interior shots that are foreground and why |

**Merged to `main`.**

---

## For Marcel to rule on

1. **`far_ring_div` 4 ships, and the 224 ms upload is the reason to look at it
   before anything else.** The flip met the gate the plan set. It did not have
   to meet a gate on the upload, because that number did not exist until
   tonight. A quarter-second main-thread hitch per far rebuild is visible, and
   at div 4 during a sprint the probe caught two frames of 247.8 and 258.8 ms.
   **`far_ring_div` 2 puts it back and costs you the 1 m cell.** My own
   recommendation is to keep 4 for a night of looking at it and rule after -
   the cells are what the last three epics have been for, and the hitch has a
   real fix that a knob does not.

2. **The upload is now the far country's binding cost, and it is the next
   rung's real subject.** The plan's ladder puts the chunk mesher next. On
   tonight's numbers the bigger win may be moving `arrays_to_mesh` off the
   frame thread or making it incremental: the far mesher went 6,430 ms to 158,
   and 56 of those 158 are the upload. At div 4 it is 224 of 661. The chunk
   mesher is a larger blast radius for a smaller number.

3. **The impostor ring rebuilds 70-120 times while the player stands still.**
   Found by Stage 8's harness rather than looked for. It is the one thing in
   this document that is a straightforward bug rather than a trade, it is not
   this epic's file to touch, and it is cheap to see: `grep FarTrees` on any
   tour log.

4. **`kubik.gdextension` prints three engine `ERROR` lines on a machine with no
   compiled library.** Hard rule 1 asks for "one load warning". These come from
   Godot's extension loader and there is no "optional library" flag to set.
   `origin/main` already prints them on linux for the same reason. Either it is
   accepted and documented in the README's *Running it*, or the file stops
   naming platforms nobody has built for - which would break Marcel's Mac.

---

## Carried forward

**Closed tonight:** nothing that was open. This epic added a capability and
took nothing off the list, which is worth saying plainly.

**Open, and unchanged by tonight:**

* **STATUS items 9 and 18 - the loud ring boundaries.** Max fizz 80.00 blocks
  at 400 m, 128.00 at 960 m, 256.00 at 1,920 m, measured again tonight and
  identical to `main`. The fix is known and written down: blend the SAMPLE
  POSITION from the fine ring's cell centre to the coarse ring's over the last
  two cells before a boundary. Stage 9 did not take it and says why. **It is
  now 11x cheaper to measure** - `--far-probe --cpp` runs the whole table in
  27 s where the GDScript table takes 313 s - and it must land in **both**
  meshers in one commit or the parity gate is the thing that breaks.
* **STATUS items 11 and 17 - the main-thread upload.** Promoted from a
  footnote to the binding cost; see "For Marcel to rule on" 1 and 2, and
  Stage 6 for the numbers.
* **STATUS item 16 - `_is_ridge` uses `>=`.** Item 16 says it is "now strictly
  `>`". It is not: both `_is_ridge` and `terrace_offset` use `>=` on `main`
  tonight. The C++ port transcribes what the code does, not what the status
  doc says, so parity is unaffected either way - but one of the two is wrong
  and it is worth five minutes to find out which.

**New, from tonight:**

* **The impostor ring thrashes** - see "For Marcel to rule on" 3.
* **`screenshot_tour.gd` now waits for the far field.** Every tour shot from
  here on is taken with the far country the vantage actually asked for, which
  it was not before. Labelled sets taken before tonight are not comparable to
  ones taken after on the far band, and the GDScript leg of a far A/B is now
  four times slower to shoot because it waits for what it asked for.
* **There is no `TODO.md` entry for distance v3.** Noticed while adding v4's.
  Left alone rather than invented.
* **The build is not in CI.** `gdext/bin/` is gitignored and nothing on GitHub
  Actions builds it, so the Windows artifact ships without the library and
  falls back to GDScript at `far_ring_div` 4 - which is a 45 s rebuild. That is
  the first thing the next rung has to fix, and it is a bigger deal after the
  flip than it was before it.

**Where the pictures are.** `build/` is gitignored, so every
`build/tour/<label>/...` path here is a file **on ganymede**. The sets this
document rests on are `s8-cpp` / `s8-gd` / `s8-cpp2` (the broken instrument)
and `s8b-cpp` / `s8b-gd` / `s8b-cpp2` (the fixed one).

---

## Addendum - the Windows bring-up (2026-09-01, gemini, not ganymede)

Stage 0's recipe, repeated on Marcel's Windows box the morning after the
merge: scons 4.11.1 via pip, godot-cpp at the same `26fb7ab`,
`extension_api.json` dumped from the same `4.7.2.stable.official.ed1daf0bf`,
MSVC 2022 Build Tools - which scons finds unaided, no developer prompt.
`gdext/bin/libkubik.windows.editor.x86_64.dll` in one build, and
`gdext/.gitignore` gains `*.obj` for MSVC's droppings.

| gate | result | provenance |
| --- | --- | --- |
| `-s gdext/check.gd` exits 0 | class exists true, ping answers, bench **21x** | gemini, single run |
| far dispatch through the real `FarField` | 391,872 verts, **54 ms C++ against 2,503 ms GDScript (46x)**, meshes identical | gemini, single run |
| full self-test | **`7 FAILED`, and all seven are last-bit rounding** | gemini, twice - the second with `/fp:strict`, byte-identical diffs |

**What the seven are.** The exact-zero gates doing their job on a new
compiler: the five parity cases at max colour diff 0.000000060-0.000000119
(one to two float ULPs - positions, normals and indices at ZERO in all five),
the pyramid's `slope` at 3.55e-15 (a double ULP), and zone parity's `vertex` -
the `Look.to_wire` chain - at one ULP. Geometry is bit-exact everywhere, `far
dispatch` passes with meshes identical, and the worst colour diff sits some
33,000x below one 8-bit colour step. The library is safe to play on, and
gemini now does.

**Why.** Stage 2's own comment names the assumption: "on one machine's libm
the same expression rounds the same way". That held on ganymede because gcc
compiled the transcription to round like the gcc-built engine. On Windows the
engine is one binary and the DLL is MSVC's; godot-cpp compiles ITS OWN copy of
the engine's Color arithmetic, and MSVC lands an expression in the
to_wire/jitter chain one ULP away. `/fp:strict` on the extension changes
nothing - measured, not assumed - so it is not contraction in our five files.

**For Marcel to rule on, item 5.** Either exact-zero is Linux doctrine - CI
runs it there (`.github/workflows/selftest.yml`, added with this addendum) and
a Windows dev checkout lives with `SELFTEST: 7 FAILED` as a known number - or
the COLOUR rows get a documented epsilon of two float ULPs (2.4e-7) while
geometry stays exact on every platform. Nothing was relaxed without the
ruling.

**And the carried CI item moved, halfway.** "The build is not in CI" (above):
`selftest.yml` now builds the Linux editor library and runs every gate on each
push to main, so the port can no longer rot silently. First run green -
33488522757, godot-cpp cold build included, ~11 minutes; cached runs are the
compile minus four of those.

**The half that stands is worse than carried: `build.yml` is RED, and has
been since the doorway.** Every push since `0ef02a0` added `kubik.gdextension`
fails at "Export Kubik.exe" - exit 1 after `savepack` completes, the log
naming the missing `libkubik.linux.editor.x86_64.so`. So the exe does not
ship WITHOUT the library; it does not ship AT ALL, and nobody was told,
because a red badge on a repo nobody watches is not a telling. Ruling item 4
(the three ERROR lines on library-less machines) and this are the same
decision now: the export needs either a cross-compiled
`windows.template_release` library in CI - with its own parity look - or an
export that tolerates a `.gdextension` naming platforms nobody built. It
stays carried, upgraded from silent to loud.
