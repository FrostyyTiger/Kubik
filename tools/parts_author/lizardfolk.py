"""The lizardfolk at 1/16 of a block: a snout in front, a tail behind, and
leaning eight degrees into both.

The stack, in model voxels:

    legs   [0, 18)  18
    pelvis [18, 22)  4
    torso  [22, 42) 20
    head   [42, 60) 18
"""

from .voxlib import (Part, gd_file, solid_eyes,
                     S, s, M, E, W, C, c, B, X, T)

HEAD_SIZE = (16, 18, 24)
HEAD_ANCHOR = (8, 0, 16)
SKULL_X = (-8, 8)
SKULL_Y = (0, 18)
SKULL_Z = (-8, 8)
SNOUT_Z = (-16, -8)
CHAMFER = 2
JAW_INSETS = (1,)
CROWN_INSETS = (1, 2)


def head() -> Part:
    p = Part("HEAD", HEAD_SIZE, HEAD_ANCHOR)
    # The skull, at z 8..23.
    p.prism((0, 16), (0, 18), (8, 24), S, chamfer=CHAMFER,
            bottom=JAW_INSETS, top=CROWN_INSETS)
    p.note(0, "the underside of the jaw")
    # The snout: 8 wide, 8 tall, 8 long, in front of the skull, its own
    # vertical edges chamfered one.
    p.prism((4, 12), (4, 12), (0, 8), S, chamfer=1)
    p.note(4, "the snout begins - and its teeth")
    # Teeth: the front two rows of the snout's bottom slice.
    p.repaint((4, 12), (4, 5), (0, 2), T)
    # The mouth: a line round the snout at y = 6.
    p.front_paint(6, (4, 12), M, zr=(0, 8))
    p.repaint((4, 5), (6, 7), (1, 8), M)
    p.repaint((11, 12), (6, 7), (1, 8), M)
    p.note(6, "the mouth line, round the snout")
    # Nostrils on the top of the snout.
    p.repaint((5, 7), (11, 12), (0, 1), s)
    p.repaint((9, 11), (11, 12), (0, 1), s)
    p.note(11, "the top of the snout, with nostrils")
    # Eyes on the front of the SKULL, above the snout: 2 x 4 solid iris, one
    # voxel proud, gap 6, exactly as the other three (look v2 Stage 5). Low z
    # is the front here as everywhere, so proud is z = 7.
    solid_eyes(p, 8, 12, 8, gap=6, clear=((2, 14), (12, 16), (8, 9)))
    p.note(12, "eyes on the front of the skull, above the snout")
    # NO HAIR BROW. The lizardfolk has no hair over the brow - the crest is its
    # hair - so the spec's "one row of H, or none" is none, and the brow ridge
    # stays the shaded skin it has always been.
    p.repaint((10, 15), (16, 17), (8, 9), s)
    p.repaint((1, 6), (16, 17), (8, 9), s)
    p.note(16, "the brow ridge, and the crown")
    return p


HEAD_COMMENT = """--- Head ---------------------------------------------------------------------

16 wide, 18 tall, and 24 DEEP: a 16-deep skull at z 8 to 23 with an 8-voxel
snout in front of it at z 0 to 7. The snout is eight wide and eight tall,
not sixteen, so the head reads as a wedge from above and as a muzzle from
the side, and its own edges are chamfered so it is a stepped block rather
than a box.

The eyes sit on the front of the SKULL at z = 8, above the snout, which is
where a reptile's are. Teeth on the underside of the snout in the `T` slot,
a mouth line the whole way round it, and nostrils on top."""


def torso() -> Part:
    p = Part("TORSO", (20, 20, 11), (10, 0, 5.5))
    p.box((0, 20), (0, 18), (0, 11), C)
    p.box((1, 19), (18, 19), (0, 11), C)
    p.box((2, 18), (19, 20), (1, 10), C)
    p.repaint((0, 20), (0, 2), (0, 11), B)
    p.repaint((8, 12), (0, 2), (0, 1), X)
    # A sash from the right shoulder to the left hip, instead of a collar.
    for y in range(2, 18):
        x = 4 + (y - 2) * 12 // 16
        p.front_paint(y, (x, x + 3), c)
    p.note(0, "the belt, buckle on the front")
    p.note(2, "the tunic, with a sash across it")
    p.note(18, "the shoulders step in")
    return p


TORSO_COMMENT = """--- Torso --------------------------------------------------------------------

20 wide, 20 tall, 11 deep - THE HUMAN'S TORSO, stepped shoulders and all,
with a sash across the front instead of a collar. Deliberate: if the
lizardfolk had a distinct build as well as a snout, a crest and a tail, the
silhouette test would not be able to tell which feature was doing the
work."""


