class_name PartsLizardfolk

## The lizardfolk: a snout in front, a tail behind, and leaning eight degrees
## into both.
##
## THE SILHOUETTE IS "TAIL, CREST, SNOUT" and it is the only one of the four
## that is made of things sticking OUT rather than of overall proportion. The
## body is the human's - same 8 x 5 torso, same 9-voxel legs - which is
## deliberate: if the lizardfolk had a distinct build as well, the silhouette
## test would not be able to tell which feature was doing the work.
##
## THE STACK, in model voxels:
##
##     legs   [0,  9)   9
##     pelvis [9, 11)   2
##     torso  [11, 21) 10
##     head   [21, 30)  9
##
## The 8 degree forward lean is baked into the HIPS REST POSE (see Rig.build),
## not applied by the animator, so it survives every pose and the animator
## never learns that one race stands differently from the others.
##
## The tail is three bones on the generic chain rule - the same rule the
## critter uses in Stage 13 - with segments of 5, 5 and 4 voxels.

# --- Head ---------------------------------------------------------------------
#
# 8 wide, 9 tall, and 12 DEEP: an 8-deep skull at z 4 to 11 with a 4-voxel
# snout in front of it at z 0 to 3. The snout is four wide, not eight, so the
# head reads as a wedge from above and as a muzzle from the side.
#
# The eyes sit on the front of the SKULL at z = 4, above the snout, which is
# where a reptile's are. Teeth on the underside of the snout in the `T` slot.

const HEAD := {
	"size": Vector3i(8, 9, 12),
	"anchor": Vector3(4, 0, 8),
	"slices": [
		# y = 0, the underside of the jaw
		["........", "........", "........", "........",
		 "SSSSSSSS", "SSSSSSSS", "SSSSSSSS", "SSSSSSSS",
		 "SSSSSSSS", "SSSSSSSS", "SSSSSSSS", "SSSSSSSS"],
		# y = 1
		["........", "........", "........", "........",
		 "SSSSSSSS", "SSSSSSSS", "SSSSSSSS", "SSSSSSSS",
		 "SSSSSSSS", "SSSSSSSS", "SSSSSSSS", "SSSSSSSS"],
		# y = 2, the snout begins - and its teeth
		["..TTTT..", "..TTTT..", "..SSSS..", "..SSSS..",
		 "SSSSSSSS", "SSSSSSSS", "SSSSSSSS", "SSSSSSSS",
		 "SSSSSSSS", "SSSSSSSS", "SSSSSSSS", "SSSSSSSS"],
		# y = 3
		["..SSSS..", "..SSSS..", "..SSSS..", "..SSSS..",
		 "SSSSSSSS", "SSSSSSSS", "SSSSSSSS", "SSSSSSSS",
		 "SSSSSSSS", "SSSSSSSS", "SSSSSSSS", "SSSSSSSS"],
		# y = 4
		["..SSSS..", "..SSSS..", "..SSSS..", "..SSSS..",
		 "SSSSSSSS", "SSSSSSSS", "SSSSSSSS", "SSSSSSSS",
		 "SSSSSSSS", "SSSSSSSS", "SSSSSSSS", "SSSSSSSS"],
		# y = 5, the top of the snout, with nostrils
		["..ssss..", "..SSSS..", "..SSSS..", "..SSSS..",
		 "SSSSSSSS", "SSSSSSSS", "SSSSSSSS", "SSSSSSSS",
		 "SSSSSSSS", "SSSSSSSS", "SSSSSSSS", "SSSSSSSS"],
		# y = 6, eyes on the front of the skull, above the snout
		["........", "........", "........", "........",
		 "SWESSEWS", "SSSSSSSS", "SSSSSSSS", "SSSSSSSS",
		 "SSSSSSSS", "SSSSSSSS", "SSSSSSSS", "SSSSSSSS"],
		# y = 7, eyes, upper row
		["........", "........", "........", "........",
		 "SWESSEWS", "SSSSSSSS", "SSSSSSSS", "SSSSSSSS",
		 "SSSSSSSS", "SSSSSSSS", "SSSSSSSS", "SSSSSSSS"],
		# y = 8, the brow ridge and the crown
		["........", "........", "........", "........",
		 "ssssssss", "SSSSSSSS", "SSSSSSSS", "SSSSSSSS",
		 "SSSSSSSS", "SSSSSSSS", "SSSSSSSS", "SSSSSSSS"],
	],
}


# --- Torso, pelvis, leg, arm --------------------------------------------------
#
# The human's dimensions, in a harness and a loincloth rather than a tunic.
# DESIGN.md gives the lizardfolk the only outfit that is not a tunic; the slots
# are the same ones and it is the resolve table that differs.

