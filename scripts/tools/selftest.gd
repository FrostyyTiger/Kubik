extends SceneTree

## Worldgen and mesher self-tests, offline.
##
##     godot --headless --path . --script scripts/tools/selftest.gd
##
## Everything here checks something that is either invisible from inside the
## game, or only visible once you already know what you are looking at.
## Exits non-zero on failure, so CI can run it.

func _init() -> void:
	var failures := 0
	failures += _test_winding()
	failures += _test_tree_borders()
	failures += _test_chunk_determinism()
	failures += _test_day_cycle()
	failures += _test_config_contract()
	print("")
	print("SELFTEST: %s" % ("all passed" if failures == 0 else "%d FAILED" % failures))
	quit(1 if failures > 0 else 0)


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
func _test_winding() -> int:
	var bad := 0
	var checked := 0
	var quads := 0

	for case in ["single", "slab", "checker"]:
		var chunk := Chunk.new(Vector3i(0, 0, 0))
		for y in Chunk.SIZE:
			for z in Chunk.SIZE:
				for x in Chunk.SIZE:
					var solid := false
					match case:
						"single": solid = (x == 8 and y == 8 and z == 8)
						"slab": solid = y < 6
						"checker": solid = ((x + y + z) % 2 == 0)
					if solid:
						chunk.set_voxel(x, y, z, Block.STONE)

		var arrays := ChunkMesher.build_arrays(chunk, func(_a, _b, _c): return false, 1.0)
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
					print("  BAD %s: cross %s want %s" % [case, cross.normalized(), want])
			i += 3
		print("  %-8s %5d verts, %5d tris" % [case, v.size(), idx.size() / 3])

	print("winding: %d triangles checked, %d wrong, %d quads emitted" % [checked, bad, quads])
	return 1 if bad > 0 else 0


## THE CHUNK BORDER TEST.
##
## A tree is rooted in one chunk and reaches into its neighbours, so every
## chunk it touches has to draw its own share of it. TerrainGenerator does that
## by iterating candidate cells over a region wider than the chunk by
## tree_canopy_max. If that margin were too narrow, canopies would be sliced
## off at chunk boundaries - and only sometimes, depending on which chunks
## happened to be loaded, which is the worst kind of bug to be handed.
##
## The test: generate a chunk normally, then stamp every tree from a MUCH wider
## region into a second copy. Stamping is idempotent - trunk over trunk changes
## nothing, leaves are only drawn over air - so if the normal margin is wide
## enough the two chunks are identical byte for byte. If it is too narrow, the
## wide pass finds blocks the normal one missed.
func _test_tree_borders() -> int:
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
				var span := 6 * cfg.tree_canopy_max + Chunk.SIZE
				var c0x := Chunk.floor_div(cx * Chunk.SIZE - span, cfg.tree_cell_blocks)
				var c1x := Chunk.floor_div(cx * Chunk.SIZE + span, cfg.tree_cell_blocks)
				var c0z := Chunk.floor_div(cz * Chunk.SIZE - span, cfg.tree_cell_blocks)
				var c1z := Chunk.floor_div(cz * Chunk.SIZE + span, cfg.tree_cell_blocks)
				for tz in range(c0z, c1z + 1):
					for tx in range(c0x, c1x + 1):
						gen._stamp_tree(wide, tx, tz)

				tested += 1
				for i in Chunk.VOLUME:
					if narrow.voxels[i] != wide.voxels[i]:
						bad += 1
						break
				for i in Chunk.VOLUME:
					var id := narrow.voxels[i]
					if id == Block.LEAVES or id == Block.TRUNK:
						tree_blocks += 1

	print("tree borders: %d chunks, %d tree blocks, %d differed under a 6x margin" % [
		tested, tree_blocks, bad])
	if tree_blocks == 0:
		print("  WARNING: no tree blocks in the sample - this test proved nothing")
		return 1
	return 1 if bad > 0 else 0


## Same seed, same config, same chunks - byte for byte. This is the guarantee
## the whole terrain-is-never-sent contract rests on.
func _test_chunk_determinism() -> int:
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
func _test_day_cycle() -> int:
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
func _test_config_contract() -> int:
	var bad := 0

	var host_config := WorldgenConfig.new()
	host_config.mountain_amp += 37.0
	host_config.forest_max -= 11.0
	host_config.tree_probability = 0.21

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
