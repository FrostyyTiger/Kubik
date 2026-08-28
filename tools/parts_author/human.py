"""The stocky human at 1/16 of a block. The reference the other races are
separated from: square stepped shoulders, a head a third of the height,
big hands, big boots, no neck.

Numbers are the look plan's Stage 6 table. The stack, in model voxels:

    legs   [0, 16)  16
    pelvis [16, 22)  6
    torso  [22, 42) 20
    head   [42, 64) 22
"""

from .voxlib import (split_limb, Part, gd_file, solid_eyes, hair_brow,
                     S, s, M, E, W, H, C, c, L, B, X)

# --- Geometry the hair file needs to know ------------------------------------

HEAD_SIZE = (18, 22, 17)
HEAD_ANCHOR = (9, 0, 9)
# In head-frame coordinates: the skull box, its plan chamfer, and the rows
# that are stepped in at the jaw and the crown.
SKULL_X = (-9, 9)
SKULL_Y = (0, 22)
SKULL_Z = (-8, 8)
CHAMFER = 2
JAW_INSETS = (2, 1)    # y = 0 inset 2, y = 1 inset 1
CROWN_INSETS = (1, 2)  # y = 20 inset 1, y = 21 inset 2
BROW_Y = 14            # the brow row; a fringe stops just above it
MOUTH_Y = 5


def head() -> Part:
    p = Part("HEAD", HEAD_SIZE, HEAD_ANCHOR)
    # The skull: 18 x 22 x 16 at z 1..16, so the nose can sit at z = 0.
    p.prism((0, 18), (0, 22), (1, 17), S, chamfer=CHAMFER,
            bottom=JAW_INSETS, top=CROWN_INSETS)
    p.note(0, "the chin, stepped in twice")
    p.note(2, "the jaw at full width")
    # Mouth: FIVE wide, not eight (look v2 Stage 5). An eight-wide mouth on an
    # eighteen-wide head is a grin; five is a line, and a line is what a poster
    # prints.
    p.front_paint(MOUTH_Y, (7, 12), M)
    p.note(MOUTH_Y, "the mouth")
    # Nose: 2 wide, 3 tall, one voxel proud of the face.
    p.box((8, 10), (8, 11), (0, 1), S)
    p.note(8, "the nose - the only slices with anything at z = 0")
    # Eyes: 2 x 4 solid iris, one voxel proud, gap 6 (look v2 Stage 5). The
    # old 4 x 4 white with a 2 x 2 iris inside it is cleared back to skin
    # first.
    solid_eyes(p, 9, 10, 1, gap=6, clear=((3, 15), (10, 14), (1, 2)))
    p.note(10, "eyes, the iris rows")
    p.note(12, "eyes, the upper rows")
    # Brow: one row in the HAIR's colour over each eye, one voxel wider
    # outboard. Shaded skin was a smudge past arm's length.
    hair_brow(p, (11, 16), BROW_Y, 1)
    hair_brow(p, (2, 7), BROW_Y, 1)
    p.note(BROW_Y, "the brows")
    p.note(20, "the crown, stepped in")
    return p


HEAD_COMMENT = """--- Head ---------------------------------------------------------------------

18 wide, 22 tall, 16 deep PLUS ONE for the nose. The skull occupies z 1..16
and the anchor sits at its centre, z = 9, not at the middle of the
seventeen.

THE HEAD IS A THIRD OF THE CHARACTER. 22 of 64 voxels, which is the Cube
World read the look plan asks for, kept on the stocky side of it. The
vertical edges are chamfered two voxels so the head is an octagon from
above, and the jaw and the crown step in - rule 4 of the look plan: forms are
stepped and chamfered, never rounded.

THE FACE IS THE WHOLE POINT OF THE FINER VOXEL. Two 4 x 4 eyes, each a white
with a 2 x 2 iris set low and inboard so the character looks at you rather
than past you; a one-row brow over each; a 2 x 3 nose one voxel proud; an
8-wide mouth. At the game's 75 degree FOV on a 720-line viewport a 4 x 4 eye
is about five pixels across at 15 m, which is a face and not a smudge."""


def torso() -> Part:
    p = Part("TORSO", (20, 20, 11), (10, 0, 5.5))
    p.box((0, 20), (0, 18), (0, 11), C)
    # The shoulders step in: one voxel at y = 18, two at y = 19.
    p.box((1, 19), (18, 19), (0, 11), C)
    p.box((2, 18), (19, 20), (1, 10), C)
    # Belt on the bottom two rows, buckle on the front.
    p.repaint((0, 20), (0, 2), (0, 11), B)
    p.repaint((8, 12), (0, 2), (0, 1), X)
    # A stepped V collar on the front face - the one line of Deco on a tunic.
    for y, (x0, x1) in ((19, (6, 14)), (18, (7, 13)), (17, (8, 12)), (16, (9, 11))):
        p.front_paint(y, (x0, x1), c)
    p.note(0, "the belt, buckle on the front")
    p.note(2, "the tunic")
    p.note(16, "the collar begins")
    p.note(18, "the shoulders step in")
    return p


