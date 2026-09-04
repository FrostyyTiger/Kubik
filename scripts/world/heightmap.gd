class_name Heightmap
extends RefCounted

## The whole world's surface altitude, sampled once at startup on a coarse grid.
##
## WHY A GLOBAL HEIGHTMAP AT ALL. Per-chunk generation is the obvious design and
## it makes three things impossible:
##
##   * LAKES. A basin is a depression with a rim all the way around it. You
##     cannot see one by looking at a 16-block chunk, any more than you can find
##     a valley by staring at one paving stone.
##   * THE FAR FIELD. 200 m of view distance is ~30,000 chunks of voxels. It is
##     affordable only as one low-poly mesh, and that mesh has to come from
##     somewhere that already knows the terrain a kilometre away.
##   * A MINIMAP, later, for free.
##
## The cost is one 750x750 array of floats - 2.25 MB and about 650 ms of noise
## on a 2018 desktop CPU. That is cheap enough to simply do, which is the whole
## argument for a bounded world: an infinite one could never afford this, and
## everything above is worth more than infinity is.
##
## Resolution is one sample per 4 blocks (2 m). Per-block roughness is added
## later, at voxel time, and deliberately is NOT in here - see TerrainGenerator.

## Altitudes in blocks, row-major: index = i + j * cols.
var cells := PackedFloat32Array()

## Cells per side.
var cols := 0

## Blocks per cell.
var step := 4

## Block coordinate of cell 0 on both axes. The world is centred on the origin,
## so this is negative.
var min_block := 0

var _max_block := 0


# --- TILES, distance v5 Stage 4 ----------------------------------------------
#
# WHY, AND IT IS NOT PERFORMANCE. `CLAUDE.md` § Worldgen guidance: "The world is
# unbounded by design ... No new system may bake in a world edge, a global
# heightmap, or any global-extent assumption - heightmaps and lakes go regional
# (tiled) as the world opens." The height map is the global heightmap that
# sentence is about.
#
# WHAT A TILE IS HERE. A square of world, `tile_blocks` on a side, ANCHORED TO
# THE ORIGIN rather than to this region's corner - so a tile has the same
# identity whatever region is loaded, which is the property an unbounded world
# needs and a region-relative grid cannot have. Tiles are the unit the map is
# BUILT in, the unit the C++ builder is handed, and the unit a build is timed
# in.
#
# WHAT THIS DOES NOT DO YET, stated plainly rather than implied: the tiles
# still write into ONE region array, `cells`, and every existing reader -
# lakes, spawn, the probes, the C++ far mesher's marshal - still indexes that
# array as `i + j * cols`. So the global-extent assumption has moved out of the
# BUILDER and not yet out of the STORE. Making each tile own its own array is
# a change across eight files whose gate is a byte-identical world, and it buys
# nothing until a second region exists. See docs/status/distance-v5.md.
#
# THE APRON, likewise: the pyramid is built over the region in one pass, so it
# cannot see a tile seam - there is nothing between two tiles to see. An apron
# becomes necessary on the day tiles stop sharing an array, and the note is
# here so that day starts from a sentence rather than from a bug report.

## Blocks per tile edge. From `config.heightmap_tile_blocks`, and a multiple of
## `step` - a tile that ended mid-cell would put one cell in two tiles.
var tile_blocks := 512

## Tile index range covering this region, inclusive, on both axes.
var tile_lo := 0
var tile_hi := 0


func _init(config: WorldgenConfig) -> void:
	step = config.coarse_step
	cols = int(config.world_blocks_xz / config.coarse_step)
	min_block = -int(config.world_blocks_xz / 2)
	_max_block = min_block + (cols - 1) * step
	cells.resize(cols * cols)
	tile_blocks = maxi(int(config.heightmap_tile_blocks) / step, 1) * step
	tile_lo = Chunk.floor_div(min_block, tile_blocks)
	tile_hi = Chunk.floor_div(_max_block, tile_blocks)


## Tiles per side over this region. The region is not required to be a whole
## number of tiles and generally is not: the tile grid is the WORLD's, and a
## region is however much of it happens to be loaded.
func tile_count() -> int:
	return tile_hi - tile_lo + 1


## The cells of one tile, as a range of cell indices on each axis, clipped to
## this region. `end` is exclusive. Empty when the tile has no cells here.
func tile_cell_rect(tx: int, tz: int) -> Rect2i:
	var lo_x := _cell_ceil(tx * tile_blocks)
	var lo_z := _cell_ceil(tz * tile_blocks)
	var hi_x := _cell_ceil((tx + 1) * tile_blocks)
	var hi_z := _cell_ceil((tz + 1) * tile_blocks)
	lo_x = clampi(lo_x, 0, cols)
	lo_z = clampi(lo_z, 0, cols)
	hi_x = clampi(hi_x, 0, cols)
	hi_z = clampi(hi_z, 0, cols)
	return Rect2i(lo_x, lo_z, maxi(hi_x - lo_x, 0), maxi(hi_z - lo_z, 0))


## The first cell index at or after a block coordinate. `tile_blocks` is a
## multiple of `step` and `min_block` is not necessarily on a tile boundary, so
## this is a ceiling division rather than an exact one.
func _cell_ceil(block: int) -> int:
	return Chunk.floor_div(block - min_block + step - 1, step)


## Block coordinate of a cell index on either axis.
func cell_to_block(i: int) -> int:
	return min_block + i * step


func cell_height(i: int, j: int) -> float:
	return cells[clampi(i, 0, cols - 1) + clampi(j, 0, cols - 1) * cols]


## Altitude in blocks at any block position, interpolated between cells.
##
## Bilinear rather than nearest: at 4 blocks per cell, nearest gives the world
## visible 4-block terraces, and no amount of detail noise hides a staircase
## that big.
func height_at(bx: float, bz: float) -> float:
	# OUTSIDE THE HOME REGION THIS NO LONGER CLAMPS. Horizon v1 Stage 1, D44.
	#
	# Everything below this line is untouched and answers for every position
	# inside the region, bit for bit, which is what the canonical world line
	# proves after every stage. What changed is that a position OUTSIDE it used
	# to be dragged onto the region's rim - `clampf` - and read the edge cell's
	# altitude, so the world had a wall of extruded rim at 3 km whichever way
	# you walked. It now reads the tile store, which builds that ground from
	# the seed on demand.
	#
	# THE TWO GRIDS LINE UP AND THAT IS NOT LUCK. A level-0 tile's cells sit at
	# multiples of `step` anchored to the ORIGIN; the region's sit at
	# `min_block + i * step`, and `min_block` is `-world_blocks_xz / 2`, which
	# is a multiple of `step` for every world this config can describe. So the
	# cell at block -3000 is the same cell in both, the bilinear is continuous
	# across the boundary, and there is no seam to hide.
	if bx < float(min_block) or bx > float(_max_block) \
			or bz < float(min_block) or bz > float(_max_block):
		return _tile_bilinear(0, bx, bz, false, {})
	return _region_bilinear(bx, bz)


