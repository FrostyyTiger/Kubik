class_name CreatureNav
extends RefCounted

## A path across a territory, over the grid the world already has.
##
## NOT A NAVMESH, AND THAT IS THE WHOLE POINT (DESIGN.md's tool table).
## `NavigationServer3D` wants navmeshes re-baked per chunk on voxel terrain,
## which is a streaming problem the size of the streaming problem this project
## already has. The coarse heightmap is ALREADY the 2 m grid the lakes and the
## zones live on: a path over it is deterministic, cheap, and defined for
## ground that has not streamed in yet - which matters, because the host
## simulates creatures over terrain it may only ever have as numbers.
##
## ONE GRID PER PACK TERRITORY, NOT ONE PER WORLD. A 3 km world is 1500 cells
## on a side and 2.25 million points; a wolf territory is 151 on a side and
## 23 thousand, which builds in milliseconds and is thrown away when the pack
## is. Design decision 6 gave every creature an address, and this is the first
## thing that address buys.
##
## TERRAIN USE IS ONE WEIGHT TABLE (DESIGN.md rule 4). The ibex, when it
## arrives, is this same file reading a different row of `Species`: uphill
## cheap where the wolf's is dear, and it will flee up a slope because up a
## slope is where its costs are low. Nothing about that is a special case.

## The furthest a blocked endpoint is nudged, in cells, looking for open
## ground. Eight cells is 16 m: enough to get a den off a boulder-steep cell,
## short enough that a path never quietly starts somewhere else entirely.
const ENDPOINT_SEARCH_CELLS := 8

## The altitude difference, in metres, at which the rise term reaches full
## strength. See `_weight_for`.
const RISE_REFERENCE_M := 40.0

var species := Species.WOLF

## Cell coordinates of the territory, in HEIGHTMAP cell space - so a cell here
## is a cell there and no coordinate system has to be converted twice.
var region := Rect2i()

## How many cells were solid, for the status doc and the F10 readout.
var solid_cells := 0
var total_cells := 0
var build_ms := 0

var _grid := AStarGrid2D.new()
var _world: World = null
var _gen: TerrainGenerator = null
var _step_m := 2.0


## The grid for one pack, centred on its home.
##
## `centre_m` is the den. `_ref_alt` below is the den's altitude, and it is the
## reference the rise term is measured from - which is the honest thing to
## measure from, because a territory IS a thing centred on a home.
static func build(world: World, p_species: int, centre_m: Vector3) -> CreatureNav:
	var nav := CreatureNav.new()
	nav._build(world, p_species, centre_m)
	return nav


var _ref_alt := 0.0


