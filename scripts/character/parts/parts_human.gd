class_name PartsHuman

## The stocky human, voxel by voxel.
##
## Read VoxelModel's class docstring before editing anything here. In short:
## slices run bottom to top, rows inside a slice run front (-Z) to back, and
## the first character of a row is the left of the picture as you look at the
## character's face. Every character is a slot, never a colour.
##
## THE STACK, from the race table, in model voxels:
##
##     legs   [0,  9)   9   boots at the bottom, trousers above
##     pelvis [9, 13)   4   the four voxels the plan's table does not spend
##     torso  [13, 23) 10   tunic, belt on its bottom row
##     head   [23, 32)  9   eyes at 28-29, which is 1.79 m
##
## The arms hang from a shoulder at 22 and are 9 long, so the hands finish at
## the waist. Nothing here is a number `player.gd` may read - hard rule 3.

# --- Head ---------------------------------------------------------------------
#
# 8 wide, 9 tall, 8 DEEP PLUS ONE for the nose, which sticks a single voxel out
# in front of the face. The head block therefore occupies z 1..8 and the anchor
# sits at its centre, z = 5, not at the middle of the nine.
#
# THE FACE IS THE WHOLE POINT OF THE STOCKY SCHEME. Two 2 x 2 eyes, a four-wide
# mouth line and a nose, all readable at 15 m: at the game's 75 degree vertical
# FOV on a 720-line viewport, a 2 x 2 eye is about five pixels across at that
# distance, which is a face and not a smudge. Everything else about this head
# is a plain block, because a plain block is what the game's other geometry is.
#
# Each eye is white on the outer column and iris on the inner one. Two colours
# in a 2 x 2 is all the resolution there is, and putting the iris inboard reads
# as a character looking at you rather than past you.

const HEAD := {
	"size": Vector3i(8, 9, 9),
	"anchor": Vector3(4, 0, 5),
	"slices": [
		# y = 0, the chin
		["........", "SSSSSSSS", "SSSSSSSS", "SSSSSSSS", "SSSSSSSS",
		 "SSSSSSSS", "SSSSSSSS", "SSSSSSSS", "SSSSSSSS"],
		# y = 1
		["........", "SSSSSSSS", "SSSSSSSS", "SSSSSSSS", "SSSSSSSS",
		 "SSSSSSSS", "SSSSSSSS", "SSSSSSSS", "SSSSSSSS"],
		# y = 2, the mouth
		["........", "SSMMMMSS", "SSSSSSSS", "SSSSSSSS", "SSSSSSSS",
		 "SSSSSSSS", "SSSSSSSS", "SSSSSSSS", "SSSSSSSS"],
		# y = 3
		["........", "SSSSSSSS", "SSSSSSSS", "SSSSSSSS", "SSSSSSSS",
		 "SSSSSSSS", "SSSSSSSS", "SSSSSSSS", "SSSSSSSS"],
		# y = 4, the nose - the only slice with anything at z = 0
		["...SS...", "SSSSSSSS", "SSSSSSSS", "SSSSSSSS", "SSSSSSSS",
		 "SSSSSSSS", "SSSSSSSS", "SSSSSSSS", "SSSSSSSS"],
		# y = 5, eyes, lower row
		["........", "SWESSEWS", "SSSSSSSS", "SSSSSSSS", "SSSSSSSS",
		 "SSSSSSSS", "SSSSSSSS", "SSSSSSSS", "SSSSSSSS"],
		# y = 6, eyes, upper row
		["........", "SWESSEWS", "SSSSSSSS", "SSSSSSSS", "SSSSSSSS",
		 "SSSSSSSS", "SSSSSSSS", "SSSSSSSS", "SSSSSSSS"],
		# y = 7, the brow
		["........", "ssssssss", "SSSSSSSS", "SSSSSSSS", "SSSSSSSS",
		 "SSSSSSSS", "SSSSSSSS", "SSSSSSSS", "SSSSSSSS"],
		# y = 8, the crown
		["........", "SSSSSSSS", "SSSSSSSS", "SSSSSSSS", "SSSSSSSS",
		 "SSSSSSSS", "SSSSSSSS", "SSSSSSSS", "SSSSSSSS"],
	],
}


# --- Torso --------------------------------------------------------------------
#
# 8 wide, 10 tall, 5 deep. Square shoulders - that IS the human silhouette, and
# it is the reference every other race is separated from, so it does not get
# narrowed to make a comparison easier.
#
# The outfit is baked in rather than being a separate part, because the torso
# slot belongs to the gear plan and v1 has one outfit per race. Belt on the
# bottom row, which is the waist at 13 voxels.

