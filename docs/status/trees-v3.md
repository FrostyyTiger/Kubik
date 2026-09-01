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


---

## Stage 4 - one species end to end, near

**The valley broadleaf is drawn from the library over the whole voxel radius
while the block stamp still runs for every other species, and
`4-valley-floor` has both in one frame.** Two library beeches stand in the
meadow with two cone impostors between them, and the register shift the epic
is for is the difference in their size.

### What moved

| | |
| --- | --- |
| `TreeTable.MODEL_SLOTS` | `[&"beech"]` - the whole of "two systems for one night", as data |
| `TreePlacement._stamp_found` | one guard: a species drawn from the library is not stamped as blocks. **The scan is untouched** - the candidate walk, the crown area and `canopy_cover` all still happen for a model tree, and only the WRITE stops (decision 6). |
| `TreePlacement.stamp_cell` | routed through `_stamp_found` so it and `stamp_column` cannot disagree about which species the stamper still owns |
| `FarTreesJob.buffers` | keyed by a STRING now: `c<species>` for a cone, `m<variant>\|<lod>` for a library mesh. One species draws many variants at several rungs and each pair is its own MultiMesh. |
| the walk | the per-sector inner test **moved below `decide()`** and now applies only to cone species - which is the whole of "the walk extends inward to distance zero" |
| `_pack` | a library mesh is already the right size, so its transform carries only yaw and a +/-15% scale jitter on a new salt (233). A cone is still a unit shape scaled by the placement table's height. |
| `FarTrees` | slots keyed the same way; the triangle count reads the INDEX array for a library mesh and the vertex array for a cone |

**Ruling 3 lands in one branch of `_pack`.** A model was authored at world size
like a character, so scaling it by the placement table's height would be
scaling the artist's tree to fit a number that describes a different tree. The
jitter exists because a model has no size RANGE - it is exactly as tall as it
was drawn - and 15% is the most that puts a stand back into a stand of trees
rather than a row of copies without reading as two species.

### The gate

| Stage 4 gate (plan) | result |
| --- | --- |
| `cover_column()` split out for this species | the scan/write split is `_stamp_found`'s guard; `canopy_cover` is **0.7871, unchanged** |
| **instance count for the species equals its placement count** | **32 model instances over 8 variants, placement says 32, 0 disagree** - the new `tree field` self-test gate, exact rather than a tolerance |
| the A/B tour pair | `build/tour/trees-v3-before` against `build/tour/trees-v3-s4`, 18 shots each |
| no upload over budget | every commit still flows through `FarUpload` (decision 10) - and the slices got SMALLER, because 7 species-sized slices became 14 slot-sized ones |
| self-test both ways | **green**; the absent leg prints "tree field: no library mounted, 0 checks (public build)" |
| placement does not move | 28,383 / same mix / `(-44, -124)` |

**The `tree field` gate is only checkable on the nearest band and says so.**
The outer bands walk one candidate cell in four, sixteen and sixty-four on
purpose (distance v1 Stage 7), so the field is DESIGNED to draw fewer trees
than placement decides out there. The test collapses every band onto the first
so the whole scan is stride 1, which is the band the handover to the player
happens in and the only one where "every tree" is the right claim.

### What one species already bought, and what it already cost

| | Stage 0 | Stage 4 | |
| --- | --- | --- | --- |
| column, stamp trees | 125.381 ms | **78.644 ms** | **-37%, from beech alone** |
| tree share of generation | 95.5% | 93.1% | |
| tree share of the whole column job | 51.7% | **43.7%** | |
| chunks built per column | 3.14 | 3.09 | |
| canopy cover | 0.7871 | **0.7871** | unchanged, as decision 6 requires |
| **field triangles at spawn** | **17,700** | **606,484** | **34x - and this is the number Stage 5 exists to answer** |
| field slots at spawn | 7 | 14 | |
| model instances at spawn | 0 | 121 of 589 | 20.5%, which is beech's share of the mix |

**606,484 triangles for 121 trees is Stage 4 drawing LOD0 at every distance,
deliberately.** Every band's rung is 0 tonight so the gate is read against the
near field with nothing hidden behind a downsample. Stage 5 assigns the bands
on these numbers, and 121 beeches costing thirty-four times what 589 cones did
is the argument for doing it.

### One thing that did not move, and it is not a bug

