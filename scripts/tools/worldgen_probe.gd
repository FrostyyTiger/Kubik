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
##
## Terrain v2 Stage 1 added the instruments the rest of that plan is judged on:
##
##   LAYER SLOPES     4 * amplitude / wavelength per noise layer. "Too hilly"
##                    stops being a feeling and becomes a number you can point
##                    at - and it is how the hills layer was convicted of being
##                    as steep as a mountain face at a 30 m wavelength.
##   SLOPE HISTOGRAM  what the summed layers actually produce, measured off the
##                    coarse heightmap rather than predicted from the config.
##                    The two lines that matter are the SHARE OF MAP UNDER 5
##                    and UNDER 10 DEGREES: a mean slope can improve while the
##                    world still contains no flat ground at all, and Stages 9
##                    and 11 exist precisely to move those two numbers.
##   ALTITUDE PCTILE  what altitude each percentile of the map sits at. Stage 7
##                    turns zone thresholds from absolute altitudes into shares
##                    of map area, and this table is what it resolves against.
##   OBJECT SCALE     every object measured against its real-world equivalent.
##                    Stage 8 is judged on this line: trees and lakes sit at
##                    1:4 and mountains were at 1:10.5, and the point of that
##                    stage is to bring the third into line with the first two.

func _init() -> void:
	var args := _parse_args()
	var world_seed: int = args.get("seed", 1)

	var config := WorldgenConfig.load_or_default()
	config.apply_cli_overrides(OS.get_cmdline_user_args())
	# The config is half of the determinism contract, so it gets printed next to
	# the seed rather than being left implicit.
	print("seed          %d" % world_seed)
	print("config        %s" % config.hash_key())

	# Memory around the two big allocations, because the world doubling to 3 km
	# quadrupled both and "it is only floats" stops being true somewhere.
	var mem_before := OS.get_static_memory_usage()
	var gen := TerrainGenerator.new(world_seed, config)
	var ms := gen.build_heightmap()
	var hm := gen.heightmap
	var mem_heightmap := OS.get_static_memory_usage()

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

	# Lakes FIRST, and handed straight back to the generator, because the game
	# does the same: since Stage 11 the detail layer is faded out near a water
	# line, and without this the probe would count trees and measure surfaces
	# the game never builds.
	var lakes := Lakes.new()
	lakes.compute(hm, config)
	gen.lakes = lakes

	_print_altitude_percentiles(hm, config)
	_print_layer_slopes(config)
	_print_slope_histogram(hm, config)
	_print_zones(gen, hm, config)
	print("memory        heightmap %.1f MB, + lakes %.1f MB (%.1f MB total)" % [
		float(mem_heightmap - mem_before) / 1048576.0,
		float(OS.get_static_memory_usage() - mem_heightmap) / 1048576.0,
		float(OS.get_static_memory_usage() - mem_before) / 1048576.0])
	_print_lakes(lakes, hm)
	_print_object_scale(hm, lakes, config)
	_print_trees(gen, hm, config)
	# The same call World makes, in the same place: after the heightmap and
	# after the lakes, because every criterion is a question about terrain that
	# already exists.
	var spawn_ms := Time.get_ticks_msec()
	gen.find_spawn()
	spawn_ms = Time.get_ticks_msec() - spawn_ms
	_print_spawn(gen, config, spawn_ms)
	_print_spawn_clearance(gen, config)
	if "--canopy" in OS.get_cmdline_user_args():
		_print_canopy(gen, config)
	quit()


