# Terrain v2 - the shape of the land

Overnight implementation plan. Successor to `terrain-v1.md`, which landed on
`main` as "Merge terrain v1: a walkable Swiss pre-Alpine world".

This plan is **the shape of the land**: scale, zoning, colour, flat ground,
view distance, world size and traversal. **Water, rivers and foliage are
deliberately NOT here** - they are Plan B, and several stages below exist to
prepare the ground for them.

---

## How to use this document

Execute it in one pass, top to bottom. **Do not stop to ask questions.** Every
number below is already decided; where a judgement call remains, the rule for
making it is stated. If something is genuinely ambiguous, pick the option that
keeps the game running and record the choice in `STATUS.md`.

Before starting, read `CLAUDE.md`, `README.md`, `docs/DESIGN.md` and
`docs/IDEAS.md`. The design pillars there outrank anything in this file.

Godot 4.7.2, invoked by full path (it is not on PATH):

```
C:\Users\tiger\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64.exe
```

Confirm the baseline before touching anything:

```
<godot> --headless --editor --quit --path .
<godot> --headless --path . --script scripts/tools/selftest.gd
<godot> --headless --path . --quit-after 2500 -- --host --seed 42
```

Expect zero script errors, `SELFTEST: all passed`, and roughly 2650 chunks
built with a far field of about 400k vertices.

---

## What changed since v1, and what it taught us

All three `TODO(marcel)` exercises are now **written** - `_ridge()`,
`_domain_warp()` and `_flatten_valleys()`. Do not treat them as stubs. Five
findings came out of writing them, and five stages below exist because of them.

**1. Zone thresholds are absolute altitudes, and that silently couples them to
every other terrain knob.** Turning on valley flattening at `valley_curve 1.6`
sent meadow from 56.7% to 79.8% and snow from 6.1% to 1.7%. The world did not
become greener - it became *lower*, and low means meadow by definition.
Rescaling the thresholds through the same curve,
`H' = lo + ((H-lo)/(hi-lo))^c * (hi-lo)`, restored the shares to within 0.5%
and reproduced the tree count **exactly** (8620 both sides). This is Stage 7,
and it is the most important structural change in the plan.

**2. Object scale is incoherent, and mountains are the outlier.** Measured
against real Swiss pre-Alpine equivalents:

| Thing | In game | Real | Compression |
| --- | --- | --- | --- |
| Player | 2.0 m | 1.75 m | 1 : 0.9 |
| Tree | 6-10 m | ~30 m spruce | 1 : 4 |
| Largest lake | ~93 m across | ~400 m tarn | 1 : 4 |
| **Mountain relief** | **133 m** | **~1400 m** | **1 : 10.5** |

Trees and lakes already sit at a consistent 1:4. **Only mountains are wrong**,
by a factor of 2.6. This is Stage 8. The world scale is 1:4 and stays 1:4;
mountains rise to meet it.

**3. Domain warp is statistically free.** With warp on and flattening off,
altitude mean moved 107.6 -> 107.1, meadow 56.7% -> 57.2%, trees 8620 -> 8643.
A coordinate bend moves features around without touching the height
distribution. Warp strength can therefore be tuned purely on looks.

**4. View distance and voxel radius are different kinds of expensive.**
Measured on the target machine:

| fog_end | far-field verts | chunk load |
| --- | --- | --- |
| 200 m | 42,684 | 4,955 ms |
| 400 m | 178,428 | 4,538 ms |
| 600 m | 404,588 | 4,520 ms |

| voxel_radius | voxels to | chunks | load |
| --- | --- | --- | --- |
| 8 | 64 m | 1,201 | 4.5 s |
| 12 | 96 m | 2,653 | 10.3 s |
| 16 | 128 m | 4,829 | 18.2 s |

Fog costs GPU vertices and **nothing at load** - the far field already derives
its radius from `fog_end_m` and builds on a worker thread. Voxel radius is
quadratic and CPU-bound. So fog can be generous on every machine and **voxel
radius is the real quality dial**. Stages 3 and 4.

