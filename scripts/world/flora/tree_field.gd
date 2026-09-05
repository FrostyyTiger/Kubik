class_name TreeField
extends Node3D

## EVERY TREE IN THE GAME. Trees v3 decision 1.
##
## THIS WAS `FarTrees`, THE IMPOSTOR RING, AND THE RENAME IS THE EPIC. It drew
## the forest BEYOND the voxel radius as six-triangle cones, because the real
## trees were blocks in the chunk volume and stopped at the seam. There are no
## block trees any more and there is no seam: this walks the placement lattice
## from the player's boots to the fog and draws a library mesh at every
## candidate, at a coarser LOD rung the further out it stands.
##
## The machine is unchanged and that is deliberate - the ring-walk in four
## stride bands, the per-sector frontier holes, the inner and outer fades, the
## terrace footing lift, the backdrop convergence, distance v5's horizontal
## debounce and its budgeted uploader are all INHERITED, not rewritten. What
## changed is what a candidate draws.
##
##
## GEOMETRY ALL THE WAY OUT. NO CARDS (ruling 4).
##
## There are no impostor billboards, no baked octahedral sheets and no painted
## far ring. The far register is a DOWNSAMPLED VERSION OF THE SAME GRID - the
## Distant Horizons move applied to a model library - so the near/far seam
## stops being a KIND boundary (block tree against cone) and becomes only a
## RESOLUTION boundary. Two things follow, and both were bought deliberately:
## a walking eye cannot find the handover, and looking down from a peak works,
## which cards never did.
##
## What it must NOT do is scatter its own trees. It walks the same candidate
## lattice `TreePlacement.decide()` answers for, so the tree you see at 200 m
## is the tree you arrive at - which was true of the impostor ring and is the
## one property that had to survive becoming the only renderer.

signal rebuilt(count: int, elapsed_ms: int)

## Cells the placement memo may hold before it is dropped. About 300,000 cells
## is a 800 m ring at an 8 m lattice with room to walk, and a dropped memo
## costs one slow rebuild rather than a wrong tree.
const PLACE_CACHE_MAX := 300000

## Raw placement decisions, keyed by cell, shared by every job this field runs.
var _place_cache := {}

## What that memo was filled under: seed and config hash. A change empties it.
var _place_cache_key := ""

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

## How far in from the OUTER edge a tree shrinks away again, in metres.
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
## TreeFieldJob: three bands cost 1.52x the Stage 6 ring against a gate of
## 1.25x, and took 9% off the stream probe's chunks/s on the way back - which
## is hard rule 6. 600 m is where the fog is already 87% of the frame.
const LOD_COARSEST_M := 600.0

var _job: TreeFieldJob = null
var _task := -1
var _pending := Vector2i.ZERO
var _has_pending := false

## Per-sector radius in chunks out to which the real trees have landed. Set by
## Game from World.loaded_frontier() when the frontier moves.
var frontier := PackedInt32Array()

## FELLED TREES, KEYED BY PLACEMENT CELL. Decision 8's seam.
##
## EMPTY, AND NOTHING IN THIS EPIC WRITES TO IT. Chopping is fell-as-a-unit now
## (ruling 2) and the ONE MUTATION PATH will be its only writer - a client
## proposes, the host validates against the allowed list and applies, exactly
## as a block edit is treated (CLAUDE.md habit 3). It is threaded through the
## job, the draw and the collider ring while all three are being written
## because adding it afterwards would mean touching all three again, and
## because a seam nobody has tried to thread is a seam nobody knows the shape
## of. Flora carries `_flora_removed` for the same reason and got it right the
## same way.
var removed_trees := {}
var _last_center_m := Vector3(INF, INF, INF)

var _generator: TerrainGenerator = null
var _config: WorldgenConfig = null
## SLOT KEY -> MultiMeshInstance3D. The key is TreeFieldJob's - `c<species>`
## for a cone and `m<variant>|<lod>` for a library mesh - so one species with
## seven variants at three rungs is up to twenty-one slots and one draw call
## each. See the note on TreeFieldJob.buffers.
var _slots := {}

## The world's origin offset as this node last saw it - horizon v1 Stage 6.
var _origin_m := Vector3.ZERO


## Every slot moved by -delta, and the offset remembered. Called by `Game` on a
## rebase, with the same delta every other anchor in the world just took.
func shift_anchors(delta: Vector3) -> void:
	_origin_m += delta
	for key in _slots:
		var slot: Node3D = _slots[key]
		if is_instance_valid(slot):
			slot.position -= delta
	# AND THE TRUNK COLLIDERS, which are shapes on one static body rather than
	# nodes with anchors. A few hundred of them, and they are what the player
	# walks into: leaving them a rebase behind would put an invisible trunk two
	# kilometres from its tree until the next ring rebuild.
	for cs in _shapes:
		if is_instance_valid(cs):
			cs.position -= delta
