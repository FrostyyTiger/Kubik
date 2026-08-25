class_name PartsHair

## Hair, beards and crests. Everything that hangs off a head.
##
## AUTHORED IN THE HEAD'S OWN FRAME. A hair part uses the same lattice as the
## head part it sits on, so its anchor is the head's anchor shifted - which is
## what lets a beard be described as "six voxels below the chin and three in
## front of the face" rather than in a coordinate system nobody can hold in
## their head.
##
## ANCHORS HERE MAY BE NEGATIVE OR PAST THE PART. A crest sits nine voxels
## ABOVE its head bone, so its anchor y is -9; a beard hangs below, so its
## anchor y is positive on a part that lives entirely under the chin. Both are
## legal: the anchor is a lattice point, not an index into the voxels, and the
## alternative is nine slices of empty ASCII to push the shape into place.
##
## HAIR SITS OUTSIDE THE HEAD, never inside it. The mesher culls faces between
## two voxels OF THE SAME PART, so a hair part overlapping the skull would
## leave a hidden shell of triangles inside it - invisible, and paid for on
## every frame. Every part here is placed clear of the skull it attaches to,
## and each block below states the head geometry it was placed against so the
## next person can check that rather than trust it.
##
## THE THREE OPTIONS ARE THREE SILHOUETTES, not three textures. There are no
## textures. A cap, a curtain down the back and a tail out of the back are
## distinguishable at 40 m; three variations on a fringe are not, and would be
## three parts that cost the same to author and read as one.

# =============================================================================
# HUMAN.  Head is 8 x 9 x 9 anchored at (4, 0, 5).
#   skull  x -4..+4   y 0..9    z -4..+4      crown at y = 9
#   the nose sticks out to z = -5, at y = 4 only
# =============================================================================

## A cap, two layers, sitting on the crown.
const HUMAN_HAIR_SHORT := {
	"size": Vector3i(8, 2, 8),
	"anchor": Vector3(4, -9, 4),
	"slices": [
		["HHHHHHHH", "HHHHHHHH", "HHHHHHHH", "HHHHHHHH",
		 "HHHHHHHH", "HHHHHHHH", "HHHHHHHH", "HHHHHHHH"],
		["........", ".HHHHHH.", ".HHHHHH.", ".HHHHHH.",
		 ".HHHHHH.", ".HHHHHH.", ".HHHHHH.", "........"],
	],
}

## The cap plus a curtain down the back, to the shoulders.
const HUMAN_HAIR_LONG := {
	"size": Vector3i(8, 10, 9),
	"anchor": Vector3(4, -1, 4),
	"slices": [
		["........", "........", "........", "........",
		 "........", "........", "........", "........", "HHHHHHHH"],
		["........", "........", "........", "........",
		 "........", "........", "........", "........", "HHHHHHHH"],
		["........", "........", "........", "........",
		 "........", "........", "........", "........", "HHHHHHHH"],
		["........", "........", "........", "........",
		 "........", "........", "........", "........", "HHHHHHHH"],
		["........", "........", "........", "........",
		 "........", "........", "........", "........", "HHHHHHHH"],
		["........", "........", "........", "........",
		 "........", "........", "........", "........", "HHHHHHHH"],
		["........", "........", "........", "........",
		 "........", "........", "........", "........", "HHHHHHHH"],
		["........", "........", "........", "........",
		 "........", "........", "........", "........", "HHHHHHHH"],
		["HHHHHHHH", "HHHHHHHH", "HHHHHHHH", "HHHHHHHH",
		 "HHHHHHHH", "HHHHHHHH", "HHHHHHHH", "HHHHHHHH", "HHHHHHHH"],
		["........", ".HHHHHH.", ".HHHHHH.", ".HHHHHH.",
		 ".HHHHHH.", ".HHHHHH.", ".HHHHHH.", "........", "........"],
	],
}

