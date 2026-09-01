class_name TreeModels

## The tree library: sculpted voxel trees, meshed through this game's pipeline.
##
##     assets/purchased/trees/<variant>.ktree   packed greedy quads, 3 LOD rungs
##     assets/purchased/trees/<variant>.json    what the game needs to know
##
##
## A SIBLING OF FloraModels, NOT A TENANT (trees v3 decision 4).
##
## The obvious move is to append trees to `FloraModels` and reuse its cache.
## It does not work: a `FloraModels` id is the TOP BYTE of a 64-bit flora
## identity (`FloraPlacement.identity`), and the removal and body-promotion
## machinery keys off that byte. Adding thirty-eight tree ids to that enum
## would put trees inside a system that thinks it can promote them to bodies
## and gather them into a removal set - two behaviours this epic explicitly
## does not want yet, arriving by accident.
##
## So this is the same SHAPE - `available()`, `mesh_for()`, `triangles_for()`,
## a mutex-guarded lazy cache - with its own ids and its own material, and the
## two files never refer to each other.
##
##
## THE PUBLIC BUILD HAS NO TREES, AND THAT IS THE DESIGN (ruling 6).
##
## `available()` is false when the mount is not there, and every caller is
## required to handle it. Placement still computes, the field still walks its
## bands, nothing is planted, nothing crashes, and the self-test passes - which
## CI proves on every push by construction, because CI has no assets repo.
## There is NO FALLBACK TREE SYSTEM. Marcel: "not two."
##
##
## GDSCRIPT ASSEMBLES. IT NEVER MESHES.
##
## The quads in a `.ktree` were greedy-meshed offline by
## `Kubik-assets/tools/trees_convert.py`. What happens here is a loop that
## turns each quad into four vertices and six indices - no occupancy test, no
## neighbour lookup, no merging. That distinction is the whole reason the
## format is quads: this engine build serialises GDScript across threads, and
## meshing a 74,000-voxel shell in GDScript is the pathology ground cover was
## moved off the block grid to escape (`FloraModels:9`).

## Where the library is mounted. `sync_assets.py` copies it out of the private
## assets repo; the directory is gitignored and CI never has it.
const ROOT := "res://assets/purchased/trees"

## Model voxels per world block. FOUR - 12.5 cm - which is the shrub rung of
## `FloraModels.voxels_per_block`, and the rung `DESIGN.md`'s ladder table has
## said trees belong on since trees v2 diagnosed them as being off the bottom
## of it. Asserted against every sidecar at load: the tool computes its
## `height_m` from its own copy of this number, and a disagreement means the
## library and the game are on different ladders.
const VOXELS_PER_BLOCK := 4

## The three LOD rungs, as the tool bakes them: full, 2x, 4x.
const LOD_COUNT := 3

const MAGIC := 0x4552544B   # "KTRE" little-endian

static var _index := {}          # variant StringName -> sidecar Dictionary
static var _order := []          # variant names, sorted, for the gallery
static var _by_species := {}     # species StringName -> [variant, ...]
static var _scanned := false
static var _meshes := {}         # "variant|lod|block_size" -> ArrayMesh
static var _triangles := {}
static var _mutex := Mutex.new()


# --- Is there a library at all ----------------------------------------------

## Is the purchased library mounted?
##
## FIRST-CLASS FALSE. Every caller branches on this and the self-test exercises
## both legs at every stage (hard rule 3). It is not an error path.
static func available() -> bool:
	_scan()
	return not _index.is_empty()


## Every variant in the library, sorted. Empty in the public build.
static func variants() -> Array:
	_scan()
	return _order


## Every variant of one pack species, sorted. Empty for an unknown species.
static func variants_of(species: StringName) -> Array:
	_scan()
	return _by_species.get(species, [])


## Every pack species in the library, sorted.
static func species() -> Array:
	_scan()
	var out := _by_species.keys()
	out.sort()
	return out


## One variant's sidecar, or {} if there is no such variant.
static func info(variant: StringName) -> Dictionary:
	_scan()
	return _index.get(variant, {})


## How tall this variant stands, in metres, at the model ladder's tree rung.
## The mapping table may scale it; this is what the artist drew.
static func height_m(variant: StringName) -> float:
	return float(info(variant).get("height_m", 0.0))


## Trunk radius and height IN METRES, for the collider (decision 8). Measured
## off the model by the tool, not typed - see its `trunk_of()`.
static func trunk_of(variant: StringName) -> Vector2:
	var d := info(variant)
	if d.is_empty():
		return Vector2.ZERO
	var t: Dictionary = d.get("trunk", {})
	var unit := float(d.get("voxel_m", 0.125))
	return Vector2(float(t.get("radius_voxels", 1.0)) * unit,
		float(t.get("height_voxels", 1)) * unit)


