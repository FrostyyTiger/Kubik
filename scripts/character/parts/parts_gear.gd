class_name PartsGear

## Three placeholders that hang on three sockets.
##
## THIS IS NOT A GEAR SYSTEM. There are no slots on CharacterDef, nothing on
## the wire, and no stats. THE SOCKETS ARE THE DELIVERABLE; these three items
## exist to prove them - that a thing attached to `hand_r` swings with the arm,
## a thing on `chest` rides the sprint lean, and a thing on `neck` stays put
## through a sit. The gear plan owns everything past that.
##
## AUTHORED IN THE SOCKET'S OWN FRAME, the way hair is authored in the head's:
## the origin is the socket, so a sword is described as "rising from the hand,
## outboard of the arm" rather than in a coordinate system nobody can picture.
##
## EVERY PLACEHOLDER IS PLACED CLEAR OF EVERY BODY, all four races and both
## builds, and the self-test checks it voxel by voxel rather than by eye. That
## is harder than it sounds - the races differ by a factor of two in torso
## depth - and it is the reason the pendant hangs a little proud of the chest
## rather than resting on it. A placeholder that intersects a dwarf would be
## measuring the placeholder instead of the socket.

# --- A wooden sword, for `hand_r` ---------------------------------------------
#
# 14 voxels: three of grip, one of crossguard, ten of blade. The `hand_r`
# socket sits at the far end of the arm bone, on its centre line, so the sword
# is offset OUTBOARD - x +2.5 to +5.5 - which clears the widest arm in the game
# (the dwarf's, four voxels across) and reads as carried at the shoulder.
#
# Rising rather than hanging, and that is forced rather than chosen: a 14-voxel
# sword pointing down from a dwarf's hand, which is five voxels off the ground,
# would be nine voxels underground.

const SWORD := {
	"size": Vector3i(3, 14, 3),
	"anchor": Vector3(-2.5, 0, 1.5),
	"slices": [
		["...", ".D.", "..."],
		["...", ".D.", "..."],
		["...", ".D.", "..."],
		["XXX", "XXX", "XXX"],
		["...", ".X.", "..."],
		["...", ".X.", "..."],
		["...", ".X.", "..."],
		["...", ".X.", "..."],
		["...", ".X.", "..."],
		["...", ".X.", "..."],
		["...", ".X.", "..."],
		["...", ".X.", "..."],
		["...", ".X.", "..."],
		["...", ".X.", "..."],
	],
}


# --- A tunic overlay, for `chest` ---------------------------------------------
#
# The `chest` socket sits ON the front face of the torso, so a panel one voxel
# in front of it is one voxel outside the body for every race - which is what
# "a shell one voxel outside the torso" means when the torsos are 4, 5 and 7
# voxels deep.
#
# Four wide rather than the torso's width, because the torso's width is 5 on an
# elf and 12 on a dwarf and one placeholder cannot be both. It reads as a
# tabard, which is exactly what a placeholder for a chest item should read as.

const TUNIC := {
	"size": Vector3i(4, 6, 1),
	"anchor": Vector3(2, 3, 1),
	"slices": [
		["cccc"],
		["cccc"],
		["cccc"],
		["cccc"],
		["cccc"],
		["cccc"],
	],
}


# --- A pendant on a cord, for `neck` ------------------------------------------
#
# The `neck` socket is at the TOP of the torso and on its centre line, so
# anything hanging straight down from it is inside the chest. This hangs five
# voxels forward instead, which clears the deepest torso in the game (the
# dwarf's, 3.5 voxels to the front face) with room to spare.
#
# IT THEREFORE FLOATS SLIGHTLY PROUD of an elf's narrower chest, and a cord
# that sloped back to the neck would look better and would put two voxels
# inside a dwarf. For an item whose entire job is to prove that a socket exists
# and follows the body, zero intersection on all four races is worth more than
# a prettier cord. The gear plan can do better with per-race offsets.

const PENDANT := {
	"size": Vector3i(3, 6, 1),
	"anchor": Vector3(1.5, 6, 5),
	"slices": [
		["XXX"],
		[".X."],
		[".B."],
		[".B."],
		[".B."],
		[".B."],
	],
}


## Socket name -> the placeholder that hangs on it. The other three sockets -
## `hand_l`, `back` and `belt` - get nothing, and that is the point: they exist
## on every race whether or not anything is hanging on them.
const PLACEHOLDERS := {
	"hand_r": SWORD,
	"chest": TUNIC,
	"neck": PENDANT,
}
