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
##
##
## BAKED AMBIENT OCCLUSION, AND WHY IT FIGHTS GREEDY MESHING
##
## A greedy-meshed hillside in flat vertex colour carries no edge information
## at all: an entire slope is literally one colour, so the eye has nothing to
## grab and the world reads as smooth shapes rather than as stacked cubes.
## Corner AO is the standard fix and it is what makes a voxel world look like
## one - each vertex is darkened by how many of the three blocks meeting at
## that corner (two sides and the diagonal) are solid.
##
## The two techniques are in direct conflict. Merging assumes every cell in a
## quad looks identical; AO makes cells next to a wall differ from cells in the
## open. So the AO code joins the mask, and a run only merges while BOTH the
## block id and the four corner AO values repeat.
##
## That is not merely conservative, it is exactly right, and the reason is
## worth stating because it is what makes the interpolation across a merged
## quad correct rather than approximate. Two side-by-side cells SHARE two
## lattice corners, and a shared corner is computed from the same three blocks
## by both, so it gets the same value in both. If their AO codes are equal,
## then each cell's leading corner equals its own trailing corner - the code is
## constant along the run - and a linear interpolation across the merged quad
## reproduces every cell it swallowed. A run that would have needed a gradient
## cannot form in the first place, because its codes would differ and the merge
## would stop.

## For each sweep axis d, which axes play the roles of u and v.
##
## The triples are chosen so that (u, v, d) is right-handed - u cross v == d.
## That is not cosmetic: the winding order of the emitted quads is derived from
## it, and a left-handed triple silently turns the world inside out.
const AXIS_U := [1, 2, 0]   # d = X -> u = Y ; d = Y -> u = Z ; d = Z -> u = X
const AXIS_V := [2, 0, 1]   # d = X -> v = Z ; d = Y -> v = X ; d = Z -> v = Y

## Four corner AO levels of 3 (fully open), packed two bits each. The value a
## face carries when AO is switched off, so the merge test behaves identically
## to the pre-AO mesher rather than needing a second code path.
const AO_OPEN := 0xFF

