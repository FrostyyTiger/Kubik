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
## human's legs, 0.5 m. Every other race scales from it.
##
## THE LITERAL IS IN VOXELS AND THE VOXEL CHANGED SIZE. It was 16 at 1/16 of a
## block and is 24 at 1/24 - the same half metre, a different number of voxels.
## Miss this and every race's stride scales from a reference two thirds of the
## right length, which reads as the whole cast mincing and is the sort of thing
## that gets blamed on an amplitude knob for a week.
const REFERENCE_LEG_M := 24.0 * VoxelModel.VOXEL_M

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


# --- Rig shapes ---------------------------------------------------------------
#
# WHICH BONES ARE LEGS, WHICH ARE ARMS, AND WHICH OF THEM SHARE A PHASE.
#
# The humanoid walk is not a special case here - it is the two-leg entry in the
# same table a trot is the four-leg entry of. That is the whole reason Stage 13
# builds a critter: an animator that could only do bipeds would look identical
# to this one right up until the first enemy that is not a person.
#
# `root` takes the hip bob and the landing dip; `lean` takes the sprint pitch
# and the breath. On a person those are two bones and on a dog they are the
# same one, which is a fact about dogs and not a branch in the animator.

const RIG_SHAPES := {
	"biped": {
		"root": "hips",
		"lean": "torso",
		# Opposite ends of the cycle: one leg forward while the other is back.
		#
		# `lower` IS OPTIONAL, and its absence is a statement rather than an
		# omission: a rig shape with no `lower` key is a rig with no knee, which
		# is the correct description of the critter's trot and of anything else
		# built from rigid parts that does not have one. Nothing branches on
		# which races have knees.
		"legs": [
			{"bone": "leg_r", "lower": "leg_r_lower", "foot": "leg_r_foot", "phase": 0.0},
			{"bone": "leg_l", "lower": "leg_l_lower", "foot": "leg_l_foot", "phase": 0.5},
		],
		# Arms in antiphase with the leg on their OWN side, which is what a
		# person does and what makes a walk read as a walk.
		"arms": [
			{"bone": "arm_r", "lower": "arm_r_lower", "phase": 0.5},
			{"bone": "arm_l", "lower": "arm_l_lower", "phase": 0.0},
		],
	},
	"trot": {
		"root": "body",
		"lean": "body",
		# DIAGONAL PAIRS. Front-left with back-right, front-right with
		# back-left - the gait a dog uses at anything above a walk, and the one
		# that keeps the animal balanced on two feet at every instant.
		"legs": [
			{"bone": "leg_fl", "phase": 0.0},
			{"bone": "leg_br", "phase": 0.0},
			{"bone": "leg_fr", "phase": 0.5},
			{"bone": "leg_bl", "phase": 0.5},
		],
		"arms": [],
	},
}


## The rig shape for a dimension table, falling back to the biped.
##
## A WARNING AND A FALLBACK, NOT A CRASH. A rig with a gait this build has
## never heard of is a rig from a newer part file or a typo, and in both cases
## an animal that walks like a person is a better outcome than one that does
## not appear.
static func rig_shape(dims: Dictionary) -> Dictionary:
	var gait: String = dims.get("gait", "biped")
	if not RIG_SHAPES.has(gait):
		push_warning("[Animator] unknown gait '%s' - walking it like a biped" % gait)
		return RIG_SHAPES["biped"]
	return RIG_SHAPES[gait]


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
	# NO DEFAULT. `dims` always comes from a race table or from a part file's
	# own DIMS, both of which have `legs`; the old fallback of 9 was a fossil
	# from the 1/8 grid and would now silently produce a character with legs
	# three quarters of a voxel long rather than a loud failure.
	var legs_m: float = float(dims["legs"]) * v

	match state.pose:
		LocomotionState.POSE_SIT:
			return _pose_sit(config, legs_m, t, extra)
		LocomotionState.POSE_DOWNED:
			return _pose_downed(config, legs_m)
		LocomotionState.POSE_WAVE:
			pose = _pose_locomotion(state, phase, t, config, dims, legs_m, extra)
			_apply_wave(pose, config, t, float(extra.get("wave", 0.0)))
			_apply_head_look(pose, extra)
			return pose

	pose = _pose_locomotion(state, phase, t, config, dims, legs_m, extra)
	_apply_head_look(pose, extra)
	return pose


