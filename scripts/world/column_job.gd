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

## What the border marshal cost, kept out of `mesh_usec` so the two can be read
## against each other (mesher v1 Q4). The strips below are built once per
## COLUMN; `borders_for()` is per chunk and costs a handful of dictionary
## writes plus a reference to each neighbour's bytes.
var border_usec := 0

## False for the bench, which generates a disc of columns and then meshes them
## itself, twice, timing each. Nothing in the game sets it.
var build_meshes := true

var _chunks := {}

## The generator's answer for the blocks just outside this column, reduced to
## ONE INTEGER PER BLOCK COLUMN (mesher v1 Q4).
##
## WHY AN INTEGER AND NOT THE SURFACE ALTITUDE. `TerrainGenerator.is_solid_at`
## is `by < 0 or float(by) <= surface_at(bx, bz)`, and `by` is an integer, so
## that expression is EXACTLY `by <= floor(surface)` - and floor(surface) is an
## integer that no compiler can round differently. Handing the float across
## would have put a float32 truncation between the two meshers on a comparison
## whose two sides are within a ULP of each other several dozen times over a
## spawn disc; handing the integer removes the question instead of measuring it.
##
## The strips are built for the faces that need them and no others: `top_col`
## is the column's own 16 x 16 footprint and answers both the +Y and the -Y
## face, and each side row of 16 is built only where the neighbouring column
## has no chunk at some level this job is meshing.
var _strips := {}

## This job's own C++ mesher, or null. One per job - see
## `ChunkMesher.new_cpp_mesher()` for why it is not shared.
var _cpp: Object = null

## The highest chunk of this column that contains a solid block; everything
## above it is air and is not built at all. Set by run(), kept so the bench can
## walk the same set of chunks the streaming path meshes.
var ceiling := -1


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

	# THE CANOPY SCAN LEFT THE HOT PATH IN LIGHT V1 STAGE 3.
	#
	# It ran `TreePlacement.cover_column()` once per column so the mesher could
	# darken the ground under a wood, because no tree cast a shadow at any
	# distance. LOD0 trees cast real shadows now (Q10) and `_under_canopy` is
	# gone, so this was a full candidate walk per column feeding a value nothing
	# reads. `cover_column()` itself stays - the worldgen probe measures grove
	# density with it and the self-test proves it deterministic - and only the
	# per-column call on the streaming path goes. `tree_usec` therefore now
	# measures nothing and stays at zero, which the load line prints.
	var t2 := Time.get_ticks_usec()
	tree_usec = t2 - t1

	# THE CEILING. The highest chunk that actually contains a solid block;
	# everything above it is air and is not built at all.
	ceiling = -1
	for cy in cy_range:
		if (_chunks[cy] as Chunk).has_solid:
			ceiling = maxi(ceiling, cy)

	# ONE C++ MESHER PER JOB, or null when the twin is running - and the strips
	# are built only for a job that is going to hand them over, so
	# `--mesher gdscript` costs exactly what it cost before this stage and the
	# A/B is honest.
	if build_meshes:
		_cpp = ChunkMesher.new_cpp_mesher(config)
	if _cpp != null or not build_meshes:
		build_strips()
	if not build_meshes:
		mesh_usec = Time.get_ticks_usec() - t2 - border_usec
		return

	for cy in cy_range:
		if cy > ceiling:
			continue
		var chunk: Chunk = _chunks[cy]
		var arrays: Array
		if _cpp != null:
			var t_b := Time.get_ticks_usec()
			var borders := borders_for(cy)
			border_usec += Time.get_ticks_usec() - t_b
			arrays = ChunkMesher.build_arrays_from(
				chunk, borders, config, world_seed, _cpp, _solid_at)
		else:
			arrays = ChunkMesher.build_arrays_gd(
				chunk, _solid_at, config, world_seed)
		built[cy] = {
			"chunk": chunk,
			"arrays": arrays,
			"faces": ChunkMesher.faces_from(arrays),
		}
	mesh_usec = Time.get_ticks_usec() - t2 - border_usec


