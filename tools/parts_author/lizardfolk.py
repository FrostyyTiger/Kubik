"""The lizardfolk at 1/16 of a block: a snout in front, a tail behind, and
leaning eight degrees into both.

The stack, in model voxels:

    legs   [0, 18)  18
    pelvis [18, 22)  4
    torso  [22, 42) 20
    head   [42, 60) 18
"""

from .voxlib import (split_limb, Part, gd_file, json_file, solid_eyes, k, v,
                     S, s, M, E, W, C, c, B, X, T)

HEAD_SIZE = (16, 16, 24)
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
    p.prism((0, 16), (0, 16), (8, 24), S, chamfer=CHAMFER,
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
    # GAP 8, NOT 6, AND THE REASON IS THE GRID MAP rather than the face.
    #
    # An author voxel becomes a span of one or two output voxels, alternately.
    # A mirrored pair of features therefore only stays mirrored if the pair is
    # chosen so that its SCALED spans mirror - which is a stricter condition
    # than being symmetric in author space. At gap 6 the eyes sit at author
    # x 3..5 and 11..13, an exact mirror about the head's centre of 8, and they
    # scale to [5, 8) and [17, 20) in a 24-wide head: the mirror of [5, 8) is
    # [16, 19), so the face acquired a half-voxel squint. The eyes-forward test
    # caught it at 0.9988 against its 0.999 threshold.
    #
    # At gap 8 they sit at 2..4 and 12..14, which scale to [3, 6) and [18, 21).
    # The mirror of [3, 6) about 24 is [18, 21). Exactly.
    #
    # This is the same sharp edge that took the catchlight out in Stage 3, and
    # it is worth stating as a rule: at a non-integer change of grid, check a
    # mirrored feature's SPANS and not its coordinates. The test is the check.
    solid_eyes(p, 8, 10, 8, gap=8, height=3, clear=((2, 14), (10, 14), (8, 9)))
    p.note(10, "eyes on the front of the skull, above the snout")
    # NO HAIR BROW. The lizardfolk has no hair over the brow - the crest is its
    # hair - so the spec's "one row of H, or none" is none, and the brow ridge
    # stays the shaded skin it has always been.
    p.repaint((10, 15), (14, 15), (8, 9), s)
    p.repaint((1, 6), (14, 15), (8, 9), s)
    p.note(14, "the brow ridge, and the crown")
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
    # FOURTEEN WIDE, NOT TWENTY, and this single number is the whole of what
    # was wrong with this race for three passes.
    #
    # Until character v2 Stage 6 the lizardfolk's torso WAS the human's torso -
    # same 20 x 11, same stepped shoulders - deliberately, so the silhouette
    # test could tell which of its features was doing the work. It answered:
    # none of them could, because the mask is dominated by an identical torso
    # and identical legs. Front on the pair measured 0.913 on the GPU, and
    # 0.759 even three-quarter, which is the view the v1 status doc offered as
    # a way out. Two of its three differentiating features - the tail and the
    # snout - are PROFILE features a front-on mask cannot see at all.
    #
    # Shoulder over height goes from 0.333 to 0.233, which puts this race in
    # the gap between the elf's 0.17 and the human's 0.31 instead of on top of
    # the human. It is the numeric statement of "give the lizardfolk its own
    # body", settled by Marcel on 2026-08-27.
    p = Part("TORSO", (14, 20, 11), (7, 0, 5.5))
    p.box((0, 14), (0, 18), (0, 11), C)
    p.box((1, 13), (18, 19), (0, 11), C)
    p.box((2, 12), (19, 20), (1, 10), C)
    p.repaint((0, 14), (0, 2), (0, 11), B)
    p.repaint((5, 9), (0, 2), (0, 1), X)

    # COUNTERSHADING, and it is the cheapest thing in the entire design doc.
    # Dark above, light below - a light belly and throat. It costs ZERO extra
    # voxels because it is a palette split of a slot that already exists, and
    # it is the single strongest signal that a thing is an animal rather than a
    # person in a costume. Every real animal has it and no fantasy game
    # bothers.
    p.repaint((3, 11), (2, 14), (0, 2), v)

    # A sash from the right shoulder to the left hip, instead of a collar.
    for y in range(2, 18):
        x = 2 + (y - 2) * 9 // 16
        p.front_paint(y, (x, x + 2), c)
    # And the liner where the cloth meets the throat.
    p.box((3, 11), (19, 20), (0, 11), k)
    p.note(0, "the belt, buckle on the front")
    p.note(2, "the tunic, the sash, and the pale belly")
    p.note(18, "the shoulders step in")
    p.note(19, "the liner at the throat")
    return p


TORSO_COMMENT = """--- Torso --------------------------------------------------------------------

20 wide, 20 tall, 11 deep - THE HUMAN'S TORSO, stepped shoulders and all,
with a sash across the front instead of a collar. Deliberate: if the
lizardfolk had a distinct build as well as a snout, a crest and a tail, the
silhouette test would not be able to tell which feature was doing the
work."""


def pelvis() -> Part:
    # FOUR TALL, WHICH IS WHAT THE STACK LEAVES. `pelvis_height()` derives it
    # as total - legs - torso - head, and this part has to be exactly that or
    # the built body is taller than its own table says - which is what the
    # height self-test caught when this was briefly six: the lizardfolk
    # measured 1.98 m against a tabled 1.88.
    p = Part("PELVIS", (14, 4, 11), (7, 0, 5.5))
    p.box((0, 14), (0, 4), (0, 11), c)
    p.repaint((3, 11), (0, 4), (0, 2), v)
    return p


PELVIS_COMMENT = """--- Pelvis -------------------------------------------------------------------

20 wide, 4 tall, 11 deep. The tail's first link hangs off the back of it."""


def leg() -> Part:
    # TWENTY TALL AND CUT IN THREE. The digitigrade leg is the expensive one,
    # and it is where the resolution raise pays for itself: 30 output voxels
    # over three segments is 10 each, and at the old grid it would have been 5.
    # A joint half its own thickness is not a joint.
    #
    #     thigh  y 13..20   the trouser, hung from the hip
    #     shin   y  6..13   bare scale
    #     foot   y  0..6    the long metatarsal that a digitigrade animal
    #                       stands on the end of, plus the toes and claws
    #
    # The hock - the backward-facing joint that reads as "not a person" at any
    # distance - is the one between the shin and the foot, and the animator
    # bends it BACKWARD where the knee bends forward. See Animator's `foot` key.
    p = Part("LEG", (7, 20, 9), (3.5, 20, 5.5))
    p.box((0, 7), (13, 20), (2, 9), c)
    p.box((0, 7), (6, 13), (2, 9), S)
    # The foot proper: longer than it is tall, which is the whole point.
    p.box((0, 7), (2, 6), (3, 9), S)
    p.box((0, 7), (0, 2), (0, 9), S)
    # Pale underside, the same countershading as the belly.
    p.repaint((1, 6), (0, 2), (0, 9), v)
    for x in (0, 3, 6):
        p.put(x, 0, 0, T)
    p.note(0, "the toes, with claws, and the pale sole")
    p.note(2, "the long foot - a digitigrade animal stands on the END of this")
    p.note(6, "the shin")
    p.note(13, "the thigh")
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
    # Countershading runs the length of the tail: dark above, pale below. It is
    # the same palette split as the belly and it costs nothing.
    p.repaint((0, w), (0, 1), (0, d), v)
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


# --- Where this race's knee and elbow go -------------------------------------
#
# Character v2 Stage 4. The limb is authored full length above and cut here, so
# the drawing code never has to know where the joint is. Both splits are the
# midpoint of the author-grid limb, which is what the design doc asks for - "the
# legs are 24, and 12/12 thigh and shin"; at the author grid of 64 that is 8/8.
LEG_SPLIT = 13
## And again, for the hock: the shin above, the long foot below.
FOOT_SPLIT = 6
ARM_SPLIT = 10


def render() -> tuple[str, str]:
    # THREE SEGMENTS, so the limb is cut twice: thigh off the top, then the
    # remainder cut again into shin and foot. `split_limb` takes the same
    # shape both times and neither call knows the other happened.
    leg_upper, _rest = split_limb(leg(), LEG_SPLIT, "LEG_UPPER", "LEG_REST")
    leg_lower, leg_foot = split_limb(_rest, FOOT_SPLIT, "LEG_LOWER", "LEG_FOOT")
    arm_upper, arm_lower = split_limb(
        arm(), ARM_SPLIT, "ARM_UPPER", "ARM_LOWER")
    parts = {
        "head": head(),
        "torso": torso(),
        "pelvis": pelvis(),
        "leg_upper": leg_upper,
        "leg_lower": leg_lower,
        "leg_foot": leg_foot,
        "arm_upper": arm_upper,
        "arm_lower": arm_lower,
        # FOUR LINKS, NOT THREE, since character v2 Stage 6. The design doc
        # asks for a tail that ARCS down and back as a counterweight rather
        # than sticking out sideways like a plank, and an arc needs a fourth
        # joint to bend at. `MAX_CHAIN_LINKS` was already 4 and `CHAIN_NAMES`
        # was already a table, so the animator needed no change at all.
        #
        # Tapering to a point, and countershaded underneath like the belly.
        "tail_1": tail("TAIL_1", (6, 6, 8), (3, 0, 0), None),
        "tail_2": tail("TAIL_2", (5, 5, 8), (2.5, -1, 0), None),
        "tail_3": tail("TAIL_3", (4, 4, 7), (2, -1, 0), 4),
        "tail_4": tail("TAIL_4", (3, 3, 5), (1.5, -1, 0), 3),
    }
    comments = {"head": HEAD_COMMENT, "torso": TORSO_COMMENT,
                "pelvis": PELVIS_COMMENT, "leg_upper": LEG_COMMENT,
                "arm_upper": ARM_COMMENT, "tail_1": TAIL_COMMENT}
    blocks = [p.gd(name.upper(), comments.get(name, ""))
              for name, p in parts.items()]
    return (gd_file("PartsLizardfolk", DOC, blocks,
                    {k: k.upper() for k in parts}, "lizardfolk.py"),
            json_file("lizardfolk.py", DOC, parts, comments))
