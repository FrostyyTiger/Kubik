class_name Races

## The four races, as data. Dimensions, bone tables, palettes, option counts.
##
## EVERY PER-RACE NUMBER IN THE GAME LIVES HERE. Hard rule 3: race is never a
## stat. One capsule, one camera pivot height, one MAX_STEP, one speed table,
## for every race - so `player.gd` must not contain a single number from this
## file, and the way to guarantee that is for there to be exactly one file that
## has them. The dwarf's head sits at 1.5 m inside a 2 m capsule and the elf's
## pokes 0.25 m above it. That is cosmetic, and it is by decision.
##
## The tables below are the plan's starting numbers. Anything tuned by eye
## afterwards is recorded in docs/status/character-v1.md under "Tuned blind".


enum {
	HUMAN = 0,
	ELF = 1,
	DWARF = 2,
	LIZARDFOLK = 3,
}

const RACE_COUNT := 4
const RACE_NAMES := ["human", "elf", "dwarf", "lizardfolk"]

## Proportion schemes. The human is built in both and Marcel picks in the
## morning; every other race clamps to stocky.
enum {
	STOCKY = 0,
	LEAN = 1,
}

const BUILD_COUNT := 2
const BUILD_NAMES := ["stocky", "lean"]


# --- The stack ---------------------------------------------------------------
#
# THE PLAN'S PART TABLE SUMS TO 28, AND THE HUMAN IS 32.
#
# "Head 9, Neck 0, Torso 10, Legs 9" stacks to 28 voxels, or 1.75 m, against a
# fixed total of 32 voxels = 2.00 m that the plan states twice and makes a
# self-test of. Rather than inflate three tabled numbers to close a four-voxel
# gap, the four voxels go where a voxel character usually has them and where
# this rig already needed a bone: the HIPS.
#
# `hips` is the root bone of the plan's own bone list and every bone in that
# list must have a part. A four-voxel pelvis between the legs and the torso
# gives it one, preserves every number in the proportion table exactly, and
# produces the Cube World stack the scheme is named after - short legs, a
# chunky middle, a big head:
#
#     legs   [0,  9)   9
#     pelvis [9, 13)   4
#     torso  [13, 23) 10
#     head   [23, 32)  9
#                     --
#                      32
#
# Recorded in the status doc as a departure. It is the only one in the
# proportion table.

## Model voxels, for readability of the tables below.
const V := VoxelModel.VOXEL_M


# --- The race table ----------------------------------------------------------
#
# `torso_w` / `torso_d` / `head` / `legs` / `arm_len` / `arm_w` are the plan's
# numbers in model voxels. `pelvis` is derived: total - legs - torso - head.

const TABLE := [
	{
		"name": "human",
		"total": 32, "legs": 9, "torso": 10, "head": 9,
		"torso_w": 8, "torso_d": 5, "head_w": 8, "head_d": 8,
		"leg_w": 3, "arm_len": 9, "arm_w": 3,
		"lean_deg": 0.0,
		"silhouette": "the reference: square shoulders",
	},
	{
		"name": "elf",
		"total": 36, "legs": 12, "torso": 10, "head": 9,
		# torso 5 and legs 2, narrowed from the table's 6 and 3 in silhouette
		# pass 3 - see PartsElf. "Width" is on the plan's own list of features
		# an elf may be exaggerated by.
		"torso_w": 5, "torso_d": 4, "head_w": 8, "head_d": 8,
		"leg_w": 2, "arm_len": 11, "arm_w": 2,
		"neck": 2, "ear_out": 3,
		"lean_deg": 0.0,
		"silhouette": "tall and narrow, ears",
	},
	{
		"name": "dwarf",
		# TORSO 9, NOT THE TABLE'S 10. legs 5 + torso 10 + head 10 is 25 and
		# the dwarf's fixed total is 24, so one voxel has to come out of
		# something. The torso is the one that is not a silhouette feature:
		# the head and the beard are half of what makes a dwarf nameable at
		# 40 m, and the legs are already the shortest in the game.
		"total": 24, "legs": 5, "torso": 9, "head": 10,
		"torso_w": 12, "torso_d": 7, "head_w": 10, "head_d": 8,
		"leg_w": 4, "arm_len": 8, "arm_w": 4,
		"lean_deg": 0.0,
		"silhouette": "as wide as it is tall, beard",
	},
	{
		"name": "lizardfolk",
		"total": 30, "legs": 9, "torso": 10, "head": 9,
		"torso_w": 8, "torso_d": 5, "head_w": 8, "head_d": 8,
		"leg_w": 3, "arm_len": 9, "arm_w": 3,
		"snout": 4, "tail_len": 14, "tail_segments": [5, 5, 4],
		"lean_deg": 8.0,
		"silhouette": "tail, crest, snout",
	},
]


