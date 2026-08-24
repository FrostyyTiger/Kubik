# Terrain v2 — run status

Unattended run of `docs/plans/terrain-v2.md`, 2026-08-24, on the Linux box.
All fourteen stages attempted, committed one per stage on `feat/terrain-v2`.
**Not merged to `main`** — that is your call, as it was for v1.

---

## Read this first

```
git checkout feat/terrain-v2
godot --path . -- --host --seed 42
```

Walk out of spawn. You will start somewhere flat and dry with a mountain in
view and water within two minutes' walk, because the world now *chooses* a
spawn that satisfies the acceptance test rather than dropping you at the origin
and hoping. **Hold Shift to sprint** — the world is 3 × 3 km now and you will
want it. Alt is a precision crawl.

Six screenshots are in `build/tour/v2-final/`, and three earlier sets sit
beside them for comparison — `v2-baseline` (the world as v1 left it),
`v2-stage5`, `v2-stage9`. Regenerate any of them with:

```
godot --path . -- --tour --seed 42 --label some-name
```

**`build/` is gitignored, so none of those images are in the repo.** If you are
reading this on another machine, run the tour.

### The three things that want your judgement, in order

1. **Is the world too dry?** Water is 0.7% of the map, against 8.3% in v1.
   That number is the single most contested thing in this run and there is a
   whole section on it below. `lake_max_depth` is the dial.
2. **Does the terracing read as landscape or as rice paddies?** It is the
   biggest visual gamble here and it was tuned entirely on a number
   (`terrace_sharpness`, F4 panel).
3. **Is the heath the right colour?** It is a rusty red-brown and it is doing a
   lot of work breaking up the green. On a software renderer it looks right; on
   your screen it may look like Mars.

### The renderer caveat still applies, and it applies harder

This box has no display, so everything was rendered under Xvfb on the **OpenGL
Compatibility renderer on Mesa llvmpipe**. You run **Forward+ on an RTX 5080**.
Every value in the "Tuned blind" section was chosen against the wrong renderer.

---

## What got done

| Stage | What | Verdict |
| --- | --- | --- |
| 1 | Instruments: slope histogram, altitude percentiles, object scale, tour comparison harness | done |
| 2 | Baked corner AO, MSAA 4× | done |
| 3 | Threaded chunk generation | done |
| 4 | View distance presets, far-field LOD rings | done |
| 5 | Far-field transition band | done, then found broken, then fixed |
| 6 | 3 × 3 km world, sprint, traversal probe | done |
| 7 | Seven elevation zones as shares of map area | done |
| 8 | Scale coherence — mountains rise to 1:4 | done |
| 9 | Hills retune, terracing, hill gating, slope-aware zoning | done |
| 10 | Colour jitter and slope/aspect tinting | done |
| 11 | Wider valleys, shore flats, benches, plateaux | done |
| 12 | Spawn by construction, danger field, wildness ramp | done |
| 13 | The 180° facing bug, docs tidy | done |
| 14 | Handoff | this file |

---

## Every measured number

All on seed 42, on this box (i5-8400, 6 cores, 16 GB). Nothing here is an
estimate; where something was not measured it says so.

### The world, before and after

| | v1 (1.5 km) | v2 (3 km) |
| --- | --- | --- |
| Footprint | 1.5 × 1.5 km | **3 × 3 km** |
| Coarse heightmap | 750² cells | 1500² cells |
| Mountain relief | 134 m | **400 m** |
| Relief vs real | 1 : 10.4 | **1 : 3.5** |
| Tree vs real | 1 : 3.5 | 1 : 4.0 |
| Lake vs real | 1 : 3.5 | 1 : 3.3 |
| Meadow share of map | 57.2% | **30.0%** |
| Zones | 4 | **7** |
| Map under 5° | 1.67% | **24.12%** |
| Map under 10° | 6.53% | **36.01%** |
| Mean slope | 36.5° | 30.7° |
| Trees | 8,620 | 34,915 |
| Lakes | 289 | 53 |
| Water | 8.3% of map | **0.7% of map** |
| Worldgen memory | ~11 MB | 36.6 MB |

### Layer slopes — the corrugation, as a number

`4 × amplitude / wavelength`, which is the angle the eye reads off a hillside.

