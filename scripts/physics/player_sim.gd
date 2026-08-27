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
## A dropped packet must not read as "let go of everything": a stutter of one
## tick per lost packet is far worse than holding W for an extra fraction of a
## second. So the last input is held, and the only question is for how long.
##
## IT WAS 200 MS - six packets at the 30 Hz the plan asks for - AND THAT WAS
## THE WRONG UNIT. The interval between packets is not the send RATE, it is the
## SENDER'S FRAME TIME, and they are the same number only on a machine with
## frames to spare. Under the pair probe, with two engines on one box, the
## client managed seven sends a second and the host's own frames ran to 250 ms.
## Every physics tick therefore saw an input older than 200 ms and fell back to
## the stale path, so a peer sprinting flat out was simulated as a peer
## standing still - with a `wish (1.0, 0.0)` sitting right there in `_input`,
## which is what made it look like the movement step was broken rather than the
## window.
##
## 500 ms is ten packets at 20 Hz. It is long enough that no plausible hitch on
## either side reaches it, and short enough that a peer who really has gone
## quiet stops within half a second - nothing anybody will see. The number that
## must not be exceeded is "how far a held input can carry a body somewhere it
## should not be", and at 13 m/s that is 6.5 m.
const HOLD_MS := 500

## ...AND IT IS A FLOOR, NOT THE WHOLE ANSWER.
##
## A host only hears from a peer when it polls, and it polls once per frame. If
## its own frames are 570 ms long - which is what this box does with two
## engines running, measured - then every input is over 500 ms old by the time
## physics looks at it, and a peer sprinting flat out is simulated as standing
## still. The host is not detecting a quiet peer; it is detecting itself.
##
## So the window is at least this many of the host's own frames. A host cannot
## honestly call a peer silent in less time than it takes to look twice.
##
## This matters on a real machine too, just less often: a host that hitches for
## 300 ms while loading a chunk should not stop every peer in the session dead
## for the duration.
const HOLD_FRAMES := 3.0


## The window as it applies right now.
static func hold_ms() -> float:
	var fps := maxf(Engine.get_frames_per_second(), 1.0)
	return maxf(float(HOLD_MS), HOLD_FRAMES * 1000.0 / fps)

## The last thing this peer asked for.
var _input := Locomotion.Intent.new()
var _input_at := 0

## True once the first input has landed. Before that this body has never been
## told anything and holds still where the host spawned it.
var _heard := false

## The surface zone under this peer, set by Game once a sync tick. The host has
## to know what a remote body is standing on for the same reason the client
## does - it is running the same step - and the client's own prediction uses
## its own lookup of the same world.
var ground_zone := -1

## How many input packets have landed, how many times this body has been
## stepped, and the speed the last input asked for. Read by the pair probe -
## see debug_line().
var packets := 0
var ticks := 0
var want_speed := 0.0

## Ticks that ran on a held-then-expired input. Nonzero in normal play is
## fine; consistently nonzero means HOLD_MS is shorter than the real packet
## interval, which is the failure described above.
var stale_ticks := 0

## How old the input was when it was last used. The measurement HOLD_MS and
## HOLD_FRAMES have to be set from - see hold_ms().
var age_last := 0


func setup(peer_id: int) -> void:
	name = "PlayerSim_%d" % peer_id
	Locomotion.configure_body(self)
	add_child(Locomotion.make_collider())


## A packet landed. Nothing is validated here beyond what the struct's own
## accessors clamp, because there is nothing in an INPUT to cheat with: the
## worst a client can claim is that it is holding every key at once, which is
## a thing it could do with its hands.
func receive(input: Locomotion.Intent) -> void:
	_input = input
	_input_at = Time.get_ticks_msec()
	_heard = true
	packets += 1


func _physics_process(delta: float) -> void:
	if not _heard:
		return
	ticks += 1
	var input := _effective_input()
	want_speed = Locomotion.WALK_SPEED * Locomotion.speed_multiplier(input)
	Locomotion.step(self, input, delta, ground_zone)
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
	var age := Time.get_ticks_msec() - _input_at
	age_last = age
	if float(age) <= hold_ms():
		return _input
	stale_ticks += 1
	var stale := Locomotion.Intent.new()
	stale.look = _input.look
	# Noclip is kept, because a peer that was flying when the wire went quiet
	# would otherwise start falling from wherever it was - possibly from
	# several hundred metres up, and through terrain nobody has streamed.
	if _input.flying():
		stale.bits = Locomotion.BIT_FLY
	return stale


## Everything about this body that the pair probe's per-second line needs, and
## every field of it earned its place during Stage 10's debugging.
##
## "The peer is not moving" turned out to have FOUR distinct causes over six
## runs, and from the outside they are indistinguishable:
##
##   no packets arriving          the client had not finished generating its
##                                own world, so nothing it sent got out
##   packets arriving, wish zero  the client was not driving yet
##   wish right, no ticks         the body was never stepped
##   wish right, ticks, vel 0     the body was stuck - the capsule was buried
##                                because its shape sat at the origin
##
## Each of those took a run to distinguish, and each run is nine minutes. The
## line is longer than a debug line usually deserves for exactly that reason.
func debug_line() -> String:
	if not _heard:
		return "nothing heard"
	var hit := "none"
	if get_slide_collision_count() > 0:
		var names := []
		for i in get_slide_collision_count():
			var c := get_slide_collision(i)
			var o = c.get_collider()
			names.append("%s@%s n%s" % [
				o.name if o != null else "?",
				c.get_position().snapped(Vector3.ONE * 0.1),
				c.get_normal().snapped(Vector3.ONE * 0.1)])
		hit = ", ".join(names)
	return "wish %s bits %d, %dpk, %dt (%d stale), age %d ms of %d, want %.1f, vel %.1f/%.1f, floor %s, hit %s" % [
		_input.wish, _input.bits, packets,
		ticks, stale_ticks, age_last, int(hold_ms()), want_speed,
		velocity.x, velocity.y, is_on_floor(), hit]


## What this peer is asking to move toward, in world space. Read by the push:
## leaning on a rock counts only if you are walking into it.
func wish() -> Vector2:
	return _effective_input().wish


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