const TORSO := {
	"size": Vector3i(8, 10, 5),
	"anchor": Vector3(4, 0, 2.5),
	"slices": [
		["BBBBBBBB", "BBBBBBBB", "BBBBBBBB", "BBBBBBBB", "BBBBBBBB"],
		["SSSSSSSS", "SSSSSSSS", "SSSSSSSS", "SSSSSSSS", "SSSSSSSS"],
		["SSSSSSSS", "SSSSSSSS", "SSSSSSSS", "SSSSSSSS", "SSSSSSSS"],
		["SSSBBSSS", "SSSSSSSS", "SSSSSSSS", "SSSSSSSS", "SSSSSSSS"],
		["SSSBBSSS", "SSSSSSSS", "SSSSSSSS", "SSSSSSSS", "SSSSSSSS"],
		["SSBBBBSS", "SSSSSSSS", "SSSSSSSS", "SSSSSSSS", "SSSSSSSS"],
		["SSSSSSSS", "SSSSSSSS", "SSSSSSSS", "SSSSSSSS", "SSSSSSSS"],
		["SSSSSSSS", "SSSSSSSS", "SSSSSSSS", "SSSSSSSS", "SSSSSSSS"],
		["SSSSSSSS", "SSSSSSSS", "SSSSSSSS", "SSSSSSSS", "SSSSSSSS"],
		["SSSSSSSS", "SSSSSSSS", "SSSSSSSS", "SSSSSSSS", "SSSSSSSS"],
	],
}


const PELVIS := {
	"size": Vector3i(8, 2, 5),
	"anchor": Vector3(4, 0, 2.5),
	"slices": [
		["cccccccc", "cccccccc", "cccccccc", "cccccccc", "cccccccc"],
		["cccccccc", "cccccccc", "cccccccc", "cccccccc", "cccccccc"],
	],
}


## Barefoot, with claws at the toes - the one race that does not wear boots.
const LEG := {
	"size": Vector3i(3, 9, 4),
	"anchor": Vector3(1.5, 9, 2.5),
	"slices": [
		["TTT", "SSS", "SSS", "SSS"],
		["SSS", "SSS", "SSS", "SSS"],
		["...", "SSS", "SSS", "SSS"],
		["...", "SSS", "SSS", "SSS"],
		["...", "SSS", "SSS", "SSS"],
		["...", "SSS", "SSS", "SSS"],
		["...", "ccc", "ccc", "ccc"],
		["...", "ccc", "ccc", "ccc"],
		["...", "ccc", "ccc", "ccc"],
	],
}


const ARM := {
	"size": Vector3i(3, 9, 3),
	"anchor": Vector3(1.5, 9, 1.5),
	"slices": [
		["TTT", "SSS", "SSS"],
		["SSS", "SSS", "SSS"],
		["SSS", "SSS", "SSS"],
		["SSS", "SSS", "SSS"],
		["SSS", "SSS", "SSS"],
		["SSS", "SSS", "SSS"],
		["SSS", "SSS", "SSS"],
		["BBB", "SSS", "SSS"],
		["SSS", "SSS", "SSS"],
	],
}


# --- Tail ---------------------------------------------------------------------
#
# Three segments, 5 + 5 + 4 = 14 voxels, tapering. Each is anchored at its
# FRONT face so it grows backward along +Z from the bone that carries it, and
# each bone's rest offset is the previous segment's length - so the chain is
# continuous by construction rather than by three numbers agreeing.
#
# The animator finds these by name alone (`tail_1..n`) and knows nothing about
# lizards. Stage 13's critter uses the same rule.

const TAIL_1 := {
	"size": Vector3i(3, 3, 5),
	"anchor": Vector3(1.5, 0, 0),
	"slices": [
		["SSS", "SSS", "SSS", "SSS", "SSS"],
		["SSS", "SSS", "SSS", "SSS", "SSS"],
		["SSS", "SSS", "SSS", "SSS", "SSS"],
	],
}

const TAIL_2 := {
	"size": Vector3i(2, 2, 5),
	"anchor": Vector3(1, 0, 0),
	"slices": [
		["SS", "SS", "SS", "SS", "SS"],
		["SS", "SS", "SS", "SS", "SS"],
	],
}

const TAIL_3 := {
	"size": Vector3i(2, 2, 4),
	"anchor": Vector3(1, 0, 0),
	"slices": [
		["SS", "SS", "ss", "ss"],
		["SS", "SS", "ss", "ss"],
	],
}


const PARTS := {
	"head": HEAD,
	"torso": TORSO,
	"pelvis": PELVIS,
	"leg": LEG,
	"arm": ARM,
	"tail_1": TAIL_1,
	"tail_2": TAIL_2,
	"tail_3": TAIL_3,
}
