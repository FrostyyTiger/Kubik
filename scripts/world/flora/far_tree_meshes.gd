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
## chosen by outline - a stepped pyramid is a conifer, a stepped crown is a
## broadleaf, a stick is a dead one - and every triangle that does not change
## the outline is a triangle spent on nothing.
##
## THAT WAS "PURELY BY OUTLINE" UNTIL DISTANCE V2, AND IT WAS HALF THE
## COMPLAINT. Chosen purely by outline, the conifer was a six-sided cone: six
## triangles, and under flat shading six big DIAMOND facets. A near spruce is a
## trunk block with a cone of leaf VOXELS stacked on it - a staircase - so the
## eye read diamonds where it expected steps, and Marcel's word for it was
## "rhomboid", which is precise rather than vague. The outline was right and the
## surface was from a different game.
##
## Since Stage 5 the shapes are stacks of boxes at the same triangle scale.
## Silhouette still decides WHICH shape; the surface is now the same one the
## near field has.
##
## THE COLOUR MUST MATCH THE VOXEL TREE, though, and that is not cosmetic: a
## forest whose far half is a different green from its near half draws a circle
## on the hillside at exactly the voxel radius, which is the artefact this
## whole ring exists to remove. Shade A of each species, straight out of
## Block.COLORS, so the two cannot drift apart.

static var _meshes := {}
static var _mutex := Mutex.new()


## HARD RULE 1 REACHES THE TREES TOO. `far_terrace 0.0` is the game f23c3f0
## drew, and that includes its far forest: at 0 this returns the six-sided cone
## and the octahedron, unchanged, and at anything above 0 the stepped shapes.
##
## A mesh cannot blend the way a height can, so this is a threshold where the
## terrain is a lerp. That is the right place for the discontinuity: `far_terrace`
## is "how much the far country is made of blocks", the impostors are part of the
## far country, and turning the knob off has to give the whole old picture back
## rather than stepped trees standing on smooth ground - which would be the worst
## of both and exactly the confusion the knob exists to resolve.
##
## Two entries per species in the cache rather than one, so flipping the knob
## back and forth does not rebuild anything. TreeField re-reads this on every
## rebuild, which is what makes the swap land without an F7.
static func for_species(species: int, config: WorldgenConfig) -> ArrayMesh:
	var key := species * 2 + (1 if config.far_terrace > 0.0 else 0)
	var got: ArrayMesh = _meshes.get(key)
	if got != null:
		return got
	_mutex.lock()
	got = _meshes.get(key)
	if got == null:
		got = _build(species, config, config.far_terrace > 0.0)
		_meshes[key] = got
	_mutex.unlock()
	return got


## SHADE A OF ONE SPECIES, LINEAR - the colour the impostor mesh is built with.
##
## Public because distance v1 Stage 6 needs it on the worker: an impostor's
## instance colour is a MULTIPLIER on the mesh's own vertex colour, so working
## out "what multiplier lands this cone on the hillside's colour" needs the
## colour the cone already is. Reading it from here rather than re-deriving it
## in TreeFieldJob is what stops the two drifting apart.
static func color_of_species(species: int, config: WorldgenConfig) -> Color:
	var row: Dictionary = TreeSpecies.table(config)[species]
	# Shade A. The far field is not the place for per-tree colour variation -
	# it would cost a second mesh per species to save an effect nobody can
	# resolve at 150 m.
	return Block.color_of(row["leaves"]) \
		if row["leaves"] != Block.AIR else Block.color_of(row["trunk_id"])


static func _build(species: int, config: WorldgenConfig,
		stepped: bool) -> ArrayMesh:
	var row: Dictionary = TreeSpecies.table(config)[species]
	var color := color_of_species(species, config)

	if not stepped:
		# THE WAY BACK. Exactly what f23c3f0 built, untouched.
		match species:
			TreeSpecies.SPRUCE, TreeSpecies.LARCH:
				return _cone(6, 0.5, 1.0, color)
			TreeSpecies.KRUMMHOLZ:
				return _cone(6, 0.7, 1.0, color)
			TreeSpecies.BEECH, TreeSpecies.BIRCH, TreeSpecies.HERO:
				return _dome_smooth(0.5, 1.0, color, Block.color_of(row["trunk_id"]))
			TreeSpecies.SNAG:
				return _post(0.10, 1.0, color)
		return _cone(6, 0.5, 1.0, color)

	match species:
		TreeSpecies.SPRUCE, TreeSpecies.LARCH:
			# A STEPPED PYRAMID, distance v2 Stage 5 - three stacked boxes
			# shrinking upward where there used to be a six-sided cone. A cone
			# under flat shading gives big diamond facets, and the eye reads
			# diamonds where it expects steps: Marcel's "rhomboid", which is a
			# precise word and not a vague one. The outline still says conifer;
			# the surface now says voxel.
			return _stack([1.0, 0.66, 0.33], 0.5, 1.0, color)
		TreeSpecies.KRUMMHOLZ:
			# Squat and wide: it is barely a tree and should not read as one.
			# Two tiers rather than three, because a krummholz that is three
			# boxes tall is a small spruce.
			return _stack([1.0, 0.6], 0.7, 1.0, color)
		TreeSpecies.BEECH, TreeSpecies.BIRCH, TreeSpecies.HERO:
			# A STEPPED crown on a stalk. The widths bulge in the middle and
			# come back in, which is what separates a broadleaf from a conifer
			# at this range - the same job the octahedron did, in the same
			# language as the spruce beside it.
			return _dome_stepped(0.5, 1.0, color, Block.color_of(row["trunk_id"]))
		TreeSpecies.SNAG:
			# A thin box. No crown at all is the point of a snag, and a bare
			# vertical stroke among the cones is what makes one visible.
			#
			# LEFT ALONE, and deliberately: a four-sided post IS a box already.
			# There is nothing about it that reads as smooth, so the "same
			# language" the plan asks for is the language it is already in.
			return _post(0.10, 1.0, color)
	return _stack([1.0, 0.66, 0.33], 0.5, 1.0, color)


