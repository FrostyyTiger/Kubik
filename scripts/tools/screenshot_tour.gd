class_name ScreenshotTour
extends Node

## Drives the camera to eleven vantage points, photographs each, and quits.
##
##     godot --path . -- --tour --seed 42
##
## Built last, exactly as the plan asked, so that it could never block terrain
## work by failing.
##
## WHAT IT IS FOR. Terrain is judged by looking at it, and the whole of this
## project runs on a headless box over SSH. Six pictures in build/tour/ turn
## "the numbers look plausible" into something you can actually disagree with
## over breakfast. Shot 6 is terrain v2's acceptance test - a mountain, its
## forested slopes and a lake in one frame - and shot 11 is foliage v1's:
## standing inside the forest at dusk.
##
## SHOTS 1-6 ARE ABOUT TERRAIN AND 7-11 ARE ABOUT WHAT GROWS ON IT, and they
## are composed completely differently on purpose. The first six stand well
## back and photograph shape. The last five stand IN the world at eye height,
## because trunk spacing, undergrowth and a treeline do not exist at 80 m -
## from there a forest is a green patch, dense or sparse alike.
##
## The vantage points are DERIVED FROM THE WORLD, not hardcoded - it scans the
## heightmap for the highest summit, the steepest forested slope, the biggest
## lake and the flattest valley floor. Same seed, same six photographs, so two
## runs are comparable and a change in terrain shows up as a change in the
## pictures.

## Where the pictures go. A run with `--label NAME` writes to a subdirectory of
## its own instead, which is what makes this a COMPARISON HARNESS rather than
## just a screenshot tool:
##
##     godot --path . -- --tour --seed 42 --label v2-baseline
##     ...change something...
##     godot --path . -- --tour --seed 42 --label stage9-after
##
## Same seed, same six vantage points, both sets left on disk side by side. A
## terrain change that only shows up as a number in the probe can then be
## looked at, and - the part that actually matters - a change that makes the
## world worse can be seen to have made it worse rather than argued about.
##
## Without a label it writes to build/tour directly, which is where the v1
## shots live and what STATUS.md tells you to run.
const OUT_DIR := "res://build/tour"

## Metres. Far enough back to frame a mountain, near enough that the subject is
## not all fog - fog starts biting at 120 m.
const EYE_DISTANCE := 78.0
const EYE_HEIGHT := 26.0

## Frames to let the world settle after moving before taking the picture.
## Chunk streaming is budgeted per frame, so arriving somewhere and
## photographing it immediately gets you a picture of empty sky.
const SETTLE_FRAMES := 8
const MAX_WAIT_FRAMES := 5400

## Time of day every shot is taken at, unless --time says otherwise.
##
## The config's own day_start, so the tour photographs the world at the light
## level it was tuned against rather than at a light level of its own.
const DEFAULT_TOUR_TIME := -1.0

var _world: World = null
var _player: Player = null
var _sky: SkyCycle = null
var _camera: Camera3D = null

## Resolved from --label at run(). Empty means write straight into OUT_DIR.
var _out_dir := OUT_DIR


func run(world: World, player: Player, sky: SkyCycle = null) -> void:
	_world = world
	_player = player
	_sky = sky

	_freeze_time()
	_out_dir = _resolve_out_dir()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out_dir))

	# A camera of our own rather than steering the player's orbit rig. The rig
	# is built to follow a character and fight for control of its own pitch;
	# for a photograph we just want to say where to stand and what to look at.
	_camera = Camera3D.new()
	_camera.far = 600.0
	_camera.fov = 68.0
	get_tree().current_scene.add_child(_camera)
	_camera.current = true

	# The player still drives which chunks exist, so it gets moved to each
	# vantage point too - frozen, or it would spend the tour falling.
	_player.set_physics_process(false)

	print("[Tour] waiting for the first world load")
	await _wait_for_world()

	var shots := _choose_vantages()
	for i in shots.size():
		await _capture(i, shots[i])

	print("[Tour] done, %d images in %s" % [shots.size(), _out_dir])
	await _shutdown()


