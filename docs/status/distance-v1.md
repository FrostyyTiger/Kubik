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

### Gates

| gate | result |
| --- | --- |
| heightmap hash | **`76cccdb6`** |
| spawn | **(-44, -124)** |
| trees | **28,383** |
| config hash | `3d45b8fc` |
| self-tests | green |
| far probe determinism | PASS |

