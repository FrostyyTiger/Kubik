class_name ScreenshotTour
extends Node

## Drives the camera to six vantage points, photographs each, and quits.
##
##     godot --path . -- --tour --seed 42
##
## Built last, exactly as the plan asked, so that it could never block terrain
## work by failing.
##
## WHAT IT IS FOR. Terrain is judged by looking at it, and the whole of this
## project runs on a headless box over SSH. Six pictures in build/tour/ turn
## "the numbers look plausible" into something you can actually disagree with
## over breakfast. The last shot is the acceptance test itself: a mountain, its
## forested slopes and a lake in one frame.
##
## The vantage points are DERIVED FROM THE WORLD, not hardcoded - it scans the
## heightmap for the highest summit, the steepest forested slope, the biggest
## lake and the flattest valley floor. Same seed, same six photographs, so two
## runs are comparable and a change in terrain shows up as a change in the
## pictures.

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

var _world: World = null
var _player: Player = null
var _camera: Camera3D = null


func run(world: World, player: Player) -> void:
	_world = world
	_player = player

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))

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

	print("[Tour] done, %d images in %s" % [shots.size(), OUT_DIR])
	get_tree().quit()


# --- Choosing where to stand ------------------------------------------------

## Six vantage points, found by reading the world rather than by guessing.
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
	shots.append({
		"name": "1-spawn",
		"note": "where the player starts",
		"target": _to_metres(Vector2i(0, 0), gen.surface_at(0.0, 0.0), cfg),
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
	return shots


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


# --- Taking the picture -----------------------------------------------------

func _capture(index: int, shot: Dictionary) -> void:
	var hm := _world.generator.heightmap
	var cfg := _world.config
	var target: Vector3 = shot["target"]

	var eye: Vector3
	if shot.has("eye_cell"):
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

	# The image is only valid once the frame has actually been drawn.
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var path := "%s/%s.png" % [OUT_DIR, shot["name"]]
	var err := image.save_png(path)
	if err != OK:
		push_warning("[Tour] could not write %s: %s" % [path, error_string(err)])
	else:
		print("[Tour]   -> %s (%dx%d)" % [path, image.get_width(), image.get_height()])


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
