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
const RING_OUTER_M := [150.0, 300.0, 600.0, 1200.0, 2400.0]

## Blocks per vertex in each ring, as a multiple of the BASE step below. At the
## default far_step of 8 blocks that is 2, 4, 8, 16, 32 and 64 metres per
## vertex.
const RING_STEP_MULTIPLE := [1, 2, 4, 8, 16, 32]

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

## One `[verts, normals, colors, indices]` per frontier sector, in sector
## order. Empty unless `slice` is on.
var slices: Array = []

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
var _band_treeline := 0


func run() -> void:
	var _t0 := Time.get_ticks_msec()
	# THE PYRAMID IS BUILT ON FIRST USE, and this is the first use. Idempotent
	# and behind a mutex, so the cost lands once, on this worker, inside this
	# job's elapsed_ms - which is where it is visible rather than hidden in a
	# startup total.
	heightmap.build_pyramid()
	var bs: float = config.block_size
	var base_step := base_step_blocks(config)
	# The treeline's band, once. zone_thresholds[ZONE_FOREST] is the top of the
	# forest zone in BLOCKS; _band_color works in metres.
	_band_treeline = treeline_band(generator, config)
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
	# DISTANCE V3 STAGE 1. Read once per job for the same reason far_terrace is:
	# it is a knob on a shared config the main thread can write while this worker
	# runs, and a value that changed half way through would vote on half a mesh.
	_voting = config.far_vote > 0.0 and generator != null and heightmap != null
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
	if slice:
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
		_build_ring(ring, step, inner, outer, y_offset, verts, normals, colors, indices)
		inner = outer

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
			if sink[0].is_empty():
				out.append([])
				continue
			var a := []
			a.resize(Mesh.ARRAY_MAX)
			a[Mesh.ARRAY_VERTEX] = sink[0]
			a[Mesh.ARRAY_NORMAL] = sink[1]
			a[Mesh.ARRAY_COLOR] = sink[2]
			a[Mesh.ARRAY_INDEX] = sink[3]
			out.append(a)
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
	# Per ring, because the cell grid is per ring and a key from the last ring
	# could collide with a cell of this one.
	_vote_memo.clear()
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
			if not heightmap.in_bounds(bx0, bz0):
				continue

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
			if slice:
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
			var p0 := Vector3(float(bx0) * bs, _corner_y(bx0, bz0, h00, band, y_offset), float(bz0) * bs)
			var p1 := Vector3(float(bx1) * bs, _corner_y(bx1, bz0, h10, band, y_offset), float(bz0) * bs)
			var p2 := Vector3(float(bx1) * bs, _corner_y(bx1, bz1, h11, band, y_offset), float(bz1) * bs)
			var p3 := Vector3(float(bx0) * bs, _corner_y(bx0, bz1, h01, band, y_offset), float(bz1) * bs)

			# Colour from the same zone rules the voxels use, sampled at the
			# quad's middle. Anything else and the treeline would be in a
			# different place near and far.
			var mid_h := (h00 + h10 + h11 + h01) * 0.25
			var zone_bx := bx0 + step / 2
			var zone_bz := bz0 + step / 2
			# THE ZONE READS THE UNQUANTISED HEIGHT, distance v2 - and it read
			# the quantised one from Stage 2 until an agent looking at the
			# pictures noticed a meadow had turned to rock.
			#
			# `mid_h` is the height the quad is DRAWN at, which since Stage 2 is
			# the cell's shelf. Deciding the zone from it means a cell whose
			# true altitude sits just under a zone threshold, and whose shelf
			# rounds up across it, is repainted as the zone above - so the
			# treeline and the snow line move by up to half a step, 2 m at
			# ring 0 and 4 m at ring 1. The comment below says exactly why the
			# inner rings may not do that: "the first so the treeline agrees
			# with the voxels at the seam".
			#
			# WHAT a place is made of is not this epic's to change - hard rule
			# 7 in spirit, the same reason the heightmap hash may not move. The
			# terrace changes how the far country is DRAWN and never what it IS,
			# and a zone is what it is. At far_terrace 0 mid_true is mid_h
			# exactly, so this is a no-op there.
			var zone_h := mid_true
			# BEYOND THE FIRST RING THE ZONE IS SAMPLED ON A COARSER CELL, look
			# v1. Zone boundaries are noise, so quad by quad a far peak comes
			# out as a speckle of rock, snow and turf; sampled once per
			# far_zone_cell_m it comes out in blocks, which is how a poster
			# paints a mountainside. The two inner rings keep the exact sample:
			# the first so the treeline agrees with the voxels at the seam, the
			# second because at 200 m a 24 m cell is still a visible square,
			# and the postcard showed a checkerboard of meadow on the shore.
			# Rendering only: the zones themselves do not move.
			# THE CELL GROWS WITH DISTANCE, distance v1 Stage 4. One constant
			# paints a mountainside at 600 m in the same 24 m fields as one at
			# 200 m, and at 600 m a 24 m field is a couple of pixels.
			var zone_d_m := 0.0
			if ring > 0:
				var zdx := float(bx0 + step / 2 - _ring_cx)
				var zdz := float(bz0 + step / 2 - _ring_cz)
				zone_d_m = sqrt(zdx * zdx + zdz * zdz) * bs
			# THE ZONE CELL'S OWN WIDTH IN BLOCKS, which distance v3's vote needs
			# and the single-sample path never had to name: the vote's four
			# sub-samples sit at the quarter points of THIS square.
			var zone_cell := step
			if ring > 1 and config.far_zone_cell_m > 0.0:
				var cell_m := maxf(config.far_zone_cell_m,
					config.far_zone_cell_ratio * zone_d_m)
				zone_cell = maxi(int(round(cell_m / bs)), step)
				zone_bx = Chunk.floor_div(bx0, zone_cell) * zone_cell + zone_cell / 2
				zone_bz = Chunk.floor_div(bz0, zone_cell) * zone_cell + zone_cell / 2
				# THE ZONE READS THE FILTERED HEIGHT TOO. It decided the quad's
				# colour off the raw 2 m grid while the quad's own corners came
				# off the pyramid, so the paint was sampled from a surface the
				# geometry no longer had.
				#
				# NOT TAKEN WHEN THE VOTE IS ON - the vote reads its own four
				# heights at its own level and this sample would be thrown away.
				# It is two pyramid reads per quad, which is most of what pays
				# for the vote.
				if not _voting:
					zone_h = _filtered(zone_bx, zone_bz, 0.0)
			var zone := _far_zone(zone_bx, zone_bz, zone_h, ring, zone_cell)
			var color := Block.color_of(TerrainGenerator.ZONE_SURFACE[zone])

			# THE BACKDROP, look v1. One altitude band per quad - so the band
			# edges are the quad edges, a hard stepped contour rather than a
			# gradient across the quad - and a lighting normal from the slope
			# of the whole flank rather than of this one facet. See the two
			# helpers below.
			# THE BAND INTERVAL IS THE RING'S STEP HEIGHT, distance v2 Stage 7,
			# so a band boundary IS a shelf boundary and lands on a riser
			# instead of wandering across a slope. Per quad rather than per
			# ring, because the terrace fades across the seam band and the
			# interval fades with it.
			var band_m := band_m_at(config, step, terr)
			var band_tl := _band_treeline
			if band_m != config.far_band_m:
				band_tl = treeline_band(generator, config, band_m)
			color = _band_color(color, mid_h * bs, band_m, band_tl)
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
				# A neighbour outside the heightmap emitted no quad of its own,
				# so there is no shelf for a riser to stand against. Left exactly
				# as it was before this epic: hard rule 1 is about every edge,
				# including the ones at the edge of the world.
				if not heightmap.in_bounds(nbx, nbz):
					continue
				var nat := _cell(i + e[4], j + e[5])
				var nt: float = _t_t[nat]
				var nq: float = _t_hq[nat]
				# THE GAP, AT BOTH ENDS OF THE EDGE. Both cells blend from the
				# same raw corner sample, so at far_terrace 0 this is exactly
				# zero at both ends and no riser is emitted at all - and where
				# the terrace is fading in across the seam band (Stage 8) the two
				# ends can differ, which is why the riser is a trapezoid rather
				# than a rectangle.
				# THE LIFT IS ASYMMETRIC, and this is the whole of the black
				# crush fix. Measured: terracing takes the far band's dead-black
				# share from 7.08% to 15.63%, and it is the RISERS - turning off
				# the altitude bands makes it worse (15.63%) and turning off the
				# impostors worse still (18.06%), so neither of those is the
				# cause. Geometry cannot fix it either: a riser is as tall as the
				# terrain's own height difference to its neighbour, so its area
				# is cell width x slope and the step size only rounds it.
				#
				# That leaves light, and light has a trap: the ramp is three flat
				# bands, so on a slope facing fully away from the sun the top and
				# the riser land in the SAME band and nothing separates them.
				# They crush together into one flat black.
				#
				# A symmetric lift was tried at 1.30 and is a weak lever - the
				# treeline band moved 34.79% to 34.11% - because it lifts the lit
				# side too, where it is not needed and where it starts to look
				# like a cheat (a riser brighter than its own shelf top).
				#
				# So the lift goes only where the dark is. `e[4]`/`e[5]` are the
				# edge's outward direction in cells, which is exactly what
				# Block.aspect_shade already dots against SUN_ASPECT, so the
				# mesher knows which risers face away without computing anything
				# new. A riser facing the sun is drawn at far_riser_shade and is
				# an honest voxel side face; one facing away is lifted off the
				# shade floor by far_riser_lift.
				var away := clampf(-(float(e[4]) * Block.SUN_ASPECT.x
					+ float(e[5]) * Block.SUN_ASPECT.y), 0.0, 1.0)
				# THE AXIS TERM, distance v3 Stage 3. `cross` is 1 for a riser
				# facing ACROSS the aspect axis and 0 for one facing along it -
				# the perp dot of the edge's outward direction against
				# Block.SUN_ASPECT, which is the same fixed direction aspect_tint
				# has picked since look v1, so the far country and the near
				# country disagree about nothing. See far_riser_axis.
				var cross := absf(float(e[4]) * Block.SUN_ASPECT.y
					- float(e[5]) * Block.SUN_ASPECT.x)
				var k: float = config.far_riser_shade \
					* lerpf(1.0, config.far_riser_lift, away) \
					* (1.0 - config.far_riser_axis * cross)
				var riser := Color(color.r * k, color.g * k, color.b * k, color.a)
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
					riser, w_verts, w_normals, w_colors, w_indices)


