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
## RETIRED BY TREES V3 STAGE 7, AND THE NUMBERS ARE KEPT AS A RECORD.
##
## `REF_MAX_TREE_BLOCKS` was the tallest tree the table could grow, and
## `world_height_blocks` reserved that much empty sky above every column so a
## canopy had somewhere to land. Trees are models now and nothing is written
## above the terrain, so the reserve is gone and these describe a world that no
## longer exists. They are left because the self-test's `sky reserve` gate is
## rewritten against them - it now asserts the reserve is ABSENT rather than
## sufficient - and because a constant deleted is a number somebody re-derives.
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
	# FAR_TREE IS THE FOG, AT EVERY PRESET - distance v1 Stage 7. It used to be
	# half of it, so the far half of every wooded ridge was bald and the far
	# field painted it forest-green: a mown slope. World feel v1 Stage 7 raised
	# High from 300 to 400 for this reason and did not close the gap; this
	# closes it. What pays for it is the LOD ramp in TreeFieldJob, which keeps
	# the candidate count growing with the radius rather than with its square.
	# AND FROM DISTANCE V3 STAGE 4 THE TOP TWO PRESETS SEE THE WHOLE REGION,
	# which is decision 3 and the monumental north star as a number.
	#
	# The region is 3 x 3 km, so its diagonal is 4,243 m and its rim is about
	# 2.6 km from a valley floor. fog_end 3200 m puts the far field's own radius
	# at 3,840 m (x FOG_MARGIN) and the camera's far plane at 4,000 m
	# (x Player.FAR_PLANE_RATIO), so the rim is inside the frame from anywhere a
	# player can stand, with headroom. It costs one more ring per doubling and
	# nothing at load - the far field has been logarithmic in reach since
	# distance v1 Stage 4, and this is the first time anything has spent that.
	#
	# FAR_TREE DOES NOT FOLLOW IT, and that is decision 6 rather than an
	# oversight: the impostor ring stays at 800 m and the forest beyond it is
	# terrain colour. Eight hundred metres of impostors is already 1,016 trees at
	# the postcard vantage; four times the radius is sixteen times the ring area,
	# and a far forest at 3 km is two pixels tall. The three distances still have
	# to AGREE - "fog past the far trees is a bald mountain in plain view" - and
	# what makes them agree here is Stage 1's vote, which paints that ground
	# forest-green because it IS forest, rather than a triangle drawn for nobody.
	#
	# Low and Medium are untouched. Their far radius runs out inside ring 2, so
	# the ladder simply stops there and they cost exactly what they cost before.
	# HORIZON V1 STAGE 3, grill Q21. `fog_end` is R, the reach - the distance
	# the fog ramp is normalised to and the distance the far mesh draws to. The
	# presets differ in the NEAR: how many chunks of voxels, and how far the
	# impostor ring goes. High and Ultra both see 32 km, which is D84's "32 km
	# on a clear day"; Low and Medium halve it twice, which costs them two
	# rings and nothing else, because a ring is a constant number of quads.
	#
	# Q21's own sentence says "all presets see R = 32 km" and then gives Low
	# 8 km and Medium 16 km in the next line. The explicit table is taken -
	# it is the more specific of the two and the only one that can be
	# implemented - and Ultra is 32 km either way, which is what every gate in
	# this plan is measured at. Recorded in docs/status/horizon-v1.md.
	{"name": "low", "radius": 6, "fog_end": 8000.0, "far_tree": 400.0},
	{"name": "medium", "radius": 8, "fog_end": 16000.0, "far_tree": 500.0},
	{"name": "high", "radius": 12, "fog_end": 32000.0, "far_tree": 400.0},
	{"name": "ultra", "radius": 16, "fog_end": 32000.0, "far_tree": 800.0},
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
## TODO(marcel): MEASURED AT 3 AND 4, AND THE PROBE STILL CANNOT DECIDE.
##
## Forward+, seed 42, same commit, `--pair-probe` with `--set`:
##
##     3   PASS   median 0.217 m, worst 1.464 m, 38 chunks built for the ring
##     4   PASS   median 0.217 m, worst 1.300 m, 46 chunks built for the ring
##
## Neither dropped the peer below the surface, so 3 looks like 17% less
## collision built for terrain nobody looks at, for free.
##
## IT IS NOT FREE, AND THE PROBE IS WHY. `PairProbe.SPRINT_OUT_M` is 100.0: the
## peer turns round at 100 m, and both runs show exactly ONE `floor false`
## frame - the same step-up at about 40 m. Neither value was ever put under
## pressure. "3 never fell" means "3 survives a 100 m out-and-back on a 4 ms
## host", which is not the question.
##
## The question is how far a body travels between nearing the edge of its ring
## and the next ring landing, and answering it needs a LONGER EXCURSION, not
## another run at 100 m: raise SPRINT_OUT_M to something like 800, or give the
## probe a sustained-run mode that keeps going until the peer either falls or
## reaches the world edge, and watch for the first frame where `floor` goes
## false somewhere that is not a step. Do that before trimming this to 3.
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
##
## 8 UNTIL TREES V4, WHICH IS 4 m - a spacing chosen when a crown was 2 to 4
## blocks wide and the lattice was therefore the whole spacing rule. Against
## the model library's 8 to 22 m crowns a 4 m lattice offers candidates that
## `tree_canopy_spacing` then rejects almost all of, which is scan cost spent
## to produce nothing: at 800 m the ring visited about 160,000 cells to keep a
## few thousand. 24 blocks is 12 m, close to a typical crown's own width, so
## most candidates are a real question again and the scan is a ninth of the
## size. Density is held by `tree_density_scale`, which was retuned with it.
@export var tree_cell_blocks := 16

