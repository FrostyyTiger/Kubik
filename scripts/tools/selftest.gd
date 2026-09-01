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
		# UI V1 STAGE 2, appended at the end of the list.
		"ui mouse owners": _test_ui_mouse_owners,
		"stats table": _test_stats_table,
		# DISTANCE V4 STAGE 1, appended at the end of the list.
		"far parity": _test_far_parity,
		"far pyramid parity": _test_far_pyramid_parity,
		"far zone parity": _test_far_zone_parity,
		"far dispatch": _test_far_dispatch,
		# DISTANCE V5 STAGE 1, appended at the end of the list.
		"far slice parity": _test_far_slice_parity,
		# DISTANCE V5 STAGE 3, appended after it.
		"far geomorph parity": _test_far_geomorph_parity,
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
## DISTANCE V5 STAGE 1: AND UNTIL THE UPLOAD HAS LANDED. Since the handover is
## budgeted, a build finishing is no longer the moment the mesh is on screen -
## it is sixteen frames earlier - and a test that stopped at the old moment
## would read the vertex count of the build before it, which is precisely the
## bug this function was written for.
func _pump_far_field(far_field: Node) -> void:
	for i in 4000:
		far_field._process(0.0)
		if far_field._task == -1 and not far_field._has_pending \
				and int(far_field.stats()["upload_pending"]) == 0:
			return
		OS.delay_msec(2)
	print("  far field never went idle - a rebuild is stuck")


# --- UI V1 -------------------------------------------------------------------
#
# Appended at the end of the file, and nothing above it is touched. See
# docs/plans/ui-v1-tech.md, Territory: this file is shared and append-only.


## THE MOUSE IS OWNED BY A SET, NOT BY A BOOLEAN (ui v1 Stage 2).
##
## The bug this replaces is invisible from inside one screen and needs three to
## show itself: the F4 panel, the F8 panel and - from Stage 6 - the character
## sheet all want the cursor, and the boolean they used to share could not say
## "somebody else still wants it". Open two, close one, and the camera grabbed
## the pointer back with a panel still on screen.
##
## Headless-testable because UiMouse touches nothing but Input.mouse_mode,
## which is a no-op under --headless and not what is being asserted anyway. The
## assertion is about the SET.
func _test_ui_mouse_owners():
	var bad := 0
	UiMouse.clear()
	if UiMouse.held():
		print("  a cleared UiMouse still claims to hold the cursor")
		bad += 1

	# Two owners, and the whole point: releasing one leaves the other holding.
	var a := RefCounted.new()
	var b := RefCounted.new()
	UiMouse.claim(a)
	UiMouse.claim(b)
	if UiMouse.count() != 2:
		print("  two claims counted %d owners" % UiMouse.count())
		bad += 1
	UiMouse.release(a)
	if not UiMouse.held():
		print("  releasing one of two owners let go of the cursor - THE BUG")
		bad += 1
	if UiMouse.count() != 1:
		print("  one release of two claims left %d owners" % UiMouse.count())
		bad += 1

	# Release-all lets go.
	UiMouse.release(b)
	if UiMouse.held():
		print("  releasing every owner did not let go of the cursor")
		bad += 1

	# Claiming twice is one claim, so a screen that re-opens without closing
	# cannot leave a claim behind that nothing will ever release.
	UiMouse.claim(a)
	UiMouse.claim(a)
	if UiMouse.count() != 1:
		print("  claiming twice counted %d owners, not 1" % UiMouse.count())
		bad += 1
	# ...and one release is enough to undo it.
	UiMouse.release(a)
	if UiMouse.held():
		print("  a doubled claim needed two releases")
		bad += 1

	# Double-release of an owner that is already gone is harmless, and does not
	# reach into anybody else's claim.
	UiMouse.claim(b)
	UiMouse.release(a)
	UiMouse.release(a)
	if not UiMouse.held() or UiMouse.count() != 1:
		print("  releasing a non-owner disturbed the set: held %s, %d owners" % [
			UiMouse.held(), UiMouse.count()])
		bad += 1
	UiMouse.clear()

	print("ui mouse owners: claim/release set, %d checks failed" % bad)
	return 1 if bad > 0 else 0


