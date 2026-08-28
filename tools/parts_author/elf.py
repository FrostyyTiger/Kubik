"""The elf at 1/16 of a block: tall, narrow, pointed at the ears, and the
only race with a neck.

The stack, in model voxels:

    legs   [0, 24)  24
    pelvis [24, 27)  3
    torso  [27, 47) 20
    neck   [47, 50)  3   the bottom three slices of the head part
    head   [50, 72) 22
"""

from .voxlib import (split_limb, Part, gd_file, solid_eyes, hair_brow,
                     S, s, M, E, W, H, C, c, L, B, X)

HEAD_SIZE = (28, 25, 17)
HEAD_ANCHOR = (14, 0, 9)
# Head-frame geometry, for the hair file.
SKULL_X = (-8, 8)
SKULL_Y = (3, 25)
SKULL_Z = (-8, 8)
CHAMFER = 2
JAW_INSETS = (2, 1)
CROWN_INSETS = (1, 2)
BROW_Y = 17
EAR_Z = (-2, 2)
EAR_Y = (14, 22)
NECK = 3


def head() -> Part:
    p = Part("HEAD", HEAD_SIZE, HEAD_ANCHOR)
    # The neck: 8 x 8, the bottom three slices, so the head pivots at its base.
    p.box((10, 18), (0, NECK), (5, 13), S)
    p.note(0, "the neck")
    # The skull: 16 wide at columns 6..21, 22 tall, at z 1..16.
    p.prism((6, 22), (NECK, 25), (1, 17), S, chamfer=CHAMFER,
            bottom=JAW_INSETS, top=CROWN_INSETS)
    p.note(NECK, "the chin, stepped in twice")
    # Five wide, centred on the elf's face (look v2 Stage 5).
    p.front_paint(8, (11, 16), M)
    p.note(8, "the mouth")
    p.box((13, 15), (11, 14), (0, 1), S)
    p.note(11, "the nose")
    # 2 x 4 solid iris, one voxel proud, gap 6 (look v2 Stage 5); the old
    # 4 x 4 whites are cleared back to skin first.
    solid_eyes(p, 14, 13, 1, gap=6, clear=((8, 20), (13, 17), (1, 2)))
    p.note(13, "eyes, the iris rows")
    hair_brow(p, (16, 21), BROW_Y, 1)
    hair_brow(p, (7, 12), BROW_Y, 1)
    p.note(BROW_Y, "the brows")
    # THE EARS. Six out at eye level, four above that, two at the crown, four
    # deep - a blade on the side of the head, not a slab through it. Column
    # 0 is the picture's left, which is the character's right, +X.
    z0, z1 = 9 + EAR_Z[0], 9 + EAR_Z[1]
    p.box((22, 28), (14, 18), (z0, z1), S)
    p.box((0, 6), (14, 18), (z0, z1), S)
    p.box((22, 26), (18, 20), (z0, z1), S)
    p.box((2, 6), (18, 20), (z0, z1), S)
    p.box((22, 24), (20, 22), (z0, z1), S)
    p.box((4, 6), (20, 22), (z0, z1), S)
    p.note(14, "the ears, six voxels out")
    p.note(18, "the ears sweep in")
    p.note(23, "the crown, stepped in")
    return p


HEAD_COMMENT = """--- Head ---------------------------------------------------------------------

28 wide, 3 + 22 tall, 16 deep plus one for the nose. The SKULL is 16 wide and
occupies columns 6 to 21; the outer six columns on each side are ear, and
they exist only at z 7 to 10 - an ear is a flat blade on the side of a head,
not a slab through it.

The ears sweep: six voxels out at eye level, four above that, two at the
crown, nothing below. That taper is what makes them read as ears rather
than as handles, and six is the look plan's number: at 40 m the ears are
the one feature that survives when the width difference has stopped being
legible, so they are the feature that gets exaggerated.

The bottom three slices are the neck, 8 x 8, and the neck is part of the
head part rather than a bone: the head rotates about the BASE of the neck,
which is where a head-look should pivot."""


def torso() -> Part:
    p = Part("TORSO", (12, 20, 8), (6, 0, 4))
    p.box((0, 12), (0, 18), (0, 8), C)
    p.box((1, 11), (18, 19), (0, 8), C)
    p.box((2, 10), (19, 20), (1, 7), C)
    p.repaint((0, 12), (0, 2), (0, 8), B)
    p.repaint((5, 7), (0, 2), (0, 1), X)
    for y, (x0, x1) in ((19, (3, 9)), (18, (4, 8)), (17, (5, 7))):
        p.front_paint(y, (x0, x1), c)
    p.note(0, "the belt")
    p.note(2, "the tunic")
    p.note(18, "the shoulders step in")
    return p