## How clear of trees the spawn point actually is.
##
## THE PLACEMENT RULE SAYS trees ramp in from tree_spawn_clear_m; this measures
## whether they do. It is worth measuring rather than trusting because the two
## halves are decided by completely different code at completely different
## times - spawn is chosen from the finished heightmap, and the ramp is a term
## in a product evaluated per candidate - and nothing but this line would
## notice if they disagreed.
##
## Spawn is chosen to be flat, dry and open with a mountain in view. A forest
## closing over it undoes every one of those at once, and it is also the one
## place in the world a player stands still for their first minute.
func _print_spawn_clearance(gen: TerrainGenerator, config: WorldgenConfig) -> void:
	var spawn := gen.spawn_block
	var cell: int = config.tree_cell_blocks
	var reach := int(ceil(config.tree_spawn_ramp_m / config.block_size)) + cell
	var nearest := INF
	var within := 0
	var masks := TreePlacement.masks_for(gen)
	for cz in range(Chunk.floor_div(spawn.y - reach, cell),
			Chunk.floor_div(spawn.y + reach, cell) + 1):
		for cx in range(Chunk.floor_div(spawn.x - reach, cell),
				Chunk.floor_div(spawn.x + reach, cell) + 1):
			var found := TreePlacement.decide(gen, cx, cz, masks)
			if found.is_empty():
				continue
			var dx := float(int(found["bx"]) - spawn.x) * config.block_size
			var dz := float(int(found["bz"]) - spawn.y) * config.block_size
			var d := sqrt(dx * dx + dz * dz)
			nearest = minf(nearest, d)
			if d < config.tree_spawn_clear_m:
				within += 1
	print("spawn clear   nearest tree %.1f m, %d inside the %.0f m clearing%s" % [
		nearest if nearest < INF else -1.0, within, config.tree_spawn_clear_m,
		"" if within == 0 else "  <-- FAILED"])
##
## The sanity check this answers is "do all four zones actually occur" - it is
## entirely possible to tune a world where the treeline sits above the highest
## peak, and from inside the game that just looks like a green world rather
## than like a bug. Shares are unequal on purpose: lowlands should dominate and
## snow should be the caps of the few highest summits, not a third of the map.
func _print_zones(gen: TerrainGenerator, hm: Heightmap, config: WorldgenConfig) -> void:
	var counts := PackedInt32Array()
	counts.resize(TerrainGenerator.ZONE_COUNT)
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
	var shares := config.zone_shares()
	var worst := 0.0
	for i in TerrainGenerator.ZONE_COUNT:
		var got := counts[i] / n * 100.0
		var want := shares[i] * 100.0
		worst = maxf(worst, absf(got - want))
		print("zone %-9s %6.2f%%  (want %5.2f%%, %+5.2f)  %8d cells  above %.1f blk" % [
			TerrainGenerator.ZONE_NAMES[i], got, want, got - want, counts[i],
			config.min_altitude if i == 0 else gen.zone_thresholds[i - 1]])
	# The acceptance number for Stage 7, on its own line. The point of that
	# stage is that this stays small while everything else about the terrain
	# changes underneath it.
	print("zone error    worst %.2f percentage points off target" % worst)


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
func _print_lakes(lakes: Lakes, hm: Heightmap) -> void:
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
## How many trees the world grows, and of what.
##
## THE TOTAL WAS THE ONLY NUMBER UNTIL FOLIAGE V1, and one number cannot answer
## the question that plan is judged on. "35,000 trees" is equally true of a
## world that is one species everywhere and of one where larch replaces spruce
## as you climb - and the second is the whole point of having seven of them. A
## species that never occurs, or that occurs 40 times in three million
## candidates, is a tuning bug that a total hides completely.
func _print_trees(gen: TerrainGenerator, hm: Heightmap, config: WorldgenConfig) -> void:
	var started := Time.get_ticks_msec()
	var names := PackedStringArray()
	for row in TreeSpecies.gallery_rows(config):
		names.append(row["name"])
	var per_species := PackedInt32Array()
	per_species.resize(names.size())

	var trees := 0
	var step: int = config.tree_cell_blocks
	var lo := -int(config.world_blocks_xz / 2)
	var hi := int(config.world_blocks_xz / 2)
	var cell_lo := lo / step
	var cell_hi := hi / step
	# THE WORLD'S OWN RULE, asked directly. Restating the placement formula
	# here would be a second copy of it, and a second copy of a rule this long
	# would be wrong within a stage - which is the whole reason decide() is one
	# function that the stamper, the probe, the tour and the far-tree ring all
	# call.
	var masks := TreePlacement.masks_for(gen)
	for cz in range(cell_lo, cell_hi):
		for cx in range(cell_lo, cell_hi):
			var found := TreePlacement.decide(gen, cx, cz, masks)
			if found.is_empty():
				continue
			trees += 1
			var species: int = found["species"]
			if species >= 0 and species < per_species.size():
				per_species[species] += 1
	print("trees         %d in the whole world (%d ms)" % [
		trees, Time.get_ticks_msec() - started])
	for s in names.size():
		# Printed even at zero, and deliberately: a species missing from the
		# list reads as "not implemented yet", a species listed at 0 reads as
		# "implemented and never chosen", and those are different bugs.
		print("  %-11s %7d  %5.1f%%" % [names[s], per_species[s],
			100.0 * float(per_species[s]) / float(maxi(trees, 1))])
	_print_glades(gen, hm, config)
	_print_flora(gen, hm, config)


