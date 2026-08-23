class_name TerrainGenerator
extends RefCounted

## Turns a seed plus a world position into blocks. Deterministically.
##
## This determinism is the whole reason terrain never touches the network: the
## host picks one integer, sends it, and both machines compute an identical
## world locally. Only player EDITS get transmitted. Break determinism (a
## randf() in here, a dependence on iteration order, a float that rounds
## differently) and the two players quietly end up in different worlds.
##
## Shape: a 3D density field, not a 2D heightmap.
##
##     density(x, y, z) = noise3d(x, y*2, z) + (SURFACE_Y - y) / TRANSITION
##     solid where density > 0
##
## The second term is a vertical bias: far below SURFACE_Y it exceeds +1 so the
## noise (which is in [-1, 1]) can never win and everything is solid; far above
## it drops below -1 and everything is air. In between there is a band about
## 2 * TRANSITION blocks tall where the noise actually decides - and that is
## what produces overhangs and floating islands. A heightmap cannot, by
## construction, ever make an overhang.

## Middle of the terrain band, in blocks.
const SURFACE_Y := 32.0

## Half-height of the band where noise decides solid vs air.
const TRANSITION := 14.0

## Noise features are stretched horizontally by sampling y at a higher rate.
## Without this you get spherical blobs instead of landscape.
const Y_SQUASH := 2.0

## How far up we look for solid blocks when picking a surface material. Keep
## small: it costs one extra noise sample per column per step.
const SURFACE_PROBE := 3

var world_seed: int

var _density: FastNoiseLite


func _init(p_seed: int) -> void:
	world_seed = p_seed
	_density = FastNoiseLite.new()
	_density.seed = p_seed
	_density.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	# Feature size ~ 1 / frequency, so ~40 blocks across.
	_density.frequency = 0.025
	_density.fractal_type = FastNoiseLite.FRACTAL_FBM
	# Each octave adds finer detail at half the amplitude. 4 is a good
	# ratio of "looks natural" to "costs CPU".
	_density.fractal_octaves = 4
	_density.fractal_lacunarity = 2.0
	_density.fractal_gain = 0.5


func is_solid_at(wx: int, wy: int, wz: int) -> bool:
	var bias := (SURFACE_Y - float(wy)) / TRANSITION
	return _density.get_noise_3d(float(wx), float(wy) * Y_SQUASH, float(wz)) + bias > 0.0


## Fill a chunk with blocks. Column by column, top to bottom.
##
## Why columns instead of the mesher's linear y -> z -> x order: picking the
## surface material needs to know how much solid sits directly above a voxel.
## Walking a column downwards keeps that count in a variable for free, instead
## of re-sampling the noise several times for every solid block.
func generate_into(chunk: Chunk) -> void:
	var origin := chunk.origin()
	var top_y := origin.y + Chunk.SIZE - 1

	for lz in Chunk.SIZE:
		for lx in Chunk.SIZE:
			var wx := origin.x + lx
			var wz := origin.z + lz

			# Chunks are generated independently, so before descending we peek
			# a few blocks above this chunk's ceiling. Without that, the top
			# layer of every chunk would think it was a surface and grow grass
			# in the middle of a mountain.
			var solid_above := 0
			for k in range(1, SURFACE_PROBE + 1):
				if not is_solid_at(wx, top_y + k, wz):
					break
				solid_above += 1

			for ly in range(Chunk.SIZE - 1, -1, -1):
				var wy := origin.y + ly
				if is_solid_at(wx, wy, wz):
					chunk.voxels[Chunk.index(lx, ly, lz)] = block_for(solid_above, wy)
					solid_above += 1
				else:
					chunk.voxels[Chunk.index(lx, ly, lz)] = Block.AIR
					solid_above = 0

	chunk.dirty = true


## Choose the block type for a solid voxel.
##
## `solid_above` = how many solid blocks are stacked directly on top of this
## one (0 means this voxel is exposed to the sky). `wy` = world height.
func block_for(solid_above: int, wy: int) -> int:
	# TODO(marcel): make the surface look like terrain instead of a stone ball.
	#
	# Rules to implement, in order:
	#   - solid_above == 0 (nothing on top, so this is the surface):
	#       below y = 26  -> Block.SAND   (lakeshore-ish lowlands)
	#       above y = 40  -> Block.SNOW   (peaks)
	#       otherwise     -> Block.GRASS
	#   - solid_above < 4 (just under the surface) -> Block.DIRT
	#   - anything deeper -> Block.STONE
	#
	# Hint: this is a pure function - no state, no noise, just the two
	# arguments. Write it as an if/elif chain and return early. Once it works,
	# try changing the 26 and 40 and re-hosting to see the biomes move.
	return Block.STONE
