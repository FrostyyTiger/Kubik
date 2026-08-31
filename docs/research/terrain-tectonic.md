# Tectonic vs our worldgen

Research, 2026-08-31. Commissioned to answer: how does the Minecraft mod
**Tectonic** make its mountains read as mountains, what does it do that we do
not, and which of it survives contact with an unbounded, heightmap-driven,
1:4-scale voxel world.

**Observations only. No implementation plan** - that is a separate step.

Every Tectonic claim carries a URL. Every claim about our code carries a file
path. Anything derived by my own arithmetic rather than stated by a source is
marked **(derived)**; anything I could not confirm is marked **(unconfirmed)**.

---

## 0. The name, and the mods it gets confused with

Marcel said "Tectonics". The mod is **Tectonic**, singular, by
**Apollounknowndev** - <https://modrinth.com/mod/tectonic>, source at
<https://github.com/Apollounknowndev/tectonic> (default branch
`rewrite-squared`, 155 stars, last push 2026-06-22, MIT per the Modrinth page;
the GitHub API reports no license file). 15.9 M downloads, 7.2 K followers on
Modrinth. It ships as **both a datapack and a Fabric/NeoForge mod** from the
same source tree - the datapack bakes constants into JSON, the mod reads them
from a config screen.

Three neighbours it gets confused with:

- **Terralith** - a different project, by Starmute. It is a *biome* pack.
  Tectonic is a *terrain shaping* pack. They overlap and fight.
- **Terratonic** - Apollo's own Tectonic-with-Terralith build. "Terratonic is a
  modified version of Tectonic that builds in Terralith support. It alters
  terrain shaping to better accommodate for Terralith's biome layout and adds
  some of its terrain features like megacaves, glacial spikes and badlands
  arches." Using Tectonic and Terralith together *without* Terratonic means
  "world generation will be broken."
  <https://github.com/Apollounknowndev/tectonic/wiki/Terratonic-FAQ>
- **CliffTree** - another compatibility overlay in the same repo
  (`overlay.clifftree/`).

That split - shaping vs biomes - is the first thing worth carrying over, and
section 1.1 says why.

---

## 1. Tectonic's mechanism

### 1.1 The pipeline it plugs into

Minecraft 1.18+ separates two questions that older versions fused:

- **Terrain shaping** - where the rock is. A 3D **density function** graph
  evaluated per position; positive is solid, negative is air.
- **Biome placement** - what the rock is made of and what grows on it. Six
  climate parameters (temperature, humidity/vegetation, continentalness,
  erosion, weirdness/ridges, depth) index a multi-noise table.
  <https://minecraft.wiki/w/World_generation>

The shaping graph funnels into one number per column called `offset`, produced
by a **spline** - a piecewise curve with hand-placed control points - whose
input coordinate is another spline, nested several deep. The wiki's summary of
the pieces: "The larger the continentalness, the higher the average terrain
height. The higher the erosion at a location, the lower the terrain height and
the flatter the terrain... Jaggedness uses a spline function to obtain the
distribution of mountain ranges based on continentalness, erosion, PV (peaks
and valleys) value, and weirdness value."
<https://minecraft.wiki/w/Tutorial:Custom_world_generation>

Tectonic **replaces the whole shaping half and re-derives the climate
parameters from its own shaping**, leaving vanilla biome tables in place.
Concretely: `.../minecraft/worldgen/density_function/overworld/noise_router/continents.json`
is just `add(tectonic:noise/full_continents, 0)`, and `erosion.json` /
`ridges.json` point at `tectonic:biome_parameter/erosion` and
`tectonic:biome_parameter/ridges` - each of which is *itself* a large authored
spline over Tectonic's own terrain fields. So biomes are told about the terrain
Tectonic actually built, rather than about the noise vanilla would have built
from. That is the structural trick, and it is why Terralith needs a special
build: two packs both want to own that hand-off.

Scale of the thing: **245 JSON files, 164 of them density functions and 38 noise
definitions** (counted from the repo tree). This is a data project, not a code
project - the Java is a config UI, a few mixins, and four custom density
function types (`ConfigConstant`, `ConfigNoise`, `ConfigClamp`, `Invert`).

### 1.2 The four numbers that make it big

The single largest effect is not clever - it is a change of horizontal scale on
three noise fields, applied twice (base octave *and* sample scale).

| Field | Vanilla | Tectonic | Effective lattice, vanilla → Tectonic **(derived)** |
| --- | --- | --- | --- |
| continentalness | base octave **-9**, 9 amplitudes `[1,1,2,2,2,1,1,1,1]`, sampled at `xz_scale 0.25` | base octave **-10**, amplitudes `[1.75,1,2,3,2,2,1,1,1]`, sampled at `xz_scale 0.13` | 2048 → **7877 blocks (3.85x)** |
| erosion | base octave **-9**, 5 amplitudes `[1,1,0,1,1]`, `xz_scale 0.25` | base octave **-10**, **9** amplitudes `[2,1.75,1.5,1.5,1.3,1,1,1,1]`, `xz_scale 0.25` | 2048 → **4096 blocks (2x)** |
| ridge (weirdness) | base octave **-7**, 6 amplitudes `[1,2,1,0,0,0]`, `xz_scale 0.25` | base octave **-8**, 3 amplitudes `[1,2,1]`, `xz_scale 0.25` | 512 → **1024 blocks (2x)** |

