class_name CharacterConfig
extends Resource

## Every character knob that was chosen by eye.
##
## NOT IN WorldgenConfig, and not in its PROPERTIES table. Nothing here changes
## a block, a chunk or a seed, and `worldgen.tres` belongs to two other runs
## tonight. Separate file, separate save, separate panel key.
##
## THE RULE THAT PUT THIS FILE HERE. This box has no display: Godot falls back
## to OpenGL Compatibility on llvmpipe under Xvfb, and Marcel runs Forward+ on
## an RTX 5080. Every amplitude and every colour in this run was therefore
## judged on the wrong renderer. The deal the plan strikes is that tuning blind
## is allowed provided nothing tuned by eye is ever hardcoded - so every number
## below is reachable from the F8 panel, and every one of them is listed in
## docs/status/character-v1.md under "Tuned blind - re-check these first",
## with its before and after.

## `_v2` since look v1: every `_vox` knob below is in model voxels, and the
## model voxel halved. A v1 file loaded here would move everything half as
## far, so the old file is simply not read.
const USER_PATH := "user://character_tuning_v2.tres"

## Mesh triangles per character WITH hair and beard, the number the height
## self-test and the gallery's budget sheet gate on. 6000 in character v1 at
## 1/8 of a block; the finer voxel quadruples the surface, and the chamfers and
## the hands add a little more, so 24000. Four players is under 100k, which is
## the far field's own budget - see docs/status/look-v1-characters.md for
## the measured numbers.
const TRIANGLE_BUDGET := 24000


# --- Locomotion ---------------------------------------------------------------

## Leg swing amplitude at walk speed, in degrees, measured from the rest pose
## to the extreme of the stride.
@export var walk_swing_deg := 35.0

## At sprint. Bigger, because 13 m/s with a walk's amplitude reads as a
## character being dragged along the ground rather than running.
@export var sprint_swing_deg := 60.0

## Arm amplitude as a fraction of the leg's. Arms swing less than legs on a
## real gait and much less on a stylised one.
@export var arm_swing_ratio := 0.8

## Precision crawl amplitude, as a fraction of the walk's.
@export var precision_swing_ratio := 0.4

## Torso pitched forward at sprint, in degrees. The single strongest cue that
## a character is running rather than walking quickly.
@export var sprint_lean_deg := 12.0

## How far the hips rise and fall per step, in MODEL VOXELS rather than metres,
## so the number means the same thing on a dwarf and on an elf.
@export var bob_walk_vox := 3.0
@export var bob_sprint_vox := 6.0

## Metres covered by one full cycle - two steps - at walk speed, for a stocky
## human. Every other race and scheme scales this by its own leg length.
@export var stride_walk_m := 1.3

## THE WALK CYCLE IS DRIVEN BY DISTANCE, NOT TIME: phase advances by
## `speed * dt / stride`, so feet do not slide at any speed. At sprint that
## would be a 10 Hz flail through a 1.3 m stride, so this caps the leg RATE and
## lets the stride grow to `speed / cycle_hz_max` instead - 3.7 m at 13 m/s.
## The player looks like they are bounding, which is the honest visual of the
## sprint speed DESIGN.md already accepted.
@export var cycle_hz_max := 3.5

## Per-bone blend rate, as the k in `1 - exp(-k dt)`. The codebase's
## frame-rate-independent convention - see RemotePlayer for why this shape
## rather than lerp(current, target, 0.1).
@export var pose_smoothing := 10.0


# --- In the air ---------------------------------------------------------------

## Legs tucked while rising, in degrees.
@export var jump_tuck_deg := 25.0

## Arms out while falling, in degrees.
@export var fall_arms_deg := 30.0

## The hips dip this far on landing and recover over this long.
@export var land_squash_vox := 4.0
@export var land_squash_ms := 120.0


# --- Life ---------------------------------------------------------------------

## Idle torso rise. Small and slow: a character that visibly pumps while
## standing still reads as panting, not as breathing.
@export var breath_hz := 0.25
@export var breath_vox := 1.0

## How high the hips sit above the ground in the two static poses, in model
## voxels.
##
## BOTH ARE "HIPS AT GROUND LEVEL" IN THE PLAN, and they cannot be the same
## number. A sitting character's thighs lie flat on the ground and its hip
## pivot ends up half a thigh above it; a character on its back is lying on the
## depth of its own body, which is thicker. Sitting is the lower of the two,
## and the difference is what stops the two poses reading as one.
##
## Chosen by eye against the gallery's pose strip, so they live here rather
## than in the animator - and they are in the re-check table with everything
## else that was.
@export var sit_lift_vox := 3.0
@export var downed_lift_vox := 5.0

## Blink timing. The interval is drawn uniformly between the two bounds; the
## blink itself is a mesh swap, not a shader.
@export var blink_min_s := 3.0
@export var blink_max_s := 6.0
@export var blink_ms := 120.0


