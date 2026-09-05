extends Node

## WHAT A COLUMN COSTS TO ARRIVE, part by part, on the frame thread.
## Upload v1 Stage 0.
##
##     godot --headless --path . scenes/upload_bench.tscn -- \
##         --seed 42 [--radius 8] [--passes 3] [--mesher gdscript] \
##         [--atom column|chunk] [--column-node 0|1] [--mesh-on-worker 0|1]
##
## A SCENE AND NOT `--script`, and `selftest.gd`'s own header says why in full:
## `--script` replaces the main loop and Godot only creates AUTOLOADS for a real
## one, `world.gd` names the `Net` autoload in its edit path, so under `--script`
## it fails to compile - and the symptom is not that error but `World.new()`
## reporting that GDScript has no function called `new()`, which is exactly what
## the plan's own command line produced the first time it was run. The plan
## § 2 quotes the `--script` form; this file is the correction and it costs one
## scene file. `mesh_bench.gd` is a `SceneTree` script and can stay one because
## it never instantiates a `World`.
##
## THE NUMBER THIS EXISTS FOR. `mesh_bench.gd` measures what a chunk costs to
## MESH, which is worker time and has been in C++ since mesher v1. This is the
## other half and it is the half that is left: what a finished column costs to
## INSTALL - `ChunkNode.new()`, a `StaticBody3D` and a `CollisionShape3D`,
## `add_child`, `add_surface_from_arrays`, `ConcavePolygonShape3D.set_faces` -
## which horizon v1 Stage 7 named as the whole of its open hitch gate without
## ever being able to say which of those five it was.
##
## HOW IT MEASURES. The generation and the meshing happen ONCE on the pool and
## are never timed; then the columns are installed ONE AT A TIME through the
## REAL `World._collect_chunks` with an unbounded budget, so what is timed is
## the shipped installer and not a copy of it. Each column's split is drained
## from `World.take_upload_split()` around its own arrival, which is why the
## per-part medians below are per-COLUMN medians and not a total divided by a
## count: an average would hide the tall columns, and the tall column is what
## the hitch gate is about.
##
## THE WORLD IS IN THE TREE AND ITS `_process` IS OFF. Both halves matter. A
## `MeshInstance3D` outside the tree has no rendering-server instance, so a
## mesh assigned to one is not the same call the game makes - the bench would
## measure a cheaper thing and call it the upload. And `_process` off is what
## lets the pump be driven a column at a time instead of eight milliseconds at
## a time. `set_process(false)` rather than a flag in `world.gd`: the smaller
## change, and the plan's § 5 item 9.
##
## HEADLESS, AND WHAT THAT COSTS. The dummy rendering driver still packs the
## vertex format on the calling thread - which is the part this lane moves -
## but never touches a GPU. So the bench is the RANKING instrument and the
## sprint on the RTX 3070 Ti is the judge; a rung that does not move
## `col_median_us` and `col_max_us` here is not worth a sprint (plan § 3).

const DEFAULT_PASSES := 3
const DEFAULT_RADIUS := 8

var _argv := PackedStringArray()
var _seed := 42
var _radius := DEFAULT_RADIUS
var _passes := DEFAULT_PASSES


func _ready() -> void:
	_go()


func _go() -> void:
	_argv = OS.get_cmdline_user_args()
	_seed = int(_arg("--seed", "42"))
	_radius = int(_arg("--radius", str(DEFAULT_RADIUS)))
	_passes = int(_arg("--passes", str(DEFAULT_PASSES)))

	# THE CONFIGURATIONS, ABAB. The first is always the tree's own defaults;
	# each rung flag names a second one, and the two are alternated pass by
	# pass so a box that warms up or cools down over the run does it to both.
	var configs: Array = [{"name": "shipped", "knobs": {}}]
	for flag in [
		["--atom", "upload_atom_chunk", "chunk"],
		["--column-node", "column_node", ""],
		["--mesh-on-worker", "mesh_on_worker", ""],
		["--shape-on-worker", "shape_on_worker", ""],
		["--flora-on-pump", "flora_on_pump", ""],
	]:
		var given := _arg(flag[0], "")
		if given == "":
			continue
		var value: Variant = (1 if given == flag[2] else 0) \
			if flag[2] != "" else int(given)
		configs.append({
			"name": "%s=%s" % [flag[1], value],
			"knobs": {flag[1]: value},
		})

	print("upload bench: seed %d, radius %d, %d passes, backend %s" % [
		_seed, _radius, _passes, ChunkMesher.backend_name()])

	var results := {}
	for pass_i in _passes:
		for cfg in configs:
			var name: String = cfg["name"]
			var row: Dictionary = await _one(cfg["knobs"])
			if not results.has(name):
				results[name] = []
			(results[name] as Array).append(row)
			print("  pass %d, %s: col median %d us over %d columns" % [
				pass_i + 1, name, int(row["col_median_us"]), int(row["columns"])])

	for name in results:
		_report(name, results[name])
	get_tree().quit(0)


