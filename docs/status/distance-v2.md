# Distance v2 - status

The run of `docs/plans/distance-v2.md`, on `feat/distance-v2` from `main` at
`b163ab5` (`f23c3f0` plus the plan itself - distance v1, both nights, merged).
Night 1 is everything visible: the far terrain and the far forest both stop
being smooth. Night 2 is the seams, the bands and the boundary.

**The complaint this answers**, Marcel on 2026-08-28, looking at a night shot
from the valley floor:

> I love the fact that you can see the mountains, you can see the snow, but it
> feels still like it's a different game. [...] It feels like it's two separate,
> same art style game, but one is a cube based game, and the other one is just
> sort of an edge based vector game.

The far field was built to match the near field's **silhouette** and never its
**surface**. This epic gives it a surface made of blocks - bigger blocks the
further away you go, one per far-field cell, 4 m at the seam and 16 m at the
fog.

**The one number to lead with is not FIZZ.** It is `far_terrace`: one knob on
F4, 0 is the game Marcel photographed and 1 is the far country made of blocks,
and moving it redraws the background **without a reroll and without the player
moving**. That is how the whole epic is judged, and Stage 0 is where it was
built rather than where it was promised.

---

## Provenance

Distance v1 introduced this column and it is kept, unchanged, for the same
reason: `e63554f` is the bill for conflating "a number" with "a number worth
comparing".

| provenance | means |
| --- | --- |
| `ganymede, deterministic` | the far probe or the worldgen probe. Pure geometry from a seeded generator: same number on any box, every run, and the probe asserts it by running its whole table twice. |
| `ganymede, single run` | one wall-clock measurement. A smoke alarm, not evidence of a delta. |
| `ganymede, ABAB median` | interleaved, three runs each, median with spread, run order recorded. The only kind of number this epic compares two commits with. |
| `ganymede, eye` | a judgement made by looking at a tour shot taken here, on the RTX 3070 Ti, under the renderer named in the shot's directory. |

ganymede varies about 9% run to run on wall clock; Marcel's desktop varies 60%.
Every comparative number below was taken here.

---

*(this document is written as the run proceeds; sections appear in stage order)*

## Stage 0 - Measure first, and the switch

**Shipped.**

- `far_terrace` on F4 as `distance: far terrace`, 0.0 to 1.0, in
  `LOCAL_PROPERTIES` beside `far_filter_bias` and `far_peak_gain`. Nothing read
  it at this stage. `far_riser_shade` went in beside it, for Stage 3.
- **The knob does not need F7.** `FarField.apply_far_knobs()` keeps a snapshot of
  every LOCAL knob that changes only the far mesh or the impostor ring; when one
  of them moves it rebuilds both in place and returns the message to show.
  `game.gd` spends exactly the one line this epic allows it, `debug_hud.gd`
  gained two appended rows, and neither file was restructured.
- `FarField.rebuild_in_place()` re-requests at the centre and frontier the last
  request used - not "around the player", which would mean re-deriving World's
  chunk snapping in a second place. `FarTrees.force_rebuild()` forgets where the
  last ring was built so the next `update()` rebuilds it standing still.
- The far probe gained the `far_terrace` header, a **ring boundary** row (max
  and rms over a 50 m window straddling each boundary, because the 100 m bins
  put the 400 m boundary in whichever bin the worst sample fell in), a
  **terrace compliance** row, and - added during Stage 1 - a **shelf stability**
  row over a 200 m walk.
- `--strict` now fails on more than **one** frame over 33 ms. Decision 11.

### Why the knob mattered enough to be Stage 0

F7 is `_on_reroll_requested(same seed)`: the same world, rebuilt chunk by chunk.
3,276 chunks in 39,023 ms on Marcel's box. Forty seconds per flip, with the
world streaming back in around you, is not an A/B a person can judge by eye -
and this epic has exactly one acceptance test, which is a person flipping that
knob and saying whether they still see two games.

### The knob, as a self-test rather than as a promise

`selftest.gd` gained `far terrace knob`. It builds a real `World`, pumps
`FarField._process` by hand (the World is not in the scene tree, so a finished
mesh would never be applied), and asserts four things:

| check | result |
| --- | --- |
| a call with no far knob moved returns the caller's own "press F7" message | pass |
| moving `far_terrace` returns the far-field message and starts a rebuild | pass |
| **not one chunk is queued, built or freed by it** | pass |
| **0.0 -> 1.0 -> 0.0 returns EXACTLY the original vertex count** | pass |

The last row is hard rule 1 as a gate. It runs at every stage from here on.

### The baseline, and the numbers this epic is read against

Seed 42, `--view high`, fog_end 800 m, far_step 8 blocks, heightmap `76cccdb6`,
spawn `(-44, -124)`. All heights in **blocks** (1 block = 0.5 m game, 2 m real).
`ganymede, deterministic`.

| | `f23c3f0` |
| --- | --- |
| FIZZ rms / max | 0.607 / 21.570 |
| ROUGHNESS | 2.5648 |
| PEAK LOSS at 600 m | +55.28 mean, +81.14 worst |
| VALLEY GAIN | +0.53 mean |
| ring boundary 200 m | max 4.60, rms 0.462 |
| ring boundary 400 m | max 21.57, rms 1.611 |
| shelf move over a 200 m walk | rms 5.74 / 5.25 / 8.34, max 50.2 / 43.6 / 62.5 |
| far mesh in game | 103,608 vertices |

### Gate

