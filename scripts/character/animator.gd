class_name Animator
extends RefCounted

## Procedural animation. No clips, no keyframes, no AnimationPlayer.
##
## Every pose in this file is arithmetic on a `LocomotionState`, which means it
## works at any speed, on any race, at any frame rate, and can be checked in a
## self-test without a scene tree. `pose_for()` is a PURE function - state and
## numbers in, bone name -> transform out - and it is what the gallery's pose
## strips and every animation test call. `update()` and `apply()` are the
## stateful half: the cycle phase, the exponential blend, and the landing timer.
##
##
## THE WALK CYCLE IS DRIVEN BY DISTANCE, NOT TIME.
##
## Phase advances by `speed * dt / stride`, so a foot plants once per stride
## travelled and does not slide at any speed. The alternative - a fixed cycle
## rate with the amplitude scaled by speed - looks correct at exactly one speed
## and looks like ice skating at every other, and this game has a sprint that
## is 2.6 times walk.
##
## At sprint that would be a 10 Hz flail through a 1.3 m stride, so
## `cycle_hz_max` caps the leg RATE and lets the stride grow instead. The
## player looks like they are bounding. That is the honest visual of the sprint
## speed DESIGN.md already accepted - "sprint looks fast" - and it is a knob.
##
##
## SMOOTHING IS 1 - exp(-k dt), NOT lerp(current, target, 0.1).
##
## The codebase's convention, and RemotePlayer explains why: the tempting
## version moves 10% of the way per FRAME, so it is twice as fast at 120 fps as
## at 60 and the game feels different on two machines.

## The reference leg length the stride table is written against: the stocky
## human's 9 voxels. Every other race and scheme scales from it.
const REFERENCE_LEG_M := 9.0 * VoxelModel.VOXEL_M

## Below this speed the character is standing still as far as the legs are
## concerned, and the swing blends out rather than shrinking asymptotically.
## Without it a character nudged by a slope twitches its legs forever.
const MOVING_SPEED_M := 1.5

var config: CharacterConfig = null

## The race's own dimension table, for the stride and for where the hips are.
## Data, not behaviour - the animator reads it and never branches on which race
## it belongs to.
var dims := {}

## 0..1, one full cycle is two steps.
var phase := 0.0

## Seconds since this animator started, for breathing and idle sway.
var time := 0.0

var _smoothed := {}
var _was_grounded := true
var _land_remaining := 0.0
var _look_yaw := 0.0
var _look_pitch := 0.0

## Seconds left of the current wave, if any. The wave is the one pose that ends
## by itself.
var _wave_remaining := 0.0

## Seconds until the eyes change state, and which state they are in.
##
## REAL RANDOMNESS, DELIBERATELY. Hard rule 13: determinism is not required
## here, because nothing about a blink generates the world or is sent to
## anyone. Two players watching the same character will see it blink at
## different moments, which is exactly as visible as it sounds - not at all.
var _blink_timer := 0.0
var _blinking := false


func setup(p_config: CharacterConfig, p_dims: Dictionary) -> void:
	config = p_config
	dims = p_dims
	# Staggered from the start, so four players who joined together do not
	# blink in unison - which reads as a scripted event rather than as life.
	_blink_timer = randf_range(config.blink_min_s, config.blink_max_s)