| Layer | v1 | v2 |
| --- | --- | --- |
| Continent | 602 m / 24 m / 9.1° | 1579 m / 62.9 m / 9.1° |
| Mountain | 150 m / 89 m / 67.1° | 394 m / 233 m / 67.1° |
| **Hills** | **30 m / 8 m / 46.9°** | **180 m / 8 m / 10.1°** |
| Detail | 6 m / 1.5 m / 45° | 6 m / 1.5 m / 45° |

The hills layer was as steep as a mountain face at a 30 m wavelength, laid over
the whole world at uniform strength. That was the corrugation.

### The hills wavelength sweep

Share of map under 5°, at 8 m amplitude:

| 30 m | 90 m | 120 m | **180 m** | 240 m | 360 m |
| --- | --- | --- | --- | --- | --- |
| 1.30% | 3.84% | 4.50% | **5.29%** | 5.58% | 5.63% |

180 m takes almost all of the gain and everything past it is decimal places.
It also lands the layer at 10.1°, which is the plan's target.

**The sweep's more important result is that wavelength alone is not enough.**
Even at 360 m the mean slope only fell from 45.7° to 40.3° and five-sixths of
the map was still steeper than 10°. fbm noise is a sum of smooth waves, so
every point sits on some slope and genuinely level ground has measure zero.

### Where the flat ground actually came from

| Change | under 5° | under 10° |
| --- | --- | --- |
| v2 start | 1.30% | 5.12% |
| + hills at 180 m | 5.29% | 17.75% |
| + wavelengths scaled with amplitudes | 11.96% | 29.66% |
| + terracing (h 8, sharpness 1.5) | 20.30% | 32.72% |
| + hill gating | ~20.3% | ~32.7% |
| + valley_curve 1.6 | 25.64% | 38.49% |
| final, with the wildness ramp | **24.12%** | **36.01%** |

### Threading (Stage 3)

| | before | after |
| --- | --- | --- |
| radius 8, wall | 10,309 ms | 7,945 ms |
| radius 8, main thread | 4,811 ms | **599 ms** |
| radius 12, wall | 22,335 ms | 17,755 ms |
| radius 12, main thread | 10,936 ms | **1,406 ms** |

Main-thread cost down about 90% at both radii.

**The first attempt made wall time worse** — 12,515 and 27,834 ms. Godot gives
the low-priority worker pool 30% of its threads by default; meshing alone had
had those two, and putting generation on them too meant both phases fought over
the same two. `project.godot` now sets `low_priority_thread_ratio` to 0.75.
Without that line, Stage 3 is a regression.

### View distance presets (Stage 4)

| Preset | radius | voxels to | fog | chunks | load wall | main thread | far verts |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Low | 6 | 48 m | 400 m | 700 | 4,204 ms | 269 ms | 69,280 |
| Medium | 8 | 64 m | 500 m | 1,201 | 7,109 ms | 483 ms | 75,088 |
| **High** | 12 | 96 m | 600 m | 2,653 | 18,210 ms | 1,167 ms | 80,352 |
| Ultra | 16 | 128 m | 800 m | 4,829 | 29,677 ms | 2,121 ms | 81,872 |

The far field was **404,588 vertices at fog 600** before LOD rings and is
**80,352** after. It now grows 18% for a doubling of view distance rather than
four times. Fog has stopped being a performance dial.

### Baked AO (Stage 2)

75 surface chunks: **10,157 → 17,246 quads (+69.8%)**, **802.6 → 1,152.8 ms
(+43.6%)**. Meshing is on worker threads, so that time is off the main thread.

### Zone shares (Stage 7), and the live test of them (Stage 8)

Worst zone, percentage points off target:

| seed 42 | seed 7 | seed 12345 | after relief ×2.5 | final |
| --- | --- | --- | --- | --- |
| 0.42 | 0.23 | 0.41 | **0.21** | 0.60 |

The fourth column is the point of the whole stage: mountain relief changed by
two and a half times and the seven shares did not move. Absolute thresholds
would have re-zoned the entire world as a side effect.

### Cost of the 3 km world (Stage 6)

| | 1.5 km | 3 km |
| --- | --- | --- |
| Heightmap | 1,257 ms | 5,150 ms |
| Lakes | 1,039 ms | 4,900 ms |
| Spawn search | — | 780 ms |
| Memory | 8.6 MB + 17.8 | 8.6 MB + 28.0 = **36.6 MB** |

**World setup is now about 11 seconds before the first chunk is queued**, on
top of 18–23 s of chunk loading at High. Both of those passes are on the main
thread and neither is threaded. This is the biggest single thing left undone —
see "the exact next step".

