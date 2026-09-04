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
7. **The near-band pixel gate needs a control run and gets one.**
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

- **The near-band picture gate was retired and replaced, on evidence.** The
  plan asks for zero differing pixels over the terrain rows; the film grain is
  full-frame animated noise and the flora ring settles differently every run, so
  two tours of the SAME commit differ by up to 6.7 mean luma levels over 26% of
  a frame. The exact array parity gates cover what the pixels were a proxy for,
  and cover more of the code than a tour does. Numbers above.
- The twin's retirement proposal lands at Stage 4.

## For Fable at merge

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

- Nothing yet.
