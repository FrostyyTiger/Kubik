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

# The slot letters, exactly VoxelModel.SLOT_CHARS.
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
EMPTY = "."

SLOTS = set("SsHEWMCcLBTXD")


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

    def slices(self) -> list[list[str]]:
        out = []
        for y in range(self.h):
            rows = []
            for z in range(self.d):
                rows.append("".join(
                    self.cells.get((self.w - 1 - col, y, z), EMPTY)
                    for col in range(self.w)))
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
        lines.append("const %s := {" % const_name)
        lines.append('\t"size": Vector3i(%d, %d, %d),' % (self.w, self.h, self.d))
        lines.append('\t"anchor": Vector3(%s, %s, %s),' % tuple(_fmt(a) for a in self.anchor))
        lines.append('\t"slices": [')
        per_line = max(1, (76 - 3) // (self.w + 4))
        for y, rows in enumerate(self.slices()):
            note = self.notes.get(y)
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
