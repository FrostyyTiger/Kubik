class_name SelftestUpload
extends Node

## UPLOAD V1'S OWN GATE FILE.
##
##     godot --headless --path . scenes/selftest_upload.tscn
##
## and one line in `selftest.gd` runs it inside the main suite too, so a green
## `SELFTEST: all passed` means both.
##
## WHY A THIRD FILE. The same reason `selftest_horizon.gd` is a second one, and
## the plan's § 0 ownership table says so: this lane is allowed exactly one line
## in `selftest.gd`, and everything it asserts lives here.
##
## SHAPED LIKE ITS TWO PARENTS, deliberately: tests are UNTYPED (an aborted
## typed function returns the default value of its return type, and this file's
## code for "passed" is 0), each returns its failure count and prints its own
## evidence line whether it passed or not, and `run()` returns the total.

## The canonical seed, so a failure here is comparable with the canonical world
## line every stage reprints.
const SEED := 42


func _ready() -> void:
	var failures := run()
	print("")
	print("SELFTEST-UPLOAD: %s" % (
		"all passed" if failures == 0 else "%d FAILED" % failures))
	get_tree().quit(1 if failures > 0 else 0)


static func run() -> int:
	var tests := {
		# STAGE 0.
		"sprint summary parse": _test_sprint_summary,
		"upload parity": _test_upload_parity,
		"collision honesty": _test_collision_honesty,
	}
	var failures := 0
	for name in tests:
		var result = (tests[name] as Callable).call()
		if not (result is int):
			print("  %s DID NOT COMPLETE - it returned %s, so it crashed" % [
				name, type_string(typeof(result))])
			failures += 1
			continue
		failures += result
	return failures


# --- Stage 0 ------------------------------------------------------------------

## THE SPRINT PROBE'S SUMMARY LINE STILL CARRIES THE SPLIT.
##
## Horizon v1's own version of this test guards the fields that were on the line
## before tonight; this one guards the seven this lane added. Same two halves
## and the second is the one that would break silently: the keys are parsed out
## of a specimen line, and then `sprint_probe.gd`'s SOURCE is checked for the
## format specifier of each, so a rename cannot leave sixty beautiful per-second
## lines and a status doc full of dashes.
static func _test_sprint_summary():
	var bad := 0
	var line := ("SPRINT label=x seconds=60 frames=3607 median_ms=14.25 "
		+ "p99_ms=22.10 worst_ms=31.40 over25=3 chunks=812 far_rebuilds=9 "
		+ "far_ms_median=214 tree_rebuilds=4 mem_mb=1180 moved_m=771 jumps=12 "
		+ "tiles=48 tile_mb=6 rebases=1 jitter_mm=0.000 "
		+ "up_node_ms=120.5 up_mesh_ms=430.1 up_shape_ms=210.9 up_edit_ms=0.0 "
		+ "up_flora_ms=88.4 up_bodies_ms=3.2 up_col_max_ms=41.75")
	var got := _parse_kv(line)
	var want := {
		"up_node_ms": "120.5", "up_mesh_ms": "430.1", "up_shape_ms": "210.9",
		"up_edit_ms": "0.0", "up_flora_ms": "88.4", "up_bodies_ms": "3.2",
		"up_col_max_ms": "41.75",
	}
	for key in want:
		if not got.has(key):
			print("  sprint summary: no %s in the line" % key)
			bad += 1
		elif got[key] != want[key]:
			print("  sprint summary: %s is %s, expected %s" % [
				key, got[key], want[key]])
			bad += 1
	var src := FileAccess.get_file_as_string(
		"res://scripts/tools/sprint_probe.gd")
	var missing := PackedStringArray()
	for key in want:
		if not src.contains("%s=%%" % key):
			missing.append(key)
	# AND THE PER-SECOND LINE'S TWO FIELDS, which are what the split table in
	# the status doc is read off.
	for key in ["up=%d/%d/%d/%d/%d/%d", "colmax=%d"]:
		if not src.contains(key):
			missing.append(key)
	if not missing.is_empty():
		print("  sprint summary: sprint_probe.gd no longer writes %s" % missing)
		bad += 1
	print("sprint summary parse: %d split keys, %d bad" % [want.size(), bad])
	return bad


