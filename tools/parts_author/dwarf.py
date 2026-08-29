"""The dwarf at 1/16 of a block: as wide as it is tall, and always bearded.

The stack, in model voxels:

    legs   [0, 10)  10
    torso  [10, 28) 18
    head   [28, 48) 20
"""

from .voxlib import (split_limb, Part, json_file, solid_eyes, hair_brow, k,
                     S, s, M, E, W, H, C, c, L, B, X)

HEAD_SIZE = (20, 20, 17)
HEAD_ANCHOR = (10, 0, 9)
SKULL_X = (-10, 10)
SKULL_Y = (0, 20)
SKULL_Z = (-8, 8)
CHAMFER = 2
JAW_INSETS = (2, 1)
CROWN_INSETS = (1, 2)
BROW_Y = 13   # two rows, 13 and 14
MOUTH_Y = 4


def head() -> Part:
    p = Part("HEAD", HEAD_SIZE, HEAD_ANCHOR)
    p.prism((0, 20), (0, 20), (1, 17), S, chamfer=CHAMFER,
            bottom=JAW_INSETS, top=CROWN_INSETS)
    p.note(0, "the chin - well inside the beard")
    # Four wide; most of a dwarf's mouth is under the beard anyway.
    p.front_paint(MOUTH_Y, (8, 12), M)
    p.note(MOUTH_Y, "the mouth")
    p.box((9, 11), (7, 10), (0, 1), S)
    p.note(7, "the nose")
    solid_eyes(p, 10, 9, 1, gap=6, clear=((3, 17), (9, 13), (1, 2)))
    p.note(9, "eyes, the iris rows")
    # ONE row, not two, and in the HAIR's colour: the spec is one row for
    # every race, and two rows of shaded skin was the loudest thing on his face.
    hair_brow(p, (13, 18), BROW_Y, 1)
    hair_brow(p, (2, 7), BROW_Y, 1)
    p.note(BROW_Y, "the brows")
    p.note(18, "the crown, stepped in")
    return p


HEAD_COMMENT = """--- Head ---------------------------------------------------------------------

20 wide, 20 tall, 16 deep plus one for the nose. Wider than the human's head
and nearly as tall, on a body that is three-quarters the height - a big face
at eye level, which is what you want on the race whose face is half its
identity. The brows are two rows deep, because a dwarf's are.

The head is 42% of the total height, the most extreme proportion in the
game, and the point of the race."""


## How far the shoulders rise above the stack's torso, in author voxels. The
## dwarf's whole silhouette rule lives in this number - see below.
##
## THE STACK STAYS AT 18 AND NOT THE DESIGN DOC'S 17. The doc's dwarf is
## "total 72, legs 16, pelvis 0, torso 26, head 30". Its `legs` of 16 is not
## reachable from the author grid - the leg part is 10 author voxels, which is
## 15 - so taking `torso` to 26 would leave the stack one voxel short and
## `pelvis_height()` would hand the dwarf a ONE-VOXEL PELVIS, and with it a
## pelvis part this race has never had and does not want. 27 instead of 26 is
## two centimetres on a 1.5 m character and keeps the pelvis at zero, which is
## what "no neck, no pelvis, by construction" means for this race.
SHOULDER_RISE = 3


def torso() -> Part:
    p = Part("TORSO", (26, 18 + SHOULDER_RISE, 14), (13, 0, 7))
    p.box((0, 26), (0, 16), (0, 14), C)
    p.repaint((0, 26), (0, 2), (0, 14), B)
    p.repaint((11, 15), (0, 2), (0, 1), X)

    # THE HEAD SITS BETWEEN THE SHOULDERS, NOT ABOVE THEM, and that is the
    # whole trick of this race. A head that pokes above the shoulders reads as
    # a person; a head set INSIDE the shoulder line reads as mass. The dwarf is
    # the only race wider than the space it occupies - it fills a doorway - and
    # it is not a short human, because a short human is a child and no part of
    # this may read as one.
    #
    # So instead of the human's ziggurat, where the torso steps IN toward the
    # neck, the dwarf's shoulders carry straight up past the point where the
    # head bone sits, and the neck opening is cut out of them. Three author
    # voxels of rise, recorded as `torso_rise` in races.gd so the bone table
    # and the self-test both know this part is taller than its slice of the
    # stack.
    top = 18 + SHOULDER_RISE
    p.box((0, 26), (16, top), (0, 14), C)
    for y in range(16, top):
        for z in range(3, 11):
            for x in range(9, 17):
                p.erase(x, y, z)
    # Inked around the opening, so the shoulders read as two masses with a gap
    # rather than as one slab with a hole in it.
    p.box((8, 18), (top - 1, top), (2, 12), k)
    p.repaint((0, 26), (15, 16), (0, 14), k)

    for y, (x0, x1) in ((15, (11, 15)), (14, (12, 14))):
        p.front_paint(y, (x0, x1), c)
    p.note(0, "the belt, buckle on the front")
    p.note(2, "the tunic")
    p.note(15, "the liner, under the shoulder line")
    p.note(16, "the shoulders carry on up, and the head sits between them")
    return p


