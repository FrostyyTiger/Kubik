class_name FarFieldJob
extends RefCounted

## Builds the low-poly terrain mesh that stands in for voxels beyond the voxel
## radius. Runs on a worker thread, for the same reason chunk meshing does.
##
## WHY THIS EXISTS AT ALL. The design wants a 200 m view distance. 200 m of
## voxels is roughly 30,000 chunks, which is not a performance problem so much
## as an impossibility. Everything past the voxel radius is therefore one mesh
## built straight from the coarse heightmap at 4 m per vertex - the same
## heightmap the voxels came from, so the two agree about where the ground is.
##
## IT IS BUILT AROUND THE PLAYER, NOT AROUND THE WORLD. The plan describes one
## mesh over the whole 1.5 km map. Flat-shaded, that is 374x374 quads at four
## unshared vertices each - about 559k vertices, well past the plan's own
## ~300k budget, and it would have to be rebuilt every time the voxel hole
## moved. Fog is fully opaque at 200 m, so terrain past that is not merely
## cheap to draw, it is INVISIBLE. Building a disc sized to the fog instead
## gives ~45k vertices and a rebuild small enough to hide on a worker thread.
## Recorded in STATUS.md as a departure.
##
##
## LOD RINGS, AND WHY VIEW DISTANCE IS NOW NEARLY FREE
##
## Terrain v1 built the whole disc at one resolution, so its cost was quadratic
## in the fog distance: 42,684 vertices at 200 m, 178,428 at 400 m, 404,588 at
## 600 m. That is what made fog_end look expensive, and it is why the v1 world
## could not simply see further.
##
## It is the wrong shape of cost. A vertex 500 m away covers a hundredth of the
## screen area of one 50 m away, so spending equal detail on both spends it
## where it cannot be seen. The rings below step the resolution down with
## distance - 4 m per vertex out to 200 m, 8 m to 400 m, 16 m beyond - and each
## ring covers four times the area of its predecessor for a comparable vertex
## count. Cost becomes roughly logarithmic in view distance, which is what
## turns fog_end from a performance dial into a look dial.
##
##
## CRACKS, AND WHY THIS USES SKIRTS
##
## Where a fine ring meets a coarse one, the fine ring has a vertex halfway
## along each coarse edge. Its height comes from the heightmap; the coarse edge
## is a straight line between its own two ends. The two do not agree, and the
## disagreement is a crack you can see the sky through - the classic T-junction
## of every LOD scheme.
##
## The textbook fix is to snap those midpoints onto the coarse edge. It is
## exact and costs nothing at runtime, and it needs to know which vertices lie
## on a ring boundary and between which two coarse vertices - easy on square
## rings, genuinely awkward on the DISC this builds. The disc is worth keeping:
## it matches the shape of the fog, and a square would build 27% more quads in
## corners that are opaque grey.
##
## So: skirts. Any quad whose neighbour across an edge belongs to a different
## ring, or to no ring at all, drops a vertical curtain from that edge. It costs
## a few percent in vertices, it does not care what shape the rings are, and it
## cannot be subtly wrong the way a snapping rule can - a crack is either
## covered or it is not.

## How far past fog_end to build, as a multiple. Fog hides everything at
## fog_end; a little beyond means the mesh's own edge is never the thing you
## notice first.
const FOG_MARGIN := 1.2

## Where each level of detail ends, in metres. The last ring has no entry here:
## it runs from the final boundary out to the fog.
##
## TWO MORE RINGS SINCE DISTANCE V3 STAGE 4, and they are what makes the whole
## region visible - decision 3, the monumental pillar made literal.
##
## | ring | cells | covers        | cubic-lock step |
## | 0    | 2 m   | seam to 150 m | 2 m             |
## | 1    | 4 m   | 150-300 m     | 4 m             |
## | 2    | 8 m   | 300-600 m     | 8 m             |
## | 3    | 16 m  | 600-1200 m    | 16 m            |
## | 4    | 32 m  | 1200-2400 m   | 32 m            |
## | 5    | 64 m  | 2400 m to the fog | 64 m        |
##
## HALVED 2026-08-31, Marcel's ruling on the block-lattice look: the flat tops
## were twice too wide at every range. The halving lives in the ring divisor
## rather than in far_step's default because the panel now saves the config to
## user://worldgen.tres, and a saved far_step would shadow a default forever.
## The sixth ring keeps the horizon at 64 m cells, where the fog is the one
## doing the drawing; the price of the whole halving is roughly 2x the quads,
## not 4x.
##
## EACH DOUBLING OF THE REACH COSTS ONE MORE RING AND ABOUT WHAT THE LAST ONE
## COST. Ring area grows 4x per ring and cell area grows 4x with it, so the
## quad count per ring is roughly constant - which is DH's "constant cells per
## section with logarithmic ring spacing", and it is also exactly what an
## unbounded world will need. Measured rather than trusted: the table is in
## docs/status/distance-v3.md.
##
## POWERS OF TWO, so distance v2's subset property extends unchanged: every
## 64 m shelf is also a 32 m shelf is also a 16 m one, and a ring boundary
## SUBDIVIDES a mountain's shelves rather than moving them.
##
## NOTHING HERE READS THE WORLD'S SIZE. The rings are derived from the
## configured far radius (fog_end_m x FOG_MARGIN) and stop at whichever one the
## radius runs out inside - so Low and Medium simply never start rings 3 and 4,
## and a preset that reached ten kilometres would want a sixth entry and
## nothing else. CLAUDE.md, 2026-08-31.
## FOUR MORE RINGS SINCE HORIZON V1 STAGE 3, and they are what makes the north
## star's second sentence a number: the view reaches the horizon, 32 km on a
## clear day (D41 as raised by D84).
##
## | ring | covers          | step multiple |
## | 6    | 2400-4800 m     | 64            |
## | 7    | 4800-9600 m     | 128           |
## | 8    | 9600-19200 m    | 256           |
## | 9    | 19200-38400 m   | 512           |
##
## EACH DOUBLING OF THE REACH COSTS ONE MORE RING AND ABOUT WHAT THE LAST ONE
## COST - the sentence four rings above, now with four more rings standing on
## it. Ring area grows 4x per ring and cell area grows 4x with it, so the quad
## count per ring is roughly constant; the measured table per ring is in
## docs/status/horizon-v1.md and the sum at Ultra is what the plan's 2.0 M
## vertex budget is read against.
##
## RING 5'S OUTER MOVES FROM "TO THE FOG" TO 4,800 m. It used to be the last
## ring and ran to `far_radius`, which at the old 3,200 m reach was 3,840 m of
## 32 m cells; it is now a ring like any other and the reach is carried by the
## four above it.
const RING_OUTER_M := [150.0, 300.0, 600.0, 1200.0, 2400.0,
	4800.0, 9600.0, 19200.0, 38400.0]

## Blocks per vertex in each ring, as a multiple of the BASE step below. At the
## default far_step of 8 blocks that is 2, 4, 8, 16, 32 and 64 metres per
## vertex.
const RING_STEP_MULTIPLE := [1, 2, 4, 8, 16, 32, 64, 128, 256, 512]

## The innermost cell is far_step / config.far_ring_div, in blocks - see the
## table above for why the divisor exists at all. Every conversion between
## overlap CELLS and BLOCKS must go through base_step_blocks() below, or the
## exclusion radius and the job disagree about where the far mesh stops -
## which is a hole.
##
## A KNOB SINCE 2026-09-01, because Marcel wants the cells smaller still and
## GDScript cannot yet afford them: at 4 the whole schedule doubles again
## (roughly 1.6 M vertices, a 40 s rebuild on his box). Judgeable standing
## still today; playable when the far mesher lands in C++.
static func ring_div(config: WorldgenConfig) -> int:
	# 1, 2 or 4 - a power of two, so distance v2's shelf-subset property and
	# the ring-boundary alignment hold. 3 on the panel rounds up.
	return 4 if config.far_ring_div >= 3.0 else maxi(int(config.far_ring_div), 1)


## The one base step every ring, overlap and exclusion derives from.
static func base_step_blocks(config: WorldgenConfig) -> int:
	return maxi(config.far_step / ring_div(config), 1)

## How far a skirt hangs below its edge, as a multiple of that ring's step in
## BLOCKS. At 1.0 a skirt covers any mismatch up to a 45 degree slope across
## one cell, which is well past what a heightmap sampled at that spacing can
## produce. Cheap insurance either way: a skirt that is too long is buried in
## the hillside, a skirt that is too short is a hole in the horizon.
const SKIRT_DEPTH_CELLS := 1.0

## THE TRANSITION BAND, in cells of the innermost ring.
##
## Terrain v1 left the voxel/far-field seam as a known artefact, and at 96 m of
## voxels against 600 m of visibility it became the most visible thing in the
## game. The far mesh is the COARSE heightmap; the voxels are that plus
## per-block detail, so the two disagree by up to detail_amp - three blocks,
## 1.5 m - and they disagree along a circle centred on the player that moves
## with them.
##
## Three fixes were on the table. A skirt hides a hole but not a STEP, and a
## step is what this is. A blend band that merely fades the colour leaves the
## geometry wrong. So: sample the detail layer into the far mesh near the seam,
## at full strength where it meets the voxels and fading to nothing over this
## many cells. At the seam the far mesh is then computing the same surface the
## voxels are, so there is nothing left to disagree about; a few cells out it
## is back to the cheap coarse mesh, and the fade is what stops the boundary of
## the FIX becoming the new visible line.
##
## 8 cells is 32 blocks, 16 m at the default far_step and ring divisor - the
## same METRES the band has always measured: it was 4 cells until 2026-08-31,
## and the halving of the innermost cell doubled the count to keep the
## distance. The band now scales with the cell: at far_ring_div 4 it is 8 m,
## which still covers detail_amp's 1.5 m disagreement many times over. Long
## enough that the fade is not itself an edge, short enough that the extra
## noise samples are a few hundred quads on a ring of tens of thousands.
const SEAM_BAND_CELLS := 8.0

## HOW MANY TIMES LONGER THE TERRACE'S OWN FADE IS. Distance v2 Stage 8.
##
## Decision 5 says terracing fades in as the seam band fades out, and the seam
## band is four cells because that is what the DETAIL samples need: long enough
## that the fade is not itself an edge, short enough that the extra noise samples
## are a few hundred quads on a ring of tens of thousands.
##
## The terrace has neither constraint and a harder job. What it is fading
## between is not "coarse" and "coarse plus a little noise" - it is the VOXEL
## surface and a quantised one, and those differ by up to half a ring-0 step
## plus a detail_amp wherever the ground is steep. Over four cells that is a
## visible ramp on a summit; over twelve it is not. It costs nothing: the fade
## is a multiply on a number the cell cache already holds, and no extra sample
## is taken for it.
const TERRACE_FADE_CELLS := 12.0

## Blocks to raise the far mesh by inside the band, to meet the TOP of a voxel
## rather than its centre.
##
## The topmost solid block in a column is floor(surface), and the face you see
## and stand on is its top, at floor(surface) + 1. So the visible voxel ground
## averages half a block above the surface function the far mesh draws
## directly. Without this the seam is level on average and still a consistent
## half-block step down, which reads as a shallow moat around the player.
const VOXEL_TOP_BIAS_BLOCKS := 0.5

## Skirts are drawn darker than the surface they hang from. They stand in for
## ground seen edge-on through a crack, and a crack that lights up BRIGHTER
## than the terrain around it draws the eye straight to the artefact it is
## there to hide.
##
## A TERRACE RISER IS NOT A SKIRT and does not use this - see far_riser_shade,
## which starts at the same 0.7 and is a knob because a riser is a real surface
## with a real normal, where a skirt is a curtain hiding a crack.
const SKIRT_SHADE := 0.7