# --- The head follows the camera ----------------------------------------------
#
# This is what makes a character feel present rather than piloted. The head
# turns toward where the player is looking, clamped so it never snaps round.

@export var look_yaw_deg := 60.0
@export var look_pitch_deg := 25.0
@export var look_smoothing := 8.0


# --- Chains -------------------------------------------------------------------
#
# The tail, and anything else named `<chain>_1..n`. Generic because the
# lizardfolk and the critter both need it and it must not be designed twice.

@export var tail_hz := 1.2
@export var tail_deg := 12.0

## Seconds of lag per link. What makes a chain read as a tail rather than as a
## rigid stick with a hinge in it.
@export var tail_lag := 0.15


# --- Rendering ----------------------------------------------------------------

## Baked corner AO on character parts. LOWER THAN THE WORLD'S 0.45: a face is
## smaller than a hillside and the same darkening reads as dirt on it.
@export var ao_strength := 0.35

## The local view hides when the active camera is nearer than this to the head.
## Covers the spring arm collapsing against a wall AND the screenshot tour,
## which parks the player at the camera's eye.
@export var view_hide_m := 1.0


## Rows for the F8 panel: property, label, min, max, step. Kept beside the
## properties so a new knob is one line in one file rather than two lines in
## two, which is the thing that makes knobs quietly stop being reachable.
const TUNING_ROWS := [
	["walk_swing_deg", "walk leg swing (deg)", 0.0, 90.0, 1.0],
	["sprint_swing_deg", "sprint leg swing (deg)", 0.0, 120.0, 1.0],
	["arm_swing_ratio", "arm swing / leg swing", 0.0, 2.0, 0.05],
	["precision_swing_ratio", "precision / walk swing", 0.0, 1.0, 0.05],
	["sprint_lean_deg", "sprint torso lean (deg)", 0.0, 45.0, 1.0],
	["bob_walk_vox", "walk hip bob (vox)", 0.0, 12.0, 0.1],
	["bob_sprint_vox", "sprint hip bob (vox)", 0.0, 16.0, 0.1],
	["stride_walk_m", "walk stride (m)", 0.4, 3.0, 0.05],
	["cycle_hz_max", "max leg rate (Hz)", 0.5, 8.0, 0.1],
	["pose_smoothing", "pose blend rate", 1.0, 40.0, 0.5],
	["jump_tuck_deg", "jump leg tuck (deg)", 0.0, 90.0, 1.0],
	["fall_arms_deg", "fall arms out (deg)", 0.0, 90.0, 1.0],
	["land_squash_vox", "landing dip (vox)", 0.0, 16.0, 0.1],
	["land_squash_ms", "landing dip (ms)", 20.0, 600.0, 10.0],
	["sit_lift_vox", "sit hip height (vox)", 0.0, 16.0, 0.1],
	["downed_lift_vox", "downed hip height (vox)", 0.0, 16.0, 0.1],
	["breath_hz", "breathing (Hz)", 0.0, 2.0, 0.05],
	["breath_vox", "breathing rise (vox)", 0.0, 6.0, 0.1],
	["blink_min_s", "blink gap min (s)", 0.5, 20.0, 0.5],
	["blink_max_s", "blink gap max (s)", 0.5, 30.0, 0.5],
	["blink_ms", "blink length (ms)", 40.0, 400.0, 10.0],
	["look_yaw_deg", "head look yaw (deg)", 0.0, 120.0, 1.0],
	["look_pitch_deg", "head look pitch (deg)", 0.0, 80.0, 1.0],
	["look_smoothing", "head look rate", 1.0, 30.0, 0.5],
	["tail_hz", "tail sway (Hz)", 0.0, 5.0, 0.05],
	["tail_deg", "tail sway (deg)", 0.0, 60.0, 1.0],
	["tail_lag", "tail lag per link (s)", 0.0, 1.0, 0.01],
	["ao_strength", "part AO strength", 0.0, 1.0, 0.05],
	["view_hide_m", "hide own view within (m)", 0.0, 4.0, 0.1],
]


static func load_or_default() -> CharacterConfig:
	if ResourceLoader.exists(USER_PATH):
		var res := ResourceLoader.load(USER_PATH, "", ResourceLoader.CACHE_MODE_IGNORE)
		if res is CharacterConfig:
			return res
		push_warning("[CharacterConfig] %s is not a CharacterConfig, using defaults" % USER_PATH)
	return CharacterConfig.new()


func save_to_user() -> void:
	var err := ResourceSaver.save(self, USER_PATH)
	if err != OK:
		push_warning("[CharacterConfig] could not save %s: %s" % [USER_PATH, error_string(err)])
	else:
		print("[CharacterConfig] saved to %s" % USER_PATH)
