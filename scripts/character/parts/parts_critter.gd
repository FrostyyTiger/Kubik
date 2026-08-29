class_name PartsCritter

## The critter: the tables a four-legged animal needs and a humanoid does not.
##
## HAND-WRITTEN AND PERMANENT. The geometry left for
## `assets/characters/parts/critter.json` in parts-data v1 - `body`, `head`,
## `leg`, `tail_1`, `tail_2` - and what stayed is everything below, which is
## GDScript rather than ASCII: a dimension table, a bone table written out by
## hand, and a palette.
##
## THIS ANIMAL EXISTS TO PROVE NONE OF THE PIPELINE IS SECRETLY HUMANOID. It
## has no `torso`, no `hips`, no arms and four legs, and it is built by the
## same Rig, the same Animator and the same mesher as a person.


## Model voxels, for the tables below.
const V := VoxelModel.VOXEL_M


## The critter's dimension table, in the shape Races.dims() returns.
##
## `gait` is the only field that is not a measurement, and it is the field this
## whole animal exists to exercise: it names an entry in Animator.RIG_SHAPES,
## which says which bones are legs and which of them share a phase.
const DIMS := {
	"name": "critter",
	"total": 22, "legs": 10, "torso": 12, "head": 12,
	"torso_w": 12, "torso_d": 12, "head_w": 12, "head_d": 18,
	"leg_w": 4, "arm_len": 0, "arm_w": 0,
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
	var leg_x := 3.0
	var leg_z := 10.0
	return [
		{"name": "body", "parent": "", "rest": Vector3(0, 10, 0) * V, "part": "body"},
		{"name": "head", "parent": "body", "rest": Vector3(0, 4, -14) * V, "part": "head"},
		{"name": "leg_fr", "parent": "body", "rest": Vector3(leg_x, 0, -leg_z) * V, "part": "leg"},
		{"name": "leg_fl", "parent": "body", "rest": Vector3(-leg_x, 0, -leg_z) * V,
			"part": "leg", "mirror": true},
		{"name": "leg_br", "parent": "body", "rest": Vector3(leg_x, 0, leg_z) * V, "part": "leg"},
		{"name": "leg_bl", "parent": "body", "rest": Vector3(-leg_x, 0, leg_z) * V,
			"part": "leg", "mirror": true},
		{"name": "tail_1", "parent": "body", "rest": Vector3(0, 8, 14) * V, "part": "tail_1"},
		{"name": "tail_2", "parent": "tail_1", "rest": Vector3(0, 0, 8) * V, "part": "tail_2"},
		# One socket, because the rule is that sockets are not a humanoid idea.
		# A pack, a saddle, a collar: whatever the first-enemy plan wants, the
		# machinery is the same machinery.
		{"name": "back", "parent": "body", "rest": Vector3(0, 12, 0) * V, "socket": true},
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
