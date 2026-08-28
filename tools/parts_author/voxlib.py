"""The voxel authoring kit behind every generated part file.

WHAT THIS IS. `scripts/character/parts/parts_*.gd` hold every character part
as ASCII slices in slot letters - see the docstring on `VoxelModel` for the
convention. At 1/16 of a block a human head is 22 slices of 17 rows of 18
characters, which is past what anyone should type by hand, so the ASCII is
WRITTEN by the modules beside this one and committed alongside them. The
runtime never sees Python: it parses the ASCII exactly as it did when the
ASCII was typed.

THE COORDINATE CONVENTION IS VoxelModel'S, restated once here. Inside a part,
`x` runs along the character's own right (+X, `Vector3.RIGHT`), `y` runs up,
and `z` runs from the FRONT (-Z, `Vector3.FORWARD`, index 0) to the back. The
only inversion is the one the ASCII makes: the first character of a row is
the left of the PICTURE, which is the character's right, so column
`w - 1 - x`. `Part.slices()` applies that and nothing else does.

Two ways to author:

  - `Part(name, size, anchor)` and paint into it by index. Bodies are built
    this way, because their anchors are lattice points that may sit on a
    half voxel (the top-centre of a 9-wide leg is x = 4.5).
  - `Frame()` and paint in the frame of the part this one hangs off - a head
    for hair and beards, a socket for gear - then `Frame.to_part()`, which
    finds the bounding box and derives the anchor. That is what lets a beard
    be described as "below the chin and in front of the face" in the same
    integers the head was built in.
"""

from __future__ import annotations

import math

# --- The grid ----------------------------------------------------------------
#
# THE RESOLUTION IS A NUMBER IN THIS FILE, which is the single most important
# fact about the character redesign: nothing under scripts/character/parts/ is
# drawn by hand, so moving the grid is a re-run rather than a rewrite, and the
# 96-vs-128 decision stops being one-way. See docs/plans/character-v2-tech.md
# Stage 2.
#
# EVERY GENERATOR STILL AUTHORS AT 64 AND KNOWS NOTHING ABOUT THIS. That is
# deliberate, and it is what makes the change small enough to be safe. The
# alternative - wrapping every literal in every generator in a scale call - is
# 1,887 lines of edits whose correctness cannot be checked by the one gate that
# actually proves something, because at RES 64 every scale call is the identity
# and the edits are invisible to it.
#
# Instead the scaling happens ONCE, at output. A part is authored, drawn and
# reasoned about entirely on the 64 grid; `Part.slices()` and `Part.gd()` are
# the only things that have ever heard of RES. So:
#
#   - every drawing method, every frame, every hair footprint and every skull
#     test stays in author space and is untouched;
#   - there is no inverse map to get wrong, because nothing ever has to ask
#     "which author voxel did this scaled voxel come from" anywhere except in
#     the one function that builds the output grid;
#   - at RES 64 the map is the identity, so the byte-identity gate is exact.
#
# THE RULE: an author voxel `a` occupies the half-open scaled span
# `[U(a), U(a + 1))`. Adjacency, abutting boxes and solidity are preserved by
# construction, because U is applied to COORDINATES and never to lengths - two
# boxes that met at author y = 18 still meet at U(18), whatever U does to it.

## The grid every generator is written against. Not a knob.
AUTHOR_RES = 64

## The grid to emit. 64 reproduces the committed files byte for byte.
## `python -m tools.parts_author --res 96` is the character v2 grid.
RES = AUTHOR_RES


def U(v: int) -> int:
    """An author coordinate to an output coordinate.

    ROUND HALF UP, and consistently, which is the whole of why this is a
    function and not an inline multiply. Python's `round` is banker's rounding:
    `round(16.5)` is 16 and `round(17.5)` is 18. Used here that would map a
    part's depth of 11 to 16 while the box filling it mapped to 17, and the
    part would be one slice short of itself at some resolutions and not at
    others. Half-up is monotonic and boring, which is what a coordinate map has
    to be.

    AND `math.floor`, NOT `int`. `int` truncates toward zero, so it maps -4.5
    to -4 while mapping 4.5 to 4 - and anchors here are routinely negative: a
    sword is authored in its socket's frame with anchor x = -5, and a tail link
    sits at y = -1. The first version of this function used `int` and moved
    three anchors at RES 64, where the map is supposed to be the identity. The
    byte-identity gate caught it on three files, which is exactly what that
    gate is for.
    """
    return math.floor(v * RES / AUTHOR_RES + 0.5)


