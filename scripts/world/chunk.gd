class_name Chunk
extends RefCounted

## A 16x16x16 block of voxels, stored as a flat PackedByteArray.
##
## Why flat and not Array[Array[Array]]: a PackedByteArray is one contiguous
## allocation of 4096 bytes. The nested version would be 273 separate Arrays of
## boxed Variants - dozens of times more memory and much slower to walk. It
## also serialises to the network or to disk as-is, with no conversion.
##
## Index order is x + z*SIZE + y*SIZE^2, so a loop of y -> z -> x with x
## innermost walks memory front to back. The mesher touches every voxel, so
## that ordering is worth getting right.

const SIZE := 16
const SIZE_SQ := SIZE * SIZE
const VOLUME := SIZE * SIZE * SIZE

## Position in CHUNK space, not block space. Chunk (1, 0, 0) starts at block
## (16, 0, 0).
var chunk_pos: Vector3i

## 4096 block ids.
var voxels: PackedByteArray

## Set when the contents change, cleared once a mesh has been rebuilt.
var dirty := true

## Whether this chunk contains any air, and any solid, at all.
##
## Almost every chunk in a heightmap world is entirely underground or entirely
## sky, and knowing which lets the mesher skip most of its work: a chunk with no
## solid blocks has no faces to draw AT ALL, and one with no air can only have
## faces on its six outer surfaces. Without this the mesher pays the same fixed
## cost for a chunk of empty sky as for the surface.
##
## They are maintained conservatively - set true, never cleared, when a voxel
## is written. An edit can therefore leave has_air true for a chunk that is now
## solid throughout, which costs a little meshing time and can never draw the
## wrong thing. Erring the other way would hide faces that should be drawn, so
## the default below matters: a fresh chunk is zero-filled, and AIR is 0.
var has_air := true
var has_solid := false


func _init(p_chunk_pos: Vector3i) -> void:
	chunk_pos = p_chunk_pos
	voxels = PackedByteArray()
	# Packed arrays zero-fill on resize, and AIR is 0, so a fresh chunk is
	# empty - which is why has_air starts true and has_solid starts false.
	voxels.resize(VOLUME)


static func index(x: int, y: int, z: int) -> int:
	return x + z * SIZE + y * SIZE_SQ


static func in_bounds(x: int, y: int, z: int) -> bool:
	return x >= 0 and y >= 0 and z >= 0 and x < SIZE and y < SIZE and z < SIZE


## Local coordinates only (0..15). Out of range reads return AIR rather than
## crashing, which keeps the mesher's neighbour checks simple.
func get_voxel(x: int, y: int, z: int) -> int:
	if not in_bounds(x, y, z):
		return Block.AIR
	return voxels[index(x, y, z)]


## Returns true if the value actually changed - callers use that to skip
## pointless remeshes and pointless network traffic.
func set_voxel(x: int, y: int, z: int, id: int) -> bool:
	if not in_bounds(x, y, z):
		return false
	var i := index(x, y, z)
	if voxels[i] == id:
		return false
	voxels[i] = id
	if id == Block.AIR:
		has_air = true
	else:
		has_solid = true
	dirty = true
	return true


## World-space block position of this chunk's (0,0,0) corner.
func origin() -> Vector3i:
	return chunk_pos * SIZE


# --- Coordinate conversion --------------------------------------------------
#
# THE classic voxel bug lives here. Integer division truncates towards zero:
# -1 / 16 == 0. But block x = -1 belongs to chunk -1 at local x = 15, not to
# chunk 0. Get this wrong and you get a band of corrupted blocks that only
# appears on the negative side of the origin, which is a miserable thing to
# debug. So we floor-divide, and take a always-positive modulo.

static func floor_div(a: int, b: int) -> int:
	# posmod() is never negative for positive b, so (a - posmod(a, b)) is a
	# multiple of b at or below a - exactly floor division, with no floats.
	return (a - posmod(a, b)) / b


static func world_to_chunk(world_block_pos: Vector3i) -> Vector3i:
	return Vector3i(
		floor_div(world_block_pos.x, SIZE),
		floor_div(world_block_pos.y, SIZE),
		floor_div(world_block_pos.z, SIZE),
	)


static func world_to_local(world_block_pos: Vector3i) -> Vector3i:
	return Vector3i(
		posmod(world_block_pos.x, SIZE),
		posmod(world_block_pos.y, SIZE),
		posmod(world_block_pos.z, SIZE),
	)
