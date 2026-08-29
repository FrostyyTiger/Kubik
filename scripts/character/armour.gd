class_name Armour

## What can be worn, as data. Slots, tiers, pieces, and where each hangs.
##
## THIS IS NOT AN ITEM SYSTEM, and it says so here for the same reason
## `parts_gear.gd` says it: there is no item table, no inventory, no drops, no
## rule about what GRANTS a tier and no stats anywhere. Items v1 (Wave 3, G)
## owns every one of those. What lives here is the minimum for a character to
## wear something, for a friend across the network to see it, and for the
## silhouette harness to count what it does to the outline.
##
##
## WHY A LADDER OF OUTLINE EVENTS, AND NOT OF SURFACE DECORATION
##
## With flat vertex colour and no textures, surface detail is free to author
## and invisible at range: the outline is the only currency an armour piece
## has. So a tier is defined by how many places the silhouette's width profile
## gains a local maximum the naked body does not have - a pauldron past the arm
## line, a gorget raising the shoulder, faulds flaring below the belt, a crest
## above the head, a cloak behind the legs.
##
## That is a COUNTABLE claim, which is the whole point: `--sheet outline`
## measures it, and the ladder below is a gate rather than an adjective.
##
##
## THE FITTING RULE: PROPORTIONS RELATIVE, THICKNESSES ABSOLUTE
##
## One idea has to be worn by a 39-voxel-wide dwarf, an 18-voxel-wide elf and a
## forward-leaning lizardfolk with a tail. Per-race remodelling is four times
## the authoring; a single scaled mesh puts a dwarf breastplate on an elf and it
## looks like a barrel.
##
## So a piece is authored once in a NORMALISED SLOT FRAME - 0..1 across the
## attachment's width, height and depth - and stamped into the race's actual
## dimensions by the generator. Its SHAPE is the same fraction of every
## shoulder; its PLATE is the same THICKNESS on every race - 2 author voxels,
## which is 3 on the 96 grid - because a plate is a plate whoever wears it. Get that backwards and dwarf armour looks like foam rubber
## while elf armour looks like it was cut from sheet tin.

## The five tiers, and what each one is allowed to do to the outline. The count
## is what `--sheet outline` gates on.
##
## Tier 1 has ZERO outline events on purpose: if starting gear changes the
## silhouette then the naked character is not the design, the starting gear is,
## and the whole acceptance test is four races identifiable in nothing.
##
## Tier 3 also has almost none, and that is the interesting one. Mail's whole
## character is that it DRAPES - it does nothing to the outline and everything
## to the surface - so tier 3 is where a player learns that armour is not
## monotonically bigger.
const TIERS := [
	{"name": "none", "events": 0, "material": "-"},
	{"name": "cloth", "events": 0, "material": "cloth"},
	{"name": "hide", "events": 1, "material": "leather over cloth"},
	{"name": "mail", "events": 1, "material": "scale checker over cloth"},
	{"name": "plate", "events": 3, "material": "steel with bright rim"},
	{"name": "named", "events": 5, "material": "steel, a second metal, and a rune"},
]


## Where each slot hangs, and why there rather than somewhere else.
##
## AN OVERLAY IS NOT A SOCKET, and the difference is worth writing down because
## "why is the pauldron a bone overlay and the cloak a socket attachment" is a
## question someone will ask in six months.
##
##   - An OVERLAY is a second mesh on an existing bone. It moves with that bone
##     exactly and needs no new transform, which is what a layer over a body
##     part wants: a pauldron IS the shoulder, seen from outside.
##   - A SOCKET is a point to hang a carried object from. A cloak hangs off the
##     back; it is not a layer over the torso.
const SLOTS := [
	{"slot": CharacterDef.SLOT_TORSO, "bone": "torso", "overlay": true,
		"share": 0.38, "why": "the largest surface; every layer shows on it"},
	{"slot": CharacterDef.SLOT_SHOULDERS, "bones": ["arm_r", "arm_l"], "overlay": true,
		"share": 0.12, "why": "the only slot that grows the outline outward at the widest point, and a pauldron swings with the arm"},
	{"slot": CharacterDef.SLOT_BACK, "socket": "back",
		"share": 0.15, "why": "reads at 40 m, carries motion, and is the cheapest expensive-looking thing there is"},
	{"slot": CharacterDef.SLOT_HEAD, "bone": "head", "overlay": true,
		"share": 0.20, "why": "second-most-looked-at, and the slot that fights race identity hardest"},
	{"slot": CharacterDef.SLOT_LEGS, "bones": ["leg_r", "leg_l"], "overlay": true,
		"share": 0.15, "why": "declared, no geometry - a greave at 15 m is nine pixels behind a tuft of grass"},
	{"slot": CharacterDef.SLOT_HANDS, "sockets": ["hand_r", "hand_l"],
		"share": 0.0, "why": "declared; the sockets exist from character v1 Stage 10 and Items v1 fills them"},
]


