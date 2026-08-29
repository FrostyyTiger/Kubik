"""Three gear placeholders, authored in the frame of the socket each hangs on."""

from .voxlib import Frame, Part, json_file, X, D, c, C, B


def sword() -> Part:
    f = Frame()
    f.box((7, 9), (0, 6), (-1, 1), D)       # grip
    f.box((5, 11), (6, 8), (-1, 1), X)      # crossguard
    f.box((7, 9), (8, 26), (-1, 1), X)      # blade
    f.box((7, 8), (26, 28), (-1, 1), X)     # the point, one column
    return f.to_part("SWORD")


SWORD_COMMENT = """--- A wooden sword, for `hand_r` ---------------------------------------------

28 voxels: six of grip, two of crossguard, twenty of blade. The `hand_r`
socket sits at the far end of the arm bone, on its centre line, so the sword
is offset OUTBOARD - x +5 to +11 - which clears the widest hand in the game
(the dwarf's, ten voxels across, so five from the centre line) exactly, and
reads as carried at the shoulder.

Rising rather than hanging, and that is forced rather than chosen: a
28-voxel sword pointing down from a dwarf's hand, which is eleven voxels
off the ground, would be seventeen voxels underground."""


def tunic() -> Part:
    f = Frame()
    f.box((-4, 4), (-6, 6), (-1, 0), c)
    f.box((-1, 1), (-6, 6), (-1, 0), C)     # a lighter stripe down the middle
    return f.to_part("TUNIC")


TUNIC_COMMENT = """--- A tunic overlay, for `chest` ---------------------------------------------

The `chest` socket sits ON the front face of the torso, so a panel one voxel
in front of it is one voxel outside the body for every race - which is what
"a shell one voxel outside the torso" means when the torsos are 8, 11 and 14
voxels deep. ONE voxel and not two, because the dwarf's beard hangs over its
chest and starts one voxel further out; a thicker panel would be inside it.

Eight wide rather than the torso's width, because the torso's width is 12
on an elf and 26 on a dwarf and one placeholder cannot be both. It reads as
a tabard, which is exactly what a placeholder for a chest item should read
as."""


def pendant() -> Part:
    # ONE VOXEL FURTHER OUT SINCE CHARACTER V2 STAGE 3, and the reason is the
    # dwarf's beard. Character v1's status doc already recorded that this
    # placeholder "floats slightly proud of a narrow chest because a cord that
    # sloped back would put two voxels inside a dwarf" - the clearance was one
    # voxel at 1/16 of a block, which is 3.1 cm. At 1/24 a voxel is 2.1 cm, so
    # the same one-voxel standoff is a third less room, and the beard, which
    # scaled with everything else, closed on it: the gear-socket self-test
    # reported 30 cells of pendant inside the dwarf's beard.
    #
    # Moved rather than the test loosened. It is a placeholder proving a
    # socket, and a placeholder that intersects a dwarf is measuring the
    # placeholder instead of the socket.
    f = Frame()
    f.box((-3, 3), (-2, 0), (-14, -12), X)   # the clasp
    f.box((-1, 1), (-4, -2), (-14, -12), X)
    f.box((-1, 1), (-8, -4), (-14, -12), B)  # the cord
    f.box((-2, 2), (-12, -8), (-14, -12), X) # the medallion
    return f.to_part("PENDANT")


PENDANT_COMMENT = """--- A pendant on a cord, for `neck` ------------------------------------------

The `neck` socket is at the TOP of the torso and on its centre line, so
anything hanging straight down from it is inside the chest. This hangs
eleven voxels forward instead, which clears the deepest torso in the game
(the dwarf's, 7 voxels to the front face) AND the dwarf's beards, which
hang three voxels in front of a face that is itself a voxel proud of the
chest - the beard stops at z = -11 and the pendant starts there.

IT THEREFORE FLOATS WELL PROUD of a human's or an elf's chest, and a cord
that sloped back to the neck would look better and would put voxels inside
a dwarf's beard. For an item whose entire job is to prove that a socket
exists and follows the body, zero intersection on all four races is worth
more than a prettier cord. The gear plan can do better with per-race
offsets."""


DOC = """Three placeholders that hang on three sockets.

THIS IS NOT A GEAR SYSTEM. There are no slots on CharacterDef, nothing on
the wire, and no stats. THE SOCKETS ARE THE DELIVERABLE; these three items
exist to prove them - that a thing attached to `hand_r` swings with the arm,
a thing on `chest` rides the sprint lean, and a thing on `neck` stays put
through a sit. The gear plan owns everything past that.

AUTHORED IN THE SOCKET'S OWN FRAME, the way hair is authored in the head's:
the origin is the socket, so a sword is described as "rising from the hand,
outboard of the arm" rather than in a coordinate system nobody can picture.

EVERY PLACEHOLDER IS PLACED CLEAR OF EVERY BODY, all four races, and the
self-test checks it voxel by voxel rather than by eye. That is harder than
it sounds - the races differ by nearly a factor of two in torso depth, and
the dwarf's beard reaches its belt - and it is the reason the pendant hangs
a long way proud of the chest rather than resting on it. A placeholder that
intersects a dwarf would be measuring the placeholder instead of the
socket."""



def render() -> str:
    # THE KEY IS THE SOCKET, because `PLACEHOLDERS` is the only index these
    # three have ever had and a placeholder exists to prove one socket.
    built = [
        ("hand_r", "SWORD", sword(), SWORD_COMMENT),
        ("chest", "TUNIC", tunic(), TUNIC_COMMENT),
        ("neck", "PENDANT", pendant(), PENDANT_COMMENT),
    ]
    parts = {key: part for key, _c, part, _cm in built}
    comments = {key: comment for key, _c, _p, comment in built}

    return json_file("gear.py", DOC, parts, comments)
