class_name World
extends Node3D

## Owns every loaded chunk and is the only place voxels are allowed to change.
##
## Real editable voxels exist only near the player - a disc of chunk columns
## whose radius is config.voxel_radius_chunks. Everything beyond is the
## far-field heightmap mesh (Stage 7), which is the only reason a 200 m view
## distance is affordable at all: 200 m of voxels is roughly 30,000 chunks.
##
## Within a column we build only the chunks that terrain actually passes
## through - the surface, plus voxel_depth_chunks of rock beneath it. The world
## is 320 blocks tall and nobody can see the bottom 250 of it, so building full
## vertical columns would be about four times the chunks for no visible
## difference whatsoever.

signal generation_finished(chunk_count: int, elapsed_ms: int)

## Chunks are kept this much beyond the load radius before being freed.
##
## Without hysteresis, a player standing exactly on a chunk boundary and
## shuffling sideways would free and rebuild the same ring of chunks every
## frame - the single most expensive thing the world can do, triggered by
## standing still.
const UNLOAD_MARGIN_CHUNKS := 2

## Milliseconds of MAIN THREAD chunk work allowed per frame. At 60 fps a frame
## is 16.6 ms, so 8 leaves room for everything else and the window stays alive.
##
## Since v1 Stage 6 meshing happens on worker threads, and since v2 Stage 3 so
## does generation. What is left on the main thread is only what has to be:
## creating nodes, replaying edits, and handing finished arrays to the
## rendering and physics servers.
const BUILD_BUDGET_MS := 8

## The same budget while the FIRST load is still arriving. The player is
## frozen at spawn until the ground exists, so nobody is looking at the frame
## rate - they are looking at a world that is not there yet. Doubling the
## slice halves the time until it is, and once the initial load has reported
## the budget drops back to BUILD_BUDGET_MS for good.
const INITIAL_BUILD_BUDGET_MS := 16

## How many chunks may be out at the worker pool at once.
##
## Not unbounded: each job holds its chunk and six neighbours alive, and a
## queue of a thousand of them would pin the whole loaded region in memory
## while the pool worked through it. Deep enough to keep every core fed, which
## is all a queue has to do.
## Counted across BOTH phases together. A chunk generating and a chunk meshing
## each occupy one worker, so splitting the cap in two would either starve one
## phase or double the real ceiling by accident.
##
## NOT SIZED FROM THE CORE COUNT, and that was tried. "One thread per core,
## so feed every core" is the obvious model and it is wrong for GDScript in
## this engine build: measured on a 20-thread machine, a worker-pool fill took
## exactly as long on two workers as on one, 1.2x longer on four and 4x longer
## on sixteen. GDScript execution is serialised across threads, and every
## extra job in flight only adds contention. So the cap is a per-machine dial
## in the config, and a small one - see WorldgenConfig.max_jobs_in_flight for
## the load times at each value.
var _max_jobs_in_flight := 4

var world_seed := 0
var generator: TerrainGenerator = null

## Every tunable number. Part of the determinism contract alongside the seed,
## so it is stored here next to it rather than reached for globally.
var config: WorldgenConfig = null

var _chunks := {}        # Vector3i -> Chunk
var _chunk_nodes := {}   # Vector3i -> ChunkNode
var _build_queue: Array[Vector3i] = []

## Mirror of _build_queue, for membership tests only. refresh_region() asks
## "is this already queued" once per wanted chunk, and Array.has() is a linear
## scan - the two together were O(n^2) over thousands of chunks, which was a
## visible hitch on the main thread every time the player crossed a chunk
## boundary. Every write to _build_queue keeps this in step.
var _queued := {}

## Chunk-space column the loaded region is centred on. Stage 4's player drives
## it; until then it stays at the spawn column.
var _center := Vector2i.ZERO

## Emitted once, for the first full load. With streaming the queue empties
## every time the player stops walking, and a signal that fired then would have
## Game re-running its spawn logic for the rest of the session.
var _initial_load_reported := false

## chunk position -> {"task": int, "job": GenJob}. Chunks whose voxels are
## being built by the worker pool and which therefore DO NOT EXIST YET in
## _chunks. Everything that asks "is this chunk here" has to know about this
## set as well, which is most of the cost of Stage 3.
var _gen_in_flight := {}

## chunk position -> {"task": int, "job": MeshJob}. Chunks whose voxels exist
## and whose mesh is being built by the worker pool.
var _in_flight := {}

## The low-poly terrain beyond the voxel radius. Everything the player can see
## but not touch.
var _far_field: FarField = null