| gate | result |
| --- | --- |
| far probe at `far_terrace 0.0` identical to `f23c3f0` | **MET** - every geometry row character-for-character identical; only the wall-clock lines differ (1,654 -> 1,650 ms per mesh) |
| far mesh vertex count | **103,608, unchanged** |
| `--strict` passes twice running | **MET** - 1 long frame then 0, holes 0 on both, PASS both. Under the OLD standard the first run would have exited 1, which is decision 11's whole point |
| the knob redraws the far country without a reroll | **MET** - see the self-test above; the wall-clock half is in Stage 2 |

---

## Stage 1 - The height grid

**Shipped**, and it took two attempts. The second one is the interesting part.

`hq = round(h / step) * step`, in **blocks**, where `step` is the ring's own cell
width - 8, 16 and 32 blocks, which are 4, 8 and 16 m. Quantising in blocks
rather than in metres is decision 4's cubic lock written directly: the ring's
step IS its cell width, so step height equals cell width by construction and the
three are powers of two of each other without any arithmetic that could round.

The corners blend: `h = lerp(h_true, hq, far_terrace)`, per corner, from the four
bilinear samples the quad already took. At 1.0 all four are the same number and
the top quad is flat. At 0.0 it is the old quad, unchanged, and not one extra
pyramid read is taken.

### The player term was not in the expression. It was in the input.

The first implementation quantised `_filtered()` - the height the smooth mesh
draws. That expression contains no player term, which is what hard rule 2 asks
for on its face. Its **input** does: `_level_at()` is `log2(distance from the
player)`, so the height being quantised breathes as the player walks, and
quantising a breathing number turns a half-block breath into a **whole step
jump**.

`ganymede, deterministic`, seed 42, `far_terrace 1.0`:

| | smooth (`f23c3f0`) | quantising `_filtered()` |
| --- | --- | --- |
| shelf move over a 200 m walk, rms | 5.74 / 5.25 / 8.34 | **9.76 / 10.10 / 13.56** |
| worst | 50.2 / 43.6 / 62.5 | **80 / 86 / 96** |
| FIZZ rms | 0.607 | 3.409 |

The terraces swam, exactly as hard rule 2 warns, with the rule's letter
satisfied throughout. **This is the finding of Stage 1** and it is why the rule
is worth restating as: nothing the quantisation READS may depend on where the
player is standing either.

### One level, not one per ring

The obvious repair is a pyramid level fixed per ring. It works - within a ring
`hq` becomes a pure function of world position and the FIZZ past 500 m falls to
**exactly zero** - and it breaks the property the whole plan leans on:

> every 16 m shelf is also an 8 m shelf, so crossing 400 m makes a mountain's
> shelves SUBDIVIDE rather than move

which is only true if the two rings quantise **the same height function**. With
a level per ring they do not, and the 400 m boundary measured **144 blocks**
against `f23c3f0`'s 21.6.

So: one level for the whole job, `log2(ring step / heightmap step) +
far_filter_bias`, with which ring's step chosen by `TERRACE_LEVEL_RING`.

### The sweep that chose it

All three run through the far probe at `far_terrace 1.0`, seed 42.
`ganymede, deterministic`.

| `TERRACE_LEVEL_RING` | 0 (level 2) | 1 (level 3) | 2 (level 4) | per-ring |
| --- | --- | --- | --- | --- |
| FIZZ rms | 1.279 | 1.284 | 1.589 | 2.246 |
| FIZZ max | 80.0 | 64.0 | 98.2 | 144.0 |
| ROUGHNESS | 15.46 | 14.42 | 12.54 | 13.20 |
| 200 m boundary, max | 32.0 | 24.0 | 24.0 | 40.0 |
| 400 m boundary, max | **80.0** | 64.0 | 64.0 | 144.0 |
| **PEAK LOSS at 600 m** | **+29.40** | +35.80 | +56.60 | +56.60 |
| seam fizz, summit vantage, 0-100 m | **19.36** | 45.63 | 98.19 | - |
| shelf move, rms | 4.58 / 6.63 / 5.20 | 4.26 / 6.19 / 4.92 | 4.01 / 6.73 / 4.76 | 6.26 / 10.10 / 8.68 |

**Shipped at 0 - the finest ring's 4 m cell, level 2** - on the two things that
can be seen:

- **PEAK LOSS.** +29.40 blocks against `f23c3f0`'s +55.28, a 47% improvement and
  the best number carried item 4 has ever had. Level 4 draws +56.60, which fails
  Stage 4's gate before Stage 4 starts: a terrace cut from a heavily filtered
  surface is a terrace cut from a mountain that is already too short.
- **The seam.** The terrace fades in over four cells at the voxel boundary and
  what it fades *towards* is this level, so the further that is from the surface
  the voxels actually have, the deeper the dip in the middle of the fade.
  Standing on the world's highest summit the 0-100 m band measures 19.4 blocks
  at level 2 against 98.2 at level 4.

What it costs is the 400 m boundary: 80 blocks against 64 at the two coarser
levels. That boundary is Stage 9's subject and is measured there.

### Gate

| gate | result |
| --- | --- |
| at 1.0, every corner height is an exact multiple of its ring's step | **MET, 100.0%** - 5,536 / 5,892 / 9,345 quads at spawn on the 8, 16 and 32 block grids, worst deviation **0.000** blocks; same at the summit and lake vantages. Read off the emitted vertices, not re-derived. Quads inside the seam band are excluded by construction - there the far mesh computes the VOXEL surface on purpose |
| walk 200 m and back; a named shelf does not change height | **NOT MET AS WRITTEN, and the honest comparison is better than it sounds.** A named shelf DOES move at a ring boundary. Over a 200 m walk the terraced far field moves rms **4.58 / 6.63 / 5.20** blocks against the smooth mesh's own **5.74 / 5.25 / 8.34** - so on average it moves LESS than the game already did. Worst sample is worse: 80/96/96 against 50/44/62. **Inside a ring it does not move at all**: FIZZ past 500 m is exactly `0.00` in every band and at every vantage, against 2.11-3.27 for the smooth mesh. Every block of the residue is at the two ring boundaries |
| hard rule 1 | **MET** - far probe at 0.0 identical to `f23c3f0` on every geometry row, far mesh 103,608 vertices at both 0.0 and 1.0 |
| self-tests | green |
| far probe determinism | **PASS**, tables IDENTICAL over two runs, at both knob settings |