`tree borders` still reports **1,146 tree blocks** on all four runs, before and
after beech left the block grid. The test samples chunks `cy` 4-14 - blocks
y 64-224 - and a beech tops out around y 72 on that seed, so almost none of
its blocks were ever in the sample. The test is proving the SCAN MARGIN, which
is unchanged and must be; Stage 7 replaces it with the canopy-aware siblings
the plan names.


---

## Stage 5 - the whole field, every band

**Every species is drawn from the library, the cones are retired, the walk
runs from the player's boots to the fog, and `FarTrees` is `TreeField`.**
636 trees at spawn, **636 of them models and none of them cones.**

### The band -> rung assignment, and open question 1

Decided on Stage 4's number rather than on taste: **one species at LOD0 in
every band cost 606,484 triangles where the whole cone ring had cost 17,700.**
Seven species that way is not a configuration this game can afford.

| band | radius | stride | rung | voxel |
| --- | --- | --- | --- | --- |
| 0 | 0 -> 1.6 x voxel radius (154 m at High) | 1 | **LOD0** | 12.5 cm |
| 1 | 154 -> 400 m | 2 | **LOD1** | 25 cm |
| 2 | 400 -> 600 m | 4 | **LOD2** | 50 cm |
| 3 | 600 m -> fog | 8 | **LOD2** | 50 cm |

**The nearest band is stride 1 and LOD0 all the way to the old seam, and that
answers open question 1's second half: there is no nearer cut.** That band is
what a player walks through, stands under and looks at; every tree in it is
the tree the artist drew at 12.5 cm voxels, and the handover to the rung above
happens well beyond where anyone can resolve a voxel.

**The outer two bands share LOD2** rather than the tool baking a fourth rung.
Band 3 is past 600 m, where distance v1 Stage 7's own note says the fog is
already 87% of the frame - a rung nobody can see is a rung nobody should pay
to bake. The merged-lump step the plan records as the next move is what band 3
actually wants if the fog ever moves out.

**The band's spread still applies to a model, and it has to.** The outer bands
walk one candidate cell in four, sixteen and sixty-four; without widening what
they do draw, the far forest would be sixty-four times sparser than the near
one and the treeline would thin into nothing. So a model takes the cone ring's
own arithmetic unchanged - full width, height by half a step per doubling - and
the outer band reads as a canopy rather than as a skyline of towers.

### The colour re-pin (decision 7)

`FarTreeMeshes.color_of_species()` reads `Block.color_of(row["leaves"])`, and
that pin is dead the night leaf blocks die. It is replaced by
`TreeModels.canopy_color()` - the variant's dominant canopy palette index
through `TreePalette` - and `_pack`'s instance-colour divisor is pointed at the
same source. **Near and far cannot drift apart because they are the same mesh
under the same table: the drift MECHANISM is what got deleted, not the drift.**
The old function is still called for cone keys, which nothing produces any
more; Stage 7 removes it.

### The rename

One commit, no behaviour. `far_trees.gd` -> `tree_field.gd`,
`far_trees_job.gd` -> `tree_field_job.gd`, `FarTrees` -> `TreeField`,
`FarTreesJob` -> `TreeFieldJob`, the scene node, `[FarTrees]` -> `[TreeField]`
in the log, `far trees (m)` -> `tree field (m)` on F4, and the HUD line now
reports models as well as trees. Both class docstrings are rewritten, because
they described an impostor ring and it is not one.

### The gate

| Stage 5 gate (plan) | result |
| --- | --- |
| all species to the library | `MODEL_SLOTS` is all seven; **636 model instances of 636 - zero cones** |
| the walk extended to distance zero | the inner test applies to cone species only, and there are none |
| band -> rung chosen on measured totals and recorded | above |
| cones retired | drawn nowhere; the builders survive until Stage 7's deletion |
| colour re-pin per decision 7 | `TreeModels.canopy_color()` |
| instance-colour divisor re-pointed | same source, in `_pack` |
| fades and frontier holes re-verified | inherited unchanged; `tree field` gate is exact over the near band |
| **`FarTrees` renamed `TreeField`** | file, class, job, node, log tag, F4 label |
| **standing 60 s -> 0 rebuilds** | **0 far-field and 0 tree-field rebuilds**, 8,696 frames, worst frame **9.6 ms**, 0 over 33 ms |
| **draw calls counted** | **97 slots** at spawn, 99-103 over the tour - the plan predicted "high tens" and this is just above it |
| tour at every rung crossing, and one from the summit | `build/tour/trees-v3-s5`, 18 shots |
| self-test both ways | **green** |