# --- Palettes ----------------------------------------------------------------
#
# sRGB hex in the table, converted to linear ONCE at load - the convention
# Block.COLORS records and the reason it records it. A vertex colour fed
# straight from a hex value renders pale and washed out, and every palette here
# would arrive on screen as a different, weaker palette than the one authored.
#
# All of these are STARTING VALUES, tuned blind on a renderer that is not the
# one Marcel will judge them on. Every one is in the status doc's re-check
# table.

const SKIN_HEX := [
	["#F1C9A5", "#E0AC7E", "#C68642", "#8D5524", "#4A2C17"],
	["#F5E3D3", "#E8C9B0", "#C7A98A", "#9FA8A3", "#6F7F73"],
	["#E9B48E", "#D08C5A", "#B36A3C", "#8A4B2A", "#5A3420"],
	["#4E8A3C", "#2F6F6A", "#B8A05A", "#8A3F2A", "#3A3F4A"],
]

const HAIR_HEX := [
	["#1B1411", "#4A2E1B", "#C9A05A", "#A63A1E", "#B8B2A8"],
	["#E8E4DA", "#F0D9A0", "#2A1E1A", "#7A4B2A", "#4C5A3C"],
	["#A8321E", "#C27A2C", "#3B2A1F", "#1E1A17", "#D8D2C6"],
	["#D14A2A", "#E0B030", "#2A7FB0", "#6A2A8A", "#F0E6D0"],
]

const EYE_HEX := [
	["#4B2E1A", "#3A6EA5", "#4E7B3A", "#7A7A7A"],
	["#7FB2D9", "#57A773", "#C9A227", "#6A5ACD"],
	["#3F2A1A", "#2F5F8F", "#6B6B6B", "#7B5B2A"],
	["#E0B030", "#C93A2A", "#101010", "#9AD0C0"],
]

## Fixed slots, the same for everyone. The torso belongs to the gear plan, so
## v1 has one outfit per race and no picker for it.
const EYE_WHITE_HEX := "#F4F0E8"
const TOOTH_HEX := "#EDE6D4"
const METAL_HEX := "#9A9FA6"
const WOOD_HEX := "#7A5230"
const CLOTH_HEX := "#7A6A4F"
const LEATHER_HEX := "#3A2A1E"
const BELT_HEX := "#5A4632"

## Per-race tunic, where the race has one. Elf green, dwarf brown, human and
## lizardfolk the default.
const TUNIC_HEX := ["#7A6A4F", "#5C7A5A", "#6B4F3A", "#7A6A4F"]


# --- Options -----------------------------------------------------------------
#
# The dwarf's beard is half its silhouette, so a dwarf ALWAYS has a beard: its
# beard list has three entries and none of them is "none". The elf has no beard
# option at all. The lizardfolk has no hair; its hair slot holds a crest.

const HAIR_OPTIONS := [
	["short", "long", "tied back"],
	["short", "long", "braided"],
	["short", "long", "braided"],
	["crest low", "crest tall", "frill"],
]

const BEARD_OPTIONS := [
	["none", "short", "full"],
	[],
	["short", "full", "forked"],
	[],
]

## Which races have a lean part set. `CharacterDef.validate()` clamps `build`
## to stocky for every race not in here.
const HAS_LEAN := [true, false, false, false]


# --- Lookups -----------------------------------------------------------------

static func valid_race(race: int) -> int:
	return clampi(race, 0, RACE_COUNT - 1)


static func name_of(race: int) -> String:
	return RACE_NAMES[valid_race(race)]


## Race index from a name, or -1. For the `--race` CLI flag.
static func from_name(text: String) -> int:
	return RACE_NAMES.find(text.strip_edges().to_lower())


static func table(race: int) -> Dictionary:
	return TABLE[valid_race(race)]


static func has_lean(race: int) -> bool:
	return HAS_LEAN[valid_race(race)]


static func skin_count(race: int) -> int:
	return SKIN_HEX[valid_race(race)].size()


static func hair_color_count(race: int) -> int:
	return HAIR_HEX[valid_race(race)].size()


static func eye_count(race: int) -> int:
	return EYE_HEX[valid_race(race)].size()


static func hair_count(race: int) -> int:
	return HAIR_OPTIONS[valid_race(race)].size()