## The region's own bilinear, exactly as it has read since terrain v1 -
## clamping and all. Lifted out of `height_at` unchanged so that the far mesh's
## own door (`far_height_at`) and the rim fallback read the SAME expression
## rather than a second copy of it that could drift.
func _region_bilinear(bx: float, bz: float) -> float:
	var fx := (clampf(bx, float(min_block), float(_max_block)) - min_block) / float(step)
	var fz := (clampf(bz, float(min_block), float(_max_block)) - min_block) / float(step)

	var i0 := int(floor(fx))
	var j0 := int(floor(fz))
	var tx := fx - float(i0)
	var tz := fz - float(j0)
	var i1 := mini(i0 + 1, cols - 1)
	var j1 := mini(j0 + 1, cols - 1)

	var h00 := cells[i0 + j0 * cols]
	var h10 := cells[i1 + j0 * cols]
	var h01 := cells[i0 + j1 * cols]
	var h11 := cells[i1 + j1 * cols]

	return lerpf(lerpf(h00, h10, tx), lerpf(h01, h11, tx), tz)


## Local ground steepness in DEGREES at any block position.
##
## Central differences over one cell either side, so it is the drop across two
## cells rather than to one neighbour - a one-sided difference on noise is half
## measurement and half which direction you happened to look. Both rise and run
## are in blocks, so the ratio is dimensionless and block_size cancels.
##
## Reads the interpolated surface rather than the raw cells, which means it is
## defined between cells too and gives the same answer to the zone code, the
## probe and anything else that asks.
## `far` picks the door - horizon v1 Stage 1. The far mesh must never reach a
## door that BUILDS a tile: it has a second leg in C++ that cannot build one,
## and a slope read that quietly conjured ground on this side and not on that
## one is two different mountains. See the note by `_far_tiles`. Defaulted
## false, so every caller that was here before this line is unchanged.
func slope_deg_at(bx: float, bz: float, far := false, view := {}) -> float:
	var d := float(step)
	if far:
		var fgx := (far_height_at(bx + d, bz, view)
			- far_height_at(bx - d, bz, view)) / (2.0 * d)
		var fgz := (far_height_at(bx, bz + d, view)
			- far_height_at(bx, bz - d, view)) / (2.0 * d)
		return rad_to_deg(atan(sqrt(fgx * fgx + fgz * fgz)))
	var gx := (height_at(bx + d, bz) - height_at(bx - d, bz)) / (2.0 * d)
	var gz := (height_at(bx, bz + d) - height_at(bx, bz - d)) / (2.0 * d)
	return rad_to_deg(atan(sqrt(gx * gx + gz * gz)))


## Is this block position inside the HOME REGION - the 3 km the lakes, the
## spawn and the zone thresholds are computed over?
##
## RENAMED FROM `in_bounds`, horizon v1 Stage 1, and the rename is the point.
## "In bounds" was a statement about the WORLD and it stopped being true the
## moment `height_at` answered everywhere: there is no out of bounds now, and a
## caller asking this question is asking about the region's bookkeeping - the
## lakes, the spawn, the zone histogram - and not about whether ground exists.
## Every remaining caller is one of those, or the far mesh's own quad cull,
## which Stage 3 replaces with a ring test.
func in_home_region(bx: int, bz: int) -> bool:
	return bx >= min_block and bz >= min_block \
		and bx <= _max_block + step - 1 and bz <= _max_block + step - 1


# --- THE FILTERED PYRAMID, distance v1 Stage 1 -------------------------------
#
# A MIPMAP, IN GEOMETRY. `cells` is a 2 m grid, and the far mesh samples it
# every 8 or 16 m and keeps whatever lands on the lattice - a texture read
# without mipmaps, which is exactly the fault distance v1 exists to fix. Ridges
# are spiky because a summit survives by luck rather than by height, and a
# range changes shape as you walk because each LOD ring re-samples it from a
# different lattice.
#
# So: levels, each a 2x2 box mean of the one below. Level 0 is `cells` at 2 m;
# level 1 is 4 m, 2 is 8, 3 is 16, 4 is 32, 5 is 64. Successive box filters
# approximate a Gaussian, which is what mip generation has always been and is
# good enough here.
#
# IT IS DERIVED AND IT IS NEVER WRITTEN BACK. Hard rule 3 of the plan: `cells`
# is untouched, hash_key() is untouched, and nothing that decides what the
# world IS - zones, lakes, spawn, tree placement, the voxel surface - reads a
# level above 0. The pyramid lives next to `cells` for the same reason a mipmap
# lives next to a texture, and for no other reason.
#
# WEIGHTED, AND THAT IS WHAT MAKES THE MEAN CONSERVE EXACTLY. 1500 halves to
# 750, 375, 188, 94, 47 - and 375 is odd, so the last cell of level 3 has only
# one parent rather than two. Averaging it against a duplicated edge cell would
# double-count that column and shift the mean; averaging it alone and carrying
# how many level-0 cells sit under each cell does not. The weight is analytic -
# it depends only on the index and the level - so it costs no memory, and the
# self-test asserts what it buys: the weighted mean of every level equals the
# mean of level 0 to float error. A box filter conserves the mean, and if it
# does not the pyramid is wrong.
#
# Cost: levels 1-5 are about 750k cells against level 0's 2.25 M, so a third
# more memory and one pass over a quarter of the data. Measured on ganymede and
# recorded in docs/status/distance-v1.md.

## The coarsest level THE REGION PYRAMID HAS. 5 is 64 m per cell, which is a
## whole mountain flank.
##
## PER-SOURCE SINCE HORIZON V1 STAGE 3. This one is the pyramid's and it is
## bounded by the region: level 5 of a 1500-cell map is 47 cells, and a sixth
## level would be 24, which is a mountain range in four numbers. The TILE store
## has no such bound - a level-9 tile is 128 cells of 1,024 m, built from the
## seed like any other - so the two are named separately and every level clamp
## asks which source it is about. See `TILE_MAX_LEVEL`.
const MAX_LEVEL := 5

## The coarsest level THE TILE STORE builds, and it is the ring table's.
##
## Ring 9 draws 1,024 m cells to 38.4 km (`FarFieldJob.RING_STEP_MULTIPLE`), and
## `_level_at` is log2 of the distance, so the level chooser has to be able to
## ask for 9. Inside the region the pyramid answers and clamps itself to 5,
## which is what keeps the home 3 km drawn exactly as it was.
const TILE_MAX_LEVEL := 9

