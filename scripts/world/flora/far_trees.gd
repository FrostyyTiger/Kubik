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
## THREE chunks since distance v1 Stage 7, and it was two before that.
##
## The plan's original number was 16 m - twice the chunk size, so the ring was
## rebuilt half as often as the voxel region is refreshed, which was affordable
## because an impostor 200 m away moving 16 m late is a sub-pixel error.
##
## Stage 7 doubles the ring's radius, and a rebuild that costs half again as
## much at the same cadence is half again as much of a worker pool that runs
## ONE GDScript task at a time - measured, on the stream probe, as 9% off
## chunks/s on the return leg. Work per metre walked is what that budget is
## really made of, so the cadence moves with the radius: 24 m puts the ring
## back at Stage 6's cost per metre and the extra LOD band below puts it under.
##
## WHAT A LONGER STEP COSTS is a longer OVERLAP at the handover, never a gap.
## The far mesh's hole and the ring's inner edge are both cut at the frontier
## captured when the job was submitted, so a stale ring draws impostors where
## real trees have since landed - and world feel v1 Stage 3 settled that trade
## explicitly: an impostor and a real tree overlapping for a second is
## invisible, because it is the same species at the same place at the same
## height, and a gap is not. This makes an invisible window 50% longer.
##
## DISTANCE V5 STAGE 2: THE DEFAULT, and the knob is `far_tree_step_m`. 24 m
## is what this constant has been since distance v1 Stage 7 and what every
## measurement in the project was taken at, so the default is the shipped
## number and not a new one.
const REBUILD_STEP_M := 24.0

## How far in from the inner edge an impostor grows to full size, in metres.
const FADE_M := 12.0

## And how far in from the OUTER edge it shrinks away again, in metres.
##
## FOUR TIMES THE INNER FADE, and the asymmetry is the point rather than an
## oversight. The inner fade covers a handover 96 m from the player, where 12 m
## of walking is a visible distance and a longer fade would leave half-size
## trees standing next to full-size ones. The outer edge is 800 m away, where
## 12 m of radius subtends almost nothing and the whole fade would happen
## inside a single fog band - which is to say it would not happen at all. 48 m
## is still less than one fog band's width out there, and it is enough that the
## last trees visibly shrink rather than stop.
const OUTER_FADE_M := 48.0

## Where the second LOD step begins, in metres. Past it one candidate cell in
## sixteen is considered and each impostor is drawn four times as wide. The
## plan's number, and it is also where the ring used to END.
const LOD_COARSE_M := 400.0

## And the third, which the plan did not ask for and the measurement did. Past
## it one cell in sixty-four, drawn eight times as wide. See the band table in
## FarTreesJob: three bands cost 1.52x the Stage 6 ring against a gate of
## 1.25x, and took 9% off the stream probe's chunks/s on the way back - which
## is hard rule 6. 600 m is where the fog is already 87% of the frame.
const LOD_COARSEST_M := 600.0

var _job: FarTreesJob = null
var _task := -1
var _pending := Vector2i.ZERO
var _has_pending := false

## Per-sector radius in chunks out to which the real trees have landed. Set by
## Game from World.loaded_frontier() when the frontier moves.
var frontier := PackedInt32Array()
var _last_center_m := Vector3(INF, INF, INF)

var _generator: TerrainGenerator = null
var _config: WorldgenConfig = null
## SLOT KEY -> MultiMeshInstance3D. The key is FarTreesJob's - `c<species>`
## for a cone and `m<variant>|<lod>` for a library mesh - so one species with
## seven variants at three rungs is up to twenty-one slots and one draw call
## each. See the note on FarTreesJob.buffers.
var _slots := {}
var _count := 0
var _models := 0
var _triangles := 0
var _last_ms := 0


func setup(generator: TerrainGenerator, config: WorldgenConfig) -> void:
	_generator = generator
	_config = config
	_last_center_m = Vector3(INF, INF, INF)
	for key in _slots:
		_slots[key].queue_free()
	_slots.clear()
	_count = 0
	_models = 0


