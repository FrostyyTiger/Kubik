class_name FloraModels

## The little things that grow at your feet, as voxel models.
##
##
## WHY THESE ARE NOT BLOCKS.
##
## Everything else in this world is a block. Ground cover is not, and it cannot
## be, for a reason that is written down in ChunkMesher and worth repeating:
## GREEDY MESHING AND PER-BLOCK VARIATION DO NOT MIX. A flat meadow chunk is
## one quad today; scatter differently-coloured grass through it and it becomes
## hundreds. Worse, a grass tuft at block resolution is a 50 cm cube, which is
## knee-high on the player and not grass at all.
##
## So plants live on a separate DECORATION LAYER that never enters a chunk,
## never enters the mesher, and never enters the edit dictionary. They are
## drawn as MultiMesh instances of a shared mesh, which costs one draw call per
## model type per column no matter how many blades are in it.
##
##
## TWO VOXEL SCALES, AND THIS IS THE SECOND ONE.
##
## DESIGN.md already says characters are model voxels six to eight times finer
## than world blocks - "two systems, not one". Plants join the character system.
## A block is 0.5 m and a model voxel is 8 to the block, so 6.25 cm.
##
## That matters more than it sounds. Trees are LANDSCAPE, drawn at 1:4 like the
## mountains, because they are read from across a valley. Plants are read from
## two metres away by a player standing next to them, so they are drawn at 1:1
## - real size. A grass tuft at 1:4 would be 12 cm tall and invisible from the
## camera. The model gallery puts a capsule of the player's exact dimensions
## beside them so that this stays obvious.

## Model voxels per world block. 8, from the character scale in DESIGN.md.
const VOXELS_PER_BLOCK := 8

# --- Model ids --------------------------------------------------------------
#
# Indices into the model table. They are NOT block ids and do not cross the
# network - but they DO form the top byte of a flora instance's identity in
# Stage 9, so appending is cheaper than reordering.

enum {
	GRASS_TUFT_A = 0,
	GRASS_TUFT_B = 1,
}

const COUNT := 2

## Names, for the probe, the gallery and STATUS.md.
const NAMES := ["grass_tuft_a", "grass_tuft_b"]


# --- The palette ------------------------------------------------------------
#
# STORED LINEAR, hex given beside each, exactly as Block.COLORS is - and for
# exactly the same reason, which cost a whole screenshot tour to find the first
# time. Godot treats a vertex colour as already linear, so feeding it an sRGB
# hex value draws it far brighter and far less saturated than intended. Doing
# the conversion here rather than with vertex_color_is_srgb on the material,
# because that flag does nothing under the Compatibility renderer and the tour
# runs on Compatibility while Marcel plays on Forward+.

enum {
	C_GRASS_BLADE = 0,
	C_GRASS_BLADE_DRY = 1,
}

## THE TIP IS MUCH LIGHTER THAN THE BASE, and that is the whole readability of
## a grass tuft at this size.
##
## The first pair were both DARKER than the meadow block they stand on
## (#86B04A), and the gallery close-up showed why that fails: a dark clump on
## bright ground reads as a shadow or a patch of dirt, not as something
## growing. Grass catches the light at its tips, so the tip colour is well
## above the ground's value and the base a little below it. The tuft then reads
## as a small bright thing against the meadow rather than a hole in it.
##
## Recorded in STATUS.md under "tuned blind": this was judged on the
## Compatibility renderer, and value contrast is exactly the kind of thing the
## two renderers disagree about.
const COLORS := [
	Color(0.1912, 0.3663, 0.0452),   # GRASS_BLADE      #79A33C  blade, base
	Color(0.3916, 0.5841, 0.1119),   # GRASS_BLADE_DRY  #A8C95E  blade, sunlit tip
]


# --- The model table --------------------------------------------------------
#
# A model is a list of voxels, each [x, y, z, colour index, emissive]. The
# origin is the BOTTOM CENTRE, so an instance's position is the point on the
# ground it stands on and nothing has to know how tall it is.
#
# `emissive` is 0 or 1 and travels in the vertex colour's ALPHA channel, where
# Stage 8's shader reads it to make mushroom caps and fireflies glow after
# dark. It costs nothing until then: alpha is otherwise unused, the material is
# opaque, and a model with no emissive voxels writes 0 into every one.


## Every model, built on demand and cached.
static var _meshes := {}
static var _mesh_mutex := Mutex.new()
static var _material: ShaderMaterial = null


