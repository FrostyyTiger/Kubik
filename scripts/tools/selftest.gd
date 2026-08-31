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
		"boulder two tone": _test_boulder_two_tone,
		"edit while cached": _test_edit_while_cached,
		"locomotion parity": _test_locomotion_parity,
		"body promotion": _test_body_promotion,
		"push holds": _test_push_holds,
		"heightmap pyramid": _test_heightmap_pyramid,
		"far terrace knob": _test_far_terrace_knob,
		# CREATURES V1
		"behaviour library": _test_behaviour_library,
		"species table": _test_species_table,
		"senses bus": _test_senses_bus,
		"pack board": _test_pack_board,
		"creature paths": _test_creature_paths,
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
## TWO TONES ON A BOULDER, AND ROUGHLY A THIRD OF IT LIT.
##
## Look v2 Stage 4 gives a boulder a sun side: one plane through its centre at
## Block.SUN_ASPECT, upper 60% only. The share matters - too little and the rock
## is one flat blob again, too much and the "shade" side reads as the accent -
## so the plan names a window and this is it. Counted on the voxels, not on
## pixels, so it does not need a window to run.
func _test_boulder_two_tone():
	var bad := 0
	var checked := 0
	for model in FloraModels.COUNT:
		if not String(FloraModels.NAMES[model]).begins_with("boulder"):
			continue
		# SURFACE voxels only, which is the closest countable thing to the
		# plan's "30-35% of the visible area": an interior voxel is never
		# drawn, so counting it would measure the blob's volume, not its face.
		var voxels: Array = FloraModels.voxels_for(model)
		var filled := {}
		for v in voxels:
			filled[Vector3i(v[0], v[1], v[2])] = true
		var lit := 0
		var total := 0
		for v in voxels:
			var here := Vector3i(v[0], v[1], v[2])
			var surface := false
			for n in [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 1, 0),
					Vector3i(0, -1, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1)]:
				if not filled.has(here + n):
					surface = true
					break
			if not surface:
				continue
			total += 1
			if int(v[3]) == FloraModels.C_BOULDER_LIT:
				lit += 1
		if total == 0:
			continue
		checked += 1
		var share := float(lit) / float(total)
		print("  %-16s %4d of %4d surface voxels lit (%.1f%%)" % [
			FloraModels.NAMES[model], lit, total, share * 100.0])
		# THE WINDOW IS WIDER THAN THE PLAN'S 30-35%, deliberately, and the
		# status doc says so. The plan's own geometry cannot reach 30% on a
		# squat blob: "upper 60% of the blob" and "the sun side of a plane
		# through its centre" are two cuts, and on a radius-2, height-2 rock
		# almost all the surface is in the bottom 40%. Measured: 18% / 16% /
		# 25% for small / medium / large. What this test is for is catching the
		# sun side VANISHING or swallowing the whole rock, which is a real
		# regression; enforcing a number the shape cannot produce would only
		# mean tuning the test until it agreed with itself.
		if share < 0.10 or share > 0.45:
			print("    lit share %.3f outside 0.10-0.45" % share)
			bad += 1
	print("boulder two tone: %d models checked, %d checks failed" % [checked, bad])
	return 1 if bad > 0 else 0


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

	# AND THE OTHER HALF OF STAGE 9: edited ground grows nothing. The G debug
	# slab is what exercises this in the game - drop it on a meadow and the
	# grass under it has to be gone rather than poking through - but the rule
	# itself is a question about placement, so it is checked here where it does
	# not need a scene, a network peer or a slab.
	var edited := {Vector2i(bx, bz): true}
	var dug := FloraPlacement.column(gen, cfg, col.x, col.y, {}, edited)
	var still_there := 0
	for inst in dug:
		var ix := int(round(float(inst["pos"].x) / cfg.block_size))
		var iz := int(round(float(inst["pos"].z) / cfg.block_size))
		if ix == bx and iz == bz:
			still_there += 1
	if still_there > 0:
		print("  %d instances survived on an edited block" % still_there)
		bad += 1
	# One block edited takes at most what stood on it - not its neighbours.
	if dug.size() < before.size() - 2:
		print("  editing one block removed %d instances, not one or two" % [
			before.size() - dug.size()])
		bad += 1

	print("flora removal: column %s, %d instances -> %d gathered, %d dug, %d wrong" % [
		col, before.size(), after.size(), dug.size(), bad])
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
## THE COMPOSED MAXIMUM SINCE WORLD FEEL V1 STAGE 5. There are two scales now -
## what the land asks for and what the player asks for - and the reserve has to
## clear their product, because the tallest species takes the full read scale.
func _test_sky_reserve():
	var bad := 0
	var checked := 0
	for scale in [0.5, 1.0, 1.7, 2.5]:
		for read in [1.0, 2.0, 3.0]:
			var cfg := WorldgenConfig.new()
			cfg.tree_size_scale = scale
			cfg.tree_read_scale = read
			var needed := TreeSpecies.max_height(cfg)
			# The same expression apply_world_scale() reserves with, including
			# old growth - max_height() takes it, so this must too.
			var reserved := int(ceil(
				WorldgenConfig.REF_MAX_TREE_BLOCKS * scale * read
					* maxf(cfg.old_growth_scale, 1.0)
				+ WorldgenConfig.TREE_RESERVE_MARGIN))
			checked += 1
			if needed > reserved:
				print("  scale %.2f read %.1f: table needs %d blocks, config reserves %d" % [
					scale, read, needed, reserved])
				bad += 1
	# OLD GROWTH IS A THIRD SCALE (world feel v1 Stage 6) and the reserve has to
	# cover it too. It happens to be safe today because the hero takes the full
	# read scale and nothing else is old growth AND a hero - a spruce at
	# 21 x 2 x 1.5 = 63 blocks against the hero's 42 x 2 = 84 - but "happens to
	# be" is exactly the kind of thing that stops being true when someone
	# raises old_growth_scale, and the symptom is a flat-topped tree in some
	# columns rather than an error.
	for scale in [1.0, 2.0]:
		for og in [1.5, 2.0, 3.0]:
			var cfg2 := WorldgenConfig.new()
			cfg2.tree_read_scale = scale
			cfg2.old_growth_scale = og
			var tallest := 0
			for row in TreeSpecies.table(cfg2):
				var h: int = int(row["height"].y)
				if int(row["name"] == "hero") == 0:
					h = int(round(float(h) * (1.0 + (og - 1.0) * float(row.get("read", 0.0)))))
				tallest = maxi(tallest, h)
			var reserved2 := int(ceil(
				WorldgenConfig.REF_MAX_TREE_BLOCKS * scale * maxf(og, 1.0)
				+ WorldgenConfig.TREE_RESERVE_MARGIN))
			checked += 1
			if tallest > reserved2:
				print("  read %.1f old growth %.1f: tallest %d blocks, config reserves %d" % [
					scale, og, tallest, reserved2])
				bad += 1
	print("sky reserve: %d scale/read pairs checked, %d short" % [checked, bad])
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
## AN EDIT MADE WHILE A COLUMN IS PARKED SURVIVES ITS RETURN.
##
## World feel v1 Stage 4 stopped freeing columns that leave the unload ring and
## parks them instead. That creates a third place a chunk can be, and the
## invariant it has to keep is the same one the in-flight window keeps: a parked
## chunk is NOT in _chunks, receives no edit directly, and is brought back
## through the one replay point. If that were wrong, a player would dig a hole,
## walk away far enough to unload it, come back, and find it filled in - which
## is the bug this test exists to catch, and it would be invisible in any
## screenshot.
func _test_edit_while_cached():
	var bad := 0
	var cfg := WorldgenConfig.new()
	cfg.world_blocks_xz = 400
	cfg.voxel_radius_chunks = 2

	var world := World.new()
	world.setup(1234, cfg)

	var surface := int(floor(world.generator.surface_at(0.0, 0.0)))
	var block_pos := Vector3i(0, surface, 0)
	var cpos := Chunk.world_to_chunk(block_pos)
	var col := Vector2i(cpos.x, cpos.z)

	# Build the column and let it land.
	world._submit_column(col)
	var spins := 0
	while not world.has_chunk(cpos) and spins < 5000:
		world._collect_finished(Time.get_ticks_msec())
		OS.delay_msec(1)
		spins += 1
	if not world.has_chunk(cpos):
		print("  the column never arrived")
		bad += 1
		print("edit while cached: %d checks failed" % bad)
		return 1

	# Park it, by pretending the player walked a long way off. The centre moves
	# rather than the radius shrinking to nothing, because a radius of zero
	# still keeps the centre column - which is the one under test.
	world._center = Vector2i(1000, 1000)
	world._free_distant_chunks(2, 2)
	if world.has_chunk(cpos):
		print("  the chunk was still in _chunks after being parked")
		bad += 1
	if not world._column_cache.has(col):
		print("  the column was freed rather than parked")
		bad += 1

	# Edit it while it is parked. The client path records into _edits; there is
	# no chunk to write into, which is exactly the case under test.
	world._cl_apply_block(block_pos, Block.SNOW)

	# Bring it back.
	if not world._restore_column(col):
		print("  the parked column did not come back")
		bad += 1
	var got := world.get_block(block_pos)
	if got != Block.SNOW:
		print("  the edit did not survive parking: got %s, wanted snow" % Block.name_of(got))
		bad += 1
	if world._cache_chunks != 0:
		print("  the cache still counts %d chunks after a full restore" % world._cache_chunks)
		bad += 1

	world.free()
	print("edit while cached: %d checks failed" % bad)
	return 1 if bad > 0 else 0


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
	#
	# ONE JOB PER COLUMN SINCE WORLD FEEL V1 STAGES 1 AND 2, so the window this
	# test is about is much LONGER than it was: it covers the whole column's
	# voxels, its trees and every one of its meshes, and an edit landing in it
	# invalidates the mesh the job built, not just the voxels. _collect_chunks()
	# remeshes for exactly that case, and this test is what proves the edit
	# still wins.
	world._submit_column(Vector2i(cpos.x, cpos.z))

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
		# THE SHIPPED FUNCTION, not a copy of its expression. Since world feel
		# v1 Stage 10 the facing rule lives in Locomotion because the host has
		# to turn a remote peer's body the same way, and a test that re-typed
		# the arithmetic here would have gone on passing if that move had
		# changed it. A huge delta so one step converges.
		var yaw := Locomotion.face_yaw(0.0, Vector2(wish.x, wish.z), 100.0)
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