## Corner order inside a packed AO code: index = su + sv * 2, where su and sv
## are 0 for the u0/v0 side of the cell and 1 for the u1/v1 side.
##
## CANONICAL, and deliberately NOT the order the quad's vertices come out in -
## that order differs between the two facings, and a code whose meaning
## depended on the facing could not be compared between neighbouring cells.
const AO_CORNER_U0V0 := 0
const AO_CORNER_U1V0 := 1
const AO_CORNER_U0V1 := 2
const AO_CORNER_U1V1 := 3

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
## `config` is the world's SNAPSHOT of its tuning values - World clones it at
## setup and never writes to it again - so reading it from a worker thread is
## safe and needs no copying. It replaced a growing list of loose float
## parameters at Stage 10, when per-vertex tinting added five more.
## `canopy_cover` is how much of this column's sky its own trees cover, 0 to 1,
## and it darkens the ground under them - world feel v1 Stage 6.
##
## SHADE IS AN INK (look v2 rule 1), so this is not a multiply: the colour keeps
## its luminance and takes the shade's HUE, in proportion to
## `cover * canopy_shade`. A multiply would darken and desaturate together and
## give the forest floor a grey cast; the ink gives it the same violet the
## ramp's shade band uses, which is what makes a wood read as shaded rather
## than as underexposed.
##
## AND IT IS AN AUTHORING STEP, NOT A TRANSFER CHANGE. It happens to the vertex
## colour before Look.to_wire(), exactly where baked AO happens, so look v2's
## rule 4 - what is authored is what is on screen - is untouched and the swatch
## sheet does not move.
static func build_arrays(chunk: Chunk, solid_outside: Callable,
		config: WorldgenConfig, world_seed: int, canopy_cover := 0.0,
		shade_ink := Color(0.25, 0.29, 0.55, 1.0)) -> Array:
	var canopy_mix := clampf(canopy_cover, 0.0, 1.0) * config.canopy_shade
	var block_size: float = config.block_size
	var ao_strength: float = config.ao_strength
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
	# Parallel to `mask`, one packed AO code per face cell. Separate rather than
	# folded into the mask value because the mask's sign already carries the
	# facing, and stuffing a third field into one int would make the one line
	# that decides whether two faces may merge unreadable.
	var ao_mask := PackedInt32Array()
	ao_mask.resize(size * size)
	var want_ao := ao_strength > 0.0

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
						# The air is on the far side of the face from the solid
						# block, and AO is a question about the air side: which
						# of the blocks around this corner are in the way of
						# light arriving.
						ao_mask[iu + jv * size] = _corner_ao(
							chunk, origin, solid_outside, d, u, v,
							slice + 1 if m > 0 else slice, iu, jv) if want_ao else AO_OPEN
					else:
						ao_mask[iu + jv * size] = AO_OPEN

			if has_face:
				_emit_slice(mask, ao_mask, size, d, u, v, slice + 1,
					config, world_seed, origin,
					verts, normals, colors, indices, canopy_mix, shade_ink)

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
static func _emit_slice(mask: PackedInt32Array, ao_mask: PackedInt32Array, size: int,
		d: int, u: int, v: int, plane: int,
		config: WorldgenConfig, world_seed: int, origin: Vector3i,
		verts: PackedVector3Array, normals: PackedVector3Array,
		colors: PackedColorArray, indices: PackedInt32Array,
		canopy_mix := 0.0,
		shade_ink := Color(0.25, 0.29, 0.55, 1.0)) -> void:
	for jv in size:
		var iu := 0
		while iu < size:
			var value := mask[iu + jv * size]
			if value == 0:
				iu += 1
				continue
			# The AO code is part of the identity of a face, so a run stops
			# where the shading changes even though the blocks are identical.
			# With AO off every code is AO_OPEN and this reduces exactly to the
			# pre-AO behaviour.
			var ao_value := ao_mask[iu + jv * size]

			var w := 1
			while iu + w < size and mask[iu + w + jv * size] == value \
					and ao_mask[iu + w + jv * size] == ao_value:
				w += 1

			var h := 1
			while jv + h < size:
				var row_matches := true
				for k in w:
					if mask[iu + k + (jv + h) * size] != value \
							or ao_mask[iu + k + (jv + h) * size] != ao_value:
						row_matches = false
						break
				if not row_matches:
					break
				h += 1

			_emit_quad(d, u, v, plane, iu, jv, w, h, value, ao_value,
				config, world_seed, origin, verts, normals, colors, indices,
				canopy_mix, shade_ink)

			for dv in h:
				for du in w:
					mask[iu + du + (jv + dv) * size] = 0
			iu += w


static func _emit_quad(d: int, u: int, v: int, plane: int,
		u0: int, v0: int, w: int, h: int, value: int, ao_value: int,
		config: WorldgenConfig, world_seed: int, origin: Vector3i,
		verts: PackedVector3Array, normals: PackedVector3Array,
		colors: PackedColorArray, indices: PackedInt32Array,
		canopy_mix := 0.0,
		shade_ink := Color(0.25, 0.29, 0.55, 1.0)) -> void:
	var positive := value > 0
	var block_size: float = config.block_size
	var ao_strength: float = config.ao_strength
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
	# The second entry of each pair is the CANONICAL AO corner this vertex is,
	# which is why the two lists are not just reorderings of the same four
	# points - the winding differs between facings and the AO code does not.
	var corners: Array
	if positive:
		corners = [
			[u0, v0, AO_CORNER_U0V0], [u0, v1, AO_CORNER_U0V1],
			[u1, v1, AO_CORNER_U1V1], [u1, v0, AO_CORNER_U1V0]]
	else:
		corners = [
			[u0, v0, AO_CORNER_U0V0], [u1, v0, AO_CORNER_U1V0],
			[u1, v1, AO_CORNER_U1V1], [u0, v1, AO_CORNER_U0V1]]

	# Aspect and slope are properties of the FACE, so they are computed once for
	# the whole quad. Only the jitter varies from corner to corner.
	var shaded := Block.aspect_shade(color, normal, config.slope_tint, config.aspect_tint)

	var first := verts.size()
	for c in corners:
		var p := Vector3.ZERO
		p[d] = float(plane)
		p[u] = float(c[0])
		p[v] = float(c[1])
		verts.push_back(p * block_size)
		normals.push_back(normal)
		# The palette is stored LINEAR (see Block), and occlusion is a
		# multiplication in linear space - so this is a plain scale, not a
		# blend towards a darker colour, and it stays correct if the palette
		# is re-authored.
		var level: int = (ao_value >> (int(c[2]) * 2)) & 3
		var shade := 1.0 - ao_strength * (1.0 - _ao_curve(level))
		# Jitter is sampled at the corner's WORLD position, so two quads meeting
		# at a lattice point agree about it and the field is continuous across
		# chunk boundaries as well as across quad boundaries.
		var tinted := Block.jitter(shaded,
			origin.x + int(p.x), origin.z + int(p.z), world_seed,
			config.color_jitter_blocks, config.color_jitter_value,
			config.color_jitter_hue)
		# sRGB on the wire: the AO multiply above is linear, this is the one
		# conversion, and it is the last thing before the push. See Look.to_wire.
		var lit := Color(tinted.r * shade, tinted.g * shade,
			tinted.b * shade, tinted.a)
		if canopy_mix > 0.0:
			lit = _under_canopy(lit, canopy_mix, shade_ink)
		colors.push_back(Look.to_wire(lit))

	indices.push_back(first)
	indices.push_back(first + 1)
	indices.push_back(first + 2)
	indices.push_back(first)
	indices.push_back(first + 2)
	indices.push_back(first + 3)