func _build(world: World, p_species: int, centre_m: Vector3) -> void:
	var started := Time.get_ticks_msec()
	_world = world
	_gen = world.generator
	species = Species.valid(p_species)
	var cfg := world.config
	var hm: Heightmap = _gen.heightmap
	_step_m = float(hm.step) * cfg.block_size
	_ref_alt = world.surface_height_m(
		int(floor(centre_m.x / cfg.block_size)),
		int(floor(centre_m.z / cfg.block_size)))

	# THE SQUARE IS 2 * territory_m ON A SIDE, so a creature at the far edge of
	# its territory can still path to the far edge on the other side without
	# the grid running out underneath it.
	var half := int(ceil(Species.territory_m(species) / _step_m))
	# THE RAW CELL, NOT `_cell_of`. That one clamps into `region`, and `region`
	# is what this line is on its way to computing - so using it here gave
	# every grid a degenerate rectangle clamped against Rect2i(0, 0, 0, 0), a
	# territory 75 cells wide instead of 151, and paths of exactly one
	# waypoint that still passed every assertion about not standing in rock.
	var centre := _raw_cell_of(centre_m)
	var lo_x := maxi(centre.x - half, 0)
	var lo_z := maxi(centre.y - half, 0)
	var hi_x := mini(centre.x + half, hm.cols - 1)
	var hi_z := mini(centre.y + half, hm.cols - 1)
	region = Rect2i(lo_x, lo_z, hi_x - lo_x + 1, hi_z - lo_z + 1)

	_grid.region = region
	# CELL SIZE AND OFFSET IN METRES, so `get_point_path` hands back world XZ
	# and nothing has to convert grid space twice. offset is where heightmap
	# cell 0 actually is.
	_grid.cell_size = Vector2(_step_m, _step_m)
	_grid.offset = Vector2(
		float(hm.min_block) * cfg.block_size, float(hm.min_block) * cfg.block_size)
	# ONLY_IF_NO_OBSTACLES: the strict diagonal. An animal may not cut the
	# corner between two solid cells, which is exactly the move that sends a
	# wolf clipping through the nose of a ridge.
	_grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	_grid.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	_grid.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	_grid.update()

	var costs := Species.slope_cost(species)
	var cliff := float(costs["cliff_deg"])
	var border := Species.territory_m(species)
	total_cells = region.size.x * region.size.y
	solid_cells = 0
	for j in range(region.position.y, region.end.y):
		for i in range(region.position.x, region.end.x):
			var bx := float(hm.cell_to_block(i))
			var bz := float(hm.cell_to_block(j))
			var here := Vector2(bx * cfg.block_size, bz * cfg.block_size)
			# THE TERRITORY IS A CIRCLE AND THE GRID IS A SQUARE, so the
			# corners are masked out. Without this the two disagree by up to
			# 41% of the radius, and the disagreement is not cosmetic: a
			# patrolling wolf pathing round a cliff would leave the CIRCLE the
			# leash is measured against while still inside the SQUARE it is
			# pathing in, journal a leash_turn it had no reason to, and go
			# home. That is what the first run of `pack-flank` was doing while
			# it drifted from 47 m to 151 m out.
			#
			# With the mask, no path a creature can follow ever leaves its
			# territory, and the leash means exactly one thing: the thing it is
			# chasing went outside.
			if here.distance_to(Vector2(centre_m.x, centre_m.z)) > border:
				_grid.set_point_solid(Vector2i(i, j), true)
				solid_cells += 1
				continue
			var slope := hm.slope_deg_at(bx, bz)
			if slope > cliff or _is_underwater(bx, bz):
				_grid.set_point_solid(Vector2i(i, j), true)
				solid_cells += 1
				continue
			_grid.set_point_weight_scale(Vector2i(i, j),
				_weight_for(slope, hm.height_at(bx, bz) * cfg.block_size, costs, cliff))
	build_ms = Time.get_ticks_msec() - started


## What one cell costs this species to stand in.
##
## A PER-POINT WEIGHT CANNOT EXPRESS A PER-EDGE ASYMMETRY, and that is the one
## place this file argues with its own plan. `AStarGrid2D` weights a POINT, not
## the move into it, so "uphill is dearer than downhill" - which is a fact
## about a direction of travel - has no direct expression here. Rebuilding a
## directed graph to get it would mean giving up the grid, which is the thing
## that makes this cheap enough to have per pack.
##
## So the table's two numbers are spent on two things a point CAN know:
##
##   STEEPNESS, direction-free. Steep ground is dear in proportion to how close
##   it is to the species' cliff angle, scaled by `uphill`. This is what makes
##   a wolf take the contour rather than the crest, and it is the term the
##   selftest's ridge measures.
##
##   RISE ABOVE THE DEN, which is a direction, just a fixed one. A territory is
##   a thing centred on a home, so "above home" and "below home" are real
##   places: being above costs `uphill`, being below costs `downhill`, and for
##   a wolf that is 2.6 against 0.8. An ibex's row inverts it and its
##   territory tilts uphill instead - which is the design intent, expressed in
##   the only place a grid can hold it.
func _weight_for(slope_deg: float, altitude_m: float, costs: Dictionary,
		cliff_deg: float) -> float:
	var steepness := clampf(slope_deg / maxf(cliff_deg, 1.0), 0.0, 1.0)
	var w := 1.0 + float(costs["uphill"]) * steepness
	var rise := (altitude_m - _ref_alt) / RISE_REFERENCE_M
	if rise > 0.0:
		w += float(costs["uphill"]) * minf(rise, 1.0)
	else:
		w += float(costs["downhill"]) * minf(-rise, 1.0)
	return w


