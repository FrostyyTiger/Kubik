"""Write every generated part file.

    python -m tools.parts_author            # from the repo root
    python -m tools.parts_author --res 96   # on the character v2 grid

Each module renders TWO files from one set of in-memory parts: the ASCII
data at assets/characters/parts/<module>.json, which is what the game loads
through `PartsData`, and - for now - the GDScript constants under
scripts/character/parts/ that the data is replacing. The runtime never
imports Python; it parses the same ASCII rows either way.

THE TWO EMITTERS SHARE THEIR `Part` OBJECTS, one call, one build. That is
the only reason a byte-identical `.gd` says anything at all about whether
the JSON drifted: if they were built separately the gate below would be
comparing a generator against itself.

`--res` is the whole point of character v2 Stage 2: every generator is
written against the 64 grid and knows nothing about the flag, and `voxlib`
scales at output. **`--res 64` must produce a zero diff against what is
committed.** That is the gate, and it is the only check that can prove a
change to the authoring kit did not move a voxel - so run it after touching
anything in this package:

    python -m tools.parts_author && git diff --stat scripts/character/parts/

Note what the gate CANNOT prove: at 64 every scale is the identity, so it
says nothing about whether the scaling is right. That is what the height and
part-size self-tests are for, on the far side of the grid change.
"""

import sys
from pathlib import Path

from . import human, elf, dwarf, lizardfolk, hair, gear, critter, armour, voxlib

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "scripts" / "character" / "parts"
OUT_JSON = ROOT / "assets" / "characters" / "parts"

MODULES = {
    "human": human.render,
    "elf": elf.render,
    "dwarf": dwarf.render,
    "lizardfolk": lizardfolk.render,
    "hair": hair.render,
    "gear": gear.render,
    "armour": armour.render,
    "critter": critter.render,
}


def main() -> None:
    argv = sys.argv[1:]
    if "--res" in argv:
        voxlib.RES = int(argv[argv.index("--res") + 1])
        if voxlib.RES < voxlib.AUTHOR_RES:
            # Not forbidden, but say so: below the author grid the map is
            # lossy - two author voxels can land on one output voxel and the
            # narrower of two abutting shapes disappears rather than thinning.
            print("warning: --res %d is below the author grid of %d; detail "
                  "will be dropped, not thinned" % (voxlib.RES, voxlib.AUTHOR_RES))
        print("grid: %d model voxels to a 2.00 m human (author grid %d)" % (
            voxlib.RES, voxlib.AUTHOR_RES))

    # Before anything is written: the slot legend here and the one in
    # voxel_model.gd have to be the same set. See voxlib.check_slots_match.
    voxlib.check_slots_match(ROOT)
    OUT_JSON.mkdir(parents=True, exist_ok=True)
    for name, render in MODULES.items():
        gd_text, json_text = render()
        # A `None` for the GDScript means that module's `.gd` is HAND-WRITTEN
        # and permanent - hair, gear and critter, whose files kept the tables
        # and lookups no JSON can hold and lost the ASCII. Never overwrite one.
        written = [(OUT_JSON / ("%s.json" % name), json_text)]
        if gd_text is not None:
            written.insert(0, (OUT / ("parts_%s.gd" % name), gd_text))
        for path, text in written:
            path.write_text(text, encoding="utf-8", newline="\n")
            print("wrote %s (%d lines)" % (path.relative_to(ROOT), text.count("\n")))


if __name__ == "__main__":
    main()
