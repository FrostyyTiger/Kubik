class_name ColumnJob
extends RefCounted

## One COLUMN - every chunk of it - built in a single worker task: voxels,
## trees, meshes and collision faces.
##
## WHY THE COLUMN AND NOT THE CHUNK (world feel v1 Stage 2). Everything the
## world already reasons about is a column: `wanted`, freeing, flora, the cache.
## Only the jobs were chunks, and that cost two things.
##
## THE TREE SCAN, WHICH WAS THE BIG ONE AND IS NOW THE ONLY ONE.
## TreePlacement's candidate scan walks `(16 + 2 * max_reach)^2 / cell^2` cells
## and calls decide() for each, and the six or seven chunks of a column each
## did it again - the same cells, the same answers, six or seven times over.
## Doing it once per column is what made bigger trees affordable.
##
## TREES V3 STAGE 7 DELETED THE OTHER HALF OF IT. The scan used to stamp
## `Block.LEAVES` and `Block.TRUNK` as it went, and that stamping was HALF THE
## WHOLE COLUMN JOB - measured at 125.4 ms against 5.9 ms of voxel generation
## in real forest, which is 95.5% of generation and 51.7% of everything. It is
## gone: `TreeField` draws every tree in the game from a model library, and
## what this scan returns now is `canopy_cover` alone.
##
## THE SKY RESERVE WENT WITH IT. World used to queue a column from its lowest
## possible ground to its highest possible TREE TOP, because a crown must not
## be cut off by a chunk nobody built - twenty-one metres of empty chunks per
## column, reserved for canopies that no longer land in the volume. Nothing
## writes above the terrain any more, so the column ends at the terrain.
##
## What that reserve cost was never the generation - Chunk.new() is already all
## air and the ceiling below skipped it - but every one of those chunks was an
## ENTRY in cy_range, a Chunk allocated, and a column World queued. See
## `worldgen_config.gd`'s note where the reserve used to be.
##
## WHAT MAKES IT SAFE is what made the old GenJob and MeshJob safe: everything is
## captured at submit time, the job writes only into ITS OWN chunks, and it
## never calls back into World.
##
## THE HAZARD is the same and now spans a column: none of these chunks is in
## World._chunks until the job completes, so an edit arriving in the window has
## nowhere to go. World records it and replays it at collection, and any chunk
## an edit landed in is remeshed rather than using this job's arrays.

var chunk_x := 0
var chunk_z := 0

## The chunk y indices this job MAY build - World's maximum extent for the
## column. What it actually builds is `built`, which stops at the ceiling.
var cy_range: Array = []

var generator: TerrainGenerator = null
var config: WorldgenConfig = null
var world_seed := 0

## chunk position -> Chunk, for the neighbours of this column that already
## exist. Captured at submit time; the generator is the fallback for the rest.
var neighbours := {}

## The results. chunk y index -> {"chunk": Chunk, "arrays": Array,
## "faces": PackedVector3Array}. Only the chunks that were actually built.
var built := {}

## How much of this column's sky its own trees cover, 0 to 1. Decided by the
## tree scan and used to shade the ground under them.
var canopy_cover := 0.0

## False for a column the host is building only so a remote peer's body has
## ground under it (world feel v1 Stage 10). The arrays are built either way -
## the collision faces are derived from them - but World does not upload a mesh
## for one. The job itself does not branch on this; it carries it so the main
## thread knows what it asked for by the time the column lands.
var mesh := true

## The surface zone at this column's centre, worked out once here and used for
## the chunk colliders' friction (world feel v1 Stage 12). One generator query
## per column rather than one per chunk; see ChunkNode.setup().
var zone := TerrainGenerator.ZONE_MEADOW

var gen_usec := 0
var tree_usec := 0
var mesh_usec := 0

var _chunks := {}


func run() -> void:
	var t0 := Time.get_ticks_usec()
	# THE SKY IS NOT GENERATED, ONLY RESERVED.
	#
	# cy_range runs from below the ground to above the tallest tree the world
	# could grow, because a crown must not be cut off by a chunk nobody built.
	# But a chunk whose BOTTOM is above the highest ground in this column
	# contains no terrain at all - only whatever a tree writes into it later -
	# so running the generator over its 4,096 voxels writes air 4,096 times.
	#
	# It has to EXIST, because the tree writer needs somewhere to put a crown.
	# It does not have to be generated. Chunk.new() is already all air.
	#
	# This is what makes a generous reserve free, and world feel v1 Stage 6 is
	# where that stopped being theoretical: old growth raised max_tree_height()
	# by half, which lengthened cy_range, which added a full generation pass
	# per column per extra chunk - ten of twelve 48 m jumps stopped settling
	# inside a minute.
	var bx_mid := chunk_x * Chunk.SIZE + Chunk.SIZE / 2
	var bz_mid := chunk_z * Chunk.SIZE + Chunk.SIZE / 2
	zone = generator.surface_zone_at(bx_mid, bz_mid,
		generator.surface_at(float(bx_mid), float(bz_mid)))

	var span := generator.column_surface_range(chunk_x, chunk_z)
	var sky_from := int(floor(span.y)) + 1
	for cy in cy_range:
		var chunk := Chunk.new(Vector3i(chunk_x, cy, chunk_z))
		if cy * Chunk.SIZE <= sky_from:
			generator.generate_ground_into(chunk)
		else:
			chunk.has_air = true
			chunk.has_solid = false
		_chunks[cy] = chunk
	var t1 := Time.get_ticks_usec()
	gen_usec = t1 - t0

	# ONCE FOR THE WHOLE COLUMN. See the note at the top.
	#
	# TREES V3 STAGE 7: THE SCAN SURVIVES AND THE WRITER IS GONE. There is no
	# ColumnWriter and no tree block to bind it to - `TreeField` draws every
	# tree in the game - but the column still has to know how much of its sky
	# its own trees cover, and that has always come from this scan rather than
	# from the voxels.
	canopy_cover = TreePlacement.cover_column(generator, chunk_x, chunk_z)
	var t2 := Time.get_ticks_usec()
	tree_usec = t2 - t1

	# THE CEILING. The highest chunk that actually contains a solid block;
	# everything above it is air and is not built at all.
	var ceiling := -1
	for cy in cy_range:
		if (_chunks[cy] as Chunk).has_solid:
			ceiling = maxi(ceiling, cy)

	for cy in cy_range:
		if cy > ceiling:
			continue
		var chunk: Chunk = _chunks[cy]
		var arrays := ChunkMesher.build_arrays(
			chunk, _solid_at, config, world_seed, canopy_cover)
		built[cy] = {
			"chunk": chunk,
			"arrays": arrays,
			"faces": ChunkMesher.faces_from(arrays),
		}
	mesh_usec = Time.get_ticks_usec() - t2


## Is there a solid block at this WORLD position? Called only for positions
## outside the chunk being meshed - which for a column job may be another chunk
## of the SAME column, and those are in `_chunks` and already stamped.
func _solid_at(wx: int, wy: int, wz: int) -> bool:
	var wpos := Vector3i(wx, wy, wz)
	var cpos := Chunk.world_to_chunk(wpos)
	var chunk: Chunk = null
	if cpos.x == chunk_x and cpos.z == chunk_z:
		chunk = _chunks.get(cpos.y)
	else:
		chunk = neighbours.get(cpos)
	if chunk != null:
		var l := Chunk.world_to_local(wpos)
		return Block.is_solid(chunk.voxels[Chunk.index(l.x, l.y, l.z)])
	return generator.is_solid_at(wx, wy, wz)
