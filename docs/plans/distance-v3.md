# Distance v3 - the whole country, in the air of a poster

The third distance epic, planned 2026-08-31 - the same day the world went
unbounded, the north star went monumental, and Marcel looked at Distant
Horizons and said:

> that looks absolutely stunning. [...] It's exactly the epic feeling I would
> like for my game. [...] this distant horizons is really the feel I'm going
> for.

Distance v2 made the far country block-SHAPED. This epic makes it
block-SURFACED and makes it *all visible*: stand anywhere in the valley and
see the rim of the world, blocky, hazed, with no fog wall. The research this
plan stands on is `docs/research/distant-horizons.md` - read from DH's
source, not from screenshots - and its one-line summary is: **the epic look
is four tricks, and three of them are shader work.** Far colour that never
averages to mush, a block grid that is painted rather than meshed, faces
shaded by direction, and fog scaled to the far radius instead of the near
one.

It jumps the queue by the same case distance v2 made: pillar 3, now with the
monumental north star behind it, and Marcel's explicit ask.

---

## What was decided

Six answers, 2026-08-31. Each is Marcel's ("for all six, I go with your
recommendations"); the reasoning is recorded so a later plan does not reopen
a settled question.

| # | Decision | |
| --- | --- | --- |
| 1 | **Geometry stays terraced** - v2's shelves and risers are kept; DH's surface language lands on top | the terraces are paid for and correct; Veloren-style fragment-shader cubification is recorded as the fallback if geometry cost ever forces it, and is otherwise NOT pursued |
| 2 | **Colour: all three mechanisms** - mode-vote per far cell, block-grid jitter in the shader, noise-style variation further out | this is the heart of the epic; the mush is the enemy |
| 3 | **The whole region is visible** - extend the far field to cover all of the current 3 km world, rim included, via new 32 m and 64 m rings | the monumental pillar made visible; the log-ring structure makes each doubling cost one more ring, which is also what an unbounded world will need |
| 4 | **Fog is exp² over the FAR radius** - start at ~0.4 of it, cylindrical, sky never fogged; the Deco bands survive as a quantisation of that curve | DH's no-wall mechanism, in our poster's voice |
| 5 | **The seam adopts overdraw + dither** - the far field starts INSIDE the voxel radius and dissolves in a Bayer-dithered band | replaces the v2 seam-fade as the primary join; the frontier rule is untouched |
| 6 | **Scope**: far-tree colour variation gets one light stage; TAA gets a test-and-judge; shadows, god rays, clouds and water stay OUT for a later look plan | the vista first; the drama is a separate, art-direction-sensitive epic |

And one execution ruling, same conversation: **this plan is written to be run
autonomously by Opus on the headless Linux box** (the one the status docs
call ganymede - it has a GPU and can take its own tour shots). Everything
judged "by eye" in this plan means: photograph it, ship the shots, write the
verdict as a question for Marcel; nothing blocks on him mid-run.

---

## What the research found, in the order it matters here

Full detail with file-level citations in `docs/research/distant-horizons.md`.
The five mechanisms this plan actually uses:

1. **Mode-vote coarsening.** DH never averages colour when merging cells: it
   takes the most common block ID (air never wins, ties resolve
   deterministically and the arbitrariness reads as texture), so a coarse
   cell is always ONE real material at full saturation. Distant forest =
   leaves-next-to-dirt flecks, not brown-green soup.
2. **The ratio texture.** Per-block surface detail stored as a multiplier
   around 1.0, UV'd from `fract(worldPos)` per fragment - so it tiles once
   per block across a quad of any size and *provably does not change the
   average colour at distance*. We have no textures and want none; our
   translation is the near field's own per-block colour jitter, applied to
   the far field on a world-space block lattice (Stage 2).
3. **Directional face shading.** Tops bright, sides shaded by axis. The
   cheapest single thing that makes steps read as cubes. DH bakes it into
   vertex colour at build time; so will we.
4. **Fog normalised to the far radius.** `farFogStart 0.4, farFogEnd 1.0` of
   DH's OWN render distance, exp², cylindrical distance, depth-only (sky
   untouched). The wall is not a fog property; it is a fog-over-30-metres
   property.
