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

## THE BUDGETED UPLOADER, ONE PER WORLD, OWNED HERE. Distance v5 Stage 1,
## decision 1 - and the choice of owner is recorded because the plan left it
## open. FarField rather than World, because it is FarField that already has a
## _process running on the main thread every frame, already owns the far mesh's
## whole lifecycle, and already dies with the world. Putting it in World would
## have meant a second node with a second _process to pump it, for nothing.
##
## The impostor ring is Game's child rather than World's, so it reaches this
## one through the tree - see uploader().
var _upload := FarUpload.new()

## THE NEW MESH, BEING FILLED, THAT NOBODY IS LOOKING AT. Rule 2 of FarUpload:
## slices land here and `mesh` is assigned once, when the last one has.
var _next_mesh: ArrayMesh = null
var _next_frontier := PackedInt32Array()
var _next_verts := 0

## What the last completed handover cost on the frame thread, and over how many
## frames. For the F3 readout.
var _last_upload_ms := 0.0
var _last_upload_frames := 0

## THE C++ MESHER, ONE INSTANCE PER WORLD, OWNED HERE. Distance v4 Stage 5,
## hard rule 5: no new global state - it is a RefCounted this node holds and
## drops with itself, and setup() hands it the world exactly once because
## marshalling a pyramid per rebuild would spend the speedup on the seam.
##
## Null on a checkout with no compiled library, which is hard rule 1: the game
## must run, play and pass every self-test with the far mesh built in GDScript
## and one load warning as the only trace.
var _mesher: FarMesher = null

## Whichever of the two built the mesh currently being waited on. Both present
## `arrays`, `vertex_count`, `elapsed_ms` and `frontier`, so _process reads one
## variable and does not care which.
var _active: RefCounted = null

## What built the LAST finished mesh, for the F3 readout. "gdscript" until one
## has been built, which is honest: before the first build nothing has.
var _last_mesher := "gdscript"

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

## Every rebuild's wall time this session, for the summary printed at exit.
## See the note where it is appended.
var _walls := PackedInt32Array()


func setup(generator: TerrainGenerator, config: WorldgenConfig) -> void:
	_generator = generator
	_heightmap = generator.heightmap
	_config = config
	# ITS OWN MATERIAL SINCE DISTANCE V3 STAGE 2, and it used to be the chunks'.
	#
	# The comment that stood here said "one shared material with the chunks, so
	# the renderer can batch the far field together with the voxels instead of
	# breaking the batch at the horizon". That was true and it is now paid for:
	# the far field has uniforms the chunks must not have - the block-lattice
	# grain, and Stage 7's dither - and a material is where a uniform lives. The
	# cost is one extra draw group for ONE mesh, which is the same price
	# figure_material() and far_tree_material() already pay, and it is measured
	# rather than assumed in docs/status/distance-v3.md.
	#
	# The SOURCE is still the chunks' - far_field_material() is a second
	# OPAQUE_SHADER rather than editing it - so the near field's shader string is
	# byte for byte the one main compiles.
	material_override = Look.far_field_material()
	# DISTANCE V3 STAGE 7. Before any job exists, and on the main thread - see
	# apply_overdraw().
	apply_overdraw(config)
	# DISTANCE V4 STAGE 5, THE DISPATCH. The world crosses the seam once, here,
	# on the main thread, before any job exists. A failure to marshal is not an
	# error: _mesher stays null and every rebuild goes through FarFieldJob,
	# which is the path this game shipped on.
	_mesher = null
	if FarMesher.available():
		var m := FarMesher.new()
		if m.setup(_heightmap, generator, config):
			_mesher = m
		else:
			push_warning("[FarField] the C++ far mesher would not take this world - building in GDScript")
	else:
		# ONE LOAD WARNING AND NOTHING ELSE. Hard rule 1's "the only trace".
		print("[FarField] no compiled far mesher - building in GDScript")
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
	# THE UPLOADER GETS ITS BUDGET FIRST, and it gets it whether or not a build
	# finished this frame - a handover takes about sixteen frames and a rebuild
	# arrives every seven hundred milliseconds, so most frames that have
	# uploading to do have no job to collect.
	_upload.pump(_config.far_upload_budget_ms if _config != null else 4.0)
	if _task == -1:
		return
	if not WorkerThreadPool.is_task_completed(_task):
		return
	WorkerThreadPool.wait_for_task_completion(_task)
	_task = -1

	_last_ms = _active.elapsed_ms
	_last_wall_ms = int((Time.get_ticks_usec() - _started_us) / 1000)
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
	if _rebuilds == 0:
		print("[FarField] first build: %d vertices, %d ms job, %d ms wall, %s mesher" % [
			_active.vertex_count, _last_ms, _last_wall_ms, _last_mesher])
	# AND EVERY REBUILD'S WALL TIME, KEPT FOR THE SUMMARY AT EXIT. Distance v3
	# Stage 4, because the first build is the WORST one and the acceptance
	# criterion is about a rebuild.
	#
	# The first build happens while the world is generating: 2,400 chunks are
	# queued on a worker pool that runs one GDScript task at a time, so its
	# wall time is mostly a queue this job did not create. Every rebuild after
	# it - the player crossing a chunk boundary, or a knob moving on F4 - runs
	# against a nearly idle pool, and THAT is what "the far country redraws in
	# under N seconds" has always meant. One number cannot be both.
	_walls.append(_last_wall_ms)
	# THE HANDOVER, ON A BUDGET. Distance v5 Stage 1: what used to be one
	# `ChunkMesher.arrays_to_mesh` on this frame - 197 ms at far_ring_div 4 -
	# is now one queued job of sixteen sector slices, and `mesh` does not move
	# until the last of them has landed.
	_queue_upload(_active.slices, _active.frontier, _active.vertex_count)
	# AND THE MESHER LETS GO OF THEM. The queue holds every slice it still has
	# to upload; the mesher holding a second reference to the same arrays until
	# its next build would keep a whole extra far mesh alive for the whole
	# handover, which at far_ring_div 4 is about 120 MB.
	_active.slices = []
	_job = null
	_active = null
	_start_if_idle()