### Chunk cost of the higher relief (Stage 8)

2,653 → 3,386 chunks queued at High (+28%), load 18.1 s → 23.0 s (+27%).
Chunks follow the surface rather than bedrock, so more relief is more vertical
spread and not a proportional explosion. The default preset stays at High.

### Two peers, one world

Host at High, client at Low, headless, on this machine:

```
host   config 756afa4  heightmap 6310d674  289 lakes
client config 756afa4  heightmap 6310d674  289 lakes   -> SAME WORLD
```

That the two view distances differ and the join still succeeds is Stage 4's
property split working. Before it, they could not have joined at all.

### Spawn (Stage 12)

Ten seeds — 1, 7, 42, 99, 123, 512, 2024, 31337, 65535, 999999. **All ten
produce a spawn meeting every criterion.** 8,836 candidates in ~780 ms each.

Across all ten, slope rejects about 60% of candidates and **water and mountain
reject none**. The world is short of flat ground, not short of scenery.

---

## Tuned blind — re-check these first

Every value here was chosen by looking at a software-rendered screenshot on a
box with no display, or in three cases by looking at no screenshot at all.
They are all in `WorldgenConfig` and all reachable from the **F4** panel, so
each one is a ten-second reroll away from being something else. Previous values
are kept beside the new ones rather than deleted.

| Knob | Was | Now | What it does | How it was judged |
| --- | --- | --- | --- | --- |
| `ao_strength` | — | 0.45 | how dark an enclosed corner goes | convention; screenshot |
| `msaa_level` | off | 4× | antialiasing | not judged — cannot be, here |
| `terrace_height` | — | 8 blk | shelf spacing | number (flat ground) |
| `terrace_sharpness` | — | 1.5 | how much of a shelf is flat | number, traded against lakes |
| `hills_gate_strength` | — | 1.0 | hilly vs flat districts | number, and a weak one |
| `slope_zone_strength` | — | 1.0 | slope-aware zoning on | screenshot |
| `rock_slope_deg` | — | 78° | steep ⇒ bare rock | **share budget, not physics** |
| `snow_max_slope_deg` | — | 72° | snow slides off steeper | screenshot, second attempt |
| `color_jitter_value` | — | 0.05 | per-vertex brightness | **not judged** |
| `color_jitter_hue` | — | 0.02 | per-vertex hue tilt | **not judged** |
| `color_jitter_blocks` | — | 12 blk | tint cell size | **not judged** |
| `slope_tint` | — | 0.10 | steep faces darker | **not judged** |
| `aspect_tint` | — | 0.06 | sun-facing warmer | **not judged** |
| `bench_strength` | — | 0.7 | alpine benches | **not judged — see below** |
| `plateau_strength` | — | 0.6 | high tableland | **not judged — see below** |
| `lake_max_depth` | 10 blk | 2 blk | how far basins fill | number, four times over |
| `lake_min_depth` | — | 1 blk | below this it is wet ground | number |
| `shore_flat_blocks` | — | 4 blk | detail fade at the water line | screenshot |
| Heath colour | — | `#8C5F4B` | the rusty band | screenshot |
| Alpine colour | — | `#A7B860` | yellow turf band | screenshot |
| Shore colour | — | `#BFB48C` | wet gravel | screenshot |

**The five colour-tint knobs and the two masked-terrace knobs were never seen
at all.** For the tints, the software renderer's tonemapping is different
enough that a 5% brightness jitter is not something I would trust myself to
judge from it. For the benches and plateaux, the probe genuinely cannot help:
they are local by design, so the world-wide share of map under 5° moves from
25.64% to 25.67% whether they are on or off. **Walk a mountain shoulder and
look.**

`rock_slope_deg` deserves its own line. Vegetation genuinely stops around
40–45°, and at 45 that rule converts 29% of the map, overshoots rock's 11%
target by **nineteen points** and collapses snow to 0.8%. "Steep faces become
rock at any altitude" and "zone shares still within tolerance" cannot both hold
on terrain this steep. The threshold is therefore set by the share budget, and
the honest consequence is that the rock rule barely fires below the treeline.
**If you want visible crags in the forest, this is the knob, and the shares
will move.**

---

## The dry world — the one thing I would change first if you disagree

Water fell from 8.3% of the map to 0.7%, and 289 lakes became 53.

This was not one decision. `lake_max_depth` was re-tuned **four times** across
the run, because every stage that flattened the world changed how far a given
cap spreads the water:

