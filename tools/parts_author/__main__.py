"""Write every generated part file.

    python -m tools.parts_author            # from the repo root
    python -m tools.parts_author --res 96   # on the character v2 grid

Each module renders one file under scripts/character/parts/. The runtime
never imports Python; it parses the ASCII these write, exactly as it parsed
the ASCII that used to be typed.

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

from . import human, elf, dwarf, lizardfolk, hair, gear, critter, voxlib

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "scripts" / "character" / "parts"

FILES = {
    "parts_human.gd": human.render,
    "parts_elf.gd": elf.render,
    "parts_dwarf.gd": dwarf.render,
    "parts_lizardfolk.gd": lizardfolk.render,
    "parts_hair.gd": hair.render,
    "parts_gear.gd": gear.render,
    "parts_critter.gd": critter.render,
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
    for name, render in FILES.items():
        text = render()
        path = OUT / name
        path.write_text(text, encoding="utf-8", newline="\n")
        print("wrote %s (%d lines)" % (path.relative_to(ROOT), text.count("\n")))


if __name__ == "__main__":
    main()
