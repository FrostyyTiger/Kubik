class_name ChunkNode
extends MeshInstance3D

## The visual half of a chunk. Chunk holds the data, ChunkNode holds the mesh.
##
## Keeping them apart matters for multiplayer: a dedicated server would want
## Chunk without ever building a mesh, and the mesher can be moved onto a
## worker thread later precisely because it only touches Chunk.

var chunk: Chunk


func setup(p_chunk: Chunk) -> void:
	chunk = p_chunk
	var c := p_chunk.chunk_pos
	name = "Chunk%d_%d_%d" % [c.x, c.y, c.z]
	# The mesh is built in chunk-local coordinates (0..16), so the node
	# position supplies the world offset. That also means editing one block
	# rebuilds one small mesh, not a world-sized one.
	position = Vector3(p_chunk.origin())


func rebuild(world_solid: Callable) -> void:
	# build() returns null for a chunk with no visible faces. Assigning null
	# clears the mesh, which is exactly what we want.
	mesh = ChunkMesher.build(chunk, world_solid)
	chunk.dirty = false