| After | flat ground | lake_max_depth | largest lake | water |
| --- | --- | --- | --- | --- |
| Stage 8 (relief ×2.5) | 5.3% | 11 blk | 1 : 4.0 | 2.4% |
| Stage 9 (wavelengths) | 12.0% | 5 blk | 1 : 3.0 | 1.7% |
| Stage 9 (terracing) | 20.3% | 4 blk | 1 : 3.0 | 2.6% |
| Stage 11 (valley_curve) | 25.6% | 2 blk | 1 : 3.3 | 0.7% |

Each row is inside the plan's own acceptance band of 1:3 to 1:5. Each row is
drier than the one above it. **The two criteria pull in opposite directions and
the plan only names one of them.**

There is also a measurement problem underneath it, and you should know about it
before trusting the column that drove all four decisions. The scale test is
"largest lake vs a 400 m tarn", and **the largest lake in a world gets bigger
as the world gets bigger** — that is extreme value statistics, not terrain.
The world quadrupled in area in Stage 6, which on its own should have moved the
largest lake by about a factor of two. Held to a fixed 400 m reference, the
test therefore got roughly twice as strict without anybody deciding it should.

If the world looks too dry on your screen: **`lake_max_depth` 3 gives 1.3%
water and 91 lakes, 4 gives 1.8% and 121.** Both put the largest lake outside
the plan's band, at 1:2.7 and 1:2.2 — and I think that band is wrong for a 3 km
world rather than the lakes being wrong. Your call; the numbers are here so it
can be one.

A second thing came out of the same corner. Terracing **manufactures water**: a
perfectly flat shelf with any rim at all floods across its whole width however
shallow the cap is. Seed 42 produced 185 "lakes" of which **138 were films ten
centimetres deep** — wet ground drawn as lake surface. `lake_min_depth` now
discards them. `terrace_sharpness` is the other end of that trade:

| sharpness | under 5° | largest lake | water |
| --- | --- | --- | --- |
| 1.5 | 20.30% | 1 : 3.0 | 2.6% |
| 2.0 | 23.10% | 1 : 2.3 | 4.3% |
| 3.0 | 27.88% | 1 : 1.8 | 7.7% |

---

## Departures from the plan, and why

Every one of these is a place where the plan said one thing and this run did
another. None of them was a judgement call I wanted to make alone; all of them
were forced.

**1. `voxel_radius_chunks`, `far_step`, `fog_start_m` and `fog_end_m` moved out
of `PROPERTIES`.** The plan's hard rule 2 says every config field joins that
array. Those four were in it, which meant a laptop could not join a desktop —
their config hashes differed — and if they somehow did, `from_dict()` would
overwrite the joiner's view distance with the host's. **Stage 4's own preset
would have shipped as a setting that breaks multiplayer the moment anyone used
it.** None of the four can move a block: an edit outside a client's voxel
radius is still recorded in `World._edits` and replayed when that chunk loads.
Verified with two headless peers at different presets.

**2. `ao_strength`, `msaa_level` and the five colour knobs never joined
`PROPERTIES` either**, for the same reason in a milder form. A shape knob is a
determinism contract; a look knob is not. Two machines disagreeing about
`ao_strength` see the same terrain with slightly different shading, and hashing
that would turn a cosmetic preference into a refused join.

**3. `world_scale` scales wavelengths as well as amplitudes.** The plan's Stage
8 lists `world_height_blocks`, `max_altitude`, `mountain_amp` and
`continent_amp` and no frequencies. Scaling only those made the mountain layer
2.6× taller over the same 150 m footprint, took its characteristic slope from
67° to 81°, and put **34.7% of the map past 60°** — unwalkable, since the
character's floor angle is 55, and exactly why the first traversal run wedged
against a hillside. What that produces is not a bigger mountain, it is a spire.

**4. The plan is wrong that `terrace_sharpness` 1.0 is a no-op.** At 1.0 the
transform is `smoothstep(frac)`, an S-curve with zero gradient at both ends —
already terracing, and it takes flat ground from 11.96% to 15.68% on its own.
`terrace_height` 0 is the real off switch and is what the knob ships behind.

**5. Stage 11's items were reordered.** The plan says valley floors, benches,
shore flats, plateaux, and to stop when the budget runs out. Shore flats were
promoted ahead of benches because the Stage 9 postcard showed the shoreline as
the worst thing left in the frame. All four landed.

