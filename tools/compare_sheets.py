#!/usr/bin/env python3
"""Side-by-side strips of the same tour shot across several labelled runs.

    python tools/compare_sheets.py look2-base look2-0-transfer [more labels]
    python tools/compare_sheets.py --gl look2-base look2-0-transfer

Every shot name that exists in `build/tour/<label>/` for the FIRST label gets
one strip: the same shot from each label in order, left to right, each under a
caption naming the label it came from. Strips land in `build/tour/compare/`.

WHY A STRIP AND NOT A DIFF. A pixel diff answers "did anything change", which
is never the question here - a stage that changes a colour path changes every
pixel. The question is "is this better", and that is answered by looking at
three of them next to each other with their names attached.

`--gl` does the same for the `<label>-gl` directories, so the Compatibility
sets are compared with each other and never against a Forward+ set.

PIL only. On ganymede that means a venv:
    ~/.venvs/kubik/bin/python tools/compare_sheets.py ...
"""

import sys
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
TOUR = ROOT / "build" / "tour"
OUT = TOUR / "compare"

CAPTION_H = 28
PAD = 6
BG = (24, 24, 28)
FG = (235, 235, 230)


def strip(shot: str, labels: list[str], paths: list[Path]) -> Image.Image:
    tiles = [Image.open(p).convert("RGB") for p in paths]
    h = min(t.height for t in tiles)
    tiles = [t if t.height == h else t.resize(
        (round(t.width * h / t.height), h), Image.LANCZOS) for t in tiles]

    w = sum(t.width for t in tiles) + PAD * (len(tiles) + 1)
    out = Image.new("RGB", (w, h + CAPTION_H + PAD * 2), BG)
    draw = ImageDraw.Draw(out)
    x = PAD
    for tile, label in zip(tiles, labels):
        out.paste(tile, (x, CAPTION_H + PAD))
        draw.text((x + 4, 8), f"{shot}  -  {label}", fill=FG)
        x += tile.width + PAD
    return out


def main(argv: list[str]) -> int:
    gl = "--gl" in argv
    labels = [a for a in argv if not a.startswith("--")]
    if len(labels) < 2:
        print(__doc__)
        return 2
    if gl:
        labels = [f"{lab}-gl" for lab in labels]

    dirs = [TOUR / lab for lab in labels]
    missing = [d for d in dirs if not d.is_dir()]
    if missing:
        for d in missing:
            print(f"no such tour set: {d.relative_to(ROOT)}")
        return 1

    OUT.mkdir(parents=True, exist_ok=True)
    shots = sorted(p.stem for p in dirs[0].glob("*.png"))
    if not shots:
        print(f"no shots in {dirs[0].relative_to(ROOT)}")
        return 1

    written = 0
    for shot in shots:
        paths, have = [], []
        for lab, d in zip(labels, dirs):
            p = d / f"{shot}.png"
            if p.exists():
                paths.append(p)
                have.append(lab)
        if len(paths) < 2:
            print(f"  {shot}: only in {have[0] if have else 'nothing'}, skipped")
            continue
        name = f"{shot}-{'-vs-'.join(have)}.png"
        strip(shot, have, paths).save(OUT / name)
        print(f"  -> build/tour/compare/{name}")
        written += 1
    print(f"{written} strips in build/tour/compare")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