### `tree borders` had to be handled a stage early

With every species in the library a mounted build has **no tree blocks
anywhere**, so `tree borders` reported `0 tree blocks` and failed on its own
"this test proved nothing" guard - which is the correct behaviour and the
wrong result.

It is **not** deleted, and that is the point: **on the assetless leg the block
stamper still runs for everything**, and that leg is the public build and the
one CI runs. So the gate keeps its full assertion exactly where blocks still
exist, and self-skips with a message where they cannot. Stage 7 replaces it
with the canopy-aware siblings the plan names.

### The numbers, so far

| | Stage 0 | Stage 4 | Stage 5 |
| --- | --- | --- | --- |
| field trees at spawn | 580 | 589 | **636** |
| of those, models | 0 | 121 | **636** |
| field slots (draw calls) | 7 | 14 | **97** |
| field triangles at spawn | 17,700 | 606,484 | **1,267,828** |
| field rebuild wall | 475 ms | 539 ms | **563 ms** |
| standing 60 s, rebuilds | 0 | - | **0** |
| standing 60 s, worst frame | 8.6 ms | - | **9.6 ms** |
| `1-spawn` primitives in frame | 10.13 M | - | **11.24 M** (+11%) |

**1.27 M triangles is 72x the cone ring and 11% more primitives in the
frame**, which is what geometry-all-the-way-out costs and what ruling 4 bought
knowingly. It buys a forest with no card in it anywhere.


---

## Stage 6 - the body: colliders, occupancy, the removed-set seam

**A trunk stops you, the ring holds exactly one cylinder per placed tree, and
a ray twenty metres to the side hits nothing.**

### Where the collider ring lives, and why not where the plan said

Decision 8 asks for the colliders to come "through the same worker->main
promotion path `FloraJob` uses for boulders". `FloraJob` is flora's own system
and hard rule 6 makes it read-only to this epic - so the ring takes that
path's SHAPE rather than its code: **`TreeFieldJob` computes the list on the
worker and `TreeField` promotes it on the main thread**, which is the same
split for the same reason, in a file this lane owns.

`TreeFieldJob` already walks the placement lattice at stride 1 near the player
and already knows each tree's variant, so the cylinder's dimensions come
straight off the sidecar at the point the variant is chosen. Nothing is asked
twice.

| | |
| --- | --- |
| radius and height | `TreeModels.trunk_of()` - measured off the model by the tool, never typed |
| where | inside `sim_radius_chunks * Chunk.SIZE` - **the sim radius, not the voxel radius**, because a collider is a GAMEPLAY fact and the sim radius is the ring World already streams collidable ground into for every peer |
| the shapes | one `StaticBody3D` holding a POOL of `CollisionShape3D`, reused across rebuilds and disabled rather than freed |
| the canopy | **does not collide, and never meaningfully did** - leaf blocks were written `only_air`, which made them decoration you could stand inside |
| the budget | the collider batch is a slice on `FarUpload` like any other (decision 10, v5 hard rule 6 verbatim) |
| the knob | `tree_colliders`, LOCAL, default true |

**`tree_colliders` is LOCAL and that classification wants a sentence.** A
collider sounds like world truth and is not: the world truth is WHERE THE TREE
IS, which is `decide()` and is hashed. Whether this machine has built a
cylinder there is the same kind of fact as whether it has built the ground's
own collider, and the host is authoritative for movement either way. Two
machines at different values still agree about the forest.

### The removed-set seam, threaded and unwritten

`TreeField.removed_trees` and `TreeFieldJob.removed`, keyed by placement cell,
checked in **one place** - immediately after `decide()` - so a felled tree is
neither drawn nor collidable and the two cannot disagree.

**Nothing in this epic writes to it.** It is threaded while all three
consumers are being written because adding it afterwards would mean touching
all three again, and because a seam nobody has tried to thread is a seam
nobody knows the shape of. Chopping is fell-as-a-unit now (ruling 2) and the
one mutation path will be its only writer - a client proposes, the host
validates against the allowed list and applies, exactly as a block edit is
treated.

### Open question 4, answered on cost

*"Collider granularity: one cylinder per tree always, or a capsule for the
leaners - body-probe cost decides."*