## Under a lake's water line.
##
## `shore_level_at_cell` answers NaN for a cell that is not near a lake at all,
## which is the guard the plan names - and the test is against the SHORE LEVEL
## rather than against the shore's existence, because the ground just above a
## waterline is walkable and the ground just below it is not.
func _is_underwater(bx: float, bz: float) -> bool:
	if _gen.lakes == null:
		return false
	var level := _gen.lakes.shore_level_at_cell(_gen._cell_index(bx, bz))
	if is_nan(level):
		return false
	return _gen.heightmap.height_at(bx, bz) < level


# --- Paths -------------------------------------------------------------------

## Metre-space waypoints from one point to another, or an empty path.
##
## Y COMES FROM `surface_height_m`, not from the coarse heightmap, and the
## difference is the detail layer: the coarse cell is where the pathfinder
## thinks the ground is and `surface_at` is where it actually is. A creature
## walking the first would float and sink by a metre at a time.
func path_m(from_m: Vector3, to_m: Vector3) -> PackedVector3Array:
	var out := PackedVector3Array()
	var a := _open_cell_near(_cell_of(from_m))
	var b := _open_cell_near(_cell_of(to_m))
	if a == Vector2i(-1, -1) or b == Vector2i(-1, -1):
		return out
	# PARTIAL PATHS ARE ALLOWED, and that is a behaviour decision as much as a
	# pathfinding one. A real territory can be cut in two by a cliff band or a
	# lake, and on seed 42 one in-territory pair out of twenty is genuinely
	# unreachable from the other. The choice is between a creature that stands
	# still because the answer was empty and one that goes as far towards you
	# as the land allows and then gives up - and the second is both the better
	# animal and the one the leash in Stage 6 already knows how to end.
	var flat := _grid.get_point_path(a, b, true)
	var cfg := _world.config
	for p in flat:
		var bx := int(floor(p.x / cfg.block_size))
		var bz := int(floor(p.y / cfg.block_size))
		out.append(Vector3(p.x, _world.surface_height_m(bx, bz), p.y))
	return out


## The heightmap cell a metre position falls in, clamped into the territory.
##
## CLAMPED RATHER THAN REJECTED: a creature chasing a player past its own
## border still needs a path, and the honest answer is a path to the edge of
## what it knows. The leash is a behaviour (Stage 6), not a pathfinding
## failure, and conflating the two would make a wolf that stops dead at an
## invisible line rather than one that turns round and goes home.
func _cell_of(pos_m: Vector3) -> Vector2i:
	var c := _raw_cell_of(pos_m)
	return Vector2i(
		clampi(c.x, region.position.x, region.end.x - 1),
		clampi(c.y, region.position.y, region.end.y - 1))


## The heightmap cell a metre position falls in, unclamped. The one the grid's
## own extent is computed from, and the one `contains_m` asks about.
func _raw_cell_of(pos_m: Vector3) -> Vector2i:
	var hm: Heightmap = _gen.heightmap
	var cfg := _world.config
	return Vector2i(
		int(floor((pos_m.x / cfg.block_size - float(hm.min_block)) / float(hm.step))),
		int(floor((pos_m.z / cfg.block_size - float(hm.min_block)) / float(hm.step))))


## The nearest open cell to this one, searched in rings, or (-1, -1).
##
## A den can sit on a cell the weight table calls a cliff, and a player can
## stand in a lake. Neither is a reason to have no path.
func _open_cell_near(cell: Vector2i) -> Vector2i:
	if not _grid.is_point_solid(cell):
		return cell
	for r in range(1, ENDPOINT_SEARCH_CELLS + 1):
		for dz in range(-r, r + 1):
			for dx in range(-r, r + 1):
				# The ring only, not the filled square - the inside was
				# searched by a smaller r.
				if absi(dx) != r and absi(dz) != r:
					continue
				var c := Vector2i(cell.x + dx, cell.y + dz)
				if not region.has_point(c):
					continue
				if not _grid.is_point_solid(c):
					return c
	return Vector2i(-1, -1)


## For the selftest: is the ground at this metre position pathable at all?
func is_solid_at_m(pos_m: Vector3) -> bool:
	var cell := _cell_of(pos_m)
	return _grid.is_point_solid(cell)


## For the selftest and the F10 readout.
func weight_at_m(pos_m: Vector3) -> float:
	return _grid.get_point_weight_scale(_cell_of(pos_m))


## Is this metre position inside the territory the grid covers?
func contains_m(pos_m: Vector3) -> bool:
	return region.has_point(_raw_cell_of(pos_m))