## THE STATS TABLE, AND THE ONE MUTATION SEAM (ui v1 Stage 3).
##
## Every assertion here is about apply_delta, because apply_delta is the only
## thing in the game that writes a stat and the clamp and the journal are both
## inside it. A test that set a row directly would be testing a dictionary.
func _test_stats_table():
	var bad := 0
	var journal := Journal.new()
	var stats := StatsTable.new()
	stats.set_journal(journal)

	# A fresh row is the defaults, and the defaults are the maxima.
	stats.ensure_row(1)
	var row := stats.get_row(1)
	for stat in StatsTable.ORDER:
		if not is_equal_approx(float(row[stat]), float(StatsTable.DEFAULTS[stat])):
			print("  a fresh row has %s at %s, not the default %s" % [
				stat, row[stat], StatsTable.DEFAULTS[stat]])
			bad += 1
	if not stats.is_full(1):
		print("  a fresh row does not read as full")
		bad += 1

	# A REAL DELTA JOURNALS EXACTLY ONE EVENT, with from and to correct. This
	# is the shot driver's -30 and the H key's -10, so the numbers are the ones
	# every later stage's evidence is measured against.
	var before := journal.size()
	var left := stats.apply_delta(1, "hp", -30.0, "test")
	if not is_equal_approx(left, 70.0):
		print("  -30 from 100 left %s" % left)
		bad += 1
	if journal.size() != before + 1:
		print("  one delta wrote %d events" % (journal.size() - before))
		bad += 1
	var event: Dictionary = journal.dump()[journal.size() - 1]
	if event.get("kind") != "stat_changed" or event.get("stat") != "hp" \
			or not is_equal_approx(float(event.get("from", -1.0)), 100.0) \
			or not is_equal_approx(float(event.get("to", -1.0)), 70.0) \
			or event.get("peer") != 1 or event.get("cause") != "test":
		print("  the event a delta wrote is wrong: %s" % event)
		bad += 1
	if stats.is_full(1):
		print("  a hurt row still reads as full - the fade would never come in")
		bad += 1

	# A NO-OP DELTA JOURNALS NOTHING. Regen against a full bar at 20 Hz is the
	# case: 1200 identical events a minute is the same as no journal at all.
	before = journal.size()
	stats.apply_delta(1, "hp", 0.0, "noop")
	if journal.size() != before:
		print("  a zero delta wrote %d events" % (journal.size() - before))
		bad += 1
	# ...and neither does one that is clamped away against a full stat.
	stats.apply_delta(1, "sp", 40.0, "overheal")
	if journal.size() != before:
		print("  healing a full stat wrote %d events" % (journal.size() - before))
		bad += 1
	if not is_equal_approx(float(stats.get_row(1)["sp"]), 100.0):
		print("  healing past the maximum left sp at %s" % stats.get_row(1)["sp"])
		bad += 1

	# CLAMPED AT ZERO, and health at 0 does nothing else - there is no death
	# system, and the table's docstring says so.
	stats.apply_delta(1, "hp", -500.0, "test")
	if not is_equal_approx(float(stats.get_row(1)["hp"]), 0.0):
		print("  -500 clamped to %s, not 0" % stats.get_row(1)["hp"])
		bad += 1

	# The row is a COPY. Writing to what get_row hands back must not be a way
	# around the seam.
	var stolen := stats.get_row(1)
	stolen["hp"] = 999.0
	if not is_equal_approx(float(stats.get_row(1)["hp"]), 0.0):
		print("  writing to a handed-out row changed the table - the seam leaks")
		bad += 1

	# fraction_of() reads a row off the wire the same way it reads one here,
	# which is what lets a client draw the same bar from a synced dictionary.
	if not is_equal_approx(StatsTable.fraction_of({"hp": 70.0}, "hp"), 0.7):
		print("  fraction_of 70/100 is not 0.70")
		bad += 1
	# An absent stat draws FULL, not empty: a bar with no packet yet has not
	# been contradicted, and an empty health bar on join would read as a bug.
	if not is_equal_approx(StatsTable.fraction_of({}, "hp"), 1.0):
		print("  an empty row does not draw a full bar")
		bad += 1

	# erase() forgets a peer that left, so a stale row cannot be broadcast.
	stats.erase(1)
	if stats.has_row(1) or not stats.get_row(1).is_empty():
		print("  an erased peer still has a row")
		bad += 1

	print("stats table: seam, clamp and journal, %d checks failed" % bad)
	return 1 if bad > 0 else 0


# --- DISTANCE V4 -------------------------------------------------------------
#
# Appended at the end of the file, and nothing above it is touched.
#
# THE HARNESS EXISTS BEFORE THE PORT, which is the whole of Stage 1 and is the
# lesson ui v1's shot harness paid for: the class of bug a rewrite introduces
# is not the class the numbers catch. A 30x speedup that draws a slightly
# different mountain is not a speedup, it is a regression nobody measured, and
# by the time the pictures show it there are eight stages of C++ to bisect.
#
# So the comparison is wired in first and runs from Stage 1 onward, skipping
# itself while the C++ side is a stub and printing that it skipped - because a
# gate that silently passes when its subject is missing is the other way this
# goes wrong.


## THE TWO MESHERS AGREE, ARRAY FOR ARRAY. Distance v4 Stage 1, decision 3.
##
## Builds the same far mesh twice - once through `FarFieldJob` (GDScript, the
## reference) and once through `FarMesher` (the GDExtension) - and compares the
## four arrays. The default gate is IDENTICAL: same vertex count, same index
## buffer, zero max component difference. Both meshers compute in doubles and
## store into 32-bit packed arrays, and on one machine's libm the same
## expression rounds the same way, so "close enough" is not the bar and a stage
## that cannot hold exactness records WHICH expression and the measured worst
## diff rather than lowering it quietly.
##
## FOUR CASES, and each one is a thing the far probe cannot see:
##
##   * far_terrace 0.0 - the smooth mesh, hard rule 1's way back, no cell cache
##     and no riser in the whole build.
##   * far_terrace 1.0 - the terrace, the ridge test, the risers, and the
##     _t_full fast path the shipped config actually takes.
##   * far_ring_div 4 - the 1 m cell the whole night is for, at four times the
##     quads and a different base step in every derived radius.
##   * A NON-EMPTY FRONTIER. `_sector_exclude` is filled only when a frontier
##     is passed, and the far probe builds with an empty one - which is exactly
##     how distance v2 shipped a moved inner edge past seven stages of
##     "identical on every geometry row" (STATUS item 12). This harness is not
##     allowed to be blind in the same place.
func _test_far_parity():
	var bad := 0
	var cfg := WorldgenConfig.new()
	# The far terrace knob test's world, and for its reason: small enough that
	# a far mesh is a few thousand vertices rather than a hundred thousand.
	# This test is about AGREEMENT, and the cost of a real rebuild is Stage 6's.
	cfg.world_blocks_xz = 400
	cfg.view_distance = -1
	cfg.voxel_radius_chunks = 3
	cfg.fog_end_m = 90.0

	var world := World.new()
	world.setup(1234, cfg)
	var heightmap: Heightmap = world.generator.heightmap
	var generator: TerrainGenerator = world.generator
	var wcfg: WorldgenConfig = world.config

	var mesher := FarMesher.new()
	if not FarMesher.available() or not mesher.setup(heightmap, generator, wcfg):
		print("far parity: c++ mesher absent/stub, 0 checks")
		world.free()
		return 0

	var with_colors := FarMesher.colors_ready()
	# A frontier the voxels have only partly reached: three sectors short, the
	# rest at the full radius. Sixteen entries, in CHUNKS.
	var partial := PackedInt32Array()
	partial.resize(16)
	for s in 16:
		partial[s] = wcfg.voxel_radius_chunks
	partial[0] = 1
	partial[1] = 1
	partial[7] = 2

	var cases := [
		{"name": "terrace 0.0", "terrace": 0.0, "div": 2.0,
			"frontier": PackedInt32Array()},
		{"name": "terrace 1.0", "terrace": 1.0, "div": 2.0,
			"frontier": PackedInt32Array()},
		{"name": "ring_div 4", "terrace": 1.0, "div": 4.0,
			"frontier": PackedInt32Array()},
		{"name": "frontier", "terrace": 1.0, "div": 2.0,
			"frontier": partial},
		# THE PATHS THE SHIPPED CONFIG NEVER TAKES. far_vote is 0.0 and both
		# colour-jitter knobs are 0.0 by default, so the mode vote, its memo
		# and Block.jitter's whole hash path are dead code in every mesh this
		# project has built - and a gate that only ever ran the early return
		# would be testing nothing. Turned on here, and only here.
		{"name": "vote+jitter", "terrace": 1.0, "div": 2.0,
			"frontier": partial, "vote": 1.0, "jitter": true},
	]
	var checks := 0
	for c in cases:
		wcfg.far_terrace = c["terrace"]
		wcfg.far_ring_div = c["div"]
		wcfg.far_vote = float(c.get("vote", 0.0))
		wcfg.color_jitter_value = 0.06 if c.get("jitter", false) else 0.0
		wcfg.color_jitter_hue = 0.03 if c.get("jitter", false) else 0.0
		# THE OVERLAP IS A STATIC BOTH MESHERS READ, and it is derived from
		# far_ring_div through base_step_blocks() - so it has to be pushed
		# again whenever the divisor moves, on the main thread, exactly as
		# FarField does it.
		FarField.apply_overdraw(wcfg)
		var centre := Vector2i(0, 0)

		var job := FarFieldJob.new()
		job.heightmap = heightmap
		job.generator = generator
		job.config = wcfg
		job.center = centre
		job.frontier = c["frontier"]
		job.run()

		if not mesher.build(wcfg, centre, c["frontier"]):
			print("  %s: the c++ mesher refused to build" % c["name"])
			bad += 1
			continue
		checks += 1
		var d := _far_parity_diff(job, mesher, with_colors)
		print("  %-12s gd %6d verts / cpp %6d, %s" % [
			c["name"], job.vertex_count, mesher.vertex_count, d["text"]])
		if not d["ok"]:
			bad += 1

	print("far parity: %d checks, colours %s" % [
		checks, "compared" if with_colors else "SKIPPED (c++ emits white)"])
	world.free()
	return bad