def pelvis() -> Part:
    p = Part("PELVIS", (20, 4, 11), (10, 0, 5.5))
    p.box((0, 20), (0, 4), (0, 11), c)
    return p


PELVIS_COMMENT = """--- Pelvis -------------------------------------------------------------------

20 wide, 4 tall, 11 deep. The tail's first link hangs off the back of it."""


def leg() -> Part:
    p = Part("LEG", (7, 18, 9), (3.5, 18, 5.5))
    p.box((0, 7), (6, 18), (2, 9), c)
    p.box((0, 7), (2, 6), (2, 9), S)
    p.box((0, 7), (0, 2), (0, 9), S)
    for x in (0, 3, 6):
        p.put(x, 0, 0, T)
    p.note(0, "the foot, bare, with claws at the toes")
    p.note(2, "the shin")
    p.note(6, "the trouser leg")
    return p


LEG_COMMENT = """--- Leg ----------------------------------------------------------------------

7 wide, 18 tall, 7 deep with a foot two voxels longer at the toe. Barefoot,
with three claws at the toes - the one race that does not wear boots. Its
`leg_w` is the human's 8 so the two feet touch rather than overlap."""


def arm() -> Part:
    p = Part("ARM", (8, 20, 8), (4, 20, 4))
    p.box((1, 7), (13, 20), (1, 7), C)
    p.box((1, 7), (12, 13), (1, 7), c)
    p.box((1, 7), (6, 12), (1, 7), S)
    p.box((0, 8), (0, 6), (0, 8), s)
    for x in (1, 4, 6):
        p.put(x, 0, 0, T)
    p.note(0, "the hand, with claws")
    p.note(6, "the forearm")
    p.note(13, "the sleeve")
    return p


ARM_COMMENT = """--- Arm ----------------------------------------------------------------------

The human's arm, with claws on the fingertips."""


def tail(name: str, size, anchor, shade_from: int | None) -> Part:
    p = Part(name, size, anchor)
    w, h, d = size
    p.box((0, w), (0, h), (0, d), S)
    if shade_from is not None:
        p.repaint((0, w), (0, h), (shade_from, d), s)
    return p


TAIL_COMMENT = """--- Tail ---------------------------------------------------------------------

Three segments, 10 + 10 + 8 = 28 voxels, tapering: 6 x 6, then 4 x 4, then
4 x 4 with a shaded tip. Each is anchored at its FRONT face so it grows
backward along +Z from the bone that carries it, and each bone's rest
offset is the previous segment's length - so the chain is continuous by
construction rather than by three numbers agreeing. The thinner links are
anchored a voxel up so they sit on the centre line of the thick one.

The animator finds these by name alone (`tail_1..n`) and knows nothing
about lizards. The critter uses the same rule."""


DOC = """The lizardfolk: a snout in front, a tail behind, and leaning eight degrees
into both.

THE SILHOUETTE IS "TAIL, CREST, SNOUT" and it is the only one of the four
that is made of things sticking OUT rather than of overall proportion. The
body is the human's - same 20 x 11 torso, same 20-voxel arms - which is
deliberate: if the lizardfolk had a distinct build as well, the silhouette
test would not be able to tell which feature was doing the work.

THE STACK, in model voxels:

    legs   [0, 18)  18
    pelvis [18, 22)  4
    torso  [22, 42) 20
    head   [42, 60) 18

The 8 degree forward lean is baked into the HIPS REST POSE (see Rig.build),
not applied by the animator, so it survives every pose and the animator
never learns that one race stands differently from the others."""


def render() -> str:
    parts = {
        "head": head(),
        "torso": torso(),
        "pelvis": pelvis(),
        "leg": leg(),
        "arm": arm(),
        "tail_1": tail("TAIL_1", (6, 6, 10), (3, 0, 0), None),
        "tail_2": tail("TAIL_2", (4, 4, 10), (2, -1, 0), None),
        "tail_3": tail("TAIL_3", (4, 4, 8), (2, -1, 0), 5),
    }
    blocks = [
        parts["head"].gd("HEAD", HEAD_COMMENT),
        parts["torso"].gd("TORSO", TORSO_COMMENT),
        parts["pelvis"].gd("PELVIS", PELVIS_COMMENT),
        parts["leg"].gd("LEG", LEG_COMMENT),
        parts["arm"].gd("ARM", ARM_COMMENT),
        parts["tail_1"].gd("TAIL_1", TAIL_COMMENT),
        parts["tail_2"].gd("TAIL_2"),
        parts["tail_3"].gd("TAIL_3"),
    ]
    return gd_file("PartsLizardfolk", DOC, blocks,
                   {k: k.upper() for k in parts}, "lizardfolk.py")