## Put the world down before ending the main loop.
##
## A TOUR THAT NEVER EXITS IS WORSE THAN A TOUR THAT NEVER RUNS, and this box
## has produced one: a completed run was found still burning three and a half
## cores seven hours after it wrote its last image. Nothing downstream noticed,
## because every photograph it was asked for was on disk - it had simply not
## returned, and the next thing to want the machine got a third of it.
##
## World holds chunk generation and meshing jobs on the WorkerThreadPool and
## drains them in _exit_tree(). Relying on that means relying on the order the
## engine tears a scene down in while a real renderer is also shutting down.
## Draining first, explicitly, while the tree is still alive and a frame can
## still be processed, costs a few milliseconds and takes the ordering question
## off the table.
##
## If a tour still hangs after this, the drain is where it is hanging, which is
## a far more useful thing to know than "it did not come back".
func _shutdown() -> void:
	if _world != null and is_instance_valid(_world):
		_world.reset()
	await get_tree().process_frame
	get_tree().quit()


# --- Choosing where to stand ------------------------------------------------

## Eleven vantage points, found by reading the world rather than by guessing.
func _choose_vantages() -> Array:
	var hm := _world.generator.heightmap
	var cfg := _world.config
	var gen := _world.generator

	var summit := _find_summit(hm)
	var slope := _find_forest_slope(hm, gen)
	var valley := _find_valley_floor(hm, gen)
	var lake := _find_largest_lake(hm)
	var postcard := _find_postcard(hm)

	var shots := []
	var spawn := gen.spawn_block
	shots.append({
		"name": "1-spawn",
		"note": "where the player starts",
		"target": _to_metres(spawn, gen.surface_at(float(spawn.x), float(spawn.y)), cfg),
		"distance": 46.0, "height": 9.0,
	})
	shots.append({
		"name": "2-summit",
		"note": "the highest ground in the world",
		"target": _cell_to_metres(hm, summit, cfg),
		"distance": 132.0, "height": 22.0,
	})
	shots.append({
		"name": "3-forest-slope",
		"note": "the steepest ground inside the forest band",
		"target": _cell_to_metres(hm, slope, cfg),
		"distance": 60.0, "height": 13.0,
	})
	shots.append({
		"name": "4-valley-floor",
		"note": "flat low meadow, the kind of place a campfire goes",
		"target": _cell_to_metres(hm, valley, cfg),
		"distance": 52.0, "height": 9.0,
	})
	shots.append({
		"name": "5-lake",
		"note": "the largest lake in the world",
		"target": _cell_to_metres(hm, lake, cfg),
		"distance": 68.0, "height": 13.0,
	})
	# THE ACCEPTANCE TEST. Stand on the far side of a lake from the highest
	# thing near it, so the water is foreground and the mountain is behind.
	shots.append({
		"name": "6-postcard",
		"note": "a mountain, its forest and a lake in one frame",
		"target": postcard["look_at"],
		"eye_cell": postcard["eye"],
		"distance": 0.0, "height": 15.0,
	})

	# --- Foliage v1 Stage 1: four vantage points about what grows -----------
	#
	# The six above photograph TERRAIN, from far enough back to see its shape.
	# Not one of them is taken from inside anything, and a forest judged from
	# 80 m away is judged as a green patch on a hillside. The four below stand
	# in the world at eye height instead, because that is where undergrowth,
	# trunk spacing and a treeline actually read - and because the acceptance
	# test for this plan is a sentence about standing inside a forest.
	shots.append_array(_foliage_vantages(hm, gen, cfg))
	return shots


