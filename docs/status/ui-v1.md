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

---

## F9 tunables - starting and final values

Filled from Stage 4 onward.

---

## For Marcel to rule on

Filled as the run raises them.

---

## Deferred / wrapped

Nothing yet.
