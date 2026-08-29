"""Hair, beards and crests, authored in the frame of the head they hang off.

Every builder here takes the head's own skull cells (in head-frame
coordinates, from `Part.frame_cells()`) and paints AROUND them, never into
them: the mesher culls faces only between voxels of one part, so a hair
voxel inside a skull would be a hidden shell paid for every frame. The
`Frame` finds its own bounding box and anchor afterwards, which is what lets
a beard be described as "below the chin and in front of the face" in the
integers the head was built in.

THE SHAPES ARE DECO. A cap that wraps the stepped crown, a fringe with a
hard line just above the brows, a bob with a flat bottom at the jaw, braids
notched in steps, crests as fans of steps. Stepped masses, not textures -
rule 4 of the look plan.
"""

from .voxlib import Frame, Part, json_file, octagon, H
from . import human, elf, dwarf, lizardfolk


# --- Shared builders ---------------------------------------------------------

def cap(f: Frame, skull: set, foot: set, y0: int, y1: int) -> None:
    """Fill the skull's own footprint from `y0` to `y1`, skipping skull cells.
    Started at the first stepped crown row, that wraps the steps and adds a
    flat top - a helmet-cap flush with the sides of the head."""
    for y in range(y0, y1):
        for (x, z) in foot:
            if (x, y, z) not in skull:
                f.put(x, y, z, H)


def fringe(f: Frame, xr, y0: int, y1: int, z: int, depth: int = 1) -> None:
    """Proud of the forehead, from just above the brows to the top of the cap.
    The hard bottom edge is the fringe line.

    LOOK V2 STAGE 5: `depth` lets the mass BREAK THE HEAD BOX. A hair that is
    one voxel of paint on a flat forehead reads as a hat brim at any distance;
    a mass that overhangs is what tells a human from an elf in a silhouette,
    which is what `silhouettes-40` is for. Low z is the front, so the fringe
    grows toward -z."""
    f.box(xr, (y0, y1), (z - depth + 1, z + 1), H)


def notched_column(f: Frame, xr_wide, xr_narrow, y_top: int, y_bottom: int, zr) -> None:
    """A braid: two-row bands alternating wide and narrow, top down."""
    y = y_top
    wide = True
    while y > y_bottom:
        f.box(xr_wide if wide else xr_narrow, (max(y - 2, y_bottom), y), zr, H)
        y -= 2
        wide = not wide


def jaw_wrap(f: Frame, skull: set, foot: set, y0: int, y1: int, front_only=True) -> None:
    """Fill the stepped-in jaw rows back out to the footprint, on the front
    half - a beard that wraps the chin and the sides of the jaw."""
    for y in range(y0, y1):
        for (x, z) in foot:
            if front_only and z >= 0:
                continue
            if (x, y, z) not in skull:
                f.put(x, y, z, H)


# --- Human ---------------------------------------------------------------------

def human_frame():
    head = human.head()
    skull = head.frame_cells()
    foot = octagon(*human.SKULL_X, *human.SKULL_Z, human.CHAMFER)
    return skull, foot


def human_hair_short() -> Part:
    skull, foot = human_frame()
    f = Frame()
    cap(f, skull, foot, 20, 24)
    fringe(f, (-8, 8), human.BROW_Y + 1, 24, -9, depth=2)
    return f.to_part("HUMAN_HAIR_SHORT")


def human_hair_long() -> Part:
    skull, foot = human_frame()
    f = Frame()
    cap(f, skull, foot, 20, 24)
    fringe(f, (-8, 8), human.BROW_Y + 1, 24, -9, depth=2)
    # The bob: sides and back, outside the skull, flat bottom at the jaw.
    f.fill_outside(skull, (-10, 10), (4, 24), (-6, 9), H, footprint=foot)
    return f.to_part("HUMAN_HAIR_LONG")


def human_hair_tied() -> Part:
    skull, foot = human_frame()
    f = Frame()
    cap(f, skull, foot, 20, 24)
    fringe(f, (-8, 8), human.BROW_Y + 1, 24, -9, depth=2)
    # A bun at the back, stepped top and bottom.
    f.box((-3, 3), (17, 21), (8, 12), H)
    f.box((-2, 2), (16, 17), (8, 11), H)
    f.box((-2, 2), (21, 22), (8, 11), H)
    return f.to_part("HUMAN_HAIR_TIED")


def human_beard_short() -> Part:
    skull, foot = human_frame()
    f = Frame()
    f.box((-7, 7), (0, human.MOUTH_Y), (-9, -8), H)      # the front slab
    jaw_wrap(f, skull, foot, 0, 2)
    # Under the chin it steps in, and stays in front of the chest (z < -6).
    f.box((-7, 7), (-1, 0), (-9, -6), H)
    f.box((-6, 6), (-2, -1), (-9, -6), H)
    f.box((-5, 5), (-3, -2), (-9, -7), H)
    f.box((-3, 3), (-4, -3), (-9, -8), H)
    return f.to_part("HUMAN_BEARD_SHORT")


