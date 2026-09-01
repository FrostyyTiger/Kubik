# Trees v3 - status

The run of `docs/plans/trees-v3.md`, on `feat/trees-v3` from `main` at
`f6d94bd` (distance v5 merged, the uploader shipped, the plan amended with
v5 as it landed). One night, unattended, on ganymede.
**The forest becomes models, the whole way out.**

Trees are the last living thing in this game still built out of terrain.
Tonight they stop being - and they stop being two different creatures near
and far at the same time.

---

## Provenance

Distance v1 introduced this column and every epic since has kept it. Kept
again unchanged, with one row added for the tool.

| provenance | means |
| --- | --- |
| `ganymede, deterministic` | the worldgen probe, the far probe or a self-test gate. Pure geometry from a seeded generator: same number on any box, every run. |
| `ganymede, single run` | one wall-clock measurement. A smoke alarm, not evidence of a delta. |
| `ganymede, ABAB median` | interleaved, three runs each, median with spread, run order recorded. The only kind of number this document compares two implementations with. |
| `ganymede, eye` | a judgement made by looking at a tour shot taken here, on the RTX 3070 Ti, Forward+ under `xvfb-run`. |
| **`tool, deterministic`** | printed by `trees_convert.py` off the pack's own bytes. Same number on any box with the pack; no engine, no seed. |

Every comparative number below was taken here, on the **editor** target,
headless unless it is a picture, at `far_ring_div` 4 and
`far_upload_budget_ms` 4.0 - the shipped defaults since distance v5.

---

## Stage 0 - the instruments, the audit, and the post-v5 baseline

Bring-up is distance v5's, repeated and green: `~/bin/godot` 4.7.2, godot-cpp
against `4.7.2.stable.official.ed1daf0bf`,
`libkubik.linux.editor.x86_64.so` up to date, `-s gdext/check.gd` answering
`class exists: true` and an 18x trivial bench. `../Kubik-assets` is on the
box with all **55 `.vox` sources** present; `sync_assets.py` mounts 116 files
(characters, creatures, weapons - no trees yet).

One correction to the command block for anyone repeating it: **this box has
no `python`, only `python3`.** `python scripts/tools/sync_assets.py` fails
with `command not found` and - because it is not the last command in the
line - does so with an exit code nobody reads.

### The uploader contract, read rather than guessed (decision 10)

Read out of `docs/status/distance-v5.md` before the first commit, and it is
what this epic conforms to:

| | |
| --- | --- |
| the class | `FarUpload`, `scripts/world/far_upload.gd` |
| the owner | **`FarField`**, as a `RefCounted` it holds and drops with itself |
| how a client reaches it | `FarField.uploader()`; `FarTrees._uploader()` walks `World/FarField` from Game and is the in-tree example |
| the granularity | one slice per frontier **sector** for the far mesh, one slice per **species** for the ring |
| the budget | `far_upload_budget_ms`, LOCAL, unhashed, default **4.0**; 0 restores distance v4 exactly |
| the three rules | a slice is atomic; the swap is atomic (a build in progress shows the OLD COMPLETE far country); a superseded job is dropped rather than queued behind |
| no uploader | apply directly - what the self-test's small Worlds and any headless caller get |

And the debounce this epic inherits: `far_tree_step_m`, default **24.0**,
measured **horizontally** on purpose. If the cadence is touched the
measurement stays horizontal.

### The before-picture

Seed 42, view High (`fog_end` 3,200 m), `far_ring_div` 4, C++ mesher,
`far_upload_budget_ms` 4.0.