## Global multiplier on the whole placement product. 0 empties the world of
## trees, 1 is the tuned density, 2 doubles it.
##
## REPLACED tree_probability IN STAGE 4. That knob was "the chance in the
## middle of the forest band", which stopped being a single number the moment
## there were five bands with different rules - a meadow's 0.008 and a forest's
## 0.45 cannot both be it. What survives is the thing a person actually reaches
## for the slider to do, which is "more trees" or "fewer trees" everywhere at
## once. Recorded as a departure.
## TREES V4 RAISED THIS FROM 1.0 TO 4.0, and it is a compensation rather than
## a new opinion about how wooded the world is. The candidate lattice went from
## 4 m to 8 m - a quarter of the candidates - and the crown rule now rejects a
## further quarter of what survives.
##
## IT CANNOT FULLY COMPENSATE, AND THAT IS THE POINT. The pre-v4 forest ran at
## about 3,400 trees per km2 with crowns up to 22.5 m across, which is why they
## grew through each other; 4.0 lands at about 1,750 and no crown touches
## another. The rest of the gap is not recoverable by this knob - it is the
## arithmetic of putting 22 m trees on the ground without overlapping them. The
## lever for a denser forest is a SMALLER TREE: `TreeTable`'s `height_m` is
## NATIVE on every species today, and scaling the library to about 60% would
## roughly triple how many fit. That is a look decision, not a tuning one.
##
## The ring costs about 0.5 ms per tree it draws, so this knob is also the
## rebuild budget: 4.0 is a 2.0 s ring at far_tree_m 800, 2.0 is 1.4 s.
@export var tree_density_scale := 4.0


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
## What fraction of medium and large boulders are PUSHABLE rather than
## scenery (world feel v1 Stage 11).
##
## HASHED, NOT LOCAL (hard rule 5). It changes what the world CONTAINS, not
## what a machine keeps or shows: two peers at different values would disagree
## about which rocks move, and the symptom is a friend heaving at a boulder
## that is scenery on your screen. So it lives in PROPERTIES and moves the
## config hash.
##
## NOT ALL OF THEM, deliberately. A world where every boulder rolls is a world
## with no landmarks in it - you cannot say "meet me at the big rock" if the
## big rock is wherever somebody last shoved it. 0.15 leaves the scenery
## standing and makes the pushable ones a small find.
@export var body_fraction := 0.15

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
@export var tree_jitter_blocks := 4

## HOW MUCH ROOM A CROWN CLAIMS, as a multiple of the two crowns' radii summed.
##
## THE LATTICE STOPPED BEING THE SPACING RULE the night trees became models.
## It bounded TRUNK separation, which is a walkability fact, and that was the
## whole of the rule while a crown was 2 to 4 blocks wide - about what the
## lattice already gave. The pack's crowns are up to 22.5 m and the lattice
## did not move, so canopies grew straight through each other.
##
## 1.0 means two crowns may TOUCH and never interpenetrate, which is what
## "trees should never completely overlap" asks for and reads a little
## park-like. Below 1.0 they interlock - 0.8 is a closed forest canopy with
## visible overlap - and 0 switches the whole test off and restores the
## pre-trees-v3 behaviour. This is a LOOK knob and it is meant to be turned.
@export var tree_canopy_spacing := 1.0

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
## 24 m was the first value and the postcard came back still a patchwork: at
## 8 and 16 m per vertex that is a couple of quads, and the coarse heightmap
## has a ridge every few of those. A flank is a hundred metres wide.
# LIGHT V1 STAGE 3 DELETED THE FAR FIELD'S PAINT KNOBS (grill Q15):
# far_band_m, far_band_step, far_riser_shade, far_riser_lift and far_riser_axis
# tuned altitude bands and a riser shade that existed because the toon ramp
# faceted, and slope_tint, aspect_tint and the three color_jitter_* knobs tuned
# the same idea on the voxels. All of it was paint doing what light does, and
# the code that read it left the C++ and its GDScript twin in one commit so the
# parity tests never saw them disagree. canopy_shade went with the canopy ink
# for the same reason: LOD0 trees cast real shadows now.
#
# All eleven were LOCAL, so the config hash does not move for them.

## FAR_NORMAL_M STAYS, and it is not paint. A flank-averaged lighting normal is
## a coarse mesh's CORRECT normal: it is what makes a far mountain one lit flank
## instead of a patchwork of facets, which under real light matters more than it
## did under the ramp, not less.
@export var far_normal_m := 96.0
## Metres per zone-colour cell in the rings beyond the first; 0 samples every
## quad. Blocks of colour on the far peaks rather than speckle.
@export var far_zone_cell_m := 24.0

## THE MIP LEVEL THE FAR MESH READS, as a function of distance. Distance v1
## Stage 2, and the two knobs that decide how calm the far country is.
##
## The far mesh used to sample the 2 m heightmap every 8 or 16 m and keep
## whatever landed on the lattice - a texture read without mipmaps. Heightmap
## now carries a filtered pyramid, and the level is chosen CONTINUOUSLY from
## the distance to the ring's snapped centre:
##
##     level(d) = log2(d / far_level_ref_m) + far_filter_bias
##
## clamped to [0, Heightmap.MAX_LEVEL] and sampled trilinearly. Continuous
## rather than one level per LOD ring, because a level per ring fixes the
## aliasing and KEEPS THE POP: the ring boundary is still a discrete step at a
## fixed distance from the player, so a mountain still re-cuts itself when it
## crosses one.
##
## far_level_ref_m is the distance at which level 0 is exactly right - about
## where a 2 m feature is a pixel or two. 100 m, so 200 m reads level 1, 400 m
## level 2, 800 m level 3.
##
## far_filter_bias is the margin on top, and it is the main LOOK knob in this
## epic. Nyquist says a 16 m sample spacing needs content band-limited to 32 m,
## so a ring is critically sampled by the level matching its own step and still
## aliases a little; one level coarser is the cheapest honest margin. 0 is "no
## margin", 2 is "twice as smooth as the theory asks".
##
## LOOK, NOT SHAPE, so both are LOCAL and unhashed - hard rule 2. Nothing about
## what the world IS reads them; they choose which mip the backdrop is drawn
## from and nothing else.
@export var far_level_ref_m := 100.0
@export var far_filter_bias := 1.0

## HOW MUCH OF THE SUMMIT THE FILTER GIVES BACK, distance v1 Stage 3.
##
## The far mesh draws lerp(mean_level, max_level, far_peak_gain) - the mean
## pyramid blended towards a parallel pyramid of per-cell MAXIMA. 0 is the
## plain box filter. A mean filter lowers summits and raises valleys, and at
## 600 m the unfiltered lattice already loses 60 blocks of summit before any
## filter is applied (Stage 0's baseline), so some of it has to come back or
## this epic trades a fizzing mountain for a short one - and a mountain that
## visibly GROWS as you walk up to it is the worse artefact of the two.
##
## It is a dilation, not a sharpen: the max pyramid is itself smooth at its own
## level, so this restores amplitude without restoring high frequency. The
## price is that it fills valleys by the same mechanism, which is why the far
## probe reports VALLEY GAIN next to PEAK LOSS.
##
## 0.60, not the plan's 0.35. The plan's starting value was calibrated against
## an assumed baseline near zero; Stage 0 measured the UNFILTERED far field
## already losing 60 blocks of summit at 600 m, and 0.35 only takes the filtered
## loss back to 80. 0.60 takes it to 55 - better than the unfiltered far field
## ever was - while ROUGHNESS stays within 3.5% of Stage 2's and the valleys
## rise by half a block. See docs/status/distance-v1.md, Stage 3.
##
## LOCAL and unhashed, like every other knob in this epic.
@export var far_peak_gain := 0.60