# --- The decoration layer (foliage v1 Stage 5) ------------------------------
#
# Ground cover does not live in chunks, in the mesher, or in the edit
# dictionary - see FloraModels for why it cannot. It is a parallel set of nodes
# keyed by chunk COLUMN, built by the same worker pool under the same in-flight
# cap, and freed by the same distance rule.
#
# Deliberately NOT a second worker pool. GDScript execution is serialised
# across threads in this engine build - the note on _max_jobs_in_flight has the
# measurements - so a second pool would add contention rather than throughput,
# and flora would compete with the terrain the player is standing on.

var _flora_nodes := {}       # Vector2i -> FloraColumn
var _flora_in_flight := {}   # Vector2i -> {"task": int, "job": FloraJob}
var _flora_queue: Array[Vector2i] = []
var _flora_queued := {}
var _flora_instances := 0
var _flora_ms := 0

## Every basin in the world, and the water sitting in it.
var lakes: Lakes = null
var _water: MeshInstance3D = null

## Wall clock, as distinct from _total_ms which counts main-thread time only.
## With threading those two stop being the same number, and the gap between
## them is precisely what the threading bought.
var _wall_start_ms := 0

var _total_ms := 0
var _built := 0

## Split generate from mesh rather than reporting one number. They are tuned by
## completely different means - generate by noise layer count, mesh by the
## meshing algorithm - and one combined figure hides which of the two just got
## worse.
##
## Since Stage 3 _gen_ms is WORKER time, summed from what each job reports
## about itself, and no longer main-thread time. The gap between it and the
## wall clock is what the threading bought, and it is the number that should
## be read against v1's 3.81 ms per chunk on the main thread.
var _gen_ms := 0
var _mesh_ms := 0
var _heightmap_ms := 0
var _far_vertices := 0


## Start building. Called once per session.
func setup(p_seed: int, p_config: WorldgenConfig = null) -> void:
	world_seed = p_seed
	# A SNAPSHOT, not the live tuning object. The panel writes into the config
	# Game holds, and if the world read from that too, then moving a slider
	# would change the terrain of chunks not yet streamed in while leaving the
	# ones already around the player alone - a world that disagrees with itself
	# along a line you cannot see. Terrain changes on reroll and at no other
	# time, which is exactly what the panel says it does.
	config = (p_config if p_config != null else WorldgenConfig.new()).clone()
	_max_jobs_in_flight = maxi(config.max_jobs_in_flight, 1)
	generator = TerrainGenerator.new(p_seed, config)

	# The whole world's surface, once, before any chunk exists. Everything
	# downstream reads its shape from here, which is what stops the voxels, the
	# far mesh and the lakes from each having their own private opinion about
	# where the ground is.
	_heightmap_ms = generator.build_heightmap()
	print("[World] coarse heightmap %dx%d in %d ms, hash %s" % [
		generator.heightmap.cols, generator.heightmap.cols,
		_heightmap_ms, generator.heightmap.hash_key()])

	# Lakes are found in the coarse heightmap, before any voxel exists and
	# before the detail layer is applied - a 3-block bump must never be able to
	# invent or drain one.
	_build_lakes()

	_initial_load_reported = false
	_wall_start_ms = Time.get_ticks_msec()

	if _far_field == null:
		_far_field = FarField.new()
		_far_field.name = "FarField"
		_far_field.rebuilt.connect(_on_far_field_rebuilt)
		add_child(_far_field)
	_far_field.setup(generator, config)
	_far_field.request_rebuild(_center * Chunk.SIZE)

	refresh_region()
	print("[World] seed %d, %d chunks queued around %s" % [
		p_seed, _build_queue.size(), _center])


func _process(_delta: float) -> void:
	if _build_queue.is_empty() and _in_flight.is_empty() \
			and _gen_in_flight.is_empty() and _flora_queue.is_empty() \
			and _flora_in_flight.is_empty():
		return

	# Spend a bounded slice of this frame on chunk work. Doing it all at once
	# would freeze the window for seconds with no sign of life.
	var started := Time.get_ticks_msec()
	var budget := BUILD_BUDGET_MS if _initial_load_reported else INITIAL_BUILD_BUDGET_MS
	_collect_finished(started, budget)
	_submit_jobs()
	_submit_flora()
	_total_ms += Time.get_ticks_msec() - started

	if is_idle() and not _initial_load_reported:
		_initial_load_reported = true
		var wall := Time.get_ticks_msec() - _wall_start_ms
		var n := float(maxi(_built, 1))
		print("[World] %d chunks in %d ms wall (%d ms main thread; %.2f ms gen per chunk on workers, %.2f ms main-thread upload per chunk)" % [
			_built, wall, _total_ms, float(_gen_ms) / 1000.0 / n,
			float(_mesh_ms) / 1000.0 / n])
		print("[World] far field %d vertices" % _far_vertices)
		print("[World] flora %d instances in %d columns, %.2f ms per column on workers" % [
			_flora_instances, _flora_nodes.size(),
			float(_flora_ms) / 1000.0 / float(maxi(_flora_nodes.size(), 1))])
		generation_finished.emit(_built, wall)


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


