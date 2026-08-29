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

## Proportion schemes. Character v1 built the human in both and the look plan
## DECIDED STOCKY for every race; the lean part set is gone. LEAN stays here
## because `build` is a byte on the wire and in the save file, and a def that
## still says 1 must clamp to 0 rather than fail to parse.
enum {
	STOCKY = 0,
	LEAN = 1,
}

const BUILD_COUNT := 2
const BUILD_NAMES := ["stocky", "lean"]


# --- The stack ---------------------------------------------------------------
#
# ONE MODEL VOXEL IS 1/24 OF A BLOCK since character v2, and a human is 96 of
# them. See `VoxelModel.VOXEL_M` for why 96 and why not 128; the short version
# is that a 16-voxel leg cannot have a knee and a 24-voxel one can.
#
#     legs   [0, 24)  24
#     pelvis [24, 33)  9
#     torso  [33, 63) 30
#     head   [63, 96) 33
#                     --
#                      96
#
# Head a third of the height, big hands, big boots - the Cube World stack the
# scheme is named after.
#
# STAGE 3 MOVED THE GRID AND NOTHING ELSE. Every number in the table below is
# its 64-grid value times 1.5, rounded, and no race's DESIGN changed here -
# that is Stages 5 and 6. Isolating the two is the point: if a silhouette
# number moves in this commit it is a bug, not a decision.
#
# THE PELVIS ABSORBS THE ROUNDING, and that is why it is derived rather than
# tabled. `pelvis_height()` is `total - legs - torso - head - neck`, so the
# stack sums to `total` by construction whatever 1.5x did to the parts. The elf
# is the case that needs it: its neck and pelvis were 3 and 3, which are 4.5
# and 4.5, and something has to give.
#
# EVERY HEIGHT IN METRES IS UNCHANGED - 2.00, 2.25, 1.50, 1.875 - because the
# totals and the voxel size moved by reciprocal factors. So the capsule, the
# camera pivot, MAX_STEP, the speed table and `player.gd` are untouched, and
# hard rule 3 still holds: race is never a stat.
#
# THE DESIGN DOC'S HUMAN STACK SUMS TO 94, NOT 96. It writes "total 96, legs
# 24, pelvis 8, torso 30, head 32". Since the pelvis is derived the code cannot
# reproduce that error; with the doc's other three numbers the pelvis comes out
# at 10. Stage 5 resolves it as a design question. This stage uses the
# mechanical 1.5x, which puts the human at legs 24, torso 30, head 33,
# pelvis 9. It is the same class of slip character v1 found in its own plan's
# table, and it is why the height self-test measures the BUILT RIG rather than
# summing the table - a height computed from the table would only prove the
# table agrees with itself.

# `torso_rise` IS HOW FAR THE TORSO PART RISES ABOVE ITS SLICE OF THE STACK.
# Zero for the human and the lizardfolk. Five for the elf, whose standing
# collar is a ring the neck comes up through; four for the dwarf, whose
# shoulders carry straight past the point where the head bone sits so that the
# head is set BETWEEN them rather than above them.
#
# It is a table field rather than a number inside a generator because two other
# things need to know: `parts match the table` would otherwise report a torso
# taller than the table says, and it is exactly the sort of per-race fact the
# fourth pillar wants readable rather than buried in Python.
#
# It does NOT move the head bone. The head still sits at `torso`, which is what
# keeps the stack summing and the height test honest; the rise is geometry
# around the head, not a change to where the head is.

# THE GAIT TABLE, in words, because a column of multipliers is not a design.
#
# The key is `gait_scale` and NOT `gait`, which was already taken: `dims["gait"]`
# names the RIG SHAPE - "biped", "trot" - that Animator.rig_shape looks up, and
# putting a dictionary there made every character in the game pose zero bones.
# Two different things called the same obvious name, one of them four stages
# older; the self-tests caught it in a minute and the collision is worth a
# sentence so nobody re-introduces it.
#
#   the elf GLIDES and takes a long time to stop - long slow strides, the
#   widest arm swing in the cast, and a settle a third longer than anyone's.
#   the dwarf is a PISTON - short, quick, low bob, settles instantly, and
#   fidgets constantly.
#   the lizardfolk's power is in its SPINE, so its counter-rotation and its
#   sprint lean are the highest in the cast and its arms do the least.
#   the human is 1.00 everywhere, which is what being the reference means.

## Model voxels, for readability of the tables below.
const V := VoxelModel.VOXEL_M