## How many pieces are authored for a slot, INCLUDING the empty piece at index
## 0. `CharacterDef.validate()` clamps against this, so a peer claiming piece
## 200 wears piece 0 rather than crashing anything.
##
## Two slots ship with nothing in them and that is not an oversight - it is why
## the wire format reserved six slots rather than four. Filling `legs` and
## `hands` later costs geometry and no version bump.
static func piece_count(slot: int) -> int:
	return VARIANTS


## WHAT EACH SLOT WEARS AT EACH TIER, indexed by tier. "" is nothing.
##
## THE TIER SELECTS THE PIECE, which is what makes the ladder a ladder rather
## than a set of independent choices. `armour_item` stays on the wire beside it
## as the VARIANT within a tier - two different tier-4 breastplates - and Items
## v1 owns what fills it; today every slot has one variant and the byte is
## always zero.
##
## Read down a column and you get the ladder the design doc argues for:
##
##   tier 1 cloth   0 events   what you start in. The four races have to be
##                             identifiable in NOTHING, so starting gear that
##                             changed the silhouette would mean the naked
##                             character is not the design.
##   tier 2 hide    1 event    a shoulder cap. You killed something.
##   tier 3 mail    1 event    a raised collar, and a 1-voxel checker over
##                             cloth. Mail DRAPES - it does nothing to the
##                             outline and everything to the surface - which is
##                             where a player learns armour is not
##                             monotonically bigger.
##   tier 4 plate   3 events   pauldrons past the arm line, the gorget, and
##                             faulds below the belt.
##   tier 5 named   5 events   the three above, plus a cloak and one vertical
##                             element above the head.
const PIECES := [
	["", "jerkin", "hide", "mail", "plate", "plate"],       # torso
	["", "", "cap", "", "pauldron", "pauldron"],            # shoulders
	["", "", "", "", "", "cloak"],                          # back
	["", "", "", "gorget", "helm", "helm_crowned"],         # head
	["", "", "", "", "", ""],                               # legs - declared
	["", "", "", "", "", ""],                               # hands - declared
]

## ONE SHOULDER, NOT BOTH. What the FIRST bone of a slot wears instead, per
## tier, when the piece is deliberately asymmetric.
##
## Symmetric armour reads as issued; asymmetric reads as assembled by someone
## who lived through things - and it is free, which is why the design doc ranks
## it second only to a cloak in value per voxel authored. Tier 5's rune band
## goes on ONE pauldron: one lit shoulder is a story, two are a costume.
##
## It also halves the glow budget, which is how it was noticed - the cap test
## reported 30 voxels against a cap of 12 with the band on both arms.
const ASYMMETRIC := {
	5: {CharacterDef.SLOT_SHOULDERS: "pauldron_runed"},
}


## The piece for one bone of a slot. `index` is its position in the slot's bone
## list, and 0 is the authored side.
static func part_name_for(slot: int, tier: int, race: int, index: int) -> String:
	if index == 0 and ASYMMETRIC.has(tier) and ASYMMETRIC[tier].has(slot):
		return "%s_%s" % [ASYMMETRIC[tier][slot], Races.name_of(race)]
	return part_name(slot, tier, race)


