class_name WorldgenConfig
extends Resource

## Every tunable number that shapes the world, in one place.
##
## Two reasons this is a Resource and not a pile of constants:
##
## 1. TUNING. Terrain is found by trial and error, and recompiling your way to
##    a mountain range is miserable. These values load from user://worldgen.tres
##    at startup and re-read on a key press, so the loop is "edit, press F5,
##    look" instead of "edit, restart, walk back to where you were".
##
## 2. DETERMINISM. The README's contract is that terrain is never sent, only a
##    seed - both machines regenerate an identical world from it. That is only
##    true if both machines also agree on every number below. The config is
##    therefore part of the determinism contract ALONGSIDE the seed, and it is
##    sent in the join handshake next to it. A client generating with a
##    different treeline is the silent-desync failure the README warns about.
##
## Hence to_dict()/from_dict()/hash_key(): serialisable from the start, so
## putting it on the wire is a two-line change rather than a refactor.

## Where the hot-reloadable copy lives. Absent on a fresh install, which is
## why every value below has a default that is already the shipped spec.
const USER_PATH := "user://worldgen.tres"


# --- Scale ------------------------------------------------------------------
#
# The one number here that touches everything else is block_size. Voxel maths
# stays in integer BLOCKS everywhere; metres only appear when we hand a
# position to the renderer or the physics engine. Keeping that line sharp is
# what stops "is this 0.5 or 1.0?" bugs from spreading through the codebase.

## Metres per block. 0.5 means a 4-block player is 2 m tall.
@export var block_size := 0.5

## THE ONE SCALE KNOB. Metres of real world per metre of game world.
##
## The world is 1:4 against reality and the value of saying so once is that ONE
## ratio then has to appear on every line. The eye judges size by comparison,
## so an object at 1:10 standing next to one at 1:4 does not read as a small
## world - it reads as a broken one, and that is exactly what the probe found:
## trees and lakes both at 1:3.5 and mountains at 1:10.5, off by a factor of
## nearly three from everything they stand next to.
##
## Mountain relief, tree height and minimum lake size are all DERIVED from this
## by apply_world_scale(), so they cannot drift apart again. Set it to 0 or
## less to hand-tune them instead, the same escape hatch view_distance has.
@export var world_scale := 4.0

## What the derivation is measured against. These are the v1 values and the
## relief they actually produced, so at world_scale 4 the shape of the world is
## unchanged and only its VERTICAL SIZE moves.
const REFERENCE_RELIEF_BLOCKS := 267.0
const REF_CONTINENT_AMP := 48.0
const REF_MOUNTAIN_AMP := 178.0
const REF_CONTINENT_FREQ := 0.00083
const REF_MOUNTAIN_FREQ := 0.00333
const REF_ZONE_JITTER_FREQ := 0.0025
const REF_BASE_ALTITUDE := 70.0
const REF_MAX_ALTITUDE := 318.0
const REF_ZONE_JITTER_BLOCKS := 12.0

## The real-world sizes everything is measured against, in metres.
##
## Swiss pre-Alpine, and chosen so that at world_scale 4 the tree and lake
## numbers come out EXACTLY as they already were. That is the test of the
## derivation rather than a coincidence: trees and lakes were already coherent
## with each other, so a derivation that moved them would be the wrong
## derivation. Only the mountains were out of line, and only they change.
const REAL_MOUNTAIN_RELIEF_M := 1400.0
const REAL_TREE_HEIGHT_M := Vector2(26.0, 42.0)
const REAL_LAKE_MIN_M2 := 2560.0
const REAL_LAKE_WIDTH_M := 400.0
const REAL_PLAYER_HEIGHT_M := 1.75

## The largest tree in the species table, and the sky the world must reserve
## above the terrain for it - both in blocks, at tree_size_scale 1.
##
## RESTATED HERE RATHER THAN READ FROM TreeSpecies, deliberately. TreeSpecies
## takes a WorldgenConfig in every signature, and having this file call back
## into it makes the two mutually dependent for the sake of two integers. The
## self-test asserts the two agree instead, which is the same guarantee without
## the cycle - see "sky reserve" in selftest.gd.
const REF_TREE_MAX_BLOCKS := 21.0
const REF_MAX_TREE_BLOCKS := 42.0

## Blocks of slack above the tallest tree. FLAT, NOT SCALED, and the self-test
## is what found that out: a shape may round a layer upward by a block or two
## whatever size it is being drawn at, so the slack is a property of the
## rounding and not of the tree. Scaling it with everything else left the
## reserve one block short at tree_size_scale 0.5 - which would have shown up
## as heroes with flat tops, in some columns, on small-scale worlds only.
const TREE_RESERVE_MARGIN := 3.0

## World footprint in blocks, centred on the origin: x and z run
## -world_blocks_xz/2 .. world_blocks_xz/2 - 1.
##
## 6000 blocks is 3 x 3 km. Doubled from v1's 1.5 km in terrain v2 Stage 6,
## and deliberately not until sprint existed to cross it: the map diagonal is
## 4243 m and a world nobody wants to walk across is smaller than a world they
## do, whatever the map says.
@export var world_blocks_xz := 6000

## Vertical extent in blocks. 880 blocks = 440 m, which clears the highest
## possible summit plus the tallest possible tree standing on it. Only chunks
## the terrain actually passes through are ever built, so a taller world costs
## nothing but a higher ceiling.
@export var world_height_blocks := 880

## Blocks per coarse heightmap cell. 4 blocks = 2 m, giving a 1500x1500 grid.
@export var coarse_step := 4

## Blocks per far-field mesh vertex. 8 blocks = 4 m, giving 375x375.
@export var far_step := 8

## VIEW DISTANCE, as one setting. -1 means custom; 0-3 index VIEW_PRESETS.
##
## Two numbers decide how far you can see and they cost completely different
## things, which is why they used to drift apart:
##
##   fog_end_m costs GPU vertices and NOTHING at load. Since Stage 4 the far
##   field is built in LOD rings, so its cost is roughly logarithmic in
##   distance rather than quadratic. Fog can be generous on any machine.
##
##   voxel_radius_chunks is quadratic and it is CPU work - 1201 chunks at
##   radius 8, 2653 at 12, 4829 at 16. This is the real quality dial and the
##   thing to turn down when a machine cannot keep up.
##
## Binding them into one setting is what stops someone turning fog down to fix
## a frame rate problem that fog was not causing.
@export var view_distance := 2

## radius in chunks, fog end in metres. Ultra is 800 and not a round 1000
## because at 1:4 a 350 m mountain frames from about 750 m: the view distance
## and the scale of the terrain are matched on purpose.
## THE THREE DISTANCES MOVE TOGETHER, and world feel v1 Stage 7 is where they
## were finally written down in one place.
##
##   radius     the voxels. Quadratic and CPU: this is the real quality dial.
##   fog_end    how far you can see. GPU vertices and nothing at load, because
##              the far field is built in LOD rings.
##   far_tree   how far the forest goes. Past this a wooded ridge is bare.
##
## They have to agree or the world ends visibly: fog past the far trees is a
## bald mountain in plain view, far trees past the fog are triangles drawn for
## nobody, and a camera far plane short of the fog - which is what shipped
## until Stage 0 - is a wall with nothing behind it.
const VIEW_PRESETS := [
	{"name": "low", "radius": 6, "fog_end": 400.0, "far_tree": 200.0},
	{"name": "medium", "radius": 8, "fog_end": 500.0, "far_tree": 300.0},
	{"name": "high", "radius": 12, "fog_end": 800.0, "far_tree": 400.0},
	{"name": "ultra", "radius": 16, "fog_end": 1000.0, "far_tree": 500.0},
]

## view_distance value meaning "leave the numbers below exactly as they are".
## The escape hatch for hand-tuning: without it, editing voxel_radius_chunks in
## the .tres would be silently overwritten by the preset on the next load.
const VIEW_CUSTOM := -1