| | before | provenance |
| --- | --- | --- |
| **trees in the world** | **28,383** | ganymede, deterministic |
| species mix | spruce 11,861 / beech 5,869 / larch 4,038 / krummholz 1,802 / birch 103 / snag 4,652 / hero 58 | ganymede, deterministic |
| spawn | **(-44, -124)**, altitude 28 m, slope 0.1 deg | ganymede, deterministic |
| spawn clearance | nearest tree 59.4 m, 0 inside the 24 m clearing | ganymede, deterministic |
| heightmap hash | **`4782edac`**, 1500 x 1500, 4 blocks per cell | ganymede, deterministic |
| lakes | 53, 65,632 m2 | ganymede, deterministic |
| config hash | `3d45b8fc` | ganymede, deterministic |
| chunks at spawn | **2,369** in 24,872 ms wall | ganymede, single run |
| gen per chunk, on workers | 9.51 ms | ganymede, single run |
| main-thread upload per chunk | 0.23 ms | ganymede, single run |
| far field, first build | 3,413,644 verts, 680 ms wall | ganymede, single run |
| **impostor ring at spawn** | **580 impostors, 17,700 triangles, 7 species meshes**, 475 ms | ganymede, single run |
| sprint, worst frame (out / back) | 39.4 / 37.7 ms | ganymede, single run |
| sprint, frames over 33 ms | 8 | ganymede, single run |
| sprint, holes | **0 / 0** | ganymede, single run |
| sprint, collidable front min | 56.0 / 64.0 m | ganymede, single run |
| sprint, chunks/s | 101.5 / 111.5 | ganymede, single run |
| static memory (stream probe, 2,996 chunks) | 393.1 MB | ganymede, single run |
| far rebuilds over the sprint | 168, median 607 ms wall | ganymede, single run |
| impostor rebuilds over an 18-vantage tour | **18** - one per vantage, v5's fix holding | ganymede, single run |
| full self-test, mount present | **green** | ganymede, deterministic |
| full self-test, mount moved aside | **green** | ganymede, deterministic |

**The tree count is 28,383 and not trees-v2's 73,675.** The plan expected
this (decision 5, as amended): 73,675 is foliage v1's number from before
world feel v1 retuned the masks, and 28,383 has been the shipped figure since
trees v1. Distance v5 deferred its resolution step, so the world is unchanged
on the same seed and **the reprint confirms it rather than correcting it**.
28,383 / that species mix / (-44, -124) is this epic's invariant, and hard
rule 1 is read against it at every stage.

### A new instrument, because the epic's biggest claim had no numerator

`scripts/tools/tree_probe.gd`. `column_job.gd:11` has claimed since world
feel v1 that tree stamping is *half the generation cost*, and that claim is
Stage 7's gate - but nothing in the project reported the numerator. World
prints `gen_usec + tree_usec` as ONE number per chunk, and the stream probe
measures a walking player on a box that varies 9% run to run.

So this builds a fixed 8 x 8 rectangle of columns through the real
`ColumnJob`, in a fixed order, and prints the job's own three counters.

**It samples the densest patch of the candidate lattice, and the first
version did not.** Sampling the columns around the origin reported a mean
canopy cover of **0.017**, which is not a forest - it is the 24 m spawn
clearing and the ramp around it, which exist precisely to keep trees off the
place a player lands. Measuring the cost of tree stamping where there are no
trees is a way to prove anything. The probe now walks one candidate in
sixteen over the whole region, buckets by 16-chunk patch, and puts the
rectangle on the winner - deterministic, and it prints where it landed.

| | before | provenance |
| --- | --- | --- |
| sample | column (-76, 20) = block (-1216, 320), **canopy cover 0.7871** | ganymede, deterministic |
| chunks reserved per column | **9.61** | ganymede, deterministic |
| chunks built per column | **3.14** | ganymede, deterministic |
| **chunks reserved above the terrain** | **6.47 per column** | ganymede, deterministic |
| column, generate voxels | 5.882 ms | ganymede, single run |
| **column, stamp trees** | **125.381 ms** | ganymede, single run |
| column, mesh | 111.212 ms | ganymede, single run |
| column, total | 242.476 ms | ganymede, single run |
| **tree share of generation** | **95.5%** | ganymede, single run |
| **tree share of the whole column job** | **51.7%** | ganymede, single run |