5. **The seam trio.** Far field's inner edge at 0.8-0.9 of the near radius
   (overdraw), a screen-space 4x4 Bayer dither dissolving fragments over
   `[clip, 1.5*clip]`, and overdraw reduced when the player moves fast.

And one warning worth keeping: DH stops drawing per-block texture where
blocks go sub-pixel (4-block cells, ~1.5 km at their scale) and fades its
noise past 1 km, because past a certain angular size per-block variation
stops helping and starts aliasing. Detail near, flat far, atmosphere
carrying the distance - that is the shape of the curve.

---

## The ring ladder

`config.block_size` is 0.5 m. Distance v2's ladder, extended by decision 3:

| ring | cells | covers | step height | status |
| --- | --- | --- | --- | --- |
| 0 | 4 m | seam to 200 m | 4 m | exists |
| 1 | 8 m | 200-400 m | 8 m | exists |
| 2 | 16 m | 400-960 m | 16 m | exists |
| 3 | 32 m | 960-1920 m | 32 m | **Stage 4** |
| 4 | 64 m | 1920 m to the rim | 64 m | **Stage 4** |

Powers of two, so v2's subset property extends unchanged: every 64 m shelf
is also a 32 m shelf is also a 16 m shelf. Ring boundaries subdivide, never
move.

**The budget arithmetic** (to be verified by the far probe, not trusted):
ring area grows 4x per ring but cell area grows 4x too, so each new ring
costs roughly what ring 2 cost. Expect the far mesh to grow from ~200-260k
vertices to ~300-350k for nearly 4x the visible distance. If Stage 4 lands
far outside that envelope, stop and write down why before proceeding.

**No global-extent assumptions** (CLAUDE.md, 2026-08-31): the new rings are
derived from the configured far radius, never from the world's size. That
the far radius happens to reach the rim of today's region is a preset value.
The heightmap the rings read is today's global one; when terrain v3 makes
heightmaps regional, the rings must not care.

---

## The lane

No other lane is live (character v2, distance v2 and trees v1 are all
merged). This epic owns:

```
scripts/world/far_field.gd            scripts/world/flora/far_trees.gd
scripts/world/far_field_job.gd        scripts/world/flora/far_trees_job.gd
scripts/world/worldgen_config.gd      scripts/world/flora/far_tree_meshes.gd
scripts/world/look.gd                 scripts/tools/far_probe.gd
```

**`look.gd` is inside the lane this time** - the fog curve, the block-grid
jitter and the dither dissolve all live in the poster shader, and there is
no parallel lane to collide with. The compensating rule is a gate, not a
convention: **any shader change must leave the near field untouched at
default knobs** - `swatches.png` and `swatch-ramp.png` byte-identical
(the terrain material is bit-reproducible on ganymede; distance v2's status
doc, "And the pictures"), and a near-band crop (rows 500-720) of a
standing-still tour pair within flora-streaming tolerance.

Append-only, same as every epic:

- **`scripts/ui/debug_hud.gd`** - new F4 rows appended to
  `LOCAL_TUNING_ROWS`, nothing restructured.
- **`scripts/game/game.gd`** - nothing expected; if a line is unavoidable,
  it is one line, appended, and the status doc says why.

Every new knob this plan adds is LOCAL, unhashed, appended to
`WorldgenConfig.LOCAL_PROPERTIES` **and** to `FarField.FAR_ONLY_PROPERTIES`
so it redraws the far country live without a reroll - the F4-not-F7
property is how every stage gets A/B'd and it must never regress.

Untouched: `scripts/world/world.gd`, `scripts/world/chunk_mesher.gd` (read
it, never write it), everything under `scripts/character/`, the worldgen
shape path (`heightmap.gd`'s hashed inputs - this epic is LOOK, NOT SHAPE,
end to end).

---

## How to use this document - the autonomous run

Written for Opus, alone, on the headless Linux box, overnight.

- **Branch `feat/distance-v3` from current `main`.** One commit per stage,
  in the house voice, and **push the branch after every stage** so the run
  is inspectable from elsewhere while it goes.