## Advance the cycle and the smoothing. Call once per frame with the frame's
## delta; it is safe to call with dt 0.
func update(state: LocomotionState, dt: float) -> void:
	if config == null:
		return
	time += dt

	var stride := stride_for(state.speed)
	if stride > 0.0001:
		phase = fposmod(phase + state.speed * dt / stride, 1.0)

	# The landing dip is a one-shot, armed by the transition rather than by the
	# state - a character that spawns on the ground has not landed.
	if state.grounded and not _was_grounded:
		_land_remaining = config.land_squash_ms / 1000.0
	_was_grounded = state.grounded
	_land_remaining = maxf(_land_remaining - dt, 0.0)

	if state.pose == LocomotionState.POSE_WAVE and _wave_remaining <= 0.0:
		_wave_remaining = WAVE_SECONDS
	if state.pose != LocomotionState.POSE_WAVE:
		_wave_remaining = 0.0
	_wave_remaining = maxf(_wave_remaining - dt, 0.0)

	# The head turns toward where the player is looking, clamped and smoothed.
	# Smoothed here rather than inside pose_for so that the pure function stays
	# pure and a test can ask for an exact pose at an exact look angle.
	var look_t := 1.0 - exp(-config.look_smoothing * dt)
	_look_yaw = lerp_angle(_look_yaw, clampf(state.look_yaw_rel,
		-deg_to_rad(config.look_yaw_deg), deg_to_rad(config.look_yaw_deg)), look_t)
	_look_pitch = lerpf(_look_pitch, clampf(state.look_pitch,
		-deg_to_rad(config.look_pitch_deg), deg_to_rad(config.look_pitch_deg)), look_t)

	_update_blink(dt)

	var target := pose_for(state, phase, time, config, dims, {
		"look_yaw": _look_yaw,
		"look_pitch": _look_pitch,
		"land": land_amount(),
		"wave": _wave_remaining,
	})

	var t := 1.0 - exp(-config.pose_smoothing * dt)
	_blend_into(target, t)


## Write the current pose onto a rig.
func apply(rig: Rig) -> void:
	if rig != null:
		rig.apply_pose(_smoothed)


## The pose as it stands, for the self-tests and for the gallery's strips.
func current_pose() -> Dictionary:
	return _smoothed


## Jump straight to a pose with no blend. Used when a character is built or
## teleported - blending in from the last character's pose would be a visible
## snap on the creation screen.
func snap_to(state: LocomotionState) -> void:
	if config == null:
		return
	_look_yaw = clampf(state.look_yaw_rel,
		-deg_to_rad(config.look_yaw_deg), deg_to_rad(config.look_yaw_deg))
	_look_pitch = clampf(state.look_pitch,
		-deg_to_rad(config.look_pitch_deg), deg_to_rad(config.look_pitch_deg))
	_smoothed = _normalised(pose_for(state, phase, time, config, dims, {
		"look_yaw": _look_yaw, "look_pitch": _look_pitch,
		"land": 0.0, "wave": 0.0,
	}))


## Are the eyes shut this frame?
func blinking() -> bool:
	return _blinking


## Eyes shut for blink_ms, then open for a uniform gap between blink_min_s and
## blink_max_s.
##
## The gap is measured from the eyes OPENING, so two blinks are always at least
## blink_min_s apart plus the blink itself. A gap measured from the blink's
## start could in principle schedule the next one inside the current one, which
## is the failure the self-test looks for.
func _update_blink(dt: float) -> void:
	_blink_timer -= dt
	if _blink_timer > 0.0:
		return
	if _blinking:
		_blinking = false
		_blink_timer = randf_range(config.blink_min_s, config.blink_max_s)
	else:
		_blinking = true
		_blink_timer = config.blink_ms / 1000.0


## TODO(marcel): make the blinks cluster.
##
## Real blinking is not a uniform random gap. People blink in bursts, and they
## blink just before they turn their head or start to speak - which is why a
## character with perfectly even blinks reads as a machine imitating one.
##
##   Hint: keep a small "burst" counter. When it is zero, draw the gap the way
##   this does; when it is not, draw a much shorter one and decrement it. Set
##   the counter to two or three whenever the head look yaw changes by more
##   than about 20 degrees in a frame.
##
## The head-look yaw is already in this class as `_look_yaw`, so the trigger
## costs nothing to detect. Watch it on the F8 panel with blink_min_s turned
## right down, where the rhythm is visible in a few seconds.
##
## Fallback: uniform between min and max, which is what is here.


## How much of the landing dip is still owed, 0 to 1.
func land_amount() -> float:
	var total := config.land_squash_ms / 1000.0
	return _land_remaining / total if total > 0.0 else 0.0


# --- The stride ---------------------------------------------------------------