**One cylinder, always.** The widest ring this test could build holds **213
cylinders**; the ring the game actually builds at `sim_radius_chunks` 4 holds
**1 to 11** over a 960 m sprint. That is not a budget a capsule special case
could improve on, and Tree 09 and Tree 10 - the "leaners" the question was
about - turned out to be coconut palms and are benched.

### The gate

| Stage 6 gate (plan) | result |
| --- | --- |
| trunk cylinders within the sim radius via the promotion path | worker computes, main thread promotes, pooled shapes |
| `removed_trees` threaded, unwritten | one check, immediately after `decide()` |
| the audit's kill-or-keep executed for gameplay queries | `_ground_allows` / `_trees_near` already asked placement and are untouched; nothing else asked at all (Stage 0's grep) |
| **a new test: walk into a trunk, be stopped** | **ray hit yes**, and a ray 20 m clear hits nothing |
| **body-probe count matches placed trees in radius** | **213 cylinders, placement says 213** |
| physics cost of the collider ring measured and recorded | **1-11 cylinders** over a 960 m sprint at the shipped `sim_radius_chunks` |
| self-test both ways | **green** |

Collider dimensions across the sample: **radius 0.44-0.95 m, height
2.00-27.00 m**. The 27 m heights are the bare spires and the 2 m ones the
stumps, both from the tool's `solid` trunk rule - a spire IS a post and a
stump IS a trunk, so a cylinder the height of the model is the right answer
for both.

### A finding: the collider ring's guaranteed margin is 8 m

The ring is rebuilt on the field's own debounce - `far_tree_step_m`, 24 m,
horizontal - and reaches `sim_radius_chunks * Chunk.SIZE` = **32 m**. So a
tree is guaranteed to have a collider from at least **32 - 24 = 8 m** before
the player reaches it, and usually much further.

Eight metres is enough - a sprinting player crosses it in well under a second
and the cylinder is there before they arrive - but it is thinner than it
looks, and it is the number to watch if either knob moves. **Raising
`far_tree_step_m` without raising `sim_radius_chunks` would eventually let a
player walk through a trunk**, and the symptom would be intermittent and
position-dependent, which is the worst kind. Recorded here rather than
guarded in code, because both knobs are Marcel's and the relationship is the
thing to know.

### And the self-test harness would not run an awaiting test

Worth writing down, because the first version of the body test was correct and
the harness refused it. The obvious way to test a collider is to add a
`StaticBody3D` to the scene and fire a ray - and a body is not in its space
until a physics frame has passed, so the test has to `await` one.

**An awaiting test breaks this harness's entire crash-detection method.** It
reports a crash by returning something that is not an int (see the note at the
top of `selftest.gd`), and a coroutine is not an int either. `_ready` refused
to call it at all: `Trying to call an async function without "await"`.

The fix is not to make the harness await - that would mask the crash detection
for all thirty tests. It is to give the test **its own physics space through
`PhysicsServer3D`**, which is live the moment it is created and needs no
frame. Same Jolt server, same cylinder shape, same query; the only thing given
up is the scene tree, which was never part of the claim.


---

## Stage 7 - the deletion

**`tree_species.gd` goes 3,383 lines to 532, the sky reserve is gone, and the
whole column job runs 6.2x faster.** Ruling 5, in a commit that is almost all
red.

### What died

| | |
| --- | --- |
| `TreeSpecies`' shape half | `ChunkWriter`, `ColumnWriter`, `draw()` and every shape function: the whorled cone, the spruce spire and its leader nubs, the larch ziggurat and its shelf limits, the beech's lobes and bites and forks, the bowed birch, the krummholz mound and its spars, three snags, the hero's two archetypes and its root flare, the whorl disc, the overhangs, the clump voids, the trunk writer. **2,851 lines.** |
| `TREE_BLOCKS` / `is_tree_block()` | the last thing in the game that asked a block id whether it was a tree |
| the `shape` and `fill` columns | read by the shape half and by nothing else |
| `TreePlacement.stamp_chunk` / `stamp_cell` / `_stamp_found` | and `stamp_column()` becomes **`cover_column()`** |
| `TerrainGenerator._place_trees` | a generated chunk is terrain and nothing else, which is what the function's own name always claimed |
| `FarTreeMeshes` | the cone, the octahedron, the stepped pyramid, the post, and `color_of_species()`'s block read. The file survives as its own gravestone. |
| **the sky reserve** | `worldgen_config.gd`'s `world_height_blocks` expression, and `World._column_chunk_range`'s `+ max_tree_height()` |
| `loose_check.gd` | the floating-block flood fill. It checked shapes. |
| the gallery's `--vary`, `--stand`, `--masks` and its species rows | trees v1 Stage 0's instruments, every one of them a shape stamped into a scratch volume |
| `tree borders`, `species borders` | replaced, below |