var _trunks: StaticBody3D = null
var _shapes: Array = []
var _collider_count := 0
var _count := 0
var _models := 0
var _triangles := 0
var _last_ms := 0

## Rebuilds completed this session - see rebuild_count().
var _rebuilds := 0


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
	var job := TreeFieldJob.new()
	job.center = _pending
	# THE RING'S CENTRE IS THE SLOT'S ANCHOR, horizon v1 Stage 6. Every row the
	# job packs is relative to it, and the slot node carries it - so the ring's
	# rows are at most its own radius from their node at any distance from the
	# origin. See TreeFieldJob.anchor.
	job.anchor = Vector3(float(_pending.x) * _config.block_size, 0.0,
		float(_pending.y) * _config.block_size)
	job.generator = _generator
	job.config = _config
	# The heightmap the far mesh draws from, for the colour convergence in
	# TreeFieldJob._tint_at(). The generator owns it and neither of them is
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
	# NO INNER FADE. It shrank every tree inside the voxel radius to nothing
	# once the voxel trees it handed over to were deleted; `_fade_at()` carries
	# the receipt.
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
	# THE COLLIDER RING, trees v3 Stage 6. The sim radius, because a collider is
	# a GAMEPLAY fact and the sim radius is the ring World already streams
	# collidable ground into for every simulated peer - so a tree you can walk
	# into is a tree standing on ground you can walk on, by construction rather
	# than by two radii that happen to agree.
	job.collider_blocks = float(_config.sim_radius_chunks * Chunk.SIZE) \
		if _config.tree_colliders else 0.0
	# The felled set. Nothing writes to it tonight - see the note on the job's
	# own field, and on `removed_trees` below.
	job.removed = removed_trees
	# THE PLACEMENT MEMO, CARRIED BETWEEN REBUILDS. A rebuild is triggered by
	# 24 m of walking into a ring hundreds of metres across, so nearly every
	# cell it re-decides it decided last time - and placement is pure, so the
	# answer is the same. Dropped wholesale when it gets big rather than
	# evicted cleverly: the walk that filled it has moved on, and a dictionary
	# that grows for a session is a leak with a slow fuse.
	#
	# AND IT IS THROWN AWAY WHEN THE CONFIG CHANGES. Every knob the F4 tuner
	# owns - density, the lattice, crown spacing, the masks - is an input to
	# the decision this memo holds, so a stale entry is a tree standing where
	# the current settings say no tree stands. Keyed on the config's own hash
	# rather than on a list of the knobs that matter, because that list is a
	# thing someone would have to remember to update.
	var ckey := "%d|%s" % [_generator.world_seed, _config.hash_key()]
	if ckey != _place_cache_key or _place_cache.size() > PLACE_CACHE_MAX:
		_place_cache.clear()
		_place_cache_key = ckey
	job.cache = _place_cache
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
func _apply(job: TreeFieldJob) -> void:
	_triangles = 0
	var up := _uploader()
	if up == null:
		for key in job.buffers:
			_apply_species(job, key)
		_apply_colliders(job)
		_apply_tail(job)
		return
	var work: Array[Callable] = []
	for key in job.buffers:
		work.append(_apply_species.bind(job, key))
	# THE COLLIDER BATCH IS A SLICE LIKE ANY OTHER (decision 10, and v5 hard
	# rule 6 adopted verbatim). It is a few hundred shape writes and has never
	# measured above a millisecond - it is on the budget because "every
	# handover" is a rule, and a rule with an exception is a thing somebody has
	# to remember.
	work.append(_apply_colliders.bind(job))
	up.submit(&"tree_field", work, _apply_tail.bind(job))


func _apply_species(job: TreeFieldJob, key: String) -> void:
	var buf: PackedFloat32Array = job.buffers[key]
	var n := buf.size() / TreeFieldJob.FLOATS_PER_INSTANCE
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
	# THE MESH IS RE-READ EVERY REBUILD, and the reason has changed with the
	# meshes. Distance v2 re-read it so `far_terrace` could swap a cone for a
	# stepped pyramid without an F7; now it is so a library reloaded or a
	# palette retuned at runtime lands without one. TreeModels caches, so this
	# is a dictionary lookup and not a rebuild.
	slot.multimesh.mesh = mesh
	slot.multimesh.instance_count = n
	slot.multimesh.buffer = buf
	# THE SLOT SITS AT THE JOB'S ANCHOR, in render space.
	slot.position = job.anchor - _origin_m
	slot.visible = true
	# Triangles the field actually draws, off the INDEX array - a library mesh
	# is indexed and `surface_get_array_len` would give its vertex count, which
	# on a greedy quad mesh is two thirds of the answer.
	var idx: int = mesh.surface_get_array_index_len(0)
	_triangles += n * (idx / 3)


