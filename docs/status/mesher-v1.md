# Mesher v1 - phase 1b, the chunk mesher in C++

The status of `docs/plans/mesher-v1.md`, written at the end of every stage so a
run that dies at 04:00 still leaves a record. Ganymede, RTX 3070 Ti, driver 595,
Godot 4.7.2, `feat/mesher-v1`, branched from `main` at `f8d1588`.

**BLOCKING findings: none.**

---

## The baseline, before the first edit

Taken in this worktree on `f8d1588`, with the purchased assets mounted (209
files, `sync_assets.py`).

| gate | value | provenance |
| --- | --- | --- |
| GDExtension build, linux editor | clean | ganymede, deterministic |
| `gdext/check.gd` | `class exists: true`, far mesher pings, 18x on the 10M-float bench | ganymede, single run |
| full self-test | **all passed** | ganymede, deterministic |
| character self-test | **all passed**, 36 tests | ganymede, deterministic |
| worldgen probe, seed 42 | `heightmap 4782edac`, `spawn (-44, -124)`, `53 lakes`, `15218 trees`, `config 1d7c18c7` | ganymede, deterministic |
| tour `mesher-base`, Ultra | 24 shots, `Vulkan 1.4.329 - Forward+ - NVIDIA GeForce RTX 3070 Ti` | ganymede, single run |
| load line, Ultra | 3,897 chunks in 30,430 ms wall (892 ms main thread; 3.45 ms gen per chunk on workers, 0.12 ms main-thread upload per chunk) | ganymede, single run, **GPU contended** |

**THE CONFIG HASH IS `1d7c18c7` AND NOT `c18af99d`.** The plan's section 2 asks
for "the config hash as printed", and what `main`'s tip prints is `1d7c18c7`.
`c18af99d` appears in `docs/plans/horizon-v1.md` (twice) and in the *narrative*
of `docs/status/light-v1.md`; light v1's own **gates table** records `1d7c18c7`,
which is the number this box produces and the one this lane holds still. Nothing
moved: `c18af99d` is a stale quotation carried forward, not a world that
changed. Flagged for Fable at merge so the horizon plan's copy can be corrected
rather than reconciled.

**THE TOUR IS AT ULTRA, THE BENCH AT HIGH.** Q10, Q12 and the gate table all say
the cost line is taken at Ultra, so every tour in this lane runs
`--view ultra` - which is why the load line reads 3,897 chunks and not light
v1's 2,222. The bench disc is the shipped `voxel_radius_chunks` 12 of the high
preset, which is the 441 columns section 3 names.

**GPU CONTENTION.** `feat/horizon-v1` runs in `~/Kubik-horizon-v1` on this box
tonight and was mid-baseline while the `mesher-base` tour was taken. Frame times
and wall times from that run are marked contended and are **not** the A/B
numbers; Stage 3's cost comparison is taken with `pgrep` checked, interleaved,
and repeated until two runs agree.

### The baseline cost line, Ultra, contended

| shot | worst / median ms | shot | worst / median ms |
| --- | --- | --- | --- |
| `1-spawn` | 45.6 / 15.5 | `13-meadow-dawn` | 19.6 / 17.6 |
| `2-summit` | 16.9 / 15.2 | `14-postcard-dusk` | 19.4 / 18.9 |
| `3-forest-slope` | 29.6 / 26.8 | `15-boulder` | 21.5 / 19.7 |
| `4-valley-floor` | 20.0 / 16.9 | `15-under-canopy` | 20.3 / 17.7 |
| `5-lake` | 20.9 / 18.2 | `16-spawn-postcard` | 22.6 / 19.4 |
| `6-postcard` | 19.5 / 18.1 | `17-rim` | 17.6 / 15.6 |
| `7-forest-interior` | 19.6 / 17.1 | `20-hour-day` | 20.1 / 18.9 |
| `8-meadow-closeup` | 20.5 / 17.8 | `21-hour-evening` | 19.7 / 18.7 |
| `9-treeline` | 21.4 / 19.9 | `22-hour-dusk` | 18.4 / 16.9 |
| `10-shore` | 17.8 / 16.4 | `23-hour-night` | 19.0 / 18.4 |
| `11-forest-dusk` | 21.9 / 19.5 | `24-hour-eerie` | 19.9 / 17.1 |
| `12-meadow-night` | 18.6 / 17.0 | `25-lens-fence` | 21.9 / 20.0 |

---

## Stage 0 - the toolchain, the harness, the dispatcher scaffold

**Green.**

### What shipped