## Metres per full cycle at this speed.
##
## Scales with leg length across races and schemes, so the dwarf takes short
## quick steps and the elf long slow ones out of one table, and then stretches
## rather than letting the leg rate exceed `cycle_hz_max`.
func stride_for(speed: float) -> float:
	var leg: float = float(dims.get("legs", 9)) * VoxelModel.VOXEL_M
	var base: float = config.stride_walk_m * leg / REFERENCE_LEG_M
	return _stride_capped(base, speed, config.cycle_hz_max)


## TODO(marcel): a stride that knows the difference between a walk and a run.
##
## What this does now is the linear leg-length scale plus a rate cap: below
## `cycle_hz_max` the stride is constant and the legs simply move faster, and
## above it the stride stretches to keep the rate down. That is two regimes
## with a corner between them, and a real gait has three - a walk whose stride
## grows gently with speed, a transition, and a run whose stride grows much
## faster.
##
##   Hint: make the base stride depend on speed as well, something like
##   `base * (0.75 + 0.25 * speed / walk_speed)`, before the cap is applied.
##   The corner softens and a character accelerating from a stand lengthens
##   its steps the way a person does.
##
## Worth doing with the gallery's walk strips side by side rather than in the
## world, because the difference is a few centimetres per step and the only
## way to see it is two strips one above the other.
##
## Fallback: the linear scale plus the cap, which is what is here and what
## every stylised game does.
static func _stride_capped(base: float, speed: float, cycle_hz_max: float) -> float:
	if cycle_hz_max <= 0.0:
		return base
	# Cycles per second this stride would demand at this speed.
	var hz := speed / maxf(base, 0.0001)
	if hz <= cycle_hz_max:
		return base
	return speed / cycle_hz_max


# --- The pose -----------------------------------------------------------------

## Seconds a wave lasts before the pose returns to none.
const WAVE_SECONDS := 1.5

## THE PURE FUNCTION. State and numbers in, `bone -> {"rot", "pos"}` out.
##
## Everything is an OFFSET FROM REST, so a bone this function says nothing
## about stays where the rig put it - which is how one animator serves a
## seven-bone human and a nine-bone lizardfolk without knowing that either
## exists.
##
## THE PLAN WRITES THIS AS `pose_for(state, phase, t)`. It takes `config` and
## `dims` as well, because hard rule "every value chosen by eye goes in
## CharacterConfig" and a pure function cannot reach a member variable. `extra`
## carries the values `update()` smooths over time - the head look, the landing
## dip, the wave countdown - which are stateful by nature and would otherwise
## be the one thing forcing this function to stop being pure.
static func pose_for(state: LocomotionState, phase: float, t: float,
		config: CharacterConfig, dims: Dictionary, extra := {}) -> Dictionary:
	var pose := {}
	var v := VoxelModel.VOXEL_M
	var legs_m: float = float(dims.get("legs", 9)) * v

	match state.pose:
		LocomotionState.POSE_SIT:
			return _pose_sit(config, legs_m, t, extra)
		LocomotionState.POSE_DOWNED:
			return _pose_downed(config, legs_m)
		LocomotionState.POSE_WAVE:
			pose = _pose_locomotion(state, phase, t, config, legs_m, extra)
			_apply_wave(pose, config, t, float(extra.get("wave", 0.0)))
			_apply_head_look(pose, extra)
			return pose

	pose = _pose_locomotion(state, phase, t, config, legs_m, extra)
	_apply_head_look(pose, extra)
	return pose


