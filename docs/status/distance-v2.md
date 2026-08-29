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
runs and none in distance v1's twelve. The plausible mechanism is the one
`FRONTIER_OVERLAP_CELLS` was always about: the far mesh's hole is cut to the
frontier captured when the job was **submitted**, and terracing makes that job
12% slower (1,650 -> 1,852 ms), so at 13 m/s the player covers proportionally
more ground inside the window.

**Four more cells of overlap looked like the fix, were shipped, and were wrong
twice over.** The merge to `main` caught it - see "The constant that looked like
a fix and made the instrument lie" below, which is the most instructive mistake
in the epic. The constant is back at 8 for both settings, and the honest number
is at the end of this stage.

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
| never a hole | **0 of 11 runs at `far_terrace 0.0`. 1 of 7 at 1.0.** Not met as a proof at 1.0 and not refuted either - see "The honest hole number" above. At the shipped default it is met on every run ever taken |
| hard rule 1 | **MET after the correction below.** As first written this stage broke it - see the next section |
| self-tests | green |
| cost | far mesh **255,128** vertices at 1.0 (2.46x), 1,852 ms per rebuild |

### The constant that looked like a fix and made the instrument lie

Found while merging to `main`, from the one line the WORLD prints at load. Two
mistakes in one constant, and the second is one the neighbouring file already
warns about in as many words.

The four extra cells of overlap were first spent by raising
`FRONTIER_OVERLAP_CELLS` from 8 to 12.

**Mistake one: it broke hard rule 1, and the far probe could not see it.** The
constant is not gated on `far_terrace`, so it moved the far mesh's inner edge at
**every** value of the knob, and `far_terrace 0.0` quietly stopped being
`f23c3f0`:

| in-game far mesh at `far_terrace 0.0` | vertices |
| --- | --- |
| `f23c3f0`, and Stages 0-7 | **103,608** |
| Stage 8 as first written | **104,808** |
| now | **103,608** |

The far probe **builds `FarFieldJob` with an empty `frontier`**, so
`_sector_exclude` is never filled and this constant is dead code to it. Seven
stages of "identical on every geometry row" were all true and said nothing about
the one thing that had changed. That is a different instrument failure from
distance v1's aliased probe - not measuring the wrong thing, but being
structurally blind to a whole input - and it belongs beside it.

**Mistake two: gating the extra on `far_terrace` broke the probe instead.** The
obvious repair is a second constant added only while terracing, so 0.0 goes back
to `f23c3f0`. That was written, and it made the stream probe report **two hole
samples that were not there** - because `scripts/world/world.gd` reads
`FarFieldJob.FRONTIER_OVERLAP_CELLS` to decide whether a column is covered, and
`far_field_exclusion_m()` says exactly what happens when it and the job disagree:

> THE SAME CONSTANT THE JOB CUT THE MESH WITH. Keeping a second copy of it here
> is how the probe came to report 21 holes that were not there: the job had
> widened its overlap and this had not.

Raising it also changed the behaviour of a file this epic is not allowed to
touch, **through a shared constant rather than an edit** - the lane rule broken
by arithmetic, which no diff would have shown.

**So it stays at 8, for both settings.** Whether terracing costs a real hole is
then measured with the job and world.gd in step, which is the only way the
number means anything.

### The honest hole number

`ganymede`, seed 42, `--view High`, matched overlap, interleaved:

| | runs | hole samples |
| --- | --- | --- |
| `far_terrace 0.0` | **11** | **0** |
| `far_terrace 1.0` | **7** | **1** |

One sample, in one run, on a probe that samples four times a second through a
480 m sprint. Distance v1 saw 0 in twelve at this setting. **It is not enough to
call either way**, and it is written down as a number rather than as a fix.
`far_terrace` ships at 0.0, where the count is 0 of 11 and has never been
anything else.

---

## Stage 9 - The 400 m boundary, measured

**The claim this stage exists to test:**

> the power-of-two step ladder may have removed it without a geomorph. Every
> 16 m shelf is also an 8 m shelf, so a mountain crossing 400 m should
> subdivide its shelves rather than move them, and there is nothing left to
> re-cut.