**5. The camera pivot was welded to the body's rotation.** `CamPivot` was a
child of `Player`, so the camera's world yaw was `body.rotation.y + _yaw` while
`_wish_direction()` rotated input by `_yaw` alone - and since
`_face_movement()` rewrites `body.rotation.y` every frame, holding W made you
curve. Fixed with `top_level = true`. Already on the branch; do not undo it.

---

## Hard rules

1. **Determinism is sacred.** Every generated detail derives from
   `(seed, coordinates, config)`. No `randf()`, no `randi()`, no unseeded RNG
   anywhere in worldgen. No dependence on `Dictionary` iteration order.
2. **Every new config field joins `WorldgenConfig.PROPERTIES`.** That array is
   the determinism hash and half the join handshake. A knob outside it is a
   desync waiting to happen.
3. **Do not break multiplayer.** Beyond adding config fields, **do not touch
   the net protocol** - not the RPC surface, not the join handshake shape.
   Desync found after the fact is miserable to debug.
4. **Do not change the design pillars.** If a stage seems to need one bent,
   stop that stage, write the argument into `STATUS.md`, and move on.
5. **Do not rewrite or delete `TODO(marcel)` exercises** unless this plan
   explicitly assigns one. New exercises this plan creates follow the same
   shape: a working fallback, a hint, and no dependency on being done.
6. **No unverified performance claims.** Every timing or vertex count in
   `STATUS.md` must come from a measurement actually run, never an estimate.
   Write "not measured" rather than guessing.
7. **GDScript only.** No plugins, no GDExtension. `FastNoiseLite` for noise.
8. **Commit after every stage.** Never leave the tree dirty between stages.
9. **Verify after every stage.** Three fix attempts, then commit what works,
   record the failure in `STATUS.md`, continue to the next independent stage.
10. **Third person only.** No first-person camera mode, ever.

### The renderer caveat, and what to do about it

This box has no display. Godot falls back to OpenGL Compatibility on Mesa
llvmpipe under Xvfb. **Marcel runs Forward+ on an RTX 5080.** Last run this
produced a palette that arrived on his screen washed out and samey - which is
exactly what several stages below exist to fix.

You are cleared to tune values anyway. In exchange:

- **Every value chosen by eye goes in `WorldgenConfig`**, never hardcoded, so
  it is reachable from the F4 panel in a ten-second reroll loop.
- **Every visual decision is listed in one `STATUS.md` section** titled
  "Tuned blind - re-check these first", with the measured before/after and the
  knob name.
- Never delete a previous value. Record it beside the new one.

---

## Fixed numbers

### Scale

The world is **1:4 against reality** and stays there. Trees and lakes already
sit at 1:4; this plan brings mountains to join them.

| Thing | Value |
| --- | --- |
| Block size | 0.5 m (unchanged) |
| Player height | 4 blocks / 2 m (unchanged) |
| **World** | **3.0 x 3.0 km** (`world_blocks_xz` 6000, was 3000) |
| Coarse heightmap | 1500 x 1500 cells at 4 blocks (was 750) |
| **Mountain relief** | **~350 m** (was 133 m) |
| Chunk | 16^3 (unchanged) |

Two design-doc consequences, both handled in Stage 6's commit:

- `docs/DESIGN.md` says "one fixed 1.5 x 1.5 km region". **Amend it.** Per
  `IDEAS.md` the design moves deliberately and in writing or not at all.
- Full scale (1:1) was considered and rejected in writing. A real 1400 m
  mountain needs a 6 km base, which does not fit in a 3 km world at all, and a
  15 km world has a 21 km diagonal - roughly 35 minutes' sprint corner to
  corner. That is the failure mode that damaged Cube World's 2019 release.
  Rendering was never the constraint; LOD rings make a 10 km view cost about
  356k vertices, less than 600 m costs uniformly today. **Traversal was the
  constraint.** Record this reasoning in `STATUS.md` so it is not relitigated.

### Terrain shape

Characteristic slope, the number the eye actually reads, is
`4 * amplitude / wavelength`. Current layers measure:

| Layer | Wavelength | Amplitude | Slope |
| --- | --- | --- | --- |
| Continent | 600 m | 24 m | ~9 deg |
| Mountain | 150 m | 89 m | ~67 deg (gated) |
| **Hills** | **30 m** | **8 m** | **~47 deg - WRONG** |
| Detail | 6 m | 1.5 m | ~45 deg |

