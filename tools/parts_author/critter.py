"""The critter, scaled exactly x2 from the character v1 ASCII.

It is a test rig, not a character: it exists to fail loudly if anything in
the pipeline is secretly humanoid, and the only thing that matters about
its shape is that it is the same shape it was. So the v1 ASCII is embedded
here as data and every voxel becomes eight, which is the one transformation
that provably changes nothing about it.
"""

from .voxlib import Part

# The character v1 parts, verbatim, at 1/8 of a block.
V1 = {
    "BODY": ((6, 6, 14), (3, 0, 7), [
        ["......", "SSSSSS", "SSSSSS", "SSSSSS", "SSSSSS", "SSSSSS", "SSSSSS",
         "SSSSSS", "SSSSSS", "SSSSSS", "SSSSSS", "SSSSSS", "SSSSSS", "......"],
        ["SSSSSS"] * 14,
        ["SSSSSS"] * 14,
        ["SSSSSS"] * 14,
        ["SSSSSS"] * 14,
        ["......", "SSSSSS", "SSSSSS", "SSSSSS", "SSSSSS", "SSSSSS", "SSSSSS",
         "SSSSSS", "SSSSSS", "SSSSSS", "SSSSSS", "SSSSSS", "SSSSSS", "......"],
    ]),
    "HEAD": ((6, 6, 9), (3, 0, 9), [
        ["..TT..", "..SS..", "..SS..", "SSSSSS", "SSSSSS", "SSSSSS", "SSSSSS",
         "SSSSSS", "SSSSSS"],
        ["..SS..", "..SS..", "..SS..", "SSSSSS", "SSSSSS", "SSSSSS", "SSSSSS",
         "SSSSSS", "SSSSSS"],
        ["..SS..", "..SS..", "..SS..", "SSSSSS", "SSSSSS", "SSSSSS", "SSSSSS",
         "SSSSSS", "SSSSSS"],
        ["......", "......", "......", "SWESES", "SSSSSS", "SSSSSS", "SSSSSS",
         "SSSSSS", "SSSSSS"],
        ["......", "......", "......", "SSSSSS", "SSSSSS", "SSSSSS", "SSSSSS",
         "SSSSSS", "SSSSSS"],
        ["......", "......", "......", "HSSSSH", "HSSSSH", "SSSSSS", "SSSSSS",
         "SSSSSS", "SSSSSS"],
    ]),
    "LEG": ((2, 5, 2), (1, 5, 1), [
        ["TT", "SS"],
        ["SS", "SS"],
        ["SS", "SS"],
        ["SS", "SS"],
        ["SS", "SS"],
    ]),
    "TAIL_1": ((2, 2, 4), (1, 0, 0), [
        ["SS", "SS", "SS", "SS"],
        ["SS", "SS", "SS", "SS"],
    ]),
    "TAIL_2": ((2, 2, 3), (1, 0, 0), [
        ["SS", "ss", "ss"],
        ["SS", "ss", "ss"],
    ]),
}


def scaled(name: str) -> Part:
    (w, h, d), (ax, ay, az), slices = V1[name]
    p = Part(name, (w * 2, h * 2, d * 2), (ax * 2, ay * 2, az * 2))
    for y, rows in enumerate(slices):
        for z, row in enumerate(rows):
            for col, ch in enumerate(row):
                if ch == ".":
                    continue
                x = w - 1 - col
                for dx in (0, 1):
                    for dy in (0, 1):
                        for dz in (0, 1):
                            p.put(x * 2 + dx, y * 2 + dy, z * 2 + dz, ch)
    return p


DOC = """A four-legged thing the size of a large dog.

IT EXISTS TO FAIL LOUDLY IF ANY OF THIS IS SECRETLY HUMANOID. It has no
`torso`, no `hips`, no arms and four legs, so every place in the pipeline
that quietly assumed a two-legged skeleton - the mesher, the rig, the chain
rule, the animator - either works on it or does not. Nothing else in this
plan could have found those assumptions, because everything else in this
plan is a person.

GALLERY ONLY. No AI, no scene, no spawning, no CharacterDef. It is a model
that walks in a strip, and it is what the first-enemy plan starts from.

Shoulder height is 22 voxels, 0.69 m, which is a big dog. The body is
twenty-eight voxels long, so it is longer than it is tall by two to one -
the proportion that makes a quadruped read as a quadruped rather than as a
person on all fours.

SCALED EXACTLY x2 FROM CHARACTER V1 when the model voxel halved. It is a
test rig, and the only thing that matters about its shape is that it is the
same shape it was - so every v1 voxel became eight and nothing else
changed. It has no chamfers and no Deco; the first-enemy plan draws the
first real animal."""

BODY_COMMENT = """--- Body ---------------------------------------------------------------------

12 wide, 12 tall, 28 long. The anchor is at the middle of its length and the
bottom of its height, so the four leg sockets hang from it symmetrically and
the whole animal sits on top of its legs."""

HEAD_COMMENT = """--- Head ---------------------------------------------------------------------

12 wide, 12 tall, 12 of skull plus 6 of snout. The anchor is at the BACK of
the head - z 18 - so the head grows forward from the neck joint, which is
where a quadruped's head hangs from."""

LEG_COMMENT = """--- Leg ----------------------------------------------------------------------

4 x 10 x 4, anchored at the TOP so it swings from the shoulder, exactly as a
humanoid leg does. Authored once and used four times: the gait table decides
which of them are in phase, not the geometry."""

TAIL_COMMENT = """--- Tail ---------------------------------------------------------------------

Two segments on the SAME generic chain rule the lizardfolk uses. That is half
the point of building this animal: if the chain rule had quietly assumed
three links or a humanoid parent, this is where it would show."""



def render() -> str:
    from .voxlib import json_file
    built = [
        ("body", scaled("BODY"), BODY_COMMENT),
        ("head", scaled("HEAD"), HEAD_COMMENT),
        ("leg", scaled("LEG"), LEG_COMMENT),
        ("tail_1", scaled("TAIL_1"), TAIL_COMMENT),
        ("tail_2", scaled("TAIL_2"), ""),
    ]
    parts = {key: part for key, part, _cm in built}
    comments = {key: comment for key, _p, comment in built}
    return json_file("critter.py", DOC, parts, comments)
