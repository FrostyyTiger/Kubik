class_name RemotePlayer
extends Node3D

## Another player. Purely visual - it never decides anything, it follows the
## table the host sends.
##
## It is now a CHARACTER rather than a capsule, and that changes what arrives
## rather than what this class is for. The position and yaw are smoothed
## exactly as they were; velocity, a state byte and a look yaw go straight into
## a LocomotionState, and the animator does the rest - so a friend walking,
## sprinting, jumping and sitting is the same code path as the local player,
## driven from a different source. That was the point of LocomotionState.
##
## THE BODY IS NEVER TINTED, AND THE PEER COLOUR LIVES ON THE PARTY ICON.
##
## Before the character redesign every player was a differently-coloured
## capsule, and the colour was the only way to tell two of them apart. Now the
## character is - so tinting a dwarf purple would throw away the appearance the
## player chose, and that reasoning is unchanged. What changed in ui v1 Stage 5
## is where the colour went: it used to outline a floating Label3D over this
## body's head, and THAT TAG IS GONE (ui-v1.md, decision 5 - Marcel: it reads
## Minecrafty and breaks immersion).
##
## In-world identity is now silhouette, palette and the character the player
## built. The name and the hue are on the party icon at the edge of the HUD,
## which is a screen-space answer to a screen-space question - "who else is
## here" - rather than a label pinned to a body in the world. color_for_peer()
## stays exactly where it is, static and deterministic, because the icon needs
## the same colour this file always derived and neither machine has ever sent
## a byte about it.

## Higher = snappier, lower = smoother but laggier looking.
const SMOOTHING := 15.0

var peer_id := 0

var _target_position := Vector3.ZERO
var _target_yaw := 0.0
var _has_target := false

## The appearance this view was last built from. Eight bytes compared per sync
## tick is free; rebuilding a rig twenty times a second is not.
var _built_from := PackedByteArray()

@onready var _view: CharacterView = $View

## What the host says this peer is called. Stored rather than displayed: the
## party icons read it, and nothing in the world does.
var display_name := ""


## Call before add_child(). @onready vars do not exist yet at this point, so
## this only records the id; the visuals are set up in _ready().
func setup(p_peer_id: int) -> void:
	peer_id = p_peer_id
	name = "Player%d" % p_peer_id


func _ready() -> void:
	if display_name.is_empty():
		display_name = "peer %d" % peer_id
	# A remote character is never the one the close-camera hide applies to.
	_view.local = false
	# The default human until an appearance arrives. A REMOTE VIEW MUST NEVER
	# FAIL TO BUILD: a client's row can exist before its announce does, and a
	# player who is briefly the wrong character is a much smaller problem than
	# a player who is briefly nothing at all.
	_apply_appearance(CharacterDef.new().to_bytes())


## One row of the host's table, as sent.
##
## Everything is optional except the position: a host running an older build,
## or a row written before that peer announced itself, still has to produce a
## character standing in the right place.
func set_target(st: Dictionary) -> void:
	_target_position = st.get("p", _target_position)
	_target_yaw = st.get("y", _target_yaw)
	if not _has_target:
		# First update: snap, do not glide in from the world origin.
		_has_target = true
		position = _target_position
		rotation.y = _target_yaw

	# NAME BEFORE APPEARANCE. The two arrive in the same row and the order
	# does not matter to the player, but _apply_appearance logs who this peer
	# turned out to be, and doing it the other way round made every one of
	# those lines say "unnamed" - the name does not ride in the appearance
	# bytes, it is a separate field.
	if st.has("n"):
		display_name = st["n"]
	if st.has("a"):
		_apply_appearance(st["a"])

	var state := LocomotionState.new()
	var velocity: Vector3 = st.get("v", Vector3.ZERO)
	state.speed = Vector2(velocity.x, velocity.z).length()
	state.vertical = velocity.y
	state.from_state_byte(int(st.get("s", 1)))
	state.look_yaw = st.get("l", _target_yaw)
	_view.set_state(state)


## Rebuild the character, but only when the bytes actually changed.
func _apply_appearance(bytes: PackedByteArray) -> void:
	if bytes == _built_from:
		return
	_built_from = bytes
	var def := CharacterDef.from_bytes(bytes)
	_view.build(def)
	print("[RemotePlayer] peer %d (%s) is a %s %s" % [
		peer_id, display_name, Races.BUILD_NAMES[def.build], Races.name_of(def.race)])


func _process(delta: float) -> void:
	if not _has_target:
		return
	# Frame-rate independent exponential smoothing.
	#
	# The tempting version, lerp(current, target, 0.1), moves 10% of the way
	# per FRAME - so it is twice as fast at 120 fps as at 60, and the game
	# feels different on two machines. 1 - exp(-k*dt) moves 10% per equal
	# amount of TIME regardless of frame rate.
	var t := 1.0 - exp(-SMOOTHING * delta)
	position = position.lerp(_target_position, t)
	rotation.y = lerp_angle(rotation.y, _target_yaw, t)


## Deterministic colour per peer, so both machines paint the same player the
## same way without sending a single byte about it.
static func color_for_peer(p_peer_id: int) -> Color:
	# Stepping the hue by the golden ratio spreads consecutive ids as far apart
	# on the colour wheel as possible, so nobody gets near-identical colours.
	var hue := fposmod(float(p_peer_id) * 0.61803398875, 1.0)
	return Color.from_hsv(hue, 0.65, 0.95)