## Walk, sprint, precision, idle, jump, fall, land - the whole ground game.
static func _pose_locomotion(state: LocomotionState, phase: float, t: float,
		config: CharacterConfig, dims: Dictionary, legs_m: float,
		extra: Dictionary) -> Dictionary:
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

	var shape := rig_shape(dims)
	var root_bone: String = shape["root"]
	var lean_bone: String = shape["lean"]

	# Hips rise and fall twice per cycle - once per step - about their rest
	# height, so the character does not float upward at speed.
	var bob := bob_vox * v * 0.5 * sin(2.0 * TAU * phase) * moving

	# Breathing. Small and slow: a character that visibly pumps while standing
	# still reads as panting. Fades out as soon as it is walking, where the bob
	# is doing the same job much more loudly.
	var breath := config.breath_vox * v * sin(TAU * config.breath_hz * t) * (1.0 - moving)

	var torso_pitch := 0.0
	if state.mode == LocomotionState.MODE_SPRINT:
		# Negative pitches the top of the torso toward -Z, which is forward.
		torso_pitch = -deg_to_rad(config.sprint_lean_deg) * moving

	# A positive rotation about X swings a downward-hanging bone's tip toward
	# -Z, which is forward. Every leg is the same expression at its own point
	# in the cycle, so a trot is four entries in a table rather than a branch.
	var tuck := deg_to_rad(config.jump_tuck_deg)
	var rising := not state.grounded and state.rising
	for entry in (shape["legs"] as Array):
		var leg_phase := float(entry["phase"])
		var angle: float = tuck if rising else swing * sin(TAU * (phase + leg_phase))
		pose[entry["bone"]] = {"rot": Vector3(angle, 0.0, 0.0)}
		if entry.has("lower"):
			# A KNEE BENDS ONE WAY. A knee that hyperextends is the single most
			# obviously wrong thing a procedural rig can do, and a plain sine
			# does it for half of every cycle. So the angle is a RECTIFIED sine
			# - negative half clipped away - which is also, conveniently, what a
			# knee actually does: straight through stance, bent through swing.
			#
			# A quarter cycle behind the hip, because the knee's peak bend is
			# at mid-swing and the hip's extreme is at contact.
			var bend := -deg_to_rad(config.knee_swing_deg) * moving * maxf(
				0.0, sin(TAU * (phase + leg_phase + 0.25)))
			if rising:
				# Tucked under, which is most of what makes a tuck read as one.
				bend = -tuck
			pose[entry["lower"]] = {"rot": Vector3(bend, 0.0, 0.0)}
			if entry.has("foot"):
				# THE HOCK BENDS THE OTHER WAY. On a digitigrade leg the ankle
				# is raised and faces BACKWARD, so where the knee folds the
				# shin back, the hock folds the foot forward under it - which
				# is the joint that makes a lizardfolk read as an animal from
				# any angle. Another quarter cycle behind the knee, so the
				# three joints peak in sequence down the limb.
				#
				# A pose entry for a bone that does not exist costs nothing -
				# `Rig.apply_pose` iterates the bones it HAS - so writing this
				# for a human is free rather than a branch on race.
				pose[entry["foot"]] = {"rot": Vector3(
					deg_to_rad(config.hock_swing_deg) * moving * maxf(
						0.0, sin(TAU * (phase + leg_phase + 0.5))), 0.0, 0.0)}

	var falling := not state.grounded and not state.rising
	# Arms out while falling. Positive Z rotation swings the right arm's tip
	# toward +X, away from the body; the left is mirrored, so both go outward.
	var out := deg_to_rad(config.fall_arms_deg) if falling else 0.0
	var arms: Array = shape["arms"]
	for i in arms.size():
		var entry: Dictionary = arms[i]
		var arm_phase := float(entry["phase"])
		var angle := arm_swing * sin(TAU * (phase + arm_phase))
		# The first arm in the list is the right one, and outward is +Z for it
		# and -Z for its mirror.
		var side := 1.0 if i % 2 == 0 else -1.0
		pose[entry["bone"]] = {"rot": Vector3(angle, 0.0, out * side)}
		if entry.has("lower"):
			# An elbow bends the OTHER WAY from a knee, and it is the same
			# rectified expression with the opposite sign. Positive X swings the
			# forearm's tip forward, which is the only direction an elbow goes.
			pose[entry["lower"]] = {"rot": Vector3(
				deg_to_rad(config.elbow_swing_deg) * moving * maxf(
					0.0, sin(TAU * (phase + arm_phase + 0.25))), 0.0, 0.0)}

	if not state.grounded:
		bob = 0.0

	# The landing dip, decaying over land_squash_ms.
	var land: float = float(extra.get("land", 0.0))
	var dip := -config.land_squash_vox * v * land

	# On a person the root and the lean are two bones; on a quadruped they are
	# the same one, so the two writes are merged rather than one overwriting
	# the other.
	var root_entry := {"pos": Vector3(0.0, bob + dip, 0.0)}
	if lean_bone == root_bone:
		root_entry["rot"] = Vector3(torso_pitch, 0.0, 0.0)
		root_entry["pos"] = Vector3(0.0, bob + dip + breath, 0.0)
		pose[root_bone] = root_entry
	else:
		pose[root_bone] = root_entry
		pose[lean_bone] = {"rot": Vector3(torso_pitch, 0.0, 0.0),
			"pos": Vector3(0.0, breath, 0.0)}

	_apply_chains(pose, config, t, state.speed)
	return pose


