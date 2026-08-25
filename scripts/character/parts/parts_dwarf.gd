class_name PartsDwarf

## The dwarf: 24 voxels tall and 20 wide across the arms.
##
## THE SILHOUETTE IS "AS WIDE AS IT IS TALL, BEARD". At 1.50 m tall and 1.25 m
## across the shoulders it is the only character in the game whose outline is
## wider than a door, and that alone separates it from the human at any
## distance. The beard is the second half and it is not optional: the dwarf's
## beard picker has three entries and none of them is "none", because a
## beardless dwarf at 40 m is a short human.
##
## THE STACK, in model voxels:
##
##     legs   [0,  5)   5
##     torso  [5, 14)   9
##     head   [14, 24) 10
##
## No pelvis - the stack leaves no room and `hips` is a pure transform with the
## belt socket on it. The head is 42% of the total height, which is the most
## extreme proportion in the game and is the point of the race.

# --- Head ---------------------------------------------------------------------
#
# 10 wide, 10 tall, 8 deep plus one for the nose. Wider than the human's head
# and taller, on a body that is shorter - a big face at eye level, which is
# what you want on the race whose face is half its identity.

const HEAD := {
	"size": Vector3i(10, 10, 9),
	"anchor": Vector3(5, 0, 5),
	"slices": [
		# y = 0, the chin - well inside the beard, once it arrives
		["..........", "SSSSSSSSSS", "SSSSSSSSSS", "SSSSSSSSSS", "SSSSSSSSSS",
		 "SSSSSSSSSS", "SSSSSSSSSS", "SSSSSSSSSS", "SSSSSSSSSS"],
		# y = 1
		["..........", "SSSSSSSSSS", "SSSSSSSSSS", "SSSSSSSSSS", "SSSSSSSSSS",
		 "SSSSSSSSSS", "SSSSSSSSSS", "SSSSSSSSSS", "SSSSSSSSSS"],
		# y = 2
		["..........", "SSSSSSSSSS", "SSSSSSSSSS", "SSSSSSSSSS", "SSSSSSSSSS",
		 "SSSSSSSSSS", "SSSSSSSSSS", "SSSSSSSSSS", "SSSSSSSSSS"],
		# y = 3, the mouth
		["..........", "SSSMMMMSSS", "SSSSSSSSSS", "SSSSSSSSSS", "SSSSSSSSSS",
		 "SSSSSSSSSS", "SSSSSSSSSS", "SSSSSSSSSS", "SSSSSSSSSS"],
		# y = 4
		["..........", "SSSSSSSSSS", "SSSSSSSSSS", "SSSSSSSSSS", "SSSSSSSSSS",
		 "SSSSSSSSSS", "SSSSSSSSSS", "SSSSSSSSSS", "SSSSSSSSSS"],
		# y = 5, the nose - two voxels out, because a dwarf's is
		["....SS....", "SSSSSSSSSS", "SSSSSSSSSS", "SSSSSSSSSS", "SSSSSSSSSS",
		 "SSSSSSSSSS", "SSSSSSSSSS", "SSSSSSSSSS", "SSSSSSSSSS"],
		# y = 6, eyes, lower row
		["..........", "SSWESSEWSS", "SSSSSSSSSS", "SSSSSSSSSS", "SSSSSSSSSS",
		 "SSSSSSSSSS", "SSSSSSSSSS", "SSSSSSSSSS", "SSSSSSSSSS"],
		# y = 7, eyes, upper row
		["..........", "SSWESSEWSS", "SSSSSSSSSS", "SSSSSSSSSS", "SSSSSSSSSS",
		 "SSSSSSSSSS", "SSSSSSSSSS", "SSSSSSSSSS", "SSSSSSSSSS"],
		# y = 8, a heavy brow
		["..........", "ssssssssss", "SSSSSSSSSS", "SSSSSSSSSS", "SSSSSSSSSS",
		 "SSSSSSSSSS", "SSSSSSSSSS", "SSSSSSSSSS", "SSSSSSSSSS"],
		# y = 9, the crown
		["..........", "SSSSSSSSSS", "SSSSSSSSSS", "SSSSSSSSSS", "SSSSSSSSSS",
		 "SSSSSSSSSS", "SSSSSSSSSS", "SSSSSSSSSS", "SSSSSSSSSS"],
	],
}


