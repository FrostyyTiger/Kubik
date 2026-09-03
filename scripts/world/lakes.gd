class_name Lakes
extends RefCounted

## Finds the basins in the coarse heightmap and fills them with water.
##
## THIS IS WHY THE HEIGHTMAP IS GLOBAL. A basin is a depression with a rim all
## the way around it. You cannot see one by looking at a chunk, or at a
## kilometre of chunks either - you have to be able to ask "if water fell here,
## where would it run to, and does it ever reach the edge of the world". That
## question is about the whole map at once, and answering it is the single
## thing per-chunk generation can never do.
##
##
## THE ALGORITHM: PRIORITY FLOOD
##
## Start with every cell on the border of the map - water there runs off the
## edge, so its level is simply its own altitude. Put them all in a queue
## ordered by altitude, lowest first. Then repeatedly:
##
##   * take the LOWEST cell in the queue
##   * for each neighbour not yet reached, its water level is
##         max(its own altitude, the level of the cell we came from)
##     because water arriving from a cell at level L cannot sit lower than L
##   * put that neighbour in the queue at its new level
##
## Taking the lowest first is what makes it correct: when a cell is reached, it
## is reached over the LOWEST possible rim, which is exactly the spill point.
## Every cell whose water level ends up above its own altitude is under water,
## and every cell in one basin comes out at the same level - the height of the
## lip it would pour over.
##
## The queue is buckets rather than a heap. A binary heap over 562,500 cells is
## a few million comparisons in GDScript and takes seconds; priority flood only
## ever pops in non-decreasing order, so an array of buckets indexed by level
## with a cursor that never moves backwards does the same job in one pass.
##
##
## DETERMINISM
##
## Every loop here runs in a FIXED order - scan order for cells, a fixed
## neighbour order, and last-in-first-out within a bucket. Nothing iterates a
## Dictionary. Two machines must find the same lakes from the same seed or they
## are looking at different worlds, and lakes are large and obvious enough that
## the players would notice, which makes this one of the few determinism bugs
## that would actually get reported rather than silently ruining a session.

## Buckets per block of altitude. Finer means a more exact spill point; the
## error is at most one bucket, so 8 is about 6 cm of water level.
const BUCKETS_PER_BLOCK := 8.0

## How far above its own altitude a cell's water has to sit before we call it
## flooded rather than a rounding artefact, in blocks.
const FLOODED_EPSILON := 0.05

## Fixed neighbour order. Deterministic by construction, and never a Dictionary.
const NEIGHBOURS := [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]

## Water surface altitude per cell, in blocks. Equal to the terrain altitude
## where there is no water.
var water := PackedFloat32Array()

## Which lake each cell belongs to, or -1 for none. Index into `lakes`.
var lake_id := PackedInt32Array()

## Water level of the nearest lake, for cells near one. `shore_near` is 1 where
## `shore_level` means anything and 0 everywhere else.
##
## WHY THIS EXISTS. Lakes are capped at a couple of blocks deep so they stay in
## scale, and per-block detail roughness is up to three blocks. A shallow sheet
## of water over bumpy ground therefore intersects it constantly, and the first
## postcard of the new terrain came back with a shoreline made of a hundred
## disconnected tan islands. The fix is to damp the detail layer near the water
## line - see TerrainGenerator.detail_at() - and to do that a block column has
## to know what the water level near it is, which is a question about a
## NEIGHBOURHOOD and not about the cell itself.
##
## Built by scattering OUTWARD from the flooded cells rather than by scanning
## the map for them. That distinction is the whole reason this is affordable: a
## gather pass is 2.25 million cells times four neighbours whatever the world
## looks like, while a scatter is the number of flooded cells - 58,000 here -
## times the dilation area, and it gets cheaper as the world gets drier.
var shore_level := PackedFloat32Array()
var shore_near := PackedByteArray()

## One entry per surviving lake:
##   {"level": float, "cells": int, "area_m2": float}
var lakes: Array = []

var _cols := 0
var _elapsed_ms := 0


func elapsed_ms() -> int:
	return _elapsed_ms


func lake_count() -> int:
	return lakes.size()


## Find every basin, discard the puddles, and set a level for what is left.
func compute(heightmap: Heightmap, config: WorldgenConfig) -> void:
	var started := Time.get_ticks_msec()
	_cols = heightmap.cols
	var total := _cols * _cols

	water = PackedFloat32Array()
	water.resize(total)
	lake_id = PackedInt32Array()
	lake_id.resize(total)
	lakes = []

	_fill_to_spill_points(heightmap, config, total)
	_find_lakes(heightmap, config, total)
	_build_shore_field(config, total)

	_elapsed_ms = Time.get_ticks_msec() - started


