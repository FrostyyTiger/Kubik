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

## Stage 1 - the atom is a chunk

**Green, and it ships - but the sprint cannot tell it from the column atom on
this build, and that is said plainly below.**

### What shipped

`_collect_chunks` checks `chunk_upload_budget_ms` between CHUNKS instead of
between columns. A column whose remaining chunks did not fit stays in
`_in_flight` with a cursor (`entry["cys"]`, the install order fixed once, and
`entry["next"]`) and the next frame resumes it before starting anything new -
`_in_flight` keeps insertion order, so the resumed column is at the front of
the walk. `_column_landed`, `_frontier_advanced`, `_loaded_columns` and
`_columns_built` now fire on the column's LAST chunk, which for a column that
fits in one frame is the frame it always was. `_drain_jobs` learned not to wait
a second time on a task the pump has already joined. `upload_atom_chunk` (LOCAL,
unhashed, default **1**) restores the column atom at 0.

### The bench

```
UPLOAD_BENCH mesher=cpp config=shipped              columns=197 chunks=841 col_median_us=217 col_p99_us=954 col_max_us=1066 node_us=67 mesh_us=29 shape_us=93 per_chunk_us=50 passes=3 spread=+-6.2%
UPLOAD_BENCH mesher=cpp config=upload_atom_chunk=0  columns=197 chunks=841 col_median_us=217 col_p99_us=935 col_max_us=1071 node_us=69 mesh_us=28 shape_us=93 per_chunk_us=50 passes=3 spread=+-1.2%
```

**Identical, and the bench is blind to this rung by construction.** It installs
one column at a time with an unbounded budget, so there is no budget line for
the atom to stop at. Plan § 3's rule - "a rung that does not move
`col_median_us` and `col_max_us` on the bench is not worth a sprint" - cannot
apply to Stage 1, whose whole subject IS the budget line. Recorded under
"Questions taken alone"; the sprint is the only judge here.

### The sprint line, ABAB x3, plus the knob off twice

| run | median | p99 | worst | **over 25 ms** | chunks | `up_col_max_ms` |
| --- | --- | --- | --- | --- | --- | --- |
| base-s1-1 (contended) | 6.93 | 15.67 | 121.59 | 32 | 12,814 | - |
| **s1-1** | 6.94 | 8.33 | 29.34 | **2** | 13,010 | 15.73 |
| base-s1-2 | 6.90 | 8.33 | 30.38 | 3 | 13,048 | - |
| **s1-2** | 6.90 | 8.33 | 39.84 | **3** | 13,085 | 25.17 |
| base-s1-3 | 6.90 | 8.33 | 39.55 | 3 | 13,001 | - |
| **s1-3** | 6.90 | 8.33 | 26.15 | **1** | 13,053 | 6.28 |
| `upload_atom_chunk=0`, 1 | 6.90 | 8.33 | 32.29 | 5 | 13,049 | 10.42 |
| `upload_atom_chunk=0`, 2 | 6.90 | 8.33 | 26.15 | 3 | 13,049 | 21.69 |

**Medians: base 6.90, branch 6.90.** Over-25 medians: **base 3, chunk atom 2,
column atom 4.** Against base the rung is no worse on either number and
directionally better on the count, which is what plan § 5 item 4 asks of a rung
that ships.

**And the honest reading is that three runs cannot separate 2 from 4 when the
quantity is a handful of frames out of 8,590.** `base-s1-1` produced 32 on the
untouched tree; that is the size of this measurement's noise floor, and it is
larger than the effect. The rung is kept at default 1 anyway, for a reason that
does not need the sprint to agree: **it bounds the slice by construction.**
Before it, a frame with 0.1 ms of its budget left could start a whole column and
pay all of it; after it, the most a frame can be made to swallow past its budget
is one chunk. That the bound rarely binds today is a fact about this build's
column sizes, not an argument for being able to overshoot by a column.

**`up_col_max_ms` did NOT fall to about one chunk's cost, and the plan expected
it to** (1.2). Measured: 15.73 / 25.17 / 6.28 with the chunk atom against
10.42 / 21.69 with the column atom - the same distribution. The explanation is
in the atom rule itself: the budget is checked AFTER a chunk, so the worst slice
is always at least one chunk's cost, and **one chunk's worst cost on this build
is 6 to 25 ms**. That is a finding for Stage 2 and 3 rather than a failure of
Stage 1: the tail of the arrival is not a column being too big, it is a single
chunk occasionally being very expensive, and the shape is 59% of a chunk.

### Checks