## Fog starts this far into its own range. Fog that begins at zero is haze on
## your boots; fog that begins at fog_end is a wall.
## Look v2 Stage 2: 0.6 -> 0.4. The bands need room to be bands; starting
## them at 60% of the view distance left four of them stacked in the last
## fifth of the frame, which reads as one soft edge rather than as steps.
const FOG_START_RATIO := 0.4

## Radius, in chunks, of real editable voxels around the player.
## THIS IS THE PERFORMANCE DIAL. If the frame budget cannot be met, turn this
## down rather than changing anything else.
##
## Driven by view_distance unless that is VIEW_CUSTOM.
@export var voxel_radius_chunks := 12

## The collision-only ring the HOST streams around each remote peer, in chunks
## (world feel v1 Stage 10).
##
## THIS IS THE COST OF AUTHORITY. The host simulates every peer's body, and a
## body needs ground: the host loads columns around ITS OWN player, so a friend
## 500 m away would be standing on nothing and would fall out of the world.
##
## It is small - 4 chunks is 32 m - because nothing is being LOOKED at. No mesh
## is uploaded and no flora is grown; the columns exist so a capsule has a
## trimesh under it. All it has to cover is how far a body can move between the
## moment it approaches the edge and the moment the next ring lands, and at
## sprint that is a couple of seconds.
##
## LOCAL, not a world fact: it changes what the host streams, never what the
## world contains, so a host with a different value generates the same world.
##
## TODO(marcel): 4 is a guess and the pair probe could not test it. The number
## that matters is how far a body travels between nearing the edge of its ring
## and the next ring landing, and on this box the host ran at 595 ms frames -
## where a sprinting peer outruns any ring you care to name. On a machine that
## holds 60 fps, walk a peer away from the host and watch `--pair-probe`'s
## "chunks built for its ring" against the moment it falls: if it never falls,
## try 3 and find the edge, because every chunk of this is collision the host
## builds for terrain nobody looks at.
@export var sim_radius_chunks := 4

## How many chunks of solid rock to build below the surface. The world is 320
## blocks tall but nobody can see the bottom 250 of it, so building a full
## vertical column would be ~4x the chunks for no visible difference.
@export var voxel_depth_chunks := 3

## How many chunks may be out at the worker pool at once, generating and
## meshing counted together. Per machine, like the view distance, and NOT a
## "more is faster" dial: GDScript on the pool is serialised across threads in
## this engine build, so past a handful of jobs every extra one only adds
## contention and the whole pipeline slows down.
##
## Measured on the 20-thread target machine, headless, 3043 chunks, one seed:
##
##   1 job   51.5 s      4 jobs  20.1 s     12 jobs  65.2 s
##   2 jobs  29.3 s      6 jobs  28.3 s     24 jobs  78.0 s
##
## One job starves the pool between frames; twelve - the old constant - is
## three times slower than four. Four covers a 60 fps frame at the measured
## 5-7 ms per chunk, which is all the depth the queue needs.
@export var max_jobs_in_flight := 4

## Player capsule, in blocks. 4 blocks tall = 2.0 m.
@export var player_height_blocks := 4.0
@export var player_radius_blocks := 0.8


# --- Terrain shape ----------------------------------------------------------
#
# Four noise layers, coarse to fine, summed. They are kept SEPARATE on purpose:
# one fused noise expression is shorter but you cannot tune it, because every
# knob moves every feature at once.
#
# Frequency is 1 / wavelength, in blocks. The comment on each line is the
# wavelength it works out to, because that is the number you can actually
# picture standing in the world.

## 3150 blocks / 1575 m - broad "where is high ground at all" trend.
## Amplitude is derived from world_scale; see apply_world_scale().
@export var continent_freq := 0.000317
@export var continent_amp := 125.8

## 787 blocks / 394 m - THE feature layer. Ridged, so it makes peaks and
## valleys rather than lumps. Mountain footprints land at 100-200 m across,
## which is the readability target: big enough to be a landmark, small enough
## to walk around before you get bored.
@export var mountain_freq := 0.00127
@export var mountain_amp := 466.7

## Where mountains are ALLOWED to be, as a window on the continent layer.
##
## Summing the layers everywhere gives a world that is uniformly bumpy - the
## same amount of relief in every direction, no lowlands to speak of, and
## nowhere flat enough to hold a lake. Gating the mountain layer on the
## continent layer instead gives what the design actually asks for: broad
## lowlands with meadows and water, and mountain country concentrated into
## massifs you can see from outside and walk into.
##
## Below _lo the mountain layer contributes nothing at all; above _hi it
## contributes in full; between them it fades in. Both are values of the
## continent noise, so they live in [-1, 1].
@export var mountain_mask_lo := -0.12
@export var mountain_mask_hi := 0.47

## 360 blocks / 180 m - the rolling-country layer.
##
## WAS 60 blocks / 30 m, and that was the corrugation Marcel reported. At 8 m
## of amplitude over a 30 m wavelength its characteristic slope was 46.9
## degrees - as steep as a mountain face - laid over the entire world at
## uniform strength. Standing anywhere, the ground was a staircase.
##
## The amplitude was never the problem: 8 m for a real 30 m hill is already
## 1:4. Cutting it flattens hills into nothing; stretching the wavelength draws
## them out into hills you can walk over. Swept at 30 / 90 / 120 / 180 / 240 /
## 360 m, measuring the share of map under 5 degrees:
##
##   30 m  1.30%     120 m  4.50%     240 m  5.58%
##   90 m  3.84%     180 m  5.29%     360 m  5.63%
##
## 180 m takes almost all of the gain and everything past it is decimal places,
## so that is the pick - and it lands the layer at 10.1 degrees, which is the
## plan's target of about 10.
##
## THE SWEEP ALSO SHOWS WHY WAVELENGTH ALONE IS NOT THE ANSWER. Even at 360 m
## the mean slope only falls from 45.7 to 40.3 degrees and five-sixths of the
## map is still steeper than 10 degrees. fbm noise is a sum of smooth waves, so
## every point sits on some slope and genuinely level ground has measure zero.
## Flat ground needs a transform with a dead zone in it - see terracing and
## hill gating below.
@export var hills_freq := 0.002778
@export var hills_amp := 16.0

## HILL GATING. Strength of the low-frequency mask on the hills layer, 0 to 1.
## 0 disables it entirely and is the default.
##
## The mountain layer is gated on the continent layer, and that gate is the
## reason massifs read as massifs with an outside to see them from. Nothing
## gated the hills, so hills were everywhere at uniform strength - which is
## even bumpiness, not landscape. Gating them on their own mask gives hilly
## districts and genuinely flat districts, which is half of the Cube World
## shape Marcel is asking for: flats, with hills rising out of them.
@export var hills_gate_strength := 1.0

## 667 blocks / 333 m - how big a hilly or flat district is.
@export var hills_mask_freq := 0.0015

## Window on the mask noise, in [-1, 1]. Below _lo the hills layer contributes
## nothing; above _hi it contributes in full.
@export var hills_mask_lo := -0.25
@export var hills_mask_hi := 0.35

## TERRACING. Height of one shelf, in blocks. 0 disables it and is the default.
##
## Quantise height to shelves with short risers between them, so that most of
## each shelf is genuinely flat. This is the other half of the Cube World
## shape, and unlike a wavelength it produces ground with zero gradient rather
## than merely gentler gradient.
##
## A small multiple of the block size, so shelves land on block boundaries
## rather than fighting them.
##
## NOTE, AND THE PLAN IS WRONG ABOUT THIS: it says to ship terrace_sharpness at
## 1.0 as a no-op. It is not one. At sharpness 1 the transform is
## smoothstep(frac), which is an S-curve with zero gradient at both ends - that
## is already terracing, just gentle terracing. The genuine off switch is
## terrace_height 0, which is what ships.
@export var terrace_height := 8.0