## Eye-height vantages for foliage: inside a forest, in a meadow, at the
## treeline, and at a shore.
##
## EYE HEIGHT IS 1.7 m AND THAT IS THE POINT. The player is 2 m tall at 1:1 and
## trees are 1:4 landscape, so the whole question "does this read as a forest"
## is a question about a specific viewpoint. Photographed from 20 m up, dense
## forest and sparse forest look identical - both are green.
func _foliage_vantages(hm: Heightmap, gen: TerrainGenerator,
		cfg: WorldgenConfig) -> Array:
	var out := []

	var forest := _find_densest_forest(hm, gen)
	var forest_eye := _stand_at(forest, cfg, EYE_LEVEL_M)
	# Looking level, lifted a little at the far end so the canopy is in frame.
	# Straight ahead at eye height photographs trunks and forest floor and cuts
	# the crowns off at the top of the picture, which answers half the question.
	var forest_look := _along(forest_eye, _hashed_heading(7), 22.0, 5.0)
	out.append({
		"name": "7-forest-interior",
		"note": "standing inside the densest forest in the world",
		"eye_m": forest_eye, "target": forest_look,
	})

	var meadow := _find_valley_floor(hm, gen)
	var meadow_eye := _stand_at(meadow, cfg, 3.0)
	# Down 30 degrees. Ground cover is at the player's FEET, and a level camera
	# in a meadow photographs the horizon with a green strip along the bottom.
	out.append({
		"name": "8-meadow-closeup",
		"note": "meadow ground cover, from 3 m up looking down 30 degrees",
		"eye_m": meadow_eye,
		"target": _along(meadow_eye, _hashed_heading(8), 14.0, -tan(deg_to_rad(30.0)) * 14.0),
	})

	var treeline := _find_treeline(hm, gen)
	var treeline_eye := _stand_at(treeline["cell"], cfg, EYE_LEVEL_M)
	out.append({
		"name": "9-treeline",
		"note": "mid-slope below the top of the forest band, looking up it",
		"eye_m": treeline_eye,
		"target": _uphill_target(treeline_eye, treeline["uphill"], cfg, 70.0),
	})

	var shore := _find_shore_stand(hm, cfg)
	out.append({
		"name": "10-shore",
		"note": "two metres from the water, looking along the shoreline",
		"eye_m": shore["eye"], "target": shore["look"],
	})

	# THE ACCEPTANCE TEST FOR THIS PLAN, and the reason a shot carries its own
	# time of day. "Standing inside the forest at dusk, it reads as a forest" is
	# the sentence the whole run is judged on, and dusk is not a detail of it -
	# it is when a forest stops being a green texture and becomes trunks with
	# light between them. Same spot as shot 7, so the two are comparable.
	out.append({
		"name": "11-forest-dusk",
		"note": "shot 7 again, at dusk - the acceptance test",
		"eye_m": forest_eye, "target": forest_look,
		"time": 0.85,
	})
	return out


func _find_summit(hm: Heightmap) -> Vector2i:
	var best := Vector2i.ZERO
	var best_h := -INF
	for j in hm.cols:
		for i in hm.cols:
			var h := hm.cells[i + j * hm.cols]
			if h > best_h:
				best_h = h
				best = Vector2i(i, j)
	return best


## The steepest cell that is still forest. Steep because a flat forest
## photographs as a green carpet and tells you nothing about the terrain under
## it.
func _find_forest_slope(hm: Heightmap, gen: TerrainGenerator) -> Vector2i:
	var best := Vector2i(hm.cols / 2, hm.cols / 2)
	var best_score := -INF
	for j in range(2, hm.cols - 2):
		for i in range(2, hm.cols - 2):
			var h := hm.cells[i + j * hm.cols]
			var bx := hm.cell_to_block(i)
			var bz := hm.cell_to_block(j)
			if gen.surface_zone_at(bx, bz, h) != TerrainGenerator.ZONE_FOREST:
				continue
			var gx: float = absf(hm.cells[i + 1 + j * hm.cols] - hm.cells[i - 1 + j * hm.cols])
			var gz: float = absf(hm.cells[i + (j + 1) * hm.cols] - hm.cells[i + (j - 1) * hm.cols])
			var score := gx + gz
			if score > best_score:
				best_score = score
				best = Vector2i(i, j)
	return best


