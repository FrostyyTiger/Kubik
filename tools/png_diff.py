#!/usr/bin/env python3
"""How far apart are two gallery runs, per sheet, in numbers.

    ~/.venvs/kubik/bin/python tools/png_diff.py build/character/v2-0 build/character/v2-1
    ~/.venvs/kubik/bin/python tools/png_diff.py --strict A B      # exit 1 if any sheet is over tolerance

`compare_sheets.py` is the other half of this and answers a different
question. It builds side-by-side strips, because "is this better" is answered
by looking. This one answers "did anything move that I did not mean to move",
because a stage that was supposed to change one race must not have changed the
critter, and nobody can see a delta of 3 by looking.


WHY THERE IS A TOLERANCE AT ALL, which is character v2 Stage 0's finding.

The obvious gate is "the sheets are identical". It does not work, and it does
not work on the GPU either - which was a surprise, because the IoU harness on
the same box is bit-stable across runs and the counts reproduce exactly.

Measured on ganymede (RTX 3070 Ti, Vulkan 1.4.329, Forward+), two runs of the
SAME COMMIT, back to back:

    22 of 53 sheets bit-identical      every frozen-pose strip, every mask
                                       sheet, every swatch sheet, the critter
    31 of 53 sheets differ             every LIT sheet with a character in it

    worst: variants-elf.png, 14,123 px (1.53%), worst channel delta 211
    typical: a few hundred px, 0.01% to 0.6%
    of every differing pixel, 72% differ by exactly 1

So it is overwhelmingly one least-significant bit spread across lit surfaces,
plus several hundred antialiased edge pixels that flip coverage. It is not the
animator: freezing every subject's `_process` (blink is real randomness by
design, breath runs on wall-clock time) changed none of it. It is not sheet
ordering or state left over from the previous sheet: a run of `--sheet closeup`
ALONE, twice, differs the same way. It is the lit path, below anything this
repo controls.

The consequences, and they are the reason this file exists:

  - COUNTS GATE STAGES. Triangles, voxels, bones, parts, IoU, outline events,
    hashes. Those reproduce exactly and always have.
  - MASK SHEETS AND FROZEN STRIPS CAN BE DIFFED EXACTLY. They are bit-stable,
    so `anim-human-walk.png` unchanged really does mean the human's walk did
    not change.
  - LIT SHEETS CANNOT. Comparing them means comparing these numbers against a
    tolerance, and the tolerance below is set from the measurement above with
    room to spare - not guessed.

A sheet OVER tolerance means something really moved. A sheet under it means
nothing did, and a human still has to look at the picture to know whether what
moved was an improvement.
"""

import sys
from pathlib import Path

from PIL import Image, ImageChops

ROOT = Path(__file__).resolve().parent.parent

# Set from the Stage 0 measurement, with room. The worst honest run-to-run
# noise seen was 1.53% of pixels; anything over 3% is a real change. The delta
# ceiling is deliberately NOT tight: edge coverage flips reach 230, so a big
# delta on a few pixels says nothing, and only the AREA is diagnostic.
AREA_TOLERANCE_PCT = 3.0

# Sheets that are bit-stable and are therefore held to it exactly. Prefixes.
EXACT = ("anim-", "critter-", "gear-walk", "masks-", "swatch", "testcube")


def is_exact(name: str) -> bool:
    return any(name.startswith(p) for p in EXACT)


def compare(pa: Path, pb: Path) -> dict:
    a = Image.open(pa).convert("RGB")
    b = Image.open(pb).convert("RGB")
    if a.size != b.size:
        return {"size_mismatch": (a.size, b.size)}
    d = ImageChops.difference(a, b)
    bbox = d.getbbox()
    if bbox is None:
        return {"n": 0, "worst": 0, "pct": 0.0, "bbox": None}
    # Max over the three channels, as one band.
    flat = max_band(d)
    hist = flat.histogram()
    n = sum(hist[1:])
    worst = max((i for i, c in enumerate(hist) if c), default=0)
    total = a.size[0] * a.size[1]
    return {"n": n, "worst": worst, "pct": 100.0 * n / total, "bbox": bbox}


def max_band(img: Image.Image) -> Image.Image:
    r, g, b = img.split()
    return ImageChops.lighter(ImageChops.lighter(r, g), b)


def main(argv: list[str]) -> int:
    strict = "--strict" in argv
    argv = [a for a in argv if a != "--strict"]
    if len(argv) != 2:
        print(__doc__.strip().split("\n\n")[1])
        return 2
    a_dir, b_dir = (Path(p) if Path(p).is_absolute() else ROOT / p for p in argv)
    names = sorted(p.name for p in a_dir.glob("*.png"))
    if not names:
        print("no PNGs in %s" % a_dir)
        return 2

    print("%-38s %9s %7s %7s  %s" % ("sheet", "differ", "worst", "% px", "verdict"))
    over = 0
    identical = 0
    for name in names:
        pb = b_dir / name
        if not pb.exists():
            print("%-38s %9s" % (name, "MISSING"))
            over += 1
            continue
        r = compare(a_dir / name, pb)
        if "size_mismatch" in r:
            print("%-38s  size %s vs %s  CHANGED" % (name, *r["size_mismatch"]))
            over += 1
            continue
        if r["n"] == 0:
            identical += 1
            print("%-38s %9s" % (name, "identical"))
            continue
        limit = 0.0 if is_exact(name) else AREA_TOLERANCE_PCT
        bad = r["pct"] > limit
        over += bad
        print("%-38s %9d %7d %6.3f%%  %s" % (
            name, r["n"], r["worst"], r["pct"],
            "CHANGED" if bad else "noise"))

    print("\n%d identical, %d over tolerance, %d sheets" % (identical, over, len(names)))
    if strict and over:
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
