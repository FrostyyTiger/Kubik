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


## Voxels per block for ONE model, where 8 is not the right answer.
##
## NOT EVERY MODEL IS A PLANT, and the measurement that forced this is worth
## keeping. A 3 m boulder built at 8 voxels to the block is 48 voxels across,
## and its shell came to 35,964 TRIANGLES - one rock costing more than two
## hundred grass tufts, and a scree field costing more than the entire flora
## budget by itself. A heath of 90 cm shrubs at 2,184 triangles each was the
## same problem one size down.
##
## The fix is not to make them smaller - the sizes are what you see - it is to
## notice that THE WORLD'S OWN BLOCKS ARE 50 cm. A boulder made of 25 cm voxels
## is still twice as detailed as the ground it is sitting on, and a shrub at
## 12.5 cm is four times. There was never a reason for a rock to be eight times
## finer than the mountain it fell off.
##
## Grass, flowers, ferns and mushrooms stay at 8. They are the things a player
## crouches next to, they are the things DESIGN.md's character scale is about,
## and they are small enough that the resolution costs almost nothing.
static func voxels_per_block(model: int) -> int:
	match model:
		BOULDER_S, BOULDER_M, BOULDER_L:
			return 2
		SHRUB_A, SHRUB_B:
			return 4
	return VOXELS_PER_BLOCK

# --- Model ids --------------------------------------------------------------
#
# Indices into the model table. They are NOT block ids and do not cross the
# network - but they DO form the top byte of a flora instance's identity in
# Stage 9, so appending is cheaper than reordering.

enum {
	GRASS_TUFT_A = 0,
	GRASS_TUFT_B = 1,
	GRASS_SHORT = 2,
	# FOUR FLOWERS, ONE PER HEAD COLOUR, and that is a deliberate answer to a
	# real constraint. The plan wants a flower's head colour to be a property
	# of the INSTANCE - a patch of meadow is all one colour - but the only
	# per-instance channel a MultiMesh has is a colour that multiplies the
	# WHOLE model, stem included, which would give green-stemmed white flowers
	# a white stem. Four models is the cheap way out: the placement rule picks
	# one per patch, a column that has flowers usually has exactly one of them
	# in it, and the stems stay green.
	FLOWER_WHITE = 3,
	FLOWER_YELLOW = 4,
	FLOWER_PURPLE = 5,
	FLOWER_RED = 6,
	FERN = 7,
	MUSHROOM = 8,
	SHRUB_A = 9,
	SHRUB_B = 10,
	ALPINE_FLOWER = 11,
	BOULDER_S = 12,
	BOULDER_M = 13,
	BOULDER_L = 14,
	SCREE_A = 15,
	SCREE_B = 16,
	REED = 17,
	FIREFLY = 18,
}

const COUNT := 19

## Names, for the probe, the gallery and STATUS.md.
const NAMES := [
	"grass_tuft_a", "grass_tuft_b", "grass_short",
	"flower_white", "flower_yellow", "flower_purple", "flower_red",
	"fern", "mushroom", "shrub_a", "shrub_b", "alpine_flower",
	"boulder_s", "boulder_m", "boulder_l",
	"scree_a", "scree_b", "reed", "firefly",
]

