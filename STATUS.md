# Foliage v1 — run status

Unattended overnight run of `docs/plans/foliage-v1.md`, 2026-08-24/25, on the
Linux box. All eleven stages attempted and committed on `feat/foliage-v1`,
branched from `main` at `198274d` (the terrain work — threaded heightmap,
detail damping on flats, the queue that does not scan).

---

## Read this first

```
git checkout feat/foliage-v1
godot --path . -- --host --seed 42
```

Walk out of spawn into the meadow. **It is not one quad any more.** Grass moves
in the wind, flowers come in fields of a single colour, and there is a lone
beech somewhere in the frame. Walk up the slope on your right and the forest
closes over you; keep going and it thins into twisted pine before it gives up
at the heath. Look back down the valley and the forest is still there at 300 m
rather than stopping at a circle centred on you.

Press **F3** for the readout — it now shows flora instances, flora triangles,
columns, and the impostor ring's count and rebuild time. **F4** has every new
knob. Wait for dusk, or press F4 and set `day_start`, to see the fireflies.

Two sets of pictures:

```
build/tour/foliage-final/     twelve vantages, seed 42
build/gallery/foliage-final/  every tree species, every plant model
```

Regenerate either with:

```
godot --path . -- --host --tour --seed 42 --label some-name
godot --path . scenes/gallery.tscn -- --label some-name
```

**`build/` is gitignored, so none of those images are in the repo.** Run them.

### The five things that want your judgement, in order

1. **Is the ground cover too dense, or not dense enough?** A meadow block
   carries something with probability 0.50. On a software renderer that reads
   as a meadow; it may read as a lawn on yours. `flora_draw_fraction` in the F4
   panel thins it without changing where anything is, so you can turn it down
   and back up while standing still.
2. **Are the impostor trees convincing at the handover?** Walk from the meadow
   into the forest and watch the middle distance. The ring hands over to real
   voxel trees at 96 m, and impostors grow from nothing over the 12 m outside
   that. If you can see it happen, say so — the fade length is a constant in
   `far_trees.gd` and wants a real GPU to tune against.
3. **Are the colours right?** Eleven new leaf and bark colours and seventeen
   plant colours, every one chosen on the wrong renderer. The whole list is in
   "Tuned blind" below.
4. **Nights are very dark, and this run is the first thing that has cared.**
   Not a foliage change — `sun_energy` has floored at 0.04 since terrain v1 —
   but glowing mushrooms and fireflies are the first content that only exists
   after dark, and putting them in made it obvious. Under a forest canopy at
   night the frame is genuinely black; in the open meadow it reads beautifully
   (`12-meadow-night.png`). There is still no torch. Worth deciding whether
   that is the intended "tense out" register or whether the floor wants
   raising, before the enemy makes it a gameplay question.
5. **Is a snag every seventh tree too many?** 14.7% of the world's trees are
   dead ones. That is what the plan's weight table plus its wildness bonus
   produce, and it is more than it sounds like when you are standing in it.
   `wildness_snag` is the dial.

### The renderer caveat still applies, and it applies harder than in v2

This box has no display, so everything was rendered under Xvfb on the **OpenGL
Compatibility renderer on Mesa llvmpipe**. You run **Forward+ on an RTX 5080**.
Terrain v2 tuned nine block colours that way. This run tuned twenty-eight
colours, nineteen models and seven tree shapes.

**What the gallery is for.** Stage 1 built it before anything else changed, and
it earned that position three times over — see "Things the gallery caught"
below. One image, every species, a fixed camera, a frozen noon sun: whatever
you disagree with, you can point at it.

---

## What got done

All eleven stages. One commit each, except Stages 8 and 9, which landed
together because both touch `flora_placement.gd` and separating them afterwards
would have been a fiction.

| Stage | What | Commit |
| --- | --- | --- |
| 1 | Instruments: model gallery, five new tour vantages, per-species probe | `efd242e` |
| 2 | Trees move out of `TerrainGenerator` — a pure refactor, verified tree-for-tree | `d182250` |
| 3 | Seven species instead of one, eleven new block ids | `e816660` |
| 4 | The placement product: groves, glades, slope, bench, spawn | `474fb37` |
| 5 | The decoration layer, with one model | `d2f32fc` |
| 6 | Eighteen more models and every zone rule | `f53f7ba` |
| 7 | The impostor ring — a forest that does not stop at 96 m | `0927f9c` |
| 8+9 | Night, and the path gathering will use | `c257060` |
| 10 | The budget, measured | (this file) |
| 11 | Handoff | (this file) |