## THE DOMINANT CANOPY COLOUR OF ONE VARIANT, LINEAR - decision 7's new pin.
##
## `FarTreeMeshes.color_of_species()` read `Block.color_of(row["leaves"])`, and
## that pin is dead the night leaf blocks die. This replaces it, and the reason
## near and far cannot drift apart any more is stronger than the reason they
## could not before: they are THE SAME MESH under THE SAME TABLE. The drift
## mechanism is what got deleted, not the drift.
static func canopy_color(variant: StringName) -> Color:
	var d := info(variant)
	if d.is_empty():
		return Color(0.0284, 0.0782, 0.0482)
	return TreePalette.color_of(variant, int(d.get("canopy_palette", 0)))


# --- The meshes -------------------------------------------------------------

## One variant at one LOD rung, assembled and cached. null if there is no
## library, no such variant, or the rung is empty.
static func mesh_for(variant: StringName, lod: int,
		block_size: float) -> ArrayMesh:
	var key := "%s|%d|%.4f" % [variant, lod, block_size]
	var got: ArrayMesh = _meshes.get(key)
	if got != null:
		return got
	_scan()
	if not _index.has(variant):
		return null
	_mutex.lock()
	got = _meshes.get(key)
	if got == null:
		got = _build(variant, lod, block_size)
		_meshes[key] = got
		_triangles[key] = 0 if got == null \
			else got.surface_get_array_index_len(0) / 3
	_mutex.unlock()
	return got


## Triangles in one instance of this variant at this rung.
static func triangles_for(variant: StringName, lod: int,
		block_size: float) -> int:
	var key := "%s|%d|%.4f" % [variant, lod, block_size]
	if not _triangles.has(key):
		mesh_for(variant, lod, block_size)
	return int(_triangles.get(key, 0))


## Drop every assembled mesh. For the F4 panel and for the self-test, which
## builds several small worlds at different block sizes in one process.
static func clear_cache() -> void:
	_mutex.lock()
	_meshes.clear()
	_triangles.clear()
	_mutex.unlock()


# --- Reading the library ----------------------------------------------------

static func _scan() -> void:
	if _scanned:
		return
	_mutex.lock()
	if not _scanned:
		_scanned = true
		_scan_locked()
	_mutex.unlock()


static func _scan_locked() -> void:
	var dir := DirAccess.open(ROOT)
	if dir == null:
		# THE PUBLIC BUILD. Not a warning: the README's rule is that the game
		# must always run without these assets, and a build that printed a
		# warning every launch would be a build that trained people to ignore
		# warnings.
		return
	for file in dir.get_files():
		if not file.ends_with(".json"):
			continue
		var text := FileAccess.get_file_as_string("%s/%s" % [ROOT, file])
		if text.is_empty():
			push_warning("[TreeModels] %s is empty" % file)
			continue
		var parsed = JSON.parse_string(text)
		if typeof(parsed) != TYPE_DICTIONARY:
			push_warning("[TreeModels] %s is not a sidecar" % file)
			continue
		var d: Dictionary = parsed
		var name := StringName(d.get("variant", file.get_basename()))
		# THE LADDER IS ASSERTED, NOT ASSUMED. The tool computes `height_m`
		# from its own copy of VOXELS_PER_BLOCK, so if the two ever disagree
		# every tree in the world is the wrong size and nothing else says so.
		if int(d.get("voxels_per_block", VOXELS_PER_BLOCK)) != VOXELS_PER_BLOCK:
			push_warning("[TreeModels] %s was baked at %s voxels per block, this build is %d" % [
				name, d.get("voxels_per_block"), VOXELS_PER_BLOCK])
			continue
		_index[name] = d
		var sp := StringName(d.get("species", "unknown"))
		if not _by_species.has(sp):
			_by_species[sp] = []
		(_by_species[sp] as Array).append(name)
	_order = _index.keys()
	_sort_names(_order)
	for sp in _by_species:
		_sort_names(_by_species[sp])


## SORT StringNames BY THEIR TEXT, BECAUSE `Array.sort()` DOES NOT.
##
## `StringName` compares by its internal POINTER, not lexicographically - that
## is the whole point of a StringName and it is why comparing one is an integer
## compare. So `[&"t16_6", &"t05", &"t5_5", &"t09_1"].sort()` returns
## `[t09_1, t5_5, t05, t16_6]`: a stable order, an arbitrary one, and one that
## changes with allocation.
##
## It cost a gallery sheet to find, and the symptom is worth recognising
## because it does not look like a sort bug: the first sheet came out
## `t5_5, t16_6, t16_5, t16_4 ...`, which reads as a deliberate reverse sort
## rather than as no sort at all.
static func _sort_names(names: Array) -> void:
	names.sort_custom(func(a, b): return String(a) < String(b))