## The cap plus a tail out of the back at crown height.
const HUMAN_HAIR_TIED := {
	"size": Vector3i(8, 4, 12),
	"anchor": Vector3(4, -7, 4),
	"slices": [
		["........", "........", "........", "........",
		 "........", "........", "........", "........",
		 "...HH...", "...HH...", "...HH...", "........"],
		["........", "........", "........", "........",
		 "........", "........", "........", "........",
		 "...HH...", "...HH...", "...HH...", "...HH..."],
		["HHHHHHHH", "HHHHHHHH", "HHHHHHHH", "HHHHHHHH",
		 "HHHHHHHH", "HHHHHHHH", "HHHHHHHH", "HHHHHHHH",
		 "...HH...", "........", "........", "........"],
		["........", ".HHHHHH.", ".HHHHHH.", ".HHHHHH.",
		 ".HHHHHH.", ".HHHHHH.", ".HHHHHH.", "........",
		 "........", "........", "........", "........"],
	],
}

## Short beard: chin and jaw, stopping below the mouth at y = 2.
const HUMAN_BEARD_SHORT := {
	"size": Vector3i(8, 5, 3),
	"anchor": Vector3(4, 4, 7),
	"slices": [
		["...HH...", "...HH...", "...HH..."],
		["..HHHH..", "..HHHH..", "..HHHH.."],
		[".HHHHHH.", ".HHHHHH.", ".HHHHHH."],
		["HHHHHHHH", "HHHHHHHH", "HHHHHHHH"],
		["HHHHHHHH", "HHHHHHHH", "HHHHHHHH"],
	],
}

## Full beard: to the chest, and up the cheeks.
const HUMAN_BEARD_FULL := {
	"size": Vector3i(8, 9, 3),
	"anchor": Vector3(4, 8, 7),
	"slices": [
		["...HH...", "...HH...", "...HH..."],
		["...HH...", "...HH...", "...HH..."],
		["..HHHH..", "..HHHH..", "..HHHH.."],
		["..HHHH..", "..HHHH..", "..HHHH.."],
		[".HHHHHH.", ".HHHHHH.", ".HHHHHH."],
		["HHHHHHHH", "HHHHHHHH", "HHHHHHHH"],
		["HHHHHHHH", "HHHHHHHH", "HHHHHHHH"],
		["HH....HH", "HH....HH", "HH....HH"],
		["HH....HH", "HH....HH", "HH....HH"],
	],
}


# =============================================================================
# ELF.  Head is 14 x 11 x 9 anchored at (7, 0, 5).
#   skull  x -4..+4   y 2..11   z -4..+4      crown at y = 11
#   ears   x -7..-4 and +4..+7, at z -2..+1 only
#
# The same three shapes as the human's, eleven voxels further up. The hair
# deliberately does NOT cover the ears: they are what separates an elf at
# distance, and a cap that swallowed them would throw away the one feature the
# silhouette metric can see.
# =============================================================================

const ELF_HAIR_SHORT := {
	"size": Vector3i(8, 2, 8),
	"anchor": Vector3(4, -11, 4),
	"slices": [
		["HHHHHHHH", "HHHHHHHH", "HHHHHHHH", "HHHHHHHH",
		 "HHHHHHHH", "HHHHHHHH", "HHHHHHHH", "HHHHHHHH"],
		["........", ".HHHHHH.", ".HHHHHH.", ".HHHHHH.",
		 ".HHHHHH.", ".HHHHHH.", ".HHHHHH.", "........"],
	],
}