The hills layer is as steep as a mountain face at a 30 m wavelength, laid over
everything. That is the corrugation Marcel reported. **Target: ~180 m
wavelength, ~8 m amplitude, about 10 degrees.** Push the wavelength out; do not
merely cut the amplitude, which flattens hills into nothing instead of drawing
them out.

Hill amplitude at ~8 m is already correct for 1:4 - a real 30 m hill is 7.5 m
here. It is the wavelength that is wrong.

**Wavelength alone is not enough, and this is the important part.** fbm noise
is never flat: it is a sum of smooth waves, so every point sits on some slope
and the set of genuinely level ground has measure zero. Stretching the
wavelength makes slopes gentler but leaves the world uniformly undulating.
Marcel's reference is Cube World - "more flats, and hills rise gradually then a
little bump" - which needs a transform containing a **dead zone or a plateau**.
Two are specified, in Stage 9:

**Terracing.** Quantise height to shelves with short risers between them:

```
t = h / terrace_height
f = floor(t)
frac = t - f
h = (f + smoothstep(0.0, 1.0, pow(frac, terrace_sharpness))) * terrace_height
```

With `terrace_sharpness > 1` most of each shelf is genuinely flat and the
transition is quick. At 1 it degrades to plain smooth terrain, which makes it
safe to ship at 1 and tune upward. Terrace height wants to be a small multiple
of the block size so shelves land on block boundaries rather than fighting them.

**Hill gating.** The mountain layer is already gated on the continent layer,
and it is the reason massifs read as massifs. Nothing gates the hills layer, so
hills are everywhere at uniform strength. Gate them the same way, on their own
low-frequency mask, giving hilly districts and genuinely flat districts instead
of even bumpiness. The mechanism already exists in `height_at_block()` - reuse
its shape rather than inventing a second one.

### Elevation zones - seven, by percentile

Zones stop being absolute altitudes and become **target shares of map area**,
resolved against the actual altitude histogram each generation. Low to high:

| Zone | Share |
| --- | --- |
| Shore / wetland | 4% |
| Meadow | 30% |
| Forest | 26% |
| Alpine meadow | 14% |
| Heath | 10% |
| Rock / scree | 11% |
| Snow | 5% |

Meadow falls from 57% to 30%, which is the direct answer to "too green and
samey". Colours are yours to author; record the authored hex beside each linear
value as `Block.COLORS` already does.

Ordering of alpine meadow against heath is a design call, not a fact. The
default above is the plan's; change it with a stated reason in `STATUS.md`.

### View distance presets

`voxel_radius` is the dial. Fog stays generous everywhere, because it is nearly
free once LOD rings exist.

| Preset | voxel_radius | voxels to | fog_end |
| --- | --- | --- | --- |
| Low | 6 | 48 m | 400 m |
| Medium | 8 | 64 m | 500 m |
| High (default) | 12 | 96 m | 600 m |
| Ultra | 16 | 128 m | 800 m |

Far-field LOD rings, so `fog_end` can grow without the vertex count going
quadratic: `far_step` 8 blocks (4 m/vertex) out to 200 m, 16 to 400 m, 32
beyond.

At 1:4, a 350 m mountain is framed from about 750 m - which is why Ultra is
800 m and not a round number. The scale and the view distance are matched on
purpose.

### Traversal

3 km corner to corner must not be tedious. **Target: the map diagonal in under
6 minutes at sprint.** Measure the current walk speed first and record it.

---

## Stages

Order matters. Instruments first, then the things that change what you can
see, then the container - view distance, world size, scale - then its contents.

### Stage 1 - instruments

Nothing here changes the world. It changes what you can find out about it.

- Add to `worldgen_probe.gd`: a **slope histogram** (distribution of local
  gradient across the coarse map, in degrees, bucketed) and a **per-layer
  characteristic slope** line using `4 * amp / wavelength`. "Too hilly" becomes
  a number rather than a feeling.