## The four arrays, compared. Returns whether it passed and a line to print.
##
## Vertices, normals and colours are float32 in the packed arrays, so the
## comparison is a max ABSOLUTE component difference and the gate is that it
## is exactly zero. Indices are integers and are compared for equality, which
## is a stronger statement than any tolerance: a mesh with the same vertices in
## a different order is a different mesh.
func _far_parity_diff(job: FarFieldJob, mesher: FarMesher,
		with_colors: bool) -> Dictionary:
	var a: Array = job.arrays
	var b: Array = mesher.arrays
	if a.is_empty() or b.is_empty():
		return {"ok": a.is_empty() and b.is_empty(),
			"text": "one side emitted no arrays at all (gd %d, cpp %d)" % [
				a.size(), b.size()]}
	if job.vertex_count != mesher.vertex_count:
		return {"ok": false, "text": "VERTEX COUNTS DIFFER"}

	var va: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
	var vb: PackedVector3Array = b[Mesh.ARRAY_VERTEX]
	var na: PackedVector3Array = a[Mesh.ARRAY_NORMAL]
	var nb: PackedVector3Array = b[Mesh.ARRAY_NORMAL]
	var ia: PackedInt32Array = a[Mesh.ARRAY_INDEX]
	var ib: PackedInt32Array = b[Mesh.ARRAY_INDEX]
	if va.size() != vb.size() or na.size() != nb.size() or ia.size() != ib.size():
		return {"ok": false, "text": "ARRAY SIZES DIFFER: v %d/%d n %d/%d i %d/%d" % [
			va.size(), vb.size(), na.size(), nb.size(), ia.size(), ib.size()]}

	var dv := 0.0
	for k in va.size():
		var p := va[k]
		var q := vb[k]
		dv = maxf(dv, maxf(absf(p.x - q.x), maxf(absf(p.y - q.y), absf(p.z - q.z))))
	var dn := 0.0
	for k in na.size():
		var p := na[k]
		var q := nb[k]
		dn = maxf(dn, maxf(absf(p.x - q.x), maxf(absf(p.y - q.y), absf(p.z - q.z))))
	var bad_i := 0
	for k in ia.size():
		if ia[k] != ib[k]:
			bad_i += 1
	var dc := 0.0
	if with_colors:
		var ca: PackedColorArray = a[Mesh.ARRAY_COLOR]
		var cb: PackedColorArray = b[Mesh.ARRAY_COLOR]
		if ca.size() != cb.size():
			return {"ok": false, "text": "COLOUR ARRAY SIZES DIFFER: %d/%d" % [
				ca.size(), cb.size()]}
		for k in ca.size():
			var p := ca[k]
			var q := cb[k]
			dc = maxf(dc, maxf(absf(p.r - q.r),
				maxf(absf(p.g - q.g), maxf(absf(p.b - q.b), absf(p.a - q.a)))))

	var ok := dv == 0.0 and dn == 0.0 and bad_i == 0 and dc == 0.0
	var text := "max diff pos %.9f normal %.9f colour %s, %d indices differ" % [
		dv, dn, ("%.9f" % dc) if with_colors else "-", bad_i]
	return {"ok": ok, "text": text}