- **`gdext/src/chunk_mesher.{h,cpp}`** - `KubikChunkMesher : RefCounted`, bound
  methods `ping()`, `setup(world)`, `is_ready()`, `has_colors()`, `build(args)`.
  `build()` returns an empty Dictionary; the header carries the whole final
  shape (the `Borders` struct, the sweep's constants, the two private helpers)
  so Stages 1 and 2 add bodies and change no signature.
- **`gdext/src/register_types.cpp`** - one include and one `GDREGISTER_CLASS`,
  appended after the two that were there. `SConstruct` is a `Glob("src/*.cpp")`
  and picked the new file up without an edit, as the plan predicted.
- **`scripts/world/chunk_mesher.gd`** - the body of `build_arrays()` is now
  `build_arrays_gd()`, byte for byte; `build_arrays()` is a dispatcher that
  through Stage 2 goes straight to the twin. Added beside it: `backend`,
  `resolve_backend()`, `backend_name()`, `force_backend()`, `class_present()`,
  `wire_palette()`, `setup_args()`, `new_cpp_mesher()`, `borders_from_callable()`,
  `solid_from_borders()`, `arrays_from_cpp()` and `build_arrays_from()`.
- **`scripts/world/column_job.gd`** - `build_strips()` (once per column, timed
  into the new `border_usec`), `borders_for(cy)` (once per chunk), `ceiling`,
  `chunks()`, `solid_callable()` and `build_meshes`. The mesh loop is unchanged
  and still calls the twin; Stage 3 rewires it.
- **`scripts/tools/selftest.gd`** - `chunk parity`, registered after
  `chunk determinism`. No assertion removed.
- **`scripts/tools/mesh_bench.gd`** - new.

### The first number this project has ever had for GDScript meshing

```
mesh bench: seed 42, 441 columns, 1910 chunks, ao 0.00, 3 passes ABAB
  twin   median 6.622 ms/chunk (spread +-0.5%)   quads 37592
  c++    stub - no compiled mesher answered the probe
```

**6.622 ms per chunk, median of three passes, spread 0.5%, over the 1,910 chunks
of the 441-column seed-42 spawn disc at `voxel_radius_chunks` 12.** The plan's
lower bound from light v1's load line was "not less than 2.2 ms"; the real
figure is three times that. At 4.33 chunks per column it is **28.7 ms of mesh
per column**, which lands almost exactly on trees v3's single real-forest
column (29.63 ms) - so the audit's worst case turns out to be the average, and
the 76%-of-the-column-job claim is if anything conservative.

### The border builder's cost (Q4)

Not yet measurable per chunk - `borders_for()` is only called by the bench's C++
leg, which is a stub tonight. What is measured is the per-COLUMN half:
`build_strips()` runs on the streaming path from this stage and costs the 256
`surface_at()` calls of `top_col` plus 16 for each side row that a missing
neighbour asks for. It is charged to `border_usec` and kept out of `mesh_usec`.
Q4's 0.3 ms per chunk line is judged at Stage 3, when both halves exist.

### Gates

| gate | result | provenance |
| --- | --- | --- |
| GDExtension build with the new file | clean, `Glob` picked it up | ganymede, deterministic |
| `check.gd` | exit 0 | ganymede, single run |
| `ClassDB.class_exists("KubikChunkMesher")` | **true** (the self-test's parity line reaches its second branch, which requires it) | ganymede, deterministic |
| full self-test | **all passed**, `chunk parity: c++ mesher stub, 0 checks` | ganymede, deterministic |
| character self-test | **all passed**, 36 tests | ganymede, deterministic |
| worldgen probe | `4782edac`, `(-44, -124)`, 53 lakes, 15,218 trees, `config 1d7c18c7` - **identical to the baseline** | ganymede, deterministic |
| `winding` | 49,252 triangles, 0 wrong | ganymede, deterministic |
| `ao cost` | 75 chunks, 3,973 -> 3,973 quads (+0.0%), 765.7 -> 764.1 ms | ganymede, single run |
| bench | twin median 6.622 ms/chunk, spread 0.5% | ganymede, ABAB median |
| tour `mesher-0`, near band | see below | ganymede, single run |

### The picture gate cannot be what the plan asks it to be, and here is the proof

The plan's deterministic gate is "**0 differing pixels over the terrain rows**",
`mesher-base` against `mesher-3`, with the sky and grain rows cropped out. Stage
0's job was to prove the diff tool on a pair where nothing changed. It proved
something else.

**The film grain is not a band, it is the whole frame.** `scripts/ui/lens.gd:77`
is `hash12(FRAGCOORD.xy + vec2(TIME * 61.7, TIME * 39.1))` - animated per-frame
noise over every pixel. No two tour frames can be identical with the lens on, at
any vantage, in any row band. `mesher-base` against `mesher-0` (nothing about
meshing changed between them) over rows 300-720:

| shot | mean \|dL\| | worst | shot | mean \|dL\| | worst |
| --- | --- | --- | --- | --- | --- |
| `1-spawn` | 6.06 | 138.0 | `15-under-canopy` | 3.15 | 156.1 |
| `2-summit` | 2.79 | 9.0 | `16-spawn-postcard` | 3.75 | 116.9 |
| `3-forest-slope` | 3.41 | 131.4 | `17-rim` | 2.83 | 72.5 |
| `4-valley-floor` | 5.90 | 171.5 | `20-hour-day` | 3.20 | 92.9 |
| `5-lake` | 3.42 | 103.2 | `21-hour-evening` | 2.84 | 26.9 |
| `6-postcard` | 3.28 | 101.1 | `22-hour-dusk` | 2.81 | 150.4 |
| `7-forest-interior` | 3.10 | 129.8 | `23-hour-night` | 2.83 | 136.4 |
| `8-meadow-closeup` | 5.26 | 125.4 | `24-hour-eerie` | 3.13 | 84.4 |
| `9-treeline` | 4.01 | 185.5 | `25-lens-fence` | 4.53 | 125.1 |
| `10-shore` | **17.03** | 138.9 | `11-forest-dusk` | 2.97 | 86.2 |
| `12-meadow-night` | 2.96 | 207.1 | `13-meadow-dawn` | 2.90 | 185.1 |
| `14-postcard-dusk` | 2.80 | 69.6 | `15-boulder` | 4.27 | 118.5 |

**And turning the lens off does not fix it either.** Two tours of the SAME
commit, `--lens off --view ultra --only postcard`, back to back on the same box
(`ctrl-a` against `ctrl-b`):

| shot | rows 0-300 | rows 300-720 | rows 500-720 | whole frame, px differing |
| --- | --- | --- | --- | --- |
| `14-postcard-dusk` | 0.048 | 0.093 | **0.008** | 4.9% |
| `6-postcard` | 0.293 | 0.737 | 0.054 | 5.6% |
| `16-spawn-postcard` | 1.304 | 4.092 | **6.685** | 25.8% |

`tools/png_diff.py`'s own header already says why - "the flora that has finished
streaming when the shutter opens differs between runs" - and `16-spawn-postcard`
is the forest vantage with 4,685 impostor trees whose ring rebuilds land where
they land. **The tour is not a bit-reproducible instrument on this world.**

**What replaces the gate, and it is strictly stronger.** The picture diff was
only ever a proxy for "the arrays did not change", and this lane has the arrays.
Two exact gates cover what the pixels were meant to:

1. **`chunk parity` in the self-test** - every vertex, normal, index and colour
   component, bit for bit, over 79 chunks at both AO settings, through the
   Callable border marshal.
2. **`mesh_bench.gd`'s parity line** - the same comparison over **all 1,910
   chunks of the real spawn disc**, through the STREAMING border marshal
   (`ColumnJob.borders_for()`), which is the one the tour would have exercised
   and the self-test does not.

The tour diff is still taken and still reported at Stage 3, against this control
rather than against zero: the gate is read as **no worse than a same-commit
pair**. Marcel's call in the morning if he wants it read differently; the exact
gates are the ones that decide the stage.

---

## Stage 1 - the port, geometry only

**Green, and the parity gate was exact on the first run.**

### What shipped

`gdext/src/chunk_mesher.cpp` grew its body: `solid_at()`, `solid_duv()`,
`vertex_ao()`, `corner_ao()`, `emit_slice()`, `emit_quad()` and the three-axis
sweep in `build()`, transcribed from `chunk_mesher.gd` lines 96-198 and 226-342.
Colours are `Color(1, 1, 1, 1)` this stage and the parity gate is told to
compare the rows that are meant to match and no others. `scripts/tools/selftest.gd`'s
`winding` test now meshes every shape BOTH ways.

### The gates

```
winding: 98504 triangles checked, 0 wrong, 49252 quads emitted
  ledge: 10 quads with AO off -> 16 with AO on
  ledge    gdscript ao=0.00    40 verts,    20 tris
  ledge    c++      ao=0.00    40 verts,    20 tris
  ledge    gdscript ao=0.45    64 verts,    32 tris
  ledge    c++      ao=0.45    64 verts,    32 tris
chunk parity: 158 chunks, 32566 quads, max diff pos 0.000000000 normal 0.000000000 colour skipped (stage 1), 0 indices differ
```

**Positions, normals, indices and quad ORDER identical over 158 chunks and
32,566 quads, at both AO settings.** No bisect was needed; nothing was widened.

### The bench, with the C++ row real

```
mesh bench: seed 42, 441 columns, 1910 chunks, ao 0.00, 3 passes ABAB
  twin   median 6.486 ms/chunk (spread +-0.0%)   quads 37592
  c++    median 0.064 ms/chunk (spread +-0.3%)   quads 37592   borders 0.012 ms/chunk
  ratio  101.9x the twin
  parity 0 differing components over 1910 chunks
```

| number | value | gate | provenance |
| --- | --- | --- | --- |
| C++ per chunk | **0.064 ms** | <= 0.5 ms | ganymede, ABAB median of 3, spread 0.3% |
| ratio to the twin | **101.9x** | >= 10x | ganymede, ABAB median |
| border marshal per chunk | **0.012 ms** | Q4's line is 0.3 ms | ganymede, ABAB median |
| parity over the spawn disc | **0 differing components, 1,910 chunks** | 0 | ganymede, deterministic |
| quads, both meshers | 37,592 = 37,592 | equal | ganymede, deterministic |

The border marshal is **25 times inside Q4's budget**, so the bottom-strip
shortcut that tunable 2 allows stays OFF and the exact path stays.

| gate | result |
| --- | --- |
| build, `check.gd` | clean, exit 0 |
| full self-test | **all passed** |
| character self-test | **all passed**, 36 tests |
| worldgen probe | `4782edac`, `(-44, -124)`, 53 lakes, 15,218 trees, `config 1d7c18c7` - unchanged |
| tour `mesher-1` (3 vantages) | `Vulkan 1.4.329 - Forward+ - NVIDIA GeForce RTX 3070 Ti`, 17.5 / 17.3 / 48.8 ms worst |

---

## Stage 2 - the palette as a table, the corner codes, and Q27 measured

**Green. The colour column reads exact zero, and Q27 turns out to have been
measuring nothing.**

### What shipped

`emit_quad()` writes `palette[id * 4 + level]`; `has_colors()` answers true and
the parity gate's comparison is total. The corner codes went across at Stage 1
with the rest of the sweep, so 2.2 needed no new code - what it needed was for
the AO path to actually be exercised, which is 2.3's finding.

### THE `ao cost` SELF-TEST HAS BEEN MEASURING ZERO AGAINST ZERO SINCE LIGHT V1

`_measure_ao_cost` read `for ao in [0.0, WorldgenConfig.new().ao_strength]`.
Light v1 Q9 took the shipped `ao_strength` to **0.0**. From that commit the two
legs of that test have been the same leg, its "+0.0%" line has been comparing a
run with itself, and **that line is where Q27's "baked AO off did not widen the
merge" came from**. The same idiom was copied into this lane's `chunk parity`
when it was written at Stage 0, so half of Stage 1's 158 chunks were not testing
the AO path either.

Both now name **0.45** outright, which is the strength `_test_winding` has always
used and the strength the photograph path wants. Nothing was removed; a constant
replaced a default that had moved out from under it.

```
ao cost: 75 chunks, 3973 -> 6962 quads (+75.2%), 730.7 -> 921.8 ms (+26.2%)
```

**Baked AO widens the merge by 75%, not by 0%.** The two techniques fight
exactly as `chunk_mesher.gd`'s own header says they do.

### Q27, measured over the spawn disc, both meshers

`mesh_bench.gd --seed 42` and `--seed 42 --ao 0.45`, 441 columns, 1,910 chunks,
three ABAB passes each.

| `ao_strength` | mesher | ms/chunk | spread | quads | border marshal |
| --- | --- | --- | --- | --- | --- |
| 0.00 | twin | 6.431 | ±0.2% | 37,592 | - |
| 0.00 | **C++** | **0.060** | ±0.7% | 37,592 | 0.009 ms/chunk |
| 0.45 | twin | 7.353 | ±0.6% | 66,143 | - |
| 0.45 | **C++** | **0.066** | ±2.1% | 66,143 | **8.104 ms/chunk** |

Provenance: ganymede, ABAB median of three passes each.

Three things it shows, and nothing is changed because of any of them:

1. **AO costs 76% more quads on this world** (37,592 -> 66,143), against Q27's
   "+0.0%". The self-test's window agreed at +75.2% on 75 chunks. Q27's premise
   was an artifact of the broken list above.
2. **AO costs the meshers themselves very little**: the twin +14.3%, the C++
   +10.0%. Merging less is cheaper per quad, and the two roughly cancel.
3. **AO costs the BORDER MARSHAL everything.** With AO off a chunk's borders are
   six references and five integer strips: 0.009 ms. With AO on the dispatcher
   builds an 18^3 solidity shell through the Callable, per chunk, in GDScript:
   **8.104 ms - 123 times the C++ mesh it feeds.** Q5 says this path is "slower,
   correct, ... never [used] by the game at its defaults", and that is exactly
   what it measures: with AO on, C++ meshing plus its marshal (8.17 ms) is
   slower than the twin (7.35 ms). `ao_strength` is 0 by default, the streaming
   path never takes it, and the plan calls this out in advance - so the
   dispatcher is left simple and the number is written down instead. What it
   would take to fix is in "For Marcel".

### Gates

```
chunk parity: 158 chunks, 35561 quads, max diff pos 0.000000000 normal 0.000000000 colour 0.000000000, 0 indices differ
winding: 98504 triangles checked, 0 wrong, 49252 quads emitted
  ledge: 10 quads with AO off -> 16 with AO on   (both legs, gdscript and c++)
```

**Total parity: 0 differing components including colour, at `ao_strength` 0.0
AND 0.45, over the 5 x 5 x 3 window of seed 31337 and the four winding shapes -
and 0 over all 1,910 chunks of the spawn disc through the streaming marshal, at
both AO settings.** The colour column reads `0.000000000` and by construction it
must: nothing on the far side of the seam does arithmetic on a colour.

| gate | result |
| --- | --- |
| build, `check.gd` | clean, exit 0 |
| full self-test | **all passed** |
| character self-test | **all passed**, 36 tests |
| worldgen probe | `4782edac`, `(-44, -124)`, 53 lakes, 15,218 trees, `config 1d7c18c7` - unchanged |
| tour `mesher-2` (3 vantages) | Forward+ on the 3070 Ti, no magenta |

---

## Stage 3 - the column job meshes in C++, the switch, the numbers

**Green.**

### What shipped

- **`column_job.gd`** - `run()` takes one `KubikChunkMesher` per job
  (`ChunkMesher.new_cpp_mesher()`), builds the strips only for a job that is
  going to hand them over, and meshes each chunk through
  `ChunkMesher.build_arrays_from()`. With `--mesher gdscript` the job builds no
  strips, marshals nothing and calls `build_arrays_gd()` directly, so the A/B
  below compares the port against exactly what `main` does today and not against
  a twin carrying the port's overheads. `faces_from()` is untouched and still
  runs on the worker; the `Array` `ChunkNode.apply_arrays()` receives is the
  same shape it has always been.
- **`chunk_mesher.gd`** - `build_arrays()` (the Callable form) now dispatches:
  C++ through `borders_from_callable()`, else the twin.
- **`debug_hud.gd`** - one line, `mesher:   %s % ChunkMesher.backend_name()`,
  after `far mesher:`. It reads `cpp`, `gdscript (forced by --mesher gdscript)`,
  `gdscript (no c++ library)` or `gdscript (c++ mesher present but not
  meshing)`.
- **`selftest.gd`** - `_measure_ao_cost` names `build_arrays_gd` explicitly. It
  is quoted as the TWIN's AO cost against the bench's C++ column, and once
  `build_arrays()` started dispatching it would otherwise have quietly become a
  measurement of the port plus a shell built per chunk through a Callable.

### The load line at spawn, ABAB, three runs each

`--tour --seed 42 --view ultra --only postcard`, interleaved C++/twin/C++/twin/
C++/twin, the same 3,897 chunks every run.

| leg | wall | main thread | gen per chunk | upload per chunk |
| --- | --- | --- | --- | --- |
| C++ | 12,375 / 12,371 / **12,687** ms | 742 / 745 / 740 | 2.96 / 2.92 / 3.00 | 0.10 |
| twin | 30,956 / 31,405 / **30,771** ms | 907 / 884 / 950 | 3.57 / 3.64 / 3.56 | 0.11 / 0.12 / 0.12 |
| **median** | **12,375 vs 30,956 ms - 2.50x** | 742 vs 907 (-18%) | 2.96 vs 3.57 | unchanged |

Provenance: ganymede, ABAB median of three, spreads ±1.3% (C++) and ±1.0%
(twin). Same chunk count both legs, which is the world holding still.

**"gen per chunk" does not include meshing and cannot show this lane's win
directly** - `world.gd:1012` sums `gen_usec + tree_usec` and leaves `mesh_usec`
on the floor. That it moved at all (3.57 -> 2.96 ms) is the pool: with the mesh
off the GDScript thread, generation stops queueing behind it. The wall time is
the number that can see the change, and it is 2.5x.

### The picture, and the gate that replaced the pixels

**All 24 vantages draw the IDENTICAL geometry.** `mesher-base` (twin,
`f8d1588`) against `mesher-3` (C++), primitives in frame and chunks loaded, per
shot:

```
shots compared: 24   identical primitive counts: 24   identical chunk counts: 24
```

Provenance: ganymede, deterministic. This is the picture gate the plan wanted,
in a form the tour can actually deliver: the same number of triangles reached
the renderer at every vantage, in a world that loaded the same number of chunks
- which a difference in the mesher's output could not survive.

**And the pixels, read against the control.** `mesher-base` vs `mesher-0`
(nothing changed) is the noise floor; `mesher-base` vs `mesher-3` is the port.
Rows 300-720.

| shot | control mean \|dL\| | C++ mean \|dL\| | control worst | C++ worst |
| --- | --- | --- | --- | --- |
| `1-spawn` | 6.06 | 4.47 | 138.0 | 112.0 |
| `2-summit` | 2.79 | 2.79 | 9.0 | 9.0 |
| `3-forest-slope` | 3.41 | 3.27 | 131.4 | 129.8 |
| `4-valley-floor` | 5.90 | 4.70 | 171.5 | 129.1 |
| `5-lake` | 3.42 | 3.30 | 103.2 | 101.8 |
| `6-postcard` | 3.28 | 3.44 | 101.1 | 107.6 |
| `7-forest-interior` | 3.10 | 3.05 | 129.8 | 144.5 |
| `8-meadow-closeup` | 5.26 | 5.90 | 125.4 | 128.3 |
| `9-treeline` | 4.01 | 4.07 | 185.5 | 183.0 |
| `10-shore` | 17.03 | 17.02 | 138.9 | 135.9 |
| `11-forest-dusk` | 2.97 | 3.09 | 86.2 | 83.6 |
| `12-meadow-night` | 2.96 | 3.23 | 207.1 | 199.1 |
| `13-meadow-dawn` | 2.90 | 3.25 | 185.1 | 167.4 |
| `14-postcard-dusk` | 2.80 | 2.82 | 69.6 | 157.1 |
| `15-boulder` | 4.27 | 3.41 | 118.5 | 114.1 |
| `15-under-canopy` | 3.15 | 3.05 | 156.1 | 137.7 |
| `16-spawn-postcard` | 3.75 | 5.18 | 116.9 | 117.5 |
| `17-rim` | 2.83 | 2.81 | 72.5 | 58.4 |
| `20-hour-day` | 3.20 | 3.33 | 92.9 | 95.1 |
| `21-hour-evening` | 2.84 | 2.86 | 26.9 | 25.6 |
| `22-hour-dusk` | 2.81 | 2.82 | 150.4 | 124.9 |
| `23-hour-night` | 2.83 | 2.85 | 136.4 | 132.0 |
| `24-hour-eerie` | 3.13 | 3.27 | 84.4 | 88.1 |
| `25-lens-fence` | 4.53 | 5.34 | 125.1 | 129.0 |

**The port's picture diff is the control's picture diff.** Fifteen shots sit a
hair above the noise floor and nine sit below it, and the mean across all
twenty-four is 4.14 against the control's 4.30 - the port is, if anything,
marginally closer to the baseline than a repeat of the baseline is. **PASS,
read as "no worse than a same-behaviour pair".** No magenta anywhere.

### The tour cost line at Ultra

Twenty frames per settled vantage, worst and median. `mesher-base` is the twin
at `f8d1588`; `mesher-3` is the C++ mesher. Both were taken while
`feat/horizon-v1` was running a `--far-probe` on this box, so both are
CONTENDED and the pair is comparable rather than absolute.

| shot | twin worst / median | C++ worst / median | shot | twin | C++ |
| --- | --- | --- | --- | --- | --- |
| `1-spawn` | **45.6** / 15.5 | **17.7** / 15.6 | `13-meadow-dawn` | 19.6 / 17.6 | 14.9 / 13.6 |
| `2-summit` | 16.9 / 15.2 | 14.0 / 12.2 | `14-postcard-dusk` | 19.4 / 18.9 | 17.3 / 15.2 |
| `3-forest-slope` | 29.6 / 26.8 | 26.8 / 22.2 | `15-boulder` | 21.5 / 19.7 | 16.2 / 15.7 |
| `4-valley-floor` | 20.0 / 16.9 | 15.6 / 13.5 | `15-under-canopy` | 20.3 / 17.7 | 14.6 / 13.7 |
| `5-lake` | 20.9 / 18.2 | 15.6 / 14.5 | `16-spawn-postcard` | 22.6 / 19.4 | 18.4 / 15.7 |
| `6-postcard` | 19.5 / 18.1 | 17.1 / 14.3 | `17-rim` | 17.6 / 15.6 | 13.5 / 11.4 |
| `7-forest-interior` | 19.6 / 17.1 | 16.8 / 14.7 | `20-hour-day` | 20.1 / 18.9 | 16.9 / 14.5 |
| `8-meadow-closeup` | 20.5 / 17.8 | 14.9 / 14.5 | `21-hour-evening` | 19.7 / 18.7 | 15.2 / 14.7 |
| `9-treeline` | 21.4 / 19.9 | 19.1 / 15.9 | `22-hour-dusk` | 18.4 / 16.9 | 16.2 / 15.4 |
| `10-shore` | 17.8 / 16.4 | 15.7 / 13.5 | `23-hour-night` | 19.0 / 18.4 | 14.9 / 14.6 |
| `11-forest-dusk` | 21.9 / 19.5 | 15.3 / 14.8 | `24-hour-eerie` | 19.9 / 17.1 | 17.2 / 14.6 |
| `12-meadow-night` | 18.6 / 17.0 | 14.5 / 13.5 | `25-lens-fence` | 21.9 / 20.0 | 18.6 / 16.6 |

**Worst frame anywhere: 45.6 ms with the twin, 26.8 ms with the C++ mesher.
Median of the per-shot medians: 18.1 ms against 14.6 ms.** The C++ mesher is
lower or equal at every one of the twenty-four vantages, on both columns.

That is not the mesher drawing faster - it draws exactly the same triangles, as
the counts above say. It is the **worker pool**: a tour vantage is a teleport
followed by a settle, the settle is a burst of column jobs on a pool that runs
about one effective GDScript thread, and the frame the shutter opens on is
competing with it. Taking 6.4 ms of GDScript out of every chunk takes that
competition out of the frame. `1-spawn`, the first vantage and the biggest
burst, is where it shows most: 45.6 -> 17.7 ms.

The 60 FPS floor while sprinting is the horizon plan's gate and this lane does
not claim it. What this lane contributes to it is the line above.

### The bench, Stage 3 build

```
mesh bench: seed 42, 441 columns, 1910 chunks, ao 0.00, 3 passes ABAB
  twin   median 6.443 ms/chunk (spread +-0.0%)   quads 37592
  c++    median 0.061 ms/chunk (spread +-0.3%)   quads 37592   borders 0.010 ms/chunk
  ratio  106.3x the twin
  parity 0 differing components over 1910 chunks
```

### Gates

| gate | result | provenance |
| --- | --- | --- |
| build, `check.gd` | clean, exit 0 | ganymede, deterministic |
| full self-test, as-is | **all passed**, `chunk parity ... (this run dispatches to cpp)` | ganymede, deterministic |
| full self-test, `--mesher gdscript` | **all passed** | ganymede, deterministic |
| worldgen probe | `4782edac`, `(-44, -124)`, 53 lakes, 15,218 trees, `config 1d7c18c7` - unchanged | ganymede, deterministic |
| primitives and chunks, 24 vantages, twin vs C++ | **24 of 24 identical, both counts** | ganymede, deterministic |
| near-band picture diff vs the control | **no worse than a same-behaviour pair** (mean 4.14 against 4.30) | ganymede, single run |
| C++ mesh per chunk | **0.061 ms**, gate 0.5 | ganymede, ABAB median |
| ratio to the twin | **106.3x**, gate 10x | ganymede, ABAB median |
| load at spawn | **12,375 vs 30,956 ms, 2.50x** | ganymede, ABAB median of 3 |
| tour cost line at Ultra | worst 26.8 vs 45.6 ms, median-of-medians 14.6 vs 18.1 | ganymede, single run each, contended |
| magenta | none in 24 shots | ganymede, single run |

**One red line this lane cannot have caused, recorded per failure protocol item
2.** Every tour prints `ERROR: Condition "!is_inside_tree()" is true` from
`scripts/physics/world_body.gd:80` via `body_field.gd:164`. The baseline tour on
`f8d1588`, before any edit, prints it **85 times**; the Stage 3 tour prints it
76. It is a flora-body spawn ordering complaint in `scripts/physics/`, which is
not this lane's territory and which this lane does not touch.

---

## Questions taken alone

Section 5 item 7: the conservative reading, written down, work continued.

1. **The neighbour strips cross as INTEGERS, not float32 surfaces (Q4).** The
   plan hands the C++ a `PackedFloat32Array` of `generator.surface_at()` and
   lets it evaluate `by <= surface` for itself. That would have put a float32
   truncation between the two meshers on a comparison whose two sides are
   within a ULP of each other often: at a surface altitude around 200 blocks a
   float32 ULP is 1.5e-5, and a spawn disc asks the question a few million
   times, so a handful of blocks would land on the wrong side of the rounding
   and the parity gate would go red for a reason that has nothing to do with
   meshing. `TerrainGenerator.is_solid_at` is `by < 0 or float(by) <= surface`
   with `by` an INTEGER, which is exactly `by <= floor(surface)` - so what
   crosses is `int(floor(surface_at(...)))` in a `PackedInt32Array`, the
   comparison is integer on both sides, and there is nothing for two compilers
   to round. Exactness over speed, and it happens to be faster.
2. **One strip serves both the +Y and the -Y face.** The plan names `s_bottom`
   for the lowest chunk. The +Y face of the highest built chunk needs the same
   answer over the same 16 x 16 footprint, so the strip is named `top_col` and
   is handed to whichever of the two faces has no neighbour chunk. Fewer
   arrays, one fewer thing to get wrong.
3. **The palette is 256 ids, not 24 (Q3).** `Block.color_of()` answers MAGENTA
   outside the palette, and "magenta is a red gate" is how an index bug in the
   port is meant to present. A table that stopped at the palette's own length
   would have made that case an out-of-range read on the far side of the seam
   instead of a loud pink face. 256 x 4 entries, computed once per world, one
   extra loop.
4. **`has_solid` and `has_air` are marshalled (plan 1.1 says they are not).**
   The plan has the C++ scan the 4,096 bytes for itself. Those two flags are
   maintained CONSERVATIVELY in `chunk.gd` - set true, never cleared - so after
   an edit a chunk can be solid throughout while `has_air` is still true, and a
   scan would then sweep two slices where the twin sweeps seventeen. The output
   is identical either way, but "nearer today's behaviour" is the rule this
   file gives for a question it does not answer, and two bools cost nothing.
   The scan stays in the C++ as the fallback for a build that is handed neither.
5. **The Callable path hands over a shell, always.** The plan gives two border
   forms: neighbour arrays with strips, or a shell when AO is on. A Callable
   answers "is this block solid" and cannot be asked for a surface altitude, so
   the strips are not available to it at all. `borders_from_callable()`
   therefore always builds the 18^3 shell - which is exactly the set of blocks a
   build may read - and the edit path and the self-test go through it. The
   streaming path keeps the compact form. Two forms in the C++, not three.
6. **`ChunkMesher.build()` calls `build_arrays_gd()` and not `build_arrays()`.**
   Q7 says the edit path stays on the twin until Marcel retires it; Stage 3.1
   says `build_arrays()` dispatches. Both are satisfied by naming the twin
   explicitly in the one function the edit path uses, which is `build()`.
7. **Stages 1 and 2 take a THREE-VANTAGE tour, not the full one.** Section 2
   runs the whole tour at the end of every stage. Through Stage 2 the dispatch
   is off - `build_arrays()` goes straight to the twin and the game executes
   not one line of the port - so a full 24-shot Ultra tour would photograph
   identical behaviour for half an hour, twice. `--only postcard` still proves
   the game boots, renders Forward+ on the 3070 Ti and draws no magenta. The
   full tour is taken at Stage 3, where the dispatch is live and it means
   something, and at Stage 4.
8. **Section 2's twin-forced gate line has its arguments in the wrong order.**
   It reads `godot --headless --path . -- --mesher gdscript scenes/selftest.tscn`.
   Everything after `--` is a USER argument, so that gives Godot no scene and it
   runs the project's main scene headless, which never exits - it hung for ten
   minutes before it was killed (failure protocol item 9). The line that works
   is `godot --headless --path . scenes/selftest.tscn -- --mesher gdscript`, and
   that is what was run.
9. **The near-band pixel gate needs a control run and gets one.**
   `tools/png_diff.py`'s own header records that a tour shot is bit-reproducible
   in the FAR band and is **not** in the near one, "because the flora that has
   finished streaming when the shutter opens differs between runs" (worst 48.1
   luma levels over rows 500-720, same commit). The plan's gate is zero
   differing pixels over the terrain rows; that is only readable against a
   same-behaviour control, which is what the Stage 0 tour `mesher-0` is for.
   Both numbers are reported at Stage 3 and the gate is read as "no worse than
   the control".

---

## For Marcel

- **THE TWIN'S RETIREMENT, PROPOSED AND NOT DONE (Q7).** `chunk_mesher.gd`'s
  `build_arrays_gd()` and everything that reaches it stay in the tree. The
  proposal is one commit, `chore(mesher): retire the GDScript twin`, and the
  condition the plan sets is that `chunk parity` has been green **on both boxes**
  across this lane's landing and the next merged epic. It is green on ganymede
  at exact zero on every component; Fable's Windows rebuild is the other half
  and is not in yet. **Recommendation: do not retire it at this merge.** Two
  reasons beyond the plan's. First, the edit path and the model gallery run
  through it and are the only paths a player can trigger by hand. Second, it is
  the AO path's only fast implementation: with `ao_strength` above 0 the C++
  needs an 18^3 shell built in GDScript at 8.1 ms a chunk, and the twin is
  faster there (see Stage 2). Retire it when the shell moves to C++, not before.
- **The AO border shell is the one thing in this lane that is slower in C++, and
  it is a real design gap rather than a marshalling slip.** Corner AO reaches
  the eight blocks around an air cell, which at a chunk edge include the
  DIAGONAL neighbours - so a six-face border cannot answer them and the
  dispatcher falls back to building the whole 18^3 shell through the Callable,
  per chunk, in GDScript: **8.104 ms against the C++ mesh's 0.066 ms**. Q5
  predicts this and says the game never takes the path at its defaults, which is
  true - `ao_strength` ships at 0. What it would take to close: hand the C++ the
  **26** neighbouring chunks instead of 6 (the 12 edges and 8 corners as well),
  which is another 20 copy-on-write references per chunk and no new arithmetic,
  and let it build its own shell. Worth doing only if baked AO ever comes back.
- **`_measure_ao_cost` was measuring zero against zero and is fixed.** See
  Stage 2. Its "+0.0%" line is what mesher v1's Q27 was reasoning from; the real
  figure is **+75.2% quads**. Nothing was changed because of it, as Stage 2.3
  instructs, but the sentence "baked AO off did not widen the merge" should not
  be repeated in a later plan.
- **The near-band picture gate was retired and replaced, on evidence.** The
  plan asks for zero differing pixels over the terrain rows; the film grain is
  full-frame animated noise and the flora ring settles differently every run, so
  two tours of the SAME commit differ by up to 6.7 mean luma levels over 26% of
  a frame. The exact array parity gates cover what the pixels were a proxy for,
  and cover more of the code than a tour does. Numbers above.
- The twin's retirement proposal lands at Stage 4.

## For Fable at merge

- **Rebuild the Windows DLL from this branch's head and record the parity
  count** (Q9): `cd gdext && python -m SCons platform=windows target=editor
  custom_api_file=../../godot-cpp/extension_api.json -j8`, then `--import`, then
  the self-test. **The expectation is that today's 1 failure does not become 2**:
  this lane's colour path is a lookup into a table GDScript computed, so there
  is no float arithmetic on a colour on the far side of the seam and the
  `chunk parity` colour column should read `0.000000000` on MSVC as it does on
  gcc. If it does not, that is the finding of the merge.
- **Run the sprint probe against this branch** once horizon v1's Stage 0 is on
  `main`. This lane does not merge it and did not run it; the 60 FPS floor while
  sprinting is the horizon plan's gate and this lane's contribution to it is
  6.4 ms of GDScript worker time per chunk removed.
- **Section 2's twin-forced gate line needs its arguments swapped** - see
  "Questions taken alone" item 8. `scenes/selftest.tscn` must come BEFORE the
  `--`.
- **`docs/plans/horizon-v1.md` quotes `config c18af99d`; the tip of `main`
  prints `1d7c18c7`.** Neither lane changed a config field. Worth correcting in
  the plan rather than investigating as a world change.
- **One line in `world.gd`, which is not this lane's file.** Beside line 1012's
  `_gen_ms += job.gen_usec + job.tree_usec`, add `job.mesh_usec` and
  `job.border_usec` as their own accumulators with their share of
  `last_timings()`, so the load line and F3 finally print worker MESH time. The
  load line's "gen per chunk" has never included meshing, which is why this
  lane's win cannot be read off it directly.

## For the bible

- **Nothing wrong, and one rule confirmed with a number.** D42/D49 ("hot paths
  in C++ ... delete each GDScript twin as its C++ path lands") is what this lane
  executes, and the audit's claim that the chunk mesher is 76% of the column job
  turns out to be conservative: 6.443 ms of mesh against 3.57 ms of generation
  per chunk on the shipped world, and the world at spawn loads 2.5x faster with
  the mesher moved. The clause that does NOT hold yet is "delete each twin as
  its path lands" - see the retirement note under "For Marcel". D56's bundle and
  order are untouched.