**6. `zone_blend_blocks` does not scale with `world_scale`**, though the first
version of Stage 8 scaled it along with the other altitude quantities. A blend
band is a distance in altitude and the area it covers depends on how steep the
ground is; on the flats Stage 9 had just created, an entire plain sat inside
one 15.7-block band and came out as green-and-tan confetti.

**7. Stage 13's facing fix was verified by assertion, not by a marker mesh.**
The plan says to swap in an asymmetric mesh and look. The self-test instead
asserts, across ten directions, that the yaw sends Godot's own
`Vector3.FORWARD` along the wish direction — and that the OLD expression fails
the same check, without which it would prove nothing about the bug having been
real. That is the same identity checked exactly rather than by eye, and for
every direction rather than the few you would try.

**8. The self-test suite moved from `--script` to a scene.**
`godot --headless --path . scenes/selftest.tscn`. `--script` replaces the main
loop and Godot only creates autoloads for a real one, so `World` — which names
the `Net` autoload — cannot even be compiled under it. The symptom is not that
error but a much stranger one: `World.new()` reporting that GDScript has no
function called `new()`. `Engine.register_singleton()` is not a way round it;
it fills a different table from the one the GDScript compiler resolves autoload
names against.

**9. Darker fog with distance was not done.** Since Stage 4 fog is a per-machine
local setting, and driving it from world position is a runtime change to
`SkyCycle` rather than a worldgen one. The other two halves of "terrain signals
distance" — more relief and more scree further out — are in.

---

## Things found along the way that were not in the plan

**`mountain_mask_lo`, `mountain_mask_hi` and `lake_max_depth` were missing from
`WorldgenConfig.PROPERTIES`.** All three shape the world — the mask decides
where mountains are allowed to exist at all — so two machines disagreeing about
any of them would have generated different terrain **while the handshake
reported a match**. That is exactly the silent desync the hash exists to catch.
Found by auditing the array against the `@export` block.

**The screenshot tour was photographing the night.** A day is 480 s and a
six-shot tour under software rendering takes about five minutes, so the sun set
between shot 3 and shot 4 and shots 4 and 5 of every tour this box has ever
taken came back as black rectangles. It has been like that since v1 and it
never showed on your GPU, where the tour is over before the light moves. The
black frames are the obvious half; the half that matters is that a comparison
harness whose lighting depends on how long rendering took compares the wrong
thing. `SkyCycle.frozen` now pins it.

**The self-test suite could report success while a test crashed.** A test
declared `-> int` that hits a runtime error returns 0, which this file read as
"passed". The Stage 3 test crashed on its second line and the suite printed
"all passed" twice before that was noticed. The tests are now untyped, so an
aborted one returns `null` — a value no test returns on purpose — and the
harness names it.

**The player would have frozen at spawn on most seeds.**
`_release_player_when_ground_exists()` waited for the chunk at (0, 0), and
Stage 12 moved spawn off the origin. The world loads chunks around the PLAYER,
so a spawn further from the origin than the voxel radius — 192 blocks at High,
against a spawn search ranging over 750 — means the chunk at (0, 0) never
loads and physics is never re-enabled. **Seed 42 spawns 131 blocks out and
worked by luck.** Found by the traversal probe reporting 0 m walked in 90
seconds.

**The shore-flat fade was reading the wrong water level.** `Lakes.water[]`
holds the priority flood's SPILL level — the lip the basin would pour over —
and the actual surface is capped far below it for a broad shallow basin. The
fade was therefore applied in the wrong altitude band and the shoreline stayed
exactly as broken as before the fix. The Stage 11 postcard is what caught it.

**Adding a new `class_name` file needs the editor import re-run** —
`godot --headless --editor --quit --path .` — before the class resolves
anywhere. Until then the symptom is, again, "Nonexistent function 'new' in base
'GDScript'", on a completely different class.

---

## What was NOT done

- **Darker fog with distance.** See departure 9.
- **Threading the heightmap, the lake flood and the spawn search.** All three
  are single-threaded main-thread passes and together they are ~11 s of the
  boot. Not in the plan's scope; it is the next thing worth doing.
- **A second pass at the mountain silhouette.** The ridged mountain layer still
  produces sharp combs along a crest — visible in `2-summit.png` in every set.
  It is v1's silhouette at v2's scale, so it is not a regression, but it is not
  a Swiss pre-Alp either.
