"""The critter, scaled exactly x2 from the character v1 ASCII.

It is a test rig, not a character: it exists to fail loudly if anything in
the pipeline is secretly humanoid, and the only thing that matters about
its shape is that it is the same shape it was. So the v1 ASCII is embedded
here as data and every voxel becomes eight, which is the one transformation
that provably changes nothing about it.
"""

from .voxlib import Part

# The character v1 parts, verbatim, at 1/8 of a block.
V1 = {
    "BODY": ((6, 6, 14), (3, 0, 7), [
        ["......", "SSSSSS", "SSSSSS", "SSSSSS", "SSSSSS", "SSSSSS", "SSSSSS",
         "SSSSSS", "SSSSSS", "SSSSSS", "SSSSSS", "SSSSSS", "SSSSSS", "......"],
        ["SSSSSS"] * 14,
        ["SSSSSS"] * 14,
        ["SSSSSS"] * 14,
        ["SSSSSS"] * 14,
        ["......", "SSSSSS", "SSSSSS", "SSSSSS", "SSSSSS", "SSSSSS", "SSSSSS",
         "SSSSSS", "SSSSSS", "SSSSSS", "SSSSSS", "SSSSSS", "SSSSSS", "......"],
    ]),
    "HEAD": ((6, 6, 9), (3, 0, 9), [
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
    ]),
    "LEG": ((2, 5, 2), (1, 5, 1), [
        ["TT", "SS"],
        ["SS", "SS"],
        ["SS", "SS"],
        ["SS", "SS"],
        ["SS", "SS"],
    ]),
    "TAIL_1": ((2, 2, 4), (1, 0, 0), [
        ["SS", "SS", "SS", "SS"],
        ["SS", "SS", "SS", "SS"],
    ]),
    "TAIL_2": ((2, 2, 3), (1, 0, 0), [
        ["SS", "ss", "ss"],
        ["SS", "ss", "ss"],
    ]),
}


def scaled(name: str) -> Part:
    (w, h, d), (ax, ay, az), slices = V1[name]
    p = Part(name, (w * 2, h * 2, d * 2), (ax * 2, ay * 2, az * 2))
    for y, rows in enumerate(slices):
        for z, row in enumerate(rows):
            for col, ch in enumerate(row):
                if ch == ".":
                    continue
                x = w - 1 - col
                for dx in (0, 1):
                    for dy in (0, 1):
                        for dz in (0, 1):
                            p.put(x * 2 + dx, y * 2 + dy, z * 2 + dz, ch)
    return p


DOC = """A four-legged thing the size of a large dog.

IT EXISTS TO FAIL LOUDLY IF ANY OF THIS IS SECRETLY HUMANOID. It has no
`torso`, no `hips`, no arms and four legs, so every place in the pipeline
that quietly assumed a two-legged skeleton - the mesher, the rig, the chain
rule, the animator - either works on it or does not. Nothing else in this
plan could have found those assumptions, because everything else in this
plan is a person.

GALLERY ONLY. No AI, no scene, no spawning, no CharacterDef. It is a model
that walks in a strip, and it is what the first-enemy plan starts from.

Shoulder height is 22 voxels, 0.69 m, which is a big dog. The body is
twenty-eight voxels long, so it is longer than it is tall by two to one -
the proportion that makes a quadruped read as a quadruped rather than as a
person on all fours.

SCALED EXACTLY x2 FROM CHARACTER V1 when the model voxel halved. It is a
test rig, and the only thing that matters about its shape is that it is the
same shape it was - so every v1 voxel became eight and nothing else
changed. It has no chamfers and no Deco; the first-enemy plan draws the
first real animal."""

BODY_COMMENT = """--- Body ---------------------------------------------------------------------

12 wide, 12 tall, 28 long. The anchor is at the middle of its length and the
bottom of its height, so the four leg sockets hang from it symmetrically and
the whole animal sits on top of its legs."""

HEAD_COMMENT = """--- Head ---------------------------------------------------------------------

12 wide, 12 tall, 12 of skull plus 6 of snout. The anchor is at the BACK of
the head - z 18 - so the head grows forward from the neck joint, which is
where a quadruped's head hangs from."""

LEG_COMMENT = """--- Leg ----------------------------------------------------------------------

4 x 10 x 4, anchored at the TOP so it swings from the shoulder, exactly as a
humanoid leg does. Authored once and used four times: the gait table decides
which of them are in phase, not the geometry."""

TAIL_COMMENT = """--- Tail ---------------------------------------------------------------------

Two segments on the SAME generic chain rule the lizardfolk uses. That is half
the point of building this animal: if the chain rule had quietly assumed
three links or a humanoid parent, this is where it would show."""

EXTRA = """## Model voxels, for the tables below.
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
	}"""


def render() -> str:
    from .voxlib import gd_file
    blocks = [
        scaled("BODY").gd("BODY", BODY_COMMENT),
        scaled("HEAD").gd("HEAD", HEAD_COMMENT),
        scaled("LEG").gd("LEG", LEG_COMMENT),
        scaled("TAIL_1").gd("TAIL_1", TAIL_COMMENT),
        scaled("TAIL_2").gd("TAIL_2"),
    ]
    parts = {"body": "BODY", "head": "HEAD", "leg": "LEG", "tail_1": "TAIL_1", "tail_2": "TAIL_2"}
    return gd_file("PartsCritter", DOC, blocks, parts, "critter.py", extra=EXTRA)
