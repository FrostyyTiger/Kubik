class_name World
extends Node3D

## The loaded frontier moved: the far mesh and the impostor ring both cut their
## inner edge to it, so both want to know. Emitted at most once a frame.
signal frontier_moved

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

## THE CHUNK CACHE (world feel v1 Stage 4), counted in CHUNKS.
##
## A column leaving the unload ring is not freed: its nodes are hidden, its
## colliders disabled, and it is parked here. Turning round used to rebuild the
## trail you had just walked - measured at Stage 0 as every column of the
## return leg.
##
## THE PLAN SAYS 3,000, WITH A 250 MB CEILING ON THE CACHE, and 3,000 is what
## it is - but only after measuring twice, because the first measurement looked
## like a fail and was not.
##
## Godot's static memory with the cache full is 268.9 MB at 2,996 chunks and
## 226.1 MB at 1,997. That is the WHOLE PROCESS, not the cache, and the first
## figure alone reads as over the ceiling. The difference between the two is
## what isolates it: 42.8 MB per 999 chunks, so the cache is about **86 MB at
## 2,000 and 128 MB at 3,000** - comfortably inside 250 MB, and the 268.9 was
## the heightmap, the lakes, the far mesh and the flora buffers.
##
## 3,000 chunks is about 600 columns, a few 48 m steps of trail.
const CHUNK_CACHE_CHUNKS := 3000

## HOW FAR IN FRONT OF A MOVING PLAYER THE QUEUE LEANS, in chunks.
##
## The build queue is nearest-first, which is right for a player standing still
## and wrong for one sprinting: the columns behind them are nearer than the
## ones they are running at. This biases the sort key along the direction of
## travel. Zero below WALKING_SPEED, so a standing player is nearest-first
## exactly as before.
const STREAM_HEADING_BIAS := 0.0
const HEADING_MIN_SPEED := 2.0

## Nodes freed in one frame, at most. The rest wait for the next one.
const FREES_PER_FRAME := 32

## Parked columns brought back in one frame, at most.
##
## A crossing can want dozens at once - turning round wants a whole disc - and
## restoring them all in the frame the centre moved is a hitch of exactly the
## kind this stage exists to remove. Measured: uncapped, the return leg of a
## sprint hit 50.7 ms frames. Spread, it does not.
const RESTORES_PER_FRAME := 8

## Collision-only columns given their mesh in one frame, at most. Same reason
## and same shape as RESTORES_PER_FRAME: re-meshing a column is six or seven
## main-thread uploads, and a peer walking towards the host can hand over
## dozens of columns at once.
const UPGRADES_PER_FRAME := 2

## Flora columns kept hidden after they leave the far ring, most recent last.
##
## 1024, measured. The far disc is about 800 columns and a 48 m move replaces
## 188 of them, so 256 - the first value - held a single step back and the
## probe rebuilt everything past it. 1024 is five steps, and a column is a
## few kilobytes of buffer plus its MultiMesh objects: a few megabytes on the
## render server for every step back the way you came being free.
const FLORA_CACHE_COLUMNS := 1024

## Chunk columns of hysteresis on the flora rings, for the same reason chunks
## have UNLOAD_MARGIN_CHUNKS: a player shuffling on a ring boundary must not
## evict and restore the same column every step.
const FLORA_MARGIN_CHUNKS := 1

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
var _build_queue: Array[Vector2i] = []

## Mirror of _build_queue, for membership tests only. refresh_region() asks
## "is this already queued" once per wanted chunk, and Array.has() is a linear
## scan - the two together were O(n^2) over thousands of chunks, which was a
## visible hitch on the main thread every time the player crossed a chunk
## boundary. Every write to _build_queue keeps this in step.
var _queued := {}

## Chunk-space column the loaded region is centred on. Stage 4's player drives
## it; until then it stays at the spawn column.
var _center := Vector2i.ZERO

## HOST ONLY, and empty in every other case. The chunk column each remote peer's
## simulated body is standing in - see set_sim_centres() and
## WorldgenConfig.sim_radius_chunks.
var _sim_centres: Array[Vector2i] = []

## Columns that were built for collision only and have no mesh. A column in
## here that comes inside the host's own disc is upgraded rather than rebuilt.
var _collision_only := {}

## Columns waiting to be given the mesh they were not built with. Drained a few
## per frame like the cache restores, because a mesh is a main-thread upload.
var _upgrade_queue: Array[Vector2i] = []

## Set by Game. World does not own bodies - it owns columns, and a body outlives
## the column it was born in - so all it does is tell BodyField which columns
## have arrived and which have gone. See body_field.gd.
var body_field: BodyField = null

## Emitted once, for the first full load. With streaming the queue empties
## every time the player stops walking, and a signal that fired then would have
## Game re-running its spawn logic for the rest of the session.
var _initial_load_reported := false

## COLUMN (Vector2i of chunk x,z) -> {"task": int, "job": ColumnJob}. Columns
## whose chunks - voxels, trees, meshes and collision faces - are being built
## by the worker pool, and which therefore DO NOT EXIST YET in _chunks.
## Everything that asks "is this chunk here" has to know about this set too.
##
## ONE SET, AND IT IS A COLUMN, since world feel v1 Stages 1 and 2. There were
## two sets keyed by chunk, one per phase, and a chunk moved between them
## through the main thread. See ColumnJob.
var _in_flight := {}

## Columns whose chunks have all landed. The unit of work is the column, so
## "is this here" is a column question - and it has to be its own set rather
## than a test on _chunks, because a column's SKY chunks are deliberately never
## built (see ColumnJob's ceiling) and would never appear there.
var _loaded_columns := {}

## Columns built since the world was, for the ms-per-column readout.
var _columns_built := 0

## THE FRONTIER (world feel v1 Stage 3). How far out, per angular sector, every
## wanted column has actually landed.
##
## WHY IT EXISTS. The far mesh used to cut its hole at one radius the instant
## the centre column changed - `voxel_radius - 2 cells`, everywhere at once -
## on the assumption that the voxels had it covered. Ahead of a moving player
## they do not: the hole moves the moment you cross a boundary and the voxels
## arrive seconds later, so the ground in front of you is neither far mesh nor
## voxels. That is what the Stage 0 baseline measured as 126 of 144 samples
## with a hole in them, and it is the "missing ground" the playtest reported.
##
## `_sector_missing[sector][ring]` counts wanted columns at that ring in that
## sector which are NOT loaded. It is filled once per crossing inside the scan
## refresh_region() already does, and adjusted by one as each column lands - so
## nothing scans the disc twice. The frontier of a sector is the first ring
## with a missing column in it.
const FRONTIER_SECTORS := 16

## The frontier is reported in steps of this many chunks. See _recompute_frontier().
const FRONTIER_STEP_CHUNKS := 2

var _sector_missing := []
var _frontier := PackedInt32Array()
var _frontier_dirty := true

## Set when a column lands. The far mesh and the impostor ring follow the
## frontier, so they have to rebuild when it MOVES - not only when the centre
## column changes, which is what they used to key off. request_rebuild()
## already coalesces, so this costs one worker rebuild per frontier change at
## most, and in practice a handful over a 48 m move.
var _frontier_advanced := false

## The frontier the far mesh was last ASKED for. See _process().
var _frontier_last_sent := PackedInt32Array()