## The quads of one variant at one rung, straight out of the binary.
##
## A TWIN READS ITS SIBLING'S GEOMETRY. Species 12-15 ship the same tree in
## five palettes, and the tool emitted one `.ktree` for the five - so a twin's
## sidecar names the geometry it shares and the colour comes from ITS OWN row
## of the palette table. That is what makes a whole autumn forest cost no new
## triangles.
static func _quads(variant: StringName, lod: int) -> PackedByteArray:
	var d: Dictionary = _index.get(variant, {})
	var geometry := String(d.get("geometry", variant))
	var bytes := FileAccess.get_file_as_bytes("%s/%s.ktree" % [ROOT, geometry])
	if bytes.size() < 8:
		push_warning("[TreeModels] %s.ktree is missing or truncated" % geometry)
		return PackedByteArray()
	if bytes.decode_u32(0) != MAGIC:
		push_warning("[TreeModels] %s.ktree is not a KTRE file" % geometry)
		return PackedByteArray()
	if bytes[4] != 1:
		push_warning("[TreeModels] %s.ktree is version %d, this build reads 1" % [
			geometry, bytes[4]])
		return PackedByteArray()
	var lods := int(bytes[6])
	if lod < 0 or lod >= lods:
		return PackedByteArray()
	# Walk the rungs rather than seeking: the counts are what say where the
	# next one starts, and a file whose header lied would otherwise be read
	# as geometry rather than rejected.
	var at := 8
	for i in lods:
		if at + 4 > bytes.size():
			push_warning("[TreeModels] %s.ktree ends inside LOD %d" % [geometry, i])
			return PackedByteArray()
		var n := int(bytes.decode_u32(at))
		at += 4
		var span := n * 12
		if at + span > bytes.size():
			push_warning("[TreeModels] %s.ktree LOD %d claims %d quads it does not have" % [
				geometry, i, n])
			return PackedByteArray()
		if i == lod:
			return bytes.slice(at, at + span)
		at += span
	return PackedByteArray()


## THE FOUR CORNERS OF EACH FACE, AS OFFSETS ALONG THE FACE'S OWN TWO AXES.
##
## `FloraModels.FACES` in a form that takes a WIDTH and a HEIGHT, because a
## greedy quad is a rectangle rather than one voxel's face. Each row is
## `[axis, u, v, corner order]` where the corner order is four (du, dv) pairs
## wound CLOCKWISE SEEN FROM OUTSIDE - Godot's front face, and the same rule
## `ChunkMesher`'s winding self-test enforces on the terrain:
##
##     (p1 - p0) x (p2 - p0) == -normal
##
## `FloraModels` records that every one of its six was backwards on the first
## attempt, and that the symptom was not an inside-out model but thin
## horizontal gaps through every rounded blob. So these are checked by the
## `tree winding` self-test with the cross product, not by looking at them.
const FACE_NORMALS := [
	Vector3i(1, 0, 0), Vector3i(-1, 0, 0),
	Vector3i(0, 1, 0), Vector3i(0, -1, 0),
	Vector3i(0, 0, 1), Vector3i(0, 0, -1),
]

## Per face: which axis it is perpendicular to, which two axes its width and
## height run along, whether the quad sits at the voxel's far side of its axis,
## and whether the winding needs flipping.
## THE FLIP COLUMN WAS WRONG ON FOUR OF SIX AND THE CROSS PRODUCT FOUND IT.
##
## Written by reasoning about the corner order, the first version had `+X`,
## `-X`, `+Y` and `-Y` backwards - 326,514 triangles of 481,654 - and the two
## Z faces right, which is exactly the pattern that makes a winding bug look
## like a modelling choice rather than a mistake. `FloraModels` records the
## same experience from the other side: all six of ITS faces were backwards and
## the symptom was not an inside-out model.
##
## The rule, once derived rather than guessed: the corner order below traces
## `(0,0) (w,0) (w,h) (0,h)` in the face's own `(u, v)` plane, so the triangle
## normal is `+(u x v)`. For `X` that is `y x z = +x` and for `Z` it is
## `x x y = +z`, both pointing the same way as the axis - but for `Y` it is
## `x x z = -y`, pointing the OTHER way. So the flip is `offset == 1` on X and
## Z and `offset == 0` on Y, and Y being the odd one out is the whole of it.
##
## Do not edit this table by looking at a render. `tree winding` in the
## self-test checks all six with `(p1 - p0) x (p2 - p0) == -normal`, on every
## variant at every rung, and it is the thing that pins these six booleans.
const FACE_AXES := [
	# face   axis  u  v  offset  flip
	[0, 1, 2, 1, true],    # +X: u = y, v = z
	[0, 1, 2, 0, false],   # -X
	[1, 0, 2, 1, false],   # +Y: u = x, v = z
	[1, 0, 2, 0, true],    # -Y
	[2, 0, 1, 1, true],    # +Z: u = x, v = y
	[2, 0, 1, 0, false],   # -Z
]


