class_name Player
extends CharacterBody3D

## The player character: a capsule that walks on terrain, with a third-person
## orbit camera and a debug flight mode.
##
## THIRD PERSON ONLY. Not a preference - the design is sold on reading
## landscape at a glance, and an over-the-shoulder or first-person framing
## hides exactly the thing worth looking at. There is no first-person mode and
## there is not going to be one.
##
## PHYSICS IS LOCAL, FOR NOW. The host does not simulate this yet. Clients
## still report their POSITION rather than their input, exactly as the debug
## camera did - see the provisional note in Game. Turning that into
## "client sends input, host simulates, host broadcasts position" is a carried
## ticket, and the shape of the existing channel is already right for it.

## Metres per second on flat ground. Blocks are 0.5 m, so this is faster in
## blocks than it looks: 5 m/s is 10 blocks a second.
const WALK_SPEED := 5.0

## SET BY TRAVERSAL, NOT BY REALISM, and worth knowing that before judging it.
##
## The world is 3 x 3 km, so its diagonal is 4243 m, and terrain v2 sets the
## target at under six minutes corner to corner. That is 11.8 m/s, and 2.6
## gives 13.0 m/s and crosses it in 5.4 minutes.
##
## The tension this creates is real and deliberate. The LAND is at 1:4 against
## reality; the PLAYER is at 1:0.9, essentially life-size. So a sprint that
## covers the land at a sensible rate covers it at 47 km/h next to a 2 m
## character, and it will look fast. The alternative is a world that takes
## twenty minutes to cross, which is the Cube World 2019 failure the plan
## names by name. Speed is the cheaper mistake.
const SPRINT_MULTIPLIER := 2.6

## For lining up a screenshot, or edging along a ledge.
const PRECISION_MULTIPLIER := 0.3

## Deliberately above Earth gravity. Real 9.8 makes a jump feel like it is
## happening underwater, because a game character's jump is much shorter than a
## real one and the arc has to be compressed to match.
const GRAVITY := 22.0
const JUMP_HEIGHT := 1.1

## How high a ledge the player walks up without jumping, in metres.
##
## This one number is the difference between voxel terrain being walkable and
## being infuriating. Blocks are 0.5 m, so ANY slope is a staircase of 0.5 m
## steps, and a capsule with no step logic stops dead at every one of them.
const MAX_STEP := 0.55

## How fast the body turns to face where it is going.
const TURN_SMOOTHING := 12.0

const MOUSE_SENSITIVITY := 0.0025
const PITCH_MIN_DEG := -70.0
const PITCH_MAX_DEG := 35.0

## Flight speed multiplier, so noclip is useful for crossing a 3 km world.
## Sprint multiplies it too, which is how you get across the map in a hurry.
const FLY_SPEED := 18.0

@onready var _pivot: Node3D = $CamPivot
@onready var _arm: SpringArm3D = $CamPivot/SpringArm3D
@onready var _camera: Camera3D = $CamPivot/SpringArm3D/Camera3D
## The character. NOT a capsule any more: the collider is still a capsule and
## always will be - hard rule 3, one collider for every race - but what you see
## is a CharacterView built from the saved CharacterDef. The model's feet are at
## y = 0 and the capsule's centre is at y = 1, and the two agree.
@onready var _view: CharacterView = $View

## Debug flight. A tool, not a mode - see docs/DESIGN.md. Tuning terrain
## without it is miserable, which is the entire reason it survives.
var noclip := false

## Steering for the traversal probe, in world space. Zero means "read the
## keyboard", which is every case except `--traverse`.
##
## A hook rather than synthesised key events: Input state is global and faking
## a held key would leak into the debug panel, the menu and anything else that
## polls it. This is one vector that one tool sets and nothing else reads.
var wish_override := Vector3.ZERO

## Held down by the traversal probe. Same reasoning as wish_override.
var sprint_override := false

## One-shot jump request from the traversal probe, cleared when it is used.
## Voxel terrain is a staircase and a player crossing it presses Space a lot;
## a probe that never jumps measures a world nobody plays in.
var jump_override := false

## A static pose, when something has asked for one. Scaffolding until the
## campfire owns sit and the death design owns downed - see the debug keys.
var pose := LocomotionState.POSE_NONE

var _yaw := 0.0
# The pivot's authored offset above the feet, read from the scene at _ready
# and then carried by hand - see _ready() for why it cannot stay a child.
var _pivot_offset := Vector3.ZERO
var _pitch := deg_to_rad(-15.0)