**Verdict: UNCHANGED-OR-WORSE as shipped, and the plan's reasoning is right
anyway.** The step ladder is not what breaks it. Something else is, it was
found by measurement, and the fix is one line - which this stage does not ship,
because of what it would cost elsewhere.

### The number

`ganymede, deterministic`, seed 42, max and rms FIZZ over a 50 m window
straddling each boundary, blocks:

| | 200 m max / rms | 400 m max / rms |
| --- | --- | --- |
| `far_terrace 0.0` (= `f23c3f0`) | 4.60 / 0.462 | **21.57 / 1.611** |
| `far_terrace 1.0` (shipped) | 24.00 / 2.869 | **80.00 / 6.090** |

The 400 m boundary is **3.7x worse on the max and 3.8x worse on the rms**. It is
the largest single regression in this epic, and it is exactly the artefact
carried item 3 is about.

### Why, and it is not the step ladder

Two experiments, each a five-line change to `_cell()` / `_cell_h()`, each run
through the whole far probe at `far_terrace 1.0`. Neither is shipped; both are
in `build/probe/s9-expA.txt` and `s9-expB.txt`.

| | 200 m max | **400 m max** | 400 m rms | FIZZ max, whole disc |
| --- | --- | --- | --- | --- |
| `f23c3f0`, smooth | 4.60 | **21.57** | 1.611 | 21.570 |
| shipped: each ring quantises **its own** height at **its own** step | 24.00 | **80.00** | 6.090 | 80.000 |
| **A**: every ring at the **same step** (32 blocks), each sampling its own cell centre | 32.00 | **96.00** | 5.888 | 96.000 |
| **B**: every ring at the **same sample point** (the 32-block cell centre), each at its own step | 8.00 | **16.00** | 4.259 | **21.404** |

**Experiment A makes it worse. Experiment B all but removes it** - 16 blocks at
the 400 m boundary against `f23c3f0`'s 21.57, and a whole-disc FIZZ max of
21.404, also under the smooth mesh's.

So the plan's claim is **correct about the step ladder and wrong about what was
breaking the boundary**. Making the two rings quantise to the same set of
heights (A) does nothing; the shelves were never moving because 32 is not a
multiple of 16. They were moving because **the two rings sample the cell height
at different world points** - ring 1 at the centre of a 16-block cell, ring 2 at
the centre of the 32-block cell containing it, which are up to 8 blocks apart,
and on a mountain flank 8 blocks of horizontal offset is tens of blocks of
height before anything is quantised at all.

The subset property is real. It applies to the SET of heights a cell may land
on, not to which one it picks, and which one it picks is decided by where the
sample was taken.

### Why Experiment B is not shipped

Because the sample point every ring would have to share is **the coarsest
ring's**. Ring 0's 4 m cells and ring 1's 8 m cells would then all read the same
height as the 16 m cell containing them, and the far country would be made of
**16 m blocks at every range** - at 100 m as much as at 900. That is the direct
contradiction of this epic's own one-sentence idea, "bigger blocks the further
away you go", and it would flatten the near half of the far field where the LOD
is spending its vertices precisely to avoid that.

There is no finer shared grid: ring 0's cell centres sit at multiples of 8 plus
4, ring 1's at multiples of 16 plus 8, ring 2's at multiples of 32 plus 16, and
no two of those coincide anywhere. Sharing a sample point means sharing the
coarsest one.

**What would get both** is a geomorph, and the plan is explicit that this stage
does not build one - but the measurement changes what a geomorph has to do.
It does not have to blend two surfaces: it has to blend the SAMPLE POSITION
across the boundary, which is a much smaller thing. Over the last cell or two of
ring 1, move the cell-height sample from the ring-1 centre to the ring-2 centre.
Both surfaces are then continuous into the boundary and the subset property
does the rest. That is the shape of it, written down here so the next plan does
not start from "blend the two rings' surfaces".

### Gate

| gate | result |
| --- | --- |
| a FIZZ-max number at the 400 m boundary for both knob settings, in the status doc, with the verdict written out | **MET.** 21.57 at `far_terrace 0.0`, **80.00** at 1.0, plus rms for both, plus the two experiments that say why |
| carried item 3 | **stays open, and is now a different ticket.** Not "the ring boundary is the loudest thing the probe sees, and the fix is a geomorph of the surfaces" but "the two rings sample the cell height 8 blocks apart, and the fix is a geomorph of the sample POSITION". Experiment B is the proof that closing it closes the boundary: 16 blocks, under the pre-epic 21.57 |