## How much of the forest band is CLEARING rather than trees.
##
## The glade mask is what stops a forest from being a solid block of canopy
## with no floor visible anywhere, and it is the one placement term whose
## effect is invisible in a tree count: glades move trees around rather than
## removing them, so the total barely shifts while the world changes
## completely. This is the number that says whether they are happening.
func _print_glades(gen: TerrainGenerator, _hm: Heightmap, _config: WorldgenConfig) -> void:
	var step := 8
	print("groves        %.1f%% of the forest band (want %.1f%%), every %d blocks" % [
		100.0 * TreePlacement.grove_share_measured(gen, step),
		100.0 * _config.grove_share, step])
	print("glades        %.1f%% of the forest band (want %.1f%%), every %d blocks" % [
		100.0 * TreePlacement.glade_share_measured(gen, step),
		100.0 * _config.glade_share, step])


## Ground cover, per zone.
##
## SAMPLED AND SCALED, AND THE LINE SAYS SO. Every block column in a 3 km world
## is nine million placement evaluations and this tool is run twice per stage;
## a stride of 16 is 35,000 of them and answers the question the number is
## actually asked - "does heath have shrubs on it" - to well inside the
## precision anyone reads it at. A scaled estimate labelled as one is honest.
## An exact count nobody waits for is not available.
func _print_flora(_gen: TerrainGenerator, _hm: Heightmap, _config: WorldgenConfig) -> void:
	if not ResourceLoader.exists("res://scripts/world/flora/flora_placement.gd"):
		print("flora         not yet - the decoration layer arrives in Stage 5")
		return
	var script := load("res://scripts/world/flora/flora_placement.gd")
	if not script.has_method("probe_counts"):
		print("flora         placement exists but reports nothing")
		return
	var stride := 16
	var report: Dictionary = script.probe_counts(_gen, _config, stride)
	print("flora         %d instances estimated, sampled every %d blocks and scaled" % [
		int(report.get("total", 0)), stride])
	for zone in TerrainGenerator.ZONE_NAMES:
		print("  %-13s %11d" % [zone, int(report.get(zone, 0))])
	print("flora models")
	for name in FloraModels.NAMES:
		var n: int = int(report.get("model_" + name, 0))
		if n > 0:
			print("  %-13s %11d" % [name, n])


# --- Terrain v2 Stage 1: the instruments ------------------------------------