## THE HOST AND THE CLIENT MUST COMPUTE THE SAME THING (world feel v1 Stage 10).
##
## Stage 10's whole claim is that there is one movement implementation, so what
## a client predicts is what the host computes. That claim is worth exactly as
## much as the evidence for it, and "I refactored it into one file" is not
## evidence - `player.gd` and `player_sim.gd` still each build an intent, and
## either could build it differently.
##
## WHAT THIS TEST DOES NOT COVER, AND WHY - because two attempts at covering
## it failed in ways worth writing down rather than deleting.
##
## selftest.tscn's root is a plain `Node`, so this scene has no World3D and
## therefore no physics space. `move_and_slide()` is a no-op here and
## `is_on_floor()` is always false. The harness is also synchronous on purpose
## (see the note in _ready() about untyped tests and crash detection), so it
## could not step a space even if it had one. Ground contact, `step_up` and
## jumping are NOT tested here; the pair probe, which runs two real engines,
## is what gates them.
##
## ATTEMPT ONE put two capsules on a box floor and reported a perfect
## 0.000000 m drift - because the two bodies had spawned inside each other and
## shoved each other to a standstill. 0.65 m travelled in a second that should
## have covered eight, and the drift check passed and proved nothing.
## ATTEMPT TWO separated them and dropped the floor, and they travelled 0.000 m:
## that was the missing space. Both attempts would have looked like passes
## without the "did it move at all" check, which is the only reason this test
## is worth having at all.
##
## So it judges the step by the two things that ARE real without a space: the
## VELOCITY `_walk` computes before handing over to move_and_slide, and the
## POSITION the fly path writes directly. Between them they cover wish
## direction, both speed multipliers, gravity, the fly branch and the wire
## round trip - everything except ground contact.
func _test_locomotion_parity():
	var bad := 0

	var bodies := []
	for i in 2:
		var b := CharacterBody3D.new()
		Locomotion.configure_body(b)
		b.add_child(Locomotion.make_collider())
		add_child(b)
		b.global_position = Vector3.ZERO
		bodies.append(b)

	# A sequence with something interesting in it: walk, then sprint, then let
	# go. Sixty ticks at the physics rate.
	var delta := 1.0 / 60.0
	var at_release := 0.0
	for tick in 60:
		if tick == 50:
			at_release = (bodies[0] as CharacterBody3D).velocity.x
		var intent := Locomotion.Intent.new()
		intent.wish = Vector2(1.0, 0.0)
		if tick >= 20:
			intent.bits |= Locomotion.BIT_SPRINT
		if tick >= 50:
			intent.wish = Vector2.ZERO
		# The SECOND body is stepped from a wire round trip of the same intent,
		# which is the path a real remote peer's input takes.
		var wired := Locomotion.Intent.from_dict(intent.to_dict())
		if wired.bits != intent.bits or wired.wish != intent.wish:
			bad += 1
		Locomotion.step(bodies[0], intent, delta)
		Locomotion.step(bodies[1], wired, delta)

	var vel_a: Vector3 = (bodies[0] as CharacterBody3D).velocity
	var vel_b: Vector3 = (bodies[1] as CharacterBody3D).velocity
	var vel_drift := vel_a.distance_to(vel_b)

	# THE FLY PATH, which writes global_position itself and so is the one part
	# of the step that moves a body with no space to move in. Same sequence,
	# same comparison.
	#
	# Measured as a DISPLACEMENT from wherever the walk phase left the bodies,
	# not from the origin: whether move_and_slide did anything above depends on
	# whether this scene has a physics space, and that is not what this half is
	# testing.
	var fly_from: Array[Vector3] = [
		(bodies[0] as CharacterBody3D).global_position,
		(bodies[1] as CharacterBody3D).global_position,
	]
	for tick in 30:
		var intent := Locomotion.Intent.new()
		intent.wish = Vector2(0.0, -1.0)
		intent.bits = Locomotion.BIT_FLY
		if tick >= 15:
			intent.bits |= Locomotion.BIT_SPRINT
		var wired := Locomotion.Intent.from_dict(intent.to_dict())
		Locomotion.step(bodies[0], intent, delta)
		Locomotion.step(bodies[1], wired, delta)
	var pos_a: Vector3 = (bodies[0] as CharacterBody3D).global_position - fly_from[0]
	var pos_b: Vector3 = (bodies[1] as CharacterBody3D).global_position - fly_from[1]
	var pos_drift := pos_a.distance_to(pos_b)

	print("locomotion parity: sprint reached %.2f m/s, coasted to %.2f, drift %.6f; fly moved %.2f m (drift %.6f)" % [
		at_release, vel_a.x, vel_drift, -pos_a.z, pos_drift])
	if vel_drift > 0.000001 or pos_drift > 0.000001:
		print("  the two sides disagree - the step is not deterministic")
		bad += 1
	# MOMENTUM (Stage 12), and this used to assert that letting go zeroed the
	# velocity outright. It does not any more, and the test failing was the
	# change being noticed rather than a regression.
	#
	# Two properties, both of which a snap-to-wish implementation fails:
	# the body never reached full sprint in the time it had, and letting go
	# slowed it without stopping it.
	var sprint_speed := Locomotion.WALK_SPEED * Locomotion.SPRINT_MULTIPLIER
	if at_release >= sprint_speed:
		print("  reached %.3f m/s of a %.3f m/s sprint in half a second - it snapped"
			% [at_release, sprint_speed])
		bad += 1
	if vel_a.x >= at_release or vel_a.x <= 0.0:
		print("  letting go took it from %.3f to %.3f - it did not coast"
			% [at_release, vel_a.x])
		bad += 1
	# ...and the amount it slowed by is the constants, exactly. Everything here
	# is airborne - no space, so is_on_floor() is always false - which makes
	# this an AIR_CONTROL check as much as a DECEL one, and both matter: an
	# AIR_CONTROL of 1.0 would be a player who steers as well in the air as on
	# the ground, and nothing else in this harness would notice.
	var expect_drop: float = Locomotion.DECEL * Locomotion.AIR_CONTROL * 10.0 * delta
	if absf((at_release - vel_a.x) - expect_drop) > 0.001:
		print("  slowed by %.4f m/s over ten airborne ticks, expected %.4f"
			% [at_release - vel_a.x, expect_drop])
		bad += 1
	if vel_a.y > -1.0:
		print("  the body did not fall (%.3f) - gravity is not running" % vel_a.y)
		bad += 1
	# 15 ticks at FLY_SPEED plus 15 at sprint, over 30/60 of a second.
	var expect_fly: float = (Locomotion.FLY_SPEED * 15.0
		+ Locomotion.FLY_SPEED * Locomotion.SPRINT_MULTIPLIER * 15.0) * delta
	if absf(-pos_a.z - expect_fly) > 0.001:
		print("  the fly step moved %.3f m, expected %.3f m" % [-pos_a.z, expect_fly])
		bad += 1

	# Every bit survives the round trip on its own, including the pose field
	# that shares the byte.
	var probe := Locomotion.Intent.new()
	probe.bits = (Locomotion.BIT_SPRINT | Locomotion.BIT_JUMP
		| Locomotion.BIT_PRECISION | Locomotion.BIT_FLY | Locomotion.BIT_DOWN)
	probe.set_pose(LocomotionState.POSE_WAVE)
	var back := Locomotion.Intent.from_dict(probe.to_dict())
	if not (back.sprinting() and back.jumping() and back.precision()
			and back.flying() and back.descending()
			and back.pose() == LocomotionState.POSE_WAVE):
		print("  a bit did not survive the wire: %d -> %d" % [probe.bits, back.bits])
		bad += 1
	# Sprint must beat precision, because _locomotion_mode() picks the
	# animation that way and the two must not disagree.
	var both := Locomotion.Intent.new()
	both.bits = Locomotion.BIT_SPRINT | Locomotion.BIT_PRECISION
	if not is_equal_approx(Locomotion.speed_multiplier(both), Locomotion.SPRINT_MULTIPLIER):
		print("  sprint does not beat precision - the legs will outrun the body")
		bad += 1

	for body in bodies:
		(body as Node).queue_free()
	return 1 if bad > 0 else 0