## Are this chunk's VOXELS available right now? A chunk still out at the worker
## pool answers false - it exists as an object but its contents are undefined
## until the job completes. Callers that mean "will exist shortly" want
## is_chunk_pending() as well; the edit validator is the one place that does.
func has_chunk(chunk_pos: Vector3i) -> bool:
	return _chunks.has(chunk_pos)


## Queued or out at the worker pool: no voxels yet, but there will be.
func is_chunk_pending(chunk_pos: Vector3i) -> bool:
	return _gen_in_flight.has(chunk_pos)


## Is there something to STAND ON in this chunk yet? Stricter than has_chunk():
## the voxels arrive first and the mesh with its trimesh arrives with the
## upload, frames later. Anything that means to put a body on the ground has
## to ask this one, or it puts the body in the ground.
func is_chunk_collidable(chunk_pos: Vector3i) -> bool:
	var node: ChunkNode = _chunk_nodes.get(chunk_pos)
	return node != null and node.collision_applied


func is_world_ready() -> bool:
	return generator != null and _build_queue.is_empty()


## Throw the world away so a new seed can be built in its place.
##
## Reroll is a tuning tool: change a number, press the key, look at a fresh
## world without leaving the session. The edit dictionary is cleared with
## everything else - edits are positions in a world that no longer exists, and
## replaying them into the new one would drop blocks in mid-air.
func reset() -> void:
	_drain_jobs()
	if _far_field != null:
		_far_field.drain()
	for pos in _chunk_nodes:
		_chunk_nodes[pos].queue_free()
	_chunk_nodes.clear()
	_chunks.clear()
	for col in _flora_nodes:
		_flora_nodes[col].queue_free()
	_flora_nodes.clear()
	_flora_queue.clear()
	_flora_queued.clear()
	_flora_instances = 0
	_flora_ms = 0
	_gen_in_flight.clear()
	_build_queue.clear()
	_queued.clear()
	_edits.clear()
	_total_ms = 0
	_built = 0
	_gen_ms = 0
	_mesh_ms = 0
	_heightmap_ms = 0
	_wall_start_ms = Time.get_ticks_msec()


## Nothing queued and nothing out at the worker pool. is_world_ready() answers
## a weaker question - it does not know about jobs in flight - and the
## screenshot tour needs to know the world has actually finished arriving
## before it takes a picture of it.
func is_idle() -> bool:
	return generator != null and _build_queue.is_empty() \
		and _in_flight.is_empty() and _gen_in_flight.is_empty() \
		and _flora_queue.is_empty() and _flora_in_flight.is_empty()


func loaded_chunk_count() -> int:
	return _chunks.size()


func queued_chunk_count() -> int:
	return _build_queue.size()


## Averages, not totals: a total tells you the world loaded, a per-chunk
## average tells you whether the next one will arrive in time. The HUD shows
## these live and they are the number the performance work in Stage 6 moves.
func last_timings() -> Dictionary:
	var n: int = maxi(_built, 1)
	return {
		"gen_ms": float(_gen_ms) / 1000.0 / float(n),
		"mesh_ms": float(_mesh_ms) / 1000.0 / float(n),
		"heightmap_ms": _heightmap_ms,
	}


# --- Internals --------------------------------------------------------------

## Hand queued chunks to the worker pool until it is full.
##
## NO TIME BUDGET HERE, deliberately. It used to share the frame budget with
## _collect_finished(), which runs first - so on upload-heavy frames collection
## spent the whole 8 ms, nothing was submitted, and the pool sat idle with a
## full queue behind it. A submission is two allocations and an add_task -
## microseconds - and the in-flight cap already bounds the loop, so the budget
## was protecting the frame from nothing and stalling the pipeline to do it.
func _submit_jobs() -> void:
	while not _build_queue.is_empty() and _jobs_in_flight() < _max_jobs_in_flight:
		var chunk_pos: Vector3i = _build_queue.pop_front()
		_queued.erase(chunk_pos)
		if _chunks.has(chunk_pos) or _gen_in_flight.has(chunk_pos):
			continue
		_submit_generation(chunk_pos)


func _jobs_in_flight() -> int:
	return _gen_in_flight.size() + _in_flight.size() + _flora_in_flight.size()