const ELF_HAIR_LONG := {
	"size": Vector3i(8, 12, 9),
	"anchor": Vector3(4, -1, 4),
	"slices": [
		["........", "........", "........", "........",
		 "........", "........", "........", "........", "HHHHHHHH"],
		["........", "........", "........", "........",
		 "........", "........", "........", "........", "HHHHHHHH"],
		["........", "........", "........", "........",
		 "........", "........", "........", "........", "HHHHHHHH"],
		["........", "........", "........", "........",
		 "........", "........", "........", "........", "HHHHHHHH"],
		["........", "........", "........", "........",
		 "........", "........", "........", "........", "HHHHHHHH"],
		["........", "........", "........", "........",
		 "........", "........", "........", "........", "HHHHHHHH"],
		["........", "........", "........", "........",
		 "........", "........", "........", "........", "HHHHHHHH"],
		["........", "........", "........", "........",
		 "........", "........", "........", "........", "HHHHHHHH"],
		["........", "........", "........", "........",
		 "........", "........", "........", "........", "HHHHHHHH"],
		["........", "........", "........", "........",
		 "........", "........", "........", "........", "HHHHHHHH"],
		["HHHHHHHH", "HHHHHHHH", "HHHHHHHH", "HHHHHHHH",
		 "HHHHHHHH", "HHHHHHHH", "HHHHHHHH", "HHHHHHHH", "HHHHHHHH"],
		["........", ".HHHHHH.", ".HHHHHH.", ".HHHHHH.",
		 ".HHHHHH.", ".HHHHHH.", ".HHHHHH.", "........", "........"],
	],
}

## One thick braid straight down the back, notched so it reads as plaited
## rather than as a plank.
const ELF_HAIR_BRAIDED := {
	"size": Vector3i(8, 12, 9),
	"anchor": Vector3(4, -1, 4),
	"slices": [
		["........", "........", "........", "........",
		 "........", "........", "........", "........", "..HHHH.."],
		["........", "........", "........", "........",
		 "........", "........", "........", "........", "...HH..."],
		["........", "........", "........", "........",
		 "........", "........", "........", "........", "..HHHH.."],
		["........", "........", "........", "........",
		 "........", "........", "........", "........", "...HH..."],
		["........", "........", "........", "........",
		 "........", "........", "........", "........", "..HHHH.."],
		["........", "........", "........", "........",
		 "........", "........", "........", "........", "...HH..."],
		["........", "........", "........", "........",
		 "........", "........", "........", "........", "..HHHH.."],
		["........", "........", "........", "........",
		 "........", "........", "........", "........", "...HH..."],
		["........", "........", "........", "........",
		 "........", "........", "........", "........", "..HHHH.."],
		["........", "........", "........", "........",
		 "........", "........", "........", "........", "..HHHH.."],
		["HHHHHHHH", "HHHHHHHH", "HHHHHHHH", "HHHHHHHH",
		 "HHHHHHHH", "HHHHHHHH", "HHHHHHHH", "HHHHHHHH", "HHHHHHHH"],
		["........", ".HHHHHH.", ".HHHHHH.", ".HHHHHH.",
		 ".HHHHHH.", ".HHHHHH.", ".HHHHHH.", "........", "........"],
	],
}


# =============================================================================
# DWARF.  Head is 10 x 10 x 9 anchored at (5, 0, 5).
#   skull  x -5..+5   y 0..10   z -4..+4      crown at y = 10
#   the nose sticks out to z = -5, at y = 5 only
#
# THE BEARD IS HALF THE SILHOUETTE, and there are three of them and no "none".
# A beardless dwarf at 40 m is a short human, which is the one thing the race
# table says it must never be.
# =============================================================================

const DWARF_HAIR_SHORT := {
	"size": Vector3i(10, 2, 8),
	"anchor": Vector3(5, -10, 4),
	"slices": [
		["HHHHHHHHHH", "HHHHHHHHHH", "HHHHHHHHHH", "HHHHHHHHHH",
		 "HHHHHHHHHH", "HHHHHHHHHH", "HHHHHHHHHH", "HHHHHHHHHH"],
		["..........", ".HHHHHHHH.", ".HHHHHHHH.", ".HHHHHHHH.",
		 ".HHHHHHHH.", ".HHHHHHHH.", ".HHHHHHHH.", ".........."],
	],
}