---

## Stage 2 - The terrace

**Shipped.** A cell gets one height, its top quad is flat, and the difference to
each lower neighbour is a vertical riser. The riser is `_push_skirt` with the
neighbour's height gap instead of a fixed drop - the machinery has been in
`_build_ring` since terrain v1 and only the depth is new. Ring-boundary skirts
stay: they cover cracks *between* rings, which risers do not, and the two
coexist.

Two details the plan did not specify and both are load-bearing:

- **A riser is a trapezoid, not a rectangle.** Its depth at each end is the gap
  between this cell's blended corner and the neighbour's blended corner at the
  same world position, and both blends start from the same raw sample. So at
  `far_terrace 0.0` it is exactly zero at both ends and no riser is emitted at
  all - hard rule 1 by arithmetic rather than by a branch - and across the seam
  band, where two neighbouring cells are terraced by different amounts, the gap
  really is a wedge.
- **A ring-boundary skirt grows with the terrace**,
  `step * (SKIRT_DEPTH_CELLS + far_terrace)`. One cell of drop covers anything a
  smooth heightmap can produce across one cell; a terraced one can also disagree
  with its coarser neighbour by most of a step. Exactly the old length at 0.0.

### The bug this stage was nearly shipped with

`far_terrace` reached the far mesh in a self-test, in a probe, and nowhere else.
**`World.setup()` keeps a CLONE of the config, deliberately** - "the panel writes
into the config Game holds, and if the world read from that too, then moving a
slider would change the terrain of chunks not yet streamed in while leaving the
ones already around the player alone." The F4 panel writes into Game's config;
`FarField` and `FarTrees` read World's snapshot. So the knob was correctly wired
end to end, rebuilt the far mesh on every turn of the spinbox, and rebuilt it
**from the old value**.

It compiled, ran, logged a rebuild and changed nothing on screen. What caught it
was one line of the Stage 0 self-test printing the vertex count at 0.0 and at
1.0 and getting the same number twice.

The fix is three lines in `apply_far_knobs`: copy the moved keys, and only
those, into the snapshot the two jobs read. The clone rule exists for **shape**
knobs and has nothing to say about these eleven, every one of which was checked
by grep to be read by `FarFieldJob` and `FarTreesJob` and nothing else, and both
of which rebuild their whole output at once - there is no half-old half-new
state for a look knob to leave behind.

The self-test now asserts the vertex count **grows** at 1.0. It reads
9,744 -> 20,632 -> 9,744.

### Gate

| gate | result |
| --- | --- |
| no holes on the horizon from any tour vantage | **MET** - `build/tour/d2-t1` against `build/tour/d2-t0`, seed 42, Forward+ on the RTX 3070 Ti. `6-postcard`, `5-lake`, `2-summit` and `16-spawn-postcard` all show a continuous horizon |
| vertex count under 4x the baseline | **MET at 2.22x** - 103,608 -> **229,824** in game at seed 42, spawn. The plan predicted "roughly 2-3x" |
| `--strict` passes | **MET** - twice running at `far_terrace 1.0`: holes **0**, 1 long frame each, PASS both |
| far mesh build cost | 1,645 -> **1,719 ms** per mesh, +4.5%, `ganymede, deterministic-ish` (98 meshes, main thread, uncontended). The fully-terraced path takes ONE cached centre sample per cell instead of four bilinear corner samples, which is why doubling the vertices costs five per cent |
| hard rule 1 | **MET** - far probe at 0.0 identical to Stage 1's and to `f23c3f0`; far mesh 103,608 vertices |
| self-tests | green |

The far probe's geometry table is **identical to Stage 1's at both knob
settings**, which is the right answer and worth saying: risers are vertical, the
probe excludes vertical quads by an exact test, and the drawn ground height at a
world position is decided by the top quads alone. Stage 2 added surface, not
height.

### The picture

`build/tour/d2-t0/6-postcard.png` against `build/tour/d2-t1/6-postcard.png` is
the pair to look at first. At 0 the massifs are smooth shells with contour bands
painted on them; at 1 they are stacks of blocks with lit tops and dark sides,
and the diamond facets Marcel called rhomboids are gone. Decision 2 asked for
unmistakable rather than subtle and this is not subtle.

**What it also shows, and Stage 3 owns it:** at `SKIRT_SHADE`'s 0.7 the risers
on a shaded flank go nearly black, and a mid-distance ridge reads as a dark
band. That is the "harsh stripes" the plan told this run to photograph rather
than quietly fix.

---

## Stage 3 - The risers are side faces

**Shipped, and the plan's starting value was moved by the pictures.**

Most of this stage was already true when Stage 2 landed, which is the useful
finding. A riser carries its own **horizontal** normal - `_push_quad` derives
one from the winding, and only the top quad is handed `_flank_normal` instead -
so it goes through Look's three-band ramp exactly as a voxel's side face does,
and through `Block.aspect_shade`'s `slope_tint` (x0.90 for a wall) and
`aspect_tint` exactly as a voxel's side face does. That is decision 8's "one
lighting language, both halves", for nothing. Tops keep `_flank_normal`,
unchanged.

