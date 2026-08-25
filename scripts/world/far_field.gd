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
var _has_pending := false

var _heightmap: Heightmap = null
var _generator: TerrainGenerator = null
var _config: WorldgenConfig = null


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
func request_rebuild(center_block: Vector2i) -> void:
	_pending_center = center_block
	_has_pending = true
	_start_if_idle()


func _process(_delta: float) -> void:
	if _task == -1:
		return
	if not WorkerThreadPool.is_task_completed(_task):
		return
	WorkerThreadPool.wait_for_task_completion(_task)
	_task = -1

	mesh = ChunkMesher.arrays_to_mesh(_job.arrays)
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
	_task = WorkerThreadPool.add_task(_job.run, false, "kubik far field")


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


## Block until any build finishes, before the world it reads is thrown away.
func drain() -> void:
	if _task != -1:
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1
	_job = null
	_has_pending = false


func _exit_tree() -> void:
	drain()
