# Mesher v1 - phase 1b of the reconciliation: the chunk mesher in C++

The work order for phase 1b of `RECONCILIATION.md` section 9 ("The chunk
mesher in C++", bible D56), written in the shape of `docs/plans/light-v1-tech.md`
and `docs/plans/distance-v4.md` so that one agent can execute it unattended:
exact edits, exact checks, exact numbers, what the agent may decide alone,
what it may not, what to do when a check fails, and what Marcel finds in the
morning.

The direction is `CLAUDE.md` § Engine rules, three sentences of it: **hot
paths in C++** (D42, D49 - "chunk meshing ... live in `gdext/`; delete each
GDScript twin as its C++ path lands"), **keep the seam discipline** (data in,
arrays out, marshalled once per world, every value quantised on both sides so
gcc and MSVC cannot produce two worlds), and **the mesher decides how a chunk
looks, never what it is**. The audit that makes the case is
`docs/reconciliation/02-world-render.md` § C3 and § 3: GDScript worker
threads are serialised to about one effective thread, and the chunk mesher
is **76% of the column job** (`docs/status/trees-v3.md`, the real-forest
column: 29.63 ms of mesh against 5.81 ms of voxels).

**What phase 1b is.** `ChunkMesher.build_arrays()` - greedy meshing over
three axes, the sign-encoded face mask, the corner AO codes, the flat colour
per material, the winding rule - rewritten as `KubikChunkMesher` in
`gdext/src/chunk_mesher.{h,cpp}`, called once per chunk from `ColumnJob` on
the worker, with the GDScript mesher kept in-tree as the reference twin and a
parity gate that says the two emit the same arrays. The worker's GDScript time
per chunk goes to the cost of handing over bytes.

**What phase 1b is not.** Not voxel generation: `TerrainGenerator.generate_ground_into`,
`column_surface_range`, the zone pass, lakes and the heightmap store are the
world-truth break (D56, phase 5) and are not touched here. Not the far field:
`gdext/src/far_*` and `height_tiles.*` are read for their pattern and never
edited. Not a look change: with `ao_strength` 0 every quad carries
`Look.to_wire(Block.color_of(id))` and nothing else (light v1 Stage 3.2), and
the parity gate is what proves the picture did not move. Not a probe: Q23's
stream probe hangs, and the instrument that replaces it is the HORIZON lane's
`--sprint-probe` (horizon-v1 Stage 0), not anything built here.

**The lane runs beside another one.** `docs/plans/horizon-v1.md` executes on
the same nights in `~/Kubik-horizon-v1` on `feat/horizon-v1`. The two never
edit the same file; the ownership table in section 0 is the whole of that
contract and the horizon plan carries its mirror image. Both branch from the
same `main`; both are merged by Fable, who resolves nothing because there is
nothing to resolve.

---

## 0. The contract

**Who and where.** One agent, Opus, on **ganymede** (Ubuntu 24.04, RTX 3070
Ti 8 GB, driver 595), in tmux session `mesher-v1`, in the worktree
`~/Kubik-mesher-v1` on branch `feat/mesher-v1`, `claude --permission-mode
auto --effort high --model opus`. Tools: `~/bin/godot` 4.7.2, `~/bin/scons`
(the `~/.venvs/scons` venv; not on a non-interactive PATH), `~/godot-cpp`
pinned at `26fb7ab` with `extension_api.json` already dumped from this exact
binary, `~/.venvs/kubik/bin/python` for anything with PIL. Windowed commands
run under `xvfb-run -a -s "-screen 0 1280x720x24"` with `XDG_RUNTIME_DIR`
exported to a writable directory; the first console line of a tour must read
`Vulkan 1.4 - Forward+ - Using Device #0: NVIDIA GeForce RTX 3070 Ti` or the
run stops and records before Stage 0. The ALSA errors under it are the
missing sound card. **Marcel's Windows box (RTX 5080)** rebuilds the DLL
from this branch's head in the morning (Fable, Q9) and re-measures the cost
line there; overnight work never runs there.

**Branch.** `feat/mesher-v1` from `main` at the commit the launcher records.
One commit per stage minimum, pushed to `origin` after every stage. Merged
to `main` by Fable after Marcel's morning review, alongside `feat/horizon-v1`.
**The agent never force-pushes, never rewrites history, never reverts anyone
else's commit, never touches `main` directly, never merges or cherry-picks
from `feat/horizon-v1`, and never edits `../Kubik-bible` or
`../Kubik-assets`.** Findings for the bible go in the status doc under "For
the bible".

**Delivered by morning.** `feat/mesher-v1`, pushed; `docs/status/mesher-v1.md`
updated at the end of every stage (a run that dies at 04:00 still leaves a
record); `gdext/src/chunk_mesher.{h,cpp}` registered and built on linux;
the parity gate in the self-test; `scripts/tools/mesh_bench.gd` and its
table; the tour cost line at Ultra with the C++ mesher on and off; a final
message in the shape of section 6.

**File ownership - the zero-overlap table.** This is binding for the whole
run. A file not in the first two rows is not this lane's, whatever the reason.

| may | files |
| --- | --- |
| **edit freely** | `gdext/src/chunk_mesher.h`, `gdext/src/chunk_mesher.cpp` (both new); `gdext/src/register_types.cpp` (append the class); `scripts/world/chunk_mesher.gd`; `scripts/world/column_job.gd`; `scripts/world/chunk_node.gd`; `scripts/world/chunk.gd`; `scripts/tools/selftest.gd` (its own tests appended, no assertion removed); `scripts/tools/mesh_bench.gd` (new); `docs/status/mesher-v1.md`; `docs/plans/mesher-v1.md` |
| **add ONE line to** | `scripts/ui/debug_hud.gd` (the F3 `mesher:` line, next to `far mesher:`); `README.md` § "Two things are C++, and you do not need either" (the heading becomes three, one paragraph appended) |
| **never edit** | `scripts/world/world.gd`, `far_field.gd`, `far_field_job.gd`, `far_upload.gd`, `heightmap.gd`, `terrain_generator.gd`, `lakes.gd`, `worldgen_config.gd`, `look.gd`, `sky_cycle.gd`, `valley_fog.gd`, `flora/*`, `scripts/player/*`, `scripts/game/*`, `scripts/physics/*`, `gdext/src/far_*`, `gdext/src/height_tiles.*`, `gdext/SConstruct`, `kubik.gdextension`, `project.godot`, `scenes/*`, `STATUS.md`, `TODO.md`, `CLAUDE.md`, `RECONCILIATION.md`, `docs/DESIGN.md`, every other `docs/` file |
| **read only, both lanes** | `scripts/world/block.gd` |

If the mesher genuinely needs a hook in `world.gd` - and section 3 already
names one it will want - the agent writes the one-line request under "For
Fable at merge" in the status doc and works around it meanwhile. There is
no other way to touch a file outside the table.

**Never.** No edit to voxel generation. No new knob in `worldgen_config.gd`
(not this lane's file; the switch lives on `ChunkMesher`, Q6). No change to
`Block.COLORS` or any palette hex. No colour arithmetic in C++ (Q3). No
change to the winding rule, the AO corner order or the mask encoding - the
port reproduces `chunk_mesher.gd` line for line and the parity gate is the
proof. No new textures, no shader edits. No question left unrecorded.

**Reading order, before the first edit.** `CLAUDE.md` (§ Engine rules, §
Where work runs), `RECONCILIATION.md` § 9 row 1b,
`docs/reconciliation/02-world-render.md` § C3 and § 3,
`docs/plans/distance-v4.md` (all of it: the decisions, the hard rules, the
stage discipline of the first C++ epic), `docs/status/distance-v4.md`
(Stage 6's numbers method and the Windows addendum), `docs/status/light-v1.md`
§ "Column job, before and after" and Q27, this file. Then
`scripts/world/chunk_mesher.gd` TOP TO BOTTOM (485 lines - it is the thing
being ported and every comment in it is a rule), `column_job.gd`, `chunk.gd`,
`chunk_node.gd`, `block.gd` (the enum, `COLORS`, `is_solid`, `color_of`),
`look.gd` `to_wire()` only, `world.gd` lines 740-760 (`_submit_column`), 838-848
(`_column_neighbour_chunks`), 997-1050 (`_collect_chunks`) and 469-476
(`is_solid_world`) - all read-only; `terrain_generator.gd` `is_solid_at()`
(736-740) and `surface_at()` (706-707) - read-only; `gdext/src/far_mesher.{h,cpp}`,
`far_build.cpp` (the `setup(Dictionary)` / `build(Dictionary)` shape),
`height_tiles.{h,cpp}` (the `cfg_f` reader, the QUANTUM idiom),
`register_types.cpp`, `gdext/SConstruct`, `gdext/check.gd`;
`scripts/tools/selftest.gd` (`_test_winding`, `_measure_ao_cost`,
`_test_chunk_determinism`, `_test_height_tile_parity` - the parity template),
`scripts/tools/far_probe.gd` § `_bench_table` (the ABAB idiom),
`scripts/tools/worldgen_probe.gd` (the `--script` probe shape `mesh_bench.gd`
copies).

**Time budget** (wall clock, guidance): setup 0.5 h; Stage 0 3 h; Stage 1
4 h; Stage 2 2.5 h; Stage 3 3 h; Stage 4 1.5 h. Fourteen and a half hours:
**one long night, or two** (Q2). If the run wraps inside Stage 3, the second
night begins by finishing it. A stage that runs past 1.5x its budget is
wrapped at its last green commit and the next stage starts; what was left
undone goes in the status doc. **Stage 0 is the exception**: it is never
wrapped early, and if it cannot be made green the run stops there (section 5).

---

## 1. The grill - questions asked before the run, answers taken

STATUS: **BOUND by Fable, 2026-09-04**, on Marcel's standing instruction to
take the recommendations; Marcel may overrule any in the morning, and an
overruled answer is re-run from the stage that used it. **An answer here is
binding.**

| # | question | proposed answer | binds |
| --- | --- | --- | --- |
| 1 | What crosses the seam, and what never does? | **Voxels in, arrays out.** `KubikChunkMesher` is a `RefCounted` with `setup(Dictionary)` once per world (`block_size`, `ao_strength`, the wire palette table of Q3) and `build(Dictionary)` once per chunk: the chunk's own `voxels` (4,096 bytes), and for each of the six faces either the neighbour chunk's `voxels` (`n_px`, `n_nx`, `n_py`, `n_ny`, `n_pz`, `n_nz`; a `PackedByteArray` is copy-on-write, so handing it over costs a reference) or, where no neighbour chunk exists, the surface strip of Q4. Out: `verts`, `normals`, `colors`, `indices` as packed arrays plus `quads`. **It never holds a reference to `Chunk`, `TerrainGenerator`, `WorldgenConfig` or `Look`, and never calls back into GDScript during a build.** Decision 2 of distance v4, verbatim in spirit. | Stages 0-3 |
| 2 | One night or two? | **Budgeted at one long night**; the second is the finishing night if Stage 3 is not green by 06:00. Night two starts from the branch head after `git pull --ff-only`. | § 0 |
| 3 | The Windows self-test reads 1 FAILED today (the far pyramid slope, a double ULP) and read 7 and 15 in the two C++ epics before it, every one a last-bit colour rounding. Does this lane add to that number? | **No: colour crosses as a table, not as arithmetic.** GDScript computes `Look.to_wire(Block.color_of(id) * shade)` for every id in `Block.COLORS` and every AO level 0-3 - 24 x 4 = 96 colours - ONCE in `ChunkMesher.setup_backend()` and hands the table to `setup()` as a `PackedColorArray`. The C++ colour path is an index. Both meshers then read the same float from the same engine call, so the gate is **exact zero on every platform**, Windows included. The distance v4 addendum's two-ULP allowance is the documented fallback if a later stage must compute colour in C++; nothing in this plan needs it. | Stage 2 |
| 4 | `solid_outside` is a `Callable` today: a neighbour chunk's byte where one exists, else `generator.is_solid_at()` = `by < 0 or by <= surface_at(bx, bz)`. What does the C++ get for the "else"? | **A surface strip, exact.** For a face with no neighbour chunk the dispatcher passes a `PackedFloat32Array` of `generator.surface_at()` values: 16 x 16 for the bottom face (the column's own footprint), 16 for each of the four sides (the row of blocks just outside), plus `origin_y` so the C++ can evaluate `by <= surface` for itself. Same expression, same floats, same answer as the twin. The strip is built once per COLUMN in `ColumnJob` (not per chunk) and only for the sides that need it. Its cost is measured in Stage 0 (it is GDScript calling the generator) and recorded; if it exceeds 0.3 ms per chunk on ganymede, Stage 3 may replace the bottom grid with the assertion path: a self-test over 10,000 sampled columns that proves every block one below a column's lowest chunk is solid, after which the bottom face passes `solid` and no grid. **Exact first, shortcut only with proof.** | Stages 0, 3 |
| 5 | AO on needs the eight blocks around the air cell, which at a chunk edge reach the diagonal neighbours a six-face border cannot answer. | **AO on is the photograph path and pays for itself.** `ao_strength` is 0 by default (light v1 Q9) and the merge is by id alone; that is the streaming path and it is all C++. When `ao_strength > 0` the dispatcher builds the full 18 x 18 x 18 solidity shell in GDScript through the Callable and hands it as `shell` (5,832 bytes); the C++ reads corners off the shell. Slower, correct, exercised by the winding test's `ledge@0.45` case and by Q27's measurement, never by the game at its defaults. | Stage 2 |
| 6 | How is the C++ path switched off for an A/B, given `worldgen_config.gd` is not this lane's file? | **A static on `ChunkMesher`.** `ChunkMesher.backend` is `"cpp"` when `ClassDB.class_exists("KubikChunkMesher")` and the class answers `ping()`, else `"gdscript"`; `--mesher gdscript` in `OS.get_cmdline_user_args()` forces the twin at first use, and the self-test flips it directly. The F3 line reads `mesher: cpp` / `mesher: gdscript` / `mesher: gdscript (no c++ library)`. No config knob, no F4 row, nothing saved to `user://`. | Stage 3 |
| 7 | Where does the twin live, and when does it die? | **`ChunkMesher.build_arrays()` becomes the dispatcher; the body it has today moves verbatim to `ChunkMesher.build_arrays_gd()` and is the reference.** Retirement is not this lane's call: the status doc proposes it (`chore(mesher): retire the GDScript twin`, one commit, once the parity gate has been green on BOTH boxes across this lane's landing and the next merged epic), and Marcel rules in the morning. Until then the edit path (`ChunkNode.rebuild()` -> `ChunkMesher.build()`, one chunk, main thread) stays on the twin - one chunk per edit is not a hot path. | Stages 0, 4 |
| 8 | What is the parity gate, exactly? | **Identical arrays.** For every chunk the self-test meshes both ways: `verts.size()`, `indices.size()`, `quads` equal; every vertex, normal, index and colour component equal to the bit; and quads emitted in the SAME order (the sweep order is `d`, `slice`, `jv`, `iu`, and the port keeps it, so no canonical re-sort is needed - if a stage ever needs one, the status doc says so and why). Printed as `chunk parity: N chunks, M quads, max diff pos 0.000000000 normal 0.000000000 colour 0.000000000, 0 indices differ`. Anything else is red. | Stages 1-3 |
| 9 | The Windows library. | **Rebuilt by Fable on Marcel's box from the branch head** in the morning (`cd gdext && python -m SCons platform=windows target=editor custom_api_file=../../godot-cpp/extension_api.json -j8`, then `--import`, then the self-test); the Windows parity count is recorded by Fable in the status doc's addendum, as distance v4 and v5 did. The agent does nothing for Windows except keep Q3. | § 6 |
| 10 | What is measured, and how? | **Three numbers, ABAB, medians with spread, ganymede editor target, `pgrep godot` empty before each.** (a) mesh time per chunk, twin vs C++, over the 441 columns of the seed-42 spawn disc, three interleaved passes each (`mesh_bench.gd`); (b) the load line at spawn with the C++ mesher on and off (`[World] N chunks in M ms wall`, three runs each, interleaved); (c) the tour cost line at Ultra, on and off. Target for (a): **C++ at or under 0.5 ms per chunk median and at least 10x the twin**; the twin's own number is measured, not assumed - today's "gen per chunk" excludes meshing entirely (`world.gd:1012` sums `gen_usec + tree_usec`), so no document has ever printed it. | Stages 0, 3 |
| 11 | Q27: baked AO off did not widen the merge (+0.0%). | **Measured in C++ and in the twin, same chunks, both `ao_strength` 0.0 and 0.45**: quads, verts, mesh ms. The self-test's `ao cost` line already does this for the twin over a 5 x 5 x 3 window of seed 31337; `mesh_bench.gd --ao` does it for both meshers over the spawn disc. Reported as a table; nothing is changed because of it. | Stage 2 |
| 12 | The cost instrument for "walking lag". | **The tour cost line, exactly as light v1 night two took it** (twenty frames per settled vantage, worst and median), Ultra preset, ganymede, C++ on and off. `--stream-probe` is not run (four attempts, four hangs). `--sprint-probe` is the horizon lane's Stage 0 and lives on `feat/horizon-v1`; this lane does not merge it, so **it is run against the mesher by Fable at merge time, not tonight**. The 60 FPS floor while sprinting is the horizon plan's gate; this plan reports its contribution and says so in those words. | Stage 3 |
| 13 | Commit hygiene? | `feat(mesher):`, `fix(mesher):`, `docs(mesher):`; body says what changed and which gate proved it; trailers `Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>` and `Claude-Session: https://claude.ai/code/session_012UVKGx4zoRXCDB1ZUqRZyX`. | all |
| 14 | If the port is slower than the twin at any stage? | It cannot be; if it measures so, the marshal is wrong (a per-face Dictionary, a per-quad `Array`, a `Variant` in the inner loop). Find it before Stage 3 wires the dispatch; record the wrong number and the fix. | Stage 3 |

---

## 2. Setup and the gates

```
cd ~/Kubik && git fetch origin && git worktree add -b feat/mesher-v1 ~/Kubik-mesher-v1 origin/main
cd ~/Kubik-mesher-v1 && git reset --hard origin/main      # worktree add resolved a stale main once before
export PATH="$HOME/bin:$PATH"; export XDG_RUNTIME_DIR=/tmp/xdg-$USER; mkdir -p "$XDG_RUNTIME_DIR"
cd gdext && scons platform=linux target=editor custom_api_file=../../godot-cpp/extension_api.json -j$(nproc) && cd ..
godot --headless --path . --import
python scripts/tools/sync_assets.py            # the tree library must be mounted; a treeless tour judges nothing
godot --headless --path . -s gdext/check.gd    # "class exists: true", the ping, the bench
```

**Baselines, same worktree, before the first edit:**

```
godot --headless --path . scenes/selftest.tscn                                   # SELFTEST: all passed
godot --headless --path . scenes/character/selftest_character.tscn
godot --headless --path . --script scripts/tools/worldgen_probe.gd -- --seed 42   # heightmap 4782edac, spawn (-44, -124), 53 lakes, config hash
xvfb-run -a -s "-screen 0 1280x720x24" godot --path . -- --tour --seed 42 --label mesher-base
```

The probe's line is copied into the status doc as **the baseline** and must
read `heightmap 4782edac, spawn (-44, -124), 53 lakes`, with the config hash
as printed. **This lane edits no config field, so the hash cannot move; it is
printed after every stage anyway.** The tour's cost line at Ultra is the
cost baseline, twin mesher.

**The gates, run at the end of every stage, in this order:**

```
cd gdext && scons platform=linux target=editor custom_api_file=../../godot-cpp/extension_api.json -j$(nproc) && cd ..
godot --headless --path . -s gdext/check.gd
godot --headless --path . scenes/selftest.tscn                     # incl. chunk parity, exact
godot --headless --path . -- --mesher gdscript scenes/selftest.tscn # once more with the twin forced (Stage 3 on)
godot --headless --path . scenes/character/selftest_character.tscn
godot --headless --path . --script scripts/tools/worldgen_probe.gd -- --seed 42
godot --headless --path . --script scripts/tools/mesh_bench.gd -- --seed 42      # Stage 0 on
xvfb-run -a -s "-screen 0 1280x720x24" godot --path . -- --tour --seed 42 --label mesher-<n>
```

then the stage's checks, then the status doc, then the commit and the push.

**Magenta is a red gate.** `Block.color_of()` returns magenta for an id
outside the palette; a magenta face in any tour shot is an index bug in the
port and the stage is not green until it is gone.

**A tour shot must not change.** The port is invisible by construction; the
far band diff of distance v4 Stage 8 is repeated here on the NEAR band:
`mesher-base` versus `mesher-3` at the same vantage, same seed, same hour -
zero differing pixels over the terrain rows is the gate, and the sky and
grain rows (which the lens and the clock own) are excluded by cropping. The
parity gate made visible, and cheap.

---

## 3. The numbers

**The world.** Seed 42, `heightmap 4782edac`, spawn `(-44, -124)`, 53 lakes,
15,218 trees, 2,222 chunks at spawn on the high preset (light v1). The
spawn disc at `voxel_radius_chunks` 12 is 441 columns; `mesh_bench.gd`
meshes every chunk of every one of them.

**The mesher today, in GDScript.** Real-forest column, trees v3 Stage 7:
**29.630 ms of mesh** per column against 5.811 ms of voxels (76% of the job).
Average over the spawn disc: **never printed** - `world.gd`'s "gen per
chunk" is `gen_usec + tree_usec` and leaves `mesh_usec` on the floor. A
lower bound from light v1's load line: 19,105 ms wall less 3.28 ms x 2,222
of generation less 8.62 ms x 797 flora columns is about 4.9 s over 2,222
chunks, so **not less than 2.2 ms per chunk**, and the true number is what
Stage 0 measures first.

**The pool.** One effective GDScript thread (`world-feel-v1.md:143-147`).
Every millisecond this lane removes from the worker is a millisecond the
flora columns, the tree ring and the far mesher stop waiting.

**The gates as numbers.**

| gate | value | kind |
| --- | --- | --- |
| chunk parity, every stage from 1 | 0 differing components, 0 differing indices, equal quad counts | deterministic |
| winding, both AO cases, both meshers | 0 wrong triangles | deterministic |
| canonical world line | `4782edac`, `(-44, -124)`, 53, unchanged config hash | deterministic |
| near-band tour diff, base vs Stage 3 | 0 differing pixels over the terrain rows | deterministic |
| C++ mesh per chunk, spawn disc | <= 0.5 ms median; >= 10x the twin's median | ABAB median |
| load at spawn, C++ vs twin | reported; expected lower, not gated | ABAB median |
| tour cost line at Ultra, C++ vs twin | reported; the 60 FPS floor is horizon-v1's gate | single run, twenty frames |
| Windows parity count (Fable, morning) | unchanged from today's 1 | deterministic |

**The API, so the two sides cannot drift.** `setup({"block_size": float,
"ao_strength": float, "palette": PackedColorArray[96]})` where
`palette[id * 4 + level]` is `Look.to_wire(Color(c.r * s, c.g * s, c.b * s, c.a))`
with `s = 1.0 - ao_strength * (1.0 - level / 3.0)`, `c = Block.COLORS[id]`,
level 0-3, id 0-23 - computed in GDScript, once. `build({"voxels":
PackedByteArray[4096], "origin_y": int, "n_px" ... "n_nz": PackedByteArray[4096]
or absent, "s_bottom": PackedFloat32Array[256] or absent, "s_px" ... "s_nz":
PackedFloat32Array[16] or absent, "shell": PackedByteArray[5832] or absent})`
returning `{"verts": PackedVector3Array, "normals": PackedVector3Array,
"colors": PackedColorArray, "indices": PackedInt32Array, "quads": int}`.
An empty Dictionary for a chunk with nothing to draw, exactly where the twin
returns `[]`.

---

## 4. Tunables

The only numbers the agent may change on its own judgement. Everything else
in this file is fixed.

| knob | where | start | range | judged on |
| --- | --- | --- | --- | --- |
| `mesh_bench.gd` passes per leg | the bench | 3 | 3-5 | the spread; more passes if the spread exceeds 15% |
| bottom-strip shortcut (Q4) | `ColumnJob` | off | off / on with the proof test | Stage 0's strip cost |
| `-O` level in the port's compile flags | `SConstruct` is not this lane's; nothing | godot-cpp default | none | - |

There is no tunable that changes a vertex, a normal, an index or a colour.

---

## 5. Failure protocol

1. **The parity gate goes red:** fix within the stage; if the cause is not
   found in 30 minutes, bisect by axis (`d` = 0, 1, 2), then by facing, then
   by slice - the twin's sweep order is the C++'s, so the first differing
   quad names the line. Never widen the gate. If still red at 1.5x the stage
   budget, revert to the last green commit and record which quad, which
   chunk, which component.
2. **The self-test or the probe goes red for a reason outside meshing:** it
   is not this lane's code; record and continue only if the red line is one
   this lane cannot have caused (the status doc quotes it).
3. **`check.gd` cannot load the class after a build:** the registration or
   the `SConstruct` glob; the library is `Glob("src/*.cpp")` so a new file is
   picked up without an edit - if it is not, record the compiler line and stop
   Stage 0 (item 8).
4. **The C++ measures slower than the twin (Q14):** find the marshal fault
   before wiring Stage 3; record the wrong number.
5. **Stage 3's load line is worse than the twin's on all three runs:** the
   dispatch is doing work per chunk it should do per column (the strips, the
   shell); fix; if still worse, leave the dispatch OFF by default
   (`ChunkMesher.backend` forced `"gdscript"`), push, and say so in the
   morning message as BLOCKING.
6. **A tour shot differs in the near band:** that is a parity miss the gate
   did not catch (a chunk the bench does not cover, the edit path, a border);
   treat as item 1.
7. **A question this file does not answer:** take the conservative reading
   (fewer files, nearer today's behaviour, exactness over speed), write the
   question and the reading under "Questions taken alone", continue.
8. **Stage 0 cannot be made green after the full procedure:** push what
   exists, write the findings, stop the run.
9. **Godot hangs or a tour crashes:** kill it, re-run once; if it repeats,
   record the command and the last console lines, continue without that
   evidence, saying so.
10. **`origin/feat/mesher-v1` has moved:** it should not; `git pull --rebase`,
    and a conflict is a stop-and-record. **`origin/feat/horizon-v1` moving is
    not this lane's business** and is never pulled.

---

## Stage 0 - The toolchain, the harness, the dispatcher scaffold (3 h)

### 0.1 The toolchain proves itself on this worktree

Section 2's setup, verbatim. `gdext/src/chunk_mesher.{h,cpp}` created as the
stub: `KubikChunkMesher : RefCounted`, `_bind_methods()` binding `ping()`,
`setup(world)`, `is_ready()`, `build(args)`; `ping()` returns
`"kubik chunk mesher, C++"`; `build()` returns an empty Dictionary.
`register_types.cpp` gains `#include "chunk_mesher.h"` and
`GDREGISTER_CLASS(KubikChunkMesher);` after the two existing lines. Build;
`check.gd` is not edited (it belongs to the far mesher) - the load proof is
`ClassDB.class_exists("KubikChunkMesher")` printed by the new self-test.

### 0.2 The dispatcher scaffold, behaviour unchanged

`chunk_mesher.gd`: the body of `build_arrays()` moves to
`build_arrays_gd()`, byte for byte; `build_arrays()` becomes

```
static func build_arrays(chunk, solid_outside, config, world_seed) -> Array:
    return build_arrays_gd(chunk, solid_outside, config, world_seed)
```

plus `static var backend := ""` and `static func backend_name() -> String`
(Q6; tonight it only ever answers `"gdscript"` because the class's `build()`
is a stub, and `class_present()` tests `ping()` AND a non-empty `build()` on
a one-block chunk before it will say `"cpp"`). `setup_backend(config)`
builds the 96-entry wire palette of Q3 and calls `setup()` on the C++
instance; it is called from `ColumnJob.run()` guarded by a static flag so it
runs once per world, and from the self-test directly.

### 0.3 The parity harness, before the port

`selftest.gd` gains `_test_chunk_parity()` registered as `"chunk parity"`
after `"chunk determinism"`. It builds seed 31337's 5 x 5 x 3 window exactly
as `_measure_ao_cost()` does, plus the four `_test_winding` shapes, meshes
each through `build_arrays_gd()` and through the C++ path with the SAME
border data (the dispatcher's border builder of 0.4, so the harness tests the
real marshal and not a private one), and compares per Q8. Tonight the C++
path is the stub: the test prints `chunk parity: c++ mesher stub, 0 checks`
and returns 0 - the harness is wired before any port code exists, as
distance v4 Stage 1 did, and for the same reason.

### 0.4 The border builder, and its cost

`ColumnJob` gains `_borders_for(cy) -> Dictionary`: the six neighbour arrays
where `_chunks` / `neighbours` hold them, the surface strips of Q4 where they
do not, `origin_y`, and the 18 x 18 x 18 `shell` only when `ao_strength > 0`
(Q5). The strips are built once per column in `run()` before the mesh loop
(`s_bottom` for the lowest chunk, `s_px` ... `s_nz` only for sides whose
neighbour column is absent from `neighbours`). Timed separately as
`border_usec` and printed by the bench.

### 0.5 The bench

`scripts/tools/mesh_bench.gd`, `extends SceneTree`, run as
`godot --headless --path . --script scripts/tools/mesh_bench.gd -- --seed 42 [--ao 0.45] [--passes 3]`.
It builds the heightmap, generates the 441 spawn-disc columns' voxels ONCE
(untimed - generation is not this lane), then for each pass interleaves
A (twin) and B (C++) chunk by chunk, timing `build_arrays_gd` and the C++
`build` plus the border builder separately, and prints one table:

```
mesh bench: seed 42, 441 columns, N chunks, ao 0.00, 3 passes ABAB
  twin   median X.XXX ms/chunk (spread ±Y%)   quads Q
  c++    median X.XXX ms/chunk (spread ±Y%)   quads Q   borders X.XXX ms/chunk
  parity 0 differing components over N chunks
```

Tonight the C++ row reads `stub` and only the twin's median is real: **that
is the first number this project has ever had for GDScript meshing per chunk
averaged over a real disc**, and it goes in the status doc as the baseline.

### 0.6 Checks

- `check.gd` exit 0; `ClassDB.class_exists("KubikChunkMesher")` true in the
  self-test's print.
- Full self-test green, `chunk parity` printing its stub line.
- Worldgen probe line identical to the baseline.
- Bench prints the twin's median and spread over the spawn disc; the border
  builder's cost per chunk printed and recorded against Q4's 0.3 ms line.
- Tour `mesher-0` taken; near band identical to `mesher-base` (nothing
  changed - this proves the diff tool, not the port).
- Commit `feat(mesher): stage 0 - the class stub, the dispatcher, the parity harness, the bench`. Push.

---

## Stage 1 - The port, geometry only (4 h)

### 1.1 The sweep

`chunk_mesher.cpp`: `build()` reads `voxels` into a `const uint8_t *`,
builds a `solid_at(x, y, z)` that answers the chunk's own bytes for
`0 <= x, y, z < 16`, a neighbour array's byte for one step outside a face
where the array is present, the strip comparison `by < 0 || by <= s` where
a strip is present, and `shell` when it is present; then the three-axis
sweep exactly as `chunk_mesher.gd` lines 96-198: `AXIS_U = {1, 2, 0}`,
`AXIS_V = {2, 0, 1}`, `slice` from -1 to 15, the `solid_throughout` skip
(`has_air` is not marshalled: the C++ scans the 4,096 bytes for air and
solid itself, which is a memchr and costs nothing), the sign-encoded mask,
`AO_OPEN = 0xFF` when `ao_strength == 0`.

### 1.2 The rectangles and the quad

`_emit_slice` and `_emit_quad` ported line for line: grow `w` then `h`,
clear, advance; the corner tables for positive and negative facings with
their AO corner indices; vertices `p * block_size` in the same `d, u, v`
assignment order; the normal; indices `first, first+1, first+2, first,
first+2, first+3`. Colours: **white** this stage (`Color(1, 1, 1, 1)`), so
the parity gate compares positions, normals and indices and prints the
colour column as `skipped`.

### 1.3 Checks

- `chunk parity` unskipped for positions, normals, indices: **0 differing,
  equal quad counts, same order**, over the 5 x 5 x 3 window and the four
  shapes; colours reported `skipped (stage 1)`.
- Winding through the C++ arrays: 0 wrong triangles (the test meshes both
  ways from this stage on).
- Bench: the C++ row is real; the number is recorded whatever it is.
- Commit `feat(mesher): stage 1 - the sweep, the rectangles and the quads cross`. Push.

---

## Stage 2 - The colour table, AO on, and Q27 (2.5 h)

### 2.1 The palette crosses as a table (Q3)

`setup()` stores the 96 wire colours; `_emit_quad` writes
`palette[id * 4 + level]` per vertex with `level = (ao >> (corner * 2)) & 3`.
With `ao_strength` 0 every level is 3 and the entry is
`Look.to_wire(Block.COLORS[id])` - the same float the twin pushes.

### 2.2 The corner codes (Q5)

`_corner_ao`, `_vertex_ao` (the interior-angle special case: two solid
sides give 0 whatever the diagonal) and `_solid_at` ported; the `shell`
answers every read outside the chunk when present. The twin's `_ao_curve`
is linear and is baked into the table on the GDScript side; the C++ never
evaluates it.

### 2.3 Q27, measured

`mesh_bench.gd --ao 0.45` over the spawn disc, both meshers: quads and mesh
ms at 0.0 and at 0.45, in one table. The self-test's `ao cost` line is
re-run and quoted beside it. Whatever the merge does or does not do at this
world's quad sizes is written down with the numbers and left alone.

### 2.4 Checks

- `chunk parity` **total**: 0 differing components including colour, both
  `ao_strength` 0.0 and 0.45, the window and the four shapes. The colour
  column reads `0.000000000`, and on ganymede it must, by construction.
- `_test_winding`'s `ledge@0.45` case emits a different quad set from
  `ledge@0.00` through the C++ path too (the AO split path is exercised).
- Q27 table in the status doc.
- Commit `feat(mesher): stage 2 - the palette as a table, the corner codes, and Q27 measured`. Push.

---

## Stage 3 - Wired into the column job, and the numbers (3 h)

### 3.1 The dispatch

`ColumnJob.run()`'s mesh loop calls `ChunkMesher.build_arrays_from(chunk,
borders, config)` - a new entry that takes the border Dictionary of 0.4 -
and `build_arrays()` (the Callable form the edit path and the tests use)
builds its borders through the Callable and calls the same thing. Both go to
C++ when `ChunkMesher.backend == "cpp"`, else to `build_arrays_gd()` with
the Callable rebuilt from the borders (so the twin's signature never
changes). `--mesher gdscript` forces the twin (Q6). `faces_from()` is
unchanged and still runs on the worker. The `Array` the node receives
(`arrays[Mesh.ARRAY_VERTEX]` ...) is shaped exactly as before, so
`ChunkNode.apply_arrays()` and `world.gd` see nothing new.

### 3.2 The F3 line

`debug_hud.gd`, one line after `far mesher:`:
`lines.append("mesher:   %s" % ChunkMesher.backend_name())`.

### 3.3 The numbers (Q10)

ABAB, three each, interleaved, `pgrep godot` empty before each:

1. Bench: twin vs C++ per chunk over the spawn disc, medians and spread; the
   border builder's cost as its own column.
2. The load line at spawn (`[World] N chunks in M ms wall (P ms main thread;
   Q ms gen per chunk on workers ...)`), C++ on and off, from the tour's
   console. Note in the status doc that "gen per chunk" does not include
   meshing and cannot show this lane's win directly; the wall time can.
3. The tour cost line at Ultra (Q12), C++ on and off: twenty frames per
   settled vantage, worst and median per shot, the table in light v1's shape.

### 3.4 Checks

- Self-test green twice: as-is (`mesher: cpp`) and with `--mesher gdscript`.
- Worldgen probe line identical to the baseline.
- Near-band tour diff, `mesher-base` vs `mesher-3`: 0 differing pixels over
  the terrain rows.
- Bench: C++ median <= 0.5 ms per chunk and >= 10x the twin, or the number
  and the reason (item 4 of section 5).
- The three tables in the status doc, each row saying `ganymede, ABAB median`
  or `ganymede, single run`.
- Commit `feat(mesher): stage 3 - the column job meshes in C++, the switch, the numbers`. Push.

---

## Stage 4 - Docs, the retirement proposal, the merge requests (1.5 h)

- `docs/status/mesher-v1.md` completed per section 6.
- `README.md` § "Two things are C++, and you do not need either" becomes
  "Three things ..." with one paragraph: `KubikChunkMesher`, the measured
  speedup, the `--mesher gdscript` switch, the twin as the reference until
  Marcel retires it.
- **For Fable at merge**, in the status doc: the one line `world.gd` will
  want (`_mesh_worker_ms += job.mesh_usec` beside line 1012, and its share
  of `last_timings()`), so the load line and F3 finally print worker mesh
  time; the sprint probe run against this branch once horizon-v1's Stage 0
  is on main.
- **The twin's retirement**, proposed not done (Q7).
- Commit `docs(mesher): stage 4 - status, README, the retirement proposal, the merge requests`. Push.

---

## 6. The status doc and the morning message

`docs/status/mesher-v1.md`, in the shape of `docs/status/distance-v4.md`,
updated at the end of every stage with, per stage: what shipped; the parity
line verbatim; the probe's line and the config hash; the bench table; every
number with its provenance column (`ganymede, deterministic` / `ganymede,
ABAB median` / `ganymede, single run`); "Questions taken alone"; "For
Marcel"; "For Fable at merge"; "For the bible" (any rule that turned out
wrong or impossible). At the top, before anything: any BLOCKING finding.

The final message to Marcel, in this order and nothing else first:

1. `feat/mesher-v1`'s last commit; which stages are green, which were
   wrapped early, which reverted. The Windows library needs rebuilding by
   Fable before the Windows count is known (Q9).
2. The bench table: twin vs C++ per chunk, spawn disc, ABAB medians.
3. The BLOCKING findings, if any.
4. The parity line, verbatim, and the near-band diff result.
5. The load line and the tour cost line at Ultra, C++ on and off, against
   `mesher-base`.
6. Q27's table, one sentence on what it showed.
7. Every "For Marcel" item, one line each - the retirement proposal first.
8. Every "For Fable at merge" item, one line each.
9. What is left: the edit path on the twin until retirement; voxel
   generation, lakes and zones as the next C++ rungs (phase 5, D56); the
   sprint probe run to come.