## Turn a finished build into a queued handover. See FarUpload's three rules.
##
## The new mesh is built beside the old one and swapped in whole, so a rebuild
## in progress shows the OLD COMPLETE far country and never a mixed one - and
## `_built_frontier`, `rebuilt` and the vertex count all move on the SWAP
## rather than on the build. Anything asking "is this column covered right now"
## - the stream probe above all - would otherwise be told yes about ground that
## is still sixteen frames from being on screen.
func _queue_upload(slices: Array, frontier: PackedInt32Array, verts: int) -> void:
	var next := ArrayMesh.new()
	_next_mesh = next
	_next_frontier = frontier
	_next_verts = verts
	var work: Array[Callable] = []
	for arrays in slices:
		if (arrays as Array).is_empty():
			# A sector with no quads in it. Some always are: the far disc has a
			# hole in the middle and the world has an edge.
			continue
		work.append(func() -> void:
			next.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			next.surface_set_material(next.get_surface_count() - 1,
				ChunkMesher.get_material()))
	_upload.submit(&"far_field", work, _commit_upload)


func _commit_upload() -> void:
	mesh = _next_mesh if _next_mesh != null \
		and _next_mesh.get_surface_count() > 0 else null
	# The frontier THIS MESH was cut to. Not the same as the world's current
	# one: a rebuild takes a frame or two on a worker plus a handover on the
	# frame thread, and during that window what is on screen is the old hole.
	_built_frontier = _next_frontier
	_last_verts = _next_verts
	# REBUILDS COUNTS WHAT IS ON SCREEN, not what has been built. Every waiter
	# in the project - the self-test's pump, the far probe's idle rebuild, the
	# bench - spins on this number to mean "the new mesh is up", and after this
	# stage the build finishing is no longer that moment.
	_rebuilds += 1
	var last: Dictionary = _upload.stats()["last"]
	if last.has(&"far_field"):
		_last_upload_ms = float(last[&"far_field"]["ms"])
		_last_upload_frames = int(last[&"far_field"]["frames"])
	rebuilt.emit(_next_verts)