# --- Torso --------------------------------------------------------------------
#
# 12 wide, 9 tall, 7 deep. A barrel. This is where the "as wide as it is tall"
# comes from, before the arms are even attached.

const TORSO := {
	"size": Vector3i(12, 9, 7),
	"anchor": Vector3(6, 0, 3.5),
	"slices": [
		["BBBBBBBBBBBB", "BBBBBBBBBBBB", "BBBBBBBBBBBB", "BBBBBBBBBBBB",
		 "BBBBBBBBBBBB", "BBBBBBBBBBBB", "BBBBBBBBBBBB"],
		["CCCCCCCCCCCC", "CCCCCCCCCCCC", "CCCCCCCCCCCC", "CCCCCCCCCCCC",
		 "CCCCCCCCCCCC", "CCCCCCCCCCCC", "CCCCCCCCCCCC"],
		["CCCCCCCCCCCC", "CCCCCCCCCCCC", "CCCCCCCCCCCC", "CCCCCCCCCCCC",
		 "CCCCCCCCCCCC", "CCCCCCCCCCCC", "CCCCCCCCCCCC"],
		["CCCCCCCCCCCC", "CCCCCCCCCCCC", "CCCCCCCCCCCC", "CCCCCCCCCCCC",
		 "CCCCCCCCCCCC", "CCCCCCCCCCCC", "CCCCCCCCCCCC"],
		["CCCCCCCCCCCC", "CCCCCCCCCCCC", "CCCCCCCCCCCC", "CCCCCCCCCCCC",
		 "CCCCCCCCCCCC", "CCCCCCCCCCCC", "CCCCCCCCCCCC"],
		["CCCCCCCCCCCC", "CCCCCCCCCCCC", "CCCCCCCCCCCC", "CCCCCCCCCCCC",
		 "CCCCCCCCCCCC", "CCCCCCCCCCCC", "CCCCCCCCCCCC"],
		["CCCCCCCCCCCC", "CCCCCCCCCCCC", "CCCCCCCCCCCC", "CCCCCCCCCCCC",
		 "CCCCCCCCCCCC", "CCCCCCCCCCCC", "CCCCCCCCCCCC"],
		["CCCCCCCCCCCC", "CCCCCCCCCCCC", "CCCCCCCCCCCC", "CCCCCCCCCCCC",
		 "CCCCCCCCCCCC", "CCCCCCCCCCCC", "CCCCCCCCCCCC"],
		["CCCCCCCCCCCC", "CCCCCCCCCCCC", "CCCCCCCCCCCC", "CCCCCCCCCCCC",
		 "CCCCCCCCCCCC", "CCCCCCCCCCCC", "CCCCCCCCCCCC"],
	],
}


# --- Leg ----------------------------------------------------------------------
#
# 4 wide, 5 tall, 4 deep with a 5-deep boot. The shortest legs in the game, and
# most of what is left is boot - which is why the dwarf's stride is short and
# quick out of the same one-line scale every other race uses.

const LEG := {
	"size": Vector3i(4, 5, 5),
	"anchor": Vector3(2, 5, 3),
	"slices": [
		["LLLL", "LLLL", "LLLL", "LLLL", "LLLL"],
		["LLLL", "LLLL", "LLLL", "LLLL", "LLLL"],
		["....", "cccc", "cccc", "cccc", "cccc"],
		["....", "cccc", "cccc", "cccc", "cccc"],
		["....", "cccc", "cccc", "cccc", "cccc"],
	],
}


# --- Arm ----------------------------------------------------------------------
#
# 4 wide, 8 long, 4 deep. Thick, and hung off a 12-wide torso, which puts the
# outside of the hand 10 voxels from the centre line - 1.25 m across.

const ARM := {
	"size": Vector3i(4, 8, 4),
	"anchor": Vector3(2, 8, 2),
	"slices": [
		["ssss", "ssss", "ssss", "ssss"],
		["ssss", "ssss", "ssss", "ssss"],
		["ssss", "ssss", "ssss", "ssss"],
		["SSSS", "SSSS", "SSSS", "SSSS"],
		["SSSS", "SSSS", "SSSS", "SSSS"],
		["CCCC", "CCCC", "CCCC", "CCCC"],
		["CCCC", "CCCC", "CCCC", "CCCC"],
		["CCCC", "CCCC", "CCCC", "CCCC"],
	],
}


const PARTS := {
	"head": HEAD,
	"torso": TORSO,
	"leg": LEG,
	"arm": ARM,
}
