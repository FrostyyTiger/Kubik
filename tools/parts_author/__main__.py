"""Write every generated part file.

    python -m tools.parts_author            # from the repo root

Each module renders one file under scripts/character/parts/. The runtime
never imports Python; it parses the ASCII these write, exactly as it parsed
the ASCII that used to be typed.
"""

from pathlib import Path

from . import human, elf, dwarf, lizardfolk, hair, gear, critter

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
    for name, render in FILES.items():
        text = render()
        path = OUT / name
        path.write_text(text, encoding="utf-8", newline="\n")
        print("wrote %s (%d lines)" % (path.relative_to(ROOT), text.count("\n")))


if __name__ == "__main__":
    main()