**`column_job.gd:11` undersells itself.** In real forest, tree stamping is
not half of generation - it is 95.5% of it, and *half of the entire column
job including the mesher*. The comment's "half" is the whole-job figure and
it is exactly right; what it does not say is that the generate-voxels phase
it is being compared against is almost nothing beside it.

### The audit (trees-v2 Stage 0's list, executed at last)

Grep over every `.gd`, `.cpp` and `.h` in the tree for
`TreeSpecies.TREE_BLOCKS`, `is_tree_block()`, `Block.LEAVES*` and
`Block.TRUNK*`. **The result is far cleaner than trees-v2 feared**, and the
kill-or-keep list is short.

| consumer | verdict |
| --- | --- |
| `tree_species.gd` - `TREE_BLOCKS`, `is_tree_block()`, every shape function's `set_block` | **KILL** (Stage 7). This is the writer half, and it is the epic. |
| `block.gd:16-63` - the `LEAVES*` / `TRUNK*` enum ids | **KEEP, PARKED** (ruling 5). Removing an id renumbers a wire format for zero benefit. |
| `block.gd:112-140` - their `COLORS` rows | **KEEP.** The palette table is what Stage 2's tree colours are mapped *toward*, so the world's greens stay one family. |
| `selftest.gd:252` - `is_tree_block()` in `tree borders` | **KILL AND REPLACE** (Stage 7). The only live gameplay-side consumer in the project, and it is a test. Replaced by `cover determinism` and `registry determinism`. |
| `selftest.gd:672,699` + `worldgen_config.gd:87,1854` - `REF_MAX_TREE_BLOCKS` | **REWRITE** (Stage 7). The sky reserve and the `sky reserve` gate that asserts they agree, reconciled to the new smaller truth. |
| `chunk_mesher.gd:103-401` - `_under_canopy`, `canopy_cover` | **KEEP UNTOUCHED** (decision 6). Its input has always come from the scan, never from the voxels. |
| `flora_placement.gd:217-594` - `_trees_near`, `_ground_allows` | **KEEP UNTOUCHED** (decision 8). Both already ask placement, not blocks. |
| `far_tree_meshes.gd:82` - `color_of_species()` reading `Block.color_of(row["leaves"])` | **KILL** (decision 7). The one place near and far are pinned together through a block id, and it is dead the night leaf blocks die. |
| `screenshot_tour.gd:875` - `_count_trees_near` | **KEEP.** Asks `decide()`, not the volume. |
| `far_field_job.gd:1183` | comment only, no reference. |

**Nothing outside `tree_species.gd`, `block.gd` and one self-test reads a
leaf or trunk block id anywhere in the game.** Trees-v2's open question 4 -
"does anything want leaves to stay blocks: canopy shade, a player on a crown,
rain occlusion" - is answered by the grep: forest-floor shade already comes
from the scan, and nothing else asks at all.

### The gate

| Stage 0 gate (plan) | result |
| --- | --- |
| self-test green both ways, untouched | **green** both legs |
| `docs/status/distance-v5.md` read; uploader owner and enqueue contract recorded | above |
| tree count / species mix / spawn reprinted against post-v5 main | **28,383**, the mix above, **(-44, -124)** |
| chunks and load wall at spawn | **2,369 / 24,872 ms** |
| sprint frame profile | worst 39.4 / 37.7 ms, 8 over 33 ms, holes 0 |
| `[FarTrees]` rebuild numbers | 580 impostors, 17,700 triangles, 475 ms; 18 rebuilds over a tour |
| tour set `--label trees-v3-before` | **18 shots**, `build/tour/trees-v3-before` |
| gallery `--label trees-v3-before` | **9 sheets**, `build/gallery/trees-v3-before` |
| the audit list written down | above |
| every number with its box and target | the provenance column |

