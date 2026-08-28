# Distance v2 - the far country is made of blocks too

Distance v1 fixed what the far country is *coloured*. This one fixes what it is
*made of*.

The complaint that opened this plan, in Marcel's words on 2026-08-28, looking at
a night shot from the valley floor at `pos -71.9 36.5 -122.2`:

> I love the fact that you can see the mountains, you can see the snow, but it
> feels still like it's a different game. [...] It feels like it's two separate,
> same art style game, but one is a cube based game, and the other one is just
> sort of an edge based vector game.

That is the correct diagnosis, and the code agrees with it exactly:

- A **near tree** is a trunk block with a cone of LEAF VOXELS stacked on it -
  `tree_species.gd`, a staircase.
- A **far tree** is a literal six-sided smooth cone, six triangles -
  `far_tree_meshes.gd`. Its own header says the shapes were "chosen purely by
  outline - a cone is a conifer [...] and every triangle that does not change
  the outline is a triangle spent on nothing."
- **Near terrain** is cubes. **Far terrain** is a smooth surface draped over
  height samples, `_build_ring` emitting one bilinear quad per cell.

So the far field was built to match the near field's **silhouette**, and it
succeeds - a cone does read as a conifer at 400 m. It was never built to match
its **surface**, and that is the thing you can feel and cannot name. Marcel's
"rhomboid" is precise, not vague: a six-sided cone under flat shading gives big
diamond facets, and the eye reads diamonds where it expects steps.

**The fix, in one sentence: make the far world out of blocks too, just bigger
blocks the further away you go.**

Written 2026-08-28 after a fifteen-question session with Marcel, from the shot
`Screenshot 2026-08-28 161152.png` taken at `f23c3f0` on his box. Every decision
below is his; every number is a starting value. Two nights, one branch:
`feat/distance-v2`, from `main` at `f23c3f0` (distance v1 merged, both nights).

**Night 1 is everything visible** (Stages 0-6) - terrain and trees both change,
so the whole idea can be judged in one sitting. **Night 2 is polish** (Stages
7-10) - the seams, the boundary, the bands and the gate.

---

## The thing distance v1 already half-built

Three findings from reading `far_field_job.gd`, all of which make this cheaper
than it sounds. They are the reason this is a two-night plan and not a rewrite.

### 1. The colour already terraces. The geometry does not.

`far_band_m = 60.0`, `far_band_step = 0.03`. Every 60 m of altitude the far
mesh steps its value, applied once per quad to the quad's middle height - and
the header says why, deliberately: "which is what makes the band edge a hard
stepped line along the quad grid rather than a gradient interpolated across it."

So the colour is already drawing contour steps. It is drawing them onto a
*smooth* slope, which is why the band edge wanders along the triangle grid.
**That is the chevron zigzag where snow meets rock in Marcel's shot.** The
colour says terraced, the shape says smooth, and the two fight.

Terrace the geometry on the same interval and the band edges land exactly on
the risers. The machinery exists; Stage 7 is mostly setting one constant equal
to another.

### 2. The riser machinery already exists, and it is called a skirt.

`_push_skirt(e[0], e[1], skirt_drop, shaded, ...)` already emits a vertical quad
hanging off a cell edge, drawn darker at `SKIRT_SHADE = 0.7`, with the reasoning
that "a crack that lights up BRIGHTER than the terrain around it draws the eye
straight to the artefact it is there to hide."

**A step riser is a skirt whose depth is the height difference to the neighbour
instead of a fixed drop.** The edge loop in `_build_ring` already walks the four
neighbours and already knows their cell offsets. Stage 2 changes what depth is
passed, not how a vertical quad gets built.

### 3. A terraced top quad is already a voxel top face.

From the corner-order comment in `_build_ring`: "the +Y face order from
ChunkMesher, which is clockwise seen from above - the same winding the voxels
use, so both are lit and culled identically."

The far mesh has been emitting quads in voxel winding since terrain v1. Flatten
one and it *is* a block's top face, at sixteen metres instead of half of one.

---

## What was decided

Fifteen answers, 2026-08-28. Each is Marcel's; the reasoning is recorded so a
later plan does not reopen a settled question.