- **At the end of the run, merge to `main` and push** (Marcel,
  2026-08-31: he reviews at main, on his own machine). The merge happens
  only after Stage 10's acceptance table is filled in and every hard rule
  below checks out - a run that stopped early stays on its branch, pushed,
  with the status doc saying where and why. Merge `main` into the branch
  first if main moved, resolve, run the self-test once more, then merge.
- **Keep `docs/status/distance-v3.md` as you go**, in the house style:
  provenance column (`ganymede, deterministic` / `single run` /
  `ABAB median` / `eye`), numbers with spreads, failures named. Distance
  v2's status doc is the template and the bar.
- **The instruments already exist.** `--import` once after checkout; the
  tour (`--tour --seed 42 --label NAME`, 17 shots), the far probe
  (`scripts/tools/far_probe.gd` - runs its table twice and asserts
  determinism), the self-test (`scripts/tools/selftest.gd`, including the
  far-terrace knob test), `tools/png_diff.py` for per-pixel comparisons.
  Extend the probe and self-test where a stage says so; never delete an
  existing assertion.
- **Per-pixel comparisons are valid over the far band only** (rows 0-300 of
  a tour frame): the far field is bit-reproducible on this box, the flora is
  not (distance v2 status doc, the table). A whole-frame diff proves
  nothing; say which rows every number comes from.
- **Every "by eye" gate becomes a photograph plus a written question.** Shoot
  the A/B pair, name the crop, write what you see and what you would rule,
  and leave the ruling to Marcel in the status doc's "For Marcel to rule on"
  section. Do not block, and do not silently decide taste questions that are
  listed as his.
- **Perf claims are ABAB medians, three runs each, on this box.** A single
  wall-clock number is a smoke alarm, not evidence.
- **If a stage's gate cannot be met as written**: run what you can, record
  the number you got, say so in the status doc, and continue unless the
  stage says stop. Distance v1 had three of those and was better for naming
  them.
- **If the run dies** (GPU device-lost has happened on Marcel's box; watch
  for it here too): note where, commit what is clean, and resume from the
  next stage boundary. Never leave the branch mid-stage without a status
  note.

---

## Stage 0 - Instruments first: the fleck number and the baseline

The epic's claim is "the far country stops being mush". Make that a number
before touching anything.

**The fleck number.** Add to `far_probe.gd`: mean absolute LOCAL colour
contrast over the far band - for each pixel in rows 0-300 of a named tour
shot, the mean |dL| against its 4-neighbours, averaged, reported per shot.
(Computed by `tools/png_diff.py` growing a `--local-contrast` mode; the
probe prints the command and the number lands in the status doc.) Mush is
low; fleck is high; the near field's own band (rows 500-720, same metric)
is the reference for "what blocks are supposed to look like".

**The baseline.** One full tour at today's `main` (far_terrace 1.0), plus
the fleck number for every far-band shot, plus the current far-mesh stats
(vertices, build ms, wall ms - ABAB). Every later stage is judged against
this.

**Gate:** the fleck table exists in the status doc with baseline numbers
for all 17 shots; the far probe still passes its determinism assertion.

## Stage 1 - The mode vote: a far cell is one real material

Today the far field's colour comes from zone fields sampled per zone cell -
read the actual path in `far_field_job.gd` first (`far_zone_cell_m`,
`far_zone_cell_ratio`) and record it in the status doc before changing it.

Replace the single sample per cell with DH's vote: sample the generator's
zone/material at the 4 sub-cell midpoints, take the most common, with two
rules ported from DH: **water never wins** (the analogue of "air never
wins" - a cell that is 3/4 meadow and 1/4 lake shore is meadow, not a
floating blue fleck), and **ties resolve to the first sample**,
deterministically - the arbitrariness is free texture.

New knob: `far_vote` (0 = old single-sample path, 1 = vote), default 1,
appended to F4 / LOCAL_PROPERTIES / FAR_ONLY_PROPERTIES.

