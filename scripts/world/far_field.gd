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
	# DISTANCE V2 STAGE 0. Remember what the far-only knobs are worth NOW, so
	# the first turn of a spinbox after the world loads is seen as a change
	# rather than as the value the snapshot happened to be seeded with.
	_snapshot_knobs(config)


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
	# THE FIRST BUILD, PRINTED. Distance v3 Stage 0, and it closes distance v2's
	# carried item 13: the far probe is structurally blind to the frontier, so a
	# change to the exclusion machinery passed seven stages of "identical on
	# every geometry row" and was caught by the number the WORLD printed at load.
	# That number is here rather than in world.gd - another lane's file - and it
	# carries the two costs the probe cannot see, because the probe runs on the
	# main thread with nothing else happening and this one waits for a worker
	# pool that runs one GDScript task at a time.
	#
	# Once, on the first build of a session: this is a baseline line for a
	# headless run, not a per-frame log.
	if _rebuilds == 1:
		print("[FarField] first build: %d vertices, %d ms job, %d ms wall" % [
			_last_verts, _last_ms, _last_wall_ms])
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


# --- THE KNOB THAT DOES NOT NEED F7, distance v2 Stage 0 ----------------------
#
# `far_terrace` is how Marcel judges this whole epic: stand still, move one
# number, and see the far country redraw. Today _on_config_changed() in game.gd
# applies MSAA, sky, flora and Look immediately and then says "config changed -
# press F7 to rebuild terrain". F7 is a full reroll - 3,276 voxel chunks in
# 39,023 ms on Marcel's box - with the world streaming back in around you.
# Forty seconds per flip is not an A/B a person can judge with their eyes.
#
# None of the knobs below touches a voxel chunk. They change the far mesh and
# the impostor ring, both of which already rebuild on a worker with the old one
# left on screen. So on a change to one of them: rebuild those two in place and
# say so, instead of falling through to the F7 message.
#
# WHY THE LIST IS WIDER THAN THIS EPIC. distance v1's four geometry knobs have
# always needed a full reroll to see, for no reason other than that nothing
# ever wired them up. The plan calls that "a welcome side effect and not a
# reason to widen the stage", so they are here.
#
# WHY IT IS A SNAPSHOT AND NOT A SIGNAL ARGUMENT. debug_hud's config_changed
# carries no property name, and debug_hud is APPEND-ONLY in this epic - a new
# signal is not an append to an existing list. Comparing values costs one
# dictionary walk over a dozen floats on a UI event and needs nothing from the
# other lane's files.

## Every LOCAL knob that changes only the far mesh or the impostor ring.
const FAR_ONLY_PROPERTIES: PackedStringArray = [
	"far_terrace", "far_riser_shade",
	"far_filter_bias", "far_peak_gain", "far_normal_m", "far_level_ref_m",
	"far_band_m", "far_band_step", "far_zone_cell_m", "far_zone_cell_ratio",
	"far_tree_tint",
	# DISTANCE V3, appended. Every one of them redraws the far mesh or the
	# impostor ring and nothing else, which is what earns a place on this
	# list - and being on it is what makes a knob judgeable standing still.
	"far_vote",
]

static var _knobs := {}


static func _snapshot_knobs(config: WorldgenConfig) -> void:
	if config == null:
		return
	for key in FAR_ONLY_PROPERTIES:
		_knobs[key] = float(config.get(key))


## Which of the far-only knobs have moved since the last call. Empty means
## nothing this can act on changed, so the caller keeps its own message.
static func _moved_knobs(config: WorldgenConfig) -> PackedStringArray:
	var out := PackedStringArray()
	if config == null:
		return out
	for key in FAR_ONLY_PROPERTIES:
		var v := float(config.get(key))
		if _knobs.has(key) and _knobs[key] != v:
			out.append(key)
		_knobs[key] = v
	return out


## THE ONE LINE game.gd IS ALLOWED IN THIS EPIC, and everything behind it.
##
## Returns the status text to show: the far-field message when one of the knobs
## above moved and the rebuild was actually started, and `fallback` - the
## caller's own "press F7" line - otherwise. Returning the text rather than
## setting it keeps the UI entirely on the caller's side of the seam.
##
## `world` is asked for its FarField by node name rather than through an
## accessor because `scripts/world/world.gd` is another lane's file this epic
## does not touch - the same reason debug_hud reaches for it that way.
static func apply_far_knobs(world: Node, far_trees: Node,
		config: WorldgenConfig, fallback: String) -> String:
	var moved := _moved_knobs(config)
	if moved.is_empty():
		return fallback
	var far_field: Node = world.get_node_or_null("FarField") if world != null else null
	if far_field == null or not far_field.has_method("rebuild_in_place"):
		return fallback
	# WORLD KEEPS A SNAPSHOT OF THE CONFIG, NOT THE LIVE ONE, and without this
	# line the whole stage compiles, runs, rebuilds the far mesh and changes
	# nothing on screen.
	#
	# World.setup() clones the config on purpose: "the panel writes into the
	# config Game holds, and if the world read from that too, then moving a
	# slider would change the terrain of chunks not yet streamed in while
	# leaving the ones already around the player alone - a world that disagrees
	# with itself along a line you cannot see." That reasoning is exactly right
	# for a SHAPE knob and has nothing to say about these eleven, every one of
	# which is read only by FarFieldJob and FarTreesJob - checked by grep, not
	# assumed - and both of which rebuild their whole output at once. There is
	# no half-old half-new state for a look knob to leave behind.
	#
	# So the moved values are copied into the snapshot the two jobs actually
	# read, and only those. Nothing else in the snapshot is touched, and F7
	# still re-clones everything as it always did.
	#
	# FOUND BY THE SELF-TEST, which asserted the vertex count and got the same
	# number at 0.0 and at 1.0. It is the reason that assertion exists.
	if world.config != null:
		for key in moved:
			world.config.set(key, config.get(key))
	if not far_field.rebuild_in_place():
		return fallback
	# The ring is rebuilt too: far_terrace moves the shelf every impostor
	# stands on (Stage 5) and far_tree_tint moves its colour. Cheap to ask for
	# either way - FarTrees drops the request if it is already building.
	if far_trees != null and far_trees.has_method("force_rebuild"):
		far_trees.force_rebuild()
	return "%s changed - far country redrawing, no reroll needed" % \
		String(", ").join(moved)


## Rebuild at the SAME centre and frontier the last request used.
##
## Not "rebuild around the player": the player has not moved, and re-deriving
## the centre here would mean re-deriving World's chunk snapping in a second
## place. _pending_center and _pending_frontier still hold what World last
## asked for, which is exactly the mesh that is on screen.
##
## False when there is nothing to rebuild yet - before the first setup(), or on
## a client whose world has not arrived.
func rebuild_in_place() -> bool:
	if _generator == null:
		return false
	_has_pending = true
	_start_if_idle()
	return true