## Parked columns: Vector2i -> {"chunks": {cy: Chunk}, "nodes": {cy: ChunkNode}}.
## _cache_order is the LRU, oldest first.
var _column_cache := {}
var _cache_order: Array[Vector2i] = []
var _cache_chunks := 0

## Nodes waiting to be freed, spread over frames.
var _pending_frees: Array[ChunkNode] = []

## Parked columns that are wanted again, waiting their turn. A column here is
## neither loaded nor queued for a worker: it is built already and is coming
## back within a few frames.
var _pending_restores: Array[Vector2i] = []
var _restore_queued := {}

## Unit vector the player is travelling in, or zero when they are not. Set from
## successive recentres.
var _heading := Vector3.ZERO
var _last_center_m := Vector3.ZERO
var _have_last_center := false

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
var _flora_triangles := 0
var _flora_ms := 0
var _flora_built := 0          # columns built on workers, for the ms-per-column readout

## Columns that walked out of range, KEPT rather than freed - hidden, in
## insertion order, so the oldest is the first evicted. Look v1's playtest
## found the cost of not having this: turn round and the meadow you just
## walked through is rebuilt from scratch, tuft by tuft, while you stand on
## bare ground. A column's buffers are a few kilobytes; FLORA_CACHE_COLUMNS
## of them is the price of never paying twice for the same hillside.
var _flora_cache := {}         # Vector2i -> FloraColumn, hidden

## Flora instances that have been taken out of the world, as a set of 64-bit
## identities. Host-owned, in the same spirit as _edits.
##
## THE DIFFERENCE FROM THE WORLD, NOT THE WORLD. There are nearly nine million
## flora instances on seed 42 and this dictionary holds none of them: an
## instance's identity is a pure function of its position, so placement can
## recompute it and ask "was this one taken" for the cost of one lookup.
## Gathering a thousand plants therefore costs a thousand integers, and
## gathering none costs nothing at all.
##
## NOT YET WIRED TO ANYTHING. Stage 9 builds the identity and the removal path
## up to but not including the RPC - see remove_flora_local().
var _flora_removed := {}

## Every basin in the world, and the water sitting in it.
var lakes: Lakes = null
var _water: MeshInstance3D = null

## Wall clock, as distinct from _total_ms which counts main-thread time only.
## With threading those two stop being the same number, and the gap between
## them is precisely what the threading bought.
var _wall_start_ms := 0

var _total_ms := 0
var _built := 0

## WORLD FEEL V1 STAGE 0 - the live counters behind the F4 readout.
##
## The crossing is where a frame is lost, so the two numbers that describe one
## are kept from the last crossing rather than averaged away: how many nodes it
## freed and how long refresh_region took. `_max_frame_ms_2s` is a rolling
## window, because a max since load is a number that only ever goes up and
## stops meaning anything after the first hitch.
var _freed_last_crossing := 0
var _refresh_ms := 0.0
var _max_frame_ms_2s := 0.0
var _frame_window := []

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
	_far_field.request_rebuild(_center * Chunk.SIZE, loaded_frontier())

	refresh_region()
	print("[World] seed %d, %d chunks queued around %s" % [
		p_seed, _build_queue.size(), _center])


func _process(delta: float) -> void:
	_track_frame(delta)
	if _build_queue.is_empty() and _in_flight.is_empty() \
			and _flora_queue.is_empty() \
			and _flora_in_flight.is_empty():
		return

	# Spend a bounded slice of this frame on chunk work. Doing it all at once
	# would freeze the window for seconds with no sign of life.
	var started := Time.get_ticks_msec()
	var budget := BUILD_BUDGET_MS if _initial_load_reported else INITIAL_BUILD_BUDGET_MS
	_collect_finished(started, budget)
	_submit_jobs()
	_submit_flora()
	_drain_restores()
	_drain_upgrades()
	_drain_frees()

	# THE FAR MESH AND THE IMPOSTORS FOLLOW THE FRONTIER. Both used to key off
	# a centre crossing, which is exactly when the voxels have NOT arrived yet;
	# they now rebuild when the frontier itself moves. request_rebuild()
	# coalesces, so a burst of landing columns costs one rebuild.
	if _frontier_advanced:
		_frontier_advanced = false
		# ONLY WHEN IT ACTUALLY MOVED. _frontier_advanced is set by every
		# column that lands, which during a stream is every frame - and asking
		# for a rebuild every frame keeps a worker permanently busy on the far
		# mesh, on a pool that runs one GDScript task at a time. Measured: it
		# cost 1.4 s on the 48 m settle. A sector's frontier changing by a
		# chunk is the event; a column landing is not.
		var now := loaded_frontier()
		if now != _frontier_last_sent:
			_frontier_last_sent = now
			if _far_field != null:
				_far_field.request_rebuild(_center * Chunk.SIZE, now)
			frontier_moved.emit()

	_total_ms += Time.get_ticks_msec() - started

	if is_idle() and not _initial_load_reported:
		_initial_load_reported = true
		var wall := Time.get_ticks_msec() - _wall_start_ms
		var n := float(maxi(_built, 1))
		print("[World] %d chunks in %d ms wall (%d ms main thread; %.2f ms gen per chunk on workers, %.2f ms main-thread upload per chunk)" % [
			_built, wall, _total_ms, float(_gen_ms) / 1000.0 / n,
			float(_mesh_ms) / 1000.0 / n])
		print("[World] far field %d vertices" % _far_vertices)
		print("[World] flora %d instances, %.2f M triangles, %d columns, %.2f ms per column on workers" % [
			_flora_instances, float(_flora_triangles) / 1000000.0,
			_flora_nodes.size(),
			float(_flora_ms) / 1000.0 / float(maxi(_flora_built, 1))])
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
	return _in_flight.has(Vector2i(chunk_pos.x, chunk_pos.z))


## Is there something to STAND ON in this chunk yet? Stricter than has_chunk():
## the voxels arrive first and the mesh with its trimesh arrives with the
## upload, frames later. Anything that means to put a body on the ground has
## to ask this one, or it puts the body in the ground.
func is_chunk_collidable(chunk_pos: Vector3i) -> bool:
	var node: ChunkNode = _chunk_nodes.get(chunk_pos)
	if node != null:
		return node.collision_applied
	# A CHUNK THAT WAS NEVER BUILT BECAUSE IT IS ALL AIR answers true once its
	# column has landed (world feel v1 Stage 2). There is nothing to stand on
	# in it and nothing missing from it, and the alternative - answering false
	# forever for every sky chunk - would tell the stream probe the world has a
	# hole in it wherever the ceiling did its job.
	return _loaded_columns.has(Vector2i(chunk_pos.x, chunk_pos.z))


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
	for col in _flora_cache:
		_flora_cache[col].queue_free()
	_flora_cache.clear()
	_flora_queue.clear()
	_flora_queued.clear()
	_flora_instances = 0
	_flora_triangles = 0
	_flora_ms = 0
	_flora_built = 0
	_build_queue.clear()
	_queued.clear()
	_loaded_columns.clear()
	_columns_built = 0
	for col in _column_cache:
		for cy in _column_cache[col]["nodes"]:
			var n: ChunkNode = _column_cache[col]["nodes"][cy]
			if is_instance_valid(n):
				n.queue_free()
	_column_cache.clear()
	_cache_order.clear()
	_cache_chunks = 0
	_pending_frees.clear()
	_pending_restores.clear()
	_restore_queued.clear()
	_heading = Vector3.ZERO
	_have_last_center = false
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
		and _in_flight.is_empty() \
		and _flora_queue.is_empty() and _flora_in_flight.is_empty()