## Levels 1..MAX_LEVEL. Level 0 is `cells` itself and is never copied.
var _levels: Array[PackedFloat32Array] = []
var _level_cols := PackedInt32Array()

## THE SECOND PYRAMID, distance v1 Stage 3: 2x2 MAX instead of 2x2 mean.
##
## A box filter lowers summits and raises valleys. Stage 0 measured what the
## unfiltered LOD lattice already does to a summit at 600 m - a mean loss of 60
## blocks over the twenty highest - and a mean filter on top of that can only
## make it worse. Drawing `lerp(mean, max, far_peak_gain)` restores amplitude
## WITHOUT restoring high frequency, because the max pyramid is itself smooth
## at that level: it is a dilation, not a sharpen.
##
## It costs one more array of the same size - about 3 MB - and the same single
## pass. Level 0 is `cells` for this one too: the maximum of one cell is itself.
var _max_levels: Array[PackedFloat32Array] = []

## How long build_pyramid() took, in milliseconds. 0 until it has run.
var pyramid_ms := 0

## BUILT LAZILY, UNDER A MUTEX, and it is worth saying why rather than at
## startup with the heightmap.
##
## The only caller is FarFieldJob, which runs on a WorkerThreadPool task. The
## code that FILLS `cells` lives in TerrainGenerator and World, and this epic's
## lane owns neither - see docs/plans/distance-v1.md, "The lane". Building on
## first use keeps the whole pyramid inside this file, and the mutex makes that
## safe whatever thread asks first. FarField runs one job at a time, so in
## practice the lock is uncontended; it is here so that stops being a thing
## somebody has to know.
var _pyramid_mutex := Mutex.new()
var _pyramid_ready := false


## Build every level above 0. Idempotent, and safe from any thread.
func build_pyramid() -> void:
	_pyramid_mutex.lock()
	if _pyramid_ready:
		_pyramid_mutex.unlock()
		return
	var t0 := Time.get_ticks_msec()
	_levels = []
	_max_levels = []
	_level_cols = PackedInt32Array()
	var prev := cells
	var prev_max := cells
	var prev_cols := cols
	# The widths of level 0 are all 1 by definition.
	var prev_w := PackedInt32Array()
	prev_w.resize(cols)
	prev_w.fill(1)
	for level in range(1, MAX_LEVEL + 1):
		var n := (prev_cols + 1) / 2
		var out := PackedFloat32Array()
		out.resize(n * n)
		var out_max := PackedFloat32Array()
		out_max.resize(n * n)
		# The widths, once per level rather than four times per cell. Only the
		# LAST entry can be short, but branching on that inside a loop over
		# 560k cells costs more than the array does.
		var w := PackedInt32Array()
		w.resize(n)
		for i in n:
			var a := i * 2
			w[i] = prev_w[a] + (prev_w[a + 1] if a + 1 < prev_cols else 0)
		for j in n:
			var j0 := j * 2
			var j1 := j0 + 1
			var wj0 := prev_w[j0]
			var wj1 := prev_w[j1] if j1 < prev_cols else 0
			var row0 := j0 * prev_cols
			var row1 := (j1 if j1 < prev_cols else j0) * prev_cols
			var inv_j := 1.0 / float(wj0 + wj1)
			var at := j * n
			for i in n:
				var i0 := i * 2
				var i1 := i0 + 1
				var wi0 := prev_w[i0]
				var wi1 := prev_w[i1] if i1 < prev_cols else 0
				if wi1 == 0:
					i1 = i0
				# The dilation needs no weights: the max of a short run is the
				# max of the cells that are actually there.
				var m := maxf(prev_max[i0 + row0], prev_max[i1 + row0])
				if wj1 > 0:
					m = maxf(m, maxf(prev_max[i0 + row1], prev_max[i1 + row1]))
				out_max[i + at] = m
				out[i + at] = (
					(prev[i0 + row0] * float(wi0) + prev[i1 + row0] * float(wi1))
						* float(wj0)
					+ (prev[i0 + row1] * float(wi0) + prev[i1 + row1] * float(wi1))
						* float(wj1)
				) / float(wi0 + wi1) * inv_j
		_levels.append(out)
		_max_levels.append(out_max)
		_level_cols.append(n)
		prev = out
		prev_max = out_max
		prev_cols = n
		prev_w = w
	pyramid_ms = Time.get_ticks_msec() - t0
	_pyramid_ready = true
	_pyramid_mutex.unlock()


## How many level-0 columns sit under column `i` of `level`. 1 << level for
## every cell but the last, which is short whenever a level had an odd count
## somewhere below it.
func _span(i: int, level: int) -> int:
	var width := 1 << level
	return mini((i + 1) * width, cols) - i * width


## THE PYRAMID, FOR MARSHALLING ACROSS THE GDEXTENSION SEAM. Distance v4.
##
## Three accessors and no logic: the C++ far mesher is handed the levels as
## plain arrays once per world (decision 2, data in and arrays out), and
## reaching into `_levels` from another file would make the underscore a lie.
## Level 0 is `cells` and is deliberately NOT in here - it is never copied, and
## the caller already has it.
##
## Call build_pyramid() first; these return what exists, which before that is
## nothing.
func pyramid_levels() -> Array[PackedFloat32Array]:
	return _levels


func pyramid_max_levels() -> Array[PackedFloat32Array]:
	return _max_levels


func pyramid_level_cols() -> PackedInt32Array:
	return _level_cols


## Cells per side at one level.
func level_cols(level: int) -> int:
	if level <= 0:
		return cols
	return _level_cols[mini(level, MAX_LEVEL) - 1]


## Altitude in blocks at any block position, read off one level of the pyramid.
##
## Bilinear, like height_at(), and with the same clamping - but the sample
## POSITIONS move. A level-L cell is the mean of up to 2^L level-0 cells, so it
## stands for the MIDDLE of that run, half a level-0 step short of where cell 0
## of level 0 sits. Ignoring the offset shifts the whole far country by up to
## 15.5 blocks at level 5, which would read as the ground sliding sideways as
## the filter came on - a far worse artefact than the one being fixed.
func height_at_level(bx: float, bz: float, level: int) -> float:
	return _bilinear(bx, bz, level, false)


## The same, off the MAX pyramid. Distance v1 Stage 3.
func height_max_at_level(bx: float, bz: float, level: int) -> float:
	return _bilinear(bx, bz, level, true)


