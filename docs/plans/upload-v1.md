# Upload v1 - the frame thread stops touching the mesh

The work order for phase 1d of `RECONCILIATION.md` § 9 (D85, 2026-09-05),
written in the shape of `docs/plans/horizon-v1.md` so that one agent can
execute it unattended: exact edits, exact checks, exact numbers, what the
agent may decide alone, what it may not, what to do when a check fails, and
what Marcel finds in the morning.

The direction is the bible: D84 (the north star; its third sentence, "the
frame holds", is this lane's whole subject), D85 (this lane runs before the
world-truth break because the upload touches nothing a seed produces), D56
(world truth changes once, and not here), D49 (hot paths in C++ - and this
lane adds none, see below). The measurement that names the fault is
`docs/status/horizon-v1.md` Stage 7 and "For Marcel" item 15. Read those
before this file.

**What horizon v1 measured (2026-09-05, ganymede, Ultra, seed 42, the
sixty-second sprint from spawn along `+X`).** Median 16.67 ms, three runs,
spread 0.00% - the median half of the frame gate is met. **171 to 233 frames
of about 3,340 over 25 ms - the hitch half is not.** With the C++ chunk
mesher merged the same sprint streams 12,870 chunks instead of 5,900 and the
median rises to 22.1 ms with 786 to 807 hitches: generation and meshing are
off the main thread now, so the queue no longer waits on them, and what is
left on the frame thread is the arrival of a column - `ChunkNode.new()`, a
`StaticBody3D` and a `CollisionShape3D` per chunk, `add_child`,
`ArrayMesh.add_surface_from_arrays` per chunk, `ConcavePolygonShape3D
.set_faces` per chunk - at 214 columns a second. Every rung of horizon's
shrink list made both numbers worse; a smaller `chunk_upload_budget_ms`
lengthens the queue and a second that would have paid eight milliseconds once
pays four twice and then arrives with a backlog. **The frame that build has is
the frame it wants.** So this lane does not move the budget. It makes the
thing the budget is spent on cheaper, and it measures which part of it is the
cost before touching any of it.

**What upload v1 is.** An instrument that splits a column's arrival into its
parts and prints them; then, rung by rung and each one measured against
`main` in the same session, the arrival made cheaper on the frame thread: the
atom of the pump shrunk from a column to a chunk; collision installed on its
own budget with the player's own ground always first; one node and one body
per column instead of one per chunk; the `ArrayMesh` built on the worker that
built its arrays; the flora buffers and the boulder bodies on the one pump
the far country already uses. Then the sprint line, with and without each
rung, and the ones that pay their way stay.