## The zone of one far-field quad.
##
## NO DITHER AND NO JITTER PAST THE FIRST RING, distance v1 Stage 4.
##
## `surface_zone_at()` hashes a per-column jitter and a per-patch dither so the
## two zones INTERLEAVE across a boundary. At 0.5 m per block that reads as a
## gradient, which is what it is for. At 16 m per quad the same mechanism reads
## as tetris - a camouflage of small hard-edged patches instead of the three or
## four large fields the poster is supposed to paint - and it is the single
## most likely cause of the mosaic in `6-postcard.png`.
##
## So past ring 0 the zone is decided by ALTITUDE ALONE: zone_at() with no
## jitter and a dither of exactly 0.5, which promotes a cell the moment its
## altitude passes the threshold and never before. Ring 0 keeps the exact
## sample, because it touches the voxels at the seam and the treeline has to
## agree with the trees.
##
## The SLOPE override is kept - snow does not sit on a cliff, and dropping it
## past ring 0 would put white on every far spire. It is deterministic at
## slope_zone_strength 1.0 (the roll can never exceed 1), so it is a function
## of the ground and not another hash.
##
## Rendering only: the zones themselves do not move, and nothing here is read
## by anything that decides what the world is.
func _far_zone(bx: int, bz: int, altitude: float, ring: int, cell: int) -> int:
	if ring == 0:
		return generator.surface_zone_at(bx, bz, altitude)
	if not _voting:
		return backdrop_zone(generator, bx, bz, altitude)
	return _zone_vote(bx, bz, cell)