## Zero for the elf and the lizardfolk, which is what makes the beard row
## disappear from the creation screen rather than showing one dead option.
static func beard_count(race: int) -> int:
	return BEARD_OPTIONS[valid_race(race)].size()


# --- Derived geometry --------------------------------------------------------

## Total height in metres. The number the height self-test checks a built
## character against.
static func height_m(race: int, build := STOCKY) -> float:
	return float(dims(race, build)["total"]) * V


## Where this race's eyes are, in metres above its feet.
##
## Derived from its own stack rather than tabled, so a change to leg or torso
## height cannot leave the head-look and the gallery camera aiming at a face
## that has moved. The eyes sit about two thirds of the way up the head.
static func eye_height_m(race: int, build := STOCKY) -> float:
	var t := dims(race, build)
	var head_bottom: int = t["total"] - t["head"]
	return (float(head_bottom) + float(t["head"]) * 0.62) * V


## Leg length in metres. The stride scales with this, which is what makes the
## dwarf take short quick steps and the elf long slow ones from one table.
static func leg_length_m(race: int, build := STOCKY) -> float:
	if build == LEAN and has_lean(race):
		return float(LEAN_HUMAN["legs"]) * V
	return float(table(race)["legs"]) * V


## The pelvis, which is the height the rest of the stack does not spend. See
## the note at the top of this file. Zero is a legal answer - the lean human
## and the dwarf have no pelvis block at all, and their `hips` bone is a pure
## transform with a socket on it.
static func pelvis_height(race: int, build := STOCKY) -> int:
	var t := dims(race, build)
	var out: int = t["total"] - t["legs"] - t["torso"] - t["head"] - int(t.get("neck", 0))
	if out < 0:
		push_warning("[Races] %s %s stacks to %d voxels, %d more than its total" % [
			name_of(race), BUILD_NAMES[build], t["total"] - out, -out])
		return 0
	return out


# --- The lean human ----------------------------------------------------------
#
# The second scheme, for the proportion study in Stage 7. Same total height,
# same animator, different bone lengths - which is the entire point of the
# comparison: if the two schemes needed two animators the study would be
# measuring the animator instead of the proportions.

const LEAN_HUMAN := {
	"name": "human", "total": 32, "legs": 14, "torso": 11, "head": 6,
	"torso_w": 7, "torso_d": 4, "head_w": 6, "head_d": 6,
	"leg_w": 2, "arm_len": 12, "arm_w": 2, "neck": 1,
	"lean_deg": 0.0,
	"silhouette": "naturalistic: neck and shoulders",
}


## The dimension table for a race in a given build.
static func dims(race: int, build := STOCKY) -> Dictionary:
	if build == LEAN and has_lean(race):
		return LEAN_HUMAN
	return table(race)


# --- Palette resolution ------------------------------------------------------

## The full slot -> linear Color table for one character.
##
## THIS IS THE ONLY PLACE A SLOT BECOMES A COLOUR. Parts are authored in slots
## and the mesher resolves them through whatever dictionary it is handed, so
## the same voxels with a different table are a different-looking character -
## and there is exactly one table builder, so there is no second place for a
## palette to be half-applied.
static func palette(race: int, skin_index: int, hair_index: int, eye_index: int) -> Dictionary:
	var r := valid_race(race)
	var skin := _linear(SKIN_HEX[r][clampi(skin_index, 0, SKIN_HEX[r].size() - 1)])
	var hair := _linear(HAIR_HEX[r][clampi(hair_index, 0, HAIR_HEX[r].size() - 1)])
	var eyes := _linear(EYE_HEX[r][clampi(eye_index, 0, EYE_HEX[r].size() - 1)])
	var cloth := _linear(TUNIC_HEX[r])
	return {
		VoxelModel.SKIN: skin,
		# Derived rather than authored: a shaded skin that is not the skin
		# times a constant drifts away from it the moment the skin is retuned.
		VoxelModel.SKIN_SHADED: _scale(skin, 0.80),
		VoxelModel.HAIR: hair,
		VoxelModel.IRIS: eyes,
		VoxelModel.EYE_WHITE: _linear(EYE_WHITE_HEX),
		VoxelModel.MOUTH: _scale(skin, 0.55),
		VoxelModel.CLOTH: cloth,
		VoxelModel.CLOTH_DARK: _scale(cloth, 0.75),
		VoxelModel.LEATHER: _linear(LEATHER_HEX),
		VoxelModel.BELT: _linear(BELT_HEX),
		VoxelModel.TOOTH: _linear(TOOTH_HEX),
		VoxelModel.METAL: _linear(METAL_HEX),
		VoxelModel.WOOD: _linear(WOOD_HEX),
	}