---

## Every measured number

### The world, before and after

Seed 42 throughout. "Before" is `main` at `198274d`, which is the same terrain.

| | before | after |
| --- | --- | --- |
| Trees | 34,925 | **73,675** |
| Species | 1 | **7** |
| Ground cover instances | 0 | **8,761,600** |
| Heightmap hash | `76cccdb6` | `76cccdb6` — unchanged |
| Zone shares | worst 0.60 pts off | unchanged |
| Spawn | (-44, -124) | unchanged |
| Config hash | `5d5eee15` | `da8868d1` |

The heightmap hash, the zone shares and the spawn are identical at every stage
of this run. **Nothing moved that should not have** — that is the fourth
acceptance criterion and it is the one with a hash behind it rather than a
photograph.

### Trees, by species

| Species | seed 42 | share |
| --- | --- | --- |
| spruce | 28,849 | 39.2% |
| beech | 15,761 | 21.4% |
| larch | 9,782 | 13.3% |
| snag | 10,821 | 14.7% |
| krummholz | 7,386 | 10.0% |
| birch | 777 | 1.1% |
| hero | 299 | 0.4% |

Groves are **35.6%** of the forest band against 35% asked for; glades **12.4%**
against 12%. Both thresholds are measured from the noise's own distribution at
world build time rather than guessed — see "Departures" for why that matters.

**Birch at 1.1% is the one number I would look at first.** It grows only in the
shore band and as a quarter of meadow trees, and the shore band is 3.9% of the
map with a further condition on top. It is not zero anywhere, but it is rare
enough that you can walk a long way without seeing one.

### Ground cover, by zone

Estimated by sampling every 16th block and scaling — the line in the probe says
so. Every model occurs.

| Zone | instances |
| --- | --- |
| meadow | 5,344,256 |
| forest | 2,077,952 |
| alpine | 694,528 |
| shore | 462,592 |
| heath | 171,776 |
| rock | 6,912 |
| snow | 3,584 |

### The traversal check — the one that mattered most in Stage 4

Dense forest that stops the player is a placement bug, not a feature.

| | baseline (v2) | foliage v1 |
| --- | --- | --- |
| Speed made good, first 30 s | 12.82 m/s | **12.97 m/s** (101%) |
| Speed made good, first 60 s | 10.20 m/s | 10.10 m/s (99%) |
| Wedged after | 612–840 m | 639 m |

The plan's floor was 75% of baseline. The forest did not cost anything
measurable, and it still wedges in the same place and the same range the bare
terrain did — that is terrain v2's unsolved navigation problem, not this one.

### The performance budget — one met, one missed

Measured at High on seed 42, against `main` at `198274d` (the same terrain,
before any of this). Both runs on this box, which was running other work all
night; treat the wall clock as a ratio rather than an absolute.

| | before | after | budget |
| --- | --- | --- | --- |
| Chunks queued | 2,949 | 3,541 | — |
| Chunks built | 3,051 | 3,742 | — |
| **Boot to `is_idle()`** | 34.3 s | **60.3 s (+76%)** | **+10% — MISSED** |
| Main-thread time during load | 4.08 s | 6.10 s (+49%) | +10% — missed |
| Generation per chunk, worker | 7.46 ms | 15.45 ms | — |
| Mesh upload per chunk, main | 0.85 ms | 0.96 ms | — |
| Far-field vertices | 80,320 | 80,320 | — |
| Flora | — | 24,490 instances, 2.72 M triangles, 197 columns, 15.2 ms/column | — |

**The triangle budget is MET, at every one of the twelve vantages.** The plan
sets it at 1.5 M flora triangles in frame at High, measured with
`RENDER_TOTAL_PRIMITIVES_IN_FRAME`. The tour now prints that beside every
photograph, along with the flora actually loaded around the camera:

| Vantage | primitives IN FRAME | flora instances | flora triangles loaded |
| --- | --- | --- | --- |
| 1-spawn (meadow) | 1.20 M | 24,145 | 2.73 M |
| 2-summit | 0.35 M | 222 | 0.07 M |
| 3-forest-slope | **1.62 M** | 2,126 | 0.36 M |
| 4-valley-floor (meadow) | 1.12 M | 25,558 | 2.82 M |
| 5-lake | 0.80 M | 19,125 | 1.63 M |
| 6-postcard | 0.49 M | 1,812 | 0.32 M |
| 7-forest-interior | 1.27 M | 11,578 | 1.74 M |
| 8-meadow-closeup | 1.03 M | 25,295 | 2.77 M |
| 9-treeline | 1.02 M | 12,090 | 1.53 M |
| 10-shore | 0.38 M | 10,903 | 0.99 M |
| 11-forest-dusk | 0.79 M | 11,578 | 1.74 M |
| 12-meadow-night | 0.89 M | 25,295 | 2.77 M |