- On the same line, report **share of map under 5 degrees and under 10
  degrees**. These two numbers are how Stages 9 and 11 are judged - a mean
  slope can improve while the world still contains no flat ground at all.
- Add an **altitude histogram** in percentile buckets - Stage 7 needs it.
- Add an **object scale** readout: player height, tree height range, largest
  lake width, mountain relief, and the implied compression ratio of each
  against its real-world reference. Stage 8 is judged on this line.
- Extend `screenshot_tour.gd` into a **comparison harness**: same seed, same
  six vantage points, writing to `build/tour/<label>/`. Later stages must be
  able to shoot `before` and `after` and leave both on disk.
- Shoot a `v2-baseline` set now.

*Verify:* probe twice on seed 42, every line identical. Baseline shots exist.

### Stage 2 - baked ambient occlusion and MSAA

Marcel's report: "not sharp - maybe missing antialiasing in the distance, but
close up it needs to be sharper too". Two separate causes.

- **Close up**: greedy-meshed faces in flat vertex colour carry no edge
  information at all - a hillside is literally one colour, so the eye has
  nothing to grab. Bake **corner ambient occlusion** into vertex colours:
  darken each vertex by how many of the three blocks diagonally adjacent to
  that corner are solid. This is what makes voxel worlds read as built out of
  cubes. Greedy meshing complicates it, because a merged quad may not share AO
  across its span - so **split merged quads whose corner AO differs**, and
  record the cost in quads and ms.
- **Distance**: MSAA is off by default in Forward+. Turn it on (start at 4x)
  and record the frame cost. Flat voxel edges against sky alias badly.

*Verify:* self-tests pass - winding must still be correct after AO splitting -
plus comparison shots against `v2-baseline`.

### Stage 3 - threaded chunk generation

The single biggest performance win, deferred from v1 because it changes how
block edits replay. It is a prerequisite for everything after it: at radius 16
there is 16.9 s of main-thread generation, and threading is what makes view
distance affordable at all.

- Move voxel generation to the existing worker pool, as meshing already is.
- The hazard, stated in v1's `STATUS.md`: chunk data no longer exists at submit
  time, so **the edit-replay path changes**. Handle it explicitly - queue edits
  against chunks still generating and apply them on completion. Do not paper
  over it.
- Measure before and after at radius 8 and 12.

*Verify:* self-tests, two-peer test, and a **new self-test** that edits a block
in a chunk which is still generating and asserts the edit survives.

### Stage 4 - view distance presets and far-field LOD

- Implement the preset table above as a single setting driving `voxel_radius`
  and `fog_end_m` together. Default High.
- Implement far-field LOD rings per the table. Record vertex counts per preset.
- The far field already derives its radius from `fog_end_m` - keep that
  derivation. Do not introduce a second number that has to be kept in sync.

*Verify:* each preset boots headless; chunk counts and vertex counts recorded.

### Stage 5 - the far-field transition band

Promoted from a v1 leftover. At 96 m of voxels against 600 m of visibility this
is now the most visible artefact in the game.

The far mesh is the coarse heightmap; voxels are that plus per-block detail, so
they differ by up to 3 blocks at the boundary. Pick one fix and say why: a
skirt, a blend band, or sampling detail into the far mesh near the seam.

*Verify:* comparison shots from a vantage point that frames the boundary.

### Stage 6 - the world grows to 3 km, and traversal

- `world_blocks_xz` 3000 -> 6000, coarse heightmap 750 -> 1500 cells.
- Measure heightmap time, lake time and memory. Expect roughly 4x; if it lands
  materially worse, record it and continue.
- **Amend `docs/DESIGN.md` in this commit** - the 1.5 km line and everything
  downstream of it, plus the rejected-full-scale reasoning from Fixed Numbers.
- **Traversal**: implement sprint. `Player._speed_multiplier()` is a
  `TODO(marcel)` and this plan **claims it** - the single exception to rule 5 -
  because a 3 km world without sprint is the Cube World failure in miniature.
  Shift for sprint, Alt for precision. Tune so the map diagonal is under 6
  minutes sprinting, and record walk and sprint speeds.

*Verify:* headless boot, probe determinism at the new size, measured crossing
time.