## Wrap finished arrays in an ArrayMesh. MUST run on the main thread - this is
## the only part of meshing that touches the rendering server, which is exactly
## why build_arrays() returns arrays instead of a mesh.
## The triangle soup `ArrayMesh.create_trimesh_shape()` would derive: every
## index expanded to its vertex, three at a time.
##
## WHY IT IS HERE AND NOT ON THE MAIN THREAD (world feel v1 Stage 1). Deriving
## the collision shape from a finished ArrayMesh is pure arithmetic over the
## index buffer - no server call, no Resource - and it was being done on the
## main thread for every chunk. On a worker it leaves the main thread
## `ConcavePolygonShape3D.new()` and `set_faces()`: one allocation and one
## memcpy. See ChunkNode.apply_arrays().
static func faces_from(mesh_arrays: Array) -> PackedVector3Array:
	if mesh_arrays.is_empty():
		return PackedVector3Array()
	var verts: PackedVector3Array = mesh_arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = mesh_arrays[Mesh.ARRAY_INDEX]
	var faces := PackedVector3Array()
	faces.resize(indices.size())
	for i in indices.size():
		faces[i] = verts[indices[i]]
	return faces


## Take the shade ink's hue, keep the luminance. See build_arrays().
##
## THE INK IS PASSED IN, NOT FETCHED. It lives in a global shader parameter, and
## reading one means calling RenderingServer - which a worker thread must never
## do, and which this did once per VERTEX. The world still loaded, so nothing
## looked broken; it took 466 seconds instead of 30. Captured on the main
## thread at submit time, in World._submit_column().
static func _under_canopy(c: Color, mix: float, ink: Color) -> Color:
	var lum := Look.luma(c)
	var ink_lum := maxf(Look.luma(ink), 0.0001)
	# The ink at THIS colour's luminance, so only the hue crosses over.
	var k := lum / ink_lum
	var tinted := Color(ink.r * k, ink.g * k, ink.b * k, c.a)
	return c.lerp(tinted, mix)


static func arrays_to_mesh(arrays: Array) -> ArrayMesh:
	if arrays.is_empty():
		return null
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, get_material())
	return mesh


## Synchronous build, for the one chunk changed by an edit. Bulk loading goes
## through build_arrays() on a worker thread instead.
static func build(chunk: Chunk, world_solid: Callable,
		config: WorldgenConfig, world_seed: int) -> ArrayMesh:
	return arrays_to_mesh(build_arrays(chunk, world_solid, config, world_seed))


## One shared material for every chunk. Sharing it means the renderer can batch
## chunks together; a material per chunk would defeat that.
##
## SINCE LOOK V1 IT IS THE POSTER MATERIAL, shared with the far field, the far
## trees and the characters - see Look. What it keeps from the terrain v1
## StandardMaterial3D: the per-block colour baked into the vertices IS the
## albedo, no texture, no UVs in the vertex stream, and nothing shiny, because
## a specular highlight sliding across a hillside as you walk is the fastest
## way to make a matte world look like wet plastic. What it adds is the ramp.
static func get_material() -> Material:
	return Look.opaque_material()


# --- Corner ambient occlusion -----------------------------------------------