## HOOK 1 OF 4: submit. Hand queued flora columns to the worker pool.
##
## AFTER the terrain, and sharing its cap, which is the whole of the priority
## policy: a column of grass matters only if there is ground under it, so
## terrain jobs are offered the pool first and flora takes what is left. On a
## busy load that means flora arrives a moment behind the ground, which is
## exactly the order a player notices things in.
func _submit_flora() -> void:
	while not _flora_queue.is_empty() and _jobs_in_flight() < _max_jobs_in_flight:
		var col: Vector2i = _flora_queue.pop_front()
		_flora_queued.erase(col)
		if _flora_in_flight.has(col):
			continue
		var job := FloraJob.new()
		job.column = col
		job.generator = generator
		job.config = config
		job.draw_fraction = config.flora_draw_fraction
		_flora_in_flight[col] = {
			"task": WorkerThreadPool.add_task(job.run, false, "kubik flora"),
			"job": job,
		}


## HOOK 4 OF 4: rebuild one column's flora.
##
## Called when something under the plants has changed - a block edit, or a
## gathered instance in Stage 9. The node is left alone until the new buffers
## arrive, so the plants do not blink out and back.
func _flora_dirty(col: Vector2i) -> void:
	if not _flora_nodes.has(col) and not _flora_in_flight.has(col):
		return
	if _flora_queued.has(col) or _flora_in_flight.has(col):
		return
	_flora_queue.append(col)
	_flora_queued[col] = true


## PHASE ONE. Hand a chunk's voxels to the worker pool.
##
## The chunk object exists from here on, but it is NOT in _chunks and its
## contents are undefined until the job completes - the worker is writing into
## it. Nothing may read it in the meantime, which is the whole reason it is
## held in _gen_in_flight rather than published early.
func _submit_generation(chunk_pos: Vector3i) -> void:
	var job := GenJob.new()
	job.chunk = Chunk.new(chunk_pos)
	job.generator = generator
	_gen_in_flight[chunk_pos] = {
		"task": WorkerThreadPool.add_task(job.run, false, "kubik chunk gen"),
		"job": job,
	}


## PHASE TWO. The voxels have arrived; publish the chunk and mesh it.
func _submit_mesh(chunk: Chunk) -> void:
	var chunk_pos := chunk.chunk_pos

	# The node exists immediately, with no mesh. That keeps the bookkeeping in
	# one place: everything downstream can assume a chunk in _chunks has a node
	# in _chunk_nodes, whether or not its mesh has arrived yet.
	var node := ChunkNode.new()
	node.setup(chunk, config, world_seed)
	add_child(node)
	_chunk_nodes[chunk_pos] = node

	var job := MeshJob.new()
	job.chunk = chunk
	job.generator = generator
	job.config = config
	job.world_seed = world_seed
	job.neighbours = _face_neighbour_chunks(chunk_pos)
	_in_flight[chunk_pos] = {
		"task": WorkerThreadPool.add_task(job.run, false, "kubik chunk mesh"),
		"job": job,
	}


## Install meshes for jobs the pool has finished with.
##
## Upload order does not matter to what the world ends up looking like, which
## is why walking a Dictionary is acceptable here and is not anywhere in
## worldgen: this decides which chunk appears a frame earlier, not what is in
## it.
##
## MESHES BEFORE VOXELS, and the order is load-bearing. Both phases draw on
## one budget, and an uploaded mesh is the only output the player can see or
## stand on; a published chunk is a promise of one. Generated-first let a
## busy pool fill the whole budget with publishing and node creation, frame
## after frame, while finished meshes queued behind it unseen - the world
## arrived slowly however fast the workers were, and the spawn chunk's
## collision arrived late enough to drop the player through it. Meshes-first
## cannot starve generation the same way: when no upload is waiting the
## first pass costs nothing and the budget falls through to the second.
func _collect_finished(started: int, budget: int = BUILD_BUDGET_MS) -> void:
	_collect_meshed(started, budget)
	_collect_generated(started, budget)
	_collect_flora(started, budget)