| # | Decision | |
| --- | --- | --- |
| 1 | Terrain and trees in **one epic** | the two halves are one complaint |
| 2 | **Unmistakably chunky**, not subtle | subtle lands back in the uncanny middle |
| 3 | It **jumps the queue** again | same case as distance v1: pillar 3 |
| 4 | **Cubic lock** - step height = cell width | a shelf wider than it is tall is a rice terrace, not a block |
| 5 | Terracing **fades in as the seam band fades out** | never both fixes on the same ground |
| 6 | Impostors are **stepped pyramids**, ~20 tris | kills the rhomboid facets, same cost class |
| 7 | `far_band_m` **locked to the step height** | band edges become risers |
| 8 | Tops lit, **risers shaded** as voxel side faces | one lighting language, both halves |
| 9 | **Round up at ridges**, nearest elsewhere | summits keep their height |
| 10 | **Attempt** the 400 m boundary | the subset property may kill it for free |
| 11 | `--strict` **allows one long frame** | carried item 6, settled |
| 12 | Far step is **16 m** - the ring's own cell | bold, and costs no extra vertices |
| 13 | Judged by a **live F4 toggle** | flip it standing still; also the way back |
| 14 | Night 1 is **everything visible** | see the whole idea in one sitting |
| 15 | **No** flora density ramp | carried item 8 is another lane's file |

### The step ladder, and why the numbers are powers of two

`config.block_size` is 0.5 m and `config.far_step` is 8 blocks, so:

| ring | cells | covers | **step height** |
| --- | --- | --- | --- |
| 0 | 4 m | seam to 200 m | **4 m** |
| 1 | 8 m | 200-400 m | **8 m** |
| 2 | 16 m | 400 m to fog (960 m at High) | **16 m** |

Cubic lock (decision 4) sets step height equal to cell width. Decision 12 fixes
ring 2's at the ring's own 16 m rather than halving the cells to soften it.

**Decisions 4 and 10 appeared to conflict and do not.** Cubic lock gives the
rings different step heights, which looks like it would move every shelf at a
ring boundary - the exact re-cut decision 10 wants to kill. It does not, because
the heights are powers of two: **every 16 m shelf is also an 8 m shelf.** The
coarse levels are a subset of the fine ones, so crossing 400 m makes a
mountain's shelves **subdivide** rather than move. Nothing that was there
before goes away; intermediate shelves appear between the ones already drawn.

That is the same subset property `_build_ring` already relies on for its XZ
grids - "which is also what keeps the coarse rings' vertices a subset of the
fine rings'." This plan extends it to Y.

### Tops keep the flank normal

Decision 8 says risers are shaded like voxel side faces. It does **not** mean
top quads are forced to flat +Y.

`_flank_normal` exists because "a mountain in a poster has one lit side and one
shaded side," and the first look tour came back with the far ranges as a
patchwork when every facet picked its own tone. Force every terrace top to +Y
and every mountain is lit identically - the range goes flat and that regression
is already documented.

So: **tops keep `_flank_normal`, and only risers take the dark side-face
treatment.** The block reading comes from the contrast between a lit top and a
shaded riser, which is exactly where it comes from in the near field.

---

## The lane

`feat/character-v2` is live in a worktree under another agent. TODO's convention
applies. This epic owns:

```
scripts/world/far_field_job.gd        scripts/world/flora/far_trees_job.gd
scripts/world/flora/far_tree_meshes.gd  scripts/world/worldgen_config.gd
scripts/world/heightmap.gd            scripts/tools/far_probe.gd
scripts/world/far_field.gd            scripts/world/flora/far_trees.gd
```

Three files are **append-only** - add at the end of an existing list, never
restructure, never re-order:

- **`scripts/world/look.gd`** - Stage 3 may append a riser shade helper. It must
  not modify `figure_material()` or `far_tree_material()`.
- **`scripts/game/game.gd`** - one line for the F3 readout.
- **`scripts/ui/debug_hud.gd`** - the F4 knob rows, appended to the table.

**It does not touch `scripts/character/` at all**, and it does not touch
`scripts/world/world.gd` - which is what rules out the flora density ramp
(decision 15, carried item 8). If a stage finds it cannot work inside that list,
it **stops and writes the conflict into the status doc**.