## WHAT REACHES THE SCREEN IS WHAT THE WORKER BUILT.
##
## The whole of this lane is "the arrival, made cheaper", and the one thing it
## must never do is change what arrives. So: the canonical seed, the 5 x 5
## columns around the spawn, installed through the REAL `_collect_chunks` with
## every knob at its shipped value, and then every installed surface read back
## and compared with the arrays the `ColumnJob` handed over.
##
## WHAT "EXACT" CAN MEAN, AND THIS IS A FINDING OF STAGE 0. `ArrayMesh` does not
## store what you give it. Measured on this engine: a vertex and an index survive
## `add_surface_from_arrays` -> `surface_get_arrays` bit for bit, a NORMAL does
## not - (0, 1, 0) reads back as (0, 1, -0.000015), octahedral 2 x 16 - and a
## COLOUR does not either - 0.1 reads back as 0.098, eight bits a channel. The
## plan's § 3 asks for all four exact against the job's arrays and that is not a
## thing the engine can do.
##
## So the gate is exact in two layers, and together they are STRICTER than the
## plan's sentence rather than weaker:
##
##   1. against the job's OWN arrays: vertices and indices, bit for bit. These
##      are the two the engine keeps, and they are the two a wrong offset, a
##      wrong surface or a wrong chunk would move.
##   2. against a REFERENCE mesh built from the same arrays by the same
##      `ChunkMesher.arrays_to_mesh`, read back the same way: all four,
##      including normals and colours, bit for bit. The engine's quantisation
##      is a function of the input, so two meshes that read back differently
##      were given different arrays - which is the question being asked.
##
## Both meshers, because `--mesher gdscript` is still a supported run (grill
## Q10) and each leg is compared against ITS OWN job's arrays.
static func _test_upload_parity():
	var bad := 0
	var lines := PackedStringArray()
	for backend in ["cpp", "gdscript"]:
		if backend == "cpp" and not ChunkMesher.class_present():
			lines.append("cpp skipped (no library)")
			continue
		var was := ChunkMesher.backend
		ChunkMesher.force_backend(backend)
		var got := _parity_leg(backend)
		ChunkMesher.force_backend(was)
		bad += int(got["bad"])
		lines.append("%s %d chunks, %d surfaces, %d bad" % [
			backend, int(got["chunks"]), int(got["surfaces"]), int(got["bad"])])
	print("upload parity: %s" % ", ".join(lines))
	return bad


## One mesher's leg of the parity gate.
static func _parity_leg(backend: String) -> Dictionary:
	var bad := 0
	var world := World.new()
	world.setup(SEED, _config())
	var spawn: Vector2i = world.generator.spawn_block
	var centre := Vector2i(
		Chunk.floor_div(spawn.x, Chunk.SIZE), Chunk.floor_div(spawn.y, Chunk.SIZE))

	var cols: Array[Vector2i] = []
	for dz in range(-2, 3):
		for dx in range(-2, 3):
			cols.append(centre + Vector2i(dx, dz))
	for col in cols:
		world._submit_column(col)

	# THE JOBS ARE CAPTURED BEFORE THE PUMP RUNS, because `_collect_chunks`
	# drops `_in_flight` as it goes and the arrays under test go with it.
	var spins := 0
	var jobs := {}
	while jobs.size() < cols.size() and spins < 60000:
		for col in world._in_flight:
			if WorkerThreadPool.is_task_completed(world._in_flight[col]["task"]):
				jobs[col] = world._in_flight[col]["job"]
		if jobs.size() < cols.size():
			OS.delay_msec(1)
			spins += 1
	if jobs.size() < cols.size():
		print("  %s: only %d of %d columns ever finished" % [
			backend, jobs.size(), cols.size()])
		world.free()
		return {"bad": 1, "chunks": 0, "surfaces": 0}

	# THE WHOLE PUMP, unbudgeted, and then the collision pump if this build has
	# one - the gate is the state AFTER the arrival, however many frames the
	# shipped configuration takes to get there.
	world._collect_finished(Time.get_ticks_msec(), 1.0e9)
	_drain_collision(world)

	var chunks := 0
	var surfaces := 0
	for col in cols:
		var job: ColumnJob = jobs[col]
		for cy in job.built:
			var entry: Dictionary = job.built[cy]
			var arrays: Array = entry["arrays"]
			var faces: PackedVector3Array = entry["faces"]
			var chunk_pos := Vector3i(col.x, cy, col.y)
			var node: ChunkNode = world._chunk_nodes.get(chunk_pos)
			if node == null:
				print("  %s: %s never got a node" % [backend, chunk_pos])
				bad += 1
				continue
			chunks += 1
			if arrays.is_empty():
				# A chunk with no visible faces gets no surface and no shape,
				# and that is the rule `chunk_node.gd` states: nothing to see
				# and nothing to stand on rather than an empty one of each.
				if _surface_count(world, chunk_pos) != 0:
					print("  %s: %s has faces it should not" % [backend, chunk_pos])
					bad += 1
				continue
			surfaces += 1
			bad += _compare_surface(world, chunk_pos, arrays, backend)
			bad += _compare_faces(world, chunk_pos, faces, backend)
			if not world.is_chunk_collidable(chunk_pos):
				print("  %s: %s is not collidable after the pump" % [
					backend, chunk_pos])
				bad += 1
	world.free()
	return {"bad": bad, "chunks": chunks, "surfaces": surfaces}