## HOOK 2 OF 4: collect. Install flora buffers the pool has finished with.
##
## LAST of the three, and sharing their budget, for the same reason flora is
## submitted last: ground the player can stand on outranks grass growing on it.
## When the terrain has nothing waiting this costs nothing and the whole budget
## falls through to here.
func _collect_flora(started: int, budget: int) -> void:
	var done: Array[Vector2i] = []
	for col in _flora_in_flight:
		if Time.get_ticks_msec() - started >= budget:
			break
		var entry: Dictionary = _flora_in_flight[col]
		if not WorkerThreadPool.is_task_completed(entry["task"]):
			continue
		WorkerThreadPool.wait_for_task_completion(entry["task"])
		done.append(col)

	for col in done:
		var job: FloraJob = _flora_in_flight[col]["job"]
		_flora_in_flight.erase(col)
		_flora_ms += job.elapsed_usec
		# The column may have walked out of range while its job was in flight.
		# Dropping the result is right: nothing is drawing it, and the job will
		# be resubmitted if the player comes back.
		if not _wants_flora(col):
			continue
		var node: FloraColumn = _flora_nodes.get(col)
		if node == null:
			node = FloraColumn.new()
			node.setup(col)
			add_child(node)
			_flora_nodes[col] = node
		_flora_instances -= node.instance_count
		node.apply_buffers(job.buffers, config)
		_flora_instances += node.instance_count


## Chunks whose voxels have arrived. Publish them, replay their edits, and
## hand them straight on to phase two.
func _collect_generated(started: int, budget: int) -> void:
	var done: Array[Vector3i] = []
	for chunk_pos in _gen_in_flight:
		if Time.get_ticks_msec() - started >= budget:
			break
		var entry: Dictionary = _gen_in_flight[chunk_pos]
		if not WorkerThreadPool.is_task_completed(entry["task"]):
			continue
		WorkerThreadPool.wait_for_task_completion(entry["task"])
		done.append(chunk_pos)

	for chunk_pos in done:
		var job: GenJob = _gen_in_flight[chunk_pos]["job"]
		var chunk: Chunk = job.chunk
		_gen_ms += job.elapsed_usec
		_gen_in_flight.erase(chunk_pos)
		_chunks[chunk_pos] = chunk

		# THE EDIT-REPLAY POINT, and the reason it has to be exactly here.
		#
		# Every edit accepted while this chunk was still generating was
		# recorded in _edits and could not be written into any chunk, because
		# there was no chunk to write into. This is the first moment there is.
		# It has to happen BEFORE the mesh job is submitted, or the mesh would
		# be built from the unedited voxels and the edit would be invisible
		# until something else happened to dirty the chunk.
		_replay_edits_for(chunk)

		var t_upload := Time.get_ticks_usec()
		_submit_mesh(chunk)
		_mesh_ms += Time.get_ticks_usec() - t_upload


func _collect_meshed(started: int, budget: int) -> void:
	var done: Array[Vector3i] = []
	for chunk_pos in _in_flight:
		if Time.get_ticks_msec() - started >= budget:
			break
		var entry: Dictionary = _in_flight[chunk_pos]
		if not WorkerThreadPool.is_task_completed(entry["task"]):
			continue
		# Required even for a task already reported complete - it is what
		# releases the pool's own bookkeeping for it.
		WorkerThreadPool.wait_for_task_completion(entry["task"])

		var t_upload := Time.get_ticks_usec()
		var node: ChunkNode = _chunk_nodes.get(chunk_pos)
		if node != null and is_instance_valid(node):
			node.apply_arrays(entry["job"].arrays)
		_mesh_ms += Time.get_ticks_usec() - t_upload
		done.append(chunk_pos)
		_built += 1

	for chunk_pos in done:
		_in_flight.erase(chunk_pos)


## The six chunks sharing a face with this one, for the mesher to ask about
## neighbours it cannot see itself. Missing ones are simply absent, and the job
## falls back to the generator for them.
## Find the basins and put water in them.
func _build_lakes() -> void:
	lakes = Lakes.new()
	lakes.compute(generator.heightmap, config)
	# The generator needs them back, so it can fade the detail layer out at the
	# water line. Strictly one-way and strictly in this order: lakes are found
	# in the coarse heightmap, and the coarse heightmap must never depend on
	# them or the two would be defined in terms of each other.
	generator.lakes = lakes

	# Spawn is chosen from the finished world, because every criterion it has
	# to satisfy - flat, dry, mountain in view, water within a walk - is a
	# question about terrain that already exists.
	var spawn := generator.find_spawn()
	var report := generator.spawn_report
	if report.get("ok", false):
		print("[World] spawn at (%d, %d), altitude %.1f blk, slope %.1f deg" % [
			spawn.x, spawn.y, report["altitude"], report["slope"]])
	else:
		push_warning("[World] NO SPAWN met every criterion - falling back to the origin. %s"
			% [report.get("failed", {})])

	if _water == null:
		_water = MeshInstance3D.new()
		_water.name = "Water"
		_water.material_override = Lakes.make_material()
		# Non-interactive, per the design: no physics, no swimming, no
		# collision shape. It is a surface to look at and stand beside.
		add_child(_water)
	_water.mesh = ChunkMesher.arrays_to_mesh(lakes.build_water_arrays(
		generator.heightmap, config))

	var flooded := 0
	var area := 0.0
	for lake in lakes.lakes:
		flooded += lake["cells"]
		area += lake["area_m2"]
	print("[World] %d lakes, %.0f m2 (%.1f%% of the map) in %d ms" % [
		lakes.lake_count(), area,
		float(flooded) / float(generator.heightmap.cols * generator.heightmap.cols) * 100.0,
		lakes.elapsed_ms()])


