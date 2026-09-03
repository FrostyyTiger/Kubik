extends SceneTree

## What a column costs, split three ways, off a seeded generator.
##
##     godot --headless --path . --script scripts/tools/tree_probe.gd -- --seed 42
##
## WHY THIS EXISTS, AND WHY IT IS NOT THE STREAM PROBE.
##
## Trees v3 deletes the tree stamper, and `column_job.gd:11` has claimed since
## world feel v1 that tree stamping is HALF the generation cost. That claim is
## the epic's Stage 7 gate, and nothing in the project reported the numerator:
## World prints `gen_usec + tree_usec` as one number per chunk, and the stream
## probe measures a walking player on a box that varies 9% between runs.
##
## So this builds a fixed rectangle of columns through the real `ColumnJob`,
## on the main thread, in a fixed order, and prints what the job itself
## recorded. The three splits are the job's own counters - not a
## reimplementation of the pipeline, which would drift from it by the second
## stage.
##
## THE CHUNK COUNTS ARE THE OTHER HALF. `cy_range` is what World would queue
## for a column - the terrain plus the sky reserve above it - and `built` is
## what the job actually generated, which stops at the highest solid block.
## Trees v3 removes the reserve, so the gap between those two numbers is
## exactly what the removal is worth, and it is printed here before anything
## is removed.
##
## Deterministic: same seed, same config, same numbers on any box. The wall
## clock is the only thing here that is not, and it is labelled as such.

const COLUMNS := 8


func _init() -> void:
	var args := _parse_args()
	var world_seed: int = args.get("seed", 42)

	var config := WorldgenConfig.load_or_default()
	config.apply_cli_overrides(OS.get_cmdline_user_args())
	print("seed          %d" % world_seed)
	print("config        %s" % config.hash_key())

	var gen := TerrainGenerator.new(world_seed, config)
	var ms := gen.build_heightmap()
	print("heightmap     %d ms, hash %s" % [ms, gen.heightmap.hash_key()])

	# THE SAMPLE MUST BE FOREST, AND SPAWN IS THE ONE PLACE IT IS NOT.
	#
	# The first version of this probe sampled the columns around the origin and
	# reported a mean canopy cover of 0.017, which is not a forest - it is the
	# 24 m spawn clearing and the ramp around it (`tree_spawn_clear_m`), which
	# exist precisely to keep trees off the place a player lands. Measuring the
	# cost of tree stamping in the one part of the world that has no trees is
	# a way to prove anything.
	#
	# So the rectangle is placed by SEARCHING for the densest patch, on the
	# same coarse walk the screenshot tour uses to pick its forest vantage.
	# It is deterministic - the same candidate lattice, the same decide(), the
	# same order - and it prints where it landed so the number can be read
	# against a place.
	var c0 := _densest_column(gen, config)
	print("sample at     column (%d, %d) = block (%d, %d)" % [
		c0.x, c0.y, c0.x * Chunk.SIZE, c0.y * Chunk.SIZE])

	# THE SAME EXTENT WORLD QUEUES, and after trees v3 Stage 7 that is the
	# terrain and nothing above it. Before the deletion this added the sky
	# reserve - `REF_MAX_TREE_BLOCKS` scaled by the tree knobs - so the
	# `reserved` column below measured what a canopy needed somewhere to land
	# in. It measures the terrain's own span now, and the two numbers this
	# probe printed at Stage 0 are what the removal was worth.
	var reserve := 0

	var gen_us := 0
	var tree_us := 0
	var mesh_us := 0
	var reserved_chunks := 0
	var built_chunks := 0
	var cover_sum := 0.0
	var n := 0

	for dz in COLUMNS:
		for dx in COLUMNS:
			var cx := c0.x + dx
			var cz := c0.y + dz
			var span := gen.column_surface_range(cx, cz)
			var lo := Chunk.floor_div(int(floor(span.x)) - 1, Chunk.SIZE)
			var hi := Chunk.floor_div(int(ceil(span.y)) + reserve, Chunk.SIZE)
			var cy_range := []
			for cy in range(lo, hi + 1):
				cy_range.append(cy)

			var job := ColumnJob.new()
			job.chunk_x = cx
			job.chunk_z = cz
			job.cy_range = cy_range
			job.generator = gen
			job.config = config
			job.world_seed = world_seed
			job.run()

			gen_us += job.gen_usec
			tree_us += job.tree_usec
			mesh_us += job.mesh_usec
			reserved_chunks += cy_range.size()
			built_chunks += job.built.size()
			# ASKED DIRECTLY SINCE LIGHT V1 STAGE 3. ColumnJob stopped running
			# the canopy scan when the canopy ink was removed, so the probe
			# calls the same function itself rather than reporting a zero.
			cover_sum += TreePlacement.cover_column(gen, cx, cz)
			n += 1

	var generation := maxi(gen_us + tree_us, 1)
	var total := maxi(generation + mesh_us, 1)
	print("columns       %d" % n)
	print("chunks        %.2f reserved per column, %.2f built (%.2f above the terrain)" % [
		float(reserved_chunks) / float(n), float(built_chunks) / float(n),
		float(reserved_chunks - built_chunks) / float(n)])
	print("canopy cover  %.4f mean" % (cover_sum / float(n)))
	print("column ms     %.3f gen, %.3f trees, %.3f mesh, %.3f total (per column, ganymede)" % [
		float(gen_us) / 1000.0 / float(n), float(tree_us) / 1000.0 / float(n),
		float(mesh_us) / 1000.0 / float(n), float(total) / 1000.0 / float(n)])
	# TWO SHARES, BECAUSE TWO DIFFERENT CLAIMS ARE MADE ABOUT THIS NUMBER.
	# `column_job.gd:11` says tree stamping is half the GENERATION cost, and
	# that is the figure World's own per-chunk line reports (`_gen_ms` is
	# `gen_usec + tree_usec` and nothing else). The share of the whole job is
	# the smaller number, because meshing dominates both of them.
	print("tree share    %.1f%% of generation, %.1f%% of the whole column job" % [
		100.0 * float(tree_us) / float(generation),
		100.0 * float(tree_us) / float(total)])
	quit(0)


