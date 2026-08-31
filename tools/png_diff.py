#!/usr/bin/env python3
"""How far apart are two gallery runs, per sheet, in numbers.

    ~/.venvs/kubik/bin/python tools/png_diff.py build/character/v2-0 build/character/v2-1
    ~/.venvs/kubik/bin/python tools/png_diff.py --strict A B      # exit 1 if any sheet is over tolerance

Two things were added by distance v3 Stage 0, and both exist because "the far
country stops being mush" is a claim that needs a number:

    # THE FLECK NUMBER. Mean |dL| against the 4-neighbours, over a row band.
    ~/.venvs/kubik/bin/python tools/png_diff.py --local-contrast --rows 0:300 build/tour/base

    # A BAND DIFF. Two runs compared over the far band only, in luma levels.
    ~/.venvs/kubik/bin/python tools/png_diff.py --rows 0:300 build/tour/a build/tour/b

`--rows A:B` is not decoration. Distance v2 measured that a tour shot is
bit-reproducible in the FAR BAND (rows 0-300: mean |dL| 0.0000, worst 0.0) and
is NOT in the near one (rows 500-720: worst 48.1), because the flora that has
finished streaming when the shutter opens differs between runs. So a
whole-frame diff of a tour pair proves nothing, and every per-pixel number in
distance v2's and v3's status docs says which rows it came from. This flag is
how it says it.

The fleck number itself is the epic's own instrument. Mush is a far band whose
neighbouring pixels agree; a block-surfaced far country is one where they do
not. It is read against a baseline of the same shot, and the NEAR field's own
band (rows 500-720) is the reference for "what blocks are supposed to look
like".

Needs numpy for the two new modes (`pip install numpy` in the kubik venv); the
original per-sheet comparison does not.

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


# --- THE ROW BAND, AND THE FLECK NUMBER (distance v3 Stage 0) ----------------
#
# Rec. 709 luminance on the sRGB values as they sit in the file, so a "level"
# here is a level of the 0-255 encoding and matches what distance v2's tables
# report. NOT linearised: the question is what the eye sees on the screen, and
# the screen is what the PNG holds.
LUMA = (0.2126, 0.7152, 0.0722)


def _need_numpy():
    try:
        import numpy as np
    except ImportError:  # pragma: no cover - environment, not logic
        print("this mode needs numpy: ~/.venvs/kubik/bin/pip install numpy")
        raise SystemExit(2)
    return np


def luma_band(path: Path, rows: tuple[int, int] | None):
    """The image's luminance as a float array, cropped to `rows`."""
    np = _need_numpy()
    a = np.asarray(Image.open(path).convert("RGB"), dtype=np.float64)
    if rows is not None:
        a = a[rows[0]:rows[1]]
    return a[:, :, 0] * LUMA[0] + a[:, :, 1] * LUMA[1] + a[:, :, 2] * LUMA[2]


def local_contrast(path: Path, rows: tuple[int, int] | None) -> dict:
    """THE FLECK NUMBER: mean |dL| against the 4-neighbours, over the band.

    Averaged over every ADJACENT PAIR rather than over pixels, which is the
    same quantity and does not have to special-case the band's own edges: a
    pixel on the top row has three neighbours inside the crop and four outside
    it, and counting the missing one as zero would report the edge as smoother
    than it is.
    """
    np = _need_numpy()
    lum = luma_band(path, rows)
    if lum.size == 0:
        return {"mean": 0.0, "n": 0, "p95": 0.0}
    dh = np.abs(np.diff(lum, axis=1))
    dv = np.abs(np.diff(lum, axis=0))
    both = np.concatenate((dh.ravel(), dv.ravel()))
    return {
        "mean": float(both.mean()),
        "n": int(both.size),
        "p95": float(np.percentile(both, 95.0)),
        # THE SHARE OF THE BAND THAT HAS ANY TEXTURE AT ALL, and it is here
        # because the far band of a tour frame is part SKY. The sky is a smooth
        # gradient in flat bands and contributes almost nothing to |dL|, so a
        # shot whose upper third is mostly sky dilutes the mean towards zero and
        # a real change in the terrain moves it less than it should. p95 and
        # this share are read off the fleckiest pixels instead, which are the
        # ground ones, so they say what happened to the country rather than to
        # the frame.
        "textured": float((both > 2.0).mean()),
    }