**Gate:** the fleck number over forest-facing far-band shots rises against
Stage 0's baseline (record the delta; no target - the direction is the
gate). Far probe deterministic. Build-cost delta measured ABAB and under
+25% of baseline build ms - the vote is 4 samples where 1 was, and the
zone-cell grid is the coarse one, so it should be nowhere near that.

## Stage 2 - The block grid is painted: jitter on the block lattice

The near field's per-block colour variation comes from the tint machinery
(`color_jitter_value`, `color_jitter_hue`, `color_jitter_blocks`). Find
where it is applied - shader or mesher, checked by grep, not assumed - and
record it. Then give the far field the same variation, DH's way: in the
poster shader, on a **world-space lattice**, as a multiplier around 1.0 so
the average colour at distance is untouched.

- Lattice size = one block (0.5 m) near the seam, growing with distance to
  the local ring's cell size - DH's dropoff lesson: past the range where a
  block is sub-pixel, per-block variation aliases instead of helping. Use
  fragment world distance to blend lattice scales.
- Amplitude follows DH's recipe: luminance-weighted (parabola peaking at
  mid-tone, nothing on near-black or near-white), brightening toward white
  rather than hue-shifting - it must stay inside the poster's three-tone
  language.
- The far field needs its own material for the new uniforms: same shader
  source as the chunks (the precedent is figure_material getting its own),
  instanced with `far_grain` uniforms only it sets. This also creates the
  material seam Stage 7 needs for the dither. Note in the status doc that
  the far field stops batching with the chunks, and measure whether that
  matters (it should not - it is one mesh).

New knob: `far_grain` (0 = off, default matches the near field's jitter
value), appended everywhere as usual.

**Gate 1 (the average is preserved):** a standing-still tour pair with
`far_grain` 0 vs default, far band rows 0-300, mean |dL| under 0.5 sRGB
levels - the fleck must be variance, not a colour shift.
**Gate 2:** the fleck number rises again over Stage 1. Swatches
byte-identical (the near-field rule from The Lane).

## Stage 3 - Faces shaded by axis

Distance v2 settled that tops keep `_flank_normal` and only risers take the
side-face treatment; that stands. This stage adds the axis distinction DH
bakes: risers facing the two compass axes get different multipliers (the
near field's aspect idiom - `aspect_tint` already picks one fixed sun-ward
direction; reuse ITS direction so the far country and the near country
disagree about nothing), and the v2 riser machinery (`far_riser_shade`,
`far_riser_lift`) keeps doing exactly what it does on top of that.

Read the near field's actual side-face treatment in the mesher first and
match its ratios; do not import Minecraft's 0.8/0.6 constants blindly into
a poster that has its own lighting ramp.

New knob: `far_riser_axis` (0 = v2 behaviour, default on), appended as
usual.

**Gate:** v2's vertical-luma-gradient metric over the far band (the
`far_riser_shade` instrument) moves; A/B crops shot for Marcel; swatches
identical; far probe deterministic.

## Stage 4 - The reach: rings 3 and 4, and the rim

Extend `far_field_job.gd`'s ring table by 32 m and 64 m rings per the
ladder above. The v2 rules extend with it: cubic lock (step height = cell
width), round-up at ridges so the peaks keep their height, subset property
across ring boundaries. The impostor ring's `far_tree_m` is NOT extended
(decision 6; the far forest beyond it is terrain colour, and Stage 1's vote
is what makes it read as forest).

The reach itself is preset-owned: view preset 3 (High) gets
`fog_end_m`/camera-far values that cover the region's diagonal from any
standpoint (rim ~2.6 km from a valley floor; camera far with headroom,
~4000 m). Lower presets keep shorter reaches - the ladder derives from the
configured radius, so they simply stop at an earlier ring. Godot 4.7
Forward+ has reversed-Z; if depth artefacts appear at 4 km anyway, record
them with shots before touching anything.

**Gate:** far-mesh vertex count within the budget envelope (≤ ~350k);
build/wall ms ABAB against baseline, and wall stays under 5 s on this box;
a tour shot from the valley floor in which the rim of the world is visible
and terraced; frontier rule untouched (stream probe run, zero holes); far
probe determinism table extended to the new rings and passing twice.

## Stage 5 - The air: exp² fog over the far radius, banded