## WHICH RING'S CELL SIZE THE TERRACE IS CUT AT - for every ring, not just for
## that one. Distance v2 Stage 1; see _t_level for why it is one level and not
## one per ring.
##
## An index into RING_STEP_MULTIPLE, so 0 means "the finest ring's 4 m cell" -
## level 2 at the default far_step and far_filter_bias.
##
## MEASURED, NOT PICKED. All three values were run through the far probe at
## far_terrace 1.0, seed 42, on ganymede; the table is in the status doc. The
## coarsest looks like the safe choice - every ring would then quantise a
## surface smoother than its own cells - and it is the worst of the three on the
## two things that can be seen:
##
##   * PEAK LOSS at 600 m. Level 2 draws +29.40 blocks against f23c3f0's
##     +55.28; level 4 draws +56.60, which fails Stage 4's gate before Stage 4
##     starts. A terrace cut from a heavily filtered surface is a terrace cut
##     from a mountain that is already too short.
##   * THE SEAM. The terrace fades in over four cells at the voxel boundary, and
##     what it fades TOWARDS is this level. The further that is from the surface
##     the voxels actually have, the deeper the dip in the middle of the fade.
##     Standing on the world's highest summit, the 0-100 m band measures 19.4
##     blocks of fizz at level 2, 45.6 at level 3 and 98.2 at level 4.
##
## What it costs is the 400 m ring boundary - 80 blocks against 64 at the two
## coarser levels - and that boundary is Stage 9's subject, measured there.
const TERRACE_LEVEL_RING := 0

## HOW WIDE A "LOCAL MAXIMUM OF THE FLANK" IS, in blocks each side. Distance v2
## Stage 4, decision 9.
##
## Rounding to nearest saws a summit flat: a peak whose true height falls just
## below a step boundary loses up to half a step, and at ring 2 half a step is
## 8 m. So a cell that is a local maximum rounds UP and every other cell rounds
## to nearest - a ridgeline keeps its height and gains at most one step, a
## hillside stays honest.
##
## 96 blocks is far_normal_m's own half-span, which is the window _flank_normal
## already averages the slope over, so "local maximum of the FLANK" is read at
## the scale the flank is read at rather than at the scale of one cell. A local
## maximum over one cell would fire on every bump; over 96 blocks it fires on
## summits.
##
## In blocks rather than in cells so the test asks the same question in every
## ring - the ring converts it to a whole number of its own cells - which
## matters because a cell that is a ridge in ring 1 and not in ring 2 is another
## block of difference at the 400 m boundary.
const RIDGE_SPAN_BLOCKS := 96

## HOW MUCH FINER A RIDGE CELL'S STEP IS THAN ITS RING'S. Distance v2 follow-up,
## and it replaces Stage 4's round-UP rather than joining it.
##
## Stage 4 rounded a local maximum up to the next whole step so a summit kept its
## height. It works - PEAK LOSS went +29.40 to +13.40 - and it has two costs that
## only showed up in the pictures. A summit's last 16 m collapses into ONE slab,
## so the peaks read as a city skyline rather than as an alpine one; and a lone
## crest cell is pushed a whole step above its neighbours, which is where the
## one-block "needle" standing in front of the massif came from.
##
## Both are the same mistake: rounding UP is a bigger lie than rounding to
## nearest, and at a summit it is told against the sky, where the eye is best at
## catching it.
##
## So a ridge cell still rounds UP - that part is load-bearing, and dropping it
## cost PEAK LOSS +13.40 -> +27.80 in one measurement - but it rounds up onto a
## QUARTER of its ring's step: 1 m at ring 0 and 4 m at ring 2. The upward bias
## that buys a summit its height back off a filtered pyramid is kept; what goes
## is the OVERSHOOT, from up to a whole step down to at most a quarter of one.
## The summit gets four treads where it had one slab, and a lone crest cell is
## lifted 4 m rather than 16, which is no longer a needle.
##
## THE POWER-OF-TWO LADDER SURVIVES because a quarter of a power of two is one:
## the sub-step is 2, 4 and 8 blocks against the rings' 8, 16 and 32, so a ridge
## shelf is still on a grid every other cell's shelf is also on. What it is not
## is on the RING's own grid, which is why the far probe's terrace check now
## reports against the sub-step - see there.
const RIDGE_SUBSTEP := 4

var heightmap: Heightmap = null
var generator: TerrainGenerator = null
var config: WorldgenConfig = null

## Block position the disc is centred on.
var center := Vector2i.ZERO

## SLICED OUTPUT, distance v5 Stage 1, decision 1.
##
## THE UPLOAD IS THE FAR COUNTRY'S BINDING COST (STATUS items 11, 17 and 20):
## `ChunkMesher.arrays_to_mesh` runs on the MAIN THREAD and costs 197 ms at
## `far_ring_div` 4, every rebuild. It cannot be moved off the frame thread -
## RenderingServer wants the main thread - so it is SPLIT instead, and the
## thing it is split along is the frontier sector, which is the one partition
## of the far disc this project already has a name and a function for.
##
## `slice` off is the mesh this file has emitted since terrain v1, in one set
## of four arrays, byte for byte: the far probe, the parity harness and the
## self-test all build that way and their numbers stay comparable across this
## night. `slice` on fills `slices` instead - one set of four arrays per
## sector, in sector order - and leaves `arrays` empty, because the runtime
## path never wants the concatenation and assembling three million vertices to
## throw them away is the cost this stage exists to remove.
##
## NOTHING NUMERIC MOVES. The walk is the same walk in the same order, every
## expression is the same expression, and the only thing that changes is WHICH
## four arrays a quad is appended to and what its index base is. That is what
## lets decision 2's gate be exact rather than approximate: the concatenation
## of the slices is the reference build's own quads, stably partitioned by
## sector.
var slice := false

## THE (RING, SECTOR) KEYS THIS BUILD IS FOR. Horizon v1 Stage 3, grill Q14.
##
## Flat, `[ring, sector, ring, sector, ...]`, because it crosses the
## GDExtension seam and a PackedInt32Array is one marshal where an Array of
## Vector2i is a Variant per entry.
##
## WHY A SUBSET AT ALL. The reach went from 3.2 km to 32, which is four more
## rings, and the frontier moves every time a chunk column lands - so a far
## field that rebuilds the whole disc every time the frontier moves would
## rebuild thirty-eight kilometres of country because the player walked eight
## metres. The Stage 0 baseline already measured that thrashing at the OLD
## reach: seventeen to nineteen rebuilds in a sixty-second sprint, 530 ms
## each, and the sprint probe's `far=0` columns say most of them never even
## finished their upload before the next one superseded them.
##
## So a rebuild is a SET OF KEYS. Rings 0 to 2 follow the frontier as they
## always have; ring r >= 3 is rebuilt only when the player has left the
## quarter-radius its last build was centred on (`far_ring_recenter_frac`).
## Walking a hundred metres touches rings 0 and 1 and nothing else.
##
## EMPTY MEANS EVERYTHING, in one mesh, exactly as this file has emitted since
## terrain v1 - which is what the far probe, the parity harness and the
## self-test build, and why their numbers stay comparable across this night.
var keys := PackedInt32Array()

## One `[verts, normals, colors, indices]` per frontier sector in sector order
## (`slice`), or one per KEY in key order (`keys`). Empty unless one of the two
## is set.
var slices: Array = []

## One world anchor per key, in key order, in METRES. Empty unless `keys` is
## set.
##
## THE VERTICES OF A KEYED BUILD ARE RELATIVE TO THIS. A ring snaps its centre
## to its own grid, so all sixteen sectors of a ring share one anchor and a
## vertex is at most the ring's outer radius from it - 38 km at ring 8, which
## is a float with 4 mm of resolution, and 4 mm at 38 km is what Stage 6's
## floating origin exists to keep. `FarField` puts the anchor on the node and
## Stage 6 subtracts the origin from it there; nothing in this file knows about
## an origin.
var key_anchors: PackedVector3Array = PackedVector3Array()

## Ring -> the first index in `keys` for it, or -1. Built once per run.
var _key_ring_first := PackedInt32Array()

## (ring * FRONTIER_SECTORS + sector) -> the sink index, or -1.
var _key_slot := PackedInt32Array()

## The ring's anchor in metres, subtracted from every vertex of a keyed build.
var _anchor_x := 0.0
var _anchor_z := 0.0

var arrays: Array = []
var vertex_count := 0

## How long run() took, in milliseconds. DISTANCE V1 STAGE 0: the cost of a
## rebuild is about to be changed by four stages in a row, and a number that is
## only visible in a profiler is a number nobody watches. Measured inside the
## job rather than around the task, so it is the work and not the queue.
var elapsed_ms := 0

## Distance from the player, in blocks, at which the voxels stop and this mesh
## takes over. Set by run() and read by _corner_y(); a member rather than
## another parameter threaded through three functions that all already have
## six.
var _seam_radius := 0.0

## The ring currently being built, snapped to its own grid, in blocks. The mip
## level is a function of the distance from HERE - the same snapped centre the
## ring's vertices are laid out from, so the level of a given world position is
## stable under exactly the snapping that already stops the mesh shimmering.
var _ring_cx := 0
var _ring_cz := 0

## The material pyramid level the ring currently being built paints from - see
## `material_level`, and `_build_ring` which sets it.
var _mat_level := 0

## `far_forest_blend` and the canopy colour it blends towards, read once per
## job like every other knob the ring loop reads.
var _forest_blend := 0.0
var _canopy := Color(0.0284, 0.0782, 0.0482)

## 1 / ln(2). GDScript has log() and no log2().
const INV_LN2 := 1.4426950408889634

## HOW FAR THE PER-SECTOR HOLE SITS INSIDE THE FRONTIER, in far-field cells.
##
## The plan says two, which is what the single-radius hole always used. Two is
## not enough once the hole follows the frontier, and the reason is REBUILD
## LATENCY: the frontier moves the moment a column lands or the centre shifts,
## but the mesh that expresses it is built on a worker over a frame or two. At
## 13 m/s the player covers most of a chunk in that window, so a hole cut to
## the frontier of two frames ago is a hole. Measured: at two cells the stream
## probe saw 17 hole samples over a 480 m sprint; at four it sees none.
##
## Four cells is 32 blocks, 16 m of overlap between far mesh and voxels. The
## overlap is invisible - the far mesh sits half a detail_amp below the voxel
## surface and the voxels are drawn over it - whereas a gap is a hole in the
## world. Hard rule S1: never a hole, at any speed.
## NOT A CONST SINCE DISTANCE V3 STAGE 7, and the name is deliberate.
##
## `world.gd` reads `FarFieldJob.FRONTIER_OVERLAP_CELLS` to decide whether a
## column is covered by the far mesh, and the note below records what happens
## when the job and that function disagree: the stream probe reports holes that
## are not there. So the overlap has to be ONE number that both read, and
## distance v3 needs it to move with a knob.
##
## A `static var` with the same name does both. `FarField.apply_overdraw()`
## sets it from `far_overdraw` on the MAIN thread before any job is submitted -
## never from a worker - and `world.gd` keeps reading it by the same name,
## unchanged, in step by construction.
static var FRONTIER_OVERLAP_CELLS := 8

## HOW FAR THE FAR MESH SINKS BELOW THE VOXEL SURFACE INSIDE THE FRONTIER, in
## blocks, ramped over the seam band. Distance v3 Stage 7.
##
## Overdraw means the far mesh is now drawn UNDER the voxels rather than
## stopping short of them, and inside the seam band `_corner_y()` deliberately
## computes the voxel surface itself: `coarse + detail + half a block`. The
## voxel you stand on has its top face at `floor(coarse + detail) + 1`, so the
## far mesh sits `0.5 - frac(...)` above it - **half the time it pokes
## through**, by up to a quarter of a metre, and what you would see is patches
## of far-field colour lying over the near ground.
##
## Three blocks is `detail_amp`, which is the amplitude of the only thing the
## far mesh does not know about the voxel surface, and six times the worst
## poke-through. Under the voxels it is invisible. Where the voxels have NOT
## arrived it is the whole point: what shows through a hole in the world is
## then ground drawn a metre and a half low, rather than sky. Hard rule 2 does
## not trade.
const SEAM_SINK_BLOCKS := 3.0