**The worst frame in the world is 1.62 M primitives, and that INCLUDES terrain
and the far field** — so flora's share of it is smaller again, and the highest
figure is a forest slope where ground cover is 2,126 instances. The flora
budget has room everywhere.

The two columns are worth reading together. "Loaded" is every flora triangle in
the 197 columns around the player, a full 360°; "in frame" is what the frustum
actually kept. The ratio is consistently about a third, which is what makes the
loaded figure a usable proxy for zones the tour does not visit.

**The one vantage not measured is a heath**, and arithmetic says it is about
level with the meadow rather than worse: heath carries a shrub on roughly one
block in eight, which is ~6,300 shrubs inside `flora_radius_m` at 480 triangles
each, or ~3.0 M loaded — against the 2.82 M a meadow already reaches without
trouble. `flora_radius_m` is the dial if it turns out otherwise, and a tour
vantage in heath is the honest way to settle it.

**THE BOOT BUDGET IS MISSED AND CANNOT BE MET BY KNOBS**, so it ships as
measured, and here is the accounting:

- **+23% chunks.** Not flora. The world reserves empty sky above the terrain
  for the tallest tree that can grow there, and the hero pushed that from 23
  blocks to 45. That is a bigger vertical column everywhere for a tree that
  occurs once per 300 × 300 m of meadow.
- **+107% generation per chunk.** The world grows 2.1× the trees through a
  six-term product instead of a one-term probability. Two rounds of
  optimisation already took the whole-world placement pass from 68.4 s to
  27.5 s; what is left is real work.
- **Flora is the small term** — 197 columns × 15.2 ms is 3.0 s of worker time
  out of 60.

**The budget as written is not reachable alongside the plan's own tree
target.** The plan says tree counts "will roughly double or triple. That is
intended", and doubling the trees cannot cost +10% of the time spent building
them. The honest number is above; the fix that would actually move it is named
under "The exact next step".

### The ten-seed sweep

Every seed the plan names. All boot, all spawn clear of trees, and **every
species occurs on every one of them** — no seed had to be reported with zero
larch.

| seed | trees | nearest tree to spawn |
| --- | --- | --- |
| 1 | 64,898 | 30.3 m |
| 7 | 72,711 | 30.0 m |
| 42 | 73,675 | 42.6 m |
| 99 | 68,945 | 33.3 m |
| 123 | 76,039 | 30.9 m |
| 512 | 72,191 | 43.5 m |
| 2024 | 76,451 | 32.0 m |
| 31337 | 76,954 | 25.5 m |
| 65535 | 73,079 | 30.3 m |
| 999999 | 64,982 | 39.9 m |

Not one has a tree inside the 24 m clearing the placement rule promises, and
the nearest anywhere in the sweep is 25.5 m. The rarest species anywhere is
birch at 658 on seed 1, so it is thin everywhere and absent nowhere — the plan
allowed for reporting a seed with zero larch rather than adjusting the table,
and no seed needed it.

### Two peers, one world

```
host   --view high   voxel radius 12 chunks (96 m)   config da8868d1
client --view low    voxel radius  6 chunks (48 m)   config da8868d1
```

Identical config hashes at different view distances, which is the check that
the twenty-one new SHAPE knobs went into `PROPERTIES` and the five new LOCAL
ones did not. A client that disagreed about `grove_share` would grow its
forests in different places while the handshake reported a match.

### Triangles per flora model

Measured, at the voxel scale each model actually ships at.

| model | voxels | triangles | | model | voxels | triangles |
| --- | --- | --- | --- | --- | --- | --- |
| grass_tuft_a | 14 | 132 | | shrub_a | 128 | 480 |
| grass_tuft_b | 9 | 96 | | shrub_b | 56 | 272 |
| grass_short | 7 | 68 | | boulder_s | 21 | 124 |
| flower (×4) | 12 | 80 | | boulder_m | 110 | 376 |
| fern | 32 | 340 | | boulder_l | 369 | 1,156 |
| mushroom | 8 | 68 | | scree_a / _b | 21 / 59 | 176 / 292 |
| alpine_flower | 5 | 40 | | reed | 47 | 372 |
| | | | | firefly | 1 | 12 |