## The mesh one slot key names: a library rung, `m<variant>|<lod>`.
func _mesh_for_key(key: String) -> Mesh:
	var m := TreeFieldJob.model_of_key(key)
	return TreeModels.mesh_for(StringName(m[0]), int(m[1]), _config.block_size)


## THE TRUNK COLLIDERS, decision 8.
##
## One StaticBody3D holding every trunk in the sim radius, with the shapes
## POOLED across rebuilds - a CollisionShape3D is a node and a shape is a
## server resource, and building six hundred of each every twenty-four metres
## of walking is the kind of allocation churn that shows up as a stutter rather
## than as a number.
##
## THE CANOPY DOES NOT COLLIDE, and never meaningfully did: leaf blocks were
## written with `only_air`, which made them decoration you could stand inside.
## A trunk is what a player bumps into, and a cylinder is what a trunk is.
func _apply_colliders(job: TreeFieldJob) -> void:
	if _trunks == null:
		_trunks = StaticBody3D.new()
		_trunks.name = "Trunks"
		add_child(_trunks)
	var want := job.colliders.size()
	# Grow the pool. Shrinking it is deliberately not done: the ring is a
	# roughly constant size and freeing nodes to rebuild them next rebuild is
	# the churn this pool exists to avoid.
	while _shapes.size() < want:
		var cs := CollisionShape3D.new()
		var cyl := CylinderShape3D.new()
		cs.shape = cyl
		_trunks.add_child(cs)
		_shapes.append(cs)
	for i in _shapes.size():
		var cs: CollisionShape3D = _shapes[i]
		if i >= want:
			cs.disabled = true
			continue
		var row: Array = job.colliders[i]
		var cyl: CylinderShape3D = cs.shape
		cyl.radius = float(row[1])
		cyl.height = float(row[2])
		# The collider rows are world metres like the instance rows were; the
		# shapes hang off THIS node, which is at the render origin, so the
		# offset comes off here. Horizon v1 Stage 6.
		cs.position = (row[0] as Vector3) - _origin_m
		cs.disabled = false
	_collider_count = want


func _apply_tail(job: TreeFieldJob) -> void:
	for key in _slots:
		if not job.buffers.has(key):
			_slots[key].multimesh.instance_count = 0
			_slots[key].visible = false
	_count = job.count
	_models = job.model_count
	# THE TRIANGLE COUNT, printed here rather than folded into Game's
	# "[TreeField] N impostors in N ms" line: game.gd is append-only in this
	# epic and has already spent its one line. Stage 5's gate is a ratio and
	# nothing in the project reported the numerator.
	print("[TreeField] %d triangles over %d slots (%d model instances of %d), %d trunk colliders" % [
		_triangles, _slots.size(), _models, _count, _collider_count])
	_rebuilds += 1
	rebuilt.emit(job.count, _last_ms)


## The far mesh's uploader, reached through the tree. TreeField is Game's child
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
	# LOD0 CASTS, THE OTHER THREE RUNGS DO NOT (light v1 Stage 0, Q10).
	#
	# Until light v1 no tree cast a shadow at any distance, and the ground
	# under a wood was darkened by a painted canopy ink instead. Under real
	# light that is paint doing what light does, so the nearest rung casts and
	# `canopy_shade` goes to 0.
	#
	# ONLY THE NEAREST RUNG, and the old note's argument is why: the shadow map
	# pays for every triangle in it as if it were in front of the camera, and a
	# proxy lump's shadow at 400 m is not a tree's shadow - it is a cost. LOD0
	# is the rung inside `lod_blocks`, which sits well inside the 250 m shadow
	# distance, so a rung that casts is always a rung the shadow map already
	# reaches. The key is `m<variant>|<lod>`; the rung is what follows the bar.
	var lod := key.get_slice("|", 1).to_int()
	node.cast_shadow = (GeometryInstance3D.SHADOW_CASTING_SETTING_ON if lod == 0
		else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
	add_child(node)
	return node


## Impostors drawn, and how long the last rebuild took. For the F3 readout and
## for STATUS.md.
func stats() -> Dictionary:
	return {"impostors": _count, "rebuild_ms": _last_ms, "triangles": _triangles,
		"models": _models, "colliders": _collider_count, "rebuilds": _rebuilds}


## HOW MANY TIMES THE RING HAS BEEN REBUILT THIS SESSION. Horizon v1 Stage 0.
##
## The sprint probe reports it beside the far field's, and the pair answers a
## question a frame time on its own cannot: whether a run was slow because the
## frame is slow or because that run happened to rebuild the forest four more
## times than the one it is being compared against. A count survives a drifting
## box; a millisecond does not.
func rebuild_count() -> int:
	return _rebuilds


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
