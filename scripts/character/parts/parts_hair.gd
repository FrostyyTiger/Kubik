class_name PartsHair

## Hair, beards and crests. Everything that hangs off a head.
##
## AUTHORED IN THE HEAD'S OWN FRAME. A hair part uses the same lattice as the
## head part it sits on, so its anchor is the head's anchor shifted - which is
## what lets a beard be described as "six voxels below the chin and three in
## front of the face" rather than as a separate coordinate system nobody can
## hold in their head.
##
## ANCHORS HERE MAY BE NEGATIVE OR PAST THE PART. The lizardfolk's crest sits
## nine voxels ABOVE its head bone, so its anchor y is -9; the dwarf's beard
## hangs six voxels BELOW, so its anchor y is 6 on an eight-tall part. Both are
## legal: the anchor is a lattice point, not an index into the voxels, and the
## alternative is nine slices of empty ASCII to push the shape up into place.
##
## HAIR SITS OUTSIDE THE HEAD, never inside it. The mesher culls faces between
## two voxels OF THE SAME PART, so a hair part overlapping the skull would
## leave a hidden shell of triangles inside the head - invisible, and paid for
## on every frame. Every part here is placed clear of the skull it attaches to.
##
## Stage 8 authors the DEFAULTS: the dwarf's beard and the lizardfolk's crest,
## the two the race table makes mandatory. Stage 9 fills in the rest.

# --- The dwarf's beard --------------------------------------------------------
#
# The dwarf's head is 10 x 10 x 9 with its anchor at (5, 0, 5), so its skull
# front face is four voxels in front of the bone. This beard occupies z -7 to
# -4 - directly in front of that face and clear of it - and y -6 to +2, hanging
# from the chin to the middle of the chest. It stops below the mouth at head
# y = 3, which is what makes it the SHORT beard rather than the full one.
#
# A DWARF ALWAYS HAS ONE. Its beard picker has three entries and none of them
# is "none": half the dwarf's silhouette is this shape, and a beardless dwarf
# at 40 m is a short human.

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


# --- The lizardfolk's crest ---------------------------------------------------
#
# A fin three voxels wide along the midline of the skull, tallest in the
# middle. The lizardfolk head is 8 x 9 x 12 anchored at (4, 0, 8), so its crown
# is at y = 9 and its skull runs z -4 to +4; this sits from y 9 to 14 and z -4
# to +3, on top and clear.
#
# THREE WIDE AND SEVEN TALL, not the two-by-four it started as, and it now
# rakes BACKWARD rather than peaking in the middle - which is both more like a
# crest and more outline in the one direction the front view can see.
#
# The reason it kept growing is structural and is recorded in the status doc:
# the lizardfolk's body IS the human's body by design - same 8 x 5 torso, same
# 9-voxel legs - so that the silhouette test can tell which feature is doing
# the work. Two of its three differentiating features, the tail and the snout,
# are PROFILE features a front-on mask cannot see at all. From the front the
# crest is the only lever there is.
#
# The lizardfolk has no hair. Its `hair` slot holds this instead, which is why
# the slot is called `hair` in the def and `crest` in the option list - one
# byte on the wire, two names for the humans reading it.

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


# --- Lookup -------------------------------------------------------------------
#
# Indexed by race and then by the option index in the def. A null entry means
# "this option adds no geometry", which is what the human's "none" beard is and
# what every option Stage 9 has not authored yet is. Rig treats a hair or beard
# bone with no part as an optional bone and says nothing.

const HAIR := [
	[null, null, null],                 # human:      short, long, tied back
	[null, null, null],                 # elf:        short, long, braided
	[null, null, null],                 # dwarf:      short, long, braided
	[LIZARD_CREST_LOW, null, null],     # lizardfolk: crest low, crest tall, frill
]

const BEARD := [
	[null, null, null],                 # human: none, short, full
	[],                                 # elf:   none at all
	[DWARF_BEARD_SHORT, null, null],    # dwarf: short, full, forked
	[],                                 # lizardfolk: none at all
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