**Boulders and shrubs are not built at 8 voxels per block**, and that is a
departure the budget forced — see below. At 8 the large boulder was **35,964
triangles**, one rock costing more than two hundred grass tufts.

### The impostor ring

| | without LOD | shipped |
| --- | --- | --- |
| Impostors at High | 1,439 | 612 |
| Rebuild, worker ms | 1,432 | **399–810** |

Rebuilt every 16 m of movement. The spread is contention on this box, which
was running other work all night; take the low end as the real figure.

### Self-tests

Eight, up from six. All pass.

```
winding             49252 triangles checked, 0 wrong
ao cost             75 chunks, +73.1% quads, +51.5% ms
tree borders        250 chunks, 0 differed under a 6x margin
species borders     7 species stamped across chunk boundaries, 0 wrong
sky reserve         4 scales checked, 0 short
flora determinism   25 columns, 1574 instances, 0 differed
flora removal       78 instances -> 77, 0 wrong
chunk determinism   same hash twice
edit during generation, facing, day cycle, config contract   all pass
```

**Two of the three new tests found real bugs before they shipped**, which is
the whole argument for writing them:

- **`sky reserve`** caught the tree-height reserve scaling its own safety
  margin. At `tree_size_scale` 0.5 the world reserved 23 blocks of sky for a
  tree that needs 24. The symptom would have been heroes with flat tops, in
  some columns, on small-scale worlds only.
- **`species borders`** is the definition of the border-safe stamp stated
  directly: draw a tree once into an unbounded buffer, again into every chunk
  around it, and require the union of the clipped copies to equal the whole.
  Six of the seven shapes had never been drawn across a boundary before it.

---

## The acceptance test

> Standing inside the forest at dusk, it reads as a forest: trunks around you,
> undergrowth at your feet, canopy overhead, and the treeline visible as a
> thinning to twisted pines above. From the meadow below, that same forest is
> still there at 300 m.

`11-forest-dusk.png` is the first sentence, `6-postcard.png` and
`9-treeline.png` the second. Judge them yourself; they were composed on a
software renderer.

The three additions:

- **A meadow is not one quad.** Compare `build/tour/stage4/1-spawn.png` with
  `build/tour/foliage-final/1-spawn.png`. Same terrain, same seed, same camera.
- **Every species is tellable from the others in the gallery** without reading
  the label. `build/gallery/foliage-final/gallery.png`, and one close-up each.
- **Nothing moved that should not have.** Heightmap hash, zone shares and spawn
  identical, line for line, at every stage.

---

## Tuned blind — re-check these first

Everything in this section was judged on OpenGL Compatibility under Xvfb.
Nothing here was chosen from a screenshot of the world; all of it was chosen
from the model gallery, which is the whole reason Stage 1 built one.

### Leaf and bark colours (`Block.COLORS`, ids 12–22)

Stored linear, authored as sRGB hex. `LEAVES` (spruce A) and `TRUNK` keep their
old ids and values, so nothing already in the ground changed colour.

| Block | hex | Note |
| --- | --- | --- |
| `LEAVES_SPRUCE_B` | `#557F38` | shade B of the existing `#4E7A32` |
| `LEAVES_BEECH` / `_B` | `#6E9C3E` / `#78A448` | mid green, lighter than spruce |
| `LEAVES_LARCH` / `_B` | `#B89B3C` / `#C2A649` | yellow-gold — the loudest new colour |
| `LEAVES_PINE` / `_B` | `#3C6B4C` / `#437356` | krummholz, bluish |
| `LEAVES_BIRCH` / `_B` | `#9CBF57` / `#A6C763` | light yellow-green |
| `TRUNK_BIRCH` | `#D5D2C4` | pale bark |
| `TRUNK_DEAD` | `#9A9186` | snag, weathered grey |

The A/B pairs are a few percent apart in value and hue and are hashed **per
tree**, never per block — per-block variation is incompatible with greedy
meshing and would turn a flat canopy from one quad into hundreds.

### Plant colours (`FloraModels.COLORS`)

Seventeen. Two were re-authored after the gallery showed them failing, and both
failures are worth knowing about because they are properties of the renderer
rather than of taste:

| Colour | first try | shipped | Why |
| --- | --- | --- | --- |
| Grass blade base / tip | `#6E9433` / `#8AA046` | `#79A33C` / `#A8C95E` | Both were darker than the meadow block they stand on. A dark clump on bright ground reads as a shadow, not a plant. The tip is now well above the ground's value. |
| Boulder | `#8E877A` | `#B4AEA3` | A sensible mid-grey on paper, near-black on screen: a blob has almost no upward-facing surface, so nearly every face it shows the camera is lit edge-on. |
| Fern frond | `#4A7A34` | `#5E9440` | Almost black against the forest floor. |

The rest, unchanged and unverified: alpine turf `#93A552`, stem `#5C7A2E`,
mushroom stem `#C9BFA8` and cap `#D96A4A`, heath shrub `#96604A` / `#A06B4E`,
reed `#9C9552`, firefly `#FFE9A0`, and the five flower heads — white `#F2EFE2`,
yellow `#E8C64A`, purple `#9B6FC4`, red `#C9504A`, alpine `#D8E4F0`.

### Tree shapes

All seven, in `TreeSpecies.SPECIES`. Heights and crown radii are the plan's
own numbers; what was chosen by eye is where the crown starts up the trunk, and
these read differently at different distances:

| Species | Crown base | Note |
| --- | --- | --- |
| spruce, larch | 28% of height | The whorl — alternate layers one block narrower — is what separates a spruce from a traffic cone. Judge it in the close-up. |
| beech | 40% | |
| birch | 55% | Trunk drawn to full height, because a birch is recognised by its bark. |
| krummholz | ground | Leans one block at the top half. |
| hero | its parent's | Always a 2 × 2 trunk. |

### Plant models

Nineteen, in `FloraModels.voxels_for()`. Sizes are the plan's; the shapes are
not. The ones I would look at first:

- **The fern.** One-voxel fronds read as a spider. Fronds are now two voxels
  across where they are widest, and it is better, but it is the model I am
  least happy with.
- **The grass tufts.** Only five voxels tall at 6.25 cm each, so the shape can
  do very little and the base-to-tip colour gradient is doing most of the work.
- **The impostor dome** (beech, birch, hero at distance) is an octahedron, and
  from some angles it reads as a floating diamond rather than a crown. The plan
  asked for a stacked octahedron; this is one stack.

### Densities

Every one is in the F4 panel. `flora_draw_fraction` thins everything at once
without moving anything, which is the knob to reach for first.

---

## Departures from the plan, and why

**1. `TreeSpecies` arrived in Stage 1 rather than Stage 2.** The gallery needs
something to stamp through, and the alternative was a copy of the tree code
living in a tool for two stages. The file was created holding the original cone
unchanged; Stage 2 then moved the world onto it and proved the count was
identical.

**2. Four config knobs retired, and one added, in Stage 3.**
`tree_trunk_min/max` and `tree_canopy_min/max` described ONE tree because there
was one. Seven species cannot share four numbers — a krummholz is 3 blocks and
a hero is 42 — so per-species sizes moved into the table where they can be read
next to each other, and `tree_size_scale` replaces them as the thing that
genuinely applies to all of them at once. `apply_world_scale()` sets it from
the same 26–42 m derivation it used before, so world_scale still works.

**3. `tree_probability` retired for `tree_density_scale` in Stage 4.** "The
chance in the middle of the forest band" stopped being a single number the
moment there were five bands with different rules.
`TerrainGenerator.tree_probability_at()` went with it.

**4. Krummholz fades across alpine AND heath together.** The plan says "0.05
fading to 0 halfway up the alpine band", and in this world alpine is the zone
immediately above forest with heath above it — so taken literally, krummholz
would give out before reaching the heath the same sentence puts it in. Read as
the two bands together: full strength where the forest ends, gone by the
midpoint of the pair, which is early heath.

**5. The meadow beech/birch split is 3:1, and the plan does not say.** It says
only "beech/birch/hero". Birch's own row calls it a tree of the shore and of
meadow *margins*, and a margin species that is half the meadow is not a margin.

**6. The impostor ring has an LOD, and the plan says it should not.** The plan
says the ring "iterates the same tree candidates with the same hash". Beyond
1.6× the voxel radius it now iterates every second cell on each axis and draws
each impostor twice as wide. This is the departure I am least comfortable with
and the measurement that forced it is:

> The full ring at High is 63,000 candidate cells — about 500 ms of worker
> time. This engine build **serialises GDScript across threads** (the
> measurements are in the note on `World._max_jobs_in_flight`), so 500 ms of
> ring is 500 ms of chunk generation not happening. At sprint the ring rebuilds
> every 1.2 s, so it would have taken forty per cent of every worker in the
> machine, permanently, to draw trees you cannot reach.

