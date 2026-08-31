class_name CreatureView
extends Node3D

## What a creature LOOKS like. Display only, on host and client alike.
##
## HARD RULE 7, THE SECOND HALF: clients never decide, and the server never
## renders. This class has no opinion about anything - it is handed a position,
## a yaw and a state int, and it builds a body and animates it. Every decision
## behind those three numbers was made by `wolf.gd` on the host.
##
## THE HOST BUILDS THESE TOO, from its own creatures, and that is the point of
## the class rather than an efficiency. One code path for what a creature looks
## like means a wolf cannot look different to the player who is hosting than to
## the player who joined - which is the class of bug that only ever appears in
## somebody else's living room.
##
## NIGHT 1'S WOLF WEARS THE CRITTER'S BODY (decision 4). `PartsCritter` is a
## real animated quadruped that exists in the repo today - the same `Rig`, the
## same `Animator`, the same mesher a person is built with - so the wolf is a
## table row and a gait rather than new art. The wolf's own model is night 2's
## stage, and when it lands, this file changes by one line.

## Higher = snappier, lower = smoother but laggier. `RemotePlayer`'s constant
## and its reasoning: 1 - exp(-k dt), never lerp(a, b, 0.1), or the game moves
## at a different speed on a 120 Hz machine than on a 60 Hz one.
const SMOOTHING := 12.0

var species := Species.WOLF
var id := 0

var rig: Rig = null
var animator: Animator = null

var _target_position := Vector3.ZERO
var _target_yaw := 0.0
var _has_target := false
var _state := Creature.STATE_IDLE

## Speed inferred from how far the target moved, not sent. ONE FEWER FIELD ON
## THE WIRE for a number the receiver can work out: the animator wants a speed
## to pick a stride, and the difference between two positions twenty times a
## second is exactly that.
var _speed_mps := 0.0

var _config: CharacterConfig = null


func setup(p_species: int, p_id: int) -> void:
	species = Species.valid(p_species)
	id = p_id
	name = "%sView%d" % [Species.name_of(species), id]


func _ready() -> void:
	_build()


func _build() -> void:
	_config = CharacterConfig.load_or_default()
	rig = Rig.new()
	rig.name = "Rig"
	add_child(rig)
	# EXACTLY WHAT THE GALLERY DOES (character_gallery.gd, the critter strip),
	# because the gallery is the thing that proves this animal builds and moves.
	rig.build(PartsCritter.bone_table(), PartsData.module("critter"),
		PartsCritter.palette(), _config.ao_strength)
	animator = Animator.new()
	animator.setup(_config, Species.dims(species))
	animator.snap_to(_locomotion())


## One row from the host: `[pos, yaw, state, species]`.
func set_row(row: Array) -> void:
	if row.size() < 4:
		return
	var pos: Vector3 = row[0]
	if _has_target:
		# Distance over the sync interval IS the speed. See `_speed_mps`.
		_speed_mps = Creature.flat_distance(pos, _target_position) * Species.SYNC_HZ
	_target_position = pos
	_target_yaw = row[1]
	_state = int(row[2])
	if not _has_target:
		# First row: snap, do not glide in from the world origin. The same rule
		# `RemotePlayer.set_target` follows, for the same reason.
		_has_target = true
		global_position = _target_position
		rotation.y = _target_yaw


func _process(delta: float) -> void:
	if not _has_target or animator == null:
		return
	var t := 1.0 - exp(-SMOOTHING * delta)
	global_position = global_position.lerp(_target_position, t)
	rotation.y = lerp_angle(rotation.y, _target_yaw, t)
	animator.update(_locomotion(), delta)
	animator.apply(rig)


## The state int, turned into something the animator understands.
##
## A SMALL POSE SET, and deliberately not a big one. The wire carries four
## states because that is what a client needs to draw the difference between an
## animal walking, running and springing at you; the twelve things a wolf's
## tree is actually doing are the host's business and would be twelve poses
## nobody could tell apart.
func _locomotion() -> LocomotionState:
	var st := LocomotionState.new()
	st.grounded = true
	match _state:
		Creature.STATE_IDLE:
			st.speed = 0.0
		Creature.STATE_WALK:
			st.speed = maxf(_speed_mps, Species.walk_mps(species))
		Creature.STATE_RUN:
			st.speed = maxf(_speed_mps, Species.run_mps(species) * 0.8)
		Creature.STATE_LUNGE:
			# The lunge has no pose of its own yet - that is night 2's, with
			# the wolf's own parts - so it reads as a hard run rather than as
			# nothing at all. Named here so the gap is a decision.
			st.speed = Species.run_mps(species)
	return st