## IT WAS BRIEFLY 12 WHILE TERRACING, AND THAT WAS TWO MISTAKES IN ONE LINE.
## Distance v2 Stage 8, reverted while merging to main. Kept as a comment
## because the second mistake is one this file's neighbour already warns about
## and it was made anyway.
##
## Terracing makes a rebuild 12% slower, so the hole cut to the frontier
## captured at submit time lags further behind a sprinting player, and an
## interleaved ABAB found one hole sample in three terraced runs. Four more
## cells of overlap looked like the fix.
##
##   1. RAISING THIS CONSTANT BREAKS HARD RULE 1. It is not gated on
##      far_terrace, so it moves the far mesh's inner edge at every value of the
##      knob: 103,608 vertices at far_terrace 0.0 became 104,808. The far probe
##      cannot see it - it builds FarFieldJob with an EMPTY frontier, so
##      _sector_exclude is never filled and this constant is dead code to it -
##      so seven stages of "identical on every geometry row" said nothing about
##      the one thing that had changed.
##   2. ADDING THE EXTRA ONLY WHILE TERRACING BREAKS THE PROBE INSTEAD, and
##      world.gd's far_field_exclusion_m() says so in as many words: "keeping a
##      second copy of it here is how the probe came to report 21 holes that
##      were not there: the job had widened its overlap and this had not."
##      world.gd reads THIS constant to decide whether a column is covered, so
##      the job and that function must cut the hole with the same number or the
##      stream probe's hole count is fiction. Measured: two hole samples in one
##      run with the two out of step, and both of them false.
##
## So it stays at 8, for both settings, and whether terracing costs a real hole
## is measured at a MATCHED overlap in docs/status/distance-v2.md rather than
## papered over with a number that made the instrument lie.

## THE FRONTIER, one radius in CHUNKS per angular sector (world feel v1 Stage
## 3). The far mesh cuts its hole only where the voxels have actually arrived,
## which is what makes "never a hole" true by construction rather than by
## being fast enough. Empty falls back to the old single radius.
var frontier := PackedInt32Array()

## frontier, converted to blocks with the overlap already taken off. Built once
## per job in run().
var _sector_exclude := PackedFloat32Array()

# --- THE TERRACE, distance v2 Stages 1 and 2 ---------------------------------
#
# THE FAR WORLD IS MADE OF BLOCKS TOO, JUST BIGGER BLOCKS THE FURTHER AWAY YOU
# GO. A near tree is a staircase of leaf voxels and near terrain is cubes; the
# far field was built to match their SILHOUETTE and never their SURFACE, which
# is what Marcel could feel and could not name - "one is a cube based game, and
# the other one is just sort of an edge based vector game".
#
# So: one height per cell, quantised to that ring's own cell width, and the
# difference to a lower neighbour drawn as a vertical riser. Ring 0's cells are
# 4 m, ring 1's are 8 and ring 2's are 16, and the STEP HEIGHT EQUALS THE CELL
# WIDTH - decision 4, the cubic lock. A shelf wider than it is tall is a rice
# terrace, not a block.
#
# THE HEIGHTS ARE POWERS OF TWO AND THAT IS LOAD-BEARING. Every 16 m shelf is
# also an 8 m shelf and a 4 m one, so the coarse levels are a SUBSET of the fine
# ones - the same property _build_ring already relies on for its XZ grids,
# extended to Y. Crossing a ring boundary therefore SUBDIVIDES a mountain's
# shelves instead of moving them: nothing that was drawn goes away, intermediate
# shelves appear between the ones already there. Stage 9 measures whether that
# removed the 400 m re-cut on its own.
#
# THERE IS NO PLAYER TERM IN THE QUANTISATION. `round(h / step) * step`, on the
# world's own altitudes, exactly as _build_ring already snaps its XZ centre to
# the ring's grid and for exactly the same reason - "so its vertices land on the
# same world positions every rebuild and the mesh does not shimmer as the player
# walks". A shelf at 112 m is at 112 m from every vantage, on every rebuild, in
# every ring. Get this wrong and the terraces swim, which is the failure
# distance v1 already learned once with the mip level.
#
# AND AT far_terrace 0.0 NOTHING BELOW RUNS AT ALL. Not the cache, not a single
# extra _filtered() call, not one riser. Hard rule 1: 0.0 is the mesh f23c3f0
# drew, byte for byte, and it is the way back.

## config.far_terrace, read once per job. 0 disables every line below.
var _t_amount := 0.0

## The ring being built, for the cell cache: its step and seam band in blocks.
var _t_step := 0
var _t_band := 0.0

## config.far_step_y_blocks, read once per job like far_terrace. 0 keeps the
## cubic lock (each ring quantises to its own cell width); above it the height
## quantises to this many BLOCKS whatever the cell width, so the far country
## keeps full vertical resolution on the block lattice.
var _t_step_y := 0.0

## THE PYRAMID LEVEL THE TERRACE IS CUT FROM. One level for the WHOLE JOB, and
## both halves of that sentence were bought with a measurement. Distance v2
## Stage 1.
##
## WHY NOT `_filtered()`, WHICH IS WHAT THE SMOOTH MESH DRAWS. That expression
## has no player term in it, which is what hard rule 2 asks for on its face. Its
## INPUT does: `_level_at` is log2(distance from the player), so the height
## being quantised breathes as you walk, and quantising a breathing number turns
## a half-block breath into a WHOLE STEP jump. Measured on ganymede at seed 42:
## over a 200 m walk the drawn far height moved by rms 9.8-13.6 blocks and up to
## 96, against 0.4 for the smooth mesh. The terraces swam exactly as the rule
## warns, and the rule's letter was satisfied throughout.
##
## WHY NOT ONE LEVEL PER RING, WHICH FIXES THAT. It does - within a ring `hq`
## becomes a pure function of world position and the fizz past 500 m falls to
## EXACTLY zero. But it breaks the property the whole plan leans on:
##
##     every 16 m shelf is also an 8 m shelf, so crossing 400 m makes a
##     mountain's shelves SUBDIVIDE rather than move
##
## which is only true if the two rings quantise THE SAME height function. With a
## level per ring they do not, and the 400 m boundary measured 144 blocks of
## fizz against f23c3f0's 21.6. Recorded in docs/status/distance-v2.md; it is
## the most useful wrong turn in this epic.
##
## So: one level, for every ring, chosen by TERRACE_LEVEL_RING below.
##
##     level = log2(that ring's step / heightmap step) + far_filter_bias
##
## `hq` is then a pure function of world position full stop - the same number in
## every ring, on every rebuild, from every vantage - and the three rings
## quantise it at 8, 16 and 32 blocks, which are powers of two of each other by
## construction. That is the subset property, exactly as written.
var _t_level := 0.0

# --- THE GEOMORPH, distance v5 Stage 3 ---------------------------------------
#
# STATUS ITEMS 9 AND 18, AND THE FIX THEY THEMSELVES WROTE DOWN. Distance v2
# Stage 9 measured why a ring boundary is loud, and it is not the step ladder:
#
#     f23c3f0, smooth                                        21.57 blocks
#     shipped: each ring quantises at its own step            80.00
#     every ring at the SAME STEP, its own sample point       96.00 - worse
#     every ring at the SAME SAMPLE POINT, its own step       16.00 - gone
#
# Two rings sample a cell's height at DIFFERENT WORLD POINTS - the fine ring at
# the centre of its own cell, the coarse ring at the centre of the coarser cell
# containing it, up to half a coarse cell apart. On a flank that is tens of
# blocks of height before anything is quantised, and the player walking past the
# boundary sees the ground jump by exactly that.
#
# So the fix has a smaller job than "blend two surfaces": blend the SAMPLE
# POSITION. Over the last `far_geomorph_cells` cells before a ring's outer
# boundary, the cell-height sample slides from this ring's cell centre to the
# centre of the coarse ring's cell that contains it, and at the boundary the two
# rings are reading the same point - which is the third row of that table, made
# local instead of global. The third row was never shipped because sharing a
# sample point EVERYWHERE means 16 m blocks at every range, which is the
# opposite of the whole idea; sharing it only where two rings meet costs the
# last two cells of each ring their independence and nothing else.
#
# WHAT IT DOES NOT TOUCH: the quantisation step, the ridge test, the corner
# heights, the terrace fade, the seam band. One position, blended.

## The ring's outer radius in blocks, and the width of the blend in blocks.
## `_t_geo` is 0 when this ring has no coarser neighbour to hand over to - the
## outermost ring, or a ring whose outer edge is the fog rather than a boundary.
var _t_outer := 0.0
var _t_geo := 0.0

## The fog radius, in blocks. Read in _build_ring to decide whether a ring's
## outer edge is a handover or the end of the world.
var _far_radius := 0.0

## The tile view this build reads - see `run()`.
var _view := {}

# --- THE DETAIL LAYER, distance v5 Stage 6 -----------------------------------
#
# WHAT THE PYRAMID CANNOT KNOW. The far mesh reads a filtered height map, so
# everything finer than its level is gone by construction - that is what a mip
# level IS. Distance v5 Stage 5 was meant to buy that information back by
# doubling the height map's resolution and could not afford it (see the status
# doc), so this is the other half of the same idea: put the GRAIN back
# analytically where there is no data, and only where there is no data.
#
# THREE RULES, and each is a way this goes wrong without it:
#
#   1. WORLD SPACE. The sample position is the cell's own - the SAME position,
#      geomorph and all, that the height was read at. So two rings meeting at a
#      boundary read the same detail for the same reason they read the same
#      height, and Stage 3's fix carries this layer across for free. A layer
#      keyed to the ring, the step or the level would put the ring boundary
#      back and undo the stage before it.
#   2. FAR RINGS ONLY. Ring 0 is the seam band, where the far mesh is blending
#      onto the actual voxel surface and there is nothing to invent - inventing
#      there is a step exactly where distance v3 Stage 7 spent a stage removing
#      one.
#   3. LOOK ONLY. It is added to the CELL height the far mesh draws and to
#      nothing else. The pyramid is not written, `heightmap.cells` is not
#      touched, and spawn, lakes and the voxel surface read the same functions
#      they read yesterday. Hard rule 8.
#
# THE NOISE IS THE VOXEL WORLD'S OWN. `TerrainGenerator._detail` is the field
# the near ground's roughness comes from, and the far mesher already holds it
# for the seam band. Using it here means the far country's grain is the grain
# you walk on when you get there, rather than a second invented texture that
# has to be kept in step with the first - and it costs no new marshalling and
# no new parity risk, because it is an engine object sampled natively on both
# sides of the seam.
#
# WHAT IT DOES NOT DO: it rides the CELL height, which is the terraced path, so
# at `far_terrace` 0 there is no cell and this layer is absent. That is hard
# rule 1 rather than an oversight - far_terrace 0 is the smooth mesh this
# project shipped, and adding grain to it would make the way back not the way
# back.
var _t_detail := 0.0

## THE CELL CACHE, one entry per cell of the ring currently being built.
##
## A cell needs its own quantised height and its four neighbours', so the naive
## form costs five extra pyramid reads per quad on a job whose whole cost is
## pyramid reads. Cached, each cell is computed once however many neighbours ask
## for it, which brings the extra back to about one read per quad.
##
## _t_h is the raw filtered height at the cell CENTRE and is separate from _t_hq
## on purpose: Stage 4's ridge test reads the four neighbours' RAW heights, and
## a cache that only held quantised ones would have to recurse to answer it.
##
## NAN means "not computed yet". Indexed (i + _t_off) + (j + _t_off) * _t_w over
## i, j in [-span-1, span] - one cell of margin, because the outermost quad in
## the loop still asks about a neighbour outside it.
var _t_h := PackedFloat32Array()
var _t_hq := PackedFloat32Array()
var _t_t := PackedFloat32Array()
var _t_off := 0
var _t_w := 0

## RIDGE_SPAN_BLOCKS in this ring's own cells, at least one.
var _t_ridge := 1