## THE PYRAMID CROSSES, EXPRESSION BY EXPRESSION. Distance v4 Stage 2.
##
## Ten thousand random (x, z, level) triples through five functions, C++ against
## GDScript, and the gate is EXACT - not "close", not a tolerance. Both sides
## compute in doubles off the same float32 arrays, and on one machine's libm the
## same expression rounds the same way, so a difference here is a difference in
## the expression and nothing else.
##
## THE SAMPLES DELIBERATELY GO OUTSIDE THE WORLD. Both implementations clamp,
## and a clamp is exactly the kind of edge a transcription gets subtly wrong -
## `mini(i0 + 1, cols - 1)` against `i0 + 1 < cols - 1 ? ... : ...` are the same
## function and only one of them is obviously so. A quarter of the range is off
## the map on each axis.
##
## LEVELS ARE CONTINUOUS, and half of them land within 0.0001 of an integer on
## purpose: that is `_trilinear`'s early-out, and the branch either side of it
## is where a level would silently become a different level.
func _test_far_pyramid_parity():
	var bad := 0
	if not FarMesher.class_present():
		print("far pyramid parity: c++ mesher absent, 0 checks")
		return 0

	var cfg := WorldgenConfig.new()
	cfg.world_blocks_xz = 400
	cfg.view_distance = -1
	cfg.voxel_radius_chunks = 3
	cfg.fog_end_m = 90.0
	var world := World.new()
	world.setup(1234, cfg)
	var heightmap: Heightmap = world.generator.heightmap
	var wcfg: WorldgenConfig = world.config

	var mesher := FarMesher.new()
	if not mesher.setup(heightmap, world.generator, wcfg):
		print("  the c++ mesher would not take the world")
		world.free()
		return 1

	var rng := RandomNumberGenerator.new()
	rng.seed = 424242
	var half := float(cfg.world_blocks_xz) * 0.5
	var worst := {"height": 0.0, "filtered": 0.0, "max": 0.0, "peak": 0.0,
		"slope": 0.0}
	var n := 10000
	for k in n:
		# Half again outside the map on each axis, so the clamps are exercised.
		var bx := rng.randf_range(-half * 1.5, half * 1.5)
		var bz := rng.randf_range(-half * 1.5, half * 1.5)
		var level := rng.randf_range(0.0, float(Heightmap.MAX_LEVEL))
		if k % 2 == 0:
			# Land on an integer level, which is _trilinear's early-out.
			level = float(rng.randi_range(0, Heightmap.MAX_LEVEL))
		worst["height"] = maxf(worst["height"],
			absf(heightmap.height_at(bx, bz) - mesher.h_at(bx, bz)))
		worst["filtered"] = maxf(worst["filtered"],
			absf(heightmap.height_filtered(bx, bz, level)
				- mesher.h_filtered(bx, bz, level)))
		worst["max"] = maxf(worst["max"],
			absf(heightmap.height_max_filtered(bx, bz, level)
				- mesher.h_max_filtered(bx, bz, level)))
		worst["peak"] = maxf(worst["peak"],
			absf(FarFieldJob.filtered_height(heightmap, wcfg, bx, bz, level)
				- mesher.h_peak(bx, bz, level)))
		worst["slope"] = maxf(worst["slope"],
			absf(heightmap.slope_deg_at(bx, bz) - mesher.h_slope_deg(bx, bz)))

	for key in worst:
		if worst[key] != 0.0:
			print("  %s differs: max %.17f over %d samples" % [key, worst[key], n])
			bad += 1
	print("far pyramid parity: %d samples x 5 functions, max diff %.17f" % [
		n, maxf(maxf(worst["height"], worst["filtered"]),
			maxf(worst["max"], maxf(worst["peak"], worst["slope"])))])
	world.free()
	return bad


## ZONE AND COLOUR CROSS, EXPRESSION BY EXPRESSION. Distance v4 Stage 4,
## decision 4's micro-gate.
##
## Ten thousand random samples per function, C++ against GDScript, exact.
##
## THE LADDER LANDED ON RUNG (a), and the plan's own wording is worth holding it
## to. `backdrop_zone`, `zone_at`, `_slope_zone`, `wildness_at`, `band_color`,
## `band_m_at`, `treeline_band`, `Block.color_of`, `Block.aspect_shade`,
## `Block.jitter` and `Look.to_wire` are pure functions of altitude, a slope
## read off level 0, a hash and config scalars, and they are ported.
##
## ONE FUNCTION IS NOT PURE and it is `zone_jitter_at`, which ring 0's
## `surface_zone_at` needs: a FastNoiseLite sample. It is neither rung (a) as
## written nor rung (b) - no grid is precomputed - because FastNoiseLite is an
## ENGINE class and the mesher holds the very same object the generator built,
## calling get_noise_2d on it natively. Decision 2's "never calls back into
## GDScript during a build" holds exactly, and the noise is bit-identical by
## construction rather than by a reimplementation. `detail_at` crossed the same
## way in Stage 3. It is recorded here and in the status doc because it is a
## third rung the plan did not name, not because it is a compromise.
##
## THE JITTER KNOBS ARE TURNED UP FOR THIS TEST, and that is deliberate:
## color_jitter_value and color_jitter_hue both ship at 0.0, so Block.jitter's
## whole hash path returns early in every mesh this project has ever built. A
## gate that only ever exercised the early return would be testing nothing.
func _test_far_zone_parity():
	var bad := 0
	if not FarMesher.class_present():
		print("far zone parity: c++ mesher absent, 0 checks")
		return 0

	var cfg := WorldgenConfig.new()
	cfg.world_blocks_xz = 400
	cfg.view_distance = -1
	cfg.voxel_radius_chunks = 3
	cfg.fog_end_m = 90.0
	var world := World.new()
	world.setup(1234, cfg)
	var generator: TerrainGenerator = world.generator
	var heightmap: Heightmap = generator.heightmap
	var wcfg: WorldgenConfig = world.config
	# See the note above: the shipped defaults are 0.0 and would test the early
	# return and nothing else.
	wcfg.color_jitter_value = 0.06
	wcfg.color_jitter_hue = 0.03

	var mesher := FarMesher.new()
	if not mesher.setup(heightmap, generator, wcfg):
		print("  the c++ mesher would not take the world")
		world.free()
		return 1

	var rng := RandomNumberGenerator.new()
	rng.seed = 987654
	var half := float(cfg.world_blocks_xz) * 0.5
	var n := 10000
	var diff := {
		"backdrop_zone": 0, "surface_zone_at": 0, "treeline_band": 0,
		"band_m_at": 0.0, "band_color": 0.0, "aspect_shade": 0.0, "vertex": 0.0,
	}
	for k in n:
		var bx := rng.randi_range(int(-half * 1.2), int(half * 1.2))
		var bz := rng.randi_range(int(-half * 1.2), int(half * 1.2))
		var alt := rng.randf_range(cfg.min_altitude - 20.0, cfg.max_altitude + 20.0)
		if FarFieldJob.backdrop_zone(generator, bx, bz, alt) \
				!= mesher.z_backdrop(bx, bz, alt):
			diff["backdrop_zone"] += 1
		if generator.surface_zone_at(bx, bz, alt) != mesher.z_surface(bx, bz, alt):
			diff["surface_zone_at"] += 1

		var band_m := rng.randf_range(1.0, 90.0)
		if FarFieldJob.treeline_band(generator, wcfg, band_m) \
				!= mesher.c_treeline_band(band_m):
			diff["treeline_band"] += 1
		var step_blocks := rng.randi_range(1, 256)
		var terrace := rng.randf_range(-0.2, 1.2)
		diff["band_m_at"] = maxf(diff["band_m_at"],
			absf(FarFieldJob.band_m_at(wcfg, step_blocks, terrace)
				- mesher.c_band_m_at(step_blocks, terrace)))

		var zone := rng.randi_range(0, TerrainGenerator.ZONE_COUNT - 1)
		var color := Block.color_of(TerrainGenerator.ZONE_SURFACE[zone])
		var y_m := rng.randf_range(-50.0, 500.0)
		var tl := rng.randi_range(0, 12)
		diff["band_color"] = maxf(diff["band_color"], _color_diff(
			FarFieldJob.band_color(color, y_m, wcfg, tl, band_m),
			mesher.c_band_color(color, y_m, tl, band_m)))

		var normal := Vector3(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0),
			rng.randf_range(-1.0, 1.0))
		if normal.length_squared() > 0.0:
			normal = normal.normalized()
		else:
			normal = Vector3.UP
		diff["aspect_shade"] = maxf(diff["aspect_shade"], _color_diff(
			Block.aspect_shade(color, normal, wcfg.slope_tint, wcfg.aspect_tint),
			mesher.c_aspect_shade(color, normal)))

		var point := Vector3(rng.randf_range(-500.0, 500.0),
			rng.randf_range(-50.0, 400.0), rng.randf_range(-500.0, 500.0))
		var inv_bs := 1.0 / wcfg.block_size
		var gd := Look.to_wire(Block.jitter(
			Block.aspect_shade(color, normal, wcfg.slope_tint, wcfg.aspect_tint),
			int(round(point.x * inv_bs)), int(round(point.z * inv_bs)),
			generator.world_seed, wcfg.color_jitter_blocks,
			wcfg.color_jitter_value, wcfg.color_jitter_hue))
		diff["vertex"] = maxf(diff["vertex"], _color_diff(gd,
			mesher.c_vertex(color, normal, point)))

	for key in diff:
		if diff[key] != 0 and diff[key] != 0.0:
			print("  %s differs: %s over %d samples" % [key, diff[key], n])
			bad += 1
	print("far zone parity: %d samples x 7 functions, %s" % [
		n, "all identical" if bad == 0 else "%d FUNCTIONS DIFFER" % bad])
	world.free()
	return bad


