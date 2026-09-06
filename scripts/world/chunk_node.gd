class_name ChunkNode
extends MeshInstance3D

## The visual half of a chunk, or since upload v1 Stage 3 of a whole COLUMN.
## Chunk holds the data, ChunkNode holds the mesh.
##
## Keeping them apart matters for multiplayer: a dedicated server would want
## Chunk without ever building a mesh, and the mesher can be moved onto a
## worker thread later precisely because it only touches Chunk.
##
## ONE NODE PER CHUNK, OR ONE PER COLUMN - upload v1 Stage 3, grill Q6, chosen
## by `WorldgenConfig.column_node` and decided by Stage 0's split, which put
## node creation at 17.0% of a column's arrival.
##
##   * per CHUNK (0): the node sits at its chunk's origin, its `mesh` has one
##     surface, and it owns one `StaticBody3D` with one `CollisionShape3D`.
##     Exactly what this file has always done.
##   * per COLUMN (1): the node sits at the COLUMN's origin - chunk (cx, 0, cz)
##     - its `mesh` has one surface per chunk that has faces, and one
##     `StaticBody3D` carries one `CollisionShape3D` per chunk. A column of four
##     chunks is four nodes and one body instead of twelve nodes and four
##     bodies.
##
## EVERYTHING IS KEYED BY THE CHUNK'S Y INDEX in both modes, and that is what
## keeps the two from being two files: per chunk the dictionaries below hold
## exactly one entry. `World` passes `chunk_pos.y` and never asks which mode it
## is in.
##
## THE COLUMN MODE'S ARRAYS ARE OFFSET, AND THE OFFSET IS THE JOB'S. A surface
## cannot carry a transform of its own, so a chunk at cy = 3 must be packed
## three chunks higher than the node. That addition happens in `ColumnJob`, on
## the worker, so `built[cy]["arrays"]` and `built[cy]["faces"]` are both
## already in the column's space by the time they reach here - which is what
## lets the upload parity gate go on comparing what was installed against what
## the job handed over, unchanged.

## The chunks this node draws, by chunk y index. One entry per chunk mode.
var chunks := {}

## True once a mesh AND its collision have been installed, for EVERY chunk this
## node carries. The node exists from the moment its chunk's voxels are
## published, but until the upload lands there is nothing to see and nothing to
## stand on - and the gap between the two is the upload queue, which can be many
## frames deep during a load.
##
## Kept as a whole-node summary for the readouts; `is_collidable(cy)` is the
## per-chunk truth and is what `World.is_chunk_collidable` asks.
var collision_applied := false

## HOW SLIPPERY THE GROUND IS, PER ZONE (world feel v1 Stage 12).
##
## One material per zone, built once and shared by every chunk in it, because a
## PhysicsMaterial is a resource and a thousand identical copies of one is a
## thousand things for the physics server to keep distinct.
##
## The numbers are friction coefficients and they are what makes a boulder's
## run-out depend on WHERE rather than on how hard it was hit: the same shove
## that stops in ten metres of meadow keeps going on scree.
##
## STARTING VALUES, all of them, and tuned blind - nobody has pushed a rock
## down a mountain and formed an opinion yet.
const ZONE_FRICTION := {
	TerrainGenerator.ZONE_SHORE: 0.9,
	TerrainGenerator.ZONE_MEADOW: 0.9,
	TerrainGenerator.ZONE_FOREST: 0.8,
	TerrainGenerator.ZONE_HEATH: 0.8,
	TerrainGenerator.ZONE_ROCK: 0.7,
	TerrainGenerator.ZONE_ALPINE: 0.45,
	TerrainGenerator.ZONE_SNOW: 0.3,
}

static var _materials := {}

var _block_size := 1.0
var _config: WorldgenConfig = null
var _world_seed := 0
var _body: StaticBody3D = null

## cy -> CollisionShape3D, cy -> surface index in `mesh`, cy -> has a shape been
## installed, cy -> was a mesh asked for (false on a collision-only chunk).
var _colliders := {}
var _surface := {}
var _installed := {}
var _want_mesh := {}
var _parked := false

## The column's own chunk y origin in column mode - always 0, because the node
## sits at chunk (cx, 0, cz) - and the chunk's own y in per-chunk mode. What a
## surface's arrays are offset BY is `(cy - _base_cy) * Chunk.SIZE * block_size`
## and in per-chunk mode that is zero by construction.
var _base_cy := 0
var _column_mode := false