## One installed surface against the arrays that built it. See the two layers in
## `_test_upload_parity`'s note.
static func _compare_surface(world: World, chunk_pos: Vector3i, arrays: Array,
		backend: String) -> int:
	var got: Array = _surface_arrays(world, chunk_pos)
	if got.is_empty():
		print("  %s: %s has no installed surface" % [backend, chunk_pos])
		return 1
	var want := ChunkMesher.arrays_to_mesh(arrays).surface_get_arrays(0)
	var bad := 0
	# LAYER 1: the two the engine keeps, against the job's own arrays.
	if (got[Mesh.ARRAY_VERTEX] as PackedVector3Array) \
			!= (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array):
		print("  %s: %s vertices differ from the job's" % [backend, chunk_pos])
		bad += 1
	if (got[Mesh.ARRAY_INDEX] as PackedInt32Array) \
			!= (arrays[Mesh.ARRAY_INDEX] as PackedInt32Array):
		print("  %s: %s indices differ from the job's" % [backend, chunk_pos])
		bad += 1
	# LAYER 2: all four, against the reference mesh, through the same storage.
	for which in [Mesh.ARRAY_VERTEX, Mesh.ARRAY_NORMAL, Mesh.ARRAY_COLOR,
			Mesh.ARRAY_INDEX]:
		if got[which] != want[which]:
			print("  %s: %s array %d differs from the reference mesh" % [
				backend, chunk_pos, which])
			bad += 1
	return bad


## The installed collision shape against the faces the worker derived.
static func _compare_faces(world: World, chunk_pos: Vector3i,
		faces: PackedVector3Array, backend: String) -> int:
	var node: ChunkNode = world._chunk_nodes.get(chunk_pos)
	var shape: Shape3D = _shape_of(node, chunk_pos)
	if shape == null:
		print("  %s: %s has no collision shape" % [backend, chunk_pos])
		return 1
	var got: PackedVector3Array = (shape as ConcavePolygonShape3D).get_faces()
	if got != faces:
		print("  %s: %s shape faces differ (%d against %d)" % [
			backend, chunk_pos, got.size(), faces.size()])
		return 1
	return 0