## sRGB hex to the linear value the renderer actually wants. See Block.COLORS:
## a vertex colour is treated as already linear, so feeding it a hex value
## directly draws it far brighter and far less saturated than intended.
static func _linear(hex: String) -> Color:
	return Color.html(hex).srgb_to_linear()


## A multiply in LINEAR space, which is what "80% as bright" means physically.
## Alpha is left alone.
static func _scale(c: Color, f: float) -> Color:
	return Color(c.r * f, c.g * f, c.b * f, c.a)


# --- The rig -----------------------------------------------------------------
#
# ONE BONE TABLE BUILDER FOR EVERY RACE AND BOTH SCHEMES, derived from the
# dimensions above rather than written out four times. That is not tidiness: a
# hand-written table per race is four places for a shoulder to end up in a
# different spot, and the whole proportion study rests on the two human schemes
# differing ONLY in their numbers.
#
# Rest offsets are relative to the parent bone, in metres.

## Bones and sockets for one character, parents before children.
##
## An entry is `{name, parent, rest, part, mirror, socket}`. `part` is the key
## into the race's part set; a socket has no part and exists to hang gear on.
static func bone_table(race: int, build := STOCKY) -> Array:
	var t := dims(race, build)
	var legs: int = t["legs"]
	var torso: int = t["torso"]
	var neck: int = t.get("neck", 0)
	var pelvis := pelvis_height(race, build)
	var torso_w: int = t["torso_w"]
	var torso_d: int = t["torso_d"]
	var leg_w: int = t["leg_w"]
	var arm_w: int = t["arm_w"]
	var arm_len: int = t["arm_len"]

	# One voxel of daylight between the legs, so a walk cycle has somewhere to
	# swing into and the two do not read as one column.
	var leg_x := (float(leg_w) + 1.0) * 0.5
	# Arms hang flush against the outside of the torso.
	var arm_x := float(torso_w) * 0.5 + float(arm_w) * 0.5
	# The shoulder is one voxel down from the top of the torso, so the arm's
	# top face is level with the shoulder line rather than poking above it.
	var shoulder_y := float(torso - 1)

	var out := [
		{"name": "hips", "parent": "", "rest": Vector3(0, legs, 0) * V,
			"part": "pelvis" if pelvis > 0 else ""},
		{"name": "torso", "parent": "hips", "rest": Vector3(0, pelvis, 0) * V,
			"part": "torso"},
		# THE NECK IS PART OF THE HEAD PART, not an offset here. A race with a
		# neck authors it as the bottom slices of its head, so the head bone
		# sits at the top of the torso and the head rotates about the BASE of
		# the neck - which is where a head-look should pivot. Offsetting by
		# `neck` here as well would double-count it and leave a gap.
		{"name": "head", "parent": "torso", "rest": Vector3(0, torso, 0) * V,
			"part": "head"},
		{"name": "arm_r", "parent": "torso", "rest": Vector3(arm_x, shoulder_y, 0) * V,
			"part": "arm"},
		{"name": "arm_l", "parent": "torso", "rest": Vector3(-arm_x, shoulder_y, 0) * V,
			"part": "arm", "mirror": true},
		{"name": "leg_r", "parent": "hips", "rest": Vector3(leg_x, 0, 0) * V,
			"part": "leg"},
		{"name": "leg_l", "parent": "hips", "rest": Vector3(-leg_x, 0, 0) * V,
			"part": "leg", "mirror": true},
	]

	# The tail is a CHAIN, and the chain machinery is generic because the
	# critter in Stage 13 needs it too. Bones are named `<chain>_1..n` and the
	# animator finds them by that name alone.
	# SEGMENT LENGTHS ARE TABLED, not divided out. 14 voxels over three bones
	# is 4.67 each, and a part cannot be 4.67 voxels deep - so the table gives
	# the three lengths that add to 14 and each bone's rest offset is the
	# PREVIOUS segment's length. The chain is then continuous by construction
	# rather than by three numbers happening to agree.
	var segments: Array = t.get("tail_segments", [])
	for i in segments.size():
		out.append({
			"name": "tail_%d" % (i + 1),
			"parent": "hips" if i == 0 else "tail_%d" % i,
			# The first link starts at the back of the pelvis, a little above
			# the hip pivot; the rest follow their parent's own length.
			"rest": (Vector3(0, 1, float(torso_d) * 0.5) if i == 0
				else Vector3(0, 0, float(segments[i - 1]))) * V,
			"part": "tail_%d" % (i + 1),
		})

	# Hair and beard hang off the head in ITS frame, so both bones sit exactly
	# on the head bone and the parts carry their own offsets. Optional, because
	# "none" is a real answer for a human's beard and for every race that has
	# no crest - Rig says nothing about an optional bone with no part.
	if hair_count(race) > 0:
		out.append({"name": "hair", "parent": "head", "rest": Vector3.ZERO,
			"part": "hair", "optional": true})
	if beard_count(race) > 0:
		out.append({"name": "beard", "parent": "head", "rest": Vector3.ZERO,
			"part": "beard", "optional": true})

	out.append_array(socket_table(race, build))
	return out