## Dilate each lake's water level outward over the dry land around it.
##
## Deterministic by construction: a fixed scan over cells, a fixed square
## neighbourhood, and where two lakes reach the same cell the LOWER level wins.
## "Lower wins" rather than "nearer wins" because it needs no distances and
## because the lower of two water lines is the one a shore actually sits on.
func _build_shore_field(config: WorldgenConfig, total: int) -> void:
	shore_level = PackedFloat32Array()
	shore_near = PackedByteArray()
	var reach: int = config.shore_flat_cells
	if reach <= 0 or config.shore_flat_blocks <= 0.0:
		return

	shore_level.resize(total)
	shore_near.resize(total)

	for idx in total:
		var id := lake_id[idx]
		if id < 0:
			continue
		# THE LAKE'S LEVEL, NOT water[idx]. water[] holds the priority flood's
		# SPILL level - the height of the lip the basin would pour over - and
		# _find_lakes then caps the actual surface at floor + lake_max_depth,
		# which for a broad shallow basin is far below it. Reading the spill
		# here put the whole shore fade in the wrong altitude band, so the
		# detail layer was never damped anywhere near the real water line and
		# the shoreline stayed exactly as broken as before the fix.
		var level: float = lakes[id]["level"]
		var cx := idx % _cols
		var cz := idx / _cols
		var x0 := maxi(cx - reach, 0)
		var x1 := mini(cx + reach, _cols - 1)
		var z0 := maxi(cz - reach, 0)
		var z1 := mini(cz + reach, _cols - 1)
		for z in range(z0, z1 + 1):
			var row := z * _cols
			for x in range(x0, x1 + 1):
				var at := row + x
				if shore_near[at] == 0 or level < shore_level[at]:
					shore_level[at] = level
					shore_near[at] = 1


## Water level near this cell, or NAN if there is none. Cell index, not blocks.
func shore_level_at_cell(idx: int) -> float:
	if shore_near.is_empty() or idx < 0 or idx >= shore_near.size():
		return NAN
	if shore_near[idx] == 0:
		return NAN
	return shore_level[idx]


# --- Priority flood ---------------------------------------------------------

func _fill_to_spill_points(heightmap: Heightmap, config: WorldgenConfig, total: int) -> void:
	var elev := heightmap.cells
	var visited := PackedByteArray()
	visited.resize(total)

	var bucket_count := int(config.max_altitude * BUCKETS_PER_BLOCK) + 4
	# Plain Arrays, not PackedInt32Arrays. Packed arrays are copy-on-write, so
	# pulling one out of a container to push onto it can quietly operate on a
	# copy - a bug that shows up as a queue that never empties.
	var buckets: Array = []
	buckets.resize(bucket_count)
	for i in bucket_count:
		buckets[i] = []

	# Seed: every border cell drains off the edge of the world, so its water
	# level is its own altitude and nothing can raise it.
	for i in _cols:
		_seed_border(i, 0, elev, visited, buckets, bucket_count)
		_seed_border(i, _cols - 1, elev, visited, buckets, bucket_count)
	for j in range(1, _cols - 1):
		_seed_border(0, j, elev, visited, buckets, bucket_count)
		_seed_border(_cols - 1, j, elev, visited, buckets, bucket_count)

	# The cursor only ever moves forward. That is the property that lets
	# buckets stand in for a priority queue at all.
	var cursor := 0
	while cursor < bucket_count:
		var bucket: Array = buckets[cursor]
		if bucket.is_empty():
			cursor += 1
			continue

		var idx: int = bucket.pop_back()
		var level := water[idx]
		var cx := idx % _cols
		var cz := idx / _cols

		for offset in NEIGHBOURS:
			var nx: int = cx + offset.x
			var nz: int = cz + offset.y
			if nx < 0 or nz < 0 or nx >= _cols or nz >= _cols:
				continue
			var nidx := nx + nz * _cols
			if visited[nidx] != 0:
				continue
			visited[nidx] = 1
			# Water arriving from a cell at `level` cannot come to rest below
			# it. This one line is the whole of the flooding.
			var n_level := maxf(elev[nidx], level)
			water[nidx] = n_level
			var b := clampi(int(n_level * BUCKETS_PER_BLOCK), cursor, bucket_count - 1)
			buckets[b].push_back(nidx)


