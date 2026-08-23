class_name ChunkNode
extends MeshInstance3D

## The visual half of a chunk. Chunk holds the data, ChunkNode holds the mesh.
##
## Keeping them apart matters for multiplayer: a dedicated server would want
## Chunk without ever building a mesh, and the mesher can be moved onto a
## worker thread later precisely because it only touches Chunk.

var chunk: Chunk

var _block_size := 1.0


func setup(p_chunk: Chunk, block_size: float) -> void:
	chunk = p_chunk
	_block_size = block_size
	var c := p_chunk.chunk_pos
	name = "Chunk%d_%d_%d" % [c.x, c.y, c.z]
	# The mesh is built in chunk-local coordinates, so the node position
	# supplies the world offset. That also means editing one block rebuilds one
	# small mesh, not a world-sized one.
	#
	# Note the scale factor rather than a scaled node: origin() is in BLOCKS and
	# the scene graph is in METRES, and that conversion happens here and in the
	# mesher and nowhere else.
	position = Vector3(p_chunk.origin()) * block_size


func rebuild(world_solid: Callable) -> void:
	# build() returns null for a chunk with no visible faces. Assigning null
	# clears the mesh, which is exactly what we want.
	mesh = ChunkMesher.build(chunk, world_solid, _block_size)
	chunk.dirty = false
