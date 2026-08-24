class_name TraversalProbe
extends Node

## Walks the player from one corner of the world to the opposite one and times
## it.
##
##     godot --headless --path . -- --host --seed 42 --traverse --view low
##
## WHY THIS EXISTS. Terrain v2 grows the world from 1.5 km to 3 km, and the one
## thing that can make that a mistake is traversal: a world nobody wants to
## cross is smaller than a world they do, whatever the map says. The plan sets
## the target at the map diagonal in under six minutes at sprint, and a target
## needs a measurement rather than a division.
##
## The division is easy and it is not the answer. Speed is assigned straight to
## velocity, so on flat ground the crossing time is exactly distance / speed and
## computing it proves nothing. What it cannot tell you is what the TERRAIN
## does - every slope over the 55 degree floor angle, every lake to go round,
## every ridge that has to be climbed at an angle. That is the whole question,
## and it only has an experimental answer.
##
## IT RUNS IN REAL TIME AND CANNOT BE HURRIED. Godot advances physics from the
## wall clock, so a six-minute crossing takes six minutes. Use `--view low` for
## it: the voxel radius decides how much of a moving 4 km corridor has to be
## built, and the answer at High is most of a day.

## How close, in metres, counts as having arrived. One chunk: closer than that
## and a lake or a cliff at the exact corner would read as a failure to cross
## the world.
const ARRIVE_M := 8.0

## Give up after this much SIM time. 20 minutes is over three times the target,
## so reaching it is a result and not a timeout.
const MAX_SECONDS := 1200.0

## Progress line every this many seconds of sim time.
const REPORT_EVERY := 30.0

## Stuck detection: if the straight-line distance to the target has not
## improved by this many metres over STUCK_WINDOW seconds, say so and stop.
## Walking into a cliff face forever otherwise looks exactly like a slow
## crossing right up until the timeout.
const STUCK_GAIN_M := 5.0
const STUCK_WINDOW := 150.0

## How far below the local ground counts as having fallen out of the world.
##
## THIS IS NOT HYPOTHETICAL AND IT IS WORTH KNOWING ABOUT. Sprint is 13 m/s
## and the Low preset has voxels out to 48 m, so a sprinting player reaches
## unloaded ground in under four seconds. Unloaded ground has no collision
## mesh, so they fall through it - and then the chunks stream in AROUND them
## and they are inside solid rock, permanently stuck. The first run of this
## probe covered 67 m at full speed and then stopped dead for the rest of the
## run, which is exactly that.
const FALL_THROUGH_M := 6.0

## GOING ROUND THINGS, which is the difference between measuring the world and
## measuring a straight line drawn across it.
##
## The first working run covered 68 m at full sprint and then stood still for
## the rest of the run, pushing into a mountainside. That is a true fact about
## a 4 km straight line through alpine terrain and it is not what the six
## minute target is asking: a player walks round the mountain. So when progress
## stalls, the probe turns aside for a few seconds, alternating which way, and
## it jumps - because voxel terrain is a staircase and a player crossing it
## presses Space constantly.
##
## Crude on purpose. Real pathfinding would measure the pathfinder.
const DETOUR_ANGLE_DEG := 65.0
const DETOUR_SECONDS := 4.0

## How many detours on one side before trying the other. Wall-following needs
## commitment; a probe that changes its mind every four seconds walks a zigzag
## in a corner forever.
const DETOUR_TRIES_PER_SIDE := 4

## Progress smaller than this over STALL_WINDOW seconds counts as blocked.
const STALL_GAIN_M := 2.0
const STALL_WINDOW := 1.5

var _world: World = null
var _player: Player = null

var _target := Vector3.ZERO
var _start := Vector3.ZERO
var _elapsed := 0.0
var _next_report := REPORT_EVERY
var _path_m := 0.0
var _last_pos := Vector3.ZERO
var _best_remaining := INF
var _best_at := 0.0
var _running := false

## Sim seconds spent standing still waiting for chunks, kept OUT of _elapsed.
##
## The six-minute target is a question about the TERRAIN - how much the shape
## of the land slows a sprint down. Chunk streaming is a different question
## with a different answer on every machine, and averaging the two together
## would produce a number that describes neither. Both are reported.
var _waited := 0.0
var _rescues := 0

