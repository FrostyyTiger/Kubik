class_name Creature
extends Node3D

## One animal, as the host moves it.
##
## HEIGHT-SNAPPED KINEMATICS, NOT A PHYSICS BODY - decision 1 of
## `docs/plans/creatures-v1-tech.md`. A wolf is a `Node3D` standing on
## `World.surface_height_m()` and walked along a path by the server: no
## `CharacterBody3D`, no Jolt cost, no collision shape, and the bite is a range
## check. Sixteen of these cost the physics engine nothing at all, which is
## what makes the cap a policy rather than a budget.
##
## What that defers, recorded rather than discovered later: **a creature does
## not collide with a boulder**, cannot be pushed by one, and will walk through
## a pushed body's new position. The bodies are `BodyField`'s and they are
## solid to players; making them solid to animals is a Combat-v1-era question
## and it is written down in the status doc.
##
## THE BRAIN IS NOT HERE. This class walks and turns and stands on the ground;
## `wolf.gd` decides where. Keeping the two apart is what lets the marmot's
## utility scores and the eagle's boids drive exactly the same body.

## How sharply a creature turns to face where it is going, per second. The
## repo's smoothing convention: 1 - exp(-k dt), which moves the same fraction
## per unit of TIME at any frame rate. See `remote_player.gd` for why the
## tempting lerp(a, b, 0.1) is wrong.
const TURN_RATE := 6.0

## How close, in metres, counts as having reached a waypoint. Under a cell, so
## a creature does not visibly stop at each one.
const WAYPOINT_M := 1.2

## How much a slope slows an animal down, as a fraction of its speed at the
## steepest ground it will walk on. 0.55 means the last walkable slope is
## covered at 45% speed - noticeably labouring, still moving.
const SLOPE_DRAG := 0.55

## The states that ride the sync row's state int. Small and display-facing:
## a client turns these into a pose, and nothing more.
enum {
	STATE_IDLE = 0,
	STATE_WALK = 1,
	STATE_RUN = 2,
	STATE_LUNGE = 3,
}

var species := Species.WOLF

## Server-assigned, stable for the creature's life, and the `id` every journal
## event and every sync row carries.
var id := 0

var world: World = null
var nav: CreatureNav = null
var board: PackBoard = null

## What this creature is doing, for the wire and for the animator.
var state := STATE_IDLE

## Metres per second right now - the species' walk or run, as the brain asked.
var speed_mps := 0.0

## Where the brain last pointed it. Empty means standing still.
var _path := PackedVector3Array()
var _path_i := 0

## Yaw in radians, smoothed towards the direction of travel.
var _yaw := 0.0

## Metres actually covered, for the probe.
var travelled_m := 0.0


func setup(p_species: int, p_id: int, p_world: World, p_nav: CreatureNav,
		p_board: PackBoard) -> void:
	species = Species.valid(p_species)
	id = p_id
	world = p_world
	nav = p_nav
	board = p_board
	name = "%s%d" % [Species.name_of(species), id]
	snap_to_ground()


## Follow this path from the start. An empty path stops the creature where it
## is rather than leaving it walking to a stale waypoint - which is what a
## brain changing its mind actually means.
func set_path(path: PackedVector3Array) -> void:
	_path = path
	_path_i = 0
	if path.is_empty():
		state = STATE_IDLE


func has_path() -> bool:
	return _path_i < _path.size()


## Where it is going, or its own position when it is going nowhere.
func destination() -> Vector3:
	if _path.is_empty():
		return global_position
	return _path[_path.size() - 1]


## The way it is looking, flat. THE ONLY THING THE SENSES BUS IS GIVEN about
## which way a creature faces - see `SensesBus.can_see`.
func facing() -> Vector3:
	return Vector3(sin(_yaw), 0.0, cos(_yaw))


func yaw() -> float:
	return _yaw


## One frame of walking. Called by the server at frame rate, not at brain rate:
## decisions are ten a second and movement is smooth between them.
func advance(delta: float) -> void:
	if not has_path() or speed_mps <= 0.0:
		if state != STATE_LUNGE:
			state = STATE_IDLE
		snap_to_ground()
		return

	var target := _path[_path_i]
	var to_target := target - global_position
	to_target.y = 0.0
	var flat := to_target.length()
	if flat < WAYPOINT_M:
		_path_i += 1
		if not has_path():
			state = STATE_IDLE
		snap_to_ground()
		return

	var dir := to_target / flat
	# SLOPE SLOWS IT DOWN, measured along the way it is actually going rather
	# than from the cell's own steepness: an animal running along a contour on
	# a 30 degree hillside is on steep ground and is not climbing.
	var step := minf(speed_mps * delta, flat)
	var ahead := global_position + dir * maxf(step, 0.5)
	var rise := _ground_at(ahead) - global_position.y
	var climb := clampf(rise / maxf(step, 0.001), 0.0, 1.0)
	step *= 1.0 - SLOPE_DRAG * climb

	var moved := dir * step
	global_position += moved
	travelled_m += step
	snap_to_ground()

	# Turn towards where it is going. Frame-rate independent, per TURN_RATE.
	var wanted := atan2(dir.x, dir.z)
	_yaw = lerp_angle(_yaw, wanted, 1.0 - exp(-TURN_RATE * delta))
	rotation.y = _yaw

	if state != STATE_LUNGE:
		state = STATE_RUN if speed_mps > Species.walk_mps(species) * 1.5 \
			else STATE_WALK


## Feet on the ground, wherever the ground turned out to be.
##
## EVERY FRAME, NOT ONLY ON ARRIVAL. A creature crossing a chunk boundary into
## terrain whose detail layer differs from the coarse cell would otherwise walk
## with its ankles in the rock until its next waypoint.
func snap_to_ground() -> void:
	global_position.y = _ground_at(global_position)


func _ground_at(pos: Vector3) -> float:
	if world == null:
		return pos.y
	var bs := world.config.block_size
	return world.surface_height_m(int(floor(pos.x / bs)), int(floor(pos.z / bs)))


## One row of the sync table - decision 3, the BodyField school. Positions and
## a state int; a client builds a view from this and decides nothing.
func to_row() -> Array:
	return [global_position, _yaw, state, species]
