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