| check | result |
| --- | --- |
| main self-test | **SELFTEST: all passed** - `edit while cached` and `edit during generation` inside it |
| upload self-test | **SELFTEST-UPLOAD: all passed** - six tests |
| horizon self-test | **SELFTEST-HORIZON: all passed** |
| character self-test | **36 tests, all passed** |
| canonical line | **unchanged**, character for character |
| upload parity | **0 bad, both meshers** |
| collision honesty | **0 bad** |
| **atom knob** (new) | `upload_atom_chunk` in `LOCAL_PROPERTIES`, not in `PROPERTIES`, **config hash `1d7c18c7` unmoved** when it is flipped |
| **atom parity** (new) | **36 chunks compared, 0 bad.** Two worlds on the canonical seed, one per atom, pumped to completion: every installed surface and every collision shape identical, and the same set of landed columns. |
| **atom invariants** (new) | **122 pumps, 4 mid-column observations, 0 bad.** While a column is half installed it is never in `_loaded_columns`, and every chunk behind the cursor has its node. The test FAILS if it never catches the pump mid-column, so it cannot quietly measure nothing. |
| thread-guard errors | **none.** The only lines matching `thread` in the stage's logs are the horizon suite's own `tile threads` test name. |
| the tour | **green, 28 images**, `Vulkan 1.4.329 - Forward+ - Using Device #0: NVIDIA GeForce RTX 3070 Ti`. `32-horizon-walk` is forest interior with its ground cover, trunks and mushrooms intact - no hole, no seam. |
| the load line | 16,325 / 16,027 / 16,257 ms wall against base 16,780 / 15,988 / 17,567. Inside noise. |
| `jumps`, `moved_m` | **9 to 10 and 543 m in every run of both sides** - unchanged, so nothing arrived late under the player |

### Tunables moved

None. `chunk_upload_budget_ms` stays at 8.

---

## Stage 2 - collision on its own budget

**Green, and it is the rung that moves the number: the over-25 count's median
goes 3 -> 1 against base, over eleven clean runs.** The shape on the worker
(2.2, grill Q5) is measured and **dead**.

### What shipped

- **`_collect_chunks` installs the mesh and OWES the shape.** A chunk with
  faces pushes `[faces, shape]` onto `_collision_pending` (the debt, keyed by
  chunk position) with `_collision_order` beside it (the order); a chunk with no
  faces, and a collision-only column, are installed inline as before.
- **`_pump_collision(budget)` right after `_collect_finished`.** Every owed
  chunk within `collision_now_radius` (2) of the streaming centre is installed
  **before the budget is consulted** - the ground under the player is never
  scheduled - then the rest nearest-first by `_queue_key`, with the budget
  checked AFTER each shape, the way `FarUpload`'s slices are.
- **`is_chunk_collidable` is still the truth.** `ChunkNode` gained
  `_collision_installed`, and `set_parked` is now `collision_applied =
  _collision_installed and not parked` rather than an assignment - a chunk can
  be drawn, parked and restored with its shape still owed, and `set_parked
  (false)` must not promise ground nobody installed.
- **Park drops the debt; restore pays it** from the node's own mesh. Eviction
  drops it too.
- **`ColumnJob` can build the shape on the worker** behind `shape_on_worker`
  (default **0** - see below).
- **Knobs:** `collision_budget_ms` (2.0), `collision_now_radius` (2),
  `shape_on_worker` (0), all LOCAL and unhashed. **And
  `chunk_upload_budget_ms` moves 8.0 -> 6.0** - see the tunable below, it is
  half the result.

### THE TUNABLE THAT IS HALF THE RESULT: two budgets add

The first three branch runs came back at an over-25 median of **4 against
base's 3** - the rung making the number it exists to move *worse*. The
mechanism is arithmetic and the instrument found it: `_pump_collision` spends
`collision_budget_ms` **on top of** the chunk pump's `chunk_upload_budget_ms`,
so a frame that could spend eight milliseconds installing the world could now
spend ten.

Held at **6 + 2**, the total is the eight it always was:

| configuration | clean runs | over 25 ms | **median** | `up_col_max_ms` |
| --- | --- | --- | --- | --- |
| **base** (chunk 8, no queue) | 10 | 0,1,1,1,1,3,3,5,6,7 | **3** | - |
| branch, chunk 8 + collision 2 (**total 10**) | 6 | 1,1,1,4,4,5 | **4** | 3.20 |
| queue off, chunk 8 | 2 | 1,3 | 3 | 6.04 |
| queue off, chunk 6 | 6 | 1,1,2,2,4,4 | **2** | 4.91 |
| **SHIPPED: chunk 6 + collision 2 (total 8)** | **11** | **0,0,0,0,1,1,1,2,2,4,5** | **1** | **3.31** |

**Both halves contribute and neither is the whole of it.** The 6 ms chunk
budget alone takes the median count from 3 to 2; the queue on top of it takes
it to 1 and takes the worst arrival slice from 4.91 ms to 3.31. Seven of the
eleven shipped runs are at 0 or 1, and the whole spread is 0 to 5 against
base's 0 to 7.