- **Anything about water beyond keeping it in scale.** Rivers, flow, shorelines
  with beaches. That is Plan B.
- **The edit-log compaction** that `IDEAS.md` still lists as blocking terrain
  destruction. Untouched.

---

## The exact next step

**Thread `World.setup()`.** The world spends about 11 seconds on the main
thread before a single chunk is queued — 5.2 s building the coarse heightmap,
4.9 s flooding the lakes, 0.8 s searching for a spawn — and then 18–23 s
streaming chunks. The chunk half is already threaded and costs 1.4 s of main
thread; the setup half is not threaded at all.

The heightmap loop is embarrassingly parallel by row and every dependency it
has is read-only. The lake flood is not parallel, but it does not have to run
on the main thread either. Doing this would take the boot from about 30 seconds
to something you would not go and make coffee during, and it is the single
biggest remaining cost in the whole system.

After that, in order: look at the three "wants your judgement" items at the top
of this file, then decide whether the world is too dry.

---

## Three new TODO(marcel) exercises

Same shape as the v1 three: each has a fallback that works, a hint, and nothing
depends on it being done.

1. **`ChunkMesher._ao_curve()`** — the ambient occlusion curve is a straight
   line and probably should not be. Straight-line spreads the darkening evenly
   over all four occlusion levels, so level 2 is already noticeably dark — and
   most of a voxel world is level 2, so most of the world gets a little dirty
   and the true corners never get to be dramatic. Squaring it is one line.

2. **`Block.aspect_curve()`** — the aspect tint varies smoothly through every
   angle, which is physically reasonable and visually weak, because almost
   every face in a voxel world is side-on and gets almost no tint. A real
   Alpine hillside is two kinds of slope, not a gradient between them.

3. **`TerrainGenerator._bench_placement()`** — benches are placed by noise,
   which is a fine way to pick districts and a poor way to pick a bench. A
   bench is a place where a slope eases off, and the terrain already knows
   where those are. This one has a trap in it worth finding: flattening the
   ground changes its slope, so a rule that reads the slope it is about to
   change can chase its own tail. The comment says where the trap is; work out
   whether it is a bug or a feature before relying on it.

---

## What Plan B will need from this work

Water, rivers and foliage. Several things here exist specifically for it:

- **`Lakes.shore_level` / `shore_near`** — a dilated field giving the water
  level near any cell, built by scattering outward from flooded cells rather
  than scanning for them. Rivers will want the same field and the same trick;
  a gather pass over 2.25 million cells is not affordable and a scatter from
  the wet ones is.
- **`TerrainGenerator.detail_at()` already fades near water**, so anything that
  puts more water in the world gets a clean edge for free.
- **The threshold solver closes the loop.** Any new rule that moves cells
  between zones — a river carving its banks, a flood plain, a burnt area — is
  absorbed by the correction rounds without touching the solver. Add the rule,
  and the seven shares hold.
- **`lake_max_depth` is the water dial** and it is in the F4 panel. Read the
  "dry world" section above before turning it: it is where this run and the
  plan's acceptance criteria disagree, and Plan B owns the argument.
- **Foliage will hit the greedy-meshing constraint** that Stage 10 hit: per-
  block variation is incompatible with merging. The way round it was to move
  the variation into the vertices; the way round it for AO was to let the code
  join the mask and split the quads. Whichever a grass or flower layer needs,
  both patterns are in `ChunkMesher` with the reasoning written down.
- **The far field will need to know about water.** It draws terrain only, so a
  lake more than 96 m away is currently invisible. Nobody has noticed because
  fog is thick, but a river you can see the length of will make it obvious.

---

## Where this run met the design

`docs/DESIGN.md` gained a scale section and a traversal section in Stage 6, and
its "one fixed 1.5 × 1.5 km region" line is now 3 × 3 km with the reasoning
beside it — including why full scale was rejected in writing, so it is not
relitigated. `docs/IDEAS.md` no longer describes terrain v1 as upcoming.

Against the pillars:

- **BETTER TOGETHER.** Nothing here is solo-tuned. Stage 4 made it possible for
  two players on unequal machines to be in the same world at all, which it was
  not before.
- **TENSE OUT, COZY IN THE LIGHT.** The alpine benches are where a campfire
  goes. `danger_at()` exists, and the terrain already grows wilder with it.
- **THE WORLD IS THE CONTENT.** The world is four times the area, the mountains
  are three times as tall, and distance now reads as wildness in the terrain
  itself rather than only on a map.
