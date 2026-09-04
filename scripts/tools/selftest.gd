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
		"cover determinism": _test_cover_determinism,
		"chunk determinism": _test_chunk_determinism,
		# MESHER V1 STAGE 0, appended beside the determinism test it borrows
		# its chunks from.
		"chunk parity": _test_chunk_parity,
		"edit during generation": _test_edit_during_generation,
		"facing": _test_facing,
		"day cycle": _test_day_cycle,
		"config contract": _test_config_contract,
		"sky reserve": _test_sky_reserve,
		"registry determinism": _test_registry_determinism,
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
		# DISTANCE V5 STAGES 3 AND 6, appended after it.
		"far layer parity": _test_far_geomorph_parity,
		# DISTANCE V5 STAGE 4, appended after it.
		"height tile parity": _test_height_tile_parity,
		"canonical world": _test_canonical_world,
		# TREES V3 STAGE 2, appended at the end of the list.
		"tree winding": _test_tree_winding,
		"tree library": _test_tree_library,
		# TREES V3 STAGE 3.
		"tree table": _test_tree_table,
		# TREES V3 STAGE 4.
		"tree field": _test_tree_field,
		# TREES V3 STAGE 6.
		"tree colliders": _test_tree_colliders,
		"tree spacing": _test_tree_spacing,
		# TREES V3 STAGE 8.
		"tree swatches": _test_tree_swatches,
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
			# The per-vertex tints this used to switch off left the mesher in
			# light v1 Stage 3; there is nothing to turn off any more.
			var solid := func(_a, _b, _c): return false
			var arrays := ChunkMesher.build_arrays_gd(chunk, solid, cfg, 0)
			# MESHER V1 STAGE 1: BOTH MESHERS, EVERY SHAPE. The C++ port emits
			# its own index buffer and its own two corner tables, and a winding
			# rule proved on the twin says nothing about a transcription of it.
			# The parity gate would catch a difference, but this says WHAT is
			# wrong when one appears - "the world is inside out" rather than
			# "vertex 4,118 differs".
			var legs := [["gdscript", arrays]]
			if ChunkMesher.class_present():
				var impl: Object = ClassDB.instantiate(ChunkMesher.CPP_CLASS)
				impl.setup(ChunkMesher.setup_args(cfg))
				legs.append(["c++", ChunkMesher.arrays_from_cpp(impl.build(
					ChunkMesher.borders_from_callable(chunk, solid)))])
			for leg in legs:
				var who: String = leg[0]
				var got: Array = leg[1]
				if got.is_empty():
					print("winding %s (%s): EMPTY - nothing was meshed" % [case, who])
					bad += 1
					continue
				var v: PackedVector3Array = got[Mesh.ARRAY_VERTEX]
				var n: PackedVector3Array = got[Mesh.ARRAY_NORMAL]
				var idx: PackedInt32Array = got[Mesh.ARRAY_INDEX]
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
							print("  BAD %s %s ao=%.2f: cross %s want %s" % [
								case, who, ao, cross.normalized(), want])
					i += 3
				if who == "gdscript":
					per_case["%s@%.2f" % [case, ao]] = v.size() / 4
				print("  %-8s %-8s ao=%.2f %5d verts, %5d tris" % [
					case, who, ao, v.size(), idx.size() / 3])

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


## THE SKY RESERVE MUST BE GONE, AND THE COLUMN MUST END AT THE TERRAIN.
##
## THIS GATE IS INVERTED BY TREES V3 STAGE 7 AND KEPT RATHER THAN DELETED.
##
## It used to assert that `WorldgenConfig` reserved ENOUGH empty sky above
## every column for the tallest tree `TreeSpecies` could grow - because a
## species taller than the reserve would have its crown cut off by a chunk
## nobody queued, and the symptom was not an error but a flat-topped tree in
## some columns, sometimes. The two numbers lived apart on purpose and this
## test was the coupling.
##
## Nothing writes above the terrain any more. `TreeField` instances a model
## library and never touches a voxel, so the reserve is dead weight - about
## twenty-one metres of empty chunks per column, on every column in the world.
## The gate now asserts the OPPOSITE: that `world_height_blocks` does NOT
## carry a tree's height in it, at every scale a knob can reach.
##
## Why keep it at all. Because `REF_MAX_TREE_BLOCKS` and `tree_read_scale` are
## still in the file, and the expression that used them is the kind of thing
## somebody restores while fixing something else. This says, in a runnable
## form, that putting it back is a regression.
func _test_sky_reserve():
	var bad := 0
	var checked := 0
	for scale in [0.5, 1.0, 1.7, 2.5]:
		for read in [1.0, 2.0, 3.0]:
			for og in [1.0, 2.0, 3.0]:
				var cfg := WorldgenConfig.new()
				cfg.tree_size_scale = scale
				cfg.tree_read_scale = read
				cfg.old_growth_scale = og
				cfg.apply_world_scale()
				var a := cfg.world_height_blocks
				# The same config with every tree knob at its smallest. If the
				# reserve were still in there, these two would differ.
				var flat := WorldgenConfig.new()
				flat.tree_size_scale = 0.5
				flat.tree_read_scale = 1.0
				flat.old_growth_scale = 1.0
				flat.apply_world_scale()
				checked += 1
				if a != flat.world_height_blocks:
					print("  scale %.2f read %.1f old growth %.1f: height %d, tree-free height %d" % [
						scale, read, og, a, flat.world_height_blocks])
					bad += 1
	print("sky reserve: %d knob combinations, %d still reserve sky for trees" % [
		checked, bad])
	return bad


## THE FOREST FLOOR'S SHADE MUST NOT DEPEND ON WHO ASKED.
##
## `cover_column()` is what is left of the tree stamper: the same candidate
## walk over the same `max_reach` margin, returning the share of a column's sky
## its trees cover. `ChunkMesher._under_canopy()` darkens the ground with it,
## so if two calls disagreed - or if a column and its neighbour disagreed about
## a tree that straddles them - the forest floor would be shaded differently
## depending on which column was built first, which is exactly the class of bug
## the old `tree borders` test existed to catch on the block stamp.
##
## THIS IS THAT TEST, ASKED OF THE SCAN INSTEAD OF THE VOLUME, and it is
## strictly stronger in one way: it works on BOTH LEGS. `tree borders` could
## only prove anything where tree blocks existed, and after tonight they exist
## nowhere.
##
## Two claims:
##   REPEATABLE   the same column twice is the same number, bit for bit.
##   SHARED       a tree whose crown spans a column boundary is counted by
##                BOTH columns - so the sum over a rectangle does not change
##                when the rectangle is walked in a different order.
func _test_cover_determinism():
	var cfg := WorldgenConfig.new()
	var gen := TerrainGenerator.new(4242, cfg)
	gen.build_heightmap()
	var bad := 0
	var columns := 0
	var covered := 0
	var total := 0.0
	var seen := {}
	for cz in range(-6, 7, 2):
		for cx in range(-6, 7, 2):
			var a := TreePlacement.cover_column(gen, cx, cz)
			var b := TreePlacement.cover_column(gen, cx, cz)
			columns += 1
			total += a
			if a > 0.0:
				covered += 1
			if a != b:
				print("  column (%d, %d): %.9f then %.9f" % [cx, cz, a, b])
				bad += 1
			seen[Vector2i(cx, cz)] = a

	# WALKED BACKWARDS, which is the order test. Nothing in the scan should
	# care, and a scan that cached anything across columns would fail here.
	for cz in range(6, -7, -2):
		for cx in range(6, -7, -2):
			var a: float = seen[Vector2i(cx, cz)]
			var b := TreePlacement.cover_column(gen, cx, cz)
			if a != b:
				print("  column (%d, %d) differed when walked backwards" % [cx, cz])
				bad += 1

	print("cover determinism: %d columns, %d with cover, mean %.4f, %d differed" % [
		columns, covered, total / float(maxi(columns, 1)), bad])
	if covered == 0:
		print("  WARNING: no canopy cover in the sample - this test proved nothing")
		return 1
	return bad


