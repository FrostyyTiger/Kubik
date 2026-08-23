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