**Block ids stay parked** in `block.gd`, with their `COLORS` rows - removing an
id renumbers a wire format for zero benefit, and the palette rows are what
Stage 2's tree colours were mapped *toward*. `params_for()` still returns them:
open question 5 asks whether it slims now or later and the answer is **later**,
because the plan requires `decide()`'s output shape not to change and a commit
that is already almost all red is the wrong place to also reshape the
dictionary four consumers read.

### The numbers the deletion was for

`tree_probe.gd`, the same 8 x 8 rectangle of columns in the same forest
(canopy cover **0.7871**, unchanged - decision 6's claim, measured).

| | Stage 0 | after | |
| --- | --- | --- | --- |
| **chunks reserved per column** | **9.61** | **1.53** | the sky reserve, gone |
| chunks built per column | 3.14 | **1.42** | tree blocks made chunks solid |
| chunks reserved above the terrain | 6.47 | **0.11** | |
| column: generate voxels | 5.882 ms | 5.811 ms | untouched, as it should be |
| **column: the tree scan** | **125.381 ms** | **3.589 ms** | **35x** - and what is left is the scan `cover_column` still needs |
| **column: mesh** | 111.212 ms | **29.630 ms** | **3.8x** - the mesher lost its worst input AND most of its chunks |
| **column: total** | **242.476 ms** | **39.030 ms** | **6.2x** |
| tree share of generation | 95.5% | 38.2% | |
| tree share of the whole column job | 51.7% | **9.2%** | |
| canopy cover | 0.7871 | **0.7871** | the forest floor is untouched |

**`column_job.gd:11`'s claim is cashed and then some.** It said tree stamping
was half the generation cost; Stage 0 measured 95.5% of generation and 51.7% of
the whole job, and removing it made the whole job **six times faster** rather
than twice. The extra factor is the mesher: it lost the per-block A/B leaf
scatter that `FloraModels:9` names as its pathology, and it lost half its
chunks with them, because a tree's crown was what made a chunk two levels above
the ground `has_solid`.

And in the world, streamed:

| | Stage 0 | Stage 7 | |
| --- | --- | --- | --- |
| **chunks at spawn** | **2,369** | **2,222** | |
| **load wall at spawn** | **24,872 ms** | **19,322 ms** | **-22%** |
| gen per chunk, on workers | 9.51 ms | **4.07 ms** | **2.3x** |
| main-thread upload per chunk | 0.23 ms | 0.14 ms | |
| **sprint collidable front min** | 56 / 64 m | **72 / 72 m** | the streamer got ahead of the player |
| sprint chunks/s | 101.5 / 111.5 | **114.8 / 129.3** | |
| sprint worst frame | 39.4 / 37.7 ms | 34.2 / 40.2 ms | |
| sprint frames over 33 ms | 8 | 5 | |
| holes | 0 / 0 | **0 / 0** | |
| static memory | 393.1 MB | 511.0 MB | **worse - see below** |

**Static memory is up about 118 MB and that is the tree library resident.**
Thirty-eight geometries at three rungs, assembled once at load and held for the
life of the world - which is what "a whole forest is a few dozen draw calls"
costs on the other side of the ledger. It is a steady-state figure rather than
distance v5's handover spike, and the lever is the LOD cache: nothing drops a
rung it is not currently drawing.

### The self-test gates, replaced

`tree borders` and `species borders` both asked questions about block shapes
and both are gone. What replaces them asks the same questions of the SCAN, and
is strictly stronger in one way: **they work on both legs.** `tree borders`
could only prove anything where tree blocks existed, and after tonight they
exist nowhere.

| new gate | what it asserts | result |
| --- | --- | --- |
| **`cover determinism`** | `cover_column()` twice is the same number bit for bit, and the same rectangle walked BACKWARDS gives the same numbers - so the forest floor's shade cannot depend on which column was built first | **49 columns, 8 with cover, mean 0.0756, 0 differed** |
| **`registry determinism`** | `decide()` over a fixed 49 x 49 rectangle hashes equal on repeat - species, old growth, jittered position, ground, height, crown **and the variant**, which is hashed on salt 232 and had never been exercised by any test | **103 trees, 29 distinct variants, hash 198620935, 0 differed** |
| **`sky reserve`, inverted** | `world_height_blocks` does NOT carry a tree's height in it, at every combination the three tree knobs can reach | **36 combinations, 0 still reserve sky** |

**The `sky reserve` gate is inverted rather than deleted, deliberately.**
`REF_MAX_TREE_BLOCKS` and `tree_read_scale` are still in the file and the
expression that used them is exactly the kind of thing somebody restores while
fixing something else. The gate now says, in a runnable form, that putting it
back is a regression.

**`registry determinism` hashes identically with and without the library** -
`198620935` on both legs - which is a stronger statement than either leg alone.
The table lives in the public repo, so what a cell decides is a property of the
repo rather than of the mount.

### The gate

| Stage 7 gate (plan) | result |
| --- | --- |
| shape functions, block writers, `stamp_column`'s writer half, the sky reserve, cone builders, `color_of_species`'s block read | all deleted |
| `max_height()` / the sky-reserve self-test reconciled to the new smaller truth | `max_height()` kept and its meaning NARROWED - it reserves nothing; `max_reach()` is the one still load-bearing, and its note says so |
| `tree borders` replaced by `cover determinism` and `registry determinism` | above |
| self-test both ways | **green** |
| chunks per column at spawn, against Stage 0 | **9.61 -> 1.53 reserved, 3.14 -> 1.42 built** |
| **column generation ms - "expect roughly half"** | **242.5 -> 39.0 ms, 6.2x** |
| load wall at spawn vs Stage 0 | **24,872 -> 19,322 ms** |
| **grep proves no live reference to deleted symbols** | one match, and it is the parked constant the inverted gate reads |
| placement does not move | **28,383 / same mix / (-44, -124) / `4782edac`** |


---

## Stage 8 - sway and the tint channels

### The sway

Shipped at Stage 2 and turned on here, which is the ordering the material note
argues for: the thing Stage 8 turns on is a UNIFORM rather than a new material,
so the sway arrives without every tree's colour moving on the same night.

`tree_sway`, LOCAL, unhashed, **default 0.5**. `COLOR.a` carries each vertex's
height as a fraction of its own model's - 0 at the roots, 1 at the top - and
the shader SQUARES it, so the bottom third of a trunk is effectively still. A
linear weight shears a spruce's lowest branches sideways, which reads as the
tree sliding rather than bending. Phase comes from the INSTANCE's world
position, so a stand moves in one wave; the period is about half grass's and
the amplitude a third of it relative to height, because a 25 m tree that moves
like a tuft is a tree made of rubber.

**Open question 3 is answered in the mesh rather than in the shader:** COLOR's
alpha, because a tree is the one model family in this game with no emissive
parts and the channel the mushrooms use for their glow is free. It costs no
attribute, no second stream and no branch.

**The splice had to go INSIDE `OPAQUE_SHADER`'s own `vertex()`**, which turned
out to be required rather than a consolation - the displacement must happen
before `world_pos` is taken, or the grain and the banded fog are sampled where
the vertex would have been in still air and a moving crown shimmers through
them.

### The season and altitude channels are WEIGHTS, not tints

The plan asks for "instance colour multiplier driven from the mapping table's
colourways". **The colourways turned out to be better than a multiplier.**

This pack ships each tree five times over in green, autumn, crimson, pink and
snow - as separate palettes over ONE SHARED GEOMETRY. So autumn is not a tint
applied to a green tree, it IS the autumn tree, and it costs no new mesh
because the twin already shares the binary. A multiplier would have given a
green tree painted orange; a weight bias gives the tree the artist drew.

| | |
| --- | --- |
| **the tag** | read off `TreePalette` - a variant whose dominant canopy index maps into the AUTUMN ramp is an autumn tree, one that maps to SNOW is snow-dusted. **A fact about the colour table**, so retuning `t13_2` from autumn to green also stops it being an autumn tree, with no second list to keep in step. |
| **`tree_season`** | 0 summer, 1 autumn. **PROPERTIES, hashed, in the join handshake** - it changes WHICH TREE a cell grows, and two machines disagreeing about it would draw different forests while the handshake reported a match (hard rule 5). |
| **snow** | **no knob and wants none** - it is altitude, how far up its own zone's band a tree stands, off the same `zone_band` the far field's colour convergence reads. So the white on a distant ridge and the white on the tree standing on it agree about where the treeline is. |

Measured over 400 larch cells:

| | green | autumn | snow |
| --- | --- | --- | --- |
| summer, valley | 286 | 107 | 7 |
| **autumn, valley** | 23 | **377** | 0 |
| **summer, treeline** | 199 | 76 | **125** |

The greens give way rather than being deleted - a forest that is entirely
autumn is a texture, and one turning tree in three is a season.

### The swatch gate found a real bug, which is what a swatch gate is for

`tree swatches`, a self-test rather than a sheet. The plan offers a choice of
extending the character gallery's swatch strip or adding a tree one; this takes
a third option and **asserts the thing the sheet was looking for instead of
photographing it** - every vertex colour in every assembled mesh must be an
authored `TreePalette` family converted exactly once.

It reported **"13 of 16 families reachable, unused: PINK_A, PINK_B,
BARK_DEAD"** - and that was not a spare-colour note. **It was four hero
variants rendering as one flat brown.**

**A colourway twin ships no geometry and reads its OWNER's `.ktree`, whose
quads carry the OWNER's palette indices.** Tree 15's owner paints with indices
31, 32, 84, 85, 86 and its pink and crimson twins with 1 to 5, so the twin's
palette row matched nothing and every quad fell back to `BARK_DARK`. Tree 13
and Tree 14 were unaffected **only because their twins happen to use the same
numbers as their owners** - luck, not design, and exactly the kind of luck that
makes a bug look like it is not there.

Fixed in the tool: a twin's sidecar is re-keyed into the owner's index space at
bake time. Index j in the twin is index i in the owner exactly when they fill
the same voxels, which is EXACT because identical occupancy is what made them
twins in the first place. Everything downstream reads one index space and the
game needs no remapping step. `Kubik-assets` `490ce13`.

**15 of 16 families are reachable now.** The one that is not is `BARK_DEAD`,
deliberately - it is where a variant goes when somebody benches one into the
snag register, and a family invented at that moment is a family invented
differently.

### And the gate's own tolerance took three attempts

Worth recording because two of them failed on all 638,164 vertex colours at
once, which looks like a catastrophe and is a comparison bug.

1. **Compare floats exactly.** An `ArrayMesh` stores a vertex colour in eight
   bits per channel and hands back the quantised value, not the float pushed.
2. **Quantise both sides by rounding.** Godot **truncates** - `c * 255` cast to
   a byte - so an authored `0.2195` goes in as 55.97 and comes back as 55.
3. **Within one unit per channel.** Truncating both sides is right in principle
   and lands on a knife edge: `0.2823 * 255` is 71.99 authored and 70.99 read
   back, so one float ulp moves the answer by a whole unit.

One unit is the smallest tolerance eight bits admits, and far tighter than the
6 the plan offers - that number is the character gallery's and it is about a
PHOTOGRAPH, with light and a renderer in the way.

### The gate

| Stage 8 gate (plan) | result |
| --- | --- |
| sway weighted by the chosen channel | COLOR alpha, squared; `tree_sway` default 0.5 |
| seasonal / altitude tint hooks from the mapping table's colourways | **weights rather than tints** - see above; zero new meshes, zero new draw calls |
| snow-dust above the treeline band | altitude-driven, no knob, off the far field's own `zone_band` |
| autumn as a table row Marcel can flip | `tree_season`, PROPERTIES |
| a sway-on/off tour pair | `build/tour/trees-v3-sway` (`tree_sway` 1.0) against `build/tour/trees-v3-still` (0.0), 18 shots each, **all 18 differ** |
| swatch-gate discipline | `tree swatches`: **638,164 vertex colours over 55 variants, 0 wrong**; sway weight 0.0000-1.0000; 15 of 16 families reachable |
| self-test both ways | **green** |

**The sway pair is an eye judgement and the pixel counts are not evidence.**
All eighteen shots differ, and STATUS item 13a says the tour is not
bit-reproducible in the near field anyway - flora lands in a different order
run to run. What the pair is FOR is looking at, and the files are on ganymede.

