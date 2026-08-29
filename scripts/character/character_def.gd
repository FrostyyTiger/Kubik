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

## Bumped when the layout changes. A peer sending a version this build does not
## know gets the default human rather than a character built from misread
## bytes, which would be worse than no character at all.
##
## **VERSION 2 SINCE CHARACTER V2 STAGE 8.** Version 1 payloads still parse -
## see `from_bytes` - because a friend on an older build, and every save file
## written before the bump, must still produce the character they describe
## rather than a stranger.
const WIRE_VERSION := 2

## Bytes per version. `from_bytes` dispatches on the VERSION BYTE and then
## checks the length, rather than guessing the version from the length: two
## layouts could one day be the same size, and a wrong guess is a character
## built from misread bytes.
const WIRE_LENGTHS := {1: 8, 2: 20}

const WIRE_BYTES := 20

# --- Armour ------------------------------------------------------------------
#
# SIX SLOTS, TWO OF WHICH SHIP WITH NO GEOMETRY. Declared here rather than in
# `Armour` because it is the wire format that has to reserve room for them:
# filling `legs` and `hands` later must not need another version bump, and a
# byte costs nothing on a payload sent once per join.
#
# THIS IS NOT AN ITEM SYSTEM. There is no item table, no inventory, no rule
# about what grants a tier and no stats - Items v1 (Wave 3, G) owns all of
# that. What is here is the minimum for a character to WEAR something and for a
# friend to see it: an id per slot, a tier per slot, and the validation that
# stops either being a lie.

enum {
	SLOT_TORSO = 0,
	SLOT_SHOULDERS = 1,
	SLOT_BACK = 2,
	SLOT_HEAD = 3,
	SLOT_LEGS = 4,
	SLOT_HANDS = 5,
}

const ARMOUR_SLOTS := 6
const ARMOUR_SLOT_NAMES := ["torso", "shoulders", "back", "head", "legs", "hands"]

## Tier 0 is "nothing worn". 1 cloth, 2 hide, 3 mail, 4 plate, 5 named.
const TIER_MAX := 5

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

## Per slot: which piece, and what tier it is. Index by the SLOT_* enum.
##
## NOT IN THE SAVE FILE - see `to_dict`. This resource is the player's chosen
## APPEARANCE, and `DESIGN.md` is explicit that gear is world state living in
## the host's save: "The character lives in the world, on the host." A player
## who changes worlds must not arrive wearing the last world's plate.
@export var armour_item: Array[int] = [0, 0, 0, 0, 0, 0]
@export var armour_tier: Array[int] = [0, 0, 0, 0, 0, 0]


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

	# CLAMP, NEVER REJECT, exactly as every field above. A friend whose build
	# knows a piece this one does not must appear - wearing something else -
	# rather than not appear.
	armour_item = _sized(armour_item)
	armour_tier = _sized(armour_tier)
	for i in ARMOUR_SLOTS:
		armour_tier[i] = clampi(armour_tier[i], 0, TIER_MAX)
		armour_item[i] = clampi(armour_item[i], 0, Armour.piece_count(i) - 1)
		# A piece with no tier is not worn, and a tier with no piece is not
		# either. Keeping the two consistent here means nothing downstream has
		# to ask which of them it should believe.
		if armour_tier[i] == 0:
			armour_item[i] = 0


## An armour array of exactly the right length, whatever arrived.
static func _sized(values: Array) -> Array[int]:
	var out: Array[int] = [0, 0, 0, 0, 0, 0]
	for i in mini(values.size(), ARMOUR_SLOTS):
		out[i] = int(values[i])
	return out


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
	# Bytes 8-13 the piece per slot, 14-19 the tier per slot. ONE BYTE PER
	# FIELD, not packed: the appearance rides its own reliable RPC once per
	# join, not the twenty-times-a-second state table, so twelve bytes buys
	# nothing and costs this file the one-byte-per-field readability that makes
	# the layout checkable by eye.
	for i in ARMOUR_SLOTS:
		out[8 + i] = armour_item[i]
		out[8 + ARMOUR_SLOTS + i] = armour_tier[i]
	return out