def human_beard_full() -> Part:
    skull, foot = human_frame()
    f = Frame()
    f.box((-7, 7), (0, human.MOUTH_Y), (-9, -8), H)
    jaw_wrap(f, skull, foot, 0, 10)                       # up the cheeks
    f.box((-7, 7), (-6, 0), (-9, -6), H)
    f.box((-5, 5), (-10, -6), (-9, -6), H)
    f.box((-3, 3), (-12, -10), (-9, -7), H)
    return f.to_part("HUMAN_BEARD_FULL")


# --- Elf -----------------------------------------------------------------------

def elf_frame():
    head = elf.head()
    skull = head.frame_cells()
    foot = octagon(*elf.SKULL_X, *elf.SKULL_Z, elf.CHAMFER)
    return skull, foot


def elf_hair_short() -> Part:
    skull, foot = elf_frame()
    f = Frame()
    cap(f, skull, foot, 23, 27)
    fringe(f, (-6, 6), elf.BROW_Y + 1, 27, -9)
    # SWEPT BACK 3 PAST THE SKULL (look v2 Stage 5). The elf's silhouette is
    # the one that has to differ from the human's from behind as well as in
    # front, and the ears alone were not doing it at 40 m.
    f.box((-7, 7), (14, 25), (8, 11), H)
    return f.to_part("ELF_HAIR_SHORT")


def elf_hair_long() -> Part:
    skull, foot = elf_frame()
    f = Frame()
    cap(f, skull, foot, 23, 27)
    fringe(f, (-6, 6), elf.BROW_Y + 1, 27, -9)
    # Sides BEHIND the ears only (the ears live at z -2..1), and the back.
    f.fill_outside(skull, (-10, 10), (8, 23), (2, 9), H, footprint=foot)
    # A curtain down the back to the shoulders.
    f.box((-8, 8), (-2, 8), (8, 10), H)
    f.box((-10, 10), (8, 23), (8, 10), H)
    return f.to_part("ELF_HAIR_LONG")


def elf_hair_braided() -> Part:
    skull, foot = elf_frame()
    f = Frame()
    cap(f, skull, foot, 23, 27)
    fringe(f, (-6, 6), elf.BROW_Y + 1, 27, -9)
    f.box((-7, 7), (14, 25), (8, 11), H)
    notched_column(f, (-2, 2), (-1, 1), 23, -8, (8, 11))
    return f.to_part("ELF_HAIR_BRAIDED")


# --- Dwarf ---------------------------------------------------------------------

def dwarf_frame():
    head = dwarf.head()
    skull = head.frame_cells()
    foot = octagon(*dwarf.SKULL_X, *dwarf.SKULL_Z, dwarf.CHAMFER)
    return skull, foot


def dwarf_hair_short() -> Part:
    skull, foot = dwarf_frame()
    f = Frame()
    cap(f, skull, foot, 18, 22)
    fringe(f, (-8, 8), dwarf.BROW_Y + 2, 22, -9)
    return f.to_part("DWARF_HAIR_SHORT")


def dwarf_hair_long() -> Part:
    skull, foot = dwarf_frame()
    f = Frame()
    cap(f, skull, foot, 18, 22)
    fringe(f, (-8, 8), dwarf.BROW_Y + 2, 22, -9)
    f.fill_outside(skull, (-11, 11), (3, 22), (-6, 9), H, footprint=foot)
    return f.to_part("DWARF_HAIR_LONG")


def dwarf_hair_braided() -> Part:
    skull, foot = dwarf_frame()
    f = Frame()
    cap(f, skull, foot, 18, 22)
    fringe(f, (-8, 8), dwarf.BROW_Y + 2, 22, -9)
    # Two braids down the back, one behind each shoulder.
    notched_column(f, (-8, -4), (-7, -5), 18, -10, (8, 11))
    notched_column(f, (4, 8), (5, 7), 18, -10, (8, 11))
    return f.to_part("DWARF_HAIR_BRAIDED")


def dwarf_beard_short() -> Part:
    skull, foot = dwarf_frame()
    f = Frame()
    f.box((-8, 8), (0, dwarf.MOUTH_Y), (-9, -8), H)
    jaw_wrap(f, skull, foot, 0, 2)
    # In front of the face plane (z = -8) and behind the pendant (z = -11),
    # and never touching the tabard, which sits at z = -8 on the chest.
    f.box((-8, 8), (-4, 0), (-11, -8), H)
    f.box((-6, 6), (-8, -4), (-10, -8), H)
    return f.to_part("DWARF_BEARD_SHORT")


