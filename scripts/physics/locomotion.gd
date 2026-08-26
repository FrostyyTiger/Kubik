class_name Locomotion

## The movement rules, in one place, for one `CharacterBody3D` and one input
## snapshot.
##
## WHY THIS EXISTS, AND IT IS THE WHOLE OF STAGE 10. Until world feel v1 the
## client simulated its own body and told the host where it had ended up
## (`_srv_report_state`), which `README.md` calls the largest provisional bit in
## the codebase and which every combat and creature plan is queued behind: a
## client that reports its own position can report any position it likes.
##
## The fix is the carried ticket - the client sends INPUT and the host
## simulates - and the thing that makes it work is that both sides run the same
## step. If the host's movement and the client's prediction were two
## implementations of the same rules they would disagree within a second of
## walking, and every disagreement would look like a cheat or a bug rather than
## like drift. So there is one implementation, it is static, it takes everything
## it needs as arguments, and neither `player.gd` nor the host's sim bodies have
## a copy of any of it.
##
## STATIC AND STATELESS, deliberately. Everything that persists between ticks
## lives on the body - `velocity`, `global_position` - which is exactly the
## state the host is authoritative over and the client is predicting. A
## `Locomotion` that remembered anything would be a second place for the two
## sides to diverge.
##
## The one thing it does NOT do is decide what the input is. A client reads a
## keyboard; the host reads the last packet a peer sent. Both hand over the same
## `Input` struct, and this cannot tell them apart - which is what makes solo
## play (a host with zero clients, moving its own body through this same step)
## the same code path as everything else.

# --- The numbers -------------------------------------------------------------
#
# These were `player.gd`'s and they keep its values exactly. They are here
# rather than there because the host has no Player node to read them off, and a
# constant that lives on one side of a network boundary is a constant that will
# be edited on one side of it.

const WALK_SPEED := 5.0
const SPRINT_MULTIPLIER := 2.6
const PRECISION_MULTIPLIER := 0.3
const GRAVITY := 22.0
const JUMP_HEIGHT := 1.1
const MAX_STEP := 0.55
## Noclip is for crossing a 3 km world, so it is deliberately far faster
## than walking.
const FLY_SPEED := 18.0

## Input bits, as they travel on the wire. One byte, so a packet is a Vector2,
## a float and an int rather than four booleans and a schema.
const BIT_SPRINT := 1
const BIT_JUMP := 2
const BIT_PRECISION := 4
const BIT_FLY := 8
## Descend, in noclip only. It is a bit of its OWN rather than a reuse of
## precision, because the shipped keybind is Ctrl and Ctrl never meant "go
## slowly" - folding the two together would have quietly made flying downwards
## a third of the speed of flying upwards.
const BIT_DOWN := 16


## One tick of intent. Everything the rules need that is not on the body.
##
## `wish` is in the CAMERA's frame and already normalised - the client rotates
## it before sending, because the host does not know where a client's camera is
## pointing and should not have to. `look` is the yaw the body faces, which the
## host needs only to write into the table for other peers to render.
class Input extends RefCounted:
	var wish := Vector2.ZERO
	var bits := 0
	var look := 0.0

	func sprinting() -> bool:
		return bits & BIT_SPRINT != 0

	func jumping() -> bool:
		return bits & BIT_JUMP != 0

	func precision() -> bool:
		return bits & BIT_PRECISION != 0

	func flying() -> bool:
		return bits & BIT_FLY != 0

	func descending() -> bool:
		return bits & BIT_DOWN != 0

	## The wire form: three fields, no allocation on the receiving side beyond
	## this object.
	func to_dict() -> Dictionary:
		return {"w": wish, "b": bits, "l": look}

	static func from_dict(d: Dictionary) -> Input:
		var out := Input.new()
		out.wish = d.get("w", Vector2.ZERO)
		out.bits = int(d.get("b", 0))
		out.look = float(d.get("l", 0.0))
		return out


## How fast this input wants to go, as a multiple of WALK_SPEED.
##
## SPRINT IS CHECKED FIRST, and that order is not arbitrary. It is what
## `player.gd` shipped, and more to the point it is what `_locomotion_mode()`
## still uses to pick the animation. If this resolved precision first the body
## would move at 0.3x while the legs played a sprint cycle - the exact
## disagreement that function's comment promises cannot happen.
static func speed_multiplier(input: Input) -> float:
	if input.sprinting():
		return SPRINT_MULTIPLIER
	if input.precision():
		return PRECISION_MULTIPLIER
	return 1.0


## Advance one body by one tick. The only entry point.
##
## `body` is moved in place - `velocity` and `global_position` are the state.
## Returns nothing, because everything a caller needs afterwards it reads off
## the body, which is also what the host writes into the table.
static func step(body: CharacterBody3D, input: Input, delta: float) -> void:
	if input.flying():
		_fly(body, input, delta)
		return
	_walk(body, input, delta)


static func _walk(body: CharacterBody3D, input: Input, delta: float) -> void:
	var wish := Vector3(input.wish.x, 0.0, input.wish.y)
	var speed := WALK_SPEED * speed_multiplier(input)

	body.velocity.x = wish.x * speed
	body.velocity.z = wish.z * speed

	if body.is_on_floor():
		if input.jumping():
			# v = sqrt(2gh) - the speed you need to leave the ground at to
			# reach exactly JUMP_HEIGHT, rather than a number picked by feel
			# that changes meaning the moment gravity is retuned.
			body.velocity.y = sqrt(2.0 * GRAVITY * JUMP_HEIGHT)
	else:
		body.velocity.y -= GRAVITY * delta

	step_up(body, delta)
	body.move_and_slide()


## Walk up a ledge instead of stopping dead at it.
##
## Godot's CharacterBody3D has no stair stepping and voxel terrain is nothing
## but stairs - every slope is a run of 0.5 m steps. The test is deliberately
## the whole thing: if the move is blocked from here but the SAME move from
## MAX_STEP higher is clear, then what blocked us was a step and not a wall.
## A real wall blocks both, so this cannot be used to climb one.
static func step_up(body: CharacterBody3D, delta: float) -> void:
	if not body.is_on_floor():
		return
	var motion := Vector3(body.velocity.x, 0.0, body.velocity.z) * delta
	if motion.length_squared() < 0.000001:
		return
	if not body.test_move(body.global_transform, motion):
		return  # nothing in the way
	var raised := body.global_transform.translated(Vector3.UP * MAX_STEP)
	if body.test_move(raised, motion):
		return  # still blocked from up there, so it is a wall
	# floor_snap_length pulls us back down onto the step's surface on the next
	# move_and_slide, so this does not leave the body floating.
	body.global_position.y += MAX_STEP


## Noclip. A debug tool, and the host honours it for any peer - which is
## written down as a debug ALLOWANCE rather than as a rule, because a client
## asking to fly is exactly the thing authority is supposed to refuse. It stays
## until there is something to cheat at.
static func _fly(body: CharacterBody3D, input: Input, delta: float) -> void:
	var dir := Vector3(input.wish.x, 0.0, input.wish.y)
	if input.jumping():
		dir += Vector3.UP
	if input.descending():
		dir -= Vector3.UP
	if dir != Vector3.ZERO:
		dir = dir.normalized()
	body.velocity = dir * FLY_SPEED * speed_multiplier(input)
	body.global_position += body.velocity * delta
