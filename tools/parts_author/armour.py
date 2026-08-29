"""Armour, authored once and stamped into four bodies.

THE FITTING RULE, and it is the only interesting thing in this file:

    PROPORTIONS ARE RELATIVE. THICKNESSES ARE ABSOLUTE.

One idea has to be worn by a 39-voxel-wide dwarf, an 18-voxel-wide elf and a
forward-leaning lizardfolk with a tail. The two obvious approaches are both
wrong. Remodelling each piece per race is four times the authoring for four
races. Scaling one mesh puts a dwarf's breastplate on an elf and it looks like
a barrel - because scaling a plate scales its THICKNESS, and a plate three
voxels thick on a dwarf becomes two on an elf and reads as sheet tin, while
going the other way it reads as foam rubber.

So a piece is described in a NORMALISED SLOT FRAME - fractions of the
attachment's own width, height and depth - and stamped into each race's real
dimensions by `stamp()`. Its shape is the same fraction of every shoulder; its
plate is `PLATE` voxels thick on every body.

WHERE THE DIMENSIONS COME FROM. This module imports the race modules and asks
them, rather than keeping a second copy of the race table. `human.torso()`
knows how wide a human torso is because it just drew one, and a piece stamped
from that cannot drift from the body it is worn on.

TWO PER-RACE EXCEPTIONS ARE NAMED AND THERE ARE NO OTHERS. Leg armour does not
fit a digitigrade leg, and a back piece has to route around a dorsal ridge and
a tail. Both are variants of two pieces, not a per-race system. The research
lane's "every armour piece needs at least one race-specific variant" is not
taken: it is right that a literal one-size piece will clip, and wrong that the
answer is variants everywhere.
"""

from __future__ import annotations

from . import human, elf, dwarf, lizardfolk
from .voxlib import Part, gd_file, X, R, x, L, C, c, k, A, a, G

## Thicknesses, in AUTHOR voxels, the same on every race. The whole point of the
## fitting rule - these are the numbers that must NOT scale with the wearer.
##
## AUTHOR VOXELS, AND NOT `U_len`. Everything in this package is written on the
## 64 grid and `voxlib` scales at output; `U_len` converts an author length to
## an OUTPUT length, so calling it here applies the grid factor twice. The
## helm's one-voxel shell came out three voxels thick and read as a hat brim,
## which is how it was found. `U_len` is for code that has already crossed into
## output space, and nothing in this file has.
PLATE = 2
## How far faulds flare past the hips, in author voxels. They have to exceed
## the torso's own width or they are a skirt rather than an outline event, so
## the plate's part is wider than the body it is worn on by this much a side.
FLARE = 4
## A helm's shell. TWO and not one: the heads are chamfered, so a one-voxel
## shell touches the skull at every cut corner - measured, 180 voxels of it on
## the human. Two clears every race, and it is the same thickness as a plate,
## which is what "thicknesses are absolute" is supposed to mean anyway.
SHELL = 2
CAP = 2

## The races, and the module that draws each one.
RACES = {
    "human": human,
    "elf": elf,
    "dwarf": dwarf,
    "lizardfolk": lizardfolk,
}


def _frame(module, which: str):
    """The size AND ANCHOR of the thing a piece is worn on, from the body itself.

    THE ANCHOR MATTERS AS MUCH AS THE SIZE, and leaving it out was worth about
    four hundred voxels of clipping per race on the first attempt. A piece
    centred on its own bounding box is only centred on the BODY if the body's
    anchor happens to be the middle of its part - and the human head's is 9 in
    a part 17 deep, whose middle is 8.5, because the nose is in front of the
    skull. Half a voxel of disagreement puts a whole face of helm inside a
    whole face of head.

    So a piece is placed against the wearer's anchor, not against its own
    middle, and the two frames line up by construction.
    """
    builder = {"torso": module.torso, "arm": module.arm, "head": module.head}
    if which not in builder:
        raise KeyError(which)
    p = builder[which]()
    return p.w, p.h, p.d, p.anchor


