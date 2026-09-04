class_name Locomotion

## The movement rules, in one place, for one `CharacterBody3D` and one input
## snapshot.
##
## WHY THIS EXISTS, AND IT IS THE WHOLE OF STAGE 10. Until world feel v1 the
## client simulated its own body and told the host where it had ended up
## (`_srv_report_state`), which `README.md` called the largest provisional bit
## in the codebase and which every combat and creature plan was queued behind: a
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
## `Intent` struct, and this cannot tell them apart - which is what makes solo
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

## THE SAME NUMBER, AS A KNOB. Horizon v1 Stage 0, grill Q10.
##
## The world stopped being 3 km wide and the view reaches 32 km, so crossing
## the drawn country at 18 m/s is half an hour of holding W. `fly_speed_mps`
## on F4 moves this between 18 and 500, and `--tp X Z` gets there in one frame
## for anything a probe or a tour needs.
##
## A `static var` rather than a config read inside `_fly`, for the reason
## `FarFieldJob.FRONTIER_OVERLAP_CELLS` is one: this file is static and
## stateless on purpose - "everything that persists between ticks lives on the
## body" - and threading a config through `Locomotion.step` would put a knob in
## the one signature the host and the client have to agree about. Written on
## the MAIN THREAD only, from `Game._on_config_changed` and `Game._ready`, and
## read on both legs of the prediction, so the host and the client are in step
## by construction whatever either machine has it set to.
##
## LOCAL AND A DEBUG ALLOWANCE, like noclip itself: it changes how fast a
## developer crosses the world and nothing about what the world contains.
static var fly_speed := FLY_SPEED

# --- Momentum (world feel v1 Stage 12) ---------------------------------------
#
# WHY A BODY THAT USED TO SNAP TO ITS WISH NOW TAKES A MOMENT.
#
# Until this stage `velocity.x` was assigned `wish * speed` outright, so a
# player went from standing to 13 m/s in one tick and back again in one tick.
# That is fine for a debug camera and wrong for a world whose entire content
# axis is DISTANCE: a sprint that stops dead has no weight to it, and a
# character with no weight makes a 3 km world feel like a menu you scroll.
#
# The numbers are chosen so that WALKING DOES NOT CHANGE. At walk speed the
# ramp is over in an eighth of a second and nobody will find it; at sprint it
# is a third of a second up and 2.8 m of run-out down, which is the difference
# between arriving somewhere and stopping there.
#
#   0 -> 13 m/s at 40 m/s^2   = 0.325 s
#   13 -> 0 at 30 m/s^2       = 2.82 m of run-out
#
# STARTING VALUES, all three, and they are LOCAL knobs (hard rule 5): they
# change how a machine moves a body, never what the world contains. A client's
# copies affect only its own prediction and the host's copy wins.
const ACCEL := 40.0
const DECEL := 30.0

## How much of that authority a body has with its feet off the ground.
##
## Not zero, because a jump you cannot steer at all reads as a bug rather than
## as realism, and not one, because a player who can turn on a sixpence in
## mid-air is a player for whom the ground is optional.
const AIR_CONTROL := 0.35

## What one player leaning on something contributes, in newtons.
##
## THE NUMBER THAT MAKES PILLAR 1 LEGIBLE. Against the holds in BodyTable it
## reads: one player moves a boulder_m (600 >= 400) and does not move a
## boulder_l (600 < 1000); two do (1200 >= 1000). Nothing in the game has to
## know what "two players" means - the accumulator adds up whatever is pushing
## and the rock compares one number - which is also what makes a third and a
## fourth player work without a special case.
##
## A STARTING VALUE, and the one most likely to move: it is the difference
## between "we shifted it together" and "I could have done that alone".
const PUSH_FORCE_N := 600.0


# --- The slide ---------------------------------------------------------------
#
# SCREE IS THE ONE TERRAIN THAT DOES SOMETHING TO YOU. Pillar 2 is TENSE OUT,
# COZY IN THE LIGHT and pillar 3 is THE WORLD IS THE CONTENT: a mountainside
# that takes the decision away from you for a few seconds is both of those, and
# it costs one rule.
#
# IT IS DELIBERATELY NOT EVERYWHERE. Meadow, forest and rock do not slide at
# any angle. A world where every steep face is a slide is a world where you
# stop trusting slopes, and the traversal cost of that is exactly the failure
# world feel v1 exists to avoid - so the surfaces that slide are the ones a
# player can SEE are loose.
const SLIDE_ANGLE_DEG := 45.0
const SLIDE_FACTOR := 0.5