func lake_count() -> int:
	return lakes.lake_count() if lakes != null else 0


func _on_far_field_rebuilt(vertex_count: int) -> void:
	_far_vertices = vertex_count


func far_field_vertices() -> int:
	return _far_vertices


func _face_neighbour_chunks(chunk_pos: Vector3i) -> Dictionary:
	var out := {}
	for offset in [
		Vector3i(1, 0, 0), Vector3i(-1, 0, 0),
		Vector3i(0, 1, 0), Vector3i(0, -1, 0),
		Vector3i(0, 0, 1), Vector3i(0, 0, -1),
	]:
		var pos: Vector3i = chunk_pos + offset
		var c: Chunk = _chunks.get(pos)
		if c != null:
			out[pos] = c
	return out


## Block until the pool has finished everything. Called before the world is
## thrown away - a worker still reading a chunk we are about to drop is exactly
## the kind of bug that shows up once a month and never reproduces.
func _drain_jobs() -> void:
	for chunk_pos in _gen_in_flight:
		WorkerThreadPool.wait_for_task_completion(_gen_in_flight[chunk_pos]["task"])
	_gen_in_flight.clear()
	for chunk_pos in _in_flight:
		WorkerThreadPool.wait_for_task_completion(_in_flight[chunk_pos]["task"])
	_in_flight.clear()
	for col in _flora_in_flight:
		WorkerThreadPool.wait_for_task_completion(_flora_in_flight[col]["task"])
	_flora_in_flight.clear()


func _nearer_to_centre(a: Vector3i, b: Vector3i) -> bool:
	# Horizontal distance only - vertical order does not change how it looks.
	var da := (a.x - _center.x) * (a.x - _center.x) + (a.z - _center.y) * (a.z - _center.y)
	var db := (b.x - _center.x) * (b.x - _center.x) + (b.z - _center.y) * (b.z - _center.y)
	return da < db


# --- The loaded region ------------------------------------------------------

## Move the loaded region. Takes a position in METRES, because that is what
## everything outside worldgen speaks; the conversion to chunk space happens
## here, once.
##
## Returns true if the region actually moved, so callers can skip the rebuild
## work that follows a move (the far-field mesh, in Stage 7).
func set_center_from_position(pos_m: Vector3) -> bool:
	var bx := int(floor(pos_m.x / config.block_size))
	var bz := int(floor(pos_m.z / config.block_size))
	var c := Vector2i(Chunk.floor_div(bx, Chunk.SIZE), Chunk.floor_div(bz, Chunk.SIZE))
	if c == _center:
		return false
	_center = c
	refresh_region()
	# The voxel hole in the far mesh has moved, so the far mesh is now wrong.
	# Rebuilding is threaded, so this costs the main thread nothing.
	if _far_field != null:
		_far_field.request_rebuild(_center * Chunk.SIZE)
	return true


## Bring the loaded set in line with where the centre now is: queue what is
## missing inside the radius, free what has fallen well outside it.
func refresh_region() -> void:
	var radius: int = config.voxel_radius_chunks
	var radius_sq := radius * radius
	var lo := _world_chunk_min()
	var hi := _world_chunk_max()

	var wanted := {}
	for dz in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			# A disc, not a square. The corners of a square are 1.41x the
			# radius away, so a square loads twice the chunks to show the
			# player terrain they cannot see any better than the rest.
			if dx * dx + dz * dz > radius_sq:
				continue
			var cx := _center.x + dx
			var cz := _center.y + dz
			if cx < lo or cx > hi or cz < lo or cz > hi:
				continue  # outside the bounded world
			for cy in _column_chunk_range(cx, cz):
				wanted[Vector3i(cx, cy, cz)] = true

	for pos in wanted:
		# _gen_in_flight is the third place a chunk can be. Forgetting it here
		# would queue a second copy of every chunk currently generating, and
		# the two would race to install a node under the same key.
		if not _chunks.has(pos) and not _gen_in_flight.has(pos) \
				and not _queued.has(pos):
			_build_queue.append(pos)
			_queued[pos] = true

	_free_distant_chunks(radius + UNLOAD_MARGIN_CHUNKS)
	_refresh_flora()

	# Nearest-first, so the world grows outward from the player rather than
	# popping in in some arbitrary order.
	_build_queue.sort_custom(Callable(self, "_nearer_to_centre"))


