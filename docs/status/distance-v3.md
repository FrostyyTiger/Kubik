# Distance v3 - status

The run of `docs/plans/distance-v3.md`, on `feat/distance-v3` from `main` at
`1ece781` (distance v2 merged, `far_terrace` flipped to 1.0, the plan itself).
One night, unattended, on ganymede. **The far country stops being mush.**

Distance v2 made the far country block-SHAPED. This epic makes it
block-SURFACED and makes all of it visible: stand in the valley and see the
rim of the region, blocky, hazed, with no fog wall. The research it stands on
is `docs/research/distant-horizons.md`, read from DH's source, and its
one-line summary is that the epic look is four tricks and three of them are
shader work.

*(this document is written as the run proceeds; sections appear in stage
order)*

---

## Provenance

Distance v1 introduced this column, distance v2 kept it, and it is kept again
unchanged.

| provenance | means |
| --- | --- |
| `ganymede, deterministic` | the far probe or the worldgen probe. Pure geometry from a seeded generator: same number on any box, every run, and the probe asserts it by running its whole table twice. |
| `ganymede, single run` | one wall-clock measurement. A smoke alarm, not evidence of a delta. |
| `ganymede, ABAB median` | interleaved, three runs each, median with spread, run order recorded. The only kind of number this epic compares two commits with. |
| `ganymede, eye` | a judgement made by looking at a tour shot taken here, on the RTX 3070 Ti, under the renderer named in the shot's directory. |

ganymede varies about 9% run to run on wall clock; Marcel's desktop varies 60%.
Every comparative number below was taken here.

**Every per-pixel number in this document says which ROWS it came from, and
that is not pedantry.** Distance v2 measured two tours of identical code: the
far band (rows 0-300 of a 1280x720 frame) came back at mean |dL| 0.0000 and
worst 0.0 - bit-identical - while the near field (rows 500-720) differed by up
to 48 luma levels, because which flora columns have finished streaming when the
shutter opens is not deterministic. A whole-frame diff of a tour pair proves
nothing. A far-band diff proves everything.

---

## Stage 0 - Instruments first: the fleck number and the baseline

**Shipped.** Four instruments, three of them new, and one of the three closes a
carried item from distance v2.

**THE FLECK NUMBER.** `tools/png_diff.py --local-contrast --rows A:B` -
mean |dL| against the 4-neighbours over a row band, in sRGB luma levels. Mush
is a far band whose neighbouring pixels agree; a block-surfaced far country is
one where they do not. Reported with two companions, and the companions are
not decoration:

- **p95** of the same pair distribution, and
- **textured**, the share of neighbour pairs over 2 levels,

because **the far band of a tour frame is part SKY**, and the sky is a smooth
gradient in flat bands that contributes almost nothing to |dL|. A shot whose
upper third is mostly sky dilutes the mean toward zero, so a real change in the
country moves it less than it should. p95 and the textured share read the
fleckiest pixels, which are the ground ones. **This is a limitation of the
plan's metric as written and it is named rather than worked around**: all three
numbers are reported at every stage and the mean is not read on its own.

**THE ROW BANDS ARE CONSTANTS NOW.** `FarProbe.FLECK_FAR_ROWS` (0-300) and
`FLECK_NEAR_ROWS` (500-720), and the far probe prints the exact command with
them substituted, so the two halves of the instrument cannot drift apart. The
far probe cannot measure the fleck itself - it reads a mesh's triangles and
never a frame - and printing the recipe is the honest version of "the number
lands in the status doc".

**`[FarField] first build`, printed once per session.** The far mesh's vertex
count, job time and WALL time, at the first build of a run. This is distance
v2's carried item 13 - "the far probe is structurally blind to the frontier,
so a change to exactly that passed seven stages of identical-on-every-geometry-
row; either the probe should take a frontier, or the far-mesh vertex count the
WORLD prints at load should be a gate in its own right. The second is nearly
free" - and it is now free and in `far_field.gd` rather than in `world.gd`,
which is another lane's file.

**`--far-probe --cost`.** The same builder at the same three vantages, three
meshes each, job ms as a median with its range and the vertex count beside it.
It exists because hard rule 7 says perf claims are ABAB medians and the full
table is **4m10s a run** - twenty-five minutes for one three-and-three
comparison, at every stage that touches the job. The cost table is about ninety
seconds.

**The two cost numbers are different questions and both are reported.** The
probe's is the JOB's own time on the main thread with nothing else happening -
the least contended number this project can take. `[FarField] first build`'s
wall is what the player feels: it waits for a worker pool that runs one
GDScript task at a time while 2,400 chunks are being generated on it. At
baseline they are **1,920 ms** and **4,444 ms** for the same work.

### The baseline, and the numbers this epic is read against

Seed 42, `--view high`, fog_end 800 m, far_step 8 blocks, `far_terrace 1.0`,
heightmap `76cccdb6`, config `3d45b8fc`, spawn `(-44, -124)`. Heights in
**blocks** (1 block = 0.5 m game, 2 m real). `ganymede, deterministic` unless
the row says otherwise.

