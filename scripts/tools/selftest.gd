extends Node

## Worldgen and mesher self-tests, offline.
##
##     godot --headless --path . scenes/selftest.tscn
##
## Everything here checks something that is either invisible from inside the
## game, or only visible once you already know what you are looking at.
## Exits non-zero on failure, so CI can run it.
##
##
## WHY THIS IS A SCENE AND NOT `--script`, AS IT WAS UNTIL TERRAIN V2 STAGE 3
##
## `--script` replaces the main loop, and Godot only creates AUTOLOADS for a
## real one. World names the Net autoload directly in its edit path, so under
## `--script` world.gd fails to compile with "Identifier not found: Net" - and
## the symptom is not that error but a later, much stranger one:
## `World.new()` reporting that GDScript has no function called new().
##
## That mattered the moment there was a test of the edit path to write. The
## alternatives were to reach around Net from worldgen, or to test a
## reimplementation of the ordering rather than the ordering itself. Running
## the suite in the same environment the game runs in is the honest fix, and it
## costs one scene file and a different command line.
##
## Engine.register_singleton() is NOT a way around this. It fills a different
## table from the one the GDScript compiler resolves autoload names against.

func _ready() -> void:
	# Called through a list, and each result type-checked, because a runtime
	# error inside a test does NOT stop the run - and worse, it does not report
	# one either. GDScript aborts the failing function and returns the DEFAULT
	# VALUE OF ITS DECLARED RETURN TYPE, so a test declared `-> int` that
	# crashes on its second line comes back as 0, which is this file's code for
	# "passed". The Stage 3 test did exactly that and the run printed
	# "all passed" twice before it was noticed.
	#
	# Hence the tests below are deliberately UNTYPED. An aborted untyped
	# function returns null, which is a value no test ever returns on purpose,
	# and that is the difference between a crash being visible and being
	# indistinguishable from success.
	var tests := {
		"winding": _test_winding,
		"ao cost": _measure_ao_cost,
		"tree borders": _test_tree_borders,
		"chunk determinism": _test_chunk_determinism,
		"edit during generation": _test_edit_during_generation,
		"facing": _test_facing,
		"day cycle": _test_day_cycle,
		"config contract": _test_config_contract,
		"sky reserve": _test_sky_reserve,
		"species borders": _test_species_borders,
		"flora determinism": _test_flora_determinism,
		"flora removal": _test_flora_removal,
		"flora winding": _test_flora_winding,
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
	print("")
	print("SELFTEST: %s" % ("all passed" if failures == 0 else "%d FAILED" % failures))
	get_tree().quit(1 if failures > 0 else 0)


## WINDING. Every triangle must satisfy
##
##     (p1 - p0) x (p2 - p0) == -normal
##
## which is the algebraic form of "clockwise seen from outside" - the face
## Godot draws, since back faces are culled. Getting it wrong does not make a
## face vanish, which you would notice: it turns the world inside out, so you
## see the far side of the terrain through the near side.
##
## The three shapes between them cover every face direction, both signs, merged
## runs, and the worst case for merging. This test earned its keep immediately:
## it caught a fresh Chunk defaulting has_air to false, which made the mesher
## treat a hand-built chunk as solid throughout and skip all its interior faces.
func _test_winding():
	var bad := 0
	var checked := 0
	var quads := 0

	# Both with AO off and with AO on. Baked AO splits merged quads wherever
	# the corner shading changes, so it produces a DIFFERENT set of rectangles
	# out of the same voxels - and the winding of every one of them still has
	# to be right. Running only the AO-off case would have left the splitting
	# path completely untested, which is the path that is new.
	# quads emitted per case, keyed "case@ao", so the AO-off and AO-on runs can
	# be compared at the end.
	var per_case := {}

	for ao in [0.0, 0.45]:
		for case in ["single", "slab", "checker", "ledge"]:
			var chunk := Chunk.new(Vector3i(0, 0, 0))
			for y in Chunk.SIZE:
				for z in Chunk.SIZE:
					for x in Chunk.SIZE:
						var solid := false
						match case:
							"single": solid = (x == 8 and y == 8 and z == 8)
							"slab": solid = y < 6
							"checker": solid = ((x + y + z) % 2 == 0)
							# A slab with a wall standing on one edge of it.
							# The top of the slab is one merged quad with AO
							# off; with AO on the strip against the wall is
							# darker than the open ground and has to split off.
							# Without a case like this the whole splitting path
							# would be untested, because the other three shapes
							# have nothing to merge in the first place.
							"ledge": solid = (y < 6) or (x < 3 and y < 10)
						if solid:
							chunk.set_voxel(x, y, z, Block.STONE)

			var cfg := WorldgenConfig.new()
			cfg.block_size = 1.0
			cfg.ao_strength = ao
			# Tinting off: this test is about winding and about how AO splits
			# quads, and a per-vertex colour would change none of that while
			# making a failure much harder to read.
			cfg.color_jitter_value = 0.0
			cfg.color_jitter_hue = 0.0
			cfg.slope_tint = 0.0
			cfg.aspect_tint = 0.0
			var arrays := ChunkMesher.build_arrays(
				chunk, func(_a, _b, _c): return false, cfg, 0)
			if arrays.is_empty():
				print("winding %s: EMPTY - nothing was meshed" % case)
				bad += 1
				continue
			var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var n: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			quads += v.size() / 4
			var i := 0
			while i < idx.size():
				var p0 := v[idx[i]]
				var p1 := v[idx[i + 1]]
				var p2 := v[idx[i + 2]]
				var cross := (p1 - p0).cross(p2 - p0)
				var want := -n[idx[i]]
				checked += 1
				if cross.length() < 0.0001 or cross.normalized().distance_to(want) > 0.001:
					bad += 1
					if bad <= 3:
						print("  BAD %s ao=%.2f: cross %s want %s" % [
							case, ao, cross.normalized(), want])
				i += 3
			per_case["%s@%.2f" % [case, ao]] = v.size() / 4
			print("  %-8s ao=%.2f %5d verts, %5d tris" % [
				case, ao, v.size(), idx.size() / 3])

	print("winding: %d triangles checked, %d wrong, %d quads emitted" % [checked, bad, quads])

	# The point of running the AO pass at all is that it emits a DIFFERENT set
	# of rectangles. If it emitted the same set everywhere, the AO-on half of
	# this test would be re-checking the AO-off half and proving nothing.
	var split_seen := false
	for case in ["single", "slab", "checker", "ledge"]:
		if per_case.get("%s@0.45" % case, 0) > per_case.get("%s@0.00" % case, 0):
			split_seen = true
	if not split_seen:
		print("  WARNING: AO never split a quad - the splitting path is untested")
		bad += 1
	else:
		print("  ledge: %d quads with AO off -> %d with AO on" % [
			per_case.get("ledge@0.00", 0), per_case.get("ledge@0.45", 0)])

	return 1 if bad > 0 else 0


## THE CHUNK BORDER TEST.
##
## A tree is rooted in one chunk and reaches into its neighbours, so every
## chunk it touches has to draw its own share of it. TreePlacement does that by
## iterating candidate cells over a region wider than the chunk by the widest
## crown in the species table. If that margin were too narrow, canopies would be sliced
## off at chunk boundaries - and only sometimes, depending on which chunks
## happened to be loaded, which is the worst kind of bug to be handed.
##
## The test: generate a chunk normally, then stamp every tree from a MUCH wider
## region into a second copy. Stamping is idempotent - trunk over trunk changes
## nothing, leaves are only drawn over air - so if the normal margin is wide
## enough the two chunks are identical byte for byte. If it is too narrow, the
## wide pass finds blocks the normal one missed.
func _test_tree_borders():
	var cfg := WorldgenConfig.new()
	var gen := TerrainGenerator.new(4242, cfg)
	gen.build_heightmap()

	var bad := 0
	var tested := 0
	var tree_blocks := 0

	for cx in range(-6, 7, 3):
		for cz in range(-6, 7, 3):
			for cy in range(4, 14):
				var narrow := Chunk.new(Vector3i(cx, cy, cz))
				gen.generate_into(narrow)

				var wide := Chunk.new(Vector3i(cx, cy, cz))
				gen.generate_into(wide)
				# SIX TIMES the margin the world actually uses, so a tree the
				# real scan missed lands in `wide` and shows up as a differing
				# voxel. Derived from the species table, not from a config
				# knob, for the same reason the real margin is: the widest
				# crown is a property of the table and grows when it does.
				var span := 6 * TreeSpecies.max_reach(cfg) + Chunk.SIZE
				var c0x := Chunk.floor_div(cx * Chunk.SIZE - span, cfg.tree_cell_blocks)
				var c1x := Chunk.floor_div(cx * Chunk.SIZE + span, cfg.tree_cell_blocks)
				var c0z := Chunk.floor_div(cz * Chunk.SIZE - span, cfg.tree_cell_blocks)
				var c1z := Chunk.floor_div(cz * Chunk.SIZE + span, cfg.tree_cell_blocks)
				var writer := TreeSpecies.ChunkWriter.new()
				writer.bind(wide)
				for tz in range(c0z, c1z + 1):
					for tx in range(c0x, c1x + 1):
						TreePlacement.stamp_cell(writer, gen, tx, tz)

				tested += 1
				for i in Chunk.VOLUME:
					if narrow.voxels[i] != wide.voxels[i]:
						bad += 1
						break
				for i in Chunk.VOLUME:
					if TreeSpecies.is_tree_block(narrow.voxels[i]):
						tree_blocks += 1

	print("tree borders: %d chunks, %d tree blocks, %d differed under a 6x margin" % [
		tested, tree_blocks, bad])
	if tree_blocks == 0:
		print("  WARNING: no tree blocks in the sample - this test proved nothing")
		return 1
	return 1 if bad > 0 else 0


## EVERY FLORA TRIANGLE MUST FACE OUTWARDS.
##
## The terrain has had a winding self-test since v1 and it earned its keep
## immediately. FloraModels shipped without one and every single face in it was
## backwards - all six directions - for three stages.
##
## WHAT MAKES THAT WORTH A TEST rather than a look is how it presented. The
## models were not inside out and nothing disappeared: because the blobs are
## solid and most of their faces are culled as interior anyway, the only
## symptom was thin horizontal gaps through rounded models. A boulder read as
## sedimentary layers, which looks almost deliberate. It survived being
## explained as the raggedness setting, as the coarser voxel scale, and as
## shadow acne, and was found by checking the arithmetic.
##
## The rule is the same one ChunkMesher's test enforces:
##
##     (p1 - p0) x (p2 - p0) == -normal
##
## which is the algebraic form of "clockwise seen from outside" - the face
## Godot draws, since back faces are culled.
func _test_flora_winding():
	var bad := 0
	var checked := 0
	for model in FloraModels.COUNT:
		var mesh := FloraModels.mesh_for(model, 0.5)
		if mesh == null:
			continue
		var arrays := mesh.surface_get_arrays(0)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var wrong := 0
		var i := 0
		while i + 2 < indices.size():
			var p0 := verts[indices[i]]
			var p1 := verts[indices[i + 1]]
			var p2 := verts[indices[i + 2]]
			var n := normals[indices[i]]
			var cross := (p1 - p0).cross(p2 - p0)
			# Direction only - the magnitude is twice the triangle's area.
			if cross.length() > 0.0 and cross.normalized().dot(-n) < 0.99:
				wrong += 1
			checked += 1
			i += 3
		if wrong > 0:
			print("  %s: %d of %d triangles wound the wrong way" % [
				FloraModels.NAMES[model], wrong, indices.size() / 3])
			bad += 1
	print("flora winding: %d triangles across %d models, %d models wrong" % [
		checked, FloraModels.COUNT, bad])
	if checked == 0:
		print("  WARNING: no triangles in the sample - this test proved nothing")
		return 1
	return bad


## GATHERING ONE PLANT MUST TAKE EXACTLY ONE PLANT.
##
## The removal path is a set of identities that placement skips, and the whole
## thing rests on an identity being a pure function of position. If it were not
## - if it depended on the order instances were generated in, say - then
## removing one would renumber its neighbours, and gathering a single flower
## would silently delete or duplicate others in the same column. Nobody would
## see an error; they would see a meadow that changes when you pick something.
##
## So the test is exact rather than approximate: rebuild the column with one id
## removed, and require the result to be the SAME BUFFER with one instance's
## worth of floats missing and every other float identical. That is a much
## stronger statement than "one fewer instance", and it is the statement the
## RPC will need to be able to rely on.
func _test_flora_removal():
	var cfg := WorldgenConfig.new()
	cfg.world_blocks_xz = 512
	var gen := TerrainGenerator.new(4242, cfg)
	gen.build_heightmap()
	var lakes := Lakes.new()
	lakes.compute(gen.heightmap, cfg)
	gen.lakes = lakes
	gen.find_spawn()

	# A column with something in it.
	var col := Vector2i.ZERO
	var before: Array = []
	for cz in range(-3, 4):
		for cx in range(-3, 4):
			var got := FloraPlacement.column(gen, cfg, cx, cz)
			if got.size() > before.size():
				before = got
				col = Vector2i(cx, cz)
	if before.is_empty():
		print("  no flora anywhere in the sample - this test proved nothing")
		return 1

	# Take the middle one, so the check covers instances on both sides of it.
	var victim: Dictionary = before[before.size() / 2]
	var bx := int(round(float(victim["pos"].x) / cfg.block_size))
	var bz := int(round(float(victim["pos"].z) / cfg.block_size))
	var id := FloraPlacement.identity(int(victim["model"]), bx, bz)

	var bad := 0
	# The identity must round-trip, or _flora_dirty() would resubmit the wrong
	# column and the plant would stay on screen until the player walked away.
	var back := FloraPlacement.block_of(id)
	if back != Vector2i(bx, bz):
		print("  identity did not round-trip: (%d, %d) -> %s" % [bx, bz, back])
		bad += 1
	if FloraPlacement.column_of(id) != col:
		print("  identity names column %s, not %s" % [
			FloraPlacement.column_of(id), col])
		bad += 1
	if FloraPlacement.model_of(id) != int(victim["model"]):
		print("  identity lost its model id")
		bad += 1

	var after := FloraPlacement.column(gen, cfg, col.x, col.y, {id: true})
	if after.size() != before.size() - 1:
		print("  removing one instance left %d of %d" % [
			after.size(), before.size()])
		bad += 1

	# Every survivor, unchanged and in the same order.
	var j := 0
	for i in before.size():
		var a: Dictionary = before[i]
		if int(a["model"]) == int(victim["model"]) and a["pos"] == victim["pos"]:
			continue
		if j >= after.size():
			bad += 1
			break
		var b: Dictionary = after[j]
		if a["pos"] != b["pos"] or int(a["model"]) != int(b["model"]) \
				or not is_equal_approx(float(a["yaw"]), float(b["yaw"])):
			print("  survivor %d changed when its neighbour was removed" % j)
			bad += 1
			break
		j += 1

	print("flora removal: column %s, %d instances -> %d, %d wrong" % [
		col, before.size(), after.size(), bad])
	return bad


## A COLUMN OF GROUND COVER MUST COME BACK THE SAME EVERY TIME IT IS BUILT.
##
## This is the determinism contract at the flora scale, and it is worth its own
## test rather than being assumed from the terrain's, because the decoration
## layer is rebuilt far more often than a chunk is. A column is rebuilt when
## the player walks away and returns, when a block in it is edited, and in
## Stage 9 when an instance is gathered - and if any of those came back with
## the plants in a different ORDER, the buffers would differ, every plant in
## the column would jump to a different neighbour's position, and the only
## symptom would be a meadow that reshuffles itself when you dig a hole in it.
##
## Comparing the packed BUFFERS rather than the instance list is deliberate:
## the buffer is what actually reaches the renderer, and it is where an
## ordering difference or a float that took a different path would show up.
func _test_flora_determinism():
	# A small world, because this test needs a heightmap and does not care how
	# big it is. At the default 6000 blocks that is seventeen seconds of
	# heightmap for a question about sixteen columns.
	var cfg := WorldgenConfig.new()
	cfg.world_blocks_xz = 512
	var gen := TerrainGenerator.new(31337, cfg)
	gen.build_heightmap()
	var lakes := Lakes.new()
	lakes.compute(gen.heightmap, cfg)
	gen.lakes = lakes
	gen.find_spawn()

	var bad := 0
	var total := 0
	var columns := 0
	for cz in range(-2, 3):
		for cx in range(-2, 3):
			var a := _flora_buffers(gen, cfg, cx, cz)
			var b := _flora_buffers(gen, cfg, cx, cz)
			columns += 1
			if a.keys().size() != b.keys().size():
				bad += 1
				continue
			for model in a:
				if not b.has(model):
					bad += 1
					break
				var pa: PackedFloat32Array = a[model]
				var pb: PackedFloat32Array = b[model]
				total += pa.size() / FloraJob.FLOATS_PER_INSTANCE
				if pa != pb:
					print("  column (%d, %d) model %d differed" % [cx, cz, model])
					bad += 1

	print("flora determinism: %d columns, %d instances, %d differed" % [
		columns, total, bad])
	if total == 0:
		print("  WARNING: no flora in the sample - this test proved nothing")
		return 1
	return bad


func _flora_buffers(gen: TerrainGenerator, cfg: WorldgenConfig,
		cx: int, cz: int) -> Dictionary:
	var job := FloraJob.new()
	job.column = Vector2i(cx, cz)
	job.generator = gen
	job.config = cfg
	job.run()
	return job.buffers


## EVERY SPECIES MUST SURVIVE BEING CUT UP BY CHUNK BOUNDARIES.
##
## _test_tree_borders proves the world's candidate scan is wide enough, but it
## can only prove it for the species the world actually grows - which until
## Stage 4 is spruce and nothing else. Six shapes would therefore reach Stage 4
## having never been drawn across a boundary at all, and the ones most likely
## to break are exactly the ones that write furthest from their root: a hero
## with a 2 x 2 trunk and a crown of 8, a krummholz whose lean moves its whole
## body one block sideways.
##
## THE TEST IS THE DEFINITION OF CORRECT, stated directly. Draw the tree once
## into an unbounded buffer - the whole tree, clipped by nothing. Then draw it
## again into each of the chunks around it, through the writer the world uses.
## The union of the clipped copies must equal the unbounded one, block for
## block, with nothing missing and nothing extra. That is precisely what "every
## chunk draws its own share" means, so there is no gap between what is checked
## and what is required.
func _test_species_borders():
	var cfg := WorldgenConfig.new()
	var bad := 0
	var checked := 0

	for species in TreeSpecies.table(cfg).size():
		# Rooted deliberately AWKWARDLY: one block inside a chunk corner, so
		# the tree straddles boundaries on both axes at once and the biggest
		# crowns reach three chunks out.
		var root := Vector3i(15, 40, 15)
		var params := TreeSpecies.params_for(species, 3, 5, 777, cfg)

		var whole := {}   # Vector3i -> block id
		var loose := LooseWriter.new()
		loose.blocks = whole
		TreeSpecies.draw(loose, species, root.x, root.y, root.z, params, cfg)
		if whole.is_empty():
			print("  %s drew nothing" % TreeSpecies.table(cfg)[species]["name"])
			bad += 1
			continue

		# Every chunk the tree could possibly have reached, and two beyond.
		var pieces := {}
		var reach := TreeSpecies.max_reach(cfg) + 2
		var lo := Chunk.world_to_chunk(root - Vector3i(reach, 2, reach))
		var hi := Chunk.world_to_chunk(
			root + Vector3i(reach, TreeSpecies.max_height(cfg) + 2, reach))
		for cy in range(lo.y, hi.y + 1):
			for cz in range(lo.z, hi.z + 1):
				for cx in range(lo.x, hi.x + 1):
					var chunk := Chunk.new(Vector3i(cx, cy, cz))
					var writer := TreeSpecies.ChunkWriter.new()
					writer.bind(chunk)
					TreeSpecies.draw(writer, species, root.x, root.y, root.z,
						params, cfg)
					var origin := chunk.origin()
					for i in Chunk.VOLUME:
						if chunk.voxels[i] == Block.AIR:
							continue
						var ly := i / Chunk.SIZE_SQ
						var rem := i % Chunk.SIZE_SQ
						pieces[origin + Vector3i(
							rem % Chunk.SIZE, ly, rem / Chunk.SIZE)] = chunk.voxels[i]

		var missing := 0
		var extra := 0
		for pos in whole:
			if not pieces.has(pos):
				missing += 1
		for pos in pieces:
			if not whole.has(pos):
				extra += 1
		checked += 1
		if missing > 0 or extra > 0:
			print("  %s: %d blocks missing, %d extra, of %d" % [
				TreeSpecies.table(cfg)[species]["name"], missing, extra,
				whole.size()])
			bad += 1

	print("species borders: %d species stamped across chunk boundaries, %d wrong" % [
		checked, bad])
	return bad


## A writer that clips to nothing, for the reference copy above.
class LooseWriter extends RefCounted:
	var blocks := {}

	func set_block(bx: int, by: int, bz: int, id: int, only_air: bool) -> void:
		var pos := Vector3i(bx, by, bz)
		if only_air and blocks.has(pos):
			return
		blocks[pos] = id


## THE SKY RESERVE MUST COVER THE TALLEST TREE THE TABLE CAN GROW.
##
## World builds only the chunks a column's terrain passes through, plus
## max_tree_height() of empty sky above it. If a species is ever added that is
## taller than WorldgenConfig's REF_MAX_TREE_BLOCKS, the world stops queueing
## the chunk that species' crown needs - and the symptom is not an error. It is
## a tree with a flat top, sometimes, in some columns, depending on where the
## terrain happened to sit relative to a chunk ceiling.
##
## The two numbers live apart on purpose: WorldgenConfig sizing itself from
## TreeSpecies, which takes a WorldgenConfig in every signature, would make the
## two mutually dependent for the sake of an integer. This is the cheaper half
## of that trade - the coupling is a test rather than an import, and the test
## says exactly what breaks.
func _test_sky_reserve():
	var bad := 0
	for scale in [0.5, 1.0, 1.7, 2.5]:
		var cfg := WorldgenConfig.new()
		cfg.tree_size_scale = scale
		var needed := TreeSpecies.max_height(cfg)
		var reserved := int(ceil(
			WorldgenConfig.REF_MAX_TREE_BLOCKS * scale
			+ WorldgenConfig.TREE_RESERVE_MARGIN))
		if needed > reserved:
			print("  scale %.2f: table needs %d blocks, config reserves %d" % [
				scale, needed, reserved])
			bad += 1
	print("sky reserve: 4 scales checked, %d short" % bad)
	return bad


## Same seed, same config, same chunks - byte for byte. This is the guarantee
## the whole terrain-is-never-sent contract rests on.
func _test_chunk_determinism():
	var cfg := WorldgenConfig.new()
	var hashes := []
	for run in 2:
		var gen := TerrainGenerator.new(99, cfg)
		gen.build_heightmap()
		var blob := PackedByteArray()
		for cx in range(-2, 3):
			for cz in range(-2, 3):
				for cy in range(4, 12):
					var c := Chunk.new(Vector3i(cx, cy, cz))
					gen.generate_into(c)
					blob.append_array(c.voxels)
		hashes.append("%08x" % (hash(blob) & 0xFFFFFFFF))
	var ok: bool = hashes[0] == hashes[1]
	print("chunk determinism: %s vs %s -> %s" % [
		hashes[0], hashes[1], "same" if ok else "DIFFERENT"])
	return 0 if ok else 1


## A full day is eight minutes of real time, so nobody is going to watch a
## headless run through one. The colour and sun-angle work is pure functions of
## the sun's elevation precisely so it can be stepped through here instead.
##
## What would actually break: a NaN from normalising a zero vector, the sun
## never rising, or fog and sky disagreeing at the horizon, which reads as a
## grey wall standing in front of the view.
func _test_day_cycle():
	var bad := 0
	var highest := -2.0
	var lowest := 2.0
	var crossings := 0
	# The last NON-ZERO sign. At sunrise the elevation is exactly zero, and
	# signf(0.0) is 0, so comparing raw signs counts one sunrise as two
	# crossings - a test artefact, not a sun that rises twice.
	var previous_sign := signf(SkyCycle.sun_position(0.0).y)

	for step in 1441:
		var t := float(step) / 1440.0
		var pos := SkyCycle.sun_position(t)
		if is_nan(pos.x) or is_nan(pos.y) or is_nan(pos.z):
			bad += 1
			continue
		if absf(pos.length() - 1.0) > 0.001:
			bad += 1
		var elevation := pos.y
		highest = maxf(highest, elevation)
		lowest = minf(lowest, elevation)
		var current_sign := signf(elevation)
		if current_sign != 0.0:
			if current_sign != previous_sign:
				crossings += 1
			previous_sign = current_sign

		var sun := SkyCycle.sun_color(elevation)
		var fog := SkyCycle.fog_color(elevation)
		if is_nan(sun.r) or is_nan(fog.r):
			bad += 1
		if SkyCycle.sun_energy(elevation) <= 0.0:
			bad += 1  # a pitch black night is a black screen, not atmosphere

		# The basis the sun light actually uses must stay well formed all the way
		# round, including straight overhead.
		var basis := Basis.looking_at(-pos, Vector3.UP)
		if is_nan(basis.x.x) or absf(basis.determinant() - 1.0) > 0.01:
			bad += 1

	if crossings != 2:
		print("  the sun crossed the horizon %d times in a day, expected 2" % crossings)
		bad += 1

	print("day cycle: 1441 steps, elevation %.3f to %.3f, %d horizon crossings, %d bad" % [
		lowest, highest, crossings, bad])
	return 1 if bad > 0 else 0


## THE JOIN HANDSHAKE'S HALF OF THE DETERMINISM CONTRACT.
##
## Terrain is never sent, only a seed - which is only true if both machines
## also agree on every tuning number. The config therefore travels with the
## seed, and this checks the three things that has to mean:
##
##   1. two different configs must not fingerprint the same, or the guard is
##      blind to exactly what it exists to catch;
##   2. a config must survive to_dict/from_dict unchanged, because that is the
##      form it crosses the network in;
##   3. and a config that made the round trip must generate the SAME WORLD,
##      byte for byte, as the one it was copied from. That is the property a
##      joining client depends on and the other two only imply.
func _test_config_contract():
	var bad := 0

	var host_config := WorldgenConfig.new()
	host_config.mountain_amp += 37.0
	# A zone share rather than the retired forest_max, and it is worth being a
	# SHARE specifically: since Stage 7 the zone boundaries are percentiles
	# resolved at generation time, so this checks that a value which only takes
	# effect through a later computation still crosses the wire intact.
	host_config.share_forest = 0.31
	# A flora shape knob, because foliage v1 added twenty of them and every one
	# is part of the join handshake: two machines that disagreed about the
	# grove share would grow forests in different places while the handshake
	# reported a match, which is the exact failure this test exists to catch.
	host_config.grove_share = 0.21
	host_config.tree_density_scale = 1.4

	var defaults := WorldgenConfig.new()
	if host_config.hash_key() == defaults.hash_key():
		print("  a retuned config fingerprints the same as the defaults")
		bad += 1

	# What a joining client does with what arrives on the wire.
	var client_config := WorldgenConfig.new()
	client_config.from_dict(host_config.to_dict())
	if client_config.hash_key() != host_config.hash_key():
		print("  config did not survive to_dict/from_dict")
		bad += 1

	var host_world := _heightmap_hash(7777, host_config)
	var client_world := _heightmap_hash(7777, client_config)
	var default_world := _heightmap_hash(7777, defaults)

	if host_world != client_world:
		print("  client generated a DIFFERENT world from the host's config")
		bad += 1
	if host_world == default_world:
		print("  the config made no difference to the world at all")
		bad += 1

	print("config contract: host %s, client %s, untuned %s -> %s" % [
		host_world, client_world, default_world,
		"ok" if bad == 0 else "FAILED"])
	return 1 if bad > 0 else 0


func _heightmap_hash(world_seed: int, cfg: WorldgenConfig) -> String:
	var gen := TerrainGenerator.new(world_seed, cfg)
	gen.build_heightmap()
	return gen.heightmap.hash_key()


## WHAT BAKED AO COSTS, on real terrain rather than on a test shape.
##
## AO splits merged quads wherever the corner shading changes, so it buys its
## look with vertices and with meshing time. Both numbers belong in STATUS.md
## and neither may be estimated (plan hard rule 6), so they are measured here -
## same chunks, same order, once with AO off and once with it on.
##
## Not a test: it prints and always passes. There is no threshold to assert
## against that would not be a number invented on the spot.
func _measure_ao_cost():
	var cfg := WorldgenConfig.new()
	var gen := TerrainGenerator.new(31337, cfg)
	gen.build_heightmap()

	# Chunk columns around the origin, at the altitudes terrain actually passes
	# through, so this measures surface chunks and not empty sky.
	var positions: Array[Vector3i] = []
	for cx in range(-2, 3):
		for cz in range(-2, 3):
			var span := gen.column_surface_range(cx, cz)
			var cy := Chunk.floor_div(int(span.x), Chunk.SIZE)
			for k in 3:
				positions.append(Vector3i(cx, cy + k, cz))

	var chunks: Array[Chunk] = []
	for pos in positions:
		var c := Chunk.new(pos)
		gen.generate_into(c)
		chunks.append(c)

	var solid := func(wx: int, wy: int, wz: int) -> bool:
		return gen.is_solid_at(wx, wy, wz)

	var results := []
	for ao in [0.0, WorldgenConfig.new().ao_strength]:
		cfg.ao_strength = ao
		var quads := 0
		var started := Time.get_ticks_usec()
		for c in chunks:
			var arrays := ChunkMesher.build_arrays(c, solid, cfg, 31337)
			if not arrays.is_empty():
				quads += (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 4
		results.append({
			"ao": ao,
			"quads": quads,
			"ms": float(Time.get_ticks_usec() - started) / 1000.0,
		})

	var off: Dictionary = results[0]
	var on: Dictionary = results[1]
	print("ao cost: %d chunks, %d -> %d quads (%+.1f%%), %.1f -> %.1f ms (%+.1f%%)" % [
		chunks.size(), off["quads"], on["quads"],
		(float(on["quads"]) / maxf(float(off["quads"]), 1.0) - 1.0) * 100.0,
		off["ms"], on["ms"],
		(on["ms"] / maxf(off["ms"], 0.001) - 1.0) * 100.0])
	return 0


## THE STAGE 3 HAZARD, MADE INTO A TEST.
##
## Generation moved to worker threads, so between the moment a chunk is
## submitted and the moment it comes back there is a window in which the chunk
## DOES NOT EXIST. An edit arriving in that window has no voxels to be written
## into. v1's STATUS.md flagged this as the reason generation had not been
## threaded yet, and it is the kind of bug that would show up as "sometimes the
## block I broke comes back" - intermittent, timing-dependent, and dependent on
## how busy the worker pool happened to be, so effectively unreproducible.
##
## Three things have to hold, and all three are checked here:
##
##   1. the host ACCEPTS an edit into a chunk that is still generating. If
##      validation only accepted loaded chunks, the edit would be dropped on
##      the floor with no error anywhere.
##   2. the edit SURVIVES generation. The worker overwrites every voxel in the
##      chunk, so an edit applied before it finished would be wiped; it has to
##      be replayed after.
##   3. an edit into a chunk that is neither loaded nor pending is still
##      REFUSED. Otherwise "accept pending chunks" would have quietly become
##      "accept everything", and a client could edit the far side of the world.
func _test_edit_during_generation():
	var bad := 0

	# A deliberately tiny world: this test is about ordering, not about scale,
	# and a 3 km heightmap would cost seconds to prove a property that does not
	# depend on it.
	var cfg := WorldgenConfig.new()
	cfg.world_blocks_xz = 400
	cfg.voxel_radius_chunks = 2

	var world := World.new()
	world.setup(1234, cfg)

	# A block that is solid in the unedited world, so changing it is visible.
	var surface := int(floor(world.generator.surface_at(0.0, 0.0)))
	var block_pos := Vector3i(0, surface, 0)
	var cpos := Chunk.world_to_chunk(block_pos)

	if world.has_chunk(cpos):
		print("  the chunk existed before generation was submitted")
		bad += 1

	# 3. Nothing is loaded and nothing is pending yet, so this must be refused.
	if world._validate_edit(1, block_pos, Block.SNOW):
		print("  an edit was accepted into a chunk that is neither loaded nor pending")
		bad += 1

	# Now put exactly that chunk out at the worker pool and leave it there.
	world._submit_generation(cpos)

	# 1. Still no voxels, but the chunk is coming, so the host must accept.
	if not world._validate_edit(1, block_pos, Block.SNOW):
		print("  an edit was REFUSED into a chunk that is still generating")
		bad += 1

	# The client path, which is the one that needs no network to exercise:
	# record the edit, and discover there is nothing to apply it to yet.
	world._cl_apply_block(block_pos, Block.SNOW)
	if world.get_block(block_pos) != Block.AIR:
		print("  a chunk with no voxels answered get_block with something")
		bad += 1

	# Let the job finish and be collected, exactly as _process would.
	# With a delay, because the spin without one is over in microseconds and
	# the worker has not necessarily even been scheduled by then - which looks
	# exactly like the chunk never arriving.
	var spins := 0
	while not world.has_chunk(cpos) and spins < 5000:
		world._collect_finished(Time.get_ticks_msec())
		OS.delay_msec(1)
		spins += 1
	if not world.has_chunk(cpos):
		print("  the chunk never arrived")
		bad += 1

	# 2. The worker wrote every voxel in the chunk. The edit has to have been
	# replayed over the top of it.
	var got := world.get_block(block_pos)
	if got != Block.SNOW:
		print("  the edit did not survive generation: got %s, wanted snow" % Block.name_of(got))
		bad += 1

	world._drain_jobs()
	if world._far_field != null:
		world._far_field.drain()
	world.free()

	print("edit during generation: %d checks failed" % bad)
	return 1 if bad > 0 else 0


## THE CHARACTER FACES WHERE IT IS GOING, and not the other way round.
##
## Player._face_movement() turns the body toward its travel direction. For the
## whole of terrain v1 it computed atan2(wish.x, wish.z), which is the yaw that
## points local +Z along travel - and Godot's forward is -Z, so the character
## was 180 degrees out in every direction, every frame.
##
## Nobody saw it because Body is a CapsuleMesh and a capsule is rotationally
## symmetric. It would have appeared the moment a character with a front and a
## back arrived, and it would have looked like a bug in the new character.
##
## The assertion is against Vector3.FORWARD rather than against a hand-written
## (0, 0, -1), because FORWARD is the engine's own definition of the thing this
## has to agree with. If Godot ever changed its convention this test would
## change with it, which is the behaviour you want from a test of a convention.
func _test_facing():
	var bad := 0
	var checked := 0
	# Eight compass directions plus two off-axis ones, so a sign error on one
	# axis alone cannot hide.
	for degrees in [0, 45, 90, 135, 180, 225, 270, 315, 23, 197]:
		var a := deg_to_rad(float(degrees))
		var wish := Vector3(sin(a), 0.0, cos(a))
		# The expression from Player._face_movement().
		var yaw := atan2(-wish.x, -wish.z)
		var facing := (Basis(Vector3.UP, yaw) * Vector3.FORWARD).normalized()
		checked += 1
		if facing.distance_to(wish.normalized()) > 0.0001:
			bad += 1
			if bad <= 3:
				print("  %d deg: wish %s but forward points %s" % [degrees, wish, facing])

	# ...and the old expression must FAIL the same test, or this proves nothing
	# about the bug having been real.
	var wish_check := Vector3(1.0, 0.0, 0.0)
	var old_yaw := atan2(wish_check.x, wish_check.z)
	var old_facing := (Basis(Vector3.UP, old_yaw) * Vector3.FORWARD).normalized()
	var old_was_wrong: bool = old_facing.distance_to(wish_check) > 1.0
    
	print("facing: %d directions checked, %d wrong; the old expression was %s" % [
		checked, bad, "180 degrees out as described" if old_was_wrong else "FINE - the fix may be wrong"])
	if not old_was_wrong:
		bad += 1
	return 1 if bad > 0 else 0