---

## Stage 10 - Docs, night 2

### The postcards, final

Seed 42, ganymede, RTX 3070 Ti. `far_terrace 0.0` is pixel-identical at every
stage of this epic, so the two `t0` sets stand for all of them.

| | Forward+ | Compatibility |
| --- | --- | --- |
| `far_terrace 0.0` | `build/tour/n1-t0` | `build/tour/n1-t0-gl` |
| `far_terrace 1.0`, shipped | **`build/tour/final-t1`** | **`build/tour/final-t1-gl`** |

Step-edge strength on `6-postcard`'s far-massif band - mean absolute vertical
luma gradient, sky excluded:

| | `far_terrace 0` | `far_terrace 1` |
| --- | --- | --- |
| Forward+ | 2.764 | **4.428** |
| Compatibility | 2.926 | **5.033** |

Also on disk, all `far_terrace 1.0`, Forward+, seed 42:

| tour | what it shows |
| --- | --- |
| `d2-t1-rs050`, `d2-t1-rs070`, `d2-t1-rs100` | `far_riser_shade` at 0.50, 0.70 and 1.00 |
| `n1-t1` | night 1's end, before the band lock and the wider seam fade |
| `n2-s7-t1` | Stage 7, the band lock, against `n1-t1` |
| `n2-t1-dbl` vs `n2-t1` | double-sided against single-sided risers - `build/probe/crop-dbl.png` and `crop-single.png` are the 4x crop that decided it |

### Every constant this epic moved

| constant | `f23c3f0` | shipped | why, in one line |
| --- | --- | --- | --- |
| `far_terrace` | - | **0.0**, on F4 | ships OFF; 1.0 is the epic and 0.0 is the way back |
| `far_riser_shade` | - | **1.0**, on F4 | the plan's 0.7 measured as a dimmer, not a contrast knob |
| `TERRACE_LEVEL_RING` | - | **0** (pyramid level 2) | swept 0/1/2/per-ring; chosen on PEAK LOSS and the seam dip |
| `RIDGE_SPAN_BLOCKS` | - | **96** | `far_normal_m`'s half-span: a ridge read at the scale a flank is |
| `TERRACE_FADE_CELLS` | - | **12** | three times the detail's fade; halves the seam artefact |
| `FRONTIER_OVERLAP_CELLS` | 8 | **8, unchanged** | raised to 12 in Stage 8 and reverted at merge time: it broke hard rule 1 and, gated, made the hole probe lie |
| `SKIRT_DEPTH_CELLS` | 1.0 | **1.0 + `far_terrace`** | a terraced ring can disagree with its coarser neighbour by most of a step |
| `far_band_m` | 60.0 | **lerp(60, ring step, `far_terrace`)** | decision 7; 16 m at ring 2, exactly 60 at knob 0 |
| `far_band_step` | 0.03 | **0.03 x band_m / 60** | the constant preserved is the value change per METRE |
| `LONG_FRAMES_ALLOWED` | (0) | **1** | decision 11 |
| spruce / larch impostor | `_cone(6)`, 12 tris | **`_stack([1, .66, .33])`, 32 tris** | a cone under flat shading is six diamond facets |
| broadleaf impostor | octahedron, 12 tris | **stepped crown, 34 tris** | the same language as the spruce beside it |
| krummholz impostor | `_cone(6, .7)`, 12 tris | **`_stack([1, .6])`, 22 tris** | two tiers; three boxes tall is a small spruce |
| snag impostor | `_post`, 8 tris | **unchanged** | a four-sided post is already a box |

Everything above is per-machine LOOK. **`PROPERTIES` and `hash_key()` are
untouched**, so nothing this epic added crosses the network or can refuse a
join.

### The whole table

`ganymede, deterministic`, seed 42, `--view high`, blocks.