## The shared material for one zone.
##
## A CHUNK IS ONE ZONE, ALMOST ALWAYS, and that is what makes this affordable.
## Zones are hundreds of metres across and a chunk is eight; the handful that
## straddle a boundary get the zone of their own column's centre, and being one
## chunk wrong about the friction of a boundary strip is not something anybody
## can feel. Per-triangle materials would be the alternative and they would cost
## a material lookup per contact for the rest of the project's life.
static func material_for_zone(zone: int) -> PhysicsMaterial:
	var got: PhysicsMaterial = _materials.get(zone)
	if got != null:
		return got
	got = PhysicsMaterial.new()
	got.friction = float(ZONE_FRICTION.get(zone, 0.8))
	# Nothing in this world bounces. A boulder that hops down a mountain reads
	# as a beach ball, and there is no surface here that should give anything
	# back.
	got.bounce = 0.0
	_materials[zone] = got
	return got


## `zone` is the surface zone of this chunk's COLUMN, worked out once on the
## worker that built it - see ColumnJob.zone - rather than looked up here. A
## generator query is a heightmap read and a noise sample, and doing it per
## chunk would be six or seven times per column for one answer.
##
## `column_mode` makes this the whole column's node: the position is the
## column's origin rather than the chunk's, and `add_chunk` brings the rest in.
func setup(p_chunk: Chunk, config: WorldgenConfig, world_seed: int,
		zone := TerrainGenerator.ZONE_MEADOW, column_mode := false) -> void:
	_block_size = config.block_size
	# Kept so an edited chunk remeshes with the same shading as the bulk load
	# gave it. Without this a block you break would leave its chunk flat-shaded
	# and visibly different from its neighbours.
	_config = config
	_world_seed = world_seed
	_column_mode = column_mode

	var c := p_chunk.chunk_pos
	_base_cy = 0 if column_mode else c.y
	add_chunk(p_chunk)

	# Collision is a StaticBody3D child rather than this node becoming one,
	# because a dedicated server wants Chunk with no mesh AND no body, and
	# keeping the two as separate children means neither is load-bearing for
	# the other.
	#
	# ONE BODY FOR THE WHOLE COLUMN in column mode, with one shape per chunk
	# under it. That is where most of Stage 3's saving is meant to be: a body is
	# a broadphase insert and a column had four of them.
	_body = StaticBody3D.new()
	_body.name = "Body"
	# The zone of this chunk's own column, decided once at build. See
	# material_for_zone().
	_body.physics_material_override = material_for_zone(zone)
	add_child(_body)

	name = ("Col%d_%d" % [c.x, c.z]) if column_mode \
		else ("Chunk%d_%d_%d" % [c.x, c.y, c.z])
	# The mesh is built in chunk-local coordinates (or column-local, in column
	# mode), so the node position supplies the world offset. That also means
	# editing one block rebuilds one small mesh, not a world-sized one.
	#
	# Note the scale factor rather than a scaled node: origin() is in BLOCKS and
	# the scene graph is in METRES, and that conversion happens here and in the
	# mesher and nowhere else.
	var origin := p_chunk.origin()
	if column_mode:
		origin.y = 0
	position = Vector3(origin) * _block_size


## Another chunk of this column. Column mode only; per chunk there is one.
func add_chunk(p_chunk: Chunk) -> void:
	chunks[p_chunk.chunk_pos.y] = p_chunk


## The one chunk, for a node that carries one. Kept because most of the world
## still thinks in chunks and only the arrival thinks in columns.
func chunk_at(cy: int) -> Chunk:
	return chunks.get(cy)


## Install a mesh built on a worker thread. This half of meshing has to happen
## on the main thread because ArrayMesh and the physics shape both talk to
## servers that are not safe to call from anywhere else - which is exactly why
## ColumnJob hands back arrays rather than a mesh.
##
## `want_mesh` false builds the COLLIDER ONLY (world feel v1 Stage 10). The host
## streams a small ring of columns around every remote peer so their body has
## ground under it, and nobody on the host's machine is looking at that ground -
## it is 500 m away and behind the fog. The arrays are still built, because the
## faces are derived from them, but no surface is added and nothing is drawn.
## That is the whole saving: the mesh upload is the part that touches the
## rendering server.
func apply_mesh(cy: int, arrays: Array, want_mesh := true) -> void:
	_want_mesh[cy] = want_mesh
	if want_mesh and not arrays.is_empty():
		_set_surface(cy, arrays)
	elif not want_mesh:
		_drop_surface(cy)
	var chunk: Chunk = chunks.get(cy)
	if chunk != null:
		chunk.dirty = false


