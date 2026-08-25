class_name PartsElf

## The elf: 36 voxels tall, narrow, and pointed at the ears.
##
## THE SILHOUETTE IS "TALL AND NARROW, EARS" and every number here serves that.
## The torso is 6 wide against the human's 8 and the arms are 2 against 3, so
## the body is a column; the head stays a full 8 wide, which makes it read as
## LARGE on a narrow frame rather than as merely small; and the ears put two
## voxels of hard outline outside the skull on each side, which is the one
## feature that survives at 40 m when the width difference has stopped being
## legible.
##
## THE STACK, in model voxels:
##
##     legs   [0, 12)  12
##     pelvis [12, 15)  3
##     torso  [15, 25) 10
##     neck   [25, 27)  2   the bottom two slices of the head part
##     head   [27, 36)  9
##
## The neck is part of the head part, not a bone - see PartsHumanLean for why.

# --- Head ---------------------------------------------------------------------
#
# 14 wide, 2 + 9 tall, 8 deep plus one for the nose. The SKULL is 8 wide and
# occupies columns 3 to 10; the outer three columns on each side are ear, and
# they exist only at z 3 to 5 - an ear is a flat blade on the side of a head,
# not a slab through it.
#
# The ears sweep: three voxels out at eye level, two above that, one at the
# crown, nothing below. That taper is what makes them read as ears rather than
# as handles.
#
# THREE OUT, NOT THE TABLE'S TWO. Silhouette pass 1 put the elf against the
# lean human at 0.789 IoU - two tall narrow columns that the eye cannot
# separate at 40 m. The fix follows the plan's rule exactly: exaggerate the
# DIFFERENTIATING feature and never the shared ones, so the ears grew and the
# body did not. A 14-wide head on a 6-wide torso is a shape nothing else in the
# game has.

const HEAD := {
	"size": Vector3i(14, 11, 9),
	"anchor": Vector3(7, 0, 5),
	"slices": [
		# y = 0, neck
		["..............", "..............", "..............", "..............",
		 "......SS......", "......SS......", "..............", "..............",
		 ".............."],
		# y = 1, neck
		["..............", "..............", "..............", "..............",
		 "......SS......", "......SS......", "..............", "..............",
		 ".............."],
		# y = 2, the chin
		["..............", "...SSSSSSSS...", "...SSSSSSSS...", "...SSSSSSSS...",
		 "...SSSSSSSS...", "...SSSSSSSS...", "...SSSSSSSS...", "...SSSSSSSS...",
		 "...SSSSSSSS..."],
		# y = 3
		["..............", "...SSSSSSSS...", "...SSSSSSSS...", "...SSSSSSSS...",
		 "...SSSSSSSS...", "...SSSSSSSS...", "...SSSSSSSS...", "...SSSSSSSS...",
		 "...SSSSSSSS..."],
		# y = 4, the mouth
		["..............", "...SSMMMMSS...", "...SSSSSSSS...", "...SSSSSSSS...",
		 "...SSSSSSSS...", "...SSSSSSSS...", "...SSSSSSSS...", "...SSSSSSSS...",
		 "...SSSSSSSS..."],
		# y = 5
		["..............", "...SSSSSSSS...", "...SSSSSSSS...", "...SSSSSSSS...",
		 "...SSSSSSSS...", "...SSSSSSSS...", "...SSSSSSSS...", "...SSSSSSSS...",
		 "...SSSSSSSS..."],
		# y = 6, the nose - the only slice with anything at z = 0
		["......SS......", "...SSSSSSSS...", "...SSSSSSSS...", "...SSSSSSSS...",
		 "...SSSSSSSS...", "...SSSSSSSS...", "...SSSSSSSS...", "...SSSSSSSS...",
		 "...SSSSSSSS..."],
		# y = 7, eyes, and the ears at their full three voxels out
		["..............", "...SWESSEWS...", "...SSSSSSSS...", "SSSSSSSSSSSSSS",
		 "SSSSSSSSSSSSSS", "SSSSSSSSSSSSSS", "...SSSSSSSS...", "...SSSSSSSS...",
		 "...SSSSSSSS..."],
		# y = 8, eyes and ears
		["..............", "...SWESSEWS...", "...SSSSSSSS...", "SSSSSSSSSSSSSS",
		 "SSSSSSSSSSSSSS", "SSSSSSSSSSSSSS", "...SSSSSSSS...", "...SSSSSSSS...",
		 "...SSSSSSSS..."],
		# y = 9, the brow, and the ears begin to sweep in
		["..............", "...ssssssss...", "...SSSSSSSS...", ".SSSSSSSSSSSS.",
		 ".SSSSSSSSSSSS.", ".SSSSSSSSSSSS.", "...SSSSSSSS...", "...SSSSSSSS...",
		 "...SSSSSSSS..."],
		# y = 10, the crown, and the tips
		["..............", "...SSSSSSSS...", "...SSSSSSSS...", "..SSSSSSSSSS..",
		 "..SSSSSSSSSS..", "..SSSSSSSSSS..", "...SSSSSSSS...", "...SSSSSSSS...",
		 "...SSSSSSSS..."],
	],
}