| | `f23c3f0` | S1 | S2 | S4 | S5 | S7 | **S8 (shipped)** |
| --- | --- | --- | --- | --- | --- | --- | --- |
| FIZZ rms | 0.607 | 1.279 | 1.279 | 1.267 | 1.267 | 1.267 | **1.261** |
| FIZZ max | 21.570 | 80.0 | 80.0 | 80.0 | 80.0 | 80.0 | **80.0** |
| FIZZ past 500 m | 2.11-3.27 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | **0.00** |
| FIZZ 0-100 m (spawn/summit/lake) | 1.75/4.82/1.76 | 3.61/19.36/4.55 | " | " | " | " | **2.30/8.77/2.80** |
| ROUGHNESS | 2.5648 | 15.46 | 15.46 | 16.13 | 16.13 | 16.13 | **16.04** |
| 200 m boundary max/rms | 4.60/0.462 | 32.0/2.884 | " | 24.0/2.869 | " | " | **24.0/2.869** |
| 400 m boundary max/rms | 21.57/1.611 | 80.0/6.152 | " | 80.0/6.090 | " | " | **80.0/6.090** |
| PEAK LOSS at 600 m | +55.28 | +29.40 | +29.40 | +13.40 | +13.40 | +13.40 | **+13.40** |
| VALLEY GAIN | +0.53 | -6.53 | -6.53 | -6.53 | -6.53 | -6.53 | **-6.53** |
| seam vs voxel surface, max | 2.93/19.99/0.50 | - | - | - | - | 4.26/18.24/1.34 | **3.37/18.99/0.68** |
| shelf move over 200 m, rms | 5.74/5.25/8.34 | 4.58/6.63/5.20 | " | 4.78/6.79/5.31 | " | " | **4.78/6.85/5.31** |
| terrace compliance | 0% | 100% | 100% | 100% | 100% | 100% | **100%** |
| far mesh verts, in game | 103,608 | 103,608 | 229,824 | 232,136 | 232,136 | 232,136 | **255,128** |
| far mesh build, ms | 1,650 | 1,406 | 1,719 | 1,782 | 1,782 | 1,830 | **1,852** |
| impostors at spawn | 580 | 580 | 580 | 580 | 580 | 580 | **580** |
| impostor triangles | 6,764 | 6,764 | 6,764 | 6,764 | 17,700 | 17,700 | **17,700** |

Every column but the first is `far_terrace 1.0`. **At 0.0 every stage reproduces
the first column character for character**, checked by the far probe at Stages
0, 1, 2, 4, 5, 7 and 8, and pixel-for-pixel in the tour at Stage 7.

### Gates, both nights

| gate | result |
| --- | --- |
| heightmap hash | **`76cccdb6`** - unchanged, hard rule 7 |
| spawn | **(-44, -124)** |
| trees | **28,383** |
| config hash | **`3d45b8fc`** |
| impostors at spawn, both knob settings | **580 / 580** - hard rule 8 |
| self-tests | **green at the end of every stage** |
| far probe determinism | **PASS**, tables IDENTICAL over two runs, at every stage and both knob settings |
| hard rule 1 - 0.0 is `f23c3f0` | **MET at every stage**, geometrically and photographically |
| hard rule 2 - no player term in the quantisation | **MET after Stage 1's second attempt**, and the rule needed restating: nothing the quantisation READS may depend on the player either |
| hard rule 3 - powers of two across rings | **MET**, 8 / 16 / 32 blocks, 100% compliance |
| hard rule 4 - tops keep `_flank_normal` | **MET**, only risers take a side-face treatment |
| hard rule 5 - `scripts/character/` and `world.gd` untouched | **MET**, neither file appears in any diff |
| hard rule 6 - `look.gd` append-only, `figure_material()` unmodified | **MET - `look.gd` was not touched at all.** Stage 3 turned out not to need it: a riser already carries a horizontal normal and goes through the existing ramp |
| hard rule 7 - heightmap hash unchanged | **MET** |
| hard rule 8 - same seed, spawn, tree count | **MET** |
| hard rule S1 - never a hole | **MET at the shipped default** - 0 samples over 11 runs at `far_terrace 0.0`. At 1.0 it is **1 sample over 7 runs**, which is neither a pass nor a failure at that sample size. Carried forward |
| `--strict` | **PASS** at Stages 0, 2 and 7; at Stage 8 the interleaved ABAB is the number, and holes are 0 on all six |
| vertex count under 4x | **MET at 2.46x** |
| impostor triangles under 4x | **MET at 2.62x** |

