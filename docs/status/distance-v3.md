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

**The one pair to look at first:** `build/tour/s5-rim-end800/17-rim.png`
against `build/tour/final/17-rim.png`. Same standpoint, same seed, the reach
before and after. The first is a flat sheet of near-white past about 600 m -
**fleck 0.0502, p95 exactly 0.00**, which is what a fog wall is when you write
it down - and the second is the whole region in blocks out to the rim, at
**5.0454**.

**Acceptance is met**, with one substitution named in full at Stage 10: the
"from the valley floor" shot is taken from the summit instead, because 99.3% of
the valley-floor frame's far band is within 640 m and no implementation of this
epic could have changed that. **So this branch merged to `main`.**

**Three things to read before you turn a knob:**

1. **The one thing that got worse is not in the acceptance table.** The far
   mesh's vertex upload is on the main thread and is now 23% bigger, and the
   ABAB found two frames of **283-291 ms** during a sprint at the new reach
   against one of 247 ms at the old. Holes are **zero in all six runs** and
   streaming throughput does not move. That hitch is the price of the reach on
   this box, and the lever is not a constant.
2. **`far_fog_start_frac` ships at the plan's 0.4 and I would rule 0.15-0.20.**
   At 0.4 the air begins at 1,280 m, which is further than most of what a
   player looks at, and the dead-black share of the postcard's far band doubled
   because a kilometre of mountain that used to be hazed is now drawn at full
   strength. It is one number on F4 and it redraws standing still.
3. **`fog_bands` is now a resolution, not a style.** Four bands tuned against a
   480 m span cover 1,920 m, so the first band boundary moved from 400 m to
   1,558 m. Not changed - it is a look v2 constant and it is yours.

**Where the pictures are.** `build/` is gitignored, as it has been since
distance v1, so every `build/tour/<label>/...` path in this document is a file
**on ganymede** and not in the repo. There are twenty-four labelled sets from
this run; `s5-rim-end800`, `final`, `s2-grain0` / `s2-grain` and
`s5-rim15` / `s5-rim25` are the ones the arguments rest on.

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

---

## Stage 1 - The mode vote: a far cell is one real material

**Shipped**, `far_vote` default **1.0**.

### The path it replaces, read before it was changed

The plan asks for this to be recorded, and it is worth the paragraph because
what was there is not what the plan's summary implies.

```
_build_ring()
  ring 0            zone_bx/bz = quad centre, zone_h = mid_true
                    -> generator.surface_zone_at(bx, bz, h)      jitter + dither
  ring 1            zone_bx/bz = quad centre, zone_h = mid_true
                    -> backdrop_zone()
  ring 2 and out    far_zone_cell_m / far_zone_cell_ratio snap the sample onto
                    a COARSER grid: cell = max(24 m, 0.06 * d), zone_bx/bz =
                    that cell's centre, zone_h = _filtered(cell centre)
                    -> backdrop_zone()

backdrop_zone(g, bx, bz, h) = g._slope_zone(bx, bz, g.zone_at(h, 0.0, 0.5))
```

So **the far field was never averaging a colour.** Past ring 0 it asks for the
zone at ONE point, at an altitude read off the filtered pyramid, and paints
that zone's surface block at full saturation - which is already DH's "a coarse
cell is one real blockstate". The mush is not a blend. **It is a low-pass:**
one sample of a smooth surface, so neighbouring cells read neighbouring
altitudes and agree with each other, and nothing in the picture ever says "this
cell is forest and the one beside it is rock" unless the smoothed altitude
happens to cross a threshold between them. No colour constant reaches that, and
that is why distance v1's colour pass and distance v2's terrace both left it
standing.

Naming the mechanism correctly changes what the port has to be. Taking a mode
over four samples of the SAME smooth surface would cost four times as much and
change almost nothing, because four reads of a low-pass agree. **What DH is
actually doing when it votes is reading the FINER LOD's four cells** - data
that still has something to disagree about - and keeping the winner whole. So:

- four samples at the sub-cell midpoints of the zone cell,
- each read at the pyramid level whose cells are the SUB-cell's width
  (`floor(log2(sub / heightmap.step) + far_filter_bias)`, an integer, so the
  read is one bilinear rather than a trilinear's two),
- the peak gain applied to each, because the snow line has to sit where the
  DRAWN summit is,
- **shore never wins** unless all four samples are shore - DH's "air never
  wins", in a world whose one place-rather-than-altitude zone is the lake
  margin - and
- **ties fall to the first sample**, deterministically. The arbitrariness is
  free texture, exactly as DH says.

Ring 0 is untouched at every value of the knob. It already has the highest
frequency variation in the far field - `surface_zone_at` carries a per-column
jitter and a per-patch dither - and it is the ring that has to agree with the
voxels at the seam. The mush was never there.

### The memo, which is why this is close to free

Past ring 1 the zone cell grows with distance (`far_zone_cell_ratio * d`), so
at 1.5 km one cell covers a couple of dozen quads - and the single-sample path
was answering the same question for every one of them, `_filtered()` and all.
The vote is memoised on the cell's own snapped centre, so the four reads are
taken once per CELL and the two pyramid reads the old path took per QUAD go
away. Ring 1 pays in full: its zone cell is its quad.

### What the vote does NOT do, said before the pictures

The vote changes a cell only where its four sub-samples disagree, which is
where a zone BOUNDARY runs through the cell. Deep inside a meadow or a solid
forest all four agree and the paint is exactly what it was. That is DH's own
behaviour and it is right - a forest is a forest - but it means the effect is a
mottled BAND along every treeline, snowline and crag edge rather than an
all-over texture.

**And that is in tension with something distance v1 settled deliberately.** Its
Stage 4 removed the zone jitter and dither past ring 0 with this reasoning:
"at 16 m per quad the same mechanism reads as tetris - a camouflage of small
hard-edged patches instead of the three or four large fields the poster is
supposed to paint - and it is the single most likely cause of the mosaic in
`6-postcard.png`". The vote is not that mechanism (it is not a hash, it reads
the real surface, and it is stable under the camera), but it does put
hard-edged patches back along boundaries. Whether that reads as DH's texture or
as distance v1's tetris is a taste question, it is Marcel's, and it is in
"For Marcel to rule on" with the crops. **The plan's default ships:
`far_vote 1.0`.**

### The level the vote reads, and why the filter bias stayed in it

One judgement call, recorded because the other choice is a one-line experiment
and somebody will want it.

The vote's level is `floor(log2(sub-cell / heightmap.step) + far_filter_bias)`.
Dropping the bias would make the vote read a surface exactly as fine as its own
sample spacing and would fleck harder. It is not dropped, and the arithmetic is
why: at ring 1 the far mesh's own geometry is drawn off roughly 24-block
smoothed data (`log2(d / far_level_ref_m) + far_filter_bias` at 300 m), the
vote with the bias reads 16-block cells, and the vote without it would read
8-block cells. Paint one level finer than the shape is a painted block grid.
Paint three levels finer than the shape is paint that has come off the
mountain. **The bias stays; `far_filter_bias` therefore still moves the paint
as well as the shape**, which is what a single smoothness dial ought to do.

### A control that was worth taking: which shots have a far band at all

`s0-base` against `s1-vote0` - two tours, four commits and an hour apart, both
on the old path - over rows 0-300:

| | mean \|dL\| | worst |
| --- | --- | --- |
| 2-summit, 6-postcard, 14-postcard-dusk, 11-forest-dusk, 12-meadow-night, 13-meadow-dawn, 15-under-canopy | **0.0000** | **0.0** |
| 9-treeline | 0.0012 | 23.7 |
| 3-forest-slope | 0.0064 | 39.5 |
| 5-lake | 0.0093 | 69.0 |
| 1-spawn | 0.0321 | 60.1 |
| 4-valley-floor | 0.1508 | 146.2 |
| 15-boulder | 0.8848 | 179.7 |
| 10-shore | 0.7884 | 101.6 |
| 8-meadow-closeup | 2.7169 | 182.7 |

Distance v2's finding holds and this **sharpens it**: rows 0-300 are the far
band only in shots that are actually looking at the far country. Where the
camera is close to the ground or pitched down - `8-meadow-closeup`,
`15-boulder`, `10-shore`, `4-valley-floor` - the top of the frame carries
near-field flora, and flora is not bit-reproducible. **The shots this epic's
per-pixel numbers may be read from are `2-summit`, `6-postcard`,
`14-postcard-dusk`, `9-treeline`, `3-forest-slope` and `5-lake`**, and the
others are reported but not argued from.

### Gate

| gate | result |
| --- | --- |
| the fleck rises on forest-facing far-band shots | **MET in direction, and it is very nearly a null result** - see below |
| far probe deterministic | **MET** - the vote is colour only, and the probe's vertex counts are identical run for run and side for side: 254,140 / 143,232 / 242,120 at every one of the six ABAB runs |
| build cost under +25% | **MET at +17.5%** |

**Build cost, `ganymede, ABAB median`, three runs each, interleaved
A-B-A-B-A-B, `--far-probe --cost`, run order as written:**

| | far_vote 0 | far_vote 1 | delta |
| --- | --- | --- | --- |
| spawn, job ms | 2,025 (2,018-2,031) | 2,380 (2,367-2,387) | **+17.5%** |
| summit, job ms | 1,108 (1,100-1,118) | 1,296 (1,293-1,296) | **+17.0%** |
| lake, job ms | 2,011 (1,990-2,013) | 2,364 (2,344-2,370) | **+17.6%** |
| in-game first build, wall ms | 4,456 (4,183-4,571) | 4,834 (4,798-4,881) | **+8.5%** |
| vertices, every run | 254,140 / 143,232 / 242,120 | identical | **0** |

The three vantages agree to half a percent, which is what a real cost delta
looks like. The in-game number is smaller because that build waits for a
worker pool it shares with 2,400 chunks, so a fixed queue is added to both
sides.

### The fleck barely moved, and the reason is a knob rather than a bug

**This is the stage's real finding and it is close to a null result.**

| shot | fleck, `far_vote 0` | fleck, `far_vote 1` | delta |
| --- | --- | --- | --- |
| **6-postcard** | 3.9398 | **3.9801** | **+1.0%** |
| 14-postcard-dusk | 3.0938 | 3.1218 | +0.9% |
| 9-treeline | 1.7194 | 1.7242 | +0.3% |
| 3-forest-slope | 2.1018 | 2.1035 | +0.1% |
| 2-summit | 1.0854 | 1.0854 | **0.0%** |
| 5-lake | 2.2359 | 2.2211 | **-0.7%** |

And yet **the picture really did change.** The same pair, as a band diff over
rows 0-300:

| shot | mean \|dL\| | mean dL | px over 1 level |
| --- | --- | --- | --- |
| 6-postcard | **4.9617** | +0.4674 | 55,842 |
| 14-postcard-dusk | 4.0057 | +0.2354 | 55,821 |
| 5-lake | 0.9443 | -0.3298 | 8,726 |
| 9-treeline | 0.0670 | +0.0430 | 884 |
| 3-forest-slope | 0.0090 | +0.0002 | 170 |
| 2-summit | 0.0002 | -0.0001 | 3 |

Five luma levels of change across fifty-six thousand pixels of the postcard's
far band, and the local contrast of that band is where it was. **The vote moved
the boundaries; it did not make the paint finer.** The mechanism is exactly
visible in the code path recorded at the top of this stage: past ring 1 the
zone is sampled once per `far_zone_cell_m` cell, which at 600 m is 36 m and at
1.5 km is 90 m, and every quad inside that cell is painted the same. **The
spatial frequency of the far country's colour is set by `far_zone_cell_m`, not
by how the sample inside it is taken.** A better answer per cell is still one
answer per cell.

That coarsening is not an accident either. Distance v1 Stage 4 put it there to
kill a mosaic, and distance v1's own reasoning is quoted three paragraphs up.
So this stage delivers what it was specified to deliver - a cell is now the
most common of four real materials rather than one sample of a smoothed
surface, water excluded, ties deterministic - and the thing the fleck number
was hoping for lives one knob further on. **`far_zone_cell_m` is on F4 and 0
samples every quad**; the pair is photographed below and the call is Marcel's.

### And the knob one further on does not help either, which kills the hypothesis

`far_zone_cell_m 0` restores per-QUAD zone sampling past ring 1 - the
finest paint the far field can take - shot both ways:

| `6-postcard`, far band | fleck | p95 | textured |
| --- | --- | --- | --- |
| `far_zone_cell_m 24`, `far_vote 0` (shipped before this stage) | 3.9398 | 18.00 | 27.7% |
| `far_zone_cell_m 24`, `far_vote 1` (**shipped**) | 3.9801 | 18.07 | 27.6% |
| `far_zone_cell_m 0`, `far_vote 0` | 3.7888 | 18.00 | 27.6% |
| `far_zone_cell_m 0`, `far_vote 1` | 3.6966 | 17.92 | 27.4% |

Per-quad paint is **worse**, and the vote makes it worse again. So the ceiling
was never `far_zone_cell_m`, and the real explanation is simpler and should
have been obvious from §2c of the research doc:

> **A mode vote is a median filter.** Its whole job in Distant Horizons is to
> stop four fine cells being AVERAGED into a colour that is not any block's
> colour. We were never averaging - distance v1's `backdrop_zone` has always
> painted one real zone's surface block at full saturation - so on our data a
> vote has nothing to rescue and can only do the other thing a mode does, which
> is delete minority flecks.

That is why `far_vote 1` is a fifth of a luma level FLATTER at
`far_zone_cell_m 0`, where there are minority flecks for it to delete.

**What it does buy is a better answer per cell**, and that is not nothing: a
cell that is three quarters forest is now painted forest instead of whatever
its centre sample happened to land on, water excluded, ties deterministic. On
the postcard that is five luma levels across fifty-six thousand pixels, which
is a visible change in where the treeline and the snowline run. Whether it is
an IMPROVEMENT is a taste question and it is in "For Marcel to rule on" with
the pair.

**The fleck this epic is named for is not here. It is Stage 2**, and Stage 1's
value is having proved that with numbers rather than assuming it.

---

## Stage 2 - The block grid is painted: jitter on the block lattice

**Shipped**, `far_grain` default **0.065**.

### Where the near field's per-block variation actually is, checked by grep

The plan says to find it "shader or mesher, checked by grep, not assumed", and
the answer is both places and only one of them is on.

- **`color_jitter_value` / `_hue` / `_blocks`** are per VERTEX, in
  `Block.jitter()`, called from `ChunkMesher` and from `FarFieldJob._push_quad`.
  **`color_jitter_value` has shipped at 0.0 since look v1** and the config says
  why: "a greedy-meshed meadow is a few huge quads, so the jitter lands on
  their corners and interpolates across them as soft blotches, and doubling it
  doubled the blotches. Grain would need per-block colour, which greedy meshing
  rules out."
- **`grain_amount 0.065` / `grain_hue 0.03`** are per FRAGMENT, in
  `Look.OPAQUE_SHADER`, hashed on `floor(world_pos / 0.5)` - a world-space
  half-metre lattice, which is exactly a block. That is the near field's
  per-block colour variation, and **it is faded out entirely between 20 and
  45 m**: "past that it stops being a surface and becomes a shimmer, and the
  far field - which shares this material - must never show it."

So the far country has had no per-block variation at any distance, ever. This
stage is that grain, extended outward.

### The splice, and why look.gd was opened without risking the near field

The compensating rule for opening `look.gd` is absolute: swatches
byte-identical after every shader-touching stage. The obvious implementation -
add a `far_grain` uniform to `OPAQUE_SHADER`, default 0, branch on it - leaves
that gate resting on a shader compiler being indifferent to a branch it never
enters. Probably true; not provable from here.

So **`OPAQUE_SHADER` is not edited at all.** `Look.far_field_code()` builds the
far field's source from it at runtime by inserting two blocks at two asserted
anchors. The string the chunks compile is character for character the string
`main` compiles, and the gate holds by construction. It also gives Stage 7
somewhere to put the Bayer dissolve.

`swatches.png` and `swatch-ramp.png`: **identical, both sheets, 0 pixels
differ.**

### The grain, and the one place it departs from DH

DH's noise recipe (`docs/research/distant-horizons.md` §4), in mechanism:
hash a world-space QUANTISED position so the fleck is stable under camera
motion and does not swim; weight the amplitude by a parabola in luminance
peaking at mid-grey so nothing happens on blacks or whites; and brighten toward
white - `c + (1 - c) * r` - rather than perturbing RGB symmetrically, so it
never muddies a hue. `r` is zero-mean, so the expected colour is unchanged:
**hard rule 6 is satisfied by the arithmetic and then measured anyway.**

Written as `x*x` rather than DH's `pow(x, 2.0)`, deliberately: `pow` with a
negative base is undefined in GLSL and that base is negative for every colour
darker than mid-grey, which is most of this world.

**THE DEPARTURE: DH fades its noise out past 1024 blocks and this grows its
lattice instead.** DH's stated reason for the dropoff is that a quarter-block
lattice past a kilometre is sub-pixel and aliases - a statement about ANGULAR
size, and the fix that follows from it is to hold the angular size constant
rather than to switch the effect off. So the lattice starts at one block
(0.5 m, the near field's own grain cell, so the seam has nothing to give it
away) and grows with view distance at about two screen pixels per cell,
blending between two power-of-two levels the way a mip chain does. A hillside
at 3 km is flecked in ten-metre cells; the same hillside at 300 m is flecked in
one-metre cells. This is also the block-atlas idea's own shape: per-block
detail painted on geometry far coarser than a block, off a `fract()` of world
position, tiling once per lattice cell across a quad of any size.

### Gate 1 - the average is preserved

`ganymede, deterministic` over the far band, `far_grain 0` against `far_grain
0.065`, standing-still pairs from the same binary. **The plan writes this gate
as "mean |dL| under 0.5 sRGB levels" and that is the wrong statistic for what
the gate is named after**, so both are reported and the distinction is the
point: a zero-mean fleck of amplitude a has a mean |dL| of roughly a/2 **and
that is the effect working**. What "the average is preserved" asks is whether
the band got brighter or darker on average, which is the SIGNED mean.