**What upload v1 is not.** No change to what a seed produces (the canonical
line is reprinted after every stage and one changed character is a red gate).
No change to what the mesher emits: the arrays a `ColumnJob` hands over are
byte-identical to today's, both meshers, and the upload parity gate proves it
every stage. No C++: this lane is about what happens AFTER the arrays exist,
and every one of its edits is GDScript on the frame thread or the worker. No
`HeightMapShape3D` for chunk collision - the shape stays derived from the
drawn faces (`chunk_node.gd`'s rule: you cannot stand on a face that is not
drawn, or walk through one that is) because edits must collide. No physics
thread (`physics/3d/run_on_separate_thread` stays false; it changes the timing
of every physics query in the game and is a different lane's question). The
render thread model is an EXPERIMENT in this lane (Stage 6), never a silent
change.

The three habits apply: the split is a table (habit 1); nothing here touches
the journal or the mutation path - an edit still goes through
`World.set_block` and the replay point in `_collect_chunks`.

---

## 0. The contract

**Who and where.** One agent, Opus, on ganymede, **Forward+ only**, in tmux
session `upload-v1`, worktree `~/Kubik-upload-v1`, branch `feat/upload-v1`
from `main` at or after `243bbda` (the tip that carries D85 and the macOS
gate fixes). Ganymede: Ubuntu 24.04, RTX 3070 Ti 8 GB, driver 595,
`~/bin/godot` 4.7.2, `~/godot-cpp` (pinned, API dumped), `~/bin/scons` (venv
`~/.venvs/scons`), `~/.venvs/kubik/bin/python` for PIL; windowed commands
under `xvfb-run -a -s "-screen 0 1280x720x24"` with `XDG_RUNTIME_DIR`
exported to a writable directory. The first console line of the first
windowed run must read `Vulkan 1.4 - Forward+ - Using Device #0: NVIDIA
GeForce RTX 3070 Ti`; anything else is a stop-and-record. The ALSA errors are
the missing sound card.

**No second lane runs these nights.** The box is this lane's. Benchmarks are
still taken as ABAB against a base worktree (section 2), because the box
drifts on its own.

| this lane OWNS | this lane may ADD ONE LINE to | this lane must NOT touch |
| --- | --- | --- |
| `scripts/world/world.gd` (`_process`, `_collect_chunks`, `_collect_flora`, `_submit_jobs`, `_free_distant_chunks`, `_restore_column`, `is_chunk_collidable`, the stats), `scripts/world/chunk_node.gd`, `scripts/world/column_job.gd` (the hand-over only: what `built[cy]` carries and what `run()` does AFTER the arrays exist), `scripts/world/flora/flora_column.gd`, `scripts/world/far_upload.gd`, `scripts/world/flora/tree_field.gd` (`_apply`, `_uploader` only), `scripts/physics/body_field.gd` (`column_landed` only), `scripts/world/worldgen_config.gd` (new LOCAL knobs only), `scripts/ui/debug_hud.gd` (new rows only), `scripts/tools/sprint_probe.gd`, `scripts/game/game.gd` (CLI flags and the ground wait only), NEW `scripts/tools/upload_bench.gd`, NEW `scripts/tools/selftest_upload.gd` + `scenes/selftest_upload.tscn`, `README.md` § Running it (the upload bench and the new summary fields only), `docs/status/upload-v1.md` | `scripts/tools/selftest.gd` (`"upload": SelftestUpload.run`), `project.godot` (Stage 6 only, and only under its ship rule) | `scripts/world/chunk_mesher.gd`, `gdext/` (anything), `scripts/world/terrain_generator.gd`, `heightmap.gd`, `lakes.gd`, `far_field.gd`, `far_field_job.gd`, `far_mesher.gd`, `flora/*_placement.gd`, `flora/tree_field_job.gd`, `flora/flora_job.gd`, `look.gd`, `sky_cycle.gd`, `chunk.gd`, `block.gd`, `STATUS.md`, `TODO.md`, `CLAUDE.md`, `../Kubik-bible`, `../Kubik-assets` |

**No new GDExtension class, no C++ edit, in this lane.** If a rung wants
C++ (a column's arrays concatenated natively, a shape built natively), it is
written as a finding under "For Marcel" with the measured GDScript cost
beside it, and the GDScript version ships or the rung does not.

**Branch.** `feat/upload-v1`. One commit per stage minimum, pushed to `origin`
after every stage. **The agent never force-pushes, never rewrites history,
never reverts anyone else's commit, never edits `../Kubik-bible` or
`../Kubik-assets`.** Findings for the bible go in the status doc under "For
the bible".

**The merge (Marcel's standing amendment of 2026-09-04, carried into this
lane).** When the run is COMPLETE and every gate of the last stage is GREEN,
the branch merges itself into `main` and pushes: `git fetch origin`, `git
merge origin/main` (resolve only trivial docs conflicts by keeping both sides'
substance; otherwise abort and stop), re-run the section 2 gates if any code
file changed in the merge, then `git push origin HEAD:main`, once more if
rejected. **Green for this lane means:** every self-test green, the canonical
line unchanged, the upload parity exact, and the sprint line NO WORSE than
the base worktree on BOTH numbers (median and over-25 count). If the hitch
gate (over-25 = 0) is not reached but both numbers improved, merge and print
the residual as BLOCKING with the split table beside it. If either number is
worse than base, do not merge: leave the branch pushed, say why in one line,
stop. Never merge a red or wrapped-early stage.

**Delivered by morning.** `feat/upload-v1`, pushed and (under the rule above)
merged; `docs/status/upload-v1.md` updated at the end of every stage (a run
that dies at 04:00 still leaves a record); the split table per stage; the
sprint probe's line per stage; the bench's line per stage; a final message in
the shape of section 6.

**Never.** No generator, mesher, far-field or flora-placement edit. No
change to the arrays a job emits. No `HeightMapShape3D` for chunks. No
physics thread. No `thread_model` change outside Stage 6 and its ship rule.
No column released to the player without collision under it. No world
coordinate stored as a large float (horizon's anchor rule stands: a column
node is anchored at its column's render-space origin). No question left
unrecorded.

**Reading order, before the first edit.** `CLAUDE.md` (World rules, Engine
rules, Where work runs), `docs/status/horizon-v1.md` (BLOCKING, Stage 3 "The
sprint, and what `far_rebuilds` counts now", Stage 6 "The rebase, measured",
Stage 7 whole, "For Marcel" 15), `docs/status/mesher-v1.md` (the twin and
the edit path, the AO shell, "For Fable at merge"), `docs/status/distance-v5.md`
Stage 1 (the uploader - the precedent for a budgeted handover and why a
slice is atomic), `docs/plans/horizon-v1.md` § 0 to § 5 (the shape) and § 0.1
(the sprint probe), this file. Then the code, top to bottom: `world.gd`
(`_process`, `_collect_finished`, `_collect_chunks`, `_collect_flora`,
`_submit_jobs`, `_submit_flora`, `_free_distant_chunks`, `_restore_column`,
`_replay_edits_for`, `is_chunk_collidable`, `set_block` and the edit path,
`_shift_anchors`), `chunk_node.gd` (all 200 lines), `column_job.gd` (all),
`chunk_mesher.gd` (`faces_from`, `arrays_to_mesh`, `build`, and READ ONLY),
`flora/flora_column.gd`, `far_upload.gd`, `flora/tree_field.gd` (`_apply`,
`_apply_species`, `_uploader`), `physics/body_field.gd` (`column_landed`,
`_spawn`), `tools/sprint_probe.gd`, `tools/mesh_bench.gd` (the shape of a
bench), `game.gd` (`_release_player_when_ground_exists`, the flag parsing
around line 209), `selftest.gd` (`edit while cached`, `edit during
generation`, `chunk parity`, `locomotion parity`), `selftest_horizon.gd` (the
shape of a lane's own gate file).

**Time budget** (wall clock, guidance): setup 0.5 h; Stage 0 3 h; Stage 1
2 h; Stage 2 3 h; Stage 3 3 h; Stage 4 2 h; Stage 5 1.5 h; Stage 6 1 h;
Stage 7 2 h; Stage 8 1 h. About nineteen hours: **one night and the day
after, in one session.** The run does not wait for a review; Marcel reads
whichever morning he is at and can stop or redirect the session then. A
stage that runs past 1.5x its budget is wrapped at its last green commit and
the next stage starts; what was left undone goes in the status doc. **Stage
0 is the exception**: it is never wrapped early, and if it cannot be made
green the run stops there (section 5).

---

## 1. The grill - questions asked before the run, answers taken

STATUS: **BOUND, 2026-09-05, by Fable** on Marcel's standing instruction
("do the tolerance and decide for me"; "yes lets decide on the upload
fix"). Marcel may overrule any of them in the morning; until he does, **an
answer here is binding.**

| # | question | answer | binds |
| --- | --- | --- | --- |
| 1 | The gate? | **The north star's frame rule, unchanged from horizon Q7**: at Ultra, seed 42, sixty seconds of sprint from spawn along `+X`, C++ mesher on, on ganymede with the box otherwise idle: median under 16.7 ms AND no frame over 25 ms. Three runs ABAB against the base worktree; medians and spread. The over-25 count is the number this lane exists to move; a run that lowers the median and raises the count has failed. | Stage 7 |
| 2 | Measure first, or fix first? | **Measure first, and the split is the deliverable of Stage 0.** No rung is attempted before the instrument says what share of a column's arrival is node creation, mesh upload, collision, flora and bodies. A rung that targets a share under 15% of the whole is not attempted. | Stage 0, every stage |
| 3 | What is the atom of the pump? | **A chunk, not a column.** Today `_collect_chunks` checks the budget between columns and installs a whole column inside it, so a frame can pay a column of seven chunks at once. The pump stops AT the budget at chunk granularity; a column's chunks may land across frames. `is_chunk_collidable` and `collision_applied` already carry per-chunk truth, so nothing above them changes. | Stage 1 |
| 4 | Collision: derived from the mesh, or a heightfield? | **Derived from the drawn faces, as today - `chunk_node.gd`'s rule stands.** What changes is WHEN: collision gets its own budget (`collision_budget_ms`) and its own nearest-first queue, and a column within `collision_now_radius` chunks of the player (2) is installed in the frame it lands, before anything else in that frame. The ground wait (`_release_player_when_ground_exists`) is unchanged and is the gate. | Stage 2 |
| 5 | Can the shape be built off the frame thread? | **Try it, prove it, or drop it.** `ConcavePolygonShape3D.new()` and `set_faces()` on the worker inside `ColumnJob.run()` is a physics-server call from a worker with the physics server on the main thread; Jolt builds its own mesh shape lazily when the shape reaches a body, so the saving may be nothing and the risk is real. Stage 2 measures where Jolt's cost lands, runs the self-test's 200-column stress twenty times, and keeps the rung only if it saves over 15% of the shape share AND prints no thread error AND never crashes. Otherwise the shape stays on the main thread and the queue of Q4 is the whole rung. | Stage 2 |
| 6 | One node per column, or one per chunk? | **One `ChunkNode` per column with one SURFACE per chunk and one `StaticBody3D` with one `CollisionShape3D` per chunk under it**, if and only if Stage 0 says node creation (`ChunkNode.new`, the body, the collider, `add_child`, the broadphase insert) is over 15% of the arrival. Surfaces stay per chunk so an edit still remeshes ONE chunk on the twin (mesher v1 Q7: the twin is the edit path, 6.4 ms a chunk, and a column-wide remesh would be a 40 ms hitch per broken block). `World._chunk_nodes` keys by chunk position still; the value may be a (node, surface index) pair. | Stage 3 |
| 7 | The `ArrayMesh` on the worker? | **Yes, under Godot's own definition of the thread model in use.** `rendering/driver/threads/thread_model` is 1 (Single-Safe) in `project.godot`: the rendering server runs on the main thread and calls from other threads are queued. `ArrayMesh.add_surface_from_arrays` packs the vertex format on the CALLING thread and queues the GPU part, so building the mesh inside `ColumnJob.run()` moves the packing off the frame and leaves the queued upload where it was. Measured, not assumed: Stage 4 reports what share of `mesh_us` left the frame. If Godot prints a thread-guard error or the parity gate goes red, the rung is dead. | Stage 4 |
| 8 | Flora and bodies? | **On the one pump.** `FloraColumn.apply_buffers` writes one `MultiMesh.buffer` per model slot and each write is a rendering-server call measured above a millisecond in distance v5; they become slices on the `FarUpload` the far country and the tree ring already share, one slice per slot, with the column's `draw_fraction` set in the commit. `BodyField.column_landed` spawns `RigidBody3D`s; they go on a per-frame count (`bodies_per_frame`, 8) nearest-first. Measured against the split; kept if it pays. | Stage 5 |
| 9 | The render thread model? | **An experiment, recorded, with a ship rule.** Stage 6 sets `rendering/driver/threads/thread_model` to 2, runs the gates and the sprint line, and ships it ONLY if every self-test is green, the tour's terrain windows are within noise of the same tree at model 1, and BOTH sprint numbers improve. Godot's own documentation says the multi-threaded model has known bugs; Marcel's Windows box and CI run the same project file. Flagged "For Marcel" whether shipped or not. | Stage 6 |
| 10 | The GDScript twin? | **Still a run, once.** `--mesher gdscript` at Stage 7, one sprint, so the twin's path through the new arrival is proven to work and its line is in the table; it is not a gate. The upload parity gate runs both meshers every stage. | Stage 7, gates |
| 11 | The initial load? | **A RECORD, not a gate, with a fence.** The load line at spawn (mesher v1: 12.4 s, 1,910 chunks) is printed every stage; a rung that slows it by more than 10% is reverted unless it is the rung that meets the hitch gate, in which case it ships and the number goes "For Marcel". `INITIAL_BUILD_BUDGET_MS` (16) and the doubled budget before `_initial_load_reported` stay. | every stage |
| 12 | Where is "before"? | **A base worktree in the same session.** `git worktree add ~/Kubik-upload-v1-base main` at the branch point, built and asset-mounted once; every sprint comparison is ABAB against it, three each. Never pushed, deleted in Stage 8. | section 2 |
| 13 | Knobs? | **All LOCAL and unhashed, on F4 under an `upload:` prefix**: `chunk_upload_budget_ms` (exists, 8), `collision_budget_ms` (2), `collision_now_radius` (2), `upload_atom_chunk` (1), `column_node` (0 until Stage 3 ships it), `mesh_on_worker` (0 until Stage 4), `flora_on_pump` (0 until Stage 5), `bodies_per_frame` (8). Every one is an A/B in a running game and none moves the config hash. | section 3 |
| 14 | Commit hygiene? | `feat(upload):`, `fix(upload):`, `docs(upload):`; body says what changed and what number judged it; the two trailers the harness gives this session at its start (the model that did the work and its session URL). | every commit |
| 15 | If a rung helps the median and hurts the hitches? | **It does not ship.** Section 5 item 4. The count is the gate. | every rung |

---

## 2. Setup and the gates

```
cd ~/Kubik && git fetch && git checkout main && git pull --ff-only          # 243bbda or later
git worktree add -b feat/upload-v1 ~/Kubik-upload-v1 main
git worktree add ~/Kubik-upload-v1-base main                                # the "before", never pushed
for d in ~/Kubik-upload-v1 ~/Kubik-upload-v1-base; do
  cd $d && git reset --hard origin/main
  python scripts/tools/sync_assets.py
  ~/bin/godot --headless --path . --import
  (cd gdext && scons platform=linux target=editor custom_api_file=../../godot-cpp/extension_api.json -j$(nproc))
  ~/bin/godot --headless --path . -s gdext/check.gd                         # "class exists: true"
done
cd ~/Kubik-upload-v1
```

**Baselines, same day, before the first edit**, in the base worktree and
copied into the status doc as **the baseline**:

```
<godot> --headless --path . scenes/selftest.tscn                                  # SELFTEST: all passed
<godot> --headless --path . --script scripts/tools/worldgen_probe.gd -- --seed 42   # heightmap 4782edac, spawn (-44, -124), 53 lakes, 15218 trees, config 1d7c18c7
<godot> --headless --path . -- --host --seed 42 --view ultra --sprint-probe --seconds 60 --label up-base-1   # x3
<godot> --path . -- --tour --seed 42 --label up-base                              # under xvfb-run
```

The three base sprints are expected near horizon's merged line: median about
22 ms, over-25 about 800, chunks about 12,900. If they are not within 15% of
that on chunks, the box is not quiet: find what is running, record it, and
take them again.

**The gates, run at the end of every stage, in this order:**

```
<godot> --headless --path . scenes/selftest.tscn
<godot> --headless --path . scenes/selftest_upload.tscn                           # this lane's own, from Stage 0
<godot> --headless --path . scenes/selftest_horizon.tscn
<godot> --headless --path . scenes/character/selftest_character.tscn
<godot> --headless --path . --script scripts/tools/worldgen_probe.gd -- --seed 42
   # heightmap 4782edac, spawn (-44, -124), 53 lakes, 15218 trees, config 1d7c18c7 - every character
<godot> --headless --path . --script scripts/tools/upload_bench.gd -- --seed 42     # from Stage 0; both meshers
<godot> --headless --path . -- --host --seed 42 --view ultra --sprint-probe --seconds 60 --label up-<n>-a   # ABAB x3 vs base
<godot> --path . -- --tour --seed 42 --label up-<n>                               # under xvfb-run; eye check only
```

then the stage's checks, then the status doc, then the commit and the push.
**The upload parity test is exact** (section 3) and it is red on one
differing byte. **A thread-guard error in any console log of a stage is a
red gate for that stage's rung** (`ERR_THREAD_GUARD`, "can't call the
function ... on this node", "not safe to call from a thread" - grep every log
for `thread`). The tour is an eye check in this lane: the mesh is proven
identical by the arrays, and the film grain makes pixels incomparable
(mesher v1 retired the picture gate for that reason).

---

## 3. The numbers

**The split** (Stage 0 builds it). Per column arrival on the frame thread,
microseconds, measured with `Time.get_ticks_usec()` around each part inside
`_collect_chunks` / `_collect_flora` and summed per second:

| field | what it times |
| --- | --- |
| `up_node_us` | `ChunkNode.new()`, `setup()` (the `StaticBody3D`, the `CollisionShape3D`, the physics material), `position`, `add_child` |
| `up_mesh_us` | `apply_arrays`'s mesh half: `ChunkMesher.arrays_to_mesh` (`ArrayMesh.new`, `add_surface_from_arrays`, `surface_set_material`) and the assignment to `mesh` |
| `up_shape_us` | `apply_arrays`'s collision half: `ConcavePolygonShape3D.new`, `set_faces`, the assignment to `_collider.shape` |
| `up_edit_us` | `_replay_edits_for` and the `rebuild` it may cause |
| `up_flora_us` | `FloraColumn.setup`/`add_child` and `apply_buffers` |
| `up_bodies_us` | `BodyField.column_landed` |
| `up_col_max_us` | the single most expensive column arrival in the second |

The sprint probe's per-second line gains `up=<node>/<mesh>/<shape>/<edit>/<flora>/<bodies> colmax=<us>`
(microseconds, integers) and the summary line gains `up_node_ms=`,
`up_mesh_ms=`, `up_shape_ms=`, `up_edit_ms=`, `up_flora_ms=`,
`up_bodies_ms=` (totals over the run) and `up_col_max_ms=` (the worst
column). `selftest_upload.gd`'s "sprint summary parse" test parses a line
with every field.

**The bench** (`scripts/tools/upload_bench.gd`, Stage 0). Headless, the
canonical seed, the spawn disc at `--radius` (default 8 chunks, about 200
columns): generate and mesh every column ONCE on the pool (not timed), then
time the ARRIVAL of every column on the main thread through the real
`_collect_chunks` path, ABAB against a second arrival path when one exists
(`--atom column|chunk`, `--column-node 0|1`, `--mesh-on-worker 0|1`), three
passes, medians and spread, and the split per column. One line per
configuration:

```
UPLOAD_BENCH mesher=<cpp|gdscript> atom=<..> column_node=<0|1> mesh_on_worker=<0|1> columns=<n> chunks=<c> col_median_us=<m> col_p99_us=<p> col_max_us=<w> node_us=<..> mesh_us=<..> shape_us=<..> per_chunk_us=<..>
```

This is the number a rung is judged on before the sprint is even run: a rung
that does not move `col_median_us` and `col_max_us` on the bench is not
worth a sprint.

**The frame (Stage 7).** Ultra, seed 42, sixty seconds from spawn along
`+X`, C++ mesher, the base worktree idle: **median under 16.7 ms and
over-25 = 0**; three runs ABAB against base, medians and spread. Every rung's
line goes in one table with the base's beside it.

**Upload parity (every stage, `selftest_upload.gd`).** For the canonical seed
and the 5 x 5 columns around the spawn, through the real arrival path with
every knob at its shipped value: for every chunk that has faces, `mesh
.surface_get_arrays(i)` read back from the installed mesh equals the
`ColumnJob`'s `built[cy]["arrays"]` for that chunk, vertex for vertex,
normal, colour and index, exact; `_collider.shape.get_faces()` equals
`built[cy]["faces"]` exact; the count of surfaces equals the count of chunks
with faces; `is_chunk_collidable` is true for every chunk with faces once the
column's collision has been pumped. Run for both meshers (`--mesher
gdscript` forces the twin - the arrays differ between meshers only where
mesher v1's own parity gate says they do not, so both legs must be exact
against their own job).

**Collision honesty (every stage).** After the pump, no chunk reports
`collision_applied` without a shape installed, and no shape is installed on a
parked node. The ground wait releases the player only after
`is_chunk_collidable` on the player's own column is true, exactly as today;
the sprint probe's `jumps` and `moved_m` are the field check (a player who
fell through the ground goes nowhere).

**Config knobs added, all LOCAL and unhashed, every one on F4 under
`upload:`:** `collision_budget_ms` (2.0), `collision_now_radius` (2),
`upload_atom_chunk` (1), `column_node` (0), `mesh_on_worker` (0),
`flora_on_pump` (0), `bodies_per_frame` (8). Each rung flips its knob's
default when it ships; the old path stays reachable by the knob for one epic
so the A/B survives the merge.

---

## 4. Tunables

The only numbers the agent may change on its own judgement. Everything else
in this file is fixed. Each change: the bench line or sprint line that
decided it, before and after, in the status doc.

| knob | where | start | range | judged on |
| --- | --- | --- | --- | --- |
| `chunk_upload_budget_ms` | config | 8.0 | 4-12 | sprint over-25 count (never below 4: horizon measured 4 and 2 as worse) |
| `collision_budget_ms` | config | 2.0 | 1-6 | sprint over-25 count, `jumps` |
| `collision_now_radius` | config | 2 | 1-4 | `jumps`, `moved_m`, the ground wait |
| `bodies_per_frame` | config | 8 | 2-32 | sprint over-25, the bodies share |
| slices per flora column | FloraColumn | one per slot | slots merged by 2 | sprint over-25 |
| `INITIAL_BUILD_BUDGET_MS` | world.gd | 16 | 16-32 | the load line at spawn |

---

## 5. Failure protocol

1. **A self-test or the probe goes red:** fix it within the stage; if the fix
   is not obvious in 20 minutes, revert to the stage's last green commit,
   record, and continue with the next stage only if it does not build on the
   reverted work (1 on 0, 2 on 1, 3 on 1, 4 on 1, 5 on 1, 6 on nothing, 7 on
   everything, 8 on nothing).
2. **The canonical world line changes by one character:** the stage is not
   done, whatever else passed. Find the write. No tolerance.
3. **Upload parity goes red:** the rung changed what reaches the screen.
   Revert the rung inside the stage; if the fix is not obvious in 20
   minutes, the rung is dead, record why, continue.
4. **A rung improves the median and worsens the over-25 count, or worsens
   either against base on the bench or the sprint:** it does not ship. Its
   knob stays in the tree at the old default, its line stays in the table.
5. **A thread-guard error, a "not safe to call from a thread" line, or a
   crash in any run of a worker-side rung (Stage 2's shape, Stage 4's mesh,
   Stage 6's model):** the rung is dead. Revert, keep the knob at 0, record
   the exact console line, continue.
6. **The sprint probe fails the frame gate at Stage 7:** record it as
   BLOCKING with the split table of the best configuration beside it, so the
   residual has a name (which share is left, and how big), and continue to
   Stage 8. The merge rule of section 0 decides whether the branch lands.
7. **`jumps` rises or `moved_m` falls against base in any rung's sprint:**
   collision arrived late somewhere. Raise `collision_now_radius` by one and
   re-run once; if it persists, revert the rung.
8. **The load line at spawn slows by more than 10%:** grill Q11.
9. **A question this file does not answer:** take the conservative reading
   (smaller change, nearer today's value, fewer files), write the question
   and the reading under "Questions taken alone", continue.
10. **Stage 0 cannot be made green:** push what exists, write the findings,
    stop the run. Nothing after Stage 0 is judgeable without its instrument.
11. **Godot hangs or a run crashes:** kill it, re-run once; if it repeats,
    record the command and the last console lines, continue without that
    evidence, saying so.
12. **`origin/feat/upload-v1` has moved:** it should not. `git pull
    --rebase`; a conflict is a stop-and-record.
13. **Memory on the box passes 12 GB for the game process:** something is
    retaining arrays after arrival (a job kept alive by a Callable). Fix
    before continuing.

---

## Stage 0 - The instrument, and the split

Nothing in this plan is judgeable without knowing which part of a column's
arrival the frame is paying for. The project has one number for all of it
(`_mesh_ms` in the load line) and that number is the sum.

### 0.1 The split in `world.gd`

Around each part named in section 3 inside `_collect_chunks` and
`_collect_flora`: `Time.get_ticks_usec()` before and after, accumulated into
seven counters on `World` (`up_node_us` ... `up_col_max_us`), reset by a
`take_upload_split() -> Dictionary` the probe calls once a second. The
`_mesh_ms` total stays for the load line and gains `job.mesh_usec` beside
`_gen_ms` (mesher v1's "For Fable at merge" request, one line). The load line
prints the split once at `_initial_load_reported`.

### 0.2 The probe

`sprint_probe.gd`: the per-second line and the summary gain the fields of
section 3. Nothing else in the probe changes; horizon's fields keep their
names and positions.

### 0.3 The bench

`scripts/tools/upload_bench.gd`, shaped like `mesh_bench.gd`: a `SceneTree`
script, `--seed`, `--radius`, `--passes`, `--mesher`, and one flag per rung
as it lands. It builds a `World` (added to the tree so `_process` runs),
submits the disc's columns, waits for the pool with `_collect_finished`
disabled, then times each column's arrival by calling the real installer
with an unbounded budget, ABAB when a second configuration is named. Prints
the `UPLOAD_BENCH` line per configuration and the split medians.

### 0.4 The gate file

`scripts/tools/selftest_upload.gd` + `scenes/selftest_upload.tscn`, shaped
like `selftest_horizon.gd`, and the one line in `selftest.gd`. Tests from
this stage: `sprint summary parse` (the new fields), `upload parity` (both
meshers, section 3), `collision honesty`. Later stages add theirs.

### 0.5 Checks

- The bench runs on base and on the branch (identical code so far) and
  agrees within 10%: it is an instrument.
- Three base sprints and three branch sprints ABAB: within noise. The split
  table from the sprint, medians per second, in the status doc: **this table
  decides Stages 2 to 5** (grill Q2: a share under 15% is not chased).
- The gates of section 2.
- Commit `feat(upload): stage 0 - the split, the bench, the gate file`.

---

## Stage 1 - The atom is a chunk

### 1.1 The pump

`_collect_chunks`: the budget check moves inside the column loop, per chunk.
A column whose remaining chunks did not fit stays in `_in_flight`'s done
list with a cursor (`entry["next_cy"]`), and the next frame resumes it;
`_column_landed`, `_frontier_advanced` and `_columns_built` fire when the
LAST chunk of the column is in, so the frontier and the far field see a
column exactly when they saw it before. `upload_atom_chunk` 0 restores
today's column atom for the A/B.

### 1.2 Checks

- Upload parity, collision honesty, `edit while cached`, `edit during
  generation` green: an edit landing on a half-installed column replays into
  the chunks not yet installed as it does today (the replay point is per
  chunk already).
- Bench: `col_max_us` is a column's cost either way; the sprint's
  `up_col_max_ms` should fall to about one chunk's cost. ABAB x3.
- Commit `feat(upload): stage 1 - the atom is a chunk`.

---

## Stage 2 - Collision on its own budget

### 2.1 The queue

`apply_arrays` splits: `apply_mesh(arrays)` and `apply_collision(faces)`.
`_collect_chunks` installs the mesh and pushes `(chunk_pos, faces)` onto a
collision queue ordered by `_queue_key` (nearest first, heading-biased as
the build queue is); `_pump_collision(budget)` runs right after
`_collect_finished` and spends `collision_budget_ms`. **Before the pump
spends anything**, every queued chunk whose column is within
`collision_now_radius` of the player's column is installed unconditionally -
the ground under the player is never budgeted. `is_chunk_collidable` stays
the truth: false until the shape is installed. A parked column drops its
queue entries; `_restore_column` re-queues.

### 2.2 The shape on the worker (grill Q5)

`ColumnJob.run()` gains, behind `shape_on_worker` (a LOCAL knob, default 0),
`built[cy]["shape"] = ConcavePolygonShape3D.new()` with `set_faces` called
on the worker; `apply_collision` assigns it. Measure on the bench: where does
the shape share go - to the worker (the resource's own copy) or does it stay
(Jolt building on assignment)? Stress: `selftest_upload.gd` `worker shape
stress` installs 200 columns twenty times with the knob at 1 and greps
nothing - the self-test cannot read its own console, so the STAGE's gate is
the log grep of section 2. Ship rule per Q5; the default flips only if it
passes.

### 2.3 Checks

- Collision honesty; the ground wait releases at the same frame count as
  base on `--tp 0 0` and on `--tp 20000 0` (the console prints "player
  released"; record both).
- `jumps` and `moved_m` within noise of base; section 5 item 7 otherwise.
- Bench and sprint ABAB x3; the split's shape share before and after.
- Commit `feat(upload): stage 2 - collision on its own budget`.

---

## Stage 3 - One node per column

Only if Stage 0's split says `up_node_us` is over 15% of the arrival.

### 3.1 The column node

`ChunkNode` becomes the column's node: one `MeshInstance3D` at the column's
render-space origin (chunk `(cx, 0, cz)`'s origin, minus `origin_offset_m`),
one `StaticBody3D`, and per chunk one surface on the one `ArrayMesh` (the
arrays offset by the chunk's y in the packing - on the worker, in
`ColumnJob`, so the arrays parity test compares against the OFFSET arrays
and the offset is part of the job's output) and one `CollisionShape3D` with
the chunk's faces (also offset). `_chunk_nodes[chunk_pos]` maps to `{node,
surface, collider}`. An edit remeshes one chunk on the twin as today and
replaces ONE surface: `surface_remove(i)` then `add_surface_from_arrays`,
with the surface index map rewritten; the collider is per chunk already.
`set_parked` parks the column. `_shift_anchors` moves one node per column.
`column_node` 0 restores today's node per chunk for the A/B.

### 3.2 Checks

- Upload parity (the offset arrays), collision honesty, every edit test,
  `chunk parity` (the mesher is untouched and must say so), the tour's eye
  check at `6-postcard` and `32-horizon-walk` (no seam, no missing chunk,
  no double-drawn chunk).
- Bench: `node_us` share; sprint ABAB x3.
- Commit `feat(upload): stage 3 - one node per column`.

---

## Stage 4 - The mesh built on the worker

Only if Stage 0's split says `up_mesh_us` is over 15% of the arrival.

### 4.1 The job packs the mesh

Behind `mesh_on_worker` (default 0): `ColumnJob.run()` builds the
`ArrayMesh` after the arrays (`ChunkMesher.arrays_to_mesh` is main-thread
by its own comment - this lane calls `ArrayMesh.new()` and
`add_surface_from_arrays` directly in the job and sets the material there
too; `chunk_mesher.gd` is not edited) and hands `built[cy]["mesh"]` over;
`apply_mesh` assigns it. Under thread model 1 the packing happens on the
worker and the server call is queued; the split says how much of the mesh
share left the frame.

### 4.2 Checks

- The log grep for thread errors (section 2), twenty bench passes and three
  sprints: none. Upload parity: the read-back arrays are exact.
- Bench: `mesh_us` share; sprint ABAB x3.
- Commit `feat(upload): stage 4 - the mesh is packed on the worker`.

---

## Stage 5 - Flora and bodies on the one pump

Only if Stage 0's split says `up_flora_us` + `up_bodies_us` is over 15%.

### 5.1 Flora slices

Behind `flora_on_pump`: `_collect_flora` submits a `FarUpload` job keyed by
the column, one slice per model slot (`apply_buffers` split into
`apply_slot(model, buffer)`), the commit setting `draw_fraction`, the
instance and triangle counts, and `bodies`. A column that leaves range while
its job is queued is dropped by the key rule the far country already has.
The pump is `FarField`'s (`_far_field.uploader()`), so the frame has one
budget for every handover.

### 5.2 Bodies

`BodyField.column_landed` spawns at most `bodies_per_frame` per frame,
nearest column first, from a queue it owns; `column_left` drops the queue's
entries for that column.

### 5.3 Checks

- `flora determinism`, `flora removal`, `body promotion` green; the tour's
  eye check for missing plants at `6-postcard`.
- Sprint ABAB x3; the flora and bodies shares.
- Commit `feat(upload): stage 5 - flora and bodies on the one pump`.

---

## Stage 6 - The render thread model, as an experiment

`project.godot`: `rendering/driver/threads/thread_model=2`. The gates of
section 2, the bench, three sprints ABAB against the branch at model 1, the
tour. The ship rule is grill Q9 and it is strict; the default is that this
does NOT ship. Either way the status doc records the two lines side by side
and the tour's windows, and "For Marcel" carries the recommendation.

- Commit `docs(upload): stage 6 - the thread model, measured` (and
  `feat(upload): ...` only under the ship rule).

---

## Stage 7 - The sprint line

The north star's third sentence, measured, with every rung that shipped.

### 7.1 The runs

At Ultra, on ganymede, the base worktree idle: the branch three times ABAB
against base, then each shipped rung turned OFF one at a time (its knob) for
one run each, so the table says what each one bought, then `--mesher
gdscript` once. Medians, spreads, the over-25 count, `up_col_max_ms` and
the split, in one table.

### 7.2 The gate

Median under 16.7 ms and over-25 = 0 on the plain branch run. If it fails:
section 5 item 6, and the merge rule of section 0. The result, PASS or
BLOCKING with the residual's name, is the first line of the morning message.

- Commit `docs(upload): stage 7 - the sprint line`.

---

## Stage 8 - Docs, the merge, the base worktree

`README.md` § Running it: the upload bench, the new summary fields, the
`upload:` knobs, one paragraph. `worldgen_config.gd`: every new knob's
comment says LOCAL and why. `docs/status/upload-v1.md` complete. `STATUS.md`,
`TODO.md`, `CLAUDE.md` are not this lane's: the requests for them go in the
status doc under "For Marcel". `git worktree remove ~/Kubik-upload-v1-base`.
Then the merge rule of section 0.

- Commit `docs(upload): status, the requests, the morning message`.

---

## 6. The status doc and the morning message

`docs/status/upload-v1.md`, in the shape of `horizon-v1.md`, updated at the
end of every stage with, per stage: what shipped; the canonical line; the
split table; the bench line; the sprint line ABAB against base; every
tunable changed (was / now / number); the checks; "Questions taken alone";
"For Marcel"; "For the world-truth break" (anything this lane noticed about
columns that the break will change); "For the bible". At the top, before
anything: any BLOCKING finding.

The final message to Marcel, in this order and nothing else first:

1. `feat/upload-v1`'s last commit; which stages are green, which were
   wrapped early, which rungs shipped and which were reverted, and whether
   the branch merged to `main` (with the sha) or why not.
2. The sprint line: median, p99, worst, over-25, `up_col_max_ms`, against
   base, plain and per rung. PASS or BLOCKING, and if BLOCKING the residual's
   name from the split.
3. The load line at spawn against base.
4. Every "For Marcel" item, one line each - the thread model's
   recommendation first.
5. Every tunable moved off its start, one line each.
6. What is left.