The poster shader's fog (look.gd, the RAMP) currently ramps linearly
between `fog_start_m` and `fog_end_m` in bands. Rebuild the curve DH's way,
keeping the banding:

- Distance: **cylindrical** (XZ), not spherical - looking up must not fog
  the peaks' sky.
- Curve: **exp²**, with density normalised so the curve spans
  `[far_fog_start_frac * far_radius, far_radius]` - new knob
  `far_fog_start_frac`, default 0.4, of the CONFIGURED far radius, never a
  hardcoded metre value (unbounded rule).
- The bands: quantise the exp² result through `fog_bands` exactly as the
  linear curve is quantised today. The bands are the poster; the curve
  under them is the atmosphere.
- The sky shader is untouched; fog applies to drawn geometry only. The
  horizon stays geometry-against-sky, no fog plane.

**Gate:** a tour pair old-curve/new-curve from the valley floor; the rim
readable through haze in the new one (fleck number at the rim band above
zero where the old curve saturates to flat fog colour); near-band crop
within tolerance at default knobs; every existing fog knob (`fog_bands`,
`fog_start_m`, `fog_end_m`) still does something sensible, recorded in the
knob table.

## Stage 6 - Docs, night 1

Status doc catches up in full: fleck tables, ABAB tables, the knob table
with photographed alternatives, "For Marcel to rule on" with the A/B pairs
from Stages 1-5. Commit. This is the point where the epic is visible in
one sitting - if the run must stop early, stop here.

## Stage 7 - The seam: overdraw and the dithered dissolve

Replace the v2 seam-band-fade as the primary join (the terrace fade inside
the seam band survives - it is geometry agreement, not the join):