# --- The race table ----------------------------------------------------------
#
# `torso_w` / `torso_d` / `head` / `legs` / `arm_len` / `arm_w` are the plan's
# numbers in model voxels. `pelvis` is derived: total - legs - torso - head.

const TABLE := [
	# `leg_w` and `arm_w` are the widths the BONE TABLE spaces limbs by - the
	# boot and the hand, which are a voxel wider than the trouser and the
	# sleeve - so two boots touch at the centre line rather than sharing a
	# voxel, and a hand hangs flush with the torso with a voxel of daylight at
	# the armpit. `head_d` is the skull; the nose is one more in front of it.
	{
		"name": "human",
		# HOW THIS RACE MOVES, as multipliers on knobs that already exist.
		# Race is never a stat and gait is not one either: this is the same
		# animator reading different numbers out of this table, exactly as
		# stride already scales with leg length. Nothing here reaches the
		# simulation.
		"gait_scale": {"cadence": 1.00, "arm": 1.00, "twist": 1.00,
			"bob": 1.00, "lean": 1.00, "settle": 1.00, "idle": 1.00},
		"total": 96, "legs": 24, "torso": 30, "head": 32,
		"torso_w": 30, "torso_d": 17, "head_w": 27, "head_d": 24,
		"leg_w": 12, "arm_len": 30, "arm_w": 12,
		"lean_deg": 0.0,
		"silhouette": "the reference: square stepped shoulders",
	},
	{
		"name": "elf",
		# HOW THIS RACE MOVES, as multipliers on knobs that already exist.
		# Race is never a stat and gait is not one either: this is the same
		# animator reading different numbers out of this table, exactly as
		# stride already scales with leg length. Nothing here reaches the
		# simulation.
		"gait_scale": {"cadence": 0.85, "arm": 1.35, "twist": 1.20,
			"bob": 1.15, "lean": 0.80, "settle": 1.30, "idle": 0.70},
		"total": 108, "legs": 36, "torso": 30, "head": 28, "torso_rise": 5,
		"torso_w": 18, "torso_d": 12, "head_w": 24, "head_d": 24,
		"leg_w": 9, "arm_len": 36, "arm_w": 9,
		"neck": 5, "ear_out": 9,
		"lean_deg": 0.0,
		"silhouette": "tall and narrow, ears",
	},
	{
		"name": "dwarf",
		# HOW THIS RACE MOVES, as multipliers on knobs that already exist.
		# Race is never a stat and gait is not one either: this is the same
		# animator reading different numbers out of this table, exactly as
		# stride already scales with leg length. Nothing here reaches the
		# simulation.
		"gait_scale": {"cadence": 1.20, "arm": 0.65, "twist": 0.60,
			"bob": 0.55, "lean": 1.10, "settle": 0.55, "idle": 1.40},
		"total": 72, "legs": 15, "torso": 27, "head": 30, "torso_rise": 5,
		"torso_w": 39, "torso_d": 21, "head_w": 30, "head_d": 24,
		"leg_w": 15, "arm_len": 24, "arm_w": 15,
		"lean_deg": 0.0,
		"silhouette": "as wide as it is tall, beard",
	},
	{
		"name": "lizardfolk",
		# HOW THIS RACE MOVES, as multipliers on knobs that already exist.
		# Race is never a stat and gait is not one either: this is the same
		# animator reading different numbers out of this table, exactly as
		# stride already scales with leg length. Nothing here reaches the
		# simulation.
		"gait_scale": {"cadence": 1.10, "arm": 0.80, "twist": 1.40,
			"bob": 0.70, "lean": 1.60, "settle": 0.90, "idle": 1.20},
		"total": 90, "legs": 30, "torso": 30, "head": 24,
		"torso_w": 21, "torso_d": 17, "head_w": 24, "head_d": 24,
		"leg_w": 12, "arm_len": 30, "arm_w": 12,
		"snout": 12, "tail_len": 42, "tail_segments": [12, 12, 10, 8],
		"lean_deg": 26.0,
		# The digitigrade stance, in degrees about X, matched by bone-name
		# suffix. Thigh forward, shin back, foot forward onto the toes.
		"leg_stance": {"leg_r": 10.0, "leg_l": 10.0,
			"leg_r_lower": -22.0, "leg_l_lower": -22.0,
			"leg_r_foot": 14.0, "leg_l_foot": 14.0,
			"arm_r": 34.0, "arm_l": 34.0,
			"arm_r_lower": 46.0, "arm_l_lower": 46.0},
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

# --- The liner, and the value tiers -------------------------------------------
#
# THE LOOK V2 TUNIC RULE IS RETIRED, character v2 Stage 1, and the reason it had
# to go is arithmetic rather than taste.
#
# It asked that cloth and skin cross a value ratio of 0.5 or lower - one at most
# half the other - for EVERY skin a player can pick. Each race's five skins span
# most of the luminance range (the human's from 0.033 to 0.632), so a tunic
# clears all five only by sitting below the darkest or above the lightest. Above
# is impossible for every race but the lizardfolk. Below works, and it is the
# only thing that works, so four races solved one constraint and arrived at the
# same answer:
#
#     human #262119 Y 0.0157   elf #465C44 Y 0.0937
#     dwarf #34271C Y 0.0226   lizardfolk #302A1F Y 0.0238
#
# Four hues, all under Y 0.10, against grass at Y 0.221. On screen that is four
# black rectangles, and the elf's is nominally green and six times the human's
# luminance and you cannot tell. The constraint had exactly one solution.
#
# THE FIX IS STRUCTURAL: put a fixed dark LINER between skin and cloth - one or
# two voxels of a constant near-black at every boundary where skin meets cloth,
# at the collar, the cuff, the waist and the boot top. The pair that has to
# carry the contrast becomes skin/liner, and it holds BY CONSTRUCTION:
#
#     lightest elf  #F5E3D3   144.8x the liner
#     darkest human #4A2C17     6.1x the liner   <- the worst case in the game
#
# 6.1:1 against the 2.1:1 the old rule scraped. And the cloth is then free: any
# hue, any value above about Y 0.03, because it is no longer the thing doing the
# separating. This is how comic inking works and it is why an inked figure can
# wear any colour without dissolving.

## The liner. ONE VALUE FOR EVERY RACE AND EVERY PALETTE, and never a player
## pick - the moment it varies it stops being a constant the contrast can be
## proved against.
const LINER_HEX := "#14100C"

## Every race spans at least three value tiers, and places them in the same
## structural spots so the cast reads as one family. Grass is Y 0.221 and dusk
## sky is Y 0.03 to 0.08: a character that is entirely mid-value dissolves into
## the meadow and one that is entirely dark dissolves into dusk. The old cast
## was entirely dark, which is why it was VISIBLE at both times of day and
## IDENTIFIABLE at neither.
##
##     liner  0.005 - 0.012   every skin/cloth boundary, seams, boot tops
##     deep   0.03  - 0.09    legs, the lower half, under-layer, shadowed cloth
##     mid    0.15  - 0.30    the torso mass; the race's main hue lives here
##     light  0.45  - 0.70    ONE element: hair, a collar, a beard, a belly
##     accent any            saturated, under 10% of silhouette, the identity
##
## The light tier does a specific job: it is what stays visible when the whole
## figure has gone to silhouette at dusk. The elf's white hair is already doing
## it by accident and it is the only thing in `silhouettes-15.png` that works.
##
## Measured Y, in order human / elf / dwarf / lizardfolk.
const DEEP_HEX := ["#4C5566", "#3E4550", "#7A2320", "#7A5A26"]    # .090 .059 .054 .116
const MID_HEX := ["#6E7A8C", "#7C8794", "#A83A2E", "#B98A3A"]     # .191 .238 .116 .288
const LIGHT_HEX := ["#D8D2C2", "#D8D2C2", "#D9C08A", "#C9B48E"]   # .646 .646 .543 .478
const ACCENT_HEX := ["#B98A34", "#8C6FB0", "#B07A2A", "#9FB8C4"]  # .287 .201 .233 .456

## Fixed material slots that are nobody's race in particular.
##
## A MATERIAL IS ONE BASE VALUE PLUS A HUE AND A SATURATION. Form comes from the
## baked AO; contrast comes from putting two materials next to each other, never
## from shading one of them. So metal looks like metal because a BRIGHT RIM sits
## beside a DARK BODY across a real geometric edge that the mesher's own AO
## darkens - `TRIM_BRIGHT` over `METAL_DARK`, 6.6x apart, with one voxel of
## relief between them. Hand-painting a second shading on top of the baked AO
## double-darkens every concave corner and produces mud; see the design doc's
## argument against non-metallic-metal painting.
const TRIM_BRIGHT_HEX := "#B9C0C9"   # Y 0.522, the steel rim
const METAL_DARK_HEX := "#4A5058"    # Y 0.079, the body it sits on

## The scale/mail checker, two ADJACENT values one step apart. Free LOD: at 5 m
## you see individual scales, at 15 m the checker averages to a flat Y 0.10,
## which is what mail looks like from across a field.
const SCALE_A_HEX := "#47665A"       # Y 0.116
const SCALE_B_HEX := "#3C574D"       # Y 0.083

## The tier-5 rune. Cold and bright, and CAPPED AT 12 VOXELS by a self-test -
## the cap is the design. A rune band on one pauldron is a story; a glowing
## character is what every game does wrong, and the only thing between the two
## is a number that somebody enforces.
const GLOW_HEX := "#8FD8FF"


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

## Which races have a lean part set. NONE, since look v1 decided every race is
## stocky and retired `parts_human_lean.gd`. `CharacterDef.validate()` clamps
## `build` to stocky for every race not in here, which is how a save file or a
## peer that still says "lean" gets a stocky human rather than an error. Kept
## as a table rather than deleted so the machinery is one line from coming
## back if a second scheme is ever wanted.
const HAS_LEAN := [false, false, false, false]


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
	return float(dims(race, build)["legs"]) * V


## The pelvis, which is the height the rest of the stack does not spend. See
## the note at the top of this file. Zero is a legal answer - the dwarf has no
## pelvis block at all, and its `hips` bone is a pure transform with a socket
## on it.
static func pelvis_height(race: int, build := STOCKY) -> int:
	var t := dims(race, build)
	var out: int = t["total"] - t["legs"] - t["torso"] - t["head"] - int(t.get("neck", 0))
	if out < 0:
		push_warning("[Races] %s %s stacks to %d voxels, %d more than its total" % [
			name_of(race), BUILD_NAMES[build], t["total"] - out, -out])
		return 0
	return out


## The dimension table for a race in a given build.
##
## `build` is accepted and ignored: there is one scheme per race since look
## v1. The parameter stays so the self-tests, the gallery and the animator
## keep asking the question the way they always did, and a second scheme
## would answer it here and nowhere else.
static func dims(race: int, _build := STOCKY) -> Dictionary:
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
	var out := {}
	# THE TORSO'S MID TIER IS THE CLOTH. Released from the look v2 rule: it is
	# the race's main hue at its own value, because the liner is what separates
	# it from skin now. `CLOTH_DARK` is the deep tier rather than a scale of the
	# mid, so the two tiers are authored values rather than one value and a
	# multiplier that drifts.
	var cloth := _linear(MID_HEX[r])
	out = {
		VoxelModel.SKIN: skin,
		# Derived rather than authored: a shaded skin that is not the skin
		# times a constant drifts away from it the moment the skin is retuned.
		VoxelModel.SKIN_SHADED: _scale(skin, 0.80),
		VoxelModel.HAIR: hair,
		VoxelModel.IRIS: eyes,
		VoxelModel.EYE_WHITE: _linear(EYE_WHITE_HEX),
		VoxelModel.MOUTH: _scale(skin, 0.55),
		VoxelModel.CLOTH: cloth,
		VoxelModel.CLOTH_DARK: _linear(DEEP_HEX[r]),
		VoxelModel.LEATHER: _linear(LEATHER_HEX),
		VoxelModel.BELT: _linear(BELT_HEX),
		VoxelModel.TOOTH: _linear(TOOTH_HEX),
		VoxelModel.METAL: _linear(METAL_HEX),
		VoxelModel.WOOD: _linear(WOOD_HEX),
		VoxelModel.LINER: _linear(LINER_HEX),
		# COUNTERSHADING, and it costs zero extra voxels because it is a palette
		# split of a slot that already exists. Derived from the skin rather than
		# tabled so it tracks the player's pick: a belly is the same animal's
		# hide with the sun on it, not a different colour. Mixed toward white in
		# LINEAR space, which is what "lighter" physically means.
		VoxelModel.SKIN_VENTRAL: _lighten(skin, 0.55),
		VoxelModel.TRIM_BRIGHT: _linear(TRIM_BRIGHT_HEX),
		VoxelModel.METAL_DARK: _linear(METAL_DARK_HEX),
		VoxelModel.SCALE_A: _linear(SCALE_A_HEX),
		VoxelModel.SCALE_B: _linear(SCALE_B_HEX),
		# EMISSIVE TRAVELS IN THE ALPHA, exactly as flora's does - but the
		# mesher sets the flag from the slot, not from this colour. That is the
		# whole of the character/foliage unification item 12 asks for: a shared
		# channel, not a shared struct.
		VoxelModel.GLOW: _linear(GLOW_HEX),
	}
	# Alpha is not set here at all: `VoxelModel.build_mesh` derives it from the
	# SLOT, so a palette cannot accidentally light something up. See the note
	# there - it is the difference between failing open and failing closed.
	return out


## The race's own tier colours, for anything that needs one directly rather
## than through a slot - the gallery's palette sheet, and the armour trim later.
static func tier_hex(race: int, tier: String) -> String:
	var r := valid_race(race)
	match tier:
		"liner": return LINER_HEX
		"deep": return DEEP_HEX[r]
		"mid": return MID_HEX[r]
		"light": return LIGHT_HEX[r]
		"accent": return ACCENT_HEX[r]
	return LINER_HEX


const TIER_NAMES := ["liner", "deep", "mid", "light", "accent"]


## sRGB hex to the linear value the renderer actually wants. See Block.COLORS:
## a vertex colour is treated as already linear, so feeding it a hex value
## directly draws it far brighter and far less saturated than intended.
static func _linear(hex: String) -> Color:
	return Color.html(hex).srgb_to_linear()


## A multiply in LINEAR space, which is what "80% as bright" means physically.
## Alpha is left alone.
static func _scale(c: Color, f: float) -> Color:
	return Color(c.r * f, c.g * f, c.b * f, c.a)


## Toward white by `f`, in LINEAR space. Scaling cannot lighten - a scale by 1.5
## takes a bright skin past 1.0 and clips it to a different hue - so the light
## direction is a mix and the dark direction is a multiply. Alpha is left alone.
static func _lighten(c: Color, f: float) -> Color:
	return Color(lerpf(c.r, 1.0, f), lerpf(c.g, 1.0, f), lerpf(c.b, 1.0, f), c.a)


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
			"part": "arm_upper"},
		{"name": "arm_l", "parent": "torso", "rest": Vector3(-arm_x, shoulder_y, 0) * V,
			"part": "arm_upper", "mirror": true},
		{"name": "leg_r", "parent": "hips", "rest": Vector3(leg_x, 0, 0) * V,
			"part": "leg_upper"},
		{"name": "leg_l", "parent": "hips", "rest": Vector3(-leg_x, 0, 0) * V,
			"part": "leg_upper", "mirror": true},
	]

	# THE KNEE AND THE ELBOW - character v2 Stage 4.
	#
	# ADDED, NOT SUBSTITUTED, and that is the whole design. `leg_r` keeps its
	# name and gains a child; it does not become `leg_upper`. `Rig.apply_pose()`
	# has one contract and it is written down there: a pose that says nothing
	# about a bone leaves it at rest. So every static pose, the critter, the
	# trot and every self-test that names a bone kept working on the day these
	# four landed, and the poses that wanted knees were refined afterwards
	# because someone chose to rather than to stop the build being red.
	#
	# The cost is that `leg_r` names a thigh, which is slightly dishonest. The
	# PART keys got the honest names instead - `leg_upper`, `leg_lower` - because
	# a part key is an asset contract with one consumer (assets/characters/, and
	# it ships empty) while a bone name is a pose contract with a dozen. Rename
	# the cheap one.
	#
	# THE SEGMENT LENGTH IS READ OFF THE PART, not computed as `legs / 2`. The
	# two are not the same number: the dwarf's legs are 15 voxels and its
	# segments are 8 and 8, because the grid map rounds each half up. Deriving
	# the offset from the part that is actually there is the only version that
	# cannot drift, and it is the same argument as the height self-test
	# measuring a built rig rather than summing the table.
	var set_for_bones := part_set(race, build)
	var thigh := _segment_height(set_for_bones, "leg_upper", float(legs) * 0.5)
	var upper_arm := _segment_height(set_for_bones, "arm_upper", float(arm_len) * 0.5)
	for side in [["r", 1.0], ["l", -1.0]]:
		var suffix: String = side[0]
		var mirrored: bool = suffix == "l"
		out.append({"name": "leg_%s_lower" % suffix, "parent": "leg_%s" % suffix,
			"rest": Vector3(0, -thigh, 0) * V,
			"part": "leg_lower", "mirror": mirrored})
		out.append({"name": "arm_%s_lower" % suffix, "parent": "arm_%s" % suffix,
			"rest": Vector3(0, -upper_arm, 0) * V,
			"part": "arm_lower", "mirror": mirrored})
		# THE THIRD LEG SEGMENT, and only the lizardfolk has one. A digitigrade
		# animal stands on the end of a long foot with the ankle raised into a
		# backward-facing hock, and that hock is the feature that reads as "not
		# a person" from any angle - unlike the tail and the snout, which a
		# front-on mask cannot see at all.
		#
		# Optional by the same rule the knee is: a race whose part set has no
		# `leg_foot` simply does not get the bone, and nothing branches on
		# which races are digitigrade.
		if set_for_bones.has("leg_foot"):
			out.append({"name": "leg_%s_foot" % suffix, "parent": "leg_%s_lower" % suffix,
				"rest": Vector3(0, -_segment_height(set_for_bones, "leg_lower",
					float(legs) / 3.0), 0) * V,
				"part": "leg_foot", "mirror": mirrored})

	# A DIGITIGRADE LEG IS BENT WHEN IT IS STANDING STILL, and that is the
	# whole point of it. A dog at rest has a folded hind leg; only a person
	# stands on straight columns. So the crouch belongs in the REST POSE, baked
	# in exactly as the forward lean already is - not in the walk cycle, where
	# it would vanish the moment the character stopped.
	#
	# It is also what finally moved the silhouette. The mask metric photographs
	# a character in its rest pose, so a race whose legs were straight at rest
	# and folded only while walking measured as a straight-legged race. Front on
	# against the human this pair went 0.913 -> 0.797 on the torso narrowing
	# alone, and the rest of the way on this.
	#
	# The numbers are a Z: thigh forward, shin back under the body, foot
	# forward onto the toes. They are tabled per race rather than computed,
	# because "what this animal's leg does when it is standing" is a fact about
	# the animal.
	var stance: Dictionary = t.get("leg_stance", {})
	if not stance.is_empty():
		for entry in out:
			var bone_name: String = entry["name"]
			for key in stance:
				if bone_name.ends_with(key):
					entry["rest_rot"] = Vector3(deg_to_rad(float(stance[key])), 0.0, 0.0)

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
			"rest": (Vector3(0, 2, float(torso_d) * 0.5) if i == 0
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



## The built height of a limb segment, in model voxels, or a fallback.
##
## Read off the part rather than halved from the table, because the two are not
## the same number after a non-integer change of grid. See bone_table().
static func _segment_height(parts: Dictionary, part_name: String, fallback: float) -> float:
	if parts.has(part_name) and (parts[part_name] as Dictionary).has("size"):
		return float((parts[part_name]["size"] as Vector3i).y)
	return fallback

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
	# THE HANDS HANG OFF THE FOREARM since character v2 Stage 4, not off the
	# shoulder. `arm_r` is now the upper arm, so a hand parented to it would
	# stay put while the elbow bent - which is the single most obviously wrong
	# thing a two-segment arm can do. The offset is the FOREARM's length, read
	# off its part for the same reason the elbow's is.
	var forearm := _segment_height(part_set(race, build), "arm_lower",
		float(arm_len) * 0.5)
	return [
		{"name": "hand_r", "parent": "arm_r_lower", "rest": Vector3(0, -forearm, 0) * V, "socket": true},
		{"name": "hand_l", "parent": "arm_l_lower", "rest": Vector3(0, -forearm, 0) * V, "socket": true},
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


## The part set for a race. `build` is accepted and ignored, as in dims().
static func part_set(race: int, _build := STOCKY) -> Dictionary:
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

	# THE DROP-IN RULE. `assets/characters/<race>/<part>.vox` replaces the
	# ASCII part of that name, with no code change. Checked here rather than in
	# Rig because this is the one function that already knows which race is
	# being built - and because a drop-in must be able to replace a hair part
	# as easily as a head.
	#
	# The ANCHOR comes from the ASCII part it replaces. A `.vox` file carries
	# no anchor of its own, and inventing one from its bounding box would put a
	# replacement head's pivot somewhere the bone table does not expect - so a
	# drop-in inherits the pivot of the thing it stands in for, and a part with
	# no ASCII original gets bottom-centre.
	var race_name := name_of(def.race)
	for part_name in out.keys():
		var original: Dictionary = out[part_name]
		var replacement = VoxLoader.drop_in(race_name, part_name,
			original.get("anchor", Vector3.ZERO),
			original.get("size", Vector3i.ZERO))
		if replacement != null:
			out[part_name] = replacement
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
