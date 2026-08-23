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


# --- The one and only voxel mutation path -----------------------------------
#
#   anyone: request_set_block()
#      |                       \
#      | (client) rpc to peer 1 | (host) direct call, no network
#      v                       /
#   host: _host_apply_edit()  ->  validate  ->  apply  ->  broadcast diff
#                                                             |
#                                          every client: _cl_apply_block()
#
# Clients never write to their own chunks, not even optimistically. If we ever
# want prediction, it gets added here as an explicitly reconciled layer - not
# by quietly letting a client mutate state.

## Every accepted edit so far, world block position -> block id.
##
## This dictionary is the entire difference between "what the seed generates"
## and "what the world actually looks like", which is exactly what a late
## joiner needs replayed to catch up.
var _edits := {}


## Ask for a block change. Call this from anywhere; it is the only entry point.
func request_set_block(world_block_pos: Vector3i, block_id: int) -> void:
	if Net.is_host():
		# Same destination as the RPC below, just without a round trip. The
		# branch is about transport only - authority logic exists once.
		_host_apply_edit(Net.local_peer_id(), world_block_pos, block_id)
	else:
		_srv_request_set_block.rpc_id(1, world_block_pos, block_id)


## Sent by clients, executed on the host.
@rpc("any_peer", "call_remote", "reliable")
func _srv_request_set_block(world_block_pos: Vector3i, block_id: int) -> void:
	if not Net.is_host():
		return
	# get_remote_sender_id() is assigned by the network layer, so a client
	# cannot forge it. Any identity check must use this, never a peer id
	# passed in the arguments.
	_host_apply_edit(multiplayer.get_remote_sender_id(), world_block_pos, block_id)


## Sent by the host, executed on every client.
##
## "authority" means Godot itself rejects this call unless it came from this
## node's authority (peer 1). That is what stops one client from faking world
## edits at another.
@rpc("authority", "call_remote", "reliable")
func _cl_apply_block(world_block_pos: Vector3i, block_id: int) -> void:
	_edits[world_block_pos] = block_id
	_apply_edit_locally(world_block_pos, block_id)


## Snapshot of all edits, for sending to a joining player.
func get_edits() -> Dictionary:
	return _edits.duplicate()


## Replay a snapshot. Used by a client once, right after it receives the seed.
func apply_edit_snapshot(edits: Dictionary) -> void:
	for pos in edits:
		_edits[pos] = edits[pos]
		_apply_edit_locally(pos, edits[pos])
	print("[World] replayed %d edits from host" % edits.size())


# --- Host-side authority ----------------------------------------------------

func _host_apply_edit(sender_id: int, world_block_pos: Vector3i, block_id: int) -> void:
	if not _validate_edit(sender_id, world_block_pos, block_id):
		return
	if not _apply_edit_locally(world_block_pos, block_id):
		# Nothing changed (already that block), so nothing to tell anyone.
		return
	_edits[world_block_pos] = block_id
	_cl_apply_block.rpc(world_block_pos, block_id)


## The host says yes or no. Today the rules are minimal; reach distance,
## tool checks and rate limiting all belong here later - one place, so a
## client cannot route around them.
func _validate_edit(_sender_id: int, world_block_pos: Vector3i, block_id: int) -> bool:
	if block_id < 0 or block_id >= Block.NAMES.size():
		return false
	# Only edit chunks we actually have loaded, otherwise the edit would be
	# silently lost when the chunk is generated later.
	return has_chunk(Chunk.world_to_chunk(world_block_pos))


# --- Local application (identical on host and clients) ----------------------

func _apply_edit_locally(world_block_pos: Vector3i, block_id: int) -> bool:
	var cpos := Chunk.world_to_chunk(world_block_pos)
	var chunk: Chunk = _chunks.get(cpos)
	if chunk == null:
		return false

	var l := Chunk.world_to_local(world_block_pos)
	if not chunk.set_voxel(l.x, l.y, l.z, block_id):
		return false

	_remesh(cpos)
	# A block on a chunk face changes which of the NEIGHBOUR's faces are
	# exposed, so the neighbour needs rebuilding too. Forget this and you get
	# holes along chunk seams whenever someone digs near one.
	for neighbour in _boundary_neighbours(cpos, l):
		_remesh(neighbour)
	return true


func _boundary_neighbours(cpos: Vector3i, local: Vector3i) -> Array[Vector3i]:
	var out: Array[Vector3i] = []
	var last := Chunk.SIZE - 1
	if local.x == 0:
		out.append(cpos + Vector3i(-1, 0, 0))
	elif local.x == last:
		out.append(cpos + Vector3i(1, 0, 0))
	if local.y == 0:
		out.append(cpos + Vector3i(0, -1, 0))
	elif local.y == last:
		out.append(cpos + Vector3i(0, 1, 0))
	if local.z == 0:
		out.append(cpos + Vector3i(0, 0, -1))
	elif local.z == last:
		out.append(cpos + Vector3i(0, 0, 1))
	return out


func _remesh(cpos: Vector3i) -> void:
	var node: ChunkNode = _chunk_nodes.get(cpos)
	if node != null:
		node.rebuild(Callable(self, "is_solid_world"))