func loaded_chunk_count() -> int:
	return _chunks.size()


func queued_chunk_count() -> int:
	return _build_queue.size()


## Chunks that have been meshed and uploaded since the world was built. The
## streaming probe's supply number - `built/s` over a sprint is the whole of
## what night 1's first half moves.
func built_chunk_count() -> int:
	return _built


## How far out, in metres and IN THIS DIRECTION, the far mesh declines to draw
## because the voxels are expected to cover it.
##
## PER SECTOR SINCE STAGE 3. It used to be one radius everywhere, cut the
## instant the centre column changed; it is now the frontier of the direction
## you are asking about, minus the same two-cell overlap. A column further out
## than this is covered by the far mesh, so its absence is not a hole - which
## is exactly the question the stream probe asks four times a second.
func far_field_exclusion_m(dir: Vector3) -> float:
	if _far_field == null:
		return 0.0
	# THE MESH THAT EXISTS, not the frontier that will be used next rebuild. A
	# rebuild takes a frame or two on a worker and during that window the hole
	# on screen is the old one - which is precisely the window a hole could
	# hide in.
	var f := _far_field.built_frontier()
	if f.is_empty():
		return _far_field.exclusion_blocks() * config.block_size
	var s := frontier_sector_of(int(round(dir.x * 1000.0)), int(round(dir.z * 1000.0)))
	# THE SAME CONSTANT THE JOB CUT THE MESH WITH. Keeping a second copy of it
	# here is how the probe came to report 21 holes that were not there: the
	# job had widened its overlap and this had not.
	var blocks := maxf(float(f[s] * Chunk.SIZE)
		- float(FarFieldJob.FRONTIER_OVERLAP_CELLS
			* FarFieldJob.base_step_blocks(config)), 0.0)
	return blocks * config.block_size