def _span(fraction_lo: float, fraction_hi: float, size: int) -> tuple[int, int]:
    """A normalised 0..1 span to an integer voxel range in a frame of `size`.

    At least one voxel wide, always: a piece that scales to nothing on the
    narrowest race is not a thinner piece, it is a missing one - which is the
    failure the fitting rule exists to prevent, arriving by a different door.
    """
    lo = int(fraction_lo * size + 0.5)
    hi = int(fraction_hi * size + 0.5)
    if hi <= lo:
        hi = lo + 1
    return lo, min(hi, size)


def _hollow(p: Part, xr, yr, zr) -> None:
    """Erase everything inside a box, leaving a shell.

    Armour is worn ON a body, so any piece that wraps one has to have the body
    taken back out of it. Not an optimisation - a solid cap does not read
    differently from a shell, it just occupies the same cells as the head
    inside it, and the overlap self-test is right to object.
    """
    for yy in range(*yr):
        for zz in range(*zr):
            for xx in range(*xr):
                p.erase(xx, yy, zz)


# --- The pieces ---------------------------------------------------------------


def breastplate(module, race: str) -> Part:
    """A chest plate, standing PLATE voxels proud of the torso's front face.

    38% of the silhouette lives on the torso, which makes this the piece every
    layer shows on - and it is the one piece that must NOT change the outline,
    because the torso's width is the race's own and armour that widened it
    would blur the four races back together.
    """
    w, h, d, anchor = _frame(module, "torso")
    # THE ANCHOR IS THE THING TO GET RIGHT, and it is the difference between
    # armour and a tattoo. The torso's own anchor is `d * 0.5` in a part `d`
    # deep, so its front face sits at bone z = -d/2. A plate anchored the same
    # way and drawn at z 0..PLATE lands INSIDE that face. Anchoring at
    # `d * 0.5 + PLATE` puts the plate's back against the torso's front and the
    # rest of it proud, which is what wearing something means.
    p = Part("PLATE_%s" % race.upper(), (w + FLARE * 2, h, d + PLATE),
             (anchor[0] + FLARE, anchor[1], anchor[2] + PLATE))
    x0, x1 = _span(0.12, 0.88, w)
    x0 += FLARE
    x1 += FLARE
    y0, y1 = _span(0.18, 0.86, h)
    # The plate itself, proud of the front face. `z` runs front to back and the
    # body starts at PLATE, so the plate occupies [0, PLATE).
    p.box((x0, x1), (y0, y1), (0, PLATE), x)
    # A RAISED BRIGHT RIM, one voxel, along the top and both edges. This pair -
    # a bright rim on a dark body across a real geometric edge the mesher's own
    # AO darkens - is the whole of how metal reads here. See the material note
    # in races.gd; do NOT paint highlights on the faces.
    p.box((x0, x1), (y1 - 1, y1), (0, PLATE), R)
    p.box((x0, x0 + 1), (y0, y1), (0, PLATE), R)
    p.box((x1 - 1, x1), (y0, y1), (0, PLATE), R)
    # And the under-layer showing at the bottom edge: a band of liner where the
    # hard layer stops. Same mechanism as the collar, same reason it works.
    p.box((x0, x1), (y0, y0 + 1), (0, PLATE), k)
    # HERALDRY. A block of the race's accent on the chest - cheap, reads at
    # 15 m, and in a four-player co-op game it is how you find your friends.
    hx0, hx1 = _span(0.36, 0.64, w)
    hx0 += FLARE
    hx1 += FLARE
    hy0, hy1 = _span(0.42, 0.66, h)
    p.box((hx0, hx1), (hy0, hy1), (0, 1), C)

    # FAULDS - the plates that flare below the belt, and the third of tier 4's
    # three outline events. This is the one that has to grow the outline
    # SIDEWAYS at the hips, where the naked body is narrowing, so it registers
    # as a band the bare silhouette does not have.
    # Starting a little above the belt rather than at it: at 0.02 the faulds
    # sit exactly where the pelvis begins, and on the narrow-torsoed lizardfolk
    # they clipped it. Faulds hang FROM the waist, so this is also just where
    # they go.
    fy0, fy1 = _span(0.08, 0.26, h)
    rows = fy1 - fy0
    for i, yy in enumerate(range(fy1 - 1, fy0 - 1, -1)):
        # Flaring: each row down is wider than the one above, which is what
        # makes it a flare rather than a skirt - and what makes it a band the
        # naked silhouette does not have, at the point where a body narrows.
        grow = int(FLARE * (i + 1) / max(1, rows) + 0.5)
        p.box((FLARE - grow, FLARE + w + grow), (yy, yy + 1), (0, PLATE), x)
    p.box((0, w + FLARE * 2), (fy0, fy0 + 1), (0, PLATE), R)
    return p