const DWARF_HAIR_LONG := {
	"size": Vector3i(10, 11, 9),
	"anchor": Vector3(5, -1, 4),
	"slices": [
		["..........", "..........", "..........", "..........",
		 "..........", "..........", "..........", "..........", "HHHHHHHHHH"],
		["..........", "..........", "..........", "..........",
		 "..........", "..........", "..........", "..........", "HHHHHHHHHH"],
		["..........", "..........", "..........", "..........",
		 "..........", "..........", "..........", "..........", "HHHHHHHHHH"],
		["..........", "..........", "..........", "..........",
		 "..........", "..........", "..........", "..........", "HHHHHHHHHH"],
		["..........", "..........", "..........", "..........",
		 "..........", "..........", "..........", "..........", "HHHHHHHHHH"],
		["..........", "..........", "..........", "..........",
		 "..........", "..........", "..........", "..........", "HHHHHHHHHH"],
		["..........", "..........", "..........", "..........",
		 "..........", "..........", "..........", "..........", "HHHHHHHHHH"],
		["..........", "..........", "..........", "..........",
		 "..........", "..........", "..........", "..........", "HHHHHHHHHH"],
		["..........", "..........", "..........", "..........",
		 "..........", "..........", "..........", "..........", "HHHHHHHHHH"],
		["HHHHHHHHHH", "HHHHHHHHHH", "HHHHHHHHHH", "HHHHHHHHHH",
		 "HHHHHHHHHH", "HHHHHHHHHH", "HHHHHHHHHH", "HHHHHHHHHH", "HHHHHHHHHH"],
		["..........", ".HHHHHHHH.", ".HHHHHHHH.", ".HHHHHHHH.",
		 ".HHHHHHHH.", ".HHHHHHHH.", ".HHHHHHHH.", "..........", ".........."],
	],
}

## Two braids, one over each shoulder.
const DWARF_HAIR_BRAIDED := {
	"size": Vector3i(10, 11, 9),
	"anchor": Vector3(5, -1, 4),
	"slices": [
		["..........", "..........", "..........", "..........",
		 "..........", "..........", "..........", "..........", ".HH....HH."],
		["..........", "..........", "..........", "..........",
		 "..........", "..........", "..........", "..........", "HH......HH"],
		["..........", "..........", "..........", "..........",
		 "..........", "..........", "..........", "..........", ".HH....HH."],
		["..........", "..........", "..........", "..........",
		 "..........", "..........", "..........", "..........", "HH......HH"],
		["..........", "..........", "..........", "..........",
		 "..........", "..........", "..........", "..........", ".HH....HH."],
		["..........", "..........", "..........", "..........",
		 "..........", "..........", "..........", "..........", "HH......HH"],
		["..........", "..........", "..........", "..........",
		 "..........", "..........", "..........", "..........", ".HH....HH."],
		["..........", "..........", "..........", "..........",
		 "..........", "..........", "..........", "..........", "HHH....HHH"],
		["..........", "..........", "..........", "..........",
		 "..........", "..........", "..........", "..........", "HHHHHHHHHH"],
		["HHHHHHHHHH", "HHHHHHHHHH", "HHHHHHHHHH", "HHHHHHHHHH",
		 "HHHHHHHHHH", "HHHHHHHHHH", "HHHHHHHHHH", "HHHHHHHHHH", "HHHHHHHHHH"],
		["..........", ".HHHHHHHH.", ".HHHHHHHH.", ".HHHHHHHH.",
		 ".HHHHHHHH.", ".HHHHHHHH.", ".HHHHHHHH.", "..........", ".........."],
	],
}

## Short: chin to the top of the chest, three voxels in front of the face.
const DWARF_BEARD_SHORT := {
	"size": Vector3i(10, 8, 3),
	"anchor": Vector3(5, 6, 7),
	"slices": [
		["....HH....", "....HH....", "....HH...."],
		["...HHHH...", "...HHHH...", "...HHHH..."],
		["..HHHHHH..", "..HHHHHH..", "..HHHHHH.."],
		[".HHHHHHHH.", ".HHHHHHHH.", ".HHHHHHHH."],
		[".HHHHHHHH.", ".HHHHHHHH.", ".HHHHHHHH."],
		["HHHHHHHHHH", "HHHHHHHHHH", "HHHHHHHHHH"],
		["HHHHHHHHHH", "HHHHHHHHHH", "HHHHHHHHHH"],
		["HHHHHHHHHH", "HHHHHHHHHH", "HHHHHHHHHH"],
	],
}