## HOOK 3 OF 4: free, and queue. Bring the flora columns in line with where the
## player is.
##
## flora_radius_m IS MUCH SMALLER THAN THE VOXEL RADIUS - 64 m against 96 - and
## that is the point of it being a separate radius rather than the same one.
## Ground cover is 30 cm tall: past about 60 m it is a green haze that costs
## its full triangle count and adds nothing you could describe. Trees are 10 m
## and carry on being trees to the horizon, which is what Stage 7's impostor
## ring is for.
func _refresh_flora() -> void:
	var radius := _flora_radius_chunks()
	var radius_sq := radius * radius

	var wanted := {}
	for dz in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			if dx * dx + dz * dz > radius_sq:
				continue
			var col := Vector2i(_center.x + dx, _center.y + dz)
			wanted[col] = true
			if not _flora_nodes.has(col) and not _flora_in_flight.has(col) \
					and not _flora_queued.has(col):
				_flora_queue.append(col)
				_flora_queued[col] = true

	var doomed: Array[Vector2i] = []
	for col in _flora_nodes:
		if not wanted.has(col):
			doomed.append(col)
	for col in doomed:
		var node: FloraColumn = _flora_nodes[col]
		_flora_instances -= node.instance_count
		node.queue_free()
		_flora_nodes.erase(col)

	# Anything still queued but no longer wanted is dropped before it costs a
	# worker. A job already in flight is left to finish and discarded on
	# arrival - cancelling it is not worth the bookkeeping.
	if not _flora_queue.is_empty():
		var still: Array[Vector2i] = []
		for col in _flora_queue:
			if wanted.has(col):
				still.append(col)
			else:
				_flora_queued.erase(col)
		_flora_queue = still


func _flora_radius_chunks() -> int:
	if config.flora_radius_m <= 0.0:
		return -1
	var per_chunk := float(Chunk.SIZE) * config.block_size
	return int(ceil(config.flora_radius_m / maxf(per_chunk, 0.001)))


func _wants_flora(col: Vector2i) -> bool:
	var radius := _flora_radius_chunks()
	var dx := col.x - _center.x
	var dz := col.y - _center.y
	return dx * dx + dz * dz <= radius * radius


## Instances currently drawn, and columns holding them. For the F3 readout.
func flora_stats() -> Dictionary:
	return {
		"instances": _flora_instances,
		"columns": _flora_nodes.size(),
		"pending": _flora_queue.size() + _flora_in_flight.size(),
	}


## Which chunks of one column terrain actually passes through.
func _column_chunk_range(cx: int, cz: int) -> Array:
	var span := generator.column_surface_range(cx, cz)
	# Trees stand ABOVE the terrain, so the empty sky a canopy can reach into
	# still has to be built. Without this a tree on a column near the top of a
	# chunk loses its crown to a chunk that was never queued.
	var top := Chunk.floor_div(
		int(floor(span.y)) + generator.max_tree_height(), Chunk.SIZE)
	var bottom := Chunk.floor_div(
		int(floor(span.x)) - config.voxel_depth_chunks * Chunk.SIZE, Chunk.SIZE)
	var max_cy := int(config.world_height_blocks / Chunk.SIZE) - 1
	return range(maxi(bottom, 0), mini(top, max_cy) + 1)


func _free_distant_chunks(keep_radius: int) -> void:
	var keep_sq := keep_radius * keep_radius
	var doomed: Array[Vector3i] = []
	for pos in _chunks:
		var dx: int = pos.x - _center.x
		var dz: int = pos.z - _center.y
		# Never free a chunk a worker is still reading. It will drift out of
		# range again on the next refresh, by which time its job is done.
		if dx * dx + dz * dz > keep_sq and not _in_flight.has(pos):
			doomed.append(pos)
	for pos in doomed:
		_chunks.erase(pos)
		var node: ChunkNode = _chunk_nodes.get(pos)
		if node != null:
			node.queue_free()
			_chunk_nodes.erase(pos)
	# Edits are NOT dropped with the chunk. _edits is the authoritative
	# difference between the seed and the world, and _replay_edits_for() puts
	# them back when the chunk is regenerated - which is what lets a player
	# walk away from a hole they dug and find it still there.
	if not _build_queue.is_empty():
		var still: Array[Vector3i] = []
		for pos in _build_queue:
			var dx: int = pos.x - _center.x
			var dz: int = pos.z - _center.y
			if dx * dx + dz * dz <= keep_sq:
				still.append(pos)
			else:
				_queued.erase(pos)
		_build_queue = still