func _color_diff(a: Color, b: Color) -> float:
	return maxf(absf(a.r - b.r), maxf(absf(a.g - b.g),
		maxf(absf(a.b - b.b), absf(a.a - b.a))))


## THE DISPATCH, BOTH WAYS, THROUGH THE REAL FarField. Distance v4 Stage 5.
##
## The parity test compares two meshers built side by side from the same
## inputs. This one asks the different question: does the NODE that the game
## actually uses pick the right one, hand it the right world, and put the same
## mesh on screen either way? Those are separable, and the second is where a
## dispatch goes wrong - a mesher handed a stale config, a frontier that did
## not cross, a knob that reaches the snapshot but not the job.
##
## So it drives `far_cpp` from 1 to 0 and back through `apply_far_knobs` -
## which is the F4 panel's own path, not a private one - and compares the mesh
## Godot ends up holding, vertex for vertex.
##
## WITH NO COMPILED LIBRARY this still runs and still means something: both
## legs report `gdscript`, the meshes still have to match, and the knob still
## must not break a rebuild. That is hard rule 1 checked rather than assumed.
func _test_far_dispatch():
	var bad := 0
	var cfg := WorldgenConfig.new()
	cfg.world_blocks_xz = 400
	cfg.view_distance = -1
	cfg.voxel_radius_chunks = 3
	cfg.fog_end_m = 90.0

	var world := World.new()
	world.setup(1234, cfg)
	var far_field: Node = world.get_node_or_null("FarField")
	if far_field == null:
		print("  far dispatch: World has no FarField child")
		world.free()
		return 1
	_pump_far_field(far_field)

	var legs := []
	for value in [1.0, 0.0, 1.0]:
		cfg.far_cpp = value
		# The F4 panel's own path. Returning the fallback means nothing moved,
		# which on the first leg is correct - setup() already snapshotted 1.0.
		FarField.apply_far_knobs(world, null, cfg, "FALLBACK")
		_pump_far_field(far_field)
		var stats: Dictionary = far_field.stats()
		legs.append({
			"knob": value,
			"mesher": stats.get("mesher", "?"),
			"verts": int(stats.get("vertices", 0)),
			"build_ms": int(stats.get("build_ms", 0)),
			"arrays": _far_mesh_arrays(far_field),
		})

	var available: bool = bool(far_field.stats().get("cpp_available", false))
	for leg in legs:
		print("  far_cpp %.0f -> %-8s %d verts, %d ms build" % [
			leg["knob"], leg["mesher"], leg["verts"], leg["build_ms"]])

	# 1. The knob picks the mesher it says it picks.
	var want_on := "c++" if available else "gdscript"
	if legs[0]["mesher"] != want_on or legs[2]["mesher"] != want_on:
		print("  far_cpp 1 built through %s / %s, not %s" % [
			legs[0]["mesher"], legs[2]["mesher"], want_on])
		bad += 1
	if legs[1]["mesher"] != "gdscript":
		print("  far_cpp 0 built through %s, not gdscript" % legs[1]["mesher"])
		bad += 1

	# 2. And it is the SAME MESH either way, vertex for vertex. This is the
	# parity gate again, through the node rather than beside it.
	for k in [1, 2]:
		if legs[k]["verts"] != legs[0]["verts"]:
			print("  leg %d emitted %d vertices against leg 0's %d" % [
				k, legs[k]["verts"], legs[0]["verts"]])
			bad += 1
		var d := _far_arrays_diff(legs[0]["arrays"], legs[k]["arrays"])
		if d != 0.0:
			print("  leg %d differs from leg 0 by %.9f" % [k, d])
			bad += 1

	print("far dispatch: %s, three legs, meshes identical" % [
		"c++ present" if available else "no c++ library, gdscript both ways"])
	world.free()
	return bad