## THE COLLISION HALF. `_installed[cy]` becomes true HERE and nowhere else on
## the arrival path, which is what makes `World.is_chunk_collidable` honest once
## the two halves can land in different frames (Stage 2).
##
## `shape` is a `ConcavePolygonShape3D` the WORKER already built from these
## faces - Stage 2.2, behind `shape_on_worker`. Handed in, this half is one
## assignment; null, the shape is built here as it always was.
func apply_collision(cy: int, faces := PackedVector3Array(),
		shape: Shape3D = null) -> void:
	var collider := _collider_at(cy)
	if shape != null:
		collider.shape = shape
	elif faces.is_empty():
		collider.shape = _derive_shape(cy)
	else:
		var built := ConcavePolygonShape3D.new()
		built.set_faces(faces)
		collider.shape = built
	_installed[cy] = true
	_refresh_collidable()


## Both halves at once, in the order they have always gone in. The edit path and
## the tests want the whole arrival in one line.
func apply_arrays(cy: int, arrays: Array, faces := PackedVector3Array(),
		want_mesh := true) -> void:
	apply_mesh(cy, arrays, want_mesh)
	apply_collision(cy, faces)


## Is there something to stand on in this chunk of this node?
func is_collidable(cy: int) -> bool:
	return bool(_installed.get(cy, false)) and not _parked


## False on a chunk built for collision only - see apply_mesh(). The world
## upgrades these when the host's own player comes near enough to see them.
func is_mesh_built(cy: int) -> bool:
	return bool(_want_mesh.get(cy, true))


## Park this node in the cache, or bring it back (world feel v1 Stage 4).
##
## Hidden and with its colliders off, a cached column costs a hidden
## MeshInstance3D and disabled shapes - kilobytes of bookkeeping against the
## milliseconds of a worker the player was waiting on. It is NOT in
## World._chunks while parked, receives no edits directly, and comes back
## through the same replay point everything else does.
func set_parked(parked: bool) -> void:
	_parked = parked
	visible = not parked
	for cy in _colliders:
		(_colliders[cy] as CollisionShape3D).disabled = parked
	# A parked chunk is not standable, and nothing must believe otherwise
	# between it leaving _chunks and coming back - nor is one whose shape is
	# still in the collision queue. See is_collidable().
	_refresh_collidable()


## Remesh one chunk after an edit, on the twin, and replace its surface.
##
## ONE CHUNK AND ONE SURFACE, which is the whole reason the surfaces are per
## chunk in column mode rather than one merged surface per column (mesher v1
## Q7: the twin is the edit path at 6.4 ms a chunk, and a column-wide remesh
## would be a 40 ms hitch per broken block).
func rebuild(cy: int, world_solid: Callable) -> void:
	var chunk: Chunk = chunks.get(cy)
	if chunk == null:
		return
	var arrays := ChunkMesher.build_arrays_gd(
		chunk, world_solid, _config, _world_seed)
	if arrays.is_empty():
		_drop_surface(cy)
	else:
		_set_surface(cy, offset_arrays(arrays, _y_offset(cy)))
	chunk.dirty = false
	_want_mesh[cy] = true
	_collider_at(cy).shape = _derive_shape(cy)
	_installed[cy] = true
	_refresh_collidable()


## ONE SURFACE'S ARRAYS MOVED UP BY `dy` METRES, and the only reason this is a
## static function on this file is that `ColumnJob` calls it too - on the
## worker, where the cost belongs. Upload v1 Stage 3.
##
## A copy rather than an in-place edit: the array handed in belongs to the job
## and the parity tests compare against it. Only ARRAY_VERTEX moves; a normal, a
## colour and an index are the same in both spaces, which is also why this is
## one loop over one array and not four.
static func offset_arrays(arrays: Array, dy: float) -> Array:
	if arrays.is_empty() or is_zero_approx(dy):
		return arrays
	var out := arrays.duplicate()
	var verts: PackedVector3Array = (out[Mesh.ARRAY_VERTEX] as PackedVector3Array).duplicate()
	var shift := Vector3(0.0, dy, 0.0)
	for i in verts.size():
		verts[i] = verts[i] + shift
	out[Mesh.ARRAY_VERTEX] = verts
	return out


