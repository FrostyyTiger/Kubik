# Distance v1 - the far country holds still, and the forest recedes

The view is the thing this game got right and the thing it is currently
spending badly. World feel v1 opened High to 800 m of fog and the postcard
works: from spawn you see a whole range, its treeline and its snow, and none of
it is a wall of haze. That is the pillar - **THE WORLD IS THE CONTENT**, and
ranging further has to look like something worth ranging into.

What is wrong is everything between here and there. Three separate faults, all
of which read as "jagged" in play:

1. **The far mesh aliases.** It samples a 2 m heightmap every 8 or 16 m and
   keeps whatever lands on the lattice. Ridges are spiky because a peak
   survives by luck rather than by height; a summit reads as crumpled foil
   rather than as one mountain with a lit side and a shaded side; and a range
   changes shape as you walk, because the LOD rings move with the player and a
   mountain re-samples itself when it crosses one.
2. **The colour aliases on top of it.** Every quad picks its own zone, its own
   altitude band and its own flank normal, and the zone dither is applied at
   quad resolution - so a mountainside comes out as a camouflage of small
   hard-edged patches instead of the three or four large fields the poster is
   supposed to paint.
3. **The impostor forest is drawn with the CHARACTER material.** `fog_dark_mix
   = 1.0` and no grain. It is the treatment that stops a person dissolving into
   the ground behind them, applied to two thousand trees on a hillside, so the
   far forest is forbidden from receding. This one is a bug.