static func _build(variant: StringName, lod: int,
		block_size: float) -> ArrayMesh:
	var quads := _quads(variant, lod)
	if quads.is_empty():
		return null
	var d: Dictionary = _index[variant]
	var lods: Array = d.get("lods", [])
	if lod >= lods.size():
		return null
	var step := int((lods[lod] as Dictionary).get("step", 1))
	# The rung's voxel is the base voxel times its own downsample step, so
	# every LOD of one tree is the same size in metres and only its grain
	# changes. That is what makes the far bands a RESOLUTION boundary rather
	# than a KIND boundary (ruling 4).
	var unit := block_size / float(VOXELS_PER_BLOCK) * float(step)
	var colors := TreePalette.table_for(variant)

	# The origin is the model's bottom centre in LOD0 voxels; at a coarser
	# rung it is that many of ITS voxels, so the trunk stays under the crown.
	var origin: Array = d.get("origin_voxels", [0, 0, 0])
	var ox := float(int(origin[0])) / float(step)
	var oz := float(int(origin[2])) / float(step)

	# THE SWAY WEIGHT, NORMALISED, and open question 3 answered: it rides in
	# COLOR's ALPHA. A tree has no emissive parts - it is the one model family
	# in this game whose alpha channel is free - so the crown gets the slot the
	# mushrooms use for their glow, at zero cost in vertices, attributes or
	# draw calls.
	#
	# 0 at the roots and 1 at the very top of the model, so a 28 m Tree 11 and
	# a 2 m stump sway the same PROPORTION of their own height and the shader
	# needs to know nothing about either. Eight bits on the wire is 256 levels
	# over a tree, which is finer than a voxel on every model in the library.
	var size: Array = d.get("size", [1, 1, 1])
	var inv_height := float(step) / maxf(float(int(size[1])), 1.0)

	var n := quads.size() / 12
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var cols := PackedColorArray()
	var indices := PackedInt32Array()
	verts.resize(n * 4)
	normals.resize(n * 4)
	cols.resize(n * 4)
	indices.resize(n * 6)

	var vi := 0
	var ii := 0
	for q in n:
		var at := q * 12
		var p := [
			float(quads.decode_u16(at)),
			float(quads.decode_u16(at + 2)),
			float(quads.decode_u16(at + 4))]
		var face := int(quads[at + 6])
		var pal := int(quads[at + 7])
		var w := float(quads.decode_u16(at + 8))
		var h := float(quads.decode_u16(at + 10))
		if face < 0 or face > 5:
			continue

		var row: Array = FACE_AXES[face]
		var axis: int = row[0]
		var u: int = row[1]
		var v: int = row[2]
		p[axis] += float(row[3])

		# sRGB on the wire, once, at the push - see Look.to_wire(). Alpha
		# carries the sway weight rather than emissive: a tree has no glowing
		# parts and its crown has to know how far it is off the ground. See
		# Look.tree_material().
		var c := Look.to_wire(colors[pal])

		var corners := [Vector2(0.0, 0.0), Vector2(w, 0.0),
			Vector2(w, h), Vector2(0.0, h)]
		var first := vi
		var normal := Vector3(FACE_NORMALS[face])
		for k in 4:
			var corner: Vector2 = corners[k]
			var pos := [p[0], p[1], p[2]]
			pos[u] += corner.x
			pos[v] += corner.y
			# Centred on x and z, standing on y - FloraModels' own convention,
			# so an instance transform puts the trunk on the ground.
			verts[vi] = Vector3(
				(pos[0] - ox) * unit, pos[1] * unit, (pos[2] - oz) * unit)
			normals[vi] = normal
			var sway := clampf(pos[1] * inv_height, 0.0, 1.0)
			cols[vi] = Color(c.r, c.g, c.b, sway)
			vi += 1

		if bool(row[4]):
			indices[ii] = first; indices[ii + 1] = first + 2
			indices[ii + 2] = first + 1
			indices[ii + 3] = first; indices[ii + 4] = first + 3
			indices[ii + 5] = first + 2
		else:
			indices[ii] = first; indices[ii + 1] = first + 1
			indices[ii + 2] = first + 2
			indices[ii + 3] = first; indices[ii + 4] = first + 2
			indices[ii + 5] = first + 3
		ii += 6

	if ii == 0:
		return null
	verts.resize(vi)
	normals.resize(vi)
	cols.resize(vi)
	indices.resize(ii)

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = cols
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, Look.tree_material())
	return mesh
