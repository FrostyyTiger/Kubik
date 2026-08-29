"""The stocky human at 1/16 of a block. The reference the other races are
separated from: square stepped shoulders, a head a third of the height,
big hands, big boots, no neck.

Numbers are the look plan's Stage 6 table. The stack, in model voxels:

    legs   [0, 16)  16
    pelvis [16, 22)  6
    torso  [22, 42) 20
    head   [42, 64) 22
"""

from .voxlib import (split_limb, Part, gd_file, solid_eyes, hair_brow, k,
                     S, s, M, E, W, H, C, c, L, B, X)

# --- Geometry the hair file needs to know ------------------------------------

HEAD_SIZE = (18, 21, 17)
HEAD_ANCHOR = (9, 0, 9)
# In head-frame coordinates: the skull box, its plan chamfer, and the rows
# that are stepped in at the jaw and the crown.
SKULL_X = (-9, 9)
SKULL_Y = (0, 21)
SKULL_Z = (-8, 8)
CHAMFER = 2
JAW_INSETS = (2, 1)    # y = 0 inset 2, y = 1 inset 1
CROWN_INSETS = (1, 2)  # y = 20 inset 1, y = 21 inset 2
BROW_Y = 14            # the brow row; a fringe stops just above it
MOUTH_Y = 5


def head() -> Part:
    p = Part("HEAD", HEAD_SIZE, HEAD_ANCHOR)
    # The skull: 18 x 22 x 16 at z 1..16, so the nose can sit at z = 0.
    p.prism((0, 18), (0, 21), (1, 17), S, chamfer=CHAMFER,
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
    p.note(19, "the crown, stepped in")
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

    # THE LINER, character v2 Stage 1's slot arriving as geometry. One row of
    # near-black wherever cloth meets skin - here the collar, where the neck
    # comes out. The contrast pair that has to hold is skin against THIS, and
    # it holds at 6:1 for every skin in the game, which is what released the
    # tunic from having to be black. See the liner note in races.gd.
    p.box((5, 15), (19, 20), (0, 11), k)
    p.repaint((6, 14), (19, 20), (0, 11), k)

    # THE BALDRIC - the human's one big idea, and the only diagonal in the
    # game. Nothing a human wears was made for a human: it was acquired,
    # traded for and adjusted, so the signature is straps. A diagonal is a
    # handful of voxels across the biggest flat surface the character has, it
    # is asymmetric for free, and it breaks the torso rectangle at the exact
    # point where a rectangle is least forgiving. It survives every armour
    # tier, because a strap goes OVER armour.
    #
    # Left shoulder to right hip. `x` is the character's own right, so it runs
    # from low x at the top to high x at the bottom - and it is drawn on the
    # front face and the two voxels behind it, so it reads at any angle rather
    # than vanishing in three-quarter view.
    _strap(p, (3, 17), (16, 3), width=3, ch=L, edge=k)

    # THE HOOD, LIVING DOWN. Bunched at the back of the neck - the cheapest way
    # to say "traveller" ever invented, and it costs two boxes.
    #
    # THE DESIGN DOC ASKS FOR IT TO RAISE THE SHOULDER LINE BY THREE VOXELS AND
    # IT DOES NOT, because a torso part taller than the table's `torso` would
    # fail `parts match the table` and would poke into the head bone's own
    # space. What it does instead is thicken the upper back by three voxels of
    # depth, which is the same idea seen from the side and is where a bunched
    # hood actually sits. Raising the line properly wants the hood as its own
    # part on the `back` socket, which is Stage 8's slot and Stage 8's problem.
    p.box((5, 15), (15, 20), (8, 11), c)
    p.box((6, 14), (17, 20), (8, 11), k)

    # The belt hangs past the hip ON ONE SIDE. Asymmetry is free and it is the
    # difference between kit that was issued and kit that was lived in.
    p.box((14, 18), (0, 2), (0, 11), B)
    p.box((15, 17), (-0, 0), (0, 11), B)

    p.note(0, "the belt, buckle on the front")
    p.note(2, "the tunic")
    p.note(16, "the collar begins")
    p.note(18, "the shoulders step in, and the hood bunches behind")
    p.note(19, "the liner at the collar")
    return p


def _strap(p, top, bottom, width: int, ch: str, edge: str) -> None:
    """A diagonal band across the front of a torso, inked along one edge.

    THE ONLY DIAGONAL IN THE GAME. Every other line on every other race is
    vertical or horizontal, which is what makes this one the human's name at
    15 m - and it is drawn rather than modelled, because with flat vertex
    colour a painted band and a raised one read the same at any distance a
    silhouette is judged at, and a painted one cannot clip through armour.

    Drawn on the front three slices so it survives a three-quarter view; the
    `edge` row under it is the liner, which is what stops leather-on-cloth
    dissolving when the two are close in value.
    """
    (x0, y0), (x1, y1) = top, bottom
    steps = max(abs(x1 - x0), abs(y1 - y0))
    for i in range(steps + 1):
        f = i / steps
        x = round(x0 + (x1 - x0) * f)
        y = round(y0 + (y1 - y0) * f)
        for dx in range(width):
            p.repaint((x + dx, x + dx + 1), (y, y + 1), (0, 3), ch)
        p.repaint((x + width, x + width + 1), (y, y + 1), (0, 3), edge)


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
    # And the liner at the boot top, which is the third of the four places the
    # design doc names: collar, cuff, waist, boot top.
    p.box((0, 9), (4, 5), (0, 9), k)
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
    # ROLLED SLEEVES, so the forearm is skin and the upper arm is cloth - and
    # the boundary between them lands on ARM_SPLIT, which is where the elbow
    # now is. That puts a liner ring exactly at the joint and makes the joint
    # legible for free: the crease the split already cuts is inked by the same
    # row that the design asks for anyway. Two ideas, one voxel.
    p.box((1, 7), (11, 20), (1, 7), C)
    p.box((1, 7), (10, 11), (1, 7), k)
    p.box((1, 7), (6, 10), (1, 7), S)
    # The hand: one voxel wider all round, six tall, shaded so the wrist reads.
    p.box((0, 8), (0, 6), (0, 8), s)
    p.note(0, "the hand, eight by eight")
    p.note(6, "the forearm")
    p.note(10, "the liner cuff, on the elbow")
    p.note(11, "the sleeve")
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
