extends SceneTree

## WHAT A CHUNK COSTS TO MESH, twin against C++, over a real spawn disc.
## Mesher v1 Stage 0, Q10.
##
##     godot --headless --path . --script scripts/tools/mesh_bench.gd -- \
##         --seed 42 [--ao 0.45] [--passes 3] [--radius N]
##
## THIS NUMBER HAS NEVER EXISTED. `world.gd`'s load line prints "gen per chunk",
## and that value is `gen_usec + tree_usec` - it leaves `mesh_usec` on the floor
## entirely, so no document in this project has ever said what GDScript meshing
## costs per chunk averaged over anything. The audit's case for this whole phase
## rests on one column of real forest measured in trees v3 (29.63 ms of mesh
## against 5.81 ms of voxels), which is the worst case rather than the average.
## The first line this prints is that missing average.
##
## HOW IT MEASURES, AND WHY IT IS SHAPED LIKE THE FAR PROBE'S BENCH. ABAB,
## chunk by chunk, three passes, medians with the spread beside them, and the
## generation done ONCE and never timed - generating voxels is not this lane's
## work and including it would bury the thing being measured under it. The two
## meshers are driven from the SAME borders, which is why the parity line at the
## bottom is worth reading: a bench that fed them different neighbours would
## report two speeds for two different problems.
##
## THE BORDER MARSHAL IS ITS OWN COLUMN. Handing a chunk to C++ costs something
## - six dictionary writes and a reference to each neighbour's bytes - and a
## speedup that quietly spent itself on marshalling would be a bad trade made
## invisible. Q4 puts a line at 0.3 ms per chunk; this is what it is measured
## against.

const DEFAULT_PASSES := 3