- **Overdraw:** `FarField.exclusion_blocks()` currently cuts the inner edge
  at `voxel_radius - 2 * far_step`. Change to a fraction of the ACTUAL
  frontier (v2's frontier rule machinery): the far field starts at
  ~0.85 of the built frontier per sector, drawing behind the voxels'
  outermost ring. Knob `far_overdraw`, default 0.85.
- **The dissolve:** in the far field's own material (created Stage 2), DH's
  fragment dissolve verbatim: 4x4 Bayer on `gl_FragCoord`-equivalent
  (`FRAGCOORD` in Godot), `smoothstep(clip, 1.5 * clip, viewDist)`,
  discard below. Works identically for any pass, needs no sorting.
- **Speed-aware overdraw** (DH reduces overlap toward 0.2 at speed to give
  streaming a chance): attempt it reading the player speed the stream
  probe already knows; if it needs a file outside the lane, record that and
  skip - the frontier rule already guarantees no hole, so this half is an
  optimisation, not a correctness fix.

**Gate:** stream probe at sprint: zero holes, same as v2's hard rule, run
the full harness. Seam crops from a standing tour: the join invisible at
default knobs (photograph, Marcel rules). Far probe deterministic.

## Stage 8 - The far forest flecks (light touch, decision 6)

One stage, no rework: per-impostor colour variation. Each far tree already
has a deterministic hash (position); apply a per-instance tint jitter in
the same family as `far_tree_tint`, amplitude on F4 (`far_tree_grain`,
default small), so a distant forest is thousands of slightly-different
greens - Veloren ships real per-tree colour in 13 bytes; ours is free from
the hash. Check the treeline: where impostors end and Stage 1's voted
forest-colour cells begin must not be a visible colour cliff (shot, eye,
Marcel).

**Gate:** impostor count and rebuild ms unchanged (ABAB); treeline crop
shot; determinism.

## Stage 9 - TAA, tested and judged

At 3-4 km, sub-pixel terraces crawl. Godot Forward+ ships TAA; the game
ships MSAA 4x. Produce the evidence for a ruling: the same tour twice
(MSAA 4x vs TAA), plus a 60-frame fly-forward sequence from one vantage
captured both ways for the crawl (stills cannot show it; diff consecutive
frames and report the per-frame |dL| as the shimmer number). Write up: does
TAA soften the poster's hard edges? Is the crawl visible at all on this
GPU? Recommend, do not decide - Marcel judges the pairs.

**Gate:** the shimmer numbers and the paired shots exist in the status doc
under "For Marcel to rule on". No default changes in this stage.

## Stage 10 - Docs, night 2, and the handoff

Status doc completed: acceptance table below filled in, knob table final,
open questions listed. Update `docs/DESIGN.md`'s rendering line if the far
field's description changed materially. Do not touch IDEAS/ROADMAP/TODO -
re-queueing is Marcel's.

Then the landing (Marcel's instruction, 2026-08-31): push the branch,
merge it to `main`, push `main`. He reviews the finished epic at main. If
acceptance is not met, do NOT merge - push the branch and write the
shortfall at the top of the status doc instead.

---

## Hard rules

1. **LOOK, NOT SHAPE.** Nothing in this epic touches a hashed worldgen
   input. `config.hash_key()` identical before and after every stage.
2. **Never a hole, at any speed.** The frontier rule is inherited law; the
   stream probe is its enforcement; Stage 7 runs it and so does acceptance.
3. **No global-extent assumptions.** Radii come from config; rings derive
   from radii; nothing reads the world's size. (CLAUDE.md, 2026-08-31.)
4. **The near field is sacred at default knobs.** Swatches byte-identical
   after every shader-touching stage; near-band crops within
   flora-streaming tolerance. The far country changes; the game Marcel has
   does not, until he turns a knob.
5. **Every knob live on F4, no reroll.** Appended to LOCAL_PROPERTIES and
   FAR_ONLY_PROPERTIES both, or the stage is not done. The A/B-standing-
   still property is the epic's judging instrument and must never regress.
6. **The average is preserved.** Any variation mechanism (Stage 2, Stage 8)
   must move variance, not means - measured, not asserted.
7. **Perf claims are ABAB medians on ganymede.** Single runs are smoke
   alarms. Marcel's desktop numbers are not evidence (60% variance, on
   record).
8. **Append-only outside the lane.** debug_hud and game.gd take appended
   lines only; world.gd and chunk_mesher.gd take none. A stage that cannot
   live inside the lane stops and writes the conflict into the status doc.
9. **Taste is Marcel's.** Every eye-gate produces photographs and a written
   recommendation; no default flips on a taste question he has not ruled
   on, beyond the defaults this plan itself sets.

---

## Acceptance

The epic is done when the status doc shows, with provenance:

- A tour shot from the valley floor in which **the rim of the world is
  visible, terraced, and hazed** - no fog wall anywhere in the frame.
- **Fleck numbers** for the far band above baseline at every stage that
  claimed to raise them, with the near field's own band as the reference
  point.
- **Far mesh ≤ ~350k vertices**, wall rebuild **≤ 5 s** on ganymede, ABAB.
- **Stream probe: zero holes at sprint**, full harness.
- **Swatches byte-identical** to `main`'s at default knobs.
- The **far probe determinism table** covering rings 0-4, passing twice.
- Every new knob in the F4 table, live, no reroll, listed with its
  photographed alternatives.
- A **"For Marcel to rule on"** section with the A/B pairs for: the vote,
  the grain, the axis shading, the fog curve, the seam, the treeline, TAA.

## Handoff

What this epic deliberately leaves for later, named so nobody discovers it
as a surprise:

- **Unbounded streaming of the far field** - rings that page regional
  heightmap tiles as the player ranges. Blocked on terrain v3 (regional
  heightmaps; see `docs/research/terrain-tectonic.md`, "the four bounded
  assumptions"). This epic's contribution is rings that don't care where
  the heightmap came from.
- **The drama pass** - shadows across the valley, god rays, clouds, water
  at distance. Its own plan, judged against the Deco poster, after this
  epic ships and shows what is still missing.
- **Terrain v3** - Tectonic-school macro-structure: splines, a second
  shaping axis, ranges with a 50:1 macro-to-feature ratio. The far country
  this epic renders will make today's 4:1 clusters legible from 3 km; that
  is the argument for terrain v3, on purpose.
- **The Veloren fallback** - screen-space cubification, recorded in the
  research doc, untouched unless decision 1's geometry path ever hits a
  wall.
