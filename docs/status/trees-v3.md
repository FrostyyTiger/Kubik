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


---

## Stage 1 - the tool, and the budget

**The gate is a number, and it was read before one line of Godot code
existed. It passes at 36,386 triangles against 40,000 - and the plan was
worried about the wrong thing.**

`Kubik-assets/tools/trees_convert.py`, stdlib only, **88 seconds for the
whole pack**, 2.7 MB of output. It parses each `.vox` scene graph through
`vox_parse.py`, dedupes the colourway twins on a hash of the normalised
position set, downsamples to three LOD rungs, greedy-meshes each rung per
palette index, and emits packed quads plus a JSON sidecar.

**38 distinct geometries from 55 files** - the plan estimated ~30, and the
twins fall exactly where it predicted: Tree 13 ships one geometry five
times (green / autumn / crimson / snow / a sixth with extra voxels), Tree 14
four times, Tree 15 five, and Trees 11, 12 and 16 in pairs. A twin gets its
own sidecar naming the geometry it shares and **no second binary**, which is
what makes a whole autumn forest cost no new triangles.

### The night's first table

Every geometry, `tool, deterministic`. Twins are omitted - they are the row
above them.

| variant | w x h x d | voxels | shell | LOD0 tri | LOD1 tri | LOD2 tri |
| --- | --- | --- | --- | --- | --- | --- |
| t05 | 32 x 206 x 32 | 118,598 | 16,536 | 2,614 | 1,074 | 512 |
| t5_5 | 34 x 206 x 34 | 123,184 | 16,816 | 3,240 | 1,288 | 606 |
| t07 | 118 x 210 x 92 | 141,172 | 26,684 | 6,568 | 2,496 | 1,206 |
| t08 | 17 x 175 x 16 | 26,921 | 6,662 | 2,248 | 890 | 332 |
| t09_1 | 163 x 170 x 99 | 13,300 | 8,650 | 4,742 | 1,792 | 586 |
| t09_2 | 163 x 168 x 99 | 14,064 | 8,970 | 5,390 | 1,912 | 616 |
| t09_3 | 163 x 167 x 99 | 14,573 | 9,492 | 5,508 | 2,018 | 622 |
| t09_4 | 163 x 134 x 99 | 12,912 | 8,632 | 4,988 | 1,758 | 560 |
| **t10_1** | 155 x 167 x 99 | 13,901 | 8,821 | **26,474** | 6,162 | 1,418 |
| **t10_2** | 155 x 197 x 99 | 14,517 | 9,437 | **29,602** | 6,786 | 1,594 |
| **t10_3** | 155 x 197 x 99 | 16,569 | 11,001 | **36,386** | 8,138 | 1,996 |
| t10_4 | 65 x 58 x 39 | 3,051 | 2,275 | 8,212 | 1,788 | 498 |
| t10_5 | 89 x 90 x 39 | 5,785 | 3,633 | 12,052 | 2,762 | 790 |
| **t10_6** | 155 x 122 x 81 | 9,838 | 6,870 | **24,096** | 4,812 | 1,188 |
| t11_1 | 68 x 193 x 68 | 56,306 | 39,450 | 2,686 | 1,718 | 818 |
| t11_3 | 68 x 193 x 68 | 98,414 | 48,334 | 2,632 | 1,656 | 776 |
| t11_4 | 80 x 224 x 80 | 80,129 | 59,134 | 4,482 | 2,060 | 1,428 |
| t11_6 | 35 x 216 x 35 | 13,977 | 6,416 | 3,162 | 1,608 | 202 |
| t11_7 | 80 x 224 x 80 | 94,784 | 68,350 | 4,752 | 2,342 | 1,440 |
| t11_9 | 36 x 216 x 35 | 14,736 | 6,918 | 2,848 | 1,152 | 184 |
| t12_1 | 44 x 206 x 44 | 156,672 | 19,392 | 2,770 | 1,254 | 630 |
| t12_10 | 44 x 217 x 44 | 162,358 | 20,152 | 2,950 | 1,264 | 626 |
| t12_2 | 64 x 204 x 64 | 286,060 | 28,460 | 3,152 | 1,462 | 650 |
| t12_3 | 74 x 217 x 74 | 385,031 | 45,572 | 4,152 | 1,878 | 878 |
| t12_4 | 76 x 217 x 76 | 398,252 | 46,576 | 5,158 | 2,100 | 1,040 |
| t12_5 | 74 x 217 x 74 | 382,343 | 45,596 | 4,152 | 1,880 | 808 |
| t12_7 | 74 x 217 x 74 | 452,249 | 36,560 | 4,190 | 2,072 | 984 |
| **t13_1** | 126 x 173 x 128 | **1,324,790** | 74,140 | **5,642** | 2,092 | 1,086 |
| t13_5 | 126 x 173 x 128 | 1,339,793 | 74,883 | 5,980 | 2,346 | 1,092 |
| t14_1 | 134 x 178 x 121 | 1,101,575 | 70,604 | 4,232 | 1,812 | 884 |
| t14_5 | 134 x 178 x 121 | 1,112,316 | 71,369 | 4,246 | 1,768 | 962 |
| t15_1 | 166 x 193 x 145 | 691,272 | 73,172 | 5,006 | 2,188 | 938 |
| t15_5 | 168 x 194 x 147 | 714,612 | 73,944 | 6,036 | 2,496 | 1,174 |
| t16_1 | 15 x 16 x 15 | 2,960 | 930 | 228 | 132 | 60 |
| t16_2 | 11 x 16 x 11 | 1,744 | 666 | 108 | 72 | 52 |
| t16_3 | 11 x 16 x 11 | 1,168 | 562 | 924 | 288 | 64 |
| t16_4 | 9 x 16 x 9 | 1,232 | 546 | 172 | 106 | 92 |
| t16_6 | 7 x 16 x 7 | 720 | 370 | 132 | 98 | 36 |
| | | | **total** | **251,912** | | |