## How far above this node's own origin chunk `cy` sits, in metres.
func _y_offset(cy: int) -> float:
	return float((cy - _base_cy) * Chunk.SIZE) * _block_size


## The collider for one chunk, made on first use. In column mode they are all
## children of the one body.
func _collider_at(cy: int) -> CollisionShape3D:
	var got: CollisionShape3D = _colliders.get(cy)
	if got != null:
		return got
	got = CollisionShape3D.new()
	got.name = "Shape%d" % cy
	got.disabled = _parked
	_body.add_child(got)
	_colliders[cy] = got
	return got


## Put these arrays on this chunk's surface, replacing whatever was there.
##
## SURFACE INDICES SHIFT WHEN ONE IS REMOVED, which is the one trap here:
## `surface_remove(i)` renumbers every surface after `i`. So the map is fixed up
## in the same breath, and nothing outside this file ever sees an index.
func _set_surface(cy: int, arrays: Array) -> void:
	# THE DROP COMES FIRST AND THE MESH IS RE-ACQUIRED AFTER IT, and the order
	# is not stylistic. `_drop_surface` sets `mesh` to null when it removes the
	# LAST surface, so a reference taken before it would have the new surface
	# added to an orphaned `ArrayMesh` while the node drew nothing. Every column
	# whose only faces are in its top chunk hits that on the first edit, which
	# is most of them, and the symptom is a chunk that goes invisible and loses
	# its collision the moment you break a block in it.
	_drop_surface(cy)
	if mesh == null:
		mesh = ArrayMesh.new()
	var am := mesh as ArrayMesh
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var index := am.get_surface_count() - 1
	am.surface_set_material(index, ChunkMesher.get_material())
	_surface[cy] = index


func _drop_surface(cy: int) -> void:
	if not _surface.has(cy):
		return
	var am := mesh as ArrayMesh
	var gone: int = _surface[cy]
	am.surface_remove(gone)
	_surface.erase(cy)
	for other in _surface:
		if int(_surface[other]) > gone:
			_surface[other] = int(_surface[other]) - 1
	if am.get_surface_count() == 0:
		mesh = null


## The surface index this chunk draws on, or -1. For the parity gate, which has
## to read back exactly the surface a chunk was installed on and not surface 0.
func surface_index_of(chunk_pos: Vector3i) -> int:
	return int(_surface.get(chunk_pos.y, -1))


## This chunk's collider. For the parity and honesty gates.
func collider_for(chunk_pos: Vector3i) -> CollisionShape3D:
	return _colliders.get(chunk_pos.y)


## Every collider this node owns. For the honesty gate's parked check.
func colliders() -> Array:
	return _colliders.values()


## THE COLLISION SHAPE IS GENERATED FROM THE VISIBLE MESH, so the two can never
## disagree - you cannot end up standing on a face that is not drawn, or walking
## through one that is. A chunk with no faces gets no shape at all rather than
## an empty one, which is one less thing for the physics server to keep track of.
##
## In column mode that means ONE SURFACE's triangles and not the column's: the
## surface is lifted into a mesh of its own first. This is the restore and edit
## path only - the arrival hands the faces in.
func _derive_shape(cy: int) -> Shape3D:
	if not _surface.has(cy) or mesh == null:
		return null
	var am := mesh as ArrayMesh
	if not _column_mode:
		return am.create_trimesh_shape()
	var one := ArrayMesh.new()
	one.add_surface_from_arrays(
		Mesh.PRIMITIVE_TRIANGLES, am.surface_get_arrays(int(_surface[cy])))
	return one.create_trimesh_shape()


## The whole-node summary: every chunk this node carries is standable.
func _refresh_collidable() -> void:
	if _parked:
		collision_applied = false
		return
	for cy in chunks:
		if not bool(_installed.get(cy, false)):
			collision_applied = false
			return
	collision_applied = not chunks.is_empty()