## Voxel lists, by model id.
##
## GRASS IS TWO MODELS, NOT ONE, and the difference is only shape. Colour
## variety comes from the per-instance tint, which costs nothing; SHAPE variety
## cannot come from anywhere but a second model, and a meadow of one repeated
## silhouette reads as a texture rather than as plants. Two is enough - the
## eye stops counting at two.
static func voxels_for(model: int) -> Array:
	match model:
		GRASS_TUFT_A:
			# Four blades of different heights, leaning apart at the top. The
			# LEAN IS THE WHOLE MODEL: four straight columns read as a bar
			# chart, and offsetting only the top voxel of each turns it into a
			# tuft for four extra voxels.
			return _blades([
				[0, 0, 5, 1, 0],     # x, z, height, top dx, top dz
				[1, 0, 3, 1, 0],
				[0, 1, 4, 0, 1],
				[-1, 1, 2, -1, 0],
			])
		GRASS_TUFT_B:
			# Three blades, shorter and wider apart, so the two variants differ
			# in outline and not just in detail.
			return _blades([
				[0, 0, 4, 0, 1],
				[-1, 0, 3, -1, 0],
				[1, 1, 2, 1, 1],
			])
	return []


## Turn blade descriptions into voxels.
##
## Each blade is a vertical run at (x, z) of `height` voxels. The top TWO
## voxels are displaced by (top_dx, top_dz), the upper one twice - so a blade
## arcs over rather than kinking at the last voxel, which at five voxels tall
## is the difference between a blade of grass and a letter L.
##
## The top voxel takes the pale colour. That is what stops a tuft from being
## one flat green wedge: real grass catches the light at its tips, and with
## only five voxels of height the gradient has to do the work the shape cannot.
static func _blades(blades: Array) -> Array:
	var out := []
	for b in blades:
		var x: int = b[0]
		var z: int = b[1]
		var h: int = b[2]
		for y in h:
			# 0 for the lower part of the blade, 1 just below the tip, 2 at it.
			var bend := maxi(0, y - (h - 3)) if h >= 3 else 0
			out.append([
				x + b[3] * bend,
				y,
				z + b[4] * bend,
				C_GRASS_BLADE_DRY if y == h - 1 else C_GRASS_BLADE,
				0,
			])
	return out


# --- Turning a model into a mesh --------------------------------------------

## The shared ArrayMesh for one model, built once.
##
## Cached under a mutex: the first thing to ask for a model may be a worker
## thread packing a MultiMesh buffer, and two of them arriving together must
## not each build their own. Building is cheap - a few hundred triangles - but
## publishing a half-built ArrayMesh is not.
static func mesh_for(model: int, block_size: float) -> ArrayMesh:
	var key := "%d|%.4f" % [model, block_size]
	var got: ArrayMesh = _meshes.get(key)
	if got != null:
		return got
	_mesh_mutex.lock()
	got = _meshes.get(key)
	if got == null:
		got = build_mesh_from(voxels_for(model), block_size)
		_meshes[key] = got
	_mesh_mutex.unlock()
	return got


## Build one voxel list into a mesh, with hidden faces culled.
##
## CULLING IS NOT AN OPTIMISATION HERE, IT IS THE BUDGET. A fern is thirty
## voxels; drawn as thirty independent cubes that is 360 triangles, and at
## twelve instances per block over a 64 m radius it is tens of millions. Faces
## between two voxels of the same model can never be seen - they are inside the
## plant - so dropping them is free, and on these shapes it removes between a
## third and a half of everything.
static func build_mesh_from(voxels: Array, block_size: float) -> ArrayMesh:
	if voxels.is_empty():
		return null
	var unit := block_size / float(VOXELS_PER_BLOCK)

	# Occupancy, so a face can ask whether anything is next to it.
	var filled := {}
	for v in voxels:
		filled[Vector3i(v[0], v[1], v[2])] = true

	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()

	for v in voxels:
		var pos := Vector3i(v[0], v[1], v[2])
		var color: Color = COLORS[int(v[3])]
		# Emissive rides in alpha. Stage 8's shader multiplies it by a global
		# night factor; until then nothing reads it and it is inert.
		color.a = float(v[4])
		for f in FACES.size():
			if filled.has(pos + FACE_NORMALS[f]):
				continue
			_emit_face(pos, f, color, unit, verts, normals, colors, indices)

	if indices.is_empty():
		return null
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


## The six face normals, and the four corner offsets of each face.
##
## Wound CLOCKWISE SEEN FROM OUTSIDE, which is Godot's front face - the same
## rule ChunkMesher's winding self-test enforces on the terrain. Get it wrong
## and a plant is not invisible, it is inside out.
const FACE_NORMALS := [
	Vector3i(1, 0, 0), Vector3i(-1, 0, 0),
	Vector3i(0, 1, 0), Vector3i(0, -1, 0),
	Vector3i(0, 0, 1), Vector3i(0, 0, -1),
]

