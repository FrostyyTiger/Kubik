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

	_print_altitude_percentiles(hm, config)
	_print_layer_slopes(config)
	_print_slope_histogram(hm, config)
	_print_zones(gen, hm, config)
	# Computed once and handed to both readouts. The object-scale line needs
	# the largest lake's WIDTH, which is a different question from its area and
	# cannot be answered from the summary _print_lakes prints.
	var lakes := Lakes.new()
	lakes.compute(hm, config)
	_print_lakes(lakes, hm)
	_print_object_scale(hm, lakes, config)
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
	var tree_lo := float(config.tree_trunk_min + config.tree_canopy_min + 1) * bs
	var tree_hi := float(config.tree_trunk_max + config.tree_canopy_max + 1) * bs

	var lake_w := _largest_lake_width_m(hm, lakes, config)
	print("scale         player %.2f m, tree %.1f-%.1f m, lake %.0f m across (%.0f m span), relief %.0f m" % [
		config.player_height_blocks * bs, tree_lo, tree_hi,
		lake_w, _largest_lake_span_m(hm, lakes, config),
		(st["max"] - st["min"]) * bs])

	var rows := [
		["player", config.player_height_blocks * bs, 1.75],
		["tree", (tree_lo + tree_hi) * 0.5, 30.0],
		["lake", lake_w, 400.0],
		["mountain", (st["max"] - st["min"]) * bs, 1400.0],
	]
	for row in rows:
		var game: float = row[1]
		var real: float = row[2]
		print("  vs real %-9s %8.2f m vs %7.1f m   1 : %.1f" % [
			row[0], game, real, real / maxf(game, 0.001)])


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
