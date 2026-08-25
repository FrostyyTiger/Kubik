class_name PartsCritter

## A four-legged thing the size of a large dog.
##
## IT EXISTS TO FAIL LOUDLY IF ANY OF THIS IS SECRETLY HUMANOID. It has no
## `torso`, no `hips`, no arms and four legs, so every place in the pipeline
## that quietly assumed a two-legged skeleton - the mesher, the rig, the chain
## rule, the animator - either works on it or does not. Nothing else in this
## plan could have found those assumptions, because everything else in this
## plan is a person.
##
## GALLERY ONLY. No AI, no scene, no spawning, no CharacterDef. It is a model
## that walks in a strip, and it is what the first-enemy plan starts from.
##
## Shoulder height is 11 voxels, 0.69 m, which is a big dog. The body is
## fourteen voxels long, so it is longer than it is tall by two to one - the
## proportion that makes a quadruped read as a quadruped rather than as a
## person on all fours.

## Model voxels, for the table below.
const V := VoxelModel.VOXEL_M


# --- Body ---------------------------------------------------------------------
#
# 6 wide, 6 tall, 14 long. The anchor is at the middle of its length and the
# bottom of its height, so the four leg sockets hang from it symmetrically and
# the whole animal sits on top of its legs.

const BODY := {
	"size": Vector3i(6, 6, 14),
	"anchor": Vector3(3, 0, 7),
	"slices": [
		["......", "SSSSSS", "SSSSSS", "SSSSSS", "SSSSSS", "SSSSSS", "SSSSSS",
		 "SSSSSS", "SSSSSS", "SSSSSS", "SSSSSS", "SSSSSS", "SSSSSS", "......"],
		["SSSSSS", "SSSSSS", "SSSSSS", "SSSSSS", "SSSSSS", "SSSSSS", "SSSSSS",
		 "SSSSSS", "SSSSSS", "SSSSSS", "SSSSSS", "SSSSSS", "SSSSSS", "SSSSSS"],
		["SSSSSS", "SSSSSS", "SSSSSS", "SSSSSS", "SSSSSS", "SSSSSS", "SSSSSS",
		 "SSSSSS", "SSSSSS", "SSSSSS", "SSSSSS", "SSSSSS", "SSSSSS", "SSSSSS"],
		["SSSSSS", "SSSSSS", "SSSSSS", "SSSSSS", "SSSSSS", "SSSSSS", "SSSSSS",
		 "SSSSSS", "SSSSSS", "SSSSSS", "SSSSSS", "SSSSSS", "SSSSSS", "SSSSSS"],
		["SSSSSS", "SSSSSS", "SSSSSS", "SSSSSS", "SSSSSS", "SSSSSS", "SSSSSS",
		 "SSSSSS", "SSSSSS", "SSSSSS", "SSSSSS", "SSSSSS", "SSSSSS", "SSSSSS"],
		["......", "SSSSSS", "SSSSSS", "SSSSSS", "SSSSSS", "SSSSSS", "SSSSSS",
		 "SSSSSS", "SSSSSS", "SSSSSS", "SSSSSS", "SSSSSS", "SSSSSS", "......"],
	],
}


# --- Head ---------------------------------------------------------------------
#
# 6 wide, 6 tall, 6 of skull plus 3 of snout. The anchor is at the BACK of the
# head - z 9 - so the head grows forward from the neck joint, which is where a
# quadruped's head hangs from.

const HEAD := {
	"size": Vector3i(6, 6, 9),
	"anchor": Vector3(3, 0, 9),
	"slices": [
		["..TT..", "..SS..", "..SS..", "SSSSSS", "SSSSSS", "SSSSSS", "SSSSSS",
		 "SSSSSS", "SSSSSS"],
		["..SS..", "..SS..", "..SS..", "SSSSSS", "SSSSSS", "SSSSSS", "SSSSSS",
		 "SSSSSS", "SSSSSS"],
		["..SS..", "..SS..", "..SS..", "SSSSSS", "SSSSSS", "SSSSSS", "SSSSSS",
		 "SSSSSS", "SSSSSS"],
		["......", "......", "......", "SWESES", "SSSSSS", "SSSSSS", "SSSSSS",
		 "SSSSSS", "SSSSSS"],
		["......", "......", "......", "SSSSSS", "SSSSSS", "SSSSSS", "SSSSSS",
		 "SSSSSS", "SSSSSS"],
		["......", "......", "......", "HSSSSH", "HSSSSH", "SSSSSS", "SSSSSS",
		 "SSSSSS", "SSSSSS"],
	],
}


# --- Leg ----------------------------------------------------------------------
#
# 2 x 5 x 2, anchored at the TOP so it swings from the shoulder, exactly as a
# humanoid leg does. Authored once and used four times: the gait table decides
# which of them are in phase, not the geometry.