func _bilinear(bx: float, bz: float, level: int, use_max: bool) -> float:
	if level <= 0:
		return height_at(bx, bz)
	# OUTSIDE THE REGION THE PYRAMID DOES NOT REACH, so the level-L tile
	# answers - see the tile store below. Inside, everything from here down is
	# the pyramid this project has read since distance v1, untouched.
	#
	# AND IT READS THE FROZEN VIEW, not the store, which makes this function
	# and `_far_bilinear` the same function above level 0. That is not a
	# compromise: the pyramid EXISTS for the far mesh - grep says
	# `height_filtered`, `height_max_filtered`, `height_at_level` and
	# `height_max_at_level` have exactly one caller between them outside this
	# file, and it is `selftest.gd`'s parity harness - so a "near" door onto it
	# would be a door nothing walks through that could still disagree with the
	# C++ leg. Level 0 is different and keeps its building door, because the
	# VOXEL world reads it and the ground has to follow the player.
	if bx < float(min_block) or bx > float(_max_block) \
			or bz < float(min_block) or bz > float(_max_block):
		return _tile_bilinear(mini(level, MAX_LEVEL), bx, bz, use_max, far_view())
	if not _pyramid_ready:
		build_pyramid()
	return _pyramid_bilinear(bx, bz, mini(level, MAX_LEVEL), use_max)


## One level of the pyramid, exactly as `_bilinear` has read it since distance
## v1. Lifted out unchanged, for the reason `_region_bilinear` was: the far
## mesh's own door and the rim fallback read this expression rather than a
## copy. `level` is already clamped to MAX_LEVEL and is at least 1; the
## pyramid is already built.
func _pyramid_bilinear(bx: float, bz: float, l: int, use_max: bool) -> float:
	var n := _level_cols[l - 1]
	var data: PackedFloat32Array = _max_levels[l - 1] if use_max else _levels[l - 1]
	var lstep := float(step << l)
	# Cell 0 of this level is centred half a level-0 step past min_block, plus
	# half its own extra width.
	var origin := float(min_block) + (lstep - float(step)) * 0.5
	var hi := origin + float(n - 1) * lstep

	var fx := (clampf(bx, origin, hi) - origin) / lstep
	var fz := (clampf(bz, origin, hi) - origin) / lstep
	var i0 := int(floor(fx))
	var j0 := int(floor(fz))
	var tx := fx - float(i0)
	var tz := fz - float(j0)
	i0 = clampi(i0, 0, n - 1)
	j0 = clampi(j0, 0, n - 1)
	var i1 := mini(i0 + 1, n - 1)
	var j1 := mini(j0 + 1, n - 1)

	var h00 := data[i0 + j0 * n]
	var h10 := data[i1 + j0 * n]
	var h01 := data[i0 + j1 * n]
	var h11 := data[i1 + j1 * n]
	return lerpf(lerpf(h00, h10, tx), lerpf(h01, h11, tx), tz)


## Trilinear: bilinear on two adjacent levels, blended by the fraction.
##
## The point of a CONTINUOUS level rather than one level per LOD ring: adjacent
## vertices get adjacent levels, so the drawn surface stays continuous and a
## mountain does not re-cut itself when it crosses a ring boundary. See
## FarFieldJob._level_at().
func height_filtered(bx: float, bz: float, level: float) -> float:
	return _trilinear(bx, bz, level, false)


## The same, off the MAX pyramid. Distance v1 Stage 3.
func height_max_filtered(bx: float, bz: float, level: float) -> float:
	return _trilinear(bx, bz, level, true)


func _trilinear(bx: float, bz: float, level: float, use_max: bool) -> float:
	var l := clampf(level, 0.0, float(MAX_LEVEL))
	var lo := int(floor(l))
	var f := l - float(lo)
	if f <= 0.0001 or lo >= MAX_LEVEL:
		return _bilinear(bx, bz, lo, use_max)
	return lerpf(_bilinear(bx, bz, lo, use_max),
		_bilinear(bx, bz, lo + 1, use_max), f)


## Mean of one level, weighted by how many level-0 cells sit under each cell.
##
## The pyramid's conservation law, and the self-test's whole content: a box
## filter conserves the mean, so this must equal stats()["mean"] at every level.
func level_weighted_mean(level: int) -> float:
	if level <= 0:
		var total0 := 0.0
		for h in cells:
			total0 += h
		return total0 / float(cells.size())
	if not _pyramid_ready:
		build_pyramid()
	var l := mini(level, MAX_LEVEL)
	var n := _level_cols[l - 1]
	var data := _levels[l - 1]
	var total := 0.0
	var weight := 0.0
	for j in n:
		var wj := float(_span(j, l))
		for i in n:
			var w := float(_span(i, l)) * wj
			total += data[i + j * n] * w
			weight += w
	return total / weight


# --- THE TILE STORE, horizon v1 Stage 1 --------------------------------------
#
# THE HEIGHT MAP STOPS BEING ONE ARRAY WITH AN EDGE. D44: "the terrain is
# seeded and has no wall and no edge; no system may bake in a world edge, a
# global heightmap or a global-extent assumption". Distance v5 Stage 4 moved
# the BUILDER onto tiles and said so in as many words at the top of this file -
# "the global-extent assumption has moved out of the BUILDER and not yet out of
# the STORE". This is the store.
#
# WHAT A TILE IS. `TILE_CELLS + 1` squared heights covering `tile_blocks << L`
# blocks of world, anchored to the ORIGIN, keyed `(level, tx, tz)`, built on
# demand from the seed and thrown away when the player walks far enough from
# it. Two arrays per tile: the MEAN of the cell, which is what the ground is,
# and the MAX, which is what `far_peak_gain` pulls a summit back towards.
#
# THE +1 IS AN APRON AND IT IS ONE COLUMN WIDE. A bilinear read at the last
# cell of a tile needs the first cell of the next one. Fetching the neighbour
# on the hot path would double the lookups and put a tile build inside a
# bilinear; storing the shared edge twice costs 1.6% of the memory and makes a
# tile a self-contained answer. It is not a copy of the neighbour's data - it
# is the same pure function of the same position, quantised the same way, so
# the two agree bit for bit and the seam is not a seam.
#
# LEVEL 0 IS NEVER SUPERSAMPLED, and that is a ruling rather than a detail.
# The plan says a level-L cell is the mean of a `far_supersample` square of
# `raw_height`, and applied to level 0 that would make the ground OUTSIDE the
# region a filtered version of the ground INSIDE it - a step at the region's
# rim of however much a 2 m box filter removes, which on a steep flank is a
# metre. Level 0 is the surface the voxels are built from and it must be one
# function everywhere, so it is one sample per cell: `build_tile` at
# supersample 1 is `height_at_block`, exactly, which is the plan's own
# "supersample = 1 is bit-identical to today". Supersampling is a FILTER and
# belongs to the levels that are filters, which is 1 and up. Recorded under
# "Questions taken alone" in docs/status/horizon-v1.md.
#
# WHAT IT IS NOT: it is not a cache with a truth behind it. Determinism makes
# the cache a convenience - a tile thrown away and rebuilt is the same bytes -
# and that is what lets eviction be a memory decision rather than a correctness
# one.

