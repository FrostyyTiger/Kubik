extends SceneTree

## Checks the greedy mesher's output, offline.
##
##     godot --headless --path . --script scripts/tools/mesher_test.gd
##
## WINDING is the thing worth testing. Every triangle must satisfy
##
##     (p1 - p0) x (p2 - p0) == -normal
##
## which is the algebraic form of "clockwise seen from outside" - the face
## Godot draws, since back faces are culled. Getting it wrong does not make a
## face vanish, which you would notice: it turns the world inside out, so you
## see the far side of the terrain through the near side, and it is only
## obvious once you already know what you are looking at.
##
## The three shapes between them cover every face direction, both signs, merged
## runs, and the worst case for merging.
##
## This test earned its keep immediately: it caught a fresh Chunk defaulting to
## has_air = false, which made the mesher treat a hand-built chunk as solid
## throughout and skip all of its interior faces.

func _init() -> void:
	var cfg := WorldgenConfig.new()
	var bad := 0
	var checked := 0
	var quads := 0

	# Three shapes that between them exercise every face direction, both signs,
	# merged runs, and chunk-boundary faces.
	for case in ["single", "slab", "checker"]:
		var chunk := Chunk.new(Vector3i(0, 0, 0))
		for y in Chunk.SIZE:
			for z in Chunk.SIZE:
				for x in Chunk.SIZE:
					var solid := false
					match case:
						"single": solid = (x == 8 and y == 8 and z == 8)
						"slab":   solid = y < 6
						"checker": solid = ((x + y + z) % 2 == 0)
					if solid:
						chunk.set_voxel(x, y, z, Block.STONE)
		var arrays := ChunkMesher.build_arrays(chunk, func(_a, _b, _c): return false, 1.0)
		if arrays.is_empty():
			print("%s: EMPTY" % case)
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
		print("%s: %d verts, %d tris" % [case, v.size(), idx.size() / 3])

	print("winding: %d triangles checked, %d wrong, %d quads emitted" % [checked, bad, quads])
	quit()