## Sitting: hips on the ground, legs straight out in front, torso upright.
##
## THE CAMPFIRE PLAN OWNS THIS POSE. It is here because the state byte has to
## carry it for a friend to see you sit, and because a pose with nowhere to be
## triggered from is a pose nobody finds the bugs in. The debug key is
## scaffolding and says so.
## BIPED ONLY, and it names `hips` and `torso` directly. Sitting, going down
## and waving are things people do, the campfire and the death design own them,
## and a quadruped that needs to lie down can have its own entry when something
## asks for one. The gait table is about LOCOMOTION, which is the part every
## skeleton has.
static func _pose_sit(config: CharacterConfig, legs_m: float, t: float,
		extra: Dictionary) -> Dictionary:
	var v := VoxelModel.VOXEL_M
	var pose := {
		# Down to the ground, plus the lift that puts the flat thighs ON it
		# rather than in it. See CharacterConfig.sit_lift_vox.
		"hips": {"pos": Vector3(0.0, -legs_m + config.sit_lift_vox * v, 0.0)},
		"torso": {"rot": Vector3(deg_to_rad(-4.0), 0.0, 0.0),
			"pos": Vector3(0.0, config.breath_vox * v * sin(TAU * config.breath_hz * t), 0.0)},
		# THIGHS FLAT, SHINS DOWN - which is what sitting is, and which was not
		# available before there was a knee. Until character v2 Stage 4 this
		# pose was legs straight out in front, and the v1 status doc records
		# what that cost: "a sitting character photographed from the front looks
		# like a standing character with short legs", because its legs pointed
		# along its own forward axis straight at the camera. Knees up fixes the
		# pose rather than the camera.
		"leg_r": {"rot": Vector3(deg_to_rad(78.0), 0.0, 0.0)},
		"leg_l": {"rot": Vector3(deg_to_rad(78.0), 0.0, 0.0)},
		"leg_r_lower": {"rot": Vector3(deg_to_rad(-72.0), 0.0, 0.0)},
		"leg_l_lower": {"rot": Vector3(deg_to_rad(-72.0), 0.0, 0.0)},
		"arm_r": {"rot": Vector3(deg_to_rad(-20.0), 0.0, deg_to_rad(6.0))},
		"arm_l": {"rot": Vector3(deg_to_rad(-20.0), 0.0, deg_to_rad(-6.0))},
		# Forearms resting forward on the knees rather than hanging through
		# them.
		"arm_r_lower": {"rot": Vector3(deg_to_rad(34.0), 0.0, 0.0)},
		"arm_l_lower": {"rot": Vector3(deg_to_rad(34.0), 0.0, 0.0)},
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
		# One knee drawn up, the other nearly straight. A body on its back with
		# two identical legs reads as a doll laid down; asymmetry reads as
		# someone who fell. Free, and it is the same argument the armour ladder
		# makes about symmetry meaning "issued" and asymmetry meaning "lived
		# through".
		"leg_r_lower": {"rot": Vector3(deg_to_rad(-38.0), 0.0, 0.0)},
		"leg_l_lower": {"rot": Vector3(deg_to_rad(-12.0), 0.0, 0.0)},
		"arm_r": {"rot": Vector3(0.0, 0.0, deg_to_rad(55.0))},
		"arm_l": {"rot": Vector3(0.0, 0.0, deg_to_rad(-55.0))},
		"arm_r_lower": {"rot": Vector3(deg_to_rad(22.0), 0.0, 0.0)},
		"arm_l_lower": {"rot": Vector3(deg_to_rad(10.0), 0.0, 0.0)},
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
	# THE WAVE IS AT THE ELBOW, not the shoulder, now that there is one. A whole
	# arm swinging from the shoulder is a semaphore; a raised upper arm with the
	# forearm doing the moving is a wave. The upper arm holds still at 150
	# degrees out and the oscillation moves down one joint.
	pose["arm_r_lower"] = {"rot": Vector3(0.0, 0.0, deg_to_rad(28.0) * strength + swing * 1.6)}


## The head follows the camera, clamped and already smoothed by update().
##
## This is the cheapest thing in the file and the one that does the most: a
## character whose head turns to where you are looking reads as present, and
## one whose head is welded forward reads as a puppet.
##
##
## TODO(marcel): let the torso follow the head past the clamp.
##
## The head yaw is clamped at `look_yaw_deg`, 60 degrees, and past that the
## head simply stops - so looking hard over your shoulder gives you a character
## staring at a fixed angle while the camera keeps going. A person does not do
## that: the head runs out of neck and the SHOULDERS start to come round.
##
##   Hint: the clamp is applied in update(). Keep the unclamped angle too, and
##   here, give the torso a fraction of the OVERFLOW:
##
##       var over := yaw_unclamped - yaw_clamped
##       pose["torso"] = {"rot": Vector3(pitch_term, over * 0.4, 0.0)}
##
##   0.4 is a starting point. Past about 0.6 the character starts to look like
##   it is turning to walk that way, which is a different animation.
##
## Watch it on the F8 panel with look_yaw_deg turned down to about 25, where
## the overflow is large enough to see in a couple of seconds. The arms hang
## off the torso, so they come round with it for free - which is most of why
## this reads as a body and not as a swivelling head.
##
## Fallback: the head clamps and the body does not move, which is what is here
## and is what most games do.
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