### The plan feared the giants and the giants are free

"Triangle budget is a real risk at LOD0: a hollowed 1.3 M-voxel canopy is
still a big shell." **It is not.** Tree 13 is 1,324,790 voxels and comes out
at **5,642 triangles** - 2,821 quads from 74,140 shell voxels, which is
**0.038 quads per shell voxel**. A dense canopy is enormous blobs of one
palette index, and that is exactly the input greedy meshing is best at.

**The expensive variants are the SPARSE ones**, which nothing in the plan
anticipated. Tree 10's sprawling bare branches are one voxel thick: every
shell voxel is exposed on four to six sides and merges with nothing, so
11,001 shell voxels become **18,193 quads - 1.65 per shell voxel, 43x worse
per voxel than the giant**. Tree 10 alone is **136,822 of the library's
251,912 LOD0 triangles - 54% of the budget for 1.5% of its voxels.**

It is the same lesson `FloraModels:9` and trees v1 both paid for from the
other side - *greedy meshing and per-block variation do not mix* - restated
as: greedy meshing and one-voxel-thick geometry do not mix either. Density
is cheap and lace is dear, and it is dear in proportion to how little of it
there is.

**Nothing is downsampled at the tool.** The escape valve exists
(`--downsample t10_3,...`, recorded per variant in the sidecar) and the gate
did not need it. The plan says using it is "a recorded decision, not a
failure"; not using it is recorded here for the same reason. If Stage 5's
band totals say Tree 10 is not worth what it costs, this is the lever, and
its LOD1 is already a 4.5x cut.

### Hollowing is not a step, and the reason is worth writing down

The plan asks the tool to hollow - drop voxels with six filled neighbours -
so the giants keep only their shells. **Culling hidden faces is what a greedy
mesher already does**, and hollowing a volume *before* meshing it would
expose the shell's INSIDE and roughly double the quad count. So the shell is
computed and reported (the table's middle column, which is the plan's own
column) and never removed. The plan's intent - the giants must not carry
their interiors - is satisfied by construction rather than by a pass.