### Stage 7 - percentile zone thresholds

The structural fix. Zone boundaries become **percentiles of the actual altitude
histogram**, not absolute altitudes.

- Compute the altitude histogram once per world, after all shaping.
- Resolve each zone's share from the table into a concrete altitude.
- Keep the jitter and blend that already exist - the boundary must still wobble
  and cross-fade; only its centre becomes relative.
- Retire `meadow_max` / `forest_max` / `rock_max` as tuning knobs, replaced by
  the share table.

This decouples zoning from world size, from `valley_curve`, and from every
future shaping change. Without it, Stages 6, 8 and 11 each silently re-zone the
world.

*Verify:* probe reports the seven shares within 1% of target on three different
seeds. That tolerance is the entire point of the stage.

### Stage 8 - scale coherence: mountains rise

Trees and lakes are at 1:4. Mountains are at 1:10.5. Close the gap.

- Introduce a single **`world_scale`** config value (1:4, expressed however
  reads best) and derive from it: mountain relief target, tree height range,
  and minimum lake size. One knob, so these can never drift apart again.
- Raise mountain relief from ~133 m to **~350 m**: `world_height_blocks`,
  `max_altitude`, `mountain_amp` and `continent_amp` all move together. Trees
  and lakes should come out unchanged, because they are already correct - if
  the derivation changes them, the derivation is wrong.
- **Measure the chunk cost.** Chunks follow the surface, not bedrock, so the
  cost is more vertical spread rather than a proportional explosion - but it is
  a real increase and it is unmeasured. If the frame or load budget breaks,
  drop the default preset to Medium and record it.

This stage is also a live test of Stage 7: relief changes by 2.6x and **the
seven zone shares must not move**. If they do, Stage 7 is wrong - fix it there,
not here.

*Verify:* object scale readout shows every item within 1:3 to 1:5; zone shares
unchanged within tolerance; comparison shots from a valley floor looking up.

### Stage 9 - hills retune, and slope-aware zoning

Two changes, one stage, because both are judged on the same screenshots.

- **Hills, part one - wavelength**: 30 m -> ~180 m, amplitude ~8 m, targeting
  ~10 degrees. Sweep at least three wavelengths, record the slope histogram for
  each, and state which you picked and why.
- **Hills, part two - actual flat ground.** Wavelength alone cannot produce
  flats; see Fixed Numbers. Implement both specified transforms, each behind a
  config knob that disables it at its default:
  - **Terracing**, with `terrace_height` and `terrace_sharpness`. Ship
    `terrace_sharpness` at 1.0 (a no-op) and tune upward from screenshots, so a
    bad value can never make the world unshippable.
  - **Hill gating**, mirroring the existing mountain mask on a low-frequency
    hills mask, so hilly and flat districts both exist.

  The measure of success is not the mean slope, it is **the share of the map
  under 5 degrees**. Report it before and after each of the two. If terracing
  and gating together do not raise that share materially, say so plainly rather
  than declaring victory on a slope average that hides it.
- **Slope-aware zoning**: zones key on **slope as well as height**. Steep faces
  become rock or scree at any altitude - snow does not sit on a cliff, it
  slides off. High gentle ground gets snow. This is what makes real mountains
  read, and it is what Marcel meant by "snow covered tops and rocky tops".

*Verify:* slope histogram before and after, comparison shots, zone shares still
within tolerance.

### Stage 10 - colour: jitter and slope tinting

Direct answer to "too green and samey", on top of the seven zones.

- **Per-block colour jitter**: small deterministic hue and value variation from
  `(seed, block coords)`. Subtle - this is texture, not confetti. Start around
  +/-4% value and +/-2 degrees hue, then tune from screenshots.
- **Slope and aspect tinting**: darken steep faces; warm sun-facing slopes and
  cool shaded ones. Landform becomes readable through colour alone.
- Everything here is a config knob, and everything here goes in the "Tuned
  blind" section of `STATUS.md`.

*Verify:* comparison shots against `v2-baseline`, plus a flat-meadow close-up
proving the jitter is visible but not noisy.

### Stage 11 - flat ground

