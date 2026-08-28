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
const RING_OUTER_M := [200.0, 400.0]

## Blocks per vertex in each ring, as a multiple of config.far_step. At the
## default far_step of 8 blocks that is 4, 8 and 16 metres per vertex.
const RING_STEP_MULTIPLE := [1, 2, 4]

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
## 4 cells is 32 blocks, 16 m at the default far_step. Long enough that the
## fade is not itself an edge, short enough that the extra noise samples are a
## few hundred quads on a ring of tens of thousands.
const SEAM_BAND_CELLS := 4.0

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

var heightmap: Heightmap = null
var generator: TerrainGenerator = null
var config: WorldgenConfig = null

## Block position the disc is centred on.
var center := Vector2i.ZERO

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
const FRONTIER_OVERLAP_CELLS := 8

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
	var base_step: int = config.far_step
	# The treeline's band, once. zone_thresholds[ZONE_FOREST] is the top of the
	# forest zone in BLOCKS; _band_color works in metres.
	_band_treeline = treeline_band(generator, config)
	var far_radius := config.fog_end_m / bs * FOG_MARGIN
	# DISTANCE V2 STAGE 0. Read once per job rather than per quad: it is a knob
	# on a shared config that the main thread can write while this worker runs,
	# and a value that changed half way through a build would terrace half a
	# mesh.
	_t_amount = clampf(config.far_terrace, 0.0, 1.0)
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
	var exclude := maxf(voxel_radius_blocks - float(2 * base_step), 0.0)
	_seam_radius = exclude
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
			if _t_full:
				hq = _t_hq[_cell(i, j)]
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
			var zone_h := mid_h
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
			if ring > 1 and config.far_zone_cell_m > 0.0:
				var cell_m := maxf(config.far_zone_cell_m,
					config.far_zone_cell_ratio * zone_d_m)
				var cell := maxi(int(round(cell_m / bs)), step)
				zone_bx = Chunk.floor_div(bx0, cell) * cell + cell / 2
				zone_bz = Chunk.floor_div(bz0, cell) * cell + cell / 2
				# THE ZONE READS THE FILTERED HEIGHT TOO. It decided the quad's
				# colour off the raw 2 m grid while the quad's own corners came
				# off the pyramid, so the paint was sampled from a surface the
				# geometry no longer had.
				zone_h = _filtered(zone_bx, zone_bz, 0.0)
			var zone := _far_zone(zone_bx, zone_bz, zone_h, ring)
			var color := Block.color_of(TerrainGenerator.ZONE_SURFACE[zone])

			# THE BACKDROP, look v1. One altitude band per quad - so the band
			# edges are the quad edges, a hard stepped contour rather than a
			# gradient across the quad - and a lighting normal from the slope
			# of the whole flank rather than of this one facet. See the two
			# helpers below.
			color = _band_color(color, mid_h * bs)
			var flank := _flank_normal(bx0 + step / 2, bz0 + step / 2)

			_push_quad(p0, p1, p2, p3, color, verts, normals, colors, indices, flank)

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
			var riser := Color(color.r * config.far_riser_shade,
				color.g * config.far_riser_shade,
				color.b * config.far_riser_shade, color.a)
			for e in edges:
				var nbx: int = bx0 + e[2]
				var nbz: int = bz0 + e[3]
				if not _in_ring(nbx, nbz, step, inner, outer):
					_push_skirt(e[0], e[1], skirt_drop, shaded,
						verts, normals, colors, indices)
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
					riser, verts, normals, colors, indices)


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
func _far_zone(bx: int, bz: int, altitude: float, ring: int) -> int:
	if ring == 0:
		return generator.surface_zone_at(bx, bz, altitude)
	return backdrop_zone(generator, bx, bz, altitude)


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
func _band_color(color: Color, y_m: float) -> Color:
	return band_color(color, y_m, config, _band_treeline)


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
	return h * bs + y_offset * (1.0 - blend)


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
	var step := float(_t_step)
	var h := _cell_h(i, j)
	# STAGE 4, decision 9: round UP at a local maximum of the flank, to nearest
	# everywhere else. Every result is still an exact multiple of the step, so
	# the step ladder and Stage 1's gate are untouched.
	_t_hq[at] = (ceil(h / step) if _is_ridge(i, j, h) else round(h / step)) * step
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
	var blend := clampf(
		1.0 - (sqrt(dx * dx + dz * dz) - _seam_radius) / _t_band, 0.0, 1.0)
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
## Drawn BOTH WAYS ROUND for the same reason a skirt is: see above. A riser
## faces the lower neighbour, so correct single-sided winding would be visible
## from the only side you can see it from - but "the only side you can see it
## from" is an argument about occlusion, and a riser that faces the wrong way is
## invisible, which looks exactly like the crack it was meant to cover.
func _push_riser(a: Vector3, b: Vector3, drop_a: float, drop_b: float,
		color: Color, verts: PackedVector3Array, normals: PackedVector3Array,
		colors: PackedColorArray, indices: PackedInt32Array) -> void:
	var a_down := a - Vector3(0.0, drop_a, 0.0)
	var b_down := b - Vector3(0.0, drop_b, 0.0)
	_push_quad(a, b, b_down, a_down, color, verts, normals, colors, indices)
	_push_quad(a_down, b_down, b, a, color, verts, normals, colors, indices)


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
static func treeline_band(generator: TerrainGenerator,
		config: WorldgenConfig) -> int:
	if config.far_band_m <= 0.0 or generator == null \
			or generator.zone_thresholds.size() <= TerrainGenerator.ZONE_FOREST:
		return 0
	var treeline_m: float = \
		generator.zone_thresholds[TerrainGenerator.ZONE_FOREST] * config.block_size
	return int(floor(treeline_m / config.far_band_m))


## The altitude band applied to one colour. See _band_color above.
static func band_color(color: Color, y_m: float, config: WorldgenConfig,
		band_treeline: int) -> Color:
	var step_amount: float = config.far_band_step
	if step_amount <= 0.0 or config.far_band_m <= 0.0:
		return color
	var band := int(floor(y_m / config.far_band_m))
	var k := clampf(1.0 + step_amount * float(band - band_treeline), 0.85, 1.25)
	return Color(color.r * k, color.g * k, color.b * k, color.a)


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
	return band_color(Block.color_of(TerrainGenerator.ZONE_SURFACE[zone]),
		h * config.block_size, config, band_treeline)


## THE RING'S CELL WIDTH AT ONE DISTANCE, in blocks - which is also that ring's
## terrace step height, by decision 4's cubic lock. Distance v2 Stage 5.
static func ring_step_blocks(config: WorldgenConfig, d_m: float) -> int:
	var step: int = config.far_step
	for i in RING_OUTER_M.size():
		if d_m < RING_OUTER_M[i]:
			return step * RING_STEP_MULTIPLE[i]
	return step * RING_STEP_MULTIPLE[RING_STEP_MULTIPLE.size() - 1]


## The one pyramid level the terrace is cut from - see _t_level, which is this
## expression written out for the reason given there.
static func terrace_level(heightmap: Heightmap, config: WorldgenConfig) -> float:
	var ring := clampi(TERRACE_LEVEL_RING, 0, RING_STEP_MULTIPLE.size() - 1)
	return clampf(log(float(config.far_step * RING_STEP_MULTIPLE[ring])
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
	var band := float(config.far_step) * SEAM_BAND_CELLS
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
