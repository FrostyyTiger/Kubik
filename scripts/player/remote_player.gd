class_name RemotePlayer
extends Node3D

## A capsule standing in for another player. Purely visual - it never decides
## anything, it just follows the positions the host sends.

## Higher = snappier, lower = smoother but laggier looking.
const SMOOTHING := 15.0

var peer_id := 0

var _target_position := Vector3.ZERO
var _target_yaw := 0.0
var _has_target := false

@onready var _body: MeshInstance3D = $Body
@onready var _nametag: Label3D = $Nametag


## Call before add_child(). @onready vars do not exist yet at this point, so
## this only records the id; the visuals are set up in _ready().
func setup(p_peer_id: int) -> void:
	peer_id = p_peer_id
	name = "Player%d" % p_peer_id


func _ready() -> void:
	var c := color_for_peer(peer_id)
	# A material per player, since each one is a different colour. Fine for a
	# handful of players; a shared material with per-instance colour would be
	# the move if we ever had hundreds.
	var mat := StandardMaterial3D.new()
	mat.albedo_color = c
	_body.material_override = mat
	_nametag.text = "peer %d" % peer_id
	_nametag.modulate = c


func set_target(pos: Vector3, yaw: float) -> void:
	_target_position = pos
	_target_yaw = yaw
	if not _has_target:
		# First update: snap, do not glide in from the world origin.
		_has_target = true
		position = pos
		rotation.y = yaw


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