### Gates that could not be met as written, all four in one place

1. **Stage 1, "walk 200 m and back; a named shelf does not change height."** A
   named shelf does move, at a ring boundary. The honest comparison is that over
   a 200 m walk the terraced far field moves rms 4.78 / 6.85 / 5.31 blocks
   against the smooth mesh's own 5.74 / 5.25 / 8.34 - **less, on average, than
   the game already did** - and inside a ring it does not move at all, FIZZ
   past 500 m being exactly `0.00` against 2.11-3.27.
2. **Stage 5, "852 impostors at the shot's vantage."** 580 at spawn on
   ganymede; 852 is Marcel's own vantage on his box. What the gate is really
   about - that terracing does not change the count - is met exactly.
3. **Stage 6, "the far country redraws in under two seconds."** The far mesh
   does, at 1.87 s. The impostor ring follows 0.9 s later because this engine
   build serialises GDScript across the worker pool, so the complete redraw is
   about 2.7 s on this box. **The gate was unreachable as written from the
   moment it was written**: the plan's own budget is "1,299 ms of far mesh and
   1,312 ms of impostors - about a second and a half", and those add to 2.6 s.
   What the gate protects - no reroll, no chunk rebuilt, the player standing
   still - is met with a factor of fifteen to spare.
4. **Stage 9, the 400 m boundary.** Measured, verdict written out, and worse:
   80.00 against 21.57. The stage's own gate ("a number and a verdict") is met;
   the hope behind it is not.

### What night 2 did not do

- **`look.gd` was never opened.** The one file this epic was most likely to
  collide with the character lane on. Stage 3 was expected to append a riser
  shade helper and did not need to.
- **No geomorph**, as the plan instructs. Stage 9 measured what one would have
  to do instead, which is a smaller thing than the plan assumed.
- **`far_zone_cell_m` and the zone thresholds were not touched.** The snow/rock
  boundary is a ZONE boundary, drawn on the zone-cell grid; terracing moved the
  altitude bands onto risers and left the zone fields where look v1 put them.
- **The flora density ramp**, decision 15 - `World._flora_fraction_for()` is
  another lane's file and this epic did not open `world.gd`.

### For Marcel to rule on

1. **`far_terrace`, the whole epic.** `build/tour/final-t1` against
   `build/tour/n1-t0`, and the same pair on Compatibility. Shipped at **0.0** -
   this is your call to make, not a default anyone should assume.
2. **`far_riser_shade`, three ways.** `d2-t1-rs050` / `d2-t1-rs070` /
   `d2-t1-rs100`. Shipped at **1.00**, which is the near field's own ratio; the
   plan's 0.70 is on disk and it is darker, not more contrasty.
3. **`far_band_step` after the lock.** Shipped at **0.03** with the interval
   scaled, which preserves the value change per metre exactly. `n2-s7-t1`
   against `n1-t1` is what the lock is worth: 0.23 sRGB levels.

### Carried forward

Everything below is measured, not suspected.

#### This epic owns these six

1. **The 400 m ring boundary is 3.7x worse with the terrace on** - 80.00 max
   against `f23c3f0`'s 21.57 - and Stage 9 found the mechanism and the fix.
   **It is not the step ladder.** Two rings quantising to the same set of
   heights changes nothing (experiment A, 96.00); two rings sampling the cell
   height at the same world point all but removes it (experiment B, **16.00**,
   under the pre-epic number). What a geomorph has to blend is the SAMPLE
   POSITION over the last cell or two of the finer ring, not the two surfaces.
2. **PEAK LOSS's residue is bimodal at exactly one ring-2 step.** Eleven of the
   twenty summits land within +1.7 to +9.7 blocks of the truth; the other nine
   fall +32.7 to +41.9 short because the 96-block ridge test did not fire on
   their cell. A narrower or two-tier test would move it. The gate is met by a
   factor of four, so this is taste, and it wants an eye on a picture rather
   than another sweep.