## The arrays of the mesh FarField is actually holding, read back off the
## Mesh rather than off the job - the job is gone by the time _process has
## applied it, and what is on screen is the thing being compared.
## DISTANCE V5 STAGE 1: EVERY SURFACE, CONCATENATED. The far mesh is one
## surface per frontier sector now, so surface 0 alone is a sixteenth of the
## far country and comparing it would have quietly stopped checking the rest.
func _far_mesh_arrays(far_field: Node) -> Array:
	var m: Mesh = far_field.mesh
	if m == null or m.get_surface_count() == 0:
		return []
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	for k in m.get_surface_count():
		var a := m.surface_get_arrays(k)
		var base := verts.size()
		verts.append_array(a[Mesh.ARRAY_VERTEX])
		normals.append_array(a[Mesh.ARRAY_NORMAL])
		if a[Mesh.ARRAY_COLOR] != null:
			colors.append_array(a[Mesh.ARRAY_COLOR])
		for i in (a[Mesh.ARRAY_INDEX] as PackedInt32Array):
			indices.append(i + base)
	var out := []
	out.resize(Mesh.ARRAY_MAX)
	out[Mesh.ARRAY_VERTEX] = verts
	out[Mesh.ARRAY_NORMAL] = normals
	out[Mesh.ARRAY_COLOR] = colors
	out[Mesh.ARRAY_INDEX] = indices
	return out


func _far_arrays_diff(a: Array, b: Array) -> float:
	if a.is_empty() or b.is_empty():
		return 0.0 if a.is_empty() and b.is_empty() else 1.0
	var va: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
	var vb: PackedVector3Array = b[Mesh.ARRAY_VERTEX]
	if va.size() != vb.size():
		return 1.0
	var worst := 0.0
	for k in va.size():
		var p := va[k]
		var q := vb[k]
		worst = maxf(worst, maxf(absf(p.x - q.x),
			maxf(absf(p.y - q.y), absf(p.z - q.z))))
	return worst


# --- DISTANCE V5 -------------------------------------------------------------
#
# Appended at the end of the file, and nothing above it is touched.


## THE SLICES ARE THE SAME MESH. Distance v5 Stage 1, decision 2.
##
## The upload is split along the frontier sector so it can be paid for a frame
## at a time, and the whole risk of that is that the far country quietly stops
## being the same far country. So: build the mesh both ways at the same centre
## with the same config, and check that the slices between them hold EXACTLY
## the reference build's quads - every one, once each, every position, normal
## and colour bit-identical, and every slice's index buffer the quad pattern
## over its own vertices.
##
## WHY IT IS A MULTISET MATCH AND NOT A DIFF OF TWO ARRAYS, which is what the
## plan's decision 2 asks for in as many words.
##
## Grouping the quads by sector REORDERS them - that is what grouping is - so
## the reference has to be put in the same order before a byte-for-byte diff
## means anything, and putting it in that order means knowing which sector each
## reference quad went to. That is recoverable for a ground quad, whose four
## corners span its cell, and it is NOT recoverable for a RISER: a riser's four
## corners span a cell EDGE, and the two cells either side of that edge can be
## in different sectors. Written the naive way this test failed at
## far_terrace 1.0 with a max position difference of exactly 100 blocks - both
## meshers agreeing with each other and neither with the harness.
##
## So the comparison is: index the reference's quads by a hash of their twelve
## position components, then consume one for every quad the slices emit,
## checking the whole record - positions, normals and colours - on the way. A
## quad the slices emit that the reference does not have, or emits twice, or
## leaves behind, is a failure. That is exactly the claim decision 2 is
## protecting ("the slicing must not change the union"), stated in the only
## form the output can carry, and it is exact rather than a tolerance.
##
## Both meshers, because a slice mode that is right in C++ and wrong in
## GDScript is a fallback that draws a different world.
func _test_far_slice_parity():
	var bad := 0
	var cfg := WorldgenConfig.new()
	cfg.world_blocks_xz = 400
	cfg.view_distance = -1
	cfg.voxel_radius_chunks = 3
	cfg.fog_end_m = 90.0

	var world := World.new()
	world.setup(1234, cfg)
	var heightmap: Heightmap = world.generator.heightmap
	var generator: TerrainGenerator = world.generator
	var wcfg: WorldgenConfig = world.config

	var mesher := FarMesher.new()
	var have_cpp := FarMesher.available() and mesher.setup(heightmap, generator, wcfg)

	# The same partial frontier the parity test uses: three sectors short, the
	# rest at the full radius. A slice test with an empty frontier would never
	# exercise the per-sector hole, which is the one thing that can make two
	# sectors legitimately different sizes.
	var partial := PackedInt32Array()
	partial.resize(16)
	for k in 16:
		partial[k] = wcfg.voxel_radius_chunks
	partial[0] = 1
	partial[1] = 1
	partial[7] = 2

	var cases := [
		{"name": "terrace 0.0", "terrace": 0.0, "div": 2.0,
			"frontier": PackedInt32Array()},
		{"name": "terrace 1.0", "terrace": 1.0, "div": 2.0,
			"frontier": PackedInt32Array()},
		{"name": "ring_div 4", "terrace": 1.0, "div": 4.0,
			"frontier": PackedInt32Array()},
		{"name": "frontier", "terrace": 1.0, "div": 2.0, "frontier": partial},
	]
	var centre := Vector2i(0, 0)
	var checks := 0
	for c in cases:
		wcfg.far_terrace = c["terrace"]
		wcfg.far_ring_div = c["div"]
		FarField.apply_overdraw(wcfg)

		# The reference: the whole mesh, exactly as this project has emitted it
		# since terrain v1.
		var ref := FarFieldJob.new()
		ref.heightmap = heightmap
		ref.generator = generator
		ref.config = wcfg
		ref.center = centre
		ref.frontier = c["frontier"]
		ref.run()
		var want := _slice_index(ref.arrays)

		var sliced := FarFieldJob.new()
		sliced.heightmap = heightmap
		sliced.generator = generator
		sliced.config = wcfg
		sliced.center = centre
		sliced.frontier = c["frontier"]
		sliced.slice = true
		sliced.run()
		checks += 1
		var d := _slice_match(ref.arrays, want, sliced.slices)
		print("  %-12s gdscript %6d verts in %2d slices, %s" % [
			c["name"], sliced.vertex_count, sliced.slices.size(), d["text"]])
		if not d["ok"] or sliced.vertex_count != ref.vertex_count:
			bad += 1

		if not have_cpp:
			continue
		if not mesher.build(wcfg, centre, c["frontier"], true):
			print("  %s: the c++ mesher refused to build sliced" % c["name"])
			bad += 1
			continue
		var dc := _slice_match(ref.arrays, want, mesher.slices)
		print("  %-12s c++      %6d verts in %2d slices, %s" % [
			c["name"], mesher.vertex_count, mesher.slices.size(), dc["text"]])
		if not dc["ok"] or mesher.vertex_count != ref.vertex_count:
			bad += 1

	print("far slice parity: %d checks, c++ %s" % [
		checks, "compared" if have_cpp else "ABSENT (gdscript only)"])
	world.free()
	return bad