func _seed_border(x: int, z: int, elev: PackedFloat32Array, visited: PackedByteArray,
		buckets: Array, bucket_count: int) -> void:
	var idx := x + z * _cols
	if visited[idx] != 0:
		return
	visited[idx] = 1
	water[idx] = elev[idx]
	buckets[clampi(int(elev[idx] * BUCKETS_PER_BLOCK), 0, bucket_count - 1)].push_back(idx)


# --- Connected components ---------------------------------------------------

## Group flooded cells into lakes, throw away the puddles, and give each
## survivor a level.
func _find_lakes(heightmap: Heightmap, config: WorldgenConfig, total: int) -> void:
	var elev := heightmap.cells
	for i in total:
		lake_id[i] = -1

	# -2 marks "flooded, but part of a basin we rejected", so a discarded
	# puddle is never rescanned.
	var cell_area := float(config.coarse_step * config.coarse_step) \
		* config.block_size * config.block_size

	for start in total:
		if lake_id[start] != -1:
			continue
		if water[start] - elev[start] <= FLOODED_EPSILON:
			continue

		# Flood fill this basin. An explicit stack rather than recursion: a
		# lake can be tens of thousands of cells and GDScript has no tail
		# calls.
		var members: Array[int] = []
		var stack: Array[int] = [start]
		lake_id[start] = -2
		var spill := water[start]
		var floor_altitude := elev[start]

		while not stack.is_empty():
			var idx: int = stack.pop_back()
			members.append(idx)
			spill = maxf(spill, water[idx])
			floor_altitude = minf(floor_altitude, elev[idx])
			var cx := idx % _cols
			var cz := idx / _cols
			for offset in NEIGHBOURS:
				var nx: int = cx + offset.x
				var nz: int = cz + offset.y
				if nx < 0 or nz < 0 or nx >= _cols or nz >= _cols:
					continue
				var nidx := nx + nz * _cols
				if lake_id[nidx] != -1:
					continue
				if water[nidx] - elev[nidx] <= FLOODED_EPSILON:
					continue
				lake_id[nidx] = -2
				stack.append(nidx)

		if members.size() < config.lake_min_cells:
			continue  # a puddle; leave the cells marked -2 and move on

		# Sit the surface just below the lip - at exactly the spill point the
		# water reads as brimming over the edge from any angle looking down at
		# it - and no deeper than lake_max_depth above the basin floor. See the
		# note on that setting for why the cap exists at all.
		var level := minf(
			spill - config.lake_level_offset,
			floor_altitude + config.lake_max_depth)
		level = maxf(level, floor_altitude + 0.2)

		# Capping the level takes the shallow margins of the basin back out of
		# the water, so membership has to be recomputed against it. A basin can
		# come apart into several pools this way; they share a level and sit in
		# the same valley, which is exactly what that looks like in the world.
		var wet: Array[int] = []
		var max_depth := 0.0
		var total_depth := 0.0
		for idx in members:
			var d := level - elev[idx]
			if d <= FLOODED_EPSILON:
				continue
			wet.append(idx)
			max_depth = maxf(max_depth, d)
			total_depth += d

		if wet.size() < config.lake_min_cells:
			continue

		# A FILM IS NOT A LAKE. Where the spill point sits barely above the
		# basin floor the level is forced to floor + 0.2 blocks - ten
		# centimetres - and terrain v2's terracing made a great many basins
		# like that, because a perfectly flat shelf with any rim at all holds
		# water at zero depth. Seed 42 produced 185 lakes of which 138 were
		# films. They are wet ground, not water, and drawing them as lake
		# surfaces puts flat blue sheets across the flats.
		if max_depth < config.lake_min_depth:
			continue

		var id := lakes.size()
		for idx in wet:
			lake_id[idx] = id
		lakes.append({
			"level": level,
			"cells": wet.size(),
			"area_m2": float(wet.size()) * cell_area,
			"max_depth": max_depth,
			"mean_depth": total_depth / float(wet.size()),
		})


# --- Water surface ----------------------------------------------------------

## One mesh for every lake in the world.
##
## Quads are merged along each row first: a lake 100 cells across becomes 100
## quads instead of 10,000, for nothing but a while loop. Merging in two
## dimensions as the chunk mesher does would do better still, and lakes are
## flat and few enough that it has not been worth it.
## Which of the three rings a water cell is in: 0 rim, 1 shallows, 2 body.
##
## Chebyshev distance to the nearest cell that is NOT this lake, capped at the
## shelf width - a full distance transform for three buckets would cost more
## code than the buckets are worth, and a lake is a few thousand cells.
func _ring_at(i: int, j: int, id: int, rim_cells: int, shelf_cells: int) -> int:
	for r in range(1, shelf_cells + 1):
		for dj in range(-r, r + 1):
			for di in range(-r, r + 1):
				if maxi(absi(di), absi(dj)) != r:
					continue
				var ci := i + di
				var cj := j + dj
				if ci < 0 or cj < 0 or ci >= _cols or cj >= _cols:
					return 0 if r <= rim_cells else 1
				if lake_id[ci + cj * _cols] != id:
					return 0 if r <= rim_cells else 1
	return 2