func _init() -> void:
	var argv := OS.get_cmdline_user_args()
	var world_seed := int(_arg(argv, "--seed", "42"))
	var passes := int(_arg(argv, "--passes", str(DEFAULT_PASSES)))
	var ao := float(_arg(argv, "--ao", "-1"))

	var config := WorldgenConfig.load_or_default()
	config.apply_cli_overrides(argv)
	if ao >= 0.0:
		config.ao_strength = ao
	var radius := int(_arg(argv, "--radius", str(config.voxel_radius_chunks)))

	print("mesh bench: seed %d, ao %.2f, %d passes, backend %s" % [
		world_seed, config.ao_strength, passes, ChunkMesher.backend_name()])

	var t0 := Time.get_ticks_msec()
	var gen := TerrainGenerator.new(world_seed, config)
	gen.build_heightmap()
	# Lakes first and handed back to the generator, exactly as World and the
	# worldgen probe do it: the detail layer is faded out near a water line, and
	# a bench built without them would mesh chunks the game never builds.
	var lakes := Lakes.new()
	lakes.compute(gen.heightmap, config)
	gen.lakes = lakes
	var spawn := gen.find_spawn()
	var centre := Vector2i(
		Chunk.floor_div(spawn.x, Chunk.SIZE), Chunk.floor_div(spawn.y, Chunk.SIZE))
	print("  world in %d ms: spawn (%d, %d) = column (%d, %d)" % [
		Time.get_ticks_msec() - t0, spawn.x, spawn.y, centre.x, centre.y])

	# THE DISC, NOT A SQUARE, and the same disc World.refresh_region() walks:
	# dx^2 + dz^2 <= radius^2. At the shipped radius of 12 that is 441 columns.
	var columns: Array[Vector2i] = []
	for dz in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			if dx * dx + dz * dz > radius * radius:
				continue
			columns.append(Vector2i(centre.x + dx, centre.y + dz))

	var t_gen := Time.get_ticks_msec()
	var jobs := {}
	for col in columns:
		var job := ColumnJob.new()
		job.chunk_x = col.x
		job.chunk_z = col.y
		job.cy_range = _column_chunk_range(gen, config, col.x, col.y)
		job.generator = gen
		job.config = config
		job.world_seed = world_seed
		job.build_meshes = false
		job.run()
		jobs[col] = job

	# THE NEIGHBOURS, AFTER THE FACT. In the game a column job is handed the
	# chunks that already exist when it is submitted; here every column exists,
	# so every job gets all four of its neighbours and the borders are the
	# fully-loaded interior case - which is the case the streaming path spends
	# almost all of its time in.
	for col in columns:
		var job: ColumnJob = jobs[col]
		var n := {}
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var other: ColumnJob = jobs.get(col + d)
			if other == null:
				continue
			for cy in other.chunks():
				n[Vector3i(other.chunk_x, cy, other.chunk_z)] = other.chunks()[cy]
		job.neighbours = n
		job.build_strips()

	# Every chunk the streaming path would mesh, in column order.
	var work: Array = []
	for col in columns:
		var job: ColumnJob = jobs[col]
		for cy in job.cy_range:
			if cy > job.ceiling:
				continue
			work.append([job, cy])
	print("  %d columns, %d chunks, generated in %d ms (untimed)" % [
		columns.size(), work.size(), Time.get_ticks_msec() - t_gen])

	var cpp: Object = null
	if ClassDB.class_exists(ChunkMesher.CPP_CLASS) and ChunkMesher.class_present():
		cpp = ClassDB.instantiate(ChunkMesher.CPP_CLASS)
		cpp.setup(ChunkMesher.setup_args(config))

	var twin_ms: Array[float] = []
	var cpp_ms: Array[float] = []
	var border_ms: Array[float] = []
	var twin_quads := 0
	var cpp_quads := 0
	var parity_bad := 0
	var parity_checked := 0

	for pass_i in passes:
		var twin_us := 0
		var cpp_us := 0
		var borders_us := 0
		twin_quads = 0
		cpp_quads = 0
		for item in work:
			var job: ColumnJob = item[0]
			var cy: int = item[1]
			var chunk: Chunk = job.chunks()[cy]

			var t := Time.get_ticks_usec()
			var want := ChunkMesher.build_arrays_gd(
				chunk, job.solid_callable(), config, world_seed)
			twin_us += Time.get_ticks_usec() - t
			if not want.is_empty():
				twin_quads += (want[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 4

			if cpp == null:
				continue
			t = Time.get_ticks_usec()
			var borders := job.borders_for(cy)
			borders_us += Time.get_ticks_usec() - t
			t = Time.get_ticks_usec()
			var raw: Dictionary = cpp.build(borders)
			cpp_us += Time.get_ticks_usec() - t
			cpp_quads += int(raw.get("quads", 0))
			if pass_i == 0:
				parity_checked += 1
				parity_bad += _parity(want, ChunkMesher.arrays_from_cpp(raw),
					bool(cpp.has_colors()))

		var n := float(work.size())
		twin_ms.append(float(twin_us) / 1000.0 / n)
		cpp_ms.append(float(cpp_us) / 1000.0 / n)
		border_ms.append(float(borders_us) / 1000.0 / n)

	print("mesh bench: seed %d, %d columns, %d chunks, ao %.2f, %d passes ABAB" % [
		world_seed, columns.size(), work.size(), config.ao_strength, passes])
	print("  twin   median %.3f ms/chunk (spread %s)   quads %d" % [
		_median(twin_ms), _spread(twin_ms), twin_quads])
	if cpp == null:
		print("  c++    stub - no compiled mesher answered the probe")
	else:
		print("  c++    median %.3f ms/chunk (spread %s)   quads %d   borders %.3f ms/chunk" % [
			_median(cpp_ms), _spread(cpp_ms), cpp_quads, _median(border_ms)])
		print("  ratio  %.1fx the twin" % [
			_median(twin_ms) / maxf(_median(cpp_ms), 0.000001)])
		print("  parity %d differing components over %d chunks" % [
			parity_bad, parity_checked])
	quit(0)


## The twin's and the port's arrays, compared the way the self-test's gate
## compares them. Returns the number of differing components in this chunk.
func _parity(want: Array, got: Array, colours: bool) -> int:
	if want.is_empty() or got.is_empty():
		return 0 if want.is_empty() and got.is_empty() else 1
	var av: PackedVector3Array = want[Mesh.ARRAY_VERTEX]
	var bv: PackedVector3Array = got[Mesh.ARRAY_VERTEX]
	var an: PackedVector3Array = want[Mesh.ARRAY_NORMAL]
	var bn: PackedVector3Array = got[Mesh.ARRAY_NORMAL]
	var ac: PackedColorArray = want[Mesh.ARRAY_COLOR]
	var bc: PackedColorArray = got[Mesh.ARRAY_COLOR]
	var ai: PackedInt32Array = want[Mesh.ARRAY_INDEX]
	var bi: PackedInt32Array = got[Mesh.ARRAY_INDEX]
	if av.size() != bv.size() or ai.size() != bi.size():
		return 1
	var bad := 0
	for k in av.size():
		if av[k] != bv[k]:
			bad += 1
		if an[k] != bn[k]:
			bad += 1
		if colours and ac[k] != bc[k]:
			bad += 1
	for k in ai.size():
		if ai[k] != bi[k]:
			bad += 1
	return bad


## World._column_chunk_range, transcribed. It lives on `world.gd`, which is the
## other lane's file this month, and a bench is not a reason to reach into it.
func _column_chunk_range(gen: TerrainGenerator, config: WorldgenConfig,
		cx: int, cz: int) -> Array:
	var span := gen.column_surface_range(cx, cz)
	var top := Chunk.floor_div(int(floor(span.y)), Chunk.SIZE)
	var bottom := Chunk.floor_div(
		int(floor(span.x)) - config.voxel_depth_chunks * Chunk.SIZE, Chunk.SIZE)
	var max_cy := int(config.world_height_blocks / Chunk.SIZE) - 1
	return range(maxi(bottom, 0), mini(top, max_cy) + 1)


func _median(values: Array[float]) -> float:
	if values.is_empty():
		return 0.0
	var sorted: Array[float] = values.duplicate()
	sorted.sort()
	return sorted[sorted.size() / 2]


## Half the range, as a percentage of the median - the far probe's own idiom.
## Q4's rule: more passes if this exceeds 15%.
func _spread(values: Array[float]) -> String:
	if values.size() < 2:
		return "one pass"
	var sorted: Array[float] = values.duplicate()
	sorted.sort()
	var mid := _median(values)
	var half: float = (sorted[sorted.size() - 1] - sorted[0]) * 0.5
	return "+-%.1f%%" % (100.0 * half / maxf(mid, 0.000001))


func _arg(argv: PackedStringArray, name: String, fallback: String) -> String:
	var i := argv.find(name)
	if i < 0 or i + 1 >= argv.size():
		return fallback
	return argv[i + 1]
