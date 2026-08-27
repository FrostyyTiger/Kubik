class_name ChunkNode
extends MeshInstance3D

## The visual half of a chunk. Chunk holds the data, ChunkNode holds the mesh.
##
## Keeping them apart matters for multiplayer: a dedicated server would want
## Chunk without ever building a mesh, and the mesher can be moved onto a
## worker thread later precisely because it only touches Chunk.

var chunk: Chunk

## True once a mesh AND its collision have been installed. The node exists
## from the moment its chunk's voxels are published, but until the upload
## lands there is nothing to see and nothing to stand on - and the gap between
## the two is the upload queue, which can be many frames deep during a load.
var collision_applied := false

## False on a node built for collision only - see apply_arrays(). The world
## upgrades these when the host's own player comes near enough to see them.
var mesh_built := true

## HOW SLIPPERY THE GROUND IS, PER ZONE (world feel v1 Stage 12).
##
## One material per zone, built once and shared by every chunk in it, because a
## PhysicsMaterial is a resource and a thousand identical copies of one is a
## thousand things for the physics server to keep distinct.
##
## The numbers are friction coefficients and they are what makes a boulder's
## run-out depend on WHERE rather than on how hard it was hit: the same shove
## that stops in ten metres of meadow keeps going on scree. That is the same
## argument as the slide in Locomotion, applied to the things rather than to
## the player, and it is why both are keyed off the same zone.
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
var _collider: CollisionShape3D = null


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
func setup(p_chunk: Chunk, config: WorldgenConfig, world_seed: int,
		zone := TerrainGenerator.ZONE_MEADOW) -> void:
	chunk = p_chunk
	_block_size = config.block_size
	# Kept so an edited chunk remeshes with the same shading as the bulk load
	# gave it. Without this a block you break would leave its chunk flat-shaded
	# and visibly different from its neighbours.
	_config = config
	_world_seed = world_seed

	# Collision is a StaticBody3D child rather than this node becoming one,
	# because a dedicated server wants Chunk with no mesh AND no body, and
	# keeping the two as separate children means neither is load-bearing for
	# the other.
	var body := StaticBody3D.new()
	body.name = "Body"
	# The zone of this chunk's own column, decided once at build. See
	# material_for_zone().
	body.physics_material_override = material_for_zone(zone)
	add_child(body)
	_collider = CollisionShape3D.new()
	body.add_child(_collider)
	var c := p_chunk.chunk_pos
	name = "Chunk%d_%d_%d" % [c.x, c.y, c.z]
	# The mesh is built in chunk-local coordinates, so the node position
	# supplies the world offset. That also means editing one block rebuilds one
	# small mesh, not a world-sized one.
	#
	# Note the scale factor rather than a scaled node: origin() is in BLOCKS and
	# the scene graph is in METRES, and that conversion happens here and in the
	# mesher and nowhere else.
	position = Vector3(p_chunk.origin()) * _block_size


## Install a mesh built on a worker thread. This half of meshing has to happen
## on the main thread because ArrayMesh and the physics shape both talk to
## servers that are not safe to call from anywhere else - which is exactly why
## ColumnJob hands back arrays rather than a mesh.
## `faces` is the triangle soup the worker already derived from the index
## buffer (ChunkMesher.faces_from). Passing it in leaves the main thread one
## allocation and one memcpy instead of a walk over every index; omit it and
## the shape is derived here, which is what the edit path does.
## `want_mesh` false builds the COLLIDER ONLY (world feel v1 Stage 10). The
## host streams a small ring of columns around every remote peer so their body
## has ground under it, and nobody on the host's machine is looking at that
## ground - it is 500 m away and behind the fog. The arrays are still built,
## because the faces are derived from them, but no ArrayMesh is uploaded and
## nothing is drawn. That is the whole saving: the mesh upload is the part that
## touches the rendering server.
func apply_arrays(arrays: Array, faces := PackedVector3Array(),
		want_mesh := true) -> void:
	mesh = ChunkMesher.arrays_to_mesh(arrays) if want_mesh else null
	if faces.is_empty():
		_apply_collision()
	else:
		var shape := ConcavePolygonShape3D.new()
		shape.set_faces(faces)
		_collider.shape = shape
	chunk.dirty = false
	collision_applied = true
	# Remembered so the world can tell a column that was never drawn from one
	# that has nothing to draw - an all-air chunk also has a null mesh.
	mesh_built = want_mesh


## Park this node in the cache, or bring it back (world feel v1 Stage 4).
##
## Hidden and with its collider off, a cached chunk costs a hidden
## MeshInstance3D and a disabled shape - kilobytes of bookkeeping against the
## milliseconds of a worker the player was waiting on. It is NOT in
## World._chunks while parked, receives no edits directly, and comes back
## through the same replay point everything else does.
func set_parked(parked: bool) -> void:
	visible = not parked
	if _collider != null:
		_collider.disabled = parked
	# A parked chunk is not standable, and nothing must believe otherwise
	# between it leaving _chunks and coming back.
	collision_applied = not parked


func rebuild(world_solid: Callable) -> void:
	# build() returns null for a chunk with no visible faces. Assigning null
	# clears the mesh, which is exactly what we want.
	mesh = ChunkMesher.build(chunk, world_solid, _config, _world_seed)
	_apply_collision()
	chunk.dirty = false
	collision_applied = true
	# This is also the UPGRADE path for a collision-only chunk: it re-meshes
	# from the voxels, which the node already has, rather than sending the
	# column back through generation and the tree scan.
	mesh_built = true


## The collision shape is generated FROM the visible mesh, so the two can never
## disagree - you cannot end up standing on a face that is not drawn, or
## walking through one that is. A chunk with no faces gets no shape at all
## rather than an empty one, which is one less thing for the physics server to
## keep track of.
func _apply_collision() -> void:
	_collider.shape = mesh.create_trimesh_shape() if mesh != null else null
