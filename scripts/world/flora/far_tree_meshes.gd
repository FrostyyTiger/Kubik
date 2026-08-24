class_name FarTreeMeshes

## The impostor shapes - one per species, six to twelve triangles each.
##
## EVERY MESH IS A UNIT SHAPE: one unit tall, one unit across, standing on the
## origin. The MultiMesh transform carries the real height and crown width, so
## one cone serves every spruce in the world at every size it can grow to. That
## is the whole economy of the ring - nineteen species-sized meshes total, and
## two thousand trees drawn from them in seven draw calls.
##
##
## WHAT AN IMPOSTOR HAS TO GET RIGHT, AND WHAT IT DOES NOT.
##
## At 150 m a tree is a dozen pixels tall. Its silhouette survives that; its
## whorls, its bark and its individual leaves do not. So the shapes below are
## chosen purely by outline - a cone is a conifer, a dome is a broadleaf, a
## stick is a dead one - and every triangle that does not change the outline is
## a triangle spent on nothing.
##
## THE COLOUR MUST MATCH THE VOXEL TREE, though, and that is not cosmetic: a
## forest whose far half is a different green from its near half draws a circle
## on the hillside at exactly the voxel radius, which is the artefact this
## whole ring exists to remove. Shade A of each species, straight out of
## Block.COLORS, so the two cannot drift apart.

static var _meshes := {}
static var _mutex := Mutex.new()
static var _material: StandardMaterial3D = null


static func for_species(species: int, config: WorldgenConfig) -> ArrayMesh:
	var got: ArrayMesh = _meshes.get(species)
	if got != null:
		return got
	_mutex.lock()
	got = _meshes.get(species)
	if got == null:
		got = _build(species, config)
		_meshes[species] = got
	_mutex.unlock()
	return got


static func _build(species: int, config: WorldgenConfig) -> ArrayMesh:
	var row: Dictionary = TreeSpecies.table(config)[species]
	# Shade A. The far field is not the place for per-tree colour variation -
	# it would cost a second mesh per species to save an effect nobody can
	# resolve at 150 m.
	var color: Color = Block.color_of(row["leaves"]) \
		if row["leaves"] != Block.AIR else Block.color_of(row["trunk_id"])

	match species:
		TreeSpecies.SPRUCE, TreeSpecies.LARCH:
			# A tall six-sided cone. The one shape that says "conifer" from any
			# distance at which it says anything at all.
			return _cone(6, 0.5, 1.0, color)
		TreeSpecies.KRUMMHOLZ:
			# Squat and wide: it is barely a tree and should not read as one.
			return _cone(6, 0.7, 1.0, color)
		TreeSpecies.BEECH, TreeSpecies.BIRCH, TreeSpecies.HERO:
			# An octahedron on a stalk - eight triangles that read as a round
			# crown, which is the whole difference between a broadleaf and a
			# conifer at this range.
			return _dome(0.5, 1.0, color, Block.color_of(row["trunk_id"]))
		TreeSpecies.SNAG:
			# A thin box. No crown at all is the point of a snag, and a bare
			# vertical stroke among the cones is what makes one visible.
			return _post(0.10, 1.0, color)
	return _cone(6, 0.5, 1.0, color)


## An n-sided cone, apex up, standing on the origin. n triangles for the sides
## plus n for the base cap.
##
## THE BASE IS CAPPED because the ring is often seen from ABOVE - from the
## treeline looking down into a valley, which is one of the tour's own
## vantages. An open cone seen from above is a hole with the inside of its far
## wall showing through, and back-face culling makes that worse rather than
## better.
static func _cone(sides: int, radius: float, height: float,
		color: Color) -> ArrayMesh:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var apex := Vector3(0.0, height, 0.0)
	var base_centre := Vector3.ZERO

	for i in sides:
		var a0 := float(i) / float(sides) * TAU
		var a1 := float(i + 1) / float(sides) * TAU
		var p0 := Vector3(cos(a0) * radius, 0.0, sin(a0) * radius)
		var p1 := Vector3(cos(a1) * radius, 0.0, sin(a1) * radius)
		# Side, wound so the outside faces out.
		_tri(verts, normals, colors, apex, p1, p0, color)
		# Base, wound the other way so it faces down.
		_tri(verts, normals, colors, base_centre, p0, p1, color)
	return _finish(verts, normals, colors)