var _detour_until := -1.0
var _detour_sign := 1.0
var _detour_tries := 0
var _detours := 0
var _stall_ref := Vector3.ZERO
var _stall_at := 0.0


func run(world: World, player: Player) -> void:
	_world = world
	_player = player

	print("[Traverse] waiting for the first world load")
	while not _world.is_idle():
		await get_tree().process_frame

	var cfg := _world.config
	# One chunk in from the very corner, so the walk is not spent fighting the
	# world boundary the region loader clips against.
	var half := int(cfg.world_blocks_xz / 2) - Chunk.SIZE
	# ...and then the flattest ground NEAR that corner rather than the corner
	# itself. Since Stage 12 the terrain grows wilder with distance from the
	# middle of the map, so the four corners are the steepest places in the
	# world; the first run of this against that terrain started inside a cliff
	# face and reported 0 m of 4220 m. Standing somewhere walkable is not
	# making the test easier, it is removing a fact about one arbitrary cell
	# from a measurement that is about the whole crossing.
	_start = _walkable_near(-half, -half, cfg)
	_target = _walkable_near(half, half, cfg)

	_player.global_position = _start + Vector3(0.0, 2.0, 0.0)
	# Game freezes the player until the ground under SPAWN exists, and this
	# probe teleports somewhere else entirely. Physics is turned back on here
	# rather than waited for, or the probe would measure how long a frozen
	# character takes to cross 4 km.
	_player.set_physics_process(true)
	_world.set_center_from_position(_player.global_position)
	print("[Traverse] corner to corner: %.0f m, walk %.1f m/s, sprint %.1f m/s" % [
		_start.distance_to(_target), Player.WALK_SPEED,
		Player.WALK_SPEED * Player.SPRINT_MULTIPLIER])
	print("[Traverse] waiting for the ground at the start corner")
	while not _world.is_idle():
		await get_tree().process_frame

	_last_pos = _player.global_position
	_player.sprint_override = true
	_running = true


func _physics_process(delta: float) -> void:
	if not _running:
		return

	var pos := _player.global_position

	# Fell through terrain that had not streamed in yet. Put them back on top
	# of it; being inside rock is not a fact about traversal.
	var ground := _world.surface_height_m(
		int(pos.x / _world.config.block_size), int(pos.z / _world.config.block_size))
	if pos.y < ground - FALL_THROUGH_M:
		_player.global_position = Vector3(pos.x, ground + 2.0, pos.z)
		_player.velocity = Vector3.ZERO
		_rescues += 1
		return

	# Wait for the ground rather than sprinting off the edge of it. Time spent
	# here is not time the terrain cost, so it is counted separately.
	if not _world.is_idle():
		_player.wish_override = Vector3.ZERO
		_waited += delta
		return

	# Steering is recomputed every tick rather than set once, because sliding
	# along a hillside turns you off course by degrees at a time and a fixed
	# heading would arrive somewhere else entirely.
	var to_target := _target - pos
	to_target.y = 0.0

	# Blocked? Turn aside, the other way from last time, and keep jumping.
	if pos.distance_to(_stall_ref) > STALL_GAIN_M:
		_stall_ref = pos
		_stall_at = _elapsed
	elif _elapsed - _stall_at > STALL_WINDOW and _elapsed > _detour_until:
		# KEEP GOING THE SAME WAY, which is the difference between following a
		# wall and bouncing off it. The first version alternated sides on every
		# stall and oscillated in place: 31 detours, 940 m walked, and 0 m of
		# progress over ninety seconds. A side is only abandoned after several
		# attempts have failed to find a way round on it.
		_detour_tries += 1
		if _detour_tries > DETOUR_TRIES_PER_SIDE:
			_detour_sign = -_detour_sign
			_detour_tries = 0
		# AND EACH ATTEMPT ON A SIDE IS LONGER THAN THE LAST. A fixed four
		# seconds is 50 m of sprint, which clears a boulder and does not clear
		# a mountain flank - the run before this one made 840 m at near full
		# speed and then spent 84 seconds taking 27 four-second detours around
		# something several hundred metres wide. Lengthening means the first
		# attempts stay cheap and a genuine obstacle eventually gets walked
		# round rather than nibbled at.
		_detour_until = _elapsed + DETOUR_SECONDS * float(_detour_tries + 1)
		_detours += 1
		_stall_at = _elapsed

	if _elapsed < _detour_until:
		to_target = to_target.rotated(
			Vector3.UP, deg_to_rad(DETOUR_ANGLE_DEG) * _detour_sign)
		_player.jump_override = true

	_player.wish_override = to_target

	_path_m += Vector2(pos.x - _last_pos.x, pos.z - _last_pos.z).length()
	_last_pos = pos
	_elapsed += delta

	var remaining := Vector2(to_target.x, to_target.z).length()
	if remaining < _best_remaining - STUCK_GAIN_M:
		_best_remaining = remaining
		_best_at = _elapsed

	if _elapsed >= _next_report:
		_next_report += REPORT_EVERY
		print("[Traverse] %5.0f s  %6.0f m to go  %6.0f m walked  %.2f m/s made good  (%.0f s waiting)" % [
			_elapsed, remaining, _path_m,
			(_start.distance_to(_target) - remaining) / maxf(_elapsed, 0.001),
			_waited])

	if remaining <= ARRIVE_M:
		_finish("arrived", remaining)
	elif _elapsed - _best_at > STUCK_WINDOW:
		_finish("STUCK - no progress for %.0f s" % STUCK_WINDOW, remaining)
	elif _elapsed >= MAX_SECONDS:
		_finish("gave up at the time limit", remaining)