const LEG := {
	"size": Vector3i(2, 5, 2),
	"anchor": Vector3(1, 5, 1),
	"slices": [
		["TT", "SS"],
		["SS", "SS"],
		["SS", "SS"],
		["SS", "SS"],
		["SS", "SS"],
	],
}


# --- Tail ---------------------------------------------------------------------
#
# Two segments on the SAME generic chain rule the lizardfolk uses. That is half
# the point of building this animal: if the chain rule had quietly assumed
# three links or a humanoid parent, this is where it would show.

const TAIL_1 := {
	"size": Vector3i(2, 2, 4),
	"anchor": Vector3(1, 0, 0),
	"slices": [
		["SS", "SS", "SS", "SS"],
		["SS", "SS", "SS", "SS"],
	],
}

const TAIL_2 := {
	"size": Vector3i(2, 2, 3),
	"anchor": Vector3(1, 0, 0),
	"slices": [
		["SS", "ss", "ss"],
		["SS", "ss", "ss"],
	],
}


const PARTS := {
	"body": BODY,
	"head": HEAD,
	"leg": LEG,
	"tail_1": TAIL_1,
	"tail_2": TAIL_2,
}


## The critter's dimension table, in the shape Races.dims() returns.
##
## `gait` is the only field that is not a measurement, and it is the field this
## whole animal exists to exercise: it names an entry in Animator.RIG_SHAPES,
## which says which bones are legs and which of them share a phase.
const DIMS := {
	"name": "critter",
	"total": 11, "legs": 5, "torso": 6, "head": 6,
	"torso_w": 6, "torso_d": 6, "head_w": 6, "head_d": 9,
	"leg_w": 2, "arm_len": 0, "arm_w": 0,
	"gait": "trot",
	"lean_deg": 0.0,
	"silhouette": "long, low and four-legged",
}


## Bones and sockets, in the shape Races.bone_table() returns.
##
## NO `torso`, NO `hips`, NO ARMS. Written out rather than derived, because
## Races.bone_table() derives a HUMANOID from a race table and this is the
## thing that proves it does not have to be the only shape - a quadruped whose
## bone table came out of the same generator would not be evidence of anything.
static func bone_table() -> Array:
	var leg_x := 1.5
	var leg_z := 5.0
	return [
		{"name": "body", "parent": "", "rest": Vector3(0, 5, 0) * V, "part": "body"},
		{"name": "head", "parent": "body", "rest": Vector3(0, 2, -7) * V, "part": "head"},
		{"name": "leg_fr", "parent": "body", "rest": Vector3(leg_x, 0, -leg_z) * V, "part": "leg"},
		{"name": "leg_fl", "parent": "body", "rest": Vector3(-leg_x, 0, -leg_z) * V,
			"part": "leg", "mirror": true},
		{"name": "leg_br", "parent": "body", "rest": Vector3(leg_x, 0, leg_z) * V, "part": "leg"},
		{"name": "leg_bl", "parent": "body", "rest": Vector3(-leg_x, 0, leg_z) * V,
			"part": "leg", "mirror": true},
		{"name": "tail_1", "parent": "body", "rest": Vector3(0, 4, 7) * V, "part": "tail_1"},
		{"name": "tail_2", "parent": "tail_1", "rest": Vector3(0, 0, 4) * V, "part": "tail_2"},
		# One socket, because the rule is that sockets are not a humanoid idea.
		# A pack, a saddle, a collar: whatever the first-enemy plan wants, the
		# machinery is the same machinery.
		{"name": "back", "parent": "body", "rest": Vector3(0, 6, 0) * V, "socket": true},
	]


## A palette for it. Not a race, so it has no entry in Races - and that is the
## point: the mesher takes any slot table at all.
static func palette() -> Dictionary:
	var hide := Color.html("#6B5B45").srgb_to_linear()
	return {
		VoxelModel.SKIN: hide,
		VoxelModel.SKIN_SHADED: Color(hide.r * 0.8, hide.g * 0.8, hide.b * 0.8),
		VoxelModel.HAIR: Color.html("#3A3028").srgb_to_linear(),
		VoxelModel.IRIS: Color.html("#C9A227").srgb_to_linear(),
		VoxelModel.EYE_WHITE: Color.html("#F4F0E8").srgb_to_linear(),
		VoxelModel.MOUTH: Color.html("#3A2A22").srgb_to_linear(),
		VoxelModel.CLOTH: hide,
		VoxelModel.CLOTH_DARK: hide,
		VoxelModel.LEATHER: Color.html("#3A2A1E").srgb_to_linear(),
		VoxelModel.BELT: Color.html("#5A4632").srgb_to_linear(),
		VoxelModel.TOOTH: Color.html("#EDE6D4").srgb_to_linear(),
		VoxelModel.METAL: Color.html("#9A9FA6").srgb_to_linear(),
		VoxelModel.WOOD: Color.html("#7A5230").srgb_to_linear(),
	}