## Low, and as flat as possible around it.
func _find_valley_floor(hm: Heightmap, gen: TerrainGenerator) -> Vector2i:
	var best := Vector2i(hm.cols / 2, hm.cols / 2)
	var best_score := INF
	for j in range(3, hm.cols - 3, 2):
		for i in range(3, hm.cols - 3, 2):
			var h := hm.cells[i + j * hm.cols]
			var bx := hm.cell_to_block(i)
			var bz := hm.cell_to_block(j)
			if gen.surface_zone_at(bx, bz, h) != TerrainGenerator.ZONE_MEADOW:
				continue
			if _world.lakes != null and _world.lakes.lake_id[i + j * hm.cols] >= 0:
				continue   # standing in a lake is not a valley floor
			var roughness := 0.0
			for dj in [-2, 0, 2]:
				for di in [-2, 0, 2]:
					roughness += absf(hm.cells[i + di + (j + dj) * hm.cols] - h)
			# Low ground first, flat ground second.
			var score := h * 0.4 + roughness
			if score < best_score:
				best_score = score
				best = Vector2i(i, j)
	return best


func _find_largest_lake(hm: Heightmap) -> Vector2i:
	if _world.lakes == null or _world.lakes.lakes.is_empty():
		return Vector2i(hm.cols / 2, hm.cols / 2)
	var biggest := 0
	for i in _world.lakes.lakes.size():
		if _world.lakes.lakes[i]["cells"] > _world.lakes.lakes[biggest]["cells"]:
			biggest = i
	# Scan order is fixed, so "the first cell of that lake" is the same cell on
	# every machine.
	for j in hm.cols:
		for i in hm.cols:
			if _world.lakes.lake_id[i + j * hm.cols] == biggest:
				return Vector2i(i, j)
	return Vector2i(hm.cols / 2, hm.cols / 2)


## The postcard: find the lake with the biggest mountain near it, stand on the
## far side of the water from that mountain, and aim BETWEEN the two.
##
## The composition is the whole point of this shot, and getting it wrong is
## easy. Aiming at the peak itself puts the lake off the bottom of the frame
## and fills two thirds of the picture with sky; aiming at the lake tips the
## camera down and loses the mountain over the top. Looking at a point part way
## up and part way across holds both.
##
## The search radius is also deliberate. Fog is total at 200 m, so a peak found
## 300 m away is a peak you cannot see - the mountain has to be close enough to
## still have colour.
func _find_postcard(hm: Heightmap) -> Dictionary:
	var cfg := _world.config
	var lake_cell := _find_largest_lake(hm)
	var lake_h := hm.cells[lake_cell.x + lake_cell.y * hm.cols]

	# 70 cells is 280 blocks, 140 m - inside the fog rather than lost in it.
	var search := 70
	var peak := lake_cell
	var peak_h := -INF
	for dj in range(-search, search + 1, 2):
		for di in range(-search, search + 1, 2):
			var i := lake_cell.x + di
			var j := lake_cell.y + dj
			if i < 0 or j < 0 or i >= hm.cols or j >= hm.cols:
				continue
			var h := hm.cells[i + j * hm.cols]
			if h > peak_h:
				peak_h = h
				peak = Vector2i(i, j)

	# Stand back from the lake along the line AWAY from the peak, so the shot
	# reads foreground water, middle-distance forest, mountain behind.
	var away := Vector2(lake_cell - peak)
	if away.length() < 1.0:
		away = Vector2(1, 0)
	away = away.normalized()
	var eye := lake_cell + Vector2i(away * 24.0)
	eye.x = clampi(eye.x, 0, hm.cols - 1)
	eye.y = clampi(eye.y, 0, hm.cols - 1)

	# Half way across to the mountain, and a quarter of the way up it.
	var mid := Vector2(lake_cell).lerp(Vector2(peak), 0.5)
	var look_at := Vector3(
		float(hm.cell_to_block(int(mid.x))) * cfg.block_size,
		lerpf(lake_h, peak_h, 0.25) * cfg.block_size,
		float(hm.cell_to_block(int(mid.y))) * cfg.block_size)
	return {"eye": eye, "look_at": look_at}