## What altitude each percentile of the map sits at.
##
## Stage 7 turns the elevation zones from absolute altitudes into shares of map
## area, and this is the table it resolves against: "meadow is the 4th to 34th
## percentile" becomes a pair of altitudes by reading them off here.
##
## Printing it also makes a class of tuning mistake visible that min/max/mean
## hides completely. A world whose 50th and 90th percentiles are four blocks
## apart is a flat world with a few spikes on it, and its mean looks perfectly
## healthy.
func _print_altitude_percentiles(hm: Heightmap, config: WorldgenConfig) -> void:
	var sorted := hm.cells.duplicate()
	sorted.sort()
	var n := sorted.size()
	var line := PackedStringArray()
	for p in [0, 10, 25, 50, 75, 90, 99, 100]:
		var idx := clampi(int(float(p) / 100.0 * float(n - 1)), 0, n - 1)
		line.append("p%d %.0f" % [p, sorted[idx] * config.block_size])
	print("altitude pct  %s  (metres)" % String("  ").join(line))


## Characteristic slope of each noise layer, predicted from its own two knobs.
##
## The rise of one wave of amplitude A over its own quarter-wavelength is
## 4A / L, and atan() of that is the angle the eye reads off a hillside. This
## is a PREDICTION from the config rather than a measurement of the result -
## its value is that it attributes steepness to a layer, which the measured
## histogram below cannot do because by then they have all been summed.
##
## The detail layer is listed with the others but is not part of the coarse
## heightmap: it is added per block at voxel time, so it appears in what you
## walk on and never in the slope histogram.
func _print_layer_slopes(config: WorldgenConfig) -> void:
	var bs: float = config.block_size
	var layers := [
		["continent", config.continent_freq, config.continent_amp],
		["mountain", config.mountain_freq, config.mountain_amp],
		["hills", config.hills_freq, config.hills_amp],
		["detail", config.detail_freq, config.detail_amp],
	]
	for layer in layers:
		var freq: float = layer[1]
		if freq <= 0.0:
			continue
		var wavelength_m: float = 1.0 / freq * bs
		var amp_m: float = layer[2] * bs
		var slope := rad_to_deg(atan(4.0 * amp_m / wavelength_m))
		print("layer %-10s %7.1f m wavelength  %6.1f m amplitude  %5.1f deg" % [
			layer[0], wavelength_m, amp_m, slope])


## The slope the world ACTUALLY has, measured off the coarse heightmap.
##
## Central differences, so a cell's gradient is the drop across the two cells
## either side of it rather than to one neighbour - one-sided differences on
## noise are half measurement and half which direction you happened to look.
## Both the rise and the run are in blocks, so the ratio is dimensionless and
## the block size cancels out.
##
## THE TWO LINES THAT MATTER ARE THE LAST TWO. Stages 9 and 11 are judged on
## the share of the map under 5 and under 10 degrees, and not on the mean:
## fbm noise is a sum of smooth waves, so every point sits on some slope and
## the set of genuinely level ground has measure zero. Stretching a wavelength
## lowers the mean while leaving the world just as uniformly undulating, and
## the mean would report that as a success.
##
## Measured on the coarse map, so it is the shape of the LAND. Per-block detail
## roughness sits on top of everything here and is deliberately not included -
## it is the same 45 degrees everywhere and would drown the signal.
func _print_slope_histogram(hm: Heightmap, config: WorldgenConfig) -> void:
	var edges := [2.0, 5.0, 10.0, 15.0, 20.0, 30.0, 45.0, 60.0]
	var counts := PackedInt32Array()
	counts.resize(edges.size() + 1)
	var total := 0.0
	var samples := 0
	var inv_run := 1.0 / float(2 * hm.step)

	for j in range(1, hm.cols - 1):
		var row := j * hm.cols
		for i in range(1, hm.cols - 1):
			var gx: float = (hm.cells[i + 1 + row] - hm.cells[i - 1 + row]) * inv_run
			var gz: float = (hm.cells[i + (j + 1) * hm.cols]
				- hm.cells[i + (j - 1) * hm.cols]) * inv_run
			var deg := rad_to_deg(atan(sqrt(gx * gx + gz * gz)))
			total += deg
			samples += 1
			var bucket := edges.size()
			for e in edges.size():
				if deg < edges[e]:
					bucket = e
					break
			counts[bucket] += 1

	var n := float(maxi(samples, 1))
	var cumulative := 0
	for b in counts.size():
		var lo: String = "0" if b == 0 else "%.0f" % edges[b - 1]
		var hi: String = "inf" if b == edges.size() else "%.0f" % edges[b]
		cumulative += counts[b]
		print("slope %5s-%-5s %6.2f%%  (cum %6.2f%%)" % [
			lo, hi, counts[b] / n * 100.0, cumulative / n * 100.0])
	print("slope mean    %.2f deg over %d cells" % [total / n, samples])

	# Restated on their own line because they are the acceptance numbers for
	# two whole stages, and burying them in a histogram makes them easy to miss.
	var under5 := 0
	var under10 := 0
	for b in counts.size():
		if b < edges.size() and edges[b] <= 5.0:
			under5 += counts[b]
		if b < edges.size() and edges[b] <= 10.0:
			under10 += counts[b]
	print("flat ground   %.2f%% under 5 deg, %.2f%% under 10 deg" % [
		under5 / n * 100.0, under10 / n * 100.0])