---

## How to use this document

Stages are ordered so each one is visible on its own and revertible on its own.
Land each as its own commit. If a stage's gate cannot be met as written, **run
what you can, record the number you got, and say so** - distance v1 had three of
those and the status doc is better for naming them.

The `far_terrace` knob from Stage 0 means every stage after it can be A/B'd
standing still. Use it. A screenshot pair from one vantage with the knob at 0
and 1 is the cheapest evidence in this plan.

---

## Stage 0 - Measure first, and the switch

Two things before any geometry changes.

**The knob.** Add `far_terrace` to `worldgen_config.gd`, default `0.0`, and a
row in the F4 table. `0.0` is today's mesh exactly - the smooth bilinear quad,
byte-identical output. `1.0` is fully terraced. Values between blend the
quantised height toward the true one, which is what makes the seam fade in
Stage 8 a one-line change rather than a special case.

Every stage below is written as "at `far_terrace = 1.0`". At `0.0` nothing in
this epic may change anything. **That is a gate, not a nicety** - it is the way
back if the whole idea reads badly, and it is how Marcel judges it.

`far_terrace` goes in **`LOCAL_PROPERTIES`**, beside `far_filter_bias` and
`far_peak_gain`. It is per-machine look, it is not hashed and not sent, and it
changes how the far country is drawn rather than what it is - the same reason
distance v1's knobs live there.

**The knob must rebuild the far field only, and not ask for F7.** This is a
requirement of the stage, not a nicety, because it is the whole judging method.

Today `_on_config_changed()` in `game.gd` applies MSAA, sky, flora and Look
knobs immediately and then sets `"config changed - press F7 to rebuild
terrain"`. F7 is `_on_reroll_requested(_world.world_seed)` - the same seed, so
the same world, but it rebuilds **every voxel chunk**: 3,276 chunks in 39,023 ms
on Marcel's box. Forty seconds per flip, with the world streaming back in around
you, is not an A/B a person can judge with their eyes.

`far_terrace` touches the far mesh and the impostor ring and **never a voxel
chunk**. `FarField.request_rebuild(center_block, frontier)` already exists, is
documented "safe to call every time", and its header already says "the old mesh
stays on screen for the frame or two a rebuild takes". So on a change to this
knob, call it directly and force one `FarTrees` update rather than falling
through to the F7 message. Per the F3 readout that is 1,299 ms of far mesh and
1,312 ms of impostors - about a second and a half, standing still.

The one line in `game.gd` this needs is the one line that file is allowed
(see the lane). If the same treatment happens to fall out for distance v1's
existing geometry knobs - `far_filter_bias`, `far_peak_gain`, `far_normal_m`,
which today also need a full reroll to see - that is a welcome side effect and
not a reason to widen the stage.

**The baseline.** Capture the far probe at `--seed 42` from the existing
vantages before touching geometry: FIZZ (max and rms), ROUGHNESS, PEAK LOSS.
These are the numbers distance v1 left at, and the status doc needs the pair.

**The gate, settled.** Carried item 6: `--strict` currently exits 1 on a single
frame over 33 ms, and does so on about half of all clean runs. Twelve runs
across three ABAB batches gave 0 or 1 long frames every time. Change the
standard to **fail on more than one long frame** in a three-minute sprint.
Decision 11. One line, and the gate stops being noise.

*Gate:* `far_terrace = 0.0` produces the same vertex count and the same
heightmap hash as `f23c3f0`. `--strict` passes twice running. **Changing
`far_terrace` in the F4 panel redraws the far country in under two seconds
without rerolling a single voxel chunk, and the player does not move.**

---

## Stage 1 - The height grid

Quantise a corner's height to the ring's step, on a **world-absolute** grid.

```
step_m  = ring cell width in metres    (4, 8, 16)
hq      = round(h_m / step_m) * step_m
```

**No player term anywhere in that expression.** `_build_ring` snaps its XZ
centre to the ring's own grid already, and the header says why - "so its
vertices land on the same world positions every rebuild and the mesh does not
shimmer as the player walks." Y gets the same treatment for the same reason. A
shelf at 112 m is at 112 m from every vantage, on every rebuild, in every ring.