## `decide()` OVER A FIXED RECTANGLE MUST HASH EQUAL ON REPEAT.
##
## The registry of what stands where is the whole determinism contract now.
## Until tonight it was checked indirectly - two machines stamping the same
## leaf blocks into the same chunk - and the blocks are gone, so it is checked
## directly: walk a rectangle of candidates, hash everything `decide()` said,
## and do it again.
##
## EVERYTHING, NOT JUST THE POSITIONS. Species, old growth, the jittered trunk
## position, the ground it stands on, its height and crown, AND THE VARIANT the
## library table picks for it - because the variant is hashed on a new salt
## (232) that no earlier test has ever exercised, and a variant that differed
## between two machines would be two players looking at different trees in the
## same place.
func _test_registry_determinism():
	var cfg := WorldgenConfig.new()
	var gen := TerrainGenerator.new(4242, cfg)
	gen.build_heightmap()
	var trees := 0
	var variants := {}
	var hashes := []
	for run in 2:
		var h := 0
		var masks := TreePlacement.masks_for(gen)
		for cz in range(-24, 25):
			for cx in range(-24, 25):
				var f := TreePlacement.decide(gen, cx, cz, masks)
				if f.is_empty():
					continue
				if run == 0:
					trees += 1
				var v := TreeFieldJob.variant_of(gen, cfg, f)
				if run == 0 and v != &"":
					variants[v] = int(variants.get(v, 0)) + 1
				var p: Dictionary = f["params"]
				# A string, then hashed: every field in one place, and a field
				# added later that nobody hashes is a field this test would
				# silently stop covering.
				h = hash("%d|%s|%d|%d|%d|%d|%d|%d|%s|%d" % [
					h, f["cell"], f["species"], int(f["old_growth"]),
					f["bx"], f["bz"], f["ground"],
					p["height"], v, p["crown"]])
		hashes.append(h)
	var bad := 0 if hashes[0] == hashes[1] else 1
	if bad > 0:
		print("  the registry hashed %d then %d over the same rectangle" % [
			hashes[0], hashes[1]])
	print("registry determinism: %d trees, %d distinct variants, hash %d, %d differed" % [
		trees, variants.size(), hashes[0], bad])
	if trees == 0:
		print("  WARNING: no trees in the sample - this test proved nothing")
		return 1
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

	# THE EVENING IS SIX TO EIGHT MINUTES OF A FORTY-MINUTE DAY (D52).
	#
	# Half of that is `day_seconds` and half of it is the warp in
	# `SkyCycle.arc_angle()`, and only this catches the second half: at a
	# uniform angular speed a 2,400-second day gives the sun's passage from +8
	# to -12 degrees about 133 seconds, and nothing else in the suite would
	# notice the warp being removed. The window is measured through
	# `time_for_elevation()`, which inverts the arc by bisecting
	# `sun_position()` itself, so this tests the arc rather than a second
	# description of it.
	var tilt_hi := sin(deg_to_rad(SkyCycle.WARP_HIGH_DEG))
	var tilt_lo := sin(deg_to_rad(SkyCycle.WARP_LOW_DEG))
	var t_hi := SkyCycle.time_for_elevation(tilt_hi, true)
	var t_lo := SkyCycle.time_for_elevation(tilt_lo, true)
	var evening_s := fposmod(t_lo - t_hi, 1.0) * 2400.0
	if evening_s < 360.0 or evening_s > 480.0:
		print("  the evening (+%.0f to %.0f deg) takes %.0f s of a 2400 s day, want 360-480"
			% [SkyCycle.WARP_HIGH_DEG, SkyCycle.WARP_LOW_DEG, evening_s])
		bad += 1

	# The arc must not run backwards anywhere, or the compass, the tour and the
	# clock disagree about which way the day is going.
	var previous_angle := SkyCycle.arc_angle(0.25)
	var regressions := 0
	for step in range(1, 2001):
		var angle := SkyCycle.arc_angle(0.25 + float(step) / 2001.0)
		if angle < previous_angle - 1e-9:
			regressions += 1
		previous_angle = angle
	if regressions > 0:
		print("  the sun's arc runs backwards at %d of 2000 steps" % regressions)
		bad += 1

	# Every hour anchor must resolve to a time that puts the sun back at it.
	for hour_name in SkyCycle.HOURS:
		var want: float = SkyCycle.HOURS[hour_name]
		var at := SkyCycle.time_for_elevation(want, true)
		var got := SkyCycle.sun_position(at).y
		if absf(got - want) > 0.002:
			print("  hour '%s' wants elevation %+.3f, resolved to t %.4f which is %+.3f"
				% [hour_name, want, at, got])
			bad += 1

	print("day cycle: 1441 steps, elevation %.3f to %.3f, %d horizon crossings, evening %.0f s, %d bad" % [
		lowest, highest, crossings, evening_s, bad])
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

	# 0.45 NAMED, NOT `WorldgenConfig.new().ao_strength`, AND THAT IS A FIX.
	#
	# Light v1 Q9 took the shipped `ao_strength` to 0. This list read
	# `[0.0, WorldgenConfig.new().ao_strength]`, so from that commit on it has
	# compared zero against zero and its "+0.0%" line has been measuring
	# NOTHING - which is also where mesher v1's Q27 ("baked AO off did not
	# widen the merge") came from. 0.45 is the value the winding test names for
	# the same reason: it is the strength the photograph path uses.
	const AO_ON := 0.45
	var results := []
	for ao in [0.0, AO_ON]:
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
		# THE JITTER HALF OF THIS CASE LEFT WITH THE PAINT in light v1 Stage 3;
		# what it exercised - Block.jitter's hash path - no longer exists on
		# either leg. The MODE VOTE it shares the case with is still worth a
		# row of its own, and still ships at 0.0, so it is still the only place
		# the vote and its memo are exercised at all.
		{"name": "vote", "terrace": 1.0, "div": 2.0,
			"frontier": partial, "vote": 1.0},
	]
	var checks := 0
	for c in cases:
		wcfg.far_terrace = c["terrace"]
		wcfg.far_ring_div = c["div"]
		wcfg.far_vote = float(c.get("vote", 0.0))
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
		"backdrop_zone": 0, "surface_zone_at": 0, "vertex": 0.0,
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

		# THE COLOUR PATH IS ONE EXPRESSION NOW (light v1 Stage 3, Q15). Four
		# of the seven rows this test used to carry - treeline_band, band_m_at,
		# band_color and aspect_shade - measured functions that no longer
		# exist on either leg: the altitude bands, the riser shade, the aspect
		# tint and the per-vertex jitter left the C++ and its twin in one
		# commit, so the parity harness never saw them disagree.
		#
		# What is left is what a far vertex actually travels through, and it is
		# still worth comparing exactly: Look.to_wire on the zone's own colour.
		# The normal and the point are still generated and still passed, so the
		# call shape is the one the mesher exposes and a future per-vertex term
		# lands inside a test that already runs.
		var zone := rng.randi_range(0, TerrainGenerator.ZONE_COUNT - 1)
		var color := Block.color_of(TerrainGenerator.ZONE_SURFACE[zone])
		var normal := Vector3(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0),
			rng.randf_range(-1.0, 1.0))
		if normal.length_squared() > 0.0:
			normal = normal.normalized()
		else:
			normal = Vector3.UP
		var point := Vector3(rng.randf_range(-500.0, 500.0),
			rng.randf_range(-50.0, 400.0), rng.randf_range(-500.0, 500.0))
		diff["vertex"] = maxf(diff["vertex"], _color_diff(Look.to_wire(color),
			mesher.c_vertex(color, normal, point)))

	for key in diff:
		if diff[key] != 0 and diff[key] != 0.0:
			print("  %s differs: %s over %d samples" % [key, diff[key], n])
			bad += 1
	print("far zone parity: %d samples x 3 functions, %s" % [
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
	# THE THREE COMBINATIONS THAT MATTER: neither layer, the geomorph alone,
	# and both. Distance v5 Stage 6 added its layer to this test rather than to
	# a second world, because a second world is another thirty seconds on every
	# self-test run for a question this one can already answer.
	for case in [["off", 0.0, 0.0], ["geo", 4.0, 0.0], ["both", 4.0, 1.0]]:
		var cells: float = case[1]
		wcfg.far_geomorph_cells = cells
		wcfg.far_detail = case[2]
		var job := FarFieldJob.new()
		job.heightmap = heightmap
		job.generator = generator
		job.config = wcfg
		job.center = centre
		job.run()
		meshes[case[0]] = job.arrays
		print("  %-5s far_geomorph_cells %.0f, far_detail %.0f: %d verts" % [
			case[0], cells, case[2], job.vertex_count])
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
	var verdicts := PackedStringArray()
	for pair in [["off", "geo", "the geomorph"],
			["geo", "both", "the detail layer"]]:
		var off: Array = meshes[pair[0]]
		var on: Array = meshes[pair[1]]
		if off.is_empty() or on.is_empty():
			print("  one of the two builds emitted nothing at all")
			bad += 1
			continue
		var same_verts: bool = (off[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() \
			== (on[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
		var same_quads: Dictionary = _slice_match(off, _slice_index(off), [on])
		var moved: bool = not bool(same_quads["ok"])
		if same_verts and not moved:
			print("  %s changed NOTHING - the knob reaches no code" % pair[2])
			bad += 1
		verdicts.append("%s %s" % [pair[2],
			"CHANGES the mesh" if (not same_verts or moved) else "changes NOTHING"])
	print("far layer parity: %s, c++ %s" % [
		String(", ").join(verdicts), "compared" if have_cpp else "ABSENT"])
	world.free()
	return bad


## THE HEIGHT MAP'S TWO BUILDERS AGREE, EXACTLY. Distance v5 Stage 4,
## decision 3.
##
## This is the far mesher's parity gate at a higher stake. The far mesh is
## look-only, so distance v4 could reason that a disagreement draws a slightly
## different mountain. The height map is world truth: `world.gd` finds lakes and
## spawn in it and every voxel column reads it, and terrain is never sent over
## the network - both machines regenerate it from a seed. A disagreement here is
## two players in different worlds and no error on either machine.
##
## So the gate is EQUAL, not close, and the reason it can be is decision 3's
## quantisation: both builders round to 1/1024 of a block as their last step, so
## a one-ULP difference in the expression above it cannot survive into the
## answer. The test compares the quantised heights (which is what the world
## uses) at ten thousand positions, including a quarter off the map on each
## axis, because a clamp is exactly the kind of edge a transcription gets
## subtly wrong.
func _test_height_tile_parity():
	var bad := 0
	var cfg := WorldgenConfig.new()
	cfg.world_blocks_xz = 800
	cfg.view_distance = -1
	var generator := TerrainGenerator.new(31337, cfg)
	if not HeightTiles.available():
		print("height tile parity: c++ tile builder absent, 0 checks")
		return 0
	var tiles := HeightTiles.new()
	if not tiles.setup(generator, cfg):
		print("  the c++ tile builder refused this world")
		return 1

	var rng := RandomNumberGenerator.new()
	rng.seed = 909
	var half := float(cfg.world_blocks_xz) * 0.5
	var worst := 0.0
	var differing := 0
	var samples := 10000
	for k in samples:
		# A quarter of the samples land off the map on each axis.
		var bx := rng.randf_range(-half * 1.5, half * 1.5)
		var bz := rng.randf_range(-half * 1.5, half * 1.5)
		var a := generator.height_at_block(bx, bz)
		var b := tiles.height_at_block(bx, bz)
		if a != b:
			differing += 1
		worst = maxf(worst, absf(a - b))
	if differing > 0:
		bad += 1

	# AND A WHOLE TILE, through the array path rather than the scalar one -
	# because the two are different code and the marshalling is where a tile
	# comes back short, transposed or one row late.
	var step := cfg.coarse_step
	var cols := 64
	var bx0 := -128
	var bz0 := 64
	var got := tiles.build_tile(bx0, bz0, cols, cols, step)
	var tile_bad := 0
	if got.size() != cols * cols:
		print("  the tile came back %d cells, not %d" % [got.size(), cols * cols])
		bad += 1
	else:
		for j in cols:
			for i in cols:
				var want := generator.height_at_block(
					float(bx0 + i * step), float(bz0 + j * step))
				if got[i + j * cols] != float(want):
					tile_bad += 1
		if tile_bad > 0:
			bad += 1

	print("height tile parity: %d samples, %d differing (worst %.17f); one %dx%d tile, %d cells differing" % [
		samples, differing, worst, cols, cols, tile_bad])
	return bad


## THE CANONICAL WORLD, AND ITS FINGERPRINT. Distance v5 Stage 4.
##
## HARD RULE ZERO, AUTOMATED: same seed, same config, same world - and from
## tonight that has to hold across a gcc build and an MSVC one, because the
## height map now crosses to C++ and the height map is what spawn and lakes are
## computed from.
##
## THIS TEST IS THE CROSS-BOX INSTRUMENT AND IT IS MEANT TO BE READ, not only
## to pass. It prints the three numbers that describe the world, so running the
## self-test on a second machine and comparing one line is the whole procedure.
## The morning's job on gemini is exactly that - see docs/status/distance-v5.md.
##
## The expected values below are ganymede's, at the commit that wrote them. When
## a stage deliberately changes the world - distance v5 Stage 5 changes the
## resolution, and Marcel accepted that in advance - these move WITH the change,
## in the same commit, and the status doc records the old and the new.
const CANONICAL_SEED := 42

## The QUANTISED map's fingerprint - distance v5 Stage 4. `main`'s was
## `76cccdb6` and that is what this build produces with the quantisation turned
## off, which is how the tiling was proved to change nothing; rounding every
## height to 1/1024 of a block necessarily changes the stored bits and
## therefore this number, and changes NOTHING ELSE about the world, which is
## the point of the two lines under it.
const CANONICAL_HEIGHTMAP := "4782edac"
const CANONICAL_SPAWN := Vector2i(-44, -124)
const CANONICAL_LAKES := 53


## THE CANONICAL CONFIG, BUILT RATHER THAN LOADED. `load_or_default()` reads
## `user://worldgen.tres`, so on a machine that has one this test would compare
## two different worlds and call it a determinism failure. The two calls after
## `new()` are exactly what `load_or_default()` does to a fresh config, and the
## second of them is not optional: `apply_world_scale()` derives the continent
## and mountain amplitudes and frequencies from `world_scale`, so a config
## without it builds a world with a different SHAPE. Written down because the
## first version of this test omitted it and reported the world had moved.
static func canonical_config() -> WorldgenConfig:
	var cfg := WorldgenConfig.new()
	cfg.apply_view_preset()
	cfg.apply_world_scale()
	return cfg


func _test_canonical_world():
	var bad := 0
	# BOTH LEGS, EVERY RUN. The expected values are one half of this test; the
	# other half is that a checkout with no compiled library builds the SAME
	# world - which is hard rule 1 and hard rule zero at once, and is the thing
	# quantisation exists to buy.
	var got := {}
	for leg in ["c++", "gdscript"]:
		var cfg := canonical_config()
		var generator := TerrainGenerator.new(CANONICAL_SEED, cfg)
		generator.force_gdscript_tiles = leg == "gdscript"
		var ms := generator.build_heightmap()
		var hm: Heightmap = generator.heightmap
		var lakes := Lakes.new()
		lakes.compute(hm, cfg)
		generator.lakes = lakes
		var spawn := generator.find_spawn()
		got[leg] = {
			"hash": hm.hash_key(), "spawn": spawn, "lakes": lakes.lake_count(),
			"builder": generator.heightmap_builder, "ms": ms,
		}
		print("canonical world: seed %d, heightmap %s, spawn (%d, %d), %d lakes, %s builder, %d ms" % [
			CANONICAL_SEED, got[leg]["hash"], spawn.x, spawn.y,
			got[leg]["lakes"], got[leg]["builder"], ms])

	# THE LINE THE MORNING COMPARES ACROSS TWO MACHINES is the one above. These
	# three are what makes a mismatch legible rather than merely red.
	var a: Dictionary = got["c++"]
	if a["hash"] != CANONICAL_HEIGHTMAP:
		print("  heightmap hash %s, expected %s - THE WORLD MOVED" % [
			a["hash"], CANONICAL_HEIGHTMAP])
		bad += 1
	if a["spawn"] != CANONICAL_SPAWN:
		print("  spawn (%d, %d), expected (%d, %d)" % [
			a["spawn"].x, a["spawn"].y, CANONICAL_SPAWN.x, CANONICAL_SPAWN.y])
		bad += 1
	if a["lakes"] != CANONICAL_LAKES:
		print("  %d lakes, expected %d" % [a["lakes"], CANONICAL_LAKES])
		bad += 1

	# AND THE TWO BUILDERS AGREE ON ALL THREE. Skipped, loudly, when there is
	# no library to compare against - the two legs are then the same leg.
	var b: Dictionary = got["gdscript"]
	if a["builder"] == b["builder"]:
		print("  (no compiled tile builder - both legs are gdscript)")
	elif a["hash"] != b["hash"] or a["spawn"] != b["spawn"] \
			or a["lakes"] != b["lakes"]:
		print("  THE TWO BUILDERS DISAGREE: %s/%s, spawn %s/%s, lakes %d/%d" % [
			a["hash"], b["hash"], a["spawn"], b["spawn"], a["lakes"], b["lakes"]])
		bad += 1
	return bad



# --- Trees v3 -----------------------------------------------------------------

## EVERY TREE TRIANGLE MUST FACE OUTWARDS, AND THIS IS WHY IT IS NOT ARGUED.
##
## `FloraModels`' own winding note records that all six of its faces were
## backwards on the first attempt, and - the part worth repeating - that the
## symptom was NOT an inside-out model. Nothing vanished. What appeared was
## thin horizontal gaps through every rounded blob, which survived being
## explained as a raggedness setting, as the voxel scale and as shadow acne.
##
## `TreeModels` writes six faces of its own, as RECTANGLES rather than voxel
## faces, with a per-face winding flip - which is six more chances to make the
## same mistake in a form that looks like a modelling choice. So it is checked
## with the cross product and never with eyes:
##
##     (p1 - p0) x (p2 - p0) == -normal
##
## SELF-SKIPS WITHOUT THE LIBRARY, and says so. That is hard rule 3's absent
## leg, and a gate that silently passed on a public build would be no gate.
func _test_tree_winding():
	if not TreeModels.available():
		print("tree winding: no library mounted, 0 checks (public build)")
		return 0
	var bad := 0
	var checked := 0
	var faces := {}
	for variant in TreeModels.variants():
		for lod in TreeModels.LOD_COUNT:
			var mesh := TreeModels.mesh_for(variant, lod, 0.5)
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
				if cross.length() > 0.0 and cross.normalized().dot(-n) < 0.99:
					wrong += 1
					# WHICH face, not just how many. Six flips means six
					# independent mistakes, and a count alone would send
					# somebody looking at all of them.
					faces[n] = int(faces.get(n, 0)) + 1
				checked += 1
				i += 3
			if wrong > 0:
				print("  %s lod %d: %d of %d triangles wound the wrong way" % [
					variant, lod, wrong, indices.size() / 3])
				bad += 1
	for n in faces:
		print("  normal %s: %d wrong" % [n, faces[n]])
	print("tree winding: %d triangles across %d variants x %d rungs, %d wrong" % [
		checked, TreeModels.variants().size(), TreeModels.LOD_COUNT, bad])
	if checked == 0:
		print("  WARNING: a library is mounted but it built no triangles")
		return 1
	return bad


## THE LIBRARY MUST AGREE WITH ITS OWN SIDECARS, AND WITH THE LADDER.
##
## The triangle counts in this document's Stage 1 table were printed by a
## Python tool that has no Godot in it, and the meshes the game draws are
## assembled by a GDScript loader that has never seen a `.vox`. Those two
## agreeing is the whole claim that the offline bake and the online assembly
## are the same geometry - so it is asserted rather than believed, on every
## variant at every rung.
##
## AND THE LADDER WITH IT. `TreeModels.VOXELS_PER_BLOCK` and the tool's own
## copy are two numbers that must be one number; if they drift, every tree in
## the world is the wrong size and nothing else in the project would say so.
func _test_tree_library():
	if not TreeModels.available():
		print("tree library: no library mounted, 0 checks (public build)")
		return 0
	var bad := 0
	var checked := 0
	var worst := 0
	var worst_name := ""
	var total := 0
	for variant in TreeModels.variants():
		var d := TreeModels.info(variant)
		var lods: Array = d.get("lods", [])
		if lods.size() != TreeModels.LOD_COUNT:
			print("  %s has %d rungs, the loader reads %d" % [
				variant, lods.size(), TreeModels.LOD_COUNT])
			bad += 1
			continue
		# The ladder, restated from the sidecar's own numbers: a model's height
		# in metres IS its voxel count times the rung's voxel size.
		var expect_m := float(int((d["size"] as Array)[1])) \
			* 0.5 / float(TreeModels.VOXELS_PER_BLOCK) \
			* float(d.get("base_step", 1))
		if absf(expect_m - TreeModels.height_m(variant)) > 0.001:
			print("  %s: sidecar says %.4f m, the ladder says %.4f m" % [
				variant, TreeModels.height_m(variant), expect_m])
			bad += 1
		# Every variant must have a palette row, or its whole crown falls back
		# to BARK_DARK and the tree is drawn in mud.
		if not TreePalette.has(variant):
			print("  %s has no row in TreePalette.PACK_FAMILIES" % variant)
			bad += 1
		for lod in TreeModels.LOD_COUNT:
			var want := int((lods[lod] as Dictionary).get("triangles", -1))
			var got := TreeModels.triangles_for(variant, lod, 0.5)
			checked += 1
			if want != got:
				print("  %s lod %d: the tool baked %d triangles, the loader built %d" % [
					variant, lod, want, got])
				bad += 1
			if lod == 0:
				total += got
				if got > worst:
					worst = got
					worst_name = String(variant)
	print("tree library: %d variants x %d rungs checked, %d wrong" % [
		TreeModels.variants().size(), TreeModels.LOD_COUNT, bad])
	print("  worst LOD0 %s at %d triangles, %d over the library" % [
		worst_name, worst, total])
	if checked == 0:
		print("  WARNING: a library is mounted but nothing was checked")
		return 1
	return bad


## THE MAPPING TABLE MUST AGREE WITH THE LIBRARY, AND COVER IT.
##
## `TreeTable.lint()` carries the rules; this runs it and prints what it says.
## The rule that matters most is the third one: every variant in the library
## must be either used by a row or explicitly benched with a reason. A pack
## that gains a species folder then FAILS here rather than quietly not
## appearing in the world, which is the failure mode a mapping table has.
##
## AND EVERY GAME SPECIES MUST FIND A ROW. `TreeSpecies` names seven species
## and placement can return any of them; a slot with no row draws nothing, so
## the forest would simply be missing its larches with no error anywhere.
func _test_tree_table():
	if not TreeModels.available():
		print("tree table: no library mounted, 0 checks (public build)")
		return 0
	var bad := 0
	for complaint in TreeTable.lint():
		print("  " + complaint)
		bad += 1
	var cfg := WorldgenConfig.new()
	var covered := 0
	for species in TreeSpecies.table(cfg).size():
		var slot := TreeTable.slot_of(species, cfg)
		if TreeTable.row_for(slot).is_empty():
			print("  species %s has no row in TreeTable" % slot)
			bad += 1
		else:
			covered += 1
	# DETERMINISM, on the spot rather than as a separate gate: the same cell
	# must pick the same variant twice, and two cells must not all pick one.
	var picks := {}
	for i in 400:
		var slot := TreeTable.slot_of(TreeSpecies.SPRUCE, cfg)
		var a := TreeTable.variant_at(slot, i, i * 7, 42)
		var b := TreeTable.variant_at(slot, i, i * 7, 42)
		if a != b:
			print("  variant_at is not deterministic at cell (%d, %d)" % [i, i * 7])
			bad += 1
			break
		picks[a] = int(picks.get(a, 0)) + 1
	print("tree table: %d species covered, %d live variants over 400 spruce cells, %d complaints" % [
		covered, picks.size(), bad])
	if picks.size() < 2:
		print("  WARNING: 400 cells drew %d distinct variants - the hash or the weights are wrong" % picks.size())
		return 1
	return bad


## THE FIELD MUST DRAW EVERY TREE PLACEMENT PUTS THERE, AND NO OTHERS.
##
## Trees v3 hard rule 1: placement does not move. The field is now the only
## thing that draws a library species, so "the forest is complete" stops being
## a property of the chunk stamper and becomes a property of this walk - and
## the walk has bands, strides, an annulus test and a per-sector frontier hole
## in it, any one of which could quietly drop a tree.
##
## So: run the real `TreeFieldJob` over a small ring, count the model instances
## it emitted per variant, and compare that against `TreePlacement.decide()`
## asked directly over the SAME cells. Exact equality, not a tolerance.
##
## THE NEAREST BAND IS WHERE THIS IS CHECKABLE, and only there. The outer bands
## walk one candidate cell in four, sixteen and sixty-four on purpose (distance
## v1 Stage 7), so the field is DESIGNED to draw fewer trees than placement
## decides out there. Inside `lod_blocks` the stride is 1 and every candidate
## is visited, which is the band the handover to the player happens in and the
## one the gate is about.
func _test_tree_field():
	if not TreeModels.available():
		print("tree field: no library mounted, 0 checks (public build)")
		return 0
	var cfg := WorldgenConfig.new()
	var gen := TerrainGenerator.new(42, cfg)
	gen.build_heightmap()

	var job := TreeFieldJob.new()
	job.center = Vector2i(0, 0)
	job.generator = gen
	job.config = cfg
	job.heightmap = gen.heightmap
	# NO FRONTIER, so the inner edge is the nominal radius rather than a
	# per-sector one - and for a model species the inner edge does not apply at
	# all, which is the thing being checked.
	job.inner_blocks = float(cfg.voxel_radius_chunks * Chunk.SIZE)
	job.outer_blocks = job.inner_blocks * 1.6
	# Every band collapsed onto the first, so the whole scan is stride 1 and
	# the comparison is against every candidate rather than a lattice.
	job.lod_blocks = job.outer_blocks
	job.lod2_blocks = job.outer_blocks
	job.lod3_blocks = job.outer_blocks
	job.run()

	var drawn := {}
	var models := 0
	for key in job.buffers:
		var n: int = (job.buffers[key] as PackedFloat32Array).size() \
			/ TreeFieldJob.FLOATS_PER_INSTANCE
		var m := TreeFieldJob.model_of_key(String(key))
		if String(m[0]).is_empty():
			continue
		drawn[StringName(m[0])] = int(drawn.get(StringName(m[0]), 0)) + n
		models += n

	# The same annulus, asked of placement directly.
	var want := {}
	var expect := 0
	var cell: int = cfg.tree_cell_blocks
	var masks := TreePlacement.masks_for(gen)
	var outer_sq := job.outer_blocks * job.outer_blocks
	var reach := int(ceil(job.outer_blocks))
	for cz in range(Chunk.floor_div(-reach, cell), Chunk.floor_div(reach, cell) + 1):
		for cx in range(Chunk.floor_div(-reach, cell), Chunk.floor_div(reach, cell) + 1):
			var dx := float(cx * cell)
			var dz := float(cz * cell)
			var d_sq := dx * dx + dz * dz
			if d_sq > outer_sq or d_sq <= -1.0:
				continue
			var found := TreePlacement.decide(gen, cx, cz, masks)
			if found.is_empty():
				continue
			if not TreeTable.drawn_as_model(found["species"], cfg):
				continue
			# THROUGH THE JOB'S OWN FUNCTION, not a reimplementation of it -
			# see its note. A gate that restates the rule it is checking will
			# eventually check a different rule.
			var v := TreeFieldJob.variant_of(gen, cfg, found)
			if v == &"":
				continue
			want[v] = int(want.get(v, 0)) + 1
			expect += 1

	var bad := 0
	for v in want:
		if int(drawn.get(v, 0)) != int(want[v]):
			print("  %s: the field drew %d, placement decided %d" % [
				v, int(drawn.get(v, 0)), int(want[v])])
			bad += 1
	for v in drawn:
		if not want.has(v):
			print("  %s: the field drew %d that placement did not decide" % [
				v, int(drawn[v])])
			bad += 1
	print("tree field: %d model instances over %d variants, placement says %d, %d disagree" % [
		models, drawn.size(), expect, bad])
	if expect == 0:
		print("  WARNING: no model species in the sample - this test proved nothing")
		return 1
	return bad


## NO TWO CROWNS MAY INTERPENETRATE, and this is the gate on the rule that
## says so - trees v4, and Marcel's ask in his own words: "make it so that
## they don't ever completely overlap".
##
## WHY A GATE AND NOT AN EYEBALL. The guarantee is a proof about a hash - a
## candidate dies if any raw-accepted neighbour of higher priority stands
## within their two radii - and a proof about a hash is exactly the kind of
## claim that stays true right up until a salt changes or the scan reach is
## rounded the wrong way. Both of those are one-character edits.
##
## IT CHECKS THE PAIR, NOT THE RULE. Every placed tree in the patch against
## every other, on the radii the FIELD will draw them at, so a spacing rule
## that computed the right thing from the wrong radius still fails here.
func _test_tree_spacing():
	if not TreeModels.available():
		print("tree spacing: no library mounted, 0 checks (public build)")
		return 0
	var cfg := WorldgenConfig.load_or_default()
	var gen := TerrainGenerator.new(42, cfg)
	gen.build_heightmap()
	var masks := TreePlacement.masks_for(gen)

	# A patch wide enough to hold a few hundred trees, walked at the candidate
	# lattice so this is the same set the ring would draw.
	var reach := int(ceil(300.0 / cfg.block_size / float(cfg.tree_cell_blocks)))
	var trees := []
	for cz in range(-reach, reach + 1):
		for cx in range(-reach, reach + 1):
			var found := TreePlacement.decide(gen, cx, cz, masks)
			if found.is_empty():
				continue
			# A CROWN OF ZERO IS NOT A CROWN. Snags carry crown (0, 0) in the
			# species table and have no model slot, so the field draws nothing
			# for them at all - and a thing that is not drawn cannot overlap
			# something that is. The rule skips them for the same reason, and
			# the first cut of this gate did not: it reported a snag standing
			# inside a beech as two overlapping crowns, which is one crown.
			var r := TreePlacement.canopy_radius_blocks(gen, found)
			if r <= 0.0:
				continue
			trees.append([float(found["bx"]), float(found["bz"]), r])

	var spacing: float = cfg.tree_canopy_spacing
	var worst := 1.0e9
	var bad := 0
	for i in trees.size():
		for j in range(i + 1, trees.size()):
			var a: Array = trees[i]
			var b: Array = trees[j]
			var dx: float = a[0] - b[0]
			var dz: float = a[1] - b[1]
			var need: float = (float(a[2]) + float(b[2])) * spacing
			var d := sqrt(dx * dx + dz * dz)
			# The slack as a FRACTION of what the pair needed, so one tight
			# pair of giants and one tight pair of stumps are comparable.
			worst = minf(worst, d / maxf(need, 0.0001))
			if d < need - 0.001:
				bad += 1
	print("tree spacing: %d trees, %d overlapping pairs; closest pair at %.2f of its required gap (spacing %.2f)" % [
		trees.size(), bad, 0.0 if worst > 1.0e8 else worst, spacing])
	if bad > 0:
		return 1
	return 0


## A TRUNK MUST STOP YOU, AND THE COUNT MUST MATCH PLACEMENT.
##
## Trees left the block grid, so "is there a tree here" stopped being a
## question about the voxel volume - and with it went the collision the volume
## gave for free. Decision 8 replaces it with an explicit cylinder per trunk
## inside the sim radius, which is a thing that can silently be in the wrong
## place, the wrong size, or absent.
##
## Two claims, and the second is the one that matters to a player:
##
##   COUNT   the ring holds exactly one cylinder per tree placement decides
##           inside the radius - not one per DRAWN tree, which would let a
##           fade or an LOD rung quietly remove collision.
##   BODY    a ray fired horizontally at a trunk, at chest height, from
##           outside it, HITS. That is "walk into a trunk, be stopped" in the
##           only form a headless test can carry, and it exercises the real
##           shape at its real position through the real physics server.
func _test_tree_colliders():
	if not TreeModels.available():
		print("tree colliders: no library mounted, 0 checks (public build)")
		return 0
	var cfg := WorldgenConfig.new()
	var gen := TerrainGenerator.new(42, cfg)
	gen.build_heightmap()

	var job := TreeFieldJob.new()
	job.center = Vector2i(0, 0)
	job.generator = gen
	job.config = cfg
	job.heightmap = gen.heightmap
	job.inner_blocks = float(cfg.voxel_radius_chunks * Chunk.SIZE)
	job.outer_blocks = job.inner_blocks * 1.6
	job.lod_blocks = job.outer_blocks
	job.lod2_blocks = job.outer_blocks
	job.lod3_blocks = job.outer_blocks
	# DELIBERATELY WIDER THAN THE GAME'S sim radius, because seed 42's spawn
	# has a 24 m tree clearing around it by design and a 32 m ring there holds
	# nothing at all. A test whose sample is empty proves nothing.
	job.collider_blocks = job.outer_blocks
	job.run()

	# The same annulus, asked of placement directly.
	var expect := 0
	var cell: int = cfg.tree_cell_blocks
	var masks := TreePlacement.masks_for(gen)
	var r_sq := job.collider_blocks * job.collider_blocks
	var reach := int(ceil(job.collider_blocks))
	for cz in range(Chunk.floor_div(-reach, cell), Chunk.floor_div(reach, cell) + 1):
		for cx in range(Chunk.floor_div(-reach, cell), Chunk.floor_div(reach, cell) + 1):
			var d_sq := float(cx * cell) * float(cx * cell) \
				+ float(cz * cell) * float(cz * cell)
			if d_sq > r_sq or d_sq <= -1.0:
				continue
			var found := TreePlacement.decide(gen, cx, cz, masks)
			if found.is_empty():
				continue
			if not TreeTable.drawn_as_model(found["species"], cfg):
				continue
			var v := TreeFieldJob.variant_of(gen, cfg, found)
			if v == &"":
				continue
			# A variant whose sidecar reports no trunk gets no cylinder, and
			# the expectation has to know that or it counts a tree the ring
			# was right not to build.
			if TreeModels.trunk_of(v) == Vector2.ZERO:
				continue
			expect += 1

	var bad := 0
	if job.colliders.size() != expect:
		print("  the ring holds %d cylinders, placement decides %d trees" % [
			job.colliders.size(), expect])
		bad += 1
	if job.colliders.is_empty():
		print("  WARNING: no colliders in the sample - this test proved nothing")
		return 1

	# Every cylinder must be a real trunk: a positive radius, a positive
	# height, and its foot at or above the ground rather than buried.
	var silly := 0
	for row in job.colliders:
		if float(row[1]) <= 0.0 or float(row[2]) <= 0.0:
			silly += 1
	if silly > 0:
		print("  %d cylinders have a non-positive radius or height" % silly)
		bad += 1

	# THE BODY TEST, ON ITS OWN PHYSICS SPACE AND WITHOUT `await`.
	#
	# The obvious version adds a StaticBody3D to this scene and fires a ray at
	# it - and it does not work, because a body is not in its space until a
	# physics frame has passed, so the test has to await one. An awaiting test
	# breaks this harness's whole detection method: it reports a crash by
	# returning something that is not an int, and a coroutine is not an int
	# either. `_ready` refused to call it at all.
	#
	# So: a space of this test's own, through PhysicsServer3D, which is live
	# the moment it is created and needs no frame. It is the same Jolt server
	# the game runs on and the same cylinder shape the ring builds, queried the
	# same way - the only thing given up is the scene tree, which was never
	# part of the claim.
	var space := PhysicsServer3D.space_create()
	PhysicsServer3D.space_set_active(space, true)
	var body := PhysicsServer3D.body_create()
	PhysicsServer3D.body_set_mode(body, PhysicsServer3D.BODY_MODE_STATIC)
	PhysicsServer3D.body_set_space(body, space)
	var shape := PhysicsServer3D.cylinder_shape_create()
	var first: Array = job.colliders[0]
	PhysicsServer3D.shape_set_data(shape,
		{"radius": float(first[1]), "height": float(first[2])})
	var centre: Vector3 = first[0]
	PhysicsServer3D.body_add_shape(body, shape, Transform3D(Basis(), centre))

	var stopped := false
	var leaked := false
	var st := PhysicsServer3D.space_get_direct_state(space)
	if st != null:
		# Fired horizontally at the trunk's own centre height, from three
		# metres outside its radius. This is "walk into it and be stopped".
		var from := centre + Vector3(float(first[1]) + 3.0, 0.0, 0.0)
		stopped = not st.intersect_ray(
			PhysicsRayQueryParameters3D.create(from, centre)).is_empty()
		# AND THE MIRROR OF IT, because a test that only checks for a hit
		# passes on a shape the size of the world: a ray twenty metres to the
		# side, at the same height, must MISS.
		var clear := centre + Vector3(0.0, 0.0, 20.0)
		leaked = not st.intersect_ray(PhysicsRayQueryParameters3D.create(
			clear + Vector3(float(first[1]) + 3.0, 0.0, 0.0),
			clear)).is_empty()
	if not stopped:
		print("  a ray fired at a trunk from 3 m away did not hit it")
		bad += 1
	if leaked:
		print("  a ray fired 20 m clear of the trunk hit something")
		bad += 1
	PhysicsServer3D.free_rid(shape)
	PhysicsServer3D.free_rid(body)
	PhysicsServer3D.free_rid(space)

	var radii := Vector2(1e9, 0.0)
	var heights := Vector2(1e9, 0.0)
	for row in job.colliders:
		radii = Vector2(minf(radii.x, row[1]), maxf(radii.y, row[1]))
		heights = Vector2(minf(heights.x, row[2]), maxf(heights.y, row[2]))
	print("tree colliders: %d cylinders, placement says %d; radius %.2f-%.2f m, height %.2f-%.2f m; ray hit %s" % [
		job.colliders.size(), expect, radii.x, radii.y, heights.x, heights.y,
		"yes" if stopped else "NO"])
	return bad


## One vertex colour as the three bytes the renderer will actually read.
static func _swatch_bytes(c: Color) -> Vector3i:
	return Vector3i(
		int(clampf(c.r, 0.0, 1.0) * 255.0),
		int(clampf(c.g, 0.0, 1.0) * 255.0),
		int(clampf(c.b, 0.0, 1.0) * 255.0))


## WHAT IS AUTHORED IN `TreePalette` MUST BE WHAT LANDS IN THE MESH.
##
## THE SWATCH GATE, AND IT IS A TEST RATHER THAN A SHEET. The plan offers a
## choice - extend the character gallery's swatch sheet or add a tree strip -
## and this takes a third option, which is to assert the thing the sheet was
## looking for instead of photographing it.
##
## What the sheet catches is the colour path going wrong: a linear value pushed
## into a vertex colour without `Look.to_wire()` draws far brighter and far less
## saturated than intended, which is a mistake this project has made and paid a
## whole screenshot tour to find (`FloraModels.COLORS`' note, and look v2 Stage
## 0's). It is a ROUND TRIP, and a round trip is exactly checkable.
##
## So: for every variant, assemble the real mesh, read the vertex colours the
## loader actually pushed, and require every one of them to be a family from
## `TreePalette` converted exactly once. A colour converted twice, not at all,
## or looked up from the wrong table fails.
##
## The 6-unit tolerance the plan names is the character gallery's, and it is
## about a PHOTOGRAPH - light, shade and a renderer stand between an authored
## hex and a pixel. Nothing stands between an authored hex and a vertex colour,
## so this is exact to a float epsilon instead, which is a stronger claim than
## the one being asked for.
func _test_tree_swatches():
	if not TreeModels.available():
		print("tree swatches: no library mounted, 0 checks (public build)")
		return 0
	# EVERY AUTHORED FAMILY, CONVERTED THE ONE WAY THE LOADER CONVERTS, AS THE
	# BYTES THE RENDERER WILL READ - and matched to WITHIN ONE UNIT, which is
	# the whole of what this gate's tolerance had to be worked out from.
	#
	# An ArrayMesh stores a vertex colour in eight bits per channel and hands
	# back the quantised value rather than the float that was pushed. The first
	# version of this gate compared floats exactly and failed on all 638,164
	# vertex colours in the library, which is what a tolerance bug looks like
	# when the tolerance is zero. The second quantised both sides by ROUNDING
	# and failed on all of them too - Godot TRUNCATES (`c * 255` cast to a
	# byte), so an authored `0.2195` goes in as 55.97 and comes back as 55.
	#
	# Truncating both sides is right in principle and lands on a knife edge in
	# practice: `0.2823 * 255` is 71.99 authored and 70.99 read back, so a
	# single float ulp moves the answer by a whole unit. So: within one unit
	# per channel, which is the SMALLEST tolerance eight bits admits and far
	# tighter than the 6 units the plan offers - that number is the character
	# gallery's, and it is about a PHOTOGRAPH, with light and a renderer in the
	# way. Nothing stands between an authored hex and these bytes but one
	# documented conversion and one quantisation.
	var wire := []
	for family in TreePalette.FAMILIES:
		wire.append([_swatch_bytes(Look.to_wire(TreePalette.FAMILIES[family])),
			family])
	var bad := 0
	var checked := 0
	var seen := {}
	var sway_lo := 2.0
	var sway_hi := -1.0
	for variant in TreeModels.variants():
		var mesh := TreeModels.mesh_for(variant, 0, 0.5)
		if mesh == null:
			continue
		var cols: PackedColorArray = mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
		var wrong := 0
		for c in cols:
			checked += 1
			var got := _swatch_bytes(c)
			var hit := &""
			for entry in wire:
				var want: Vector3i = entry[0]
				if absi(want.x - got.x) <= 1 and absi(want.y - got.y) <= 1 \
						and absi(want.z - got.z) <= 1:
					hit = entry[1]
					break
			if hit == &"":
				wrong += 1
			else:
				seen[hit] = true
			# THE SWAY WEIGHT RIDES IN ALPHA and must stay inside 0..1, or the
			# shader squares a number bigger than one and a crown leaves the
			# frame. Checked here because this is the only place that reads
			# every vertex the loader wrote.
			sway_lo = minf(sway_lo, c.a)
			sway_hi = maxf(sway_hi, c.a)
		if wrong > 0:
			print("  %s: %d of %d vertex colours are not an authored family" % [
				variant, wrong, cols.size()])
			bad += 1
	if sway_lo < 0.0 or sway_hi > 1.0:
		print("  the sway weight leaves 0..1: %.4f to %.4f" % [sway_lo, sway_hi])
		bad += 1
	# AND EVERY AUTHORED FAMILY SHOULD BE REACHABLE. A family nothing points at
	# is a colour nobody can see, which is worth knowing about rather than
	# failing on - `BARK_DEAD` is deliberately one of them.
	var unused := PackedStringArray()
	for family in TreePalette.FAMILIES:
		if not seen.has(family):
			unused.append(String(family))
	print("tree swatches: %d vertex colours over %d variants, %d variants wrong" % [
		checked, TreeModels.variants().size(), bad])
	print("  sway weight %.4f to %.4f; %d of %d families reachable%s" % [
		sway_lo, sway_hi, seen.size(), TreePalette.FAMILIES.size(),
		"" if unused.is_empty() else " (unused: %s)" % ", ".join(unused)])
	if checked == 0:
		print("  WARNING: no vertex colours in the sample - this proved nothing")
		return 1
	return bad


## THE CHUNK PARITY GATE. Mesher v1, Q8.
##
## IDENTICAL ARRAYS OR NOTHING. `KubikChunkMesher` is a transcription of
## `ChunkMesher.build_arrays_gd()` and the only useful question about a
## transcription is whether it says the same thing, so this compares every
## vertex, every normal, every index and every colour component TO THE BIT, and
## insists the quads come out in the same order as well. The sweep order is
## `d`, `slice`, `jv`, `iu` in both, so no canonical re-sort is needed; if a
## stage ever needs one, the status doc says so and why.
##
## EXACT ZERO IS REACHABLE HERE AND IT IS NOT AN ACCIDENT (Q3). The far mesher's
## gate has always allowed two ULPs on Windows, because it computes colour in
## C++ and gcc and MSVC round the last bit differently. This mesher computes no
## colour at all: GDScript builds a table of every colour that can be emitted
## and the C++ writes entries out of it by index. So the colour column reads
## 0.000000000 on every platform, and if it ever does not, something crossed the
## seam that should not have.
##
## THE CHUNKS ARE THE ONES THE OTHER TESTS ALREADY TRUST: the 5 x 5 x 3 window of
## seed 31337 that `ao cost` measures, which is real terrain at the altitudes
## terrain actually passes through, plus the four hand-built shapes
## `_test_winding` uses - `single` for a free-standing cube, `slab` for one big
## merge, `checker` for the worst case for merging, and `ledge` for the AO split.
## Both AO settings, because with AO on the mesher emits a DIFFERENT set of
## rectangles out of the same voxels and the splitting path is the new one.
func _test_chunk_parity():
	if not ClassDB.class_exists(ChunkMesher.CPP_CLASS):
		print("chunk parity: no c++ chunk mesher in this build, 0 checks")
		return 0
	if not ChunkMesher.class_present():
		print("chunk parity: c++ mesher stub, 0 checks")
		return 0

	var chunks: Array[Chunk] = []
	var solids: Array[Callable] = []

	var cfg := WorldgenConfig.new()
	var gen := TerrainGenerator.new(31337, cfg)
	gen.build_heightmap()
	for cx in range(-2, 3):
		for cz in range(-2, 3):
			var span := gen.column_surface_range(cx, cz)
			var cy := Chunk.floor_div(int(span.x), Chunk.SIZE)
			for k in 3:
				var c := Chunk.new(Vector3i(cx, cy + k, cz))
				gen.generate_into(c)
				chunks.append(c)
				solids.append(func(wx: int, wy: int, wz: int) -> bool:
					return gen.is_solid_at(wx, wy, wz))

	for case in ["single", "slab", "checker", "ledge"]:
		var c := Chunk.new(Vector3i(0, 0, 0))
		for y in Chunk.SIZE:
			for z in Chunk.SIZE:
				for x in Chunk.SIZE:
					var solid := false
					match case:
						"single": solid = (x == 8 and y == 8 and z == 8)
						"slab": solid = y < 6
						"checker": solid = ((x + y + z) % 2 == 0)
						"ledge": solid = (y < 6) or (x < 3 and y < 10)
					if solid:
						c.set_voxel(x, y, z, Block.STONE)
		chunks.append(c)
		solids.append(func(_a: int, _b: int, _c: int) -> bool: return false)

	var impl: Object = ClassDB.instantiate(ChunkMesher.CPP_CLASS)
	var compare_colours := bool(impl.has_colors())

	var bad := 0
	var checked := 0
	var quads := 0
	var worst_pos := 0.0
	var worst_normal := 0.0
	var worst_colour := 0.0
	var index_diffs := 0
	var count_diffs := 0
	var reported := 0

	# Both AO settings and 0.45 named outright - see `_measure_ao_cost`'s note
	# on why the config's own default is not the value to reach for here.
	for ao in [0.0, 0.45]:
		cfg.ao_strength = ao
		impl.setup(ChunkMesher.setup_args(cfg))
		for i in chunks.size():
			var chunk: Chunk = chunks[i]
			var solid: Callable = solids[i]
			# THE DISPATCHER'S OWN BORDER BUILDER, not a private one written for
			# the test: a harness that marshals its own arguments proves the
			# sweep and leaves the seam untested, and the seam is where a port
			# goes wrong.
			var borders := ChunkMesher.borders_from_callable(chunk, solid)
			var want := ChunkMesher.build_arrays_gd(chunk, solid, cfg, 31337)
			var got := ChunkMesher.arrays_from_cpp(impl.build(borders))
			checked += 1
			if want.is_empty() or got.is_empty():
				if not (want.is_empty() and got.is_empty()):
					count_diffs += 1
					bad += 1
					if reported < 3:
						reported += 1
						print("  chunk %s ao=%.2f: one mesher drew nothing (twin %s, c++ %s)" % [
							chunk.chunk_pos, ao,
							"empty" if want.is_empty() else "full",
							"empty" if got.is_empty() else "full"])
				continue
			var av: PackedVector3Array = want[Mesh.ARRAY_VERTEX]
			var bv: PackedVector3Array = got[Mesh.ARRAY_VERTEX]
			var an: PackedVector3Array = want[Mesh.ARRAY_NORMAL]
			var bn: PackedVector3Array = got[Mesh.ARRAY_NORMAL]
			var ac: PackedColorArray = want[Mesh.ARRAY_COLOR]
			var bc: PackedColorArray = got[Mesh.ARRAY_COLOR]
			var ai: PackedInt32Array = want[Mesh.ARRAY_INDEX]
			var bi: PackedInt32Array = got[Mesh.ARRAY_INDEX]
			quads += av.size() / 4
			if av.size() != bv.size() or ai.size() != bi.size():
				count_diffs += 1
				bad += 1
				if reported < 3:
					reported += 1
					print("  chunk %s ao=%.2f: %d verts / %d indices against %d / %d" % [
						chunk.chunk_pos, ao, av.size(), ai.size(),
						bv.size(), bi.size()])
				continue
			for k in av.size():
				worst_pos = maxf(worst_pos, _component_diff(av[k], bv[k]))
				worst_normal = maxf(worst_normal, _component_diff(an[k], bn[k]))
				if compare_colours:
					worst_colour = maxf(worst_colour, maxf(
						maxf(absf(ac[k].r - bc[k].r), absf(ac[k].g - bc[k].g)),
						maxf(absf(ac[k].b - bc[k].b), absf(ac[k].a - bc[k].a))))
			for k in ai.size():
				if ai[k] != bi[k]:
					index_diffs += 1
	if worst_pos > 0.0 or worst_normal > 0.0 or worst_colour > 0.0 or index_diffs > 0:
		bad += 1

	print("chunk parity: %d chunks, %d quads, max diff pos %.9f normal %.9f colour %s, %d indices differ%s" % [
		checked, quads, worst_pos, worst_normal,
		("%.9f" % worst_colour) if compare_colours else "skipped (stage 1)",
		index_diffs,
		"" if count_diffs == 0 else ", %d chunks differ in COUNT" % count_diffs])
	return 1 if bad > 0 else 0


static func _component_diff(a: Vector3, b: Vector3) -> float:
	return maxf(maxf(absf(a.x - b.x), absf(a.y - b.y)), absf(a.z - b.z))