## The reference build's quads, indexed by a hash of their twelve position
## components. One entry per distinct footprint, holding every quad that has
## it - the two windings of a two-sided riser share a footprint, and so do a
## riser and the skirt over it.
func _slice_index(arrays: Array) -> Dictionary:
	var out := {}
	if arrays.is_empty():
		return out
	var va: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	for q in va.size() / 4:
		var key := _slice_key(va, q)
		# READ, APPEND, WRITE BACK - and the write back is the point.
		# `(out[key] as PackedInt32Array).append(q)` appends to a COPY: a
		# packed array read out of a Dictionary through a cast is a value, not
		# the container's own. Written that way this index silently kept only
		# the FIRST quad of every repeated footprint - a two-sided riser and
		# the skirt over it share one - and the test reported sixteen unmatched
		# quads and sixteen left over, symmetric and repeatable, with both
		# meshers agreeing and every component difference at zero.
		var list: PackedInt32Array = out.get(key, PackedInt32Array())
		list.append(q)
		out[key] = list
	return out


func _slice_key(va: PackedVector3Array, q: int) -> int:
	var f := PackedFloat32Array()
	f.resize(12)
	for k in 4:
		var p := va[q * 4 + k]
		f[k * 3] = p.x
		f[k * 3 + 1] = p.y
		f[k * 3 + 2] = p.z
	return hash(f)


## Every quad the slices emit, matched against the reference exactly once.
func _slice_match(arrays: Array, index: Dictionary, slices: Array) -> Dictionary:
	if arrays.is_empty():
		var empty := true
		for a in slices:
			if not (a as Array).is_empty():
				empty = false
		return {"ok": empty, "text": "the reference emitted nothing"}
	var va: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var na: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var ca: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	# One tick per reference quad. A quad matched twice is as much a failure as
	# one never matched, and without this a slicer that emitted the same sector
	# sixteen times would pass on count alone.
	#
	# FILLED, NOT MERELY RESIZED. `PackedByteArray.resize()` does not zero the
	# new bytes, and the first run of this test reported sixteen unmatched
	# quads and sixteen left over - a perfectly symmetric, perfectly repeatable
	# failure that both meshers agreed on - because sixteen reference quads
	# started out already ticked. The mesh was right the whole time.
	var used := PackedByteArray()
	used.resize(va.size() / 4)
	used.fill(0)

	var seen := 0
	var unmatched := 0
	var bad_indices := 0
	for a in slices:
		var arr: Array = a
		if arr.is_empty():
			continue
		var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var n: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
		var c: PackedColorArray = arr[Mesh.ARRAY_COLOR]
		var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
		if idx.size() != v.size() / 4 * 6:
			bad_indices += 1
		for q in v.size() / 4:
			seen += 1
			if idx.size() == v.size() / 4 * 6 \
					and (idx[q * 6] != q * 4 or idx[q * 6 + 1] != q * 4 + 1
						or idx[q * 6 + 2] != q * 4 + 2 or idx[q * 6 + 3] != q * 4
						or idx[q * 6 + 4] != q * 4 + 2 or idx[q * 6 + 5] != q * 4 + 3):
				bad_indices += 1
			var key := _slice_key(v, q)
			if not index.has(key):
				unmatched += 1
				continue
			var found := false
			var candidates: PackedInt32Array = index[key]
			for r in candidates:
				if used[r] != 0:
					continue
				if not _slice_quad_equal(va, na, ca, r, v, n, c, q):
					continue
				used[r] = 1
				found = true
				break
			if not found:
				unmatched += 1
				if unmatched <= 3:
					_slice_report_miss(va, na, ca, index, key, v, n, c, q)

	var left := 0
	for u in used:
		if u == 0:
			left += 1
	var ok := unmatched == 0 and left == 0 and bad_indices == 0 \
		and seen == va.size() / 4
	return {"ok": ok,
		"text": "%d quads, %d unmatched, %d reference quads left over, %d bad index buffers%s" % [
			seen, unmatched, left, bad_indices, "" if ok else "  FAILED"]}


## WHAT A MISS ACTUALLY LOOKS LIKE. A count of unmatched quads says the
## slicing changed something and never what, and "what" is the only thing a
## failing gate is for. Prints the slice quad and the reference quad with the
## same footprint beside it, field by field.
func _slice_report_miss(va: PackedVector3Array, na: PackedVector3Array,
		ca: PackedColorArray, index: Dictionary, key: int,
		v: PackedVector3Array, n: PackedVector3Array, c: PackedColorArray,
		q: int) -> void:
	if not index.has(key):
		print("    miss: p0 %v - no reference quad has this footprint at all" % [
			v[q * 4]])
		return
	var candidates: PackedInt32Array = index[key]
	for r in candidates:
		var dp := 0.0
		var dn := 0.0
		var dc := 0.0
		for k in 4:
			dp = maxf(dp, (va[r * 4 + k] - v[q * 4 + k]).length())
			dn = maxf(dn, (na[r * 4 + k] - n[q * 4 + k]).length())
			var e := ca[r * 4 + k]
			var f := c[q * 4 + k]
			dc = maxf(dc, maxf(absf(e.r - f.r), maxf(absf(e.g - f.g),
				absf(e.b - f.b))))
		print("    miss: p0 %v vs ref %d: pos %.9f normal %.9f colour %.9f" % [
			v[q * 4], r, dp, dn, dc])