This is the hard rule that everything else leans on. Get it wrong and the
terraces swim as you walk, which is the failure distance v1 already learned
once with the mip level.

Blend by the knob: `h = lerp(h_true, hq, far_terrace)`.

*Gate:* at `1.0`, every corner height in the mesh is an exact multiple of its
ring's step. Walk 200 m and back; a named shelf does not change height.

---

## Stage 2 - The terrace

Today `_build_ring` emits one quad from four independently-sampled corners, so
the quad is a sloped bilinear patch. Terracing means the cell gets **one**
height and the difference to its neighbours becomes vertical faces.

```
  now                        terraced

    ______                     ____
   /     /|                   |    |___
  /_____/ |              _____|        |
 |     |  |             |              |
   sloped quad           flat top + risers
```

Per cell: sample the cell's height once at its centre, quantise (Stage 1), emit
a **flat** top quad at that height in the existing winding. Then for each of the
four edges, compare against the neighbour cell's quantised height and emit a
riser of exactly that difference where the neighbour is lower.

The edge loop already walks the four neighbours with their cell offsets, and
`_push_skirt` already builds a vertical quad off an edge. A riser is that call
with `neighbour_dy` instead of `skirt_drop`.

**Ring-boundary skirts stay.** They cover cracks between rings, which risers do
not; the two coexist. Where a riser already covers an edge, the skirt is
redundant and may be skipped - a cheap win, not a requirement.

**Cost.** Worst case a cell emits one top and four risers against today's one
quad. In practice a quantised surface has many neighbours at the same level -
that is what quantising is for - so expect roughly 2-3x. The far mesh is 103,608
verts against 3,834,636 triangles of near flora in Marcel's shot, at 227 fps on
a 5080. This is not where the frame goes.

*Gate:* no holes on the horizon from any tour vantage. Vertex count under 4x the
baseline. `--strict` passes.

---

## Stage 3 - The risers are side faces

The stage that makes it read as blocks rather than as stairs.

Top quads keep `_flank_normal` - unchanged, see "Tops keep the flank normal"
above. Risers take the near field's **vertical face** treatment: the same
lit/shaded relationship a voxel's side has to its top. `SKIRT_SHADE = 0.7` is
the existing constant and the honest starting value; the near field's real
contrast is stronger, and matching it exactly is the point of the stage.

Read the actual near-field numbers rather than guessing them. Distance v1's
Stage 8 recorded a lit meadow top at `#809137` against shaded vertical faces at
`#272B2D` under `shade_desat = 0.55`. Whatever ratio that is, is the ratio a far
riser wants.

Ship the strength as `far_riser_shade` on F4 so Marcel can rule on it. Decision
8 declined the "soften with distance" variant; if the far ranges come out as
harsh stripes at 900 m, **record it and photograph it** rather than quietly
adding a distance falloff.

*Gate:* a postcard at `far_terrace` 0 vs 1 from the same vantage, both renderers.
The terraced one reads as blocks and not as a contour map.

---

## Stage 4 - The peaks keep their height

Rounding to nearest saws a summit flat: a peak whose true height falls just
below a step boundary loses up to half a step, and at ring 2 half a step is 8 m.
On top of a PEAK LOSS that carried item 4 already measures at +55.28 blocks at
600 m, that is the wrong direction.

Decision 9: **round up where the cell is a local maximum of the flank, round to
nearest everywhere else.** A ridgeline keeps its height and gains at most one
step; a hillside stays honest.

`_flank_normal` already samples the gradient over `far_normal_m` = 96 m, so the
local-max test has its input. Use the filtered pyramid, not the raw grid - the
raw grid is the aliasing distance v1 spent a night removing.

Re-measure PEAK LOSS. It should fall. If it rises, terracing is costing more
summit than round-up is returning, and that is a finding worth the status doc.

*Gate:* PEAK LOSS at 600 m no worse than `f23c3f0`'s +55.28 blocks. Ridges are
not visibly inflated against the smooth mesh at `far_terrace = 0`.

---