The frame median is **6.90 ms on every clean run of every configuration**,
including base. This lane cannot move it and never claimed it would.

### A run is "clean" if its p99 is at or under 10 ms, and that is not a
### judgement call

**There is another lane on this box after all.** `tmux ls` shows `bauplan`,
`bauplan-babysit` and `bauplan-watch` (the last created at 18:35, an hour after
this lane started), a `claude` process at 14.6% CPU with 31 hours on it, and the
Navigo test server's `next-server` and `uvicorn`. None of them is this lane's
and none of them is this lane's to kill. The plan's § 0 says "the box is this
lane's"; it is not, and every frame number in this document is taken with that
qualification.

What it does to the sample is bimodal and obvious rather than subtle: a clean
run has **p99 8.33 to 9.26 ms**, a contended one **12.50 to 19.17**, with
nothing in between, and the contended ones also load fewer chunks (12,093 to
12,966 against 12,980 to 13,099). So the split is drawn at p99 = 10 ms, every
run of every configuration is counted the same way, and both counts are in the
table above. 24 of 33 sprints in this stage are clean.

### Grill Q5: the shape on the worker is DEAD, and it is worth why

`shape_on_worker` 1 builds the `ConcavePolygonShape3D` and calls `set_faces`
inside `ColumnJob.run()`, on the worker.

| | `col_median_us` | `shape_us` | `col_max_us` |
| --- | --- | --- | --- |
| shipped | 233 | 102 | 1,091 |
| `shape_on_worker=1` | 232 | 100 | 1,065 |

**Two per cent. Q5's ship rule asks for over fifteen.** And the sprint agrees:
`up_shape_ms` 1,430 against 1,385, `up_col_max_ms` **27.22 against 3.20**, over
25 ms 6 against 1. The knob stays at 0.