## One quad, component for component. Exact: both sides are float32 in packed
## arrays and both came out of the same expression, so anything but equality is
## the slicing having changed a number.
func _slice_quad_equal(va: PackedVector3Array, na: PackedVector3Array,
		ca: PackedColorArray, r: int, v: PackedVector3Array,
		n: PackedVector3Array, c: PackedColorArray, q: int) -> bool:
	for k in 4:
		if va[r * 4 + k] != v[q * 4 + k]:
			return false
		if na[r * 4 + k] != n[q * 4 + k]:
			return false
		if ca[r * 4 + k] != c[q * 4 + k]:
			return false
	return true


## THE GEOMORPH, ON A WORLD BIG ENOUGH TO HAVE A RING BOUNDARY IN IT. Distance
## v5 Stage 3.
##
## THIS TEST EXISTS BECAUSE THE OTHER TWO CANNOT SEE THE THING IT TESTS, and
## that was found by writing it rather than by reasoning about it. `far parity`
## and `far slice parity` build a 400-block world at `fog_end_m` 90, where the
## far radius is 216 blocks and ring 0's nominal outer edge is 300 - so ring 0
## is clamped to the fog, it is the only ring drawn, there is no boundary, and
## `_t_geo` is zero in every case. Both gates came back exact on the night the
## geomorph landed and **neither had executed one line of it**. That is STATUS
## item 13's lesson at a different address: a gate that is structurally blind
## to a mechanism passes it forever.
##
## So: a world with a ring boundary inside the fog, and three questions.
##
##   1. The two meshers agree, exactly, WITH the geomorph on. Decision 2 - a
##      mesh-output change lands in both meshers in the same commit or in
##      neither, and this is what says it did.
##   2. The slices are still the reference build's own quads, with it on.
##   3. **It actually does something.** `far_geomorph_cells` 0 against 2 must
##      produce a DIFFERENT mesh, or the two gates above are measuring a knob
##      that is not wired to anything - which is exactly how distance v2's
##      far_terrace test passed while the knob reached nothing.
func _test_far_geomorph_parity():
	var bad := 0
	var cfg := WorldgenConfig.new()
	# BIG ENOUGH TO HAVE A BOUNDARY IN IT, and no bigger. far_radius is
	# fog_end_m / block_size * FOG_MARGIN = 480 blocks, so ring 0's outer edge
	# at 300 blocks is a real handover to ring 1 and gets the geomorph, while
	# ring 1's own outer edge is the fog and does not. The world is wide enough
	# that the whole of ring 0's band is in bounds.
	cfg.world_blocks_xz = 1400
	cfg.view_distance = -1
	cfg.voxel_radius_chunks = 3
	cfg.fog_end_m = 200.0
	cfg.far_terrace = 1.0
	cfg.far_ring_div = 2.0

	var world := World.new()
	world.setup(4242, cfg)
	var heightmap: Heightmap = world.generator.heightmap
	var generator: TerrainGenerator = world.generator
	var wcfg: WorldgenConfig = world.config
	FarField.apply_overdraw(wcfg)
	var centre := Vector2i(0, 0)

	var mesher := FarMesher.new()
	var have_cpp := FarMesher.available() and mesher.setup(heightmap, generator, wcfg)

	var meshes := {}
	for cells in [0.0, 4.0]:
		wcfg.far_geomorph_cells = cells
		var job := FarFieldJob.new()
		job.heightmap = heightmap
		job.generator = generator
		job.config = wcfg
		job.center = centre
		job.run()
		meshes[cells] = job.arrays
		print("  far_geomorph_cells %.0f: %d verts" % [cells, job.vertex_count])
		if not have_cpp:
			continue
		if not mesher.build(wcfg, centre, PackedInt32Array()):
			print("  the c++ mesher refused to build at far_geomorph_cells %.0f" % cells)
			bad += 1
			continue
		var d := _far_parity_diff(job, mesher, FarMesher.colors_ready())
		print("    gd %6d / cpp %6d, %s" % [
			job.vertex_count, mesher.vertex_count, d["text"]])
		if not d["ok"]:
			bad += 1
		# And the slices, with the geomorph on, on a world that has a boundary.
		if not mesher.build(wcfg, centre, PackedInt32Array(), true):
			print("  the c++ mesher refused to build sliced")
			bad += 1
			continue
		var m := _slice_match(job.arrays, _slice_index(job.arrays), mesher.slices)
		print("    slices: %s" % m["text"])
		if not m["ok"]:
			bad += 1

	# 3. THE KNOB IS WIRED TO SOMETHING.
	#
	# THE COMPARISON IS OF SETS, NOT OF INDEX k AGAINST INDEX k. Turning the
	# geomorph on changes the height of the cells near a boundary, which changes
	# which of them are higher than their neighbours, which changes how many
	# risers are emitted - so the two builds do not have the same vertex count
	# and walking them in step compares quads that are not the same quad. The
	# first version of this line reported a "worst" of 342 m, which is the
	# distance between two unrelated pieces of ground.
	#
	# What it asserts is the honest thing: the mesh MOVED. A count and a
	# footprint, both of which change only if the knob reaches code.
	var off: Array = meshes[0.0]
	var on: Array = meshes[4.0]
	if off.is_empty() or on.is_empty():
		print("  one of the two builds emitted nothing at all")
		bad += 1
		world.free()
		return bad + 1
	var same_verts: bool = (off[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() \
		== (on[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
	var same_quads: Dictionary = _slice_match(off, _slice_index(off), [on])
	var moved: bool = not bool(same_quads["ok"])
	if same_verts and not moved:
		print("  far_geomorph_cells 0 -> 2 changed NOTHING - the knob reaches no code")
		bad += 1
	print("far geomorph parity: %d -> %d vertices with the geomorph on, mesh %s, c++ %s" % [
		(off[Mesh.ARRAY_VERTEX] as PackedVector3Array).size(),
		(on[Mesh.ARRAY_VERTEX] as PackedVector3Array).size(),
		"CHANGED" if (not same_verts or moved) else "unchanged",
		"compared" if have_cpp else "ABSENT"])
	world.free()
	return bad