## Terminal speed of a slide. Past this it stops reading as "losing your
## footing" and starts reading as "falling", which is a different feeling and
## has a different consequence.
const SLIDE_MAX := 8.0


## Does this surface zone give way underfoot?
##
## The rule lives here rather than in the callers because the host and the
## client both have to reach the same answer about the same patch of hill - the
## same reason every other number in this file moved here in Stage 10.
static func is_slippery_zone(zone: int) -> bool:
	return zone == TerrainGenerator.ZONE_ALPINE \
		or zone == TerrainGenerator.ZONE_ROCK \
		or zone == TerrainGenerator.ZONE_SNOW


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

## Pose id, packed into the SAME byte at bits 5-7 rather than travelling as a
## field of its own, which is what keeps the input payload the three keys the
## plan specifies: a wish, a byte and a yaw.
##
## A pose is EXPRESSION, not physics - sitting, waving, downed - so unlike
## every other bit here the host does not derive it, it relays it. There is
## nothing to validate beyond the range, and `from_state_byte` already clamps
## a pose id this build does not know about back to POSE_NONE.
const POSE_SHIFT := 5


## The body settings both sides must agree on.
##
## These lived in `player.gd:_ready()`, and leaving them there would have been
## the subtlest possible desync: identical rules, identical inputs, and a host
## capsule that snapped to the floor over a different distance than the client's
## would drift by a step height per slope and never look like a settings bug.
const CAPSULE_RADIUS := 0.4
const CAPSULE_HEIGHT := 2.0
const FLOOR_MAX_ANGLE_DEG := 55.0

## Where the capsule sits relative to the body's origin.
##
## THE ORIGIN IS AT THE FEET, which is a fact stored in player.tscn - its
## Collider carries `transform ... 0, 1, 0` - and in no code anywhere. The
## host's sim body builds its shape in code, and a shape centred on the origin
## instead of raised by this puts the bottom half of the capsule underground.
##
## That is not a subtle failure and it did not look like one either. The buried
## body was `is_on_floor()`, took its input, set a velocity of 13 m/s, and
## ended every tick at exactly the position it started at, because the ground
## it was standing in blocked it in every horizontal direction. step_up then
## lifted it 0.55 m, once, and it stayed stuck. The pair probe's host row read
## "on floor, velocity 0" for two and a half thousand ticks while the input
## channel showed a thousand correctly-decoded sprint packets arriving.
const CAPSULE_CENTRE_Y := CAPSULE_HEIGHT * 0.5


## Build the collision shape a body of this kind needs, positioned correctly.
## player.tscn does the same thing in scene form; this is for bodies that have
## no scene, and the two must not disagree.
static func make_collider() -> CollisionShape3D:
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = CAPSULE_RADIUS
	capsule.height = CAPSULE_HEIGHT
	shape.shape = capsule
	shape.position = Vector3(0.0, CAPSULE_CENTRE_Y, 0.0)
	return shape


## How fast a body turns to face where it is going, per second.
const TURN_SMOOTHING := 12.0


## The body yaw one tick later, given where it is pointing now and where it is
## going. Returns rather than assigns, so the caller decides what it is the
## yaw OF - `player.gd` writes it onto a visible mesh, the host writes it into
## the table for other machines to render.
##
## It is in here for the same reason the speeds are: the table's "y" is body
## yaw, so if the host derived facing differently from the client, every peer
## would watch a friend's shoulders point somewhere their feet were not.
static func face_yaw(current: float, wish: Vector2, delta: float) -> float:
	if wish.length_squared() < 0.01:
		return current
	# NEGATED - see the long note in player.gd:_face_movement for why, and for
	# the self-test that checks it against Godot's own Vector3.FORWARD.
	var target := atan2(-wish.x, -wish.y)
	# Frame-rate independent smoothing - see RemotePlayer for why this shape
	# rather than lerp(current, target, 0.1).
	return lerp_angle(current, target, 1.0 - exp(-TURN_SMOOTHING * delta))


static func configure_body(body: CharacterBody3D) -> void:
	# Terrain is a staircase of half-metre steps and the capsule must stay
	# glued to it going downhill, or walking down any slope turns into a
	# sequence of small hops.
	body.floor_snap_length = MAX_STEP
	body.floor_max_angle = deg_to_rad(FLOOR_MAX_ANGLE_DEG)


