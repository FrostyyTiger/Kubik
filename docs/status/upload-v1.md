# Upload v1 - status

The run of `docs/plans/upload-v1.md`, on ganymede, in `~/Kubik-upload-v1` on
`feat/upload-v1`, started 2026-09-05. Unattended, one night and the day after,
in one session, with no other lane on the box.

Written at the end of **every stage**, not at the end of the night, so a run
that dies at 04:00 still leaves a record.

---

## BLOCKING

**THE PLAN'S PREMISE DOES NOT REPRODUCE, AND THE LANE IS SMALLER THAN IT WAS
WRITTEN TO BE.** `docs/plans/upload-v1.md` opens on horizon v1's measurement of
`main` with both lanes merged: *"the median rises to 22.1 ms with 786 to 807
hitches"*, and the whole work order is aimed at that. Measured tonight on the
base worktree - `main` at `146f061`, the same sprint, the same seed, the same
preset, the same box, **quiet**:

```
base-s0-1   median 6.90 ms   p99 8.33   worst 41.38   over 25 ms: 3    13,002 chunks
base-s0-2   median 6.90 ms   p99 8.33   worst 26.15   over 25 ms: 1    13,081 chunks
```

**`main` runs the north star's sprint at 6.90 ms with one to three frames over
25 ms out of about 8,590.** The median half of the frame gate is met with a
2.4x margin and the hitch half is three frames away from met.