## The six sockets, on every race, positioned from that race's own numbers.
##
## ALL SIX EXIST EVERYWHERE even where nothing will ever hang on them, because
## the deliverable of Stage 10 is the sockets and not the placeholders - a gear
## system that has to ask which races have a back is not a gear system.
static func socket_table(race: int, build := STOCKY) -> Array:
	var t := dims(race, build)
	var torso: int = t["torso"]
	var torso_d: int = t["torso_d"]
	var arm_len: int = t["arm_len"]
	var pelvis := pelvis_height(race, build)
	var chest_y := float(torso) * 0.7
	return [
		{"name": "hand_r", "parent": "arm_r", "rest": Vector3(0, -arm_len, 0) * V, "socket": true},
		{"name": "hand_l", "parent": "arm_l", "rest": Vector3(0, -arm_len, 0) * V, "socket": true},
		{"name": "neck", "parent": "torso", "rest": Vector3(0, torso, 0) * V, "socket": true},
		{"name": "chest", "parent": "torso", "rest": Vector3(0, chest_y, -float(torso_d) * 0.5) * V, "socket": true},
		{"name": "back", "parent": "torso", "rest": Vector3(0, chest_y, float(torso_d) * 0.5) * V, "socket": true},
		{"name": "belt", "parent": "hips", "rest": Vector3(0, pelvis, 0) * V, "socket": true},
	]


const SOCKET_NAMES := ["hand_r", "hand_l", "neck", "chest", "back", "belt"]


## Which races have their OWN parts, rather than borrowing the human's.
##
## All four, since Stage 8. The flag stays because it is what the height and
## completeness self-tests gate on: one place to change when a part set lands,
## and no way for a test to be left quietly excluding a race that now exists.
## Stage 13's critter is not a race and does not appear here.
const HAS_PART_SET := [true, true, true, true]

static func has_part_set(race: int) -> bool:
	return HAS_PART_SET[valid_race(race)]


## The part set for a race and scheme.
##
## Stage 3 has only the stocky human. Every other race falls back to it WITH A
## WARNING rather than failing to build: a remote view must never fail to
## build, and the same rule is worth having on this side of the branch too - a
## half-finished run should still show you something walking around.
static func part_set(race: int, build := STOCKY) -> Dictionary:
	if build == LEAN and has_lean(race):
		return PartsHumanLean.PARTS
	match valid_race(race):
		ELF:
			return PartsElf.PARTS
		DWARF:
			return PartsDwarf.PARTS
		LIZARDFOLK:
			return PartsLizardfolk.PARTS
		_:
			return PartsHuman.PARTS


## The part set for one CHARACTER, with its chosen hair and beard resolved in.
##
## The rig is built from (bone table, part set), and neither of those knows
## which hair a player picked - so the choice is resolved HERE, once, into a
## part set that already has "hair" and "beard" in it. That keeps the def out
## of Rig entirely: a rig builds whatever parts it is handed and has no opinion
## about where they came from, which is what lets the critter in Stage 13 use
## the same class with no hair at all.
static func parts_for(def: CharacterDef) -> Dictionary:
	var out := part_set(def.race, def.build).duplicate()
	var hair = PartsHair.hair_part(def.race, def.hair)
	if hair != null:
		out["hair"] = hair
	var beard = PartsHair.beard_part(def.race, def.beard)
	if beard != null:
		out["beard"] = beard
	return out


## Warn about a missing part set ONCE per key, not once per build.
##
## The 100-random-appearance self-test builds a character per payload, most of
## them not human, and one warning each buried the suite's own output under
## four hundred lines of backtrace. A warning nobody can read is not a warning.
static var _warned := {}

static func _warn_once(key: String, message: String) -> void:
	if _warned.has(key):
		return
	_warned[key] = true
	push_warning(message)


## The 8 degree forward lean baked into the lizardfolk's hips.
static func hips_pitch_rad(race: int) -> float:
	return deg_to_rad(float(table(race).get("lean_deg", 0.0)))