## TRUE WHEN EVERY CELL OF THIS RING IS TERRACED ALL THE WAY - far_terrace 1.0
## and no seam band, which is rings 1 and 2 at the shipped value.
##
## It is a COST path, and it makes terracing cheaper than not terracing rather
## than dearer. A fully terraced cell's four corners are all the same number, so
## the four bilinear corner samples that produced them are not needed at all:
## one cached centre sample replaces four pyramid reads, and the riser depths
## are the difference of two quantised heights with the raw samples cancelling
## out of the arithmetic. Ring 0 always has a seam band and always pays full
## price, which is right - it is also the ring that is barely terraced.
var _t_full := false
## The band the treeline falls in, read once per job from the generator's own
## zone thresholds rather than re-derived - the bands have to agree with where
## the forest actually stops or the backdrop contradicts the world in front of
## it. -1 until run() computes it.


func run() -> void:
	var _t0 := Time.get_ticks_msec()
	# THE TILE VIEW THIS BUILD READS, captured once - see `Heightmap.far_view`.
	# Held for the whole run so a `publish_far_view` landing on another thread
	# cannot change what this build can see half way through it. That race is
	# what made the far parity gate report a vertex count that VARIED BETWEEN
	# RUNS: a `FarField` on a worker was publishing a new view in the middle of
	# the parity harness's own hand-built job.
	_view = heightmap.far_view()
	# THE PYRAMID IS BUILT ON FIRST USE, and this is the first use. Idempotent
	# and behind a mutex, so the cost lands once, on this worker, inside this
	# job's elapsed_ms - which is where it is visible rather than hidden in a
	# startup total.
	heightmap.build_pyramid()
	var bs: float = config.block_size
	var base_step := base_step_blocks(config)
	var far_radius := config.fog_end_m / bs * FOG_MARGIN
	_far_radius = far_radius
	# DISTANCE V2 STAGE 0. Read once per job rather than per quad: it is a knob
	# on a shared config that the main thread can write while this worker runs,
	# and a value that changed half way through a build would terrace half a
	# mesh.
	_t_amount = clampf(config.far_terrace, 0.0, 1.0)
	# THE VERTICAL STEP IS ITS OWN KNOB SINCE 2026-08-31 - Marcel's ruling on
	# the distance look: flat cell tops stay, the shelf goes. Read once per job
	# for the same reason far_terrace is.
	_t_step_y = maxf(config.far_step_y_blocks, 0.0)
	_forest_blend = clampf(config.far_forest_blend, 0.0, 1.0)
	_canopy = canopy_color()
	# ONE LEVEL FOR THE WHOLE JOB - see _t_level. heightmap.step is 4 blocks, so
	# at the default far_step of 8 the three rings' cells are 8, 16 and 32 blocks
	# and this picks 32: log2(32/4) + far_filter_bias = 4.
	_t_level = clampf(log(float(base_step
		* RING_STEP_MULTIPLE[clampi(TERRACE_LEVEL_RING, 0, RING_STEP_MULTIPLE.size() - 1)])
		/ float(heightmap.step)) * INV_LN2 + config.far_filter_bias,
		0.0, float(Heightmap.MAX_LEVEL))

	# Where the voxels take over. Quads well inside this are skipped - the
	# voxel terrain is drawn there instead, and drawing both is overdraw.
	# The margin means the two OVERLAP by two cells rather than meeting
	# exactly: a small overlap is hidden by the voxels, whereas a small gap is
	# a hole you can see the sky through.
	var voxel_radius_blocks: float = float(config.voxel_radius_chunks * Chunk.SIZE)
	# THE SEAM AND THE HOLE ARE TWO DIFFERENT RADII SINCE DISTANCE V3 STAGE 7,
	# and they used to be the same number.
	#
	# `_seam_radius` is where the far mesh is meant to AGREE with the voxels -
	# the nominal voxel edge, which is what `_corner_y`, `_level_at` and
	# `_terrace_at` all measure their fades from, and it must not move or the
	# terrace would fade in somewhere else. `exclude` is where the far mesh
	# stops DRAWING, and overdraw pushes that inward, under the voxels.
	_seam_radius = maxf(voxel_radius_blocks - float(2 * base_step), 0.0)
	var exclude := maxf(
		voxel_radius_blocks - float(FRONTIER_OVERLAP_CELLS * base_step), 0.0)
	# Per sector, the same two-cell overlap subtracted from the frontier rather
	# than from the nominal radius. A sector whose voxels are still coming keeps
	# its far mesh all the way in.
	_sector_exclude = PackedFloat32Array()
	if not frontier.is_empty():
		_sector_exclude.resize(frontier.size())
		for i in frontier.size():
			_sector_exclude[i] = maxf(
				float(frontier[i] * Chunk.SIZE)
					- float(FRONTIER_OVERLAP_CELLS * base_step), 0.0)

	# The far mesh is the COARSE heightmap; the voxels are that plus per-block
	# detail, so at the boundary the two differ by up to detail_amp. Dropping
	# the far mesh by half of that keeps it under the voxel surface through the
	# overlap instead of poking up through it.
	var y_offset := -0.5 * config.detail_amp * bs

	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()

	# THE SINKS, one per sector - see `slice`. Allocated here rather than in
	# _build_ring because a sector spans every ring, which is the whole point:
	# a slice is a wedge of the whole disc, so uploading one lands a complete
	# piece of far country from the seam to the fog rather than a complete
	# inner ring and nothing beyond it.
	slices = []
	key_anchors = PackedVector3Array()
	# THE KEYED PATH'S SINKS, one per (ring, sector) asked for, in key order,
	# plus the lookup the ring loop dispatches through. See `keys`.
	var keyed := _setup_keys()
	if not keyed and slice:
		for s in World.FRONTIER_SECTORS:
			slices.append([PackedVector3Array(), PackedVector3Array(),
				PackedColorArray(), PackedInt32Array()])

	var inner := exclude
	for ring in RING_STEP_MULTIPLE.size():
		var step: int = base_step * RING_STEP_MULTIPLE[ring]
		var outer := far_radius
		if ring < RING_OUTER_M.size():
			outer = minf(RING_OUTER_M[ring] / bs, far_radius)
		if outer <= inner:
			# The whole ring is inside the voxel radius, or past the fog. At
			# the Low preset the 400 m ring is the second of those and the
			# outermost ring never starts at all.
			inner = maxf(inner, outer)
			continue
		# A RING NOBODY ASKED FOR IS NOT WALKED AT ALL. `inner` still advances,
		# because the next ring starts where this one would have ended - the
		# ladder is a property of the table, not of what happened to be built.
		if keyed and _key_ring_first[ring] < 0:
			inner = outer
			continue
		_build_ring(ring, step, inner, outer, y_offset, verts, normals, colors, indices)
		inner = outer

	if keyed:
		vertex_count = 0
		var kout := []
		for sink in slices:
			vertex_count += sink[0].size()
			kout.append(_sink_arrays(sink))
		slices = kout
		arrays = []
		elapsed_ms = Time.get_ticks_msec() - _t0
		return

	# THE SLICED PATH ENDS HERE. `arrays` stays empty and `vertex_count` is the
	# sum over the sectors - the same number the whole-mesh path reports,
	# because it is the same quads.
	if slice:
		vertex_count = 0
		var out := []
		for sink in slices:
			vertex_count += sink[0].size()
			# EACH SLICE AS MESH ARRAYS, the same shape the C++ mesher hands
			# back and the shape `add_surface_from_arrays` takes. No copy: the
			# four packed arrays are moved into the ARRAY_MAX-sized Array the
			# renderer wants, and an empty sector emits an empty Array rather
			# than a surface with nothing in it.
			out.append(_sink_arrays(sink))
		slices = out
		arrays = []
		elapsed_ms = Time.get_ticks_msec() - _t0
		return

	vertex_count = verts.size()
	if verts.is_empty():
		arrays = []
		elapsed_ms = Time.get_ticks_msec() - _t0
		return

	arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	elapsed_ms = Time.get_ticks_msec() - _t0


## One sink's four packed arrays as the mesh arrays Godot takes. An empty sink
## emits an empty Array rather than a surface with nothing in it.
func _sink_arrays(sink: Array) -> Array:
	if (sink[0] as PackedVector3Array).is_empty():
		return []
	var a := []
	a.resize(Mesh.ARRAY_MAX)
	a[Mesh.ARRAY_VERTEX] = sink[0]
	a[Mesh.ARRAY_NORMAL] = sink[1]
	a[Mesh.ARRAY_COLOR] = sink[2]
	a[Mesh.ARRAY_INDEX] = sink[3]
	return a


## Allocate one sink per key and the two lookups the ring loop dispatches
## through. Returns whether this is a keyed build at all.
func _setup_keys() -> bool:
	_key_ring_first = PackedInt32Array()
	_key_slot = PackedInt32Array()
	if keys.is_empty():
		return false
	var rings := RING_STEP_MULTIPLE.size()
	var sectors := World.FRONTIER_SECTORS
	_key_ring_first.resize(rings)
	_key_ring_first.fill(-1)
	_key_slot.resize(rings * sectors)
	_key_slot.fill(-1)
	var n := keys.size() / 2
	for i in n:
		var r := keys[i * 2]
		var sec := keys[i * 2 + 1]
		# ONE SINK PER KEY, ALWAYS, valid or not: `slices[i]` has to be the
		# arrays for `keys[2i]` whatever the key says, or the caller's mapping
		# from key to mesh slips by one the first time a bad key arrives.
		slices.append([PackedVector3Array(), PackedVector3Array(),
			PackedColorArray(), PackedInt32Array()])
		if r < 0 or r >= rings or sec < 0 or sec >= sectors:
			continue
		_key_slot[r * sectors + sec] = i
		if _key_ring_first[r] < 0:
			_key_ring_first[r] = i
	key_anchors.resize(n)
	return true