func _start_if_idle() -> void:
	if _task != -1 or not _has_pending or _generator == null:
		return
	_has_pending = false
	# THE DISPATCH. The C++ mesher when there is one and the knob has not turned
	# it off; GDScript otherwise, on exactly the same three lines - both objects
	# present the same five members, so nothing below this branch knows which
	# built the mesh.
	if _use_cpp():
		_mesher.config = _config
		_mesher.center = _pending_center
		_mesher.frontier = _pending_frontier
		# SLICED, distance v5 Stage 1. The runtime path is the only caller that
		# asks for this; the probe, the parity harness and the self-test build
		# the whole mesh, which is byte for byte the one this project has
		# always emitted.
		_mesher.slice = true
		_active = _mesher
		_last_mesher = "c++"
	else:
		_job = FarFieldJob.new()
		_job.heightmap = _heightmap
		_job.generator = _generator
		_job.config = _config
		_job.center = _pending_center
		_job.frontier = _pending_frontier
		_job.slice = true
		_active = _job
		_last_mesher = "gdscript"
	_started_us = Time.get_ticks_usec()
	_task = WorkerThreadPool.add_task(_active.run, false, "kubik far field")


## THE A/B, IN A RUNNING GAME. `far_cpp` is a local knob on F4, default 1, and
## it is on FAR_ONLY_PROPERTIES - so turning it to 0 rebuilds the far country in
## place, standing still, in GDScript, and turning it back rebuilds it in C++.
## Every gate in this epic is run both ways because of this line.
##
## The knob cannot conjure a mesher that is not there: with no compiled library
## _mesher is null and this is false at every value.
func _use_cpp() -> bool:
	if _mesher == null or _config == null:
		return false
	return _config.far_cpp > 0.5


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
	# THE OVERDRAW RADIUS, distance v3 Stage 7, and it used to be the nominal
	# two-cell margin. Same expression the job uses, same static, so the two
	# cannot drift - which is the whole reason that static exists.
	return maxf(voxel_radius_blocks
		- float(FarFieldJob.FRONTIER_OVERLAP_CELLS
			* FarFieldJob.base_step_blocks(_config)), 0.0)


## WHERE THE FAR FIELD STARTS, from far_overdraw. Distance v3 Stage 7.
##
## `far_overdraw` is the fraction of the voxel radius the far mesh's inner edge
## sits at - DH's `overdrawPreventionPercent`, same sense: 0.9 is almost no
## overlap and 0.2 is a lot. The job and `world.gd` both work in CELLS of
## overlap rather than in a fraction, because `world.gd` subtracts a constant
## from a PER-SECTOR frontier and a fraction of what would be a different
## number in every sector. So the fraction is converted once, here, against the
## nominal voxel radius: at 0.667 this returns 8, which is the constant
## distance v2 shipped, exactly.
##
## MAIN THREAD ONLY. It writes a static a worker reads; called from setup() and
## from apply_far_knobs(), both of which are the main thread's, and never from
## inside a job.
static func apply_overdraw(config: WorldgenConfig) -> void:
	if config == null:
		return
	var voxel_radius_blocks := float(config.voxel_radius_chunks * Chunk.SIZE)
	var overlap := (1.0 - clampf(config.far_overdraw, 0.0, 1.0)) \
		* voxel_radius_blocks / float(FarFieldJob.base_step_blocks(config))
	FarFieldJob.FRONTIER_OVERLAP_CELLS = maxi(int(round(overlap)), 2)


## What the last rebuild cost, for the F3 readout. Distance v1 Stage 0.
func stats() -> Dictionary:
	return {
		"vertices": _last_verts,
		"build_ms": _last_ms,
		"wall_ms": _last_wall_ms,
		"rebuilds": _rebuilds,
		# DISTANCE V4 STAGE 5. Which of the two drew what is on screen - the F3
		# line the plan asks for, and the one thing a screenshot cannot say.
		"mesher": _last_mesher,
		"cpp_available": _mesher != null,
		# DISTANCE V5 STAGE 1. What the handover cost on the frame thread and
		# how many frames it was spread over - one number without the other is
		# half the fact.
		"upload_ms": _last_upload_ms,
		"upload_frames": _last_upload_frames,
		"upload_pending": _upload.pending(),
	}


## THE BUDGETED UPLOADER, for anything else with a far-system handover to make.
##
## `TreeField` is Game's child rather than World's, so it asks for this the way
## `apply_far_knobs` asks for `FarField` - by node name, through the tree. That
## is not elegant and it is the same trade `debug_hud` and `screenshot_tour`
## already take: reaching across is cheaper than a wiring line in another
## lane's file, and there is exactly one of these to reach for.
func uploader() -> FarUpload:
	return _upload