func _ready() -> void:
	_capture_mouse(true)
	# The character Marcel made, or the default human on a machine that has
	# never opened the creation screen. `--race` and friends override it for
	# one run - see CharacterDef.load_or_default().
	_view.build(CharacterDef.load_or_default())
	# This is the player's own character, so it is the one that has to get out
	# of the way when the camera ends up inside its head.
	_view.local = true
	# Terrain is a staircase of half-metre steps and the capsule must stay
	# glued to it going downhill, or walking down any slope turns into a
	# sequence of small hops.
	floor_snap_length = MAX_STEP
	floor_max_angle = deg_to_rad(55.0)
	# The arm casts from inside the player's own capsule, so without this it
	# collides with the player and jams the camera at zero distance.
	_arm.add_excluded_object(get_rid())

	# The camera pivot must NOT inherit the body's rotation.
	#
	# _face_movement() turns the body toward its travel direction every
	# frame. As a child, the pivot was dragged round with it, so the
	# camera's world yaw was body.rotation.y + _yaw - while
	# _wish_direction() rotated the input by _yaw alone. W therefore meant
	# "away from the camera" only while the body happened to face north,
	# and worse, it fed back: press W, the body turns, the camera swings
	# with it, so W now points somewhere else and the body turns again.
	# Holding one key made you curve.
	#
	# top_level makes the pivot's transform world-space, which is what
	# DESIGN.md asks for - the camera orbits freely, the body faces its own
	# travel, and the two do not talk to each other. Position is carried by
	# hand in _physics_process.
	_pivot_offset = _pivot.position
	_pivot.top_level = true
	_pivot.global_position = global_position + _pivot_offset


func _exit_tree() -> void:
	_capture_mouse(false)


## Where the camera is looking, used by anything that needs a facing.
func camera_yaw() -> float:
	return _yaw


func get_camera() -> Camera3D:
	return _camera


# --- Input ------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and _mouse_captured():
		_yaw -= event.relative.x * MOUSE_SENSITIVITY
		_pitch -= event.relative.y * MOUSE_SENSITIVITY
		_pitch = clampf(_pitch, deg_to_rad(PITCH_MIN_DEG), deg_to_rad(PITCH_MAX_DEG))
		_pivot.rotation.y = _yaw
		_arm.rotation.x = _pitch
		get_viewport().set_input_as_handled()
		return

	# Click back into the window after releasing the cursor - unless a debug
	# panel is what wanted it released, or the panel could never be clicked.
	if event is InputEventMouseButton and event.pressed and not _mouse_captured():
		if DebugHUD.ui_has_mouse:
			return
		_capture_mouse(true)
		get_viewport().set_input_as_handled()
		return

	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_F:
			_set_noclip(not noclip)
			get_viewport().set_input_as_handled()
			return
		if _pose_key(event.physical_keycode):
			get_viewport().set_input_as_handled()
			return

	if event.is_action_pressed("ui_cancel") and _mouse_captured():
		# First Escape frees the cursor and is consumed here. A second one is
		# left unhandled, so Game sees it and leaves the session.
		_capture_mouse(false)
		get_viewport().set_input_as_handled()


func _set_noclip(on: bool) -> void:
	noclip = on
	velocity = Vector3.ZERO
	# Turning the collider off is what makes it noclip rather than merely
	# flight. Without it you would hover, but still be stopped by hillsides.
	$Collider.disabled = on
	_view.visible = not on
	print("[Player] noclip %s" % ("on" if on else "off"))


# --- Movement ---------------------------------------------------------------

func _physics_process(delta: float) -> void:
	# Carried by hand because the pivot is top_level. One frame behind the
	# body, which the spring arm smooths away.
	_pivot.global_position = global_position + _pivot_offset

	if _wave_left > 0.0:
		_wave_left -= delta
		if _wave_left <= 0.0 and pose == LocomotionState.POSE_WAVE:
			pose = LocomotionState.POSE_NONE

	if not _mouse_captured() and wish_override == Vector3.ZERO:
		# Cursor released means a menu or a panel has focus. Walking on while
		# someone types a seed into a text field is not helpful.
		#
		# The traversal probe is exempt: it runs headless, where the mouse is
		# never captured, and without the exemption it would measure how long
		# the world takes to cross while standing still.
		if not noclip:
			velocity.x = 0.0
			velocity.z = 0.0
			velocity.y -= GRAVITY * delta
			move_and_slide()
		_publish_locomotion()
		return

	if noclip:
		_fly(delta)
	else:
		_walk(delta)
	_publish_locomotion()