## Called every frame with the player's position. Cheap when nothing has moved.
func update(position_m: Vector3) -> void:
	if _generator == null or _config == null:
		return
	if _config.far_tree_m <= 0.0:
		visible = false
		return
	visible = true
	# THE HYSTERESIS IS HORIZONTAL, and it was a 3D distance until distance v5
	# Stage 2. STATUS item 21 - "the impostor ring rebuilds 70-120 times while
	# the player stands still" - is this line: the ring is a function of the
	# XZ centre ALONE, which the two lines below say in as many words, so two
	# positions at the same x and z produce the identical ring. Measuring the
	# step in three dimensions meant ALTITUDE could ask for it, and a player
	# falling asks for it every 24 m of fall, forever, for the same ring.
	#
	# Measured on a screenshot tour, seed 42: 615 rebuilds over 18 vantages,
	# up to 94 at a single stationary one. The tour freezes the player and
	# `Game._release_player_when_ground_exists()` unfreezes it again, so the
	# player at a vantage with no collision under it falls out of the world
	# and drags the ring behind it - see the status doc, which carries that
	# half as a finding rather than fixing it here.
	var step: float = _config.far_tree_step_m if _config.far_tree_step_m > 0.0 \
		else REBUILD_STEP_M
	if Vector2(_last_center_m.x - position_m.x,
			_last_center_m.z - position_m.z).length() < step:
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

	_last_ms = _job.elapsed_usec / 1000
	_apply(_job)
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
	# The heightmap the far mesh draws from, for the colour convergence in
	# FarTreesJob._tint_at(). The generator owns it and neither of them is
	# written after setup.
	job.heightmap = _generator.heightmap
	# INNER EDGE AT THE FRONTIER, because the real trees are inside it and
	# drawing both would double every trunk near the boundary - but only where
	# the real trees have actually ARRIVED (world feel v1 Stage 3). Keyed to
	# the voxel radius, the impostors vanished ahead of a moving player seconds
	# before the real trees existed, exactly as the far mesh's hole did. An
	# impostor and a real tree overlapping for a second is invisible; a gap is
	# not. Empty frontier falls back to the old single radius.
	job.inner_blocks = float(_config.voxel_radius_chunks * Chunk.SIZE)
	job.frontier = frontier
	# OUTER EDGE AT THE SMALLER of far_tree_m and the fog. Past fog end nothing
	# is visible at all, so an impostor out there is a triangle drawn for
	# nobody - and the fog is what makes a 600 m view distance affordable in
	# the first place.
	job.outer_blocks = minf(_config.far_tree_m, _config.fog_end_m) \
		/ _config.block_size
	job.fade_blocks = FADE_M / _config.block_size
	job.outer_fade_blocks = OUTER_FADE_M / _config.block_size
	# The exact band reaches 1.6 times the voxel radius, so the handover to
	# real trees and a good stretch beyond it are drawn candidate for
	# candidate.
	job.lod_blocks = job.inner_blocks * 1.6
	# And the coarse band starts where the ring used to stop. Clamped above the
	# first step so a preset with a small fog can never put the second step
	# INSIDE the first, which would silently drop the 1-in-4 band entirely.
	job.lod2_blocks = maxf(LOD_COARSE_M / _config.block_size, job.lod_blocks)
	job.lod3_blocks = maxf(LOD_COARSEST_M / _config.block_size, job.lod2_blocks)
	_job = job
	_task = WorkerThreadPool.add_task(job.run, false, "kubik far trees")


## THE RING'S HANDOVER, THROUGH THE SAME BUDGET THE FAR MESH USES. Distance v5
## Stage 1's decision 1: every far-system mesh handover flows through one
## uploader, so the frame thread has ONE budget rather than two systems each
## individually small enough not to worry about.
##
## One slice per species - `MultiMesh.buffer` is a RenderingServer write and is
## the atom here, exactly as one sector is for the far mesh - and the tail is
## the commit. The ring is a few hundred instances and this has never been
## measured above a millisecond; it is on the budget because "every handover"
## is a rule, and a rule with an exception is a thing somebody has to remember.
##
## No uploader means no FarField, which means no world: applied directly, which
## is what the self-test's small Worlds and any future headless caller get.
func _apply(job: FarTreesJob) -> void:
	_triangles = 0
	var up := _uploader()
	if up == null:
		for key in job.buffers:
			_apply_species(job, key)
		_apply_tail(job)
		return
	var work: Array[Callable] = []
	for key in job.buffers:
		work.append(_apply_species.bind(job, key))
	up.submit(&"far_trees", work, _apply_tail.bind(job))


