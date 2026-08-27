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

---

## Stage 3 - The peaks keep their height

**Not skipped.** The plan says to read Stage 2's PEAK LOSS first and skip this
stage if every summit is inside the gate. Stage 2 measured **+114.76 blocks**
mean loss, nearly double the +60.27 the *unfiltered* far field already lost, so
the stage is exactly as necessary as it was written to be.

**Shipped.** `Heightmap` carries a second, parallel pyramid built in the same
pass: 2x2 **max** instead of 2x2 mean. `FarFieldJob._filtered()` draws
`lerp(mean_level, max_level, far_peak_gain)`. It restores amplitude without
restoring high frequency, because the max pyramid is itself smooth at its own
level - it is a dilation, not a sharpen. At gain 0 the second pyramid is never
read, so the knob turns the whole mechanism off.

Cost: one more array of the same size (+2.9 MB, ~6 MB of pyramid in total, on
top of level 0's 8.6) and no extra pass - the dilation is computed alongside the
mean and needs no weights, because the max of a short run is the max of the
cells that are actually there.

### The gate had to be reinterpreted, and the reinterpretation is stated rather than assumed

The plan's gate is "no summit visible from a tour vantage loses more than **4
blocks** of drawn height at 600 m". Stage 0 measured the *unfiltered* far field
losing **+60.27 blocks mean, 20 of 20 summits outside that line**. An absolute
4-block gate was therefore unreachable before this epic began; what it would
take to reach it is a different LOD scheme, not a filter on top of one.

**The gate this stage was actually run against:** `far_peak_gain` is turned up
until PEAK LOSS is **no worse than Stage 0's unfiltered baseline**, subject to
ROUGHNESS not regressing from Stage 2 by more than 10%.

### The sweep

At `far_filter_bias` 1.0, all ganymede, all deterministic:

| far_peak_gain | 0 (Stage 2) | 0.35 (plan's start) | **0.60 (shipped)** | 0.80 |
| --- | --- | --- | --- | --- |
| PEAK LOSS mean | +114.76 | +80.06 | **+55.28** | +35.46 |
| PEAK LOSS worst | +173.89 | +116.64 | **+81.14** | +57.51 |
| PEAK LOSS best | +29.57 | +20.08 | **+13.30** | +7.88 |
| VALLEY GAIN mean | -0.34 | +0.17 | **+0.53** | +0.82 |
| ROUGHNESS | 2.4784 | 2.4910 | **2.5648** | 2.6553 |
| FIZZ max | 22.523 | 21.967 | **21.570** | 22.268 |
| FIZZ rms | 0.395 | 0.474 | **0.607** | 0.736 |

Against the Stage 0 baseline (+60.27 mean, +128.01 worst, ROUGHNESS 4.5894,
FIZZ max 33.322):

- **0.35 is not enough.** +80.06 is still a third worse than the unfiltered far
  field. The plan's starting value was calibrated against an assumed baseline
  near zero.
- **0.60 crosses the line**: +55.28 mean is *better* than the unfiltered
  baseline, and the worst summit improves from +128.01 to **+81.14** - a summit
  that was 64 m short in game is now 41 m short. ROUGHNESS is +3.5% on Stage 2,
  inside the 10% gate, and still **-44%** on the baseline. FIZZ max is the best
  of the whole sweep.
- **0.80 buys more peak for more of everything else** and is left on the table
  for Marcel; the knob is on F4.

**VALLEY GAIN is what stops this being free profit, and it stays negligible.**
The dilation raises valleys by the same mechanism it raises summits, and the
mirror column tracks it: -1.09 blocks at Stage 0, +0.53 at gain 0.60. Half a
block. The reason the trade is so lopsided in the peaks' favour is the world's
own shape - low ground here is flat meadow and lake bed, where a dilation over a
16 m cell has almost nothing to lift.

**FIZZ rms is the one number that gets steadily worse**, 0.395 to 0.607. Same
mechanism as Stage 2's: the max pyramid changes more sharply with level than the
mean does, so the same small level change from walking produces a bigger height
change. FIZZ *max* - the artefact you can see - does not follow it.

### Gates

| gate | result |
| --- | --- |
| PEAK LOSS no worse than Stage 0 | **MET** - +55.28 against +60.27, worst +81.14 against +128.01 |
| PEAK LOSS within the plan's absolute 4 blocks | **NOT MET, and was not met before this epic either** - stated above rather than quietly dropped |
| ROUGHNESS within 10% of Stage 2 | **MET** - +3.5% |
| FIZZ max within 10% of Stage 2 | **MET** - -4.2% |
| FIZZ rms within 10% of Stage 2 | **NOT MET** - +54%. Same mechanism as Stage 2's rms rise |
| far probe determinism | **PASS** at every gain tried |
| heightmap hash | **`76cccdb6`** |
| spawn / trees | **(-44, -124)** / **28,383** |
| self-tests | green |

### The eye, on ganymede

`build/tour/dist-3-gain035`, `dist-3-gain060`, `dist-3-gain080` -
`6-postcard`, `14-postcard-dusk`, `16-spawn-postcard` at each.

At **0.35** the far white spires still carry some of the fine jaggedness the
filter was meant to take off, because the dilation is weak enough to be pulling
single-cell maxima through. At **0.60** the peaks are taller *and* the
silhouettes stay simple - the central dark peak in `6-postcard` gets its point
back without getting its fizz back, which is exactly what "a dilation, not a
sharpen" is supposed to look like. Against `dist-base` the same shot has gone
from crumpled foil to a range with a lit flank and a shaded one.

`16-spawn-postcard` at 0.60 against `dist-base`: the mid-distance ridge that was
a patchwork of olive, brown and grey is one clean band. The meadow in the
foreground is untouched and is now unmistakably the loudest thing in the frame -
which is night 2's Stage 8, and this shot is the argument for it.

---

## Stage 4 - The colour stops aliasing too

**Shipped**, three of the plan's four changes. The fourth was already done.

### 1. No dither and no jitter past the first ring

`surface_zone_at()` hashes a per-column **jitter** and a per-patch **dither** so
that two zones interleave across a boundary. At 0.5 m per block that reads as a
gradient, which is what it is for. At 16 m per quad the same mechanism reads as
**tetris**, and it is the single biggest cause of the camouflage in
`6-postcard`.

Past ring 0 the zone is now decided by **altitude alone**: `zone_at()` with no
jitter and a dither of exactly 0.5, so a cell is promoted the moment its
altitude passes the threshold and never before. Ring 0 keeps the exact sample,
because it touches the voxels at the seam and the treeline has to agree with the
trees that are standing there.

**The slope override is kept.** Snow does not sit on a cliff, and dropping
`_slope_zone` past ring 0 would put white on every far spire. It is
deterministic at `slope_zone_strength` 1.0 - the roll can never exceed 1 - so it
is a function of the ground rather than another hash.

### 2. The zone cell grows with distance

`far_zone_cell_m` was one constant, 24 m, for every ring past the first, so a
mountainside at 600 m was painted in the same fields as one at 200 m - and at
600 m a 24 m field is a couple of pixels. The cell is now
`max(far_zone_cell_m, far_zone_cell_ratio * d)`.

`far_zone_cell_ratio` **0.06**, the plan's value: 36 m fields at 600 m, 200 m
unchanged. On F4; 0 restores the flat constant exactly.

### 3. The colour reads the same surface the vertices came from

The zone sample and `_flank_normal` both took the raw 2 m grid while the quad's
own corners came off the pyramid, so the paint was being sampled from a surface
the geometry no longer had. Both now go through `_filtered()`.

**`far_normal_m` stays at 96 m**, and this is a judgement rather than a
measurement. The plan predicted the 96 m averaging could come down now that the
samples under it are not noise, and photographed both: `dist-4-n96` and
`dist-4-n48`. At **48** the flanks carry visibly more tonal relief - the central
massif reads more three-dimensional - and also a little more per-facet
variation, which is the fault this stage exists to remove. At **96** it is
flatter and more poster-like with the lit and shaded flanks still clearly
separated. Shipped at 96 on the "calm" side of the trade; both shots are on disk
and the knob is on F4, so this is a one-line change if Marcel prefers 48.

### 4. Grain fading with distance: ALREADY DONE, and the plan's premise was wrong

The plan says `grain_amount` "is world-space and constant, so past a few hundred
metres it is sub-pixel noise, which is shimmer", and asks for it to be faded to
zero over the fog's range.

**It already fades, and much more aggressively than the plan proposes.**
`Look.OPAQUE_SHADER`, which the far mesh shares with the chunks
(`ChunkMesher.get_material()` returns `Look.opaque_material()`), carries:

```
// GONE BY 45 m, whatever the fog is doing. Cube World's grain is invisible
// by 30 m; past that it stops being a surface and becomes a shimmer, and
// the far field - which shares this material - must never show it.
float near = 1.0 - smoothstep(20.0, 45.0, length(VERTEX));
v_albedo = mix(v_albedo, grained, near);
```

Look v2 Stage 3 fixed this, named the far field as the reason, and wrote the
reason into the shader. **No change made, and no knob added** - the correct
value of a knob that would fade grain over the fog range is "already zero long
before then". Recorded here because the alternative is a future reader adding
the same fade twice.

### The gate: the probe must not move, and it did not move by a digit

This stage touches colour only. Vertex positions are untouched, and the far
probe reads positions:

| | Stage 3 | **Stage 4** |
| --- | --- | --- |
| FIZZ rms | 0.607 | **0.607** |
| FIZZ max | 21.570 | **21.570** |
| ROUGHNESS | 2.5648 | **2.5648** |
| PEAK LOSS mean / worst | +55.28 / +81.14 | **+55.28 / +81.14** |
| VALLEY GAIN mean | +0.53 | **+0.53** |

**Bit-identical.** The plan's wording is "if FIZZ or PEAK LOSS changes,
something has been wired to the wrong level", and nothing did - including the
`_flank_normal` change, which alters the normal a vertex CARRIES without moving
the vertex.

### The eye, on ganymede - and this is the stage the working GPU bought

`build/tour/dist-4-n96` against `build/tour/dist-base`, `6-postcard`:

- **`dist-base`**: the ranges are a camouflage of small hard-edged patches -
  grey, olive, mauve and tan interleaved across every flank - and the ridges are
  crumpled foil. This is the picture the plan was written from.
- **`dist-4-n96`**: the left range is a clean sequence of green, brown, grey and
  white bands; the central massif is one dark mass with a lit shoulder; the
  treeline is a continuous brown band rather than a dither of forest and rock.
  Three or four large fields, which is what the poster asks for.

`16-spawn-postcard` tells the same story on the mid-distance ridge, which goes
from an olive-and-tan mottle to a single brown treeline band under a green
shoulder.

**And it makes the meadow's problem unmissable.** With the distance calm, the
foreground tufts are now by a wide margin the busiest thing in the frame - which
is exactly the inversion the plan complains about, and exactly what night 2's
Stage 8 is for.

### Cost

Far mesh build **1,169 -> 1,449 ms** on the probe's main-thread measurement
(the probe's two full passes went 57.8 s to 79.5 s). The zone sample and both
flank-normal differences now go through the pyramid instead of one raw lookup.
Vertex count unchanged.

### Streaming, and one number to watch

One run, seed 42, `--view high --strict`:

| | Stage 0 baseline (median of 3) | Stage 2 | **Stage 4** |
| --- | --- | --- | --- |
| hole samples | **0** | **0** | **0** |
| frames over 33 ms | 17 (12-35) | 7 | **21** |
| 48 m settle, out | 9,933 (9,671-10,623) | 9,524 | **10,933** |
| built/s, out | 78.4 (76.5-81.3) | 84.7 | **75.4** |

**Holes 0 - hard rule 4 still holds.** The long-frame count of 21 is inside the
baseline's own 12-35 spread on identical code and says nothing on its own.

**The settle is the number to watch: 10,933 ms is above the whole baseline
range** (9,671-10,623), and unlike the frame count there is a mechanism that
would explain it - the far mesh build has gone 650 -> 1,449 ms across night 1
and it competes with the chunk workers on a pool that runs one GDScript task at
a time. **One run is not evidence of a regression**, which is the whole lesson
of `e63554f`, and this epic does not get to conclude from it either way. It is
named here so that night 2's ABAB interleave - which hard rule 6 owes anyway -
knows to report the settle beside the frame count.

### Gates

| gate | result |
| --- | --- |
| far probe unchanged from Stage 3 | **MET, bit-identical** |
| heightmap hash | **`76cccdb6`** |
| spawn / trees | **(-44, -124)** / **28,383** |
| self-tests | green |
| stream probe holes | **0** |
| 48 m settle | **flagged** - one run above the baseline range, see above |

---

## Stage 5 - Docs, night 1

`STATUS.md` points here. What follows is the summary night 2 and Marcel work
from.

### The probe table, one column per stage

All ganymede, all deterministic, all asserted identical over two runs in the
same session. Heights in **blocks** (1 block = 0.5 m game, 2 m real at 1:4).

| | Stage 0 | Stage 2 | Stage 3 | **Stage 4 (shipped)** |
| --- | --- | --- | --- | --- |
| FIZZ rms, all | 0.373 | 0.395 | 0.607 | **0.607** |
| FIZZ max, all | 33.322 | 22.523 | 21.570 | **21.570** |
| ROUGHNESS, all | 4.5894 | 2.4784 | 2.5648 | **2.5648** |
| PEAK LOSS mean | +60.27 | +114.76 | +55.28 | **+55.28** |
| PEAK LOSS worst | +128.01 | +173.89 | +81.14 | **+81.14** |
| VALLEY GAIN mean | -1.09 | -0.34 | +0.53 | **+0.53** |
| far mesh build | 650 ms | 912 ms | 1,169 ms | **1,449 ms** |
| far mesh vertices | 95,088 | 95,088 | 95,088 | **95,088** |

Per vantage at Stage 4:

| vantage | FIZZ rms | FIZZ max | ROUGHNESS |
| --- | --- | --- | --- |
| spawn | 0.591 | 21.570 | 2.2706 |
| summit | 0.355 | 5.637 | 2.7434 |
| lake | 0.729 | 18.492 | 2.5343 |

### Night 1 against its own headline

**ROUGHNESS is down 44%. The worst re-cut at a ring boundary is down 35%. The
summits are drawn higher than they were before the epic started, by 5 blocks on
the mean and 47 on the worst. The camouflage is gone.** Against `dist-base`
every one of the plan's three faults on the ground is visibly better in the
postcard.

**And FIZZ rms is 63% worse, which is the honest headline beside it.** It is
not a tuning failure; it is what the design costs. Making the mip level
continuous in distance-from-player, which is what stops a mountain re-cutting
itself at a ring boundary, necessarily makes the whole far field breathe a
little as the player walks. Before this epic, the far half of the world was
*bit-identical* between two builds 16 m apart, because 16 m is a multiple of
every ring's step; now it moves by one to three blocks. What that trades away
is a change nobody can see; what it buys is the change everybody could.

### Every starting value, what it is now, and why

| knob | plan's start | shipped | why |
| --- | --- | --- | --- |
| `Heightmap.MAX_LEVEL` | 5 | **5** | unchanged. 64 m per cell at the top |
| `far_level_ref_m` | 100 m | **100 m** | unchanged. Puts each ring at exactly its own step's level at its inner edge |
| `far_filter_bias` | 1.0 | **1.0** | unchanged. Chosen on the pictures: 0 is not calm enough, 2 rounds the summits off, 3 breaks the seam |
| `far_peak_gain` | 0.35 | **0.60** | RAISED. 0.35 leaves PEAK LOSS a third worse than the unfiltered far field; 0.60 puts it better |
| `far_zone_cell_ratio` | 0.06 | **0.06** | unchanged |
| `far_normal_m` | try 48 | **96 (unchanged)** | 48 photographed and rejected on the "calm" side of the trade; Marcel's call, on F4 |
| grain fade to fog | new | **not built** | already faded to nothing by 45 m since look v2 Stage 3 |

All five distance knobs are on F4, all LOCAL and unhashed (hard rule 2).

### For Marcel to rule on

1. **`far_filter_bias`, three ways.** `build/tour/dist-2-bias0`, `dist-2-bias1`,
   `dist-2-bias2` - `6-postcard`, `14-postcard-dusk`, `16-spawn-postcard` at
   each. Shipped at 1.0. All three beat `dist-base`; the question is how far
   past "calm" is too far.
2. **`far_peak_gain`.** `build/tour/dist-3-gain035`, `dist-3-gain060`,
   `dist-3-gain080`. Shipped at 0.60, which is where the drawn summit stops
   being worse than it was before the epic. 0.80 is available and makes the
   peaks sharper still.
3. **`far_normal_m` 96 against 48.** `build/tour/dist-4-n96` and `dist-4-n48`.
   Shipped at 96.

### What night 2 inherits

- **Stage 6's premise is intact.** `FarTreeMeshes.material()` still returns
  `Look.figure_material()`, and the far mesh it sits in front of is now calm -
  which is precisely the "the calm thing sits in front of the fizzy thing"
  inversion the plan warned about, now the other way round. The impostors are
  the loudest wrong thing in `16-spawn-postcard` after the meadow.
- **The 48 m settle wants watching.** 10,933 ms at Stage 4 against a Stage 0
  baseline range of 9,671-10,623, one run each. The far mesh build has more than
  doubled (650 -> 1,449 ms) and shares a pool that runs one GDScript task at a
  time. Stage 7's ABAB interleave should report the settle beside the frame
  count, and hard rule 6 is measured from Stage 0's three-run table above.
- **`far_probe.gd` grew a VALLEY GAIN column** that the plan did not ask for,
  because a dilation that only reports peaks shows a trade as pure profit.

### What night 1 did not do

- **The plan's FIZZ rms gate (a 4x fall) is not met and cannot be met by this
  design.** Recorded in Stage 2 with the per-band table that shows why.
- **The plan's absolute PEAK LOSS gate (4 blocks at 600 m) is not met, and was
  not met before this epic either** - Stage 0 measured 20 of 20 summits outside
  it with no filter at all. Stage 3 was run against a relative gate instead, and
  says so.
- **The 400 m ring boundary is still the loudest thing the probe sees**
  (FIZZ max 21.6 there, against 1-4 blocks everywhere else). It is a third
  smaller than it was, and it is still a boundary. If night 2 or a later pass
  wants it gone rather than reduced, the mechanism is a geomorph - blend the two
  rings' surfaces across the boundary instead of switching - and that is a
  bigger change than a knob.

### Files this lane touched, and one lane decision worth recording

Owned outright, per the plan's file list:

```
scripts/world/heightmap.gd            scripts/world/far_field.gd
scripts/world/far_field_job.gd        scripts/world/worldgen_config.gd
scripts/tools/far_probe.gd  (new)
```

Shared, append-only, and each addition is at the end of an existing list:

- **`scripts/ui/debug_hud.gd`** - five F4 rows appended to
  `LOCAL_TUNING_ROWS`, and one `far mesh ...` line appended at the end of the F3
  readout.
- **`scripts/game/game.gd`** - one `elif "--far-probe"` at the end of the probe
  dispatch chain and one `_start_far_probe()` beside the other probe launchers.

`scripts/character/` was **not touched**, and neither was `look.gd` - night 2's
Stage 6 is the first thing in this epic that needs it.

**One file outside the plan's list:** `scripts/tools/selftest.gd`, for Stage 1's
`heightmap pyramid` test, which the plan's own gate asks for. One entry appended
to the `tests` dictionary and one function appended at the end of the file.
The character lane has its own `selftest_character.gd`, so the collision risk is
nil, but it is recorded here rather than left for a merge to discover.

**And one deliberate reach-around, in `debug_hud.gd`:** the far-mesh readout
gets its numbers from `world.get_node_or_null("FarField")` rather than through a
`World` accessor, because `world.gd` is not on this lane's list. `FarField.stats()`
is in an owned file. If `world.gd` ever gains a `far_field_stats()`, that is the
better call site.

### Gates, Stage 5

| gate | result |
| --- | --- |
| heightmap hash | **`76cccdb6`** |
| spawn | **(-44, -124)** |
| trees | **28,383** |
| self-tests | green |
---

# Night 2 - the forest recedes, and the meadow calms down

Night 2 starts at `364c1b9`, night 1's last commit, on the same branch. The
provenance column at the top of this document still applies, and there is
still no "Tuned blind" section: every tone below was judged against a picture
taken on ganymede through `xvfb-run -a`, on the same `Vulkan 1.4.329 -
Forward+ - RTX 3070 Ti` that night 1 used.

**And the first thing night 2 found is about provenance itself.** Night 1
recorded the far mesh build at **1,449 ms**, single run. Re-measured tonight at
the *same commit*, interleaved against the Stage 6 code three times each, the
same build takes **1,696 ms (1,688-1,709)**. Nothing changed between the two
measurements but the session. That is a **17% drift on a number this project
has repeatedly compared across commits**, and it is the cleanest demonstration
of the rule the provenance column exists to enforce: a `single run` row is a
smoke alarm, and only an `ABAB median` row is evidence.

## Stage 6 - The impostors are not figures

**Shipped**, both halves.

### 1. A tree is scenery. A person is not.

`Look` gains `far_tree_material()`: the same `OPAQUE_SHADER` the terrain uses,
with `fog_dark_mix` **0.0**, the terrain's grain, and `contact_band` **1.0**
(which is "off"). `FarTreeMeshes.material()` returns it.

`figure_material()` is **not touched**, and that is the whole shape of this
stage rather than an afterthought. The character redesign lane
(`feat/character-v2`) is very likely to be editing exactly that function, so
the behaviour change lives at the CALL SITE - in `far_tree_meshes.gd`, which
this lane owns outright - and `look.gd` gains one appended block at the end of
the file: a `static var` and one function. Nothing above line 690 moves.

Two details worth recording because a future reader will otherwise redo them:

- **The contact band had to go, and it is not the same argument as the fog.**
  The band darkens the bottom half of every half-metre cell of a *vertical
  face*. On a voxel wall that is a printed line where a block meets the ground.
  On a six-triangle cone whose sides are all vertical-ish faces spanning
  fifteen metres, it is horizontal stripes across the whole tree.
- **The grain is set to the terrain's value and is unreachable.** It fades out
  entirely by 45 m (look v2 Stage 3, and the shader says so), and the nearest
  impostor in the game stands at the voxel radius - 96 m at High. Setting it is
  a statement about which family this material belongs to, not an effect. Said
  in the comment so nobody measures it and concludes the fade is broken.

### 2. An impostor's colour converges towards its hillside

Today an impostor is shade A of its species, flat, at every range - so a
forest at 600 m is the same green as one at 100 m while the mountain behind it
has drained to a fog-lit grey. The tree's colour is now mixed towards
**the far mesh's own colour at that exact place**, by a factor that is 0 at the
voxel edge and `far_tree_tint` at the fog.

**The ramp is against the FOG, not against the ring's own outer edge.** A tree
at 300 m must be tinted the same amount whatever the ring's radius happens to
be, or Stage 7 - which takes the ring from 400 m to 800 - would silently
retint every tree already on screen and the two stages could not be told
apart in the pictures.

**It reads the FILTERED height, not the true one.** The question the mix
answers is "what colour is the mountain the eye sees behind this tree", and
the mountain the eye sees is the one drawn off the pyramid. Near a summit the
two differ by tens of blocks - that is Stage 0's PEAK LOSS - and a tree that
converged towards the true ground's zone while the far mesh beside it drew a
different one would be a green cone on a grey slope, which is the artefact
this is here to remove.

### The instance colour is a MULTIPLIER, and that is not a detail

The plan says the mix "is computed per instance on the worker, into the
MultiMesh's instance colour, which is already in the buffer and currently
always white - so it costs nothing at all in draw calls or shader work". All
of that is true, and the reason the buffer is full of **white** is the part
that decides the implementation: the renderer MULTIPLIES an instance colour
into the mesh's own vertex colour, and white is the identity.

So "mix this cone half way towards its hillside" cannot be written as a
colour. It is written as **the ratio that lands the cone on the mixture**:

```
instance = to_wire(lerp(species_linear, backdrop_linear, t)) / to_wire(species_linear)
```

The division is in **wire space** (sRGB), because that is where the multiply
happens - after `Look.to_wire()` has been applied to the mesh and before the
shader decodes. The mix itself is in **linear**, which is the project's one
rule about colour arithmetic. A dome's trunk takes the same ratio as its
crown, because there is one instance colour per tree and the mesh carries two;
that is the right approximation, since the ratio means "how far towards the
hillside" and a trunk that recedes with its own crown is better than one that
does not.

**And the multiply was verified rather than assumed.** `far_tree_tint` 0.0 and
0.5 were photographed at the same three vantages: `build/tour/dist-6-tint0`
against `build/tour/dist-6`. All three shots differ. Had the renderer ignored
the instance colour - which is what "white in the buffer" is also consistent
with - the two sets would have been byte-identical and the whole half of this
stage would have shipped as a no-op nobody could see.

### The eye, on ganymede

`build/tour/dist-6` (full 17-shot tour) against `build/tour/dist-4-n96`, which
is night 1's shipped state.

**`16-spawn-postcard`, which is the plan's gate.** At Stage 4 the cones on the
mid-distance ridge at the left are vivid saturated green triangles laid over a
brown treeline band - the "green triangles pasted onto the picture" the plan
describes. At Stage 6 the same cones are a muted olive that sits INSIDE the
band: the ridge reads as a wooded ridge rather than as a ridge with decals on
it. The nearer cones on the right slope, at 150-250 m, are still clearly
green, which is the ramp working - they are close enough to be trees.

**`dist-6-tint0` isolates the two halves.** With the material fixed and the
tint off, the cones are still noticeably green at distance; the material alone
stops them fogging DARK, and the tint is what makes them fog towards the
HILLSIDE. Both are needed and the plan was right that the material is the
larger half of the bug and the smaller half of the fix.

### far_tree_tint, for Marcel to rule on

`build/tour/dist-6-tint0`, `dist-6` (0.5, shipped) and `dist-6-tint10` -
`6-postcard`, `14-postcard-dusk` and `16-spawn-postcard` at each.

| far_tree_tint | 0.0 | **0.5 (shipped)** | 1.0 |
| --- | --- | --- | --- |
| the far cones read as | green triangles on a brown band | muted olive, in the band | brown - the same brown as the band |

**1.0 is too far and says why.** At full convergence the far cones take the
treeline band's own brown and stop reading as trees at all: the wooded ridge
becomes a plain brown ridge. The forest has to still be a forest at 600 m,
which is the entire argument for Stage 7 in the first place. 0.5 is the plan's
number and it is the one that keeps both properties.

### Cost, ABAB, three runs each, interleaved, run order recorded

Far mesh build, from the far probe's own main-thread timing (each run is
itself a mean over 46 builds):

| order | started (UTC) | Stage 5 (A) | Stage 6 (B) |
| --- | --- | --- | --- |
| 1 | 20:43 / 20:46 | 1,688 ms | 1,715 ms |
| 2 | 20:53 / 20:57 | 1,696 ms | 1,712 ms |
| 3 | 21:00 / 21:04 | 1,709 ms | 1,705 ms |
| **median** | | **1,696** (1,688-1,709) | **1,712** (1,705-1,715) |

**+0.9%, and the spreads overlap - the honest answer is "no measurable
difference".** That is the answer this stage wanted, because Stage 6 was not
supposed to touch the far mesh at all.

**It nearly did.** The first cut of this stage routed the far mesh's own
per-vertex height and level through the new shared statics, and the probe
reported **1,727 ms against 1,449** - which looked like a 19% regression and
was the reason the ABAB above was run at all. It is not a regression: the same
commit that produced night 1's 1,449 measures 1,696 tonight. But the inlining
stayed anyway, because it costs nothing to keep and the per-vertex path is
called nine times per quad over twenty-odd thousand quads. `_level_at()` and
`_filtered()` therefore carry the same expression as the statics beside them,
with a comment on both saying so and why.

### Streaming - hard rule 4 holds

One run, seed 42, `--view high --strict`, at the Stage 6 commit:

| | Stage 0 baseline (median of 3) | **Stage 6** (single run) |
| --- | --- | --- |
| hole samples | **0** | **0** |
| frames over 33 ms | 17 (12-35) | **2** |
| worst frame | 43.8 ms | 42.9 ms |
| built/s, out | 78.4 (76.5-81.3) | 76.1 |
| 48 m settle, out | 9,933 (9,671-10,623) | **10,442** |

**Holes 0.** The settle is back inside the Stage 0 range, against the 10,933
night 1 flagged - which on one run each says nothing either way, and is exactly
why the ABAB below exists. `--strict` exits 1 on the pre-existing frame budget
(STATUS.md item 5), unchanged since Stage 0.

**Ring rebuild time, for Stage 7's gate to be measured against:** 40 rebuilds
over that run, **median 501 ms** (273-728).

### Gates

| gate | result |
| --- | --- |
| the tour, `16-spawn-postcard` above all | **MET** - see above |
| far probe unchanged from Stage 4 | **MET, bit-identical** - FIZZ 0.607 / 21.570, ROUGHNESS 2.5648, PEAK LOSS +55.28 / +81.14, VALLEY GAIN +0.53 |
| far probe determinism | **PASS** |
| stream probe holes | **0** |
| heightmap hash | **`76cccdb6`** |
| spawn / trees | **(-44, -124)** / **28,383** |
| self-tests | green |
| `figure_material()` untouched | **yes** - `look.gd`'s diff is one appended block at the end of the file |
| `scripts/character/` untouched | **yes** |

---

## Stage 7 - The ring reaches the fog, and thins as it goes

**Shipped**, and it is the stage where the plan's two halves turned out to
contradict each other. What follows says which half won and what the numbers
were.

`VIEW_PRESETS` now sets `far_tree = fog_end` at every preset: low 200 -> 400,
medium 300 -> 500, **High 400 -> 800**, ultra 500 -> 1000. A wooded ridge is
wooded all the way to where you stop being able to see it.

### The scan is walked in a better order, and that is not a micro-optimisation

Until this stage `FarTreesJob` made ONE pass over the whole bounding square at
stride 1, and the LOD was a parity test inside it (`if (cx & 1) != 0:
continue`). That keeps the *placement decisions* down and does nothing at all
about the *loop*: doubling the radius still quadruples the cells visited. At
High the loop was 160,000 iterations to keep about 12,000 of them.

There is now one pass per band, each stepping at its own stride over its own
square, aligned DOWN to that stride's lattice so the visited set is exactly the
set the parity test used to keep. Same radii, same lattices, same comparisons
in the same order - **the same scan, walked in a better order**.

**Checked rather than believed:** at the `16-spawn-postcard` vantage the parity
version and the strided version both report **722 impostors**, the same number
to the tree.

It is worth about 9% and no more, which is the finding: the loop was never the
cost. `TreePlacement.decide()` on the cells that survive is, and that count is
what the band table has to control.

### The plan's table and the plan's gate cannot both be met, and here is the arithmetic

The plan asks for three bands - all / 1 in 4 / 1 in 16 - and for ring rebuild
time "no worse than **1.25x** Stage 6's". In candidate cells at High, with the
tree lattice at 8 blocks and the voxel radius at 96 m:

| band | radii | kept | cells |
| --- | --- | --- | --- |
| A | 96 - 153.6 m | all | 2,821 |
| B | 153.6 - 400 m | 1 in 4 | 6,696 |
| C (new) | 400 - 800 m | 1 in 16 | 5,890 |

Stage 6 scans A + B = **9,517**. The plan's three bands scan **15,407**, which
is **1.62x** - before a line of it is written. The gate is unreachable by the
design it is attached to, and no arrangement of three bands reaches it: band C
would have to keep 1 cell in 256 to fit inside 1.25x, which is a clump sixty
metres wide.

### The three-band ring was measured, and it failed hard rule 6

ABAB, three runs each, interleaved, run order and wall clock recorded, against
the Stage 6 commit. Ring rebuild is the median of the 40 rebuilds inside each
run; `built/s` is the stream probe's own chunks per second.

| | Stage 6 (A) | three bands (B) |
| --- | --- | --- |
| ring rebuild | **505 ms** (494-511) | **767 ms** (735-797) |
| built/s, out leg | 75.9 (75.8-78.0) | 72.1 (68.5-75.3) |
| built/s, **back leg** | **82.2** (80.5-82.3) | **74.8** (74.8-79.2) |
| frames over 33 ms | 0 (0-1) | 1 (0-1) |
| 48 m settle, out | 10,885 ms | 11,014 ms |
| holes | **0** | **0** |

Ring time **1.52x**, against a gate of 1.25x - close to the arithmetic above.

**The back leg's chunks/s is the finding, and it is what made this a fix rather
than a footnote.** Its spreads do not overlap - every A run is above every B
run - and the back leg shows it first because most of its chunks are cached, so
the ring is a larger share of what the worker pool is doing. 82.2 -> 74.8 is
**-9%**, and hard rule 6 names chunks/s explicitly: *a stage that makes a
failing rule fail harder is not done*.

The frame count did not move and is not the instrument here - it is a threshold
count over a drifting quantity, which is the whole subject of
`stream_probe.gd`'s own note. One of the three-band runs is the first
`--strict` PASS this project has recorded and it means nothing on its own.

### So: a fourth band, and a slower cadence. Both bought by the measurement

**A fourth band, 1 in 64 at 8x width, past 600 m.** The plan asked for three and
the measurement asked for four. 600 m is where the fog is already 87% of the
frame; a clump eight cells wide out there is a shape nobody can resolve, and the
alternative was leaving the last 200 m bald - which is the fault this whole
stage exists to fix.

**And `REBUILD_STEP_M` 16 -> 24 m.** The budget is not the cost of a rebuild, it
is the cost **per metre walked**, and the ring's radius doubled while its
cadence did not. 24 m is three chunks rather than two, so it keeps the
multiple-of-chunk-size property the original number was chosen for.

**What a longer step costs is a longer OVERLAP, never a gap.** The ring's inner
edge is cut at the frontier captured when the job was submitted, so a stale ring
draws impostors where real trees have since landed. World feel v1 Stage 3
settled that trade in as many words: an impostor and a real tree overlapping for
a second is invisible - same species, same place, same height - and a gap is
not. This makes an invisible window 50% longer and cannot make a visible one
appear.

### And an outer fade

`_fade_at` grew a mirrored term, so an impostor shrinks away over the last
`OUTER_FADE_M` instead of the forest ending at a circle.

**48 m, not the plan's 12.** The inner fade covers a handover 96 m from the
player, where 12 m of walking is a visible distance and a longer fade would
leave half-size trees standing beside full-size ones. The outer edge is 800 m
away, where 12 m of radius subtends almost nothing and the entire fade would
happen inside a single fog band - which is to say it would not happen at all.
48 m is still less than one fog band's width out there.

### What shipped, measured the same way

ABAB, three runs each, interleaved, against the Stage 6 commit:

| order | started (UTC) | ring | built/s out | built/s back | settle out | > 33 ms |
| --- | --- | --- | --- | --- | --- | --- |
| A1 | 22:19 | 490 | 78.1 | 84.9 | 10,448 | 0 |
| B1 | 22:22 | 565 | 85.1 | 95.9 | 9,466 | 0 |
| A2 | 22:25 | 485 | 79.2 | 85.7 | 10,371 | 1 |
| B2 | 22:28 | 568 | 85.0 | 91.1 | 9,606 | 0 |
| A3 | 22:31 | 468 | 81.3 | 88.4 | 9,854 | 0 |
| B3 | 22:35 | 570 | 83.2 | 95.3 | 9,669 | 1 |

| | Stage 6 (A) | **Stage 7 (B)** | |
| --- | --- | --- | --- |
| ring rebuild | 485 ms (468-490) | **568 ms** (565-570) | **1.17x - gate MET** |
| impostors drawn | 496 (406-692) | **665** (580-827) | +34% trees over 4x the area |
| built/s, out | 79.2 (78.1-81.3) | **85.0** (83.2-85.1) | +7.3%, spreads do not overlap |
| built/s, back | 85.7 (84.9-88.4) | **95.3** (91.1-95.9) | +11.2%, spreads do not overlap |
| 48 m settle, out | 10,371 (9,854-10,448) | **9,606** (9,466-9,669) | -7.4%, spreads do not overlap |
| frames over 33 ms | 0 (0-1) | 0 (0-1) | no change |
| holes | **0** | **0** | hard rule 4 |
| frontier min, out | 40.0 m | **48.0 m** | the streamer is further ahead |

**The ring is twice as wide and streaming is measurably faster than it was
before the stage.** The cadence change more than paid for the bigger ring, and
it did it on the number that matters: work per metre walked went 505/16 = 31.6
ms/m to 568/24 = 23.7.

**And the A column moved between the two ABABs**, which is worth naming: the
same Stage 6 commit measured ring 505 / 79.2 built-out at 21:54 and ring 485 /
79.2 at 22:19. That is why both tables are interleaved and why neither is
compared against the other's B.

### The eye, on ganymede

`build/tour/dist-7` (full 17-shot tour) against `build/tour/dist-6`.

**`5-lake` is the shot.** At Stage 6 the far shore and every ridge past 400 m
are bare - fogged terrain with nothing on it, which the far mesh paints
forest-green and which reads as a mown slope. At Stage 7 there is a treeline
along the far shore and across the mid-distance ridges, receding into the fog
rather than stopping. This is the plan's own night-2 acceptance line - *"a
wooded ridge at 500 m is wooded"* - and it is the shot that shows it.

`1-spawn` shows the same on the far treeline. `16-spawn-postcard` barely moves,
because every ridge it can see is inside 400 m and was already wooded - which is
worth recording, since it is this epic's gate shot and it is NOT where this
stage lives.

### Gates

| gate | result |
| --- | --- |
| ring rebuild within 1.25x of Stage 6 | **MET at 1.17x** - and NOT met at 1.52x by the plan's own three-band table, which is why there are four |
| measured ABAB, three runs each, median with spread, run order recorded | **yes**, twice |
| stream probe holes | **0** |
| stream probe `--strict` exit | **1** on two of three runs, on the pre-existing frame budget only (STATUS.md item 5) |
| long-frame count no worse | **MET** - 0 (0-1) against 0 (0-1) |
| chunks/s no worse | **MET, and better** - +7.3% out, +11.2% back, no overlap |
| heightmap hash | **`76cccdb6`** |
| spawn / trees | **(-44, -124)** / **28,383** |
| config hash | `3d45b8fc` (unchanged - `far_tree_m` is LOCAL) |
| self-tests | green |

---

## Stage 8 - The meadow stops being gravel

**This is the bail-out, and it is taken with a measurement rather than with a
shrug.** No colour and no density constant is changed. What follows is what was
tried, what it looked like, and the arithmetic that says why the first of the
plan's two candidates cannot work at all.

### Candidate 1 - contrast. It is not a constant, and here is the proof

The plan's argument: *"The tuft colour is far darker in value than the ground it
stands on. Bring it toward the ground's value and let hue carry the difference -
the same argument look v2 Stage 2 made about the far-field bands, one scale
down."*

The premise is right. `C_GRASS_BLADE` is `#4E6E30`, luma **0.130**; the meadow
block it stands on is `#809945`, luma **0.278**. The tuft's base is at 47% of
the ground's value.

**But the two are not in the same lighting band, and that is what breaks the
analogy.** A meadow block presents its TOP face to the camera, which points at
the sun and lands in the ramp's lit band. A grass blade is a one-voxel column
whose visible faces are VERTICAL, so the ones facing away from the sun land in
the shade band - and the shade band is `mix(albedo, luma, 0.55) * shade_ink`,
which throws away 55% of the hue and then multiplies by a grey-violet.

Run through `Look`'s own ramp at noon (`shade_desat` 0.55, shade `#7A7396`,
sun `#FFF2D1`):

| | drawn LIT | drawn SHADED |
| --- | --- | --- |
| meadow ground `#809945` | **`#809137`** | `#3E4042` |
| blade base `#4E6E30`, as shipped | `#4E6825` | **`#272B2D`** |
| blade base x1.75 | `#668733` | `#353A3C` |
| blade base x3.00 | `#83AD43` | `#464C4F` |
| blade tip `#9BB65A` | `#9BAD48` | `#4C4D51` |

**The meadow is `#809137` and the blade face beside it is `#272B2D`.** That is
the gravel, and it is a *lighting-band* gap, not a colour gap. Tripling the
blade's albedo - which overshoots the ground on the lit face and is therefore
already wrong - moves the shaded face only as far as `#464C4F`. There is no
value of a colour constant that closes it, and hue cannot carry the difference
because the shade band has already removed most of the hue.

**Photographed anyway, because arithmetic about a renderer is a hypothesis.**
Three variants at `16-spawn-postcard`, all on ganymede:

| variant | what changed | result |
| --- | --- | --- |
| `build/tour/dist-8-v14` | base x1.40, `#5C8139` | indistinguishable from `dist-7` |
| `build/tour/dist-8-v175` | base x1.75, `#678F41` | indistinguishable from `dist-7` |
| `build/tour/dist-8-narrow2` | base x1.80 AND tip x0.75, narrowing the tuft's own internal spread | indistinguishable from `dist-7` |

### How the culprit was identified, since three colour changes doing nothing is not a diagnosis

The speckle was traced by painting palette entries debug colours and shooting
the same vantage - `build/tour/dbg-red` (blade base red), `dbg-4` (base red,
stem blue, alpine turf magenta, boulder cyan) and `dbg-tip` (blade tip green).

The answer: **the speckle is the grass tufts, and it is their vertical faces.**
`dbg-red` turns most of it red, so it is the blade base; `dbg-tip` shows the
tip's lit top faces as thin bright slivers on top of blobs that stay grey. A
one-voxel-wide blade shows one sunward face and one shaded face at 6 cm; at 80 m
that pair is sub-pixel, and it averages towards the dark one because the shaded
face is much darker than the lit face is bright.

### Candidate 2 - density with range. The knobs that exist do not reach it

The plan's second candidate: *"They are drawn to `flora_far_m` at a constant
rate, so the number per screen pixel rises with distance until it is speckle.
Thin them with range."*

The mechanism already exists as two LOCAL knobs - full density inside
`flora_radius_m` (64 m), `flora_far_fraction` (0.25) out to `flora_far_m`
(128 m), nothing beyond. Turned to 32 m / 0.15: `build/tour/dist-8-range`, and
it is **barely distinguishable from `dist-7`**. The speckle in the postcard is
dominated by the band that is already inside the full-density circle, and
pulling that circle in only moves the step somewhere the eye can find it.

A ramp that actually thinned with range - a fraction that falls continuously
rather than in one step - lives in `World._flora_fraction_for()`. **`world.gd`
is not on this lane's file list**, and rewriting another lane's streaming
fraction to fix the grass is exactly the reach the plan's lane section forbids.

### What DOES work, and why it is not shipped as a default

`flora_draw_fraction` 1.0 -> 0.55: `build/tour/dist-8-draw55`, and it is a clear
improvement. The dots are the same grey, but there is enough green between them
that the field reads as a meadow with grass in it rather than as a gravel bed.

**It is not shipped, because it is the wrong knob wearing the right result.**
`flora_draw_fraction` is the per-machine QUALITY dial - "an instance is drawn
only if its hash falls below this", the thing a laptop turns down and Marcel
turns up. Shipping 0.55 as its default means the game arrives with its quality
slider at 55% and "turn it up" no longer means "back to normal". It is also
distance-independent, so it thins the grass at the player's feet exactly as hard
as the grass at 100 m - which is the opposite of what the diagnosis asks for.

**It is on F4 as `flora drawn`,** and the picture is on disk. If Marcel wants
the postcard tonight, that is the one line.

### So: stopped, per the plan's own instruction

> *"If it needs real work - a new decoration LOD, a different tuft model - stop,
> write up what was found, and leave it for a look pass. This epic is about
> distance and must not become about grass."*

It needs real work, and the write-up names which:

1. **A decoration LOD.** Past some distance a tuft stops being four blades and
   becomes one flat, upward-facing patch - lit rather than shaded, and one
   quad instead of twenty. That fixes the cause (vertical faces in the shade
   band at sub-pixel size) rather than the symptom, and it would take triangles
   off the near field at the same time.
2. **A tuft model with more upward-facing surface**, so a blade is not a
   one-voxel column whose visible area is almost entirely vertical.
3. **A look-pass decision about `shade_desat`.** 0.55 at noon is what turns
   every shaded surface in the game into a variant of one grey-violet. That is
   the poster's whole idea and this epic is not the place to argue with it -
   but it IS the mechanism, and a look pass that ever revisits it should know
   that the meadow speckle is downstream of it.

### Gates

| gate | result |
| --- | --- |
| the meadow at your feet is grass, not gravel | **NOT MET, and the status doc says why** - which is the plan's own alternative for this line |
| if it is a constant, turn it and photograph it | **it is not a constant** - photographed at three contrast values and two density settings, all on disk |
| this epic does not become about grass | **held** - no flora file is changed, nothing outside the lane is touched |
| heightmap hash / spawn / trees | **unchanged - nothing was shipped** |