TORSO_COMMENT = """--- Torso --------------------------------------------------------------------

26 wide, 18 tall, 14 deep. A barrel, with the shoulders stepped in at the
top. This is where "as wide as it is tall" comes from, before the arms are
even attached: 26 across the chest, 46 across the hands, on a character 48
tall."""


def leg() -> Part:
    p = Part("LEG", (10, 10, 10), (5, 10, 6))
    p.box((1, 9), (4, 10), (2, 10), c)
    # The liner at the boot top - one of the four places the design doc
    # names where cloth meets skin or leather: collar, cuff, waist, boot.
    p.box((0, 10), (0, 4), (0, 10), L)
    p.box((0, 10), (4, 5), (0, 10), k)
    p.note(0, "the boot, ten wide and ten deep")
    p.note(4, "the trouser leg, eight by eight")
    return p


LEG_COMMENT = """--- Leg ----------------------------------------------------------------------

8 wide, 10 tall, 8 deep, in a 10 x 10 boot. The shortest legs in the game,
and nearly half of each is boot - which is why the dwarf's stride is short
and quick out of the same one-line scale every other race uses."""


def arm() -> Part:
    p = Part("ARM", (10, 16, 10), (5, 16, 5))
    # The cuff is the LINER now, and it lands on ARM_SPLIT, which is where
    # the elbow is - so the joint is inked by the row the design wanted
    # there anyway. Two ideas, one voxel. See human.py.
    p.box((1, 9), (9, 16), (1, 9), C)
    p.box((1, 9), (8, 9), (1, 9), k)
    p.box((1, 9), (6, 8), (1, 9), S)
    p.box((0, 10), (0, 6), (0, 10), s)
    p.note(0, "the hand, ten by ten")
    p.note(6, "the forearm")
    p.note(8, "the liner cuff, on the elbow")
    p.note(9, "the sleeve")
    return p


ARM_COMMENT = """--- Arm ----------------------------------------------------------------------

8 wide, 16 long, 8 deep, with a 10 x 10 hand. Thick, and hung off a 26-wide
torso, which puts the outside of the hand 23 voxels from the centre line -
1.44 m across."""


DOC = """The dwarf: 48 voxels tall and 46 wide across the hands.

THE SILHOUETTE IS "AS WIDE AS IT IS TALL, BEARD". At 1.50 m tall and 1.44 m
across the hands it is the only character in the game whose outline is
wider than a door, and that alone separates it from the human at any
distance. The beard is the second half and it is not optional: the dwarf's
beard picker has three entries and none of them is "none", because a
beardless dwarf at 40 m is a short human.

THE STACK, in model voxels:

    legs   [0, 10)  10
    torso  [10, 28) 18
    head   [28, 48) 20

No pelvis - the stack leaves no room and `hips` is a pure transform with the
belt socket on it."""


# --- Where this race's knee and elbow go -------------------------------------
#
# Character v2 Stage 4. The limb is authored full length above and cut here, so
# the drawing code never has to know where the joint is. Both splits are the
# midpoint of the author-grid limb, which is what the design doc asks for - "the
# legs are 24, and 12/12 thigh and shin"; at the author grid of 64 that is 8/8.
LEG_SPLIT = 5
ARM_SPLIT = 8


def render() -> str:
    leg_upper, leg_lower = split_limb(
        leg(), LEG_SPLIT, "LEG_UPPER", "LEG_LOWER")
    arm_upper, arm_lower = split_limb(
        arm(), ARM_SPLIT, "ARM_UPPER", "ARM_LOWER")
    parts = {
        "head": head(),
        "torso": torso(),
        "leg_upper": leg_upper,
        "leg_lower": leg_lower,
        "arm_upper": arm_upper,
        "arm_lower": arm_lower,
    }
    comments = {"head": HEAD_COMMENT, "torso": TORSO_COMMENT,
                "leg_upper": LEG_COMMENT, "arm_upper": ARM_COMMENT}
    return json_file("dwarf.py", DOC, parts, comments)