## HOW BIG A ZONE FIELD IS AT DISTANCE, as a fraction of that distance.
##
## Distance v1 Stage 4. `far_zone_cell_m` is one constant applied to every ring
## past the first, so a mountainside at 600 m is painted in the same 24 m
## fields as one at 200 m - and at 600 m a 24 m field is a couple of pixels,
## which is camouflage rather than a poster. The cell is now
## `max(far_zone_cell_m, far_zone_cell_ratio * d)`, so the fields grow with
## range: bigger fields, fewer of them, which is what a poster does.
##
## 0.06 puts a 600 m mountainside in 36 m fields and leaves 200 m unchanged.
## 0 restores the flat constant exactly.
@export var far_zone_cell_ratio := 0.06

## HOW MUCH ONE FAR TREE'S COLOUR DIFFERS FROM THE NEXT, distance v3 Stage 8.
##
## `far_tree_tint` mixes an impostor toward the hillside behind it, so a distant
## forest recedes; it does not stop that forest being thousands of copies of one
## green. This is the difference between them, hashed from the same placement
## cell the yaw already uses, on its own salt so a tree is not both darker and
## turned the same way as its neighbour.
##
## Same shape as `Block.jitter()` and as the poster's own grain: a symmetric
## value multiplier with a smaller red-against-blue tilt at the grain's own
## ratio. **0.07**, which is `grain_amount` rounded - the far country's terrain
## and its forest then read as one effect rather than as a flecked hillside
## carrying a flat wood.
##
## The average is preserved by construction: `1 + g` with `g` symmetric about
## zero. Hard rule 6, measured anyway.
##
## LOOK, NOT SHAPE. LOCAL and unhashed - it changes how a tree is DRAWN, never
## where it stands, which species it is or how many there are.
@export var far_tree_grain := 0.07

## WHERE THE FAR FIELD STARTS, as a fraction of the voxel radius. Distance v3
## Stage 7, decision 5, and DH's `overdrawPreventionPercent` with the same
## sense: 0.9 is almost no overlap, 0.2 is a lot, **0 is the far mesh drawn
## under the whole voxel disc.**
##
## 0.667 IS WHAT SHIPPED BEFORE THIS EPIC - `voxel_radius - 8 * far_step` out of
## `voxel_radius` - and DH's own automatic table would pick 0.8 or 0.9 here.
## **Both are far too little, and the arithmetic says so.** Distance v3 Stage 4
## took the far mesh's rebuild to 6.3 s of wall clock during a sprint; at
## 13 m/s the disc that reaches the screen is centred **82 m** behind the
## player, so its hole - which is centred there too - sticks out behind the
## voxel disc and the stream probe counted twenty-five holes in one run. The
## overlap has to exceed the lag, the lag is 82 m and the voxel radius is 96 m,
## and what is left is nearly nothing. So: 0.
##
## IT IS AFFORDABLE. Covering the whole disc is about 1,800 more ring-0 quads,
## under 2% of the far mesh, all of them hidden under voxels - and hidden is
## the operative word, which is what `FarFieldJob.SEAM_SINK_BLOCKS` is for.
##
## LOOK, NOT SHAPE, and never a hole: hard rule 2 does not trade against a
## vertex count.
@export var far_overdraw := 0.0
# LIGHT V1 STAGE 0 DELETED far_dither_m. The 4x4 Bayer screen-space dissolve
# it clipped the far field with was an ordered dither, and D41 asks for the
# opposite: "far things arrive out of fog, never at a boundary". The fog is the
# answer; the ring geomorph keeps the geometry quiet. LOCAL, so the hash holds.


## WHERE THE AIR BEGINS, as a fraction of the FAR RADIUS. Distance v3 Stage 5,
## decision 4, and DH's `farFogStart` default.
##
## The fog wall is not a fog property. Vanilla Minecraft ramps its fog over the
## last two chunks of a 200-block radius and gets a wall; Distant Horizons ramps
## an exp-squared curve over 60% of a 4 km radius and gets aerial perspective
## (`docs/research/distant-horizons.md` §4, "How the fog wall is avoided"). This
## project's fog ramped from 320 m to 800 m, which is the vanilla shape at a
## different scale, and Stage 4's reach turned that wall into a distance nothing
## reached.
##
## A FRACTION AND NEVER A METRE VALUE, because the world is unbounded by design
## and no new system may bake in a reach (CLAUDE.md, 2026-08-31). At 0 the
## shader falls back to `fog_start_m`, so that knob still means something and is
## still on F4 - which is the other half of the decision-4 gate.
##
## 0.4 IS DH'S NUMBER AND IT IS THE PLAN'S DEFAULT, and it has one consequence
## worth reading before turning it: at fog_end 3200 m the air starts at 1,280 m,
## which is further away than most of what a player is looking AT. DH gets away
## with it because vanilla Minecraft's own fog handles everything nearer; we
## have no second fog. Alternatives at 0.15 and 0.25 are photographed in
## docs/status/distance-v3.md and the call is Marcel's.
##
## LOOK, NOT SHAPE. LOCAL and unhashed.
@export var far_fog_start_frac := 0.2

## HOW HARD THE FAR COUNTRY'S BLOCK LATTICE IS PAINTED, distance v3 Stage 2.
##
## The near field's per-block colour variation is `grain_amount`, in the poster
## shader, on a world-space half-metre lattice - and it is faded out entirely by
## 45 m, because past that "it stops being a surface and becomes a shimmer".
## (The other half of the tint machinery, `color_jitter_value` / `_hue` /
## `_blocks`, is per VERTEX in the mesher and has shipped at 0.0 since look v1:
## a greedy-meshed meadow is a few huge quads, so per-vertex tint lands on their
## corners and interpolates across them as blotches. Checked by grep, not
## assumed.)
##
## So the far country has had no per-block variation at all, at any distance.
## This is that grain, extended outward on a lattice that GROWS with view
## distance instead of being switched off - Distant Horizons' noise recipe with
## its dropoff turned inside out. See the `far_grain` uniform in Look.OPAQUE_SHADER for the mechanism and
## why the average colour is provably unmoved.
##
## Defaults to the near field's own `grain_amount`, which is the honest starting
## value: it is the same effect, on the same kind of lattice, and the far
## country asking for a different amount would be a taste claim nobody has made.
## 0 is off and is the way back.
##
## LOOK, NOT SHAPE. LOCAL and unhashed.
@export var far_grain := 0.0