### The trunk detection is on its second rule, and the first was wrong

The collider dimensions are measured off each model, not typed. The first
rule took the trunk to be the bottom run of slices whose occupied area is
under 6% of the WIDEST slice's - sound for a stick under a dense crown, and
wrong for a tree that has no dense slice anywhere. Every Tree 09 and Tree 10
is exactly that, and the run never ended: **168 voxels of trunk on a
170-voxel model, a 21 m collider around a bare tree.**

The rule that works measures against the BASE rather than the crown: base
area is the median over the bottom twentieth, the radius is that area's
equivalent circle, and the canopy starts at the first slice with four times
it. A stump never reaches four times its own base and comes out one solid
cylinder, which is correct - a stump *is* a trunk.

| | before the fix | after |
| --- | --- | --- |
| trunk radius, across the library | 3.79 - 9.29 voxels (0.47 - 1.16 m) | **0.35 - 0.95 m** |
| t09_1 trunk height | **21.00 m** (the whole tree) | 21.00 m, at **0.55 m** radius |
| t07 trunk height | 0.62 m | 6.12 m |
| t16 stumps | "fallback-quarter", 0.5 m tall | **"solid"**, the whole 2 m |

Three variants still report a trunk as tall as the model (`t09_*`, `t10_1`,
`t10_2`, `t08`, `t11_6`, `t11_9`) and after the fix that is the right
answer rather than a failure: a bare sprawling tree and a thin spire never
quadruple their base area because they never have a canopy mass, and a
0.55 m post the full height of the tree is precisely the collider a player
should be stopped by. Which rule fired is in every sidecar. **Open question
4 - one cylinder always, or a capsule for the leaners - is now answerable
with data rather than guessed at**, and Stage 6 answers it on body-probe
cost.

### The format

`.ktree`, version 1, little-endian. `KTRE` + version + LOD count, then per
LOD a `u32` quad count and that many 12-byte quads: `u16 x, y, z` in that
LOD's own voxel grid, `u8 face` (FloraModels' own order - 0 +X, 1 -X, 2 +Y,
3 -Y, 4 +Z, 5 -Z), `u8 palette index`, `u16 w, h` extents. No Godot import
dependence, quads not voxels, palette INDICES in the geometry with RGB in
the sidecar - the three constraints decision 2 sets.

The sidecar carries dimensions, native height in metres at the 12.5 cm rung,
origin (bottom centre), the collider trunk and its rule, the dominant canopy
palette index (measured over the top 60%, because a bare tree is mostly
trunk and the far colour pin hangs off this), and the pack's own 256-entry
palette.

**Native heights land at 2.00 m (the Tree 16 stumps) to 28.00 m (Tree 11),
with the trees proper at 21-28 m** - which is ruling 3's register shift,
measured rather than estimated.

### The gate

| Stage 1 gate (plan) | result |
| --- | --- |
| the tool exists, stdlib only, in the assets repo | `Kubik-assets/tools/trees_convert.py`, 88 s for the pack |
| parse / dedupe / hollow / LOD / greedy-mesh / emit | all six; hollowing is reported rather than performed, see above |
| the per-variant table printed | above |
| **worst LOD0 variant under 40,000 triangles** | **36,386** (`t10_3`) - **PASS**, and no species downsampled |
| commit tool + library to Kubik-assets | **`388692c`**, pushed |
| `sync_assets.py`, re-run, mount confirmed | **93 files, 2.7 MB** at `assets/purchased/trees` |

### Two things about this box, recorded because they cost time