## Stage 5 - The impostors are stepped, and they stand on the shelves

Two changes in `far_tree_meshes.gd`, which this lane owns outright.

**The shape.** `_cone(6, 0.5, 1.0, color)` becomes a stepped pyramid - three or
four stacked boxes shrinking upward, around 20 triangles against today's six.

```
   now  _cone(6)          proposed

       /\                     __
      /  \                  _|  |_
     /    \                |      |
    /      \             _|        |_
   /________\           |____________|

    6 tris, diamond      ~20 tris, staircase
    facets               reads voxel
```

Keep `_dome` and `_post` in the same language - an octahedron and a four-sided
post are both smooth, and a broadleaf and a snag that stay smooth beside a
stepped spruce will be the new odd thing. Decision 6 sized the spruce; apply the
same treatment to all three at the same triangle scale.

Take the tier widths from the near spruce's own `TRUNK_TIERS` and crown shape in
`tree_species.gd` where that is cheap. Decision 6 chose the cheap pyramid over a
faithful rebuild, so this is "read the real widths if they fall out easily," not
a stage of its own.

**The footing.** Distance v1 Stage 6 made each impostor converge toward the
hillside it stands on. That hillside now has shelves, so an impostor must sit on
the **shelf top**, not on the true surface, or half the far forest sinks into a
riser. Snap the base to the quantised height of the cell it stands in.

`far_trees_job.gd` already knows the cell; it must use the same quantise
expression as Stage 1. If that means the expression moves to a shared static
helper, that is fine - both files are on this lane's list.

*Gate:* 852 impostors at the shot's vantage, none floating, none buried. A far
forest at 500 m reads as stepped trees on stepped ground. Triangle count for the
impostor ring under 4x baseline.

---

## Stage 6 - Docs, night 1

`docs/status/distance-v2.md`: the case, the probe table with a column per stage,
the `far_terrace` 0/1 postcard pairs, every constant with its starting and final
value, and anything a gate could not meet as written.

**Night 1's test, in one line:** stand at Marcel's vantage, press the F4 toggle,
and the mountains stop being a different game.

---

## Stage 7 - The bands land on the risers

Set `far_band_m` to the ring's step height instead of a flat 60 m, so an
altitude band boundary falls exactly on a riser rather than wandering across a
slope. Decision 7.

At ring 2 that is 16 m against today's 60 m - roughly four times as many bands.
`far_band_step` at 0.03 per band will be far too strong at that density; expect
to scale it down by about the same factor and photograph the result. The
constant to preserve is the *total* value change from treeline to summit, not
the per-band step.

**This reopens a look v1 constant inside a geometry epic, which the plan is
doing knowingly.** look v2 Stage 2 already fixed a zigzag here by making the
bands monotonic rather than alternating; do not undo that. Zeroed at the
treeline and clamped either side, exactly as now.

If the result is worse than 60 m bands on terraced ground, say so and leave
`far_band_m` alone - the geometry change stands on its own.

*Gate:* the snow/rock boundary on the shot's right-hand massif is a stepped line
along block edges, not a chevron across facets.

---

## Stage 8 - The seam, and where the steps begin

Decision 5: terracing fades in exactly as the seam band fades out.

```
  96m         112m                       400m
  |  voxels  |--- seam band ---|--- terraced --->
                 detail  fades OUT
                 steps   fade  IN
```

`SEAM_BAND_CELLS = 4.0` already fades the detail samples from full strength at
the voxel boundary to nothing four cells out, because inside that band the far
mesh computes the same surface the voxels do and there is nothing to disagree
about. Terracing inside that band would break the agreement it exists to create.

So drive `far_terrace` from the same band factor: zero where the detail is at
full strength, one where the detail has faded. The knob from Stage 0 already
takes a continuous value, so this is a multiply, not a branch.

`VOXEL_TOP_BIAS_BLOCKS = 0.5` stays and is worth re-reading here - it exists
because "the topmost solid block in a column is `floor(surface)` and the face
you see is its top." That is this epic's whole idea, already written down for
the seam. Terracing is that generalised outward.

*Gate:* walk from the meadow to the far field and back. Nothing pops at 96 m,
and no step appears inside the voxel radius.