## WHETHER A FAR CELL IS ONE REAL MATERIAL, distance v3 Stage 1.
##
## 0 is distance v2's path exactly: past ring 0 the far field asks for the zone
## at ONE point, the zone cell's centre, at an altitude read off the pyramid.
## One sample of a smooth surface, so neighbouring cells read neighbouring
## altitudes and agree with each other - which is the mush this epic is named
## after. It is not a blend; it is a low-pass, and no colour constant reaches it.
##
## 1 is Distant Horizons' mode vote (`docs/research/distant-horizons.md` §2c):
## four samples at the sub-cell midpoints, each read at the FINER pyramid level
## so they have something to disagree about, and the most common zone wins.
## Shore never wins unless every sample is shore - DH's "air never wins", in a
## world whose one place-rather-than-altitude zone is the lake margin - and a
## tie falls to the first sample, deterministically. A distant forest becomes
## leaves-next-to-dirt flecks instead of brown-green soup.
##
## A FLAG RATHER THAN A STRENGTH, unlike far_terrace. A zone is an integer and
## there is no half-way between rock and snow; the continuous version of this
## idea is far_grain, which is Stage 2 and lives in the shader.
##
## LOOK, NOT SHAPE. LOCAL and unhashed like every knob distance v1 and v2 added:
## it decides which of two real materials a cell is PAINTED, never what the
## world contains, and nothing that decides what a place IS reads it.
@export var far_vote := 0.0

## HOW MUCH THE FAR COUNTRY IS MADE OF BLOCKS, distance v2 Stage 0.
##
## THE KNOB THIS WHOLE EPIC IS JUDGED BY. 0.0 is the smooth bilinear far mesh
## exactly as `f23c3f0` drew it - byte for byte, hard rule 1, and it is the way
## back if the idea reads badly. 1.0 quantises every far cell's height to that
## ring's own cell width (4, 8 and 16 m) and turns the difference to its
## neighbours into vertical risers, so a mountain at 600 m is drawn out of
## sixteen-metre blocks instead of out of a smooth surface with contour bands
## painted on it.
##
## Values in between blend the quantised height towards the true one, which is
## what makes the seam fade (Stage 8) a multiply rather than a special case:
## inside the seam band the far mesh computes the same surface the voxels do,
## and terracing there would break the agreement that band exists to create.
##
## THE COMPLAINT IT ANSWERS, in Marcel's words on 2026-08-28: "it feels like
## two separate, same art style game, but one is a cube based game, and the
## other one is just sort of an edge based vector game." The far field was
## built to match the near field's SILHOUETTE and never its SURFACE.
##
## LOOK, NOT SHAPE, so LOCAL and unhashed like every other knob distance v1
## added. Nothing about what the world IS reads it - the heightmap hash is
## untouched at every value.
##
## Shipped at 0.0 pending Marcel's ruling; set to 1.0 on 2026-08-31 for him to
## judge in game. Judged the same day, both ways: the cell-width shelf reads as
## "huge terraces" and the smooth mesh reads as "a different game", so flat
## cells STAY and the vertical step moves off the cell width onto the block
## lattice. See far_step_y_blocks, which is where the ruling actually lives.
@export var far_terrace := 1.0

## THE TERRACE'S VERTICAL STEP, IN BLOCKS - Marcel's 2026-08-31 ruling on the
## whole distance look, the Distant Horizons register.
##
## 0 is the cubic lock exactly as distance v2 shipped it: each cell's height
## quantises to its ring's own cell width, and a mountain at 600 m is drawn
## out of sixteen-metre shelves. At 1.0 a cell keeps FULL vertical resolution
## on the block lattice: flat cell tops, risers only as tall as the ground's
## real step to its neighbour - horizontal-only decimation, per-cell height
## and colour, which is DH's own data model on the machinery distance v2
## built. Coarser values are the ladder between the two.
##
## LOOK, NOT SHAPE. LOCAL and unhashed, like far_terrace.
@export var far_step_y_blocks := 1.0

## HOW MUCH FINER THE FAR CELLS ARE THAN far_step - the horizontal detail
## ladder, 2026-09-01. 1 is distance v3's original schedule (4 m cells at the
## seam), 2 is Marcel's 2026-08-31 halving, 4 halves it again to 1 m cells.
## Powers of two only; 3 rounds up. Each doubling costs roughly 2x the
## vertices and 2x the rebuild - 4 is a standing-still preview until the far
## mesher is C++.
##
## FLIPPED TO 4 IN DISTANCE V4 STAGE 10, and decision 5's gate is what did it:
## the flip ships only if the measured C++ rebuild at div 4 on ganymede is
## under 1.5 s of wall. It measures **661 ms** (interleaved ABAB, three runs,
## editor target, view high). So 1 m far cells stop being a screenshot mode.
##
## WHAT THE FLIP COSTS, and it is not the rebuild. div 4 is 3,266,076 vertices
## against div 2's 941,724, and uploading them through
## ChunkMesher.arrays_to_mesh costs **224 ms on the main thread**, every
## rebuild - plus about 124 MB of static memory. That is STATUS items 11 and
## 17, this epic did not touch it, and it is now the far country's binding
## cost. Putting it back is this one number.
##
## LOOK, NOT SHAPE. LOCAL and unhashed, like far_terrace.
## HORIZON V1 STAGE 3: 4 TO 2, AND THE REACH IS WHY.
##
## Marcel's 2026-09-01 ruling put this at 4 - "Marcel wants the cells smaller
## still" - and at a 3.2 km reach that was a 3.4 M vertex far country, which
## the box carried. The reach is 32 km now, which is four more rings, and a
## ring costs about the same as the ring inside it by construction. Measured
## at Ultra, seed 42, `--far-probe --ring-table`:
##
##     far_ring_div 4:  6,511,760 vertices, ring 0 at 1 m cells
##     far_ring_div 2:  1,782,136 vertices, ring 0 at 2 m cells
##
## The plan's budget is 2.0 M and its own ring table reads "ring 0 | 2 m",
## which is this value. So the halving Marcel asked for in the NEAR field is
## spent on the four rings that reach the horizon instead - the same vertices,
## ten times further out.
##
## IT IS ONE SPINBOX ON F4 and on `FarField.FAR_ONLY_PROPERTIES`, so it
## redraws the far country standing still: Marcel can put it back to 4 and see
## both, and Stage 7 reports the frame at each. Recorded under "For Marcel" in
## docs/status/horizon-v1.md, because it revisits a decision of his.
@export var far_ring_div := 2.0