1. **`git-lfs` is not installed on ganymede and `Kubik-assets` requires it.**
   `filter.lfs.required = true` makes *every* index-touching git command fail
   - `git status` included - with `git-lfs filter-process: 1: git-lfs: not
   found`. Nothing in this epic's output is LFS-tracked (the patterns are
   `.gltf` and `.glb` only), so the commit was made with the filters
   neutralised **per command** rather than by installing a package on an
   unattended box or by editing the repo's config. Every staged path was
   listed explicitly and checked against the LFS patterns first.
   `packs/voxel-dwarf-characters/Glb/Dwarf 03.glb` shows as modified in that
   working tree - a pointer/content discrepancy from the missing tool - and
   was left untouched. **Hard rule 8's "if ganymede cannot push
   Kubik-assets" did not have to fire, but it nearly did.**
2. **There is no `python` on this box, only `python3`.** The plan's command
   block says `python scripts/tools/sync_assets.py`.


---

## Stage 2 - `TreeModels`, the palette table, and the gallery

**The library loads, assembles and photographs - and the gallery sheet found
a bug in a parser this project has been shipping since character v2.**

### What was built

| | |
| --- | --- |
| **`TreeModels`** | `scripts/world/flora/tree_models.gd`. `available()`, `variants()`, `mesh_for()`, `triangles_for()`, `trunk_of()`, `canopy_color()`, a mutex-guarded lazy cache. A SIBLING of `FloraModels` per decision 4 - its own ids, its own material, and the two files never refer to each other. |
| **`TreePalette`** | `scripts/world/flora/tree_palette.gd`. Sixteen named colour families and an explicit per-variant index -> family table. |
| **`Look.tree_material()`** | The far-tree treatment (`fog_dark_mix` 0.0, `contact_band` 1.0) on a shader with a `vertex()`, plus `tree_sway` - a LOCAL, unhashed knob, default 0.5, held at 0 until Stage 8. |
| **`--trees` in the gallery** | Every variant at 1:1 beside the player capsule, and every LOD rung beside its own LOD0. |
| **two self-test gates** | `tree winding` and `tree library`, both self-skipping without the mount and saying so. |

### The palette table is keyed on the VARIANT, not the species

Decision 3 asks for "each species' palette indices mapped to authored Kubik
colours", and **a species' indices are not stable across its own
colourways**. Tree 13's palette index 3 is green foliage on `t13_1`, autumn
on `t13_2` and crimson on `t13_4`. Keying by species produced eighty-odd
disagreements, every one of them a twin overwriting its sibling. A colourway
IS a palette, so the table is per file: **55 rows.**

**Generated, then authored.**
`Kubik-assets/tools/trees_palette_table.py` printed the block from the baked
sidecars and it is checked in as data - Marcel edits a cell and that
variant's colour moves, with no tool, no re-bake and no assets-repo commit.
**Only palette INDICES and Kubik family names cross into the public repo;
the pack's RGB never does** (hard rule 8).

**The classification rule is on its second version and the first led with the
wrong half.** It took the sidecar's `canopy_share` to decide foliage-or-bark
and then chose a family inside that role - which put Tree 12's greens on the
BARK ramp (their share fell just under the line on three variants, and
nothing in Kubik has green bark) and Tree 16's cut stumps on the AUTUMN ramp
(a stump is all "canopy" by height, and its brown sits in the warm hue band).

What actually separates the two in this pack is **saturation**, and it
separates them with room to spare:

| | saturation | examples |
| --- | --- | --- |
| bark browns | **26 - 69** | the pack's trunk ramp |
| autumn foliage | **78 - 92** | the pack's autumn ramp |

So hue picks the ramp, saturation splits the one ambiguous band, and the
geometry is kept for the single question colour genuinely cannot answer: **a
near-white index high in a tree is snow dust and low in a tree is pale bark,
and `#FFFFFF` is `#FFFFFF` either way.**

Four families are new because the block world had nothing to be: `AUTUMN_A`
(a deep burnt orange under the larch ramp), `BARK_DARK` (which is the
most-used family in the whole table - this pack shades trunks far darker than
one block id ever could), and `CRIMSON_A/B` + `PINK_A/B` for the two parked
colourways. Everything else points at an existing `block.gd` row, which is
what keeps a purchased forest in the same palette as the terrain it stands on.