## An octahedron crown on a short stalk. Eight triangles plus four for the
## stalk, at the top of the plan's 6-12 range - and worth it, because a
## broadleaf without a visible trunk reads as a bush.
static func _dome(radius: float, height: float, leaf: Color,
		trunk: Color) -> ArrayMesh:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()

	var base := height * 0.35
	var top := Vector3(0.0, height, 0.0)
	var mid := base + (height - base) * 0.45
	var bottom := Vector3(0.0, base, 0.0)
	var ring := [
		Vector3(radius, mid, 0.0), Vector3(0.0, mid, radius),
		Vector3(-radius, mid, 0.0), Vector3(0.0, mid, -radius),
	]
	for i in 4:
		var p0: Vector3 = ring[i]
		var p1: Vector3 = ring[(i + 1) % 4]
		_tri(verts, normals, colors, top, p1, p0, leaf)
		_tri(verts, normals, colors, bottom, p0, p1, leaf)

	# Two crossed quads for the trunk - four triangles, and enough to put a
	# dark vertical under the crown.
	var half := radius * 0.12
	for axis in 2:
		var d := Vector3(half, 0.0, 0.0) if axis == 0 else Vector3(0.0, 0.0, half)
		var a := -d
		var b := d
		var c := d + Vector3(0.0, base, 0.0)
		var e := -d + Vector3(0.0, base, 0.0)
		_tri(verts, normals, colors, a, b, c, trunk)
		_tri(verts, normals, colors, a, c, e, trunk)
	return _finish(verts, normals, colors)


## A thin four-sided post. Eight triangles, no cap - nobody looks down a snag.
static func _post(radius: float, height: float, color: Color) -> ArrayMesh:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var corners := [
		Vector3(-radius, 0.0, -radius), Vector3(radius, 0.0, -radius),
		Vector3(radius, 0.0, radius), Vector3(-radius, 0.0, radius),
	]
	for i in 4:
		var p0: Vector3 = corners[i]
		var p1: Vector3 = corners[(i + 1) % 4]
		var q0 := p0 + Vector3(0.0, height, 0.0)
		var q1 := p1 + Vector3(0.0, height, 0.0)
		_tri(verts, normals, colors, p0, q0, q1, color)
		_tri(verts, normals, colors, p0, q1, p1, color)
	return _finish(verts, normals, colors)


## One flat-shaded triangle. The normal is the face's own, so an impostor is
## faceted rather than smooth - which is right: everything else in this world
## is, and a smoothly-shaded cone among voxel trees looks like a different
## game.
static func _tri(verts: PackedVector3Array, normals: PackedVector3Array,
		colors: PackedColorArray, a: Vector3, b: Vector3, c: Vector3,
		color: Color) -> void:
	var n := (b - a).cross(c - a).normalized()
	if n == Vector3.ZERO:
		n = Vector3.UP
	verts.push_back(a); verts.push_back(b); verts.push_back(c)
	for i in 3:
		normals.push_back(n)
		colors.push_back(color)


static func _finish(verts: PackedVector3Array, normals: PackedVector3Array,
		colors: PackedColorArray) -> ArrayMesh:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, material())
	return mesh


## The same kind of material the terrain uses: vertex colour as albedo, matte,
## no specular. Shared with nothing, because ChunkMesher's is a different
## object with the same settings and reaching across for it would couple the
## two for no gain.
static func material() -> StandardMaterial3D:
	if _material != null:
		return _material
	_mutex.lock()
	if _material == null:
		var m := StandardMaterial3D.new()
		m.vertex_color_use_as_albedo = true
		m.roughness = 1.0
		m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
		_material = m
	_mutex.unlock()
	return _material
