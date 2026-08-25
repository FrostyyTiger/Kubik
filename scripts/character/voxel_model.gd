class_name VoxelModel

## Parts, as voxels, meshed the way terrain is meshed.
##
## A character is a handful of rigid parts on a Node3D rig. This file owns what
## a part IS - the ASCII format it is authored in, the voxel list it parses to,
## and the ArrayMesh it becomes. Nothing here knows about bones, animation or
## races.
##
##
## THE COORDINATE CONVENTION, ONCE, HERE
##
## The character faces `Vector3.FORWARD`, which Godot defines as `-Z`. The
## other two axes follow from the engine's own names rather than from a
## drawing: `Vector3.RIGHT` is `+X`, so a character in rest pose has its RIGHT
## hand at `+X` and its left at `-X`. `arm_r` is the `+X` arm. This is not a
## preference - `Player._face_movement()` turns the body with a yaw derived
## from `Vector3.FORWARD`, and the world self-test already asserts against
## that constant, so a model built to any other convention would be the thing
## that is wrong.
##
## A PART IS AUTHORED AS YOU SEE IT. Stand in front of the character, look at
## its face, and write down what you see:
##
##   - `slices` runs bottom to top. Slice 0 is `y = 0`, the feet end.
##   - Inside a slice, row 0 is the FRONT row, the `-Z` face - the row nearest
##     you. Rows run away from you as the index grows.
##   - Inside a row, the first character is the one on YOUR left as you look at
##     the character's front, which is the character's own right-hand side, and
##     is `+X`. So `x = size.x - 1 - column`.
##
## That last mapping is the only one that inverts, and it inverts for the same
## reason a portrait does: the subject's left hand is on the right of the
## picture. Authoring in view order is worth one line of arithmetic, because
## the alternative is authoring every face mirrored in your head.
##
## The plan phrased this as "+X is the character's left hand side", meaning the
## left of the picture. Stated in the engine's own vocabulary it is +X = RIGHT,
## and Stage 3's eyes-forward test is what actually pins the convention down:
## it asserts the iris voxels sit on the `-Z` side of the head, which is the
## half of this that a rendering can get visibly wrong.
##
##
## WHY ASCII AND NOT PRIMITIVES
##
## Hard rule 12: parts are data, not code. A head built from box primitives in
## code cannot be edited by anyone who is not editing code, cannot be diffed
## usefully, and cannot be swapped for a MagicaVoxel file later. The format
## below is deliberately the most boring one that can hold a voxel: an array of
## strings you can read in a terminal.

## Metres per model voxel. 16 per 0.5 m block since look v1: a 2 m human is
## 64 voxels tall. Character v1 built at 8 per block, the scale foliage v1
## fixed for plants; the look plan halved it for characters alone, because a
## face needs the resolution and a grass tuft does not. Plants stay at 1/8.
const VOXEL_M := 0.03125

## Semantic slots. A part is authored in these, never in colours - the same
## voxels resolved through a different palette are a different-looking
## character, and that is what makes a palette swap free.
enum {
	SKIN = 0,
	SKIN_SHADED = 1,
	HAIR = 2,
	IRIS = 3,
	EYE_WHITE = 4,
	MOUTH = 5,
	CLOTH = 6,
	CLOTH_DARK = 7,
	LEATHER = 8,
	BELT = 9,
	TOOTH = 10,
	METAL = 11,
	WOOD = 12,
}

const SLOT_COUNT := 13

## The legend, shared by every part file. `.` and space are empty.
const SLOT_CHARS := {
	"S": SKIN,
	"s": SKIN_SHADED,
	"H": HAIR,
	"E": IRIS,
	"W": EYE_WHITE,
	"M": MOUTH,
	"C": CLOTH,
	"c": CLOTH_DARK,
	"L": LEATHER,
	"B": BELT,
	"T": TOOTH,
	"X": METAL,
	"D": WOOD,
}

const SLOT_NAMES := [
	"skin", "skin_shaded", "hair", "iris", "eye_white", "mouth",
	"cloth", "cloth_dark", "leather", "belt", "tooth", "metal", "wood",
]