def U_len(n: int) -> int:
    """A LENGTH, for the rare thing that is a thickness rather than a position.

    Not the same function: a length has no origin, so it cannot be the
    difference of two mapped coordinates without depending on where it starts.
    At least 1, because a one-voxel rim that scales to nothing is not a thinner
    rim, it is a missing one.
    """
    return max(1, math.floor(n * RES / AUTHOR_RES + 0.5))


def _axis_map(n: int) -> list[int]:
    """For each output index along an axis of author length `n`, the author
    index it came from. Length `U(n)` by construction."""
    out: list[int] = []
    for a in range(n):
        out.extend([a] * (U(a + 1) - U(a)))
    return out


def _scale_anchor(a: float) -> float:
    """An anchor is a LATTICE point and may sit on a half voxel - the top
    centre of a 9-wide leg is x = 4.5. So it is scaled by interpolating U
    rather than by rounding through it: at RES 96 a depth-11 part becomes 17
    deep and its middle, 5.5, becomes 8.5 and not 8.25. Getting this wrong
    lists the whole part a quarter of a voxel to one side, which is exactly the
    class of error the lattice-versus-index note in VoxelModel warns about."""
    lo = int(a // 1)
    frac = a - lo
    return U(lo) + frac * (U(lo + 1) - U(lo))


# The slot letters, exactly VoxelModel.SLOT_CHARS. `check_slots_match()` below
# is what keeps "exactly" true - these are two copies of one fact in two
# languages, and nothing else would notice them drifting apart.
S = "S"   # skin
s = "s"   # skin, shaded
H = "H"   # hair
E = "E"   # iris
W = "W"   # eye white
M = "M"   # mouth
C = "C"   # cloth
c = "c"   # cloth, dark
L = "L"   # leather
B = "B"   # belt
T = "T"   # tooth
X = "X"   # metal
D = "D"   # wood
# --- Character v2 Stage 1. Lowercase is the darker sibling of its uppercase.
k = "k"   # liner - the fixed near-black at every skin/cloth boundary
v = "v"   # skin, ventral - the countershaded belly, throat, underside of tail
R = "R"   # trim, bright - the raised rim that makes metal read as metal
x = "x"   # metal, dark - the body a bright rim sits on
A = "A"   # scale/mail checker, the lighter of the two adjacent values
a = "a"   # scale/mail checker, the darker
EMPTY = "."

SLOTS = set("SsHEWMCcLBTXDkvRxAa")


def check_slots_match(root) -> None:
    """`SLOTS` above and `VoxelModel.SLOT_CHARS` are one fact in two languages.

    Nothing else in the build would notice them drifting apart: a generator
    that paints a letter the runtime has never heard of writes a part file
    that `VoxelModel.parse()` rejects at load with an error naming a slice and
    a row, which is a long way from the line that caused it. So the generator
    refuses to write anything at all until the two agree.

    Read out of the GDScript by regex rather than by parsing it. That is
    normally a bad idea and is the right one here: the block is a literal
    dictionary of one-character keys, the alternative is a GDScript parser,
    and a regex that stops matching is a loud failure rather than a quiet one.
    """
    import re

    source = (root / "scripts" / "character" / "voxel_model.gd").read_text()
    block = re.search(r"const SLOT_CHARS := \{(.*?)\n\}", source, re.S)
    if block is None:
        raise SystemExit(
            "voxlib: could not find SLOT_CHARS in voxel_model.gd. If the "
            "declaration moved or was reformatted, fix this regex - do not "
            "delete the check.")
    theirs = set(re.findall(r'"(.)":', block.group(1)))
    if theirs != SLOTS:
        raise SystemExit(
            "voxlib: the slot legends disagree.\n"
            "  only in voxel_model.gd: %s\n"
            "  only in voxlib.py:      %s"
            % (sorted(theirs - SLOTS) or "-", sorted(SLOTS - theirs) or "-"))


def _fmt(v: float) -> str:
    """A number the way the existing part files write it: `9`, not `9.0`."""
    if float(v).is_integer():
        return str(int(v))
    return repr(float(v))


def octagon(x0: int, x1: int, z0: int, z1: int, chamfer: int) -> set[tuple[int, int]]:
    """The cells of the box [x0, x1) x [z0, z1) with each corner cut by
    `chamfer`: a cell is dropped when it is fewer than `chamfer` steps from
    a corner along both axes together. Chamfer 2 turns a rectangle into an
    octagon with a two-cell diagonal at each corner, which is rule 4 of the
    look plan applied to a head seen from above."""
    out = set()
    for x in range(x0, x1):
        for z in range(z0, z1):
            dx = min(x - x0, x1 - 1 - x)
            dz = min(z - z0, z1 - 1 - z)
            if dx + dz < chamfer:
                continue
            out.add((x, z))
    return out


class Cells:
    """A bag of voxels keyed by integer position. Shared by Part and Frame."""

    def __init__(self):
        self.cells: dict[tuple[int, int, int], str] = {}

    def put(self, x: int, y: int, z: int, ch: str) -> None:
        assert ch in SLOTS, ch
        self.cells[(x, y, z)] = ch

    def erase(self, x: int, y: int, z: int) -> None:
        self.cells.pop((x, y, z), None)

    def has(self, x: int, y: int, z: int) -> bool:
        return (x, y, z) in self.cells

    def box(self, xr, yr, zr, ch: str) -> None:
        for y in range(*yr):
            for z in range(*zr):
                for x in range(*xr):
                    self.put(x, y, z, ch)

    def prism(self, xr, yr, zr, ch: str, chamfer: int = 2,
              bottom=(), top=()) -> None:
        """A chamfered box. `chamfer` cuts the vertical edges (octagonal in
        plan); `bottom` and `top` are insets per slice counted from that end,
        so `top=(1, 2)` steps the crown in by one and then by two. An inset
        slice keeps whatever chamfer is left after the inset."""
        x0, x1 = xr
        y0, y1 = yr
        z0, z1 = zr
        for y in range(y0, y1):
            inset = 0
            k = y - y0
            if k < len(bottom):
                inset = bottom[k]
            k = y1 - 1 - y
            if k < len(top):
                inset = max(inset, top[k])
            for (x, z) in octagon(x0 + inset, x1 - inset, z0 + inset, z1 - inset,
                                  max(0, chamfer - inset)):
                self.put(x, y, z, ch)

    def front_paint(self, y: int, xr, ch: str, zr=None) -> None:
        """Repaint the front-most cell of each column at height `y`: the cell
        the viewer sees first, whatever the chamfer did to the row."""
        for x in range(*xr):
            zs = [z for (cx, cy, z) in self.cells if cx == x and cy == y
                  and (zr is None or zr[0] <= z < zr[1])]
            if zs:
                self.put(x, y, min(zs), ch)

    def repaint(self, xr, yr, zr, ch: str) -> None:
        """Change the slot of cells that already exist. Never adds one."""
        for y in range(*yr):
            for z in range(*zr):
                for x in range(*xr):
                    if (x, y, z) in self.cells:
                        self.cells[(x, y, z)] = ch

    def bounds(self):
        xs = [p[0] for p in self.cells]
        ys = [p[1] for p in self.cells]
        zs = [p[2] for p in self.cells]
        return (min(xs), max(xs) + 1), (min(ys), max(ys) + 1), (min(zs), max(zs) + 1)

    def count(self) -> int:
        return len(self.cells)


class Part(Cells):
    """A part in its own index space, with an explicit size and anchor."""

    def __init__(self, name: str, size, anchor, notes=None):
        super().__init__()
        self.name = name
        self.w, self.h, self.d = size
        self.anchor = tuple(anchor)
        self.notes: dict[int, str] = dict(notes or {})

    def put(self, x: int, y: int, z: int, ch: str) -> None:
        assert 0 <= x < self.w and 0 <= y < self.h and 0 <= z < self.d, (
            self.name, (x, y, z), (self.w, self.h, self.d))
        super().put(x, y, z, ch)

    def note(self, y: int, text: str) -> None:
        self.notes[y] = text

    def size_out(self) -> tuple[int, int, int]:
        """The part's size on the OUTPUT grid."""
        return (U(self.w), U(self.h), U(self.d))

    def anchor_out(self) -> tuple[float, float, float]:
        return tuple(_scale_anchor(a) for a in self.anchor)

    def slices(self) -> list[list[str]]:
        """The ASCII, on the output grid.

        THE ONLY PLACE RES IS APPLIED. Every cell above was authored, drawn and
        checked at 64; this walks the output grid and asks which author voxel
        each output voxel falls inside. The three axis maps make that a lookup
        rather than arithmetic, so there is no rounding decision taken twice.

        The `w - 1 - col` inversion is the same one it always was and is
        applied on the OUTPUT width: the first character of a row is the left
        of the picture, which is the character's own right. See VoxelModel.
        """
        mx, my, mz = _axis_map(self.w), _axis_map(self.h), _axis_map(self.d)
        out = []
        for y in my:
            rows = []
            for z in mz:
                rows.append("".join(
                    self.cells.get((mx[len(mx) - 1 - col], y, z), EMPTY)
                    for col in range(len(mx))))
            out.append(rows)
        return out

    def frame_cells(self) -> set[tuple[int, int, int]]:
        """Every cell, moved into the frame whose origin is the anchor. Only
        meaningful for a part with an integer anchor, which every head and
        every socket-frame part has - it is how hair learns where the skull
        is."""
        ax, ay, az = self.anchor
        assert all(float(a).is_integer() for a in self.anchor), self.anchor
        return {(x - int(ax), y - int(ay), z - int(az)) for (x, y, z) in self.cells}

    def gd(self, const_name: str, comment: str = "") -> str:
        """The GDScript constant, formatted the way the hand-written files
        were: one slice per group, rows wrapped to the line width, a `# y =`
        note where the author left one."""
        lines = []
        if comment:
            for text in comment.rstrip("\n").split("\n"):
                lines.append(("# " + text).rstrip())
            lines.append("")
        w_out, h_out, d_out = self.size_out()
        lines.append("const %s := {" % const_name)
        lines.append('\t"size": Vector3i(%d, %d, %d),' % (w_out, h_out, d_out))
        lines.append('\t"anchor": Vector3(%s, %s, %s),' % tuple(
            _fmt(a) for a in self.anchor_out()))
        lines.append('\t"slices": [')
        per_line = max(1, (76 - 3) // (w_out + 4))
        # Notes are keyed by AUTHOR slice; a note lands on the first output
        # slice that author slice became, so "y = 5, the mouth" still points at
        # the mouth whatever the grid is.
        note_at = {}
        for a in range(self.h):
            if a in self.notes:
                note_at[U(a)] = self.notes[a]
        for y, rows in enumerate(self.slices()):
            note = note_at.get(y)
            if note is not None:
                lines.append("\t\t# y = %d, %s" % (y, note))
            quoted = ['"%s"' % r for r in rows]
            chunks = [quoted[i:i + per_line] for i in range(0, len(quoted), per_line)]
            for i, chunk in enumerate(chunks):
                head = "\t\t[" if i == 0 else "\t\t "
                tail = "]," if i == len(chunks) - 1 else ","
                lines.append(head + ", ".join(chunk) + tail)
        lines.append("\t],")
        lines.append("}")
        return "\n".join(lines)


class Frame(Cells):
    """Cells authored in the frame of another part - a head, a socket. The
    origin is that part's anchor; `to_part()` finds the bounding box and
    derives the anchor that puts the cells back where they were authored.

    A frame may have cells at negative coordinates: a crest above a head has
    positive y and a beard below it has negative y, and both are legal, as
    the hair file has always said."""

    def to_part(self, name: str, notes=None) -> Part:
        (x0, x1), (y0, y1), (z0, z1) = self.bounds()
        part = Part(name, (x1 - x0, y1 - y0, z1 - z0), (-x0, -y0, -z0))
        for (x, y, z), ch in self.cells.items():
            part.put(x - x0, y - y0, z - z0, ch)
        if notes:
            for y, text in notes.items():
                part.note(y - y0, text)
        return part

    def fill_outside(self, skull: set, xr, yr, zr, ch: str, footprint=None) -> None:
        """Paint every cell of the box that is not skull. If `footprint` is
        given (a set of (x, z)), cells inside it are also skipped - which is
        how a bob wraps a head without ever entering it: the chamfered
        corners are outside the footprint's octagon and get filled, the
        interior is inside and does not."""
        for y in range(*yr):
            for z in range(*zr):
                for x in range(*xr):
                    if (x, y, z) in skull:
                        continue
                    if footprint is not None and (x, z) in footprint:
                        continue
                    self.put(x, y, z, ch)


def gd_file(class_name: str, doc: str, blocks: list[str], parts: dict[str, str],
            generator: str, extra: str = "") -> str:
    """Assemble a parts file. `doc` is the class docstring without the `## `
    prefixes; `blocks` are the formatted constants in order; `parts` maps the
    bone-table name to the constant it refers to."""
    out = ["class_name %s" % class_name, ""]
    for line in doc.strip("\n").split("\n"):
        out.append(("## " + line).rstrip())
    out.append("##")
    out.append("## GENERATED by tools/parts_author/%s. Re-run" % generator)
    out.append("## `python -m tools.parts_author` after editing the generator. Editing the")
    out.append("## ASCII by hand is legal - say so on this line if you do, so the next")
    out.append("## person knows the generator is behind.")
    out.append("")
    for block in blocks:
        out.append("")
        out.append(block)
        out.append("")
    out.append("")
    out.append("## Every part in this set, by the name a bone table refers to it with.")
    out.append("const PARTS := {")
    for key, const in parts.items():
        out.append('\t"%s": %s,' % (key, const))
    out.append("}")
    if extra:
        out.append("")
        out.append("")
        out.append(extra.rstrip("\n"))
    out.append("")
    return "\n".join(out)


# --- Look v2 Stage 5: the face -----------------------------------------------
#
# ONE ROUTINE, FOUR RACES. Look v1 authored each face by hand in its own module
# and the four drifted: three eye geometries, two brow conventions, mouths from
# four to eight voxels wide. The spec in docs/plans/look-v2.md Stage 5 is one
# spec, so this is one function and each race passes its own numbers.
#
# WHY THE EYES ARE SOLID AND PROUD. A 4 x 4 white with a 2 x 2 iris inside it
# is five values across four voxels, and at 40 m the white wins and the figure
# reads as having no eyes at all. A 2 x 4 block of pure iris colour, standing
# one voxel out of the face the way the nose does, is one shape and one value:
# it survives being two pixels tall, and it catches the sun on its own front
# face so it reads at every hour rather than only at noon.


def solid_eyes(p, x_centre: int, y0: int, z_face: int, gap: int = 6,
               width: int = 2, height: int = 4, catchlight: bool = True,
               clear=None) -> None:
    """Two solid iris blocks, one voxel proud of the face plane at `z_face`.

    `x_centre` is the face's centre line, `gap` the space between the two
    inner edges. `clear` is an (xr, yr, zr) region repainted back to skin
    first, which is how the old whites are removed - repaint never adds a
    cell, so this cannot punch a hole in the head.
    """
    if clear is not None:
        p.repaint(clear[0], clear[1], clear[2], S)
    inner = gap // 2
    for sign in (-1, 1):
        x0 = x_centre - inner - width if sign < 0 else x_centre + inner
        p.box((x0, x0 + width), (y0, y0 + height), (z_face - 1, z_face), E)
        if catchlight:
            # The TOP INNER corner, one voxel, and never more: it is a
            # highlight, and two of them read as a second pair of pupils.
            cx = x0 + width - 1 if sign < 0 else x0
            p.put(cx, y0 + height - 1, z_face - 1, W)


def hair_brow(p, xr, y: int, z_face: int) -> None:
    """One row of hair-coloured brow on the face plane. Rule: a brow is the
    hair's colour or it is nothing - a brow in shaded skin is a smudge at any
    distance past arm's length."""
    p.repaint(xr, (y, y + 1), (z_face, z_face + 1), H)