# --- THE MODE VOTE, distance v3 Stage 1 --------------------------------------
#
# DISTANT HORIZONS NEVER AVERAGES A COLOUR WHEN IT COARSENS. Merging four fine
# columns into one coarse column, it takes the MOST COMMON block id at the
# slice midpoints and keeps that block's colour at full saturation, with air
# excluded so a hollow structure cannot become a hole and ties falling through
# to the first sub-column. `docs/research/distant-horizons.md` §2c has the code.
# The consequence is the one this epic is named for: two adjacent coarse cells
# over a mixed forest floor come out LEAVES and DIRT rather than as two shades
# of brown-green soup, and the arbitrariness of the tie-break is free
# high-frequency texture rather than error.
#
# WHAT WE HAD INSTEAD, and it is worth saying plainly because it is not
# averaging either. Past ring 0 the far field asks `backdrop_zone` for the zone
# at ONE point - the zone cell's centre - at an altitude read off the pyramid at
# a level chosen from the distance to the player. One sample of a smooth
# surface, so neighbouring cells read neighbouring altitudes and agree with each
# other; the mush is not a blend, it is a LOW-PASS. Nothing in the picture ever
# says "this cell is forest and the one beside it is rock" unless the smoothed
# altitude happens to cross a threshold between them.
#
# So the port is: four samples at the sub-cell midpoints, EACH AT THE FINER
# LEVEL - which is exactly what DH is doing when it votes over four fine
# columns - and the mode of what they answer.
#
#   * The level is the one whose cells are the SUB-cell's width, so the four
#     samples read a surface that has detail at the scale they are spaced at.
#     Voting over four reads of a surface too smooth to disagree is four times
#     the cost of the old path and none of the benefit; this is the whole
#     mechanism.
#   * SHORE NEVER WINS, which is DH's "air never wins" in our world. A cell
#     that is three parts meadow and one part lake margin is meadow: a shore
#     fleck floating on a hillside is the artefact the rule exists to stop, and
#     shore is the only zone in this world that belongs to a place rather than
#     to an altitude. A cell whose four samples are ALL shore is shore.
#   * TIES RESOLVE TO THE FIRST SAMPLE, deterministically. Two-two splits are
#     common on a boundary and the arbitrariness is the texture.
#
# COST. Four bilinear pyramid reads per zone CELL where there was one trilinear
# per quad - and past ring 1 the zone cell is coarser than the quad, so the
# memo below serves several quads from one vote and the vote is cheaper than
# what it replaced. Ring 1 pays in full: its zone cell is its quad.