**The pack's colours are neon and Kubik's are not, and the mapping
desaturating them is the mapping doing its job** - the brightest autumn in
the pack is `V 98, S 92` and `LEAVES_LARCH` is a muted gold. That is the
whole reason the colour is mapped in the game rather than shipped from the
tool.

### `vox_parse.py` ignored MagicaVoxel's rotations, and it looked like art

**The gallery sheet found it, which is what a gallery is for.** Tree 09 came
out as a bare stick with a flat green plate balanced on top, and Tree 10 the
same. The mesher was verified exact against the source occupancy first -
88,408 exposed faces on Tree 13, every one covered exactly once, right
colour, nothing missing and nothing extra - so the geometry was arriving
wrong before the mesher ever saw it.

`vox_parse.walk` read the scene graph's `_t` translation and **dropped its
`_r` rotation.** That is invisible on a model whose parts are axis-aligned -
which is every model this tool had been pointed at - and catastrophic on one
whose parts are the SAME PIECE ROTATED. **Tree 09 is a coconut palm**: five
trunk segments and twenty-four fronds, every frond the same flat two-voxel
model turned into place. Without `_r` all twenty-four lay flat at the top in
overlapping PAIRS - `Leaf (2)_3` and `Leaf (2)_4` at byte-identical bounds,
which is the signature worth recognising.

`_r` is a packed byte: two bits for the column of row 0's non-zero entry, two
for row 1's, three sign bits. Two details the fix has to get right and a
naive version would not: **the pivot is the model's centre BEFORE rotation
and the placement is the rotated box's centre AFTER**, so each axis shifts by
the ROTATED extent or an oblong part lands offset by half the difference; and
a child's `_t` is expressed in its PARENT's rotated frame, so rotations
compose down the graph.

| | before | after |
| --- | --- | --- |
| tree files whose geometry changed | - | **29 of 55** |
| Tree 09_1 depth | 99 voxels (fronds overlapping) | **162** (fronds radiating) |
| worst LOD0 triangle count | 36,386 | **33,194** |
| library LOD0 total | 251,912 | **246,334** |
| knight files changed | - | **none** - the regression check |

**Nothing shipped moves.** `vox_parse.py` is an offline tool, it is
referenced nowhere in the game, and nothing in `game/` was ever generated
from the creature or weapon `.vox` through it. The game's own reader,
`scripts/character/vox_loader.gd`, is a flat chunk walk with no scene graph
at all and is untouched. **But the creature `.vox` files DO parse differently
now, and anyone who reached for this tool before got wrong geometry from
them** - which is worth knowing before the creature trio is modelled.

### And a finding the mapping table has to answer

**Trees 09 and 10 are coconut palms.** Decision 12 reads them as "sprawling
bare 09/10 = the krummholz/snag register", and that reading was taken off
shape statistics computed from the broken geometry - 163 voxels wide, 13,000
voxels, no dense slice anywhere. With the rotations in they are unmistakable:
a slender segmented trunk and a crown of flat radiating fronds. Stage 3
benches them, in a comment, and the reason is in this paragraph.

### Two more bugs the pictures found

1. **`StringName.sort()` is not lexicographic.** It compares the internal
   POINTER - which is the point of a StringName and why comparing one is an
   integer compare - so `[&"t16_6", &"t05", &"t5_5", &"t09_1"].sort()`
   returns `[t09_1, t5_5, t05, t16_6]`. Stable, arbitrary, and it changes
   with allocation. The symptom does not look like a sort bug: the first
   sheet came out `t5_5, t16_6, t16_5, t16_4 ...`, which reads as a
   deliberate REVERSE sort rather than as no sort at all.