## WHICH MESHER DRAWS THE FAR COUNTRY. Distance v4 Stage 5. 1 is the C++
## GDExtension, 0 forces the GDScript one.
##
## NOT A QUALITY KNOB - the two meshers emit IDENTICAL arrays and the self-test
## asserts it every stage, so moving this changes the rebuild TIME and nothing
## a picture can see. It exists because "identical" is a claim, and a claim you
## can turn off standing still is one Marcel can check with his own eyes
## instead of taking from a gate.
##
## It cannot conjure a mesher that is not there: on a checkout with no compiled
## library the far field builds in GDScript at every value of this, which is
## hard rule 1.
##
## LOOK, NOT SHAPE. LOCAL and unhashed, and on FAR_ONLY_PROPERTIES so it
## redraws in place rather than asking for F7.
@export var far_cpp := 1.0

## HOW MUCH ANALYTIC GRAIN THE FAR MESH ADDS WHERE THE PYRAMID HAS NO DATA,
## in blocks. Distance v5 Stage 6, decision 6. 0 is tonight-minus-this.
##
## The far mesh reads a FILTERED height map, so everything finer than its level
## is gone by construction. Stage 5 was meant to buy that information back with
## four times the real data and could not afford it; this puts the grain back
## analytically, in the far rings only, sampled in WORLD space at the cell's own
## position - so Stage 3's geomorph carries it across a ring boundary for free
## and the two fixes cannot undo each other.
##
## 1.0 BLOCK, and the vertical step is why. `far_step_y_blocks` quantises every
## cell to the block lattice, so a layer smaller than half a block is rounded
## away entirely and one of about a block moves a shelf by one block - which is
## the only grain a block-lattice far country can express, and exactly the
## register the distance epics have been aiming at since v2.
##
## THE NOISE IS THE VOXEL WORLD'S OWN - `TerrainGenerator._detail`, the field
## the ground you walk on is roughened with. So the far country's grain is the
## grain you arrive at rather than a second texture somebody has to keep in
## step with the first.
##
## LOOK, NOT SHAPE: it is added to the cell height the far mesh DRAWS and to
## nothing else - not the pyramid, not `cells`, not the voxel surface, not
## spawn, not lakes. LOCAL and unhashed, on FAR_ONLY_PROPERTIES.
##
## It rides the cell-height path, which is the terraced one, so at
## `far_terrace` 0 it is absent - hard rule 1: that mesh is the way back and
## has to stay the mesh this project shipped.
@export var far_detail := 1.0

## HOW HARD THE WIND MOVES A CROWN. Trees v3 Stage 8, decision 9.
##
## A multiplier on the tree material's sway, weighted by each vertex's height
## as a fraction of its own model's - so the crown moves, the roots do not, and
## a 28 m conifer and a 2 m stump take the same proportion of it.
##
## LOOK, NOT SHAPE, and therefore LOCAL and unhashed (hard rule 5). It moves
## vertices in a shader and nothing else: not placement, not the collider, not
## the canopy cover the forest floor is shaded by. Two machines at different
## values grow the same forest and one of them is windier, which is exactly
## what a look knob is allowed to be.
##
## SEPARATE FROM `wind_strength`, which is the plants'. They are not one wind
## and should not share a slider: grass at the value a tree wants is stiff, and
## a tree at the value grass wants is made of rubber. What ties them together
## is that they read the same clock and the same world position, so they move
## in step without moving by the same amount.
##
## 0 is a still forest, and it is what every stage before 8 shipped.
@export var tree_sway := 0.5

## DO TREES HAVE TRUNK COLLIDERS? Trees v3 Stage 6, decision 8.
##
## LOCAL and unhashed, and that classification takes a moment to justify
## because a collider sounds like world truth. It is not: the world truth is
## WHERE THE TREE IS, which is `TreePlacement.decide()` and is hashed. Whether
## this machine has built a cylinder there is a rendering-side fact of the same
## kind as whether it has built the ground's own collider, and the host is
## authoritative for movement either way (world feel v1's host-authoritative
## input). Two machines at different values still agree about the forest.
##
## The lever exists because a ring of six hundred cylinders is the one thing in
## this epic that costs the PHYSICS server rather than the renderer, and a
## number you can turn to 0 is how that gets measured.
@export var tree_colliders := true

## THE SEASON, 0 FOR SUMMER AND 1 FOR AUTUMN. Trees v3 Stage 8.
##
## A bias on which VARIANT a cell picks, not a tint: the pack ships each tree
## in green and autumn as separate palettes over one shared geometry, so an
## autumn forest is the autumn trees rather than the green ones painted orange,
## and it costs no new mesh. At 1 the autumn twins take four times their table
## weight and the greens fall to a third of theirs - which leaves turning trees
## among green ones rather than a uniformly orange wood.
##
## A SHAPE KNOB, NOT A LOOK KNOB, so it is on PROPERTIES and travels in the
## join handshake (hard rule 5). It changes WHICH TREE a cell grows, and two
## machines that disagreed about it would draw different forests while the
## handshake reported a match. That is exactly the failure the two lists exist
## to prevent.
##
## Snow-dust has no knob and wants none: it is driven by ALTITUDE, out of the
## same treeline band the far field's colour convergence reads.
@export var tree_season := 0.0