## Every object in the world, measured against its real-world equivalent.
##
## Stage 8 is judged on this. The world is 1:4 against reality and the point of
## the readout is that ONE compression ratio should appear on every line: an
## object at 1:10 next to an object at 1:4 does not read as a small world, it
## reads as a broken one, because the eye judges size by comparison and there
## is nothing else in frame to compare against.
##
## The references are Swiss pre-Alpine: a 1.75 m adult, a 30 m spruce, a 400 m
## tarn and roughly 1400 m of relief from valley floor to summit.
func _print_object_scale(hm: Heightmap, lakes: Lakes, config: WorldgenConfig) -> void:
	var bs: float = config.block_size
	var st := hm.stats()

	# A tree's total height is its trunk plus the canopy standing above it. The
	# canopy starts one block below the trunk top and is canopy_radius + 3
	# layers tall, so the tip lands at trunk + canopy_radius + 1 blocks.
	# The shortest and tallest CANOPY tree. Three species are deliberately left
	# out, and which three is the whole point of the row: it exists to compare
	# a tree against a real tree, so it has to be measuring trees. The hero is
	# one per 300 x 300 m and would report the world as twice the size almost
	# none of it is; a krummholz is a wind-flattened shrub 1.5 m tall and
	# dragged the reported minimum down to a ratio of 1:5.7, which said the
	# scale had drifted when nothing had moved; a snag is a dead trunk with no
	# crown at all.
	var tree_lo := INF
	var tree_hi := 0.0
	for i in TreeSpecies.table(config).size():
		if i == TreeSpecies.HERO or i == TreeSpecies.KRUMMHOLZ \
				or i == TreeSpecies.SNAG:
			continue
		var row: Dictionary = TreeSpecies.table(config)[i]
		tree_lo = minf(tree_lo, float(row["height"].x) * bs)
		tree_hi = maxf(tree_hi, float(row["height"].y) * bs)

	var lake_w := _largest_lake_width_m(hm, lakes, config)
	print("scale         player %.2f m, tree %.1f-%.1f m, lake %.0f m across (%.0f m span), relief %.0f m" % [
		config.player_height_blocks * bs, tree_lo, tree_hi,
		lake_w, _largest_lake_span_m(hm, lakes, config),
		(st["max"] - st["min"]) * bs])

	# References read from the config rather than repeated here, so the numbers
	# the world is DERIVED from and the numbers it is JUDGED against cannot
	# drift apart - which is the entire failure this readout exists to catch.
	var rows := [
		["player", config.player_height_blocks * bs, WorldgenConfig.REAL_PLAYER_HEIGHT_M],
		["tree", (tree_lo + tree_hi) * 0.5,
			(WorldgenConfig.REAL_TREE_HEIGHT_M.x + WorldgenConfig.REAL_TREE_HEIGHT_M.y) * 0.5],
		["lake", lake_w, WorldgenConfig.REAL_LAKE_WIDTH_M],
		["mountain", (st["max"] - st["min"]) * bs, WorldgenConfig.REAL_MOUNTAIN_RELIEF_M],
	]
	for row in rows:
		var game: float = row[1]
		var real: float = row[2]
		print("  vs real %-9s %8.2f m vs %7.1f m   1 : %.1f" % [
			row[0], game, real, real / maxf(game, 0.001)])
	print("  world_scale is 1 : %.1f, target relief %.0f m" % [
		config.world_scale, config.target_relief_m()])