## How much of each shelf is flat. 1 is a gentle S-curve, higher values push
## the riser into a smaller and smaller fraction of the shelf.
##
## 1.5 IS A TRADE AGAINST THE LAKES, and it is worth knowing which way it goes.
## TERRACING MANUFACTURES WATER: a perfectly flat shelf with any rim at all
## floods across its whole width, however shallow the depth cap is. At
## sharpness 3 the share of map under 5 degrees reaches 27.9% and the largest
## lake goes to 1:1.8 - a lake at half real size in a quarter-scale world, and
## 7.7% of the map under water. Dropping to 1.5 costs 7.6 points of flat ground
## and brings lakes back to 1:3.0 at 2.6% of the map.
##
##   sharpness   under 5 deg   largest lake   water
##   1.5           20.30%        1 : 3.0       2.6%
##   2.0           23.10%        1 : 2.3       4.3%
##   3.0           27.88%        1 : 1.8       7.7%
##
## TUNED BLIND on the flat-ground number and on nothing else. If Marcel wants a
## wetter, flatter world this is the first knob to turn up, and lake_max_depth
## is the second.
@export var terrace_sharpness := 1.5

## ALPINE BENCHES. Strength 0 to 1; 0 disables them.
##
## Wide flat shelves partway up a slope - very Swiss, and they are where a
## campfire or a fight can happen on ground that is otherwise all gradient.
## Distinct from ordinary terracing by SIZE: a terrace riser of 8 blocks on a
## 30 degree slope gives shelves about 7 m wide, which is a step. A bench riser
## of 24 blocks gives shelves three or four times that, which is a place.
##
## Masked, so benches happen in some districts and not others. Unmasked they
## would be a staircase up every mountain in the world.
##
## TUNED BLIND, and the probe cannot help here. Benches are local by design -
## a mask and an altitude window between them confine the effect to a small
## part of the map - so the world-wide share of map under 5 degrees moves from
## 25.64% to 25.67% whether they are on or off. That is the feature working as
## intended and it is also why this value has no measurement behind it. Look at
## a hillside before trusting it.
@export var bench_strength := 0.7
@export var bench_height := 24.0
@export var bench_freq := 0.0009

## PLATEAU REGIONS. Strength 0 to 1; 0 disables them.
##
## Occasional high tableland, as a contrast to ridged country. Same mechanism
## as the benches with a much larger riser and an altitude window higher up, so
## what it produces is one flat top rather than a flight of steps.
@export var plateau_strength := 0.6
@export var plateau_height := 90.0
@export var plateau_freq := 0.0005

## SLOPE-AWARE ZONING. Strength, 0 to 1; 0 disables it and is the default.
##
## Zones key on slope as well as height, which is what makes real mountains
## read: snow does not sit on a cliff, it slides off, and a face too steep to
## hold soil is scree whatever altitude it is at. This is what Marcel meant by
## "snow covered tops and rocky tops".
@export var slope_zone_strength := 1.0

## Ground steeper than this is bare rock at any altitude, in degrees.
##
## 75 IS SET BY THE SHARE BUDGET, NOT BY PHYSICS, and the conflict is worth
## naming because the plan asks for both. Vegetation genuinely stops around
## 40-45 degrees, and at 45 this rule converts 29% of the map - rock overshoots
## its 11% target by nineteen points and snow collapses to 0.8%. The two
## requirements, "steep faces become rock at any altitude" and "zone shares
## still within tolerance", cannot both hold on terrain this steep.
##
## So the threshold is pushed up until the shares fit: at 75 the rule touches
## only genuinely vertical faces and the worst zone lands 0.96 points off,
## inside the plan's 1 point tolerance. The honest consequence is that "rock at
## any altitude" barely happens below the treeline - the snow rule below is the
## one doing the visible work. Recorded in STATUS.md.
@export var rock_slope_deg := 78.0

## Snow needs ground gentler than this to lie on, in degrees.
##
## This is the rule that fixes the skyline. In the v1 tour, snow was painted
## over near-vertical spires, which is the single thing that made the summits
## read as decorated cones rather than as mountains. Real snow avalanches off
## anything past about 50-60 degrees, so 60 is both physical and affordable:
## the snowfields become the summit plateaux and the gentler shoulders, and the
## faces between them go bare.
##
## 72, NOT THE 60 THIS FIRST SHIPPED AT. The mountain layer's characteristic
## slope is 67 degrees, so a 60 degree cut-off takes snow off essentially every
## face of every peak - the summit screenshot came back as bare brown rock with
## a few white flecks, which is further from "snow covered tops" than the
## plastered-on version it replaced. At 72 the snowfields hold the summits and
## the shoulders and only the true walls go bare, which is the shape the design
## asks for.
@export var snow_max_slope_deg := 72.0

## 12 blocks / 6 m - per-block roughness, added at voxel time only. Deliberately
## NOT part of the coarse heightmap: lake basins are found in the coarse map,
## and a 3-block bump must never be able to invent or drain a lake.
@export var detail_freq := 0.08333
@export var detail_amp := 3.0

## DETAIL LIVES ON SLOPES. How completely the detail layer fades out on flat
## ground, 0 to 1; 0 disables the fade and restores uniform roughness.
##
## Terracing and hill gating exist to carve genuinely flat districts out of
## the coarse map - and then this layer put up to 3 blocks of bump back on
## top of every one of them, at a wavelength short enough to read as
## scattered single protruding blocks rather than as ground. A plain that is
## flat in the coarse map and lumpy in the voxels is the worst of both.
##
## Damping by the COARSE map's slope keeps the roughness where it reads as
## broken ground - on the slopes - and leaves the flats being what they are
## for. Same pattern as the shore fade next to it in detail_at(), and safe
## for the same reason: it can only REDUCE detail, so it cannot move a lake.
@export var detail_flat_damp := 1.0

## The fade window, in degrees of coarse-map slope. At or below _flat_deg the
## detail layer contributes nothing; from _full_deg up it contributes in
## full. 5 covers the terraced shelves and the gated-flat districts; 20 is
## far under the mountain layer's 67 degree characteristic slope, so
## mountainsides keep every bit of their texture.
@export var detail_flat_deg := 5.0
@export var detail_full_deg := 20.0

## 1048 blocks / 524 m - wobbles the elevation zone thresholds so the treeline
## is not a ruler-straight contour line.
@export var zone_jitter_freq := 0.000954

## Blocks of threshold wobble at full jitter, applied +/-.
@export var zone_jitter_blocks := 31.5

## Altitude the layers build up from, in blocks.
@export var base_altitude := 183.5

## Hard clamps. 0 is bedrock and the very top must stay air, or the sky is
## solid and the far mesh has nothing to draw against.
@export var min_altitude := 1.0
@export var max_altitude := 833.7

## Domain warp strength in blocks, used by the TODO(marcel) exercise in
## TerrainGenerator. Ignored by the fallback.
@export var warp_strength := 40.0

## Exponent for the valley flattening curve, used by the other TODO(marcel)
## exercise. Ignored by the fallback.
@export var valley_curve := 1.6


# --- Elevation zones --------------------------------------------------------
#
# SHARES OF MAP AREA, not altitudes, since terrain v2 Stage 7. Each boundary is
# still nudged by the zone_jitter layer and colours still blend across
# zone_blend_blocks, so a transition reads as a wobbling gradient rather than a
# contour line on a map. Only the CENTRE of each boundary changed, from an
# absolute altitude to a percentile of the world's own altitude histogram.
#
# WHY, and it is the most important structural change in terrain v2. Absolute
# thresholds are silently coupled to every other terrain knob. Turning valley
# flattening on at valley_curve 1.6 sent meadow from 56.7% of the map to 79.8%
# and snow from 6.1% to 1.7% - the world had not become greener, it had become
# LOWER, and low means meadow when meadow is defined as "below 75 blocks".
# Every stage that reshapes the terrain would otherwise re-zone the world as a
# side effect, and the re-zoning would look like the stage having gone wrong.
#
# As shares, the zoning is decoupled from world size, from valley_curve, from
# the mountain amplitude, and from anything future. Stage 8 raises relief by
# 2.6x and the seven shares must not move; if they do, this is what is wrong.
#
# The numbers below are the plan's. Meadow falls from 57% to 30%, which is the
# direct answer to "too green and samey". They are normalised before use, so
# they do not have to sum to exactly 1.
@export var share_shore := 0.04
@export var share_meadow := 0.30
@export var share_forest := 0.26
@export var share_alpine := 0.14
@export var share_heath := 0.10
@export var share_rock := 0.11
@export var share_snow := 0.05

