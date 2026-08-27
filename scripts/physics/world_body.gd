class_name WorldBody
extends RigidBody3D

## A thing in the world that moves when you push it. HOST ONLY.
##
## Clients have `WorldBodyView` instead - the same mesh, no simulation, moved by
## whatever the host's table says. That asymmetry is hard rule 4 and it is the
## same rule as everything else in this codebase: one authority, and a client's
## push is an INPUT, not a force. There is no RPC that moves a body, and the
## reason to keep it that way is that "move this rock to here" is the single
## most useful message a cheat could send.
##
## ASLEEP THE MOMENT IT IS BUILT, and that is what makes a few hundred of them
## affordable. A sleeping RigidBody3D is out of the solver entirely - Jolt keeps
## it in the broadphase and does nothing else with it - so a disc full of
## boulders costs a broadphase entry each and no integration at all until
## somebody leans on one. Stage 9's physics probe could not measure this because
## there were no dynamic bodies to count; this is what it deferred.
##
## THE SHAPE IS A CONVEX HULL OF THE MODEL'S OWN VOXELS, built once per kind and
## shared by every body of that kind. It matters that it is the model's voxels
## and not a sphere: a boulder that rolls like a marble reads as a ball, and the
## flat facets a chewed blob gives you are what makes it settle in a pose and
## stay there.

## The body's stable id - FloraPlacement.identity() of the decoration it was
## promoted from, so every peer names the same rock the same thing without
## anybody sending a list.
var id := 0
var kind := 0

## Where it was built. A body that has never moved regenerates identically, so
## it does not need storing when its column unloads; one that has moved does.
var rest_pos := Vector3.ZERO
var rest_yaw := 0.0

## Set the first time this body moves under its own steam. See BodyField.
var moved := false

static var _shapes := {}


func setup(p_id: int, p_kind: int, pos: Vector3, yaw: float, scale_f: float,
		block_size: float) -> void:
	id = p_id
	kind = p_kind
	rest_pos = pos
	rest_yaw = yaw
	name = "Body_%d" % p_id

	var row := BodyTable.row(kind)
	mass = row["mass"]
	linear_damp = row["linear_damp"]
	angular_damp = row["angular_damp"]
	# Jolt's, not ours. Rolling, settling and going back to sleep are exactly
	# the things a physics engine is for, and a hand-rolled version of any of
	# them would be worse and would also have to be replicated.
	can_sleep = true

	var shape := CollisionShape3D.new()
	shape.shape = shape_for(kind, block_size)
	add_child(shape)

	global_position = pos
	rotation.y = yaw
	# The scale the decoration would have been drawn at is applied to the MESH
	# only, never to the body. Scaling a physics body in Godot is a documented
	# way to get wrong contacts, and the ±15% a boulder varies by is not worth
	# the inertia tensor being a lie.
	var mesh := MeshInstance3D.new()
	mesh.mesh = FloraModels.mesh_for(row["model"], block_size)
	mesh.material_override = FloraModels.material_for(row["model"])
	mesh.scale = Vector3.ONE * scale_f
	add_child(mesh)


## One shape per kind, built once and shared by every body of that kind.
##
## Godot computes the hull from the point cloud, so feeding it every voxel
## corner is wasteful but correct, and it happens twice in a session. What it
## must NOT be given is voxel CENTRES - the hull would then be inset by half a
## voxel all round, and a boulder would sit visibly buried in the ground it is
## resting on.
static func shape_for(kind: int, block_size: float) -> ConvexPolygonShape3D:
	var key := "%d|%.4f" % [kind, block_size]
	var got: ConvexPolygonShape3D = _shapes.get(key)
	if got != null:
		return got
	var row := BodyTable.row(kind)
	var model: int = row["model"]
	var unit := block_size / float(FloraModels.voxels_per_block(model))
	var points := PackedVector3Array()
	for v in FloraModels.voxels_for(model):
		var base := Vector3(float(v[0]), float(v[1]), float(v[2])) * unit
		# The eight corners, so the hull encloses the voxel rather than its
		# middle. See the note above.
		for cz in 2:
			for cy in 2:
				for cx in 2:
					points.append(base + Vector3(
						float(cx), float(cy), float(cz)) * unit)
	got = ConvexPolygonShape3D.new()
	got.points = points
	_shapes[key] = got
	return got


## Wake this body and hit it.
##
## THE WAKE IS NOT OPTIONAL, and it is the whole reason this is a method rather
## than a call to apply_central_impulse() at each site. A sleeping body under
## Jolt is out of the solver, and an impulse applied to one is simply
## discarded - no error, no warning, and the rock does not move. The body probe
## spent a run on it: the shove reported success, the body reported
## `sleeping`, and every assertion downstream passed because a rock that never
## moved trivially ends where it started.
##
## Stage 12's push comes through here too, for the same reason.
func shove(impulse: Vector3) -> void:
	sleeping = false
	apply_central_impulse(impulse)


## The row this body contributes to the authoritative table.
func to_row() -> Array:
	return [global_position, quaternion]
