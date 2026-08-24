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

var _config: CharacterConfig = null


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
		Races.part_set(def.race, def.build),
		Races.palette(def.race, def.skin, def.hair_color, def.eyes),
		_config.ao_strength,
		Races.hips_pitch_rad(def.race))


## The appearance this view was built from, as bytes. Used to decide whether a
## remote character needs rebuilding: comparing eight bytes is free and
## rebuilding a rig twenty times a second is not.
func appearance_bytes() -> PackedByteArray:
	return def.to_bytes() if def != null else PackedByteArray()


func triangle_count() -> int:
	return rig.triangle_count() if rig != null else 0


func height_m() -> float:
	return rig.height_m() if rig != null else 0.0