## AO levels are 0 (fully enclosed) to 3 (fully open), exactly as in
## ChunkMesher - the same rule, so a character shades like the ground it stands
## on rather than like a different game.
const AO_OPEN := 3


# --- Parsing ----------------------------------------------------------------

## An ASCII part to a list of `Vector4i(x, y, z, slot)`.
##
## Rejects a malformed part LOUDLY, with the part name and the exact slice and
## row. A silent off-by-one in a 32-slice part is an evening lost: the model
## builds, renders, looks nearly right, and the error is a shoulder one voxel
## too far back.
static func parse(part: Dictionary, part_name := "<unnamed>") -> Array:
	var out := []
	# A part that arrived already parsed - the `.vox` importer produces these.
	# Accepted here rather than at every call site so Rig, the gallery and the
	# self-tests never learn that a part can come from a file.
	if part.has("voxels"):
		return from_list(part["voxels"])
	if not part.has("size") or not part.has("slices"):
		push_error("[VoxelModel] part %s has no size or no slices" % part_name)
		return out
	var size: Vector3i = part["size"]
	if size.x <= 0 or size.y <= 0 or size.z <= 0:
		push_error("[VoxelModel] part %s has a non-positive size %s" % [part_name, size])
		return out
	var slices: Array = part["slices"]
	if slices.size() != size.y:
		push_error("[VoxelModel] part %s declares height %d but has %d slices" % [
			part_name, size.y, slices.size()])
		return out

	for y in size.y:
		var slice: Array = slices[y]
		if slice.size() != size.z:
			push_error("[VoxelModel] part %s slice %d: expected %d rows (depth), got %d" % [
				part_name, y, size.z, slice.size()])
			return []
		for z in size.z:
			var row: String = slice[z]
			if row.length() != size.x:
				push_error("[VoxelModel] part %s slice %d row %d: expected %d characters (width), got %d - %s" % [
					part_name, y, z, size.x, row.length(), row])
				return []
			for col in size.x:
				var ch := row[col]
				if ch == "." or ch == " ":
					continue
				if not SLOT_CHARS.has(ch):
					push_error("[VoxelModel] part %s slice %d row %d column %d: '%s' is not a slot character" % [
						part_name, y, z, col, ch])
					return []
				# See the coordinate convention above: the first column is the
				# left of the picture, which is +X.
				out.append(Vector4i(size.x - 1 - col, y, z, SLOT_CHARS[ch]))
	return out


## A voxel list straight in, for a part that was not authored as ASCII - the
## `.vox` importer in Stage 11 produces one of these.
##
## FOLIAGE V1 PRODUCES A DIFFERENT SHAPE on its own branch tonight:
## `(x, y, z, colour, emissive)`, with colours already resolved rather than
## left as slots. The two builders are the same mesher with a different resolve
## step, and unifying them is a ten-line change once both branches have landed.
## Deliberately NOT done here: it would mean this branch guessing at the exact
## shape of a file it is forbidden to look at.
static func from_list(voxels: Array) -> Array:
	var out := []
	for v in voxels:
		if v is Vector4i:
			out.append(v)
		else:
			push_error("[VoxelModel] from_list expects Vector4i(x, y, z, slot), got %s" % type_string(typeof(v)))
			return []
	return out


## The same voxels with some slots replaced. `mapping` is slot -> slot.
##
## This is how the blink works: the eyes-closed head is the SAME part with
## `IRIS` and `EYE_WHITE` resolved to `SKIN`, so there is one head to author
## and no way for the two variants to drift apart.
static func remap_slots(voxels: Array, mapping: Dictionary) -> Array:
	var out := []
	for v in voxels:
		var slot: int = v.w
		out.append(Vector4i(v.x, v.y, v.z, mapping.get(slot, slot)))
	return out


## Mirror a voxel list across the model's X axis, inside a part of `width`.
##
## One arm is authored and the other is this. Not a scale of -1 on the node:
## a negative scale flips the winding of every triangle, so the mesh renders
## inside out with back-face culling on, and it flips the child bones' axes
## too, which would make the animator's left and right rotations disagree.
static func mirror_x(voxels: Array, width: int) -> Array:
	var out := []
	for v in voxels:
		out.append(Vector4i(width - 1 - v.x, v.y, v.z, v.w))
	return out