## One build and one timed arrival of every column in the disc.
func _one(knobs: Dictionary) -> Dictionary:
	var config := WorldgenConfig.load_or_default()
	config.apply_cli_overrides(_argv)
	for key in knobs:
		# A knob a stage has not landed yet simply is not there, and a bench
		# run naming it should say so rather than write a property onto a
		# Resource and silently measure the shipped path twice.
		if not (key in config):
			push_error("upload bench: no such knob: %s" % key)
			continue
		config.set(key, knobs[key])

	var world := World.new()
	world.name = "BenchWorld"
	add_child(world)
	# THE PUMP IS THIS SCRIPT'S, not the frame's. See the header.
	world.set_process(false)
	world.setup(_seed, config)
	# And the far country is not what is being measured; its worker would
	# otherwise share the pool with the columns and its uploads would land in
	# the middle of a timed arrival.
	var far: Node = world.get_node_or_null("FarField")
	if far != null:
		far.set_process(false)

	# THE DISC AROUND THE SPAWN, the same shape `refresh_region` walks, and
	# this script's own queue rather than the world's: the world queues its
	# configured radius and this bench wants a stated one.
	world._build_queue.clear()
	world._queued.clear()
	var spawn: Vector2i = world.generator.spawn_block
	var centre := Vector2i(
		Chunk.floor_div(spawn.x, Chunk.SIZE), Chunk.floor_div(spawn.y, Chunk.SIZE))
	var columns: Array[Vector2i] = []
	for dz in range(-_radius, _radius + 1):
		for dx in range(-_radius, _radius + 1):
			if dx * dx + dz * dz > _radius * _radius:
				continue
			columns.append(Vector2i(centre.x + dx, centre.y + dz))
	for col in columns:
		world._submit_column(col)

	# WAIT FOR THE POOL, without collecting. `is_task_completed` is a poll and
	# not a join; the join is `_collect_chunks`'s own
	# `wait_for_task_completion`, which is part of the arrival and is therefore
	# inside the timer where it belongs.
	while true:
		var busy := false
		for col in world._in_flight:
			if not WorkerThreadPool.is_task_completed(world._in_flight[col]["task"]):
				busy = true
				break
		if not busy:
			break
		await get_tree().process_frame

	# ONE COLUMN AT A TIME THROUGH THE REAL INSTALLER.
	var pending: Dictionary = world._in_flight.duplicate()
	world._in_flight = {}
	var col_us: Array[float] = []
	var node_us: Array[float] = []
	var mesh_us: Array[float] = []
	var shape_us: Array[float] = []
	var chunks := 0
	for col in pending:
		world._in_flight[col] = pending[col]
		world.take_upload_split()
		var before: int = world.built_chunk_count()
		var t := Time.get_ticks_usec()
		world._collect_chunks(Time.get_ticks_msec(), 1.0e9)
		var us := Time.get_ticks_usec() - t
		var split: Dictionary = world.take_upload_split()
		chunks += world.built_chunk_count() - before
		col_us.append(float(us))
		node_us.append(float(int(split.get("node", 0))))
		mesh_us.append(float(int(split.get("mesh", 0))))
		shape_us.append(float(int(split.get("shape", 0))))

	var out := {
		"columns": col_us.size(),
		"chunks": chunks,
		"col_median_us": _median(col_us),
		"col_p99_us": _percentile(col_us, 0.99),
		"col_max_us": _percentile(col_us, 1.0),
		"node_us": _median(node_us),
		"mesh_us": _median(mesh_us),
		"shape_us": _median(shape_us),
		"per_chunk_us": _median(col_us) / maxf(
			float(chunks) / float(maxi(col_us.size(), 1)), 0.000001),
	}

	world.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	return out


## The UPLOAD_BENCH line of plan § 3, one per configuration, with the medians
## taken across the passes and the spread beside them.
func _report(name: String, rows: Array) -> void:
	var col_med: Array[float] = []
	for row in rows:
		col_med.append(float(row["col_median_us"]))
	var last: Dictionary = rows[rows.size() - 1]
	print(("UPLOAD_BENCH mesher=%s config=%s columns=%d chunks=%d "
		+ "col_median_us=%d col_p99_us=%d col_max_us=%d "
		+ "node_us=%d mesh_us=%d shape_us=%d per_chunk_us=%d "
		+ "passes=%d spread=%s") % [
		ChunkMesher.resolve_backend(), name,
		int(last["columns"]), int(last["chunks"]),
		int(_median(col_med)),
		int(_median_of(rows, "col_p99_us")),
		int(_median_of(rows, "col_max_us")),
		int(_median_of(rows, "node_us")),
		int(_median_of(rows, "mesh_us")),
		int(_median_of(rows, "shape_us")),
		int(_median_of(rows, "per_chunk_us")),
		rows.size(), _spread(col_med)])


func _median_of(rows: Array, key: String) -> float:
	var values: Array[float] = []
	for row in rows:
		values.append(float(row[key]))
	return _median(values)


func _median(values: Array[float]) -> float:
	if values.is_empty():
		return 0.0
	var sorted: Array[float] = values.duplicate()
	sorted.sort()
	return sorted[sorted.size() / 2]


func _percentile(values: Array[float], frac: float) -> float:
	if values.is_empty():
		return 0.0
	var sorted: Array[float] = values.duplicate()
	sorted.sort()
	return sorted[clampi(int(float(sorted.size()) * frac), 0, sorted.size() - 1)]


## Half the range as a percentage of the median - the far probe's idiom, which
## mesh_bench.gd also uses. Over 15% asks for more passes.
func _spread(values: Array[float]) -> String:
	if values.size() < 2:
		return "one pass"
	var sorted: Array[float] = values.duplicate()
	sorted.sort()
	var mid := _median(values)
	var half: float = (sorted[sorted.size() - 1] - sorted[0]) * 0.5
	return "+-%.1f%%" % (100.0 * half / maxf(mid, 0.000001))


func _arg(name: String, fallback: String) -> String:
	var i := _argv.find(name)
	if i < 0 or i + 1 >= _argv.size():
		return fallback
	return _argv[i + 1]