## One annulus of the disc, at one resolution.
##
## `inner` and `outer` are radii in BLOCKS from the player, and membership is
## decided by the QUAD CENTRE. Deciding by centre rather than by corner is what
## makes the skirt test below correct: a quad and its neighbour are in the same
## ring exactly when their two centres both pass the same test, so asking about
## the neighbour's centre answers "is there a quad over there" without having
## to have built it yet.
func _build_ring(ring: int, step: int, inner: float, outer: float, y_offset: float,
		verts: PackedVector3Array, normals: PackedVector3Array,
		colors: PackedColorArray, indices: PackedInt32Array) -> void:
	var bs: float = config.block_size

	# Snap the centre to THIS RING'S grid, so its vertices land on the same
	# world positions every rebuild and the mesh does not shimmer as the player
	# walks. Each ring snaps to its own step, which is also what keeps the
	# coarse rings' vertices a subset of the fine rings' - the property the
	# skirts only have to cover the gaps between.
	var cx := int(floor(float(center.x) / float(step))) * step
	var cz := int(floor(float(center.y) / float(step))) * step
	_ring_cx = cx
	_ring_cz = cz
	# THE MATERIAL PYRAMID LEVEL THIS RING PAINTS FROM, horizon v1 Stage 4:
	# the level whose cell is this ring's cell. Once per ring rather than once
	# per quad, because it is a property of the ring.
	_mat_level = material_level(heightmap, step)
	# THE RING'S ANCHOR, and every vertex of a keyed build is relative to it.
	#
	# All sixteen sectors of a ring share it, because they share the snapped
	# centre - so a key's mesh sits at its ring's anchor and its vertices reach
	# at most the ring's outer radius from there. At ring 8 that is 38 km, and
	# a float has 4 mm at 38 km, which is the resolution Stage 6's floating
	# origin exists to keep. Zero on the whole-disc path, so the probe, the
	# parity harness and the self-test still read world positions out of
	# `arrays` exactly as they always have.
	var keyed := not _key_slot.is_empty()
	_anchor_x = float(cx) * bs if keyed else 0.0
	_anchor_z = float(cz) * bs if keyed else 0.0
	if keyed:
		var first := _key_ring_first[ring]
		if first >= 0:
			for i in range(first, keys.size() / 2):
				if keys[i * 2] == ring:
					key_anchors[i] = Vector3(_anchor_x, 0.0, _anchor_z)

	var span := int(ceil(outer / float(step))) + 1
	# A RING-BOUNDARY SKIRT GROWS WITH THE TERRACE. One cell of drop covers any
	# mismatch a smooth heightmap can produce across one cell; a terraced one can
	# also disagree with its coarser neighbour by most of a step. Costs nothing -
	# "a skirt that is too long is buried in the hillside, a skirt that is too
	# short is a hole in the horizon" - and is exactly the old length at 0.
	var skirt_drop := float(step) * (SKIRT_DEPTH_CELLS + _t_amount) * bs

	# Only the innermost ring touches the voxels, so only it pays for the
	# detail samples. A band of zero switches _corner_y() back to the plain
	# coarse height with one comparison.
	var band := float(step) * SEAM_BAND_CELLS if ring == 0 else 0.0

	# THE CELL CACHE FOR THIS RING. Allocated per ring rather than per job
	# because every index in it is in the ring's own cell units, and skipped
	# entirely at far_terrace 0 - hard rule 1 is also a cost rule.
	_t_step = step
	_t_band = band
	# THE GEOMORPH'S BAND FOR THIS RING - see the note by _t_geo. Only where
	# there is a coarser ring on the other side of this boundary: the outermost
	# ring hands over to nothing, and a ring whose outer edge is the fog rather
	# than a ring boundary has nothing to agree with either.
	_t_outer = outer
	_t_geo = 0.0
	if ring < RING_STEP_MULTIPLE.size() - 1 and outer < _far_radius:
		_t_geo = clampf(config.far_geomorph_cells, 0.0, 8.0) * float(step)
	# Rule 2: far rings only. `band` is non-zero on ring 0 and nowhere else.
	_t_detail = config.far_detail if band <= 0.0 else 0.0
	_t_full = _t_amount >= 1.0 and band <= 0.0
	if _t_amount > 0.0:
		# The margin is the RIDGE reach PLUS ONE, not one cell. A quad asks its
		# four riser neighbours to quantise themselves, and each of those asks
		# its own four ridge neighbours for a raw height - so the outermost quad
		# in the loop reaches ridge + 1 cells past the ring, and at ring 0 that
		# is thirteen.
		_t_ridge = maxi(RIDGE_SPAN_BLOCKS / step, 1)
		_t_off = span + _t_ridge + 1
		_t_w = 2 * _t_off + 1
		var cells := _t_w * _t_w
		_t_h.resize(cells)
		_t_h.fill(NAN)
		_t_hq.resize(cells)
		_t_hq.fill(NAN)
		_t_t.resize(cells)
		_t_t.fill(0.0)

	for j in range(-span, span):
		for i in range(-span, span):
			var bx0 := cx + i * step
			var bz0 := cz + j * step
			if not _in_ring(bx0, bz0, step, inner, outer):
				continue
			# THE LAST EDGE, AND IT IS GONE. Horizon v1 Stage 3, D44.
			#
			# `if not heightmap.in_bounds(bx0, bz0): continue` stood here since
			# terrain v1 and was the reason the far country stopped at the
			# region however far the rings reached: Stage 3 can add four rings
			# to 38 km and this line would still have drawn nothing past 3.
			# The height comes from the tile store now (Stage 1) and the tiles
			# the rings need are prepared before the build (`FarField.
			# _prepare_tiles`), so there is ground to draw everywhere the ring
			# asks and nothing left to cull against.

			var bx1 := bx0 + step
			var bz1 := bz0 + step

			# WHICH SLICE THIS CELL'S QUADS GO IN. The cell's own sector, taken
			# from its CENTRE by the same function _in_ring cuts the per-sector
			# hole with - so a cell, its risers and its skirts land together and
			# a slice is a wedge with no seams of its own inside it. One atan2
			# per cell, and only when slicing.
			var w_verts := verts
			var w_normals := normals
			var w_colors := colors
			var w_indices := indices
			if keyed:
				# THE KEY'S OWN SINK, or nothing: a ring being rebuilt for two
				# of its sixteen sectors walks all its cells - the ring test
				# is a subtraction and a compare - and emits only the two.
				var slot := _key_slot[ring * World.FRONTIER_SECTORS
					+ World.frontier_sector_of(bx0 + step / 2 - center.x,
						bz0 + step / 2 - center.y)]
				if slot < 0:
					continue
				var ksink: Array = slices[slot]
				w_verts = ksink[0]
				w_normals = ksink[1]
				w_colors = ksink[2]
				w_indices = ksink[3]
			elif slice:
				var sink: Array = slices[World.frontier_sector_of(
					bx0 + step / 2 - center.x, bz0 + step / 2 - center.y)]
				w_verts = sink[0]
				w_normals = sink[1]
				w_colors = sink[2]
				w_indices = sink[3]

			# THE TERRACE, Stage 2. One height for the whole cell, quantised to
			# the ring's step, blended in from the true bilinear corners by
			# far_terrace. At 1.0 all four corners are the same number and the
			# top quad is FLAT - which is a block's top face, at sixteen metres
			# instead of half of one, in the same winding _build_ring has emitted
			# since terrain v1.
			#
			# The raw corner heights are kept on the blended path because the
			# risers need them: a riser's depth is the gap between MY blended
			# corner and my neighbour's blended corner at the same world
			# position, and the two blends start from the same raw sample. On the
			# fully-terraced path they cancel out of that subtraction and the
			# four samples are never taken - see _t_full.
			var h00: float
			var h10: float
			var h11: float
			var h01: float
			var r00 := 0.0
			var r10 := 0.0
			var r11 := 0.0
			var r01 := 0.0
			var terr := 0.0
			var hq := 0.0
			# THE UNQUANTISED HEIGHT, kept for the ZONE. See the note on
			# zone_h below: what a cell is MADE of must not depend on which
			# shelf it landed on.
			var mid_true := 0.0
			if _t_full:
				var at := _cell(i, j)
				hq = _t_hq[at]
				mid_true = _cell_h(i, j)
				terr = 1.0
				h00 = hq
				h10 = hq
				h11 = hq
				h01 = hq
			else:
				h00 = _filtered(bx0, bz0, band)
				h10 = _filtered(bx1, bz0, band)
				h11 = _filtered(bx1, bz1, band)
				h01 = _filtered(bx0, bz1, band)
				r00 = h00
				r10 = h10
				r11 = h11
				r01 = h01
				mid_true = (h00 + h10 + h11 + h01) * 0.25
				if _t_amount > 0.0:
					var at := _cell(i, j)
					terr = _t_t[at]
					hq = _t_hq[at]
					if terr > 0.0:
						h00 = lerpf(h00, hq, terr)
						h10 = lerpf(h10, hq, terr)
						h11 = lerpf(h11, hq, terr)
						h01 = lerpf(h01, hq, terr)

			# Corner order is the +Y face order from ChunkMesher, which is
			# clockwise seen from above - the same winding the voxels use, so
			# both are lit and culled identically.
			# ANCHOR-RELATIVE ON THE KEYED PATH, world on the whole-disc one -
			# see `_anchor_x`. Y is never anchored: the origin offset is a
			# horizontal thing (Stage 6) and an altitude is small anyway.
			var x0 := float(bx0) * bs - _anchor_x
			var x1 := float(bx1) * bs - _anchor_x
			var z0 := float(bz0) * bs - _anchor_z
			var z1 := float(bz1) * bs - _anchor_z
			var p0 := Vector3(x0, _corner_y(bx0, bz0, h00, band, y_offset), z0)
			var p1 := Vector3(x1, _corner_y(bx1, bz0, h10, band, y_offset), z0)
			var p2 := Vector3(x1, _corner_y(bx1, bz1, h11, band, y_offset), z1)
			var p3 := Vector3(x0, _corner_y(bx0, bz1, h01, band, y_offset), z1)

			# THE COLOUR IS A LOOKUP NOW, horizon v1 Stage 4.
			#
			# WHAT THIS REPLACES, because the deletion is the change. Until
			# tonight this block re-derived a zone at every quad: the altitude
			# it had just drawn, run through `surface_zone_at`'s dither at ring
			# 0 and through `backdrop_zone`'s fixed 0.5 dither past it, sampled
			# on a zone cell that grew with distance (`far_zone_cell_m`,
			# `far_zone_cell_ratio`), with distance v3's four-sample majority
			# vote bolted on to stop the result fizzing. Five mechanisms, four
			# knobs, and none of them the rule the voxels use.
			#
			# The material pyramid answers all of it in one read. The cell's
			# material IS the mode of the materials under it, computed once
			# when the pyramid or the tile was built, from `surface_zone_at`
			# itself at level 0 - so the far country and the ground agree by
			# construction rather than by two rules kept in step by hand, it
			# cannot fizz because nothing is resampled per frame, and the
			# colour of a 512 m cell is the commonest thing actually in it.
			var qbx := float(bx0 + step / 2)
			var qbz := float(bz0 + step / 2)
			var mat := heightmap.far_material_at(qbx, qbz, _mat_level, _view)
			var color := Block.color_of(TerrainGenerator.ZONE_SURFACE[mat])
			# AND THE FOREST OVER IT. A far cell that is meadow with trees on
			# it is not meadow-coloured: the canopy is what the eye sees. So
			# the cell's colour is pulled towards the species canopy mid by the
			# cover, at `far_forest_blend` of full - the plan's 0.7 - which is
			# what stops a forested flank at 10 km reading as the ground under
			# it. Never at ring 0, where the real trees are drawn and this
			# would tint the ground under them a second time.
			# AND NEVER ON ROCK OR SNOW. The cover grid is coarser than the
			# material - `Heightmap.COVER_STRIDE` - so a snow cell beside a
			# forest reads the forest's sample and would come out tinted
			# green. `TreePlacement.cover_at` already answers 0 on rock and
			# snow; this is the same statement made where the coarse read
			# could otherwise smear it across a boundary. It was measured, not
			# guessed: the colour handover at the summit vantage failed on
			# snow by 33.5 points of V and on nothing else.
			if _forest_blend > 0.0 and ring > 0 \
					and mat != TerrainGenerator.ZONE_ROCK \
					and mat != TerrainGenerator.ZONE_SNOW:
				var cover := heightmap.far_cover_at(qbx, qbz, _mat_level, _view)
				if cover > 0.0:
					color = color.lerp(_canopy, cover * _forest_blend)

			# THE BACKDROP, look v1. One altitude band per quad - so the band
			# edges are the quad edges, a hard stepped contour rather than a
			# gradient across the quad - and a lighting normal from the slope
			# of the whole flank rather than of this one facet. See the two
			# helpers below.
			var flank := _flank_normal(bx0 + step / 2, bz0 + step / 2)

			_push_quad(p0, p1, p2, p3, color, w_verts, w_normals, w_colors, w_indices, flank)

			# One skirt per edge whose neighbour is not in this ring, and one
			# RISER per edge whose neighbour is in this ring and lower. The four
			# edges are in the same order as the corners, so edge k runs from
			# corner k to corner k+1; the two extra numbers are the neighbour's
			# offset in CELLS, and the two after that are this edge's raw corner
			# heights.
			#
			# A RISER IS A SKIRT WHOSE DEPTH IS THE HEIGHT DIFFERENCE TO THE
			# NEIGHBOUR instead of a fixed drop, which is the whole of Stage 2:
			# the machinery that draws a vertical quad off a cell edge has been
			# here since terrain v1 and only the depth is new. Ring-boundary
			# skirts stay - they cover cracks between rings, which risers do not,
			# and the two coexist.
			var edges := [
				[p0, p1, 0, -step, 0, -1, r00, r10],
				[p1, p2, step, 0, 1, 0, r10, r11],
				[p2, p3, 0, step, 0, 1, r11, r01],
				[p3, p0, -step, 0, -1, 0, r01, r00],
			]
			var shaded := Color(color.r * SKIRT_SHADE, color.g * SKIRT_SHADE,
				color.b * SKIRT_SHADE, color.a)
			# THE RISER IS A SIDE FACE, distance v2 Stage 3, and most of what
			# makes it one is already true before this line.
			#
			# A riser carries its own HORIZONTAL normal - _push_quad derives it
			# from the winding, and only the top quad is given _flank_normal
			# instead. So it goes through Look's three-band ramp exactly as a
			# voxel's side face does (lit, half-lit or in shade by
			# dot(NORMAL, LIGHT)), and through Block.aspect_shade's slope_tint
			# and aspect_tint exactly as a voxel's side face does. That is
			# decision 8's "one lighting language, both halves", and it costs
			# nothing.
			#
			# WHAT IT DOES NOT GIVE IS CONTRAST ON THE SUNLIT FLANK. There, a
			# terrace top (flank normal, tilted sunward) and a riser (horizontal,
			# facing downhill and therefore also sunward) both land in the lit
			# band, so both are drawn at albedo * sun and the steps stop reading
			# as steps at exactly the range where the eye is looking for them.
			# far_riser_shade is the margin that keeps them apart on both flanks,
			# and it is a knob because how much of it is taste.
			# The riser colour is now decided PER EDGE, inside the loop - see
			# the note on far_riser_lift. Only the base is common to the quad.
			for e in edges:
				var nbx: int = bx0 + e[2]
				var nbz: int = bz0 + e[3]
				if not _in_ring(nbx, nbz, step, inner, outer):
					_push_skirt(e[0], e[1], skirt_drop, shaded,
						w_verts, w_normals, w_colors, w_indices)
					continue
				if _t_amount <= 0.0:
					continue
				# THE NEIGHBOUR ALWAYS EXISTS NOW. This was "a neighbour
				# outside the heightmap emitted no quad of its own, so there is
				# no shelf for a riser to stand against" - true while the far
				# mesh had an edge. `_in_ring` above already answered whether
				# there is a quad over there, which is the question a riser
				# actually asks, and the world-edge half of it has no meaning
				# any more.
				var nat := _cell(i + e[4], j + e[5])
				var nt: float = _t_t[nat]
				var nq: float = _t_hq[nat]
				# THE GAP, AT BOTH ENDS OF THE EDGE. Both cells blend from the
				# same raw corner sample, so at far_terrace 0 this is exactly
				# zero at both ends and no riser is emitted at all - and where
				# the terrace is fading in across the seam band (Stage 8) the two
				# ends can differ, which is why the riser is a trapezoid rather
				# than a rectangle.
				# A RISER TAKES ITS TOP'S COLOUR (light v1 Stage 3, Q15).
				#
				# What stood here was the whole of distance v2's black-crush
				# fix, and it is worth recording why it can go. The toon ramp
				# was three flat bands, so on a slope facing fully away from the
				# sun a shelf top and its riser landed in the SAME band and
				# crushed together into one flat black - measured, the far
				# band's dead-black share went from 7.08% to 15.63% with
				# terracing on. The answer was to paint the riser: darken it
				# against a fixed compass direction, lift the away-facing side
				# off the shade floor, dim it across the axis. Four painted
				# tones on a far cube.
				#
				# The ramp is gone. A riser now faces away from the sun and is
				# darker for that reason, continuously, and a shelf top beside
				# it is lit - so there is nothing to crush and nothing to
				# unpaint it with.
				var riser_color := color
				var da: float
				var db: float
				if _t_full:
					da = hq - nq
					db = da
				else:
					var ra: float = e[6]
					var rb: float = e[7]
					da = lerpf(ra, hq, terr) - lerpf(ra, nq, nt)
					db = lerpf(rb, hq, terr) - lerpf(rb, nq, nt)
				if da <= 0.0 and db <= 0.0:
					continue
				_push_riser(e[0], e[1], maxf(da, 0.0) * bs, maxf(db, 0.0) * bs,
					riser_color, w_verts, w_normals, w_colors, w_indices)