The near band — which covers the handover, where "the tree you walk up to is
the tree you saw" actually has to hold — is exact. Skipping is by the cell's
own parity rather than a counter, so the far forest does not reshuffle when the
ring is rebuilt around a walking player.

**7. Boulders are 1.0 / 1.8 / 3.0 m but nothing like 24 / 48 / 96 voxels.** The
plan's sizes and its voxel counts are not consistent with 8 voxels per block: a
3 m boulder is 48 voxels across and cannot be made of 96 of them. The sizes are
what you see, so the sizes were kept.

**8. Edited ground carries no plants.** The plan asks that a block edit dirty
the column so grass never floats over a hole. Recomputing the true surface from
the edits is the thorough answer; this is the cheap one, and disturbed ground
having no grass on it is also what a player expects when they drop a slab on a
meadow.

**9. Boulders and shrubs are not built at 8 voxels per block.** The plan says
plant models are built at the character voxel scale, 8 to the block. At that
resolution a 3 m boulder is 48 voxels across and its shell is **35,964
triangles** — one rock costing more than two hundred grass tufts, and a scree
field costing more than the entire flora budget by itself. A 90 cm heath shrub
was 2,184, and heath carries one on about every eighth block.

The fix is not smaller models — the sizes are what you see. It is that **the
world's own blocks are 50 cm**: a boulder made of 25 cm voxels is still twice
as detailed as the ground it fell onto, and a shrub at 12.5 cm four times.
There was never a reason for a rock to be eight times finer than the mountain
it came off. Boulders now build at 2 voxels per block and shrubs at 4;
everything a player crouches next to stays at 8.

Large boulder: 35,964 → **1,156** triangles. Shrub: 2,184 → **480**.

**10. `11-forest-dusk` is shot at 0.74, not the 0.85 the plan names.** In this
game's light curve `sun_energy` bottoms out the instant the sun crosses the
horizon — `day_amount()` is `clamp(elevation * 3)`, so it is already zero at
elevation zero — and 0.85 is a long way past that. Shot at 0.85 the forest
interior is a black rectangle with one glowing mushroom in it, which proves the
mushroom works and proves nothing about the forest. 0.74 is the last moment
there is enough light to see a forest by. Night proper is `12-meadow-night`.

**11. Stages 8 and 9 are one commit.** Both touch `flora_placement.gd`.

---

## Things the gallery caught

Stage 1 built the model gallery before anything else changed, and the plan was
explicit that models are tuned against it rather than against the world. That
turned out to be worth more than it sounds:

1. **Boulders rendered near-black** at a colour that is a perfectly sensible
   mid-grey. Blobs are lit edge-on.
2. **Ferns read as spiders** with one-voxel fronds.
3. **Grass tufts read as dirt** at a colour darker than the ground.
4. **A 3 m boulder hid two other models entirely** at a fixed spacing, which is
   why the strip now measures every mesh, sorts by size, and spaces each row by
   the widest thing in it.
5. **The forest-interior tour vantage stood inside a canopy.** It stood at the
   centre of the densest candidate cell, which is very nearly the definition of
   where a trunk is, so the acceptance shot for the whole plan came back as a
   green rectangle. It now searches the dense window for the block furthest
   from any trunk.

Every one of those would have shipped if models had been judged from the world.

---

## The bug that took longest, and what it teaches

**Every triangle in `FloraModels` was wound backwards** — all six face
directions — from Stage 5 until the end of Stage 10.

It did not present as a winding bug. The models were not inside out and nothing
disappeared. Because the blobs are solid and most of their faces are culled as
interior anyway, the only symptom was **thin horizontal gaps through rounded
models**: a boulder read as sedimentary layers, which looks almost deliberate,
and a shrub looked like a bush with slices missing.

It survived three wrong explanations, in this order:

1. The raggedness setting chews too much at low resolution → reduced it, no
   change.
2. The coarser voxel scale is too coarse → only raggedded blobs above radius 6,
   no change.
3. Self-shadow acne on a rounded voxel blob → turned shadow casting off in the
   gallery to match how the world draws flora, no change.

Each was plausible, each was testable in one gallery run, and each was wrong.
What found it was checking the six faces against the identity the terrain's own
winding self-test uses:

```
(p1 - p0) x (p2 - p0) == -normal
```

