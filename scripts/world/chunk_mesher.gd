class_name ChunkMesher

## Turns a Chunk's voxels into one ArrayMesh.
##
## "Naive" here means: one quad per block face that touches air, no merging of
## coplanar faces. It is O(voxels) and easy to verify. The payoff is already
## large - a solid chunk underground emits zero triangles, and the whole chunk
## is a single draw call instead of 4096.
##
## Greedy meshing (merging adjacent identical faces into big quads) is the next
## optimisation, but only once we can measure that this is the bottleneck.

const BLOCK_TEXTURE := preload("res://assets/textures/block_placeholder.png")

## Face order used by every table below: +Y, -Y, +X, -X, +Z, -Z.
const FACE_NORMALS := [
	Vector3i(0, 1, 0),
	Vector3i(0, -1, 0),
	Vector3i(1, 0, 0),
	Vector3i(-1, 0, 0),
	Vector3i(0, 0, 1),
	Vector3i(0, 0, -1),
]

## Corner offsets of each face, relative to the block's minimum corner.
##
## WINDING ORDER MATTERS. Godot's front face is the CLOCKWISE one as seen from
## the front, and back faces are culled - so a mistake here does not make one
## face vanish, it turns the entire world inside out (you see the far side of
## the terrain through the near side).
##
## Each row below satisfies (v1 - v0) x (v2 - v0) == -normal, which is the
## algebraic form of "clockwise seen from outside". If you ever add a face,
## check it against that identity rather than eyeballing it in-engine.
const FACE_CORNERS := [
	[Vector3(0, 1, 0), Vector3(1, 1, 0), Vector3(1, 1, 1), Vector3(0, 1, 1)], # +Y top
	[Vector3(0, 0, 0), Vector3(0, 0, 1), Vector3(1, 0, 1), Vector3(1, 0, 0)], # -Y bottom
	[Vector3(1, 0, 0), Vector3(1, 0, 1), Vector3(1, 1, 1), Vector3(1, 1, 0)], # +X east
	[Vector3(0, 0, 0), Vector3(0, 1, 0), Vector3(0, 1, 1), Vector3(0, 0, 1)], # -X west
	[Vector3(0, 0, 1), Vector3(0, 1, 1), Vector3(1, 1, 1), Vector3(1, 0, 1)], # +Z south
	[Vector3(0, 0, 0), Vector3(1, 0, 0), Vector3(1, 1, 0), Vector3(0, 1, 0)], # -Z north
]

const FACE_UVS := [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]

static var _material: StandardMaterial3D = null


## Build the mesh for `chunk`.
##
## `world_solid` is called as world_solid.call(wx, wy, wz) -> bool and is only
## used for neighbours OUTSIDE this chunk. We cannot answer those ourselves,
## and answering "air" would draw a wall of faces at every chunk seam.
##
## Returns null for a chunk with nothing to draw - Godot refuses a surface with
## zero vertices, and a null mesh is the cheapest possible "nothing here".
static func build(chunk: Chunk, world_solid: Callable) -> ArrayMesh:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()

	var origin := chunk.origin()

	# y -> z -> x with x innermost matches Chunk.index()'s memory layout.
	for y in Chunk.SIZE:
		for z in Chunk.SIZE:
			for x in Chunk.SIZE:
				var id := chunk.voxels[Chunk.index(x, y, z)]
				if id == Block.AIR:
					continue

				var color := Block.color_of(id)
				var base := Vector3(x, y, z)

				for f in 6:
					var n: Vector3i = FACE_NORMALS[f]
					var nx := x + n.x
					var ny := y + n.y
					var nz := z + n.z

					var neighbour_solid: bool
					if Chunk.in_bounds(nx, ny, nz):
						neighbour_solid = Block.is_solid(chunk.voxels[Chunk.index(nx, ny, nz)])
					else:
						neighbour_solid = world_solid.call(
							origin.x + nx, origin.y + ny, origin.z + nz)

					# Hidden face: the whole point of the exercise.
					if neighbour_solid:
						continue

					var corners: Array = FACE_CORNERS[f]
					var face_normal := Vector3(n.x, n.y, n.z)
					var first := verts.size()

					for c in 4:
						verts.push_back(base + corners[c])
						normals.push_back(face_normal)
						uvs.push_back(FACE_UVS[c])
						colors.push_back(color)

					# Quad as two triangles, preserving the corner order.
					indices.push_back(first)
					indices.push_back(first + 1)
					indices.push_back(first + 2)
					indices.push_back(first)
					indices.push_back(first + 2)
					indices.push_back(first + 3)

	if verts.is_empty():
		return null

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, get_material())
	return mesh


## One shared material for every chunk. Sharing it means the renderer can batch
## chunks together; a material per chunk would defeat that.
static func get_material() -> StandardMaterial3D:
	if _material == null:
		var m := StandardMaterial3D.new()
		m.albedo_texture = BLOCK_TEXTURE
		# Nearest keeps the pixels crisp instead of blurring them; mipmaps stop
		# distant blocks from shimmering as the camera moves.
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
		# This is what lets one greyscale texture serve every block type: the
		# per-block colour we baked into the vertices multiplies the albedo.
		m.vertex_color_use_as_albedo = true
		_material = m
	return _material