## How wide the largest lake is, in metres: the side of the square with the
## same area.
##
## THE OBVIOUS MEASURE IS THE WRONG ONE. The first version of this took the
## longest side of the lake's bounding box and reported 326 m, which would put
## lakes at 1:1.2 against a 400 m tarn - a lake at very nearly full scale in a
## quarter-scale world. It is not: the largest lake is dendritic, a thin thing
## with arms following three branches of a valley, and its bounding box is
## mostly dry land. Priority flood over noise terrain produces that shape
## routinely, because a basin is whatever the contour encloses.
##
## The equivalent-square side is the honest answer for any shape, and it puts
## lakes at 1:3.5 - beside trees at 1:3.5, which is the plan's finding that
## everything except mountains is already coherent. The bounding-box span is
## printed next to it rather than dropped, because "115 m of water spread over
## a 326 m valley" is a real fact about the lake and the two numbers together
## say more than either alone.
func _largest_lake_width_m(hm: Heightmap, lakes: Lakes, config: WorldgenConfig) -> float:
	if lakes.lakes.is_empty():
		return 0.0
	return sqrt(lakes.lakes[_largest_lake_index(lakes)]["area_m2"])


func _largest_lake_index(lakes: Lakes) -> int:
	var biggest := 0
	for i in lakes.lakes.size():
		if lakes.lakes[i]["cells"] > lakes.lakes[biggest]["cells"]:
			biggest = i
	return biggest


## Longest side of the largest lake's bounding box, in metres. Reported beside
## the equivalent-square width so the shape of the lake is visible - see above.
func _largest_lake_span_m(hm: Heightmap, lakes: Lakes, config: WorldgenConfig) -> float:
	if lakes.lakes.is_empty():
		return 0.0
	var biggest := _largest_lake_index(lakes)
	var min_i := hm.cols
	var max_i := -1
	var min_j := hm.cols
	var max_j := -1
	for j in hm.cols:
		var row := j * hm.cols
		for i in hm.cols:
			if lakes.lake_id[i + row] != biggest:
				continue
			min_i = mini(min_i, i)
			max_i = maxi(max_i, i)
			min_j = mini(min_j, j)
			max_j = maxi(max_j, j)
	if max_i < 0:
		return 0.0
	var cells := maxi(max_i - min_i, max_j - min_j) + 1
	return float(cells * hm.step) * config.block_size


## Whether this seed produced a spawn that meets every criterion, and if not,
## which one it could not meet.
##
## Reported rather than asserted, and the criteria are never loosened to make
## it pass. A seed with no valid spawn is a fact about the world generator that
## somebody has to know, and a criterion quietly relaxed until it passes is the
## same fact with the evidence removed.
func _print_spawn(gen: TerrainGenerator, config: WorldgenConfig, ms: int) -> void:
	var report := gen.spawn_report
	var b := gen.spawn_block
	if report.get("ok", false):
		print("spawn         OK at (%d, %d) = (%.0f m, %.0f m), altitude %.0f m, slope %.1f deg" % [
			b.x, b.y, float(b.x) * config.block_size, float(b.y) * config.block_size,
			report["altitude"] * config.block_size, report["slope"]])
	else:
		print("spawn         FAILED - no candidate met every criterion")
	print("              %d candidates in %d ms, rejected: %s" % [
		report.get("considered", 0), ms, report.get("failed", {})])
	# The danger field, sampled at the two places it is defined to be 0 and 1.
	print("danger        %.2f at spawn, %.2f at the far corner" % [
		gen.danger_at(float(b.x), float(b.y)),
		gen.danger_at(float(config.world_blocks_xz / 2), float(config.world_blocks_xz / 2))])