## Blocks over which two neighbouring zone colours cross-fade.
##
## DOES NOT SCALE WITH world_scale, and it did in the first version of Stage 8,
## which was a mistake worth recording. A blend band is a distance in ALTITUDE,
## and the area it covers on the ground depends on how steep that ground is. On
## a 2.6x taller world the scaled 15.7-block band was fine on a hillside and a
## disaster on the flats Stage 9 had just created: an entire plain sat inside
## one band and the whole thing came out as green-and-tan confetti.
@export var zone_blend_blocks := 6.0

## Size of one dither patch, in blocks.
##
## The dither decides which side of a blurred boundary a piece of ground falls
## on. Hashed per BLOCK it interleaves at 0.5 m, which reads as a gradient on a
## hillside - where the band is only a metre or two wide - and as salt and
## pepper on a plain, where the whole plain is inside the band at once. Stage 9
## created a lot of plains and the first screenshot of one was confetti.
##
## Hashing a coarser grid makes the interleave happen in patches instead, which
## reads as ground cover rather than as noise. 4 blocks is 2 m, about the size
## of a bush.
@export var zone_dither_blocks := 4


# --- Content ----------------------------------------------------------------

## One candidate tree per this many blocks, in both x and z.
@export var tree_cell_blocks := 8

## Global multiplier on the whole placement product. 0 empties the world of
## trees, 1 is the tuned density, 2 doubles it.
##
## REPLACED tree_probability IN STAGE 4. That knob was "the chance in the
## middle of the forest band", which stopped being a single number the moment
## there were five bands with different rules - a meadow's 0.008 and a forest's
## 0.45 cannot both be it. What survives is the thing a person actually reaches
## for the slider to do, which is "more trees" or "fewer trees" everywhere at
## once. Recorded as a departure.
@export var tree_density_scale := 1.0


# --- Where a tree is allowed to grow ----------------------------------------
#
# THE PLACEMENT PRODUCT. A candidate's probability is
#
#   p = base(zone, altitude in band) * grove * glade
#       * slope_ok * bench_ok * spawn_ok * tree_density_scale
#
# A PRODUCT OF INDEPENDENT TERMS, not a single tuned number, and that is the
# structural point of the stage. Each term answers one question, each is
# disabled by setting its own knob to 0, and none of them has to know what the
# others decided. The old world had one term and read as evenly scattered
# cones, because one term is exactly what "evenly scattered" means.

## Peak probability in the middle of the forest band, and at its two edges.
##
## 0.45 against the old 0.12. Nearly four times as many trees in the heart of a
## forest, which is what makes it a forest you cannot see through rather than
## an orchard - and the edge value is what keeps the treeline a thinning rather
## than a boundary.
@export var tree_base_forest := 0.80
@export var tree_base_forest_edge := 0.20

## Meadow. Two orders of magnitude below the forest on purpose: a meadow with
## trees scattered through it is not a meadow. These are the lone beech and the
## birch at the margin, and there should be room to see between them.
@export var tree_base_meadow := 0.004

## The shore band - birch only - and how far above a lake's shore level it
## reaches, in blocks.
@export var tree_base_shore := 0.03
@export var tree_shore_blocks := 12.0

## Krummholz above the forest, through alpine and heath. Fades to nothing at
## the midpoint of the two bands together, so the last twisted pines give out
## well below the rock.
@export var tree_base_alpine := 0.025

## GROVES: forest clumps, ~90 m across. `grove_share` of the forest is inside a
## grove and grows at full probability; the rest grows at `grove_floor` of it.
##
## This is what breaks the evenness. A forest at one probability everywhere is
## a Poisson scatter, and a Poisson scatter has no clearings, no thickets and
## no edges - which is why the old one read as wallpaper however dense it got.
@export var grove_freq := 0.005556
@export var grove_share := 0.35
## TODO(marcel): at x2 trees, the floor no longer opens the wood.
##
## grove_floor is what a candidate OUTSIDE a grove is multiplied by, and 0.35
## was chosen when a spruce was 13-21 blocks. World feel v1 Stage 6 measured
## canopy closure for the first time and the number between groves is **0.37**,
## against a target of 0.20 - so the places that are supposed to be the open
## wood between groves are now half-roofed, because the same 35% of candidates
## grow trees three times the volume.
##
## It cannot be fixed by tuning the groves: raising old growth's closure and
## opening the space between them pull the same lever in opposite directions.
## It is a design question - how open is the wood between groves meant to be? -
## and the answer is probably somewhere around 0.20, but that changes where
## every tree outside a grove stands and is not a number to move blind on a
## box with no GPU.
##
## The measurement to re-run after changing it:
##   godot --headless --path . --script scripts/tools/worldgen_probe.gd \
##       -- --seed 42 --canopy
@export var grove_floor := 0.35

## OLD GROWTH (world feel v1 Stage 6). What share of groves are the old kind,
## how much bigger their trees are on top of tree_read_scale, and how many of
## their candidates survive.
##
## T5: contrast is what makes huge read. A third of groves at x3 against two
## thirds at x2 is a forest with old growth IN it; every grove at x2.3 would
## just be a forest with slightly bigger trees. The thinning is what stops the
## bigger crowns from becoming one solid roof - fewer trunks, further apart,
## crowns that touch rather than merge.
##
## PROPERTIES, all three: they decide where blocks go.
@export var old_growth_share := 0.33
@export var old_growth_scale := 1.5
@export var old_growth_keep := 0.55

## GLADES: clearings inside the forest, ~160 m across. The top `glade_share` of
## the mask grows nothing at all.
##
## Flowers go in them in Stage 6, which is the other half of why they exist: a
## clearing you can stand in and see the sky is where the light gets to the
## floor, and light on the floor is what grows there.
@export var glade_freq := 0.003125
@export var glade_share := 0.12

## Ground steeper than this grows no trees, in degrees. Krummholz has its own,
## steeper, limit in the species table - it is the one thing up there that
## holds onto a slope.
@export var tree_max_slope_deg := 40.0

## Whether trees avoid benches and plateaux, 0 to 1. 0 disables the term.
##
## A bench is an artificially flat shelf cut into a slope. Covering one in dense
## forest hides the only thing it was carved for, and a flat shelf carrying a
## thicket reads as a lawn that someone planted.
@export var tree_bench_avoid := 1.0

## No trees within this many metres of spawn, ramping to full at the second.
##
## Spawn is chosen to be flat, dry and open, with a mountain in view - and a
## forest closing over it undoes every one of those at once. It is also where
## a player stands still for their first minute, so it is the one place in the
## world where the frame cost of dense foliage is least worth paying.
@export var tree_spawn_clear_m := 24.0
@export var tree_spawn_ramp_m := 60.0

## Chance per meadow candidate of a hero - the one enormous tree.
##
## 0.0004 over a 4-block lattice is about one per 300 x 300 m of meadow, which
## is the density that makes one remarkable. Ten times this and they are just
## big trees.
@export var hero_probability := 0.0004

## How far a trunk may step off its lattice cell, in blocks, on each axis.
##
## BOUNDED, AND THE BOUND IS WALKABILITY. Candidates sit every
## tree_cell_blocks, so two neighbouring trunks are at least
## (tree_cell_blocks - 2 * jitter) blocks apart. Raise the jitter and trees
## start to touch, and a forest you cannot walk through is a wall, not a
## forest - which the traversal probe is what actually checks.
##
## THE BOUND IS ON CENTRES AND THE TRUNKS HAVE WIDTH SINCE STAGE 5, so the rule
## for whoever changes this next is that the CLEAR gap is
## `tree_cell_blocks - 2 * tree_jitter_blocks - max trunk width`, and it has to
## stay above the player's 0.8 m diameter. At cell 8, jitter 2 and a 3 x 3
## forest spruce that is 1 block - 0.5 m - which is tight enough to look like
## the cause of a walkability failure and was investigated as one.
##
## It is not the cause. The traversal probe stalls in the same way at Stage 4,
## BEFORE any tree changed, and gets FURTHER at jitter 2 (1,003 m) than at
## jitter 1 (875 m). See docs/status/world-feel-v1.md, Stage 5.
@export var tree_jitter_blocks := 2