2. **The winding table was wrong on four faces of six**, and the cross
   product found it - 326,514 triangles of 481,654, with `+X`, `-X`, `+Y`
   and `-Y` backwards and the two Z faces right. The rule, once derived
   rather than guessed: the corner order traces `(0,0) (w,0) (w,h) (0,h)` in
   the face's own `(u, v)` plane, so the triangle normal is `+(u x v)` -
   which for X is `y x z = +x` and for Z is `x x y = +z`, both along the
   axis, but for **Y is `x x z = -y`, against it.** So the flip is
   `offset == 1` on X and Z and `offset == 0` on Y, and Y being the odd one
   out is the whole of it. `FloraModels` records the identical experience
   from the other side; its advice - check winding with the cross product,
   not with your eyes - is why this took one run.

Also recorded because it wasted a compile: **`OPAQUE_SHADER` already has a
`vertex()`**, so the sway could not be appended beside it. Splicing it INSIDE
that function turns out to be required rather than a consolation - the
displacement has to happen before `world_pos` is taken, or the grain and the
banded fog are sampled where the vertex would have been in still air and a
moving crown shimmers through them.

### The gate

| Stage 2 gate (plan) | result |
| --- | --- |
| the loader per decision 4 | `TreeModels`, a sibling of `FloraModels` |
| `Look.tree_material()` per decision 9 | built, with the sway shipped at Stage 2 and its knob held at 0 until Stage 8 |
| the palette table per decision 3 | `TreePalette`, 16 families, 55 variant rows |
| gallery `--trees`, every variant beside the capsule | **22 sheets**, `build/gallery/trees-v3-s2` |
| every LOD beside its LOD0 | 11 `lods-*.png`, one per pack species |
| self-test, mount present | **green** - `tree winding` 474,460 triangles 0 wrong, `tree library` 55 x 3 rungs 0 wrong |
| self-test, mount absent | **green** - `TreeModels.available()` false, both tree gates print "no library mounted, 0 checks (public build)" |
| gallery `--trees` absent leg prints "no library" and exits 0 | yes |
| **triangle counts at load match Stage 1's table** | **exactly, on all 55 variants at all 3 rungs** - the Python tool has no Godot in it and the GDScript loader has never seen a `.vox`, and they agree to the triangle |

**Worst LOD0 at load: `t10_3`, 33,194 triangles. 319,082 over the library** -
which is 55 variants counting twins, against the tool's 246,334 over 38
distinct geometries. Two denominators, both correct: the tool bakes
geometries and the loader assembles variants.


---

## Stage 3 - the mapping table

`scripts/world/flora/tree_table.gd`, in the PUBLIC repo. **The one place the
pack's names appear**: `t11_4` means nothing anywhere else in this codebase,
and every other file talks about spruce and beech exactly as it did when a
spruce was made of blocks.

### What the pack turned out to actually contain

The plan's decision 12 maps by "shape and colour statistics", and Stage 2's
parser fix moved two of those readings a long way. This is what is in there:

| folder | what it is | slot |
| --- | --- | --- |
| `t05` | a dense crimson column, 25.8 m | **benched** |
| `t07` | a broad branching broadleaf - the only crown here with real branch structure | **birch** |
| `t08` | a thin crimson spire | **benched** |
| `t09` | **coconut palms** - five trunk segments, twenty-four radiating fronds | **benched** |
| `t10` | coconut palms, shorter, six variants | **benched** |
| `t11` | the classic stepped conifer, 24-28 m - **and two bare dead spires** | **spruce**, and the spires are **snag** |
| `t12` | a tiered conifer, ten variants: three greens, one snow-dusted, six autumn | **larch** |
| `t13`, `t14` | rounded broadleaves on straight trunks, five colourways each | **beech** |
| `t15` | the largest crowns in the pack, six colourways including pink | **hero** |
| `t16` | six cut stumps, 2 m | **krummholz** and **snag** |

### The two rows worth arguing about

