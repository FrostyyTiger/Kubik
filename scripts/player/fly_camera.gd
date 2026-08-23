class_name FlyCamera
extends Camera3D

## Free-flying debug camera. Noclip, no gravity, no collision.
##
## This is NOT the player. It is a tool for looking at the world while we build
## it. The real player will be a physics body whose INPUT goes to the host, and
## whose position comes back as authoritative state - see docs in the README.

const BASE_SPEED := 14.0
const SPRINT_MULTIPLIER := 4.0
const PRECISION_MULTIPLIER := 0.25
const MOUSE_SENSITIVITY := 0.0025

## Just short of 90. At exactly 90 the view direction lines up with the yaw
## axis and the camera flips over as you cross it.
const PITCH_LIMIT_DEG := 89.0

## Yaw and pitch are kept as plain numbers and the rotation is rebuilt from
## them every time. Adding deltas straight onto `rotation` accumulates roll,
## and the camera slowly tumbles - a beginner bug worth never writing once.
var _yaw := 0.0
var _pitch := 0.0


func _ready() -> void:
	# Start from whatever the scene author set, so the camera does not snap.
	_yaw = rotation.y
	_pitch = rotation.x
	_capture_mouse(true)


func _exit_tree() -> void:
	# Leaving the game with a captured cursor makes the menu unusable.
	_capture_mouse(false)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and _mouse_captured():
		_yaw -= event.relative.x * MOUSE_SENSITIVITY
		_pitch -= event.relative.y * MOUSE_SENSITIVITY
		var limit := deg_to_rad(PITCH_LIMIT_DEG)
		_pitch = clampf(_pitch, -limit, limit)
		# Godot's euler order is YXZ, so (pitch, yaw, 0) means "yaw, then pitch
		# within the yawed frame" - FPS behaviour, and roll stays exactly zero.
		rotation = Vector3(_pitch, _yaw, 0.0)
		get_viewport().set_input_as_handled()
		return

	# Click back into the window after releasing the cursor - unless a debug
	# panel is what wanted the cursor released. Without that check, clicking a
	# tuning spinbox would grab the mouse and the panel could not be used at
	# all.
	if event is InputEventMouseButton and event.pressed and not _mouse_captured():
		if DebugHUD.ui_has_mouse:
			return
		_capture_mouse(true)
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("ui_cancel") and _mouse_captured():
		# First Escape frees the cursor and is consumed here. A second one is
		# left unhandled, so Game sees it and leaves the session.
		_capture_mouse(false)
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if not _mouse_captured():
		return

	# Physical keycodes are position-based: WASD stays where WASD is, whatever
	# keyboard layout the other player has. Rebindable InputMap actions come
	# when we build the real player.
	var b := transform.basis
	var dir := Vector3.ZERO
	if Input.is_physical_key_pressed(KEY_W):
		dir -= b.z
	if Input.is_physical_key_pressed(KEY_S):
		dir += b.z
	if Input.is_physical_key_pressed(KEY_A):
		dir -= b.x
	if Input.is_physical_key_pressed(KEY_D):
		dir += b.x
	# Vertical is along the WORLD up axis, not the camera's, so looking down
	# does not turn Space into "fly forwards".
	if Input.is_physical_key_pressed(KEY_SPACE):
		dir += Vector3.UP
	if Input.is_physical_key_pressed(KEY_CTRL):
		dir -= Vector3.UP

	if dir == Vector3.ZERO:
		return
	# Normalise so diagonals are not sqrt(2) times faster than straight lines.
	position += dir.normalized() * BASE_SPEED * _speed_multiplier() * delta


## Multiplier applied to BASE_SPEED this frame.
func _speed_multiplier() -> float:
	# TODO(marcel): flying at one speed gets old fast when the world is 80
	# blocks across.
	#
	#   - Shift held -> SPRINT_MULTIPLIER
	#   - Alt held   -> PRECISION_MULTIPLIER  (for lining up a screenshot)
	#   - neither    -> 1.0
	#
	# Hint: Input.is_physical_key_pressed(KEY_SHIFT) and KEY_ALT. Check sprint
	# first so that holding both is not ambiguous. Three lines, no state.
	return 1.0


func _mouse_captured() -> bool:
	return Input.mouse_mode == Input.MOUSE_MODE_CAPTURED


func _capture_mouse(on: bool) -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if on else Input.MOUSE_MODE_VISIBLE