Marcel asked for all four. Do them in this order, and stop if the frame or time
budget runs out, recording where you stopped.

1. **Wider valley floors** - `valley_curve` is written and works; tune it now
   that Stage 7 has decoupled it from zoning. This is what made it look like a
   regression before.
2. **Alpine benches** - flat grassy terraces partway up slopes. Very Swiss, and
   they are where campfires and fights will go.
3. **Lake shore flats** - flatten a margin around each lake so shorelines are
   approachable rather than dropping straight in. Plan B will thank you.
4. **Plateau regions** - occasional high tableland as a contrast to ridged
   country.

*Verify:* probe reports **share of map under 10 degrees** before and after -
that number is the point of the stage. Plus comparison shots.

### Stage 12 - spawn, and the distance danger field

- **Spawn guarantee**: search for a spawn that is flat, safe, has a mountain in
  view, and water within about two minutes' walk. The acceptance test should be
  true by construction on every seed, not by luck.
- **Danger field**: worldgen computes and exposes a normalised
  distance-from-spawn danger value. Nothing consumes it yet - the first enemy
  is Plan B territory - but Pillar 3 makes distance the difficulty axis, and
  this is the hook it will hang on.
- **Terrain signals distance**: further out reads wilder - more relief, more
  rock and scree, darker fog. Visual only. Keep it subtle enough that it does
  not fight the zone shares.

*Verify:* ten seeds, every one produces a spawn passing all four criteria.
Report any that fail rather than loosening the criteria.

### Stage 13 - leftovers

- **`Player._face_movement()` is 180 degrees out.** `atan2(wish.x, wish.z)`
  points local +Z along travel, but Godot's forward is -Z; it wants
  `atan2(-wish.x, -wish.z)`. Invisible today because `Body` is a rotationally
  symmetric `CapsuleMesh`. **Verify before changing it** - swap in a temporary
  asymmetric marker mesh, confirm the direction, fix, then restore. Do not fix
  it blind on the strength of this paragraph.
- **Docs tidy**: `IDEAS.md` and `DESIGN.md` still describe terrain v1 as
  upcoming and point at the wrong plan path.

*Verify:* self-tests, and the marker-mesh check recorded in `STATUS.md`.

### Stage 14 - handoff

- Refresh the screenshot tour for the 3 km world, the new scale and the new
  view distance. Six vantage points derived from the world;
  `6-postcard.png` remains the acceptance test.
- Rewrite `STATUS.md` completely. It must contain: every measured number; the
  **"Tuned blind - re-check these first"** section; every departure from this
  plan with its reasoning; what was NOT done and why; and the exact next step.
- Leave **two or three new `TODO(marcel)` exercises** in the systems built
  here, each with a working fallback and a hint, in the style of the v1 three.
  Good candidates: the AO corner test, the bench placement rule, the aspect
  tint curve.
- Record what Plan B - water, rivers and foliage - will need from this work.

---

## If something goes wrong

- Three fix attempts per stage, then commit what works and move on.
- Never leave the repo uncommitted or the game unable to launch.
- A stage that cannot be completed is not a failure of the run - an unfinished
  branch with no `STATUS.md` is.
- If the frame budget cannot be met, **drop the default preset from High to
  Medium** rather than abandoning a stage, and say so. The presets exist
  precisely so scale is a dial, not a rewrite.
- If a stage would require touching the net protocol or bending a pillar, stop
  that stage and write the argument down instead.

## The acceptance test

Unchanged from v1, because it is still the right test:

> Within two minutes of walking from spawn, Marcel should be able to frame a
> mountain, its forested slopes, and a lake in one screenshot.

Stage 12 should make it true by construction. Three additions for v2:

- **The corrugation is gone, and there is real flat ground.** Standing in
  meadow country, the ground reads as flats with hills rising out of them -
  Cube World's shape - not as continuous 30 m bumps. You can stand still on
  level ground without hunting for it.
- **The scale reads.** A mountain looks like a mountain from the valley floor -
  something you would have to climb, not step over.
- **The world does not look flat-shaded and samey.** Blocks read as blocks up
  close, and zones read as distinct bands at distance.

Nothing in this plan matters more than those four.
