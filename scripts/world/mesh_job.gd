class_name MeshJob
extends RefCounted

## One chunk's meshing, packaged so it can run on a worker thread.
##
## WHY THIS IS A SEPARATE OBJECT rather than a closure over World: everything a
## worker touches has to be reachable without going through the scene tree, and
## has to be stable for the whole life of the job. So the job captures exactly
## what it needs at submit time - the chunk, its six neighbours, the generator -
## and never calls back into World. If it did, it would be reading a dictionary
## the main thread is busy inserting into.
##
## What it deliberately does NOT do is touch the rendering server. build_arrays
## returns plain packed arrays; turning those into an ArrayMesh happens back on
## the main thread. That split is the whole reason meshing can be threaded at
## all - Godot's renderer is not safe to call from anywhere else.

var chunk: Chunk = null

## Face-neighbours only, keyed by chunk position. The mesher never asks about
## anything diagonal: it only ever looks one block along one axis from a block
## inside the chunk.
var neighbours := {}

## Pure and stateless once built, so several threads can read it at once. It is
## the fallback for neighbours that are not loaded, and it gives the same
## answer the real chunk will when it arrives - which is why the edge of the
## loaded region does not sprout a wall of faces.
var generator: TerrainGenerator = null

var block_size := 1.0

## Baked corner AO strength, 0 to 1. Captured at submit time with everything
## else the job needs, so a slider moving mid-load cannot change what a chunk
## already in flight comes back looking like.
var ao_strength := 0.0

## The result. Read by the main thread once the task reports completion.
var arrays: Array = []


func run() -> void:
	arrays = ChunkMesher.build_arrays(chunk, solid_at, block_size, ao_strength)


## Is there a solid block at this WORLD position? Called only for positions
## outside `chunk`.
func solid_at(wx: int, wy: int, wz: int) -> bool:
	var wpos := Vector3i(wx, wy, wz)
	var neighbour: Chunk = neighbours.get(Chunk.world_to_chunk(wpos))
	if neighbour != null:
		var l := Chunk.world_to_local(wpos)
		return Block.is_solid(neighbour.voxels[Chunk.index(l.x, l.y, l.z)])
	return generator.is_solid_at(wx, wy, wz)