# --- Foliage v1 Stage 1: finding the four foliage vantages ------------------

## Eye height in metres. The player is player_height_blocks tall at 0.5 m per
## block - 2 m - and eyes are not on top of a head.
const EYE_LEVEL_M := 1.7

## How coarse the search for the densest forest is, in heightmap cells.
##
## The count below is O(cells x tree candidates), and at stride 1 over a
## 1500-cell map that is billions of surface samples. 16 cells is 64 blocks,
## which is four times the window being counted - so the scan cannot miss a
## dense patch by more than its own window, and a forest that dense is never
## one window wide anyway.
const FOREST_SCAN_STRIDE := 16

## The window trees are counted in, in blocks, around each scanned cell.
const FOREST_WINDOW_BLOCKS := 24


## The cell with the most trees around it.
##
## COUNTED, NOT PREDICTED. Asking tree_probability_at() where its peak is would
## answer "the middle of the forest band" and be wrong the moment Stage 4 adds
## groves and glades - the densest place stops being the highest-probability
## place and becomes wherever the grove mask happens to agree with it. Counting
## actual accepted candidates means this vantage tracks the placement rules
## through every stage without knowing anything about them.
func _find_densest_forest(hm: Heightmap, gen: TerrainGenerator) -> Vector2i:
	var best := Vector2i(hm.cols / 2, hm.cols / 2)
	var best_count := -1
	var cell: int = _world.config.tree_cell_blocks
	if cell <= 0:
		return best

	for j in range(2, hm.cols - 2, FOREST_SCAN_STRIDE):
		for i in range(2, hm.cols - 2, FOREST_SCAN_STRIDE):
			var h := hm.cells[i + j * hm.cols]
			var bx := hm.cell_to_block(i)
			var bz := hm.cell_to_block(j)
			if gen.surface_zone_at(bx, bz, h) != TerrainGenerator.ZONE_FOREST:
				continue
			var count := _count_trees_near(gen, bx, bz, cell)
			if count > best_count:
				best_count = count
				best = Vector2i(i, j)
	print("[Tour] densest forest cell %s with %d trees in %d blocks" % [
		best, best_count, FOREST_WINDOW_BLOCKS])
	return best


## Trees accepted inside a window, using the world's own placement rules.
func _count_trees_near(gen: TerrainGenerator, bx: int, bz: int, cell: int) -> int:
	var half := FOREST_WINDOW_BLOCKS / 2
	var c0x := Chunk.floor_div(bx - half, cell)
	var c1x := Chunk.floor_div(bx + half, cell)
	var c0z := Chunk.floor_div(bz - half, cell)
	var c1z := Chunk.floor_div(bz + half, cell)
	var count := 0
	for cz in range(c0z, c1z + 1):
		for cx in range(c0x, c1x + 1):
			if _accepts_tree(gen, cx, cz):
				count += 1
	return count


## Does a tree stand at this candidate cell?
##
## The world's own acceptance rule, restated here rather than reached for,
## because in Stage 1 it still lives inside TerrainGenerator._stamp_tree()
## where nothing outside can call it - and the plan is explicit that the only
## edits to terrain_generator.gd are the hooks it names per stage, which for
## Stage 1 is none.
##
## STAGE 4 REPLACES THIS with a call into TreePlacement, and so does the same
## restatement in worldgen_probe.gd. Two copies of a rule is one too many; the
## reason to accept it for three stages is that the alternative is editing a
## file another plan may be working in tonight.
func _accepts_tree(gen: TerrainGenerator, cell_x: int, cell_z: int) -> bool:
	var bx := cell_x * _world.config.tree_cell_blocks
	var bz := cell_z * _world.config.tree_cell_blocks
	var surface := gen.surface_at(float(bx), float(bz))
	var chance := gen.tree_probability_at(
		surface, gen.zone_jitter_at(float(bx), float(bz)))
	if chance <= 0.0:
		return false
	return WorldHash.hash01(cell_x, cell_z, gen.world_seed,
		TerrainGenerator.SALT_TREE) < chance


