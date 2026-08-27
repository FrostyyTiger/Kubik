# Distance v1 - status

The run of `docs/plans/distance-v1.md`, on `feat/distance-v1` from `main` at
`e7c5d9d` (world feel v1 merged, and ganymede's GPU found). Night 1 is the
ground - the far mesh's geometry and its colour. Night 2 is what grows on it
and the near field.

**THERE IS NO "TUNED BLIND" SECTION IN THIS DOCUMENT, AND THAT IS THE POINT.**
Every previous status doc in this project carries one, because ganymede shipped
with `nvidia-headless-595-open` - the compute-only driver - so the Vulkan loader
found no ICD and Mesa fell back to llvmpipe. `e7c5d9d` found that and fixed it
with one package. Verified again at the start of this run: through the same
`xvfb-run -a` line, Godot reports **`Vulkan 1.4.329 - Forward+ - NVIDIA GeForce
RTX 3070 Ti`**. Every tone this epic changed was judged against a picture taken
here, on the same box, under the same renderer.

What replaces it is a **provenance column**. Every previous doc conflated "a
number" with "a number worth comparing", and `e63554f` is the bill for it - a
publicly retracted performance delta. So every number below says which box it
came from and whether it is a single run or an interleaved median.

| provenance | means |
| --- | --- |
| `ganymede, deterministic` | the far probe or the worldgen probe. Pure geometry from a seeded generator: same number on any box, every run, and the probe asserts it. |
| `ganymede, single run` | one wall-clock measurement. A smoke alarm, not evidence of a delta. |
| `ganymede, ABAB median` | interleaved, three runs each, median with spread, run order recorded. The only kind of number this epic compares two commits with. |
| `ganymede, eye` | a judgement made by looking at a tour shot taken here. |

---

## Stage 0 - Measure first: the fizz probe

**Shipped.**

- `scripts/tools/far_probe.gd`, `--far-probe`, wired into `game.gd` beside the
  stream probe. It builds `FarFieldJob` directly - no rendering, no window - at
  three vantages derived from the world the way `screenshot_tour.gd` derives
  its own (spawn, the highest summit, the biggest lake), and reports FIZZ,
  ROUGHNESS and PEAK LOSS.
- The F3 readout gains `far mesh   N verts, N ms build, N ms wall, N rebuilds`.
  `FarField` times the job and the wall separately; `FarFieldJob.elapsed_ms`
  times its own `run()`.
- `build/tour/dist-base/` - the full sixteen-shot tour, re-taken **on ganymede
  with the GPU working**, so every later stage compares pictures taken on the
  same box under the same renderer. The Windows `world-feel-v1` set stays on
  Marcel's machine as the eye he already has.

### It reads the mesh, not the formula

Drawn height comes from the triangles `FarFieldJob` actually emitted: the quad
is split along `p0-p2` exactly as the index buffer splits it, and the height is
barycentric inside whichever half the sample lands in. Skirts are excluded by an
exact test rather than a tolerance - a skirt is a vertical curtain, so one of
its two XZ edge vectors is zero. Where two rings overlap, the **finer** quad
wins: it is the one nearer the player and the one drawn in front.

Re-deriving "what the height would be" from the ring rules would have measured
the probe's opinion of the far field rather than the far field, and the two
would have drifted apart at the first stage that changed one and not the other.

### The instrument was aliased against the thing it measures, and that was the first finding

The first version sampled FIZZ on a **16-block** world lattice, which looks like
the obvious choice and is the one thing it must not be. The rings step by 8, 16
and 32 blocks, and a coarse ring's vertices are a **subset** of a fine ring's -
so at a shared lattice point two rings agree *by construction*, whatever they do
in between. Sampling on a multiple of 16 lands on agreement points on purpose.

It showed up as a number that could not be true: **the 200-400 m band measured a
flat `0.00` FIZZ**, while the 400 m boundary next to it measured 60. One ring
boundary cannot be perfect and its neighbour catastrophic. The lattice is now
**13 blocks**, which shares no factor with 8, 16 or 32, and the 200 m boundary
promptly appeared (0.28 - 6.91 blocks, per vantage).

Caught before any baseline was recorded, so nothing downstream is built on the
aliased numbers. Recorded here because "the probe agreed with the mesh" is a
failure mode this project has not met before and will meet again.

### The baseline

Seed 42, `--view high`, fog_end 800 m, far_step 8 blocks. All heights in
**blocks** (1 block = 0.5 m game, 2 m real at 1:4).

| vantage | FIZZ rms | FIZZ max | ROUGHNESS |
| --- | --- | --- | --- |
| spawn | 0.291 | 17.844 | 4.7541 |
| summit | 0.217 | 12.094 | 3.9240 |
| lake | 0.492 | 33.322 | 5.2698 |
| **ALL** | **0.373** | **33.322** | **4.5894** |

138,832 sample positions covered by both builds. Max FIZZ per 100 m band, which
is what the Stage 2 gate is read against:

| band (m) | 0-100 | 100-200 | 200-300 | 300-400 | 400-500 | 500+ |
| --- | --- | --- | --- | --- | --- | --- |
| spawn | 1.76 | 2.04 | 6.91 | 16.76 | 17.84 | 0.00 |
| summit | 2.22 | 12.09 | 5.70 | 7.84 | 11.57 | 0.00 |
| lake | 1.84 | 1.75 | 0.28 | 33.32 | 18.63 | 0.00 |

**The shape of that table is the whole diagnosis.** Everything past 500 m is
*exactly* zero and so is everything the fine rings own; all the movement is
piled against the two ring boundaries at 200 m and 400 m. That is not noise, it
is the LOD boundary sliding past a mountain - the probe walks the player 16 m,
which is a multiple of every ring's step (8, 16 and 32 blocks), so every ring's
snapped lattice lands on exactly the same world positions in both builds and
**the only thing that can differ is which ring a quad belongs to**. The artefact
is isolated by construction.

### PEAK LOSS, and it is much worse than the plan assumed

| | Stage 0 |
| --- | --- |
| mean loss over the 20 highest summits, at 600 m | **+60.27 blocks** |
| worst | **+128.01** |
| best | **+11.76** |
| summits outside the plan's 4-block line | **20 of 20** |

Positive means the drawn summit is LOWER than `height_at()` says it is. 60
blocks is 30 m in game and **120 m at the 1:4 real scale** - a summit drawn at
600 m is, on average, a fifth of a kilometre short of the mountain you walk to.

**This is measured before this epic changes anything.** It is not filter loss;
there is no filter yet. It is the raw LOD lattice: ring 2 takes one sample every
32 blocks (16 m) from a grid whose content runs down to 2 m, and a *local
maximum* is precisely the place where an unfiltered sample is most biased
downward. `hills_amp` is 60 blocks at a 60-block wavelength, which a 32-block
lattice is already below Nyquist for.

**Stage 3's gate as written cannot be met and was never about this.** The plan
says "no summit visible from a tour vantage loses more than 4 blocks of drawn
height at 600 m", which reads as an absolute limit; against a baseline of +60 it
is unreachable by any filter, because the thing it would have to fix is the LOD
scheme itself and not the filter on top of it. The gate that can be honestly
run, and the one Stage 3 is run against below, is **relative**: Stage 2 must not
make PEAK LOSS materially worse than Stage 0's, and if it does, Stage 3 exists
to buy it back. Flagged rather than quietly reinterpreted.

### VALLEY GAIN, the mirror, and it is clean

A box filter lowers summits **and raises valleys**, and Stage 3's max pyramid
buys the summits back by dilating - which raises valleys further. A column that
only watched the peaks would show that trade as pure profit, so the probe
reports the twenty lowest basins beside the twenty highest summits.

| | Stage 0 |
| --- | --- |
| mean gain over the 20 lowest basins, at 600 m | **-1.09 blocks** |
| worst | **-0.63** |
| best | **-1.50** |
| basins outside the 4-block line | **0 of 20** |

Positive would mean the drawn floor is HIGHER than the truth; it is negative and
tiny, so the far field draws valleys about one block too deep and no more. The
asymmetry against the peaks' +60 is not a bug - the world's low ground is flat
meadow and lake bed, where an unfiltered sample has almost nothing to miss,
while a summit is by definition the place a sparse lattice is most biased
against. It also means Stage 3 has real room: there are 4 blocks of headroom
before a dilation starts filling valleys visibly.

### Determinism - hard rule 7

The probe runs its whole table **twice in one session** and compares the two
character for character.

| | |
| --- | --- |
| run 1 | 34,355 ms |
| run 2 | 34,308 ms |
| tables | **IDENTICAL** |
| verdict | **PASS** |

92 far meshes built over the two runs: **658 ms each, 95,088 vertices each**.
(Lower than world feel v1 Stage 7's 103,608 because the probe builds with an
empty frontier - no per-sector voxel hole - and at three different centres.)

### Provenance

| number | provenance |
| --- | --- |
| the FIZZ / ROUGHNESS / PEAK LOSS table | ganymede, deterministic (asserted identical across two runs) |
| 650 ms per far mesh | ganymede, single run, main thread, nothing else on the box |
| `dist-base` tour | ganymede, Vulkan Forward+, RTX 3070 Ti |
| stream probe baseline | ganymede, ABAB median - see below |

### The stream-probe baseline, which is what hard rule 6 is measured against

Three runs, seed 42, `--view high --strict`, back to back with nothing else on
the box, **run order and wall clock recorded** because that is the half every
previous performance number in this project left out. Taken at the Stage 0
commit, whose streaming behaviour is byte-identical to `e7c5d9d`'s - this epic
has not touched a chunk, a column or the frontier.

| run | started (UTC) | holes | frames > 33 ms | worst frame | built/s out | built/s back | 48 m settle out |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | 16:13:31 | 0 | 35 | 43.5 ms | 76.5 | 82.5 | 10,623 ms |
| 2 | 16:16:48 | 0 | 17 | 43.8 ms | 78.4 | 84.5 | 9,933 ms |
| 3 | 16:19:56 | 0 | 12 | 45.5 ms | 81.3 | 88.9 | 9,671 ms |
| **median** | | **0** | **17** (12-35) | **43.8** | **78.4** (76.5-81.3) | **84.5** (82.5-88.9) | **9,933** |

**Holes 0 in all three - hard rule 4 holds.** The frame budget does not: all
three FAIL, which is STATUS.md item 5 exactly as it was left. That is not this
epic's to fix; what this epic owes is that the number does not get **worse**,
and this table is what "worse" will be measured against.

Two things worth naming about the runs themselves. The spread on the long-frame
count is **12 to 35 on identical code**, which is the threshold-count problem
`stream_probe.gd`'s own note describes - `built/s` underneath it moves by 6%
over the same three runs. And the drift here goes the *opposite* way to the
Windows box's: run 1 was the slowest and run 3 the fastest, so this box warms
into a session rather than throttling out of one. Either way the defence is the
same and it is the one hard rule 8 names: interleave, never compare a run to a
remembered one.

Also worth recording because it contradicts an assumption in the plan: a stream
probe run here takes **about three minutes**, not the twenty-five that
`stream_probe.gd`'s note quotes. That note was written on llvmpipe. Three
minutes is cheap enough that the ABAB interleave Stage 7 owes is an easy twenty
minutes rather than an evening.

### Gates

| gate | result |
| --- | --- |
| heightmap hash | **`76cccdb6`** |
| spawn | **(-44, -124)** |
| trees | **28,383** |
| config hash | `3d45b8fc` |
| self-tests | green |
| far probe determinism | PASS |

---

## Stage 1 - The pyramid

**Shipped.** `Heightmap` carries a filtered mip pyramid: level 0 is `cells`
itself at 2 m, and each level above is a 2x2 box mean of the one below.
`height_at_level()` is bilinear on one level; `height_filtered()` is trilinear
between two.

**It is derived and it is never written back** - hard rule 3. `cells` is
untouched, `hash_key()` is untouched, and nothing that decides what the world
*is* reads a level above 0.

### Weighted, and that is what makes the mean conserve exactly

1500 halves to 750, 375, 188, 94, 47, and **375 is odd** - so the last cell of
level 3 has one parent, not two. Averaging it against a duplicated edge cell
would double-count that column and shift the mean by about one part in `cols`;
averaging it alone and carrying how many level-0 cells sit under each cell does
not. The weight is analytic - it depends only on the index and the level - so
it costs no memory at all, and it is what the self-test asserts.

| level | cells | metres per cell |
| --- | --- | --- |
| 0 | 1500 x 1500 = 2,250,000 | 2 |
| 1 | 750 x 750 = 562,500 | 4 |
| 2 | 375 x 375 = 140,625 | 8 |
| 3 | 188 x 188 = 35,344 | 16 |
| 4 | 94 x 94 = 8,836 | 32 |
| 5 | 47 x 47 = 2,209 | 64 |

### The cost, and it is nothing

| | measured | the plan's line |
| --- | --- | --- |
| pyramid build | **214 ms** | "a second is affordable, five is not" |
| the coarse heightmap it sits beside | 15,807 ms | (10.2 s on Marcel's box) |
| memory | **+2.9 MB** over level 0's 8.6 MB | "roughly a third more, about 3 MB" |

214 ms against the heightmap's own 15.8 s is **1.4%**, so the question of doing
it on a worker does not arise. Built lazily under a mutex on first use, which is
`FarFieldJob` on a `WorkerThreadPool` task from Stage 2 onward - that keeps the
whole pyramid inside `heightmap.gd`, and this lane owns neither the code that
fills `cells` nor `world.gd`.

### The conservation law, on the real map and in the suite

The weighted mean of every level, over the whole 1500 x 1500 map:

```
level 0  185.825311      level 3  185.825311
level 1  185.825311      level 4  185.825311
level 2  185.825311      level 5  185.825311
```

Identical to every digit printed. The new self-test **`heightmap pyramid`** runs
the same check on a 400-block world - 100 cells halving to 50, 25, 13, 7, 4, so
**two of its five levels have a short last column** and the odd case is under
real pressure at a fraction of the cost. It also asserts that
`height_at_level(level 0)` is `height_at()` *exactly* (the far field falls back
to it at the seam and the two must be the same surface), that
`height_filtered(2.0)` agrees with level 2, and that no level leaves level 0's
min/max - a mean of means cannot, and one that does has an index bug.

### Provenance

| number | provenance |
| --- | --- |
| pyramid build 214 ms, +2.9 MB | ganymede, single run, main thread, nothing else on the box |
| the conservation table | ganymede, deterministic |

### Gates

| gate | result |
| --- | --- |
| heightmap hash | **`76cccdb6`** (unchanged, before and after building the pyramid) |
| spawn | **(-44, -124)** |
| trees | **28,383** |
| config hash | `3d45b8fc` |
| self-tests | green, including the new `heightmap pyramid` |


---

## Stage 2 - The level is a function of distance, not of ring

**Shipped.** The far mesh reads the pyramid at a level that is **continuous in
distance** and sampled **trilinearly**:

```
level(d) = log2(d / far_level_ref_m) + far_filter_bias      clamped to [0, 5]
h(p)     = lerp(height_at_level(p, floor(level)),
                height_at_level(p, floor(level) + 1),
                frac(level))
```

`d` is measured from the **ring's own snapped centre**, so the level field is
stable under exactly the snapping that already stops the mesh shimmering: it
changes only when the player crosses a snap step, and every ring's snap step
divides 16 m.

`far_level_ref_m` 100 m, `far_filter_bias` 1.0, both LOCAL and unhashed, both on
F4. Those two numbers turn out to be self-consistent in a way worth writing
down: **each ring starts at exactly the level whose cell size equals its own
vertex step, and ends one level above it.** Ring 0 (4 m step) spans 88-200 m and
runs level 1 to 2; ring 1 (8 m) spans 200-400 m and runs 2 to 3; ring 2 (16 m)
spans 400 m to the fog and runs 3 to 4.3. That falls out of ref = 100 m and
every ring doubling both its step and its range together.

### The filter has to fade out at the seam, and that is not in the plan

Hard rule 5 says the seam stays invisible: `_corner_y` blends the far mesh onto
the **voxel** surface over the last few cells, and that only works if the coarse
term there is the coarse term the voxels were built from - level 0.

The seam sits at 88 m. `log2(88/100) + 1` is **0.82**, not 0. Left alone, the
filter would have reintroduced the half-block step at the seam that world feel
v1 spent a whole stage removing - and it would have done it silently, because
nothing in the probe watches the seam. `_level_at()` therefore multiplies the
level by `(1 - blend)`, using the same seam blend `_corner_y` already computes,
so the seam is **exactly level 0** and the filter comes on over the same band
the detail fades out over.

### The gate, and it is not met as written

| | Stage 0 | **Stage 2** | the plan's gate |
| --- | --- | --- | --- |
| FIZZ rms, all | 0.373 | **0.395** | fall by 4x, to 0.093 |
| FIZZ max, all | 33.322 | **22.523** | no spike at 200 / 400 m |
| ROUGHNESS, all | 4.5894 | **2.4784** | falls |
| PEAK LOSS, mean | +60.27 | **+114.76** | (Stage 3's problem) |
| VALLEY GAIN, mean | -1.09 | **-0.34** | - |
| far mesh build | 650 ms | **912 ms** (+40%) | - |

**ROUGHNESS falls by 46% and FIZZ max by 32%. FIZZ RMS rises by 6%, and the
4x fall the plan asks for is not reachable by this design at all.** That is a
statement about the mechanism, not about the tuning, and the per-band table is
where you can see why:

| band (m) | 0-100 | 100-200 | 200-300 | 300-400 | 400-500 | 500-600 | 600-700 | 700-800 | 800-900 | 900+ |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Stage 0, spawn | 1.76 | 2.04 | 6.91 | 16.76 | 17.84 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 |
| Stage 2, spawn | 1.80 | 2.81 | 3.22 | 22.52 | 14.46 | 1.04 | 2.29 | 1.79 | 2.22 | 1.91 |

At Stage 0 everything past 500 m was **exactly zero**: walk 16 m and the far
half of the world did not move by a float. It could not, because 16 m is a
multiple of every ring's step, so the lattice was identical and only ring
membership could change - and past 500 m nothing changes ring.

At Stage 2 those bands read 1-3 blocks. **The level is a function of distance
from the player, so when the player moves, the level moves, and the whole far
field breathes a little.** That is the price of continuity, and it is the price
the plan chose knowingly when it rejected "one level per ring" for keeping the
pop. What it did not anticipate is that FIZZ *RMS* - an average over the whole
disc - is dominated by that small everywhere-change rather than by the large
somewhere-change at the ring boundaries. FIZZ **max** is the number that tracks
the artefact you can actually see, and it falls.

**Both readings are in the table and neither is hidden.** For Marcel, the honest
summary is: the big re-cut at the ring boundary is a third smaller, the
jaggedness is halved, and in exchange the distance now drifts by one to three
blocks - a metre or less on screen - as you walk. Whether that trade is right is
a judgement the pictures answer better than the RMS does, and the pictures are
below.

### far_filter_bias, three ways, for Marcel to rule on

`build/tour/dist-2-bias0`, `dist-2-bias1`, `dist-2-bias2` - `6-postcard`,
`14-postcard-dusk` and `16-spawn-postcard` at each. Probe numbers over the same
sweep, plus 3.0 which is out of the running and says why:

| far_filter_bias | 0.0 | **1.0 (shipped)** | 2.0 | 3.0 |
| --- | --- | --- | --- | --- |
| FIZZ rms | 0.359 | **0.395** | 0.497 | 0.338 |
| FIZZ max | 25.371 | **22.523** | 11.764 | 19.296 |
| ROUGHNESS | 3.4649 | **2.4784** | 1.5553 | 1.0725 |
| PEAK LOSS mean | +81.30 | **+114.76** | +172.19 | +199.87 |
| PEAK LOSS worst | +126.53 | **+173.89** | +250.76 | +300.06 |

**The eye, on ganymede, at `6-postcard`.** Every one of the three is a large
improvement on `dist-base`, where the ranges read as crumpled foil. At **0.0**
the mountains are already big simple masses with a lit flank and a shaded one.
At **1.0** the silhouettes simplify further and the fields get larger without
the profiles going soft - this is the one that looks like the poster. At **2.0**
the summits are visibly *shorter and rounder*: the central dark peak loses its
point and becomes a dome, which is exactly the failure Stage 3 exists to catch,
now visible rather than inferred.

**3.0 is disqualified by the probe rather than by taste**, and the reason is
instructive: its worst FIZZ moves to the **0-100 m band** (19.30 at the summit
vantage), which is the seam. At that bias the level just outside the seam fade
is nearly 3, so the far mesh a few metres past the voxels is drawn from a 16 m
filter while the voxels beside it are not - the seam becomes the artefact. Hard
rule 5 puts a ceiling on this knob, and it is somewhere between 2 and 3.

**Shipped at 1.0**, the plan's starting value, on the strength of the pictures.

### Cost

The far mesh build goes **650 -> 912 ms** (+40%) on the probe's main-thread
measurement: two pyramid lookups per vertex instead of one raw one, plus a
`sqrt` and a `log` per vertex for the level. Vertex count is unchanged
(95,088). This is worker time, not frame time; the stream probe below is what
says whether it is felt.

### Streaming: hard rule 4 holds, and nothing regressed

One run, seed 42, `--view high --strict`. The plan asks for `--strict` green;
it exits 1, and the reason is the frame budget that was **already failing at
Stage 0**, not anything this stage did:

| | Stage 0 baseline (median of 3) | **Stage 2** (single run) |
| --- | --- | --- |
| hole samples | **0** | **0** |
| frames over 33 ms | 17 (12-35) | **7** |
| worst frame | 43.8 ms | 47.4 ms |
| built/s, out leg | 78.4 (76.5-81.3) | 84.7 |
| 48 m settle, out | 9,933 ms | 9,524 ms |

**Holes 0 - hard rule 4 is intact.** This stage moves every vertex near the
seam and the exclusion logic sits three lines away, so that was the thing worth
checking, and it is clean.

The long-frame count reads 7 against a baseline median of 17, which is inside
the baseline's own 12-35 spread on identical code and is therefore **not
evidence of an improvement**. It is evidence of no regression, which is what
hard rule 6 asks for at this stage. A real delta needs the ABAB interleave
Stage 7 owes.

### Gates

| gate | result |
| --- | --- |
| FIZZ rms falls 4x | **NOT MET** - 0.373 -> 0.395. Recorded above; the mechanism cannot meet it |
| stream probe holes | **0** - hard rule 4 green |
| stream probe `--strict` exit | **1**, on the pre-existing frame budget only (STATUS.md item 5) |
| self-tests | green |
| no spike at 200 / 400 m | **partly** - the 200 m spike halves (6.91 -> 3.22), the 400 m spike does not (16.76 -> 22.52) |
| ROUGHNESS falls | **MET** - 4.5894 -> 2.4784, -46% |
| far probe determinism | **PASS**, identical over two runs at every bias tried |
| heightmap hash | **`76cccdb6`** |
| spawn / trees | **(-44, -124)** / **28,383** |