## HOW MANY SUB-CELLS ON A SIDE. Two, which is DH's four sub-columns, and it is
## a constant rather than a knob because three would not be a mode over a power
## of two and five would be a blur.
const VOTE_SPLIT := 2

## config.far_vote > 0 and the generator can answer. Read once per job, like
## every other knob the ring loop reads.
var _voting := false

## THE VOTE MEMO, one entry per zone cell, cleared per ring.
##
## Past ring 1 the zone cell grows with distance - `far_zone_cell_ratio * d` -
## so at 1.5 km one cell covers a couple of dozen quads and the single-sample
## path was answering the same question for every one of them. Keyed on the
## cell's own centre, which is snapped to the cell grid, so two quads in one
## cell hash to one entry by construction.
var _vote_memo := {}


## The mode of the four sub-cell zones. See the block comment above.
func _zone_vote(cx: int, cz: int, cell: int) -> int:
	var key := cx * 131071 + cz
	var hit = _vote_memo.get(key)
	if hit != null:
		return hit
	# The quarter points of the cell: the centres of the four sub-cells, at
	# least one block apart even if a ring's cell ever became tiny.
	var q := maxi(cell / 4, 1)
	var level := _vote_level(cell)
	var gain: float = config.far_peak_gain
	var zones := [0, 0, 0, 0]
	var k := 0
	for dz in [-q, q]:
		for dx in [-q, q]:
			var bx: int = cx + dx
			var bz: int = cz + dz
			var h := heightmap.height_at_level(float(bx), float(bz), level)
			if gain > 0.0:
				# THE PEAK GAIN IS IN THE VOTE, for the reason the zone reads a
				# filtered height at all: the snow line has to sit where the
				# DRAWN summit is, and the drawn summit is the mean pyramid
				# pulled towards the maxima. A vote off the mean alone would
				# paint the snow line tens of blocks below the ridge it is on.
				h = lerpf(h, heightmap.height_max_at_level(
					float(bx), float(bz), level), gain)
			zones[k] = backdrop_zone(generator, bx, bz, h)
			k += 1
	# The mode, with shore excluded and the first sample winning ties. Four
	# values, so a histogram is more code than a double loop and slower.
	var best := -1
	var best_n := 0
	for a in 4:
		if zones[a] == TerrainGenerator.ZONE_SHORE:
			continue
		var n := 0
		for b in 4:
			if zones[b] == zones[a]:
				n += 1
		if n > best_n:
			best_n = n
			best = zones[a]
	if best < 0:
		best = TerrainGenerator.ZONE_SHORE
	_vote_memo[key] = best
	return best


