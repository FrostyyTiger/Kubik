# UI v1 - status

The overnight run of `docs/plans/ui-v1-tech.md`, against the design authority
`docs/plans/ui-v1.md`. Branch `feat/ui-v1`, cut from `main` at `2cd7b0a`.

Machine: **ganymede** (headless Ubuntu 24.04, RTX 3070 Ti, Vulkan / Forward+
under `xvfb-run`). Godot at `~/bin/godot`. Python with PIL at
`~/.venvs/kubik/bin/python` - **not** the system `python3`, which has no PIL;
the plan said "Python 3 + PIL are present" and that is true only inside the
venv. Recorded here so the next run does not chase it.

Every number below is tagged with its provenance:
**[deterministic]** reproduces exactly on a re-run, **[single run]** was
measured once and is not a gate, **[eye]** is a judgement made by looking.

---

## Baselines (Stage 0)

The three gates, on `2cd7b0a` with no edits:

| gate | result |
| --- | --- |
| `scenes/selftest.tscn` | **all passed**, exit 0 [deterministic] |
| `scenes/character/selftest_character.tscn` | **36 tests, all passed**, exit 0 [deterministic] |
| `worldgen_probe.gd -- --seed 42` | see below [deterministic] |

**THE PROBE BASELINE. Hard rule 1: these two numbers must be identical at
every later stage.**

| | value |
| --- | --- |
| seed | 42 |
| config hash | `3d45b8fc` |
| **heightmap#** | **`76cccdb6`** |
| **spawn** | **`(-44, -124)` blocks = `(-22 m, -62 m)`, altitude 28 m, slope 0.1 deg** |
| danger at spawn / far corner | 0.00 / 1.00 |

UI shots, `--shot-ui ui-v1-baseline`:

| file | size |
| --- | --- |
| `build/ui/ui-v1-baseline/main-menu.png` | 1280x720 [deterministic] |
| `build/ui/ui-v1-baseline/character-creation.png` | 1280x720 [single run - the turntable is not frozen yet; Stage 1 freezes it] |

`build/` is gitignored, so the PNGs live on ganymede only. The numbers
sampled out of them are here.

---

## Per-stage hash log

| stage | heightmap# | spawn | gates |
| --- | --- | --- | --- |
| 0 | `76cccdb6` | `(-44, -124)` | all green |
| 1 | `76cccdb6` | `(-44, -124)` | all green |

---

## Stage 1 - stretch mode

`canvas_items` + `expand`, plus the four raw-pixel fixes the plan listed.

### The plan's 2x gate could not be run as written, and here is what replaced it

The plan asked for a shot at 2560x1440 and a check that "the band's top edge
sits at 2x the baseline row (uniform scale, no drift)". **That is not
measurable through this harness**, and the reason is worth writing down
because it would have been re-derived at the next stage:

`UiShot.capture` photographs `tree.root.get_viewport().get_texture()`, which
under `canvas_items` is the **logical canvas as drawn, before the stretch
transform scales it to the display**. A 2560x1440 window therefore writes the
same 1280x720 PNG a 1280x720 window does - not because the scaling failed, but
because the scale is applied downstream of the pixels the harness reads. There
is no 2x row to measure; there is no 1x row either.

**What was run instead**, measured on ganymede [deterministic]:

| startup | `--shot-size` | logical canvas | INK title band rows | band height |
| --- | --- | --- | --- | --- |
| 1280x720 (`ui-v1-baseline`, pre-Stage-1) | - | 1280x720 | 89-235 | 147 |
| 1900x720 (`ui-v1-stretch`, pinned) | default | **1280x720** | 89-235 | 147 |
| default (`ui-v1-stretch-tall`) | 1280x1000 | 1280x1000 | 229-375 | 147 |
| default (`ui-v1-stretch-wide`) | 1900x720 | 1900x720 | 89-235 | 147 |

Read left to right this says everything the 2x shot was meant to:

- **Decision 11 is confirmed by measurement, not assumed.** `expand` hands the
  surplus back as canvas and never takes any away: 1280x1000 and 1900x720, and
  neither dimension ever below 1280x720. The menu and creation overflow
  scenarios genuinely do not occur.
- **The band tracks the type, not the window.** Its height is 147 px on every
  canvas, and on the tall canvas it moved down by exactly 140 px = (1000-720)/2
  - the VBox is centred, and the band followed it there. That is the Stage 1.3
  transform fix doing its job in a canvas the screen was not designed around.
- **No regression at the design size.** `main-menu.png` is **bit-identical**
  between the pre-Stage-1 baseline and the Stage 1 shot [deterministic], so the
  affine-inverse rewrite is a no-op where the old code was accidentally right.

A 9x9 PIL sample at (40, band centre) reads `(30, 36, 48)` = `Deco.INK`
`#1E2430` on all four shots, every one of the 81 pixels.

### The pin pins the canvas, not the window

The plan said to pin the window with `DisplayServer.window_set_size()`. That
call resizes the OS window and **leaves the logical canvas where it was** -
verified: window `(1280, 1000)`, canvas `(1280, 720)`. It would have written
correctly-sized PNGs for the wrong reason and gone on doing so until the first
shot at a different startup resolution. `UiShot.pin_canvas()` sets `root.size`
instead, and the 1900x720-startup row above is the proof that it holds.

`--shot-size WxH` was added as a real flag rather than the temporary driver
edit the plan suggested - same few lines, and the check stays re-runnable.
Recorded as a deliberate, small departure.

### The turntable freeze, and the tolerance Stage 6 inherits

Two `--shot-ui` runs of the **same commit**, back to back, with the turntable
frozen under `UiShot.wanted()` [deterministic on `main-menu`, single run on
the lit one]:

| sheet | differing px | worst channel | verdict |
| --- | --- | --- | --- |
| `main-menu.png` | 0 - **identical** | - | - |
| `character-creation.png` | 2141 | 124 | **0.232%** - noise |

0.232% is the floor: the creation screen is a lit 3D character, and
`tools/png_diff.py`'s own docstring records the same class of run-to-run GPU
variance on this box. **This is the tolerance Stage 6's creation re-shoot is
measured against.** Before the freeze the same pair differed by 1.372% plus an
arbitrary rotation, which is not a tolerance at all.

### Deferred out of Stage 1

**The F8-panel-fits-at-720 shot.** The panel is now `PRESET_LEFT_WIDE` with
`offset_top = 16` / `offset_bottom = -16`, so it spans the canvas height minus
32 px **by construction at any logical height** - a stronger guarantee than a
photograph, and the fixed 640 px scroll box it replaced is gone. But the
plan also asked for a shot, and F8 lives in the game scene, which has no
capture driver until Stage 4. The shot is taken there. Conservative path:
nothing about the panel is claimed from the eye until it has been seen.

---

## F9 tunables - starting and final values

Filled from Stage 4 onward.

---

## For Marcel to rule on

Filled as the run raises them.

---

## Deferred / wrapped

Nothing yet.