## THE HEIGHT MAP'S TILE EDGE, IN BLOCKS. Distance v5 Stage 4, decision 4.
##
## The world is unbounded by design, so the height map is built in tiles
## anchored to the ORIGIN rather than as one array sized to a region - see
## Heightmap's own note for what that does and does not yet change.
##
## 512 IS A MEASUREMENT. The plan's rule is "the size that keeps a tile build
## under ~100 ms". On ganymede, at `coarse_step` 4, the GDScript builder costs
## about 7.2 us a cell, so a 512-block tile is 128 x 128 cells and about 118 ms
## - and the C++ builder does the same tile in single-digit milliseconds.
## Doubling the resolution (Stage 5) quadruples the GDScript number and leaves
## the C++ one comfortable, which is the shape of the whole night: the fallback
## sets the ceiling and the crossing is what makes the ceiling irrelevant.
##
## Rounded DOWN to a multiple of `coarse_step`, because a tile that ended
## mid-cell would put one cell in two tiles.
##
## SHAPE, BUT NOT A SHAPE KNOB. The tiling is an ordering of the same
## arithmetic and the heightmap hash is identical across it - which is Stage
## 4's own gate. LOCAL and unhashed on that evidence.
@export var heightmap_tile_blocks := 512.0

## HOW MANY CELLS BEFORE A RING BOUNDARY THE CELL-HEIGHT SAMPLE SLIDES ONTO
## THE COARSE RING'S LATTICE. Distance v5 Stage 3. 0 turns the geomorph off and
## restores the ring boundaries STATUS items 9 and 18 describe.
##
## Ring boundaries are loud because two rings sample a cell's height at
## DIFFERENT WORLD POINTS - the fine ring at its own cell centre, the coarse
## one at the centre of the coarser cell containing it. Distance v2 Stage 9
## measured the three candidate fixes and only one worked: share the sample
## POINT, keep the step. Sharing it everywhere means 16 m blocks at every
## range; sharing it over the last two cells of each ring costs those cells
## their independence and nothing else.
##
## 4.0, AND IT IS A MEASUREMENT RATHER THAN THE PLAN'S GUESS. Distance v2
## Stage 9 recommended "the last cell or two"; the far probe's ring-boundary
## table on ganymede, seed 42, `far_ring_div` 4, says wider is better and
## nothing it can see gets worse:
##
##     cells       150 m  300 m  600 m  1200 m  2400 m   ALL rms   roughness
##     0 (off)      4.00  10.00  44.00   88.00  147.00     1.513     13.1954
##     2            4.00  10.00  44.00   73.00   73.00     1.278     13.2349
##     4            3.00   7.00  32.00   47.00   40.00     0.981     13.2539
##     6            3.00   7.00  26.00   36.00   26.00     0.829     13.2457
##
## The reason wider helps is what a geomorph IS: it does not remove the height
## difference between two rings, it spreads it over a band, and fizz is the
## change a 32-block step of the player produces. Twice the band is half the
## change per step.
##
## SO WHY NOT 6, OR THE WHOLE RING. Because the far probe cannot see the thing
## that eventually goes wrong. A cell inside the band is drawn on the COARSE
## ring's lattice, so a band as wide as the ring means the fine ring is not
## fine any more - which is distance v2 Stage 9's third experiment, the one it
## measured at "16.00, gone" and deliberately did not ship, because the far
## country would be 16 m blocks at every range. Roughness has not moved at 6,
## so the limit is further out than that; 4 is where the measured gain is
## already 3.7x on the worst boundary and there is still obvious headroom in
## the knob. Turning it up is one number on F4.
##
## LOOK, NOT SHAPE. LOCAL and unhashed, like every far knob, and on
## FAR_ONLY_PROPERTIES so it is judgeable standing still.
@export var far_geomorph_cells := 4.0

## HOW FAR THE PLAYER MUST MOVE HORIZONTALLY BEFORE THE IMPOSTOR RING IS
## REBUILT, in metres. Distance v5 Stage 2. 0 falls back to
## TreeField.REBUILD_STEP_M.
##
## The default is 24.0, which is that constant's own value since distance v1
## Stage 7 and the number every measurement in this project was taken at - the
## knob exists so the lever is in the panel, not to move the number.
##
## HORIZONTAL is the word that matters and it is the whole of STATUS item 21.
## The ring is a function of the player's x and z alone, so a step measured in
## three dimensions let ALTITUDE ask for a rebuild that produces the identical
## ring - and a falling player asks every 24 m of fall, forever. See
## TreeField.update().
##
## LOOK, NOT SHAPE. LOCAL and unhashed, like every far knob.
##
## TREES V4 DOUBLED IT TO 48 m, and the change that made this affordable is the
## same one that made it necessary.
##
## 24 m was chosen while the ring had STRIDE BANDS. A rebuild moved the band
## radii, and a moved band radius restrided a whole annulus at once - so
## rebuilding often was how that jump was kept small. Trees v4 deleted the
## strides: a rebuild now changes which LOD rung a tree draws at and nothing
## else, and the rungs are already a fade apart. The visible cost of waiting
## longer went with them.
##
## The benefit is the ring's share of the worker. Full density costs about
## 0.5 ms per tree drawn - 1.7 s for a 800 m ring at the tuned density, against
## 0.4 s for the old one-in-sixty-four - and this engine build SERIALISES
## GDScript across threads, so ring time is chunk time not happening. At 24 m
## and a walking pace that is a third of the worker; at 48 m it is a sixth.
## 2026-09-04, Marcel on the 5080: 48 m still rebuilt nine times in one walk at
## 3-5 s each on a pool that runs one task at a time - raised to 200 m, and
## the ring itself halved (`far_tree` 400 on the high preset) the same day.
@export var far_tree_step_m := 200.0

## HOW MUCH OF A FRAME THE FAR SYSTEMS MAY SPEND HANDING MESHES TO THE
## RENDERER, in milliseconds. Distance v5 Stage 1, decision 1.
##
## `ArrayMesh.add_surface_from_arrays` and `MultiMesh.buffer` are
## RenderingServer calls and want the main thread, so the far country's
## handover cannot be moved off the frame the player is looking at - it can
## only be SPLIT. The far mesher emits one set of arrays per frontier sector
## and FarUpload hands them over a few at a time.
##
## WHAT THE NUMBER MEANS. It is a line the pump stops AT, not one it never
## crosses: a slice is atomic, so a frame that starts a sector 0.1 ms before
## the budget runs out still pays for the whole sector. At `far_ring_div` 4 one
## sector of sixteen is about 12 ms, so 4.0 buys "one sector a frame, sixteen
## frames a rebuild" - a quarter of a second of handover, none of which is a
## quarter-second frame.
##
## 0 RESTORES DISTANCE V4: everything queued goes up on the frame it arrives,
## which is one `add_surface_from_arrays` per sector back to back, and is the
## A/B for judging whether the budget bought anything.
##
## LOOK, NOT SHAPE - it changes WHEN a mesh reaches the screen and never what
## is in it. LOCAL and unhashed, like every far knob.
@export var far_upload_budget_ms := 4.0