## How much wildness adds to the snag and krummholz weights at the far edge of
## the world, taken from spruce.
##
## Distance is the difficulty axis - see the pillars - and this is that axis
## expressed in vegetation rather than in numbers. Far from spawn the forest
## has more dead trees in it and gives way to twisted pine sooner.
@export var wildness_snag := 0.15
@export var wildness_krummholz := 0.15

## Global multiplier on every species' height and crown radius.
##
## REPLACED FOUR KNOBS IN FOLIAGE V1 STAGE 3, and the four are worth naming
## because they were doing something this one is not: tree_trunk_min/max and
## tree_canopy_min/max described ONE tree, because there was one. Seven species
## cannot share four numbers - a krummholz is 3 blocks and a hero is 42 - so
## the per-species sizes moved into the table in TreeSpecies where they can be
## read next to each other, and what is left here is the only thing that
## genuinely applies to all of them at once: how big trees are in general.
##
## A SHAPE KNOB, so it is in PROPERTIES. Two machines that disagreed about it
## would grow different trees while the join handshake reported a match, which
## is the exact failure the handshake exists to prevent.
##
## 1.0 means the table as authored, which is sized for world_scale 4 - see
## apply_world_scale(), which sets this rather than leaving it at 1.
@export var tree_size_scale := 1.0

## HOW MUCH CLOSER TO THE PLAYER'S SCALE A TREE IS DRAWN THAN THE LAND IS.
##
## World feel v1 Stage 5, and it is the row DESIGN.md's Scale table did not
## have. The land is read against the landscape at 1:4; the player is read
## against themselves at 1:1. A tree is the one object read against BOTH - a
## spruce is three per cent of the ridge behind it, which is exactly right, and
## seven player-heights tall, where a real spruce is twenty-five.
##
## So the trees scale and the land does not. `tree_size_scale` is what the land
## asks for and is derived in apply_world_scale(); this is what the player asks
## for, and the two COMPOSE per species in TreeSpecies.table() - each row taking
## the share of this its "read" field allows. Krummholz and snags take none of
## it: a knee-high alpine shrub at twice the size is not a bigger shrub.
##
## In PROPERTIES because it is a SHAPE knob: two machines that disagreed about
## it would grow different forests while the handshake reported a match.
@export var tree_read_scale := 2.0

## A basin smaller than this many coarse cells is a puddle, not a lake, and is
## discarded. 40 cells at 2 m per cell is about 160 m2.
@export var lake_min_cells := 40

## Shallowest a lake may be at its deepest point, in blocks, before it is
## discarded as wet ground rather than water. See Lakes for why this exists.
@export var lake_min_depth := 1.0

## SHORE FLATS. Blocks of altitude either side of the water line over which
## the detail layer is faded out. 0 disables it.
##
## Lakes are capped shallow so they stay in scale, and per-block detail is up
## to three blocks tall, so a sheet of water over rough ground breaks into
## islands - which is exactly what the first postcard of the new terrain showed
## along every shoreline. Fading detail to nothing at the water line gives a
## clean edge and a margin you can walk up to instead of one that drops
## straight in.
##
## Deliberately a fade on the DETAIL layer rather than a change to the coarse
## heightmap. Lakes are found in the coarse map, so editing it after the fact
## could move a spill point and drain the lake the flattening was for.
@export var shore_flat_blocks := 4.0

## How far the shore field reaches from the water, in coarse cells. 3 cells is
## 12 blocks, 6 m of margin.
@export var shore_flat_cells := 3

## Blocks below the spill point to set the water surface. Without it the water
## sits exactly at the lip and leaks visually over the edge.
@export var lake_level_offset := 1.0

## Deepest a lake is allowed to be, in blocks, measured from the basin floor.
##
## NOT in the plan, and needed. Filling every basin to its spill point puts a
## quarter of the map under water - not shallow swamp either, but genuine
## 28 m deep basins. Real terrain has very few closed basins because rivers
## carve outlets through the rims; noise terrain has thousands, and we do not
## model erosion.
##
## Capping the depth puts water in the BOTTOM of a valley instead of filling
## the valley up to its lip, which is both what the design asks for and what
## Switzerland looks like. Turn it up to see the drowned version.
##
## NOT DERIVED FROM world_scale, and that was tried first. Scaling it with the
## relief in Stage 8 took the largest lake from 1:3.5 to 1:1.3 - a lake at very
## nearly full size in a quarter-scale world - because deeper basins under the
## cap fill to a much wider water line. This is a shaping knob, not a scale
## one; what world_scale owns is lake_min_cells, the size below which a basin
## is a puddle.
##
## 11 blocks is TUNED, not chosen: at the new relief it puts the largest lake
## at 1:4.0 on seed 42 and 1:3.8 on seed 7, which is the coherence the whole
## stage is about. It is also the main water dial - turn it up for a wetter
## world, and Plan B's rivers will want a say in it.
@export var lake_max_depth := 2.0


# --- Spawn, and distance as the difficulty axis -----------------------------

## How far from spawn a player may have to walk to reach water, in metres.
## Two minutes at the walking speed of 5 m/s.
@export var spawn_water_m := 600.0

## How far from spawn a mountain has to be visible, in metres. The High
## preset's fog ends at 600, so a peak further than this is a peak you cannot
## see - and "a mountain in view" has to mean in view.
@export var spawn_mountain_m := 600.0

## Steepest ground, in degrees, that counts as a place to stand up in.
@export var spawn_max_slope_deg := 8.0

## How far from the centre of the map spawn may be, as a fraction of the half
## width.
##
## Not cosmetic. Pillar 3 makes distance from spawn the difficulty axis, and
## the terrain's own wildness ramp is computed from the centre of the world -
## which is only the same thing as distance from spawn if spawn is near the
## centre. Keeping it there is what lets one cheap field stand in for the
## other. See TerrainGenerator.wildness_at().
@export var spawn_center_fraction := 0.25

## DISTANCE READS AS WILDNESS. How much taller the mountain layer grows at the
## edge of the world than at the centre, as a fraction. 0 disables it.
##
## Visual only, and deliberately subtle: it is the hook Pillar 3 will hang
## enemies on, and the first thing it must not do is fight the zone shares.
@export var wildness_relief := 0.35

## How far the rock/scree zone reaches down at the edge of the world, in
## degrees of slope threshold. Subtracted from rock_slope_deg at full wildness,
## so the far country shows more bare stone.
@export var wildness_rock_deg := 12.0


# --- Atmosphere -------------------------------------------------------------

## Metres. Beyond fog_end nothing is visible, which is what makes the far-field
## mesh's edge invisible rather than a cliff at the horizon.
@export var fog_start_m := 360.0
@export var fog_end_m := 600.0

## How many flat steps the fog takes between the two. Look v1: distance is
## bands, not haze - see Look. 1 is a single hard cut at fog_end; 64 is
## indistinguishable from ordinary depth fog. A look knob, local.
@export var fog_bands := 4

## The poster sky, see Look.SKY_SHADER. Flat bands between horizon and zenith,
## and how much of the sky the clouds cover, 0 to 1. Look knobs, local.
@export var sky_bands := 5
@export var cloud_cover := 0.35

