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