## The strips of `_strips`, once per column, for the faces that need them.
##
## ONCE PER COLUMN AND NOT ONCE PER CHUNK, which is the whole reason they are
## strips rather than a plane of solidity bytes: a column of six chunks asks the
## generator about the same 16 x 16 footprint six times over, and the answer
## does not depend on which chunk is asking.
func build_strips() -> void:
	var t := Time.get_ticks_usec()
	_strips.clear()
	if cy_range.is_empty():
		border_usec = Time.get_ticks_usec() - t
		return

	var bx0 := chunk_x * Chunk.SIZE
	var bz0 := chunk_z * Chunk.SIZE

	# THE COLUMN'S OWN FOOTPRINT, always: the lowest chunk this job meshes has
	# nothing below it in `_chunks`, so its -Y face always needs the generator.
	var col := PackedInt32Array()
	col.resize(Chunk.SIZE_SQ)
	for lz in Chunk.SIZE:
		for lx in Chunk.SIZE:
			col[lx + lz * Chunk.SIZE] = int(floor(
				generator.surface_at(float(bx0 + lx), float(bz0 + lz))))
	_strips["top_col"] = col

	# THE FOUR SIDES, only where a neighbouring column is missing a chunk at
	# some level this job meshes. In the middle of the loaded disc that is none
	# of them and this loop costs four dictionary lookups per level.
	var sides := [
		["top_px", Vector2i(1, 0)], ["top_nx", Vector2i(-1, 0)],
		["top_pz", Vector2i(0, 1)], ["top_nz", Vector2i(0, -1)],
	]
	for side in sides:
		var key: String = side[0]
		var d: Vector2i = side[1]
		var wanted := false
		for cy in cy_range:
			if cy > ceiling:
				continue
			if not neighbours.has(Vector3i(chunk_x + d.x, cy, chunk_z + d.y)):
				wanted = true
				break
		if not wanted:
			continue
		var row := PackedInt32Array()
		row.resize(Chunk.SIZE)
		for i in Chunk.SIZE:
			var bx := bx0 + (Chunk.SIZE if d.x > 0 else (-1 if d.x < 0 else i))
			var bz := bz0 + (Chunk.SIZE if d.y > 0 else (-1 if d.y < 0 else i))
			row[i] = int(floor(generator.surface_at(float(bx), float(bz))))
		_strips[key] = row

	border_usec = Time.get_ticks_usec() - t


## One chunk's borders, in the form `KubikChunkMesher.build()` takes.
##
## A neighbour chunk crosses as its own 4,096 bytes and that costs a REFERENCE:
## a PackedByteArray is copy-on-write and neither side writes to it. Where a
## neighbour chunk does not exist the generator's strip answers instead, exactly
## as `_solid_at` falls through to `generator.is_solid_at`.
func borders_for(cy: int) -> Dictionary:
	var chunk: Chunk = _chunks[cy]
	# AO ON IS THE PHOTOGRAPH PATH AND PAYS FOR ITSELF (Q5). Corner AO reaches
	# the eight blocks around an air cell, which at a chunk edge include the
	# DIAGONAL neighbours a six-face border cannot answer, so the whole 18^3
	# shell is built through the Callable. `ao_strength` is 0 by default and the
	# game never takes this path.
	if config.ao_strength > 0.0:
		return ChunkMesher.borders_from_callable(chunk, _solid_at)

	var out := {
		"voxels": chunk.voxels,
		"origin_y": chunk.origin().y,
		"has_solid": chunk.has_solid,
		"has_air": chunk.has_air,
	}
	var above: Chunk = _chunks.get(cy + 1)
	if above != null:
		out["n_py"] = above.voxels
	else:
		out["top_col"] = _strips["top_col"]
	var below: Chunk = _chunks.get(cy - 1)
	if below != null:
		out["n_ny"] = below.voxels
	else:
		out["top_col"] = _strips["top_col"]

	var sides := [
		["n_px", "top_px", Vector2i(1, 0)], ["n_nx", "top_nx", Vector2i(-1, 0)],
		["n_pz", "top_pz", Vector2i(0, 1)], ["n_nz", "top_nz", Vector2i(0, -1)],
	]
	for side in sides:
		var d: Vector2i = side[2]
		var n: Chunk = neighbours.get(Vector3i(chunk_x + d.x, cy, chunk_z + d.y))
		if n != null:
			out[side[0]] = n.voxels
		else:
			out[side[1]] = _strips[side[1]]
	return out


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


## The chunks this job generated, by chunk y index. For the bench, which
## generates a whole spawn disc once and then meshes it twice.
func chunks() -> Dictionary:
	return _chunks


## This job's neighbour lookup, as a Callable. The twin takes one of these and
## the bench has to drive the twin with the SAME answers the C++ gets, or it is
## timing two different meshers on two different worlds.
func solid_callable() -> Callable:
	return _solid_at
