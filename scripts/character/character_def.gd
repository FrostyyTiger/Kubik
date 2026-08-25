class_name CharacterDef
extends Resource

## What a character IS, as eight bytes and a name.
##
## Everything visible about a player travels in this: race, proportion scheme,
## and five indices into that race's option lists. No colours, no geometry, no
## strings except the name - the appearance is resolved on the machine that
## draws it, from tables both machines already have.
##
## THE HOST VALIDATES EVERY CLAIM. `from_bytes()` never throws and never
## returns something that cannot be built: a wrong version, a wrong length or a
## beard index of 200 all come back as a valid character, clamped, with a
## warning. A character that fails to appear is a bug; a game that crashes
## because a friend's beard index was 7 is a disaster, and the difference
## between those two outcomes is entirely in this file.

## Bumped if the layout below ever changes. A peer sending the old version gets
## the default human rather than a character built from misread bytes, which
## would be worse than no character at all.
const WIRE_VERSION := 1
const WIRE_BYTES := 8

## The wire cap. Longer names are truncated, not rejected - a friend with a
## long name should appear, with a short name.
const NAME_MAX := 16

const SAVE_PATH := "user://character.tres"

@export var race := Races.HUMAN
@export var build := Races.STOCKY
@export var skin := 0
@export var hair_color := 0
@export var eyes := 0
@export var hair := 0
@export var beard := 0
@export var name_text := ""


# --- Validation --------------------------------------------------------------

## Clamp every field into the range its race actually declares. Idempotent, and
## called on every path that produces a def from the outside world: the wire,
## the save file, the command line.
func validate() -> void:
	race = Races.valid_race(race)
	# Every race but the human is stocky only, so `build` is not a free field -
	# a lean dwarf would ask for a part set that does not exist.
	build = clampi(build, 0, Races.BUILD_COUNT - 1)
	if not Races.has_lean(race):
		build = Races.STOCKY
	skin = clampi(skin, 0, Races.skin_count(race) - 1)
	hair_color = clampi(hair_color, 0, Races.hair_color_count(race) - 1)
	eyes = clampi(eyes, 0, Races.eye_count(race) - 1)
	hair = clampi(hair, 0, Races.hair_count(race) - 1)
	# The dwarf's beard list has three entries and no "none" - a dwarf always
	# has a beard, because it is half its silhouette. The elf's list is empty,
	# so index 0 means "no beard part exists" rather than "the none option".
	var beards := Races.beard_count(race)
	beard = clampi(beard, 0, maxi(beards - 1, 0))


func duplicate_def() -> CharacterDef:
	var out := CharacterDef.new()
	out.from_dict(to_dict())
	return out


# --- The wire ----------------------------------------------------------------

## Eight bytes: version, race, build, skin, hair colour, eyes, hair, beard.
##
## The name does NOT ride here. It is a String of arbitrary length and it is
## sanitised by a different rule, so packing it into a fixed byte array would
## either truncate it wrongly or make this array variable-length for no gain.
func to_bytes() -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(WIRE_BYTES)
	out[0] = WIRE_VERSION
	out[1] = race
	out[2] = build
	out[3] = skin
	out[4] = hair_color
	out[5] = eyes
	out[6] = hair
	out[7] = beard
	return out


## Bytes from a stranger to a character that can definitely be built.
##
## NEVER THROWS, never returns null, never returns something `validate()` would
## still object to. Everything that arrives is either understood and clamped,
## or discarded in favour of the default human with a warning naming what was
## wrong. Fed 100 random byte arrays in the self-test for exactly this reason.
static func from_bytes(data: PackedByteArray) -> CharacterDef:
	var out := CharacterDef.new()
	if data.size() != WIRE_BYTES:
		push_warning("[CharacterDef] appearance was %d bytes, wanted %d - using the default human" % [
			data.size(), WIRE_BYTES])
		out.validate()
		return out
	if data[0] != WIRE_VERSION:
		push_warning("[CharacterDef] appearance is wire version %d, this build speaks %d - using the default human" % [
			data[0], WIRE_VERSION])
		out.validate()
		return out
	out.race = data[1]
	out.build = data[2]
	out.skin = data[3]
	out.hair_color = data[4]
	out.eyes = data[5]
	out.hair = data[6]
	out.beard = data[7]
	out.validate()
	return out


## A display name that is safe to put on a Label3D and in a log line.
##
## Control characters are stripped rather than escaped: a newline in a nametag
## does not fail, it silently pushes half the name off the billboard, and a
## name is not worth a parser. An empty result becomes "peer N", so every
## player always has something to be called.
static func sanitise_name(raw: String, peer_id := 0) -> String:
	var clean := ""
	for c in raw:
		# Anything below space, plus DEL. Printable Unicode above that is left
		# alone - a friend whose name is not ASCII should still have it.
		if c.unicode_at(0) >= 32 and c.unicode_at(0) != 127:
			clean += c
	clean = clean.strip_edges()
	if clean.length() > NAME_MAX:
		clean = clean.substr(0, NAME_MAX)
		clean = clean.strip_edges()
	if clean.is_empty():
		return "peer %d" % peer_id
	return clean