## Cells per tile side. The plan's number, at every level.
const TILE_CELLS := 128

## What a far-mesh read does when the tile it wants is not in the store.
##
## IT DOES NOT BUILD ONE, and the reason is parity rather than cost. The far
## mesh has two legs - `FarFieldJob` here and `far_build.cpp` across the seam -
## and the C++ leg cannot build a tile: it is handed a map of them once per
## build and has no generator. So if the GDScript leg built on a miss and the
## C++ leg fell back, the two would draw different mountains and the far parity
## gate would fail for a reason that is nothing to do with the mesher.
##
## One rule, both legs: **a far-mesh read never builds a tile, and a missing
## tile reads the region's clamped rim** - which is exactly what this file did
## everywhere before tonight, so a far mesh with nothing prepared is the far
## mesh this project shipped. `FarField` prepares what a build will read
## through `ensure_disc`, on the main thread, before the job is submitted.
##
## The VOXEL world has no such constraint - there is one leg and it is this one
## - so `height_at` builds on demand and the ground follows the player.

## The store. `Vector3i(level, tx, tz)` -> the cell heights, row-major over
## `TILE_CELLS + 1` columns.
var _tiles := {}
var _tiles_max := {}

## THE FAR MESH'S VIEW OF THE STORE, AND WHY IT IS A SECOND DICTIONARY.
##
## The far mesh has two legs and they must read the SAME tiles. The C++ leg is
## handed its tiles when the build is submitted; the GDScript leg reads this
## file live. So a tile that appears WHILE a build is running - and one will,
## because every chunk column job outside the region builds tiles as the player
## walks - would be read by the GDScript leg and not by the C++ one, and the
## far parity gate would fail on a race that reproduces once a night.
##
## So the far mesh reads a PUBLISHED view: a shallow copy of the store taken on
## the main thread by `publish_far_view()` immediately before a build is
## submitted, and marshalled to C++ in the same breath. Shallow is enough - a
## `PackedFloat32Array` is copy-on-write and nothing ever writes into a
## published tile - so the copy is a few dozen references and costs nothing.
##
## Read under the same mutex the store is, because a GDScript Dictionary
## assignment is not documented as atomic and the alternative is a race that
## would show up as a far mesh with one wrong quad.
var _far_tiles := {}
var _far_tiles_max := {}

## THE LOCK, AND WHAT IT DOES NOT COVER. Workers read this store - every chunk
## column job calls `height_at` - and the main thread writes it. The mutex
## guards the DICTIONARY and nothing else: a tile is built outside the lock,
## from a pure function of its own position, and published under it.
##
## Two threads can therefore build the same tile at once. That is wasteful
## exactly once per tile and it is never wrong, because both produce the same
## bytes; holding the lock across a build instead would put a forty-millisecond
## stall in front of every other worker and, on the main thread, in front of a
## frame. The plan's failure protocol item 3 - "a thread wrote into a shared
## tile or the cache returned a half-built tile" - is answered by the publish
## being a single dictionary assignment of a finished array.
var _tiles_mutex := Mutex.new()

## The C++ tile builder, when there is one. Held directly because it is a
## RefCounted carrying the engine noise objects and the config and NOTHING that
## points back here - see `height_tiles.gd`.
var _tile_builder: HeightTiles = null

## The generator, weakly, for the GDScript leg of a tile build.
##
## WEAK, and it has to be: the generator holds this heightmap, so a strong
## reference here would be a RefCounted cycle and a leaked 8 MB array per
## reroll. Nothing in a tile build needs the generator to be alive - if it has
## gone, so has the world.
var _generator_ref: WeakRef = null

## TILES THAT ARE NEVER EVICTED. The region's rim, and nothing else yet.
##
## `ensure_region_rim` builds them at load because both legs of the far mesher
## need real ground just past the region's edge; `World._evict_height_tiles`
## would then throw them away on the player's first chunk crossing, because
## they are three kilometres from spawn and the eviction radius is a thousand
## blocks. The far mesh would go back to reading the clamped rim there - not
## WRONG, both legs still agree, but the half second spent building them at
## load would buy exactly one frame of correct edge.
##
## Forty-four tiles, 5.9 MB, fixed for the life of a world. Stage 3 takes the
## pin over as the ring table starts deciding what the far mesh reads.
var _pinned := {}

## Samples per axis inside one cell at level >= 1. `far_supersample`.
var _supersample := 2

## How many tiles have been built this session, and how long they took. For the
## probe line and the memory gate.
var tiles_built := 0
var tile_build_ms := 0


## Hand the store what it needs to build. Called once per world by
## `TerrainGenerator.build_heightmap`, on the main thread, after the region.
func set_tile_source(generator: TerrainGenerator, builder: HeightTiles,
		supersample: int) -> void:
	_generator_ref = weakref(generator)
	_tile_builder = builder
	_supersample = clampi(supersample, 1, 4)


## Blocks across one tile at this level. 512 at level 0, doubling per level, so
## a level-L tile covers 256 x 2^L metres at the half-metre block.
func tile_span_blocks(level: int) -> int:
	return tile_blocks << level


## Blocks between two cells at this level. 4 at level 0, and `TILE_CELLS` of
## them span the tile exactly.
func cell_step_blocks(level: int) -> int:
	return step << level


## The tile a block position falls in, at this level.
func tile_of(level: int, bx: int, bz: int) -> Vector2i:
	var span := tile_span_blocks(level)
	return Vector2i(Chunk.floor_div(bx, span), Chunk.floor_div(bz, span))


## Is this whole tile inside the home region?
##
## Such a tile is never read: the region answers first for every position
## inside itself. `ensure_disc` skips them rather than spending forty
## milliseconds building ground nothing will look at.
func tile_inside_region(level: int, tx: int, tz: int) -> bool:
	var span := tile_span_blocks(level)
	return tx * span >= min_block and tz * span >= min_block \
		and (tx + 1) * span <= _max_block and (tz + 1) * span <= _max_block


## Build the tile if it is not there, and return whether the store has it.
##
## MAIN THREAD OR WORKER, either. See `_tiles_mutex` for the two-phase rule and
## why building the same tile twice is cheaper than the alternative.
func ensure_tile(level: int, tx: int, tz: int) -> bool:
	var key := Vector3i(level, tx, tz)
	_tiles_mutex.lock()
	var have: bool = _tiles.has(key)
	_tiles_mutex.unlock()
	if have:
		return true
	var built := _build_tile_cells(level, tx, tz)
	if built.is_empty():
		return false
	_tiles_mutex.lock()
	# Checked again under the lock: another thread may have published the same
	# tile while this one was building it. Whichever lands first wins, and the
	# two are the same bytes, so there is nothing to choose between them.
	if not _tiles.has(key):
		_tiles[key] = built[0]
		_tiles_max[key] = built[1]
		tiles_built += 1
		tile_build_ms += built[2]
	_tiles_mutex.unlock()
	return true