## One tick of intent. Everything the rules need that is not on the body.
##
## `wish` is in the CAMERA's frame and already normalised - the client rotates
## it before sending, because the host does not know where a client's camera is
## pointing and should not have to. `look` is the yaw the body faces, which the
## host needs only to write into the table for other peers to render.
class Intent extends RefCounted:
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

	func pose() -> int:
		return (bits >> POSE_SHIFT) & 7

	func set_pose(id: int) -> void:
		bits = (bits & ~(7 << POSE_SHIFT)) | ((clampi(id, 0, 7) & 7) << POSE_SHIFT)

	## The wire form: three fields, no allocation on the receiving side beyond
	## this object.
	func to_dict() -> Dictionary:
		return {"w": wish, "b": bits, "l": look}

	static func from_dict(d: Dictionary) -> Intent:
		var out := Intent.new()
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
static func speed_multiplier(input: Intent) -> float:
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
## `zone` is the surface zone the body is standing on, or -1 for "not known".
## It is passed in rather than looked up because Locomotion has no world and
## must not acquire one: it is static, it is shared by the host and the client,
## and the moment it can ask the world a question the two sides can be asking
## different worlds.
## Returns whether the body SLID this tick - lost its footing on loose ground
## rather than walked. Returned rather than stored, because this stays static
## and stateless: the caller keeps it if it wants it, which is how the player
## gets it onto the F3 readout and how the traversal probe measures the
## fraction of a crossing spent sliding.
static func step(body: CharacterBody3D, input: Intent, delta: float,
		zone := -1) -> bool:
	if input.flying():
		_fly(body, input, delta)
		return false
	return _walk(body, input, delta, zone)


static func _walk(body: CharacterBody3D, input: Intent, delta: float,
		zone: int) -> bool:
	var wish := Vector3(input.wish.x, 0.0, input.wish.y)
	var speed := WALK_SPEED * speed_multiplier(input)
	var grounded := body.is_on_floor()

	# MOMENTUM. See the note above ACCEL.
	var want := wish * speed
	var flat := Vector3(body.velocity.x, 0.0, body.velocity.z)
	# Accelerating and stopping are different rates, and which one this is
	# depends on whether the player is ASKING for anything - not on whether the
	# speed happens to be rising. A player turning hard is still accelerating.
	var rate := ACCEL if want != Vector3.ZERO else DECEL
	if not grounded:
		rate *= AIR_CONTROL
	flat = flat.move_toward(want, rate * delta)

	var sliding := false
	if grounded and is_slippery_zone(zone):
		var normal := body.get_floor_normal()
		# acos of the up component IS the slope, because the floor normal is a
		# unit vector: straight up is 0 degrees, a wall is 90.
		var angle := rad_to_deg(acos(clampf(normal.y, -1.0, 1.0)))
		if angle >= SLIDE_ANGLE_DEG:
			sliding = true
			# DOWNHILL IS THE NORMAL FLATTENED AND REVERSED. The horizontal
			# part of a surface normal points uphill by definition, so the
			# steepest descent is the other way - no dot products, no
			# cross products, and correct on every facet including the ones
			# a voxel staircase makes.
			var down := Vector3(normal.x, 0.0, normal.z)
			if down.length_squared() > 0.0001:
				down = down.normalized()
				flat += down * GRAVITY * sin(deg_to_rad(angle)) \
					* SLIDE_FACTOR * delta
				if flat.length() > SLIDE_MAX:
					flat = flat.normalized() * SLIDE_MAX

	body.velocity.x = flat.x
	body.velocity.z = flat.z

	if grounded:
		if input.jumping():
			# v = sqrt(2gh) - the speed you need to leave the ground at to
			# reach exactly JUMP_HEIGHT, rather than a number picked by feel
			# that changes meaning the moment gravity is retuned.
			body.velocity.y = sqrt(2.0 * GRAVITY * JUMP_HEIGHT)
	else:
		body.velocity.y -= GRAVITY * delta

	# NO STEP-UP WHILE SLIDING, and this is the rule that makes a slide mean
	# something. step_up() lifts a body over anything up to MAX_STEP, and scree
	# is nothing but half-metre steps - so with it on, a sliding player climbs
	# the far side of every dip and the slide never gets anywhere. Off, the
	# loose ground carries you down it.
	if not sliding:
		step_up(body, delta)
	body.move_and_slide()
	return sliding


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
static func _fly(body: CharacterBody3D, input: Intent, delta: float) -> void:
	var dir := Vector3(input.wish.x, 0.0, input.wish.y)
	if input.jumping():
		dir += Vector3.UP
	if input.descending():
		dir -= Vector3.UP
	if dir != Vector3.ZERO:
		dir = dir.normalized()
	body.velocity = dir * fly_speed * speed_multiplier(input)
	body.global_position += body.velocity * delta