# --- Canopy closure ---------------------------------------------------------
#
# "NO SKY OVERHEAD", AS A NUMBER (world feel v1 Stage 6).
#
# T3 says envelop is height AND closure, and height is easy to check - it is in
# the species table. Closure is the half that can only be answered by standing
# somewhere and looking up, which on an overnight box with no GPU is exactly
# the thing that cannot be done by eye. So it is done by ray casting through
# the voxels a grove actually stamps.
#
# The method: find grove centres, stamp the columns around each into a scratch
# writer, then cast rays from eye height in a cone about vertical and count how
# many hit a leaf. That is the same question a player asks by tilting the
# camera up, and it produces a number that can be compared between stages and
# between grove kinds.

## How many columns either side of a grove's centre to stamp before casting.
##
## BIG ENOUGH THAT A RAY CANNOT LEAVE IT, which is the whole correctness of the
## measurement. A ray at 60 degrees from vertical that meets a canopy 40 blocks
## up has travelled 40 * tan(60) = 69 blocks sideways; stamped one chunk either
## side, it leaves the region long before then and is counted as sky. The first
## version did exactly that and reported 0.64 closure inside an old-growth
## grove whose crowns visibly touch.
##
## 5 chunks is 80 blocks each way, which covers the cone for anything the
## species table can grow.
const CANOPY_RADIUS_CHUNKS := 5
## Rays per sample point, and how far from vertical the cone opens.
const CANOPY_RAYS := 64
const CANOPY_CONE_DEG := 60.0
## Eye height, in blocks, above the surface.
const CANOPY_EYE_BLOCKS := 3.0
## How far a ray travels before it is counted as sky.
## A ray that reaches this far without hitting anything is sky. Kept just
## inside the stamped region so "no hit" always means "no hit in a region that
## was actually built".
const CANOPY_REACH_BLOCKS := 78.0
## Groves of each kind to sample, and how far out to look for them.
## Fewer samples than the plan's 20, because the region each one stamps grew
## 25-fold when the cone was made to fit inside it. Ten of each kind is still
## enough to separate three populations that differ by a factor of two.
const CANOPY_GROVES := 10
const CANOPY_SEARCH_M := 600.0