## HOW MUCH OF A FRAME THE CHUNK PUMP MAY SPEND, in milliseconds - horizon v1
## Stage 7, and the first rung of the plan's shrink list.
##
## It was a constant of 8 in `world.gd` and it is the largest single thing on
## the frame this stage measures: at 60 FPS a frame is 16.7 ms and this may take
## half of it, so a second in which many columns land is a second with hitches
## in it whatever the far country costs. A knob rather than a smaller constant,
## because the trade is real in both directions - a smaller slice is a smoother
## frame and a world that arrives more slowly behind you - and Marcel should be
## able to move it standing still and see both halves.
##
## LOCAL and unhashed: it changes WHEN a chunk reaches the screen, never what is
## in it.
@export var chunk_upload_budget_ms := 8.0

## Real seconds per in-game day.
## D52, light v1 Stage 1: A FULL DAY IS ABOUT FORTY MINUTES.
##
## It was eight, which put the pink-then-violet evening under a minute and made
## the hour the tone leans on hardest ("a lit window in a valley at dusk should
## land like the song's swell") something you could miss by looking away. D52
## answers 40 minutes, the evening six to eight of them.
##
## THE SECOND HALF OF THAT IS NOT HERE but in `SkyCycle.arc_angle()`: at a
## uniform angular speed even a 2,400-second day gives the evening only about
## 133 seconds, so the sun is slowed threefold across it. This knob sets how
## long the circle takes; the warp sets where the time goes.
##
## HASHED, and it stays hashed. It does not change what a seed produces - the
## probe's heightmap, spawn, lakes and trees are identical either side of this
## - but two machines running different clocks would disagree about the hour
## for the whole of a session, and the hour is what every light in the world is
## a function of. That is the class of disagreement the handshake exists to
## refuse. The config hash therefore MOVES with this change, which is correct
## and is recorded in docs/status/light-v1.md.
@export var day_seconds := 2400.0

## Where the cycle starts. 0.25 is sunrise, 0.5 midday.
##
## 0.38 is mid-morning, with the sun about 45 degrees up. Measured rather than
## picked: the sun's angle sets how much light a flat surface receives, and at
## the old 0.3 it was only 18 degrees up, so level ground got under a third of
## the sunlight and the whole palette rendered dark. Here a lit flat surface
## lands within a few percent of its authored colour, which is the point of
## having authored it.
@export var day_start := 0.38

## THE WEATHER, and there is no weather system (Q13).
##
## "clear" or "eerie". Eerie is D7's "night or day with the life taken out":
## saturation down, fog thick and inverted so the tops of tall things vanish,
## and every warm light off through the `kubik_warm` global. It is a MODIFIER
## ON THE HOUR and never a fifth hour - `SkyCycle.EERIE` is one dictionary of
## overrides applied after the blend.
##
## No transitions, no rain, no snowfall: that is the weather epic. This is one
## flag so the round 3 brief's eerie shot can be taken.
##
## LOCAL and unhashed: it changes the light on a world, never the world.
@export var weather := "clear"


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

## THE MATERIAL NOISE, light v1 Stage 0, and it is the bible's own sentence
## rather than an effect: "one body colour in three shades plus a little
## per-cube noise (one step up or down on random cubes) so big walls do not
## look flat" (`10-color-and-light.md`).
##
## `grain_sparse` is the share of half-metre cells that take a step at all;
## `grain_step` is how far the step goes, up or down by a second hash. That is
## a STEP on SOME cells, at every distance. What it replaces - grain_amount and
## grain_hue - was a continuous wobble in value and hue on EVERY cell, faded
## out by 45 m, and `contact_band` was a drawn line under every vertical face.
## Both were paint doing what light does, and light does it now.
##
## LOCAL, like every knob in this block: they change how a surface is drawn and
## never where a block stands.
@export var grain_sparse := 0.33
@export var grain_step := 0.12

## How dark a fully enclosed corner goes, 0 to 1. 0 disables baked AO entirely
## and restores the pre-v2 mesher exactly, including its quad count.
##
## TUNED BLIND - this box has no display. 0.45 is the value AO conventionally
## lands near in voxel games; check it on a real GPU before trusting it.
## 0 FROM LIGHT V1 STAGE 0 (Q9). SSAO does this job downstream of the mesh, and
## at 0 the mesher skips the corner sampling entirely so a run merges by block
## id alone - bigger quads and a cheaper column job, measured in Stage 3. The
## knob stays so the baked-AO look can still be photographed.
@export var ao_strength := 0.0

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
	# TREES V3 STAGE 8. The season decides which VARIANT a cell grows, so it is
	# world truth and travels in the join handshake (hard rule 5).
	"tree_season",
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
	"body_fraction",
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

## HOW FAR AN IMPOSTOR'S COLOUR TRAVELS TOWARDS ITS HILLSIDE, distance v1
## Stage 6.
##
## An impostor is shade A of its species, flat, at every range - so a forest at
## 600 m is the same green as one at 100 m while the mountain behind it has
## drained to a fog-lit grey-green. That reads as a decal rather than as part
## of the hill, and it is the near half of the same complaint the far mesh's
## own colour pass answered: a thing far enough away is a shade of the country
## it is in.
##
## The tree's colour is mixed towards the colour the far mesh paints at that
## exact place (FarFieldJob.backdrop_color) by a factor that is 0 at the voxel
## edge and this value at the fog. 0.5, the plan's number: at the fog the tree
## is halfway to its hillside and still recognisably a tree. 0 restores the
## flat species colour exactly.
##
## LOCAL and unhashed - it changes how a tree is drawn, never where it stands
## or what it is.
@export var far_tree_tint := 0.5

## Sway. 0 disables the wind shader entirely.
@export var wind_strength := 1.0

## Fireflies and glowing mushrooms. 0 disables them. Stage 8.
@export var night_life := 1.0


# --- HORIZON V1 --------------------------------------------------------------
#
# Every knob in this block is LOCAL and UNHASHED. None of them changes what a
# seed produces: they change how far the machine looks, how a developer gets
# there, and how the far country is cut. The canonical world line is reprinted
# after every stage of horizon v1 and one changed character is a red gate, so
# a knob that belonged in PROPERTIES would fail that gate on the day it was
# added rather than on the day it was wrong.

