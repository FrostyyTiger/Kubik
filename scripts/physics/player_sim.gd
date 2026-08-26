class_name PlayerSim
extends CharacterBody3D

## The host's body for ONE remote peer. Invisible, and the only thing in the
## session that is allowed to say where that peer is.
##
## WHY IT EXISTS (world feel v1 Stage 10). Until now a client ran its own
## movement and sent the host the answer, so "where is peer 3" was whatever
## peer 3 said it was. This is the other half of the fix: the client sends what
## it WANTS, and this steps it through exactly the same `Locomotion.step` the
## client is predicting with. What ends up in the authoritative table is what
## this body did, not what a packet claimed.
##
## IT IS NOT A PLAYER. No camera, no mesh, no CharacterView, no appearance -
## the peer's appearance is a separate reliable channel that never comes near
## this, and every other client already builds the visible capsule from the
## table. This is the physics half only, which is why it is a script with a
## shape rather than a scene.
##
## THE SHAPE IS BUILT IN CODE, from Locomotion's constants rather than from
## player.tscn. A scene would have been fewer lines and would also have been a
## second place for the capsule to be edited - and a host capsule half a
## centimetre wider than the client's is a body that catches on doorways only
## on one machine.

## How long an input is honoured after it arrives, in milliseconds.
##
## THIRTY HZ WITH NOTHING TO SPARE. Inputs arrive every 33 ms on an unreliable
## channel, so one dropped packet is normal and must not read as "let go of
## everything" - a stutter of one frame per lost packet is far worse than
## holding W for an extra 30 ms. 200 ms is six packets: long enough that a bad
## moment on the wire is invisible, short enough that a client that actually
## stops does not keep running for a noticeable distance.
const HOLD_MS := 200

## The last thing this peer asked for.
var _input := Locomotion.Intent.new()
var _input_at := 0

## True once the first input has landed. Before that this body has never been
## told anything and holds still where the host spawned it.
var _heard := false


func setup(peer_id: int) -> void:
	name = "PlayerSim_%d" % peer_id
	Locomotion.configure_body(self)
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = Locomotion.CAPSULE_RADIUS
	capsule.height = Locomotion.CAPSULE_HEIGHT
	shape.shape = capsule
	add_child(shape)


## A packet landed. Nothing is validated here beyond what the struct's own
## accessors clamp, because there is nothing in an INPUT to cheat with: the
## worst a client can claim is that it is holding every key at once, which is
## a thing it could do with its hands.
func receive(input: Locomotion.Intent) -> void:
	_input = input
	_input_at = Time.get_ticks_msec()
	_heard = true


func _physics_process(delta: float) -> void:
	if not _heard:
		return
	var input := _effective_input()
	Locomotion.step(self, input, delta)
	# The table carries body yaw as well as look yaw, so the host has to turn
	# this body the same way the client turns its own.
	rotation.y = Locomotion.face_yaw(rotation.y, input.wish, delta)


## The input as of RIGHT NOW, which is not always the input that arrived.
##
## After HOLD_MS the wish is zeroed and the bits are dropped - but the body is
## still stepped, so a peer whose connection died mid-jump finishes the arc and
## lands rather than hanging in the air. That distinction is the whole reason
## this returns a modified input instead of skipping the step.
func _effective_input() -> Locomotion.Intent:
	if Time.get_ticks_msec() - _input_at <= HOLD_MS:
		return _input
	var stale := Locomotion.Intent.new()
	stale.look = _input.look
	# Noclip is kept, because a peer that was flying when the wire went quiet
	# would otherwise start falling from wherever it was - possibly from
	# several hundred metres up, and through terrain nobody has streamed.
	if _input.flying():
		stale.bits = Locomotion.BIT_FLY
	return stale


## What goes in the table. The same seam `player.gd` fills from its own body -
## LocomotionState's own comment names this case - so the animator on every
## other machine cannot tell a host-simulated peer from a local player.
func locomotion_state() -> LocomotionState:
	var st := LocomotionState.new()
	st.speed = Vector2(velocity.x, velocity.z).length()
	st.vertical = velocity.y
	st.grounded = is_on_floor()
	var input := _effective_input()
	if input.sprinting():
		st.mode = LocomotionState.MODE_SPRINT
	elif input.precision():
		st.mode = LocomotionState.MODE_PRECISION
	else:
		st.mode = LocomotionState.MODE_WALK
	st.rising = not st.grounded and velocity.y > 0.5
	# Relayed, not derived - see Locomotion.POSE_SHIFT.
	st.pose = input.pose()
	st.look_yaw = input.look
	st.noclip = input.flying()
	return st