func _world_chunk_min() -> int:
	return Chunk.floor_div(-int(config.world_blocks_xz / 2), Chunk.SIZE)


func _world_chunk_max() -> int:
	return Chunk.floor_div(int(config.world_blocks_xz / 2) - 1, Chunk.SIZE)


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

	# A chunk still out at the worker pool has no voxels to write into yet, so
	# the edit cannot be applied - but it must still be ACCEPTED, or a player
	# digging into ground that has just come into range would have the edit
	# silently dropped, and only sometimes, depending on how busy the pool was.
	# Recording it is enough: _collect_generated() replays it the moment the
	# voxels arrive, before the chunk is meshed.
	var pending := _gen_in_flight.has(Chunk.world_to_chunk(world_block_pos))
	if pending:
		# No way to know whether this changes anything, since the ground it
		# would change does not exist yet. Accepting a redundant edit costs one
		# broadcast; rejecting a real one loses it forever.
		if _edits.get(world_block_pos) == block_id:
			return
	elif not _apply_edit_locally(world_block_pos, block_id):
		# Nothing changed (already that block), so nothing to tell anyone.
		return

	_edits[world_block_pos] = block_id
	# Nobody to tell when hosting alone, and rpc() without a peer is an error.
	if not Net.other_peer_ids().is_empty():
		_cl_apply_block.rpc(world_block_pos, block_id)


## The host says yes or no. Today the rules are minimal; reach distance,
## tool checks and rate limiting all belong here later - one place, so a
## client cannot route around them.
func _validate_edit(_sender_id: int, world_block_pos: Vector3i, block_id: int) -> bool:
	if block_id < 0 or block_id >= Block.NAMES.size():
		return false
	# Only edit chunks we have, or are about to have. A chunk still generating
	# counts: its edit is recorded and replayed on completion, so nothing is
	# lost. A chunk that is neither is genuinely out of range and the edit is
	# refused, which is what stops a client editing the far side of the world.
	var cpos := Chunk.world_to_chunk(world_block_pos)
	return has_chunk(cpos) or _gen_in_flight.has(cpos)


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
	# And the plants standing on it. The G test slab exercises this: drop a
	# slab of stone on a meadow and the grass that was there is now growing
	# through it.
	_flora_dirty_at_block(world_block_pos)
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


## Flora sits on the surface, so a changed block can leave a tuft of grass
## floating over a hole. Rebuilding the column is the whole fix, and it is one
## call because the column is the unit flora is built in.
func _flora_dirty_at_block(world_block_pos: Vector3i) -> void:
	_flora_dirty(Vector2i(
		Chunk.floor_div(world_block_pos.x, Chunk.SIZE),
		Chunk.floor_div(world_block_pos.z, Chunk.SIZE)))


func _remesh(cpos: Vector3i) -> void:
	var node: ChunkNode = _chunk_nodes.get(cpos)
	if node != null:
		node.rebuild(Callable(self, "is_solid_world"))


## Y of the highest solid block in this column, in BLOCKS. Used for putting
## things on the ground instead of inside it.
##
## Asks the generator rather than scanning voxels downward: the generator knows
## the answer directly, and it is right even for a column whose chunks are not
## loaded yet - which is exactly the case at spawn.
func find_surface_y(wx: int, wz: int) -> int:
	return int(floor(generator.surface_at(float(wx), float(wz))))


## Where the player starts, in METRES, already clear of the ground.
func spawn_position_m(clearance_m: float) -> Vector3:
	var b := generator.spawn_block
	return Vector3(
		float(b.x) * config.block_size,
		surface_height_m(b.x, b.y) + clearance_m,
		float(b.y) * config.block_size)


## Same thing in metres, which is what anything outside worldgen wants.
func surface_height_m(wx: int, wz: int) -> float:
	return generator.surface_at(float(wx), float(wz)) * config.block_size


func _replay_edits_for(chunk: Chunk) -> void:
	if _edits.is_empty():
		return
	var origin := chunk.origin()
	for pos in _edits:
		var local: Vector3i = pos - origin
		if Chunk.in_bounds(local.x, local.y, local.z):
			chunk.set_voxel(local.x, local.y, local.z, _edits[pos])


## True once a seed is known, i.e. setup() has been called.
func has_seed() -> bool:
	return generator != null


## Leaving the scene while workers are still meshing would free chunks out from
## under them. Draining first is cheap - the jobs are milliseconds - and turns
## a rare crash on scene change into nothing at all.
func _exit_tree() -> void:
	_drain_jobs()
	if _far_field != null:
		_far_field.drain()