## Walk, sprint, precision, idle, jump, fall, land - the whole ground game.
static func _pose_locomotion(state: LocomotionState, phase: float, t: float,
		config: CharacterConfig, legs_m: float, extra: Dictionary) -> Dictionary:
	var v := VoxelModel.VOXEL_M
	var pose := {}

	# How much of the swing this speed has earned. Blending in over the first
	# MOVING_SPEED_M rather than scaling by speed keeps a character nudged by a
	# slope from twitching its legs forever.
	var moving := clampf(state.speed / MOVING_SPEED_M, 0.0, 1.0)
	var swing_deg := config.walk_swing_deg
	var bob_vox := config.bob_walk_vox
	match state.mode:
		LocomotionState.MODE_SPRINT:
			swing_deg = config.sprint_swing_deg
			bob_vox = config.bob_sprint_vox
		LocomotionState.MODE_PRECISION:
			swing_deg = config.walk_swing_deg * config.precision_swing_ratio
			bob_vox = config.bob_walk_vox * config.precision_swing_ratio

	var swing := deg_to_rad(swing_deg) * moving
	var arm_swing := swing * config.arm_swing_ratio
	var cycle := TAU * phase
	var leg_wave := sin(cycle)

	# A positive rotation about X swings a downward-hanging bone's tip toward
	# -Z, which is forward. Arms are in antiphase with the leg on their own
	# side, which is what a person does and what makes a walk read as a walk.
	var leg_r := swing * leg_wave
	var leg_l := -swing * leg_wave
	var arm_r := -arm_swing * leg_wave
	var arm_l := arm_swing * leg_wave

	# Hips rise and fall twice per cycle - once per step - about their rest
	# height, so the character does not float upward at speed.
	var bob := bob_vox * v * 0.5 * sin(2.0 * cycle) * moving

	# Breathing. Small and slow: a character that visibly pumps while standing
	# still reads as panting. Fades out as soon as it is walking, where the bob
	# is doing the same job much more loudly.
	var breath := config.breath_vox * v * sin(TAU * config.breath_hz * t) * (1.0 - moving)

	var torso_pitch := 0.0
	if state.mode == LocomotionState.MODE_SPRINT:
		# Negative pitches the top of the torso toward -Z, which is forward.
		torso_pitch = -deg_to_rad(config.sprint_lean_deg) * moving

	if not state.grounded:
		if state.rising:
			# Both legs tucked up in front while rising.
			var tuck := deg_to_rad(config.jump_tuck_deg)
			leg_r = tuck
			leg_l = tuck
			bob = 0.0
		else:
			# Arms out while falling. Positive Z rotation swings the right
			# arm's tip toward +X, which is away from the body; the left is
			# mirrored, so both go outward.
			var out := deg_to_rad(config.fall_arms_deg)
			pose["arm_r"] = {"rot": Vector3(arm_r, 0.0, out)}
			pose["arm_l"] = {"rot": Vector3(arm_l, 0.0, -out)}
			bob = 0.0

	# The landing dip, decaying over land_squash_ms.
	var land: float = float(extra.get("land", 0.0))
	var dip := -config.land_squash_vox * v * land

	pose["hips"] = {"pos": Vector3(0.0, bob + dip, 0.0)}
	pose["torso"] = {"rot": Vector3(torso_pitch, 0.0, 0.0), "pos": Vector3(0.0, breath, 0.0)}
	pose["leg_r"] = {"rot": Vector3(leg_r, 0.0, 0.0)}
	pose["leg_l"] = {"rot": Vector3(leg_l, 0.0, 0.0)}
	if not pose.has("arm_r"):
		pose["arm_r"] = {"rot": Vector3(arm_r, 0.0, 0.0)}
		pose["arm_l"] = {"rot": Vector3(arm_l, 0.0, 0.0)}

	_apply_chains(pose, config, t, state.speed)
	return pose