## HOW FAR THE VIEW REACHES, in metres. The north star's second sentence, as a
## number: R.
##
## THIS IS THE ONE THE FOG RAMP IS NORMALISED TO. The far material fades toward
## the hour's fog colour over `0.4 R` to `R`, so the haze is a fixed shape on
## whatever distance the machine is drawing rather than a density that has to
## be retuned every time the reach moves. `fog_end_m` is kept equal to it by
## `apply_view_preset()`, because the far radius, the camera's far plane and
## the tour's own far plane are all derived from `fog_end_m` and have been
## since terrain v1; the two names are one number and this is the one with the
## meaning in it.
##
## Set by the preset (VIEW_PRESETS): 8 km at Low, 16 at Medium, 32 at High and
## Ultra. D84's "32 km on a clear day" is the top two.
@export var far_reach_m := 32000.0

## HOW FAR THE ORIGIN IS ALLOWED TO DRIFT before the world is rebased, in
## metres. Stage 6. See World.origin_offset_tiles.
@export var far_origin_rebase_m := 2048.0

## NOCLIP SPEED, in metres per second. Host only, developer only.
##
## `Locomotion.FLY_SPEED` was 18 because the world was 3 km across. It is
## unbounded now and the far view reaches 32 km, so crossing it at 18 m/s is
## half an hour. The constant stays as the default and this is what
## `Locomotion.fly_speed` is set from on the main thread.
@export var fly_speed_mps := 18.0

## HOW MUCH OF A FAR CELL'S COLOUR COMES FROM THE FOREST STANDING ON IT.
## Stage 4, and inert before it.
@export var far_forest_blend := 0.7

## SAMPLES PER AXIS INSIDE ONE COARSE TILE CELL, 1, 2 or 4. Stage 1.
##
## A level-L cell is the mean of `far_supersample^2` samples of `raw_height` at
## the sub-cell centres. 1 is one sample at the cell's own corner, which is
## exactly what the home region's level 0 is built with and is why the home
## region cannot move: `build_tile` at supersample 1 is byte for byte the
## function distance v5 shipped.
@export var far_supersample := 2.0

## HOW FAR A FAR RING MAY DRIFT FROM ITS ANCHOR before it is rebuilt, as a
## fraction of its INNER radius. Stage 3.
@export var far_ring_recenter_frac := 0.25

## TILES OF APRON kept beyond each ring's outer radius. Stage 1.
@export var far_tile_apron := 1.0


const LOCAL_PROPERTIES: PackedStringArray = [
	"flora_radius_m", "flora_far_m", "flora_far_fraction", "flora_draw_fraction", "far_tree_m",
	"wind_strength", "night_life", "far_tree_tint",
	"view_distance", "voxel_radius_chunks", "sim_radius_chunks", "far_step", "max_jobs_in_flight",
	"fog_start_m", "fog_end_m",
	"far_normal_m", "far_zone_cell_m",
	"far_level_ref_m", "far_filter_bias", "far_peak_gain", "far_zone_cell_ratio",
	"far_terrace", "far_step_y_blocks", "far_ring_div",
	"far_vote", "far_grain", "far_fog_start_frac",
	"far_overdraw", "far_tree_grain",
	# DISTANCE V4. LOCAL and unhashed like every far knob before it - and it
	# has to be on THIS list rather than only in the @export block, or
	# World.setup()'s clone drops it and the panel's value never reaches the
	# world. Same failure the flora and AO knobs are guarded against above.
	"far_cpp",
	# DISTANCE V5 STAGE 1. LOCAL and unhashed for the same reason far_cpp is:
	# it changes when a mesh reaches the screen and never what is in it.
	"far_upload_budget_ms", "chunk_upload_budget_ms",
	# DISTANCE V5 STAGE 2. The impostor ring's rebuild cadence.
	"far_tree_step_m",
	# DISTANCE V5 STAGE 3. The ring-boundary geomorph.
	"far_geomorph_cells",
	# DISTANCE V5 STAGE 4. The height map's tile edge.
	"heightmap_tile_blocks",
	# DISTANCE V5 STAGE 6. The far mesh's analytic grain.
	"far_detail",
	# TREES V3 STAGE 2. The wind in the crowns - a look knob, so LOCAL: two
	# machines at different values grow the same forest.
	"tree_sway",
	# TREES V3 STAGE 6. The trunk collider ring.
	"tree_colliders",
	# HORIZON V1. LOCAL and unhashed, every one - see the block by
	# `far_reach_m`. On this list rather than only in the @export block because
	# World.setup() clones the config through these two lists and a knob that
	# is on neither is silently dropped on the way into the world.
	"far_reach_m", "far_origin_rebase_m", "fly_speed_mps", "far_forest_blend",
	"far_supersample", "far_ring_recenter_frac", "far_tile_apron",
	"ao_strength", "msaa_level",
	"grain_sparse", "grain_step",
	# LIGHT V1 STAGE 1. The eerie flag (Q13): a modifier on the hour.
	"weather",
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
	# TREES V3 STAGE 7: THE SKY RESERVE IS GONE, AND THE COLUMN ENDS AT THE
	# TERRAIN.
	#
	# This used to add REF_MAX_TREE_BLOCKS * tree_size_scale * tree_read_scale
	# * old_growth_scale + a margin - about 21 metres of empty chunks above
	# every column in the world - because a crown stamped into the volume must
	# not be cut off by a chunk nobody built. Nothing writes above the terrain
	# any more: `TreeField` instances a model library and never touches a
	# voxel, so the tallest thing a column can contain is its own ground.
	#
	# THE 16 STAYS and it is not the trees'. It is one chunk of headroom over
	# the highest ground, which the mesher's neighbour lookups and the
	# streamer's own rounding both want, and it predates the reserve.
	var needed := max_altitude + 16.0
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
	# R AND `fog_end_m` ARE ONE NUMBER, horizon v1 Stage 3. `far_reach_m` is
	# the name with the meaning in it - the distance the fog ramp is normalised
	# to - and `fog_end_m` is the name everything downstream already derives
	# from: the far radius (`fog_end_m / bs * FOG_MARGIN`), the camera's far
	# plane (`fog_end_m * Player.FAR_PLANE_RATIO`) and the tour's own. Keeping
	# them equal here means one preset row sets both and neither can drift.
	far_reach_m = fog_end_m


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