Vanilla values from <https://github.com/misode/mcmeta> (`data-json` branch,
`data/minecraft/worldgen/noise/{continentalness,erosion,ridge}.json`). Tectonic
values from `src/common/main/resources/resourcepacks/tectonic/data/tectonic/worldgen/noise/parameter/*.json`
and `.../overlay.datapack/.../__constants/noise/*.json`. Defaults confirmed in
`ConfigState.java`: `CONTINENTS_SCALE = 0.13`, `EROSION_SCALE = 0.25`,
`RIDGE_SCALE = 0.25`.

Two things follow. First, "continent-like landmasses spanning thousands to tens
of thousands of blocks wide" (<https://modrinth.com/mod/tectonic>) is exactly
what a ~7900-block lattice on nine octaves produces. Second, the erosion field
grew from 5 octaves to 9 with the amplitude ramp weighted hard toward the
*largest* scales - erosion regions are now big, smooth and dominant, which is
what turns "sometimes flat, sometimes hilly" into "this whole district is a
plain and that whole district is a range".

The amplitude edit on continentalness matters too: `1.75` on the lowest octave
and `3` on the fourth against vanilla's `1` and `2` pushes contrast into the
macro scales, so the ocean/land decision is made by a few very large waves
rather than by a mush of nine equal ones.

### 1.3 Height: the same gradient, a wider domain

`.../tectonic/worldgen/density_function/depth.json`:

```json
{"type":"minecraft:y_clamped_gradient",
 "from_y":-2048,"to_y":2048,"from_value":17,"to_value":-15}
```

Vanilla's is `from_y -64, to_y 320, from_value 1.5, to_value -1.5`. **Both have
a slope of exactly 0.0078125 per block, and both cross zero at y=128**
(derived). Tectonic has not made the world steeper per block - it has extended
the ramp far past the world so that a large `offset` no longer saturates
against the end of the gradient. The clamp was the ceiling; removing the clamp
is the whole "mountains reach the build limit" feature.

On top of that:

- `__constants/vertical_scale.json` = **1.125** in the datapack. In the mod it
  is `elevation_boost * square(offset/continents) + vertical_scale` - **the
  vertical stretch is itself proportional to the square of the terrain
  offset**, so high ground is stretched more than low ground. Default
  `ELEVATION_BOOST = 0`, so the mod ships this off; presets turn it on.
- `terrain_spline/offset/final.json` applies `vertical_scale` through a
  `range_choice` gated on `offset/continents ∈ [0, 64)` - i.e. **only above sea
  level**, matching the wiki's "Vertically stretches terrain above sea level.
  Doubling this value will double the surface's height."
  <https://github.com/Apollounknowndev/tectonic/wiki/Config>
- Offset is clamped to `min_offset = -0.6`, `max_offset = 1.95`, and a constant
  `-0.50375` is subtracted before use.
- Height limits: default `(-64, 320)` = vanilla; "Increased Height" is
  `(-64, 640)` (`HeightLimits.INCREASED_HEIGHT`). Sea level stays **63**,
  noise cell size `size_horizontal 1, size_vertical 2` - the same as vanilla.
- Preset ladder (`ConfigPresets.java`): default `verticalScale 1.125`,
  `elevationBoost 0`; **Frozen Wasteland** `1.2 / 0.5`, height to y448;
  **Overkill** `2.5 / 1.6`, height to **y768**, `continentsScale 0.1`,
  `erosionScale 0.08`, `ridgeScale 0.2`.