## THE PYRAMID LEVEL THE VOTE READS, an integer, from the sub-cell's width.
##
## `level = log2(sub-cell / heightmap.step) + far_filter_bias`, floored - the
## same expression `_t_level` uses for the terrace, asked about a different cell
## and rounded DOWN rather than left continuous. Floored because the vote wants
## the finer of the two levels it sits between: a vote is only worth taking over
## a surface that still has something to disagree about, and it is an integer so
## the read is one bilinear instead of a trilinear's two.
##
## The bias is included so the paint follows the shape: far_filter_bias is the
## far country's smoothness dial and a vote that ignored it would keep flecking
## a mountain the geometry had smoothed flat.
func _vote_level(cell: int) -> int:
	var sub := maxf(float(cell) / float(VOTE_SPLIT), 1.0)
	var l := log(sub / float(heightmap.step)) * INV_LN2 + config.far_filter_bias
	return clampi(int(floor(l)), 0, Heightmap.MAX_LEVEL)


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
	level = clampf(level, 0.0, float(Heightmap.MAX_LEVEL))
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
		return heightmap.height_at(float(bx), float(bz))
	var mean := heightmap.height_filtered(float(bx), float(bz), level)
	var gain: float = config.far_peak_gain
	if gain <= 0.0:
		return mean
	return lerpf(mean,
		heightmap.height_max_filtered(float(bx), float(bz), level), gain)