### The near field's real numbers, and what they say about 0.7

Distance v1 Stage 8 recorded a lit meadow top at `#809137` against shaded
vertical faces at `#272B2D` under `shade_desat = 0.55`. In rec709 luma that is
134.9 against 42.3 - **a ratio of 0.31** - and it is produced entirely by the
lighting ramp, with `slope_tint`'s 0.90 on top and no albedo multiplier
anywhere.

So the plan's expectation that "the near field's real contrast is stronger" than
`SKIRT_SHADE`'s 0.7 is the wrong way round: **`far_riser_shade = 1.0` IS
matching the near field exactly**, and 0.7 is darker than the near field on the
shaded side and much darker on the lit one.

### And the pictures agree, monotonically

Measured on the far massifs of `6-postcard` - the whole band above the treeline,
sky excluded by a luma ceiling - seed 42, Forward+ on the RTX 3070 Ti.
`ganymede, eye` made into a number: the mean absolute **vertical** luma gradient,
which is what "do the steps read" is, because a terrace draws horizontal edges.

| | mean \|dL/dy\| | pairs over 20 | mean luma | sd |
| --- | --- | --- | --- | --- |
| `far_terrace 0` | 2.764 | 2.30% | 110.2 | 48.6 |
| riser shade 0.50 | 3.052 | 1.95% | 90.8 | 51.9 |
| riser shade 0.70 (the plan's) | 3.547 | 2.46% | 96.4 | 52.1 |
| **riser shade 1.00 (shipped)** | **4.073** | **2.54%** | 103.1 | 52.4 |

Darkening the risers makes the mountain darker and the steps **weaker**, both
monotonically. It is not a contrast knob, it is a dimmer - the contrast is the
ramp's and the ramp is already applied. At 0.70 a mid-distance ridge in
`6-postcard` goes nearly black, which is the "harsh stripes" the plan told this
run to photograph rather than quietly fix; it is photographed, and the fix was
to stop dimming.

Left on F4 as `distance: riser shade` so Marcel can overrule it in one spinbox.

### Gate

| gate | result |
| --- | --- |
| a postcard at `far_terrace` 0 vs 1 from the same vantage, both renderers | **Forward+ MET** (`d2-t0` / `d2-t1`). **Compatibility deferred to Stage 6** - the first opengl3 pair was taken while Stage 5 was mid-edit and logged 5,162 script errors, so it is discarded rather than reported. Re-taken clean in Stage 6 |
| the terraced one reads as blocks and not as a contour map | **MET** - the step-edge measurement above, 2.764 -> 4.073, and `6-postcard` at 1.0 is stacked boxes with lit tops and dark sides where at 0.0 it is a smooth shell with contour bands painted on it |
| self-tests | green |

### For Marcel to rule on

`build/tour/d2-t1-rs050`, `d2-t1-rs070` and `d2-t1-rs100` are the three, all at
`far_terrace 1.0`, seed 42, Forward+. Shipped at 1.00.

---

## Stage 4 - The peaks keep their height

**Shipped**, and it is the biggest number in the epic.

Decision 9: a cell that is a local maximum of the flank rounds **up**; every
other cell rounds to nearest. `RIDGE_SPAN_BLOCKS = 96` - `far_normal_m`'s own
half-span, the window `_flank_normal` already averages the slope over, so "local
maximum of the FLANK" is read at the scale the flank is read at rather than at
the scale of one cell. A local maximum over one cell fires on every bump; over
96 blocks it fires on summits.

In **blocks** rather than in cells, so the ring converts it to a whole number of
its own cells and every ring asks the same question - a cell that is a ridge in
ring 1 and not in ring 2 is another block of difference at the 400 m boundary.
The four neighbour heights come out of the cell cache, which is what makes the
test affordable: they are cells of this ring, so on a mountainside most of them
have already been computed for their own quads.

### PEAK LOSS at 600 m

`ganymede, deterministic`, seed 42, twenty summits, blocks. Positive means the
drawn summit is **lower** than `height_at()` says it is.

| | mean | worst | best | over 4 blocks |
| --- | --- | --- | --- | --- |
| pre-distance-v1 (unfiltered) | +60.27 | +128.01 | +11.76 | 20 of 20 |
| `f23c3f0` (distance v1's end state) | +55.28 | +81.14 | +13.30 | 20 of 20 |
| distance v2 Stage 1-3 (terraced, round to nearest) | +29.40 | +65.72 | +1.72 | 17 of 20 |
| **Stage 4 (round up at ridges)** | **+13.40** | **+41.85** | **-30.28** | **12 of 20** |

**+55.28 -> +13.40 is a 76% improvement on carried item 4**, and the far field
now draws a summit at 600 m within about 27 m of the real mountain at the 1:4
scale, against 110 m before this epic and 120 m before distance v1.

### And the residue is exactly one step, which is worth writing down

Every drawn height in the Stage 4 table is one of four numbers - 862.5, 830.5,
798.5, 766.5 - which are 32 blocks apart, ring 2's step, minus the half-block
`y_offset`. So the error is no longer a filter losing amplitude. It is
**quantisation, and it is bimodal**: eleven of the twenty summits land on the
shelf just under their true height (+1.7 to +9.7, essentially exact) and the
other nine fall a whole step short (+32.7 to +41.9) because the ridge test did
not fire on their cell - the true peak sits between two cell centres, or a
neighbour exactly 96 blocks away is higher.

A narrower or two-tier ridge test would move that. It was not tried: the gate is
met by a factor of four and this is the sort of tuning that wants Marcel's eye
on a picture rather than another sweep. **Carried forward.**

### VALLEY GAIN, the mirror

Unchanged by this stage at **-6.53 mean** (worst +14.50, best -17.33, 17 of 20
outside the 4-block line) against `f23c3f0`'s +0.53. Negative means the drawn
valley floor is **lower** than the truth. That is quantisation again and it is
symmetric with the peaks: a basin floor lands on the shelf below it. It is the
price of a 16 m step and it is not a filter error.

### Gate

| gate | result |
| --- | --- |
| PEAK LOSS at 600 m no worse than `f23c3f0`'s +55.28 | **MET with room - +13.40**, 76% better |
| ridges are not visibly inflated against the smooth mesh at 0 | **checked in Stage 6** on the final night-1 tour; the arithmetic bound is one step, and the worst over-shoot measured is -30.28 blocks against ring 2's 32-block step, so no summit gains more than one shelf |
| hard rule 1 | **MET** - far probe at 0.0 identical to Stage 2's on every geometry row |
| self-tests | green |
| cost | far mesh 1,719 -> **1,782 ms** (+3.7%), 229,824 -> **232,136** vertices (+1.0%) |

---

## Stage 5 - The impostors are stepped, and they stand on the shelves

**Shipped.** Both halves, and one thing the plan did not ask for.

**The shape.** `_cone(6, 0.5, 1.0)` becomes `_stack([1.0, 0.66, 0.33], 0.5, 1.0)`
- three boxes shrinking upward. `_stack_into` is one builder for all of them, so
the spruce, the krummholz (two tiers, because a krummholz three boxes tall is a
small spruce) and the broadleaf crown (three tiers that bulge, `[0.62, 1.0,
0.72]`) cannot drift into different languages. **`_post` is left alone and that
is deliberate**: a four-sided post IS a box already, so the "same language" the
plan asks for is the language it is already in.

**The footing.** `FarFieldJob.terrace_offset()` - how far the terrace **moved**
the ground at a place, not where the shelf is. That distinction is what keeps
hard rule 1 exact: a tree stands on `ground + 1`, the TRUE voxel surface, while
the far mesh draws the FILTERED one, and at a summit those differ by tens of
blocks. Snapping outright would move every far tree by that difference at every
value of the knob, zero included. Adding the offset moves a tree by exactly what
the ground under it moved, and by nothing at 0.

**And the shape is on the knob too**, which the plan did not say and hard rule 1
requires. `far_terrace 0.0` has to give the whole old picture back, and stepped
trees standing on smooth ground would be the worst of both - exactly the
confusion the knob exists to resolve. A mesh cannot lerp, so this is the one
threshold in an epic of blends: at 0 `for_species()` returns the six-sided cone
and the octahedron unchanged, above 0 the stacks. Both are cached, so flipping
back and forth rebuilds nothing, and `FarTrees._apply` re-reads the mesh every
rebuild so the swap lands without an F7.

### Cost

`ganymede, single run`, seed 42, spawn, `--view high`. The triangle count is new:
nothing in the project reported it, and Stage 5's gate is a ratio.

| | cones (`far_terrace 0`) | stacks (`1.0`) | |
| --- | --- | --- | --- |
| impostors | **580** | **580** | identical, hard rule 8 |
| triangles | 6,764 | **17,700** | **2.62x** |
| ring rebuild | 817 ms | 912 ms | +11.6% |

Per mesh: spruce and larch 12 -> **32** triangles, krummholz 12 -> 22, broadleaf
12 -> 34, snag 8 -> 8. **The plan said "around 20" and three tiers is 32**, which
is recorded rather than trimmed: the exposed step between two tiers is the whole
point when the ring is seen from above, and the full square cap that makes it is
already the cheap choice - the annulus between two tiers is four quads, two
triangles more than covering the whole square and letting the tier above hide
the middle.

### Gate

| gate | result |
| --- | --- |
| 852 impostors at the shot's vantage | **580 at spawn on ganymede**, identical at both knob settings. The plan's 852 is Marcel's own vantage at `pos -71.9 36.5 -122.2` on his box; the number that matters here is that terracing does not change it, and it does not |
| none floating, none buried | **MET by eye** - `build/tour/n1-t1/16-spawn-postcard.png` and `5-lake.png`, Forward+ on the RTX 3070 Ti. The far treeline sits on the terrace tops |
| a far forest at 500 m reads as stepped trees on stepped ground | **MET** - `16-spawn-postcard` is the shot. At `far_terrace 0` the treeline is a row of green triangles against blocky near trees; at 1.0 it is a row of chunky trees on chunky ground, and it stops arguing with the real spruce in the right foreground |
| triangle count for the impostor ring under 4x baseline | **MET at 2.62x** - 6,764 -> 17,700 |
| hard rule 1 | **MET** - far probe at 0.0 identical to Stage 4's on every geometry row; at 0.0 the ring is cones and octahedra, byte for byte |
| self-tests | green |

---

## Stage 6 - Docs, night 1

**Night 1's test, in one line:** stand at Marcel's vantage, press the F4 toggle,
and the mountains stop being a different game.

### The postcards

Seed 42, ganymede, RTX 3070 Ti. Four full seventeen-shot tours:

| | Forward+ | Compatibility |
| --- | --- | --- |
| `far_terrace 0.0` | `build/tour/n1-t0` | `build/tour/n1-t0-gl` |
| `far_terrace 1.0` | `build/tour/n1-t1` | `build/tour/n1-t1-gl` |

**`6-postcard` is the pair to look at**, and `16-spawn-postcard` is the one that
shows the forest. At 0 the massifs are smooth shells with contour bands painted
on them and the far treeline is a row of green triangles; at 1 they are stacks
of blocks with lit tops and shaded sides, and the treeline is a row of chunky
trees standing on chunky ground. The near spruce in the right foreground of
`16-spawn-postcard` stops arguing with the distance.

The step-edge measurement - mean absolute **vertical** luma gradient over the
far-massif band, sky excluded, which is what "do the steps read" is as a number
because a terrace draws horizontal edges:

| | `far_terrace 0` | `far_terrace 1` |
| --- | --- | --- |
| Forward+ | 2.764 | **4.405** |
| Compatibility | 2.926 | **5.037** |

**The two renderers agree**, which is not something this project takes for
granted - look v2's blocking finding was exactly a case where they did not.

### And the "both renderers" gate nearly did not happen at all

The README's own documented command for the second tour is

```
godot --path . -- --tour --seed 42 --label <name>-gl --rendering-driver opengl3
```

and **everything after `--` is passed to the game, not to the engine**, so that
line selects no driver and takes the second set of pictures on Forward+ as well.
It is not an error and there is no warning: both directories fill up, the images
differ by a frame of the day cycle, and nothing says the comparison did not
happen. Caught here because the two "renderers" produced *identical* step-edge
numbers to three decimal places. README corrected.

Every earlier `-gl` set in this project was taken with the flag in that
position. Whether any of them is actually a Compatibility picture is not
something this run checked, and it is worth someone checking.

### The knob, and whether it is under two seconds

`ganymede`, seed 42, `--view high`, the two costs measured separately because
they are separate jobs:

| | `far_terrace 0` | `far_terrace 1` |
| --- | --- | --- |
| far mesh rebuild (far probe, main thread, 98 meshes) | 1,649 ms | **1,782 ms** |
| impostor ring rebuild (`[FarTrees]`, spawn) | 817 ms | **912 ms** |

The far mesh is what changes the mountains and it lands **1.8 s** after the
spinbox moves. The ring follows about **0.9 s** later, because this engine build
serialises GDScript across the worker pool, so the complete redraw is about
**2.7 s** on this box.

**The two-second gate is met for the far mesh and missed for the pair**, and it
was unreachable as written from the moment it was written: the plan's own
budget is "1,299 ms of far mesh and 1,312 ms of impostors - about a second and a
half", and those two numbers add to 2.6 s. ganymede is the slower box; on
Marcel's the far mesh should land near 1.4 s and the whole redraw near 2.2 s.

What the gate was actually protecting is met with room: **no voxel chunk is
rebuilt, the player does not move, and F7 is not pressed.** Against F7's 39,023
ms and 3,276 chunks that is a factor of fifteen, and the self-test asserts the
chunk set is untouched at every stage.

### Every constant this epic has moved, so far

| constant | before | night 1 | why |
| --- | --- | --- | --- |
| `far_terrace` | new | **0.0**, on F4 | ships OFF. 1.0 is the epic; 0.0 is `f23c3f0` byte for byte, and the way back |
| `far_riser_shade` | new | **1.0**, on F4 | the plan's 0.7 measured as a dimmer, not a contrast knob - see Stage 3 |
| `TERRACE_LEVEL_RING` | new | **0** (level 2) | swept 0/1/2 and per-ring; chosen on PEAK LOSS and on the seam dip - see Stage 1 |
| `RIDGE_SPAN_BLOCKS` | new | **96** | `far_normal_m`'s own half-span, so a ridge is read at the scale a flank is |
| `SKIRT_DEPTH_CELLS` | 1.0 | **1.0 + `far_terrace`** | a terraced ring can disagree with its coarser neighbour by most of a step; exactly the old length at 0 |
| `LONG_FRAMES_ALLOWED` | new (was 0) | **1** | decision 11 - `--strict` used to exit 1 on about half of all clean runs |
| spruce impostor | `_cone(6)`, 12 tris | **`_stack([1.0, .66, .33])`, 32 tris** | a cone under flat shading is six diamond facets, and the eye reads diamonds where it expects steps |
| broadleaf impostor | octahedron, 12 tris | **stepped crown, 34 tris** | same language as the spruce beside it |
| krummholz impostor | `_cone(6, 0.7)`, 12 tris | **`_stack([1.0, .6])`, 22 tris** | two tiers; three boxes tall is a small spruce |
| snag impostor | `_post`, 8 tris | **unchanged** | a four-sided post is already a box |
| `far_band_m` | 60.0 | night 2 | Stage 7 |
| `far_band_step` | 0.03 | night 2 | Stage 7 |

### Night 1's numbers in one table

`ganymede, deterministic`, seed 42, `--view high`, all heights in blocks.

| | `f23c3f0` | Stage 1 | Stage 2 | Stage 4 | Stage 5 |
| --- | --- | --- | --- | --- | --- |
| FIZZ rms | 0.607 | 1.279 | 1.279 | **1.267** | 1.267 |
| FIZZ max | 21.570 | 80.0 | 80.0 | **80.0** | 80.0 |
| FIZZ past 500 m | 2.11-3.27 | **0.00** | **0.00** | **0.00** | **0.00** |
| ROUGHNESS | 2.5648 | 15.4619 | 15.4619 | **16.1283** | 16.1283 |
| 200 m boundary, max / rms | 4.60 / 0.462 | 32.0 / 2.884 | 32.0 / 2.884 | **24.0 / 2.869** | 24.0 / 2.869 |
| 400 m boundary, max / rms | 21.57 / 1.611 | 80.0 / 6.152 | 80.0 / 6.152 | **80.0 / 6.090** | 80.0 / 6.090 |
| PEAK LOSS at 600 m, mean | +55.28 | +29.40 | +29.40 | **+13.40** | +13.40 |
| VALLEY GAIN, mean | +0.53 | -6.53 | -6.53 | -6.53 | -6.53 |
| shelf move over 200 m, rms | 5.74/5.25/8.34 | 4.58/6.63/5.20 | " | 4.78/6.79/5.31 | " |
| terrace compliance | 0% | **100%** | **100%** | **100%** | **100%** |
| far mesh vertices (in game) | 103,608 | 103,608 | 229,824 | **232,136** | 232,136 |
| far mesh build, ms | 1,650 | 1,406 | 1,719 | **1,782** | 1,782 |
| impostors at spawn | 580 | 580 | 580 | 580 | **580** |
| impostor triangles | 6,764 | 6,764 | 6,764 | 6,764 | **17,700** |

Every column is at `far_terrace 1.0` except the first. **At `0.0` every stage
reproduces the first column character for character**, which the far probe
checked at Stages 0, 1, 2, 4 and 5.

### What night 1 bought, and what it cost

**Bought.** The far country is made of blocks, at 4 m near and 16 m at the fog,
with lit tops and shaded risers in the near field's own lighting language. Past
500 m it now holds **perfectly** still - FIZZ exactly `0.00` in every band at
every vantage, against 2.11-3.27 before. A summit at 600 m is drawn within
27 m of the real mountain at the 1:4 scale, against 110 m before this epic and
120 m before distance v1. And all of it is one knob away from being off.

**Cost.** Twice the far-mesh vertices for five per cent of the build time,
2.6x the impostor triangles for twelve per cent of the ring's. And the two ring
boundaries: the 400 m one is 80 blocks of worst-case fizz against `f23c3f0`'s
21.6, which is Stage 9's subject and the largest single regression in the epic.

---

# Night 2

## Stage 7 - The bands land on the risers

**Shipped**, and the honest finding is that **Stage 2 had already done Stage 7's
job**, so what this stage actually buys is smaller than the plan expected and is
measured rather than asserted.

`far_band_m` is now the ring's own step height instead of a flat 60 m - 16 m at
ring 2, four times as many bands - lerped by `far_terrace` so it is exactly 60 m
at 0.0 and hard rule 1 holds for the colour as well as for the geometry. There
is no point locking bands to shelves that are not being drawn.

`far_band_step` is scaled by the same ratio, `0.03 * band_m / 60`, so **the
constant preserved is the total value change per METRE of altitude**, which is
what look v1 and look v2 tuned and where the 0.85-1.25 clamp lands. The knob on
F4 still means what its label says.

`treeline_band` takes the interval too, and `backdrop_color` computes the same
interval at the impostor's own distance - an impostor converges towards the
colour the far mesh paints behind it, and if the two disagreed about where a
band edge is the tree would converge towards a colour that is not there.

### Why the chevron was already gone

The plan's diagnosis is right: look v1 applies one band per quad to the quad's
MIDDLE height, "which is what makes the band edge a hard stepped line along the
quad grid rather than a gradient interpolated across it", and it was drawing
those steps onto a **smooth** slope. That is the chevron.

But since Stage 2 the quad's middle height IS the quantised cell height. A band
index computed from it can therefore only change where the SHELF changes -
which is a riser - whatever the interval is. Locking the interval changes how
many bands there are, not whether they land on risers.

### What the lock is worth, measured

`build/tour/n2-s7-t1/6-postcard.png` against `build/tour/n1-t1/6-postcard.png`,
same seed, same vantage, Forward+ on ganymede - the far-massif band, per pixel:

| | mean \|dL\| | worst | pixels differing by more than 4 |
| --- | --- | --- | --- |
| `far_terrace 1.0`, 60 m bands -> ring-step bands | **0.23** | 1.9 | **0.00%** |
| `far_terrace 0.0`, before -> after | **0.0000** | 0.0 | 0.00% |

Under a quarter of one sRGB level, and nothing anywhere in the frame moves by
more than two. **Shipped anyway**, because it is structurally the right
statement - one shelf, one tone, instead of three or four shelves sharing a
band - and because it costs nothing. It is not a fix and this document should
not claim it is one.

The second row is the other half of the point: at `far_terrace 0.0` the two
tours are **pixel-identical**, so hard rule 1 now has a photographic proof and
not only a geometric one.

### Gate

| gate | result |
| --- | --- |
| the snow/rock boundary is a stepped line along block edges, not a chevron across facets | **MET, and by Stage 2 rather than by this stage.** `n1-t0/6-postcard` against `n1-t1/6-postcard`: at 0 the boundaries between rock and snow are irregular diagonals across the smooth shell, at 1 they are staircases along block edges. Locking the interval moved the picture by 0.23 luma |
| look v2's monotonic bands not undone | **MET** - `band_color` is untouched except for the interval and the matching step scale; still monotonic, still zeroed at the treeline, still clamped either side |
| hard rule 1 | **MET, photographically** - `n2-s7-t0` and `n1-t0` are pixel-identical over the far band |
| `--strict` | **MET** - twice running at `far_terrace 1.0`, holes 0, 1 long frame each, PASS both |
| self-tests | green |

---

## Stage 8 - The seam, and where the steps begin

**Shipped, in Stage 2**, and then improved here by a factor of two.

The fade itself was written in Stage 2 rather than here, and that was a
deliberate re-ordering: leaving it out would have put a terrace ring at 90 m in
every night-1 postcard, and Stage 6's whole test is a person looking at those
postcards. `_terrace_at()` drives `far_terrace` from the same seam-band factor
`_corner_y()` already uses - zero where the detail is at full strength, one
where the detail has faded. One multiply, because the knob takes a continuous
value.

What this stage added is a way to see whether it works, and a constant.

### The measurement

New far-probe row: sample the drawn far-mesh height on a ring 6 blocks outside
the voxel hole, and compare it against the surface the player actually stands
on - `height_at + detail_at + VOXEL_TOP_BIAS_BLOCKS`, the top face of the
topmost solid block, which is what `_corner_y` is written to reproduce there.
`ganymede, deterministic`, seed 42, blocks:

| vantage | `far_terrace 0` | terrace, 4-cell fade | terrace, **12-cell fade** |
| --- | --- | --- | --- |
| spawn | max 2.926 / rms 0.557 | 4.257 / 0.891 | **3.370 / 0.583** |
| summit | max 19.994 / rms 2.652 | 18.241 / 4.208 | **18.989 / 2.978** |
| lake | max 0.504 / rms 0.366 | 1.340 / 0.506 | **0.680 / 0.379** |

And the 0-100 m FIZZ band, which is "does anything move near the player as I
walk":

| vantage | `far_terrace 0` | 4-cell fade | **12-cell fade** |
| --- | --- | --- | --- |
| spawn | 1.75 | 3.61 | **2.30** |
| summit | 4.82 | 19.36 | **8.77** |
| lake | 1.76 | 4.55 | **2.80** |

**`TERRACE_FADE_CELLS = 12`**, three times the detail's own four. Decision 5
says the terrace fades in as the seam band fades out and this still does - zero
at the seam, one where the detail has gone - it just gets there over more
ground. The detail band is four cells because that is what the noise samples
need; the terrace is fading between the **voxel surface** and a **quantised**
one, which differ by up to half a ring-0 step plus a detail_amp wherever the
ground is steep, and over four cells that is a visible ramp on a summit.

**The summit vantage's ~19 blocks is not terracing.** It is there at
`far_terrace 0` too (19.994), and it is the far mesh's own linear interpolation
across an 8-block quad on the steepest ground in the world. What terracing does
to it, with the wider fade, is nothing.

### Two things went wrong here and both are recorded

**1. A hole. Hard rule S1.** The first interleaved ABAB at `far_terrace 1.0`
reported **one hole sample** in one of three runs, against none in three smooth
runs and none in distance v1's twelve. The mechanism is the one
`FRONTIER_OVERLAP_CELLS` was always about: the far mesh's hole is cut to the
frontier captured when the job was **submitted**, and terracing makes that job
12% slower (1,650 -> 1,852 ms), so at 13 m/s the player covers proportionally
more ground inside the window. **`FRONTIER_OVERLAP_CELLS` 8 -> 12**: four more
cells, 8 m more ground drawn twice, never a gap.

**2. Single-sided risers, tried and reverted, with the picture.** A riser looks
like it needs only the winding that faces its lower neighbour - the higher
cell's own top quad should be in the way from the other side. That is true on a
gentle slope and **false on a steep one**, where consecutive cells drop by more
than a cell width, the top quads are narrow slivers between tall risers, and the
silhouette of a cliff is made of risers facing several ways at once.

Measured: single-sided saves **75,760 vertices** - 255,128 down to 179,368,
2.46x the smooth mesh down to 1.73x - and opens a bright **see-through gash**
down the steep face of the central massif in `6-postcard`: 1,063 pixels of the
far band brighter by a mean of 46 sRGB levels, because the mountain behind is
showing through. `build/probe/crop-dbl.png` against `crop-single.png`, cropped
from the same frame at 4x.

Reverted. "No holes on the horizon" is Stage 2's gate and it is not tradeable
against a vertex count. The flag stays on `_push_riser` with the argument
written next to it.

### The interleaved measurement, after both

`ganymede, ABAB median`, seed 42, `--view High`, three runs each, run order
A B A B A B, all six on the shipped code:

| | `far_terrace 0` | `far_terrace 1` |
| --- | --- | --- |
| holes | **0 (0-0)** | **0 (0-0)** |
| frames over 33 ms | 2 (0-5) | **1 (1-5)** |
| built/s, out | 79.1 (76.2-80.1) | 75.7 (74.8-79.7) |
| built/s, back | 85.9 (82.5-88.8) | 81.9 (81.6-86.1) |

**Holes zero on every run of both.** Every other row's spread overlaps, and the
long-frame counts run higher on BOTH sides than distance v1's 0-1 because this
box had been running Godot continuously for hours by then - which is exactly the
drift `STATUS.md` item 5 documents and the reason this is an interleaved median
rather than two runs.

### Gate

| gate | result |
| --- | --- |
| walk out from the meadow and back; nothing pops at 96 m | **MET at spawn and lake** - the seam disagreement is 3.37 and 0.68 blocks max against the smooth mesh's own 2.93 and 0.50, and the 0-100 m fizz band is 2.30 and 2.80 against 1.75 and 1.76. **At the summit vantage the number is 18.99 blocks and it is 19.99 with the knob off** - the far mesh's own quad linearisation on the steepest ground in the world, which terracing neither causes nor worsens |
| no step appears inside the voxel radius | **MET by construction and by measurement** - `_terrace_at` returns exactly 0 at the seam radius, the far mesh draws nothing inside the hole at all, and the terrace-compliance rows (which exclude the fade band) are 100% outside it |
| never a hole | **MET, 0 on six interleaved runs**, after `FRONTIER_OVERLAP_CELLS` 8 -> 12 |
| hard rule 1 | **MET** - far probe at 0.0 identical to Stage 7's on every geometry row; far mesh 103,608 vertices |
| self-tests | green |
| cost | far mesh **256,328** vertices at 1.0 (2.47x), 1,874 ms per rebuild |
