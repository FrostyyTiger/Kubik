class_name FarField
extends MeshInstance3D

## Holds the far-field terrain mesh and rebuilds it, off the main thread, when
## the player has moved far enough to matter.
##
## The old mesh stays on screen for the frame or two a rebuild takes. That is
## the whole reason for doing it this way: swapping in a finished mesh is
## invisible, whereas building 45,000 vertices on the frame the player crosses
## a chunk boundary is a hitch every eight metres of walking.

signal rebuilt(vertex_count: int)

var _job: FarFieldJob = null
var _task := -1
var _pending_center := Vector2i.ZERO
var _pending_frontier := PackedInt32Array()
var _built_frontier := PackedInt32Array()
var _has_pending := false

var _heightmap: Heightmap = null
var _generator: TerrainGenerator = null
var _config: WorldgenConfig = null

## DISTANCE V1 STAGE 0. What the last rebuild cost, for the F3 readout.
##
## Two numbers, because they answer different questions. `_last_ms` is the
## JOB's own time - the work Stages 1-4 are about to add to. `_last_wall_ms`
## is from asking for the mesh to having it, which includes waiting for a
## WorkerThreadPool that runs one GDScript task at a time; that is the number
## the player feels, and the gap between the two is contention rather than
## cost. Reporting only the first would hide the gap; only the second would
## blame this stage for the chunk workers.
var _last_ms := 0
var _last_wall_ms := 0
var _last_verts := 0
var _rebuilds := 0
var _started_us := 0


func setup(generator: TerrainGenerator, config: WorldgenConfig) -> void:
	_generator = generator
	_heightmap = generator.heightmap
	_config = config
	# One shared material with the chunks, so the renderer can batch the far
	# field together with the voxels instead of breaking the batch at the
	# horizon.
	material_override = ChunkMesher.get_material()


## Ask for a rebuild centred on this block position. Safe to call every time
## the player crosses a chunk boundary; a request arriving while a build is
## already running simply replaces the pending one.
func request_rebuild(center_block: Vector2i, p_frontier := PackedInt32Array()) -> void:
	_pending_center = center_block
	_pending_frontier = p_frontier
	_has_pending = true
	_start_if_idle()


func _process(_delta: float) -> void:
	if _task == -1:
		return
	if not WorkerThreadPool.is_task_completed(_task):
		return
	WorkerThreadPool.wait_for_task_completion(_task)
	_task = -1

	_last_ms = _job.elapsed_ms
	_last_wall_ms = int((Time.get_ticks_usec() - _started_us) / 1000)
	_last_verts = _job.vertex_count
	_rebuilds += 1
	mesh = ChunkMesher.arrays_to_mesh(_job.arrays)
	# The frontier THIS MESH was cut to. Not the same as the world's current
	# one: a rebuild takes a frame or two on a worker, and during that window
	# what is on screen is the old hole. Anything asking "is this covered right
	# now" - the stream probe above all - has to ask about the mesh that
	# exists, not the one being built.
	_built_frontier = _job.frontier
	rebuilt.emit(_job.vertex_count)
	_job = null
	_start_if_idle()


func _start_if_idle() -> void:
	if _task != -1 or not _has_pending or _generator == null:
		return
	_has_pending = false
	_job = FarFieldJob.new()
	_job.heightmap = _heightmap
	_job.generator = _generator
	_job.config = _config
	_job.center = _pending_center
	_job.frontier = _pending_frontier
	_started_us = Time.get_ticks_usec()
	_task = WorkerThreadPool.add_task(_job.run, false, "kubik far field")


## The frontier the mesh CURRENTLY ON SCREEN was cut to. Empty before the first
## build, and after a reset.
func built_frontier() -> PackedInt32Array:
	return _built_frontier


## The radius, in blocks, inside which the far mesh declines to draw because
## the voxels are expected to cover it.
##
## Derived the same way FarFieldJob derives it, rather than read back off the
## last job: the job is null between builds, and a probe asking "is this column
## covered" needs an answer every frame, not only just after a rebuild.
func exclusion_blocks() -> float:
	if _config == null:
		return 0.0
	var voxel_radius_blocks := float(_config.voxel_radius_chunks * Chunk.SIZE)
	return maxf(voxel_radius_blocks - float(2 * _config.far_step), 0.0)


## What the last rebuild cost, for the F3 readout. Distance v1 Stage 0.
func stats() -> Dictionary:
	return {
		"vertices": _last_verts,
		"build_ms": _last_ms,
		"wall_ms": _last_wall_ms,
		"rebuilds": _rebuilds,
	}


## Block until any build finishes, before the world it reads is thrown away.
func drain() -> void:
	if _task != -1:
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1
	_job = null
	_has_pending = false


func _exit_tree() -> void:
	drain()