## Averages, not totals: a total tells you the world loaded, a per-chunk
## average tells you whether the next one will arrive in time. The HUD shows
## these live and they are the number the performance work in Stage 6 moves.
func last_timings() -> Dictionary:
	var n: int = maxi(_built, 1)
	return {
		"gen_ms": float(_gen_ms) / 1000.0 / float(n),
		"mesh_ms": float(_mesh_ms) / 1000.0 / float(n),
		"heightmap_ms": _heightmap_ms,
		# WORLD FEEL V1 STAGE 0. The averages above are cumulative since load,
		# which is the right number for "did the world arrive" and the wrong
		# one for "is it keeping up NOW" - a 20-second load buries a two-second
		# stall. These are the live ones.
		"columns_in_flight": _in_flight.size(),
		"columns_built": _columns_built,
		"ms_per_column": (float(_gen_ms) / 1000.0 / float(maxi(_columns_built, 1))),
		"chunks_per_column": (float(_built) / float(maxi(_columns_built, 1))),
		"built": _built,
		"freed_last_crossing": _freed_last_crossing,
		"refresh_ms": _refresh_ms,
		"max_frame_ms": _max_frame_ms_2s,
		"cached_chunks": _cache_chunks,
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
		var col: Vector2i = _build_queue.pop_front()
		_queued.erase(col)
		if _in_flight.has(col) or _column_loaded(col):
			continue
		_submit_column(col)


func _jobs_in_flight() -> int:
	return _in_flight.size() + _flora_in_flight.size()


## HOOK 1 OF 4: submit. Hand queued flora columns to the worker pool.
##
## AFTER the terrain, and sharing its cap, which is the whole of the priority
## policy: a column of grass matters only if there is ground under it, so
## terrain jobs are offered the pool first and flora takes what is left. On a
## busy load that means flora arrives a moment behind the ground, which is
## exactly the order a player notices things in.
##
## BUT NEVER STARVED. A walking player keeps the terrain queue full for as
## long as they walk, and with a shared cap the grass never got a worker at
## all until they stopped - look v1's playtest saw bare ground trailing the
## player and filling in only when they stood still. So one flora job may run
## OVER the cap when none is in flight: the ground still comes first, the
## grass merely always comes.
func _submit_flora() -> void:
	while not _flora_queue.is_empty():
		var lane_free := _jobs_in_flight() < _max_jobs_in_flight \
			or _flora_in_flight.is_empty()
		if not lane_free:
			return
		var col: Vector2i = _flora_queue.pop_front()
		_flora_queued.erase(col)
		if _flora_in_flight.has(col):
			continue
		if not _wants_flora(col):
			continue
		var job := FloraJob.new()
		job.column = col
		job.generator = generator
		job.config = config
		job.bodies_only = _flora_fraction_for(col) <= 0.0
		# ALWAYS THE FULL COLUMN. The ring a column is in decides how much of
		# it is shown, not how much of it is built - see FloraColumn.
		job.draw_fraction = config.flora_draw_fraction
		# A SNAPSHOT, not the live dictionary. The job reads it on a worker
		# thread and the main thread may be inserting into it at the same
		# moment. Duplicated only when it has anything in it, which for now is
		# never - so the common case costs one is_empty().
		job.removed = {} if _flora_removed.is_empty() else _flora_removed.duplicate()
		job.edited = _edited_blocks_in(col)
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


## Hand a whole COLUMN - every chunk of it - to the worker pool.
##
## ONE TASK PER COLUMN (world feel v1 Stage 2). See ColumnJob for why: the tree
## candidate scan was being re-run once per chunk of the column, and it is half
## the generation cost.
##
## None of the column's chunks is in _chunks until the job completes - the
## worker is writing into them - which is why the column is held in _in_flight
## and nothing may read it in the meantime.
##
## THE NODES ARE NOT CREATED HERE. They are created at collection with the
## meshes already in hand, which is also where the ceiling is applied: a chunk
## the job decided was all air gets no node at all.
func _submit_column(col: Vector2i) -> void:
	var job := ColumnJob.new()
	job.chunk_x = col.x
	job.chunk_z = col.y
	job.cy_range = _column_chunk_range(col.x, col.y)
	job.generator = generator
	job.config = config
	job.world_seed = world_seed
	job.neighbours = _column_neighbour_chunks(col)
	# A column wanted only by a peer's collision ring is built without a mesh.
	# The arrays are still produced - the faces come from them - but nothing is
	# uploaded to the rendering server. See ChunkNode.apply_arrays().
	job.mesh = not _collision_only.has(col)
	_in_flight[col] = {
		"task": WorkerThreadPool.add_task(job.run, false, "kubik column"),
		"job": job,
	}


## Is this column inside the host's own visible disc?
func _inside_disc(col: Vector2i, radius_sq: int) -> bool:
	var dx := col.x - _center.x
	var dz := col.y - _center.y
	return dx * dx + dz * dz <= radius_sq


## WHERE THE HOST'S SIMULATED PEERS ARE (world feel v1 Stage 10).
##
## Set by Game once per sync tick from the PlayerSim bodies, in chunk columns.
## Empty on a client and on a host playing alone, and in both of those cases
## every line this touches is a loop over nothing.
##
## Refreshes the region when the set changes, because a peer crossing a chunk
## boundary is exactly as much a reason to stream as the local player doing it.
func set_sim_centres(cols: Array[Vector2i]) -> void:
	if cols == _sim_centres:
		return
	_sim_centres = cols.duplicate()
	refresh_region()


## Every column inside sim_radius_chunks of any simulated peer, clipped to the
## world. A dictionary because two peers standing together would otherwise
## queue the overlap twice.
func _sim_ring_columns(lo: int, hi: int) -> Dictionary:
	var out := {}
	if _sim_centres.is_empty():
		return out
	var r: int = config.sim_radius_chunks
	var r_sq := r * r
	for centre in _sim_centres:
		for dz in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if dx * dx + dz * dz > r_sq:
					continue
				var cx := centre.x + dx
				var cz := centre.y + dz
				if cx < lo or cx > hi or cz < lo or cz > hi:
					continue
				out[Vector2i(cx, cz)] = true
	return out


## HOOK: give a column the mesh it was built without. A few per frame, because
## every one of them is a main-thread upload - the same reason the cache
## restores are budgeted.
func _drain_upgrades() -> void:
	var done := 0
	while not _upgrade_queue.is_empty() and done < UPGRADES_PER_FRAME:
		var col: Vector2i = _upgrade_queue.pop_front()
		for cy in _column_chunk_range(col.x, col.y):
			var node: ChunkNode = _chunk_nodes.get(Vector3i(col.x, cy, col.y))
			if node == null or node.mesh_built:
				continue
			node.rebuild(Callable(self, "is_solid_world"))
		done += 1


## Is every chunk this column would build already loaded?
##
## Asked instead of `_chunks.has(pos)` because the unit of work is the column:
## a column is loaded when its chunks are there, and "there" includes the sky
## chunks the ceiling decided not to build, which will never appear in _chunks.
## The cheap test is the surface chunk - the one a column always has.
func _column_loaded(col: Vector2i) -> bool:
	return _loaded_columns.has(col)


## The chunks of the four neighbouring columns that already exist, for this
## column's mesher to ask about the blocks along its edges. Anything missing
## falls back to the generator, which gives the same answer the real chunk
## will - which is why the edge of the loaded region does not sprout a wall of
## faces.
func _column_neighbour_chunks(col: Vector2i) -> Dictionary:
	var out := {}
	for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var n := col + d
		for cy in _column_chunk_range(n.x, n.y):
			var pos := Vector3i(n.x, cy, n.y)
			var chunk: Chunk = _chunks.get(pos)
			if chunk != null:
				out[pos] = chunk
	return out


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


## The worst frame in the last two seconds.
##
## A rolling window rather than a max since load: a max since load is a number
## that only goes up, and after the first hitch it stops telling you whether
## the thing you just changed made the next one better.
func _track_frame(delta: float) -> void:
	var now := Time.get_ticks_msec()
	_frame_window.append([now, delta * 1000.0])
	var worst := 0.0
	var keep := []
	for f in _frame_window:
		if now - int(f[0]) <= 2000:
			keep.append(f)
			worst = maxf(worst, float(f[1]))
	_frame_window = keep
	_max_frame_ms_2s = worst


## Install chunks the pool has finished with: publish the voxels, build the
## node, upload the mesh and set the collider.
##
## Upload order does not matter to what the world ends up looking like, which
## is why walking a Dictionary is acceptable here and is not anywhere in
## worldgen: this decides which chunk appears a frame earlier, not what is in
## it.
##
## ONE PASS SINCE STAGE 1. There used to be two - meshes before voxels, and
## the order was load-bearing, because a busy pool could otherwise fill the
## whole budget with publishing while finished meshes queued behind it unseen.
## With one job there is one kind of completion and nothing to starve: a chunk
## arrives finished or it does not arrive.
func _collect_finished(started: int, budget: int = BUILD_BUDGET_MS) -> void:
	_collect_chunks(started, budget)
	_collect_flora(started, budget)


func _collect_chunks(started: int, budget: int) -> void:
	var done: Array[Vector2i] = []
	for col in _in_flight:
		if Time.get_ticks_msec() - started >= budget:
			break
		var entry: Dictionary = _in_flight[col]
		if not WorkerThreadPool.is_task_completed(entry["task"]):
			continue
		# Required even for a task already reported complete - it is what
		# releases the pool's own bookkeeping for it.
		WorkerThreadPool.wait_for_task_completion(entry["task"])
		done.append(col)

	for col in done:
		var job: ColumnJob = _in_flight[col]["job"]
		_gen_ms += job.gen_usec + job.tree_usec
		_in_flight.erase(col)
		_loaded_columns[col] = true
		_column_landed(col)
		_frontier_advanced = true

		var t_upload := Time.get_ticks_usec()
		for cy in job.built:
			var entry: Dictionary = job.built[cy]
			var chunk: Chunk = entry["chunk"]
			var chunk_pos := chunk.chunk_pos
			_chunks[chunk_pos] = chunk

			# THE EDIT-REPLAY POINT, and the reason it has to be exactly here.
			#
			# Every edit accepted while this column was in flight was recorded
			# in _edits and could not be written into any chunk, because there
			# was no chunk to write into. This is the first moment there is.
			#
			# It does one more thing than it used to: the job built the mesh
			# from the voxels it generated, so an edit landing in the window
			# invalidates those arrays - they show the block that was just
			# broken. The chunk is therefore REMESHED rather than the job's
			# arrays used, which costs a main-thread mesh for the rare chunk
			# edited mid-flight - the same cost breaking a block has always had.
			var edited := _replay_edits_for(chunk)

			var node := ChunkNode.new()
			node.setup(chunk, config, world_seed, job.zone)
			add_child(node)
			_chunk_nodes[chunk_pos] = node
			if edited:
				node.rebuild(Callable(self, "is_solid_world"))
			else:
				node.apply_arrays(entry["arrays"], entry["faces"], job.mesh)
			_built += 1
		_mesh_ms += Time.get_ticks_usec() - t_upload
		_columns_built += 1


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
		var entry: Dictionary = _flora_in_flight[col]
		var job: FloraJob = entry["job"]
		_flora_in_flight.erase(col)
		_flora_ms += job.elapsed_usec
		_flora_built += 1
		# The column may have walked out of range while its job was in flight.
		# Dropping the result is right: nothing is drawing it, and the job will
		# be resubmitted if the player comes back.
		if not _wants_flora(col):
			continue
		# THE BODIES FIRST, and for a bodies-only column they are all there is.
		if body_field != null:
			body_field.column_landed(col, job.bodies)
		if job.bodies_only:
			# Nothing is drawn, so there is no FloraColumn to remember them on.
			# A bodies-only column is re-scanned if it comes back, which is the
			# right trade: it is not in the cache either.
			continue
		var node: FloraColumn = _flora_nodes.get(col)
		if node == null:
			node = _flora_cache.get(col)
			if node != null:
				_flora_cache.erase(col)
				node.visible = true
				if body_field != null:
					body_field.column_landed(col, node.bodies)
			else:
				node = FloraColumn.new()
				node.setup(col)
				add_child(node)
			_flora_nodes[col] = node
		_flora_instances -= node.instance_count
		_flora_triangles -= node.triangle_count
		node.draw_fraction = _flora_fraction_for(col)
		node.bodies = job.bodies
		node.apply_buffers(job.buffers, config)
		_flora_instances += node.instance_count
		_flora_triangles += node.triangle_count




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
	for chunk_pos in _in_flight:
		WorkerThreadPool.wait_for_task_completion(_in_flight[chunk_pos]["task"])
	_in_flight.clear()
	for col in _flora_in_flight:
		WorkerThreadPool.wait_for_task_completion(_flora_in_flight[col]["task"])
	_flora_in_flight.clear()


## Which of FRONTIER_SECTORS a column offset falls in, and how far out it is.
##
## Static and trivial on purpose: it is called once per wanted column per
## crossing (~450) and once per far-field quad (~100k), so it must not allocate
## and must agree exactly between World and FarFieldJob - which is why
## FarFieldJob calls this one rather than keeping its own copy.
static func frontier_sector_of(dx: int, dz: int) -> int:
	var a := atan2(float(dz), float(dx)) + PI
	var s := int(a / TAU * float(FRONTIER_SECTORS))
	return clampi(s, 0, FRONTIER_SECTORS - 1)


## The radius, in chunks, out to which every wanted column of each sector has
## landed. Sixteen entries, sector 0 starting at -PI.
##
## Behind the player this is simply the unload radius: a column that is not
## wanted is not missing, so a sector with nothing wanted in it reports the
## full radius and the far mesh keeps its hole there - which is correct,
## because the voxels behind you have not gone anywhere.
func loaded_frontier() -> PackedInt32Array:
	if _frontier_dirty:
		_recompute_frontier()
	return _frontier


func _recompute_frontier() -> void:
	var radius: int = config.voxel_radius_chunks
	if _sector_missing.is_empty():
		_reset_sector_missing()
	_frontier = PackedInt32Array()
	_frontier.resize(FRONTIER_SECTORS)
	for s in FRONTIER_SECTORS:
		var reach := radius
		var counts: PackedInt32Array = _sector_missing[s]
		for r in counts.size():
			if counts[r] > 0:
				reach = r
				break
		# QUANTISED DOWNWARD, in steps of FRONTIER_STEP_CHUNKS. The far mesh is
		# rebuilt whenever this array changes and a rebuild is a whole disc of
		# ~100k vertices on a pool that runs one GDScript task at a time - so
		# reacting to every single chunk of advance cost 1 s on the 48 m
		# settle. Rounding DOWN is the safe direction: the hole is smaller than
		# it strictly needs to be, which is overlap, and overlap is invisible.
		_frontier[s] = (reach / FRONTIER_STEP_CHUNKS) * FRONTIER_STEP_CHUNKS
	_frontier_dirty = false


## Start a fresh count. Called by refresh_region() before its disc scan, which
## is the one place the wanted set is known.
func _reset_sector_missing() -> void:
	var rings: int = config.voxel_radius_chunks + 1
	_sector_missing = []
	for s in FRONTIER_SECTORS:
		var row := PackedInt32Array()
		row.resize(rings)
		_sector_missing.append(row)
	_frontier_dirty = true


func _note_column(col: Vector2i, loaded: bool) -> void:
	if _sector_missing.is_empty():
		return
	var dx := col.x - _center.x
	var dz := col.y - _center.y
	var ring := int(floor(sqrt(float(dx * dx + dz * dz))))
	if ring >= config.voxel_radius_chunks + 1:
		return
	var s := frontier_sector_of(dx, dz)
	var row: PackedInt32Array = _sector_missing[s]
	row[ring] += (0 if loaded else 1)
	_sector_missing[s] = row
	_frontier_dirty = true


## One column has landed: it is no longer missing from its ring.
func _column_landed(col: Vector2i) -> void:
	if _sector_missing.is_empty():
		return
	var dx := col.x - _center.x
	var dz := col.y - _center.y
	var ring := int(floor(sqrt(float(dx * dx + dz * dz))))
	if ring >= config.voxel_radius_chunks + 1:
		return
	var s := frontier_sector_of(dx, dz)
	var row: PackedInt32Array = _sector_missing[s]
	if row[ring] > 0:
		row[ring] -= 1
		_sector_missing[s] = row
		_frontier_dirty = true


func _nearer_to_centre(a: Vector2i, b: Vector2i) -> bool:
	return _queue_key(a) < _queue_key(b)


## Distance squared, pulled forward along the direction of travel.
##
## `d^2 - bias * dot(offset, heading) * |offset|`: a column straight ahead at
## radius r scores r^2 - bias*r, which is the score of one about `bias` chunks
## nearer; a column straight behind is pushed out by the same amount. With no
## heading it is exactly d^2, which is the nearest-first order a standing
## player has always had.
func _queue_key(col: Vector2i) -> float:
	var dx := float(col.x - _center.x)
	var dz := float(col.y - _center.y)
	var d_sq := dx * dx + dz * dz
	if _heading == Vector3.ZERO:
		return d_sq
	var d := sqrt(d_sq)
	return d_sq - STREAM_HEADING_BIAS * (dx * _heading.x + dz * _heading.z) * d


# --- The loaded region ------------------------------------------------------

## Move the loaded region. Takes a position in METRES, because that is what
## everything outside worldgen speaks; the conversion to chunk space happens
## here, once.
##
## Returns true if the region actually moved, so callers can skip the rebuild
## work that follows a move (the far-field mesh, in Stage 7).
func set_center_from_position(pos_m: Vector3) -> bool:
	# THE HEADING, for the queue's velocity bias. Taken from where the player
	# has actually been rather than from their velocity vector, because this is
	# the only thing World is told every frame and a heading that survives one
	# frame of a jump is a heading that biases the queue the wrong way.
	if _have_last_center:
		var d := pos_m - _last_center_m
		d.y = 0.0
		var moved := d.length()
		if moved > 0.0001:
			var speed := moved / maxf(get_process_delta_time(), 0.0001)
			_heading = d / moved if speed > HEADING_MIN_SPEED else Vector3.ZERO
	_last_center_m = pos_m
	_have_last_center = true

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
		_far_field.request_rebuild(_center * Chunk.SIZE, loaded_frontier())
	return true


## Bring the loaded set in line with where the centre now is: queue what is
## missing inside the radius, free what has fallen well outside it.
func refresh_region() -> void:
	var _refresh_t0 := Time.get_ticks_usec()
	var _freed_before := _chunk_nodes.size()
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
			wanted[Vector2i(cx, cz)] = true

	# The frontier's counts are filled from the SAME scan, so nothing walks the
	# disc twice. A column already loaded is not missing; everything else is,
	# until its job lands and _column_landed() takes it off.
	_reset_sector_missing()
	for col in wanted:
		_note_column(col, _column_loaded(col))

	for col in wanted:
		# _in_flight is the third place a column can be. Forgetting it here
		# would queue a second copy of every column currently building, and
		# the two would race to install nodes under the same keys.
		if _column_loaded(col) or _in_flight.has(col) or _queued.has(col):
			continue
		_build_queue.append(col)
		_queued[col] = true

	# THE PEERS' RINGS, ADDED AFTER THE FRONTIER SCAN AND NOT BEFORE.
	#
	# The frontier (Stage 3) is about what the LOCAL player can see - it is
	# what the far field cuts its hole to. A ring 500 m away is not part of
	# that and folding it into the sector counts would tell the far field to
	# leave a hole around a friend nobody is looking at.
	var spare := {}
	for col in _sim_ring_columns(lo, hi):
		spare[col] = true
		if wanted.has(col):
			continue  # already the host's own, and meshed
		wanted[col] = true
		if _column_loaded(col) or _in_flight.has(col) or _queued.has(col):
			continue
		_build_queue.append(col)
		_queued[col] = true
		# Marked BEFORE the job is submitted, because _submit_column reads it
		# to decide whether to mesh.
		_collision_only[col] = true

	# A collision-only column the host's own player has now walked up to needs
	# its mesh. Re-meshed from the voxels it already has rather than rebuilt:
	# generation and the tree scan are the expensive halves and their answers
	# have not changed.
	for col in _collision_only.keys():
		if _column_loaded(col) and _inside_disc(col, radius_sq):
			_collision_only.erase(col)
			if not _upgrade_queue.has(col):
				_upgrade_queue.append(col)

	_free_distant_chunks(radius + UNLOAD_MARGIN_CHUNKS, -1, spare)
	_refresh_flora()

	# Nearest-first, so the world grows outward from the player rather than
	# popping in in some arbitrary order.
	_build_queue.sort_custom(Callable(self, "_nearer_to_centre"))

	# What this crossing cost, for the F4 readout. Stage 4 is the stage that
	# has to bring both of these down; this is where they are measured.
	_freed_last_crossing = maxi(_freed_before - _chunk_nodes.size(), 0)
	_refresh_ms = float(Time.get_ticks_usec() - _refresh_t0) / 1000.0


## HOOK 3 OF 4: free, and queue. Bring the flora columns in line with where the
## player is.
##
## TWO RINGS SINCE THE FLORA STREAMING PASS. Foliage v1 drew ground cover to
## flora_radius_m and nothing beyond, on the argument that 30 cm of grass past
## 60 m is a haze that costs its full triangle count. True - but the edge of
## that haze is a circle moving with the player, and in play the eye finds a
## circle instantly. So beyond the full ring there is now a SPARSE ring out to
## flora_far_m, drawn at flora_far_fraction of the plants. The fraction is
## hashed per plant and the buffers are SORTED by that hash (see FloraJob),
## so the sparse set is a prefix of the full one: crossing from the far ring
## into the near ring is a visible_instance_count change on a buffer the
## column already has. Nothing is rebuilt and nothing reshuffles. Every
## column is built once, at full density, whichever ring it was first seen
## from.
##
## Columns leaving the far ring are not freed. They go to _flora_cache, hidden,
## and come straight back if the player turns round - a column's buffers are
## kilobytes and its build was milliseconds of a worker the player was waiting
## on. The cache is bounded and evicts its oldest.
##
## The queue is SORTED NEAREST-FIRST, which foliage v1's was not: it appended
## in scan order, so the far corners of the disc could be built before the
## grass under the player's feet.
func _refresh_flora() -> void:
	var near := _flora_radius_chunks()
	var far := _flora_far_chunks()
	if near < 0:
		return
	var far_sq := far * far

	var wanted := {}   # col -> fraction it should be drawn at
	for dz in range(-far, far + 1):
		for dx in range(-far, far + 1):
			if dx * dx + dz * dz > far_sq:
				continue
			var col := Vector2i(_center.x + dx, _center.y + dz)
			var fraction := _flora_fraction_for(col)
			if fraction <= 0.0:
				continue
			wanted[col] = fraction
			if _flora_in_flight.has(col) or _flora_queued.has(col):
				continue
			var node: FloraColumn = _flora_nodes.get(col)
			if node == null:
				node = _flora_cache.get(col)
				if node != null:
					# Back from the cache: visible again this frame.
					_flora_cache.erase(col)
					_flora_nodes[col] = node
					node.visible = true
					# Its bodies were freed when it was cached; put them back.
					if body_field != null:
						body_field.column_landed(col, node.bodies)
					_flora_instances += node.instance_count
					_flora_triangles += node.triangle_count
			if node == null:
				_flora_queue.append(col)
				_flora_queued[col] = true
			elif not _fraction_matches(node.draw_fraction, fraction):
				# Crossed a ring: show more or less of a buffer it already
				# has. No worker, no rebuild - see FloraColumn.set_fraction.
				_flora_instances -= node.instance_count
				_flora_triangles -= node.triangle_count
				node.set_fraction(fraction)
				_flora_instances += node.instance_count
				_flora_triangles += node.triangle_count

	# THE PEERS' BODY RINGS. Queued like any other flora column and then not
	# drawn - see _flora_bodies_only(). They are deliberately not in `wanted`
	# above, because `wanted` drives the draw fraction and these are not drawn.
	for col in _sim_ring_columns(_world_chunk_min(), _world_chunk_max()):
		if wanted.has(col) or _flora_nodes.has(col) or _flora_cache.has(col):
			continue
		if _flora_in_flight.has(col) or _flora_queued.has(col):
			continue
		_flora_queue.append(col)
		_flora_queued[col] = true

	# Out of both rings, with hysteresis: keep a column a margin past the far
	# ring so a player on the boundary does not evict and restore it every
	# step. What falls outside the margin goes to the cache, not the bin.
	var keep := far + FLORA_MARGIN_CHUNKS
	var keep_sq := keep * keep
	var doomed: Array[Vector2i] = []
	for col in _flora_nodes:
		var dx: int = col.x - _center.x
		var dz: int = col.y - _center.y
		if dx * dx + dz * dz > keep_sq:
			doomed.append(col)
	for col in doomed:
		var node: FloraColumn = _flora_nodes[col]
		_flora_instances -= node.instance_count
		_flora_triangles -= node.triangle_count
		_flora_nodes.erase(col)
		node.visible = false
		_flora_cache[col] = node
		# THE BODIES STAY WITH THE CACHED PLANTS, and getting this wrong cost
		# 37% of chunk throughput.
		#
		# This used to free them here, on the argument that a body is cheap to
		# rebuild and a broadphase entry is not free. That argument is fine and
		# the PLACE was wrong: the flora cache exists precisely BECAUSE columns
		# churn in and out of the drawn set constantly during a sprint - night 1
		# measured it and cached them for exactly that reason - so freeing
		# bodies on this boundary meant destroying and rebuilding nodes,
		# collision shapes and physics registrations, on the main thread, over
		# and over, all the way across a crossing.
		#
		# A cached body is FROZEN, which is its resting state anyway (see
		# WorldBody.shove), so it costs a broadphase entry and no solver time.
		# They are freed when the column is actually EVICTED from the cache,
		# below, which is where "cheap to rebuild" was always the right trade.
	while _flora_cache.size() > FLORA_CACHE_COLUMNS:
		var oldest: Vector2i = _flora_cache.keys()[0]
		# EVICTED, not merely hidden - this is where the column really goes,
		# and where its bodies go with it. See the note above.
		if body_field != null:
			body_field.column_left(oldest)
		_flora_cache[oldest].queue_free()
		_flora_cache.erase(oldest)

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
		_flora_queue.sort_custom(_flora_nearer_to_centre)


func _flora_radius_chunks() -> int:
	if config.flora_radius_m <= 0.0:
		return -1
	var per_chunk := float(Chunk.SIZE) * config.block_size
	return int(ceil(config.flora_radius_m / maxf(per_chunk, 0.001)))


## Outer edge of the sparse ring, in chunk columns. Never inside the full ring:
## a far radius at or below the near one simply means there is no sparse ring.
func _flora_far_chunks() -> int:
	var near := _flora_radius_chunks()
	if config.flora_far_m <= config.flora_radius_m or config.flora_far_fraction <= 0.0:
		return near
	var per_chunk := float(Chunk.SIZE) * config.block_size
	return maxi(int(ceil(config.flora_far_m / maxf(per_chunk, 0.001))), near)


## The density a column should be drawn at from where the player stands: 1 in
## the full ring, flora_far_fraction in the sparse ring, 0 beyond.
func _flora_fraction_for(col: Vector2i) -> float:
	var near := _flora_radius_chunks()
	if near < 0:
		return 0.0
	var dx := col.x - _center.x
	var dz := col.y - _center.y
	var d_sq := dx * dx + dz * dz
	if d_sq <= near * near:
		return 1.0
	var far := _flora_far_chunks()
	if d_sq <= far * far:
		return config.flora_far_fraction
	return 0.0


## Is this column wanted ONLY so a remote peer has bodies to push?
##
## THE GAP THIS CLOSES (world feel v1 Stage 11). Bodies are promoted out of the
## flora scan, so they exist where flora is built - and flora is built around
## the LOCAL player. Stage 10c gave a remote peer a collision-only ring so it
## has ground; without this it would have ground and no rocks, and every
## boulder it could see on its own screen would be one the host was not
## simulating. Walking up to a rock and finding it welded to the floor is a
## worse bug than the cost of fixing it.
##
## The cost is the placement scan and nothing else - no buffers, no MultiMesh,
## no upload - which is the same trade Stage 10c made for meshes. See
## FloraJob.bodies_only.
func _flora_bodies_only(col: Vector2i) -> bool:
	if _sim_centres.is_empty() or _flora_fraction_for(col) > 0.0:
		return false
	var r: int = config.sim_radius_chunks
	for centre in _sim_centres:
		var dx := col.x - centre.x
		var dz := col.y - centre.y
		if dx * dx + dz * dz <= r * r:
			return true
	return false


static func _fraction_matches(have: float, want: float) -> bool:
	return absf(have - want) < 0.001


func _flora_nearer_to_centre(a: Vector2i, b: Vector2i) -> bool:
	var da := (a.x - _center.x) * (a.x - _center.x) + (a.y - _center.y) * (a.y - _center.y)
	var db := (b.x - _center.x) * (b.x - _center.x) + (b.y - _center.y) * (b.y - _center.y)
	return da < db


func _wants_flora(col: Vector2i) -> bool:
	return _flora_fraction_for(col) > 0.0 or _flora_bodies_only(col)


## Instances currently drawn, and columns holding them. For the F3 readout.
func flora_stats() -> Dictionary:
	return {
		"instances": _flora_instances,
		"triangles": _flora_triangles,
		"columns": _flora_nodes.size(),
		"pending": _flora_queue.size() + _flora_in_flight.size(),
		"cached": _flora_cache.size(),
		"built": _flora_built,
		"ms_per_column": float(_flora_ms) / 1000.0 / float(maxi(_flora_built, 1)),
	}


## Which chunks of one column terrain actually passes through.
func _column_chunk_range(cx: int, cz: int) -> Array:
	var span := generator.column_surface_range(cx, cz)
	# TREES V3 STAGE 7: THE COLUMN ENDS AT THE TERRAIN.
	#
	# This used to add `generator.max_tree_height()` - about twenty-one metres,
	# forty-two blocks at the shipped scales - because a canopy stamped into
	# the volume must not be cut off by a chunk nobody queued. Trees are
	# instanced models now and nothing is written above the ground, so the
	# highest chunk a column needs is the one its own terrain reaches into.
	#
	# It is not free to have carried: every one of those chunks was an entry in
	# this range, a Chunk allocated by ColumnJob, and a column World queued and
	# tracked. The generation was already skipped (the ceiling in ColumnJob) -
	# the bookkeeping was not.
	var top := Chunk.floor_div(int(floor(span.y)), Chunk.SIZE)
	var bottom := Chunk.floor_div(
		int(floor(span.x)) - config.voxel_depth_chunks * Chunk.SIZE, Chunk.SIZE)
	var max_cy := int(config.world_height_blocks / Chunk.SIZE) - 1
	return range(maxi(bottom, 0), mini(top, max_cy) + 1)


## `keep_radius` is the unload ring; `prune_radius` is where QUEUED-but-unbuilt
## columns are dropped, and it is tighter (world feel v1 Stage 4). A column in
## the trailing band that was never built should not be built when the player
## pauses - the player is not going to look at it.
## `spare` is the columns that must survive regardless of distance: since world
## feel v1 Stage 10 that is the collision rings around remote peers, which are
## by definition far outside the host's own radius. Without it they would be
## queued by every refresh and parked by the same refresh - a treadmill that
## builds a friend's ground over and over and never lets them stand on it.
func _free_distant_chunks(keep_radius: int, prune_radius: int = -1,
		spare: Dictionary = {}) -> void:
	var keep_sq := keep_radius * keep_radius
	var prune_sq := (prune_radius * prune_radius) if prune_radius > 0 else keep_sq
	var doomed: Array[Vector3i] = []
	for pos in _chunks:
		var col := Vector2i(pos.x, pos.z)
		if spare.has(col):
			continue
		var dx: int = pos.x - _center.x
		var dz: int = pos.z - _center.y
		# Never free a chunk a worker is still reading. It will drift out of
		# range again on the next refresh, by which time its job is done.
		if dx * dx + dz * dz > keep_sq and not _in_flight.has(col):
			doomed.append(pos)
	for pos in doomed:
		var chunk: Chunk = _chunks[pos]
		_chunks.erase(pos)
		var col := Vector2i(pos.x, pos.z)
		# The column goes with its chunks: it is not loaded any more, and the
		# next refresh must be free to queue it again - or to find it parked.
		_loaded_columns.erase(col)
		var node: ChunkNode = _chunk_nodes.get(pos)
		_chunk_nodes.erase(pos)
		if node == null:
			continue
		# PARKED, NOT FREED (world feel v1 Stage 4). Turning round used to
		# rebuild the trail you had just walked.
		node.set_parked(true)
		var entry = _column_cache.get(col)
		if entry == null:
			entry = {"chunks": {}, "nodes": {}}
			_column_cache[col] = entry
			_cache_order.append(col)
		entry["chunks"][pos.y] = chunk
		entry["nodes"][pos.y] = node
		_cache_chunks += 1
	_evict_cache()
	# Edits are NOT dropped with the chunk. _edits is the authoritative
	# difference between the seed and the world, and _replay_edits_for() puts
	# them back when the chunk is regenerated - which is what lets a player
	# walk away from a hole they dug and find it still there.
	if not _build_queue.is_empty():
		var still: Array[Vector2i] = []
		for col in _build_queue:
			var dx: int = col.x - _center.x
			var dz: int = col.y - _center.y
			if spare.has(col) or dx * dx + dz * dz <= prune_sq:
				still.append(col)
			else:
				_queued.erase(col)
		_build_queue = still


## Bring a parked column back. True if it was there.
##
## THE EDITS ARE REPLAYED, always. `_edits` is the authoritative difference
## between the seed and the world, and replaying it is idempotent - it writes
## the same value a second time - so replaying all of it is a superset of
## "the edits accepted since this was cached" and cannot be wrong. A chunk an
## edit landed in is remeshed, exactly as it is on the streaming path.
func _restore_column(col: Vector2i) -> bool:
	var entry = _column_cache.get(col)
	if entry == null:
		return false
	_column_cache.erase(col)
	_cache_order.erase(col)
	for cy in entry["chunks"]:
		var chunk: Chunk = entry["chunks"][cy]
		var node: ChunkNode = entry["nodes"][cy]
		var pos := chunk.chunk_pos
		_chunks[pos] = chunk
		_chunk_nodes[pos] = node
		node.set_parked(false)
		if _replay_edits_for(chunk):
			node.rebuild(Callable(self, "is_solid_world"))
		_cache_chunks -= 1
	_loaded_columns[col] = true
	_column_landed(col)
	_frontier_advanced = true
	return true


## Drop the oldest parked columns until the cache is inside its bound.
func _evict_cache() -> void:
	while _cache_chunks > CHUNK_CACHE_CHUNKS and not _cache_order.is_empty():
		var col: Vector2i = _cache_order.pop_front()
		var entry = _column_cache.get(col)
		_column_cache.erase(col)
		if entry == null:
			continue
		for cy in entry["nodes"]:
			# Spread over frames: freeing 600 columns' nodes in one frame is
			# the hitch this stage exists to remove.
			_pending_frees.append(entry["nodes"][cy])
			_cache_chunks -= 1


## Bring back a bounded number of parked columns per frame.
func _drain_restores() -> void:
	var n := 0
	while not _pending_restores.is_empty() and n < RESTORES_PER_FRAME:
		var col: Vector2i = _pending_restores.pop_front()
		_restore_queued.erase(col)
		# It may have been evicted, or walked back out of range, since it was
		# listed. Both are fine: the next refresh decides again.
		_restore_column(col)
		n += 1


## Free a bounded number of parked nodes per frame.
func _drain_frees() -> void:
	var n := 0
	while not _pending_frees.is_empty() and n < FREES_PER_FRAME:
		var node: ChunkNode = _pending_frees.pop_back()
		if is_instance_valid(node):
			node.queue_free()
		n += 1


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

## THE HOST'S JOURNAL, injected by Game (ui v1 Stage 3, Decision 10).
##
## A block edit is CLAUDE.md's own first example of habit 2 - "the host sees
## every event: an edit, a death, a campfire" - and it was the one event still
## not being recorded. The only site every accepted edit passes through is
## _host_apply_edit below, after the validate gate and after the no-op gate,
## with the sender in hand; anywhere else would journal edits that were
## refused, or count one edit twice.
##
## Null on a client and on anything that builds a World without a Game, which
## is every self-test - a client's journal would be a journal of what a client
## was told, which journal.gd already declines to keep.
var _journal: Journal = null


func set_journal(journal: Journal) -> void:
	_journal = journal


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
	# Recording it is enough: _collect_chunks() replays it the moment the
	# voxels arrive, before the chunk is meshed.
	var cpos_pending := Chunk.world_to_chunk(world_block_pos)
	var pending := _in_flight.has(Vector2i(cpos_pending.x, cpos_pending.z))
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
	# HABIT 2. Here and not in request_set_block(), because this is the line
	# after which the edit is real: past the validate gate, past the no-op
	# gate, and with the sender the network layer assigned rather than one an
	# argument claimed.
	if _journal != null:
		_journal.log_event("block_edit", {
			"peer": sender_id, "pos": world_block_pos, "block": block_id})
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
	return has_chunk(cpos) or _in_flight.has(Vector2i(cpos.x, cpos.z))


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


## Which block columns inside this chunk column have been edited.
##
## EDITED GROUND CARRIES NO PLANTS, and that is the whole rule. Flora is placed
## from the GENERATOR's surface, not from the voxels - which is what lets a
## column be built on a worker with no chunk in hand, and is right for every
## block nobody has touched. It is wrong for the ones they have: dig the
## surface block out and the generator still says the ground is where it was,
## so the grass on it hangs in the air over the hole.
##
## Recomputing the true surface from the edits would be the thorough answer and
## it is not the right one. A block somebody has dug or built on is disturbed
## ground, and disturbed ground having no grass on it is both cheap and what a
## player expects - drop the debug slab on a meadow and the grass under it is
## gone, not poking through.
##
## Returns a set keyed by Vector2i(bx, bz) - the COLUMN of the edit, not the
## block - because an edit at any altitude disturbs the whole column under it.
func _edited_blocks_in(col: Vector2i) -> Dictionary:
	var out := {}
	if _edits.is_empty():
		return out
	var x0 := col.x * Chunk.SIZE
	var z0 := col.y * Chunk.SIZE
	for pos in _edits:
		var bx: int = pos.x
		var bz: int = pos.z
		if bx < x0 or bx >= x0 + Chunk.SIZE:
			continue
		if bz < z0 or bz >= z0 + Chunk.SIZE:
			continue
		out[Vector2i(bx, bz)] = true
	return out


## Take one flora instance out of the world.
##
## `id` is a FloraPlacement.identity() - the model, a sub-index, and the block
## it stands on, packed into 64 bits. Nothing else about the instance is
## recorded, because nothing else has to be: everything it was is a function of
## where it was.
##
## THE RPC THIS IS WAITING FOR, and it is deliberately NOT here. Gathering is a
## launch skill in DESIGN.md; foliage v1 builds the identity and the removal
## path and stops. When it arrives it mirrors request_set_block() exactly:
##
##     func request_gather(id: int) -> void:
##         if Net.is_host():
##             _host_apply_gather(Net.local_peer_id(), id)
##         else:
##             _srv_request_gather.rpc_id(1, id)
##
##     @rpc("any_peer", "call_remote", "reliable")
##     func _srv_request_gather(id: int) -> void:
##         # host validates - is the player near it, does it still exist -
##         # then _cl_apply_gather.rpc(id) to everyone and applies locally.
##
## and the join handshake gains _flora_removed beside get_edits(), which is one
## more dictionary of integers and no change to the wire format of anything
## already there. NONE OF THAT IS IN THIS STAGE: the plan is explicit that the
## net protocol is not to be touched, and the point of stopping here is that
## when the RPC is written there is nothing left to design.
func remove_flora_local(id: int) -> void:
	if _flora_removed.has(id):
		return
	_flora_removed[id] = true
	_flora_dirty(FloraPlacement.column_of(id))


## Everything gathered so far, for a joining client. The counterpart of
## get_edits(), and not yet sent by anything.
func get_flora_removed() -> Dictionary:
	return _flora_removed.duplicate()


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


## The surface zone under a point given in METRES.
##
## For anything that needs to know what it is standing on rather than how high
## it is - since world feel v1 Stage 12 that is the slide rule and the chunk
## colliders' friction. It asks the generator rather than the loaded chunk,
## which means it answers for ground that has not streamed in yet: that is
## wanted, because the host simulates remote peers over terrain it may only
## have as collision.
func zone_at_m(x: float, z: float) -> int:
	var bx := int(floor(x / config.block_size))
	var bz := int(floor(z / config.block_size))
	return generator.surface_zone_at(bx, bz, generator.surface_at(
		float(bx), float(bz)))


## Same thing in metres, which is what anything outside worldgen wants.
func surface_height_m(wx: int, wz: int) -> float:
	return generator.surface_at(float(wx), float(wz)) * config.block_size


## Returns true if any edit actually landed in this chunk - which is what tells
## the caller the mesh its job built is stale. See _collect_chunks().
func _replay_edits_for(chunk: Chunk) -> bool:
	if _edits.is_empty():
		return false
	var origin := chunk.origin()
	var landed := false
	for pos in _edits:
		var local: Vector3i = pos - origin
		if Chunk.in_bounds(local.x, local.y, local.z):
			chunk.set_voxel(local.x, local.y, local.z, _edits[pos])
			landed = true
	return landed


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