## Block until any build finishes, before the world it reads is thrown away.
func drain() -> void:
	if _task != -1:
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1
	_job = null
	_active = null
	_has_pending = false
	# AND ANYTHING STILL WAITING TO GO UP. A world being put down with a half
	# uploaded mesh behind it would leave the slices' captured arrays alive in
	# a queue nobody pumps.
	_upload.drain()


func _exit_tree() -> void:
	drain()
	_print_wall_summary()


## What the far mesh cost over the whole session, printed once, at exit.
##
## Distance v3 Stage 4. The acceptance criterion is "wall rebuild under 5 s on
## ganymede", and until this existed the only wall time any run printed was the
## FIRST build's - which is the one that waits behind the whole world being
## generated and is therefore the one number that cannot answer the question.
##
## Median and worst over every rebuild, with the first one broken out so it can
## be seen rather than hidden inside the distribution. A screenshot tour visits
## seventeen vantages and rebuilds at every one, so a tour is now also a
## seventeen-sample measurement of what a rebuild costs.
func _print_wall_summary() -> void:
	if _walls.is_empty():
		return
	var sorted := _walls.duplicate()
	sorted.sort()
	var rest := 0
	if _walls.size() > 1:
		var tail := _walls.slice(1)
		tail.sort()
		rest = tail[tail.size() / 2]
	print("[FarField] %d rebuilds: median %d ms wall, worst %d ms, first %d ms, median after the first %d ms" % [
		_walls.size(), sorted[sorted.size() / 2], sorted[sorted.size() - 1],
		_walls[0], rest])


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
	"far_terrace", 
	"far_filter_bias", "far_peak_gain", "far_normal_m", "far_level_ref_m",
	"far_zone_cell_m", "far_zone_cell_ratio",
	"far_tree_tint",
	# DISTANCE V3, appended. Every one of them redraws the far mesh or the
	# impostor ring and nothing else, which is what earns a place on this
	# list - and being on it is what makes a knob judgeable standing still.
	"far_vote", "far_grain", 
	# far_grain and far_fog_start_frac are UNIFORMS and are already live
	# through Look.apply_local_knobs() before this runs. They are on this
	# list anyway, and deliberately: being on it is what makes the panel say
	# "the far country is redrawing" instead of "press F7 to rebuild
	# terrain", and the F7 message on a knob that needs no reroll is the
	# exact confusion distance v2 Stage 0 existed to remove. The rebuild it
	# also triggers is redundant and costs one worker task nobody is
	# waiting on.
	"far_fog_start_frac", "far_overdraw", "far_tree_grain",
	# 2026-08-31, the vertical-step ruling. Redraws the far mesh only.
	"far_step_y_blocks",
	# 2026-09-01, the horizontal ladder. Redraws the far mesh and the ring.
	"far_ring_div",
	# DISTANCE V5 STAGE 1. On this list so the budget can be turned to 0 and
	# back standing still - which is the A/B for "did the budget buy anything",
	# and the same argument far_cpp is on it for.
	"far_upload_budget_ms",
	# DISTANCE V5 STAGE 2. Redraws the impostor ring and nothing else.
	"far_tree_step_m",
	# DISTANCE V5 STAGE 3. Redraws the far mesh; the whole point of it is
	# judgeable by walking past a ring boundary with it on and off.
	"far_geomorph_cells",
	# DISTANCE V5 STAGE 6. Redraws the far mesh, and 0/1 standing still is the
	# A/B the morning's eyes are for.
	"far_detail",
	# DISTANCE V4 STAGE 5. Which mesher draws the far country. On this list so
	# the A/B is one spinbox and a redraw in place rather than a relaunch -
	# which is the only way "the C++ mesh is the same mesh" can be judged by
	# eye rather than only by the parity gate.
	"far_cpp",
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
static func apply_far_knobs(world: Node, tree_field: Node,
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
	# which is read only by FarFieldJob and TreeFieldJob - checked by grep, not
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
	# DISTANCE V3 STAGE 7. The overdraw is a static the JOB reads and world.gd
	# reads, so it is pushed before the rebuild is asked for rather than read
	# out of the config inside the job.
	apply_overdraw(config)
	if not far_field.rebuild_in_place():
		return fallback
	# The ring is rebuilt too: far_terrace moves the shelf every impostor
	# stands on (Stage 5) and far_tree_tint moves its colour. Cheap to ask for
	# either way - TreeField drops the request if it is already building.
	if tree_field != null and tree_field.has_method("force_rebuild"):
		tree_field.force_rebuild()
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