# --- WHAT STAGE 4 DELETED ----------------------------------------------------
#
# `_far_zone`, `_zone_vote`, `_vote_memo`, `_vote_level`, `VOTE_SPLIT` and
# `_voting` lived here: distance v1's per-ring dither rule and distance v3's
# four-sample majority vote, about 150 lines between them. Both were ways of
# guessing what a coarse cell is made of from the height the far mesh had just
# drawn. The material pyramid knows, so both are gone - see the block by
# `Heightmap.materials` and the colour lookup in `_build_ring`'s quad loop.
#
# `far_vote`, `far_zone_cell_m` and `far_zone_cell_ratio` are now read by
# nothing. They stay in the config for one more epic so a saved file does not
# lose fields on load, and the F4 panel no longer offers them.


## THE MIP LEVEL AT ONE VERTEX, distance v1 Stage 2.
##
## Continuous in distance and NOT a function of which ring the vertex belongs
## to. The naive fix - ring 0 reads level 1, ring 1 level 2, ring 2 level 3 -
## removes the aliasing and keeps the pop, because the ring boundary is still a
## discrete step at a fixed distance from the player and a mountain still
## changes shape when it crosses one. A continuous level gives adjacent
## vertices adjacent levels, so the surface stays continuous and the boundary
## stops being an event.
##
## AND IT FADES TO ZERO ACROSS THE SEAM BAND. Hard rule 5: `_corner_y` blends
## the far mesh onto the voxel surface over the last few cells, and that only
## works if the coarse term there is the same coarse term the voxels were built
## from - level 0. The seam sits at 88 m, which log2(88/100) + 1 puts at level
## 0.8, so without this the filter would reintroduce the half-block step that
## world feel v1 spent a stage removing. Multiplying by (1 - blend) makes the
## seam exactly level 0 and lets the filter come on over the same band the
## detail fades out over.
## THE SAME EXPRESSION AS level_at_distance() BELOW, WRITTEN OUT. It is the one
## piece of duplication in this file and it is here for a measured reason: this
## runs nine times per quad, twenty-odd thousand quads per build, and routing it
## through the static cost the far mesh 1,449 -> 1,727 ms per rebuild - 19% of a
## job that already shares a single-GDScript-task pool with chunk generation.
## Distance v1 Stage 6. Change one, change the other.
func _level_at(bx: int, bz: int, band: float) -> float:
	var bs: float = config.block_size
	var dx := float(bx - _ring_cx)
	var dz := float(bz - _ring_cz)
	var d_m := sqrt(dx * dx + dz * dz) * bs
	if d_m <= 0.001:
		return 0.0
	var level := log(d_m / maxf(config.far_level_ref_m, 1.0)) * INV_LN2 \
		+ config.far_filter_bias
	# CLAMPED TO THE TILE STORE'S TOP, not the pyramid's - horizon v1 Stage 3.
	#
	# `_level_at` is log2 of the distance from the ring's centre, and ring 9
	# draws to 38.4 km, so the level it wants out there is 9. The five-level
	# clamp that stood here was the PYRAMID's bound, and it was the right one
	# while the pyramid was the only source: it meant every ring past 5 read a
	# 64 m box filter, so a mountain at 30 km would have been drawn from the
	# same numbers as one at 3 km. `Heightmap.far_max_level` clamps per source
	# on the read, so inside the home region this still resolves to 5 and the
	# home 3 km is drawn exactly as it was.
	level = clampf(level, 0.0, float(Heightmap.TILE_MAX_LEVEL))
	if band > 0.0 and level > 0.0:
		var sx := float(bx - center.x)
		var sz := float(bz - center.y)
		var blend := clampf(
			1.0 - (sqrt(sx * sx + sz * sz) - _seam_radius) / band, 0.0, 1.0)
		level *= 1.0 - blend
	return level


## The coarse height at one vertex, read off the pyramid at that vertex's level.
##
## THE PEAK GAIN, distance v1 Stage 3. `far_peak_gain` blends the mean pyramid
## towards a parallel pyramid of maxima, which gives a summit back the height a
## box filter took off it without giving back the frequency that was fizzing.
## At 0 this is the plain filter and the second pyramid is never read.
## The same expression as filtered_height() below, written out - see the note on
## _level_at(). Nine calls per quad is where the far mesh's build time lives.
func _filtered(bx: int, bz: int, band: float) -> float:
	var level := _level_at(bx, bz, band)
	if level <= 0.0:
		return heightmap.far_height_at(float(bx), float(bz), _view)
	var mean := heightmap.far_height_filtered(float(bx), float(bz), level, _view)
	var gain: float = config.far_peak_gain
	if gain <= 0.0:
		return mean
	return lerpf(mean,
		heightmap.far_height_max_filtered(float(bx), float(bz), level, _view), gain)



## The slope of the FLANK, not of the facet: the heightmap's gradient over
## far_normal_m, centred on the quad.
##
## The poster ramp in Look paints three flat tones, and on a facet normal that
## means every triangle of a mountain picks its own tone - the first look tour
## came back with the far ranges as a patchwork. A mountain in a poster has
## one lit side and one shaded side. Averaging the slope over a couple of dozen
## metres gives it exactly that, and the mesh stays flat-shaded per quad, so
## the faceting is still there in the geometry; it just stops being the thing
## that decides the tone.
func _flank_normal(bx: int, bz: int) -> Vector3:
	var bs: float = config.block_size
	var span := maxi(int(round(config.far_normal_m / bs * 0.5)), 1)
	var x0 := float(bx - span)
	var x1 := float(bx + span)
	var z0 := float(bz - span)
	var z1 := float(bz + span)
	# THE SAME SURFACE THE VERTICES CAME FROM, distance v1 Stage 4. far_normal_m
	# averaged the slope over 96 m precisely because the raw samples under it
	# were noise; now they are not, so the average is over a surface that is
	# already smooth and the span can come down.
	var dx := (_filtered(int(x1), bz, 0.0) - _filtered(int(x0), bz, 0.0)) * bs
	var dz := (_filtered(bx, int(z1), 0.0) - _filtered(bx, int(z0), 0.0)) * bs
	var run := float(span) * 2.0 * bs
	return Vector3(-dx, run, -dz).normalized()


## Height of one far-field vertex, in METRES, blended towards the voxel surface
## as it approaches the seam.
##
## `inner` is where the voxels stop, so the blend is 1 at the seam and 0 a band
## further out. Note what the two ends actually compute:
##
##   at the seam   coarse + detail + half a block - no y_offset. That is the
##                 voxel surface, so the two meshes meet at the same altitude.
##   outside it    the plain coarse height, dropped by y_offset so it can never
##                 poke up through voxels that are not there to hide it.
##
## detail_at() is a noise sample and this is the only place the far field pays
## for one, which is why the band is deliberately narrow.
func _corner_y(bx: int, bz: int, coarse: float, band: float, y_offset: float) -> float:
	var bs: float = config.block_size
	if band <= 0.0:
		return coarse * bs + y_offset
	var dx := float(bx - center.x)
	var dz := float(bz - center.y)
	var blend := clampf(1.0 - (sqrt(dx * dx + dz * dz) - _seam_radius) / band, 0.0, 1.0)
	if blend <= 0.0:
		return coarse * bs + y_offset
	var h := coarse + (generator.detail_at(float(bx), float(bz), true, _view)
		+ VOXEL_TOP_BIAS_BLOCKS) * blend
	# The offset exists to keep the far mesh UNDER voxels whose detail it does
	# not know about. Where it does know about it, there is nothing to hide
	# from and the offset would reintroduce the step it was covering.
	#
	# AND INSIDE THE SEAM RADIUS IT SINKS, distance v3 Stage 7. `blend` saturates
	# at 1 the moment the far mesh is inside the voxel edge, so everything the
	# overdraw draws under the voxels would otherwise sit exactly on the voxel
	# surface and poke through half of it. `over` is how far inside the seam
	# this corner is, in bands, and the sink is zero AT the seam - so the join
	# itself is exactly what it was - and full one band in. See
	# SEAM_SINK_BLOCKS.
	var over := clampf((_seam_radius - sqrt(dx * dx + dz * dz)) / band, 0.0, 1.0)
	return (h - over * SEAM_SINK_BLOCKS) * bs + y_offset * (1.0 - blend)