## Bytes from a stranger to a character that can definitely be built.
##
## NEVER THROWS, never returns null, never returns something `validate()` would
## still object to. Everything that arrives is either understood and clamped,
## or discarded in favour of the default human with a warning naming what was
## wrong. Fed 100 random byte arrays in the self-test for exactly this reason.
static func from_bytes(data: PackedByteArray) -> CharacterDef:
	var out := CharacterDef.new()
	if data.is_empty():
		push_warning("[CharacterDef] appearance was empty - using the default human")
		out.validate()
		return out

	# DISPATCH ON THE VERSION BYTE, then check the length against what that
	# version declares. Guessing the version from the length would work today
	# and would misread the first pair of layouts that happen to be the same
	# size - and misreading is worse than refusing.
	var version: int = data[0]
	if not WIRE_LENGTHS.has(version):
		push_warning("[CharacterDef] appearance is wire version %d, this build speaks %s - using the default human" % [
			version, WIRE_LENGTHS.keys()])
		out.validate()
		return out
	var wanted: int = WIRE_LENGTHS[version]
	if data.size() != wanted:
		push_warning("[CharacterDef] appearance claims version %d but is %d bytes, wanted %d - using the default human" % [
			version, data.size(), wanted])
		out.validate()
		return out

	# Bytes 1..7 are identical in both versions, which is why version 2 could
	# be an APPEND rather than a re-layout.
	out.race = data[1]
	out.build = data[2]
	out.skin = data[3]
	out.hair_color = data[4]
	out.eyes = data[5]
	out.hair = data[6]
	out.beard = data[7]

	# A VERSION 1 PAYLOAD IS A REAL CHARACTER WEARING NOTHING, not a stranger.
	# Every save written before the bump and every peer on an older build is
	# describing the character it always described; only the armour is absent,
	# and absent armour is tier 0, which is a thing the game already has a word
	# for. Falling back to the default human here would silently change a
	# friend's race, which is the failure this whole file exists to avoid.
	if version >= 2:
		for i in ARMOUR_SLOTS:
			out.armour_item[i] = data[8 + i]
			out.armour_tier[i] = data[8 + ARMOUR_SLOTS + i]

	out.validate()
	return out


## THE COMPATIBILITY IS ONE-WAY, BY CONSTRUCTION, and that is correct.
##
## A new build reads an old payload. An OLD build reading a new one sees a
## version it does not know and falls back to the default human with a warning
## - which is the behaviour that was already written, and it fails safe. There
## is no way to make it fail better without the old build having been written
## to expect this one, so the honest thing is to say so rather than to imply
## the wire is symmetric.


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

## ARMOUR IS DELIBERATELY ABSENT. See the note on `armour_item`: this pair is
## the save file, `user://character.tres` is the player's chosen appearance, and
## `DESIGN.md` puts gear in the host's world save. A round trip through here
## comes back with every slot at tier 0, and the self-test asserts it - because
## the obvious "improvement" of adding two lines here would silently give a
## player their old world's plate in a new one.
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
	armour_item = [0, 0, 0, 0, 0, 0]
	armour_tier = [0, 0, 0, 0, 0, 0]
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
	# NO ARMOUR IN A RANDOM LOOK. `--look 7` is an APPEARANCE, and a
	# deterministic random character that arrived in tier-4 plate would quietly
	# change what every headless comparison run is looking at. The gallery's
	# armour sheets set tiers explicitly.
	armour_item = [0, 0, 0, 0, 0, 0]
	armour_tier = [0, 0, 0, 0, 0, 0]
	validate()


## Separates this use of the hash from every worldgen use of it, so a `--look`
## value can never correlate with where the trees are.
const SALT_LOOK := 771


func describe() -> String:
	return "%s %s \"%s\"" % [
		Races.BUILD_NAMES[build], Races.name_of(race),
		name_text if not name_text.is_empty() else "unnamed"]