def dwarf_beard_full() -> Part:
    skull, foot = dwarf_frame()
    f = Frame()
    f.box((-8, 8), (0, dwarf.MOUTH_Y), (-9, -8), H)
    jaw_wrap(f, skull, foot, 0, 9)
    # LOOK V2 STAGE 5: two voxels wider than the head each side and four
    # further below the jaw. A dwarf is his beard in silhouette; at look v1's
    # width it stopped exactly at the jawline and read as a chin.
    f.box((-10, 10), (-6, 0), (-11, -8), H)
    f.box((-8, 8), (-12, -6), (-11, -8), H)
    f.box((-6, 6), (-22, -12), (-11, -8), H)
    return f.to_part("DWARF_BEARD_FULL")


def dwarf_beard_forked() -> Part:
    skull, foot = dwarf_frame()
    f = Frame()
    f.box((-8, 8), (0, dwarf.MOUTH_Y), (-9, -8), H)
    jaw_wrap(f, skull, foot, 0, 2)
    f.box((-8, 8), (-4, 0), (-11, -8), H)
    f.box((-7, -2), (-18, -4), (-10, -8), H)
    f.box((2, 7), (-18, -4), (-10, -8), H)
    return f.to_part("DWARF_BEARD_FORKED")


# --- Lizardfolk ------------------------------------------------------------------