## The four corner AO levels of one face cell, packed two bits each in
## canonical (su + sv * 2) order.
##
## `air_d` is the d-coordinate of the block on the AIR side of the face. AO is
## a question about that side and only that side: how much of the sky arriving
## at this corner is blocked by the blocks standing around it.
static func _corner_ao(chunk: Chunk, origin: Vector3i, solid_outside: Callable,
		d: int, u: int, v: int, air_d: int, iu: int, jv: int) -> int:
	# The eight blocks around the air block, in its own plane. The centre is
	# the air block itself and is not asked about.
	var n00 := _solid_at(chunk, origin, solid_outside, d, u, v, air_d, iu - 1, jv - 1)
	var n10 := _solid_at(chunk, origin, solid_outside, d, u, v, air_d, iu, jv - 1)
	var n20 := _solid_at(chunk, origin, solid_outside, d, u, v, air_d, iu + 1, jv - 1)
	var n01 := _solid_at(chunk, origin, solid_outside, d, u, v, air_d, iu - 1, jv)
	var n21 := _solid_at(chunk, origin, solid_outside, d, u, v, air_d, iu + 1, jv)
	var n02 := _solid_at(chunk, origin, solid_outside, d, u, v, air_d, iu - 1, jv + 1)
	var n12 := _solid_at(chunk, origin, solid_outside, d, u, v, air_d, iu, jv + 1)
	var n22 := _solid_at(chunk, origin, solid_outside, d, u, v, air_d, iu + 1, jv + 1)

	return _vertex_ao(n01, n10, n00) \
		| (_vertex_ao(n21, n10, n20) << 2) \
		| (_vertex_ao(n01, n12, n02) << 4) \
		| (_vertex_ao(n21, n12, n22) << 6)


## AO level 0 (darkest) to 3 (fully open) for one corner.
##
## THE SPECIAL CASE IS THE WHOLE POINT. When both SIDES are solid the corner is
## in an interior angle and it makes no difference whether the diagonal block
## is there too - you cannot see past two walls meeting. Without this test the
## inside of every corner would come out one step lighter where the diagonal
## happens to be missing, which reads as a bright seam running up the join
## between two walls.
static func _vertex_ao(side1: bool, side2: bool, corner: bool) -> int:
	if side1 and side2:
		return 0
	return 3 - (int(side1) + int(side2) + int(corner))


## Is the block at these (d, u, v) chunk-local coordinates solid?
##
## Reads the chunk's own array where it can and only falls back to the Callable
## outside it. That branch is worth writing out: AO asks about eight blocks per
## face and a Callable invocation in GDScript costs far more than an array
## index, so routing the interior through the Callable as well would have made
## meshing several times more expensive for no difference in the result.
static func _solid_at(chunk: Chunk, origin: Vector3i, solid_outside: Callable,
		d: int, u: int, v: int, dd: int, uu: int, vv: int) -> bool:
	var p := Vector3i.ZERO
	p[d] = dd
	p[u] = uu
	p[v] = vv
	if Chunk.in_bounds(p.x, p.y, p.z):
		return chunk.voxels[Chunk.index(p.x, p.y, p.z)] != Block.AIR
	return solid_outside.call(origin.x + p.x, origin.y + p.y, origin.z + p.z)


## TODO(marcel): the AO curve is a straight line and probably should not be.
##
## This maps a corner's occlusion level - 0 for fully enclosed, 3 for fully
## open - onto how bright it is drawn. Straight-line is the obvious choice and
## it spreads the darkening evenly over all four levels, which means level 2
## (one neighbour solid) is already noticeably dark. Most of a voxel world is
## level 2, so most of the world gets a little dirty and the true corners never
## get to be dramatic.
##
##   Hint: try  var t := float(level) / 3.0  and then  return t * t
##   Squaring pulls the middle levels back up towards full brightness while
##   leaving level 0 at zero, so the darkening concentrates where two surfaces
##   genuinely meet.
##
##   pow(t, 0.5) is the other direction and is worth one look, if only to see
##   what "too much AO" is: it darkens the open ground and reads as grime.
##
## Reroll is not needed - AO is baked at mesh time, so F7 or walking away and
## back is enough to see a change.
##
## Fallback: linear, which is what every voxel game does by default and looks
## perfectly reasonable.
static func _ao_curve(level: int) -> float:
	return float(level) / 3.0
