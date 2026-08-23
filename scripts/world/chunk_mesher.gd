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
##
## COLOUR COMES FROM THE VERTICES, NOT A TEXTURE. The world is read at a
## distance - the whole design is sold on being able to tell a meadow from a
## forest from a snowfield across a valley - and flat saturated colour reads
## further and more clearly than any 16x16 texture would. It is also free:
## the colours are already in the vertex stream for the mesher to batch by.
##
## assets/textures/block_placeholder.png and its committed .import settings are
## therefore unused as of this stage. They are left in the repo rather than
## deleted, because a texture atlas with per-face UVs is still on the roadmap
## and the import settings are the part that was fiddly to get right.

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

static var _material: StandardMaterial3D = null


## Build the mesh for `chunk`.
##
## `world_solid` is called as world_solid.call(wx, wy, wz) -> bool and is only
## used for neighbours OUTSIDE this chunk. We cannot answer those ourselves,
## and answering "air" would draw a wall of faces at every chunk seam.
##
## `block_size` is metres per block. The mesh is built in metres rather than in
## block units so that the node holding it needs no scale: a scaled node scales
## its collision shape too, and scaled physics shapes are a class of bug nobody
## should have to debug at 1 a.m.
##
## Returns null for a chunk with nothing to draw - Godot refuses a surface with
## zero vertices, and a null mesh is the cheapest possible "nothing here".
static func build(chunk: Chunk, world_solid: Callable, block_size: float) -> ArrayMesh:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
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
						verts.push_back((base + corners[c]) * block_size)
						normals.push_back(face_normal)
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
		# The entire surface appearance: the per-block colour baked into the
		# vertices IS the albedo. No texture, no UVs in the vertex stream.
		m.vertex_color_use_as_albedo = true
		# Terrain is soil, grass, rock and snow. None of them are shiny, and a
		# specular highlight sliding across a hillside as you walk is the
		# fastest way to make a matte world look like wet plastic.
		m.roughness = 1.0
		m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
		_material = m
	return _material