## The anchor, mirrored the same way. Kept beside mirror_x so the two can never
## be applied to different widths.
##
## The anchor is in LATTICE coordinates, not voxel indices, so it mirrors about
## the part's width rather than about width - 1. See _to_metres.
static func mirror_anchor_x(anchor: Vector3, width: int) -> Vector3:
	return Vector3(float(width) - anchor.x, anchor.y, anchor.z)


# --- Geometry facts, for the self-tests -------------------------------------

## Which voxels of a list carry a given slot.
static func voxels_with_slot(voxels: Array, slot: int) -> Array:
	var out := []
	for v in voxels:
		if v.w == slot:
			out.append(v)
	return out


## Mean position of the voxels carrying `slot`, in voxel units. Vector3.ZERO
## with a count of 0 means the slot is absent; callers check the count.
static func slot_centroid(voxels: Array, slot: int) -> Vector3:
	var sum := Vector3.ZERO
	var n := 0
	for v in voxels:
		if v.w == slot:
			sum += Vector3(v.x, v.y, v.z)
			n += 1
	return sum / float(n) if n > 0 else Vector3.ZERO


## Inclusive voxel bounds as [min, max]. An empty list gives a zero AABB.
static func bounds(voxels: Array) -> Array:
	if voxels.is_empty():
		return [Vector3i.ZERO, Vector3i.ZERO]
	var lo := Vector3i(voxels[0].x, voxels[0].y, voxels[0].z)
	var hi := lo
	for v in voxels:
		lo = Vector3i(mini(lo.x, v.x), mini(lo.y, v.y), mini(lo.z, v.z))
		hi = Vector3i(maxi(hi.x, v.x), maxi(hi.y, v.y), maxi(hi.z, v.z))
	return [lo, hi]


# --- Meshing ----------------------------------------------------------------

## The terrain's material, so a character is made of the same stuff as the
## ground it stands on. Flat vertex colour, no specular, no texture, and since
## look v1 the poster ramp - the same object the chunks draw with, see Look.
## Shared across every part of every character - the colour is in the
## vertices, so one material serves every palette.
static func material() -> Material:
	return Look.opaque_material()


## Mesh a voxel list into an ArrayMesh, in metres, with baked corner AO.
##
## `palette` maps slot -> LINEAR Color. `anchor` is the voxel whose
## bottom-centre lands on the origin, which is the bone pivot.
##
## NO GREEDY MERGE, deliberately. Terrain merges because a meadow chunk is
## thousands of identical quads; a part is a few hundred at most, and merging
## fights baked AO - the mesher splits every run wherever the corner shading
## changes, and on a face the size of a head almost every quad's shading
## differs from its neighbour's. The merge would cost more than it saved. If
## the triangle budget ever breaks, this is the first thing to revisit; the
## counts are recorded in the status doc so the decision can be re-argued with
## numbers.
static func build_mesh(voxels: Array, palette: Dictionary, anchor: Vector3,
		ao_strength := 0.35) -> ArrayMesh:
	if voxels.is_empty():
		return null

	# A set to test occupancy against. Vector3i keys rather than a flat array
	# because a part's bounds are not known until it is parsed and a sparse
	# part (a beard, a crest) would be mostly empty either way.
	var solid := {}
	for v in voxels:
		solid[Vector3i(v.x, v.y, v.z)] = true

	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()

	for v in voxels:
		var p := Vector3i(v.x, v.y, v.z)
		var color: Color = palette.get(v.w, Color.MAGENTA)
		for d in 3:
			for s: int in [-1, 1]:
				var n := p
				n[d] += s
				if solid.has(n):
					continue  # a face between two voxels of one part
				_emit_face(p, d, s, solid, color, ao_strength, anchor,
					verts, normals, colors, indices)

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
	mesh.surface_set_material(0, material())
	return mesh


