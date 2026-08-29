"""Write every generated part file.

    python -m tools.parts_author            # from the repo root
    python -m tools.parts_author --res 96   # on the character v2 grid

Each module writes one file: assets/characters/parts/<module>.json, which is
what `PartsData` loads and what `VoxelModel.parse()` walks. The runtime never
imports Python; it reads the same ASCII rows these write.

Three modules keep a hand-written GDScript file in scripts/character/parts/ -
`PartsHair`, `PartsGear`, `PartsCritter` - holding the option tables, the
socket index and the critter's dimension and bone tables. **Nothing here
writes those.** They are permanent, edited by hand, and overwriting one is
the one accident this package must never have.

`--res` is the whole point of character v2 Stage 2: every generator is
written against the 64 grid and knows nothing about the flag, and `voxlib`
scales at output. **`--res 64` must produce a zero diff against what is
committed.** That is the gate, and it is the only check that can prove a
change to the authoring kit did not move a voxel - so run it after touching
anything in this package:

    python -m tools.parts_author && git diff --stat assets/characters/parts/

It moved from the `.gd` to the `.json` in parts-data v1 and lost nothing:
the same `Part` objects wrote both files for the length of that epic, the
byte-identity held on every one of them, and the self-test's test 36 carries
the claim forward as eight frozen hashes.

Note what the gate CANNOT prove: at 64 every scale is the identity, so it
says nothing about whether the scaling is right. That is what the height and
part-size self-tests are for, on the far side of the grid change.
"""

import sys
from pathlib import Path

from . import human, elf, dwarf, lizardfolk, hair, gear, critter, armour, voxlib

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets" / "characters" / "parts"

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
    OUT.mkdir(parents=True, exist_ok=True)
    for name, render in MODULES.items():
        text = render()
        path = OUT / ("%s.json" % name)
        path.write_text(text, encoding="utf-8", newline="\n")
        print("wrote %s (%d lines)" % (path.relative_to(ROOT), text.count("\n")))


if __name__ == "__main__":
    main()