## THE FAR FIELD AS A BACKDROP, see FarFieldJob. Every far_band_m of altitude
## the far mesh steps its colour's value by far_band_step - MONOTONIC since
## look v2 Stage 2, lighter with altitude rather than alternating, so a
## mountain reads as stacked contour bands; and its lighting normal is the
## heightmap's slope averaged over far_normal_m, so a flank is one tone rather
## than a patchwork of triangles. Look knobs, local. The voxels near the
## player do neither - they have their own terraces.
@export var far_band_m := 60.0
@export var far_band_step := 0.03
## 24 m was the first value and the postcard came back still a patchwork: at
## 8 and 16 m per vertex that is a couple of quads, and the coarse heightmap
## has a ridge every few of those. A flank is a hundred metres wide.
@export var far_normal_m := 96.0
## Metres per zone-colour cell in the rings beyond the first; 0 samples every
## quad. Blocks of colour on the far peaks rather than speckle.
@export var far_zone_cell_m := 24.0

## Real seconds per in-game day.
@export var day_seconds := 480.0

## Where the cycle starts. 0.25 is sunrise, 0.5 midday.
##
## 0.38 is mid-morning, with the sun about 45 degrees up. Measured rather than
## picked: the sun's angle sets how much light a flat surface receives, and at
## the old 0.3 it was only 18 degrees up, so level ground got under a third of
## the sunlight and the whole palette rendered dark. Here a lit flat surface
## lands within a few percent of its authored colour, which is the point of
## having authored it.
@export var day_start := 0.38


# --- Presentation -----------------------------------------------------------
#
# LOOK, NOT SHAPE. Everything above decides where the ground is and what it is
# made of. Everything in this section decides how that ground is DRAWN, and the
# distinction is load-bearing:
#
#   * a shape knob is part of the determinism contract. Two machines that
#     disagree about mountain_amp are in different worlds, and edits sent
#     between them land in the wrong place. That is what PROPERTIES and
#     hash_key() exist to catch.
#   * a look knob is not. Two machines that disagree about ao_strength see the
#     same terrain with slightly different shading on it. Nothing desyncs.
#
# So these live in LOCAL_PROPERTIES: saved to the .tres, reachable from the F4
# panel, and deliberately NOT hashed and NOT sent in the join handshake. Adding
# them to PROPERTIES would have made a cosmetic preference into a refused join,
# which is a worse bug than the one the hash prevents.
#
# Recorded in STATUS.md as a departure from the plan's hard rule 2.

## COLOUR VARIATION, all four TUNED BLIND - this box has no display.
##
## Direct answer to "too green and samey", on top of the seven zones. The zones
## separate a meadow from a forest; these separate one part of a meadow from
## another, which is what stops a hillside reading as a painted surface.
##
## Per VERTEX, not per block, because per-block colour is incompatible with
## greedy meshing - see Block.jitter(). The cost is zero extra quads.

## How far the per-vertex tint moves brightness, as a fraction. Terrain v2
## started at 0.05; look v1 tried 0.10 for a lithograph grain and the spawn
## tour showed why per-VERTEX tint cannot give one: a greedy-meshed meadow is
## a few huge quads, so the jitter lands on their corners and interpolates
## across them as soft blotches, and doubling it doubled the blotches. 0.07
## is where it reads as ground again. Grain would need per-block colour, which
## greedy meshing rules out - see Block.jitter().
@export var color_jitter_value := 0.0

## Red-against-blue tilt, as a fraction. Smaller than the value jitter: a hue
## shift is much more visible than a brightness shift at the same magnitude.
@export var color_jitter_hue := 0.0

## Blocks per tint cell. 6 blocks is 3 m - about a player and a half, so the
## grain is a texture on the ground rather than a patchwork of fields. Was 12
## through terrain v2, at the old half-strength.
@export var color_jitter_blocks := 6

## How much darker a vertical face is than a horizontal one, 0 to 1.
@export var slope_tint := 0.10

## How much warmer a sun-facing slope is than a shaded one, 0 to 1. This is
## aspect, not lighting - see Block.aspect_shade(). Look v1 doubled it and
## made the curve pick a side, so a slope is two tones meeting at the ridge.
@export var aspect_tint := 0.18

## THE GRAIN, look v2 Stage 3. The tooth of the paper: a hash of the world-space
## half-metre cell, offsetting value by grain_amount and hue by grain_hue. Not a
## texture - hard rule 3 - and not per-vertex jitter either, which is what this
## replaces: jitter varied a whole QUAD and read as blotches, this varies a cell
## and reads as a surface. Terrain only; figures never take it.
@export var grain_amount := 0.065
@export var grain_hue := 0.03
## Gate the grain to the top share of cells at a fixed step, for materials flat
## enough that an even grain reads as noise. 0 is off, and it is off.
@export var grain_sparse := 0.0
## How dark the bottom half-metre of a vertical face goes, so a terrace riser
## has a line under it. 1.0 is off.
@export var contact_band := 0.72

## HOW DARK THE GROUND GOES UNDER A CLOSED CANOPY, at full cover.
##
## World feel v1 Stage 6, and a LOCAL knob: it is a rendering decision, it does
## not move a block, and two machines disagreeing about it is a difference of
## taste rather than of world. On F4. Tuned blind on this box - if 0.35 reads
## as mud on a real GPU, 0.25.
@export var canopy_shade := 0.35

## How dark a fully enclosed corner goes, 0 to 1. 0 disables baked AO entirely
## and restores the pre-v2 mesher exactly, including its quad count.
##
## TUNED BLIND - this box has no display. 0.45 is the value AO conventionally
## lands near in voxel games; check it on a real GPU before trusting it.
@export var ao_strength := 0.45

## Multisample antialiasing for the 3D viewport: 0 off, 1 = 2x, 2 = 4x, 3 = 8x.
##
## Off by default in Forward+, and flat voxel edges against a bright sky are
## about the worst case there is for aliasing - which is the "not sharp in the
## distance" half of Marcel's report. 4x is the starting point the plan names.
@export var msaa_level := 2


# --- Serialisation ----------------------------------------------------------
#
# ORDER MATTERS AND IS FIXED. hash_key() walks this list, and a Dictionary in
# GDScript preserves insertion order but nothing promises that two machines
# built the dictionary the same way. Naming the order explicitly means the hash
# depends on the VALUES and nothing else - which is the entire point of having
# a hash.
## Three fields were missing from this list until terrain v2 Stage 1:
## mountain_mask_lo, mountain_mask_hi and lake_max_depth. All three shape the
## world - the mask decides where mountains are allowed to exist at all - so a
## host and a client disagreeing about any of them would have generated
## different terrain with the handshake reporting a match. Found by auditing
## the list against the @export block; see STATUS.md.
const PROPERTIES: PackedStringArray = [
	"block_size", "world_scale",
	"world_blocks_xz", "world_height_blocks", "coarse_step",
	"voxel_depth_chunks",
	"player_height_blocks", "player_radius_blocks",
	"continent_freq", "continent_amp", "mountain_freq", "mountain_amp",
	"mountain_mask_lo", "mountain_mask_hi",
	"hills_freq", "hills_amp",
	"hills_gate_strength", "hills_mask_freq", "hills_mask_lo", "hills_mask_hi",
	"terrace_height", "terrace_sharpness",
	"bench_strength", "bench_height", "bench_freq",
	"plateau_strength", "plateau_height", "plateau_freq",
	"slope_zone_strength", "rock_slope_deg", "snow_max_slope_deg",
	"detail_freq", "detail_amp",
	"detail_flat_damp", "detail_flat_deg", "detail_full_deg",
	"zone_jitter_freq", "zone_jitter_blocks",
	"base_altitude", "min_altitude", "max_altitude",
	"warp_strength", "valley_curve",
	"share_shore", "share_meadow", "share_forest", "share_alpine",
	"share_heath", "share_rock", "share_snow",
	"zone_blend_blocks", "zone_dither_blocks",
	"tree_cell_blocks", "tree_size_scale", "tree_read_scale", "tree_density_scale",
	"tree_base_forest", "tree_base_forest_edge", "tree_base_meadow",
	"tree_base_shore", "tree_shore_blocks", "tree_base_alpine",
	"grove_freq", "grove_share", "grove_floor",
	"old_growth_share", "old_growth_scale", "old_growth_keep",
	"glade_freq", "glade_share",
	"tree_max_slope_deg", "tree_bench_avoid",
	"tree_spawn_clear_m", "tree_spawn_ramp_m",
	"hero_probability", "tree_jitter_blocks",
	"wildness_snag", "wildness_krummholz",
	"spawn_water_m", "spawn_mountain_m", "spawn_max_slope_deg",
	"spawn_center_fraction", "wildness_relief", "wildness_rock_deg",
	"lake_min_cells", "lake_level_offset", "lake_max_depth", "lake_min_depth",
	"shore_flat_blocks", "shore_flat_cells",
	"day_seconds", "day_start",
]