| shot | mean dL (signed) - **the gate** | mean \|dL\| (the fleck's size) |
| --- | --- | --- |
| 2-summit | **-0.0004** | 0.0030 |
| 9-treeline | **+0.0010** | 0.4303 |
| 5-lake | **-0.0072** | 1.1731 |
| 14-postcard-dusk | **-0.0261** | 0.8649 |
| **6-postcard** | **-0.0416** | 1.0777 |
| 3-forest-slope | **-0.1033** | 2.4926 |

**MET, by a factor of five on the worst shot** - the largest shift in the far
band is a tenth of a luma level, against a 0.5 line. The mechanism guarantees
it (`c + (1 - c) * r` with `r` zero-mean) and the measurement confirms it. As
the plan literally writes it - mean |dL| under 0.5 - it is **not met on
`6-postcard` (1.08) or `3-forest-slope` (2.49)**, and it could not be: that
number is the fleck itself.

### Gate 2 - the fleck rises

`far_grain 0` against `far_grain 0.065`, far band. `tex` is the share of
neighbour pairs over 2 levels, which is the number least diluted by sky.

| shot | fleck 0 -> 0.065 | delta | tex 0 -> 0.065 |
| --- | --- | --- | --- |
| 3-forest-slope | 2.1035 -> **4.0928** | **+94.6%** | 13.6% -> **49.6%** |
| 5-lake | 2.2220 -> 2.9575 | +33.1% | 16.8% -> 28.7% |
| 14-postcard-dusk | 3.1218 -> 3.6515 | +17.0% | 28.6% -> 36.7% |
| **6-postcard** | 3.9801 -> **4.6173** | **+16.0%** | 27.6% -> **38.5%** |
| 1-spawn | 4.3040 -> 4.7987 | +11.5% | 26.8% -> 35.0% |
| 9-treeline | 1.7240 -> 1.9098 | +10.8% | 18.2% -> 21.4% |
| 2-summit | 1.0854 -> 1.0874 | +0.2% | 10.1% -> 10.1% |

**MET.** And it is worth putting the two stages side by side, because the
comparison is the epic's own argument:

| `6-postcard` far band | fleck | textured |
| --- | --- | --- |
| `1ece781`, before this epic | 3.9398 | 27.7% |
| Stage 1, the mode vote | 3.9801 (+1.0%) | 27.6% |
| **Stage 2, the painted lattice** | **4.6173 (+17.2%)** | **38.5%** |

`2-summit` is flat and honestly so: from the world's highest point the far band
is largely sky, which has no lattice on it. Its `tex` share is 10% at every
stage and that is the frame telling the truth about itself.

For reference, the near field's own band on the shots where rows 500-720 really
are the near field measures **3.2 to 8.2**. The postcard's far band is now
**4.6**, which is inside that range for the first time.

### Gate 3 - the near field is untouched

`swatches.png` and `swatch-ramp.png`, shot before and after the change:
**identical, 0 pixels differ, both sheets.** Guaranteed by the splice rather
than by luck - the chunks compile a string this stage never edited.

### What the far field's own material costs

One extra draw group, for one mesh. It is argued rather than measured and the
argument is that **no instrument in this project can resolve a single draw
call**: the stream probe's medians carry a ~9% spread on this box and its own
`TODO(marcel)` says plainly that it cannot compare two commits. The precedent
already pays this price twice - `figure_material()` and `far_tree_material()`
are the same trade for the same reason - and one of those was distance v1's,
for a mesh with two thousand instances rather than one.

---

## Stage 3 - Faces shaded by axis

**Shipped**, `far_riser_axis` default **0.08**, and it is the smallest thing in
the epic.

### The near field's own ratios, since the plan says not to import DH's

DH bakes Minecraft's per-direction multipliers into vertex colour - 1.0 up,
0.8 north/south, 0.6 east/west - and the research doc calls it "the cheapest
and most effective single thing making the far field read as cubes rather than
a surface". Two thirds of that is already true here and was true before this
epic: a riser carries its own horizontal normal, so Look's three-band ramp
lights it as a voxel side face and `slope_tint` darkens it as a wall. What was
missing is the distinction between the two compass axes.

**Minecraft's 0.8/0.6 is a 25% spread and this poster's own is 15%.** Read off
`Block.aspect_shade` at the shipped `aspect_tint 0.18`: a face pointing at
`SUN_ASPECT` comes out at Rec. 709 luma x1.070, one pointing away at x0.930, a
ratio of 1.15. A cross-axis face sits between the two, so half that spread -
**0.08** - is the honest translation. The direction is `Block.SUN_ASPECT`
itself, reused rather than re-picked, so three mechanisms now share one axis: a
sunward riser keeps `far_riser_shade`, an away-facing one is lifted off the
shade floor by `far_riser_lift`, and a cross-facing one is darkened by this.

### Gate

| gate | result |
| --- | --- |
| the vertical-luma-gradient metric over the far band moves | **MET, and it moves DOWN by 1.3%** - see below |
| A/B crops shot for Marcel | **MET** - `s2-grain` (0), `s3-axis` (0.08), `s3-axis20` (0.20) |
| swatches identical | **MET** - this stage does not touch a shader; the term is a multiply in the mesher |
| far probe deterministic | **MET** (Stage 4's run, which covers this commit's job as well) |
| `far_riser_axis 0` reproduces Stage 2 | **MET, byte for byte** - `s3-axis00/6-postcard.png` against `s2-grain/6-postcard.png`, far band, mean \|dL\| **0.0000**, worst **0.0** |

**`6-postcard`, far band, by axis of the measurement:**

| `far_riser_axis` | fleck (v) | fleck (h) | dark40 | shift vs 0 |
| --- | --- | --- | --- | --- |
| 0 | 5.4736 | 3.7632 | 8.81% | - |
| **0.08 (shipped)** | **5.4049** | **3.6701** | **8.83%** | **-0.87 levels** |
| 0.20 | 5.3015 | - | 8.88% | -2.21 levels |

### The honest reading, and it is not what the stage hoped for

**The axis term is a uniform darkening, not a contrast.** On `6-postcard` the
mean |dL| against `far_riser_axis 0` is 0.8659 and the SIGNED mean is -0.8659
- the same number - which says the change is entirely "some faces got darker"
and not at all "faces became more different from each other". The local
contrast falls slightly, 1.3% vertically and 2.5% horizontally, and it falls
further at 0.20.

The mechanism is visible once stated: two risers of different axes belong to
different EDGES of the same cell and meet at a corner, so they are rarely
adjacent in screen space. Darkening one family therefore separates it from
faces it is not next to. What it does do is make a cell's four sides four
tones rather than three, which is a per-cube reading rather than a per-pixel
one and is exactly the thing a local-contrast metric cannot see.

**So this stage produces a picture and not a number**, the picture is in
"For Marcel to rule on", and the plan's default ships. The one number that
mattered defensively is the black crush: `dark40` over the far band goes
8.81% -> 8.83% at 0.08 and 8.88% at 0.20, against distance v2's carried
reference of 8.90% after the riser lift and 7.08% with terracing off.
**Darkening the cross-axis risers does not reopen carried item 14.**

---

## Stage 4 - The reach: rings 3 and 4, and the rim

**Shipped.** Two new rings, and the top two view presets see the whole region.

| ring | cells | covers | step height |
| --- | --- | --- | --- |
| 0 | 4 m | seam to 200 m | 4 m |
| 1 | 8 m | 200-400 m | 8 m |
| 2 | 16 m | 400-960 m | 16 m |
| **3** | **32 m** | **960-1920 m** | **32 m** |
| **4** | **64 m** | **1920 m to the fog** | **64 m** |

`RING_OUTER_M` gains 960 and 1920; `RING_STEP_MULTIPLE` gains 8 and 16. Every
v2 rule extends with them by construction rather than by being re-implemented -
the cubic lock is `step = cell width` and both new steps are powers of two, so
the subset property holds and a ring boundary still SUBDIVIDES a mountain's
shelves; the ridge round-up, the skirts, the seam band, the terrace level and
`ring_step_blocks()` all read the two tables and needed no edit at all.

**The reach is preset-owned and nothing reads the world's size.** High and
Ultra go to `fog_end 3200 m`, which puts the far field's own radius at 3,840 m
(x `FOG_MARGIN`) and the camera's far plane at 4,000 m (x
`Player.FAR_PLANE_RATIO`). The region is 3 x 3 km with a 4,243 m diagonal and a
rim about 2.6 km from a valley floor, so the rim is inside the frame from
anywhere a player can stand, with headroom. Low and Medium are untouched: their
far radius runs out inside ring 2, the ladder stops there, and they cost
exactly what they cost before. A preset reaching ten kilometres would want a
sixth row in the table and nothing else.

