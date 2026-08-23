extends SceneTree

## Offline worldgen inspector. Generates a world without opening a window and
## prints facts about it.
##
## This exists because "it looked right when I walked around" is not a test.
## Determinism is invisible from inside the game - two players in two different
## worlds see no error at all - so the guard has to be a number you can compare,
## produced by a command you can run twice.
##
##     godot --headless --path . --script scripts/tools/worldgen_probe.gd -- --seed 42
##
## Run it twice with the same seed and every line must match. Run it with the
## same seed on the other player's machine and every line must still match.
##
## Later stages extend it: zone distribution (Stage 5), lakes (Stage 8), trees
## (Stage 9). One tool that answers "what did this seed actually produce".

func _init() -> void:
	var args := _parse_args()
	var world_seed: int = args.get("seed", 1)

	var config := WorldgenConfig.load_or_default()
	# The config is half of the determinism contract, so it gets printed next to
	# the seed rather than being left implicit.
	print("seed          %d" % world_seed)
	print("config        %s" % config.hash_key())

	var gen := TerrainGenerator.new(world_seed, config)
	var ms := gen.build_heightmap()
	var hm := gen.heightmap

	print("heightmap     %dx%d cells, %d blocks per cell, %d ms" % [
		hm.cols, hm.cols, hm.step, ms])
	print("heightmap#    %s" % hm.hash_key())

	var st := hm.stats()
	# Sanity against the plan's targets: valley floors 30-50 blocks, peaks up
	# to ~240. A mean pinned at min_altitude means the clamp is doing the
	# shaping, which means the amplitudes are wrong.
	print("altitude      min %.1f  max %.1f  mean %.1f blocks" % [
		st["min"], st["max"], st["mean"]])
	print("              min %.1f  max %.1f  mean %.1f metres" % [
		st["min"] * config.block_size,
		st["max"] * config.block_size,
		st["mean"] * config.block_size])

	_print_zones(gen, hm, config)
	_print_lakes(gen, hm, config)
	_print_trees(gen, hm, config)
	quit()


## Share of the map in each elevation zone.
##
## The sanity check this answers is "do all four zones actually occur" - it is
## entirely possible to tune a world where the treeline sits above the highest
## peak, and from inside the game that just looks like a green world rather
## than like a bug. Shares are unequal on purpose: lowlands should dominate and
## snow should be the caps of the few highest summits, not a third of the map.
func _print_zones(gen: TerrainGenerator, hm: Heightmap, config: WorldgenConfig) -> void:
	var counts := [0, 0, 0, 0]
	# The real assignment, jitter and dither included, rather than the raw
	# thresholds - so this reports what the world is actually made of and not
	# what the config says it should be.
	for j in hm.cols:
		var bz := hm.cell_to_block(j)
		for i in hm.cols:
			var bx := hm.cell_to_block(i)
			var h := hm.cells[i + j * hm.cols]
			counts[gen.surface_zone_at(bx, bz, h)] += 1
	var n := float(hm.cols * hm.cols)
	for i in 4:
		print("zone %-9s %6.2f%%  (%d cells)" % [
			TerrainGenerator.ZONE_NAMES[i], counts[i] / n * 100.0, counts[i]])


## Reads `--seed N` from the user arguments, i.e. everything after a bare `--`.
func _parse_args() -> Dictionary:
	var out := {}
	var argv := OS.get_cmdline_user_args()
	var i := 0
	while i < argv.size():
		match argv[i]:
			"--seed":
				if i + 1 < argv.size():
					out["seed"] = argv[i + 1].to_int()
					i += 1
		i += 1
	return out


## Lakes are the loudest determinism test we have: they are large, they are
## obviously in a place, and two players seeing different ones would notice
## immediately. Count, total area and the biggest few must match run to run.
func _print_lakes(gen: TerrainGenerator, hm: Heightmap, config: WorldgenConfig) -> void:
	var lakes := Lakes.new()
	lakes.compute(hm, config)
	var total_area := 0.0
	var flooded := 0
	for lake in lakes.lakes:
		total_area += lake["area_m2"]
		flooded += lake["cells"]
	print("lakes         %d, %d cells flooded (%.1f%% of map), %.0f m2, %d ms" % [
		lakes.lake_count(), flooded,
		float(flooded) / float(hm.cols * hm.cols) * 100.0,
		total_area, lakes.elapsed_ms()])
	var deep := 0
	for lake in lakes.lakes:
		if lake["max_depth"] >= 2.0:
			deep += 1
	print("              %d of them at least 2 blocks (1 m) deep somewhere" % deep)

	var sorted := lakes.lakes.duplicate()
	sorted.sort_custom(func(a, b): return a["cells"] > b["cells"])
	for i in mini(5, sorted.size()):
		print("  lake %-2d      %6d cells  %9.0f m2  level %6.2f  depth mean %.2f max %.2f blocks" % [
			i, sorted[i]["cells"], sorted[i]["area_m2"], sorted[i]["level"],
			sorted[i]["mean_depth"], sorted[i]["max_depth"]])


## Every candidate cell in the world, counted. Slower than sampling but it is
## the number that has to match between two machines, so it is the number worth
## printing.
func _print_trees(gen: TerrainGenerator, hm: Heightmap, config: WorldgenConfig) -> void:
	var started := Time.get_ticks_msec()
	var trees := 0
	var step: int = config.tree_cell_blocks
	var lo := -int(config.world_blocks_xz / 2)
	var hi := int(config.world_blocks_xz / 2)
	var cell_lo := lo / step
	var cell_hi := hi / step
	for cz in range(cell_lo, cell_hi):
		for cx in range(cell_lo, cell_hi):
			var bx := cx * step
			var bz := cz * step
			var surface := gen.surface_at(float(bx), float(bz))
			var chance := gen.tree_probability_at(
				surface, gen.zone_jitter_at(float(bx), float(bz)))
			if chance <= 0.0:
				continue
			if WorldHash.hash01(cx, cz, gen.world_seed, TerrainGenerator.SALT_TREE) < chance:
				trees += 1
	print("trees         %d in the whole world (%d ms)" % [
		trees, Time.get_ticks_msec() - started])