func _walk(delta: float) -> void:
	var wish := _wish_direction()

	velocity.x = wish.x * WALK_SPEED * _speed_multiplier()
	velocity.z = wish.z * WALK_SPEED * _speed_multiplier()

	if is_on_floor():
		if jump_override:
			jump_override = false
			velocity.y = sqrt(2.0 * GRAVITY * JUMP_HEIGHT)
		elif Input.is_physical_key_pressed(KEY_SPACE):
			# v = sqrt(2gh) - the speed you need to leave the ground at to
			# reach exactly JUMP_HEIGHT, rather than a number picked by feel
			# that changes meaning the moment gravity is retuned.
			velocity.y = sqrt(2.0 * GRAVITY * JUMP_HEIGHT)
	else:
		velocity.y -= GRAVITY * delta

	_step_up(delta)
	move_and_slide()
	_face_movement(wish, delta)


## Walk up a ledge instead of stopping dead at it.
##
## Godot's CharacterBody3D has no stair stepping, and voxel terrain is nothing
## but stairs - every slope is a run of 0.5 m steps. The test is deliberately
## the whole thing: if the move is blocked from here but the SAME move from
## MAX_STEP higher is clear, then what blocked us was a step and not a wall,
## and we can rise onto it. A real wall blocks both, so this cannot be used to
## climb one.
func _step_up(delta: float) -> void:
	if not is_on_floor():
		return
	var motion := Vector3(velocity.x, 0.0, velocity.z) * delta
	if motion.length_squared() < 0.000001:
		return
	if not test_move(global_transform, motion):
		return  # nothing in the way

	var raised := global_transform.translated(Vector3.UP * MAX_STEP)
	if test_move(raised, motion):
		return  # still blocked from up there, so it is a wall

	# floor_snap_length pulls us back down onto the step's surface on the next
	# move_and_slide, so this does not leave the player floating.
	global_position.y += MAX_STEP


func _fly(delta: float) -> void:
	var wish := _wish_direction()
	var dir := Vector3(wish.x, 0.0, wish.z)
	# Vertical is along the WORLD up axis, not the camera's, so looking down
	# does not turn Space into "fly forwards".
	if Input.is_physical_key_pressed(KEY_SPACE):
		dir += Vector3.UP
	if Input.is_physical_key_pressed(KEY_CTRL):
		dir -= Vector3.UP
	if dir != Vector3.ZERO:
		dir = dir.normalized()
	velocity = dir * FLY_SPEED * _speed_multiplier()
	global_position += velocity * delta


## Desired horizontal direction, in world space, relative to where the camera
## is looking. Normalised so diagonals are not sqrt(2) times faster than
## straight lines.
func _wish_direction() -> Vector3:
	if wish_override != Vector3.ZERO:
		return wish_override.normalized()
	var input := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_W):
		input.y -= 1.0
	if Input.is_physical_key_pressed(KEY_S):
		input.y += 1.0
	if Input.is_physical_key_pressed(KEY_A):
		input.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D):
		input.x += 1.0
	if input == Vector2.ZERO:
		return Vector3.ZERO
	input = input.normalized()
	# Rotate the input into the camera's frame, so W is always "away from the
	# camera" however the player has orbited it.
	return Vector3(input.x, 0.0, input.y).rotated(Vector3.UP, _yaw)


## Turn the body toward where it is moving, Cube World style: the camera orbits
## freely and the character faces its own travel, rather than the character
## being welded to the camera's facing.
func _face_movement(wish: Vector3, delta: float) -> void:
	if wish.length_squared() < 0.01:
		return
	# NEGATED, and this was wrong for the whole of terrain v1.
	#
	# atan2(wish.x, wish.z) is the yaw that points local +Z along the travel
	# direction. Godot's forward is -Z, so that yaw pointed the character
	# BACKWARDS - exactly 180 degrees out, every frame, in every direction.
	#
	# It was invisible because Body is a CapsuleMesh, which is rotationally
	# symmetric and looks identical either way round. It would have become very
	# visible indeed the first time a character with a face on it arrived.
	#
	# The claim is checked rather than assumed: see the facing self-test, which
	# asserts against Godot's own Vector3.FORWARD that this yaw sends forward
	# along the wish direction. A visual check with a marker mesh was the other
	# option and is a weaker one - it confirms the same identity by eye, and
	# only for the handful of directions you happen to try.
	var target := atan2(-wish.x, -wish.z)
	# Frame-rate independent smoothing - see RemotePlayer for why this shape
	# rather than lerp(current, target, 0.1).
	rotation.y = lerp_angle(rotation.y, target, 1.0 - exp(-TURN_SMOOTHING * delta))