def pauldron(module, race: str, glow: bool = False) -> Part:
    """A shoulder cap that grows the outline OUTWARD at the widest point.

    The best silhouette per voxel in the game: it is the only slot that adds
    width where the character is already widest, so it is the first outline
    event any tier can afford. Authored in the ARM's frame so it swings with
    the arm, which is what a pauldron does.
    """
    w, h, d, anchor = _frame(module, "arm")
    out = CAP
    # OUT AND UP, AND NOT FORWARD. The arm hangs flush against the torso, so a
    # pauldron that also grew in `z` clipped the torso's corner - twenty voxels
    # a side, which is small and is still armour inside a body. A pauldron is a
    # cap over the top of a shoulder; growing it front-to-back buys no outline
    # event from any angle a silhouette is judged from, and costs a clash with
    # the one part of the body it is guaranteed to be touching.
    pw, pd = w + out, d
    p = Part("PAULDRON_%s%s" % ("RUNED_" if glow else "", race.upper()),
             (pw, h, pd), anchor)
    y0, y1 = _span(0.80, 1.0, h)
    # OUTWARD ONLY. `x` is the character's own right and the right arm is the
    # authored one, so growing the pauldron in BOTH directions grows it inboard
    # straight into the torso - which is where three hundred voxels per side
    # went on the first run. It grows out and up, which is the direction that
    # buys an outline event anyway; the left is this mirrored, so its outward
    # is the other way for free.
    p.box((0, pw), (y0, y1), (0, pd), x)
    # The rim along the bottom lip, which is the edge a viewer actually sees.
    p.box((0, pw), (y0, y0 + 1), (0, pd), R)
    # THE RUNE BAND, on ONE pauldron, and it is twelve voxels at most.
    #
    # The cap IS the design. A rune band on one shoulder is a story about
    # something the wearer did; a glowing character is what every game does
    # wrong, and the only thing between the two is a number somebody enforces -
    # which `_test_glow_is_capped` does, at twelve, on every buildable
    # character at every tier.
    #
    # Asymmetric for free: it is on the authored side, so the mirrored arm does
    # not get one, and one lit shoulder reads as deliberate where two read as
    # a costume.
    if glow:
        gy = y0 + (y1 - y0) // 3
        for i in range(min(2, y1 - gy)):
            p.box((w + out - 1, w + out), (gy + i, gy + i + 1),
                  (pd // 2, pd // 2 + 1), G)
    # A SHELL, NOT A BLOCK. Everything inside the arm's own footprint comes
    # back out, so the pauldron is a cap OVER the shoulder rather than a solid
    # that happens to contain it. Filling the box and forgetting this put ten
    # thousand armour voxels inside each body on the first run, which the
    # overlap test reported to the voxel.
    _hollow(p, (0, w), (y0, y1), (0, d))
    return p


def cloak(module, race: str) -> Part:
    """40-60 voxels that add a third to the visual mass, move independently and
    hide bad leg geometry. The best purchase in the game, which is why the back
    slot is third in the order rather than sixth.

    Authored in the `back` SOCKET's frame rather than as a torso overlay - a
    cloak hangs off a body, it is not a layer over one.
    """
    w, h, d, _a = _frame(module, "torso")
    cw = int(w * 1.15 + 0.5)
    ch = int(h * 1.00 + 0.5)
    # Anchored at its TOP, on the `back` socket, and standing off by PLATE so
    # it hangs behind the torso rather than through it. `z` runs front to back,
    # so positive is behind.
    p = Part("CLOAK_%s" % race.upper(), (cw, ch, PLATE), (cw * 0.5, ch, -PLATE))
    # ASYMMETRIC, and it is free. Symmetric armour reads as issued; asymmetric
    # reads as assembled by someone who lived through things. The cloak is
    # gathered on one shoulder, so it is wider on that side all the way down.
    for y in range(ch):
        f = y / max(1, ch - 1)
        left = int(cw * 0.5 - cw * 0.5 * (0.45 + 0.55 * (1.0 - f)) + 0.5)
        right = int(cw * 0.5 + cw * 0.5 * (0.30 + 0.70 * (1.0 - f)) + 0.5)
        p.box((max(0, left), min(cw, right)), (y, y + 1), (0, PLATE), c)
    p.box((0, cw), (ch - 1, ch), (0, PLATE), k)

    # THE FIRST OF THE TWO NAMED LIZARDFOLK EXCEPTIONS, and it is a SPLIT
    # rather than a shortening.
    #
    # A back piece on this race has to route around a dorsal ridge and a tail,
    # and a cloak of the usual length simply hangs through the tail - five
    # hundred voxels of it on the first run, which the overlap test reported to
    # the voxel. Cutting the cloak short would have made the number go away and
    # taken the piece with it: the cloak is the best value-per-voxel item in the
    # game precisely because it is big.
    #
    # So it is split into two panels either side of the tail's root, which is
    # what a cloak worn by something with a tail actually looks like, and it
    # keeps its mass. A variant of ONE piece, not a per-race system - the
    # distinction the design doc draws, and the reason the research lane's
    # "every armour piece needs a race-specific variant" is not taken.
    if race == "lizardfolk":
        gap = int(cw * 0.45 + 0.5)
        g0 = (cw - gap) // 2
        # From the tail's root downward. Above that the panels meet, so the
        # cloak still reads as one garment from the shoulders.
        split_from = int(ch * 0.30 + 0.5)
        for yy in range(split_from, ch):
            for zz in range(PLATE):
                for xx in range(g0, g0 + gap):
                    p.erase(xx, yy, zz)
        # Inked down both new edges, so the split reads as a hem rather than as
        # a hole.
        for yy in range(split_from, ch):
            p.box((g0 - 1, g0), (yy, yy + 1), (0, PLATE), k)
            p.box((g0 + gap, g0 + gap + 1), (yy, yy + 1), (0, PLATE), k)
    return p


def helm(module, race: str, crest: bool = False) -> Part:
    """A helm that leaves its wearer's identity feature intact.

    THE HEAD SLOT IS WHERE RACE IDENTITY GOES TO DIE. A full helm erases the
    elf's ears, the dwarf's beard line and the lizardfolk's snout in one item -
    and then four races that took a whole epic to separate are four helmets.

    So every head piece is authored per race in the same way its wearer's head
    is, and each leaves its race's feature alone or replaces it in kind:

      human       anything, because the human's identity is on its chest
      elf         open at the sides, so the ears pass through
      dwarf       stops above the beard line, and gets HORNS - the only race
                  whose silhouette can afford width above the shoulders
      lizardfolk  sits behind the brow ridge and never covers the snout
    """
    w, h, d, anchor = _frame(module, "head")
    out = SHELL
    pw, pd = w + out * 2, d + out * 2
    p = Part("HELM_%s%s" % ("CROWNED_" if crest else "", race.upper()),
             (pw, h + (9 if crest else 0), pd),
             (anchor[0] + out, anchor[1], anchor[2] + out))

    # The skull cap: the top of the head, and how far down it comes is the
    # per-race decision.
    top = {"human": 0.62, "elf": 0.70, "dwarf": 0.66, "lizardfolk": 0.74}[race]
    y0, y1 = _span(top, 0.99, h)
    p.box((0, pw), (y0, y1), (0, pd), x)
    p.box((0, pw), (y0, y0 + 1), (0, pd), R)
    # A shell over the skull, for the same reason the pauldron is one.
    _hollow(p, (out, out + w), (y0, y1), (out, out + d))

    if race == "elf":
        # OPEN AT THE SIDES. The ears pass through, and the opening is a real
        # hole rather than a lighter colour, so it survives being a silhouette.
        ex0, ex1 = _span(0.0, 0.16, w + out * 2)
        for xx in list(range(ex0, ex1)) + list(range(w + out * 2 - ex1, w + out * 2 - ex0)):
            for yy in range(y0, y1 - 1):
                for zz in range(0, d + out * 2):
                    p.erase(xx, yy, zz)
    elif race == "dwarf":
        # HORNS. The dwarf is the one race whose silhouette can afford width
        # above the shoulders without becoming ambiguous with anything else,
        # and verticality above the head is otherwise reserved for tier 5.
        for side in (0, 1):
            hx = 1 if side == 0 else w + out * 2 - 2
            for i in range(4):
                p.box((hx, hx + 1), (y1 - 1 - i, y1 - i),
                      (d // 2, d // 2 + 1), R)
    elif race == "lizardfolk":
        # BEHIND THE BROW RIDGE. The snout is the front of this head and the
        # helm simply does not go there - `top` at 0.74 keeps it clear.
        pass

    # ONE VERTICAL ELEMENT ABOVE THE HEAD, and it is RESERVED FOR TIER 5 on
    # three of the four races - the dwarf gets its horns at tier 4 instead,
    # because the dwarf is the one race whose silhouette has the width to carry
    # something above the shoulders without becoming ambiguous with anything
    # else in the cast.
    #
    # It is the fifth of tier 5's five events and it is deliberately the last
    # one on the ladder: verticality above the head is the loudest thing a
    # silhouette can do, so it is what "you did something" is allowed to spend.
    if crest:
        cx = pw // 2
        for i in range(9):
            p.box((cx - 1, cx + 1), (y1 + i, y1 + i + 1), (pd // 2 - 1, pd // 2 + 2), R)
    return p


def jerkin(module, race: str) -> Part:
    """Tier 1. Cloth, and ZERO OUTLINE EVENTS ON PURPOSE.

    If starting gear changed the silhouette then the naked character is not the
    design, the starting gear is - and the acceptance test is four races
    identifiable in nothing. So this is one voxel of cloth over the chest with
    a liner hem, and it does not reach past any edge the body already had.
    """
    w, h, d, anchor = _frame(module, "torso")
    p = Part("JERKIN_%s" % race.upper(), (w, h, d + 1),
             (anchor[0], anchor[1], anchor[2] + 1))
    x0, x1 = _span(0.10, 0.90, w)
    y0, y1 = _span(0.14, 0.80, h)
    p.box((x0, x1), (y0, y1), (0, 1), c)
    p.box((x0, x1), (y0, y0 + 1), (0, 1), k)
    return p


def hide(module, race: str) -> Part:
    """Tier 2's torso. Leather over cloth, and the accent appears.

    The outline event at this tier is the shoulder CAP, not this - a hide
    jerkin drapes exactly as cloth does. What changes is the material and the
    fact that there is now something worth putting an accent on.
    """
    w, h, d, anchor = _frame(module, "torso")
    p = Part("HIDE_%s" % race.upper(), (w, h, d + 1),
             (anchor[0], anchor[1], anchor[2] + 1))
    x0, x1 = _span(0.08, 0.92, w)
    y0, y1 = _span(0.14, 0.82, h)
    p.box((x0, x1), (y0, y1), (0, 1), L)
    # A 1-voxel stitch line in liner along every edge: the tell for leather in
    # the material table, and the thing that stops hide reading as flat cloth.
    p.box((x0, x1), (y1 - 1, y1), (0, 1), k)
    p.box((x0, x1), (y0, y0 + 1), (0, 1), k)
    p.box((x0, x0 + 1), (y0, y1), (0, 1), k)
    p.box((x1 - 1, x1), (y0, y1), (0, 1), k)
    return p


def cap(module, race: str) -> Part:
    """Tier 2's ONE outline event: a shoulder cap.

    The shoulders are the only slot that grows the outline outward at the
    widest point the character has, which makes a cap the cheapest event on the
    ladder and the right one to spend first.
    """
    w, h, d, anchor = _frame(module, "arm")
    out = CAP - 1
    p = Part("CAP_%s" % race.upper(), (w + out, h, d), anchor)
    y0, y1 = _span(0.86, 1.0, h)
    p.box((0, w + out), (y0, y1), (0, d), L)
    p.box((0, w + out), (y0, y0 + 1), (0, d), k)
    _hollow(p, (0, w), (y0, y1), (0, d))
    return p


def mail(module, race: str) -> Part:
    """Tier 3. THE CHECKER, and no outline event at all from this piece.

    Mail's whole character is that it DRAPES. It does nothing to the outline
    and everything to the surface, which is correct and is where a player
    learns that armour is not monotonically bigger.

    THE 1-VOXEL CHECKER IS FREE LOD, and it is the one place in this game where
    a value pattern is right: at 5 m you see individual scales, and at 15 m the
    two adjacent values average to one flat mid-tone - which is exactly what
    mail looks like from across a field.
    """
    w, h, d, anchor = _frame(module, "torso")
    p = Part("MAIL_%s" % race.upper(), (w, h, d + 1),
             (anchor[0], anchor[1], anchor[2] + 1))
    x0, x1 = _span(0.06, 0.94, w)
    y0, y1 = _span(0.12, 0.84, h)
    for yy in range(y0, y1):
        for xx in range(x0, x1):
            p.box((xx, xx + 1), (yy, yy + 1), (0, 1), A if (xx + yy) % 2 == 0 else a)
    p.box((x0, x1), (y0, y0 + 1), (0, 1), k)
    return p


def gorget(module, race: str) -> Part:
    """Tier 3's ONE outline event: a raised collar.

    On the HEAD slot rather than the torso, so it rises with the head bone and
    a head-look does not tear it off the neck - which is the failure Veloren
    documents and the reason its chest pieces carry neck detail.
    """
    w, h, d, anchor = _frame(module, "head")
    out = SHELL
    pw, pd = w + out * 2, d + out * 2
    p = Part("GORGET_%s" % race.upper(), (pw, h, pd),
             (anchor[0] + out, anchor[1], anchor[2] + out))
    y0, y1 = _span(0.0, 0.16, h)
    if y1 <= y0 + 1:
        y1 = y0 + 2
    p.box((0, pw), (y0, y1), (0, pd), x)
    p.box((0, pw), (y1 - 1, y1), (0, pd), R)
    _hollow(p, (out, out + w), (y0, y1), (out, out + d))
    return p


PIECE_BUILDERS = {
    "jerkin": jerkin,
    "hide": hide,
    "cap": cap,
    "mail": mail,
    "gorget": gorget,
    "plate": breastplate,
    "pauldron": pauldron,
    "pauldron_runed": lambda module, race: pauldron(module, race, glow=True),
    "cloak": cloak,
    "helm": helm,
    "helm_crowned": lambda module, race: helm(module, race, crest=True),
}

DOC = """Armour, authored once in a normalised frame and stamped into four bodies.

PROPORTIONS ARE RELATIVE, THICKNESSES ARE ABSOLUTE. A piece's shape is the
same fraction of every shoulder; its plate is the same number of voxels
thick on every race. Get that backwards and dwarf armour looks like foam
rubber while elf armour looks like it was cut from sheet tin.

Four slots ship. `legs` and `hands` are declared in CharacterDef's wire
format with no geometry, so filling them later costs no version bump.

THIS IS NOT AN ITEM SYSTEM. No item table, no inventory, no drops, no rule
about what grants a tier, no stats. See Armour and, for the same sentence
written for the same reason, PartsGear."""


def render() -> str:
    parts: dict[str, Part] = {}
    for race, module in RACES.items():
        for piece, build in PIECE_BUILDERS.items():
            parts["%s_%s" % (piece, race)] = build(module, race)
    blocks = [p.gd(name.upper()) for name, p in parts.items()]
    return gd_file("PartsArmour", DOC, blocks,
                   {k: k.upper() for k in parts}, "armour.py")