## Sitting: hips on the ground, legs straight out in front, torso upright.
##
## THE CAMPFIRE PLAN OWNS THIS POSE. It is here because the state byte has to
## carry it for a friend to see you sit, and because a pose with nowhere to be
## triggered from is a pose nobody finds the bugs in. The debug key is
## scaffolding and says so.
static func _pose_sit(config: CharacterConfig, legs_m: float, t: float,
		extra: Dictionary) -> Dictionary:
	var v := VoxelModel.VOXEL_M
	var pose := {
		# Down to the ground, plus the lift that puts the flat thighs ON it
		# rather than in it. See CharacterConfig.sit_lift_vox.
		"hips": {"pos": Vector3(0.0, -legs_m + config.sit_lift_vox * v, 0.0)},
		"torso": {"rot": Vector3(deg_to_rad(-4.0), 0.0, 0.0),
			"pos": Vector3(0.0, config.breath_vox * v * sin(TAU * config.breath_hz * t), 0.0)},
		"leg_r": {"rot": Vector3(deg_to_rad(90.0), 0.0, 0.0)},
		"leg_l": {"rot": Vector3(deg_to_rad(90.0), 0.0, 0.0)},
		"arm_r": {"rot": Vector3(deg_to_rad(-20.0), 0.0, deg_to_rad(6.0))},
		"arm_l": {"rot": Vector3(deg_to_rad(-20.0), 0.0, deg_to_rad(-6.0))},
	}
	_apply_chains(pose, config, t, 0.0)
	_apply_head_look(pose, extra)
	return pose


## Downed: on its back, hips at the ground, arms out.
##
## THE DEATH DESIGN OWNS THIS POSE, for the same reason as sit. Pitching the
## HIPS rather than the whole view keeps the character's feet where they were,
## which is what falling over looks like.
static func _pose_downed(config: CharacterConfig, legs_m: float) -> Dictionary:
	var v := VoxelModel.VOXEL_M
	var pose := {
		# Higher than sitting: a character on its back is lying on the depth of
		# its own body, which is thicker than a thigh.
		"hips": {"rot": Vector3(deg_to_rad(-90.0), 0.0, 0.0),
			"pos": Vector3(0.0, -legs_m + config.downed_lift_vox * v, 0.0)},
		"torso": {"rot": Vector3(deg_to_rad(6.0), 0.0, 0.0)},
		"leg_r": {"rot": Vector3(deg_to_rad(-8.0), 0.0, 0.0)},
		"leg_l": {"rot": Vector3(deg_to_rad(-8.0), 0.0, 0.0)},
		"arm_r": {"rot": Vector3(0.0, 0.0, deg_to_rad(55.0))},
		"arm_l": {"rot": Vector3(0.0, 0.0, deg_to_rad(-55.0))},
	}
	_apply_chains(pose, config, 0.0, 0.0)
	return pose


## The right arm goes up and oscillates. Layered ON TOP of whatever the body is
## doing, so you can wave while walking.
static func _apply_wave(pose: Dictionary, config: CharacterConfig, t: float,
		remaining: float) -> void:
	if remaining <= 0.0:
		return
	# Eases out over the last quarter second rather than snapping the arm down.
	var strength := clampf(remaining / 0.25, 0.0, 1.0)
	var swing := deg_to_rad(18.0) * sin(TAU * 2.2 * t)
	pose["arm_r"] = {"rot": Vector3(
		deg_to_rad(10.0) * strength,
		0.0,
		(deg_to_rad(150.0) + swing) * strength)}


## The head follows the camera, clamped and already smoothed by update().
##
## This is the cheapest thing in the file and the one that does the most: a
## character whose head turns to where you are looking reads as present, and
## one whose head is welded forward reads as a puppet.
static func _apply_head_look(pose: Dictionary, extra: Dictionary) -> void:
	var yaw: float = float(extra.get("look_yaw", 0.0))
	var pitch: float = float(extra.get("look_pitch", 0.0))
	if is_zero_approx(yaw) and is_zero_approx(pitch):
		return
	var entry: Dictionary = pose.get("head", {})
	var rot: Vector3 = entry.get("rot", Vector3.ZERO)
	pose["head"] = {"rot": Vector3(rot.x + pitch, rot.y + yaw, rot.z)}


# --- Chains -------------------------------------------------------------------