## THE QUANTISED HEIGHT OF ONE CELL, and the terrace strength there. Returns
## the cache index, so the caller reads _t_hq and _t_t without a second lookup.
##
## Stage 1, and the one expression this whole epic rests on:
##
##     hq = round(h / step) * step,  step = the ring's cell width in BLOCKS
##
## In blocks rather than in metres because the ring's step IS its cell width in
## blocks - 8, 16 and 32 - so quantising to it is the cubic lock (decision 4)
## written directly, and the three of them are powers of two of each other by
## construction rather than by arithmetic that could round.
func _cell(i: int, j: int) -> int:
	var at := (i + _t_off) + (j + _t_off) * _t_w
	if not is_nan(_t_hq[at]):
		return at
	# far_step_y_blocks overrides the cubic lock: the cell stays as wide as its
	# ring but its height lands on the block lattice, which is DH's model -
	# horizontal-only decimation, full vertical resolution.
	var step := _t_step_y if _t_step_y > 0.0 else float(_t_step)
	var h := _cell_h(i, j)
	# DECISION 9, AND THE SHAPE IT ENDED UP IN. A local maximum of the flank
	# rounds onto a FINER grid - see RIDGE_SUBSTEP - and everything else rounds
	# to its ring's own step. Stage 4 rounded ridges UP instead; that kept the
	# height and cost the summit its point.
	if _is_ridge(i, j, h):
		# ROUND UP, ON THE FINER GRID - and the round-up is not optional. Trying
		# `round` here instead cost PEAK LOSS +13.40 -> +27.80: decision 9's
		# upward bias is what buys a summit its height back off a filtered
		# pyramid, and it turns out to be nearly the whole of the 76%
		# improvement, not the cosmetic half. What the finer grid removes is the
		# OVERSHOOT - a whole step became at most a quarter of one.
		# Never finer than one block: the block lattice is the floor of every
		# quantisation here, and a sub-block ridge height would sit off it.
		var fine := maxf(step / float(RIDGE_SUBSTEP), 1.0)
		_t_hq[at] = ceil(h / fine) * fine
	else:
		_t_hq[at] = round(h / step) * step
	_t_t[at] = _terrace_at(i, j)
	return at


## Is this cell a local maximum of the FLANK - a summit rather than a bump?
##
## Four cached neighbour heights at RIDGE_SPAN_BLOCKS either side, off the same
## filtered pyramid the cell's own height came from. The filtered pyramid and
## not the raw grid: the raw grid is the aliasing distance v1 spent a night
## removing, and a local maximum is precisely the place an unfiltered sample is
## most biased.
##
## Four cached reads rather than four fresh pyramid lookups is what makes this
## affordable. The neighbours are cells of this ring, so on a mountainside most
## of them have already been computed for their own quads and the ones outside
## the ring are the reason the cache carries a margin.
func _is_ridge(i: int, j: int, h: float) -> bool:
	var r := _t_ridge
	return h >= _cell_h(i - r, j) and h >= _cell_h(i + r, j) \
		and h >= _cell_h(i, j - r) and h >= _cell_h(i, j + r)


## The raw filtered height at one cell's CENTRE, cached.
##
## The centre and not a corner: a cell gets ONE height and a corner belongs to
## four cells, so sampling at a corner would make the cell's height depend on
## which of its corners was picked. The centre is the only point the cell owns.
##
## Read at _t_level, NOT through _filtered() - see the note on _t_level for the
## measurement that decided that. The peak gain is applied here for the same
## reason _filtered applies it: the terrace is cut from the surface the far mesh
## draws, and distance v1's dilation is part of that surface.
func _cell_h(i: int, j: int) -> float:
	var at := (i + _t_off) + (j + _t_off) * _t_w
	var v := _t_h[at]
	if not is_nan(v):
		return v
	var half := _t_step / 2
	var bx := float(_ring_cx + i * _t_step + half)
	var bz := float(_ring_cz + j * _t_step + half)
	# THE GEOMORPH. Over the last _t_geo blocks before this ring's outer
	# boundary the sample slides onto the coarse ring's own lattice, so at the
	# boundary both rings read the same point and the shelf stops moving. See
	# the note by _t_geo.
	if _t_geo > 0.0:
		var gdx := bx - float(center.x)
		var gdz := bz - float(center.y)
		var w := clampf(
			(sqrt(gdx * gdx + gdz * gdz) - (_t_outer - _t_geo)) / _t_geo, 0.0, 1.0)
		if w > 0.0:
			# The coarse ring's grid, derived exactly as _build_ring derives
			# this one's: its step is twice ours, snapped to the same centre.
			var coarse := _t_step * 2
			var ccx := int(floor(float(center.x) / float(coarse))) * coarse
			var ccz := int(floor(float(center.y) / float(coarse))) * coarse
			var chalf := coarse / 2
			var cbx := float(ccx
				+ Chunk.floor_div(int(bx) - ccx, coarse) * coarse + chalf)
			var cbz := float(ccz
				+ Chunk.floor_div(int(bz) - ccz, coarse) * coarse + chalf)
			bx = lerpf(bx, cbx, w)
			bz = lerpf(bz, cbz, w)
	v = heightmap.far_height_filtered(bx, bz, _t_level, _view)
	var gain: float = config.far_peak_gain
	if gain > 0.0:
		v = lerpf(v, heightmap.far_height_max_filtered(bx, bz, _t_level, _view), gain)
	# THE DETAIL LAYER - see the note by _t_detail. At the cell's own position,
	# which is the geomorphed one, so the layer is boundary-stable for exactly
	# the reason the height is.
	if _t_detail > 0.0:
		v += generator.detail_noise_at(bx, bz) * _t_detail
	_t_h[at] = v
	return v


## HOW TERRACED ONE CELL IS: far_terrace, faded to zero across the seam band.
##
## Decision 5, and Stage 8's whole content - never both fixes on the same
## ground. Inside SEAM_BAND_CELLS of the voxel boundary _corner_y() is already
## blending the far mesh onto the voxel surface, because there the far mesh
## computes the same surface the voxels do and there is nothing to disagree
## about. Terracing there would break the agreement that band exists to create,
## and would put a step INSIDE the voxel radius. So the steps fade in over
## exactly the band the detail fades out over: one multiply, because the knob
## already takes a continuous value.
##
## PER CELL, NOT PER CORNER. A cell has one height, so it has one terrace
## strength; a corner shared by two cells at different strengths is exactly the
## gap a riser is for.
func _terrace_at(i: int, j: int) -> float:
	if _t_band <= 0.0:
		return _t_amount
	var half := _t_step / 2
	var dx := float(_ring_cx + i * _t_step + half - center.x)
	var dz := float(_ring_cz + j * _t_step + half - center.y)
	# THE TERRACE'S FADE IS LONGER THAN THE DETAIL'S - see TERRACE_FADE_CELLS.
	# Still zero at the seam and still one where the detail has gone, which is
	# what decision 5 asks for; it just gets there over more ground.
	var band := _t_band * TERRACE_FADE_CELLS / SEAM_BAND_CELLS
	var blend := clampf(
		1.0 - (sqrt(dx * dx + dz * dz) - _seam_radius) / band, 0.0, 1.0)
	return _t_amount * (1.0 - blend)


## Is the quad whose corner is (bx0, bz0) part of this ring?
func _in_ring(bx0: int, bz0: int, step: int, inner: float, outer: float) -> bool:
	var dx := float(bx0 + step / 2 - center.x)
	var dz := float(bz0 + step / 2 - center.y)
	var d_sq := dx * dx + dz * dz
	if d_sq >= outer * outer:
		return false
	# THE INNER EDGE IS PER SECTOR (world feel v1 Stage 3). `inner` is the ring
	# boundary; the hole is where the VOXELS are, and that is the frontier of
	# this quad's own sector. Where the voxels have not arrived the far mesh
	# stays, and the two overlap for a second - which is invisible, whereas a
	# gap is not.
	var hole := inner
	if not _sector_exclude.is_empty() and inner <= _seam_radius:
		var s := World.frontier_sector_of(
			int(bx0 + step / 2 - center.x), int(bz0 + step / 2 - center.y))
		hole = minf(inner, _sector_exclude[s])
	return d_sq >= hole * hole


## A vertical curtain hanging from one edge, drawn BOTH WAYS ROUND.
##
## Two quads with opposite winding rather than one with the correct winding,
## and it is a deliberate choice rather than laziness. A skirt is needed at the
## outer edge of a ring, where "outside" faces away from the player, and at the
## inner edge against the voxel hole, where "outside" faces towards them. One
## rule cannot serve both, back faces are culled, and a skirt facing the wrong
## way is invisible - which looks exactly like the crack it was meant to cover
## and would be debugged as one. Doubling costs a few hundred quads out of a
## hundred thousand and cannot be wrong.
func _push_skirt(a: Vector3, b: Vector3, drop: float, color: Color,
		verts: PackedVector3Array, normals: PackedVector3Array,
		colors: PackedColorArray, indices: PackedInt32Array) -> void:
	_push_riser(a, b, drop, drop, color, verts, normals, colors, indices)


## The same curtain with a DIFFERENT DEPTH AT EACH END - a terrace riser.
## Distance v2 Stage 2.
##
## Two depths rather than one because the terrace fades in across the seam band
## (Stage 8), so for a few cells either side of it two neighbouring cells are
## terraced by different amounts and the gap between them is a wedge rather than
## a step. Everywhere else the two depths are equal and this is a rectangle,
## which is what a block's side face is.
##
## BOTH WAYS ROUND, FOR A RISER AS WELL AS FOR A SKIRT, and the flag is here
## because that was tried the other way and photographed.
##
## A skirt has to be drawn both ways because it is needed at the OUTER edge of a
## ring, where "outside" faces away from the player, and at the inner edge
## against the voxel hole, where it faces towards them; one rule cannot serve
## both and a skirt facing the wrong way is invisible, which looks exactly like
## the crack it was meant to cover.
##
## A RISER LOOKS LIKE IT HAS NO SUCH AMBIGUITY AND IT DOES. The argument for
## single-sided is that a riser always faces its lower neighbour, which is the
## only side it can be seen from, because the higher cell's own top quad is in
## the way from the other. That argument holds on a gentle slope and fails on a
## STEEP one: where consecutive cells drop by more than a cell width the top
## quads are narrow slivers between tall risers, they occlude nothing, and the
## silhouette of a cliff is made of risers facing several different ways at
## once.
##
## Measured, seed 42, Forward+ on ganymede, `6-postcard`: single-sided saves
## 75,760 vertices - 255,128 down to 179,368, from 2.46x the smooth mesh to
## 1.73x - and opens a bright SEE-THROUGH GASH down the steep face of the
## central massif, 1,063 pixels of the far band that get brighter by a mean of
## 46 sRGB levels because the mountain behind is showing through. Cropped and
## compared at `build/probe/crop-dbl.png` against `crop-single.png`.
##
## So: both ways round, and the vertices are the price. "No holes on the
## horizon" is Stage 2's gate and it is not tradeable against a vertex count.
func _push_riser(a: Vector3, b: Vector3, drop_a: float, drop_b: float,
		color: Color, verts: PackedVector3Array, normals: PackedVector3Array,
		colors: PackedColorArray, indices: PackedInt32Array,
		both_sides := true) -> void:
	var a_down := a - Vector3(0.0, drop_a, 0.0)
	var b_down := b - Vector3(0.0, drop_b, 0.0)
	# The first is the winding that faces the LOWER neighbour - the one a
	# single-sided riser would keep. See the note above for why it does not.
	_push_quad(a_down, b_down, b, a, color, verts, normals, colors, indices)
	if both_sides:
		_push_quad(a, b, b_down, a_down, color, verts, normals, colors, indices)


## Four corners in, one flat-shaded quad out. The normal is derived from the
## winding rather than passed in, so the identity the whole mesher rests on -
## (p1 - p0) x (p2 - p0) == -normal - holds by construction here instead of
## being something each caller has to remember.
##
## `lighting_normal`, when given, is what the vertices CARRY instead of the
## facet's own normal - the winding still decides which side is drawn. Look v1
## hands the flank normal in for the ground quads; skirts keep their own.
func _push_quad(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, color: Color,
		verts: PackedVector3Array, normals: PackedVector3Array,
		colors: PackedColorArray, indices: PackedInt32Array,
		lighting_normal := Vector3.ZERO) -> void:
	var normal := -((p1 - p0).cross(p2 - p0))
	if normal.length_squared() < 0.000001:
		normal = Vector3.UP
	else:
		normal = normal.normalized()
	if lighting_normal != Vector3.ZERO:
		normal = lighting_normal

	# ONE FLAT COLOUR PER MATERIAL, NEAR AND FAR (light v1 Stage 3, Q15). The
	# aspect shade and the per-vertex jitter that used to run here are gone from
	# both legs in the same commit, so the parity tests never saw them disagree.
	# The seam still cannot show a line in colour, and for a better reason than
	# before: the voxels beside it now emit the same flat zone colour through
	# the same one conversion.
	var wire := Look.to_wire(color)

	var first := verts.size()
	for p in [p0, p1, p2, p3]:
		verts.push_back(p)
		normals.push_back(normal)
		colors.push_back(wire)
	indices.push_back(first)
	indices.push_back(first + 1)
	indices.push_back(first + 2)
	indices.push_back(first)
	indices.push_back(first + 2)
	indices.push_back(first + 3)


