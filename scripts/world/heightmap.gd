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


func _init(config: WorldgenConfig) -> void:
	step = config.coarse_step
	cols = int(config.world_blocks_xz / config.coarse_step)
	min_block = -int(config.world_blocks_xz / 2)
	_max_block = min_block + (cols - 1) * step
	cells.resize(cols * cols)


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
func slope_deg_at(bx: float, bz: float) -> float:
	var d := float(step)
	var gx := (height_at(bx + d, bz) - height_at(bx - d, bz)) / (2.0 * d)
	var gz := (height_at(bx, bz + d) - height_at(bx, bz - d)) / (2.0 * d)
	return rad_to_deg(atan(sqrt(gx * gx + gz * gz)))


## Is this block position inside the world footprint at all?
func in_bounds(bx: int, bz: int) -> bool:
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

## The coarsest level. 5 is 64 m per cell, which is a whole mountain flank.
const MAX_LEVEL := 5

## Levels 1..MAX_LEVEL. Level 0 is `cells` itself and is never copied.
var _levels: Array[PackedFloat32Array] = []
var _level_cols := PackedInt32Array()

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
	_level_cols = PackedInt32Array()
	var prev := cells
	var prev_cols := cols
	# The widths of level 0 are all 1 by definition.
	var prev_w := PackedInt32Array()
	prev_w.resize(cols)
	prev_w.fill(1)
	for level in range(1, MAX_LEVEL + 1):
		var n := (prev_cols + 1) / 2
		var out := PackedFloat32Array()
		out.resize(n * n)
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
				out[i + at] = (
					(prev[i0 + row0] * float(wi0) + prev[i1 + row0] * float(wi1))
						* float(wj0)
					+ (prev[i0 + row1] * float(wi0) + prev[i1 + row1] * float(wi1))
						* float(wj1)
				) / float(wi0 + wi1) * inv_j
		_levels.append(out)
		_level_cols.append(n)
		prev = out
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
	if level <= 0:
		return height_at(bx, bz)
	if not _pyramid_ready:
		build_pyramid()
	var l := mini(level, MAX_LEVEL)
	var n := _level_cols[l - 1]
	var data := _levels[l - 1]
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
	var l := clampf(level, 0.0, float(MAX_LEVEL))
	var lo := int(floor(l))
	var f := l - float(lo)
	if f <= 0.0001 or lo >= MAX_LEVEL:
		return height_at_level(bx, bz, lo)
	return lerpf(height_at_level(bx, bz, lo),
		height_at_level(bx, bz, lo + 1), f)


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