const FACES := [
	# +X
	[Vector3(1, 0, 0), Vector3(1, 1, 0), Vector3(1, 1, 1), Vector3(1, 0, 1)],
	# -X
	[Vector3(0, 0, 1), Vector3(0, 1, 1), Vector3(0, 1, 0), Vector3(0, 0, 0)],
	# +Y
	[Vector3(0, 1, 1), Vector3(1, 1, 1), Vector3(1, 1, 0), Vector3(0, 1, 0)],
	# -Y
	[Vector3(0, 0, 0), Vector3(1, 0, 0), Vector3(1, 0, 1), Vector3(0, 0, 1)],
	# +Z
	[Vector3(1, 0, 1), Vector3(1, 1, 1), Vector3(0, 1, 1), Vector3(0, 0, 1)],
	# -Z
	[Vector3(0, 0, 0), Vector3(0, 1, 0), Vector3(1, 1, 0), Vector3(1, 0, 0)],
]


static func _emit_face(pos: Vector3i, face: int, color: Color, unit: float,
		verts: PackedVector3Array, normals: PackedVector3Array,
		colors: PackedColorArray, indices: PackedInt32Array) -> void:
	var n := Vector3(FACE_NORMALS[face])
	var first := verts.size()
	for corner in FACES[face]:
		# The model's origin is its bottom centre, so x and z are centred on
		# the voxel column the instance stands on and y starts at the ground.
		verts.push_back(Vector3(
			(float(pos.x) + corner.x - 0.5) * unit,
			(float(pos.y) + corner.y) * unit,
			(float(pos.z) + corner.z - 0.5) * unit))
		normals.push_back(n)
		colors.push_back(color)
	indices.push_back(first)
	indices.push_back(first + 1)
	indices.push_back(first + 2)
	indices.push_back(first)
	indices.push_back(first + 2)
	indices.push_back(first + 3)


# --- The material -----------------------------------------------------------

## One ShaderMaterial for every plant in the world.
##
## A SHADER RATHER THAN A StandardMaterial3D, for the wind. Everything else it
## does - vertex colour as albedo, roughness 1, no specular - a standard
## material does too, and the terrain uses one for exactly that. What a
## standard material cannot do is move the vertices, and grass that does not
## move is the single thing that makes a meadow read as painted-on.
##
## MUST COMPILE ON BOTH RENDERERS. The screenshot tour runs on Compatibility
## under Xvfb here; Marcel plays on Forward+ on a real GPU. Nothing in here is
## allowed to be Forward+ only, and the tour is the proof it is not - if the
## shader fails to compile, every plant in every shot turns magenta.
static func material() -> ShaderMaterial:
	if _material != null:
		return _material
	_mesh_mutex.lock()
	if _material == null:
		var shader := Shader.new()
		shader.code = SHADER
		var m := ShaderMaterial.new()
		m.shader = shader
		m.set_shader_parameter("wind_strength", 1.0)
		_material = m
	_mesh_mutex.unlock()
	return _material


## Push a local knob into the shared material. Called from the main thread when
## the F4 panel moves.
static func set_wind(strength: float) -> void:
	material().set_shader_parameter("wind_strength", strength)


const SHADER := """
shader_type spatial;
render_mode cull_back, diffuse_lambert, specular_disabled;

uniform float wind_strength = 1.0;

void vertex() {
	// THE SWAY. Height-weighted, so the roots stay planted and only the tips
	// move - grass that slides sideways as a rigid block reads as a bug.
	//
	// Driven by the instance's WORLD position rather than by an instance id,
	// so neighbouring plants are near each other in phase and a meadow moves
	// in waves instead of every blade shivering independently. The two
	// different multipliers on x and z stop the waves from running exactly
	// along an axis, which is the one thing that would give the lattice away.
	vec3 world_pos = MODEL_MATRIX[3].xyz;
	float phase = TIME * 1.3 + world_pos.x * 0.7 + world_pos.z * 0.4;
	VERTEX.x += sin(phase) * VERTEX.y * wind_strength * 0.08;
	VERTEX.z += cos(phase * 0.8) * VERTEX.y * wind_strength * 0.05;
}

void fragment() {
	// The vertex colour IS the albedo, exactly as it is for the terrain.
	// There are no textures in this world; a plant is its colour.
	ALBEDO = COLOR.rgb;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
"""


# --- The model gallery ------------------------------------------------------

## Model names, for the gallery's 1:1 strip.
static func gallery_names() -> Array:
	return NAMES.duplicate()


## Build one model by name, at the default block size.
static func build_mesh(name: String) -> ArrayMesh:
	var i := NAMES.find(name)
	if i < 0:
		return null
	return build_mesh_from(voxels_for(i), 0.5)


static func gallery_material() -> ShaderMaterial:
	return material()
