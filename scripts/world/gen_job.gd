class_name GenJob
extends RefCounted

## One chunk's VOXEL GENERATION, packaged so it can run on a worker thread.
##
## Sibling of MeshJob, and deliberately a separate object rather than a second
## mode of it. The two phases are ordered - you cannot mesh a chunk whose
## voxels do not exist yet - and giving each its own job type means the queue
## a chunk is sitting in says which phase it is in, with no flag to get wrong.
##
## WHY THIS IS THE BIGGEST WIN AVAILABLE. Meshing moved to worker threads in
## terrain v1 and generation did not, so generation became the whole of the
## main-thread cost: 3.81 ms per chunk, 2653 chunks, 10.1 seconds of a 22
## second load spent on the thread that also has to draw the window. View
## distance is quadratic in the voxel radius, so at radius 16 that figure is
## 16.9 s and the game is unplayable while the world arrives. Nothing else in
## terrain v2 can afford a larger radius until this moves.
##
## WHAT MAKES IT SAFE. generate_into() reads the coarse heightmap (finished and
## never written again), samples FastNoiseLite (already called from worker
## threads by MeshJob and FarFieldJob since v1), hashes coordinates through
## WorldHash (pure and static), and writes only into its OWN chunk. It touches
## no scene state and no rendering API, which is the same test MeshJob has to
## pass.
##
## WHAT IT COSTS, and this is the hazard v1's STATUS.md flagged: the chunk no
## longer exists in World._chunks at submit time, so an edit arriving in the
## window between submit and completion has no chunk to be written into. See
## World's edit-replay path, which is where that is handled rather than papered
## over.

var chunk: Chunk = null

## Pure and stateless once its heightmap is built, so every worker can read it
## at once. Same object every job holds, never copied.
var generator: TerrainGenerator = null

## How long the job actually took, in microseconds. Recorded by the worker
## rather than measured by the main thread, which can only see when it got
## round to collecting the result - a number that says more about the frame
## budget than about generation.
var elapsed_usec := 0


func run() -> void:
	var started := Time.get_ticks_usec()
	generator.generate_into(chunk)
	elapsed_usec = Time.get_ticks_usec() - started