**Tree 09 and Tree 10 are benched, and the plan expected them used.** Decision
12 reads them as "sprawling bare 09/10 = the krummholz/snag register", off
statistics that said 163 voxels wide, 13,000 voxels, no dense slice anywhere.
Those statistics came from geometry that was arriving wrong - Stage 2's
dropped rotations. With the rotations in they are unmistakably **coconut
palms**, and there is no reading of this world in which a coconut palm stands
on an alpine slope. Benched rather than deleted: the Second Age's coast is a
compass direction the land descends toward, and a palm is a thing that grows
where a coast is warm.

**Krummholz is the weakest row in the table and it is flagged rather than
hidden.** Krummholz is a wind-flagged alpine cushion - knee-to-shoulder high,
spreading, alive. **The pack has nothing like it.** What it has at that height
is Tree 16, which is six CUT STUMPS: dead wood, sawn flat, 2 m tall. The right
SIZE and the wrong THING.

They are used anyway, because the alternative is an alpine zone with no trees
in it at all and a weathered woody stub above the treeline is not a lie - but
**the krummholz cushion trees v1 Stage 3 authored is the one shape this epic
loses outright**, and getting it back means new art rather than a table edit.
The row's own comment tells Marcel that setting its six weights to 0 gives a
treeless alpine zone, which is a defensible picture and a one-line change.

### The parking space is a number, not a comment

Decision 12 asks for crimson and pink to "ENTER the table with spawn weight 0
near spawn, parked as distance-strangeness candidates - present, inert". They
are in as weights of exactly **0.0**: `t13_4` and `t14_4` (crimson beeches),
`t15_4` (**the pink hero**) and `t15_6` (the crimson one). The geometry loads,
the palette maps, the gallery photographs them, and no cell in the world picks
one until somebody edits a digit. **A single pink hero standing in a far
meadow is the cheapest strangeness this game will ever be able to buy.**

The roll is over the row's own weight total, so raising a parked colourway
reshuffles that species and nothing else - it cannot renumber the variants
beside it into different trees.

`t05` and `t08` are benched instead of parked, and the distinction is
deliberate: they have **no green twin anywhere in the pack**. They are crimson
or they are nothing, which makes them pure strangeness rather than a colourway
of something familiar - a different decision, and Marcel's.

### The lint

`TreeTable.lint()`, run by the `tree table` self-test gate. Three rules, and
the third is the one that stops the table rotting:

1. every variant a row names exists in the library and has a palette row;
2. no variant is named twice inside one row, and no row is entirely parked;
3. **every variant in the library is either used or explicitly benched with a
   reason.** A pack that gains a species folder FAILS here rather than quietly
   not appearing in the world.

Plus: every one of `TreeSpecies`' seven species must find a row, or the forest
would simply be missing its larches with no error anywhere.

### The gate

| Stage 3 gate (plan) | result |
| --- | --- |
| one data file, in the public repo | `tree_table.gd`; the pack's names appear nowhere else |
| species slots / heights / colourway sets / spawn weights | all present; `height_m` 0 means the artist's own size (ruling 3) |
| collider dims read from sidecars | `TreeModels.trunk_of()` - the table does not restate them |
| crimson/pink at weight 0 | `t13_4`, `t14_4`, `t15_4`, `t15_6` at exactly 0.0 |
| `FOREST_WEIGHTS`' species names wired to table rows | `TreeTable.slot_of()` reads `TreeSpecies.SPECIES[id]["name"]` rather than restating it |
| **table lints against the mounted library** | **0 complaints**; 7 species covered |
| every vox-backed species referenced or explicitly benched | 4 folders benched with reasons, and the lint enforces it |
| **placement baseline unchanged** | **28,383 trees, same mix, spawn (-44, -124), heightmap `4782edac`** - nothing consumes the table yet |
| self-test both ways | **green**; the absent leg prints "no library mounted, 0 checks (public build)" |

Variant distribution over 300 cells per species, as a sanity read: spruce
draws all 7 of its variants, larch all 10 (the snow-dusted `t12_4` at weight
0.4 taking 12 of 300), beech 8 of 10 with the two crimson never appearing,
hero 4 of 6 with the pink and crimson never appearing. The parked rows are
inert, measured rather than assumed.