## The densest patch of candidate lattice in the region, in chunk coordinates.
##
## A COARSE WALK, NOT A SURVEY. It asks decide() on one candidate cell in four
## on each axis over the whole region, which is a sixteenth of the lattice -
## enough to tell a forest from a meadow, and cheap enough to run before every
## measurement rather than being pasted in as a constant that stops being true
## the first time a mask is retuned.
func _densest_column(gen: TerrainGenerator, config: WorldgenConfig) -> Vector2i:
	var cell: int = config.tree_cell_blocks
	if cell <= 0:
		return Vector2i.ZERO
	var half := config.world_blocks_xz / 2
	var masks := TreePlacement.masks_for(gen)
	# Buckets of 16 chunks square, so a "patch" is a place rather than a cell.
	var patch := Chunk.SIZE * 16
	var counts := {}
	var stride := cell * 4
	var best := Vector2i.ZERO
	var best_n := -1
	for bz in range(-half, half, stride):
		for bx in range(-half, half, stride):
			if TreePlacement.decide(gen, Chunk.floor_div(bx, cell),
					Chunk.floor_div(bz, cell), masks).is_empty():
				continue
			var key := Vector2i(Chunk.floor_div(bx, patch),
				Chunk.floor_div(bz, patch))
			var c: int = int(counts.get(key, 0)) + 1
			counts[key] = c
			# Ties break on the FIRST patch reached in this walk's own order,
			# which is fixed - so the answer does not depend on Dictionary
			# iteration order, which is not.
			if c > best_n:
				best_n = c
				best = key
	return Vector2i(
		best.x * 16 + 8 - COLUMNS / 2,
		best.y * 16 + 8 - COLUMNS / 2)


func _parse_args() -> Dictionary:
	var out := {}
	var argv := OS.get_cmdline_user_args()
	for i in argv.size():
		if argv[i] == "--seed" and i + 1 < argv.size():
			out["seed"] = int(argv[i + 1])
	return out
