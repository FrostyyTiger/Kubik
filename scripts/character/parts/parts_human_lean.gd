class_name PartsHumanLean

## The human again, in naturalistic proportions. The other half of the study.
##
## THE POINT OF THIS FILE IS THAT IT IS ONLY A FILE. Same rig, same animator,
## same palette, same everything - one part set with different numbers in it.
## If the two schemes needed two animators the study would be measuring the
## animator instead of the proportions, which is why the plan insists on
## single-segment limbs in both.
##
## THE STACK, in model voxels:
##
##     legs   [0, 14)  14   boots at the bottom, trousers above
##     torso  [14, 25) 11   tunic, belt on its bottom row
##     neck   [25, 26)  1   the bottom slice of the head part
##     head   [26, 32)  6   eyes at 30-31, which is 1.88 m
##
## No pelvis: 14 + 11 + 1 + 6 is 32 exactly, so `hips` is a pure transform with
## the belt socket on it. That is legal by construction and it is the case the
## rig's "a bone may be a transform" branch exists for.
##
## THE NECK IS PART OF THE HEAD, not a bone of its own. A neck bone would be a
## fifth thing to pose for no gain; putting the neck column at the bottom of
## the head part means the head rotates about the BASE of the neck, which is
## where a head-look should pivot anyway.

# --- Head ---------------------------------------------------------------------
#
# 6 wide, 1 + 6 tall, 6 deep plus one for the nose.
#
# THE EYES ARE 1 x 2 AND ALL IRIS. The plan drops the face requirement here to
# "has a face at 5 m" and says the lean scheme's readability comes from neck
# and shoulders instead. At one voxel wide there is no room for white beside
# the iris - two 6.25 cm dots merge into one at any distance worth measuring -
# so the eye is a dark slot, which is what a small-scale voxel face has always
# been. The stocky head keeps its white; that difference is part of what the
# study is comparing.

const HEAD := {
	"size": Vector3i(6, 7, 7),
	"anchor": Vector3(3, 0, 3.5),
	"slices": [
		# y = 0, the neck: a 2 x 2 column under the middle of the skull
		["......", "......", "......", "..SS..", "..SS..", "......", "......"],
		# y = 1, the jaw
		["......", "SSSSSS", "SSSSSS", "SSSSSS", "SSSSSS", "SSSSSS", "SSSSSS"],
		# y = 2, the mouth
		["......", "SSMMSS", "SSSSSS", "SSSSSS", "SSSSSS", "SSSSSS", "SSSSSS"],
		# y = 3, the nose - the only slice with anything at z = 0
		["..SS..", "SSSSSS", "SSSSSS", "SSSSSS", "SSSSSS", "SSSSSS", "SSSSSS"],
		# y = 4, eyes, lower row
		["......", "SESSES", "SSSSSS", "SSSSSS", "SSSSSS", "SSSSSS", "SSSSSS"],
		# y = 5, eyes, upper row
		["......", "SESSES", "SSSSSS", "SSSSSS", "SSSSSS", "SSSSSS", "SSSSSS"],
		# y = 6, the crown
		["......", "SSSSSS", "SSSSSS", "SSSSSS", "SSSSSS", "SSSSSS", "SSSSSS"],
	],
}


# --- Torso --------------------------------------------------------------------
#
# 7 wide, 11 tall, 4 deep. Narrower and deeper-waisted than the stocky torso,
# and one voxel narrower than an odd number needs to be to have a centre column
# - which is the whole reason the anchor is a lattice point and not a voxel
# index. Belt on the bottom row, at the waist.

const TORSO := {
	"size": Vector3i(7, 11, 4),
	"anchor": Vector3(3.5, 0, 2),
	"slices": [
		["BBBBBBB", "BBBBBBB", "BBBBBBB", "BBBBBBB"],
		["CCCCCCC", "CCCCCCC", "CCCCCCC", "CCCCCCC"],
		["CCCCCCC", "CCCCCCC", "CCCCCCC", "CCCCCCC"],
		["CCCCCCC", "CCCCCCC", "CCCCCCC", "CCCCCCC"],
		["CCCCCCC", "CCCCCCC", "CCCCCCC", "CCCCCCC"],
		["CCCCCCC", "CCCCCCC", "CCCCCCC", "CCCCCCC"],
		["CCCCCCC", "CCCCCCC", "CCCCCCC", "CCCCCCC"],
		["CCCCCCC", "CCCCCCC", "CCCCCCC", "CCCCCCC"],
		["CCCCCCC", "CCCCCCC", "CCCCCCC", "CCCCCCC"],
		["CCCCCCC", "CCCCCCC", "CCCCCCC", "CCCCCCC"],
		["CCCCCCC", "CCCCCCC", "CCCCCCC", "CCCCCCC"],
	],
}


# --- Leg ----------------------------------------------------------------------
#
# 2 wide, 14 tall, 3 deep at the boot and 2 deep above it. Long, thin, and
# authored once for the right leg - the left is this mirrored.

const LEG := {
	"size": Vector3i(2, 14, 3),
	"anchor": Vector3(1, 14, 1.5),
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
		["..", "cc", "cc"],
		["..", "cc", "cc"],
	],
}


# --- Arm ----------------------------------------------------------------------
#
# 2 wide, 12 long, 2 deep. Sleeve on the top four, bare forearm below, and the
# bottom two are the hand in shaded skin - the same wrist break the stocky arm
# has, at the scale this scheme allows.

const ARM := {
	"size": Vector3i(2, 12, 2),
	"anchor": Vector3(1, 12, 1),
	"slices": [
		["ss", "ss"],
		["ss", "ss"],
		["SS", "SS"],
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


## No `pelvis` entry. The lean stack leaves no room for one, and Rig treats a
## bone whose part name is empty as a pure transform.
const PARTS := {
	"head": HEAD,
	"torso": TORSO,
	"leg": LEG,
	"arm": ARM,
}