## The four flower models, in the order a patch hashes between them.
const FLOWERS := [FLOWER_WHITE, FLOWER_YELLOW, FLOWER_PURPLE, FLOWER_RED]


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
	C_GRASS_ALPINE = 2,
	C_STEM = 3,
	C_FERN = 4,
	C_MUSHROOM_STEM = 5,
	C_MUSHROOM_CAP = 6,
	C_SHRUB = 7,
	C_SHRUB_B = 8,
	C_BOULDER = 9,
	C_REED = 10,
	C_FIREFLY = 11,
	C_FLOWER_WHITE = 12,
	C_FLOWER_YELLOW = 13,
	C_FLOWER_PURPLE = 14,
	C_FLOWER_RED = 15,
	C_FLOWER_ALPINE = 16,
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
##
## LOOK V1 MOVED ALL THREE TOWARD THE GROUND THEY STAND ON. The meadow is a
## colour field on the poster, and a tuft is a slightly darker and a slightly
## lighter meadow (#86B04A), not a different green: the base one step under
## the ground's value, the tip one step over. The contrast that used to come
## from a different hue now comes from the ramp - a tuft's sunward face is a
## tone lighter than the ground's, its far face a tone darker - which is what
## makes the field read as ground with grass in it rather than as confetti.
const COLORS := [
	Color(0.1878, 0.3613, 0.0578),   # GRASS_BLADE      #78A244  blade, base
	Color(0.3278, 0.5395, 0.0976),   # GRASS_BLADE_DRY  #9BC258  blade, sunlit tip
	Color(0.3372, 0.4342, 0.1022),   # GRASS_ALPINE     #9DB05A  short turf, on #A7B860
	# LIGHTENED from #5C7A2E, which was half the meadow block's value and read
	# as a black stick with a white brick on top. A stem is thinner than one
	# voxel in reality, so at 6.25 cm it is already too wide - making it dark
	# as well turned a field of flowers into a field of nails.
	Color(0.2384, 0.3916, 0.0595),   # STEM             #86A845  flower, reed stem
	# LIGHTER AND GREENER than the first attempt at #4A7A34, which came back
	# from the gallery almost black against the forest floor and, with
	# one-voxel fronds, read as a spider rather than as a plant.
	Color(0.1170, 0.2918, 0.0578),   # FERN_FROND       #5E9440  fern
	Color(0.5841, 0.5210, 0.3916),   # MUSHROOM_STEM    #C9BFA8
	Color(0.6939, 0.1441, 0.0685),   # MUSHROOM_CAP     #D96A4A
	Color(0.3050, 0.1170, 0.0685),   # SHRUB_HEATH      #96604A  rusty dwarf shrub
	Color(0.3515, 0.1470, 0.0762),   # SHRUB_HEATH_B    #A06B4E
	# LIGHTER THAN IT LOOKS IT SHOULD BE. Authored at #8E877A first, which is
	# a perfectly sensible mid-grey on paper and rendered near-black in the
	# gallery: a blob has almost no upward-facing surface, so nearly every
	# face it shows the camera is a side face pointing away from the sun. A
	# boulder has to be authored bright enough to survive being lit edge-on.
	Color(0.4397, 0.4072, 0.3467),   # BOULDER          #B4AEA3  boulder and scree
	Color(0.3325, 0.3005, 0.0844),   # REED             #9C9552
	Color(1.0000, 0.8148, 0.3515),   # FIREFLY          #FFE9A0
	Color(0.8879, 0.8632, 0.7605),   # FLOWER_WHITE     #F2EFE2
	Color(0.8070, 0.5647, 0.0685),   # FLOWER_YELLOW    #E8C64A
	Color(0.3278, 0.1590, 0.5520),   # FLOWER_PURPLE    #9B6FC4
	Color(0.5841, 0.0802, 0.0685),   # FLOWER_RED       #C9504A
	Color(0.6867, 0.7758, 0.8714),   # FLOWER_ALPINE    #D8E4F0
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
## Triangles per model, recorded as each mesh is built.
##
## COUNTED AT BUILD TIME because the alternative is not cheap: ArrayMesh has no
## triangle count, and get_faces() rebuilds the whole vertex list to answer.
## The number is wanted once a frame by the budget readout, so it has to be a
## lookup rather than a rebuild.
static var _triangles := {}
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
			# Four blades of different heights, arcing apart at the top. The
			# ARC IS THE WHOLE MODEL: four straight columns read as a bar
			# chart, and bending the top two voxels of each turns it into a
			# tuft for no extra voxels at all.
			return _blades(C_GRASS_BLADE, C_GRASS_BLADE_DRY, [
				[0, 0, 5, 1, 0],     # x, z, height, bend dx, bend dz
				[1, 0, 3, 1, 0],
				[0, 1, 4, 0, 1],
				[-1, 1, 2, -1, 0],
			])
		GRASS_TUFT_B:
			# Three blades, shorter and wider apart, so the two variants differ
			# in outline and not just in detail.
			return _blades(C_GRASS_BLADE, C_GRASS_BLADE_DRY, [
				[0, 0, 4, 0, 1],
				[-1, 0, 3, -1, 0],
				[1, 1, 2, 1, 1],
			])
		GRASS_SHORT:
			# 15 cm. Alpine and shore turf: cropped, not tufted.
			return _blades(C_GRASS_ALPINE, C_GRASS_ALPINE, [
				[0, 0, 3, 0, 1],
				[1, 1, 2, 1, 0],
				[-1, 0, 2, -1, 0],
			])

		FLOWER_WHITE:
			return _flower(C_FLOWER_WHITE)
		FLOWER_YELLOW:
			return _flower(C_FLOWER_YELLOW)
		FLOWER_PURPLE:
			return _flower(C_FLOWER_PURPLE)
		FLOWER_RED:
			return _flower(C_FLOWER_RED)

		ALPINE_FLOWER:
			# 15 cm, head close to the ground. Everything up there is small and
			# hugging the rock; a 35 cm stem would blow over.
			return [
				[0, 0, 0, C_STEM, 0],
				[0, 1, 0, C_FLOWER_ALPINE, 0],
				[1, 1, 0, C_FLOWER_ALPINE, 0],
				[0, 1, 1, C_FLOWER_ALPINE, 0],
				[1, 1, 1, C_FLOWER_ALPINE, 0],
			]

		FERN:
			return _fern()
		MUSHROOM:
			return _mushroom()

		# RADII ARE IN THIS MODEL'S OWN VOXELS - see voxels_per_block(). A
		# shrub's voxel is 12.5 cm and a boulder's is 25 cm, so the numbers
		# below are smaller than the plant models' for the same real size.

		SHRUB_A:
			# 100 cm across and 50 cm tall - wider than it is tall, which is
			# what "dwarf shrub" means and why heath reads as a rusty carpet
			# rather than as a field of bushes.
			return _blob(4, 4, C_SHRUB, 511)
		SHRUB_B:
			return _blob(3, 3, C_SHRUB_B, 733)

		# 1.0, 2.0 and 3.0 m across. The largest is a LANDMARK - one of them in
		# a scree field is something to walk towards.
		BOULDER_S:
			return _blob(2, 2, C_BOULDER, 101, true)
		BOULDER_M:
			return _blob(4, 3, C_BOULDER, 202, true)
		BOULDER_L:
			return _blob(6, 5, C_BOULDER, 303, true)

		SCREE_A:
			# A flat angular chip, 30-50 cm. Wide and one or two voxels thick,
			# because scree is broken rock lying where it fell.
			return _chip(3, 2, 1, C_BOULDER, 404)
		SCREE_B:
			return _chip(2, 3, 2, C_BOULDER, 505)

		REED:
			# 120 cm - the tallest thing on this layer, and taller than the
			# player is wide. Two or three bare stems, no leaves.
			return _blades(C_REED, C_REED, [
				[0, 0, 19, 1, 0],
				[1, 1, 16, 1, 1],
				[-1, 0, 12, -1, 0],
			])

		FIREFLY:
			# ONE EMISSIVE VOXEL, A METRE UP. The height is in the MODEL rather
			# than in the placement rule, because a firefly is the one thing on
			# this layer that does not stand on the ground - and putting the
			# offset here means the placement code stays "one instance on the
			# surface of this block" for every model without exception.
			#
			# 16 voxels is 1 m at 8 to the block. The shader drifts it another
			# 40 cm each way and collapses it to nothing by day.
			return [[0, 16, 0, C_FIREFLY, 1]]
	return []


## A flower: a green stem with a solid head of one colour.
##
## THE HEAD IS A WHOLE MODEL'S WORTH OF COLOUR, which is why there are four of
## these rather than one tinted four ways - see the note on the model ids.
static func _flower(head: int) -> Array:
	var out := []
	for y in 4:
		out.append([0, y, 0, C_STEM, 0])
	# A 2 x 2 x 2 head. Chunky on purpose: at 6.25 cm a voxel is already most
	# of a real flower head, and anything smaller stops being visible from
	# standing height at all.
	for y in range(4, 6):
		for z in 2:
			for x in 2:
				out.append([x, y, z, head, 0])
	return out


## A fern: four fronds arcing up out of a short stem and drooping outward.
##
## THE DROOP IS WHAT MAKES IT A FERN. Fronds that only rise read as a palm or a
## firework; the shape everyone recognises is a fountain - up fast, over, and
## down past the height it started from.
static func _fern() -> Array:
	var out := []
	for y in 4:
		out.append([0, y, 0, C_FERN, 0])
	var dirs := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	# Out from the stem, and the height it reaches at each step.
	var arc := [5, 7, 8, 7, 5]
	for d in dirs:
		# Across the frond, so it has WIDTH. One-voxel fronds were the first
		# attempt and the gallery was blunt about them: four thin lines
		# radiating from a stem is not a fern, it is a spider. A frond needs to
		# read as a leaf, which means being two voxels across where it is
		# widest and one at the tip.
		var perp := Vector2i(d.y, -d.x)
		for i in arc.size():
			out.append([d.x * (i + 1), arc[i], d.y * (i + 1), C_FERN, 0])
			if i == 1 or i == 2:
				out.append([d.x * (i + 1) + perp.x, arc[i],
					d.y * (i + 1) + perp.y, C_FERN, 0])
	return out


## A mushroom: a pale stem under a wider cap, and the cap GLOWS.
##
## Every cap voxel carries emissive = 1, which travels in the vertex colour's
## alpha and does nothing at all until Stage 8 multiplies it by a global night
## factor. That is the cheapest possible way to build night into a model: no
## second material, no second mesh, no branch in the placement rule.
static func _mushroom() -> Array:
	var out := [
		[0, 0, 0, C_MUSHROOM_STEM, 0],
		[0, 1, 0, C_MUSHROOM_STEM, 0],
	]
	# A 3 x 3 cap with the corners knocked off, so it reads as round.
	for z in range(-1, 2):
		for x in range(-1, 2):
			if absi(x) + absi(z) > 1 and not (x == 0 and z == 0):
				continue
			out.append([x, 2, z, C_MUSHROOM_CAP, 1])
	out.append([0, 3, 0, C_MUSHROOM_CAP, 1])
	return out


## A squashed ellipsoid with its surface chewed at - a shrub or a boulder.
##
## SOLID, NOT HOLLOW, and that is a rendering decision rather than a modelling
## one. Face culling removes every face between two filled voxels, so a solid
## blob draws only its shell; a hollow one would draw its shell twice, inside
## and out, for the same silhouette and double the triangles.
##
## `ragged` chews the surface with a hash so the outline is not a smooth dome.
## Boulders take it too, at a coarser setting - a perfectly ellipsoidal rock
## reads as an egg.
static func _blob(radius: int, height: int, color: int, salt: int,
		stone: bool = false) -> Array:
	var out := []
	var rr := float(radius)
	var hh := float(maxi(height, 1))
	for y in range(0, height + 1):
		for z in range(-radius, radius + 1):
			for x in range(-radius, radius + 1):
				var fy := float(y) / hh
				var d := (float(x * x + z * z) / (rr * rr)) + fy * fy
				if d > 1.0:
					continue
				# Chew only the OUTER shell. Hollowing the middle would cost
				# nothing visually and everything in triangles, because the
				# faces facing the new hole would all have to be drawn.
				#
				# AND CHEW LESS WHEN THERE IS LESS TO CHEW. The amount is
				# scaled by the radius, because at a small radius the "outer
				# shell" is most of the blob and removing a third of it does
				# not make a ragged outline, it punches holes right through -
				# which is exactly what happened when boulders and shrubs
				# moved to a coarser voxel scale and came back striped, with
				# their own inside faces showing through the gaps.
				# AND ONLY WHEN THERE IS A SHELL TO CHEW. Below radius 6 the
				# "outer shell" is most of the blob, and removing a fifth of
				# it does not ragged the outline - it opens holes right
				# through, and you see the model's own inside faces through
				# them. Boulders and shrubs moved to a coarser voxel scale for
				# the triangle budget and came back striped for exactly this
				# reason. A small blob is smooth; only the big ones are ragged,
				# which is also true of real rocks.
				if d > 0.55 and radius >= 6:
					if WorldHash.hash01(x * 31 + y, z * 17 + y, salt, 719) \
							< (0.22 if stone else 0.30):
						continue
				out.append([x, y, z, color, 0])
	return out


## A flat angular chip of stone.
static func _chip(rx: int, rz: int, height: int, color: int, salt: int) -> Array:
	var out := []
	for y in height:
		for z in range(-rz, rz + 1):
			for x in range(-rx, rx + 1):
				if WorldHash.hash01(x * 13 + y * 7, z * 29, salt, 720) < 0.25:
					continue
				out.append([x, y, z, color, 0])
	return out


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
static func _blades(base: int, tip: int, blades: Array) -> Array:
	var out := []
	for b in blades:
		var x: int = b[0]
		var z: int = b[1]
		var h: int = b[2]
		for y in h:
			# 0 for the lower part of the blade, 1 just below the tip, 2 at it.
			var bend := maxi(0, y - (h - 3)) if h >= 3 else 0
			out.append([
				x + int(b[3]) * bend,
				y,
				z + int(b[4]) * bend,
				tip if y == h - 1 else base,
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
		got = build_mesh_from(voxels_for(model), block_size,
			voxels_per_block(model))
		_meshes[key] = got
		_triangles[key] = 0 if got == null \
			else got.surface_get_array_index_len(0) / 3
	_mesh_mutex.unlock()
	return got


## Triangles in one instance of this model.
static func triangles_for(model: int, block_size: float) -> int:
	var key := "%d|%.4f" % [model, block_size]
	if not _triangles.has(key):
		mesh_for(model, block_size)
	return int(_triangles.get(key, 0))


## Build one voxel list into a mesh, with hidden faces culled.
##
## CULLING IS NOT AN OPTIMISATION HERE, IT IS THE BUDGET. A fern is thirty
## voxels; drawn as thirty independent cubes that is 360 triangles, and at
## twelve instances per block over a 64 m radius it is tens of millions. Faces
## between two voxels of the same model can never be seen - they are inside the
## plant - so dropping them is free, and on these shapes it removes between a
## third and a half of everything.
static func build_mesh_from(voxels: Array, block_size: float,
		per_block: int = VOXELS_PER_BLOCK) -> ArrayMesh:
	if voxels.is_empty():
		return null
	var unit := block_size / float(maxi(per_block, 1))

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
## rule ChunkMesher's winding self-test enforces on the terrain, and stated
## algebraically there as
##
##     (p1 - p0) x (p2 - p0) == -normal
##
## EVERY ONE OF THESE SIX WAS BACKWARDS in the first version, and the way it
## showed up is worth writing down because it did not look like a winding bug.
## The models were not inside out and nothing vanished - what appeared was thin
## horizontal gaps through every rounded blob, so a boulder read as sedimentary
## layers and a shrub as a bush with slices missing. That survived being
## explained as the raggedness setting, as the coarser voxel scale, and as
## shadow acne, and was only caught by checking the six faces against the
## identity above rather than by looking at them.
##
## The lesson is the one the terrain's winding self-test already encodes: check
## winding with the cross product, not with your eyes.
const FACE_NORMALS := [
	Vector3i(1, 0, 0), Vector3i(-1, 0, 0),
	Vector3i(0, 1, 0), Vector3i(0, -1, 0),
	Vector3i(0, 0, 1), Vector3i(0, 0, -1),
]

const FACES := [
	# +X
	[Vector3(1, 0, 1), Vector3(1, 1, 1), Vector3(1, 1, 0), Vector3(1, 0, 0)],
	# -X
	[Vector3(0, 0, 0), Vector3(0, 1, 0), Vector3(0, 1, 1), Vector3(0, 0, 1)],
	# +Y
	[Vector3(0, 1, 0), Vector3(1, 1, 0), Vector3(1, 1, 1), Vector3(0, 1, 1)],
	# -Y
	[Vector3(0, 0, 1), Vector3(1, 0, 1), Vector3(1, 0, 0), Vector3(0, 0, 0)],
	# +Z
	[Vector3(0, 0, 1), Vector3(0, 1, 1), Vector3(1, 1, 1), Vector3(1, 0, 1)],
	# -Z
	[Vector3(1, 0, 0), Vector3(1, 1, 0), Vector3(0, 1, 0), Vector3(0, 0, 0)],
]


static func _emit_face(pos: Vector3i, face: int, color: Color, unit: float,
		verts: PackedVector3Array, normals: PackedVector3Array,
		colors: PackedColorArray, indices: PackedInt32Array) -> void:
	var n := Vector3(FACE_NORMALS[face])
	var first := verts.size()
	# sRGB on the wire, once, at the push - see Look.to_wire. The alpha rides
	# through untouched: it is the emissive flag, not a colour.
	var wire := Look.to_wire(color)
	for corner in FACES[face]:
		# The model's origin is its bottom centre, so x and z are centred on
		# the voxel column the instance stands on and y starts at the ground.
		verts.push_back(Vector3(
			(float(pos.x) + corner.x - 0.5) * unit,
			(float(pos.y) + corner.y) * unit,
			(float(pos.z) + corner.z - 0.5) * unit))
		normals.push_back(n)
		colors.push_back(wire)
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
## does - vertex colour as albedo, the poster ramp, banded fog - is Look's
## opaque shader, and the pieces are concatenated from Look so the two can
## never disagree about what shade looks like. What the shared shader cannot
## do is move the vertices, and grass that does not move is the single thing
## that makes a meadow read as painted-on.
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
		# A PLANT IS A FIGURE, not the ground. It fogs toward the darker colour
		# so a meadow at 150 m does not turn into the same flat band as the
		# hillside behind it (Look.FOG_FN, look v2 Stage 2).
		m.set_shader_parameter("fog_dark_mix", 1.0)
		_material = m
	_mesh_mutex.unlock()
	return _material


## Push the local knobs into the shared materials. Called from the main thread
## when the F4 panel moves, and once at startup.
static func apply_local_knobs(config: WorldgenConfig) -> void:
	material().set_shader_parameter("wind_strength", config.wind_strength)
	material().set_shader_parameter("night_life", config.night_life)
	firefly_material().set_shader_parameter("night_life", config.night_life)


## Which material a model is drawn with.
static func material_for(model: int) -> ShaderMaterial:
	return firefly_material() if model == FIREFLY else material()


const SHADER := """
shader_type spatial;
render_mode cull_back, ambient_light_disabled, specular_disabled;
""" + Look.HEADER + Look.FOG_FN + """
uniform float wind_strength = 1.0;
uniform float night_life = 1.0;

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
	// There are no textures in this world; a plant is its colour. It arrives
	// sRGB on the wire and goes to light() through v_albedo, with ALBEDO left
	// white - see the note in Look.HEADER. A plant shader that set ALBEDO and
	// forgot v_albedo drew every tuft in the world pure black.
	v_albedo = kubik_to_linear(COLOR.rgb);
	ALBEDO = vec3(1.0);
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	// GLOWING MUSHROOMS, AND THEY COST ONE LINE. COLOR.a is the model's own
	// emissive flag, authored per voxel and carried in the vertex colour's
	// alpha - 1 on a mushroom cap and 0 on everything else in the world. So
	// this is zero for every plant that is not meant to glow, zero for all of
	// them by day, and needs no second material, no second mesh and no branch
	// anywhere in the placement rules.
	EMISSION = kubik_to_linear(COLOR.rgb) * COLOR.a * kubik_night * night_life * 2.0;
	// Distance in bands, like everything else - see Look.
	FOG = poster_fog(VERTEX, v_albedo);
}
""" + Look.RAMP


## Fireflies get their own material.
##
## WHY NOT ONE SHADER WITH A FLAG: the plant shader bends its vertices in the
## wind, and a firefly does not grow out of the ground - it drifts, blinks, and
## does not exist at all by day. Those are different vertex programs, not one
## program with a branch, and a branch taken by one model in nineteen is a
## branch every blade of grass in the world pays for.
static func firefly_material() -> ShaderMaterial:
	if _firefly_material != null:
		return _firefly_material
	_mesh_mutex.lock()
	if _firefly_material == null:
		var shader := Shader.new()
		shader.code = FIREFLY_SHADER
		var m := ShaderMaterial.new()
		m.shader = shader
		m.set_shader_parameter("night_life", 1.0)
		_firefly_material = m
	_mesh_mutex.unlock()
	return _firefly_material


static var _firefly_material: ShaderMaterial = null


const FIREFLY_SHADER := """
shader_type spatial;
render_mode cull_back, diffuse_lambert, specular_disabled;

global uniform float kubik_night;
uniform float night_life = 1.0;

varying float v_glow;

// sRGB on the wire, as everywhere else. ALBEDO is decoded by the engine;
// EMISSION is not, so it decodes here. Same function as Look.HEADER's.
vec3 kubik_to_linear(vec3 c) {
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), c));
}

void vertex() {
	// PHASE FROM THE WORLD POSITION, so every firefly drifts and blinks on its
	// own schedule without anything having to store a per-instance number.
	// Two different multipliers on x and z, and irrational-ish ratios between
	// the three periods, so nothing ever falls back into step.
	vec3 wp = MODEL_MATRIX[3].xyz;
	float ph = wp.x * 1.7 + wp.z * 2.3;

	VERTEX.x += sin(TIME * 0.60 + ph) * 0.40;
	VERTEX.z += cos(TIME * 0.47 + ph * 1.3) * 0.40;
	VERTEX.y += sin(TIME * 0.35 + ph * 0.7) * 0.22;

	// TODO(marcel): the blink is too regular. See the note below the shader.
	//
	// Squared so it spends most of its time dim and flares briefly, which is
	// what a firefly does - a plain sine reads as a pulsing lamp. What it is
	// not is IRREGULAR, and a real firefly is.
	float b = max(sin(TIME * 1.1 + ph * 2.1), 0.0);
	v_glow = (0.15 + 0.85 * b * b) * kubik_night * night_life;

	// GONE BY DAY, and collapsed rather than faded. Scaling the vertex to zero
	// makes the whole model a degenerate point: nothing is rasterised, there is
	// no alpha to sort, and at noon there is nothing to see rather than a
	// dark speck hanging in the air.
	VERTEX *= clamp(kubik_night * night_life, 0.0, 1.0);
}

void fragment() {
	// A firefly's body, dark so the glow is the whole of it. This shader has no
	// custom light() - it is diffuse_lambert - so ALBEDO is the engine's to
	// decode and the 0.15 lands in sRGB rather than in linear, which makes the
	// speck slightly lighter than 0.15 of its colour. It is a one-voxel body
	// under an EMISSION three times its own value, at night; not worth a
	// conversion. EMISSION does decode, on the line below, because it must.
	ALBEDO = COLOR.rgb * 0.15;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	EMISSION = kubik_to_linear(COLOR.rgb) * v_glow * 3.0;
}
"""


## TODO(marcel): make the fireflies blink like fireflies.
##
## The blink in FIREFLY_SHADER is one sine, squared. Every firefly therefore
## flashes at exactly the same RATE - only the phase differs - and once you have
## noticed that, a meadow full of them reads as a string of fairy lights rather
## than as insects.
##
## What a real firefly does is flash, wait an irregular while, and flash again.
##
##   Hint: multiply two sines whose periods do not divide into each other.
##
##       float a = max(sin(TIME * 1.10 + ph * 2.1), 0.0);
##       float c = max(sin(TIME * 0.37 + ph * 1.3), 0.0);
##       float b = a * a * c;
##
##   The second one is slow, so it gates the fast one on and off in bursts, and
##   because 1.10 and 0.37 are not related the pattern does not repeat for a
##   very long time. Push the two rates further apart for longer silences.
##
##   The reason to do it in the SHADER rather than by hashing a per-instance
##   rate is that there is nowhere to put a per-instance number: the MultiMesh
##   colour is already carrying the tint, and adding custom data to the buffer
##   would cost four floats on every plant in the world to give one model in
##   nineteen a variable it can derive from its own position anyway.
##
##   Worth turning night_life well up in the F4 panel while you look at it.
##
## Fallback: one squared sine, which blinks but does not wait.


# --- The model gallery ------------------------------------------------------

## Model names, for the gallery's 1:1 strip.
static func gallery_names() -> Array:
	return NAMES.duplicate()


## Build one model by name, at the default block size.
static func build_mesh(name: String) -> ArrayMesh:
	var i := NAMES.find(name)
	if i < 0:
		return null
	return build_mesh_from(voxels_for(i), 0.5, voxels_per_block(i))


static func gallery_material() -> ShaderMaterial:
	return material()


## The material one model is drawn with, by name, for the gallery.
##
## BY MATERIAL, NOT BY ONE SHARED ONE, because the firefly has its own shader
## and a gallery that drew it with the plant shader would be the one place in
## the project where the firefly shader is never compiled - which is exactly
## the shader most likely to be wrong, since it is the only one whose output
## is invisible for two thirds of the day.
static func gallery_material_for(name: String) -> ShaderMaterial:
	var i := NAMES.find(name)
	return material_for(i) if i >= 0 else material()