`ChunkMesher` has had that test since v1 and its comment says exactly why:
getting winding wrong "does not make a face vanish, which you would notice."
`FloraModels` shipped without one. **It has one now** — `flora winding`, 4,256
triangles across 19 models — and the lesson is the one already written in the
mesher: check winding with the cross product, not with your eyes.

The three wrong theories are also why the raggedness rule now scales with
radius and why the gallery no longer casts shadows from plants. Both of those
changes are improvements on their own terms; neither was the bug.

---

## Performance, and where it went

Three optimisations were forced by measurement during the run. All three are
exact — the self-tests report byte-identical output before and after.

**1. The placement product, 68.4 s → 27.5 s** over a whole world, same 73,675
trees. Written in the order the plan states the formula in, `decide()` was four
times slower than the single-term rule it replaced, and it runs three million
times per world on the chunk-generation path. Two rearrangements:

- **Roll against the ceiling first.** Accept requires `hash < p`, and `p` can
  never exceed the largest base probability anywhere, so a candidate above that
  bound is rejected on two integer hashes — no heightmap lookup, no noise, no
  zone resolution. Over half go this way.
- **Defer the binary terms.** Glade, slope and bench are only ever 0 or 1, and
  a 0-or-1 term tested *after* the roll accepts exactly what the same term
  multiplied *into* the roll accepts. The bench test's two noise samples are
  now paid only by candidates that already won.

**2. A flora column, 34 ms → a fraction of it.** Two rules need to know about
trunks — grass does not grow through one, mushrooms crowd them — and both were
calling `TreePlacement.decide()` per BLOCK over the cells that could reach it.
That is several hundred full placement decisions per column to answer a
question about a dozen trees. Thirty-six cells cover a column and its margin,
so they are decided once and the result scanned.

**3. The impostor ring's LOD**, described under Departures.

---

## What was NOT done

- **No RPC for gathering.** Stage 9 builds the identity and the removal path
  and stops, exactly as the plan requires. The comment at
  `World.remove_flora_local()` writes out the RPC it is waiting for.
- **Water and rivers.** Deliberately not in this plan. Reeds at the water's
  edge are the one thing here that touches it, and they use
  `Lakes.shore_level_at_cell()`, which terrain v2 built for them.
- **Forward+ was NOT checked.** Nothing in this run has been seen on the
  renderer you play on. Both shaders compile on Compatibility — the tour is the
  proof, because a shader that fails to compile turns every plant magenta.

---

## One thing about this box, for the next unattended run

**The screenshot tour used not to exit.** A completed run was found still
burning three and a half cores seven hours after it wrote its last image -
every photograph it had been asked for was on disk, it had simply not returned,
and the next thing to want the machine got a third of it. Over one night that
compounded: three finished-but-live processes were holding most of the CPU
while the work that needed it crawled.

**It is fixed.** `ScreenshotTour._shutdown()` now drains the world's worker jobs
explicitly, while the tree is still alive and a frame can still be processed,
before ending the main loop. Relying on `World._exit_tree()` to do it meant
relying on the order the engine tears a scene down in while a real renderer is
also shutting down. Runs after the fix print "done" and exit 0.

Two other things that made the night slower than it needed to be, both now
addressed:

- **Every headless session hosts**, so two of them collide on one ENet port and
  the loser sits silently on the main menu generating nothing. `--port N` fixes
  it and Stage 10's two-peer check needed it anyway.
- **A tour is twelve full world loads**, so re-taking one photograph cost the
  other eleven. `--only NAME` shoots just the vantages whose name contains
  NAME, which is how `11-forest-dusk` got re-taken after its time of day was
  corrected without spending an hour on the eleven shots that were already
  right.

---

## The exact next step

**Cache tree placement per chunk COLUMN.** It is the one change that would move
the boot budget materially, and it is well defined.

`TreePlacement.stamp_chunk()` scans about eighty-one candidate cells per chunk,
and a column is five or six chunks tall — so **the same eighty-one candidates
are decided five or six times over for every column in the world**, each
decision costing several noise samples and a heightmap lookup. Deciding them
once per column and handing the result to each chunk in it should take a large
bite out of the 15.45 ms per chunk that generation now costs, and generation is
where the +76% boot went.

Why it was not done in this run: it needs a cache shared across worker threads,
and getting that wrong is a determinism bug rather than a crash — the failure
mode is two players with slightly different forests and no error on either
side. That is not a thing to write at four in the morning at the end of an
unattended run. The safe shape is a `Mutex`-guarded dictionary on the
generator keyed by column, with eviction by distance from the player, and the
`chunk determinism` self-test is what proves it.