## Build one tile's two arrays. Pure: the same key gives the same bytes on any
## thread, on any machine, in any order. Returns `[mean, max, ms]`, or empty if
## there is nothing to build with.
func _build_tile_cells(level: int, tx: int, tz: int) -> Array:
	var t0 := Time.get_ticks_msec()
	var n := TILE_CELLS + 1
	var cstep := cell_step_blocks(level)
	var span := tile_span_blocks(level)
	var bx0 := tx * span
	var bz0 := tz * span
	# LEVEL 0 IS ONE SAMPLE PER CELL - see the block comment above. Above it,
	# `_supersample` samples per axis at the sub-cell centres, which is the
	# plan's "half-cell offsets" for s = 2 and generalises to 4.
	var s := 1 if level <= 0 else _supersample
	var mean := PackedFloat32Array()
	var high := PackedFloat32Array()
	var count := n * n
	mean.resize(count)
	high.resize(count)
	var inv := 1.0 / float(s * s)
	for kz in s:
		for kx in s:
			# The sub-sample's offset, in whole blocks. `cstep` is 4 << level
			# and the offsets are `cstep * (2k + 1) / (2s)`, so at s = 2 they
			# are a quarter and three quarters of a cell and land on whole
			# blocks for every level; at s = 4 they need `cstep` divisible by
			# 8, which is every level from 1 up, and level 0 never uses s > 1.
			var ox := cstep * (2 * kx + 1) / (2 * s) if s > 1 else 0
			var oz := cstep * (2 * kz + 1) / (2 * s) if s > 1 else 0
			var part := _raw_tile(bx0 + ox, bz0 + oz, n, cstep)
			if part.size() != count:
				return []
			if kx == 0 and kz == 0:
				for i in count:
					mean[i] = part[i] * inv
					high[i] = part[i]
			else:
				for i in count:
					mean[i] += part[i] * inv
					high[i] = maxf(high[i], part[i])
	# QUANTISED LAST, exactly as `height_at_block` quantises last and for the
	# same reason: 1/1024 of a block is half a millimetre of world and fifteen
	# orders of magnitude larger than the ULP two compilers can differ by, so
	# gcc and MSVC cannot round a mean to two different multiples. At s = 1 the
	# value is already a multiple of the quantum and this is a no-op, which is
	# what makes level 0 bit-identical to `height_at_block`.
	if s > 1:
		for i in count:
			mean[i] = TerrainGenerator.quantise_height(mean[i])
	return [mean, high, Time.get_ticks_msec() - t0]


## `n` x `n` raw heights from a block corner, `cstep` apart. The C++ builder
## when there is one, the generator's own function when there is not - the same
## two legs `TerrainGenerator._build_tile` has had since distance v5, and the
## quantisation inside both is what makes them the same numbers.
func _raw_tile(bx0: int, bz0: int, n: int, cstep: int) -> PackedFloat32Array:
	if _tile_builder != null:
		var got := _tile_builder.build_tile(bx0, bz0, n, n, cstep)
		if got.size() == n * n:
			return got
	var gen: TerrainGenerator = _generator_ref.get_ref() if _generator_ref != null else null
	if gen == null:
		return PackedFloat32Array()
	var out := PackedFloat32Array()
	out.resize(n * n)
	for j in n:
		var bz := float(bz0 + j * cstep)
		var row := j * n
		for i in n:
			out[row + i] = gen.height_at_block(float(bx0 + i * cstep), bz)
	return out


## Bilinear inside one level-L tile.
##
## `prepared_only` is the far mesh's rule - see the note by `_tiles`: it reads
## what is there and falls back to the region's clamped rim rather than
## building, so both legs of the mesher read the same store. `height_at` and
## the voxel world pass false and get ground wherever they ask.
## `view` empty means the live store and a build on a miss - the voxel world's
## door. A view is a job's snapshot and never builds; a missing tile there
## reads the region's clamped rim, which is what the C++ leg does too.
func _tile_bilinear(level: int, bx: float, bz: float, use_max: bool,
		view: Dictionary) -> float:
	var span := tile_span_blocks(level)
	var cstep := cell_step_blocks(level)
	var fbx := int(floor(bx))
	var fbz := int(floor(bz))
	var tx := Chunk.floor_div(fbx, span)
	var tz := Chunk.floor_div(fbz, span)
	var key := Vector3i(level, tx, tz)
	# THE FAR MESH READS THE PUBLISHED VIEW, everything else reads the store -
	# see the note by `_far_tiles`. `may_build` is the same flag: the door that
	# may build is the door that reads the live store.
	var data := _tile_lookup(key, use_max, view)
	if data.is_empty():
		if not view.is_empty():
			return _region_clamped(bx, bz, level, use_max)
		if not ensure_tile(level, tx, tz):
			return _region_clamped(bx, bz, level, use_max)
		data = _tile_lookup(key, use_max, view)
		if data.is_empty():
			return _region_clamped(bx, bz, level, use_max)

	var n := TILE_CELLS + 1
	var fx := (bx - float(tx * span)) / float(cstep)
	var fz := (bz - float(tz * span)) / float(cstep)
	var i0 := clampi(int(floor(fx)), 0, TILE_CELLS - 1)
	var j0 := clampi(int(floor(fz)), 0, TILE_CELLS - 1)
	var u := clampf(fx - float(i0), 0.0, 1.0)
	var v := clampf(fz - float(j0), 0.0, 1.0)
	# i0 + 1 is at most TILE_CELLS, which is the apron column - see the block
	# comment. No neighbour tile is fetched and none is needed.
	var h00 := data[i0 + j0 * n]
	var h10 := data[i0 + 1 + j0 * n]
	var h01 := data[i0 + (j0 + 1) * n]
	var h11 := data[i0 + 1 + (j0 + 1) * n]
	return lerpf(lerpf(h00, h10, u), lerpf(h01, h11, u), v)


## One tile's array, from the live store or from the published view.
## One tile's array. `view` empty means the LIVE store, which is the door that
## may build; a view is a snapshot a job is holding - see `far_view`.
func _tile_lookup(key: Vector3i, use_max: bool, view: Dictionary) -> PackedFloat32Array:
	if not view.is_empty():
		var held: Dictionary = view["max"] if use_max else view["mean"]
		return held.get(key, PackedFloat32Array())
	_tiles_mutex.lock()
	var from: Dictionary = _tiles_max if use_max else _tiles
	var out: PackedFloat32Array = from.get(key, PackedFloat32Array())
	_tiles_mutex.unlock()
	return out