## A spot in the top of the forest band, on a slope, and which way is up.
##
## The top QUARTER of the band rather than its very edge: at the edge the trees
## have already thinned to nothing and the picture is of bare heath with a
## green line below it. A quarter down, the thinning is happening in frame,
## which is what a treeline actually looks like.
func _find_treeline(hm: Heightmap, gen: TerrainGenerator) -> Dictionary:
	var band := gen.zone_band(TerrainGenerator.ZONE_FOREST)
	var lo := lerpf(band.x, band.y, 0.70)
	var hi := lerpf(band.x, band.y, 0.90)
	var best := Vector2i(hm.cols / 2, hm.cols / 2)
	var best_slope := -INF

	for j in range(2, hm.cols - 2, 3):
		for i in range(2, hm.cols - 2, 3):
			var h := hm.cells[i + j * hm.cols]
			if h < lo or h > hi:
				continue
			var bx := hm.cell_to_block(i)
			var bz := hm.cell_to_block(j)
			if gen.surface_zone_at(bx, bz, h) != TerrainGenerator.ZONE_FOREST:
				continue
			# Steep enough that "looking up the slope" means something, but not
			# a cliff - the zone code turns those to rock and nothing grows.
			var slope := hm.slope_deg_at(float(bx), float(bz))
			if slope > 38.0:
				continue
			if slope > best_slope:
				best_slope = slope
				best = Vector2i(i, j)

	return {"cell": best, "uphill": _uphill_at(hm, best)}


## Which way the ground rises at a cell, as a unit vector in XZ.
func _uphill_at(hm: Heightmap, cell: Vector2i) -> Vector2:
	var i := clampi(cell.x, 1, hm.cols - 2)
	var j := clampi(cell.y, 1, hm.cols - 2)
	var gx := hm.cells[i + 1 + j * hm.cols] - hm.cells[i - 1 + j * hm.cols]
	var gz := hm.cells[i + (j + 1) * hm.cols] - hm.cells[i + (j - 1) * hm.cols]
	var g := Vector2(gx, gz)
	return g.normalized() if g.length() > 0.0001 else Vector2(1.0, 0.0)


## Stand two metres back from the water's edge, looking ALONG the shoreline.
##
## Along, not across: across the water is a picture of a lake, which shot 5
## already is. Along it is a picture of the BAND - reeds, gravel, the birches
## the plan puts at a shore - receding into the distance, which is the only
## composition that shows whether the shore band has anything in it.
func _find_shore_stand(hm: Heightmap, cfg: WorldgenConfig) -> Dictionary:
	var lake_cell := _find_largest_lake(hm)
	var lakes := _world.lakes
	var outward := Vector2(1.0, 0.0)
	var edge := lake_cell

	if lakes != null and not lakes.lakes.is_empty():
		var id := lakes.lake_id[lake_cell.x + lake_cell.y * hm.cols]
		# Walk outward from a cell of the lake until the water stops. The first
		# dry cell is the shore, and the direction we walked is "outward".
		var dirs: Array[Vector2i] = [
			Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]
		for dir in dirs:
			var probe := lake_cell
			var steps := 0
			while steps < 200:
				var next := probe + dir
				if next.x < 1 or next.y < 1 or next.x >= hm.cols - 1 or next.y >= hm.cols - 1:
					break
				if lakes.lake_id[next.x + next.y * hm.cols] != id:
					edge = next
					outward = Vector2(dir).normalized()
					steps = -1
					break
				probe = next
				steps += 1
			if steps == -1:
				break

	# Two metres further onto dry land, and look along the tangent.
	var tangent := Vector2(-outward.y, outward.x)
	var back := outward * (2.0 / cfg.block_size)
	var bx := hm.cell_to_block(edge.x) + int(round(back.x))
	var bz := hm.cell_to_block(edge.y) + int(round(back.y))
	var eye := Vector3(
		float(bx) * cfg.block_size,
		_world.surface_height_m(bx, bz) + EYE_LEVEL_M,
		float(bz) * cfg.block_size)
	return {"eye": eye, "look": _along(eye, tangent, 40.0, 1.0)}


