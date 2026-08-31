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