TORSO_COMMENT = """--- Torso --------------------------------------------------------------------

12 wide, 20 tall, 8 deep. A column, against the human's 20 x 11, with the
same stepped shoulders and the same belt. The head stays a full 16 wide on
it, which makes it read as LARGE on a narrow frame rather than as merely
small."""


def pelvis() -> Part:
    p = Part("PELVIS", (12, 3, 8), (6, 0, 4))
    p.box((0, 12), (0, 3), (0, 8), c)
    return p


PELVIS_COMMENT = """--- Pelvis -------------------------------------------------------------------

12 wide, 3 tall, 8 deep. The three voxels the elf's stack does not spend on
anything else."""


def leg() -> Part:
    p = Part("LEG", (7, 24, 7), (3.5, 24, 4.5))
    p.box((1, 6), (4, 24), (2, 7), c)
    p.box((0, 7), (0, 4), (0, 7), L)
    p.note(0, "the boot")
    p.note(4, "the trouser leg, five by five")
    return p


LEG_COMMENT = """--- Leg ----------------------------------------------------------------------

5 wide, 24 tall, 5 deep - the longest legs in the game - in a 7 x 7 boot.
The anchor is the top centre of the trouser leg. `leg_w` in the race table
is 6, one more than the trouser, so the boots touch rather than overlap."""


def arm() -> Part:
    p = Part("ARM", (6, 24, 6), (3, 24, 3))
    p.box((1, 5), (16, 24), (1, 5), C)
    p.box((1, 5), (15, 16), (1, 5), c)
    p.box((1, 5), (6, 15), (1, 5), S)
    p.box((0, 6), (0, 6), (0, 6), s)
    p.note(0, "the hand, six by six")
    p.note(6, "the forearm")
    p.note(15, "the cuff")
    p.note(16, "the sleeve")
    return p


ARM_COMMENT = """--- Arm ----------------------------------------------------------------------

4 wide, 24 long, 4 deep, with a 6 x 6 hand. The thinnest arm in the game on
the longest reach; `arm_w` is the hand's 6, so the hand hangs flush with the
torso and the sleeve has a voxel of daylight at the armpit."""


DOC = """The elf: 72 voxels tall, narrow, and pointed at the ears.

THE SILHOUETTE IS "TALL AND NARROW, EARS" and every number here serves it.
The torso is 12 wide against the human's 20 and the arms are 4 against 6,
so the body is a column; the head stays a full 16 wide, which makes it read
as LARGE on a narrow frame rather than as merely small; and the ears put six
voxels of hard outline outside the skull on each side, which is the one
feature that survives at 40 m when the width difference has stopped being
legible.

THE STACK, in model voxels:

    legs   [0, 24)  24
    pelvis [24, 27)  3
    torso  [27, 47) 20
    neck   [47, 50)  3   the bottom three slices of the head part
    head   [50, 72) 22

The neck is part of the head part, not a bone: a neck bone would be a fifth
thing to pose for no gain, and putting the neck at the bottom of the head
part means the head rotates about the BASE of the neck, which is where a
head-look should pivot anyway."""


# --- Where this race's knee and elbow go -------------------------------------
#
# Character v2 Stage 4. The limb is authored full length above and cut here, so
# the drawing code never has to know where the joint is. Both splits are the
# midpoint of the author-grid limb, which is what the design doc asks for - "the
# legs are 24, and 12/12 thigh and shin"; at the author grid of 64 that is 8/8.
LEG_SPLIT = 12
ARM_SPLIT = 12


def render() -> str:
    leg_upper, leg_lower = split_limb(
        leg(), LEG_SPLIT, "LEG_UPPER", "LEG_LOWER")
    arm_upper, arm_lower = split_limb(
        arm(), ARM_SPLIT, "ARM_UPPER", "ARM_LOWER")
    parts = {
        "head": head(),
        "torso": torso(),
        "pelvis": pelvis(),
        "leg_upper": leg_upper,
        "leg_lower": leg_lower,
        "arm_upper": arm_upper,
        "arm_lower": arm_lower,
    }
    blocks = [
        parts["head"].gd("HEAD", HEAD_COMMENT),
        parts["torso"].gd("TORSO", TORSO_COMMENT),
        parts["pelvis"].gd("PELVIS", PELVIS_COMMENT),
        parts["leg_upper"].gd("LEG_UPPER", LEG_COMMENT),
        parts["leg_lower"].gd("LEG_LOWER"),
        parts["arm_upper"].gd("ARM_UPPER", ARM_COMMENT),
        parts["arm_lower"].gd("ARM_LOWER"),
    ]
    return gd_file("PartsElf", DOC, blocks, {k: k.upper() for k in parts}, "elf.py")