## Freeze what the far mesh may read. MAIN THREAD, immediately before a far
## build is submitted - see the note by `_far_tiles`.
func publish_far_view() -> void:
	_tiles_mutex.lock()
	_far_tiles = _tiles.duplicate()
	_far_tiles_max = _tiles_max.duplicate()
	_tiles_mutex.unlock()


## THE PUBLISHED VIEW ITSELF, as two dictionary references, for a job to hold
## for the length of its run.
##
## WHY A JOB HOLDS IT RATHER THAN ASKING EACH TIME. `publish_far_view` replaces
## these two references; a reader that looked them up per sample could take
## sample 1 from the old view and sample 2 from the new one, and the two legs
## of the mesher would then disagree about ground one of them could see. The
## C++ leg is handed a snapshot at the top of its build by construction - it
## has no other way - and this is how the GDScript leg gets the same deal.
##
## It cost a night to find: the far parity gate went red with a vertex count
## that CHANGED BETWEEN RUNS, because a `FarField` on a worker was publishing a
## new view in the middle of the parity harness's own hand-built job.
##
## References, not copies: a `PackedFloat32Array` is copy-on-write, nothing
## ever writes into a published tile, and `publish_far_view` builds a new
## Dictionary rather than clearing this one - so a job holding the old one
## holds a complete, immutable view for as long as it needs it.
func far_view() -> Dictionary:
	_tiles_mutex.lock()
	var out := {"mean": _far_tiles, "max": _far_tiles_max}
	_tiles_mutex.unlock()
	return out


## Every key in the PUBLISHED view, for the marshal across the seam. The
## published view and not the store, so the two legs of the mesher are handed
## the same set.
func far_view_keys() -> Array:
	_tiles_mutex.lock()
	var out := _far_tiles.keys()
	_tiles_mutex.unlock()
	return out


## One published tile's two arrays, or empty. For the marshal.
func far_view_arrays(key: Vector3i) -> Array:
	_tiles_mutex.lock()
	var a: PackedFloat32Array = _far_tiles.get(key, PackedFloat32Array())
	var b: PackedFloat32Array = _far_tiles_max.get(key, PackedFloat32Array())
	_tiles_mutex.unlock()
	if a.is_empty():
		return []
	return [a, b]


## The rim, as this file read it before tonight. What a far-mesh read gets when
## its tile was not prepared, and what any read gets when there is nothing to
## build with at all.
func _region_clamped(bx: float, bz: float, level: int, use_max: bool) -> float:
	var cx := clampf(bx, float(min_block), float(_max_block))
	var cz := clampf(bz, float(min_block), float(_max_block))
	if level <= 0:
		return _region_bilinear(cx, cz)
	if not _pyramid_ready:
		build_pyramid()
	# CLAMPED TO THE PYRAMID'S OWN TOP, always. This is the fallback a far read
	# takes when its tile is absent, and the level it was asked for may be 9;
	# `_levels` has five entries and asking for the eighth is a crash, not a
	# coarse mountain.
	return _pyramid_bilinear(cx, cz, mini(level, MAX_LEVEL), use_max)


# --- THE FAR MESH'S READS, horizon v1 Stage 1 --------------------------------
#
# The same four questions the far mesh has always asked, through a door that
# never builds a tile. See the note by `_tiles` for why the two legs of the
# mesher must agree about what is in the store, and `ensure_disc` for who fills
# it. In Stage 1 nothing is prepared, so every one of these is the region read
# this project shipped, byte for byte, and the far parity gate says so.

func far_height_at(bx: float, bz: float, view := {}) -> float:
	if bx < float(min_block) or bx > float(_max_block) \
			or bz < float(min_block) or bz > float(_max_block):
		return _tile_bilinear(0, bx, bz, false,
			view if not view.is_empty() else far_view())
	return _region_bilinear(bx, bz)


func far_height_filtered(bx: float, bz: float, level: float, view := {}) -> float:
	return _far_trilinear(bx, bz, level, false, view)


func far_height_max_filtered(bx: float, bz: float, level: float, view := {}) -> float:
	return _far_trilinear(bx, bz, level, true, view)


func far_height_at_level(bx: float, bz: float, level: int, view := {}) -> float:
	return _far_bilinear(bx, bz, level, false, view)


func far_height_max_at_level(bx: float, bz: float, level: int, view := {}) -> float:
	return _far_bilinear(bx, bz, level, true, view)


## THE COARSEST LEVEL THIS POSITION HAS A SOURCE FOR - horizon v1 Stage 3.
##
## Five inside the region, where the pyramid answers; nine outside it, where
## the tile store does. Every level clamp on the far path goes through this,
## because asking for level 8 inside the region would index `_levels[7]` of a
## five-level pyramid - a crash rather than a coarse mountain.
func far_max_level(bx: float, bz: float) -> int:
	if bx < float(min_block) or bx > float(_max_block) \
			or bz < float(min_block) or bz > float(_max_block):
		return TILE_MAX_LEVEL
	return MAX_LEVEL


func _far_bilinear(bx: float, bz: float, level: int, use_max: bool,
		view := {}) -> float:
	if level <= 0:
		return far_height_at(bx, bz, view)
	if bx < float(min_block) or bx > float(_max_block) \
			or bz < float(min_block) or bz > float(_max_block):
		return _tile_bilinear(mini(level, TILE_MAX_LEVEL), bx, bz, use_max,
			view if not view.is_empty() else far_view())
	if not _pyramid_ready:
		build_pyramid()
	return _pyramid_bilinear(bx, bz, mini(level, MAX_LEVEL), use_max)


func _far_trilinear(bx: float, bz: float, level: float, use_max: bool,
		view := {}) -> float:
	var top := far_max_level(bx, bz)
	var l := clampf(level, 0.0, float(top))
	var lo := int(floor(l))
	var f := l - float(lo)
	if f <= 0.0001 or lo >= top:
		return _far_bilinear(bx, bz, lo, use_max, view)
	return lerpf(_far_bilinear(bx, bz, lo, use_max, view),
		_far_bilinear(bx, bz, lo + 1, use_max, view), f)


# --- Keeping the store the right size ----------------------------------------

