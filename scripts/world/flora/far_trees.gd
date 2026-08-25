class_name FarTrees
extends Node3D

## The forest beyond the voxel radius, as impostors.
##
## Follows FarField exactly - a worker builds the new ring while the old one
## stays on screen, and the swap is invisible. Building 2,000 transforms on the
## frame the player crosses a threshold would be a hitch every sixteen metres
## of walking, which is every second and a bit at sprint.
##
##
## SIX TO TWELVE TRIANGLES PER TREE, AND THAT IS THE WHOLE DESIGN.
##
## A voxel spruce is several hundred triangles. Two thousand of them in a ring
## is most of a million, which is the entire flora budget spent on trees you
## cannot walk to. A cone is six, and at 150 m a cone and a spruce are the same
## handful of pixels - the silhouette carries all the information that survives
## the distance, and the silhouette is exactly what an impostor is.
##
## What it must NOT do is scatter its own trees. It walks the same candidate
## lattice the voxel stamper walks, so the tree you see at 200 m is the tree
## you arrive at.

signal rebuilt(count: int, elapsed_ms: int)

## How far the centre must move before the ring is rebuilt, in metres.
##
## The plan's number. It is twice the chunk size, so the ring is rebuilt half
## as often as the voxel region is refreshed - which is affordable because an
## impostor 200 m away moving 16 m late is a sub-pixel error.
const REBUILD_STEP_M := 16.0

## How far in from the inner edge an impostor grows to full size, in metres.
const FADE_M := 12.0

var _job: FarTreesJob = null
var _task := -1
var _pending := Vector2i.ZERO
var _has_pending := false
var _last_center_m := Vector3(INF, INF, INF)

var _generator: TerrainGenerator = null
var _config: WorldgenConfig = null
var _slots := {}   # species -> MultiMeshInstance3D
var _count := 0
var _last_ms := 0


func setup(generator: TerrainGenerator, config: WorldgenConfig) -> void:
	_generator = generator
	_config = config
	_last_center_m = Vector3(INF, INF, INF)
	for species in _slots:
		_slots[species].queue_free()
	_slots.clear()
	_count = 0


## Called every frame with the player's position. Cheap when nothing has moved.
func update(position_m: Vector3) -> void:
	if _generator == null or _config == null:
		return
	if _config.far_tree_m <= 0.0:
		visible = false
		return
	visible = true
	if _last_center_m.distance_to(position_m) < REBUILD_STEP_M:
		return
	_last_center_m = position_m
	_pending = Vector2i(
		int(floor(position_m.x / _config.block_size)),
		int(floor(position_m.z / _config.block_size)))
	_has_pending = true
	_start_if_idle()


func _process(_delta: float) -> void:
	if _task == -1:
		return
	if not WorkerThreadPool.is_task_completed(_task):
		return
	WorkerThreadPool.wait_for_task_completion(_task)
	_task = -1

	_apply(_job)
	_last_ms = _job.elapsed_usec / 1000
	rebuilt.emit(_job.count, _last_ms)
	_job = null
	_start_if_idle()


func _start_if_idle() -> void:
	if _task != -1 or not _has_pending or _generator == null:
		return
	_has_pending = false
	var job := FarTreesJob.new()
	job.center = _pending
	job.generator = _generator
	job.config = _config
	# INNER EDGE AT THE VOXEL RADIUS, because the real trees are inside it and
	# drawing both would double every trunk near the boundary.
	job.inner_blocks = float(_config.voxel_radius_chunks * Chunk.SIZE)
	# OUTER EDGE AT THE SMALLER of far_tree_m and the fog. Past fog end nothing
	# is visible at all, so an impostor out there is a triangle drawn for
	# nobody - and the fog is what makes a 600 m view distance affordable in
	# the first place.
	job.outer_blocks = minf(_config.far_tree_m, _config.fog_end_m) \
		/ _config.block_size
	job.fade_blocks = FADE_M / _config.block_size
	# The exact band reaches 1.6 times the voxel radius, so the handover to
	# real trees and a good stretch beyond it are drawn candidate for
	# candidate.
	job.lod_blocks = job.inner_blocks * 1.6
	_job = job
	_task = WorkerThreadPool.add_task(job.run, false, "kubik far trees")


func _apply(job: FarTreesJob) -> void:
	_count = job.count
	for species in job.buffers:
		var buf: PackedFloat32Array = job.buffers[species]
		var n := buf.size() / FarTreesJob.FLOATS_PER_INSTANCE
		if n <= 0:
			continue
		var slot: MultiMeshInstance3D = _slots.get(species)
		if slot == null:
			slot = _make_slot(species)
			_slots[species] = slot
		slot.multimesh.instance_count = n
		slot.multimesh.buffer = buf
		slot.visible = true
	for species in _slots:
		if not job.buffers.has(species):
			_slots[species].multimesh.instance_count = 0
			_slots[species].visible = false


func _make_slot(species: int) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = FarTreeMeshes.for_species(species, _config)
	var node := MultiMeshInstance3D.new()
	node.name = "Species%d" % species
	node.multimesh = mm
	# NO SHADOWS FROM THE RING. A cone's shadow is not a tree's shadow, and at
	# 200 m nobody can tell there is one - but the shadow map pays for every
	# triangle in it as if it were in front of the camera.
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	return node


## Impostors drawn, and how long the last rebuild took. For the F3 readout and
## for STATUS.md.
func stats() -> Dictionary:
	return {"impostors": _count, "rebuild_ms": _last_ms}


func drain() -> void:
	if _task != -1:
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1
	_job = null
	_has_pending = false


func _exit_tree() -> void:
	drain()
