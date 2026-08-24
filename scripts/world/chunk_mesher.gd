class_name ChunkMesher

## Turns a Chunk's voxels into mesh arrays.
##
## COLOUR COMES FROM THE VERTICES, NOT A TEXTURE. The world is read at a
## distance - the whole design is sold on being able to tell a meadow from a
## forest from a snowfield across a valley - and flat saturated colour reads
## further and more clearly than any 16x16 texture would.
##
## assets/textures/block_placeholder.png and its committed .import settings are
## unused as of Stage 3. They are left in the repo rather than deleted, because
## a texture atlas with per-face UVs is still on the roadmap and the import
## settings were the fiddly part to get right.
##
##
## GREEDY MESHING
##
## The naive version emitted one quad per exposed block face. It was easy to
## verify and it was measured, on this world, at 16.7 ms per chunk against
## 1.9 ms to generate the voxels in the first place - meshing dominated 9 to 1,
## which is what justified replacing it rather than assuming it needed to be.
##
## Greedy meshing merges adjacent faces that share a plane, a direction and a
## colour into one large quad. A flat meadow chunk goes from 256 top quads to
## 1. The saving is not in the triangle count so much as in the work: the naive
## mesher's time went almost entirely into pushing four vertices per face into
## packed arrays, and merging removes most of those pushes.
##
## The algorithm sweeps the chunk three times, once per axis. For each of the
## 17 planes between (and either side of) the 16 layers of blocks, it builds a
## 16x16 MASK of which faces are visible there and what colour they are, then
## repeatedly takes the largest rectangle of equal values out of the mask.
## Encoding the direction as the SIGN of the mask value is what lets one pass
## handle both facings of a plane at once.

## For each sweep axis d, which axes play the roles of u and v.
##
## The triples are chosen so that (u, v, d) is right-handed - u cross v == d.
## That is not cosmetic: the winding order of the emitted quads is derived from
## it, and a left-handed triple silently turns the world inside out.
const AXIS_U := [1, 2, 0]   # d = X -> u = Y ; d = Y -> u = Z ; d = Z -> u = X
const AXIS_V := [2, 0, 1]   # d = X -> v = Z ; d = Y -> v = X ; d = Z -> v = Y

static var _material: StandardMaterial3D = null


## Build the surface arrays for `chunk`.
##
## `solid_outside` is called as solid_outside.call(wx, wy, wz) -> bool and ONLY
## for neighbours outside this chunk. We cannot answer those ourselves, and
## answering "air" would draw a wall of faces at every chunk seam.
##
## `block_size` is metres per block. The arrays come out in metres so the node
## holding them needs no scale: a scaled node scales its collision shape too,
## and scaled physics shapes are a class of bug nobody should have to debug.
##
## Returns an empty Array for a chunk with nothing to draw. This function
## touches no scene state and no rendering API, which is what lets it run on a
## worker thread.
static func build_arrays(chunk: Chunk, solid_outside: Callable, block_size: float) -> Array:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()

	# A chunk with no solid blocks has no faces at all - not even at its
	# boundary, because a face is only ever drawn by the chunk that owns the
	# SOLID side of it. Most of a heightmap world is empty sky, so this one
	# test skips the whole sweep for a large fraction of all chunks.
	if not chunk.has_solid:
		return []

	var origin := chunk.origin()
	var size := Chunk.SIZE
	var mask := PackedInt32Array()
	mask.resize(size * size)

	# A chunk with no air in it can only have faces where it meets the outside
	# world, so only the two outermost planes of each axis can carry any. The
	# other 15 are guaranteed empty and sweeping them is pure cost - and
	# underground chunks are the other large fraction of the world.
	var solid_throughout := not chunk.has_air

	for d in 3:
		var u: int = AXIS_U[d]
		var v: int = AXIS_V[d]

		# slice is the coordinate of the block on the NEGATIVE side of the
		# plane. It starts at -1 so the chunk's own outer face is considered,
		# and ends at size - 1 so the far outer face is too.
		for slice in range(-1, size):
			if solid_throughout and slice != -1 and slice != size - 1:
				continue
			var a_in := slice >= 0
			var b_in := slice + 1 < size
			var has_face := false

			for jv in size:
				for iu in size:
					var a := Vector3i.ZERO
					a[d] = slice
					a[u] = iu
					a[v] = jv
					var b := a
					b[d] = slice + 1

					var id_a := 0
					var solid_a := false
					if a_in:
						id_a = chunk.voxels[Chunk.index(a.x, a.y, a.z)]
						solid_a = id_a != Block.AIR
					else:
						solid_a = solid_outside.call(
							origin.x + a.x, origin.y + a.y, origin.z + a.z)

					var id_b := 0
					var solid_b := false
					if b_in:
						id_b = chunk.voxels[Chunk.index(b.x, b.y, b.z)]
						solid_b = id_b != Block.AIR
					else:
						solid_b = solid_outside.call(
							origin.x + b.x, origin.y + b.y, origin.z + b.z)

					# A face exists only where solid meets air, and we draw it
					# only if the SOLID side is a block of ours - otherwise the
					# neighbouring chunk would draw the same face as well and
					# the two would z-fight.
					var m := 0
					if solid_a != solid_b:
						if solid_a:
							if a_in:
								m = id_a          # faces along +d
						elif b_in:
							m = -id_b             # faces along -d
					mask[iu + jv * size] = m
					if m != 0:
						has_face = true

			if has_face:
				_emit_slice(mask, size, d, u, v, slice + 1, block_size,
					verts, normals, colors, indices)

	if verts.is_empty():
		return []

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	return arrays