## Altitude bands - look v1's far field as a stacked backdrop.
##
## Every far_band_m of altitude the value steps by far_band_step, MONOTONICALLY
## lighter with altitude, so a mountain reads as contour bands the way a poster
## paints one. Applied to a quad's MIDDLE height, once per quad, which is what
## makes the band edge a hard stepped line along the quad grid rather than a
## gradient interpolated across it. Off at far_band_step 0.
## MONOTONIC, NOT ALTERNATING (look v2 Stage 2).
##
## Alternating put a lighter band directly above a darker one at every second
## boundary, and on a flank that climbs across several of them that reads as a
## ZIGZAG - the red zigzag on shot 9's treeline that look v1 recorded and could
## not name. Ranges get lighter with altitude and the fog bands carry the
## distance; the two axes stop fighting each other. Zeroed at the treeline so
## the forest keeps the colour it was authored with, and clamped either side so
## a 400 m peak does not run away to white.
func _band_color(color: Color, y_m: float, band_m: float,
		band_treeline: int) -> Color:
	return band_color(color, y_m, config, band_treeline, band_m)


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
	var h := coarse + (generator.detail_at(float(bx), float(bz))
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
	v = heightmap.height_filtered(bx, bz, _t_level)
	var gain: float = config.far_peak_gain
	if gain > 0.0:
		v = lerpf(v, heightmap.height_max_filtered(bx, bz, _t_level), gain)
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

	# The same aspect and jitter the voxels get, from the same functions and the
	# same seed. If the far field skipped them, the boundary between voxels and
	# far mesh would be a visible line in COLOUR as well as in geometry - and
	# Stage 5 has just spent a whole commit removing it from the geometry.
	var shaded := Block.aspect_shade(color, normal, config.slope_tint, config.aspect_tint)
	var inv_bs := 1.0 / config.block_size

	var first := verts.size()
	for p in [p0, p1, p2, p3]:
		verts.push_back(p)
		normals.push_back(normal)
		colors.push_back(Look.to_wire(Block.jitter(shaded,
			int(round(p.x * inv_bs)), int(round(p.z * inv_bs)), generator.world_seed,
			config.color_jitter_blocks, config.color_jitter_value,
			config.color_jitter_hue)))
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
# each, and FarTreesJob calls the same one.
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
	return clampf(level, 0.0, float(Heightmap.MAX_LEVEL))


## The height the far mesh draws at one place, read off the pyramid at `level`
## and pulled back towards the maxima by far_peak_gain. Level 0 is the raw
## grid, which is the surface the voxels are built from.
static func filtered_height(heightmap: Heightmap, config: WorldgenConfig,
		bx: float, bz: float, level: float) -> float:
	if level <= 0.0:
		return heightmap.height_at(bx, bz)
	var mean := heightmap.height_filtered(bx, bz, level)
	var gain: float = config.far_peak_gain
	if gain <= 0.0:
		return mean
	return lerpf(mean, heightmap.height_max_filtered(bx, bz, level), gain)


## The zone the far mesh paints past ring 0: altitude alone, no jitter and a
## dither of exactly 0.5, with the slope override kept. See _far_zone above,
## which carries the reasoning.
static func backdrop_zone(generator: TerrainGenerator, bx: int, bz: int,
		altitude: float) -> int:
	return generator._slope_zone(bx, bz, generator.zone_at(altitude, 0.0, 0.5))


## The band the treeline falls in. Read from the generator's own thresholds
## rather than re-derived, so the bands agree with where the forest stops.
##
## `band_m` overrides config.far_band_m, which distance v2 Stage 7 needs: the
## band interval is now per RING, so the band the treeline falls in is too.
static func treeline_band(generator: TerrainGenerator,
		config: WorldgenConfig, band_m := 0.0) -> int:
	var m := band_m if band_m > 0.0 else config.far_band_m
	if m <= 0.0 or generator == null \
			or generator.zone_thresholds.size() <= TerrainGenerator.ZONE_FOREST:
		return 0
	var treeline_m: float = \
		generator.zone_thresholds[TerrainGenerator.ZONE_FOREST] * config.block_size
	return int(floor(treeline_m / m))


## The altitude band applied to one colour. See _band_color above.
static func band_color(color: Color, y_m: float, config: WorldgenConfig,
		band_treeline: int, band_m := 0.0) -> Color:
	var step_amount: float = config.far_band_step
	if step_amount <= 0.0 or config.far_band_m <= 0.0:
		return color
	var m := band_m if band_m > 0.0 else config.far_band_m
	if m <= 0.0:
		return color
	# THE TOTAL VALUE CHANGE IS THE CONSTANT, NOT THE PER-BAND STEP. Distance v2
	# Stage 7 takes the interval from 60 m to a ring's own cell width - 16 m at
	# ring 2, about four times as many bands - and far_band_step at 0.03 per
	# band would be four times too strong at that density. Scaling it by the
	# same ratio keeps the value change per METRE of altitude exactly where look
	# v1 and look v2 put it, and keeps the 0.85-1.25 clamp landing at the same
	# altitudes. It also makes far_band_step still mean what its label says.
	step_amount *= m / config.far_band_m
	var band := int(floor(y_m / m))
	var k := clampf(1.0 + step_amount * float(band - band_treeline), 0.85, 1.25)
	return Color(color.r * k, color.g * k, color.b * k, color.a)


## THE ALTITUDE BAND INTERVAL AT ONE DISTANCE, in metres. Distance v2 Stage 7,
## decision 7.
##
## The colour has been drawing contour steps since look v1 - one band per quad,
## "which is what makes the band edge a hard stepped line along the quad grid
## rather than a gradient interpolated across it". It was drawing them onto a
## SMOOTH slope, so the band edge wandered along the triangle grid: that is the
## chevron zigzag where snow meets rock in Marcel's shot, the colour saying
## terraced while the shape said smooth.
##
## Lock the interval to the ring's own step height and the two stop fighting:
## a band boundary is a shelf boundary, so it lands on a riser. 60 m -> 16 m at
## ring 2.
##
## LERPED BY far_terrace RATHER THAN SWITCHED, so at 0.0 it is exactly 60 m and
## hard rule 1 holds for the colour as well as for the geometry. There is no
## point locking bands to shelves that are not being drawn.
static func band_m_at(config: WorldgenConfig, step_blocks: int,
		terrace: float) -> float:
	if terrace <= 0.0:
		return config.far_band_m
	return lerpf(config.far_band_m, float(step_blocks) * config.block_size,
		clampf(terrace, 0.0, 1.0))


## THE WHOLE BACKDROP COLOUR AT ONE PLACE, in LINEAR, before the wire
## conversion and before the per-vertex jitter and aspect shade.
##
## What an impostor converges towards. It reads the FILTERED height rather than
## the raw one on purpose: the question this answers is "what colour is the
## mountain the eye sees behind this tree", and the mountain the eye sees is
## the one drawn off the pyramid. Near a summit the two differ by tens of
## blocks - that is Stage 0's PEAK LOSS - and a tree that converged towards the
## true ground's zone while the far mesh beside it drew a different one would
## be a green cone on a grey slope, which is the artefact this is here to
## remove.
static func backdrop_color(heightmap: Heightmap, generator: TerrainGenerator,
		config: WorldgenConfig, bx: int, bz: int, d_m: float,
		band_treeline: int) -> Color:
	var h := filtered_height(heightmap, config, float(bx), float(bz),
		level_at_distance(config, d_m))
	var zone := backdrop_zone(generator, bx, bz, h)
	# THE SAME BAND INTERVAL THE MESH USES AT THIS DISTANCE, distance v2
	# Stage 7. An impostor converges towards the colour the far mesh paints
	# behind it, and if the two disagreed about where a band edge is the tree
	# would converge towards a colour that is not there.
	var bm := band_m_at(config, ring_step_blocks(config, d_m),
		clampf(config.far_terrace, 0.0, 1.0))
	var tl := band_treeline
	if bm != config.far_band_m:
		tl = treeline_band(generator, config, bm)
	return band_color(Block.color_of(TerrainGenerator.ZONE_SURFACE[zone]),
		h * config.block_size, config, tl, bm)


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
## `d_m` decides the ring and therefore the step. FarTrees centres on the
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
	var h := _cell_height_at(heightmap, config, cx, cz, level)
	var fstep := float(step)
	var r := maxi(RIDGE_SPAN_BLOCKS / step, 1) * step
	var ridge := h >= _cell_height_at(heightmap, config, cx - r, cz, level) \
		and h >= _cell_height_at(heightmap, config, cx + r, cz, level) \
		and h >= _cell_height_at(heightmap, config, cx, cz - r, level) \
		and h >= _cell_height_at(heightmap, config, cx, cz + r, level)
	var hq: float = (ceil(h / fstep) if ridge else round(h / fstep)) * fstep
	return amount * (hq - h)


## One cell-centre height off the terrace level, with the peak gain - the static
## twin of _cell_h().
static func _cell_height_at(heightmap: Heightmap, config: WorldgenConfig,
		bx: int, bz: int, level: float) -> float:
	var h := heightmap.height_filtered(float(bx), float(bz), level)
	var gain: float = config.far_peak_gain
	if gain <= 0.0:
		return h
	return lerpf(h, heightmap.height_max_filtered(float(bx), float(bz), level), gain)