# --- The save file -----------------------------------------------------------
#
# `to_dict` / `from_dict` rather than only the byte form, because the world
# save does not exist yet and when it does this is the shape it will take -
# a dictionary of named fields survives a new field being added, and an eight
# byte array does not.

func to_dict() -> Dictionary:
	return {
		"race": race, "build": build, "skin": skin,
		"hair_color": hair_color, "eyes": eyes,
		"hair": hair, "beard": beard, "name": name_text,
	}


func from_dict(data: Dictionary) -> void:
	race = int(data.get("race", Races.HUMAN))
	build = int(data.get("build", Races.STOCKY))
	skin = int(data.get("skin", 0))
	hair_color = int(data.get("hair_color", 0))
	eyes = int(data.get("eyes", 0))
	hair = int(data.get("hair", 0))
	beard = int(data.get("beard", 0))
	name_text = str(data.get("name", ""))
	validate()


func save() -> void:
	var err := ResourceSaver.save(self, SAVE_PATH)
	if err != OK:
		push_warning("[CharacterDef] could not save %s: %s" % [SAVE_PATH, error_string(err)])
	else:
		print("[Character] saved %s to %s" % [describe(), SAVE_PATH])


## The saved character, with the command line laid over the top.
##
## Flags override the file FOR THAT RUN ONLY and are never written back - a
## headless comparison run must not quietly change what Marcel sees when he
## next opens the game.
static func load_or_default() -> CharacterDef:
	var def := CharacterDef.new()
	if ResourceLoader.exists(SAVE_PATH):
		var res := ResourceLoader.load(SAVE_PATH, "", ResourceLoader.CACHE_MODE_IGNORE)
		if res is CharacterDef:
			def = res
		else:
			push_warning("[CharacterDef] %s is not a CharacterDef, using the default" % SAVE_PATH)
	def.validate()
	def.apply_cli_overrides(OS.get_cmdline_user_args())
	return def


## `--race NAME`, `--build stocky|lean`, `--look N`, `--name TEXT`.
##
## `--look N` is a DETERMINISTIC randomise, hashed from N through WorldHash
## rather than drawn from randi(). Hard rule 13 allows real randomness on the
## creation screen and this is not the creation screen: two headless runs of
## `--look 7` have to produce byte-identical appearance bytes or the two-peer
## test cannot tell a sync bug from a different character.
func apply_cli_overrides(argv: PackedStringArray) -> void:
	var look := argv.find("--look")
	if look >= 0 and look + 1 < argv.size():
		randomise_from(argv[look + 1].to_int())

	var i := argv.find("--race")
	if i >= 0 and i + 1 < argv.size():
		var found := Races.from_name(argv[i + 1])
		if found >= 0:
			race = found
		else:
			push_warning("[CharacterDef] --race %s is not a race, keeping %s" % [
				argv[i + 1], Races.name_of(race)])

	i = argv.find("--build")
	if i >= 0 and i + 1 < argv.size():
		var wanted: int = Races.BUILD_NAMES.find(argv[i + 1].strip_edges().to_lower())
		if wanted >= 0:
			build = wanted
		else:
			push_warning("[CharacterDef] --build %s is not a scheme" % argv[i + 1])

	i = argv.find("--name")
	if i >= 0 and i + 1 < argv.size():
		name_text = argv[i + 1]

	validate()


## Every appearance field, hashed from one integer. Same N, same character, on
## any machine, forever - the property that makes it usable in a test.
func randomise_from(n: int) -> void:
	race = Races.valid_race(int(WorldHash.hash01(n, 0, 0, SALT_LOOK) * Races.RACE_COUNT))
	build = Races.STOCKY
	if Races.has_lean(race) and WorldHash.hash01(n, 1, 0, SALT_LOOK) > 0.5:
		build = Races.LEAN
	skin = int(WorldHash.hash01(n, 2, 0, SALT_LOOK) * Races.skin_count(race))
	hair_color = int(WorldHash.hash01(n, 3, 0, SALT_LOOK) * Races.hair_color_count(race))
	eyes = int(WorldHash.hash01(n, 4, 0, SALT_LOOK) * Races.eye_count(race))
	hair = int(WorldHash.hash01(n, 5, 0, SALT_LOOK) * Races.hair_count(race))
	beard = int(WorldHash.hash01(n, 6, 0, SALT_LOOK) * maxi(Races.beard_count(race), 1))
	validate()


## Separates this use of the hash from every worldgen use of it, so a `--look`
## value can never correlate with where the trees are.
const SALT_LOOK := 771


func describe() -> String:
	return "%s %s \"%s\"" % [
		Races.BUILD_NAMES[build], Races.name_of(race),
		name_text if not name_text.is_empty() else "unnamed"]