def band_diff(pa: Path, pb: Path, rows: tuple[int, int] | None) -> dict:
    """Two shots compared in LUMA over one row band: mean |dL| and the worst."""
    np = _need_numpy()
    la = luma_band(pa, rows)
    lb = luma_band(pb, rows)
    if la.shape != lb.shape:
        return {"size_mismatch": (la.shape, lb.shape)}
    signed = lb - la
    d = np.abs(signed)
    return {
        # THE TWO ARE DIFFERENT QUESTIONS AND DISTANCE V3 STAGE 2 NEEDS BOTH.
        # `mean` is the size of the change: a fleck of amplitude a has a mean
        # |dL| of roughly a/2 and that is the POINT of it. `shift` is the
        # signed mean - whether the band got brighter or darker on average -
        # and it is what "the average is preserved" means. A variation
        # mechanism that moves variance and not means has a large `mean` and a
        # `shift` of nearly nothing; one that is secretly a tint has both.
        "mean": float(d.mean()),
        "shift": float(signed.mean()),
        "worst": float(d.max()),
        "over1": int((d > 1.0).sum()),
        "n": int(d.size),
    }


def parse_rows(spec: str) -> tuple[int, int]:
    a, _, b = spec.partition(":")
    return (int(a), int(b))


def pngs(path: Path) -> list[Path]:
    return [path] if path.is_file() else sorted(path.glob("*.png"))


def run_local_contrast(paths: list[Path], rows) -> int:
    label = "rows %d-%d" % rows if rows else "whole frame"
    print("%-38s %10s %8s %9s %10s  (%s)" % (
        "shot", "fleck", "p95", "textured", "pairs", label))
    for path in paths:
        for png in pngs(path):
            r = local_contrast(png, rows)
            name = png.name if path.is_file() else "%s/%s" % (path.name, png.name)
            print("%-38s %10.4f %8.2f %8.2f%% %10d" % (
                name, r["mean"], r["p95"], 100.0 * r["textured"], r["n"]))
    return 0


def run_band_diff(a: Path, b: Path, rows, strict: bool) -> int:
    label = "rows %d-%d" % rows if rows else "whole frame"
    print("%-38s %10s %9s %8s %9s  (%s)" % (
        "shot", "mean |dL|", "mean dL", "worst", "px >1", label))
    over = 0
    names = [p.name for p in pngs(a)] if a.is_dir() else [a.name]
    for name in names:
        pa = a / name if a.is_dir() else a
        pb = b / name if b.is_dir() else b
        if not pb.exists():
            print("%-38s %10s" % (name, "MISSING"))
            over += 1
            continue
        r = band_diff(pa, pb, rows)
        if "size_mismatch" in r:
            print("%-38s  size %s vs %s" % (name, *r["size_mismatch"]))
            over += 1
            continue
        print("%-38s %10.4f %+9.4f %8.1f %9d" % (
            name, r["mean"], r["shift"], r["worst"], r["over1"]))
    if strict and over:
        return 1
    return 0


def main(argv: list[str]) -> int:
    strict = "--strict" in argv
    argv = [a for a in argv if a != "--strict"]
    rows = None
    if "--rows" in argv:
        i = argv.index("--rows")
        rows = parse_rows(argv[i + 1])
        del argv[i:i + 2]
    if "--local-contrast" in argv:
        argv = [a for a in argv if a != "--local-contrast"]
        paths = [Path(p) if Path(p).is_absolute() else ROOT / p for p in argv]
        if not paths:
            print(__doc__.strip().split("\n\n")[1])
            return 2
        return run_local_contrast(paths, rows)
    if len(argv) != 2:
        print(__doc__.strip().split("\n\n")[1])
        return 2
    if rows is not None:
        a, b = (Path(p) if Path(p).is_absolute() else ROOT / p for p in argv)
        return run_band_diff(a, b, rows, strict)
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