TORSO_COMMENT = """--- Torso --------------------------------------------------------------------

20 wide, 20 tall, 11 deep. Square shoulders - that IS the human silhouette,
and it is the reference every other race is separated from - but STEPPED:
the top two rows inset by one and then two, so the shoulder is a ziggurat
profile and not a box. Belt on the bottom two rows with a buckle, and a
stepped V collar on the front, which is the one piece of ornament a tunic
gets.

The outfit is baked in rather than being a separate part, because the torso
slot belongs to the gear plan and v1 has one outfit per race."""


def pelvis() -> Part:
    p = Part("PELVIS", (20, 6, 11), (10, 0, 5.5))
    p.box((0, 20), (0, 6), (0, 11), c)
    return p


PELVIS_COMMENT = """--- Pelvis -------------------------------------------------------------------

20 wide, 6 tall, 11 deep, in trousers. `hips` is the root of the rig and
every bone must have a part; this is its part, and it is where the stack's
six spare voxels go. See the note in races.gd."""


def leg() -> Part:
    p = Part("LEG", (9, 16, 9), (4.5, 16, 5.5))
    # Trouser leg: 7 x 7, centred, from the boot top to the hip.
    p.box((1, 8), (4, 16), (2, 9), c)
    # Boot: one voxel wider each side, two deeper at the toe, four tall.
    p.box((0, 9), (0, 4), (0, 9), L)
    p.note(0, "the boot, nine wide and nine deep")
    p.note(4, "the trouser leg, seven by seven")
    return p


LEG_COMMENT = """--- Leg ----------------------------------------------------------------------

7 wide, 16 tall, 7 deep, in a 9 x 9 boot that is one voxel wider on each
side and two deeper at the toe. Authored ONCE, for the right leg; the left
is this mirrored, which is why the two can never drift apart.

The anchor is the TOP centre of the trouser leg, `(4.5, 16, 5.5)`, because a
leg swings from the hip and not from the ankle. The race table's `leg_w` is
8, one more than the trouser, so the two boots touch at the centre line
instead of sharing a voxel."""


def arm() -> Part:
    p = Part("ARM", (8, 20, 8), (4, 20, 4))
    # Sleeve, cuff, forearm: a 6 x 6 column.
    p.box((1, 7), (13, 20), (1, 7), C)
    p.box((1, 7), (12, 13), (1, 7), c)
    p.box((1, 7), (6, 12), (1, 7), S)
    # The hand: one voxel wider all round, six tall, shaded so the wrist reads.
    p.box((0, 8), (0, 6), (0, 8), s)
    p.note(0, "the hand, eight by eight")
    p.note(6, "the forearm")
    p.note(12, "the cuff")
    p.note(13, "the sleeve")
    return p


ARM_COMMENT = """--- Arm ----------------------------------------------------------------------

6 wide, 20 long, 6 deep, hanging from the shoulder, with an 8 x 8 hand on the
bottom six rows - one voxel wider all round than the sleeve, which is what
makes a hand read as a hand at 15 m. Sleeve on the top seven, a dark cuff,
bare forearm, and the hand in shaded skin so there is a visible wrist on a
limb that is otherwise one column. Authored for the right arm and mirrored
for the left.

The race table's `arm_w` is 8 - the hand's width, not the sleeve's - so the
arm hangs with the hand flush against the torso and a voxel of daylight at
the armpit."""


DOC = """The stocky human, voxel by voxel, at 1/16 of a block.

Read VoxelModel's class docstring before editing anything here. In short:
slices run bottom to top, rows inside a slice run front (-Z) to back, and
the first character of a row is the left of the picture as you look at the
character's face. Every character is a slot, never a colour.

THE STACK, from the race table, in model voxels:

    legs   [0, 16)  16   boots at the bottom, trousers above
    pelvis [16, 22)  6   the six voxels the stack does not otherwise spend
    torso  [22, 42) 20   tunic, belt on its bottom rows
    head   [42, 64) 22   eyes at 52-55, which is 1.68 m

The arms hang from a shoulder at 41 and are 20 long, so the hands finish at
the hips. Nothing here is a number `player.gd` may read - hard rule 3.

THIS IS THE REFERENCE. Square stepped shoulders, a head a third of the
height, big hands and boots, no neck: the look plan's "stocky", and the
shape every other race is measured against in the silhouette sheets."""


# --- Where this race's knee and elbow go -------------------------------------
#
# Character v2 Stage 4. The limb is authored full length above and cut here, so
# the drawing code never has to know where the joint is. Both splits are the
# midpoint of the author-grid limb, which is what the design doc asks for - "the
# legs are 24, and 12/12 thigh and shin"; at the author grid of 64 that is 8/8.
LEG_SPLIT = 8
ARM_SPLIT = 10


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
    return gd_file("PartsHuman", DOC, blocks,
                   {k: k.upper() for k in parts}, "human.py")