Written 2026-08-27 after an eight-question session with Marcel, from the tour
shot `build/tour/world-feel-v1/6-postcard.png` and `16-spawn-postcard.png`
taken at HEAD on his box. Every decision below is his; every number is a
starting value. Two nights, one branch: `feat/distance-v1`, from `main` at
`e7c5d9d` (world feel v1 merged, and ganymede's GPU found).

**Night 1** is the ground (Stages 0-5). **Night 2** is what grows on it and the
near field (Stages 6-9), and starts from night 1's last commit, not from
`main`: Stage 6 tunes the impostors against a far mesh that night 1 has just
changed the colour of.

**Why now, against the queue.** TODO Wave 1 is creatures, combat and water.
This jumps all three, and the case for it is pillar 3: distance is the content
axis, and right now the far country is the least finished-looking thing in
every screenshot of the game. Nothing in Wave 1 depends on the far field, so
nothing is blocked by doing it first, and every creature and every campfire
built afterwards is photographed against it.

**Why it is worth a whole epic and not a tuning pass.** Fault 1 is not a knob.
It is the absence of mip-mapping in a system that needs mip-mapping, and the
fix is a filtered pyramid plus a distance-continuous LOD - which touches the
heightmap, the far mesh, the seam and the colour. Fault 3 is one line. They are
in one plan because fixing 3 without 1 just makes the calm thing sit in front
of the fizzy thing.

## The lane

**A character redesign runs in parallel, in another worktree, under another
agent.** TODO's convention applies: zero-overlap file lists, `game.gd` has one
owner, everyone else adds a file plus a one-line hook. This epic is the
*scenery* lane and it owns:

```
scripts/world/heightmap.gd            scripts/world/far_field.gd
scripts/world/far_field_job.gd        scripts/world/flora/far_trees.gd
scripts/world/flora/far_trees_job.gd  scripts/world/flora/far_tree_meshes.gd
scripts/world/worldgen_config.gd      scripts/tools/far_probe.gd   (new)
```

**It does not touch `scripts/character/` at all.** Not one file, not one line,
whatever a stage seems to need.

Three files are shared and are **append-only** here - add at the end of an
existing list, never restructure, never reformat, never re-order:

- **`scripts/world/look.gd`** is the one real collision point, and it is worth
  being precise about. Stage 6 **adds** `far_tree_material()` as a new function
  and **must not modify `figure_material()`**, which a character redesign is
  very likely to be editing. The behaviour change belongs at the *call site*,
  in `far_tree_meshes.gd`, which this lane owns outright. Written that way the
  diff to `look.gd` is one appended function and merges clean.
- **`scripts/game/game.gd`** - one line for the F3 far-field readout, at the
  end of the existing readout block.
- **`scripts/ui/debug_hud.gd`** - the F4 knob rows for this epic's constants,
  appended to the end of the table.

If a stage finds it genuinely cannot work inside that list, it **stops and
writes the conflict into the status doc** rather than reaching across the lane.
An overnight agent silently editing the other lane's files is how two nights of
work become one merge nobody can review.

---

## What was measured, and what was decided

### The far mesh aliases (confirmed by reading the code, 2026-08-27)

`Heightmap.height_at()` is bilinear over `cells`, a grid at `coarse_step` 4
blocks = **2 m**. `FarFieldJob` builds three rings:

| ring | `RING_STEP_MULTIPLE` | metres per vertex | covers |
| --- | --- | --- | --- |
| 0 | 1 | 4 m | seam to 200 m |
| 1 | 2 | 8 m | 200-400 m |
| 2 | 4 | 16 m | 400 m to fog (960 m at High) |

Ring 2 therefore takes one sample in eight from a grid whose content runs down
to 2 m wavelength, with no filter. That is a texture without mipmaps, in
geometry. Three consequences, all of which match what Marcel saw in play:

- **Spiky ridges.** Whether a summit survives depends on where the ring's
  snapped lattice fell relative to it, not on how tall it is.
- **A mosaic instead of a mountain.** `_flank_normal` already averages the
  slope over `far_normal_m` = 96 m to fight this, and it is fighting the
  symptom: the *vertices* still come from unfiltered samples, so the facets
  themselves are noise.
- **A range that changes shape as you walk.** Each ring snaps to its own grid,
  which correctly stops shimmer *within* a ring - but the ring boundaries are
  at fixed distances from the player, so a mountain crossing 400 m re-samples
  itself from a 16 m lattice to an 8 m one and visibly changes.

### The impostors are drawn with the character material (bug, confirmed)

`FarTreeMeshes.material()` returns `Look.figure_material()`. Grep says exactly
two callers exist: `voxel_model.gd` (characters) and this. The figure material
sets `fog_dark_mix = 1.0`, `grain_amount = 0.0`, `contact_band = 1.0`. The
first is the one that matters, and `Look.FOG_FN` says what it is for in as many
words: *"A FIGURE FOGS DARKER THAN THE GROUND BEHIND IT, or it dissolves into
it at exactly the distance you most need to see it."*

Near voxel trees are part of chunk meshes and use `Look.opaque_material()`, as
does the far mesh. So the impostor ring is the only piece of *scenery* in the
game drawn as a figure, and it sits precisely where the eye compares it against
the terrain it is supposed to be part of.

### The forest stops before the fog does

`VIEW_PRESETS` at High: `fog_end` 800 m, `far_tree` 400 m. Stage 7 of world
feel v1 raised `far_tree` from 300 to 400 for this reason and did not close the
gap. The far half of every wooded ridge is bald, and `far_field_job` colours it
forest-green, so it reads as a mown slope.

### The meadow is the noisiest thing in the frame

`16-spawn-postcard` at HEAD: the tufts read as grey gravel scattered over the
grass. World feel v1's Stage 7 recorded it - *"the meadow tufts read as a grey
speckle at this density in this shot - it is the 'confetti' note from look v2's
Stage 4 again, now over a wider view"* - and left it. It belongs here because
it is the near half of the same complaint: the foreground is currently the
busiest thing in the picture and the distance the calmest, which is backwards.

### Decided (Marcel, 2026-08-27)

1. **Rendering only.** The filter changes how the far country is *drawn* and
   never what it *is*. Hard gate: same heightmap hash, same spawn, same lakes,
   same tree count. Walking to a mountain finds exactly the mountain that is
   there today; it just stops fizzing on the way.
2. **Smooth and calm.** Distant ranges become big simple masses. The faceting
   stays in the geometry and stops being the thing you notice.
3. **One continuous world.** Near and far keep the same visual language - same
   grain, same tinting, same fog - and the seam stays invisible. No "the world
   becomes a painting" line.
4. **No canopy shell.** Marcel's call, mid-session, and it is the right one: a
   canopy mass buys a better far silhouette at the price of a second handover
   that would move with the player, and the cone ring already has a handover
   that works (the inner fade, plus the frontier logic from world feel v1 Stage
   3 that made "never a hole" true by construction). The far forest is
   **fixed, not replaced**.
5. **Three tiers stay:** voxels to 96 m, cones from there, and the cones now
   run to the fog and thin as they go.
6. **The meadow confetti is in scope**, night 2, with a bail-out: if it is a
   density or contrast constant, turn it and photograph it; if it needs real
   work, write it up and leave it.

---

## How to use this document

Execute top to bottom. One commit per stage on `feat/distance-v1`, named
`feat(distance): stage N - <title>`. Every number is a starting value to be
judged with the probe and the tour, not a law - but the hard rules are.

Before starting read `CLAUDE.md`, `README.md`, `docs/DESIGN.md` ("Scale",
"Camera", "Art direction"), `docs/plans/look-v2.md` (Stage 0 above all - the
colour transfer, and why every constant is measured rather than assumed),
`docs/status/world-feel-v1.md` (Stages 3 and 7), and the comment blocks at the
top of `far_field_job.gd`, `far_trees_job.gd`, `far_tree_meshes.gd`,
`heightmap.gd` and `look.gd`. They contain the measurements this plan is built
on, and `far_field_job.gd`'s header in particular already explains the LOD
rings this plan is about to change.

Godot 4.7.2. On Marcel's Windows box:
`%LOCALAPPDATA%\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64_console.exe`.
On ganymede: `~/bin/godot`, wrapped in `xvfb-run -a`. `<godot>` below means
whichever applies. After any pull that adds `class_name` scripts:
`<godot> --headless --path . --import`.

**THE OVERNIGHT BOX CAN SEE NOW, AND THIS IS THE FIRST PLAN THAT GETS TO
ASSUME IT.** `e7c5d9d` found the cause of every "tuned blind" note in this
project: ganymede shipped with `nvidia-headless-595-open`, the compute-only
driver, so the Vulkan loader found no ICD and Mesa fell back to llvmpipe. One
package later it reports `Vulkan 1.4.329 - Forward+ - RTX 3070 Ti` through the
same `xvfb-run` line. Verified again at the start of this plan.

Three consequences, and they are why this epic is much better placed than look
v2 was:

- **Colour is judged overnight, not deferred to the morning.** Every stage that
  changes a tone runs its own tour and iterates against the pictures. The
  "Tuned blind" section that every previous status doc carries does not exist
  in this one. What still comes to Marcel is *taste* - `far_filter_bias`, the
  peak-gain, whether the meadow reads right - not *correctness*.
- **ganymede is the measuring box, and the desktop is not.** The surprise in
  `e7c5d9d`: two runs of identical code on ganymede vary ~9% on chunks/s
  (78.1-85.2), three on the RTX 5080 desktop vary ~60% (93.3-150.7), because
  that machine has a desktop, a compositor and another game competing for the
  card. **Every comparative number in this epic is measured on ganymede,
  interleaved ABAB, median with spread.** The desktop is where Marcel plays and
  where the acceptance test happens; it is not evidence.
- **Hard rule 7 is failing before this epic starts.** Two ganymede runs at High
  give 20 and 24 frames over 33 ms, worst 35.8-40.4 ms. That predates
  distance-v1 and is not this epic's to fix - but distance-v1 *adds* work in
  two places (Stage 2 samples the heightmap twice per far vertex, Stage 7
  doubles the impostor ring's radius), so it must not make it worse. See hard
  rule 6.

**Stage 0 is unaffected by any of this and still comes first.** Its argument
was never that the box was blind - it is that fizz cannot be judged by eye at
all. You cannot see whether a ridge re-cut itself by looking at two
screenshots taken from slightly different places; you can only measure it.

### Evidence

```
<godot> --headless --path . -- --host --seed 42 --far-probe                    # Stage 0 on
<godot> --headless --path . -- --host --seed 42 --stream-probe --strict
<godot> --headless --path . --script scripts/tools/worldgen_probe.gd -- --seed 42
<godot> --headless --path . scenes/selftest.tscn
<godot> --path . -- --tour --seed 42 --label dist-<stage>
<godot> --path . -- --tour --seed 42 --label dist-<stage>-gl --rendering-driver opengl3
```

On ganymede every rendering line above is wrapped: `xvfb-run -a ~/bin/godot ...`.

**Stage 0 re-shoots the baseline on ganymede** as `dist-base`, because the
existing `build/tour/world-feel-v1/` was taken on the Windows box and this epic
compares pictures across a dozen stages. Both sets stay on disk: ganymede is
what the stages are compared against, the Windows set is what Marcel's eye
already knows.

The worldgen probe must print heightmap hash **`76cccdb6`** and spawn
**(-44, -124)** after every stage of both nights, and the tree count must not
move at all in this epic. A stage that moves either is not done. Self-tests
green at the end of every stage.

---

# Night 1 - the far country holds still

## Stage 0 - Measure first: the fizz probe

**The instrument this project does not have.** World feel v1's most expensive
lesson is written at the top of `STATUS.md`: the stream probe *"cannot
currently compare two commits"*, because it measures wall-clock on a box that
drifts, and *"a number from a different run is not a baseline either"*. Every
night-2 performance number in the project is a single-run comparison and one of
them had to be publicly retracted.

The far field does not have that problem, and it is worth saying why: its
output is **pure geometry from a seeded generator**. No timing, no scheduler, no
GPU. Given a seed and a centre, `FarFieldJob` produces the same vertices on any
machine, every run. So a probe over it is a *measuring instrument* rather than
a gate, and it can settle by arithmetic what the tour can only settle by eye.

`scripts/tools/far_probe.gd`, `--far-probe`. It builds `FarFieldJob` directly -
no rendering, no window - at a set of centres derived from the world the way
`screenshot_tour.gd` derives its vantages (highest summit, biggest lake, the
spawn), and reports three numbers per vantage:

- **FIZZ.** Build the mesh at centre C, then at C + 16 m along +X. For every
  world position covered by both, take the difference in drawn height. Report
  RMS and max, in blocks. This is "does the far country change shape when I
  walk", as a number. Expect it to be large today.
- **ROUGHNESS.** Along a fan of rays out from the centre, the mean absolute
  second difference of drawn height per sample. This is "jaggedness", and it
  wants to fall while the next number does not.
- **PEAK LOSS.** For the twenty highest summits in the world, the drawn height
  at 600 m against the true `height_at()`. This is the number that stops the
  fix from becoming a different fault: a filter that removes fizz by flattening
  the mountains has not fixed anything.

Print a table, one row per vantage, plus a total line. **Run it twice in the
same session and assert the two are identical** - if they are not, the probe is
not deterministic and the stage is not done.

Record the baseline table in the status doc. Every later stage adds a column.

**Also in this stage**, two baselines that cost nothing to take now and cannot
be taken later:

- **The tour on ganymede as `dist-base`**, so every stage after this compares
  pictures taken on the same box under the same renderer.
- **The stream probe at `e7c5d9d`, interleaved-style: three runs, median with
  spread, run order recorded.** This is what hard rule 6 is measured against,
  and it has to be this commit's number rather than the two runs quoted in
  `STATUS.md`, because those were taken before this branch existed.

And the F3 readout gains the far mesh's current vertex count and rebuild time,
so the cost of Stages 1-4 is visible in play as well as in the probe.

## Stage 1 - The pyramid

`Heightmap` gains a filtered pyramid. Level 0 is `cells` itself (2 m); each
level above is a 2x2 box mean of the one below, so level 1 is 4 m, level 2 is
8 m, level 3 is 16 m, level 4 is 32 m, level 5 is 64 m. Successive box filters
approximate a Gaussian, which is what mip generation has always been and is
good enough here.

`height_at_level(bx: float, bz: float, level: int) -> float`, bilinear on that
level, same clamping and bounds rules as `height_at()`.

**IT IS DERIVED AND IT IS NEVER WRITTEN BACK.** `cells` is untouched, the hash
is untouched, and nothing that decides what the world *is* - zones, lakes,
spawn, tree placement, the voxel surface - reads a level above 0. The pyramid
is a rendering convenience and lives next to `cells` for the same reason a
mipmap lives next to a texture.

Cost: levels 1-5 total about 750k cells against level 0's 2.25 M, so roughly a
third more memory (about 3 MB) and one pass over a quarter of the data. Measure
the build time and put it in the status doc against the coarse heightmap's own
10.2 s; a second is affordable, five is not and would mean doing it on a worker.

**Gate:** worldgen probe prints `76cccdb6` and (-44, -124). Self-tests green,
including a new one asserting that level N's mean over the whole map equals
level 0's to within float error - a box filter conserves the mean, and if it
does not the pyramid is wrong.

## Stage 2 - The level is a function of distance, not of ring

The naive fix is "ring 0 reads level 1, ring 1 reads level 2, ring 2 reads
level 3". Do not do that: it fixes the aliasing and keeps the pop, because the
ring boundary is still a discrete step at a fixed distance from the player and
a mountain still changes when it crosses one.

Instead make the level **continuous in distance** and sample **trilinearly**:

```
level(d) = log2(d / FAR_LEVEL_REF_M) + far_filter_bias      clamped to [0, 5]
h(p)     = lerp(height_at_level(p, floor(level)),
                height_at_level(p, floor(level) + 1),
                frac(level))
```

`d` is the distance from the ring's snapped centre to the vertex, so it is
stable under the same snapping that already stops shimmer. Adjacent vertices
get adjacent levels, so the surface stays continuous. This is trilinear
mip-mapping with a distance LOD, which is the correct name for what the far
field has needed since terrain v2 built the rings.

`FAR_LEVEL_REF_M`: the distance at which level 0 is exactly right. Start at
**100 m** - about where a 2 m feature is a pixel or two - so 200 m reads
level 1, 400 m level 2, 800 m level 3.

`far_filter_bias`, starting **1.0**. Nyquist says a 16 m sample spacing needs
content band-limited to 32 m, so a ring is critically sampled by the level
matching its own step and still aliases a little; one level coarser is the
cheapest honest margin. It is also the main look knob in this epic, so it is on
F4 and the tour is run at 0.0, 1.0 and 2.0 in this stage with the three sets
left side by side for Marcel.

**Gate:** FIZZ RMS falls by at least **4x** against Stage 0's baseline and max
FIZZ has no spike at 200 m or 400 m - a spike there means the crossfade is not
working and the ring boundary is still discrete. ROUGHNESS falls. Stream probe
`--strict` still green: this stage moves vertices near the seam and the hole
logic must be unaffected.

## Stage 3 - The peaks keep their height

A box filter lowers summits and raises valleys, and at level 3 a knife ridge
can lose real height. If it does, this epic has traded a fizzing mountain for a
short one, and a mountain that visibly *grows* as you walk up to it is a worse
artefact than the one being fixed.

Read Stage 2's PEAK LOSS column first. **If every summit is inside the gate,
skip this stage and say so in the status doc** - do not build a mechanism for a
problem that measured clean.

If it is not: add a second, parallel pyramid of per-cell **maxima** (2x2 max
instead of 2x2 mean), and draw

```
h = lerp(mean_level, max_level, FAR_PEAK_GAIN)
```

starting `FAR_PEAK_GAIN` at **0.35**. This restores amplitude without restoring
high frequency, because the max pyramid is itself smooth at that level - it is
a dilation, not a sharpen. Doubles the pyramid's memory to about 6 MB, which is
nothing.

**Gate:** no summit visible from a tour vantage loses more than **4 blocks**
(2 m game, 8 m real at 1:4) of drawn height at 600 m, and FIZZ and ROUGHNESS do
not regress from Stage 2 by more than 10%.

## Stage 4 - The colour stops aliasing too

The geometry is calm and the paint on it is still camouflage. Four changes,
smallest first, each photographed:

1. **No dither and no jitter past the first ring.** `surface_zone_at()` hashes
   and dithers a zone boundary so the two zones interleave, which at 0.5 m per
   block reads as a gradient. At 16 m per quad the same mechanism reads as
   tetris. Past ring 0 the zone is decided by altitude alone. This is the
   single change most likely to fix the mosaic in `6-postcard.png`.
2. **The zone cell grows with distance.** `far_zone_cell_m` is one constant,
   24 m, applied to every ring past the first. Make it
   `max(far_zone_cell_m, FAR_ZONE_CELL_RATIO * d)` with the ratio starting at
   **0.06**, so a mountainside at 600 m is painted in 36 m fields and one at
   200 m is unchanged. Bigger fields, fewer of them, which is what a poster does.
3. **The bands read the filtered height.** `_band_color` and `_flank_normal`
   both take the same level the vertices took, so the contour bands follow the
   calm surface rather than the noisy one. `far_normal_m`'s 96 m averaging was
   compensating for exactly this and can very likely come down; try **48 m**
   and photograph both.
4. **Grain fades with distance.** `grain_amount` is world-space and constant,
   so past a few hundred metres it is sub-pixel noise, which is shimmer. Fade
   it to zero over the same range the fog covers. This is the one change that
   is *not* "one continuous world" - so it fades rather than switching, and if
   Marcel prefers it constant the knob is on F4.

**Gate:** the tour on ganymede, against `dist-base`. Specifically `6-postcard`,
`16-spawn-postcard` and `2-summit`, both renderers. **Iterate here rather than
deferring** - this is the stage the working GPU buys, and a camouflaged
mountainside is a thing the agent can now see for itself. The probe numbers
must not move: this stage touches colour only, and if FIZZ or PEAK LOSS
changes, something has been wired to the wrong level.

## Stage 5 - Docs, night 1

`docs/status/distance-v1.md` in the shape of `docs/status/world-feel-v1.md`:
the case, the probe table with one column per stage, every starting value with
its final value, a provenance column saying which box each number came from and
whether it is a single run or an interleaved median, and the three-way
`far_filter_bias` comparison for Marcel to rule on. `STATUS.md` gains a pointer.

---

# Night 2 - the forest recedes, and the meadow calms down

## Stage 6 - The impostors are not figures

One line, and it is expected to be most of the visible fix.

`Look` gains `far_tree_material()`: `OPAQUE_SHADER` like the terrain's, with
`fog_dark_mix = 0.0`, grain at the terrain's value, and no contact band.
`FarTreeMeshes.material()` returns it. The comment above it is rewritten to say
why a tree is scenery and a person is not, so the next reader does not
helpfully change it back.

Then, in the same stage, the thing the material alone does not do: **an
impostor's colour converges toward its hillside with distance.** Today it is
shade A of the species, flat, at every range. Mix it toward the far mesh's own
zone colour at that position by a factor rising with distance, starting at
**0.0 at the voxel edge and 0.5 at the fog**. A forest far enough away is a
shade of the mountain, not an object on it - and this is what makes the ring
obey "one continuous world" rather than merely stop shouting.

The mix is computed per instance on the worker, into the MultiMesh's instance
colour, which is already in the buffer and currently always white - so it costs
nothing at all in draw calls or shader work.

**Gate:** the tour, `16-spawn-postcard` above all, which is where the green
triangles are loudest. Self-tests green.

## Stage 7 - The ring reaches the fog, and thins as it goes

`VIEW_PRESETS` gains `far_tree = fog_end` at every preset: High 400 -> 800,
Ultra 500 -> 1000, medium 300 -> 500, low 200 -> 400. A wooded ridge is wooded
all the way to where you stop being able to see it.

That is 4x the candidate cells at High, and `far_trees_job.gd`'s header is
explicit about why that is not free: a placement decision is several noise
samples and a heightmap lookup, the full ring at High was already ~500 ms of
worker time, and **this engine build serialises GDScript across threads**, so
ring time is chunk time not happening. So the existing two-step LOD becomes a
ramp:

| band | cells kept | drawn width |
| --- | --- | --- |
| seam to 1.6 x voxel radius | all | 1x |
| to 400 m | 1 in 4 | 2x |
| to the fog | 1 in 16 | 4x |

Skipping stays keyed on cell parity, never on a counter, so which trees survive
does not depend on where the scan started - the property that stops the far
forest reshuffling itself around a walking player. Candidate count then grows
roughly linearly with radius instead of quadratically.

**And an outer fade.** `_fade_at` fades an impostor up from nothing at the
inner edge and does nothing at the outer one, so today the forest stops at a
circle. Add the mirrored term over the last `FADE_M` so trees shrink away into
the fog instead of ending.

**Gate, and it is the one methodological set-piece of this epic.** Ring rebuild
time at High no worse than **1.25x** Stage 6's - measured **on ganymede,
interleaved ABAB, three runs each, median with spread, run order recorded**.
Not three runs of the new code compared against a number from an hour ago:
that is exactly the method `e7c5d9d` says the amended `TODO(marcel)` on
`stream_probe.gd` now permits *only* under these conditions, and this is the
first stage in the project to owe it. If the spread of the two medians
overlaps, the honest answer is "no measurable difference", not a number.

Stream probe `--strict` green, holes 0, and the long-frame count no worse than
the `e7c5d9d` baseline (see hard rule 6).

## Stage 8 - The meadow stops being gravel

The bail-out stage, and it is allowed to end in a paragraph rather than a
commit.

Look at `16-spawn-postcard`: the tufts are dark grey-green against light green
grass, at a density where they read as scattered rubble. Two candidates, in
order of cheapness:

1. **Contrast.** The tuft colour is far darker in value than the ground it
   stands on. Bring it toward the ground's value and let hue carry the
   difference - the same argument look v2 Stage 2 made about the far-field
   bands, one scale down.
2. **Density with distance.** They are drawn to `flora_far_m` at a constant
   rate, so the number per screen pixel rises with distance until it is
   speckle. Thin them with range the way Stage 7 thins the trees.

If either turns out to be a constant, turn it, photograph it, and record what
it was and what it is. **If it needs real work - a new decoration LOD, a
different tuft model - stop, write up what was found, and leave it for a look
pass.** This epic is about distance and must not become about grass.

## Stage 9 - Docs, night 2

The status doc grows the night-2 half. Anything left open goes to the top of
`STATUS.md` in full, named rather than papered over - the standard world feel
v1 set.

---

## Hard rules

1. **The heightmap does not move.** Hash `76cccdb6`, spawn (-44, -124), every
   stage of both nights. The tree count does not move either, at any stage of
   this epic.
2. **Rendering only.** No stage changes what is generated. Every knob added
   here is local and unhashed: if a knob would change what a second machine
   generates, it is the wrong knob.
3. **The pyramid is derived.** Nothing that decides what the world *is* reads a
   level above 0. Not zones, not lakes, not spawn, not tree placement, not the
   voxel surface.
4. **Never a hole.** Stream probe `--strict` green at the end of every stage.
   This epic edits the far mesh's vertices and its exclusion logic sits three
   lines away; world feel v1 Stage 3 bought that guarantee and this epic does
   not get to spend it.
5. **The seam stays invisible.** `_corner_y`'s band still converges to the
   voxel surface at the seam. The filter applies to the coarse term; the detail
   term at the seam is unchanged.
6. **Hard rule 7 does not get worse.** It is already failing: 20 and 24 frames
   over 33 ms at High on ganymede at `e7c5d9d`, and that is not this epic's to
   fix. But this epic adds work in two places, so the stream probe's long-frame
   count and chunks/s at the end of night 2 must be **no worse than the
   `e7c5d9d` baseline**, measured the way Stage 7's gate is measured. A stage
   that makes a failing rule fail harder is not done.
7. **The far probe is deterministic.** Same seed, same numbers, every run, on
   any box. A stage that makes it vary is not done. It is an instrument, not a
   gate, and that distinction is the whole reason it exists.
8. **Comparative numbers come from ganymede, interleaved, as medians with
   spread.** Never from the desktop, and never as a single run against a
   remembered one. The desktop is where the acceptance test is played, not
   where evidence is made.
9. **No new textures.** Look v1's hard rule 3, still.
10. **GDScript only.** No GDExtension. If the pyramid or the ring wants one,
    name it in the status doc with the numbers that would justify it.
11. **Nothing on the Next 3 is built.** No creature, no attack, no campfire, no
    water.
12. **Every starting value in this file is on F4 and in the status doc** with
    what it was, what it is and why.
13. **Self-tests green at the end of every stage.**

## Acceptance

Marcel, on the Windows box at High, on the morning after each night.

**Night 1.** Stand at spawn and look at the highest ground in the world. Walk
200 m towards it and back.

- The range does not change shape as you move. No ridge fizzes, swims, or
  re-cuts itself as you cross 200 m or 400 m.
- It still reads as a *mountain* - one lit flank, one shaded flank, its whole
  profile visible against the sky, not a wall of fog. This is the thing that
  already works and the thing most at risk.
- Its summit is the height you expect when you arrive. It does not grow out of
  the ground as you approach.
- A distant mountainside is painted in a few large fields, not in camouflage.
- Nothing about the near world has changed: the same terraces, the same grain,
  the same lake in the same place.

**Night 2.**

- A wooded ridge at 500 m is wooded, and the trees on it sit *in* the hillside
  rather than on top of it. They fade into the fog rather than stopping at a
  circle.
- Walk from the meadow into the forest. Nothing pops at 96 m.
- The meadow at your feet is grass, not gravel - or the status doc says why it
  is still gravel.

If either night misses its test, the status doc says which line and why, and
that is what the next session works from.

## Handoff

`docs/status/distance-v1.md`: the case, the far-probe table with one column per
stage (FIZZ, ROUGHNESS, PEAK LOSS per vantage), every starting value with its
final value, the `far_filter_bias` comparison for Marcel to rule on, whether
Stage 3 was needed, what Stage 8 found, and what is left. `STATUS.md` becomes a
pointer to it and carries anything still open.

**There is no "Tuned blind" section in this one**, and that is the point worth
making explicitly at the top of it: it is the first status doc in the project
written by an agent that could see its own output. What replaces it is a
**provenance column** - which box each number came from, and whether it is a
single run or an interleaved median. Every previous doc conflated those two
things and `e7c5d9d` is the bill for it.

The five items already open in `STATUS.md` are untouched by this epic and stay
open. **Item 4 - the two-player push with two real machines - is unblocked as
of 2026-08-27** and wants an evening, not a plan.