func _print_canopy(gen: TerrainGenerator, config: WorldgenConfig) -> void:
	var spawn := gen.spawn_block
	var bs: float = config.block_size
	var reach := int(CANOPY_SEARCH_M / bs)
	var step: int = maxi(int(1.0 / maxf(config.grove_freq, 0.0001)) / 2, Chunk.SIZE)

	var old_pts: Array = []
	var ord_pts: Array = []
	for bz in range(spawn.y - reach, spawn.y + reach, step):
		for bx in range(spawn.x - reach, spawn.x + reach, step):
			var surface := gen.surface_at(float(bx), float(bz))
			if gen.surface_zone_at(bx, bz, surface) != TerrainGenerator.ZONE_FOREST:
				continue
			if TreePlacement.is_old_growth(gen, bx, bz):
				if old_pts.size() < CANOPY_GROVES:
					old_pts.append(Vector2i(bx, bz))
			elif ord_pts.size() < CANOPY_GROVES:
				ord_pts.append(Vector2i(bx, bz))
			if old_pts.size() >= CANOPY_GROVES and ord_pts.size() >= CANOPY_GROVES:
				break

	# Between groves: forest zone, outside any grove at all.
	var open_pts: Array = []
	for bz in range(spawn.y - reach, spawn.y + reach, step):
		for bx in range(spawn.x - reach, spawn.x + reach, step):
			var surface := gen.surface_at(float(bx), float(bz))
			if gen.surface_zone_at(bx, bz, surface) != TerrainGenerator.ZONE_FOREST:
				continue
			var masks := TreePlacement.masks_for(gen)
			if masks.grove_cut != INF \
					and masks.grove.get_noise_2d(float(bx), float(bz)) >= masks.grove_cut:
				continue
			open_pts.append(Vector2i(bx, bz))
			if open_pts.size() >= CANOPY_GROVES:
				break

	print("canopy        %d rays in a %d degree cone from %.1f blocks up" % [
		CANOPY_RAYS, int(CANOPY_CONE_DEG), CANOPY_EYE_BLOCKS])
	var old_mean := _canopy_mean(gen, config, old_pts, "old growth")
	var ord_mean := _canopy_mean(gen, config, ord_pts, "grove")
	var open_mean := _canopy_mean(gen, config, open_pts, "between groves")
	print("canopy        old growth %.2f (want >= 0.85), grove %.2f (want >= 0.60), between %.2f (want <= 0.20)" % [
		old_mean, ord_mean, open_mean])
	var bad := 0
	if old_mean < 0.85:
		bad += 1
	if ord_mean < 0.60:
		bad += 1
	if open_mean > 0.20:
		bad += 1
	print("canopy        %d of 3 targets missed" % bad)


func _canopy_mean(gen: TerrainGenerator, config: WorldgenConfig,
		points: Array, label: String) -> float:
	if points.is_empty():
		print("canopy        %-14s no samples found" % label)
		return 0.0
	var total := 0.0
	for p in points:
		total += _closure_at(gen, config, p)
	var mean := total / float(points.size())
	print("canopy        %-14s %.3f over %d samples" % [label, mean, points.size()])
	return mean


## HOW MUCH OF THE SKY THE TREES OVER THIS POINT COVER, 0 to 1.
##
## TREES V3 STAGE 7 REPLACED THE MEASUREMENT, NOT THE QUESTION. This used to
## stamp every column within three chunks into a scratch volume and fire two
## hundred rays up through the leaf blocks, because closure was a property of
## the voxels. There are no leaf blocks: `TreeField` draws every tree from a
## model library and the volume is terrain alone.
##
## So it asks the scan instead - `TreePlacement.cover_column()`, which is the
## same crown-area sum the world itself shades its forest floor with
## (`ChunkMesher._under_canopy`). That is a better instrument as well as the
## only one left: it is what the GAME believes, rather than a second opinion
## that could drift from it.
##
## THE NUMBERS ARE NOT COMPARABLE WITH TREES V1's, and the targets below are
## trees v1's. A ray count through a lattice of leaf blocks and a clamped sum
## of crown discs are two different quantities that both run 0 to 1. Read the
## three lines against EACH OTHER - old growth should be closed, ordinary
## groves less so, open ground least - and not against the old thresholds.
func _closure_at(gen: TerrainGenerator, _config: WorldgenConfig,
		at: Vector2i) -> float:
	return TreePlacement.cover_column(gen,
		Chunk.floor_div(at.x, Chunk.SIZE), Chunk.floor_div(at.y, Chunk.SIZE))

func _ray_hits_leaves(chunks: Dictionary, from: Vector3, dir: Vector3) -> bool:
	var t := 0.0
	while t < CANOPY_REACH_BLOCKS:
		t += 0.5
		var p := from + dir * t
		var b := Vector3i(int(floor(p.x)), int(floor(p.y)), int(floor(p.z)))
		var chunk: Chunk = chunks.get(Chunk.world_to_chunk(b))
		if chunk == null:
			continue
		var l := Chunk.world_to_local(b)
		var id: int = chunk.voxels[Chunk.index(l.x, l.y, l.z)]
		if id != Block.AIR:
			return true
	return false