## Take rectangles out of one mask until it is empty.
##
## For each cell still set, grow right as far as the value repeats, then grow
## down as far as every cell of that width matches, emit the rectangle, and
## clear it. Greedy rather than optimal: finding the genuinely minimal set of
## rectangles is expensive, and this gets within a few percent of it for the
## shapes terrain actually makes.
static func _emit_slice(mask: PackedInt32Array, size: int, d: int, u: int, v: int,
		plane: int, block_size: float,
		verts: PackedVector3Array, normals: PackedVector3Array,
		colors: PackedColorArray, indices: PackedInt32Array) -> void:
	for jv in size:
		var iu := 0
		while iu < size:
			var value := mask[iu + jv * size]
			if value == 0:
				iu += 1
				continue

			var w := 1
			while iu + w < size and mask[iu + w + jv * size] == value:
				w += 1

			var h := 1
			while jv + h < size:
				var row_matches := true
				for k in w:
					if mask[iu + k + (jv + h) * size] != value:
						row_matches = false
						break
				if not row_matches:
					break
				h += 1

			_emit_quad(d, u, v, plane, iu, jv, w, h, value, block_size,
				verts, normals, colors, indices)

			for dv in h:
				for du in w:
					mask[iu + du + (jv + dv) * size] = 0
			iu += w


static func _emit_quad(d: int, u: int, v: int, plane: int,
		u0: int, v0: int, w: int, h: int, value: int, block_size: float,
		verts: PackedVector3Array, normals: PackedVector3Array,
		colors: PackedColorArray, indices: PackedInt32Array) -> void:
	var positive := value > 0
	var color := Block.color_of(absi(value))

	var normal := Vector3.ZERO
	normal[d] = 1.0 if positive else -1.0

	var u1 := u0 + w
	var v1 := v0 + h

	# WINDING ORDER MATTERS. Godot's front face is the CLOCKWISE one as seen
	# from the front and back faces are culled, so a mistake here does not make
	# one face vanish - it turns the world inside out, and you see the far side
	# of the terrain through the near side.
	#
	# With (u, v, d) right-handed, these two orders satisfy
	# (p1 - p0) x (p2 - p0) == -normal, which is the algebraic form of
	# "clockwise seen from outside". Check any new face against that identity
	# rather than eyeballing it in-engine.
	var corners: Array
	if positive:
		corners = [[u0, v0], [u0, v1], [u1, v1], [u1, v0]]
	else:
		corners = [[u0, v0], [u1, v0], [u1, v1], [u0, v1]]

	var first := verts.size()
	for c in corners:
		var p := Vector3.ZERO
		p[d] = float(plane)
		p[u] = float(c[0])
		p[v] = float(c[1])
		verts.push_back(p * block_size)
		normals.push_back(normal)
		colors.push_back(color)

	indices.push_back(first)
	indices.push_back(first + 1)
	indices.push_back(first + 2)
	indices.push_back(first)
	indices.push_back(first + 2)
	indices.push_back(first + 3)


## Wrap finished arrays in an ArrayMesh. MUST run on the main thread - this is
## the only part of meshing that touches the rendering server, which is exactly
## why build_arrays() returns arrays instead of a mesh.
static func arrays_to_mesh(arrays: Array) -> ArrayMesh:
	if arrays.is_empty():
		return null
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, get_material())
	return mesh


## Synchronous build, for the one chunk changed by an edit. Bulk loading goes
## through build_arrays() on a worker thread instead.
static func build(chunk: Chunk, world_solid: Callable, block_size: float) -> ArrayMesh:
	return arrays_to_mesh(build_arrays(chunk, world_solid, block_size))


## One shared material for every chunk. Sharing it means the renderer can batch
## chunks together; a material per chunk would defeat that.
static func get_material() -> StandardMaterial3D:
	if _material == null:
		var m := StandardMaterial3D.new()
		# The entire surface appearance: the per-block colour baked into the
		# vertices IS the albedo. No texture, no UVs in the vertex stream.
		m.vertex_color_use_as_albedo = true
		# Note there is no vertex_color_is_srgb here: the palette in Block is
		# already stored linear. That flag is ignored by the Compatibility
		# renderer, and this has to look the same on both.
		# Terrain is soil, grass, rock and snow. None of them are shiny, and a
		# specular highlight sliding across a hillside as you walk is the
		# fastest way to make a matte world look like wet plastic.
		m.roughness = 1.0
		m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
		_material = m
	return _material
