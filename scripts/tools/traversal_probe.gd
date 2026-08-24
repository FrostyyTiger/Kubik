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
const STUCK_WINDOW := 45.0

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
	_start = _ground_at(-half, -half, cfg)
	_target = _ground_at(half, half, cfg)

	_player.global_position = _start + Vector3(0.0, 2.0, 0.0)
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
	# Steering is recomputed every tick rather than set once, because sliding
	# along a hillside turns you off course by degrees at a time and a fixed
	# heading would arrive somewhere else entirely.
	var to_target := _target - pos
	to_target.y = 0.0
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
		print("[Traverse] %5.0f s  %6.0f m to go  %6.0f m walked  %.2f m/s made good" % [
			_elapsed, remaining, _path_m,
			(_start.distance_to(_target) - remaining) / maxf(_elapsed, 0.001)])

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


func _ground_at(bx: int, bz: int, cfg: WorldgenConfig) -> Vector3:
	return Vector3(
		float(bx) * cfg.block_size,
		_world.surface_height_m(bx, bz),
		float(bz) * cfg.block_size)