3. **The far mesh is 2.46x the vertices at `far_terrace 1.0` and its upload runs
   on the main thread.** Single-sided risers would take that to 1.73x and tear a
   see-through gash down every steep face (Stage 8, with the crop). Getting both
   needs a genuinely watertight shell - one face per boundary, wound outward,
   with the solid below actually closed - which is a mesher change and not a
   constant.
4. **VALLEY GAIN is now -6.53 blocks** against `f23c3f0`'s +0.53: a basin floor
   lands on the shelf below it, symmetrically with the peaks. It is the price of
   a 16 m step and not a filter error, and nobody has looked at whether a valley
   floor drawn 3 m low reads badly.
5. **One hole sample in seven terraced runs, and nobody knows if it is real.**
   0 of 11 at `far_terrace 0.0`, 1 of 7 at 1.0, at a matched overlap. Distance
   v1 saw 0 of 12. The plausible mechanism is that terracing makes the rebuild
   12% slower and the hole is cut to a frontier captured a rebuild earlier, but
   the obvious remedy - more overlap - cannot be spent without either breaking
   hard rule 1 or putting the job and `world.gd` out of step, and both were
   tried. Wants more runs, or a frontier the far probe can actually set.

6. **`TERRACE_LEVEL_RING` is a taste knob that is a `const`.** Three values were
   swept and the table is in Stage 1; the shipped one is best on PEAK LOSS and
   on the seam and worst on the 400 m boundary. If (1) is ever fixed, this
   should be re-swept, and it may want to be on F4.

#### Method

7. **The far probe is blind to the frontier.** It builds `FarFieldJob` without
   setting `frontier`, so `_sector_exclude`, `FRONTIER_OVERLAP_CELLS` and the
   whole per-sector hole are dead code to it - and a Stage 8 change to exactly
   that shipped through seven "identical on every geometry row" checks before
   the merge to `main` caught it from the world's own load line. Either the
   probe should take a frontier, or the vertex count the WORLD prints should be
   a gate in its own right. The second is nearly free.

8. **The `-gl` half of every "both renderers" check in this project may not have
   happened.** `--rendering-driver` after the `--` is passed to the game, not to
   the engine, and selects nothing, with no error. The README is corrected and
   distance v2's own pair was re-taken; **no earlier epic's `-gl` set has been
   checked.**
9. **The knob's full redraw is 2.7 s on ganymede**, not the plan's two seconds -
   1.87 s of far mesh and 0.9 s of impostor ring, serialised because this engine
   build runs one GDScript task at a time. Halving either would need the job
   itself to get cheaper, which is the GDExtension conversation.

#### Untouched by this epic, and still open exactly as distance v1 left them

- **1. The meadow tufts read as gravel.** A look pass, unchanged.
- **2. `shade_desat` is the mechanism under (1).** Not argued with.
- **5. FIZZ rms is 63% worse than pre-epic** (0.373 -> 0.607). Still true at
  `far_terrace 0.0`, which is what that item measures. Worth one line of
  precision: at 1.0 the mechanism it names - a mip level continuous in
  distance-from-player - **does not apply to the terraced surface at all**,
  which is why FIZZ past 500 m is exactly zero; the 1.261 rms at 1.0 is ring
  boundaries instead, which is item (1) above.
- **7. Ring rebuild time is still not in the stream probe's report.** This epic
  added a triangle count to `FarTrees.stats()` and a printed line, and did not
  touch the stream probe's table.
- **8. A continuous flora density ramp belongs in
  `World._flora_fraction_for()`**, which is still another lane's file. Decision
  15.
- **9. `debug_hud.gd` reaches into `world.get_node_or_null("FarField")`**, and
  **this epic added a second such reach** - `FarField.apply_far_knobs()` finds
  the node the same way, for the same reason. If `world.gd` ever gains a
  `far_field()` accessor, there are now two call sites for it.

### The one number to lead with

It is not FIZZ and it is not PEAK LOSS, though PEAK LOSS is the best number in
the epic: **+55.28 blocks of lost summit at 600 m down to +13.40**, which is a
mountain drawn 27 m short instead of 110 m short at the real scale.

It is that a person standing in the valley can move one number on F4, without
moving and without pressing F7, and watch the background stop being a different
game. `build/tour/final-t1/6-postcard.png` against
`build/tour/n1-t0/6-postcard.png` is that, on this box, on both renderers.