| | `1ece781` |
| --- | --- |
| FIZZ rms / max | 1.260 / 80.000 |
| ROUGHNESS | 15.6004 |
| ring boundary 200 m | max 24.00, rms 2.775 |
| ring boundary 400 m | max 80.00, rms 6.102 |
| terrace compliance | 100% at 8, 16 and 32 blocks, all three vantages |
| seam vs voxel surface, max | 3.370 / 19.570 / 0.680 (spawn / summit / lake) |
| shelf move over a 200 m walk, rms | 4.544 / 6.635 / 5.171 |
| PEAK LOSS at 600 m | +24.20 mean, +49.85 worst, -6.28 best |
| VALLEY GAIN | -6.53 mean |
| far mesh, far probe (no frontier) | **252,966 vertices, 1,920 ms** per mesh |
| far mesh, in game (first build) | **262,312 vertices, 4,441 ms job, 4,444 ms wall** |
| impostors at spawn | 580 |
| far probe determinism | **PASS**, tables IDENTICAL over two runs |

### The fleck table, baseline

`ganymede, eye` in provenance but arithmetic in substance: a tour on this box,
Forward+, seed 42, `--label s0-base`, 17 shots, measured by
`tools/png_diff.py --local-contrast`. Mean |dL| against the 4-neighbours in
sRGB luma levels; p95 of the same distribution; `tex` is the share of
neighbour pairs over 2 levels.

**The near band is the reference and it is not always the near field.** At
`6-postcard` and `14-postcard-dusk` the bottom of the frame is distant ground
and a lake, so their near numbers are low for an honest reason. The shots where
rows 500-720 really do hold voxels under the player's feet - `1-spawn`,
`16-spawn-postcard`, `4-valley-floor`, `3-forest-slope` - measure **3.2 to
8.2**, and that is the number "what blocks are supposed to look like" means.

| shot | far fleck | far p95 | far tex | near fleck | near p95 | near tex |
| --- | --- | --- | --- | --- | --- | --- |
| 1-spawn | 4.335 | 24.64 | 26.8% | 6.670 | 40.63 | 33.7% |
| 2-summit | 1.085 | 11.13 | 10.1% | 2.338 | 11.22 | 26.3% |
| 3-forest-slope | 2.102 | 16.85 | 13.6% | 3.210 | 17.98 | 27.0% |
| 4-valley-floor | 1.345 | 0.00 | 3.7% | 6.827 | 40.69 | 33.9% |
| 5-lake | 2.236 | 15.43 | 16.8% | 3.017 | 16.14 | 26.8% |
| **6-postcard** | **3.940** | **18.00** | **27.7%** | 0.268 | 0.21 | 1.9% |
| 7-forest-interior | 0.834 | 3.00 | 7.0% | 1.055 | 3.35 | 6.9% |
| 8-meadow-closeup | 9.179 | 46.05 | 42.2% | 1.823 | 7.78 | 17.6% |
| 9-treeline | 1.719 | 11.36 | 18.2% | 0.609 | 3.14 | 10.8% |
| 10-shore | 0.686 | 2.14 | 5.0% | 0.177 | 0.79 | 0.9% |
| 11-forest-dusk | 0.671 | 2.14 | 5.8% | 0.628 | 1.86 | 4.6% |
| 12-meadow-night | 1.997 | 13.14 | 10.9% | 2.457 | 16.07 | 19.1% |
| 13-meadow-dawn | 1.332 | 10.07 | 10.3% | 1.652 | 10.07 | 16.0% |
| 14-postcard-dusk | 3.094 | 14.10 | 28.6% | 0.154 | 0.72 | 0.6% |
| 15-boulder | 3.368 | 18.53 | 23.0% | 0.565 | 2.35 | 6.1% |
| 15-under-canopy | 0.681 | 2.28 | 6.4% | 0.858 | 3.14 | 6.5% |
| 16-spawn-postcard | 1.557 | 11.86 | 10.9% | 8.239 | 45.62 | 36.4% |

### Gate

| gate | result |
| --- | --- |
| the fleck table exists with baseline numbers for all 17 shots | **MET** - above, both bands |
| the far probe still passes its determinism assertion | **MET** - `PASS`, tables IDENTICAL, run 1 in 99,317 ms and run 2 in 99,256 ms |
| self-test | **MET** - `SELFTEST: all passed`, 3m54s |
| `config.hash_key()` | **`3d45b8fc`**, heightmap **`76cccdb6`** - hard rule 1's starting values |

### One thing the tour does that is not new and is worth writing down

`7-forest-interior` and `15-under-canopy` hit `MAX_WAIT_FRAMES` - "gave up
waiting for chunks after 5400 frames" - on this box, at baseline. Both are
flora-heavy near-field vantages and both are photographed anyway. It is
pre-existing, it is the same on every run, and it is another reason no
per-pixel number in this document is taken over a near band.

