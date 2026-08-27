class_name WorldBodyView
extends Node3D

## What a body looks like on a machine that is not simulating it.
##
## The same mesh as `WorldBody`, and nothing else: no shape, no rigid body, no
## rules. It is moved by the host's table and interpolated between packets,
## exactly as `RemotePlayer` is, and for the same reason - the table arrives at
## the sync rate and the eye wants sixty.
##
## IT IS ALSO WHAT THE HOST'S OWN CLIENTS SEE OF A ROCK THAT HAS NEVER MOVED,
## which is the case that makes this cheap. A body at rest is not in the table
## at all: the client built it at its rest pose from the same seeded promotion
## the host used, and a rock that nobody has touched needs no packets ever. The
## first time one is pushed it starts appearing in the table, and this node
## starts being told where to be.

var id := 0
var kind := 0

## Where the table last said it was. Null target means "nobody has moved this",
## and the view simply stays where it was built.
var _target_pos := Vector3.ZERO
var _target_rot := Quaternion.IDENTITY
var _have_target := false

## Metres per second and radians per second of catch-up. Fast enough that a
## rolling boulder does not lag visibly behind its own dust, slow enough that a
## dropped packet is a smooth glide rather than a jump.
const FOLLOW := 12.0


func setup(p_id: int, p_kind: int, pos: Vector3, yaw: float, scale_f: float,
		block_size: float) -> void:
	id = p_id
	kind = p_kind
	name = "BodyView_%d" % p_id
	var row := BodyTable.row(kind)
	var mesh := MeshInstance3D.new()
	mesh.mesh = FloraModels.mesh_for(row["model"], block_size)
	mesh.material_override = FloraModels.material_for(row["model"])
	mesh.scale = Vector3.ONE * scale_f
	add_child(mesh)
	global_position = pos
	rotation.y = yaw


## A row from the host's table.
func set_target(pos: Vector3, rot: Quaternion) -> void:
	_target_pos = pos
	_target_rot = rot
	if not _have_target:
		# THE FIRST ONE IS A TELEPORT, not a glide. It means "this rock is not
		# where you built it" - it was pushed while this column was unloaded,
		# or before this client joined - and easing into that would drag the
		# mesh across the intervening ground in full view.
		_have_target = true
		global_position = pos
		quaternion = rot


func _process(delta: float) -> void:
	if not _have_target:
		return
	# Frame-rate independent smoothing, the same shape RemotePlayer uses.
	var t := 1.0 - exp(-FOLLOW * delta)
	global_position = global_position.lerp(_target_pos, t)
	quaternion = quaternion.slerp(_target_rot, t)