**Why it buys nothing, which is the useful part:** the main-thread shape cost is
not `ConcavePolygonShape3D.new()` and `set_faces()`. Those move to the worker
cleanly - the stress test built **8,600 shapes over 20 rounds** on worker
threads with no crash, no deadlock and no thread-guard line. The cost is the
ASSIGNMENT, `_collider.shape = shape`, where Jolt builds its own mesh shape and
inserts it into the broadphase, and that happens on the main thread wherever the
resource was made. Q5 guessed exactly this ("Jolt builds its own mesh shape
lazily when the shape reaches a body, so the saving may be nothing"); it is now
measured. **A C++ rung would not help either**, for the same reason - the
remaining cost is inside the physics server, not in front of it. Recorded under
"For Marcel".

### The bench

```
UPLOAD_BENCH mesher=cpp config=shipped             columns=197 chunks=841 col_median_us=233 col_p99_us=949 col_max_us=1091 arrival_us=127 node_us=70 mesh_us=28 shape_us=102 per_chunk_us=54 passes=3 spread=+-2.1%
UPLOAD_BENCH mesher=cpp config=shape_on_worker=1   columns=197 chunks=841 col_median_us=232 col_p99_us=938 col_max_us=1065 arrival_us=128 node_us=70 mesh_us=29 shape_us=100 per_chunk_us=54 passes=3 spread=+-2.2%
```

**`arrival_us` is new and it is the point of the stage: 127 us of the 233 is
paid in the frame the column lands, and the other 106 is paid later.** The
bench had to be corrected to say that - see "Questions taken alone" item 12; as
first written it stopped at `_collect_chunks` and reported the arrival falling
from 210 us to 116, which is an accounting change and not a saving.

### The collision queue never gets deep, and that was the thing to check

`coll_peak=11` in **every** shipped run - the deepest the queue ever got over
sixty seconds of sprinting at 214 columns a second. `coll_urgent=13`: thirteen
shapes over the whole run were installed off-budget because they were within
two chunks of the player.

The arithmetic said it had to be so - the sprint owes about 22 ms of shape per
second and the pump is offered 2 ms of every frame at 145 fps - and this is the
check on the arithmetic rather than a restatement of it. **It also means the
budget is nowhere near binding**, which is why raising it does nothing and
lowering it to 1 did nothing either (median 3 over 2 clean runs).

### Checks

| check | result |
| --- | --- |
| main self-test | **SELFTEST: all passed** |
| upload self-test | **SELFTEST-UPLOAD: all passed** - nine tests |
| horizon self-test | **SELFTEST-HORIZON: all passed** |
| character self-test | **36 tests, all passed** |
| canonical line | **unchanged**, character for character |
| upload parity | **0 bad, both meshers** |
| collision honesty | **0 bad** |
| **collision queue** (new) | **36 chunks compared, 0 bad.** The budgeted queue and the inline path install the same shapes, face for face, and the queue owes nothing when it is done. |
| **collision never early** (new) | **9 owed, 9 restored, 0 bad.** `is_chunk_collidable` is false for a chunk whose mesh is up and whose shape is owed, false for one parked with a debt, and true with a real shape under it for one brought back. |
| **worker shape stress** (new) | **20 rounds, 8,600 shapes, 0 bad.** Built on worker threads; no crash, no deadlock, no wrong shape. |
| thread-guard errors | **none** - strict count 0 over every console log of the stage, `shape_on_worker=1`'s runs included |
| **the ground wait** (plan 2.3) | **unchanged.** `ground at 1.2 s` at the spawn and `1.4 s` at `--tp 20000 0`, base and branch identical on both. |
| `jumps`, `moved_m` | **9 and 543 m** in every clean run of both sides |
| the load line | within noise of base |

### Tunables moved

| knob | was | now | the number that decided it |
| --- | --- | --- | --- |
| `chunk_upload_budget_ms` | 8.0 | **6.0** | over-25 median 4 at 8+2, **1** at 6+2, against base's 3. Two budgets add; the total goes back to the 8 ms the frame always had. |
| `collision_budget_ms` | - | **2.0** (new) | the plan's start value; 1.0 measured no better (median 3 over 2 clean runs) and the queue's peak depth of 11 says it is nowhere near binding |
| `collision_now_radius` | - | **2** (new) | the plan's start value; the ground wait is unchanged at 1.2 s and 1.4 s, so it did not need moving |
| `shape_on_worker` | - | **0** (new, and it stays 0) | 2% on the bench against Q5's 15%; worse on the sprint |

---

## Stage 3 - one node per column

**Green, measured, and it DOES NOT SHIP.** `column_node` stays at 0. The rung
does exactly what Q6 designed it to do - it takes 62% off the node share and
278 ms of frame-thread work off the sprint - and the over-25 count gets
slightly worse anyway. Plan § 5 item 4 decides it, and the finding underneath
it is the more interesting half.

### Why it was attempted

Stage 0's split put node creation at **17.0%**, over the 15% line grill Q2
draws. That is the whole of the entry condition and it was met.

### What was built (and stays in the tree, behind the knob at 0)

`ChunkNode` is now keyed by chunk-y in BOTH modes, which is what keeps them one
file rather than two: per chunk the dictionaries hold one entry. At
`column_node` 1 the node sits at the column's origin, carries one `ArrayMesh`
with **one surface per chunk**, one `StaticBody3D`, and one `CollisionShape3D`
per chunk under it. `World` still keys `_chunk_nodes` by CHUNK and simply finds
the same node under several keys - so `is_chunk_collidable`, the collision
queue, the upgrade drain, the edit path and the cache all read as they did.

**Surfaces stay per chunk and that is not an implementation detail** (Q6, mesher
v1 Q7): an edit remeshes one chunk on the twin at 6.4 ms and replaces ONE
surface, where a merged column surface would make every broken block a 40 ms
hitch.

**The offset is the job's.** A surface cannot carry a transform, so a chunk
three up a column must be packed three chunks higher than its node.
`ColumnJob` does that addition on the worker, before `faces_from`, so the faces
come out in the same space for free and `built[cy]` stays exactly the thing the
arrival installs and the parity gate compares against.

### Two aliasing traps, and one real bug the gates caught

- **`_shift_anchors` would have moved a four-chunk column four kilometres.** In
  column mode one node answers to every chunk key of its column, so the loop
  over `_chunk_nodes` had to dedupe on the node. Same for `reset()`'s
  `queue_free` and the cache's `_pending_frees`.
- **`_set_surface` was adding the new surface to an orphaned `ArrayMesh`.**
  `_drop_surface` sets `mesh` to null when it removes the LAST surface, and the
  reference had been taken before the drop. **Every column whose only faces are
  in its top chunk hits this on the first edit, which is most of them**, and the
  symptom is a chunk that goes invisible and loses its collision the moment you
  break a block in it. `column node edit` found it on the first run.

### The bench: the rung works

```
UPLOAD_BENCH mesher=cpp config=shipped         columns=197 chunks=841 col_median_us=263 col_p99_us=987 col_max_us=1121 arrival_us=151 node_us=72 mesh_us=32 shape_us=123 per_chunk_us=61 passes=3 spread=+-0.4%
UPLOAD_BENCH mesher=cpp config=column_node=1   columns=197 chunks=841 col_median_us=211 col_p99_us=948 col_max_us=1054 arrival_us=102 node_us=28 mesh_us=30 shape_us=126 per_chunk_us=49 passes=3 spread=+-1.7%
```

**`node_us` 72 -> 28, `arrival_us` 151 -> 102, the whole column 263 -> 211.**
A fifth off the arrival, and the plan's "not worth a sprint" bar is cleared
comfortably.

### The sprint: and it is worse

Five runs each, all five clean on every leg, interleaved base / on / off.

| configuration | over 25 ms | **median** | `up_node_ms` | `up_col_max_ms` |
| --- | --- | --- | --- | --- |
| base | 0, 0, 1, 2, 5 | **1** | - | - |
| `column_node=1` | 1, 2, 2, 4, 4 | **2** | **141.7** | **1.72** |
| `column_node=0` (shipped) | 0, 0, 1, 3, 3 | **1** | 377.1 | 2.86 |

The frame median is 6.90 ms on all fifteen runs.

**The rung's own instrument agrees with the bench and disagrees with the
gate.** `up_node_ms` falls 377 -> 142, the worst arrival slice falls 2.86 ->
1.72 ms, and the whole upload falls from about 2,510 ms to 2,232 - **278
milliseconds of frame thread removed from a sixty-second sprint** - and the
count of frames over 25 ms goes UP. It is not only the median: the shipped leg
and base each have two runs at zero and the rung has none, and its five runs sum
to 13 against 7 and 8.

**So it does not ship** (§ 5 item 4, and Q15: the count is the gate). The code
stays in the tree at `column_node` 0, reachable for one epic, as § 3 asks.

### What that says, which is worth more than the rung

**The hitches are not made of the arrival's total cost.** A rung can remove a
ninth of the frame-thread work the world costs and leave the hitch count where
it was or worse. Whatever the two-to-five frames over 25 ms are, they are not
"the upload is too much work per second" - Stage 2 already showed the same thing
from the other side, where the win came from capping the per-frame TOTAL at
8 ms rather than from making anything cheaper.

**The suspicion, and it is a suspicion and not a measurement:** one
`StaticBody3D` per column with N `CollisionShape3D` children means every
`apply_collision` adds a shape to a body already in the broadphase, so Jolt
updates that body's compound and its bounds again for each one - a cost that
grows with the shapes already on it, where N separate bodies are N independent
constant-cost inserts. The totals fit (`up_shape_ms` is flat at ~1,500 either
way, so it is the distribution and not the sum), but nothing here measures the
inside of the physics server. Flagged "For Marcel" rather than asserted.

### Checks

| check | result |
| --- | --- |
| main self-test | **SELFTEST: all passed** |
| upload self-test | **SELFTEST-UPLOAD: all passed** - eleven tests |
| horizon self-test | **SELFTEST-HORIZON: all passed** |
| character self-test | **36 tests, all passed** |
| canonical line | **unchanged**, character for character |
| upload parity | **0 bad, both meshers** |
| collision honesty, collision queue, collision never early | **0 bad** |
| **column node parity** (new) | **36 chunks, 36 nodes per-chunk -> 9 per-column, 0 bad.** Every vertex and every collision face compared in WORLD space - node position plus array - between the two modes, because the two modes put the same geometry in different pairs of numbers. It also fails if the column mode does not actually make fewer nodes, so the knob cannot quietly not reach the world. |
| **column node edit** (new) | **3 siblings held, 1 edited chunk changed, 0 bad.** `surface_remove` renumbers every later surface; this is the gate on the index map, and it caught the orphaned-mesh bug above. |
| thread-guard errors | **none** |
| the tour, both modes | green on Forward+; `6-postcard` and `32-horizon-walk` identical to the eye between `column_node` 0 and 1 - no seam, no missing chunk, no double-drawn chunk |
| `jumps`, `moved_m` | 9 and 543 m throughout |

### Tunables moved

None. `column_node` is added and stays at **0**.

---

## Stage 4 - the mesh on the worker: NOT ATTEMPTED

**`up_mesh_us` is 11.0% of the arrival and grill Q2 binds anything under 15%.**
Plan § 4.0: "Only if Stage 0's split says `up_mesh_us` is over 15% of the
arrival." It does not, so the rung was not written, `mesh_on_worker` does not
exist, and no time was spent on it. Stage 0's split table is the evidence and
it is reprinted there.

The measurement that would change this answer is the one Stage 0 already flags:
the split is taken with the C++ mesher, where `add_surface_from_arrays` is
28 us of a 233 us column on the bench and 250 ms of a 60-second sprint. On the
GDScript twin the arrays are the same arrays, so the share does not move
either.

---

## Stage 5 - flora and bodies on the one pump: NOT ATTEMPTED

**`up_flora_us` + `up_bodies_us` is 12.5% of the arrival** (11.9% and 0.6%) and
plan § 5.0 asks for over 15%. Not attempted, for the same reason and by the
same rule. `flora_on_pump` and `bodies_per_frame` do not exist.

Worth recording for whoever picks this up: flora is the third largest share
after the shape and the node, it is stable at 271 to 286 ms per sprint across
every configuration measured tonight, and it did not move when anything else
did - so it is a clean 12% sitting on its own, and it would be the next rung if
the 15% line were ever lowered.

---

## Stage 6 - the render thread model, as an experiment

**Measured, clean, mildly favourable, and it DOES NOT SHIP.** Grill Q9's rule
is strict and one of its three legs is not met.

### First, a correction to the plan

Q7 says "`rendering/driver/threads/thread_model` is 1 (Single-Safe) in
`project.godot`". **There is no `[rendering]` section in `project.godot` at
all** and there never was; the engine's default is 1, so the statement is true
in effect and false in the file. This stage adds the section with the line in
it, **commented out**, and the comment carries the measurement - so the next
person to wonder finds the answer beside the switch instead of in a status doc.

### The runs

Three pairs, ABAB, the branch at model 1 against the same branch at model 2,
nothing else changed.

| | over 25 ms | **median** | frame median |
| --- | --- | --- | --- |
| thread_model 1 | 3, 4, 1 | **3** | 6.90 ms |
| thread_model 2 | 1, 2, 2 | **2** | 6.90 ms |

### The ship rule, leg by leg

| Q9's leg | result |
| --- | --- |
| every self-test green at model 2 | **YES.** `SELFTEST: all passed`, `SELFTEST-UPLOAD: all passed`, `SELFTEST-HORIZON: all passed`, character 36/36. |
| the tour's terrain windows within noise of model 1 | **YES.** 27 shots compared, **25 identical** on primitives in frame, flora instances, triangles and chunks loaded. The two that differ are `31-horizon-far` (0.08 -> 0.06 M primitives, on the shot horizon v1 already recorded as an unstable sample) and `32-horizon-walk` (6.53 -> 6.50 M); flora and chunk counts are identical on both. |
| **BOTH sprint numbers improve** | **NO.** The over-25 median improves, 3 -> 2. **The frame median does not: 6.90 ms either way.** |

**So it does not ship**, which is also what the plan says the default is.

### The recommendation, and it is the first "For Marcel" item

Not now, and not because it looked bad - it looked slightly good. Three
reasons, in order:

1. **The one number it moved is a one-frame difference at n=3**, on a box
   where this lane has seen the same quantity swing from 0 to 7 on an
   untouched tree. It is not evidence yet.
2. **The frame median is 6.90 ms with the model on or off**, and that is the
   number the north star's rule is written against. There is nothing here for
   it to buy.
3. **`project.godot` is read by Marcel's Windows box and by CI**, and Godot's
   own documentation calls the multi-threaded model buggy. That is a real risk
   taken for a benefit that has not been demonstrated.

**If the hitch count ever becomes the binding gate again, this is worth
revisiting - and the first run should be on the RTX 5080 under Windows**, not
here, because that is where the game is played and where a rendering-thread bug
would show up differently.

---

## Stage 7 - the sprint line

```
SPRINT: 6.90 ms median at Ultra, 32 km - the gate is 16.7 and it is met
        with a 2.4x margin, on main and on this branch alike.
        Frames over 25 ms: base median 2, this branch median 1,
        over 23 clean runs each. The gate is 0. BLOCKING.
```

### The line, pooled over the whole night

**Every clean sprint of the night, both sides, interleaved throughout.** The
plan asks for three runs ABAB; this lane took 23 clean runs of each because the
quantity being measured is a handful of frames out of 8,590 and the box has
another lane on it (Stage 2's note). Base and branch were never run in
different sittings - every batch alternated - so the pool is an ABAB pool and
not two samples taken at different times.

| | clean runs | frames over 25 ms, sorted | **median** | mean | frame median |
| --- | --- | --- | --- | --- | --- |
| **base** (`main` at `146f061`) | 23 | 0,0,0,0,1,1,1,1,1,1,1,2,2,3,3,3,3,3,4,5,5,6,7 | **2** | 2.30 | **6.90 ms** |
| **this branch** | 23 | 0,0,0,0,0,0,1,1,1,1,1,1,2,2,2,3,3,3,3,4,4,5,5 | **1** | **1.83** | **6.90 ms** |

**Median 2 -> 1, mean 2.30 -> 1.83 (-20%), worst run 7 -> 5, and six runs at
zero against four.** Modest, consistent, and the direction the lane exists to
move. **Neither number is worse**, which is what the merge rule of § 0 asks.

### What each rung bought, one at a time

Each shipped rung turned off by its knob on the branch, everything else as it
ships:

| configuration | clean runs | over 25 ms | median |
| --- | --- | --- | --- |
| **the branch as it ships** | 23 | see above | **1** |
| `upload_atom_chunk=0` (the column atom) | 4 | 1,2,3,5 | 2.5 |
| `collision_budget_ms=0` (no queue) | 4 | 1,1,3,4 | 2 |
| `chunk_upload_budget_ms=8` (the old budget) | 8 | 0,1,1,1,3,4,4,5 | 2 |
| `column_node=1` (not shipped) | 5 | 1,2,2,4,4 | 2 |
| `thread_model=2` (not shipped) | 3 | 1,2,2 | 2 |

**Every rung turned off lands back on base's median of 2, and all three
together give 1.** No single one of them is the result; they are three small
things and the frame notices the sum.

### The frame median is 6.90 ms on every clean run ever taken tonight

Base, branch, every knob position, both meshers, both thread models: **6.90 ms**,
without exception, on 60-odd clean sprints. That is not this lane holding
something steady - it is the instrument's floor on this hardware for this walk.
The north star's median rule is met with a 2.4x margin and **there is nothing
here for any rung to improve**; the only number this lane could move was the
count, and it moved it.

### The gate

**MEDIAN: PASS.** 6.90 ms against 16.7.

**NO FRAME OVER 25 ms: FAIL, and it is the BLOCKING line.** A median of 1 frame
of about 8,590, ranging 0 to 5. Six of 23 runs meet the gate outright.

### The residual has a name, and it is not the upload's total

The plan asks for the split of the best configuration beside the residual, so
the residual has a name. Here it is, the shipped branch, milliseconds of frame
thread over sixty seconds, median of four runs:

| part | ms | share |
| --- | --- | --- |
| `up_shape_ms` | 1,500 | 61% |
| `up_node_ms` | 381 | 16% |
| `up_flora_ms` | 270 | 11% |
| `up_mesh_ms` | 275 | 11% |
| `up_edit_ms` | 15 | 0.6% |
| `up_bodies_ms` | 12 | 0.5% |
| **total** | **2,453** | **4.1% of the sprint** |

`up_col_max_ms` 0.98 to 4.89 (from 6.68 at Stage 0), `coll_peak` 9 to 11.

**And the honest reading of that table is that it is NOT the residual.** Stage 3
removed 278 ms of it - a ninth - and the count got worse; Stage 2's win came
from capping the per-frame total rather than from making anything cheaper. Four
per cent of the sprint is spent installing the world and one frame in 8,590 is
over 25 ms, and this lane's instrument cannot show that the second is made of
the first. **The next lane that wants this gate should start by measuring what a
hitch IS** - a frame-level trace of the two or three frames rather than a
per-second sum - because every per-second number this lane can print is now
flat.

### The twin, once (grill Q10)

`--mesher gdscript`, one run, not a gate:

```
SPRINT label=s7-gdscript median_ms=6.90 p99_ms=11.11 worst_ms=44.06 over25=21
  chunks=6440 up_node_ms=211.8 up_mesh_ms=146.4 up_shape_ms=741.9
  up_col_max_ms=1.18 coll_peak=6
```

**The twin's path through the new arrival works.** Half the chunks in the same
sixty seconds (6,440 against 13,000) because the GDScript mesher is the
bottleneck again, which is mesher v1's whole point and not this lane's business;
the collision queue, the chunk atom and the split all behave, and `moved_m` is
the same 543 m.

### The load at spawn (grill Q11)

| | wall | main thread | upload per chunk |
| --- | --- | --- | --- |
| base | 16,267 / 16,148 ms | 1,253 / 1,246 ms | 0.11 ms |
| branch | 16,812 / 16,852 ms | 1,412 / 1,442 ms | 0.13 ms |

**+4.0% on the wall, inside Q11's 10% fence**, and recorded rather than waved
past: the collision queue costs a little at load, where thousands of shapes are
owed at once and the pump's bookkeeping is paid per shape. It is the one place
this lane is measurably slower and it is a place nobody is looking at a frame.

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
8. **Stage 1's rung cannot be judged on the bench, and the plan says every rung
   must be.** Plan § 3: "a rung that does not move `col_median_us` and
   `col_max_us` on the bench is not worth a sprint." The bench installs one
   column at a time with an unbounded budget - that is what makes it a
   per-column instrument - so it has no budget line for a chunk atom to stop
   at, and it reported 217 us both ways. Taken as: the rule is about rungs that
   make the ARRIVAL cheaper, and Stage 1 makes it *interruptible* instead. The
   sprint judged it, and the bench line is in the table saying it saw nothing.
9. **Stage 2's collision budget is DOUBLED during the initial load**, exactly as
   `chunk_upload_budget_ms` is, and the plan does not say either way. Taken as
   the doubling: the load is not a frame anybody is looking at, the ground wait
   is at the end of it, and a 2 ms slice per frame against 850 ms of shape work
   would have stretched the spawn into Q11's 10% fence for nothing.
10. **A column parked before its shape was installed derives the shape from its
   own mesh when it comes back.** Plan 2.1 says "a parked column drops its
   queue entries; `_restore_column` re-queues", and re-queueing needs the faces,
   which were dropped with the entry. Keeping them instead would leave a debt
   nothing pays for a column that is never restored. Taken as: drop the faces on
   park, and on restore call `apply_collision()` with none - the same
   `create_trimesh_shape()` the edit path has always used, on the same mesh the
   faces were derived from, so the triangles are the same triangles. It takes
   walking away from a column inside the frame or two its shape was queued for.
11. **The bench had to charge the collision pump to the column that owed it.**
   As first written it timed `_collect_chunks` alone, and the moment Stage 2
   moved the shape onto a later frame it reported the arrival falling from
   210 us to 116 - which is an accounting change and not a saving. Taken as:
   drain the pump inside the per-column timer so `col_median_us` stays
   comparable across every stage, and report `arrival_us` beside it for the
   part that is actually paid in the frame the column lands.
12. **A run is called contended if its p99 exceeds 10 ms.** The plan assumes a
   quiet box and there is another lane on this one (Stage 2 has the detail).
   The threshold is not a judgement call: clean runs sit at p99 8.33 to 9.26
   and contended ones at 12.50 to 19.17, with nothing in between, and the
   contended ones independently load 200 to 1,000 fewer chunks. Every
   configuration is counted the same way and both counts are printed.
13. **`up_flora_us` includes one `BodyField.column_landed` call.** On the flora
   CACHE-HIT path only, where the bodies are handed over inside the block that
   acquires the node. Left as it is rather than pausing the timer around it: it
   is a branch a sprint into new terrain almost never takes, and the six
   counters are worth more as six plain pairs of clock reads than as five plain
   ones and a conditional. `up_bodies_us` is therefore a slight underestimate
   and `up_flora_us` a slight overestimate, both far inside the 15% line that
   decides anything.

---

## For Marcel

0. **The render thread model: do not ship it, and here is the whole case.**
   Stage 6 measured `thread_model` 2 against 1, three pairs ABAB: every
   self-test green, 25 of 27 tour shots identical, the over-25 median 3 -> 2
   and **the frame median unmoved at 6.90 ms**. Q9's rule needs both sprint
   numbers to improve and one of them did not, so the line is in
   `project.godot` commented out with the measurement beside it. Revisit only
   if the hitch count becomes binding again, and test it on the Windows box
   first.
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
3. **THE BOX WAS NOT THIS LANE'S.** The plan's § 0 says "no second lane runs
   these nights"; `tmux ls` shows the `bauplan` lane's three sessions, one of
   them started an hour after this one, plus the Navigo test server. Nothing
   was killed - none of it is this lane's - and every frame number here is an
   ABAB median with contended runs separated out and printed. It cost this lane
   a lot of extra runs: Stage 2's decision needed 33 sprints where the plan
   budgeted six. **If a frame lane is worth an unattended night, the box has to
   actually be reserved.**
4. **A C++ rung for the collision shape would not help.** Q5's measurement says
   the main-thread cost is not building the resource - that moves to a worker
   cleanly, 8,600 times over - it is the assignment to the body, inside Jolt.
   Anything written in front of the physics server, in any language, is
   optimising the 2% rather than the 98%. Stage 2 has the numbers.
5. **Stage 3's rung does not ship, and the reason is the interesting part.**
   One node per column takes 62% off the node share and **278 ms of frame
   thread off a sixty-second sprint**, and the over-25 count gets slightly
   worse anyway (median 2 against 1, and no zero runs where base and the
   shipped path each have two). So the hitches are not made of the arrival's
   total cost. Stage 2 said the same thing from the other side: its win came
   from capping the per-frame TOTAL at 8 ms, not from making anything cheaper.
   **The next person to chase this frame should measure what a hitch IS before
   making anything faster.**
6. **A suspicion worth one experiment, not a finding.** The column node puts one
   `StaticBody3D` under a column with a `CollisionShape3D` per chunk, so each
   shape is added to a body already in the broadphase and Jolt updates that
   body's compound and bounds again each time - where N separate bodies are N
   independent constant-cost inserts. `up_shape_ms` is flat at ~1,500 ms either
   way, so if this is real it is in the distribution and not the sum. Nothing
   here measures the inside of the physics server.
7. **Stages 4 and 5 will not be attempted, by the plan's own rule.** The mesh is
   11.0% of the arrival and flora plus bodies is 12.5%; grill Q2 binds anything
   under 15%. Stage 2 (the shape, 58.9%) and Stage 3 (the node, 17.0%) are.

---

## For the world-truth break

- Nothing yet.

---

## For the bible

- Nothing yet.