## Bones named `<chain>_1..n` sway with a lag per link.
##
## GENERIC ON PURPOSE. The lizardfolk's tail needs it in Stage 8 and the
## critter's needs it in Stage 13, and a rule designed twice is a rule that
## differs in the second place. The animator does not know that a tail is a
## tail: it knows that bones with that naming shape follow their parent late.
##
## The lag is `tail_lag` seconds per link, applied as a phase offset rather
## than as a real spring. A spring would be more correct and would need per
## instance state, which would stop `pose_for` being pure - and the visible
## difference at a 12 degree amplitude is nothing.
static func _apply_chains(pose: Dictionary, config: CharacterConfig, t: float,
		speed: float) -> void:
	if CHAIN_NAMES.is_empty():
		return
	# Amplitude grows with speed: a tail is still when its owner is, and swings
	# harder the faster it goes.
	var amp := deg_to_rad(config.tail_deg) * (0.4 + 0.6 * clampf(speed / 5.0, 0.0, 1.0))
	for chain in CHAIN_NAMES:
		for i in MAX_CHAIN_LINKS:
			var bone := "%s_%d" % [chain, i + 1]
			var lag := config.tail_lag * float(i)
			var sway := amp * sin(TAU * config.tail_hz * (t - lag))
			# Each link adds a little of its own, so the tip travels furthest.
			var scale := 0.6 + 0.4 * float(i) / float(MAX_CHAIN_LINKS - 1)
			pose[bone] = {"rot": Vector3(0.0, sway * scale, 0.0)}


## The chains this animator writes poses for. A pose entry for a bone that does
## not exist costs nothing - `Rig.apply_pose` iterates the bones it HAS - so
## writing tail poses for a human is free rather than a branch on race.
const CHAIN_NAMES := ["tail"]
const MAX_CHAIN_LINKS := 4


# --- Blending -----------------------------------------------------------------

## Every entry with both keys present.
##
## `pose_for` writes only the components a pose actually uses - `{"pos": ...}`
## for the hips' bob, `{"rot": ...}` for a leg swing - because a pose that
## spells out zeros for everything is a pose you cannot read. The blend needs
## both keys on every entry, so they are filled in once, here, rather than
## defended against at four call sites.
static func _normalised(pose: Dictionary) -> Dictionary:
	var out := {}
	for bone in pose:
		var entry: Dictionary = pose[bone]
		out[bone] = {
			"rot": entry.get("rot", Vector3.ZERO),
			"pos": entry.get("pos", Vector3.ZERO),
		}
	return out

## Move the held pose a fraction `t` of the way toward `target`.
##
## Per bone and per component, because the alternative - blending whole
## transforms - would have to decide what to do about a bone the target does
## not mention, and "leave it alone" and "return it to rest" are different
## answers that look different.
func _blend_into(target: Dictionary, t: float) -> void:
	for bone in target:
		var want: Dictionary = target[bone]
		var want_rot: Vector3 = want.get("rot", Vector3.ZERO)
		var want_pos: Vector3 = want.get("pos", Vector3.ZERO)
		if not _smoothed.has(bone):
			_smoothed[bone] = {"rot": want_rot, "pos": want_pos}
			continue
		var have: Dictionary = _smoothed[bone]
		var have_rot: Vector3 = have.get("rot", Vector3.ZERO)
		var have_pos: Vector3 = have.get("pos", Vector3.ZERO)
		_smoothed[bone] = {
			# lerp_angle per component: a swing crossing PI must take the short
			# way round, and a plain lerp would spin it the long way.
			"rot": Vector3(
				lerp_angle(have_rot.x, want_rot.x, t),
				lerp_angle(have_rot.y, want_rot.y, t),
				lerp_angle(have_rot.z, want_rot.z, t)),
			"pos": have_pos.lerp(want_pos, t),
		}
	# A bone the target stopped mentioning returns to rest rather than freezing
	# where it was - a jump that ends leaves no arm sticking out.
	for bone in _smoothed:
		if target.has(bone):
			continue
		var have: Dictionary = _smoothed[bone]
		_smoothed[bone] = {
			"rot": (have.get("rot", Vector3.ZERO) as Vector3).lerp(Vector3.ZERO, t),
			"pos": (have.get("pos", Vector3.ZERO) as Vector3).lerp(Vector3.ZERO, t),
		}