func _finish(why: String, remaining: float) -> void:
	_running = false
	_player.wish_override = Vector3.ZERO
	_player.sprint_override = false

	var straight := _start.distance_to(_target)
	var covered := straight - remaining
	print("[Traverse] %s" % why)
	print("[Traverse] %.0f s (%.2f min) for %.0f m of %.0f m" % [
		_elapsed, _elapsed / 60.0, covered, straight])
	print("[Traverse] plus %.0f s waiting for chunks, %d detours round obstacles, %d rescues from inside terrain" % [
		_waited, _detours, _rescues])
	# Two speeds, because they answer different questions. Ground speed says
	# how much the terrain slowed the character down; speed made good says how
	# much of that motion was actually towards the far corner, which is the one
	# the six-minute target is about.
	print("[Traverse] ground speed %.2f m/s, made good %.2f m/s (sprint on flat is %.2f)" % [
		_path_m / maxf(_elapsed, 0.001), covered / maxf(_elapsed, 0.001),
		Player.WALK_SPEED * Player.SPRINT_MULTIPLIER])
	if covered > 1.0:
		print("[Traverse] implied full diagonal: %.2f min" % [
			straight / (covered / maxf(_elapsed, 0.001)) / 60.0])
	get_tree().quit()


## The flattest dry cell within SEARCH_BLOCKS of (bx, bz), inward from there.
##
## Searches towards the middle of the map only, so it cannot wander out past
## the world edge, and prefers gentle ground over ground that merely happens to
## be near the corner.
const CORNER_SEARCH_BLOCKS := 240
const CORNER_SEARCH_STEP := 16


func _walkable_near(bx: int, bz: int, cfg: WorldgenConfig) -> Vector3:
	var hm := _world.generator.heightmap
	var inward_x := -signi(bx)
	var inward_z := -signi(bz)
	var best := Vector2i(bx, bz)
	var best_slope := INF
	for dz in range(0, CORNER_SEARCH_BLOCKS, CORNER_SEARCH_STEP):
		for dx in range(0, CORNER_SEARCH_BLOCKS, CORNER_SEARCH_STEP):
			var x := bx + inward_x * dx
			var z := bz + inward_z * dz
			var slope := hm.slope_deg_at(float(x), float(z))
			if slope < best_slope:
				best_slope = slope
				best = Vector2i(x, z)
	print("[Traverse] corner (%d, %d) -> walkable (%d, %d) at %.1f deg" % [
		bx, bz, best.x, best.y, best_slope])
	return _ground_at(best.x, best.y, cfg)


func _ground_at(bx: int, bz: int, cfg: WorldgenConfig) -> Vector3:
	return Vector3(
		float(bx) * cfg.block_size,
		_world.surface_height_m(bx, bz),
		float(bz) * cfg.block_size)