Modrinth's own numbers: mountain ranges "can stretch for tens of thousands of
blocks, going high enough to approach the build limit"; jungle pillars "upwards
of a hundred blocks tall"; islands "around a thousand blocks across". A search
summary reports peaks "frequently above y=200" and "sometimes above y300"
(<https://www.curseforge.com/minecraft/mc-mods/tectonic>) - **(unconfirmed)**,
I could not find those figures in the repo.

### 1.4 What makes the mountains read: the ridge field

This is the part that is genuinely not vanilla, and it is small - four files.

`tectonic/worldgen/noise/mountain_ridges/`:

```
base.json       firstOctave -8, amplitudes [1, 0.2]     -> ~151 blocks (derived, at xz_scale 1.7)
detailed.json   firstOctave -7, amplitudes [0.2, 1]     -> ~64 blocks  (derived, at xz_scale 2)
weathering.json firstOctave -4, amplitudes [1, 0]       -> ~6.4 blocks (derived, at xz_scale 2.5)
```

The mechanism, from
`tectonic/worldgen/density_function/mountain_ridges/noiseshift/*.json`:

1. Sample `base` at the point (`noiseshift/base`).
2. Sample `base` again 10 blocks along x (`noiseshift/shiftx`), and again along
   z.
3. `slopex = base - shiftx` - **a finite-difference gradient of the ridge
   field** (`noiseshift/slopex.json`).
4. `shifteddetail.json` samples `detailed` with
   `shift_x = abs(slopex) * 3000` and `shift_z = abs(slopez) * 3000`.
5. `ridges.json` = `base + 0.6 * shifteddetail`, wrapped in
   `flat_cache(cache_2d(...))` - **it is a 2D field, computed once per column**.

Step 4 is the interesting one. Where the ridge field is flat - along a crest
line, and along the valley floor - the gradient is near zero, the domain shift
is near zero, and the detail noise is sampled *coherently*, so it stretches
smoothly along the feature. On a flank, where the gradient is large, the shift
is up to **3000 blocks**, which decorrelates the detail completely. The result
is detail that runs *with* the ridgelines and breaks up *across* them - the
visual signature of an eroded range - for the cost of two extra noise samples
per column. It is a gradient-aware domain warp, and it is doing the job that a
proper hydraulic erosion pass would do, without any iteration.

`mountain_ridges/weathering.json` is the second half:

```
1 - clamp( spline( abs(weathering_noise) ),  { 0.025 -> 0 (derivative 20), 1 -> 1 }, 0, 1 )
```

A derivative of **20** at location 0.025 makes the spline snap from 0 to ~1
over roughly a 0.05-wide window (derived). So `weathering` is ~1 only in a
narrow band around the zero-contour of a short-wavelength noise field, and ~0
everywhere else - **thin curvilinear lines cut across the mountains**:
couloirs, gullies, weathered seams. It enters the terrain in
`sloped_cheese.json` as `-0.1 * weathering`, i.e. it *subtracts* height along
those lines.

Both feed the **jaggedness** term. `sloped_cheese.json`:

```
4 * quarter_negative(
      (depth + offset/depth_additive
       + jaggedness/islands * half_negative(noise jagged @ xz_scale 1500)
       + jaggedness/continents * (-0.1*weathering + (-1 * mountain_ridges/ridges) + 0.6))
      * factor )
  + ...
```

So the ridge field only speaks where `jaggedness/continents` is non-zero - and
`terrain_spline/jaggedness/continents.json` is a two-level spline that is zero
below `raw_continents 0.175` and, above it, `0.2` at `erosion_folded 0` falling
to `0` at `0.125`. **Jaggedness exists only inland and only where erosion is
low.** That is the same idea as our `mountain_mask_lo/hi` gate, expressed as a
spline instead of a smoothstep, and keyed on *two* fields instead of one.

### 1.5 The macro-structure: "regions"

`tectonic/worldgen/noise/region/selector.json` is `firstOctave -11,
amplitudes [1, 2.1, 1.5, 1.7, 1.4, 2, 2]`, sampled at `xz_scale 1.1` →
**~1862 blocks per lattice cell (derived)**. `noise/region_selector.json` adds
`flat_terrain_skew` (default **0.1**) to it. That one field then selects
between four hand-authored terrain characters, named after card suits:

| Region | File | What it is |
| --- | --- | --- |
| **club** | `region/club.json` | plateaux and valleys - sub-splines `plateau_spline`, `single_valley_spline`, `double_valley_spline`, `badlands_ridge` |
| **heart** | `region/heart.json` | rolling hills (`abs(noise @ xz_scale 0.2)`), jungle pillars |
| **spade** | `region/spade.json` | multi-tiered terrain - `lower_tier`, `upper_tier`, stepping at ridge values 0.4 → 0.55 → 0.6 → 0.64 |
| **diamond** | `region/diamond.json` | dunes (own offset_x/offset_z warp fields) and wetlands |

`terrain_spline/offset/regions.json` picks a region by `erosion` first, then by
`region_selector`, then multiplies the whole thing by
`clamp(1.2 + 0.4 * noise(region/height_multiplier @ 0.25), 0.8, 1.6)` - a
separate ~1024-block field **(derived)** that scales a region's relief by
±33%. And each region's internal choice is further keyed on
`temperature_index` and `vegetation_index`, which are splines that **quantise
the climate noises into integer bands** (`temperature_index.json` maps
temperature to 1..5 with hard steps at -0.48/-0.42, -0.18/-0.12, 0.17/0.23,
0.52/0.58).

That is the answer to "how does it get coherent large-scale structure out of
unbounded noise": **a low-frequency selector noise indexes a small table of
hand-authored terrain characters, and a second low-frequency noise scales
their amplitude.** Nothing is remembered, nothing is global, every query is
still a pure function of (x, z) - but the *character* of the land changes on a
2 km scale rather than being one texture everywhere.

### 1.6 The rest, briefly

- **Oceans.** `terrain_spline/ocean.json` is its own noise stack -
  `y_clamped_gradient(0→64, 2→0.5)` times two ocean noises, with an `abs()`
  ridge term for trenches. Depth constants `OCEAN_DEPTH = -0.22`,
  `DEEP_OCEAN_DEPTH = -0.45`, `OCEAN_OFFSET = -0.8` (the last skews the whole
  continent field toward land). Modrinth: oceans "extend into the deepslate
  layer with more varied terrain, featuring overhangs and valleys."
- **Coastlines** come out of `noise/raw_continents.json`, which is
  `ocean_offset + spline(abs(continents_noise), {0→0, 0.4→0.575, 0.48→0.68})`.
  Folding continentalness through `abs()` is what makes coasts *repeat*
  rather than being one blob.
- **Rivers** are the vanilla mechanism - the `ridges` field folded through
  `abs()` (`noise/continent/ridges_folded.json`), with the notch near zero
  carved by every offset spline (`{0.03 → -0.06, 0.1 → 0.01}` appears
  everywhere). Doubling the ridge scale doubles river spacing.
- **Underground rivers** are new: `underground_river/total.json` multiplies
  four splines (`continents * erosion * elevation * ridge`) into the final
  density, so a river that would hit a mountain **carves through it** instead
  of stopping. Same machinery makes `lava_tunnel/total.json`.
- **Caves** are vanilla cheese/noodle/spaghetti with configurable additives
  (`CHEESE_ADDITIVE 0.27`, `NOODLE_ADDITIVE -0.075`) and a depth cutoff
  (`DEPTH_CUTOFF_START 0.1`, `SIZE 0.1`) so caves stop before the surface of a
  very tall mountain.
- **Snow line.** `BiomeMixin.java` mixes into `Biome.getHeightAdjustedTemperature`
  and passes `pos.below(snowStartOffset)` - default
  **`SNOW_START_OFFSET = 128`**. The whole altitude-temperature curve is
  shifted **128 blocks up**, so the taller mountains do not turn the entire
  world into tundra. Elevation-dependent snow is vanilla; Tectonic only
  re-datums it.
- **Ultrasmooth** (`overlay.ultrasmooth/`) replaces `quarter_negative(...)` in
  `sloped_cheese` with a plain `mul` - dropping the negative-density
  compression is what "smooths" the terrain, at the cost of deep-ocean and
  windswept artefacts (per the config wiki).
- **Slope clamps.** `slope_lower` = `y_clamped_gradient(-64→-48, 0→1)`,
  `slope_upper` = `y_clamped_gradient(290→310, 1→0)` - the world is forced
  solid at the bottom and air at the top over a 16/20-block fade.

### 1.7 Authored vs emergent

Emergent: the noise fields themselves (7 named parameter noises plus the
vanilla set), the ridge domain warp, the weathering contours, the region
selector's placement.

Authored: **everything that turns a noise value into a height.** One file,
`terrain_spline/offset/continents.json`, is a tree of **27 nested splines with
56 leaf control points** (counted). `factor/continents.json` adds another ~20.
The four region files add several hundred more. Across 164 density-function
files this is, at a guess, on the order of a thousand hand-placed numbers.

The honest summary: **the noise is a coordinate system, and the terrain is a
lookup table indexed by it.** Tectonic's mountains do not look plausible
because its noise is better; they look plausible because a person spent a long
time deciding what height each (continentalness, erosion, ridges) triple should
map to, and then re-derived the biome parameters from that same mapping so the
snow line and the treeline agree with the shape.

### 1.8 Performance

No first-party figure found. Secondary sources say the cost is entirely in
chunk generation, not in ticking - "Tectonic only changes how chunks are
generated and adds no new entities, items, or tick-loop logic", with the advice
to pre-generate with Chunky
(<https://blog.curseforge.com/tectonic-minecraft-mod-faqs/>). **(unconfirmed -
these read as AI-written aggregator pages; treat as plausible, not measured.)**
What *is* verifiable from the data: nearly every 2D field is wrapped in
`flat_cache(cache_2d(...))` and the 3D ones in `cache_once` / `interpolated`,
so the graph is evaluated per column, not per voxel, wherever it can be.

---

## 2. Our worldgen today

### 2.1 The pipeline

`scripts/world/terrain_generator.gd` builds one **global coarse heightmap**
for the whole world at startup: `build_heightmap()` fills
`Heightmap.cells`, a 1500x1500 `PackedFloat32Array` at 4 blocks (2 m) per
cell, by calling `height_at_block(bx, bz)` once per cell
(`scripts/world/heightmap.gd`, `scripts/world/terrain_generator.gd:230`).

`height_at_block()` is the whole shape of the world, in order
(`terrain_generator.gd:357`):

1. `_domain_warp()` - two independent FastNoiseLite fields at
   `mountain_freq * 0.5`, each `* warp_strength` (40 blocks), added to the
   sample coordinate. Everything downstream is sampled at the bent
   coordinate.
2. `base_altitude` (183.5 blocks).
3. `+ continent * continent_amp` - fBm, 3 octaves.
4. `massif = smoothstep(mountain_mask_lo, mountain_mask_hi, continent)` - the
   mountain gate, `-0.12 .. 0.47`.
5. `+ _ridge(mountain) * mountain_amp * massif * (1 + wildness_relief * wildness_at())`
   where `_ridge(n) = (1 - abs(n))^2` and `wildness_at()` is Chebyshev
   distance from the centre of the map, 0..1.
6. `+ hills * hills_amp * _hills_gate()` - a second smoothstep gate on its own
   mask noise.
7. `_flatten_valleys()` - `t^valley_curve` on the normalised height, curve 1.6.
8. `_terrace()` - `(floor(t) + smoothstep(0,1,frac^sharpness)) * terrace_height`.
9. `_benches_and_plateaus()` - the same terrace transform again with a bigger
   riser, masked by noise *and* by an altitude band
   (`BENCH_ALTITUDE_BAND = (0.20, 0.60)`, `PLATEAU_ALTITUDE_BAND = (0.50, 1.00)`).
10. `clamp(min_altitude, max_altitude)`.

Then, separately:

- `_resolve_zone_thresholds()` builds a 2048-bucket histogram of
  `(altitude - jitter)` over the whole map and reads six threshold altitudes
  off it as **percentiles**, so the seven zone shares are exact by
  construction. With `slope_zone_strength > 0` it runs three correction rounds,
  measuring what the full zone function actually produced and pushing the
  targets by the error (`terrain_generator.gd:263`).
- `Lakes.compute()` runs **priority flood** over the whole coarse heightmap -
  border cells seeded at their own altitude, lowest-first bucket queue, every
  cell's level is `max(own altitude, level of the cell it was reached from)`
  (`scripts/world/lakes.gd:14-35`). Capped at `lake_max_depth`.
- `detail_at()` adds per-block roughness at voxel time only, damped by coarse
  slope and faded to zero at a shore line - explicitly *after* lakes, so a
  3-block bump can never invent or drain one
  (`terrain_generator.gd:530`).
- `Heightmap.build_pyramid()` builds a 6-level mip pyramid plus a parallel
  **max** pyramid for the far field (`heightmap.gd:105-244`).

### 2.2 The knobs, in wavelengths

From `scripts/world/worldgen_config.gd`. Frequency is 1/wavelength in blocks;
one block is 0.5 m, so metres are half the blocks.

| Layer | freq | wavelength | amplitude | in metres |
| --- | --- | --- | --- | --- |
| continent | 0.000317 | 3155 blk | 125.8 blk | 1577 m / 63 m |
| mountain (ridged, gated) | 0.00127 | 787 blk | 466.7 blk | 394 m / 233 m |
| hills (gated) | 0.002778 | 360 blk | 16 blk | 180 m / 8 m |
| detail (voxel time) | 0.08333 | 12 blk | 3 blk | 6 m / 1.5 m |
| hills mask | 0.0015 | 667 blk | - | 333 m |
| bench mask | 0.0009 | 1111 blk | riser 24 blk | 556 m |
| plateau mask | 0.0005 | 2000 blk | riser 90 blk | 1000 m |
| zone jitter | 0.000954 | 1048 blk | ±31.5 blk | 524 m |

World: `world_blocks_xz = 6000` (3 x 3 km), `world_height_blocks = 880`
(440 m), `coarse_step = 4`, mountain relief ~350 m at `world_scale = 4`.
`apply_world_scale()` derives `continent_amp`, `mountain_amp`,
`continent_freq`, `mountain_freq`, `zone_jitter_freq`, `base_altitude`,
`max_altitude` and `tree_size_scale` from one ratio, so they cannot drift
apart (`worldgen_config.gd:1401`).

Zone shares (`share_shore` … `share_snow`): 4 / 30 / 26 / 14 / 10 / 11 / 5 %.
Slope overrides: `rock_slope_deg 78`, `snow_max_slope_deg 72`, with
`wildness_rock_deg 12` subtracted at the world edge.

### 2.3 What our stack can already express

- **Layered fBm summed coarse-to-fine**, with per-layer amplitude and
  frequency, kept separate on purpose so each is tunable.
- **Ridged noise** - `(1 - abs(n))^2`, which is the same fold Tectonic gets
  from `ridges_folded`.
- **Domain warp** with two independent fields at half the mountain frequency.
- **Masking one layer on another** - `mountain_mask_lo/hi` on the continent
  layer, `hills_mask_*` on its own field. Structurally identical to Tectonic's
  `jaggedness` gate, one input instead of two.
- **Altitude-banded features** - benches and plateaux are windowed on where in
  the world's vertical range a point sits, with a 25% fade at each edge.
- **A transform with a dead zone** - terracing, which produces genuinely flat
  ground where a wavelength change cannot.
- **Elevation zones as percentiles of the world's own histogram**, so the
  zoning is decoupled from every other terrain knob - and a closed-loop
  corrector that absorbs any *other* rule that moves cells between zones.
- **Slope-aware zoning** - snow off cliffs, scree on steep faces.
- **Per-basin lakes from a global heightmap** via priority flood - which
  Tectonic does not do at all, because a Minecraft-style chunk generator
  cannot.
- **A filtered + max mip pyramid** over the heightmap for a stable far field.
- **A distance field** (`wildness_at`, `danger_at`) that already modulates
  relief and the rock threshold.

### 2.4 What it structurally cannot express yet

1. **A spline.** There is no data structure anywhere in `scripts/world/` that
   maps a noise value through hand-placed control points to a height. Every
   mapping we have is a closed-form curve: `smoothstep`, `pow`, `lerp`. That is
   the single biggest expressive gap, and it is the one Tectonic's whole design
   rests on.
2. **A second shaping axis.** We have exactly one macro field (`continent`) and
   it does two jobs: it sets base height *and* it gates the mountains. Tectonic
   has three (`continentalness`, `erosion`, `ridges`) and the interesting
   behaviour lives in their *interaction* - "high continentalness AND low
   erosion" is a range; "high continentalness AND high erosion" is a plateau.
   We cannot say that; our high ground is all one kind of high ground.
3. **Erosion as a field.** Nothing in our stack varies *how rough* a district
   is, only how tall. `hills_gate_strength` is the nearest thing and it gates
   one layer's amplitude, not the character of the whole column.
4. **Ridge-aligned detail.** Our `detail_at()` damps by slope magnitude but
   knows nothing about slope *direction*. Tectonic's gradient-shift trick is
   the thing that makes its flanks look eroded, and it needs two extra samples
   we do not take.
5. **Regions.** No selector, no table of terrain characters. Every square metre
   of our world is made by the same nine-step function with the same constants.
   The only variation with position is `wildness_at()`, which is a monotonic
   ramp from the centre - it makes the far country *more*, never *different*.
6. **Rivers.** None. `docs/ROADMAP.md` puts them in **B. Water v1**, Wave 1:
   "Rivers from the heightmap flow field into the basin lakes". `lake_max_depth`
   is capped at 2 blocks precisely because "Real terrain has very few closed
   basins because rivers carve outlets through the rims; noise terrain has
   thousands, and we do not model erosion" (`worldgen_config.gd:800-819`).
7. **Anything below the surface.** We are a heightmap; the world is
   `by <= surface_at(bx, bz)` (`terrain_generator.gd:617`). No caves, no
   overhangs, no underground rivers. This was a deliberate trade -
   "The previous version was a 3D density field, which buys overhangs and costs
   you the ability to ever find a valley" (`terrain_generator.gd:16-21`).
8. **Any extent at all beyond 3 km.** `Heightmap._init` sizes `cells` from
   `world_blocks_xz`; `height_at()` **clamps** the query to the map and returns
   the edge value outside it (`heightmap.gd:63-65`). `world_blocks_xz` is in
   `PROPERTIES` (`worldgen_config.gd:1183`), so it is part of the determinism
   hash and the join handshake. `wildness_at()` and `danger_at()` are both
   defined as fractions of the world half-width
   (`terrain_generator.gd:571, 1016`). Lakes' priority flood seeds on the
   *border of the map*. `build_heightmap()` is **10.8 s single-threaded at
   3 km**, and cannot be parallelised from GDScript.

That last one is now a live contradiction with the design.
`docs/DESIGN.md` § World, ruled 2026-08-31: the world is "**Procedurally
generated and effectively unbounded**… no new system may bake in a world edge
or a global-extent assumption," and heightmaps and lakes "go regional (tiled)
as the world opens." `CLAUDE.md` § Worldgen guidance repeats it. **No code has
changed, and there is no roadmap epic, plan or TODO item for it.**

---

## 3. Direct comparison

| Dimension | Tectonic | Ours today |
| --- | --- | --- |
| Representation | 3D density field, `positive = solid`; per-column 2D fields cached via `flat_cache` | 2D heightmap, `by <= surface`; no overhangs, no caves |
| Extent | Unbounded, pure function of (x, z) | One 6000-block square, global array, clamped at the edge |
| Macro fields | 3 independent: continentalness, erosion, ridges (+ temperature, vegetation) | 1: `continent`, doing double duty as height and as mountain gate |
| Macro scale | continentalness lattice **~7877 blk** (derived) | continent wavelength **3155 blk** - *smaller than one Tectonic continent cell, and it is our whole world* |
| Macro : feature ratio | ~7877 : ~151 = **~52 :1** (derived) | 3155 : 787 = **4 :1** |
| Noise→height mapping | Nested authored **splines** - 27 splines / 56 leaf points in one file alone | Closed-form: `smoothstep`, `pow`, `lerp`. No splines anywhere |
| Ridge formation | `abs()`-folded ridge noise + a dedicated `mountain_ridges` field, gated by `jaggedness` on (continents, erosion) | `(1 - abs(n))^2` on the mountain layer, gated by `smoothstep` on continent only |
| Detail on flanks | Detail noise domain-shifted by `abs(gradient of ridge field) * 3000` - runs along crests, breaks across flanks | Uniform fBm, damped by slope *magnitude*; direction-blind |
| Erosion / weathering | An erosion field (9 octaves, 4096-blk lattice) chooses flat vs mountainous; a weathering field cuts thin gullies | None. `valley_curve 1.6` steepens tops and flattens floors globally |
| Valley shape | Rivers = `ridges_folded` notch, carved by every offset spline; underground rivers tunnel through mountains | `_flatten_valleys()` power curve. No river network at all |
| Flat ground | Erosion regions, `flat_terrain_skew 0.1`, `region/spade` tiers, `region/club` plateaux | Terracing (dead zone), hill gating, alpine benches, plateau regions |
| Macro variety | 4 authored regions selected by a ~1862-blk noise, amplitude-scaled ±33% by a second field, sub-keyed on quantised temperature/vegetation | None. One function, one set of constants, everywhere |
| Distance/difficulty | Not a concept | `wildness_at()`, `danger_at()` - both defined against the world half-width |
| Vertical | Depth gradient stretched to ±2048 so offset never clamps; `vertical_scale` 1.125 (mod: `× offset²`), applied above sea level only | Fixed 880-block world; `world_scale 4` derives amplitudes and frequencies together |
| Height range | y-64 to y320 default, y640 optional, y768 in the Overkill preset; sea level 63 | 880 blocks = 440 m; ~350 m of mountain relief |
| Zoning / biomes | Vanilla multi-noise, but fed **Tectonic's own** re-derived climate parameters; snow line re-datumed +128 blocks | Seven zones as **percentiles of the world's altitude histogram**, jittered, dithered, slope-overridden, with a closed-loop share corrector |
| Lakes | Not possible (chunk-local generator); aquifers instead | **Priority flood over the whole map**, per-basin, depth-capped |
| Far field | Not a concern (Minecraft's own LOD) | Mip + max pyramid over the global heightmap, continuous level in distance |
| Authoring style | Data. 245 JSONs, ~1000 hand-placed numbers, a config UI | Code. ~90 exported floats in one `Resource`, hot-reloadable, hashed into the join handshake |

---

## 4. Observations for an unbounded, heightmap-driven, 1:4 world

Factual observations only.

1. **Our whole world is smaller than one of Tectonic's noise cells.** 6000
   blocks against a ~7877-block continentalness lattice (derived). At 1:4 our
   3 km map is 12 km of "real" landscape; a Tectonic continent at Minecraft's
   nominal 1 m block is 8-80 km of real landscape. We are not doing a smaller
   version of the same thing - we are inside a single feature of it.

2. **The macro:feature ratio is the number that decides whether ranges exist.**
   Tectonic's is ~52:1; ours is 4:1. At 4:1, a "massif" is three or four
   mountain wavelengths wide, which is a cluster, not a range. Anything that
   wants ranges spanning thousands of blocks has to widen that gap - either by
   stretching the continent layer or by adding a field above it - and at our
   scale a real 100 km range is 25 km in game, or 50,000 blocks, which is
   8.3 world-widths today.

3. **Everything Tectonic does is a pure function of (x, z), and every 2D field
   is `flat_cache`d.** Nothing it produces requires a global array, a border
   condition, or a startup pass. Our layered-noise core has the same property;
   what does not are: the **zone percentiles** (a histogram of the whole map),
   the **lake priority flood** (seeded on the map border), the **mip pyramid**
   (indexed against a fixed grid size), and **`wildness_at`/`danger_at`**
   (fractions of the world half-width). Those four are the actual bounded
   assumptions, not the noise.

4. **Tectonic's answer to unbounded coherence is a table, not memory.** A
   low-frequency selector noise picks one of four authored terrain characters,
   and a second low-frequency noise scales its relief ±33%. Both are stateless.
   That is compatible with regional tiles because it is compatible with *no*
   tiles - the region a column belongs to is recomputed from its coordinate
   every time. Our `wildness_at()` is the only positional variation we have and
   it is monotonic from a centre, which an unbounded world does not have.

5. **A spline table is `Facts as data, not prose in code`.** `CLAUDE.md`'s
   first habit asks for exactly the shape Tectonic uses: control points in a
   table a director could read, rather than a `smoothstep` with two magic
   numbers. Our zone shares already work this way; our height mapping does not.

6. **Percentile zoning does not survive an unbounded world unchanged.**
   `_resolve_zone_thresholds()` builds the histogram from the whole map, and
   its correctness argument - "exact by construction" - is a statement about a
   finite sample. A regional world would need either a per-region histogram
   (zone bands that shift between regions, which the blend and jitter would
   partly hide) or a fixed altitude→zone curve calibrated once (which loses the
   decoupling that Stage 7 was built to buy - `docs/plans/terrain-v2.md`,
   Stage 7).

7. **Lakes are our differentiator and Tectonic has no equivalent.** Priority
   flood needs a rim, and a rim needs a border condition. `docs/DESIGN.md`
   § World already names the problem: "a basin crossing a tile border is a real
   problem to be solved, not wished away." Tectonic sidesteps it entirely -
   Minecraft has aquifers and river channels, not basin lakes. There is nothing
   to copy here.

8. **The cheapest visual wins Tectonic has are both two-sample tricks.**
   (a) The gradient-shifted detail - `abs(base(x) - base(x+10)) * 3000` as a
   domain shift on a finer noise - costs two extra noise samples per column and
   is what makes flanks read as eroded. (b) The weathering contour - a spline
   with derivative 20 near zero on `abs(noise)` - costs one sample and cuts
   gullies. Neither needs state, extent, or iteration. Both are per-column.

9. **`depth.json` is the "how do we get taller mountains" answer and it is not
   an amplitude change.** Vanilla and Tectonic have *identical* per-block
   gradients and an identical zero crossing at y=128; Tectonic just extends the
   ramp from ±(64..320) to ±2048 so the offset never saturates. Our analogue is
   `max_altitude` (833.7 blocks) and the `clampf` at the end of
   `height_at_block()` - and unlike Tectonic's, ours is a hard clamp, not a
   ramp, so a summit that reaches it goes flat.

10. **Tectonic re-derives biome parameters from its own terrain; we already
    do the equivalent, differently.** Its `biome_parameter/erosion.json` and
    `ridges.json` are splines over its shaping fields, so biomes agree with the
    shape. Our zones are read off the *finished* heightmap by percentile plus a
    slope override, which is a stronger guarantee of agreement - it is measured
    rather than authored. That property is worth not losing when the world goes
    regional.

11. **The vertical stretch being proportional to `offset²` is a scale-coherence
    device.** `elevation_boost * square(offset/continents)` means low ground
    keeps its proportions while high ground grows. Our `apply_world_scale()`
    solves the same problem by scaling amplitude *and* frequency together off
    one ratio, which preserves characteristic slope; Tectonic's makes the world
    steeper where it is already high. The two are not interchangeable, and ours
    is the one that keeps a 1:4 read.

12. **Regions would collide with two things already in the queue.**
    `docs/ROADMAP.md` **H. Sites v1** already defines "biomes" as "named regions
    anchored on sites… the seven elevation zones plus distance, each given a
    name and one signature", and the pushback list says a biome rewrite "would
    move the terrain under everything tuned since". A Tectonic-style terrain
    region selector is a *shaping* concept, not a naming one - the two would
    have to be reconciled, and today the roadmap only contemplates the naming
    half.

13. **A per-column terrain function costs us more than it costs Minecraft.**
    `build_heightmap()` is 10.8 s single-threaded for 562,500 cells at 3 km, and
    the measurement in `terrain_generator.gd:216-225` is explicit that GDScript
    worker threads are serialised in this build - two workers took exactly as
    long as one, sixteen took 4x longer. Every extra noise sample per column
    (the gradient trick is +2, an erosion field is +1 to +3) multiplies against
    that number, and regional tiling means paying it repeatedly during play
    rather than once at load.

---

## Sources

Tectonic: [Modrinth](https://modrinth.com/mod/tectonic) ·
[GitHub](https://github.com/Apollounknowndev/tectonic) ·
[Config wiki](https://github.com/Apollounknowndev/tectonic/wiki/Config) ·
[Terratonic FAQ](https://github.com/Apollounknowndev/tectonic/wiki/Terratonic-FAQ) ·
[CurseForge](https://www.curseforge.com/minecraft/mc-mods/tectonic) ·
[CurseForge FAQ blog](https://blog.curseforge.com/tectonic-minecraft-mod-faqs/)

Minecraft worldgen: [World generation](https://minecraft.wiki/w/World_generation) ·
[Custom world generation tutorial](https://minecraft.wiki/w/Tutorial:Custom_world_generation) ·
vanilla data from [misode/mcmeta](https://github.com/misode/mcmeta)

Ours: `scripts/world/worldgen_config.gd`, `scripts/world/terrain_generator.gd`,
`scripts/world/heightmap.gd`, `scripts/world/lakes.gd`, `docs/DESIGN.md`
§ World and § Scale, `docs/plans/terrain-v2.md`, `docs/ROADMAP.md`,
`docs/IDEAS.md`, `CLAUDE.md` § Worldgen guidance.