`FloraPlacement` already does exactly this trick one scale down — see
`_trees_near()`, which took a flora column from 34 ms to a fraction of it by
deciding thirty-six cells once instead of several hundred times. The same
argument applies to chunks in a column; only the threading is harder.

If that is not enough, the second-largest term is the **hero's sky reserve**:
capping the hero at, say, 30 blocks instead of 42 would take roughly a fifth of
the chunks out of every column in the world for a tree that occurs once per
300 × 300 m. That is a departure from the plan's 1.6–2.0× and should be a
deliberate decision rather than a performance accident, which is why it was not
taken here.

---

## Three new TODO(marcel) exercises

Same shape as the existing ones: a working fallback, a hint, and no dependency
on being done.

1. **`TreePlacement._glade()` — glades are in the wrong places.** Noise picks
   districts well and glades badly, because a glade is where the light reaches
   the floor and the terrain already knows where that is. Deliberately the same
   exercise as `_bench_placement()` in `TerrainGenerator` — it is the same
   mistake made twice, and the second is easier to see now the first is written
   down. The interesting part is that slope is already spoken for by
   `_slope_ok`, so you have to decide which term owns steepness before you
   write the other.

2. **`TreePlacement._blend_curve()` — the species blend is a straight line.**
   Beech gives way to spruce, and spruce to larch, at a perfectly even rate all
   the way up the forest band. Real forests are one thing for most of their
   height and change their mind quickly near the top. `pow(t, 1.6)` is the
   hint. Watch the probe's per-species counts rather than the picture: this
   moves trees between species without changing the total.

3. **`FloraModels.FIREFLY_SHADER` — the blink is too regular.** One sine,
   squared: every firefly flashes at the same rate and only the phase differs,
   so a meadow of them reads as fairy lights. Multiply two sines whose periods
   do not divide into each other and it becomes flash-wait-flash. The reason to
   do it in the shader rather than per instance is that there is nowhere to put
   a per-instance number without costing four floats on every plant in the
   world.

---

## What the water and rivers plan will need from this work

- **`FloraPlacement.column()` is the hook for anything that grows near water.**
  It already asks `Lakes.shore_level_at_cell()` twice — once to keep plants out
  of lakes, once to put reeds at the waterline. A river is a shore level along
  a line instead of around a basin, and if it can answer that same question,
  reeds follow it for free.
- **The decoration layer will carry water plants without changing.** Lilies and
  bank rushes are two more entries in `FloraModels` and two more lines in the
  zone table.
- **`TreePlacement.decide()` is the one place tree placement is decided**, and
  it already multiplies independent terms. A river wanting a band of willows is
  one more `base` case, and a river wanting *no* trees in its channel is one
  more binary gate — which by the note in `decide()` costs almost nothing,
  because binary gates are tested after the roll.
- **The far ring will draw them automatically.** It walks the same candidates.
- **VEGETATION IS CURRENTLY SYMMETRIC AT EVERY WORLD EDGE, and `CLAUDE.md`
  now says the edges are not.** The snag and krummholz weights ride on
  `TerrainGenerator.wildness_at()`, which is a Chebyshev distance from the
  CENTRE of the map - so all four edges get the same wilder, deader forest.
  That was correct when every edge was impassable peaks. The Second Age's
  coast edge would get it too, and a coast should not be the wildest place in
  the world; if anything it is the opposite. Nothing here hardcodes "edge =
  mountains", but nothing here knows the difference either, and whichever plan
  makes an edge into a coast will want to look at
  `TreePlacement._forest_species()` and at `wildness_snag` /
  `wildness_krummholz` while it is in there.
- **Watch the sky reserve.** `WorldgenConfig.REF_MAX_TREE_BLOCKS` and
  `TreeSpecies.max_height()` have to agree, and the `sky reserve` self-test is
  what keeps them agreeing. If a water plan adds a tall species, that test is
  the one that will tell you.

---

## Where this run met the design

- **THE WORLD IS THE CONTENT.** Wildness now shows in vegetation: the far edge
  of the world has more dead trees in its forests and gives way to krummholz
  sooner. Distance reads as difficulty without a number on screen.
- **TENSE OUT, COZY IN THE LIGHT.** Glowing mushrooms and fireflies are the
  first thing in this game that only exists after dark, and they are warm and
  small and in the open. The register is right even though nothing is dangerous
  yet.
- **BETTER TOGETHER** is untouched by this plan, which is correct — nothing
  here is an encounter.

Nothing in this run required a pillar to be bent.