## Per-machine look and quality. NOT hashed, NOT sent - see the Presentation
## section above for why that is deliberate rather than an oversight.
##
## THE VIEW-DISTANCE KNOBS MOVED HERE IN STAGE 4, and that is a bigger change
## than it looks. They were in PROPERTIES, which meant two things at once:
## a player on a laptop could not join a player on a desktop, because their
## config hashes differed - and worse, if they somehow did, from_dict() would
## overwrite the joiner's view distance with the host's. The preset the plan
## asks for would have been a setting that breaks multiplayer the moment
## anyone touches it.
##
## Nothing about them shapes the world. voxel_radius_chunks decides which
## chunks exist on THIS machine; an edit outside it is still recorded in
## World._edits and replayed when that chunk loads, so two players at different
## radii stay in the same world. far_step and the fog are the far mesh and the
## atmosphere. None of them can move a block.
# --- The decoration layer: LOCAL, every one of them --------------------------
#
# NOT ONE OF THESE IS A SHAPE KNOB, and the test is the one rule 2 states:
# would two machines disagreeing about it mean one player could pick a flower
# the other cannot see? No - flora IDENTITY is a pure function of position and
# seed, and every knob below decides only how much of it this machine draws or
# how it looks while drawing it. A laptop at flora_radius_m 32 and a desktop at
# 96 are standing in the same meadow.
#
# That is what makes density a dial rather than a rewrite, which is the whole
# reason the performance budget can be met by turning something down.

## Columns further than this from the player carry the full ground cover.
@export var flora_radius_m := 64.0

## THE SPARSE RING, from the flora streaming pass. Between flora_radius_m and
## flora_far_m a column draws flora_far_fraction of its plants - the same
## hashed subset every machine would pick, so walking into the full ring adds
## plants around the ones already there. The circle where the grass used to
## end becomes a fade. Set flora_far_m at or below flora_radius_m to switch the
## ring off. Local knobs, like the radius.
@export var flora_far_m := 128.0
@export var flora_far_fraction := 0.25

## An instance is drawn only if its hash falls below this.
##
## HASHED, NOT COUNTED, which is what makes it safe to differ between machines:
## every machine at 0.5 hides the same half, and turning it up reveals the
## plants that were there rather than reshuffling the ones that are.
@export var flora_draw_fraction := 1.0

## Outer edge of the far-tree ring, in metres.
##
## A PRESET FIELD since world feel v1 Stage 7 - it used to be one number for
## every quality level, so High's forest stopped at 300 m while its fog ran to
## 600 and now 800. See VIEW_PRESETS.
@export var far_tree_m := 400.0

## Sway. 0 disables the wind shader entirely.
@export var wind_strength := 1.0

## Fireflies and glowing mushrooms. 0 disables them. Stage 8.
@export var night_life := 1.0


const LOCAL_PROPERTIES: PackedStringArray = [
	"flora_radius_m", "flora_far_m", "flora_far_fraction", "flora_draw_fraction", "far_tree_m",
	"wind_strength", "night_life",
	"view_distance", "voxel_radius_chunks", "sim_radius_chunks", "far_step", "max_jobs_in_flight",
	"fog_start_m", "fog_end_m", "fog_bands", "sky_bands", "cloud_cover",
	"far_band_m", "far_band_step", "far_normal_m", "far_zone_cell_m",
	"ao_strength", "msaa_level",
	"color_jitter_value", "color_jitter_hue", "color_jitter_blocks",
	"slope_tint", "aspect_tint",
	"grain_amount", "grain_hue", "grain_sparse", "contact_band", "canopy_shade",
]


func to_dict() -> Dictionary:
	var out := {}
	for key in PROPERTIES:
		out[key] = get(key)
	return out


## Missing keys keep their default. That is deliberate: an older client joining
## a newer host gets sensible values for fields it has never heard of rather
## than a crash. It does NOT get an identical world - the config hash comparison
## in the handshake is what catches that.
func from_dict(data: Dictionary) -> void:
	for key in PROPERTIES:
		if data.has(key):
			set(key, data[key])


## A short stable fingerprint of every value, for comparing two machines.
##
## Floats are formatted to 6 decimal places rather than hashed directly:
## printing pins the comparison to a fixed precision, so a value that survives
## a round trip through the network as a slightly different double still
## fingerprints the same. Two configs that differ in a way a player could ever
## notice differ far more than 1e-6.
func hash_key() -> String:
	var parts := PackedStringArray()
	for key in PROPERTIES:
		var v = get(key)
		if v is float:
			parts.append("%s=%.6f" % [key, v])
		else:
			parts.append("%s=%s" % [key, v])
	return String.num_uint64(hash(String("|").join(parts)), 16)


## A full copy, LOCAL_PROPERTIES included.
##
## Deliberately not to_dict()/from_dict(), which carry only the half that
## crosses the network. World.setup() clones the config, and a clone that
## dropped the local half would hand the world a default view distance and a
## default AO strength no matter what the player had chosen - silently, because
## every value it dropped has a plausible default.
func clone() -> WorldgenConfig:
	var c := WorldgenConfig.new()
	for key in PROPERTIES:
		c.set(key, get(key))
	for key in LOCAL_PROPERTIES:
		c.set(key, get(key))
	return c


