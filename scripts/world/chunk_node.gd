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

var _block_size := 1.0
var _config: WorldgenConfig = null
var _world_seed := 0
var _collider: CollisionShape3D = null


func setup(p_chunk: Chunk, config: WorldgenConfig, world_seed: int) -> void:
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
## MeshJob hands back arrays rather than a mesh.
func apply_arrays(arrays: Array) -> void:
	mesh = ChunkMesher.arrays_to_mesh(arrays)
	_apply_collision()
	chunk.dirty = false
	collision_applied = true


func rebuild(world_solid: Callable) -> void:
	# build() returns null for a chunk with no visible faces. Assigning null
	# clears the mesh, which is exactly what we want.
	mesh = ChunkMesher.build(chunk, world_solid, _config, _world_seed)
	_apply_collision()
	chunk.dirty = false
	collision_applied = true


## The collision shape is generated FROM the visible mesh, so the two can never
## disagree - you cannot end up standing on a face that is not drawn, or
## walking through one that is. A chunk with no faces gets no shape at all
## rather than an empty one, which is one less thing for the physics server to
## keep track of.
func _apply_collision() -> void:
	_collider.shape = mesh.create_trimesh_shape() if mesh != null else null
