class_name LocomotionState
extends RefCounted

## What a body is doing, in the only terms the animator is allowed to know.
##
## THIS STRUCT IS THE SEAM. The local player fills it from its own
## CharacterBody3D; a remote player fills it from the wire; and the
## host-simulated player this project will eventually have will fill it from
## the host's table. The animator never reads `Input`, never reads a
## `CharacterBody3D`, and never learns which of the three it is being driven
## by - which is what makes "client sends input, host simulates" a change to
## one file rather than to the animation system.
##
## Nothing here is per-race. Hard rule 3: race is never a stat, so a state that
## carried a race-specific speed would be the first crack in that.

enum {
	MODE_WALK = 0,
	MODE_SPRINT = 1,
	MODE_PRECISION = 2,
}

enum {
	POSE_NONE = 0,
	POSE_SIT = 1,
	POSE_DOWNED = 2,
	POSE_WAVE = 3,
}

## Horizontal, metres per second. Vertical is separate because the walk cycle
## is driven by ground distance and a falling character covers none.
var speed := 0.0

## Metres per second, signed. Positive is up.
var vertical := 0.0

var grounded := true
var mode := MODE_WALK

## Going up rather than coming down. Not `vertical > 0`: the two differ for one
## frame at the apex and a legs-tucked pose that flickers there is worse than
## one that commits.
var rising := false

var pose := POSE_NONE

## Where the player is looking, in WORLD space, radians. This is what travels
## on the wire, because the receiver does not necessarily know the sender's
## body yaw at the same instant.
var look_yaw := 0.0

## The same, made relative to the body this character is standing on. Filled by
## CharacterView, which is the only thing that knows both. The animator uses
## this one; nothing sends it anywhere.
var look_yaw_rel := 0.0

var look_pitch := 0.0

var noclip := false


## Everything that fits in a byte, in one byte.
##
## bit 0 grounded, 1 sprint, 2 precision, 3 rising, 4-6 pose id, 7 noclip.
## Speed, vertical and look yaw are floats and travel as themselves; these are
## flags, and a flag per field would have made the payload bigger than the
## thing it describes.
func to_state_byte() -> int:
	var out := 0
	if grounded:
		out |= 1
	if mode == MODE_SPRINT:
		out |= 2
	if mode == MODE_PRECISION:
		out |= 4
	if rising:
		out |= 8
	out |= (clampi(pose, 0, 7) & 7) << 4
	if noclip:
		out |= 128
	return out


func from_state_byte(byte: int) -> void:
	grounded = (byte & 1) != 0
	if (byte & 2) != 0:
		mode = MODE_SPRINT
	elif (byte & 4) != 0:
		mode = MODE_PRECISION
	else:
		mode = MODE_WALK
	rising = (byte & 8) != 0
	pose = (byte >> 4) & 7
	# A pose id this build does not know about is not a reason to stop
	# animating. Clamp to the poses that exist and carry on.
	if pose > POSE_WAVE:
		pose = POSE_NONE
	noclip = (byte & 128) != 0


func duplicate_state() -> LocomotionState:
	var out := LocomotionState.new()
	out.speed = speed
	out.vertical = vertical
	out.grounded = grounded
	out.mode = mode
	out.rising = rising
	out.pose = pose
	out.look_yaw = look_yaw
	out.look_yaw_rel = look_yaw_rel
	out.look_pitch = look_pitch
	out.noclip = noclip
	return out