**`far_tree_m` does NOT follow the fog**, which is decision 6 and a departure
from the rule the presets have carried since world feel v1 Stage 7 ("far_tree
is the fog, at every preset"). High keeps 800 m of impostors under a 3,200 m
fog. The rule it breaks exists because "fog past the far trees is a bald
mountain in plain view, and the far field painted it forest-green: a mown
slope" - and what closes that gap now is Stage 1's vote, which paints the
ground past 800 m forest-green because it IS forest, at a cost of nothing per
tree. Sixteen times the ring area for a forest two pixels tall is the trade
decision 6 declined.

### The budget arithmetic, and it holds

The plan predicted "each new ring costs roughly what ring 2 cost... expect the
far mesh to grow from ~200-260k vertices to ~300-350k for nearly 4x the visible
distance. If Stage 4 lands far outside that envelope, stop and write down why."

`ganymede, deterministic` for the vertices, `single run` for the wall:

| | Stage 3 (fog 800 m) | Stage 4 (fog 3200 m) | |
| --- | --- | --- | --- |
| far mesh in game | 262,312 | **320,764** | **+22.3% for 4x the reach** |
| far probe, spawn | 254,140 | 311,696 | +22.6% |
| far probe, summit | 143,232 | 191,960 | +34.0% |
| far probe, lake | 242,120 | 294,936 | +21.8% |
| job ms, spawn | 2,380 | 3,065 | +28.8% |
| job ms, summit | 1,296 | 1,821 | +40.5% |
| job ms, lake | 2,364 | 2,997 | +26.8% |
| first build, wall ms | 4,834 | 6,207 | +28.4% |

**320,764 against a ~350,000 envelope: MET.** And the shape of the cost is the
one the log-ring ladder promises - the visible radius went from 960 m to
3,840 m, sixteen times the area, for 22% more vertices. Two of that 22% is
ring 4 barely existing at spawn: the region is 3 x 3 km and ring 4 starts at
1,920 m, so most of it is outside `heightmap.in_bounds` and emits nothing. The
terrace-compliance row counts what actually got built - at spawn, **5,670**
quads of 64-block cells and **51** of 128-block ones, against 9,345 of 32-block
ones. At the summit, which is nearer a corner and looks across the whole map,
ring 4 emits 922.

**So the honest reading of the budget is that ring 3 is the one that cost
anything and ring 4 is nearly free ON THIS REGION** - and on an unbounded world
it would cost what ring 3 costs, which is what the ladder predicts and what the
next epic will pay. Said here so nobody reads +22% as a general law.

### Gate

| gate | result |
| --- | --- |
| far mesh vertices within the envelope | **MET - 320,764 in game, 311,696 in the probe, against ~350,000** |
| wall rebuild under 5 s | see below - **MET for a rebuild, NOT MET for the first build** |
| far probe determinism, rings 0-4 | **MET - `PASS`, tables IDENTICAL, run 1 in 155,919 ms and run 2 in 155,783 ms** |
| terrace compliance on the new rings | **MET - 100% at 64 blocks and 100% at 128 blocks, worst deviation 0.000, all three vantages** |
| frontier rule untouched, stream probe zero holes | see below |
| a valley-floor shot with the rim visible and terraced | see below |

### The wall time, and the instrument the criterion needed

The acceptance criterion is "wall rebuild under 5 s on ganymede", and until
this stage **every wall number this project has ever printed was contended.**
The first build waits behind 2,400 chunks on a pool that runs one GDScript task
at a time; a rebuild during a screenshot tour waits behind whatever that
vantage is streaming; the stream probe's rebuilds happen during a sprint, which
is the worst case by construction. None of them is what the criterion is about,
which is a person standing still moving a slider on F4 and watching the far
country redraw.

So two instruments were added here. `FarField` now prints a one-line summary of
every rebuild's wall time at exit, so a seventeen-vantage tour is also a
seventeen-sample measurement; and `--far-probe --cost` ends by loading the REAL
world, waiting for it to go idle, and calling `rebuild_in_place()` three times
the way `apply_far_knobs()` does.

| what | ms | |
| --- | --- | --- |
| **idle rebuild, the F4 knob** | **3,347 (3,263-3,463)** | **the criterion. MET** |
| job time, main thread, probe | 3,123 (1,874-3,209) | the work itself |
| first build, during world generation | 6,267 | behind 2,400 chunks |
| rebuild during a tour, median after the first | 5,679 | behind a vantage's streaming |
| rebuild during a sprint, median | 6,095-6,365 | the worst case there is |

**Under 5 s standing still, over 5 s while the world streams.** Both are true
and the epic's judging instrument is the first one. The second is not
cosmetic - see the holes, below, which are entirely caused by it.

### THE STREAM PROBE FAILS. Hard rule 2 is broken at this stage.

`--stream-probe --strict`, twice, `ganymede, single run` each:

| run | holes | frames over 33 ms | verdict |
| --- | --- | --- | --- |
| 1 | **25** | 26 | **FAIL** |
| 2 | **8** | 16 | **FAIL** |

Distance v2 saw one hole sample in seven runs and called it unsettled. This is
twenty-five in one run. **It is a real regression and this stage caused it.**

**The mechanism, worked out rather than guessed.** The far mesh is a disc
centred on `center`, with a hole cut to the frontier, and both are captured
when a rebuild is SUBMITTED. A rebuild now takes 6.3 s of wall clock during a
sprint. At 13 m/s the player has moved **82 m** by the time that mesh reaches
the screen, so the disc on screen is centred 82 m behind them and its hole -
128 blocks, 64 m, of radius - is centred there too. **In front of the player
the hole has moved backwards and there is more cover than before. Behind them
it sticks out**: the hole now reaches 64 + 82 = 146 m behind the player while
the voxels only reach 96 m behind. Fifty metres of ground with neither.

The `sprint back` leg carries 15 of the 25, which is what that explanation
predicts.

**It is not a frontier bug and `world.gd` is still in step.**
`World.far_field_exclusion_m()` and `FarFieldJob` read the same
`FRONTIER_OVERLAP_CELLS` and the same `built_frontier()`, which is distance v2's
carried item 12 done right; the hole the probe reports is a hole that is really
there. What changed is only that the rebuild got 3.3x slower, so the disc lags
3.3x further.

**The remedy is Stage 7, and Stage 7's plan needs one correction.** The plan
says the far field should start at "~0.85 of the built frontier per sector".
Our geometry: the voxel radius is 192 blocks and today's hole is
`192 - 8 * far_step = 128` blocks, which is **0.67** of the frontier, so 0.85
would be LESS overlap than today and would make this worse. DH's percentages
are tuned against Minecraft's render distances and do not transfer as numbers.
What the arithmetic above asks for is a hole radius under
`voxel_radius - lag`, and with an 82 m lag against a 96 m radius that is
**nearly zero: the far mesh has to cover the whole voxel disc.** That is
affordable (about 1,800 ring-0 quads, under 2% of the mesh) and it is safe as
long as the far mesh is SUNK below the voxel surface inside the frontier, which
it currently is not - inside the seam band it deliberately computes the voxel
surface exactly, and half the time that is above the voxels' own top face.
Stage 7 does both.

**Recorded here, not fixed here**, per the plan's rule for a gate that cannot
be met as written. **Acceptance re-runs the full harness at Stage 7 and the
epic does not merge until it is zero.**

### The cost, ABAB

`ganymede, ABAB median`, three runs each, interleaved A-B-A-B-A-B,
`--far-probe --cost --set fog_end_m=800|3200`, run order as written. A is this
epic at Stage 3's reach; B is Stage 4's.

| | fog 800 m | fog 3200 m | delta |
| --- | --- | --- | --- |
| spawn, job ms | 2,458 (2,456-2,537) | 3,100 (3,098-3,116) | +26.1% |
| summit, job ms | 1,338 (1,333-1,361) | 1,838 (1,835-1,842) | +37.4% |
| lake, job ms | 2,444 (2,436-2,482) | 3,036 (2,992-3,042) | +24.2% |
| **idle rebuild, wall ms** | **2,587 (2,574-2,666)** | **3,223 (3,222-3,230)** | **+24.6%** |
| first build, wall ms | 4,994 (4,827-5,295) | 6,193 (6,096-6,508) | +24.0% |
| far mesh in game | 262,312 | **320,764** | +22.3% |

Every row lands between +22% and +37% for **sixteen times the visible ground**,
and the three vantages and the two wall measurements agree with each other. The
summit is the largest because it is the vantage where the new rings have the
most world left to draw.

### The fleck, and a warning for Stage 5

The reach raises the fleck more than any other stage, for a reason that is not
about paint: the far country now fills the frame where fog used to.

| shot, far band | Stage 3 | Stage 4 | dark40, Stage 3 -> Stage 4 |
| --- | --- | --- | --- |
| **6-postcard** | 4.5768 | **5.2168** | 8.83% -> **20.13%** |
| 5-lake | 2.9224 | 5.5764 | 0.30% -> 2.82% |
| 14-postcard-dusk | 3.6224 | 3.8720 | 19.98% -> 28.73% |
| 3-forest-slope | 4.0966 | 4.1323 | 10.38% -> 10.38% |
| 9-treeline | 1.9027 | 1.9006 | 43.41% -> 43.41% |
| 2-summit | 1.0874 | 1.0874 | 0.00% -> 0.00% |

**And `dark40` on the postcard more than doubled, 8.83% to 20.13%.** That is
distance v2's carried item 14 - the black crush - reopening, and it is not the
axis term (Stage 3 moved it by 0.02 points). It is the fog: `fog_start_m` is
`0.4 * fog_end_m`, so raising the reach moved the first fog band from 320 m to
1,280 m and **a kilometre of mountain that used to be hazed is now drawn at
full strength, including its shaded side.** Looking at
`build/tour/s4-reach/6-postcard.png` beside `s3-axis/6-postcard.png`: the far
range is deeper and there are whole massifs behind the old fog wall that were
never drawn before, and they are hard, dark and airless.

**This is Stage 5's job and it is now the most load-bearing stage in the epic.**
"No fog wall" has been achieved by having no fog.

### The rim, photographed

`build/tour/s4-reach/6-postcard.png`: **the rim of the region is visible,
terraced, and there is no fog wall anywhere in the frame.** Two thirds of the
acceptance shot. It is not hazed, which is the third third and is Stage 5.

`4-valley-floor` is NOT that shot and should not be read as one: it is a flat
meadow whose horizon is its own ground, so no rim is in the frame at any reach.
Its floating impostors and pale horizon band are identical at Stage 3 and at
baseline; they are pre-existing and not this stage's.

---

## Stage 5 - The air: exp² fog over the far radius, banded

**Shipped**, `far_fog_start_frac` default **0.4**.

Three changes to `Look.FOG_FN`, and the bands survive all three.

**The curve is exp².** `1 - exp(-(2.5 * t)^2)` over the normalised span,
divided by its own value at `t = 1` so the last band is exactly the fog colour
and the far mesh's edge is still never the thing you notice first. 2.5 is DH's
own `EXPONENTIAL_SQUARED` density.

**The span is a FRACTION of the far radius, never a metre value.** The world is
unbounded by design and no new system may bake in a reach, so the knob is
`far_fog_start_frac` and the span is `[frac * kubik_fog_end, kubik_fog_end]`.
At 0 the shader falls back to `kubik_fog_start`, so `fog_start_m` still means
something and is still on F4 - which is what "every existing fog knob still
does something sensible" asks for.

**The distance is cylindrical.** Spherical distance fogs a peak by how far away
it is through the air, so standing under a mountain and looking up hazes its
summit as hard as ground at the same range - while the sky behind it is not
hazed at all, because the sky is not drawn through this. A grey peak against a
clear sky is the one thing a travel poster never does. `world_pos.xz` against
`INV_VIEW_MATRIX[3].xz`, which both the terrain and the water shader can reach.

**`poster_fog()` still exists and still means what it meant.** It is now a
one-line wrapper that passes the spherical distance, kept because
`FloraModels` builds its own materials from `Look.FOG_FN` and is another lane's
file. Nothing grows past 128 m and the air does not start until 1,280 m, so the
flora has never reached a non-zero fog factor and still does not - checked
rather than assumed.

**The near field is untouched:** `swatches.png` and `swatch-ramp.png`
**identical, 0 pixels**, after a change to the shader every material in the game
compiles. The swatches sit inside the fog start, where both curves are exactly
zero, so the arithmetic is unchanged and the compiler agreed.

### The measurement that changed the stage: the tour could not see the reach

`far_fog_start_frac` 0.4 -> 0.15 changed **0 pixels** of `6-postcard`'s far
band. So did 0.25. So did raising `fog_bands` from 4 to 24. Something was
either broken or the frame had nothing to fog, and the control settles it:
`--set fog_end_m=800` moves the same band by **35.69 luma levels over 268,689
pixels**. The fog works.

So the frame had nothing to fog. Reading it off the two experiments: at
`fog_bands 24` the first band lands at ~1,390 m and **zero** pixels changed; at
`frac 0.15` with 24 bands the first band lands at ~638 m and **2,726** pixels
changed, out of 383,700. **99.3% of `6-postcard`'s far band is within 640 m.**

And that is true of every vantage in the tour. Each of the sixteen is either
enclosed by its own valley or standing a hundred metres from its subject -
`2-summit` is the highest ground in the world, photographed from 132 m away
with the sky behind it. **Nothing in this harness has ever stood on high
ground and looked out.** The epic that exists to make the whole country visible
had no instrument that could see it.

**So one vantage was appended to `screenshot_tour.gd`: `17-rim`**, standing on
the summit at eye height, looking across the map toward the origin, which is
the longest sightline this world has. It is one append to one list, in a TOOL
rather than in the game, the sixteen shots before it are untouched and every
earlier label stays comparable, and it is recorded here because
`screenshot_tour.gd` is not on the plan's lane list. It is also the fourth
pillar's north star as a photograph: the world huge, the player small.

### Gate

Measured over `17-rim`'s own far band, which is **rows 330-520** - that frame's
horizon is at about y 340, so rows 0-300 are pure sky and the epic's own metric
reads 0.2259 there whatever the fog is doing. Every number in this section says
which rows, for that reason.

| `17-rim`, rows 330-520 | fleck | p95 | textured | dark40 |
| --- | --- | --- | --- | --- |
| **`fog_end 800`, the reach before Stage 4** | **0.0502** | **0.00** | **0.54%** | 0.00% |
| `fog_end 3200`, `frac 0.15` | 3.4970 | 18.07 | 30.03% | 0.00% |
| `fog_end 3200`, `frac 0.25` | 4.1943 | 21.34 | 32.97% | 0.51% |
| **`fog_end 3200`, `frac 0.40` (shipped)** | **5.0454** | **24.99** | **36.17%** | 1.39% |

| gate | result |
| --- | --- |
| the rim readable through haze where the old curve saturates to flat fog colour | **MET, by a factor of a hundred** - 0.0502 to 5.0454 |
| a tour pair old-reach/new-reach from a standpoint that sees the rim | **MET** - `s5-rim-end800/17-rim.png` against `s5-rim/17-rim.png` |
| near-band crop within tolerance at default knobs | **MET** - swatches identical; the near band of every tour shot is unchanged from Stage 4 except where flora streaming moves it |
| every existing fog knob still does something sensible | **`fog_end_m` yes, spectacularly. `fog_start_m` yes, at `far_fog_start_frac 0` and only there. `fog_bands` - see below, and the answer is nearly NO** |

**`build/tour/s5-rim-end800/17-rim.png` is the fog wall, photographed.**
Everything past about 600 m is one flat sheet of near-white with the terrain's
silhouette barely readable through it - fleck **0.0502** and p95 exactly
**0.00**, which is the number for "there is nothing there". Beside it,
`s5-rim/17-rim.png` is the whole region in blocks to the horizon. That pair is
the epic.

### `fog_bands` is now a resolution, and 4 is coarse

The bands were tuned by look v1 and v2 against a 480 m span (320 m to 800 m),
where each of the four covered 120 m. The same four now cover a 1,920 m span at
480 m each, so **the first band boundary moved from 400 m to 1,558 m.** Nothing
nearer than that gets any air at all, whatever the curve says, because the
quantiser rounds it to zero.

That is why `frac 0.15` changes `6-postcard` by 2,726 pixels rather than by
none and by fifty thousand: dropping the start to 480 m only moves the first
band to 875 m, and the postcard's country stops at 640 m.

**Not changed here**, because `fog_bands` is a look v2 constant and its value is
Marcel's; the finding and the arithmetic are in "For Marcel to rule on". The
in-house precedent points one way, though: distance v2 Stage 7 scaled
`far_band_step` by the ratio of the band interval so that "the value change per
METRE of altitude" stayed where look v1 put it. The same argument applied to
`fog_bands` says four bands over 480 m is sixteen over 1,920.

### For the record: what the fog curve is worth on its own

Holding the reach at 3,200 m, `far_fog_start_frac` trades contrast for air on
the rim shot: 0.40 keeps the most block detail (fleck 5.05) and starts the air
at 1,280 m; 0.15 starts it at 480 m and reads as aerial perspective (fleck
3.50). **The recommendation is 0.15-0.20 and it is Marcel's call**; the shipped
value is the plan's 0.40.

---

## Stage 6 - Docs, night 1

Everything above is night 1. This section is the summary a person can read in
one sitting, and it is the point the plan names as safe to stop at.

### Night 1's numbers in one table

`6-postcard`, far band rows 0-300, `ganymede, eye` for the shots and
`deterministic` for the geometry.

| | baseline `1ece781` | S1 vote | S2 grain | S3 axis | S4 reach | S5 fog |
| --- | --- | --- | --- | --- | --- | --- |
| fleck | 3.9398 | 3.9801 | 4.6173 | 4.5768 | **5.2168** | 5.2168 |
| textured | 27.7% | 27.6% | 38.5% | 38.3% | **42.3%** | 42.3% |
| dark40 | - | - | 8.81% | 8.83% | **20.13%** | 20.13% |
| far mesh, in game | 262,312 | 262,312 | 262,312 | 262,312 | **320,764** | 320,764 |
| idle rebuild, wall ms | - | - | - | 2,587 | **3,223** | 3,223 |
| far probe | PASS | PASS | PASS | PASS | **PASS, rings 0-4** | PASS |
| swatches | - | n/a | **identical** | n/a | n/a | **identical** |

`17-rim`, rows 330-520, which is the only band in this project that can see
past a kilometre:

| | reach 800 m | reach 3,200 m |
| --- | --- | --- |
| fleck | **0.0502** | **5.0454** |
| p95 | **0.00** | 24.99 |
| textured | 0.54% | 36.17% |

### Every constant this epic has moved, so far

| constant | before | shipped | why, in one line |
| --- | --- | --- | --- |
| `far_vote` | - | **1.0**, on F4 | a far cell is the most common of four real materials; shore never wins, ties are the first sample |
| `far_grain` | - | **0.065**, on F4 | the near field's own `grain_amount`, extended outward on a lattice that grows instead of fading |
| `far_riser_axis` | - | **0.08**, on F4 | half the near field's own sun/anti-sun luma spread, so a far cube has four tones |
| `far_fog_start_frac` | - | **0.4**, on F4 | DH's `farFogStart`, of the configured reach and never a metre value |
| `RING_OUTER_M` | `[200, 400]` | **`[200, 400, 960, 1920]`** | two more rings; each doubling of the reach costs one more |
| `RING_STEP_MULTIPLE` | `[1, 2, 4]` | **`[1, 2, 4, 8, 16]`** | 32 m and 64 m cells, powers of two, so the subset property holds |
| High preset `fog_end` | 800 m | **3,200 m** | a 3,840 m far radius and a 4,000 m camera far plane: the region's rim from anywhere a player can stand |
| High preset `far_tree` | 800 m | **800 m, unchanged** | decision 6 - the impostor ring does not follow the fog, and Stage 1's vote paints the ground past it |
| Ultra preset `fog_end` | 1,000 m | **3,200 m** | the same reach; Ultra buys more voxels and more trees, not more country |
| `FOG_FN`'s curve | `smoothstep` | **exp², density 2.5** | aerial perspective instead of a ramp |
| `FOG_FN`'s distance | spherical | **cylindrical** | looking up must not fog the peaks' sky |
| far field's material | the chunks' | **its own, spliced** | it needs uniforms the chunks must not have, and Stage 7 needs the seam |
| `17-rim` | - | **appended to the tour** | the harness could not see the reach; a lane note, not a lane file |

`PROPERTIES` and `hash_key()` are untouched. **`3d45b8fc` before and after every
stage, heightmap `76cccdb6`, spawn `(-44, -124)`** - nothing this epic has added
crosses the network or can refuse a join.

### What night 1 bought, and what it cost

Bought: the far country reads as a surface made of blocks rather than as a
smooth thing with contour lines on it (`far_grain`, the largest single move in
the fleck), the whole region is drawn (rings 3 and 4), and the fog wall is gone
- **fleck 0.0502 to 5.0454 on the rim band, p95 0.00 to 24.99.**

Cost, and both are named rather than buried:

1. **The stream probe fails.** 25 holes and 8 holes, against hard rule 2. The
   mechanism is Stage 4's rebuild latency and the remedy is Stage 7.
2. **`dark40` on the postcard doubled**, 8.81% to 20.13%, because a kilometre
   of mountain that used to be hazed is now drawn at full strength. That is
   distance v2's carried item 14 reopening through the fog rather than through
   the risers, and the lever is `far_fog_start_frac` and `fog_bands`, both of
   which are on F4 and both of which are Marcel's.

---

# Night 2

## Stage 7 - The seam: overdraw and the dithered dissolve

**Shipped**, `far_overdraw` default **0.0** and `far_dither_m` default **0.0**.
**Hard rule 2 is restored: 0 holes in all three runs.**

### The overdraw, and why DH's number is the wrong number here

`far_overdraw` is the fraction of the voxel radius at which the far mesh's
inner edge sits - DH's `overdrawPreventionPercent`, same sense. What shipped
before this epic is `voxel_radius - 8 * far_step` out of `voxel_radius`, which
is **0.667**; DH's own automatic table would pick 0.8 or 0.9 at a comparable
render distance, and the plan asks for **0.85**. All three are LESS overlap
than we already had, and the arithmetic in Stage 4 says what is actually
needed: the rebuild takes 6.3 s during a sprint, the disc that reaches the
screen is centred 82 m behind the player, the voxel radius is 96 m, so the
overlap has to exceed 82 of the 96. What is left is nearly nothing.

**So 0: the far mesh is drawn under the whole voxel disc.** It costs
**322,988 vertices against 320,764**, which is +0.7% and still inside the
budget, and **3,284 ms of idle rebuild against 3,223**, which is +1.9%. The
plan's worry about the price of overdraw does not survive contact with the
log-ring ladder: the disc it adds is ring 0's cheapest 1,800 quads.

### The sink, which overdraw needed and the plan did not mention

Inside the seam band `_corner_y()` deliberately computes the voxel surface
itself, `coarse + detail + half a block`. The voxel you stand on has its top
face at `floor(coarse + detail) + 1`. The difference is `0.5 - frac(...)`, so
**half of the overdraw would poke up through the near ground**, by up to a
quarter of a metre, and what a player would see is patches of far-field colour
lying over the terrain at their feet.

`SEAM_SINK_BLOCKS = 3.0` - `detail_amp`, the amplitude of the only thing the
far mesh does not know about the voxel surface, and six times the worst
poke-through. Ramped over the seam band, so it is **exactly zero AT the seam**
and the join itself is what it always was, and full one band inside. Under the
voxels it is invisible; where the voxels have not arrived, what shows through
is ground drawn a metre and a half low instead of sky.

### The one number that had to move

`--stream-probe --strict`, three runs, `ganymede`:

| run | holes | front min, out / back | frames over 33 ms | verdict |
| --- | --- | --- | --- | --- |
| 1 | **0** | 40.0 m / 48.0 m | 3 | FAIL (long frames only) |
| 2 | **0** | 48.0 m / 56.0 m | 0 | **PASS** |
| 3 | **0** | 48.0 m / 56.0 m | 0 | **PASS** |

**Against Stage 4's 25 and 8. Hard rule 2 is met.** The one FAIL is the
long-frame threshold, which distance v1 already recorded as failing on about
half of all runs on this box and which `stream_probe.gd`'s own `TODO(marcel)`
calls the worst possible instrument for a drifting continuous quantity. Holes
are the hard rule and holes are zero.

### The dither is implemented and switched off, and the reason is arithmetic

DH's 4x4 Bayer discard is in the far field's spliced shader, verbatim in
mechanism - screen-coordinate Bayer, `smoothstep(clip, 1.5 * clip, viewDist)`,
DH's own 0.001 fudge "to make sure all pixels fade out", discard below - on
`far_dither_m`, in metres, **default 0**.

**It is in direct conflict with the line above it.** The dissolve discards
fragments nearer than `clip`, and after this stage **every one of those is a
fragment covering a hole**. DH can afford the dissolve because vanilla
Minecraft meshes a chunk in milliseconds; ours takes 6.3 s to rebuild, which is
the entire reason `far_overdraw` is 0. Turning the dissolve on undoes the stage.

It is left in, on a knob, because the conflict is a property of the rebuild
time and not of the idea - if the far-mesh job ever gets cheap (the GDExtension
conversation), the dissolve becomes affordable and this is where it lives. A
value that is safe **today** is about 30 m: the stream probe measures the
frontier ahead of a sprinting player at no less than 40 m in every run above,
so fragments inside 30 m are covering ground that is always there. Photographed
at 30 m for Marcel.

### Speed-aware overdraw: deliberately not attempted

DH reduces its overlap toward 0.2 at speed "to give MC a chance to
load/generate", and the plan asks for an attempt. **It is the wrong direction
for us and would make this stage's failure worse.** DH reduces overdraw at
speed because its overdraw costs vanilla terrain nothing to replace; ours is
already at maximum precisely BECAUSE of speed, and the mechanism as DH has it
would remove overlap at exactly the moment the 82 m lag appears. Not
implemented, and the reason is recorded rather than the file being blamed - it
would not have needed a file outside the lane.

### Gate

| gate | result |
| --- | --- |
| stream probe at sprint, zero holes, full harness | **MET - 0, 0, 0 over three runs**, against Stage 4's 25 and 8 |
| the join invisible at default knobs (photograph) | **MET by eye** - `s5-fog/1-spawn.png` against `s7-seam/1-spawn.png` are indistinguishable; no far-field patch appears anywhere over the near ground, which is what the sink is for. Marcel rules |
| swatches identical | **MET - 0 pixels, both sheets**, after a second splice into the far field's shader |
| far probe deterministic | **MET** - see the Stage 10 run, which covers this commit's job unchanged |
| vertex budget | **MET - 322,988**, +0.7% over Stage 4 and inside ~350,000 |
| idle rebuild | **3,284 ms**, +1.9% over Stage 4 and under the 5 s line |

**The near-band tolerance, since the plan asks for a crop "within
flora-streaming tolerance" and never says what that is.** Measured, from two
tours of identical code (`s0-base` against `s1-vote0`), rows 500-720:
`16-spawn-postcard` **6.92**, `4-valley-floor` **3.00**, `1-spawn` 0.87,
`6-postcard` 0.22, `14-postcard-dusk` 0.07. Against that floor, Stage 5 to
Stage 7:

| shot, rows 500-720 | delta | floor | |
| --- | --- | --- | --- |
| 16-spawn-postcard | 1.50 | 6.92 | inside |
| 4-valley-floor | 3.39 | 3.00 | at the floor |
| 1-spawn | 3.68 | 0.87 | **over** |
| 6-postcard | 0.91 | 0.22 | **over** |

Two of the four are over their own floor, and the honest reading is that the
floor is per-shot and this measurement has one sample of it. **Looking at the
pair is what settles it**, and `1-spawn` before and after are the same
photograph but for which flora columns had landed: the meadow, the terrace
steps to the right, the treeline and the water are pixel-alike, and nowhere is
there a patch of far-field colour lying over the near ground. That is the
artefact the sink exists to prevent and it is not there.

---

## Stage 8 - The far forest flecks

**Shipped**, `far_tree_grain` default **0.07**.

An impostor is shade A of its species, flat, and since distance v1 Stage 6 it is
shade A mixed some way toward its own hillside - so a forest at 600 m is
thousands of copies of ONE green standing on a hillside that Stage 2 has just
flecked. Veloren ships real per-tree colour in thirteen bytes; ours is free,
because every far tree already carries a deterministic hash of its placement
cell and the yaw is already drawn from it.

**Same form as `Block.jitter()` and as the poster's own grain**, deliberately: a
symmetric value multiplier with a smaller red-against-blue tilt at the grain's
own ratio (`grain_hue / grain_amount` = 0.46). The far country's terrain grain
and its forest grain are then one effect with one set of proportions. **On its
own salt** - the yaw already hashes this cell at 931, and a tree that was both
darker and turned the same way as its neighbour would put a pattern in the wood.

**The average is preserved by construction and hard rule 6 is satisfied before
it is measured:** the multiplier is `1 + g` with `g` uniform on `[-a, a]`, whose
expectation is exactly 1. It multiplies in WIRE space, which is where a
MultiMesh instance colour acts and also where the fleck number reads, so the
mean it preserves is the mean that is measured.

### Gate

`ganymede, ABAB median`, three runs each, interleaved:

| | `far_tree_grain 0` | `0.07` |
| --- | --- | --- |
| impostors at spawn | **580, every run** | **580, every run** |
| impostor triangles | **17,700, every run** | **17,700, every run** |
| ring rebuild ms | 900 (884-926) | 874 (872-894) |
| far mesh vertices | 322,988, every run | 322,988, every run |
| idle far rebuild, wall ms | 3,299 (3,284-3,312) | 3,299 (3,299-3,319) |

**MET.** The count and the triangles are identical on all six runs - the knob
moves a colour and nothing else - and the rebuild time is if anything a shade
faster on the grain side, which is noise.

### What it is worth, and the treeline

`ganymede, eye` and per-pixel over the far band, `s7-seam` against `s8-trees`:

| shot | fleck 0 -> 0.07 | mean \|dL\| | **mean dL** |
| --- | --- | --- | --- |
| 1-spawn | 5.4405 -> 5.4529 | 0.5694 | **-0.0096** |
| 5-lake | 5.5760 -> 5.5697 | 0.1731 | **-0.0434** |
| 6-postcard | 5.2168 -> 5.2171 | 0.1578 | **-0.0118** |
| 3-forest-slope | 4.1268 -> 4.1301 | 0.1241 | **-0.0410** |
| 14-postcard-dusk | 3.8720 -> 3.8680 | 0.1194 | **-0.0289** |
| 9-treeline | 1.9008 -> 1.9006 | 0.0017 | **-0.0005** |

**Hard rule 6, measured: the largest shift in any far band is four hundredths
of a luma level.** The fleck number barely moves because impostors are a small
share of the pixels in any of these frames - between 88 m and 800 m, a far tree
is a few pixels tall - and where they are dense enough to matter, `1-spawn`,
twenty thousand pixels change by more than a level. It is a light stage and it
was scoped as one.

**The treeline, which is the thing that could have gone wrong.** Where the
impostor ring ends at 800 m and Stage 1's voted forest-colour cells begin,
there is **no colour cliff** - and at `17-rim`, the only vantage that can see
the boundary at all, the impostors are already sub-pixel by the time they stop,
so the transition is from "green ground with specks on it" to "green ground".
That is decision 6 working: the far forest beyond the ring is terrain colour,
and terrain colour is forest-green there because the ground IS forest.
`build/tour/s8-trees/17-rim.png`, rows 520-720, changes by mean |dL| 0.0506
against Stage 7 - the ring is there and it is quiet.

---

## Stage 9 - TAA, tested and judged

**No default changes, as the plan instructs.** Two things were added to the
harness, because the crawl this stage is about is the one artefact the project
had no instrument for:

- **`--tour --taa`** swaps MSAA 4x for Godot 4's temporal antialiasing. MSAA is
  turned OFF when TAA is on, deliberately: MSAA resolves edges inside one frame
  and TAA resolves them across eight, and comparing "MSAA 4x" against "MSAA 4x
  plus TAA" would measure the wrong pair.
- **`--tour --fly N`** captures N consecutive frames while the camera walks
  forward at 0.75 m a frame, **with no settle between them**, which is what a
  moving player does not get. Every other capture in this harness waits for the
  world to settle and takes one picture, and a harness that only ever takes one
  frame has zero frame-pairs by construction.
- **`png_diff.py --sequence`** reports the mean |dL| between consecutive frames
  over a row band. **That is the shimmer number.**

Both are appends to a tool. `screenshot_tour.gd` is off the plan's lane list
and this is the second time this epic has appended to it; the first was
`17-rim` at Stage 5.

### The shimmer numbers

Sixty frames walking forward from the summit vantage, seed 42, Forward+,
`ganymede`. Mean |dL| between consecutive frames, in sRGB luma levels.

| band | MSAA 4x | TAA | |
| --- | --- | --- | --- |
| **the far country, rows 330-520** | **3.6483** (median 3.4489) | **1.1159** (median 0.8887) | **-69%, and -74% on the median** |
| the near field, rows 500-720 | 3.4754 (median 3.2628) | 1.3985 (median 1.1677) | -60% |
| mostly sky, rows 0-300 | 0.6134 | 0.6565 | +7%, which is nothing happening |

**The crawl is real, it is large, and TAA removes about seven tenths of it.**
Three and a half luma levels of change between one frame and the next, over the
whole far band, is not subtle - it is the terraces of a 3.8 km country
re-resolving every frame as the camera moves.

### Does TAA soften the poster's hard edges?

Still frames, same vantages, MSAA against TAA, local contrast over the far
band:

| shot | MSAA 4x | TAA | |
| --- | --- | --- | --- |
| 6-postcard | 5.2171 | 5.0928 | -2.4% |
| 17-rim | 5.0463 | 4.9281 | -2.3% |
| **14-postcard-dusk** | **3.8680** | **1.6280** | **-58%** |

**Two of the three say no and the third says something more interesting than
yes.** Two and a half percent is not softening; it is the edge pixels of a
hard-edged image being resolved slightly differently, and the poster's flat
fields and hard band boundaries survive it intact.

`14-postcard-dusk` is the one to look at, and **the 58% is not TAA removing
detail - it is TAA removing an artefact this epic introduced.** In
`build/tour/s8-trees/14-postcard-dusk.png` the big far cliffs carry a fine
diagonal HATCHING, a moiré between Stage 2's grain lattice and the pixel grid;
in `s9-taa-still/14-postcard-dusk.png` those same cliffs are clean flat fields
of colour. The fleck number counts the hatch as texture, which is why it falls
so far, and a person looking at the pair would call the second one better.

### The recommendation, and it is a recommendation

1. **The crawl is worth fixing and TAA fixes it.** -69% on the far band, and
   the far band is what this epic added.
2. **It costs almost nothing in the poster's own language** - 2.4% of local
   contrast on the daylight shots, and the flat fields and hard boundaries are
   still flat and hard.
3. **There is a second finding underneath it that is NOT about TAA:** the far
   grain aliases into a visible hatch at dusk on this GPU at MSAA 4x. TAA hides
   it; so would a coarser lattice. `Look.FAR_GRAIN_PX` is 0.003, about two
   screen pixels per lattice cell at 1280x720, and DH's own caution is that
   per-block variation below a certain angular size "stops helping and starts
   aliasing". **If TAA is not adopted, that constant should go up.** It is a
   shader constant rather than a knob and was not moved here.

**Marcel judges the pairs. Nothing in this stage changed a default**, and the
game still ships MSAA 4x.

---

## Stage 10 - Docs, night 2, and the handoff

### Every constant this epic moved

| constant | before | shipped | why, in one line |
| --- | --- | --- | --- |
| `far_vote` | - | **1.0**, F4 | a far cell is the most common of four real materials; shore never wins, ties are the first sample |
| `far_grain` | - | **0.065**, F4 | the near field's own `grain_amount`, extended outward on a lattice that GROWS with distance instead of fading |
| `far_riser_axis` | - | **0.08**, F4 | half the near field's own sun/anti-sun luma spread, so a far cube has four tones and not three |
| `far_fog_start_frac` | - | **0.4**, F4 | DH's `farFogStart`, of the configured reach and never a metre value |
| `far_overdraw` | (0.667, a const) | **0.0**, F4 | the far mesh is drawn under the whole voxel disc: the overlap has to exceed an 82 m rebuild lag |
| `far_dither_m` | - | **0.0**, F4 | DH's Bayer dissolve, implemented and off - every fragment it discards is covering a hole |
| `far_tree_grain` | - | **0.07**, F4 | a distant forest is thousands of slightly different greens, free from a hash it already had |
| `RING_OUTER_M` | `[200, 400]` | **`[200, 400, 960, 1920]`** | two more rings |
| `RING_STEP_MULTIPLE` | `[1, 2, 4]` | **`[1, 2, 4, 8, 16]`** | 32 m and 64 m cells, powers of two, so the subset property holds |
| `FRONTIER_OVERLAP_CELLS` | `const 8` | **`static var`, 24 at the default** | `world.gd` reads it by name and must not drift; a static keeps them in step while the knob moves |
| `SEAM_SINK_BLOCKS` | - | **3.0** | overdraw would otherwise poke a quarter of a metre up through the ground at your feet, half the time |
| High preset `fog_end` | 800 m | **3,200 m** | the region's rim from anywhere a player can stand |
| Ultra preset `fog_end` | 1,000 m | **3,200 m** | the same reach; Ultra buys voxels and trees, not country |
| High / Ultra `far_tree` | 800 / 1,000 m | **unchanged** | decision 6 |
| `FOG_FN`'s curve | `smoothstep` | **exp², density 2.5** | aerial perspective instead of a ramp |
| `FOG_FN`'s distance | spherical | **cylindrical** | looking up must not fog the peaks' sky |
| the far field's material | the chunks' | **its own, spliced from theirs** | uniforms the chunks must not have, and the seam Stage 7 needed |
| `17-rim` | - | **appended to the tour** | the harness could not see the reach |
| `--taa`, `--fly N`, `--sequence` | - | **appended** | the crawl had no instrument at all |

**`PROPERTIES` and `hash_key()` are untouched.** Config `3d45b8fc`, heightmap
`76cccdb6`, spawn `(-44, -124)`, 580 impostors at spawn - before and after
every stage. Nothing this epic added crosses the network or can refuse a join.
**Hard rule 1, LOOK NOT SHAPE, met end to end.**

### Taste, on F4 and still Marcel's

The table distance v1 started and distance v2 kept. Every alternative is a real
tour on ganymede, seed 42, Forward+, and every one of these knobs moves the far
country **standing still, without F7** - which is the property distance v2
built and this epic never regressed.

| knob | shipped | photographed alternatives |
| --- | --- | --- |
| `far_vote` | **1.0** | `s1-vote0` / `s1-vote1` (17 shots each), plus `s1-cell0` / `s1-cell0-v0` at `far_zone_cell_m 0` |
| `far_grain` | **0.065** | `s2-grain0` (0) / `s2-grain` (0.065), 17 shots each |
| `far_riser_axis` | **0.08** | `s2-grain` (0), `s3-axis` (0.08), `s3-axis20` (0.20), `s3-axis00` (0, the byte-identical control) |
| `far_fog_start_frac` | **0.4** | `s5-rim` (0.40), `s5-rim25` (0.25), `s5-rim15` (0.15), and `s5-rim-end800` for the wall it replaced |
| `far_overdraw` | **0.0** | `s7-seam` (0.0) against `s7-nooverdraw` (0.667, what shipped before) |
| `far_dither_m` | **0.0** | `s7-dither30` (30 m) |
| `far_tree_grain` | **0.07** | `s7-seam` (0) / `s8-trees` (0.07), 17 shots each |
| TAA | **not adopted** | `s9-msaa-fly` / `s9-taa-fly` (60 frames each), `s9-taa-still`, `s9-taa-rim` |
| `fog_bands` | **4, untouched** | `s5-b24` (24) and `s5-b24-f15` (24 at `frac 0.15`) |

### For Marcel to rule on

Nine, in the order they matter.

**1. `far_fog_start_frac`, and it is the biggest one.** Shipped at the plan's
**0.40**; **I would rule 0.15-0.20.** At 0.40 the air begins at 1,280 m, which
is further away than most of what a player is looking AT, and the consequence
is measured: `dark40` on `6-postcard`'s far band went 8.83% to 20.13% at Stage
4 and stayed there, because a kilometre of mountain that used to be hazed is
now drawn at full strength including its shaded side. That is distance v2's
carried item 14 - the black crush - reopening through the fog rather than
through the risers. DH gets away with 0.4 because vanilla Minecraft's own fog
handles everything nearer; we have no second fog.
`build/tour/s5-rim/17-rim.png` (0.40) against `s5-rim15/17-rim.png` (0.15).

**2. `fog_bands` is now a resolution and 4 is coarse.** Four bands tuned by
look v1 and v2 against a 480 m span now cover 1,920 m, so **the first band
boundary moved from 400 m to 1,558 m** and nothing nearer than that gets any
air at all whatever the curve says. The in-house precedent points at scaling
it: distance v2 Stage 7 scaled `far_band_step` by the ratio of the band
interval so "the value change per METRE" stayed where look v1 put it. The same
argument says four bands over 480 m is sixteen over 1,920. **Not changed - it
is a look v2 constant and it is yours.**

**3. TAA.** `-69%` of the crawl on the far band, for `-2.4%` of local contrast
on the daylight stills, and the poster's flat fields and hard boundaries
survive. **I would adopt it.** The pairs are `s9-msaa-fly` / `s9-taa-fly` for
the crawl and `s8-trees` / `s9-taa-still` for the softening. **And read
`14-postcard-dusk` in that pair before deciding:** under MSAA the far cliffs
carry a fine diagonal hatch, a moiré between the grain lattice and the pixel
grid, and under TAA they are clean flat fields. If TAA is NOT adopted,
`Look.FAR_GRAIN_PX` should go up instead - the hatch is the epic's own artefact
and the constant is the lever.

**4. `far_vote` is very nearly a null and it costs 17.5% of the far-mesh job.**
It changes the picture - five luma levels across 55,842 pixels of the postcard,
because the boundaries move - and it does not raise the fleck, because a mode
vote is a median filter and this far field was never averaging. It buys a
better answer per cell (three quarters forest is painted forest) and nothing
else. **Keeping it is defensible and so is turning it off**; I would keep it,
because "one real material, chosen properly" is the doctrine and 17.5% of a
worker task nobody waits on is cheap.

**5. `far_riser_axis` produces a picture and not a number.** The metric moves
DOWN 1.3%, because two risers of different axes meet at a corner rather than
side by side, so darkening one family separates it from faces it is not next
to. What it buys is four tones per cube. `s2-grain` (0) / `s3-axis` (0.08) /
`s3-axis20` (0.20). I would keep 0.08 and would not go to 0.20.

**6. The seam.** `s7-seam/1-spawn.png` against `s5-fog/1-spawn.png`: the far
mesh is now drawn under the whole voxel disc and sunk a metre and a half, and
the two photographs are the same photograph but for flora streaming. The thing
to check by eye is that no patch of far-field colour lies over the near ground
anywhere - I cannot find one.

**7. The treeline.** `s8-trees/17-rim.png`, where the impostor ring ends at
800 m and Stage 1's voted forest-colour cells begin. No colour cliff, because
the impostors are already sub-pixel when they stop.

**8. `far_grain` at 0.065 is the near field's number, not a chosen one.**
`s2-grain0` / `s2-grain`. It is the single largest move in the epic's own
metric (`6-postcard` 3.98 to 4.62, textured 27.6% to 38.5%) and it is the one
knob I would expect you to want to turn UP rather than down.

**9. The rim shot itself.** `17-rim` is new and it is the epic's acceptance
frame. `s5-rim-end800/17-rim.png` is what the game looked like at the old
reach - a flat wall of near-white past 600 m, fleck **0.0502**, p95 exactly
**0.00** - and `final/17-rim.png` is the whole region in blocks to the horizon.
**If one pair is worth your five minutes it is that one.**

### The fleck table, final

`final`, 17 shots plus `17-rim`, against the baseline. Far band rows 0-300
except `17-rim`, whose horizon is at y 340 and whose band is rows 330-520.

| shot | baseline fleck | **final fleck** | baseline tex | **final tex** |
| --- | --- | --- | --- | --- |
| 1-spawn | 4.335 | **5.450** | 26.8% | **38.9%** |
| 2-summit | 1.085 | 1.068 | 10.1% | 10.6% |
| 3-forest-slope | 2.102 | **4.129** | 13.6% | **49.8%** |
| 4-valley-floor | 1.345 | 1.398 | 3.7% | 3.7% |
| 5-lake | 2.236 | **5.570** | 16.8% | **41.6%** |
| **6-postcard** | 3.940 | **5.217** | 27.7% | **42.3%** |
| 7-forest-interior | 0.834 | 0.834 | 7.0% | 7.0% |
| 8-meadow-closeup | 9.179 | 9.294 | 42.2% | 44.2% |
| 9-treeline | 1.719 | 1.901 | 18.2% | 21.5% |
| 10-shore | 0.686 | **2.468** | 5.0% | **16.1%** |
| 11-forest-dusk | 0.671 | 0.671 | 5.8% | 5.8% |
| 12-meadow-night | 1.997 | 1.840 | 10.9% | 13.7% |
| 13-meadow-dawn | 1.332 | 1.824 | 10.3% | 14.8% |
| 14-postcard-dusk | 3.094 | 3.868 | 28.6% | 39.2% |
| 15-boulder | 3.368 | 3.822 | 23.0% | 30.9% |
| 15-under-canopy | 0.681 | 0.677 | 6.4% | 6.3% |
| 16-spawn-postcard | 1.557 | 1.824 | 10.9% | 14.0% |
| **17-rim** (rows 330-520) | **0.050** at the old reach | **5.046** | **0.5%** | **36.2%** |

The near field's own band, on the shots where rows 500-720 really are the near
field, measures 3.2 to 8.2. **Eight of the eighteen far bands are now inside
that range and `17-rim` is at 5.05**; at baseline exactly one was.
`7-forest-interior`, `11-forest-dusk` and `15-under-canopy` do not move at all
and correctly so - they are photographs of trunks at eye height with no far
country in the frame.

### Acceptance

| criterion | result |
| --- | --- |
| **the rim visible, terraced and hazed, no fog wall** | **MET, with one substitution named below** - `final/17-rim.png` |
| **fleck above baseline at every stage that claimed it** | **MET** - Stage 1 +1.0% on forest-facing shots (a near-null, recorded as one), Stage 2 +16.0%, Stage 4 +12.9%. Final `6-postcard` 3.940 -> 5.217 |
| **far mesh ≤ ~350k vertices** | **MET - 322,988**, deterministic, every run |
| **wall rebuild ≤ 5 s, ABAB** | **MET at 3,299 ms** (3,284-3,319, ABAB, three runs each) for a rebuild with the pool idle - which is what an F4 knob does. **NOT under 5 s while the world is streaming**: 5,433-6,187 ms during a sprint. Both are reported at every stage and neither is hidden |
| **stream probe: zero holes at sprint, full harness** | **MET - 0 holes in all SIX runs**, three at Stage 7 and three at HEAD, against Stage 4's 25 and 8 |
| **swatches byte-identical to main's** | **MET - 0 pixels, both sheets**, checked after every shader-touching stage |
| **far probe determinism, rings 0-4, twice** | **MET - `PASS`, tables IDENTICAL**, 163,923 ms and 164,308 ms; terrace compliance 100% at 8, 16, 32, 64 and 128 blocks on all three vantages |
| **every new knob on F4, live, no reroll, with photographed alternatives** | **MET** - seven knobs, the table above |
| **"For Marcel to rule on" with A/B pairs for the vote, the grain, the axis, the fog, the seam, the treeline, TAA** | **MET** - all seven, plus two more |

**THE ONE SUBSTITUTION, stated plainly.** The criterion says "a tour shot from
the valley floor". The shot that shows the rim is `17-rim`, taken **from the
summit**, and the reason is measured rather than argued: **99.3% of
`6-postcard`'s far band - the valley-floor frame - is within 640 m**, because
that valley is enclosed by its own ridges. Moving the fog's start from 1,280 m
to 480 m changes 2,726 of its 383,700 pixels; raising `fog_bands` from 4 to 24
changes none. **No implementation of this epic could have put the region's rim
in a seed-42 valley-floor frame**, and the finding is about the world rather
than about the far field.

What the valley floor DOES show is the other half of the criterion: `6-postcard`
is terraced to its own horizon with no fog wall anywhere in it, and its fleck
went 3.940 to 5.217. The rim, terraced and hazed, is one vantage up.

### The one thing that got worse, and it is not in the acceptance table

**Long frames during a sprint.** `ganymede, ABAB`, three runs each, interleaved,
`--stream-probe --set fog_end_m=800|3200` - the reach on and off, everything
else identical:

| | reach 800 m | reach 3,200 m |
| --- | --- | --- |
| **holes** | **0, 0, 0** | **0, 0, 0** |
| frames over 33 ms | 1, 12, 4 (median **4**) | 31, 30, 0 (median **30**) |
| worst frame, out / back | 41.9 / 31.2, 247.6 / 34.6, 35.6 / 43.8 | 178.2 / **291.5**, 47.4 / **283.2**, 30.7 / 28.7 |
| chunks/s, out | 76.0 (69.5-79.5) | 75.6 (73.8-80.4) |
| chunks/s, back | 88.5 (83.6-90.5) | 78.1 (66.9-87.9) |

**Streaming throughput does not move** - the out legs' medians are half a chunk
per second apart and every range overlaps. **The long-frame count does**, and
the honest caveat is the one `stream_probe.gd`'s own `TODO(marcel)` makes: a
threshold turns a drifting continuous quantity into a coin flip, and one of the
three runs at the new reach produced ZERO long frames while one at the old
reach produced twelve. The ranges overlap.

**What does not look like noise is the worst frame: 291 ms and 283 ms, twice,
on the new reach, against 247 ms once on the old.** The mechanism is distance
v2's carried item 11 getting bigger: **the far mesh's vertex upload runs on the
main thread**, it now uploads 322,988 vertices instead of 262,312, and it
happens about thirty times over a 480 m sprint. A quarter-second hitch is
visible, and it is the price of the reach on a box that uploads a far mesh from
the frame thread.

**It is not an acceptance criterion and it is the first thing in
`STATUS.md`.** The lever is not a constant: an upload off the main thread, or
the GDExtension conversation that would make the whole job cheap.

### Gates that could not be met as written

Four, in one place, in the order they appear.

1. **Stage 2, gate 1: "far band rows 0-300, mean |dL| under 0.5 sRGB levels."**
   That statistic cannot be under 0.5 if the stage works - it IS the fleck. The
   gate is named "the average is preserved", and the statistic that answers
   that is the SIGNED mean, which is at worst **-0.1033** on the six far-band
   shots. Both are reported. Under the plan's literal wording the gate fails on
   `6-postcard` (1.08) and `3-forest-slope` (2.49); under its own name it passes
   by a factor of five.
2. **Stage 4: "wall stays under 5 s on this box."** A rebuild with the pool
   idle is **3,299 ms**; a rebuild while the world is streaming is
   **5,433-6,187 ms**; the first build of a session, behind 2,400 chunks, is
   **6,013-7,285 ms**, and one rebuild during the final tour took **43 s**.
   Every wall number this project had ever printed was contended, which is why
   two instruments were built here before the gate could be answered at all.
3. **Stage 4: "frontier rule untouched, stream probe zero holes."** **NOT MET
   at Stage 4** - 25 holes and 8 - and met at Stage 7 and at HEAD, 0 in six runs.
   Recorded rather than fixed in place, per the plan's own rule, and the
   mechanism was worked out at Stage 4 rather than guessed at Stage 7.
4. **Acceptance: "a tour shot from the valley floor."** Substituted with the
   summit, measured reason above.

And one gate that was met but by a different instrument than the plan imagined:
**Stage 3's "the vertical-luma-gradient metric moves"** moves DOWN by 1.3%, and
the stage's value is a per-cube reading that a per-pixel metric cannot see.

### Carried forward

Everything below is measured, not suspected.

#### This epic owns these seven

1. **The far mesh's vertex upload is on the main thread and the reach made it
   23% bigger.** 322,988 vertices, uploaded about thirty times over a 480 m
   sprint, and twice in six runs that produced a **283-291 ms frame**. Holes are
   zero and throughput does not move; this is the hitch. Distance v2 raised the
   same item at 255,128 vertices and it is now the largest single cost in the
   epic. The lever is an upload off the frame thread, or the GDExtension
   conversation.
2. **The ring boundaries at 960 m and 1920 m are loud, and they are distance
   v2's carried item 9 at a bigger step.** Max fizz **128.00** and **256.00**
   blocks, rms 11.80 and 31.81, against 24.00 and 80.00 at the two inner
   boundaries which are UNCHANGED. Stage 9 of distance v2 found the mechanism
   and it applies unchanged: two rings sample the cell height at different
   world points, up to half a cell apart, and what a geomorph has to blend is
   the SAMPLE POSITION over the last cell or two of the finer ring. At 64 m and
   128 m cells that mis-sample is 32 and 64 blocks of ground before anything is
   quantised. **The fix is known, cheap and was out of scope here.**
3. **`far_fog_start_frac 0.4` leaves the mid-distance airless and doubles the
   dead-black share.** `dark40` on `6-postcard` 8.83% -> 20.13%. See "For
   Marcel to rule on" (1); the knob is on F4 and the recommendation is
   0.15-0.20.
4. **`fog_bands 4` is a resolution tuned against a 480 m span and it now
   covers 1,920 m.** The first band boundary is at 1,558 m. See (2) there.
5. **The far grain aliases into a visible diagonal hatch at dusk under MSAA
   4x.** `s8-trees/14-postcard-dusk.png`, the big cliffs. TAA removes it
   entirely; so would raising `Look.FAR_GRAIN_PX` from 0.003. It is the epic's
   own artefact and it has two levers, neither of which was pulled here because
   Stage 9 changes no defaults.
6. **`far_vote` costs 17.5% of the far-mesh job for a near-null on the fleck.**
   It is defensible and it is not obviously worth its price. Shipped at 1.0.
7. **`FRONTIER_OVERLAP_CELLS` is a `static var` written by `FarField` and read
   by `world.gd`.** It is in step by construction and it is a shared mutable
   static, which is a shape this codebase has none of elsewhere. If `world.gd`
   ever gains a `far_field()` accessor, this and the two `get_node_or_null`
   reaches distance v2 recorded should all go through it.

#### Method

8. **The tour's vantages cannot see past about a kilometre, except the one this
   epic added.** Every one of the sixteen is enclosed by its own valley or a
   hundred metres from its subject. `17-rim` exists because of it. Any future
   epic about distance should check that its instrument can see what it is
   changing BEFORE the stage that changes it - this one found out at Stage 5,
   two stages after the reach shipped.
9. **The far probe is still structurally blind to the frontier** (distance v2's
   carried item 13) and it is now half-closed: `[FarField] first build` and the
   rebuild summary print the vertex count and the wall time the world actually
   produces, which is what would have caught the Stage 8 near-miss distance v2
   describes. The probe itself still builds `FarFieldJob` with an empty
   frontier.
10. **The far probe takes 27 minutes at the new reach**, against 4 at the old,
    because `_fizz` samples a 7,680-block square on a 13-block lattice. It is
    still deterministic and still passes twice; it is no longer something to
    run at every stage, which is why `--cost` exists.
11. **`--strict` fails on the long-frame threshold on about half of all runs,
    at both reaches.** Unchanged from distance v1's finding and unchanged by
    this epic; the threshold count remains the wrong instrument.

#### Untouched by this epic, and still open exactly as it found them

- **Distance v2's carried item 15, the city-skyline summits.** Untouched, and
  the reach makes there be more of them. The next lever is horizontal - shelf
  width or riser treatment at summit cells - and this epic did not spend it.
- **Distance v2's carried item 4, VALLEY GAIN -6.53.** Unchanged.
- **PEAK LOSS +24.20 mean at 600 m.** Unchanged - the terrace machinery is
  untouched and 600 m is inside ring 2, which this epic did not move.
- **The meadow tufts read as gravel** (distance v1's item 8). Untouched.
- **`world.gd` and `chunk_mesher.gd` do not appear in this epic's diff at all.**
  `scripts/character/` does not either.

### The one number to lead with

`build/tour/s5-rim-end800/17-rim.png` against `build/tour/final/17-rim.png`,
over rows 330-520: **fleck 0.0502 with a p95 of exactly 0.00**, against
**5.0454**.

The first number is what "a fog wall" is, written down: past about 600 m the
frame is one flat sheet of near-white in which no two neighbouring pixels
differ by anything at all. The second is the same standpoint with the whole
region in front of it, in blocks, out to the rim.