def lizard_crest_low() -> Part:
    # A fin six wide and fourteen tall, raking back a voxel every two rows.
    # The v1 crest's size in METRES - six and fourteen here are three and
    # seven at 1/8 - because the crest is the one feature a front-on mask
    # can see on this race, and halving it halved the number.
    f = Frame()
    for k in range(14):
        f.box((-3, 3), (18 + k, 19 + k), (-7 + k // 2, 8), H)
    return f.to_part("LIZARD_CREST_LOW")


def lizard_crest_tall() -> Part:
    # A sunburst: twenty-two tall, widening from six at the base to sixteen at
    # the top in two-voxel steps, raking back past the skull. The most Deco
    # thing on any head in the game.
    f = Frame()
    for k in range(22):
        half = 3 + k // 4
        f.box((-half, half), (18 + k, 19 + k), (-7 + k // 3, 10), H)
    return f.to_part("LIZARD_CREST_TALL")


def lizard_frill() -> Part:
    # A fan behind the head, twenty-four across, eighteen tall, four thick.
    f = Frame()
    widths = {10: 4, 12: 6, 14: 8, 16: 10, 18: 12, 20: 12, 22: 12, 24: 10, 26: 8}
    for y0, half in widths.items():
        f.box((-half, half), (y0, y0 + 2), (8, 12), H)
    return f.to_part("LIZARD_FRILL")


# --- The file ------------------------------------------------------------------

DOC = """Hair, beards and crests. Everything that hangs off a head.

AUTHORED IN THE HEAD'S OWN FRAME. A hair part uses the same lattice as the
head part it sits on, so its anchor is the head's anchor shifted - which is
what lets a beard be described as "below the chin and in front of the face"
rather than in a coordinate system nobody can hold in their head.

ANCHORS HERE MAY BE NEGATIVE OR PAST THE PART. A crest sits above its head
bone, so its anchor y is negative; a beard hangs below, so its anchor y is
positive on a part that lives entirely under the chin. Both are legal: the
anchor is a lattice point, not an index into the voxels.

HAIR SITS OUTSIDE THE HEAD, never inside it. The mesher culls faces between
two voxels OF THE SAME PART, so a hair part overlapping the skull would
leave a hidden shell of triangles inside it - invisible, and paid for on
every frame. The generator paints around the skull cells it is handed and
cannot put a voxel inside one.

THE SHAPES ARE DECO - rule 4 of the look plan. A cap wraps the stepped
crown; a fringe stops on a hard line just above the brows; the bob has a
flat bottom at the jaw; braids are notched in two-row steps; crests are
fans of steps. Three options per race are three SILHOUETTES, not three
textures: a crop, a bob and a tail are distinguishable at 40 m, three
fringes are not."""


HUMAN_COMMENT = """=============================================================================
HUMAN.  Head is 18 x 22 x 17 anchored at (9, 0, 9).
  skull  x -9..+9   y 0..22   z -8..+8   octagonal in plan (chamfer 2),
                                        jaw stepped in at y 0-1, crown at 20-21
  the nose sticks out to z = -9 at y 8..10; the brows are the row y = 14
============================================================================="""

ELF_COMMENT = """=============================================================================
ELF.  Head is 28 x 25 x 17 anchored at (14, 0, 9).
  neck   x -4..+4   y 0..3
  skull  x -8..+8   y 3..25   z -8..+8   crown stepped in at 23-24
  ears   x -14..-8 and +8..+14, at z -2..+2 only, y 14..22

The hair deliberately does NOT cover the ears: they are what separates an
elf at distance, and a cap that swallowed them would throw away the one
feature the silhouette metric can see. The bob's sides sit behind them.
============================================================================="""

DWARF_COMMENT = """=============================================================================
DWARF.  Head is 20 x 20 x 17 anchored at (10, 0, 9).
  skull  x -10..+10  y 0..20   z -8..+8   crown stepped in at 18-19
  the nose sticks out to z = -9 at y 7..9; the brows are rows 13-14

THE BEARD IS HALF THE SILHOUETTE, and there are three of them and no "none".
The full beard reaches the belt: eighteen voxels below the chin is torso
y = 0. Every beard hangs in front of z = -8 - the face plane, and one voxel
clear of the torso's front at -7, which is where the chest placeholder sits -
and behind z = -11, which is where the pendant placeholder hangs.
============================================================================="""

LIZARD_COMMENT = """=============================================================================
LIZARDFOLK.  Head is 16 x 18 x 24 anchored at (8, 0, 16).
  skull  x -8..+8   y 0..18   z -8..+8    crown at y = 18
  snout  x -4..+4   y 4..12   z -16..-8

No hair. The `hair` slot holds a crest instead, which is why the slot is
called `hair` in the def and `crest` in the option list - one byte on the
wire, two names for the humans reading it. The crests are the only
differentiating feature a front-on mask can see; the tail and snout are
profile features.
============================================================================="""



def render() -> tuple[str, str]:
    # HAIR HAS NO `PARTS` MAP to take keys from - the option tables below are
    # the index, and they are positional. So the JSON key is the constant's
    # own name, lowercased, and the pairs are written once here rather than
    # twice.
    built = [
        ("HUMAN_HAIR_SHORT", human_hair_short(), HUMAN_COMMENT + "\n\nA cap wrapping the stepped crown, and a fringe."),
        ("HUMAN_HAIR_LONG", human_hair_long(), "The bob: the cap, the fringe, and a flat-bottomed mass to the jaw."),
        ("HUMAN_HAIR_TIED", human_hair_tied(), "The cap and fringe, with a stepped bun at the back."),
        ("HUMAN_BEARD_SHORT", human_beard_short(), "Short beard: chin and jaw, stepping in below the chin, stopping below the mouth."),
        ("HUMAN_BEARD_FULL", human_beard_full(), "Full beard: up the cheeks and down to the chest in three steps."),
        ("ELF_HAIR_SHORT", elf_hair_short(), ELF_COMMENT),
        ("ELF_HAIR_LONG", elf_hair_long(), "The cap and fringe, sides behind the ears, and a curtain to the shoulders."),
        ("ELF_HAIR_BRAIDED", elf_hair_braided(), "One thick braid straight down the back, notched in two-row steps so it\nreads as plaited rather than as a plank."),
        ("DWARF_HAIR_SHORT", dwarf_hair_short(), DWARF_COMMENT),
        ("DWARF_HAIR_LONG", dwarf_hair_long(), "The bob, to the jaw."),
        ("DWARF_HAIR_BRAIDED", dwarf_hair_braided(), "Two notched braids down the back, one behind each shoulder."),
        ("DWARF_BEARD_SHORT", dwarf_beard_short(), "Short: chin to the top of the chest, three voxels in front of the face."),
        ("DWARF_BEARD_FULL", dwarf_beard_full(), "Full: to the belt in three steps, and up the cheeks."),
        ("DWARF_BEARD_FORKED", dwarf_beard_forked(), "Forked: full length, split into two prongs below the chin."),
        ("LIZARD_CREST_LOW", lizard_crest_low(), LIZARD_COMMENT + "\n\nA fin six wide, fourteen tall, raking backward in steps."),
        ("LIZARD_CREST_TALL", lizard_crest_tall(), "A sunburst: six wide at the base and sixteen at the top, twenty-two\ntall, raking back past the skull."),
        ("LIZARD_FRILL", lizard_frill(), "A fan behind the head rather than a fin on top of it: twenty-four across\nand four thick, stepped, which is a completely different outline from either\ncrest."),
    ]
    parts = {const.lower(): part for const, part, _c in built}
    comments = {const.lower(): comment for const, _p, comment in built}

    # NO GDSCRIPT. `parts_hair.gd` is hand-written and permanent since
    # parts-data v1: the option tables and `_lookup()` are the part of that
    # file no JSON can hold, and they are not generated any more. The blocks
    # above are built only so the ASCII has one origin.
    return (None, json_file("hair.py", DOC, parts, comments))