## NOBODY IS STANDING ON A CHUNK THAT HAS NOTHING UNDER IT.
##
## Two halves, and the second is the one Stage 2 can break: no chunk may report
## `collision_applied` without a shape actually installed on it, and no shape may
## be installed on a PARKED node - a parked column is not standable and
## `set_parked` says so, so a shape landing on one from a queue that outlived the
## parking would be a chunk the world believes in and the player falls through.
static func _test_collision_honesty():
	var bad := 0
	var world := World.new()
	world.setup(SEED, _config())
	var spawn: Vector2i = world.generator.spawn_block
	var centre := Vector2i(
		Chunk.floor_div(spawn.x, Chunk.SIZE), Chunk.floor_div(spawn.y, Chunk.SIZE))
	var cols: Array[Vector2i] = []
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			cols.append(centre + Vector2i(dx, dz))
	for col in cols:
		world._submit_column(col)
	var spins := 0
	while not world._in_flight.is_empty() and spins < 60000:
		world._collect_finished(Time.get_ticks_msec(), 1.0e9)
		OS.delay_msec(1)
		spins += 1
	_drain_collision(world)

	var checked := 0
	for pos in world._chunk_nodes:
		var node: ChunkNode = world._chunk_nodes[pos]
		if not node.collision_applied:
			continue
		checked += 1
		# THE RULE IS `chunk_node.gd`'s OWN, and it is about the FACES and not
		# about the voxels: "the collision shape is generated FROM the visible
		# mesh, so the two can never disagree - you cannot end up standing on a
		# face that is not drawn, or walking through one that is". A chunk deep
		# under the ground has solid blocks and no drawn face, and it gets no
		# shape on purpose - which is why the check is mesh against shape and
		# not `has_solid` against shape. (It was `has_solid` when this test was
		# first written, and 27 of 36 buried chunks said so.)
		var drawn: bool = node.mesh != null \
			and (node.mesh as ArrayMesh).get_surface_count() > 0
		var shape := _shape_of(node, pos)
		if drawn and shape == null:
			print("  %s draws faces and has no collision shape" % pos)
			bad += 1
		if not drawn and shape != null and node.mesh_built:
			print("  %s draws nothing and has a collision shape" % pos)
			bad += 1

	# AND THE PARKED HALF. Park the lot and look again.
	world._center = Vector2i(100000, 100000)
	world._free_distant_chunks(1, 1)
	var parked := 0
	for col in world._column_cache:
		var entry: Dictionary = world._column_cache[col]
		for cy in entry["nodes"]:
			var node: ChunkNode = entry["nodes"][cy]
			parked += 1
			if node.collision_applied:
				print("  a parked node still reports collision_applied")
				bad += 1
			if not _collider_disabled(node):
				print("  a parked node still has its collider enabled")
				bad += 1
	world.free()
	print("collision honesty: %d live chunks checked, %d parked, %d bad" % [
		checked, parked, bad])
	return bad


# --- Helpers ------------------------------------------------------------------

## The config every world in this file is built with: the canonical seed's own
## world, with the disc small enough that the test is about the arrival and not
## about how long a spawn takes.
static func _config() -> WorldgenConfig:
	var cfg := WorldgenConfig.load_or_default()
	cfg.voxel_radius_chunks = 3
	return cfg


## Spend the collision queue, for a build that has one (Stage 2 onward). A
## no-op before it lands, which is what keeps this file's tests written once.
static func _drain_collision(world: World) -> void:
	if world.has_method("_pump_collision"):
		world.call("_pump_collision", 0.0)


## The `ArrayMesh` surface installed for this chunk, read back - whatever shape
## the node graph has. One node per chunk today; one node per column with a
## surface index from Stage 3, and this is the one place that has to know.
static func _surface_arrays(world: World, chunk_pos: Vector3i) -> Array:
	var node: ChunkNode = world._chunk_nodes.get(chunk_pos)
	if node == null or node.mesh == null:
		return []
	var index := 0
	if node.has_method("surface_index_of"):
		index = int(node.call("surface_index_of", chunk_pos))
	if index < 0 or index >= (node.mesh as ArrayMesh).get_surface_count():
		return []
	return (node.mesh as ArrayMesh).surface_get_arrays(index)


static func _surface_count(world: World, chunk_pos: Vector3i) -> int:
	var node: ChunkNode = world._chunk_nodes.get(chunk_pos)
	if node == null or node.mesh == null:
		return 0
	if node.has_method("surface_index_of"):
		return 1 if int(node.call("surface_index_of", chunk_pos)) >= 0 else 0
	return (node.mesh as ArrayMesh).get_surface_count()


## This chunk's collision shape, whichever collider carries it.
static func _shape_of(node: ChunkNode, chunk_pos: Vector3i) -> Shape3D:
	if node.has_method("collider_for"):
		var got = node.call("collider_for", chunk_pos)
		return (got as CollisionShape3D).shape if got != null else null
	return node._collider.shape if node._collider != null else null


static func _collider_disabled(node: ChunkNode) -> bool:
	if node.has_method("colliders"):
		for c in node.call("colliders"):
			if not (c as CollisionShape3D).disabled:
				return false
		return true
	return node._collider == null or node._collider.disabled


## `key=value key=value` into a Dictionary, exactly as a reader's `awk` does it.
static func _parse_kv(line: String) -> Dictionary:
	var out := {}
	for part in line.split(" ", false):
		var at := part.find("=")
		if at <= 0:
			continue
		out[part.substr(0, at)] = part.substr(at + 1)
	return out