---

## Stage 9 - The 400 m boundary, measured

Decision 10, and the stage most likely to return a null result - which is fine,
as long as it returns a number.

Carried item 3: the 400 m ring boundary is the loudest thing the far probe sees,
FIZZ max 21.6 against 1-4 blocks everywhere else, a third smaller than before
distance v1 and still a boundary. The stated fix was a geomorph.

The claim to test: **the power-of-two step ladder may have removed it without a
geomorph.** Every 16 m shelf is also an 8 m shelf, so a mountain crossing 400 m
should subdivide its shelves rather than move them, and there is nothing left to
re-cut.

Measure FIZZ max at the boundary with `far_terrace` at 0 and at 1. Then:

- **Gone or nearly** - say so, and carried item 3 closes without a geomorph.
- **Reduced** - record by how much, and carry the geomorph forward.
- **Unchanged or worse** - the subset property is not doing what this plan
  claims. Say that plainly; it is the most useful sentence in the document.

Do not build a geomorph in this stage. It was not in this plan and it is not a
knob.

*Gate:* a FIZZ-max number at the 400 m boundary for both knob settings, in the
status doc, with the verdict written out.

---

## Stage 10 - Docs, night 2

Complete `docs/status/distance-v2.md`. `STATUS.md` becomes a pointer and carries
anything still open. Update `docs/IDEAS.md` item 1 the way distance v1 did, with
a **Carried forward** section: what this epic did not solve, in one line each,
measured rather than suspected.

Carried items 1 (meadow gravel), 2 (`shade_desat`), 5 (FIZZ rms), 7 (ring
rebuild as a probe column), 8 (flora density ramp) and 9 (`debug_hud` reaching
into `FarField`) are **untouched by this epic and stay open**. Say so, so the
next plan does not go looking.

---

## Hard rules

1. **`far_terrace = 0.0` is byte-identical to `f23c3f0`.** Every stage, all the
   way to merge. This is the way back.
2. **No player term in the height quantisation.** World-absolute or the terraces
   swim.
3. **Step heights are powers of two across rings.** The subset property is what
   Stage 9 tests and what stops the 400 m re-cut.
4. **Tops keep `_flank_normal`.** Only risers take the side-face shade.
5. **`scripts/character/` is not touched.** Not one file, not one line.
   `scripts/world/world.gd` is not touched either.
6. **`look.gd` is append-only**, and `figure_material()` and
   `far_tree_material()` are not modified.
7. **The heightmap hash does not change.** This epic changes how the far country
   is DRAWN, never what it IS - the same rule distance v1 held and proved.
8. **Same seed, same spawn, same tree count** at every stage.

---

## Acceptance

**Night 1.**

- Stand at Marcel's vantage from `Screenshot 2026-08-28 161152.png`, seed 42.
  Open F4, set `far_terrace` 0 to 1, and **without moving or pressing F7** the
  far country redraws in under two seconds. The background stops reading as a
  different game.
- Distant mountains read as blocks: lit tops, shaded risers, steps that hold
  still while you walk.
- The far forest reads as stepped trees, not as diamonds.
- 227 fps at the same vantage is not meaningfully worse. `--strict` passes under
  the new one-long-frame standard.

**Night 2.**

- The snow line is a stepped boundary along block edges, not a chevron.
- Walk out from the meadow. Nothing pops at 96 m, and nothing steps inside the
  voxel radius.
- The 400 m boundary has a number and a verdict, whichever way it went.

If either night misses its test, the status doc says which line and why, and
that is what the next session works from.

## Handoff

`docs/status/distance-v2.md` carries the case, the far-probe table with one
column per stage, the provenance column distance v1 introduced (which box, one
run or an interleaved median), the `far_terrace` postcard pairs on both
renderers, and every constant's starting and final value.

The knobs this epic adds are Marcel's, on F4, and the status doc should
photograph each one's alternatives the way distance v1 did for its four:
`far_terrace`, `far_riser_shade`, and whatever `far_band_step` lands on after
Stage 7.

**The one number to lead with** is not FIZZ or PEAK LOSS. It is whether a person
standing in the valley at night, moving one knob, stops seeing two games.