## One voxel face: four vertices, two triangles, four AO'd corners.
##
## WINDING ORDER MATTERS, and it is the mesher's identity that decides it:
## with (u, v, d) right-handed, these two corner orders satisfy
## (p1 - p0) x (p2 - p0) == -normal, which is the algebraic form of "clockwise
## seen from outside" - the face Godot draws, since back faces are culled.
## Getting it wrong does not lose a face, it turns the model inside out.
static func _emit_face(p: Vector3i, d: int, s: int, solid: Dictionary,
		color: Color, ao_strength: float, anchor: Vector3,
		verts: PackedVector3Array, normals: PackedVector3Array,
		colors: PackedColorArray, indices: PackedInt32Array) -> void:
	var u := (d + 1) % 3
	var v := (d + 2) % 3

	var normal := Vector3.ZERO
	normal[d] = float(s)

	# The block on the AIR side of the face. AO is a question about the air,
	# not about the solid: what can see this corner.
	var air := p
	air[d] += s

	# Corner order, and the canonical corner each vertex is - the winding
	# differs between the two facings and the AO does not, so the two lists are
	# not reorderings of the same four points.
	var corners: Array[Vector2i]
	if s > 0:
		corners = [Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(1, 0)]
	else:
		corners = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1)]

	var first := verts.size()
	for c in corners:
		var voxel_pos := Vector3.ZERO
		voxel_pos[d] = float(p[d] + (1 if s > 0 else 0))
		voxel_pos[u] = float(p[u] + c.x)
		voxel_pos[v] = float(p[v] + c.y)
		verts.push_back(_to_metres(voxel_pos, anchor))
		normals.push_back(normal)

		# The three voxels diagonally adjacent to this corner, in the air
		# block's own plane.
		var du: int = c.x * 2 - 1
		var dv: int = c.y * 2 - 1
		var side1 := air
		side1[u] += du
		var side2 := air
		side2[v] += dv
		var diag := air
		diag[u] += du
		diag[v] += dv
		var level := _vertex_ao(solid.has(side1), solid.has(side2), solid.has(diag))
		# The palette is LINEAR (see Block), and occlusion is a multiplication
		# in linear space - a plain scale, not a blend towards a darker colour,
		# so it stays correct if the palette is re-authored.
		var shade := 1.0 - ao_strength * (1.0 - float(level) / float(AO_OPEN))
		colors.push_back(Look.to_wire(
			Color(color.r * shade, color.g * shade, color.b * shade, color.a)))

	indices.push_back(first)
	indices.push_back(first + 1)
	indices.push_back(first + 2)
	indices.push_back(first)
	indices.push_back(first + 2)
	indices.push_back(first + 3)


## AO level 0 (darkest) to 3 (fully open) for one corner. ChunkMesher's rule,
## including the special case that is the whole point of it: when both SIDES
## are solid the corner is an interior angle and the diagonal makes no
## difference, because you cannot see past two walls meeting. Without it every
## interior corner comes out one step lighter wherever the diagonal happens to
## be missing, which reads as a bright seam up the join.
##
## AO_STRENGTH IS LOWER HERE THAN ON TERRAIN, at 0.35 against the world's 0.45.
## A face is smaller than a hillside and the same amount of darkening reads as
## dirt on it rather than as shape. The number is in CharacterConfig and on the
## F8 panel; see the "Tuned blind" table.
static func _vertex_ao(side1: bool, side2: bool, corner: bool) -> int:
	if side1 and side2:
		return 0
	return 3 - (int(side1) + int(side2) + int(corner))


## Voxel-space corner to metres.
##
## THE ANCHOR IS A LATTICE POINT, NOT A VOXEL INDEX. Integer values fall on
## voxel BOUNDARIES, so the anchor is the point of the part's own grid that
## lands on the bone pivot: `Vector3(4, 0, 4)` is exactly the bottom-centre of
## an 8 x 9 x 8 head, and `Vector3(1.5, 9, 1.5)` is exactly the top-centre of a
## 3 x 9 x 3 leg, which is where a leg swings from.
##
## Voxel-index anchoring was the first version and it cannot centre an
## even-width part: index 4 of an 8-wide head puts the head's middle half a
## voxel - 3.1 cm - to one side, which is a visible list on a character whose
## whole readability argument is symmetry. Lattice coordinates cost nothing and
## make the plan's own example, anchor (4, 0, 4) for a width-8 head, exactly
## right instead of nearly right.
static func _to_metres(voxel_pos: Vector3, anchor: Vector3) -> Vector3:
	return (voxel_pos - anchor) * VOXEL_M
