# Character v2 — run status

Unattended run of `docs/plans/character-v2-tech.md`, starting 2026-08-28 on
ganymede, on `feat/character-v2` from `main` at `8b89473`.

**This box now renders on the GPU.** `xvfb-run -a ~/bin/godot` reports
`Vulkan 1.4.329 - Forward+ - NVIDIA GeForce RTX 3070 Ti`. Every previous
character run drew on Mesa llvmpipe in Compatibility, and the "Tuned blind"
section that character v1 had to write does not exist in this document. The
renderer is still not Marcel's 5080, but it is the same API, the same driver
family and the same rendering method.

Written at the end of every stage, not at the end of the run.

---

## Read this first

```bash
G=~/bin/godot
V=~/.venvs/kubik/bin/python

# The suites
$G --headless --path . scenes/character/selftest_character.tscn
$G --headless --path . scenes/selftest.tscn

# The counts. No images, one table each, under a minute.
xvfb-run -a $G --path . scenes/character/gallery.tscn -- --label X --sheet budget
xvfb-run -a $G --path . scenes/character/gallery.tscn -- --label X --sheet masks-40
xvfb-run -a $G --path . scenes/character/gallery.tscn -- --label X --sheet masks-options
xvfb-run -a $G --path . scenes/character/gallery.tscn -- --label X --sheet outline

# Every sheet, 53 images, 45 seconds
xvfb-run -a $G --path . scenes/character/gallery.tscn -- --label X

# Did anything move that I did not mean to move
$V tools/png_diff.py build/character/A build/character/B
```

---

## Stage 0 — measure first, correct the record, build the gate

Committed as `feat(character): stage 0 - ...`. Three things came out of it and
two of them were not what the plan expected.

### 1. The baseline reproduces, and the plan's first instruction was a trap

The plan says: re-shoot `--label v2-0`, compare against `build/character/v2-baseline/`
(shot 2026-08-27), "and confirm they agree; if they do not, something moved
between 2026-08-27 and now and that is the first thing to find."

**30 of 53 sheets differed.** Nothing had moved. The sheets are not
reproducible.

Proved by elimination, in this order:

| test | result |
| --- | --- |
| `v2-baseline` vs a fresh `v2-0` | 30 of 53 differ |
| a fresh `v2-0` vs another fresh `v2-0`, **same commit, back to back** | **31 of 53 differ** |
| freeze every subject's `_process` (blink is real randomness by design, breath runs on wall-clock `time`) and repeat | **31 of 53 still differ** |
| `--sheet closeup` alone, twice, in two processes | **all 4 differ** |

So it is not a code change, not the animator, and not state left over from a
previous sheet in the same run. A single sheet shot alone, twice, differs.

**What the difference is.** Overwhelmingly one least-significant bit, spread
over lit surfaces, plus several hundred antialiased edge pixels that flip
coverage. On the worst sheet, `variants-elf.png`:

```
14,123 differing pixels of 921,600  (1.53%)   worst channel delta 211
delta == 1 : 10,174   (72%)
delta 2-4  :  1,530
delta 5-16 :  1,171
delta 17-64:    479
delta > 64 :    769   (5%, and these are edges)
```

Typical sheets are 0.01% to 0.6%. It is below anything this repo controls —
project settings request no MSAA, no TAA, no debanding, so these are Godot's
Forward+ defaults on this driver.

**What is bit-stable, measured over four runs:** every frozen-pose strip
(`anim-*`, `gear-walk`, `critter-walk`), every mask sheet, every swatch sheet,
`testcube`. 22 of 53. And every **count** — the budget table, the IoU table and
the option sweep reproduced to the digit on every run.

**So the plan's measurement rule was right for a reason it did not know.** It
says every gate is a count because frame times do not survive noise. It turns
out *pixels* do not survive noise either, on the renderer the game ships on.
Counts are the only thing that does.

`tools/png_diff.py` is the consequence: per-sheet differing-pixel counts against
a tolerance set from the measurement above (3% of area; the worst honest noise
was 1.53%), with the bit-stable sheets held to exactly zero. It is stdlib plus
PIL from `~/.venvs/kubik`, matching `compare_sheets.py`'s convention, and it
runs in 1.6 s against a 53-sheet pair.

**One change was made on a hypothesis the measurement then refuted, and kept
anyway.** `_make_subject()` now calls `view.set_process(false)`, freezing every
gallery subject the moment it is built. It fixed none of the drift. It is kept
because a still sheet catching a blink is a real hazard — the blink timer starts
at 3-6 s and a sheet is shot four frames after its subjects are built, so it
does not fire today and will the moment the 96-voxel grid makes a sheet slower.
The comment in the file says exactly this, including that it fixed nothing.

### 2. The recorded silhouette numbers were wrong, and worse than recorded

Re-measured on the GPU, three runs, identical to the thousandth every time:

| pair, front on | GPU (3 runs) | `character-v1.md` (llvmpipe) | delta |
| --- | --- | --- | --- |
| human / elf | 0.530 | 0.608 | −0.078 |
| human / dwarf | 0.561 | 0.561 | 0.000 |
| **human / lizardfolk** | **0.913** | 0.868 | **+0.045** |
| elf / dwarf | 0.357 | 0.372 | −0.015 |
| elf / lizardfolk | 0.534 | 0.580 | −0.046 |
| dwarf / lizardfolk | 0.566 | 0.593 | −0.027 |

| pair, three-quarter | GPU | `character-v1.md` |
| --- | --- | --- |
| **human / lizardfolk** | **0.759** | 0.619 |

Across every hair, beard and crest option: **94 cross-race variant pairs, 15
over 0.70, worst 0.928 (human hair 1 vs lizardfolk hair 2)** — the same counts
and the same worst case as the llvmpipe record, so the *sweep* is stable across
renderers while the *default pair* is not.

Two consequences, both recorded in `docs/status/character-v1.md`:

- Its IoU tables are void as a baseline. They are not deleted; they are boxed.
- **The way out it offered no longer exists.** Its option 3 was "judge the
  metric three-quarter on", on the strength of 0.619. On the GPU that view is
  0.759 and over target. There was never a view in which the human and the
  lizardfolk separated, and the rebuild Marcel approved on 2026-08-27 is the
  only option rather than the expensive one.

### 3. The outline-event metric exists, and it can see something

`--sheet outline`, the gate the whole armour tier ladder is defined in terms of,
built before there is any armour for it to judge. Measured at **3 m**, not 15 m:
at 1280x720 a 2 m character is 313 px at 3 m and 62 px at 15 m, and the ladder's
smallest legal feature — 2 voxels per side — is 6-7 px at 3 m and about 1 px at
15 m. The picture is judged at 15 m by a person; the count is taken where a
voxel is still a thing that exists.

The reference is **the naked body**, not tier 1, which is what makes "tier 1 has
zero outline events" a measurement rather than a tautology.

Verified two ways, because a metric whose only test is that it returns zero has
not been tested:

```
  subject                             front     up   prof prof-up   total
  stocky human (bare)                     0      0      0      0       0
  stocky human + placeholders             1      0      1      0       2
  stocky elf (bare)                       0      0      0      0       0
  stocky elf + placeholders               1      0      1      0       2
  stocky dwarf (bare)                     0      0      0      0       0
  stocky dwarf + placeholders             1      0      1      0       2
  stocky lizardfolk (bare)                0      0      0      0       0
  stocky lizardfolk + placeholders        1      0      1      0       2
```

Zero on a bare body — it does not hallucinate. Two on a body wearing the Stage
10 gear placeholders — it sees the sword rising past the shoulder line, from the
front and in profile. The placeholders are not armour and are not judged; they
are the only real outline change that exists today.

### The baseline column

`--sheet budget`, with the retained voxel list reported for the first time:

| | mesh | + gear | drawn | retained voxels | KB |
| --- | --- | --- | --- | --- | --- |
| stocky human | 17,052 | 18,356 | 34,104 | 15,992 | 374 |
| stocky elf | 14,692 | 15,996 | 29,384 | 11,320 | 265 |
| **stocky dwarf** | **17,788** | 19,092 | 35,576 | **17,646** | **413** |
| stocky lizardfolk | 16,592 | 17,896 | 33,184 | 15,118 | 354 |
| critter (not a budget) | 7,280 | — | 14,560 | — | — |

Budget 24,000. Worst character 17,788, which is the design doc's number to the
triangle.

**On item 5, the retained voxel list.** 413 KB for the worst character today, so
about 1.4 MB at 96 voxels (x3.375) and 5.6 MB for a party of four — under the
8 MB threshold the plan sets for building the `PackedInt32Array` packing. The
measurement is taken; the decision waits for Stage 3, which is when the number
actually moves.

### Green at the end of the stage

```
CHARACTER SELFTEST: 28 tests, all passed
SELFTEST: all passed
config        3d45b8fc
heightmap#    76cccdb6          <- unchanged
spawn         OK at (-44, -124) <- unchanged
```

### Departures from the plan in this stage

- **`tools/png_diff.py` is new and is not in the plan's Stage 0 file list.** It
  is there because the stage's first instruction produced a result the plan did
  not anticipate, and the following twelve stages need a way to answer "did
  anything move" that does not depend on pixel equality.
- **The plan's Stage 10 verify was amended in the same commit.** It asked for
  tour shots "pixel-identical to the pre-stage run… a single changed pixel on a
  hillside means the emissive uniform reached the terrain material". That gate
  is not achievable on this renderer and would have failed on noise. Replaced
  with a tolerance and a targeted check; see the plan.