func build_water_arrays(heightmap: Heightmap, config: WorldgenConfig) -> Array:
	if lakes.is_empty():
		return []

	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()

	var bs: float = config.block_size
	var step: int = config.coarse_step
	# THE COLOUR IS THIS FILE'S AGAIN, and it is the bible's (light v1 Stage 0).
	#
	# Until light v1 the vertex colour was a DARKENING FACTOR - a grey - and
	# the colour itself arrived as the global `kubik_water`, published per hour
	# by SkyCycle so the mesh never had to be rebuilt when the sun moved. Under
	# real light that global is gone with the rest of the poster's publish
	# path, and the hour tints the water by LIGHTING it rather than by
	# repainting it (pillar 2: mood "never from repainting a thing"). A factor
	# with no colour behind it draws a white sheet, which is what the first
	# Stage 0 postcard came back with.
	#
	# So the rings carry the bible's two lake hexes directly
	# (`10-color-and-light.md`: Lake #265f6e / #42c1c9). The mapping is the one
	# the bible implies: the rim is the SHALLOWS and takes the light teal, the
	# body is DEEP and takes the dark one, the shelf sits between them. That is
	# the same fact Stage 5 will compute per pixel from the depth buffer, and
	# these three rings are what it replaces.
	const WATER_SHALLOW := "#42c1c9"
	const WATER_DEEP := "#265f6e"
	## Rim, shelf, body: how far each ring sits from shallow toward deep.
	const RING_DEPTH := [0.0, 0.55, 1.0]
	const WATER_ALPHA := 0.92
	var water_shallow := Color.html(WATER_SHALLOW).srgb_to_linear()
	var water_deep := Color.html(WATER_DEEP).srgb_to_linear()
	# The plan's rim and shelf are 2 and 8 BLOCKS; the lake grid is in cells of
	# `step` blocks, so they are rounded to whole cells here and the status doc
	# records what they landed on.
	var rim_cells := maxi(1, int(round(2.0 / float(step))))
	var shelf_cells := maxi(rim_cells + 1, int(round(8.0 / float(step))))

	for j in _cols:
		var i := 0
		while i < _cols:
			var id := lake_id[i + j * _cols]
			if id < 0:
				i += 1
				continue
			var ring := _ring_at(i, j, id, rim_cells, shelf_cells)
			# The run also breaks where the RING changes, so every quad is one
			# flat colour.
			var run := 1
			while i + run < _cols and lake_id[i + run + j * _cols] == id \
					and _ring_at(i + run, j, id, rim_cells, shelf_cells) == ring:
				run += 1

			var level: float = lakes[id]["level"]
			var x0 := float(heightmap.cell_to_block(i)) * bs
			var x1 := float(heightmap.cell_to_block(i + run)) * bs
			var z0 := float(heightmap.cell_to_block(j)) * bs
			var z1 := z0 + float(step) * bs
			var y := level * bs

			# Same corner order as a +Y face in the chunk mesher, so the water
			# is wound and culled exactly like the ground it sits in.
			var first := verts.size()
			for p in [
				Vector3(x0, y, z0), Vector3(x1, y, z0),
				Vector3(x1, y, z1), Vector3(x0, y, z1),
			]:
				verts.push_back(p)
				normals.push_back(Vector3.UP)
				var c := water_shallow.lerp(water_deep, RING_DEPTH[ring])
				c.a = WATER_ALPHA
				colors.push_back(Look.to_wire(c))
			indices.push_back(first)
			indices.push_back(first + 1)
			indices.push_back(first + 2)
			indices.push_back(first)
			indices.push_back(first + 2)
			indices.push_back(first + 3)
			i += run

	if verts.is_empty():
		return []

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	return arrays


## Translucent, drawn from both sides, and flat - the poster water in Look.
##
## Terrain v1 gave this roughness 0.15, and a specular highlight sliding across
## a lake as you walk is exactly the thing look v1's rule 2 forbids. A poster
## lake is a flat blue with a hard shore.
static func make_material() -> Material:
	return Look.water_material()