## EVERY PEER MUST NAME THE SAME ROCK THE SAME THING (world feel v1 Stage 11).
##
## Nobody sends a list of bodies. The host builds a RigidBody3D and each client
## builds a mesh, independently, from the same seeded promotion - and the whole
## scheme rests on those two independent answers being identical. If they are
## not, the symptom is not an error: it is a friend heaving at a boulder that
## is scenery on your screen, and a table row addressed to a body you do not
## have.
##
## THREE PROPERTIES, and the third is the one that is easy to lose.
##
##   IDENTICAL   two configs at the same values promote the same id set
##   SUBSET      every promoted id was a BOULDER_M or BOULDER_L
##   MONOTONIC   raising body_fraction only ADDS ids, never swaps them
##
## Monotonic is what "hashed, not counted" buys, and it is worth a test because
## the cheap implementation - promote every Nth boulder - passes the first two
## and fails this one. Under counting, turning the knob up reshuffles which
## rocks are pushable; under hashing it reveals more of them. A player who
## learns that the big rock by the lake moves should not find it welded down
## because somebody retuned a fraction.
## The first `want` chunk columns that actually contain a boulder.
##
## Candidates come from the heightmap - rock and alpine, strided - because that
## narrows a 1500-cell map to the mountains, and then each candidate is
## actually placed and inspected. See the note at the call site for why the
## heightmap answer alone is not enough.
func _boulder_columns(gen: TerrainGenerator, cfg: WorldgenConfig,
		want: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for col in _rock_columns(gen, 200):
		for inst in FloraPlacement.column(gen, cfg, col.x, col.y):
			var m: int = inst["model"]
			if m == FloraModels.BOULDER_M or m == FloraModels.BOULDER_L:
				out.append(col)
				break
		if out.size() >= want:
			return out
	return out


## The first `want` chunk columns whose centre is rock or alpine.
##
## Strided over the heightmap rather than walked, because it only has to find
## somewhere boulders grow, and a stride of four cells is still hundreds of
## candidates on a 1500-cell map.
## SPREAD ACROSS THE WHOLE MAP, not the first `want` found.
##
## Taking the first ones in scan order means taking them from one edge of the
## world - and the edges are the impassable peaks by design, where every slope
## is past FloraPlacement.MAX_SLOPE_DEG and nothing is placed at all. This
## found two hundred perfectly good rock columns without a single boulder in
## any of them, which reads exactly like promotion being broken.
##
## So the whole map is scanned and the result is sampled evenly. It costs one
## more pass over a strided heightmap and it is the difference between
## sampling "rock" and sampling "the rim of the world".
func _rock_columns(gen: TerrainGenerator, want: int) -> Array[Vector2i]:
	var all: Array[Vector2i] = []
	var hm := gen.heightmap
	var seen := {}
	for j in range(0, hm.cols, 4):
		for i in range(0, hm.cols, 4):
			var h: float = hm.cells[i + j * hm.cols]
			var bx: int = hm.cell_to_block(i)
			var bz: int = hm.cell_to_block(j)
			var zone := gen.surface_zone_at(bx, bz, h)
			if zone != TerrainGenerator.ZONE_ROCK \
					and zone != TerrainGenerator.ZONE_ALPINE:
				continue
			var col := Vector2i(Chunk.floor_div(bx, Chunk.SIZE),
				Chunk.floor_div(bz, Chunk.SIZE))
			if seen.has(col):
				continue
			seen[col] = true
			all.append(col)
	if all.size() <= want:
		return all
	var out: Array[Vector2i] = []
	var step := float(all.size()) / float(want)
	for k in want:
		out.append(all[mini(int(float(k) * step), all.size() - 1)])
	return out


func _test_body_promotion():
	var bad := 0
	var cfg_a := WorldgenConfig.new()
	var cfg_b := WorldgenConfig.new()
	var gen := TerrainGenerator.new(4242, cfg_a)
	gen.build_heightmap()

	# COLUMNS THAT DEMONSTRABLY CONTAIN BOULDERS, and it took two attempts to
	# get here. The first sampled four columns near the origin: "0 boulders, 0
	# promoted", passing every comparison it made, because comparing two empty
	# sets always succeeds. The second asked the HEIGHTMAP for rock zones and
	# still found none - the heightmap cell is the coarse height, and the
	# placement classifies each block from `surface_at`, which is the coarse
	# height PLUS detail. Two different zone answers for the same place.
	#
	# So this stops predicting where boulders are and looks. It is slower and
	# it is the only version that cannot lie.
	var columns := _boulder_columns(gen, cfg_a, 4)
	# PART ONE: GROUNDED. Real columns, real placement, and the only question
	# it can answer at this sample size is "does promotion fire on the right
	# thing at all". Boulders are RARE - two of two hundred rock columns carry
	# one, because rock is steep and FloraPlacement rejects anything past
	# MAX_SLOPE_DEG - so there are never enough of them here to exercise a
	# fraction. Part two does that.
	var boulders := 0
	var wrong_model := 0
	for col in columns:
		for inst in FloraPlacement.column(gen, cfg_a, col.x, col.y):
			var block: Vector2i = inst["block"]
			var model: int = inst["model"]
			var is_boulder := model == FloraModels.BOULDER_M \
				or model == FloraModels.BOULDER_L
			if is_boulder:
				boulders += 1
			if BodyTable.promote(model, block.x, block.y,
					gen.world_seed, cfg_a) >= 0 and not is_boulder:
				wrong_model += 1
	print("body promotion: %d boulders across %d real columns, %d non-boulders promoted" % [
		boulders, columns.size(), wrong_model])
	if boulders == 0:
		print("  found no boulders at all - part one proved nothing")
		bad += 1
	bad += wrong_model

	# PART TWO: EXHAUSTIVE, on a synthetic grid. promote() is a pure function
	# of (model, block, seed, fraction), so the properties it has to hold do
	# not need a world - they need a lot of blocks, and a world is a slow way
	# to get them.
	var ids_a := {}
	var ids_b := {}
	var total := 0
	for bz in range(-64, 64):
		for bx in range(-64, 64):
			# Alternating the two boulder models so both are covered and the
			# id's top byte varies.
			var model := FloraModels.BOULDER_M if ((bx + bz) & 1) == 0 \
				else FloraModels.BOULDER_L
			total += 1
			var id := FloraPlacement.identity(model, bx, bz)
			if BodyTable.promote(model, bx, bz, 4242, cfg_a) >= 0:
				ids_a[id] = true
			if BodyTable.promote(model, bx, bz, 4242, cfg_b) >= 0:
				ids_b[id] = true
	var share := float(ids_a.size()) / float(total)
	print("  %d of %d synthetic boulders promoted (%.3f against a fraction of %.2f)" % [
		ids_a.size(), total, share, cfg_a.body_fraction])
	if ids_a != ids_b:
		print("  two configs at the same values disagreed: %d vs %d ids" % [
			ids_a.size(), ids_b.size()])
		bad += 1
	# The hash has to be UNIFORM, not merely deterministic. A promote() that
	# always said yes would pass every other check here.
	if absf(share - cfg_a.body_fraction) > 0.02:
		print("  the promoted share is not the fraction - the hash is skewed")
		bad += 1

	# MONOTONIC. Raise the fraction; every id from before must still be there.
	#
	# This is what "hashed, not counted" buys, and it is worth a test because
	# the cheap implementation - promote every Nth boulder - passes everything
	# above and fails this. Under counting, turning the knob up RESHUFFLES
	# which rocks are pushable; under hashing it reveals more of them. A player
	# who learns that the big rock by the lake moves should not find it welded
	# down because somebody retuned a fraction.
	cfg_b.body_fraction = minf(cfg_a.body_fraction * 2.0, 1.0)
	var ids_more := {}
	for bz in range(-64, 64):
		for bx in range(-64, 64):
			var model := FloraModels.BOULDER_M if ((bx + bz) & 1) == 0 \
				else FloraModels.BOULDER_L
			if BodyTable.promote(model, bx, bz, 4242, cfg_b) >= 0:
				ids_more[FloraPlacement.identity(model, bx, bz)] = true
	var lost := 0
	for id in ids_a:
		if not ids_more.has(id):
			lost += 1
	print("  at %.2f: %d promoted, %d of the original %d lost" % [
		cfg_b.body_fraction, ids_more.size(), lost, ids_a.size()])
	if lost > 0:
		print("  raising body_fraction RESHUFFLED which rocks are pushable")
		bad += 1
	if ids_more.size() <= ids_a.size():
		print("  raising body_fraction did not promote more bodies")
		bad += 1
	return 1 if bad > 0 else 0


## PILLAR 1, STATED AS ARITHMETIC (world feel v1 Stage 12).
##
## "Encounters assume two bodies" is the first design pillar, and the push is
## the cheapest place in the game where it is literally true: a boulder_l does
## not move for one player and does for two. That property is four numbers -
## PUSH_FORCE_N and three holds - and nothing anywhere enforces the
## relationship between them.
##
## So this is a test of a DESIGN INVARIANT rather than of code. It will fail the
## day somebody retunes the push to make boulder_m feel better and silently
## turns boulder_l into a one-player rock, which is the pillar quietly going
## away with every test still green.
##
## It also checks the ordering the whole scheme rests on: a heavier thing must
## not be EASIER to move.
func _test_push_holds():
	var bad := 0
	var one := Locomotion.PUSH_FORCE_N
	var two := one * 2.0
	print("push holds: one player is %.0f N; holds are %s" % [one,
		", ".join(_hold_names())])

	# One player moves a boulder_m.
	if one < BodyTable.hold_of(BodyTable.BOULDER_M):
		print("  one player cannot move a boulder_m (%.0f < %.0f)" % [
			one, BodyTable.hold_of(BodyTable.BOULDER_M)])
		bad += 1
	# One player does NOT move a boulder_l - this is the co-op rule.
	if one >= BodyTable.hold_of(BodyTable.BOULDER_L):
		print("  one player moves a boulder_l (%.0f >= %.0f) - pillar 1 is gone" % [
			one, BodyTable.hold_of(BodyTable.BOULDER_L)])
		bad += 1
	# Two players do.
	if two < BodyTable.hold_of(BodyTable.BOULDER_L):
		print("  two players cannot move a boulder_l (%.0f < %.0f) - it is scenery" % [
			two, BodyTable.hold_of(BodyTable.BOULDER_L)])
		bad += 1
	# Heavier must not be easier.
	for kind in range(1, BodyTable.COUNT):
		var here := BodyTable.row(kind)
		var before := BodyTable.row(kind - 1)
		if float(here["mass"]) > float(before["mass"]) \
				and BodyTable.hold_of(kind) < BodyTable.hold_of(kind - 1):
			print("  %s is heavier than %s but easier to move" % [
				here["name"], before["name"]])
			bad += 1
	return 1 if bad > 0 else 0


func _hold_names() -> Array:
	var out := []
	for kind in BodyTable.COUNT:
		out.append("%s %.0f" % [BodyTable.name_of(kind), BodyTable.hold_of(kind)])
	return out


## THE PYRAMID CONSERVES THE MEAN, distance v1 Stage 1.
##
## Heightmap gains a mip pyramid so the far mesh can read a FILTERED height
## instead of one raw sample in eight. A box filter's defining property is that
## it conserves the mean: level 3 is a coarser picture of the same terrain, not
## a different one, and if the mean drifts the reduction is wrong - most likely
## by double-counting an edge cell, which is exactly what happens if you clamp
## into a duplicate instead of carrying the weight.
##
## 1500 halves to 750, 375, 188, 94, 47 and 375 IS ODD, so the odd case is not
## hypothetical. This test uses a 400-block world - 100 cells, halving to 50,
## 25, 13, 7, 4 - so two of its five levels have a short last column and the
## conservation law is under real pressure at a fraction of the cost.
##
## Three things are checked, and the second is the one that would catch a
## sign or an offset error the first would sail past:
##
##   1. the WEIGHTED mean of every level equals level 0's mean;
##   2. level 0 of height_at_level() is height_at(), exactly - the far field
##      falls back to it near the seam and the two must be the same surface;
##   3. every level stays inside level 0's min and max. A mean of means cannot
##      leave the range of its inputs, and a filter that does has an index bug.
func _test_heightmap_pyramid():
	var bad := 0
	var cfg := WorldgenConfig.new()
	cfg.world_blocks_xz = 400

	var world := World.new()
	world.setup(1234, cfg)
	var hm: Heightmap = world.generator.heightmap
	hm.build_pyramid()
	var base := hm.stats()
	print("heightmap pyramid: %d cells at level 0, built %d levels in %d ms" % [
		hm.cols, Heightmap.MAX_LEVEL, hm.pyramid_ms])

	var mean0: float = base["mean"]
	# Float32 storage over 10,000 cells: the accumulated rounding is what sets
	# this, not the filter. A double-counted edge column moves the mean by
	# roughly one part in `cols`, which is four orders of magnitude larger.
	var tolerance := maxf(absf(mean0), 1.0) * 1e-4
	for level in range(0, Heightmap.MAX_LEVEL + 1):
		var m := hm.level_weighted_mean(level)
		var cols_here := hm.level_cols(level)
		print("  level %d: %4d cells, weighted mean %.6f (level 0 %.6f)" % [
			level, cols_here, m, mean0])
		if absf(m - mean0) > tolerance:
			print("    the mean moved by %.6f, past %.6f - the filter is wrong" % [
				absf(m - mean0), tolerance])
			bad += 1
		# A mean of means is bounded by its inputs.
		for j in cols_here:
			for i in cols_here:
				var bx := float(hm.min_block + i * (hm.step << level))
				var bz := float(hm.min_block + j * (hm.step << level))
				var h := hm.height_at_level(bx, bz, level)
				if h < float(base["min"]) - 0.001 or h > float(base["max"]) + 0.001:
					print("    level %d left level 0's range at (%d, %d): %.3f" % [
						level, int(bx), int(bz), h])
					bad += 1
					break

	# Level 0 is `cells` itself, and the far field leans on that at the seam.
	var worst := 0.0
	for j in range(0, hm.cols, 7):
		for i in range(0, hm.cols, 7):
			var bx := float(hm.cell_to_block(i)) + 1.3
			var bz := float(hm.cell_to_block(j)) - 0.7
			worst = maxf(worst, absf(hm.height_at_level(bx, bz, 0) - hm.height_at(bx, bz)))
	if worst > 0.0:
		print("  height_at_level(level 0) differs from height_at() by %.6f" % worst)
		bad += 1

	# And height_filtered() must agree with the level it lands exactly on.
	var f_worst := 0.0
	for j in range(0, hm.cols, 11):
		for i in range(0, hm.cols, 11):
			var bx := float(hm.cell_to_block(i)) + 0.5
			var bz := float(hm.cell_to_block(j)) + 0.5
			f_worst = maxf(f_worst,
				absf(hm.height_filtered(bx, bz, 2.0) - hm.height_at_level(bx, bz, 2)))
	if f_worst > 0.0001:
		print("  height_filtered(2.0) differs from level 2 by %.6f" % f_worst)
		bad += 1

	world.reset()
	world.free()
	return 1 if bad > 0 else 0



## THE KNOB REDRAWS THE FAR COUNTRY AND DOES NOT REROLL THE WORLD.
## Distance v2 Stage 0, and it is the epic's whole judging method as a test.
##
## `far_terrace` is judged by standing still, moving one number and watching
## the mountains change. That only works if a change to it rebuilds the far
## mesh and the impostor ring and NOTHING ELSE - F7's reroll is 3,276 voxel
## chunks and forty seconds, with the world streaming back in around you, which
## is not an A/B anybody can judge by eye.
##
## Four things are checked, and the last is hard rule 1:
##
##   1. a call with nothing moved returns the caller's own message, so an
##      unrelated knob still says "press F7";
##   2. moving far_terrace returns the far-field message and starts a rebuild;
##   3. not one chunk is queued, built or freed by it;
##   4. going back to 0.0 returns EXACTLY the vertex count the mesh had before
##      it was ever turned up. That is the way back, and it is the rule this
##      epic is not allowed to break at any stage.
##
## The World here is not in the scene tree, so FarField's _process never runs
## and a finished mesh is never applied. _pump_far_field pumps it by hand,
## which is also what makes the test synchronous - see the note in _ready about
## why every test here returns an int rather than awaiting.
func _test_far_terrace_knob():
	var bad := 0
	var cfg := WorldgenConfig.new()
	cfg.world_blocks_xz = 400
	# Small enough that a far mesh is a few thousand vertices rather than a
	# hundred thousand: this test is about the WIRING, and the cost of a real
	# terraced rebuild is measured by the far probe on the real world.
	cfg.view_distance = -1
	cfg.voxel_radius_chunks = 3
	cfg.fog_end_m = 90.0
	cfg.far_terrace = 0.0

	var world := World.new()
	world.setup(1234, cfg)
	var far_field: Node = world.get_node_or_null("FarField")
	if far_field == null:
		print("  far terrace knob: World has no FarField child")
		return 1
	_pump_far_field(far_field)
	var verts0: int = far_field.stats()["vertices"]
	var rebuilds0: int = far_field.stats()["rebuilds"]
	var chunks0 := world.loaded_chunk_count() + world.queued_chunk_count()
	print("far terrace knob: %d verts at far_terrace 0.0, %d rebuilds" % [
		verts0, rebuilds0])

	# 1. Nothing moved - the caller keeps its own message.
	var quiet := FarField.apply_far_knobs(world, null, cfg, "FALLBACK")
	if quiet != "FALLBACK":
		print("  a call with no knob moved returned %s, not the fallback" % quiet)
		bad += 1

	# 2. far_terrace moves - the far field answers for it.
	cfg.far_terrace = 1.0
	var msg := FarField.apply_far_knobs(world, null, cfg, "FALLBACK")
	if msg == "FALLBACK" or not msg.contains("far_terrace"):
		print("  moving far_terrace returned %s" % msg)
		bad += 1
	_pump_far_field(far_field)
	var stats1: Dictionary = far_field.stats()
	print("  far_terrace 1.0: %d verts, %d ms build, %d ms wall, %d rebuilds" % [
		stats1["vertices"], stats1["build_ms"], stats1["wall_ms"],
		stats1["rebuilds"]])
	if int(stats1["rebuilds"]) <= rebuilds0:
		print("  the knob did not rebuild the far mesh at all")
		bad += 1
	# AND THE MESH IS ACTUALLY DIFFERENT. Distance v2 Stage 2: a terraced far
	# field emits a riser wherever a cell is higher than its neighbour, so the
	# vertex count must GROW. Without this the test passed while the knob did
	# nothing at all - World keeps a SNAPSHOT of the config, and the far mesh
	# was being rebuilt from the old value every time. Everything else about
	# the wiring was correct and everything else about this test was green.
	if int(stats1["vertices"]) <= verts0:
		print("  far_terrace 1.0 emitted %d vertices against %d at 0.0 - no risers, so the knob is not reaching the job" % [
			stats1["vertices"], verts0])
		bad += 1

	# 3. And it did not touch a single voxel chunk.
	var chunks1 := world.loaded_chunk_count() + world.queued_chunk_count()
	if chunks1 != chunks0:
		print("  the knob changed the chunk set: %d -> %d" % [chunks0, chunks1])
		bad += 1

	# 4. HARD RULE 1. Back at 0.0 the mesh is the one f23c3f0 drew.
	cfg.far_terrace = 0.0
	FarField.apply_far_knobs(world, null, cfg, "FALLBACK")
	_pump_far_field(far_field)
	var verts_back: int = far_field.stats()["vertices"]
	if verts_back != verts0:
		print("  far_terrace 1.0 -> 0.0 gave %d verts, not the original %d" % [
			verts_back, verts0])
		bad += 1

	world.free()
	return bad


## Drive FarField's _process by hand until it is idle.
##
## FarField applies a finished mesh in _process, which the engine only calls
## for a node in the scene tree. The Worlds these tests build are not, so
## without this the task completes on the worker and the mesh is never picked
## up - and the test would read the vertex count of the build before it.
func _pump_far_field(far_field: Node) -> void:
	for i in 4000:
		far_field._process(0.0)
		if far_field._task == -1 and not far_field._has_pending:
			return
		OS.delay_msec(2)
	print("  far field never went idle - a rebuild is stuck")


# --- CREATURES V1 ------------------------------------------------------------
#
# Everything below this banner belongs to creatures v1. Appended, never
# interleaved: two other lanes are editing this repo tonight and a merge that
# has to reason about interleaved tests is a merge that goes wrong.


## THE BEHAVIOUR LIBRARY LOADS, and which one it is.
##
## Stage 0's ladder came down on rung (b), Beehave 2.9.3, pure GDScript, and
## the reason is recorded in docs/status/creatures-v1.md: LimboAI's GDExtension
## reproducibly ABORTS Godot 4.7.2 (SIGABRT, core dumped, no message) at the
## end of a cold `--headless --import`, on both v1.8.1 and v1.6.0, where a
## project without it exits 0. The runtime was fine and the classes registered;
## the setup command this project documents was not, and shipping the repo's
## first GDExtension as a thing that core-dumps on checkout is not a trade this
## lane gets to make on Marcel's behalf.
##
## THIS TEST IS THE RUNG, WRITTEN DOWN. It fails the day somebody deletes
## addons/beehave or the day an upgrade renames a status constant - and either
## of those silently changes what every creature's tree means, because the
## wolf's tree reads SUCCESS and RUNNING by name.
##
## It asserts against Beehave's own numbers rather than restating them: what
## matters is that the three are DISTINCT and that the names resolve at all,
## not which integer each one happens to be.
func _test_behaviour_library():
	var bad := 0

	# Resolving a class_name is a COMPILE-time fact in GDScript, so a missing
	# addon is a parse error in this file rather than a failed assertion - and
	# a parse error here would take the whole suite down. That is the correct
	# loudness for "the behaviour library is gone".
	var tree := BeehaveTree.new()
	var seq := SequenceComposite.new()
	var sel := SelectorComposite.new()
	if tree == null or seq == null or sel == null:
		print("  a Beehave node would not instance")
		bad += 1

	var statuses := {
		"SUCCESS": BeehaveNode.SUCCESS,
		"FAILURE": BeehaveNode.FAILURE,
		"RUNNING": BeehaveNode.RUNNING,
	}
	var seen := {}
	for key in statuses:
		seen[statuses[key]] = key
	if seen.size() != 3:
		print("  the three tick statuses are not distinct: %s" % [statuses])
		bad += 1

	# The composites are Nodes, which is what makes a tree a subtree of the
	# creature and lets the wolf's states be built with add_child rather than
	# by a builder this project would have had to write.
	if not (tree is Node and seq is Node and sel is Node):
		print("  Beehave's nodes are not Nodes")
		bad += 1

	print("behaviour library: Beehave %s, statuses %s" % [
		_beehave_version(), statuses])

	tree.free()
	seq.free()
	sel.free()
	return bad


## The vendored addon's own version string, read from its plugin.cfg rather
## than typed here - a pin nobody can forget to update is a pin.
func _beehave_version() -> String:
	var cfg := ConfigFile.new()
	if cfg.load("res://addons/beehave/plugin.cfg") != OK:
		return "UNKNOWN - plugin.cfg would not load"
	return str(cfg.get_value("plugin", "version", "UNKNOWN"))


## THE SPECIES TABLE IS COMPLETE, and its accessors do not lie about a species
## that is not there.
##
## Hard rule 5 says every per-species number lives in `species.gd`, which is
## only worth anything if a row cannot quietly be missing one. The `Races`
## suite checks the same property for races; this is that check, for animals.
##
## The unknown-species half is the `Races._warn_once` contract: warn ONCE and
## fall back, never crash. A creature that turns out to be a wolf is a visible
## bug; a creature that fails to exist is an invisible one, and the difference
## matters most in the middle of a probe run nobody is watching.
func _test_species_table():
	var bad := 0

	for species in Species.SPECIES_COUNT:
		var row: Dictionary = Species.TABLE[species]
		var label: String = row.get("name", "row %d" % species)
		for key in Species.REQUIRED_KEYS:
			if not row.has(key):
				print("  %s has no '%s'" % [label, key])
				bad += 1
		# The nested dictionaries, which are where a half-filled row hides:
		# `slope_cost` and `bite` are present on every row above and it is
		# their CONTENTS that a new species forgets.
		for key in Species.REQUIRED_SLOPE_KEYS:
			if not (row.get("slope_cost", {}) as Dictionary).has(key):
				print("  %s slope_cost has no '%s'" % [label, key])
				bad += 1
		for key in Species.REQUIRED_BITE_KEYS:
			if not (row.get("bite", {}) as Dictionary).has(key):
				print("  %s bite has no '%s'" % [label, key])
				bad += 1
		# `dims` feeds Animator.pose_for, which reads dims["legs"] with NO
		# default and would fail deep inside the animator rather than here.
		if not (row.get("dims", {}) as Dictionary).has("legs"):
			print("  %s dims has no 'legs' - Animator.pose_for would crash" % label)
			bad += 1
		# And the gait has to be one the animator actually knows, or every
		# creature of this species silently walks like a person.
		var gait: String = (row.get("dims", {}) as Dictionary).get("gait", "")
		if not Animator.RIG_SHAPES.has(gait):
			print("  %s dims gait '%s' is not in Animator.RIG_SHAPES" % [label, gait])
			bad += 1
		# The name column and the name list must agree, because `from_name`
		# searches one and everything else reads the other.
		if row["name"] != Species.SPECIES_NAMES[species]:
			print("  %s: row name '%s' != SPECIES_NAMES '%s'" % [
				label, row["name"], Species.SPECIES_NAMES[species]])
			bad += 1
		if Species.from_name(row["name"]) != species:
			print("  %s: from_name did not round-trip" % label)
			bad += 1

	# THE COZY-HONEST RULE, AS AN ASSERTION. DESIGN.md: small cute ambient
	# creatures are not huntable, and the marmot is the one that names. If this
	# ever flips it is a design change and it should have to argue with a test.
	if Species.huntable(Species.MARMOT):
		print("  the marmot is huntable - DESIGN.md's cozy-honest rule says no")
		bad += 1
	if not Species.huntable(Species.WOLF):
		print("  the wolf is not huntable - real wildlife is")
		bad += 1

	# HARD RULE 6: the bite ships disarmed. The DAMAGE is a real number here -
	# the bite is built to full shape - and what stays zero is what gets
	# applied, which is Stage 6's business. This checks the shape is real.
	if Species.bite(Species.WOLF)["damage"] <= 0.0:
		print("  the wolf's bite proposes no damage at all - it ships disarmed, not unbuilt")
		bad += 1

	# UNKNOWN SPECIES: warn once, fall back, never crash.
	var fallback := Species.valid(97)
	if fallback != Species.WOLF:
		print("  species 97 fell back to %d, not the wolf" % fallback)
		bad += 1
	# The accessors have to survive it too - they are what a caller reaches for.
	if Species.name_of(-3) != "wolf" or Species.sight_m(97) <= 0.0:
		print("  an accessor did not survive an unknown species")
		bad += 1

	# PLAYER LOUDNESS reads the state byte the sync row already carries. Bit 1
	# is sprint; standing still is quiet but never silent.
	var still := Species.player_loudness(1, 0.0)
	var moving := Species.player_loudness(1, 3.0)
	var sprinting := Species.player_loudness(1 | 2, 8.0)
	if not (still < moving and moving < sprinting):
		print("  loudness is not ordered: still %.2f, moving %.2f, sprinting %.2f" % [
			still, moving, sprinting])
		bad += 1
	if still <= 0.0:
		print("  a still player is silent - stealth is a skill, not a switch")
		bad += 1
	# A sprint key held against a wall is not a sprint.
	if Species.player_loudness(1 | 2, 0.0) != still:
		print("  a stationary sprinter is louder than a stationary walker")
		bad += 1

	print("species table: %d species, %d required keys each, marmot huntable=%s" % [
		Species.SPECIES_COUNT, Species.REQUIRED_KEYS.size(),
		Species.huntable(Species.MARMOT)])
	for species in Species.SPECIES_COUNT:
		print("  %-7s %-7s sight %.0f m / %.0f deg, hear %.0f m, run %.1f m/s, territory %.0f m, %s" % [
			Species.name_of(species), Species.archetype(species),
			Species.sight_m(species), Species.sight_deg(species),
			Species.hear_m(species), Species.run_mps(species),
			Species.territory_m(species), Species.home(species)])
	return bad


## THE SENSES BUS: the cone, the loudness, and the calibration between them.
##
## Hard rule 4 says a creature perceives through this and nothing else, which
## makes these two functions the entire perceptual surface of every animal in
## the game. They are pure arithmetic and they get a real test, because the
## alternative is finding out from a five-run probe median that "the wolf never
## noticed anything" and not knowing which half was wrong.
func _test_senses_bus():
	var bad := 0

	# --- THE CONE. sight_deg is the FULL width, so 110 means 55 either side.
	var eye := Vector3(10.0, 4.0, 10.0)
	var north := Vector3(0.0, 0.0, -1.0)

	var cases := [
		# [label, target offset, sight_m, sight_deg, expected]
		["dead ahead, close", Vector3(0, 0, -10), 40.0, 110.0, true],
		["dead ahead, too far", Vector3(0, 0, -60), 40.0, 110.0, false],
		["dead behind", Vector3(0, 0, 10), 40.0, 110.0, false],
		["straight out to the side", Vector3(10, 0, 0), 40.0, 110.0, false],
		# 50 degrees off the nose is inside a 110 degree cone (55 either side)
		# and outside a 90 degree one (45 either side). This pair is the whole
		# off-by-two check: a half-angle bug passes the first and fails this.
		["50 deg off in a 110 cone", Vector3(0, 0, -10).rotated(Vector3.UP, deg_to_rad(50.0)),
			40.0, 110.0, true],
		["50 deg off in a 90 cone", Vector3(0, 0, -10).rotated(Vector3.UP, deg_to_rad(50.0)),
			40.0, 90.0, false],
		["60 deg off in a 110 cone", Vector3(0, 0, -10).rotated(Vector3.UP, deg_to_rad(60.0)),
			40.0, 110.0, false],
		# ALTITUDE IS IGNORED ON PURPOSE - the cone is flat. A target directly
		# above at close range is seen, and when that stops being right it is
		# because the eagle started asking.
		["overhead, near", Vector3(0, 30, -2), 40.0, 110.0, true],
		# Standing inside each other is seeing each other, not a normalise of
		# the zero vector.
		["exactly on top", Vector3.ZERO, 40.0, 110.0, true],
	]
	for c in cases:
		var got := SensesBus.can_see(eye, north, eye + (c[1] as Vector3),
			c[2], c[3])
		if got != c[4]:
			print("  cone: '%s' -> %s, wanted %s" % [c[0], got, c[4]])
			bad += 1

	# A creature facing nowhere sees nothing, rather than everything.
	if SensesBus.can_see(eye, Vector3.ZERO, eye + Vector3(0, 0, -5), 40.0, 110.0):
		print("  a creature with no facing could still see")
		bad += 1

	# --- LOUDNESS, AND THE CALIBRATION. The reference is a walking player, so
	# a listener's hear_m IS its range against one.
	var bus := SensesBus.new()
	var here := Vector3.ZERO
	var walker := {"peer": 7, "pos": Vector3(0, 0, -29.0),
		"vel": Vector3(0, 0, -4.0), "state": 1}
	bus.tick_player_noise([walker])
	if bus.hear_events_for(here, 30.0).is_empty():
		print("  a walking player at 29 m was inaudible to 30 m of hearing")
		bad += 1
	# ...and one metre past it is not.
	walker["pos"] = Vector3(0, 0, -31.0)
	bus.tick_player_noise([walker])
	if not bus.hear_events_for(here, 30.0).is_empty():
		print("  a walking player at 31 m was audible to 30 m of hearing")
		bad += 1

	# SPRINTING CARRIES HALF AGAIN AS FAR. This is the pair the whole
	# `senses-honest` scenario rests on: the same position, heard or not
	# heard depending only on what the player is doing.
	walker["pos"] = Vector3(0, 0, -40.0)
	walker["state"] = 1
	bus.tick_player_noise([walker])
	var walking_at_40 := bus.hear_events_for(here, 30.0).size()
	walker["state"] = 1 | 2
	walker["vel"] = Vector3(0, 0, -11.0)
	bus.tick_player_noise([walker])
	var sprinting_at_40 := bus.hear_events_for(here, 30.0).size()
	if not (walking_at_40 == 0 and sprinting_at_40 == 1):
		print("  at 40 m against 30 m hearing: walking heard %d, sprinting %d - wanted 0 and 1" % [
			walking_at_40, sprinting_at_40])
		bad += 1

	# A STILL PLAYER IS QUIET, NOT ABSENT. Stealth is a skill, not a switch.
	walker["pos"] = Vector3(0, 0, -8.0)
	walker["state"] = 1
	walker["vel"] = Vector3.ZERO
	bus.tick_player_noise([walker])
	if bus.hear_events_for(here, 30.0).is_empty():
		print("  a still player at 8 m was completely silent to 30 m of hearing")
		bad += 1

	# BETTER EARS SCALE ALL OF IT TOGETHER - the marmot's 45 m against the
	# wolf's 30 m, on one walking player at 40 m.
	walker["pos"] = Vector3(0, 0, -40.0)
	walker["vel"] = Vector3(0, 0, -4.0)
	bus.tick_player_noise([walker])
	if bus.hear_events_for(here, Species.hear_m(Species.MARMOT)).is_empty():
		print("  the marmot could not hear a walking player at 40 m")
		bad += 1
	# ...and the deaf eagle hears nothing at all, at any range.
	walker["pos"] = Vector3(0, 0, -1.0)
	bus.tick_player_noise([walker])
	if not bus.hear_events_for(here, Species.hear_m(Species.EAGLE)).is_empty():
		print("  the eagle heard something, and its hearing is 0 m on purpose")
		bad += 1

	# A PEER WHO LEFT STOPS MAKING NOISE. Without this a disconnected player is
	# an eternal sound at the place they vanished.
	bus.tick_player_noise([])
	if not bus.hear_events_for(here, 45.0).is_empty():
		print("  a player who left is still audible")
		bad += 1

	# TRANSIENTS EXPIRE. A noise is a moment, not a state.
	bus.emit_noise(Vector3(0, 0, -5.0), 30.0, "howl", 1)
	if bus.hear_events_for(here, 30.0).is_empty():
		print("  a howl 5 m away was not heard")
		bad += 1
	OS.delay_msec(SensesBus.TRANSIENT_MS + 60)
	bus.prune()
	if not bus.hear_events_for(here, 30.0).is_empty():
		print("  a howl was still audible %d ms later" % SensesBus.TRANSIENT_MS)
		bad += 1

	print("senses bus: %d cone cases, loudness calibrated at %.0f m reference" % [
		cases.size(), Species.NOISE["reference_m"]])
	return bad


## THE PACK BOARD reaches a second reader, and remembers.
##
## The point of the class is that a thing one creature learns is a thing every
## member knows without anybody sending a message, so the test holds the board
## from two sides - which is exactly how the pack holds it.
func _test_pack_board():
	var bad := 0

	var board := PackBoard.new(Species.WOLF)
	# A SECOND REFERENCE, not a copy. If PackBoard ever became a value type
	# this line is what would notice.
	var second_reader := board

	if board.target_peer != -1:
		print("  a fresh board already has a target")
		bad += 1
	if board.seconds_since_seen() != INF:
		print("  a board that has seen nothing reports a time since it did")
		bad += 1
	if board.has_howled():
		print("  a fresh board has already howled")
		bad += 1

	board.broadcast("spotted", {
		"id": 11, "pos": Vector3(1, 0, 1), "target": 42,
		"target_pos": Vector3(9, 0, 9), "range_m": 11.3,
	})
	if second_reader.target_peer != 42:
		print("  the second reader did not see the target: %d" % second_reader.target_peer)
		bad += 1
	if second_reader.target_pos != Vector3(9, 0, 9):
		print("  the second reader did not see where the target was")
		bad += 1
	if second_reader.seconds_since_seen() > 1.0:
		print("  the sighting did not stamp last_seen_ms")
		bad += 1

	# THE HOWL CARRIES A BEARING, and that bearing is what the flank is
	# measured off. A howl that did not record one would make every converge
	# an offset from zero, which is a direction in the world rather than a
	# direction relative to the target.
	board.broadcast("howl", {
		"id": 11, "pos": Vector3(1, 0, 1), "target": 42,
		"target_pos": Vector3(9, 0, 9), "bearing_deg": 45.0,
	})
	if not second_reader.has_howled() or second_reader.howl_bearing_deg != 45.0:
		print("  the howl did not reach the board: howled=%s bearing=%.1f" % [
			second_reader.has_howled(), second_reader.howl_bearing_deg])
		bad += 1

	# `lost` IS MEMORY, AND IT DELIBERATELY DOES NOT ERASE THE TARGET.
	# DESIGN.md rule 3: a pack keeps going to where you were.
	board.broadcast("lost", {"id": 11, "pos": Vector3(1, 0, 1),
		"target": 42, "seconds": 3.0})
	if second_reader.target_peer != 42 or second_reader.target_pos != Vector3(9, 0, 9):
		print("  losing sight erased the memory of the target")
		bad += 1

	# ...and leashing home does clear it, because the chase is over.
	board.forget_target()
	if second_reader.target_peer != -1 or second_reader.has_howled():
		print("  forget_target left a target or a howl behind")
		bad += 1

	# A BROADCAST WITH NO POSITION IS DROPPED, not silently written as the
	# origin - an event a director cannot place is worse than no event.
	board.broadcast("spotted", {"target": 5})
	if board.target_peer == 5:
		print("  a broadcast with no id/pos was applied anyway")
		bad += 1

	print("pack board: broadcast reaches a second reader, memory survives 'lost'")
	return bad


## CREATURE PATHS: the ridge, the territory, and the ground under a waypoint.
##
## Two parts, the `_test_body_promotion` shape, for the same reason that test
## gives. PART ONE is synthetic - a ridge built by hand, where the right answer
## is known in advance and "did the weight table do anything at all" has a
## yes-or-no answer. PART TWO is a real seed-42 territory, where the question
## is not what the path is but whether one exists and stays out of the rock.
func _test_creature_paths():
	var bad := 0

	# --- PART ONE: A KNOLL, AND THE CONTOUR ROUND IT.
	#
	# A cone in the middle of flat ground, with the two endpoints on opposite
	# sides of it so the straight line goes over the top. NOTHING HERE IS
	# SOLID - the knoll's slope is 37 degrees against a wolf's 55 degree limit
	# - and that is the whole point of the shape. The first version of this
	# test built a 15 m wall two cells wide, which slope_deg_at reads as a
	# cliff: the path went round it, the assertion passed, and it had measured
	# a WALL rather than a weight table. A test a broken weight table passes is
	# not a test.
	var cfg := WorldgenConfig.new()
	cfg.world_blocks_xz = 400
	var world := World.new()
	world.setup(1234, cfg)
	var hm: Heightmap = world.generator.heightmap

	var mid := hm.cols / 2
	var knoll := 20     # cells of radius
	var rise := 3.0     # blocks per cell -> 0.75 per block -> 36.9 degrees
	for j in hm.cols:
		for i in hm.cols:
			var d := Vector2(float(i - mid), float(j - mid)).length()
			var h := 30.0
			if d <= float(knoll):
				h += rise * (float(knoll) - d)
			hm.cells[i + j * hm.cols] = h

	var centre_cell := _cell_centre_m(hm, cfg, mid, mid)
	var nav := CreatureNav.build(world, Species.WOLF, _cell_centre_m(hm, cfg, mid - 30, mid))
	var start := _cell_centre_m(hm, cfg, mid - 25, mid)
	var finish := _cell_centre_m(hm, cfg, mid + 25, mid)
	var path := nav.path_m(start, finish)
	if path.is_empty():
		print("  no path across the knoll at all")
		bad += 1
	else:
		# Nothing being solid, the ONLY thing that can push the path off the
		# straight line is the weight table. So: how close to the summit did
		# it get? Inside 10 cells is the upper half of the knoll.
		var closest := INF
		for p in path:
			closest = minf(closest, Vector2(p.x - centre_cell.x, p.z - centre_cell.z).length())
		var closest_cells := closest / (float(hm.step) * cfg.block_size)
		print("creature paths: knoll path %d waypoints, closest approach to the summit %.1f cells (radius %d)" % [
			path.size(), closest_cells, knoll])
		if closest_cells < 10.0:
			print("  the wolf climbed the upper half of the knoll instead of contouring round it")
			bad += 1
		# ...and the weights are what did it.
		var on_slope := nav.weight_at_m(_cell_centre_m(hm, cfg, mid - 8, mid))
		var on_flat := nav.weight_at_m(_cell_centre_m(hm, cfg, mid - 40, mid))
		print("  weight on the knoll %.2f vs on the flat %.2f" % [on_slope, on_flat])
		if on_slope <= on_flat:
			print("  the knoll is not dearer than the flat - the weight table did nothing")
			bad += 1
		# And nothing on this shape may be solid, or the test is a wall again.
		if nav.solid_cells > 0:
			print("  %d cells of the knoll are solid - this shape is meant to be walkable throughout" % nav.solid_cells)
			bad += 1

	# THE SPECIES TABLE IS WHAT DECIDES, not the file. Same knoll, an animal
	# whose costs are flat: it should not pay nearly as much for the height.
	var flat_nav := CreatureNav.build(world, Species.EAGLE,
		_cell_centre_m(hm, cfg, mid - 30, mid))
	var wolf_cost := nav.weight_at_m(_cell_centre_m(hm, cfg, mid - 8, mid))
	var eagle_cost := flat_nav.weight_at_m(_cell_centre_m(hm, cfg, mid - 8, mid))
	print("  the same cell costs the wolf %.2f and the flat-costed eagle %.2f" % [
		wolf_cost, eagle_cost])
	if not (wolf_cost > eagle_cost):
		print("  the species table is not being read")
		bad += 1
	world.free()

	# --- PART TWO: A REAL TERRITORY ON SEED 42.
	#
	# Twenty random in-territory pairs. The question is not which way a path
	# goes - that is part one - but that one is found and that no waypoint is
	# standing in something the grid itself calls solid.
	var cfg2 := WorldgenConfig.new()
	var world2 := World.new()
	world2.setup(42, cfg2)
	# ON GROUND A DEN COULD ACTUALLY BE, which is the honest place to ask.
	# Stage 5 puts dens at 300 m or more from spawn in a 5-25 degree slope
	# band, so a territory centred on an arbitrary diagonal offset - the first
	# version picked spawn + (400, 400) - lands in whatever the seed put there
	# and reports a fact about that cell rather than about pathing.
	var centre := _den_like_ground(world2, cfg2)
	var nav2 := CreatureNav.build(world2, Species.WOLF, centre)
	print("  territory grid %dx%d cells, %d solid (%.1f%%), built in %d ms" % [
		nav2.region.size.x, nav2.region.size.y, nav2.solid_cells,
		100.0 * float(nav2.solid_cells) / maxf(float(nav2.total_cells), 1.0),
		nav2.build_ms])

	# A territory that is almost entirely solid would make every assertion
	# below vacuous, exactly as "0 boulders, 0 promoted" did in the body test.
	if nav2.solid_cells > nav2.total_cells / 2:
		print("  over half the territory is solid - part two proves nothing")
		bad += 1

	# Deterministic pairs, hashed rather than randf'd, so a failure can be
	# reproduced by reading this file.
	var found := 0
	var waypoints := 0
	var in_rock := 0
	var radius := Species.territory_m(Species.WOLF) * 0.9
	for k in 20:
		var a := centre + _hashed_offset(k * 2, radius)
		var b := centre + _hashed_offset(k * 2 + 1, radius)
		var p := nav2.path_m(a, b)
		if p.is_empty():
			continue
		found += 1
		waypoints += p.size()
		for w in p:
			if nav2.is_solid_at_m(w):
				in_rock += 1
	print("  %d of 20 in-territory pairs found a path, %d waypoints, %d in solid ground" % [
		found, waypoints, in_rock])
	if found < 20:
		print("  %d pairs found no path inside their own territory" % (20 - found))
		bad += 1
	if in_rock > 0:
		print("  %d waypoints landed on cells the grid calls solid" % in_rock)
		bad += 1
	world2.free()
	return bad


## The metre-space centre of a heightmap cell.
func _cell_centre_m(hm: Heightmap, cfg: WorldgenConfig, i: int, j: int) -> Vector3:
	return Vector3(
		float(hm.cell_to_block(i)) * cfg.block_size, 0.0,
		float(hm.cell_to_block(j)) * cfg.block_size)


## A repeatable offset inside a radius. Hashed, not rolled - a failing case
## must be findable again.
func _hashed_offset(k: int, radius: float) -> Vector3:
	var angle := WorldHash.hash01(k, 0, 42, 4001) * TAU
	var r := sqrt(WorldHash.hash01(k, 0, 42, 4002)) * radius
	return Vector3(cos(angle) * r, 0.0, sin(angle) * r)


## Ground of the kind Stage 5 will put a den on: at least 300 m from spawn and
## in the 5-25 degree slope band. Scanned on a coarse lattice, first match
## wins, so it is repeatable.
func _den_like_ground(world: World, cfg: WorldgenConfig) -> Vector3:
	var hm: Heightmap = world.generator.heightmap
	var spawn := world.spawn_position_m(0.0)
	for step in range(320, 1400, 40):
		for k in 16:
			var angle := TAU * float(k) / 16.0
			var p := spawn + Vector3(cos(angle), 0.0, sin(angle)) * float(step)
			var bx := p.x / cfg.block_size
			var bz := p.z / cfg.block_size
			if not hm.in_bounds(int(bx), int(bz)):
				continue
			var slope := hm.slope_deg_at(bx, bz)
			if slope >= 5.0 and slope <= 25.0:
				p.y = world.surface_height_m(int(bx), int(bz))
				return p
	return spawn