# --- What the backdrop looks like, for anything drawn IN FRONT of it ----------
#
# Distance v1 Stage 6. The impostor ring converges each tree's colour towards
# the hillside it stands on, and "the hillside's colour" has to be the one this
# job actually paints or the two drift apart the first time either is tuned.
# So the four rules that decide it - the level, the filtered height, the zone
# and the altitude band - are static functions here, and the instance methods
# above are one-line calls into them. There is exactly one implementation of
# each, and TreeFieldJob calls the same one.
#
# Pure: no job state, nothing but the generator, the config and a position.
# Safe from any worker, which is where both callers are.


## The mip level the far mesh reads at a given distance from the ring's centre.
##
## The seam fade is NOT here and belongs to _level_at: it needs the job's own
## seam radius, and out where the impostors stand there is no seam - the
## nearest of them is at the voxel radius, which is where the seam ends.
static func level_at_distance(config: WorldgenConfig, d_m: float) -> float:
	if d_m <= 0.001:
		return 0.0
	var level := log(d_m / maxf(config.far_level_ref_m, 1.0)) * INV_LN2 \
		+ config.far_filter_bias
	# See _level_at: the tile store's top, and the heightmap clamps per source.
	return clampf(level, 0.0, float(Heightmap.TILE_MAX_LEVEL))


## The height the far mesh draws at one place, read off the pyramid at `level`
## and pulled back towards the maxima by far_peak_gain. Level 0 is the raw
## grid, which is the surface the voxels are built from.
static func filtered_height(heightmap: Heightmap, config: WorldgenConfig,
		bx: float, bz: float, level: float, view := {}) -> float:
	if level <= 0.0:
		return heightmap.far_height_at(bx, bz, view)
	var mean := heightmap.far_height_filtered(bx, bz, level, view)
	var gain: float = config.far_peak_gain
	if gain <= 0.0:
		return mean
	return lerpf(mean, heightmap.far_height_max_filtered(bx, bz, level, view), gain)


## ALTITUDE ALONE, NO JITTER, A DITHER OF EXACTLY 0.5, and the slope override
## kept. What the far mesh painted with until Stage 4 replaced it.
##
## NOTHING IN THE RENDER PATH CALLS THIS ANY MORE. It stays because
## `scripts/tools/selftest.gd`'s cross-leg parity test calls it - eight hundred
## positions, this against `KubikFarMesher.z_backdrop`, asserting the two
## meshers agree about a zone - and this lane may add exactly one line to that
## file (plan § 0). Deleting the function would break a green gate in a file it
## may not fix. So both legs keep it, both legs keep answering the same, and
## the request to retire the pair together is written in the status doc under
## "For the merge".
static func backdrop_zone(generator: TerrainGenerator, bx: int, bz: int,
		altitude: float, view := {}) -> int:
	return generator._slope_zone(bx, bz,
		generator.zone_at(altitude, 0.0, 0.5), true, view)


## The material the far mesh paints at one place and one ring cell - horizon v1
## Stage 4, and the whole of what `backdrop_zone` used to compute.
##
## `cell` is the ring's cell in blocks; the level is the one whose cell matches
## it. The altitude argument is gone with the rule that needed it: a material
## is read, not derived from a height.
static func backdrop_material(heightmap: Heightmap, bx: int, bz: int,
		cell: int, view := {}) -> int:
	return heightmap.far_material_at(float(bx), float(bz),
		material_level(heightmap, cell), view)


## THE WHOLE BACKDROP COLOUR AT ONE PLACE, in LINEAR, before the wire
## conversion.
##
## What an impostor converges towards. It reads the FILTERED height rather than
## the raw one on purpose: the question this answers is "what colour is the
## mountain the eye sees behind this tree", and the mountain the eye sees is the
## one drawn off the pyramid.
##
## ONE FLAT ZONE COLOUR since light v1 Stage 3. It used to run the altitude
## band over it, at the far mesh's own interval for this distance, so an
## impostor converged toward the exact painted band behind it. With no band to
## agree about, the agreement is free.
##
## `band_treeline` is kept in the signature and unread: `TreeFieldJob` passes it
## and a phase-3 building pass will want the same hook.
static func backdrop_color(heightmap: Heightmap, generator: TerrainGenerator,
		config: WorldgenConfig, bx: int, bz: int, d_m: float,
		band_treeline: int) -> Color:
	var mat := backdrop_material(heightmap, bx, bz,
		ring_step_blocks(config, d_m), heightmap.far_view())
	return Block.color_of(TerrainGenerator.ZONE_SURFACE[mat])


## THE COLOUR THE FAR FOREST BLENDS TOWARDS, in LINEAR - horizon v1 Stage 4.
##
## The mean canopy colour of every tree variant the library holds, so the far
## forest is the colour of THIS world's trees rather than of a number written
## down once. With no assets mounted the library is empty and the fallback is
## `TreeModels.canopy_color`'s own - the same constant that file falls back to,
## for the same reason - so a public checkout draws a plausible conifer green
## and the two never disagree about which constant it is.
##
## No asset colour is committed here (D50): this reads the mounted library at
## run time and names nothing.
static func canopy_color() -> Color:
	var variants := TreeModels.variants()
	if variants.is_empty():
		return Color(0.0284, 0.0782, 0.0482)
	var r := 0.0
	var g := 0.0
	var b := 0.0
	for v: StringName in variants:
		var c := TreeModels.canopy_color(v)
		r += c.r
		g += c.g
		b += c.b
	var n := float(variants.size())
	return Color(r / n, g / n, b / n)


## WHICH MATERIAL PYRAMID LEVEL HAS THIS RING'S CELL, horizon v1 Stage 4.
##
## The ladder was built for exactly this: a ring's cell is `base_step x 2^r`
## blocks and a pyramid level's cell is `heightmap.step x 2^L`, so the level
## whose cell matches the ring's is `log2(step / heightmap.step)`. At
## `far_ring_div` 2 the base step IS `heightmap.step`, so ring r paints from
## level r; at 4 the base step is half a cell and rings 0 and 1 both paint from
## level 0, which is the finest the world has.
##
## Clamped nowhere here: `far_material_at` clamps per SOURCE, because the
## region has five levels and a tile has nine, and only it knows which one a
## position is in.
static func material_level(heightmap: Heightmap, step: int) -> int:
	var s: int = maxi(heightmap.step, 1)
	if step <= s:
		return 0
	return int(round(log(float(step) / float(s)) * INV_LN2))


## THE RING'S CELL WIDTH AT ONE DISTANCE, in blocks - which is also that ring's
## terrace step height, by decision 4's cubic lock. Distance v2 Stage 5.
static func ring_step_blocks(config: WorldgenConfig, d_m: float) -> int:
	var step := base_step_blocks(config)
	for i in RING_OUTER_M.size():
		if d_m < RING_OUTER_M[i]:
			return step * RING_STEP_MULTIPLE[i]
	return step * RING_STEP_MULTIPLE[RING_STEP_MULTIPLE.size() - 1]


## The one pyramid level the terrace is cut from - see _t_level, which is this
## expression written out for the reason given there.
static func terrace_level(heightmap: Heightmap, config: WorldgenConfig) -> float:
	var ring := clampi(TERRACE_LEVEL_RING, 0, RING_STEP_MULTIPLE.size() - 1)
	return clampf(log(float(base_step_blocks(config) * RING_STEP_MULTIPLE[ring])
		/ float(heightmap.step)) * INV_LN2 + config.far_filter_bias,
		0.0, float(Heightmap.MAX_LEVEL))


## HOW FAR THE TERRACE MOVED THE GROUND AT ONE PLACE, in blocks. Distance v2
## Stage 5, and it is the whole of the impostors' footing.
##
## Returns `far_terrace * (quantised - unquantised)` rather than the shelf
## height itself, and that choice is what keeps hard rule 1 exact. An impostor
## stands on `ground + 1` today, where `ground` is the TRUE voxel surface and
## not the filtered one the far mesh draws - the two differ by tens of blocks at
## a summit, which is PEAK LOSS. Snapping the tree to the shelf outright would
## therefore move every far tree by that difference the moment this epic
## shipped, at every value of the knob including zero. Adding the OFFSET moves
## it by exactly as much as the ground under it moved and by nothing at
## far_terrace 0.
##
## THE SAME QUANTISATION AS _cell() AND _is_ridge(), WRITTEN OUT. It is the
## second piece of deliberate duplication in this file, for the reason the first
## one carries: the job runs this expression tens of thousands of times a
## rebuild off a cache, and the ring does it a few hundred times with no cache
## at all. Change one, change the other.
##
## `d_m` decides the ring and therefore the step. TreeField centres on the
## player's exact block and FarField on the player's chunk, so a tree within one
## cell of a ring boundary can pick the neighbouring ring's step; that is one
## cell of disagreement at a boundary the far mesh already has a skirt for.
static func terrace_offset(heightmap: Heightmap, config: WorldgenConfig,
		bx: int, bz: int, d_m: float) -> float:
	var amount := clampf(config.far_terrace, 0.0, 1.0)
	if amount <= 0.0:
		return 0.0
	# The seam fade, the same one _terrace_at() applies: inside the band the far
	# mesh computes the voxel surface on purpose and is not terraced, so a tree
	# there must not be lifted onto a shelf that is not drawn.
	var bs: float = config.block_size
	var seam := maxf(float(config.voxel_radius_chunks * Chunk.SIZE)
		- float(2 * config.far_step), 0.0)
	var band := float(config.far_step) * TERRACE_FADE_CELLS
	if band > 0.0:
		amount *= 1.0 - clampf(1.0 - (d_m / bs - seam) / band, 0.0, 1.0)
		if amount <= 0.0:
			return 0.0

	var step := ring_step_blocks(config, d_m)
	var level := terrace_level(heightmap, config)
	# The cell grid is anchored to the WORLD, not to the player: _build_ring
	# snaps its centre to floor(centre / step) * step, which is a multiple of
	# step, so every cell corner is one too and the cell containing a block is
	# the same cell from every vantage.
	var half := step / 2
	var cx := Chunk.floor_div(bx, step) * step + half
	var cz := Chunk.floor_div(bz, step) * step + half
	# ONE VIEW FOR ALL FIVE READS, so the impostor's footing is computed
	# against a single snapshot of the tile store - see `Heightmap.far_view`.
	var view := heightmap.far_view()
	var h := _cell_height_at(heightmap, config, cx, cz, level, view)
	var fstep := float(step)
	var r := maxi(RIDGE_SPAN_BLOCKS / step, 1) * step
	var ridge := h >= _cell_height_at(heightmap, config, cx - r, cz, level, view) \
		and h >= _cell_height_at(heightmap, config, cx + r, cz, level, view) \
		and h >= _cell_height_at(heightmap, config, cx, cz - r, level, view) \
		and h >= _cell_height_at(heightmap, config, cx, cz + r, level, view)
	var hq: float = (ceil(h / fstep) if ridge else round(h / fstep)) * fstep
	return amount * (hq - h)


## One cell-centre height off the terrace level, with the peak gain - the static
## twin of _cell_h().
static func _cell_height_at(heightmap: Heightmap, config: WorldgenConfig,
		bx: int, bz: int, level: float, view := {}) -> float:
	var h := heightmap.far_height_filtered(float(bx), float(bz), level, view)
	var gain: float = config.far_peak_gain
	if gain <= 0.0:
		return h
	return lerpf(h, heightmap.far_height_max_filtered(float(bx), float(bz), level, view), gain)
