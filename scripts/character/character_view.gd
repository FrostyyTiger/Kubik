class_name CharacterView
extends Node3D

## The single visual entry point for a character.
##
## `Player`, `RemotePlayer`, the creation screen's preview and the gallery all
## use this and nothing else builds a character. That is the whole design: one
## place that turns a `CharacterDef` into geometry means the local player, the
## friend across the network and the turntable in the menu can never disagree
## about what a dwarf looks like.
##
## `build(def)` is IDEMPOTENT and cheap enough to call on every click, because
## the creation screen does exactly that - every swatch, every arrow, every
## race button tears the rig down and puts it back up. That constraint is why
## the mesher resolves palettes at build time rather than caching per-race
## meshes: the same voxels through a different table is one array of colours,
## and it is not worth a cache.

## Feet on the ground: the model's origin is the sole of its boot, which is
## where a CharacterBody3D's origin is too. See scenes/player.tscn.

## True for the player's own character. Controls the close-camera hide, and
## nothing else - a remote character is not a different kind of character.
var local := false

var def: CharacterDef = null
var rig: Rig = null
var animator: Animator = null

var _config: CharacterConfig = null
var _state := LocomotionState.new()


func _ready() -> void:
	if rig == null:
		# Anything that forgot to call build() still gets a character rather
		# than an invisible player. The default human is always buildable.
		build(CharacterDef.new())


## Tear the character down and put it back up from `new_def`.
##
## Takes a COPY. The creation screen mutates one def in place as the user
## clicks, and a view holding a reference to it would be describing a character
## that has already changed by the time anything asks.
func build(new_def: CharacterDef) -> void:
	def = new_def.duplicate_def() if new_def != null else CharacterDef.new()
	def.validate()
	_config = CharacterConfig.load_or_default()

	if rig != null:
		rig.queue_free()
		remove_child(rig)
	rig = Rig.new()
	rig.name = "Rig"
	add_child(rig)

	rig.build(
		Races.bone_table(def.race, def.build),
		Races.parts_for(def),
		Races.palette(def.race, def.skin, def.hair_color, def.eyes),
		_config.ao_strength,
		Races.hips_pitch_rad(def.race))

	# A fresh animator per build, and snapped rather than blended into place.
	# Carrying the old one over would mean the creation screen's new dwarf
	# starts in the elf's mid-stride and eases out of it, which reads as a
	# glitch rather than as a change of character.
	animator = Animator.new()
	animator.setup(_config, Races.dims(def.race, def.build))
	animator.snap_to(_state)
	animator.apply(rig)

	# A rebuild throws the old rig away, so anything hanging on it went with
	# it. Put the placeholders back if they were on - otherwise cycling race on
	# the F8 panel would silently disarm the T key.
	if _gear_on:
		set_gear_placeholders(true)
	# And whatever the character is wearing, which arrived in the def.
	apply_armour()


## Hang everything `def` says this character is wearing.
##
## THROUGH THE SAME ONE ENTRY POINT as everything else visual, which is the
## whole design of this file: the local player, the friend across the network
## and the creation screen's turntable can never disagree about what a dwarf in
## plate looks like, because there is one function that turns a def into
## geometry and this is part of it.
##
## Cheap enough to call on every rebuild - `build()` already tears the rig down
## and puts it back on every click of the creation screen.
func apply_armour() -> void:
	if rig == null or def == null:
		return
	rig.clear_overlays()
	var palette := Races.palette(def.race, def.skin, def.hair_color, def.eyes)
	for slot in CharacterDef.ARMOUR_SLOTS:
		if def.armour_tier[slot] <= 0:
			continue
		var piece := Armour.part_name(slot, def.armour_tier[slot], def.race)
		if piece.is_empty() or not PartsArmour.PARTS.has(piece):
			continue
		var part: Dictionary = PartsArmour.PARTS[piece]
		var where := Armour.attach_points(slot)
		for bone in where.get("bones", []):
			# The left of a mirrored pair takes the mirrored part, exactly as
			# the body's own limbs do - one authored side, two that cannot
			# drift apart.
			rig.attach_overlay(bone, part, piece, palette, _config.ao_strength)
		for socket in where.get("sockets", []):
			rig.attach_to_socket(socket, part, piece, palette, _config.ao_strength)


## What this character is doing. Called every physics frame by Player, and
## every sync tick by RemotePlayer.
##
## The look yaw arrives in WORLD space - that is what the wire carries, because
## the receiver does not know the sender's body yaw at the same instant - and
## is made relative HERE, because this node is the one that is standing on the
## body and therefore the only one that knows both.
func set_state(state: LocomotionState) -> void:
	_state = state
	_state.look_yaw_rel = wrapf(state.look_yaw - global_rotation.y, -PI, PI)


func _process(delta: float) -> void:
	if animator == null or rig == null:
		return
	animator.update(_state, delta)
	animator.apply(rig)
	rig.set_blinking(animator.blinking())
	_update_close_hide()


## Hide the character when the camera is inside its head.
##
## TWO THINGS NEED THIS AND NEITHER OF THEM IS A SPECIAL CASE. The spring arm
## collapses toward the player when it hits a wall, and at full collapse the
## camera is inside the skull looking at the back of a face. And the screenshot
## tour parks the PLAYER at each vantage point because the player is what
## streams chunks - so without this, every one of the tour's six terrain shots
## would have a character's head filling it. This covers the tour without
## touching screenshot_tour.gd, which this branch may not edit.
##
## It hides the RIG rather than the view, because `visible` on the view belongs
## to noclip - Player._set_noclip() sets it - and two owners of one flag is a
## bug waiting for the day both are true.
func _update_close_hide() -> void:
	if not local:
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null or not rig.bones.has("head"):
		return
	var head: Node3D = rig.bones["head"]
	var head_pos: Vector3 = rig.global_transform * rig.transform_to_rig(head).origin
	rig.visible = cam.global_position.distance_to(head_pos) > _config.view_hide_m


## Hang the three Stage 10 placeholders on their sockets, or take them off.
##
## NOT A GEAR SYSTEM. The sockets are the deliverable and these three items
## prove them: the sword swings with the arm because it is a child of the arm
## bone, the tunic rides the sprint lean because it is a child of the torso,
## and the pendant survives a sit for the same reason. Nothing here touches
## CharacterDef or the wire.
func set_gear_placeholders(on: bool) -> void:
	if rig == null:
		return
	_gear_on = on
	rig.clear_attachments()
	if not on:
		return
	var palette := Races.palette(def.race, def.skin, def.hair_color, def.eyes)
	for socket_name in PartsGear.PLACEHOLDERS:
		rig.attach_to_socket(socket_name, PartsGear.PLACEHOLDERS[socket_name],
			socket_name, palette, _config.ao_strength)


func gear_placeholders_on() -> bool:
	return _gear_on


var _gear_on := false


## The appearance this view was built from, as bytes. Used to decide whether a
## remote character needs rebuilding: comparing eight bytes is free and
## rebuilding a rig twenty times a second is not.
func appearance_bytes() -> PackedByteArray:
	return def.to_bytes() if def != null else PackedByteArray()


func triangle_count() -> int:
	return rig.triangle_count() if rig != null else 0


func height_m(include_ornaments := false) -> float:
	return rig.height_m(include_ornaments) if rig != null else 0.0