## Full: past the belt, four voxels thick, and up the cheeks.
const DWARF_BEARD_FULL := {
	"size": Vector3i(10, 13, 4),
	"anchor": Vector3(5, 11, 8),
	"slices": [
		["...HHHH...", "...HHHH...", "...HHHH...", "...HHHH..."],
		["...HHHH...", "...HHHH...", "...HHHH...", "...HHHH..."],
		["..HHHHHH..", "..HHHHHH..", "..HHHHHH..", "..HHHHHH.."],
		["..HHHHHH..", "..HHHHHH..", "..HHHHHH..", "..HHHHHH.."],
		[".HHHHHHHH.", ".HHHHHHHH.", ".HHHHHHHH.", ".HHHHHHHH."],
		[".HHHHHHHH.", ".HHHHHHHH.", ".HHHHHHHH.", ".HHHHHHHH."],
		["HHHHHHHHHH", "HHHHHHHHHH", "HHHHHHHHHH", "HHHHHHHHHH"],
		["HHHHHHHHHH", "HHHHHHHHHH", "HHHHHHHHHH", "HHHHHHHHHH"],
		["HHHHHHHHHH", "HHHHHHHHHH", "HHHHHHHHHH", "HHHHHHHHHH"],
		["HHHHHHHHHH", "HHHHHHHHHH", "HHHHHHHHHH", "HHHHHHHHHH"],
		["HHHHHHHHHH", "HHHHHHHHHH", "HHHHHHHHHH", "HHHHHHHHHH"],
		["HH......HH", "HH......HH", "HH......HH", "HH......HH"],
		["HH......HH", "HH......HH", "HH......HH", "HH......HH"],
	],
}

## Forked: full length, split into two prongs below the chin.
const DWARF_BEARD_FORKED := {
	"size": Vector3i(10, 12, 3),
	"anchor": Vector3(5, 10, 7),
	"slices": [
		["..HH..HH..", "..HH..HH..", "..HH..HH.."],
		["..HH..HH..", "..HH..HH..", "..HH..HH.."],
		["..HH..HH..", "..HH..HH..", "..HH..HH.."],
		["..HH..HH..", "..HH..HH..", "..HH..HH.."],
		["..HHHHHH..", "..HHHHHH..", "..HHHHHH.."],
		[".HHHHHHHH.", ".HHHHHHHH.", ".HHHHHHHH."],
		[".HHHHHHHH.", ".HHHHHHHH.", ".HHHHHHHH."],
		["HHHHHHHHHH", "HHHHHHHHHH", "HHHHHHHHHH"],
		["HHHHHHHHHH", "HHHHHHHHHH", "HHHHHHHHHH"],
		["HHHHHHHHHH", "HHHHHHHHHH", "HHHHHHHHHH"],
		["HH......HH", "HH......HH", "HH......HH"],
		["HH......HH", "HH......HH", "HH......HH"],
	],
}


# =============================================================================
# LIZARDFOLK.  Head is 8 x 9 x 12 anchored at (4, 0, 8).
#   skull  x -4..+4   y 0..9    z -4..+4      crown at y = 9
#   snout  x -2..+2             z -8..-4
#
# No hair. The `hair` slot holds a crest instead, which is why the slot is
# called `hair` in the def and `crest` in the option list - one byte on the
# wire, two names for the humans reading it.
# =============================================================================

## A fin three wide, raking backward. THE ONLY DIFFERENTIATING FEATURE A
## FRONT-ON MASK CAN SEE: the lizardfolk's body is the human's by design, and
## its tail and snout are profile features. See the status doc.
const LIZARD_CREST_LOW := {
	"size": Vector3i(3, 7, 7),
	"anchor": Vector3(1.5, -9, 4),
	"slices": [
		["HHH", "HHH", "HHH", "HHH", "HHH", "HHH", "HHH"],
		["...", "HHH", "HHH", "HHH", "HHH", "HHH", "HHH"],
		["...", "...", "HHH", "HHH", "HHH", "HHH", "HHH"],
		["...", "...", "...", "HHH", "HHH", "HHH", "HHH"],
		["...", "...", "...", "...", "HHH", "HHH", "HHH"],
		["...", "...", "...", "...", "...", "HHH", "HHH"],
		["...", "...", "...", "...", "...", "...", "HHH"],
	],
}