## Variants within a tier. One each for now; the byte exists so Items v1 can
## add a second tier-4 breastplate without another wire version.
const VARIANTS := 1


## The part name for a piece on a race, or "" for nothing worn.
##
## EVERY PIECE IS PER-RACE IN THE PART FILE and authored once in the generator.
## That is the fitting rule at the seam: `armour.py` stamps one normalised
## description into four sets of real dimensions, so there are four parts and
## one design, rather than four designs or one part that fits nobody.
static func part_name(slot: int, tier: int, race: int) -> String:
	if slot < 0 or slot >= PIECES.size():
		return ""
	var names: Array = PIECES[slot]
	if tier <= 0 or tier >= names.size():
		return ""
	var piece: String = names[tier]
	if piece.is_empty():
		return ""
	return "%s_%s" % [piece, Races.name_of(race)]


## Where a slot hangs: `{"bones": [...]}` for an overlay, `{"sockets": [...]}`
## for a carried thing. One shape so the caller does not branch per slot.
static func attach_points(slot: int) -> Dictionary:
	for entry in SLOTS:
		if int(entry["slot"]) != slot:
			continue
		if entry.has("bone"):
			return {"bones": [entry["bone"]]}
		if entry.has("bones"):
			return {"bones": entry["bones"]}
		if entry.has("socket"):
			return {"sockets": [entry["socket"]]}
		if entry.has("sockets"):
			return {"sockets": entry["sockets"]}
	return {}


## The tier a slot is worn at, clamped. Convenience for the gallery and the
## debug key; the def is still the source of truth.
static func tier_of(def: CharacterDef, slot: int) -> int:
	if def == null or slot < 0 or slot >= CharacterDef.ARMOUR_SLOTS:
		return 0
	return clampi(def.armour_tier[slot], 0, CharacterDef.TIER_MAX)


## The highest tier worn anywhere on a character. What a "you did something"
## read should key off, and what the dwarf's beard rings may or may not track -
## see the TODO in PartsHair.
static func highest_tier(def: CharacterDef) -> int:
	var top := 0
	for i in CharacterDef.ARMOUR_SLOTS:
		top = maxi(top, tier_of(def, i))
	return top


## How many outline events this character's gear is claiming, from the table.
## The harness measures what it ACTUALLY produces; this is what it should be,
## and the two disagreeing is the finding.
static func expected_events(def: CharacterDef) -> int:
	var tier := highest_tier(def)
	return int(TIERS[clampi(tier, 0, TIERS.size() - 1)]["events"])


# --- Two exercises left open, on purpose --------------------------------------


## TODO(marcel): make the dwarf's beard rings track the armour.
##
## The beard supports rings and this returns 1 at every tier, so every dwarf
## wears exactly one ring forever. It is a working fallback: a dwarf with one
## ring looks like a dwarf.
##
##   Hint: it is not linear - the design doc's ladder is one ring at tier 1 and
##   three by tier 4, which is a curve rather than a slope. The interesting
##   question is the other one: should rings track the TORSO's tier, or
##   `highest_tier()`? One says "this is what I paid for my armour" and the
##   other says "this is what I have become", and they are different characters.
##   `Armour.tier_of(def, CharacterDef.SLOT_TORSO)` and `highest_tier(def)` are
##   both one call away.
static func beard_rings_for(def: CharacterDef) -> int:
	return 1


## TODO(marcel): per-race armour trim.
##
## Returns steel for everyone, which is correct and dull: one authored set that
## reads the same on all four races.
##
##   Hint: the same set reads as dwarven in bronze, elven in pewter and human in
##   brass for the price of one hex per race, and `Races.tier_hex(race,
##   "accent")` already has a per-race colour sitting there. The interesting
##   question is whether trim follows the WEARER or the ITEM - a dwarven axe
##   carried by an elf is a different story from an elf's axe, and armour is
##   the same question with more surface area. Answering "the item" needs a
##   field on the piece; answering "the wearer" needs nothing but this function.
static func trim_hex_for(race: int, _slot: int) -> String:
	return Races.TRIM_BRIGHT_HEX