The chunk count says it is the same walk: 13,002 and 13,081 against horizon's
12,862 and 12,871, and `moved_m=543`, `jumps=9` in every run of both. **What
differs is the box.** Horizon v1's Stage 7 was taken with `docs/plans/
mesher-v1.md` running in the other lane on the same six-core machine - its own
document says so in its first paragraph - and its two merged runs were taken in
a throwaway worktree while that lane was still live. Tonight nothing else runs.

**This is not a reason to stop, and it is a reason to re-scope.** The split
below is still the deliverable and it still names the shares; Stages 2 and 3
are still worth attempting on those shares. What has changed is what a rung can
be expected to buy: the upload is **3.8% of wall-clock time over the sprint**,
not the frame's binding cost, and the hitch gate is now a question about two or
three frames rather than eight hundred. Recorded here at the top because it
changes what "PASS" at Stage 7 will mean, and because Marcel should see it
before he reads a table of rungs that each move a few tenths of a millisecond.

---

## The canonical world line

Reprinted after every stage. One changed character is a red gate (plan § 0).

```
heightmap 4782edac   spawn (-44, -124)   53 lakes   15218 trees   config 1d7c18c7
```

Measured on the base worktree before the first edit and on the branch at the
end of Stage 0. Character for character, both.

---

## The baseline, 2026-09-05, before the first edit

Base worktree `~/Kubik-upload-v1-base`, `main` at `146f061`, assets mounted,
the GDExtension built.

| instrument | result |
| --- | --- |
| `gdext/check.gd` | **class exists: true**, C++ 18x GDScript on the seam bench |
| `scenes/selftest.tscn` | **SELFTEST: all passed** |
| `worldgen_probe --seed 42` | heightmap `4782edac`, spawn `(-44, -124)`, 53 lakes, **15,218 trees**, config `1d7c18c7` |
| heightmap build | 1500x1500 cells, 12 x 12 tiles of 512 blocks, median 10 ms, builder c++ |
| the sprint | **6.90 ms median, 1 to 3 frames over 25 ms** - see BLOCKING |
| the load at spawn | 5,266 to 5,324 chunks in 15,988 to 16,780 ms wall, 0.11 ms main-thread upload per chunk |

---

## Stage 0 - the instrument, and the split

**Green.** Everything 0.1 to 0.5 asks for exists, exits, and is measured below.

### What shipped

| file | what |
| --- | --- |
| `scripts/world/world.gd` | The seven counters of plan § 3 (`up_node_us` ... `up_col_max_us`), six `Time.get_ticks_usec()` pairs around the parts of `_collect_chunks` and `_collect_flora`, `take_upload_split()` and `upload_totals()`, the split printed once at `_initial_load_reported`, and - mesher v1's "For Fable at merge" request - `_worker_mesh_ms` and `_worker_border_ms` beside `_gen_ms`, on the load line and in `last_timings()`. |
| `scripts/world/chunk_node.gd` | `apply_arrays()` split into `apply_mesh(arrays, want_mesh)` and `apply_collision(faces)`, with `apply_arrays` kept as the two called in the old order. Behaviour-preserving; it is what lets the instrument time the two halves apart, and it is Stage 2's precondition. |
| `scripts/tools/sprint_probe.gd` | The per-second line gains `up=<node>/<mesh>/<shape>/<edit>/<flora>/<bodies> colmax=<us>`; the summary gains `up_node_ms=` ... `up_bodies_ms=` and `up_col_max_ms=`. The last partial second is drained into the totals so the six fields add up to the whole sprint. |
| `scripts/tools/upload_bench.gd` + `scenes/upload_bench.tscn` | NEW. The arrival of every column of the spawn disc, timed one column at a time through the REAL `_collect_chunks`. |
| `scripts/tools/selftest_upload.gd` + `scenes/selftest_upload.tscn` | NEW. `sprint summary parse`, `upload parity` (both meshers), `collision honesty`. |
| `scripts/tools/selftest.gd` | One line: `"upload": SelftestUpload.run`. |

### THE SPLIT - the table that decides Stages 2 to 5

The two clean branch sprints, milliseconds of frame thread over sixty seconds:

| part | s0-1 | s0-2 | **share** | which stage | attempted? |
| --- | --- | --- | --- | --- | --- |
| `up_shape_ms` | 1,358.2 | 1,313.0 | **58.9%** | Stage 2 | **yes** |
| `up_node_ms` | 388.7 | 381.7 | **17.0%** | Stage 3 | **yes** |
| `up_flora_ms` | 275.4 | 266.7 | 11.9% | Stage 5 | no |
| `up_mesh_ms` | 250.6 | 248.8 | 11.0% | Stage 4 | no |
| `up_edit_ms` | 15.1 | 15.0 | 0.7% | - | - |
| `up_bodies_ms` | 12.9 | 12.6 | 0.6% | Stage 5 | no |
| **total** | **2,300.9** | **2,237.8** | | | |

**Grill Q2 binds: a share under 15% is not chased.** So **Stage 4 (the mesh on
the worker, 11.0%) and Stage 5 (flora and bodies, 12.5% together) are NOT
attempted**, by the plan's own rule and on its own instrument. Stage 2's shape
and Stage 3's node are, and between them they are three quarters of the
arrival.

**And the whole of it is 2.27 s of 60 - 3.8% of the sprint.** That is the
second half of the BLOCKING note: the arrival is real, it is measurable, and it
is not what the frame is spending its time on.

The load line's own split agrees, taken at spawn rather than at speed, three
runs:

```
[World] upload split: node 21% mesh 11% shape 52% edit 1% flora 15% bodies 0% (703 ms total, worst column 6.68 ms)
[World] upload split: node 21% mesh 11% shape 51% edit 1% flora 15% bodies 0% (715 ms total, worst column 3.21 ms)
[World] upload split: node 20% mesh 11% shape 52% edit 1% flora 15% bodies 0% (1164 ms total, worst column 12.93 ms)
```

### The bench

`scenes/upload_bench.tscn`, seed 42, radius 8 (197 columns, 841 chunks), three
passes, headless.

```
UPLOAD_BENCH mesher=cpp      config=shipped columns=197 chunks=841 col_median_us=210 col_p99_us=961 col_max_us=1086 node_us=68 mesh_us=28 shape_us=93 per_chunk_us=49 passes=3 spread=+-1.2%
UPLOAD_BENCH mesher=gdscript config=shipped columns=197 chunks=841 col_median_us=214 col_p99_us=927 col_max_us=1064 node_us=68 mesh_us=29 shape_us=93 per_chunk_us=50 passes=3 spread=+-2.3%
```

**The two meshers agree to within 2%, which is the bench saying it is measuring
the arrival and not the mesher.** They must: the arrival is handed the same
arrays either way, and `upload parity` proves that separately.

**The bench is headless and that biases it, deliberately recorded.** The dummy
rendering driver packs the vertex format on the calling thread - which is the
part this lane can move - and never touches a GPU, so `mesh_us` here is a floor
and not the number the sprint sees. The bench is the RANKING instrument, and
the sprint on the RTX 3070 Ti is the judge. Note that the shape share is the
largest one on both instruments (93 of 210 us here, 58.9% there), which is the
finding either way.

### Checks

| check | result |
| --- | --- |
| **the bench agrees across worktrees** (plan 0.5) | **1.9% apart.** Stage 0's four files copied into the base worktree, the bench run there, the worktree restored and verified clean by `git status --porcelain`: base `col_median_us=214`, branch `210`, node 69/68, mesh 28/28, shape 93/93. Gate 10%. |
| **base and branch sprints ABAB, within noise** (plan 0.5) | **Identical.** Medians 6.90 / 6.90 / 6.94 both sides; median of medians 6.90 each. The instrument costs nothing measurable. |
| main self-test | **SELFTEST: all passed** (with the upload tests inside it) |
| upload self-test | **SELFTEST-UPLOAD: all passed** - three tests |
| horizon self-test | **SELFTEST-HORIZON: all passed** |
| character self-test | **36 tests, all passed** |
| canonical line | **unchanged**, character for character |
| **upload parity** | **0 bad, both meshers.** 100 chunks and 25 surfaces per leg. |
| **collision honesty** | **0 bad.** 36 live chunks checked, 36 parked. |
| thread-guard errors | **none.** `grep -icE "thread.guard\|not safe to call from a thread\|can't call the function"` over every console log of the stage: 0. |
| the tour | **green, 27 images**, first line `Vulkan 1.4.329 - Forward+ - Using Device #0: NVIDIA GeForce RTX 3070 Ti`. `6-postcard` and `32-horizon-walk` read as they did: no seam, no missing chunk, no double-drawn chunk. |
| the load line (Q11's fence) | **faster, not slower.** Branch 16,306 / 16,815 ms wall against base 16,780 / 15,988. Inside noise, nowhere near the 10% fence. |

### The sprint line, ABAB x3

Ultra, seed 42, sixty seconds from spawn along `+X`, headless, C++ mesher, the
box otherwise idle. Base first, branch second, three times.

| run | median | p99 | worst | **over 25 ms** | chunks | far rebuilds |
| --- | --- | --- | --- | --- | --- | --- |
| base-s0-1 | 6.90 | 8.33 | 41.38 | 3 | 13,002 | 208 |
| **s0-1** | **6.90** | 8.33 | 26.15 | **2** | 13,052 | 208 |
| base-s0-2 | 6.90 | 8.33 | 26.15 | 1 | 13,081 | 209 |
| **s0-2** | **6.90** | 8.33 | 26.15 | **3** | 13,016 | 207 |
| base-s0-3 (contended) | 6.94 | 20.75 | 147.16 | 64 | 12,970 | 162 |
| **s0-3 (contended)** | 6.94 | 12.26 | 55.97 | 11 | 12,844 | 197 |

**Median of medians: 6.90 base, 6.90 branch. Over-25 median: 3 base, 3
branch.** No change either way, which is what a stage that only adds
instruments should produce.

**The third pair is contended and both its legs are, which is the ABAB working.**
Something on the box took p99 from 8.33 to 20.75 on the base leg and to 12.26 on
the branch leg of the same pair; the pair is kept in the table and out of the
numbers, exactly as horizon v1 kept its own two. The lesson for the later stages
is that **the over-25 count on this build is a two-or-three-frame quantity with
a sixty-frame tail risk**, so no rung may be judged on a single run.

### Tunables moved

None. Every knob is at the plan's start value.

---

## Questions taken alone

Plan § 5 item 9: where this file does not answer, the conservative reading -
smaller change, nearer today's value, fewer files - and the question written
down. In stage order.

1. **The base worktree is DETACHED at `146f061`, not on `main`.** Plan § 2 says
   `git worktree add ~/Kubik-upload-v1-base main`, and git refuses: `main` is
   already checked out in `~/Kubik`. Taken as `git worktree add --detach
   ~/Kubik-upload-v1-base 146f061` - the same commit, the same tree, and it is
   never pushed either way.
2. **The bench is a SCENE, not `--script`.** Plan § 2 and § 3 both give
   `godot --headless --path . --script scripts/tools/upload_bench.gd`, and it
   cannot work: `--script` replaces the main loop, Godot only creates autoloads
   for a real one, `world.gd` names the `Net` autoload in its edit path, so
   under `--script` it fails to compile and the symptom is `World.new()`
   reporting that GDScript has no function called `new()`. That is exactly what
   the first run of the plan's command line produced. `selftest.gd`'s own header
   records the same discovery from terrain v2 Stage 3. Taken as
   `scenes/upload_bench.tscn`, one extra file, invoked
   `godot --headless --path . scenes/upload_bench.tscn -- --seed 42 ...`.
   `mesh_bench.gd` stays a `SceneTree` script because it never builds a `World`.
3. **"Exact" in the upload parity gate is two layers, because the engine does
   not store what it is given.** Plan § 3 asks that the read-back arrays equal
   the job's arrays "vertex for vertex, normal, colour and index, exact".
   Measured on this engine, on purpose, before the gate was written: a VERTEX
   and an INDEX survive `add_surface_from_arrays` -> `surface_get_arrays` bit
   for bit; a NORMAL does not - `(0, 1, 0)` reads back as `(0, 1, -0.000015)`,
   octahedral 2 x 16 - and a COLOUR does not - `0.1` reads back as `0.098`,
   eight bits a channel. Taken as: **layer 1**, vertices and indices exact
   against the job's own arrays, and **layer 2**, all four exact against a
   reference `ArrayMesh` built from the same arrays by the same
   `ChunkMesher.arrays_to_mesh` and read back the same way. Together that is
   stricter than the plan's sentence, not weaker: the quantisation is a function
   of the input, so two meshes that read back differently were given different
   arrays.
4. **Collision honesty compares the MESH with the shape, not `has_solid` with
   the shape.** Written the second way first, and 27 of 36 chunks failed it: a
   chunk deep under the ground has solid blocks and no drawn face, and
   `chunk_node.gd`'s rule is that it gets no shape at all rather than an empty
   one. The gate is now that rule, both ways - a chunk that draws faces has a
   shape, a chunk that draws none has no shape - which is what "you cannot end
   up standing on a face that is not drawn, or walking through one that is"
   actually asserts.
5. **`apply_arrays` was split into `apply_mesh` + `apply_collision` in Stage 0,
   not Stage 2.** Plan 2.1 puts the split in Stage 2; Stage 0 needs the two
   halves timed apart to build its own table. The split is behaviour-preserving
   - `apply_arrays` calls both in the old order and installs the same bytes -
   and the parity gate proves it. It costs Stage 2 nothing and buys Stage 0 its
   largest column.
6. **The Stage 0 baseline and the Stage 0 comparison are ONE interleaved set of
   six runs.** Plan § 2 asks for three base sprints as the baseline and 0.5
   asks for three base and three branch ABAB. Taken as one ABAB x3, which is
   both, and is the only form in which the two are comparable.
7. **The bench's cross-worktree check was taken by copying Stage 0's four files
   into the base worktree, running, and restoring.** The plan says the bench
   "runs on base and on the branch (identical code so far)" - it cannot, since
   the bench IS Stage 0's code. Restored with `git checkout --`, the two new
   files and their `.uid` sidecars deleted, `--import` re-run, and
   `git status --porcelain` empty before the next base sprint.
8. **`up_flora_us` includes one `BodyField.column_landed` call.** On the flora
   CACHE-HIT path only, where the bodies are handed over inside the block that
   acquires the node. Left as it is rather than pausing the timer around it: it
   is a branch a sprint into new terrain almost never takes, and the six
   counters are worth more as six plain pairs of clock reads than as five plain
   ones and a conditional. `up_bodies_us` is therefore a slight underestimate
   and `up_flora_us` a slight overestimate, both far inside the 15% line that
   decides anything.

---

## For Marcel

1. **The frame gate is very nearly met on `main` today, and the plan's premise
   number does not reproduce.** 6.90 ms median and one to three frames over
   25 ms of about 8,590, on a quiet box, at Ultra with the view at 32 km -
   against the plan's opening quotation of 22.1 ms and 786 to 807. Same seed,
   same walk (13,000 chunks, 543 m, 9 jumps), same box, same preset. See
   BLOCKING at the top for the full comparison.
2. **Horizon v1's Stage 7 numbers were taken with the mesher lane live on the
   same six-core machine**, and its two "both lanes merged" runs came from a
   throwaway worktree while that lane was still running. That is almost
   certainly the whole difference, and it is worth knowing before the next plan
   quotes a frame number: **on ganymede a frame measurement is only as good as
   the quietness of the box, and the ABAB against a base worktree is what makes
   it honest.** Both of tonight's contended runs (`base-s0-3`, `s0-3`) show the
   same effect inside this lane's own table.
3. **Stages 4 and 5 will not be attempted, by the plan's own rule.** The mesh is
   11.0% of the arrival and flora plus bodies is 12.5%; grill Q2 binds anything
   under 15%. Stage 2 (the shape, 58.9%) and Stage 3 (the node, 17.0%) are.

---

## For the world-truth break

- Nothing yet.

---

## For the bible

- Nothing yet.