## Resolve world_scale into everything it owns.
##
## Idempotent - it always computes from the REF_ constants, never from the
## current values, so calling it twice does not compound. A world_scale of 0 or
## less means "leave these alone", for hand-tuning.
##
## BOTH AXES SCALE TOGETHER, and the first version of this scaled only the
## vertical. That is worth recording because it looked obviously right and was
## obviously wrong within one measurement.
##
## The plan's Stage 8 lists the amplitudes and the altitudes and no
## wavelengths. Scaling those alone made the mountain layer 2.6x taller over
## the same 150 m footprint, which took its characteristic slope from 67
## degrees to 81 and put 34.7% OF THE MAP PAST 60 DEGREES. A third of the world
## was a cliff - unwalkable, since the character's floor angle is 55 - and the
## traversal probe duly wedged against one and never got out. What that
## produces is not a bigger mountain, it is a spire.
##
## So world_scale changes SIZE and not SHAPE: continent and mountain
## wavelengths stretch by exactly the same factor their amplitudes do, which
## reproduces v1's slope profile at the new size - continent back to 9.1
## degrees, mountains back to 67.1. Massif footprints go from 150 m to 394 m,
## which is what a 350 m mountain ought to be wide, and a 3 km world still
## holds seven or eight of them.
##
## zone_jitter_freq goes with them: the treeline's wobble is a horizontal
## terrain wavelength like any other, and leaving it fixed while the land grew
## would make the boundary look increasingly ruled.
##
## hills and detail are deliberately exempt. Hills are 8 m for a real 30 m
## hill, which is already 1:4, and per-block roughness is about the size of a
## block rather than the size of the world. Scaling those would make the
## corrugation 2.6 times worse, which is the exact opposite of Stage 9.
func apply_world_scale() -> void:
	if world_scale <= 0.0:
		return

	# Relief the world should have, in blocks, if a real 1400 m massif is drawn
	# at 1:world_scale.
	var relief_blocks := (REAL_MOUNTAIN_RELIEF_M / world_scale) / block_size
	var k := relief_blocks / REFERENCE_RELIEF_BLOCKS

	continent_amp = REF_CONTINENT_AMP * k
	mountain_amp = REF_MOUNTAIN_AMP * k
	# Frequency is 1 / wavelength, so a feature k times taller is k times wider
	# when its frequency is divided by k.
	continent_freq = REF_CONTINENT_FREQ / k
	mountain_freq = REF_MOUNTAIN_FREQ / k
	zone_jitter_freq = REF_ZONE_JITTER_FREQ / k
	base_altitude = REF_BASE_ALTITUDE * k
	max_altitude = REF_MAX_ALTITUDE * k
	zone_jitter_blocks = REF_ZONE_JITTER_BLOCKS * k

	# Trees. The species table is AUTHORED for world_scale 4: a spruce there is
	# 13-21 blocks, which is exactly (26..42 m / 4) / 0.5 - the same derivation
	# this used to run for the one species that existed. So the only thing left
	# to derive is the ratio between what this scale asks for and what the
	# table already is, and at world_scale 4 that ratio is 1.
	var tree_hi := (REAL_TREE_HEIGHT_M.y / world_scale) / block_size
	tree_size_scale = maxf(tree_hi / REF_TREE_MAX_BLOCKS, 0.05)

	# The ceiling has to clear the highest possible summit plus the tallest
	# possible tree standing on it, and land on a chunk boundary. Only chunks
	# terrain passes through are built, so headroom is free.
	#
	# AFTER the tree scale, not before: the tallest tree is a function of it.
	# THE COMPOSED MAXIMUM, not the land's alone (world feel v1 Stage 5). The
	# tallest species takes the full read scale, so the sky the world reserves
	# has to clear tree_size_scale * tree_read_scale - and a ceiling derived
	# from the land alone would cut the crown off every hero.
	# AND OLD GROWTH, which is a third multiplier (world feel v1 Stage 6).
	#
	# This over-reserves: the hero is the tallest species and heroes are never
	# old growth, so no tree is actually read_scale * old_growth_scale tall.
	# Over-reserving used to cost real chunks; since Stage 2 it costs nothing
	# at all, because ColumnJob builds only up to the highest solid block a
	# column actually contains and this is merely the bound it may not exceed.
	# Free safety is worth taking - the alternative is a reserve that is
	# correct today and silently short the moment someone raises a knob, with
	# a flat-topped tree in some columns as the only symptom.
	var needed := max_altitude \
		+ REF_MAX_TREE_BLOCKS * tree_size_scale * tree_read_scale \
			* maxf(old_growth_scale, 1.0) \
		+ TREE_RESERVE_MARGIN + 16.0
	world_height_blocks = int(ceil(needed / 16.0)) * 16

	# Lakes. A basin smaller than the real minimum, drawn at this scale, is a
	# puddle. Cells are coarse_step blocks square.
	var cell_m2 := pow(float(coarse_step) * block_size, 2.0)
	lake_min_cells = maxi(int(round(
		(REAL_LAKE_MIN_M2 / (world_scale * world_scale)) / cell_m2)), 1)


## What relief this scale asks for, in metres. For the probe's readout, so the
## target and the measurement come from the same place.
func target_relief_m() -> float:
	return REAL_MOUNTAIN_RELIEF_M / maxf(world_scale, 0.001)


## Resolve view_distance into voxel_radius_chunks, fog_end_m and fog_start_m.
##
## Idempotent, and a no-op at VIEW_CUSTOM. Called after loading and whenever
## the preset changes, which is the only time these three are allowed to move
## as a group.
func apply_view_preset() -> void:
	if view_distance < 0 or view_distance >= VIEW_PRESETS.size():
		return
	var preset: Dictionary = VIEW_PRESETS[view_distance]
	voxel_radius_chunks = preset["radius"]
	fog_end_m = preset["fog_end"]
	fog_start_m = fog_end_m * FOG_START_RATIO
	far_tree_m = preset["far_tree"]


## Name of the current preset, for the debug readout and the boot log.
func view_distance_name() -> String:
	if view_distance < 0 or view_distance >= VIEW_PRESETS.size():
		return "custom"
	return VIEW_PRESETS[view_distance]["name"]


# --- Loading ----------------------------------------------------------------

## Defaults, or the user's tuned copy if there is one.
##
## A broken or stale .tres must never stop the game booting - the whole point
## of the file is that Marcel edits it by hand at 1 a.m. So a failed load is a
## warning and the defaults, never an error.
static func load_or_default() -> WorldgenConfig:
	var cfg := WorldgenConfig.new()
	if ResourceLoader.exists(USER_PATH):
		var res := ResourceLoader.load(USER_PATH, "", ResourceLoader.CACHE_MODE_IGNORE)
		if res is WorldgenConfig:
			print("[Worldgen] loaded config from %s" % USER_PATH)
			cfg = res
		else:
			push_warning("[Worldgen] %s is not a WorldgenConfig, using defaults" % USER_PATH)
	# The preset is the authority over the three numbers it owns, so it is
	# resolved once here rather than every time one of them is read. A .tres
	# saved before Stage 4 has no view_distance in it, gets the default High,
	# and comes out with exactly the values it had - which is why High is the
	# default and not merely the recommendation.
	cfg.apply_view_preset()
	# After the preset and before anything reads a terrain number. The two are
	# independent - one owns how far you can see, the other how big the world
	# is - but both have to happen before the first generator is built.
	cfg.apply_world_scale()
	return cfg


## The seven zone shares, low to high, normalised to sum to 1.
##
## Normalised rather than validated, because these are hand-tuned numbers and
## "your shares add up to 0.98, refusing to generate a world" is a worse
## outcome than quietly scaling them. The ratios are what the design means; the
## absolute values never mattered.
func zone_shares() -> PackedFloat32Array:
	var out := PackedFloat32Array([
		maxf(share_shore, 0.0), maxf(share_meadow, 0.0), maxf(share_forest, 0.0),
		maxf(share_alpine, 0.0), maxf(share_heath, 0.0), maxf(share_rock, 0.0),
		maxf(share_snow, 0.0),
	])
	var total := 0.0
	for v in out:
		total += v
	if total <= 0.0:
		# Every share zeroed. Equal bands is a defensible world; a division by
		# zero is a heightmap full of NaN and a black screen.
		for i in out.size():
			out[i] = 1.0 / float(out.size())
		return out
	for i in out.size():
		out[i] = out[i] / total
	return out


## Apply `--set name=value` arguments, in order, and report what changed.
##
## Every stage of terrain v2 that tunes something by eye has to answer "what
## did this one knob do", which means two runs that differ in exactly one
## number. Editing a file between them works and is a good way to leave the
## file edited, which is how a measurement quietly becomes a measurement of
## something else. This makes the difference part of the command line, so the
## command line is the record of what was measured.
##
##     godot --headless --path . -- --host --set hills_freq=0.00556
##     godot --path . -- --tour --label ao-off --set ao_strength=0
##
## Shape knobs and local knobs both, because "what does this do" is the same
## question for either. Unknown names warn rather than fail: a typo should cost
## a line of output, not a run that looked like it worked.
func apply_cli_overrides(argv: PackedStringArray) -> void:
	var i := 0
	while i < argv.size():
		if argv[i] != "--set" or i + 1 >= argv.size():
			i += 1
			continue
		var pair := argv[i + 1]
		i += 2
		var eq := pair.find("=")
		if eq <= 0:
			push_warning("[Worldgen] --set %s is not name=value" % pair)
			continue
		var key := pair.substr(0, eq)
		var text := pair.substr(eq + 1)
		if not (PROPERTIES.has(key) or LOCAL_PROPERTIES.has(key)):
			push_warning("[Worldgen] --set %s: no such config field" % key)
			continue
		var before = get(key)
		if typeof(before) == TYPE_INT:
			set(key, text.to_int())
		else:
			set(key, text.to_float())
		print("[Worldgen] --set %s: %s -> %s" % [key, before, get(key)])


## Write the current values out so there is something to edit. Called by the
## tuning panel's save, and once on first run so the file exists to be found.
func save_to_user() -> void:
	var err := ResourceSaver.save(self, USER_PATH)
	if err != OK:
		push_warning("[Worldgen] could not save config: %s" % error_string(err))
	else:
		print("[Worldgen] saved config to %s" % USER_PATH)