# --- Small geometry helpers -------------------------------------------------

## Eye position in metres, standing on the ground at a heightmap cell.
func _stand_at(cell: Vector2i, cfg: WorldgenConfig, height_m: float) -> Vector3:
	var bx := _world.generator.heightmap.cell_to_block(cell.x)
	var bz := _world.generator.heightmap.cell_to_block(cell.y)
	return Vector3(
		float(bx) * cfg.block_size,
		_world.surface_height_m(bx, bz) + height_m,
		float(bz) * cfg.block_size)


## A point `distance` away along a heading, `rise` metres higher.
func _along(eye: Vector3, heading: Vector2, distance: float, rise: float) -> Vector3:
	return eye + Vector3(heading.x, 0.0, heading.y) * distance + Vector3(0.0, rise, 0.0)


## Look up a slope: the same distance out, but at the altitude the ground has
## actually reached there, plus a little - so the camera follows the hill
## rather than aiming through it.
func _uphill_target(eye: Vector3, uphill: Vector2, cfg: WorldgenConfig,
		distance: float) -> Vector3:
	var target := eye + Vector3(uphill.x, 0.0, uphill.y) * distance
	var bx := int(target.x / cfg.block_size)
	var bz := int(target.z / cfg.block_size)
	target.y = _world.surface_height_m(bx, bz) + 6.0
	return target


## An arbitrary but repeatable compass heading, hashed from the seed. Same
## world, same direction, every run - so two tours differ only where the world
## does.
func _hashed_heading(index: int) -> Vector2:
	var angle := WorldHash.hash01(index, 0, _world.world_seed, 909) * TAU
	return Vector2(cos(angle), sin(angle))


# --- Taking the picture -----------------------------------------------------

func _capture(index: int, shot: Dictionary) -> void:
	var hm := _world.generator.heightmap
	var cfg := _world.config
	var target: Vector3 = shot["target"]

	var eye: Vector3
	if shot.has("eye_m"):
		# An exact standing position, worked out by the shot itself. The
		# foliage vantages need this: "1.7 m up inside the forest" is not a
		# distance and an azimuth from a subject, it IS the position, and the
		# thing being looked at is 20 m of trees rather than a landmark.
		eye = shot["eye_m"]
	elif shot.has("eye_cell"):
		var cell: Vector2i = shot["eye_cell"]
		eye = _cell_to_metres(hm, cell, cfg)
		eye.y += shot["height"]
	else:
		# Azimuth is hashed from the seed, so the angle is arbitrary but
		# repeatable - the same world always photographs from the same side.
		var angle := WorldHash.hash01(index, 0, _world.world_seed, 909) * TAU
		eye = target + Vector3(cos(angle), 0.0, sin(angle)) * shot["distance"]
		eye.y = _world.surface_height_m(
			int(eye.x / cfg.block_size), int(eye.z / cfg.block_size)) + shot["height"]

	# Voxels exist near the PLAYER, so the player is what has to move.
	_player.global_position = eye
	_world.set_center_from_position(eye)

	print("[Tour] %s - %s" % [shot["name"], shot["note"]])
	await _wait_for_world()
	for i in SETTLE_FRAMES:
		await get_tree().process_frame

	_camera.global_position = eye
	_camera.look_at(target, Vector3.UP)

	# A SHOT MAY OWN ITS OWN HOUR. 11-forest-dusk is shot 7 again at 0.85, and
	# the whole point of it is the light - so the tour's frozen time is moved
	# for this frame and put back afterwards. Restoring matters: leaving it
	# would silently relight every shot after it, and the tour would stop being
	# a comparison harness halfway through its own run.
	var restore := -1.0
	if shot.has("time") and _sky != null:
		restore = _sky.time_of_day
		_sky.time_of_day = shot["time"]
		_sky.apply()
		for i in SETTLE_FRAMES:
			await get_tree().process_frame

	# The image is only valid once the frame has actually been drawn.
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var path := "%s/%s.png" % [_out_dir, shot["name"]]
	var err := image.save_png(path)
	if err != OK:
		push_warning("[Tour] could not write %s: %s" % [path, error_string(err)])
	else:
		print("[Tour]   -> %s (%dx%d)" % [path, image.get_width(), image.get_height()])

	if restore >= 0.0 and _sky != null:
		_sky.time_of_day = restore
		_sky.apply()