## A STACK OF BOXES, standing on the origin - the impostor's whole new grammar.
## Distance v2 Stage 5, decision 6.
##
## `widths` are fractions of `radius`, bottom tier first, and the tiers divide
## the height evenly between `base` and `height`. Three tiers shrinking upward
## is a spruce, two is a krummholz, three that bulge is a broadleaf crown - one
## builder for all of them, so they cannot drift into different languages.
##
## THE COST. Per tier: four side quads (8 triangles) and a full top cap (2).
## Plus one cap under the whole stack. Three tiers is 32 triangles against the
## six-sided cone's 12 - 2.7x, in the same class decision 6 asked for, though
## more than the plan's "around 20". The full top cap rather than an annulus is
## the cheap choice AND the right one: the annulus between two tiers is four
## quads, which is four triangles more than covering the whole square and
## letting the tier above hide the middle.
##
## THE BASE IS CAPPED because the ring is often seen from ABOVE - from the
## treeline looking down into a valley, which is one of the tour's own vantages.
## An open shape seen from above is a hole with the inside of its far wall
## showing through, and back-face culling makes that worse rather than better.
static func _stack(widths: Array, radius: float, height: float,
		color: Color) -> ArrayMesh:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	_stack_into(verts, normals, colors, widths, radius, 0.0, height, color)
	return _finish(verts, normals, colors)


## The stack itself, so _dome can put one on a trunk without a second copy.
static func _stack_into(verts: PackedVector3Array, normals: PackedVector3Array,
		colors: PackedColorArray, widths: Array, radius: float,
		base: float, height: float, color: Color) -> void:
	var n := widths.size()
	var span := (height - base) / float(n)
	# The floor of the whole stack, facing down.
	var r0: float = radius * float(widths[0])
	_cap(verts, normals, colors, r0, base, false, color)
	for t in n:
		var r: float = radius * float(widths[t])
		var y0 := base + span * float(t)
		var y1 := y0 + span
		# Four side quads, wound so the outside faces out.
		var c := [
			Vector3(-r, 0.0, -r), Vector3(r, 0.0, -r),
			Vector3(r, 0.0, r), Vector3(-r, 0.0, r),
		]
		for k in 4:
			var a: Vector3 = c[k]
			var b: Vector3 = c[(k + 1) % 4]
			var p0 := Vector3(a.x, y0, a.z)
			var p1 := Vector3(b.x, y0, b.z)
			var q0 := Vector3(a.x, y1, a.z)
			var q1 := Vector3(b.x, y1, b.z)
			_tri(verts, normals, colors, p0, q0, q1, color)
			_tri(verts, normals, colors, p0, q1, p1, color)
		# The step: this tier's top, whole. Where the tier above is narrower
		# the exposed ring is the shelf you can see from a treeline looking
		# down, and where it is wider the cap is hidden inside it.
		_cap(verts, normals, colors, r, y1, true, color)
		# And where the NEXT tier is wider, its underside shows.
		if t + 1 < n and float(widths[t + 1]) > float(widths[t]):
			_cap(verts, normals, colors, radius * float(widths[t + 1]), y1,
				false, color)


## One horizontal square, facing up or down.
static func _cap(verts: PackedVector3Array, normals: PackedVector3Array,
		colors: PackedColorArray, r: float, y: float, up: bool,
		color: Color) -> void:
	var a := Vector3(-r, y, -r)
	var b := Vector3(r, y, -r)
	var c := Vector3(r, y, r)
	var d := Vector3(-r, y, r)
	if up:
		_tri(verts, normals, colors, a, d, c, color)
		_tri(verts, normals, colors, a, c, b, color)
	else:
		_tri(verts, normals, colors, a, b, c, color)
		_tri(verts, normals, colors, a, c, d, color)


## A STEPPED crown on a short stalk - three boxes that widen and come back in.
## Distance v2 Stage 5.
##
## It was an octahedron until this epic, and an octahedron among stepped spruces
## is the new odd thing: decision 6 sized the spruce and said to apply the same
## treatment to all three at the same triangle scale. What has to survive the
## change is the SILHOUETTE - a broadleaf reads round and a conifer reads
## pointed, and that is nearly all the information left at 200 m - so the tiers
## bulge rather than taper.
static func _dome_stepped(radius: float, height: float, leaf: Color,
		trunk: Color) -> ArrayMesh:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()

	var base := height * 0.35
	_stack_into(verts, normals, colors, [0.62, 1.0, 0.72], radius,
		base, height, leaf)

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


## THE SHAPES `far_terrace 0.0` STILL DRAWS, byte for byte as f23c3f0 built
## them. Not dead code and not history: they are one half of the knob.


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
static func _dome_smooth(radius: float, height: float, leaf: Color,
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
	var wire := Look.to_wire(color)
	for i in 3:
		normals.push_back(n)
		colors.push_back(wire)


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


## The terrain's ramp, on a material of the ring's own - see
## Look.far_tree_material(), which carries the reasoning.
##
## Until distance v1 Stage 6 this returned Look.figure_material(), which is the
## CHARACTER treatment: fog_dark_mix 1.0, so the thing drawn with it refuses to
## fog into what is behind it. That is exactly right for a person and exactly
## wrong for two thousand cones on a hillside, and it was the reason the far
## forest read as green triangles pasted onto the picture rather than as part
## of the mountain. A tree is scenery; a person is not.
static func material() -> Material:
	return Look.far_tree_material()