# --- Torso --------------------------------------------------------------------
#
# 5 wide, 10 tall, 4 deep. A column, and one voxel narrower than the table's 6.
#
# NARROWED IN PASS 3, and "width" is on the plan's own list of things an elf
# may be exaggerated by. Front on at 40 m the elf against the human sat at
# 0.735 IoU: the ears are a handful of pixels at head height and the mask is
# dominated by the torso-and-legs mass, so the only lever that moves the number
# is the one the silhouette is actually named after. The legs went from 3 wide
# to 2 with it - a 5-wide torso over 3-wide legs would have had the legs
# sticking out past the body.

const TORSO := {
	"size": Vector3i(5, 10, 4),
	"anchor": Vector3(2.5, 0, 2),
	"slices": [
		["BBBBB", "BBBBB", "BBBBB", "BBBBB"],
		["CCCCC", "CCCCC", "CCCCC", "CCCCC"],
		["CCCCC", "CCCCC", "CCCCC", "CCCCC"],
		["CCCCC", "CCCCC", "CCCCC", "CCCCC"],
		["CCCCC", "CCCCC", "CCCCC", "CCCCC"],
		["CCCCC", "CCCCC", "CCCCC", "CCCCC"],
		["CCCCC", "CCCCC", "CCCCC", "CCCCC"],
		["CCCCC", "CCCCC", "CCCCC", "CCCCC"],
		["CCCCC", "CCCCC", "CCCCC", "CCCCC"],
		["CCCCC", "CCCCC", "CCCCC", "CCCCC"],
	],
}


const PELVIS := {
	"size": Vector3i(5, 3, 4),
	"anchor": Vector3(2.5, 0, 2),
	"slices": [
		["ccccc", "ccccc", "ccccc", "ccccc"],
		["ccccc", "ccccc", "ccccc", "ccccc"],
		["ccccc", "ccccc", "ccccc", "ccccc"],
	],
}


# --- Leg ----------------------------------------------------------------------
#
# 2 wide, 12 tall, 2 deep with a 3-deep boot. Long and thin, which is where
# most of the elf's extra four voxels of height went.

const LEG := {
	"size": Vector3i(2, 12, 3),
	"anchor": Vector3(1, 12, 1.5),
	"slices": [
		["LL", "LL", "LL"],
		["LL", "LL", "LL"],
		["..", "cc", "cc"],
		["..", "cc", "cc"],
		["..", "cc", "cc"],
		["..", "cc", "cc"],
		["..", "cc", "cc"],
		["..", "cc", "cc"],
		["..", "cc", "cc"],
		["..", "cc", "cc"],
		["..", "cc", "cc"],
		["..", "cc", "cc"],
	],
}


# --- Arm ----------------------------------------------------------------------
#
# 2 wide, 11 long, 2 deep. The thinnest limb in the game.

const ARM := {
	"size": Vector3i(2, 11, 2),
	"anchor": Vector3(1, 11, 1),
	"slices": [
		["ss", "ss"],
		["ss", "ss"],
		["SS", "SS"],
		["SS", "SS"],
		["SS", "SS"],
		["SS", "SS"],
		["SS", "SS"],
		["CC", "CC"],
		["CC", "CC"],
		["CC", "CC"],
		["CC", "CC"],
	],
}


const PARTS := {
	"head": HEAD,
	"torso": TORSO,
	"pelvis": PELVIS,
	"leg": LEG,
	"arm": ARM,
}