func _wait_for_world() -> void:
	var frames := 0
	while not _world.is_idle() and frames < MAX_WAIT_FRAMES:
		await get_tree().process_frame
		frames += 1
	if frames >= MAX_WAIT_FRAMES:
		push_warning("[Tour] gave up waiting for chunks after %d frames" % frames)


func _cell_to_metres(hm: Heightmap, cell: Vector2i, cfg: WorldgenConfig) -> Vector3:
	var bx := hm.cell_to_block(cell.x)
	var bz := hm.cell_to_block(cell.y)
	return _to_metres(Vector2i(bx, bz), hm.cells[cell.x + cell.y * hm.cols], cfg)


func _to_metres(block_xz: Vector2i, altitude_blocks: float, cfg: WorldgenConfig) -> Vector3:
	return Vector3(
		float(block_xz.x) * cfg.block_size,
		altitude_blocks * cfg.block_size,
		float(block_xz.y) * cfg.block_size)


## `--tour --label NAME` -> res://build/tour/NAME. No label -> res://build/tour.
##
## The label is sanitised rather than trusted: it becomes a directory name, and
## a stray slash in it would scatter screenshots somewhere surprising.
func _resolve_out_dir() -> String:
	var argv := OS.get_cmdline_user_args()
	var i := argv.find("--label")
	if i < 0 or i + 1 >= argv.size():
		return OUT_DIR
	var label := argv[i + 1].strip_edges()
	# Letters, digits, dash, underscore and dot survive; everything else becomes
	# a dash. is_valid_identifier() alone would reject digits, since a digit
	# cannot START an identifier - "v2-baseline" would come out as "--baseline".
	var clean := ""
	for c in label:
		if c.is_valid_identifier() or (c >= "0" and c <= "9") or c in "-_.":
			clean += c
		else:
			clean += "-"
	clean = clean.strip_edges()
	if clean.is_empty():
		push_warning("[Tour] --label %s is not usable as a directory name" % label)
		return OUT_DIR
	return "%s/%s" % [OUT_DIR, clean]


## Stop the sun where it is, for the whole tour.
##
## THE HARNESS WAS BROKEN WITHOUT THIS and it had been since v1. A day is
## day_seconds long - 480 by default - and a six-shot tour under software
## rendering takes about five minutes, so the sun set between shot three and
## shot four and the last of them came back as black rectangles. It never
## showed up on a real GPU, where the whole tour is over in seconds.
##
## The black frames are the obvious half. The half that matters is that a
## comparison harness whose lighting depends on how long rendering took cannot
## be used to compare anything - two runs of the same seed would differ in the
## light before they differed in the terrain.
##
## `--time 0.5` overrides it, for deliberately photographing the world at noon
## or at dusk.
func _freeze_time() -> void:
	if _sky == null:
		push_warning("[Tour] no SkyCycle - the sun will move during the tour")
		return
	var t := DEFAULT_TOUR_TIME
	var argv := OS.get_cmdline_user_args()
	var i := argv.find("--time")
	if i >= 0 and i + 1 < argv.size():
		t = clampf(argv[i + 1].to_float(), 0.0, 1.0)
	if t < 0.0:
		t = _world.config.day_start
	_sky.time_of_day = t
	_sky.frozen = true
	_sky.apply()
	print("[Tour] time of day frozen at %.3f" % t)