## Everything the animator is allowed to know about what this body is doing.
##
## Built fresh every frame rather than mutated, because the same object is
## handed to the view and read next frame, and a struct that two things hold a
## reference to is a struct that changes under one of them.
##
## THIS IS THE SEAM the host-authoritative rewrite goes through. When the host
## starts simulating players, it fills a LocomotionState from its own table and
## nothing in the animation system changes - see LocomotionState.
func locomotion_state() -> LocomotionState:
	var st := LocomotionState.new()
	st.speed = Vector2(velocity.x, velocity.z).length()
	st.vertical = velocity.y
	st.grounded = is_on_floor()
	st.mode = _locomotion_mode()
	# Not `vertical > 0`: the two differ for one frame at the apex, and a
	# legs-tucked pose that flickers there is worse than one that commits.
	st.rising = not st.grounded and velocity.y > 0.5
	st.pose = pose
	st.look_yaw = _yaw
	st.look_pitch = _pitch
	st.noclip = noclip
	return st


func _publish_locomotion() -> void:
	_view.set_state(locomotion_state())


## Which of the three gaits this frame is in. THE SAME PRECEDENCE as
## _speed_multiplier - sprint first, so holding both keys is not ambiguous -
## and derived from the same inputs, so the animation can never disagree with
## the speed it is animating.
func _locomotion_mode() -> int:
	if sprint_override or Input.is_physical_key_pressed(KEY_SHIFT):
		return LocomotionState.MODE_SPRINT
	if Input.is_physical_key_pressed(KEY_ALT):
		return LocomotionState.MODE_PRECISION
	return LocomotionState.MODE_WALK


## SCAFFOLDING, AND IT SAYS SO. X sits, B goes down, V waves.
##
## THE CAMPFIRE PLAN OWNS `sit` AND THE DEATH DESIGN OWNS `downed`. Neither
## system exists yet, and a pose with nothing to trigger it is a pose nobody
## finds the bugs in - so these three keys exist to drive the state byte until
## the systems that own them arrive, and they are the first thing those plans
## should delete.
##
## Local only in the sense that the KEY is local; the pose itself rides the
## state byte from Stage 6, so a friend sees you sit.
func _pose_key(keycode: int) -> bool:
	match keycode:
		KEY_X:
			pose = LocomotionState.POSE_NONE if pose == LocomotionState.POSE_SIT \
				else LocomotionState.POSE_SIT
		KEY_B:
			pose = LocomotionState.POSE_NONE if pose == LocomotionState.POSE_DOWNED \
				else LocomotionState.POSE_DOWNED
		KEY_V:
			# The wave ends by itself, so it is a press rather than a toggle.
			pose = LocomotionState.POSE_WAVE
			_wave_left = Animator.WAVE_SECONDS
		_:
			return false
	print("[Player] pose %d" % pose)
	return true


## Counts the wave down, because the wave is the one pose that stops on its
## own and the animator must not be the thing that decides a player's state.
var _wave_left := 0.0


## Multiplier applied to the base speed this frame. Applies to walking and to
## flight both.
##
## This was a TODO(marcel) exercise and terrain v2's plan claims it explicitly -
## the single exception it makes to its own rule about leaving the exercises
## alone - because a 3 km world without sprint is the traversal failure the
## whole stage exists to avoid.
##
## Sprint is checked FIRST so that holding both keys is not ambiguous.
func _speed_multiplier() -> float:
	if sprint_override:
		return SPRINT_MULTIPLIER
	if Input.is_physical_key_pressed(KEY_SHIFT):
		return SPRINT_MULTIPLIER
	if Input.is_physical_key_pressed(KEY_ALT):
		return PRECISION_MULTIPLIER
	return 1.0


func _mouse_captured() -> bool:
	return Input.mouse_mode == Input.MOUSE_MODE_CAPTURED


func _capture_mouse(on: bool) -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if on else Input.MOUSE_MODE_VISIBLE