const TORSO := {
	"size": Vector3i(8, 10, 5),
	"anchor": Vector3(4, 0, 2.5),
	"slices": [
		["BBBBBBBB", "BBBBBBBB", "BBBBBBBB", "BBBBBBBB", "BBBBBBBB"],
		["CCCCCCCC", "CCCCCCCC", "CCCCCCCC", "CCCCCCCC", "CCCCCCCC"],
		["CCCCCCCC", "CCCCCCCC", "CCCCCCCC", "CCCCCCCC", "CCCCCCCC"],
		["CCCCCCCC", "CCCCCCCC", "CCCCCCCC", "CCCCCCCC", "CCCCCCCC"],
		["CCCCCCCC", "CCCCCCCC", "CCCCCCCC", "CCCCCCCC", "CCCCCCCC"],
		["CCCCCCCC", "CCCCCCCC", "CCCCCCCC", "CCCCCCCC", "CCCCCCCC"],
		["CCCCCCCC", "CCCCCCCC", "CCCCCCCC", "CCCCCCCC", "CCCCCCCC"],
		["CCCCCCCC", "CCCCCCCC", "CCCCCCCC", "CCCCCCCC", "CCCCCCCC"],
		["CCCCCCCC", "CCCCCCCC", "CCCCCCCC", "CCCCCCCC", "CCCCCCCC"],
		["CCCCCCCC", "CCCCCCCC", "CCCCCCCC", "CCCCCCCC", "CCCCCCCC"],
	],
}


# --- Pelvis -------------------------------------------------------------------
#
# 8 wide, 4 tall, 5 deep, in trousers. The bone `hips` is the root of the rig
# and every bone must have a part; this is its part, and it is also where the
# plan's four missing voxels of height go. See the note in races.gd.

const PELVIS := {
	"size": Vector3i(8, 4, 5),
	"anchor": Vector3(4, 0, 2.5),
	"slices": [
		["cccccccc", "cccccccc", "cccccccc", "cccccccc", "cccccccc"],
		["cccccccc", "cccccccc", "cccccccc", "cccccccc", "cccccccc"],
		["cccccccc", "cccccccc", "cccccccc", "cccccccc", "cccccccc"],
		["cccccccc", "cccccccc", "cccccccc", "cccccccc", "cccccccc"],
	],
}


# --- Leg ----------------------------------------------------------------------
#
# 3 wide, 9 tall, 3 deep, plus a boot that reaches one voxel further forward -
# 4 deep in total, which is the plan's foot. Authored ONCE, for the right leg;
# the left is this mirrored, which is why the two can never drift apart.
#
# The anchor is the TOP centre, `(1.5, 9, 2.5)`, because a leg swings from the
# hip and not from the ankle. That is the whole reason the anchor is a lattice
# point rather than a voxel index: 9 is the top face of a nine-tall part, and
# there is no voxel there to name.

const LEG := {
	"size": Vector3i(3, 9, 4),
	"anchor": Vector3(1.5, 9, 2.5),
	"slices": [
		# y = 0 and 1, the boot, four deep
		["LLL", "LLL", "LLL", "LLL"],
		["LLL", "LLL", "LLL", "LLL"],
		# y = 2 up, the trouser leg, three deep
		["...", "ccc", "ccc", "ccc"],
		["...", "ccc", "ccc", "ccc"],
		["...", "ccc", "ccc", "ccc"],
		["...", "ccc", "ccc", "ccc"],
		["...", "ccc", "ccc", "ccc"],
		["...", "ccc", "ccc", "ccc"],
		["...", "ccc", "ccc", "ccc"],
	],
}


# --- Arm ----------------------------------------------------------------------
#
# 3 wide, 9 long, 3 deep, hanging from the shoulder. Sleeve on the top three,
# bare forearm below, and the bottom three are the hand - shaded skin rather
# than skin, which puts a visible wrist on a limb that is otherwise one
# unbroken column. Authored for the right arm and mirrored for the left.

const ARM := {
	"size": Vector3i(3, 9, 3),
	"anchor": Vector3(1.5, 9, 1.5),
	"slices": [
		["sss", "sss", "sss"],
		["sss", "sss", "sss"],
		["sss", "sss", "sss"],
		["SSS", "SSS", "SSS"],
		["SSS", "SSS", "SSS"],
		["SSS", "SSS", "SSS"],
		["CCC", "CCC", "CCC"],
		["CCC", "CCC", "CCC"],
		["CCC", "CCC", "CCC"],
	],
}


## Every part in this set, by the name a bone table refers to it with.
##
## `arm_l` and `leg_l` are deliberately absent: they are the right-hand parts
## mirrored, and Rig applies the mirror from the bone's own name. One authored
## arm means one arm to fix when the sleeve is wrong.
const PARTS := {
	"head": HEAD,
	"torso": TORSO,
	"pelvis": PELVIS,
	"leg": LEG,
	"arm": ARM,
}
