class_name World
extends Node3D

## Owns every loaded chunk and is the only place voxels are allowed to change.
##
## Layout for v1: a fixed 5x5 column of chunks around the origin, CHUNKS_Y tall.
## Streaming chunks in and out as players move is a later problem.

signal generation_finished(chunk_count: int, elapsed_ms: int)

## 2 -> chunks -2..2 on each horizontal axis, so 5x5.
const RADIUS_XZ := 2

## 3 chunks = 48 blocks tall, which comfortably contains the terrain band
## (SURFACE_Y 32 +/- TRANSITION 14).
const CHUNKS_Y := 3

## Milliseconds of chunk building allowed per frame. At 60 fps a frame is
## 16.6 ms, so 8 leaves room for everything else and the window stays alive.
const BUILD_BUDGET_MS := 8

var world_seed := 0
var generator: TerrainGenerator = null

var _chunks := {}        # Vector3i -> Chunk
var _chunk_nodes := {}   # Vector3i -> ChunkNode
var _build_queue: Array[Vector3i] = []

var _total_ms := 0
var _built := 0


## Start building. Called once per session.
func setup(p_seed: int) -> void:
	world_seed = p_seed
	generator = TerrainGenerator.new(p_seed)

	_build_queue.clear()
	for cy in CHUNKS_Y:
		for cz in range(-RADIUS_XZ, RADIUS_XZ + 1):
			for cx in range(-RADIUS_XZ, RADIUS_XZ + 1):
				_build_queue.append(Vector3i(cx, cy, cz))

	# Nearest-first, so the world grows outward from where the player spawns
	# instead of popping in in some arbitrary order.
	_build_queue.sort_custom(Callable(self, "_nearer_to_centre"))
	print("[World] seed %d, %d chunks queued" % [p_seed, _build_queue.size()])


func _process(_delta: float) -> void:
	if _build_queue.is_empty():
		return

	# Spend a bounded slice of this frame on chunk building. Doing all 75 in
	# _ready() would freeze the window for seconds with no sign of life.
	var started := Time.get_ticks_msec()
	while not _build_queue.is_empty() and Time.get_ticks_msec() - started < BUILD_BUDGET_MS:
		_build_chunk(_build_queue.pop_front())
	_total_ms += Time.get_ticks_msec() - started

	if _build_queue.is_empty():
		print("[World] %d chunks generated and meshed in %d ms" % [_built, _total_ms])
		generation_finished.emit(_built, _total_ms)


## Is there a solid block at this WORLD block position?
##
## This is the function the mesher uses for neighbours outside a chunk, and the
## reason the edge of the loaded area does not sprout a wall of faces: beyond
## the loaded chunks we simply ask the generator what would be there.
func is_solid_world(wx: int, wy: int, wz: int) -> bool:
	var wpos := Vector3i(wx, wy, wz)
	var chunk: Chunk = _chunks.get(Chunk.world_to_chunk(wpos))
	if chunk != null:
		var l := Chunk.world_to_local(wpos)
		return Block.is_solid(chunk.voxels[Chunk.index(l.x, l.y, l.z)])
	return generator.is_solid_at(wx, wy, wz)


func get_block(world_block_pos: Vector3i) -> int:
	var chunk: Chunk = _chunks.get(Chunk.world_to_chunk(world_block_pos))
	if chunk == null:
		return Block.AIR
	var l := Chunk.world_to_local(world_block_pos)
	return chunk.voxels[Chunk.index(l.x, l.y, l.z)]


func has_chunk(chunk_pos: Vector3i) -> bool:
	return _chunks.has(chunk_pos)


func is_ready() -> bool:
	return generator != null and _build_queue.is_empty()


# --- Internals --------------------------------------------------------------

func _build_chunk(chunk_pos: Vector3i) -> void:
	var chunk := Chunk.new(chunk_pos)
	generator.generate_into(chunk)
	_chunks[chunk_pos] = chunk

	var node := ChunkNode.new()
	node.setup(chunk)
	add_child(node)
	_chunk_nodes[chunk_pos] = node

	# A chunk built before its neighbours still meshes correctly: is_solid_world
	# falls through to the generator, which gives the same answer the neighbour
	# will have once it exists. So no re-mesh pass is needed at load time.
	node.rebuild(Callable(self, "is_solid_world"))
	_built += 1


func _nearer_to_centre(a: Vector3i, b: Vector3i) -> bool:
	# Horizontal distance only - vertical order does not change how it looks.
	var da := a.x * a.x + a.z * a.z
	var db := b.x * b.x + b.z * b.z
	return da < db