## Build every tile at `level` that a disc of `radius_blocks` around
## `centre_block` touches, skipping the ones the region already answers for.
##
## MAIN THREAD, before a far build is submitted. This is the whole of "what the
## far mesh is allowed to read": the two legs then see the same store, and a
## position outside it reads the rim rather than disagreeing.
##
## Returns how many tiles it built.
func ensure_disc(level: int, centre_block: Vector2i, radius_blocks: float) -> int:
	var span := tile_span_blocks(level)
	var lo_x := Chunk.floor_div(int(floor(float(centre_block.x) - radius_blocks)), span)
	var hi_x := Chunk.floor_div(int(ceil(float(centre_block.x) + radius_blocks)), span)
	var lo_z := Chunk.floor_div(int(floor(float(centre_block.y) - radius_blocks)), span)
	var hi_z := Chunk.floor_div(int(ceil(float(centre_block.y) + radius_blocks)), span)
	var built := 0
	for tz in range(lo_z, hi_z + 1):
		for tx in range(lo_x, hi_x + 1):
			if tile_inside_region(level, tx, tz):
				continue
			var before := tiles_built
			if ensure_tile(level, tx, tz):
				built += tiles_built - before
	return built


## Build the level-0 tiles that straddle the home region's rim, and publish
## them. Once per world, at load, from `TerrainGenerator.build_heightmap`.
##
## WHY THE RIM IS PREPARED EAGERLY AND NOTHING ELSE IS. The far mesh reads up
## to `RIDGE_SPAN_BLOCKS` past a quad, so a quad at the region's edge samples
## ground the region does not have; its two legs must get the same answer
## there, and the C++ leg can only be handed tiles. Without this the GDScript
## leg builds one on demand through `detail_at`'s shore fade and `_slope_zone`'s
## slope while C++ reads the rim, and the far parity gate finds it - four quads
## at `far_ring_div` 4 and one zone sample in ten thousand, which is exactly
## what the first Stage 1 run of the suite reported.
##
## LEVEL 0 ONLY, and that is not a shortcut. Above level 0 the far mesh reads
## the region's PYRAMID, and outside the region both legs fall back to the same
## clamped pyramid read whether or not a tile exists - so levels 1 and up agree
## by construction and preparing them would cost two seconds a world load to
## change nothing. They are prepared per the ring table from Stage 3, where the
## far mesh actually reaches out.
##
## Cost, seed 42: forty-four tiles of about ten milliseconds, so under half a
## second on a load that already takes twenty-five.
func ensure_region_rim() -> int:
	var span := tile_span_blocks(0)
	var lo_x := Chunk.floor_div(min_block, span)
	var hi_x := Chunk.floor_div(_max_block, span)
	var lo_z := lo_x
	var hi_z := hi_x
	var built := 0
	for tz in range(lo_z, hi_z + 1):
		for tx in range(lo_x, hi_x + 1):
			# Wholly inside means the region answers for every position in it and
			# nothing will ever read the tile.
			if tile_inside_region(0, tx, tz):
				continue
			var before := tiles_built
			if ensure_tile(0, tx, tz):
				built += tiles_built - before
				_pinned[Vector3i(0, tx, tz)] = true
	publish_far_view()
	return built


## Drop every tile at `level` whose centre is further than `radius_blocks` from
## `centre_block`.
##
## A MEMORY DECISION AND NOT A CORRECTNESS ONE. A tile is a pure function of
## its key, so throwing one away costs a rebuild and nothing else - which is
## what makes it safe to be aggressive here and what failure protocol item 12
## is about.
func evict_beyond(level: int, centre_block: Vector2i, radius_blocks: float) -> int:
	var span := tile_span_blocks(level)
	var half := float(span) * 0.5
	var r2 := radius_blocks * radius_blocks
	var doomed: Array[Vector3i] = []
	_tiles_mutex.lock()
	for key in _tiles:
		var k: Vector3i = key
		if k.x != level:
			continue
		var dx := float(k.y) * float(span) + half - float(centre_block.x)
		var dz := float(k.z) * float(span) + half - float(centre_block.y)
		if _pinned.has(k):
			continue
		if dx * dx + dz * dz > r2:
			doomed.append(k)
	for k in doomed:
		_tiles.erase(k)
		_tiles_max.erase(k)
		# AND OUT OF THE PUBLISHED VIEW, or the far mesh would keep drawing
		# ground the store has forgotten and the C++ side would keep its copy
		# of it forever. The next `publish_far_view` would do this anyway;
		# doing it here means eviction frees the memory now rather than at the
		# next rebuild.
		_far_tiles.erase(k)
		_far_tiles_max.erase(k)
	_tiles_mutex.unlock()
	return doomed.size()


## How many tiles are held, and how much they weigh. The sprint probe's memory
## line and the plan's 300 MB gate are read off this.
func tile_stats() -> Dictionary:
	_tiles_mutex.lock()
	var n := _tiles.size()
	_tiles_mutex.unlock()
	var per := (TILE_CELLS + 1) * (TILE_CELLS + 1) * 4
	return {
		"tiles": n,
		# Two arrays per tile - the mean and the max.
		"bytes": n * per * 2,
		"built": tiles_built,
		"build_ms": tile_build_ms,
	}


## Every tile key the store holds, for the marshal across the GDExtension seam.
func tile_keys() -> Array:
	_tiles_mutex.lock()
	var out := _tiles.keys()
	_tiles_mutex.unlock()
	return out


## One tile's two arrays, or empty. For the marshal.
func tile_arrays(key: Vector3i) -> Array:
	_tiles_mutex.lock()
	var a: PackedFloat32Array = _tiles.get(key, PackedFloat32Array())
	var b: PackedFloat32Array = _tiles_max.get(key, PackedFloat32Array())
	_tiles_mutex.unlock()
	if a.is_empty():
		return []
	return [a, b]


# --- The determinism guard --------------------------------------------------

## A fingerprint of every altitude in the world.
##
## This is the automated form of the rule that matters most. Terrain is never
## sent over the network - both machines regenerate it from a seed - so a
## single unseeded call, or a dependence on iteration order, means two players
## walk different worlds and NEITHER MACHINE REPORTS AN ERROR. You would just
## see your friend swimming through a mountain.
##
## Hashing the raw float32 bytes rather than a rounded summary is deliberate:
## the test should fail on a one-cell difference, because one cell is how these
## bugs start.
func hash_key() -> String:
	# The global hash() hashes a packed array by its CONTENTS, so this is a
	# fingerprint of every altitude in the world and not of the array object.
	# Masked to 32 bits and printed as hex purely so it is short enough to read
	# off two screens and compare by eye.
	return "%08x" % (hash(cells) & 0xFFFFFFFF)


## Min / max / mean altitude, for the probe tool and for judging whether the
## tuning numbers actually produce the valleys and peaks they promise.
func stats() -> Dictionary:
	var lo := INF
	var hi := -INF
	var total := 0.0
	for h in cells:
		lo = minf(lo, h)
		hi = maxf(hi, h)
		total += h
	return {
		"min": lo,
		"max": hi,
		"mean": total / float(cells.size()),
		"cells": cells.size(),
	}