## The same fin, half again as tall and reaching further back.
const LIZARD_CREST_TALL := {
	"size": Vector3i(3, 11, 9),
	"anchor": Vector3(1.5, -9, 4),
	"slices": [
		["HHH", "HHH", "HHH", "HHH", "HHH", "HHH", "HHH", "...", "..."],
		["...", "HHH", "HHH", "HHH", "HHH", "HHH", "HHH", "HHH", "..."],
		["...", "...", "HHH", "HHH", "HHH", "HHH", "HHH", "HHH", "HHH"],
		["...", "...", "...", "HHH", "HHH", "HHH", "HHH", "HHH", "HHH"],
		["...", "...", "...", "...", "HHH", "HHH", "HHH", "HHH", "HHH"],
		["...", "...", "...", "...", "...", "HHH", "HHH", "HHH", "HHH"],
		["...", "...", "...", "...", "...", "...", "HHH", "HHH", "HHH"],
		["...", "...", "...", "...", "...", "...", "...", "HHH", "HHH"],
		["...", "...", "...", "...", "...", "...", "...", "HHH", "HHH"],
		["...", "...", "...", "...", "...", "...", "...", "...", "HHH"],
		["...", "...", "...", "...", "...", "...", "...", "...", "HHH"],
	],
}

## A fan behind the head rather than a fin on top of it: twelve voxels across
## and two thick, which is a completely different outline from either crest.
const LIZARD_FRILL := {
	"size": Vector3i(12, 9, 2),
	"anchor": Vector3(6, -5, -4),
	"slices": [
		["....HHHH....", "....HHHH...."],
		["...HHHHHH...", "...HHHHHH..."],
		["..HHHHHHHH..", "..HHHHHHHH.."],
		[".HHHHHHHHHH.", ".HHHHHHHHHH."],
		["HHHHHHHHHHHH", "HHHHHHHHHHHH"],
		["HHHHHHHHHHHH", ".HHHHHHHHHH."],
		[".HHHHHHHHHH.", "..HHHHHHHH.."],
		["..HHHHHHHH..", "...HHHHHH..."],
		["...HHHHHH...", "....HHHH...."],
	],
}


# --- Lookup -------------------------------------------------------------------
#
# Indexed by race and then by the option index in the def. A null entry means
# "this option adds no geometry", which is what the human's "none" beard is.
# Rig treats a hair or beard bone with no part as an optional bone and says
# nothing about it.
#
# THE ORDER HERE IS THE ORDER IN Races.HAIR_OPTIONS AND Races.BEARD_OPTIONS.
# The index is one byte on the wire and one number in a save file, so the two
# lists have to agree; the self-test walks both and would catch a slip.

const HAIR := [
	[HUMAN_HAIR_SHORT, HUMAN_HAIR_LONG, HUMAN_HAIR_TIED],
	[ELF_HAIR_SHORT, ELF_HAIR_LONG, ELF_HAIR_BRAIDED],
	[DWARF_HAIR_SHORT, DWARF_HAIR_LONG, DWARF_HAIR_BRAIDED],
	[LIZARD_CREST_LOW, LIZARD_CREST_TALL, LIZARD_FRILL],
]

const BEARD := [
	[null, HUMAN_BEARD_SHORT, HUMAN_BEARD_FULL],
	[],
	[DWARF_BEARD_SHORT, DWARF_BEARD_FULL, DWARF_BEARD_FORKED],
	[],
]


## The hair or crest part for this race and option, or null.
static func hair_part(race: int, index: int):
	return _lookup(HAIR, race, index)


static func beard_part(race: int, index: int):
	return _lookup(BEARD, race, index)


static func _lookup(table: Array, race: int, index: int):
	var options: Array = table[clampi(race, 0, table.size() - 1)]
	if options.is_empty() or index < 0 or index >= options.size():
		return null
	return options[index]