func _apply_species(job: FarTreesJob, key: String) -> void:
	var buf: PackedFloat32Array = job.buffers[key]
	var n := buf.size() / FarTreesJob.FLOATS_PER_INSTANCE
	if n <= 0:
		return
	var mesh := _mesh_for_key(key)
	if mesh == null:
		# A library slot with no mesh: the mount went away between the job
		# being submitted and its buffers landing, which the self-test's
		# absent leg can actually produce. Drop the slice rather than
		# assigning null to a MultiMesh, which is an error per instance.
		return
	var slot: MultiMeshInstance3D = _slots.get(key)
	if slot == null:
		slot = _make_slot(key, mesh)
		_slots[key] = slot
	# THE MESH IS RE-READ EVERY REBUILD, distance v2 Stage 5. far_terrace
	# chooses between the cone and the stepped pyramid (hard rule 1: at 0
	# the ring is the one f23c3f0 drew), and a slot built once at the old
	# value would keep drawing cones on terraced ground until the species
	# happened to disappear and come back. Both FarTreeMeshes and TreeModels
	# cache, so this is a dictionary lookup and not a rebuild.
	slot.multimesh.mesh = mesh
	slot.multimesh.instance_count = n
	slot.multimesh.buffer = buf
	slot.visible = true
	# Triangles the field actually draws. A cone mesh is unindexed and a
	# library mesh is indexed, so the count has to come from whichever array
	# the mesh actually has - reading array_len on an indexed mesh gives its
	# VERTEX count, which on a greedy quad mesh is two thirds of the answer.
	var idx: int = mesh.surface_get_array_index_len(0)
	var verts: int = mesh.surface_get_array_len(0)
	_triangles += n * ((idx if idx > 0 else verts) / 3)


## The mesh one slot key names: a cone for `c<species>`, a library rung for
## `m<variant>|<lod>`.
func _mesh_for_key(key: String) -> Mesh:
	var species := FarTreesJob.species_of_key(key)
	if species >= 0:
		return FarTreeMeshes.for_species(species, _config)
	var m := FarTreesJob.model_of_key(key)
	return TreeModels.mesh_for(StringName(m[0]), int(m[1]), _config.block_size)


func _apply_tail(job: FarTreesJob) -> void:
	for key in _slots:
		if not job.buffers.has(key):
			_slots[key].multimesh.instance_count = 0
			_slots[key].visible = false
	_count = job.count
	_models = job.model_count
	# THE TRIANGLE COUNT, printed here rather than folded into Game's
	# "[FarTrees] N impostors in N ms" line: game.gd is append-only in this
	# epic and has already spent its one line. Stage 5's gate is a ratio and
	# nothing in the project reported the numerator.
	print("[FarTrees] %d triangles over %d slots (%d model instances of %d)" % [
		_triangles, _slots.size(), _models, _count])
	rebuilt.emit(job.count, _last_ms)


## The far mesh's uploader, reached through the tree. FarTrees is Game's child
## and FarField is World's, so this is the same reach `apply_far_knobs` makes
## in the other direction - and it is looked up per rebuild rather than cached
## because a reroll builds a new World under the same parent and a cached node
## would be the old one.
func _uploader() -> FarUpload:
	var parent := get_parent()
	if parent == null:
		return null
	var far_field := parent.get_node_or_null("World/FarField")
	if far_field == null or not far_field.has_method("uploader"):
		return null
	return far_field.uploader()


func _make_slot(key: String, mesh: Mesh) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	var node := MultiMeshInstance3D.new()
	node.name = key
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
	return {"impostors": _count, "rebuild_ms": _last_ms, "triangles": _triangles,
		"models": _models}


## FORGET WHERE THE LAST RING WAS BUILT, so the next update() rebuilds it even
## though the player has not moved. Distance v2 Stage 0.
##
## update() is called every frame and returns immediately until the centre has
## moved REBUILD_STEP_M. That is right for walking and wrong for a knob: the
## whole judging method for this epic is standing still and turning far_terrace
## from 0 to 1, and an impostor's footing is on the shelf its cell was
## quantised to (Stage 5), so the ring is as stale as the mesh is.
func force_rebuild() -> void:
	_last_center_m = Vector3(INF, INF, INF)


func drain() -> void:
	if _task != -1:
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1
	_job = null
	_has_pending = false


func _exit_tree() -> void:
	drain()
