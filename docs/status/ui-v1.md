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
| 2 | `76cccdb6` | `(-44, -124)` | all green, **+1 selftest** (`ui mouse owners`) |
| 3 | `76cccdb6` | `(-44, -124)` | all green, **+1 selftest** (`stats table`) |

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

## Stage 2 - the mouse owner set

`DebugHUD.ui_has_mouse` is gone. `UiMouse` (`scripts/ui/ui_mouse.gd`) holds a
set of owners: the mouse goes VISIBLE on the first claim and CAPTURED on the
last release. F4, F8 and - from Stage 6 - the character sheet are the three
owners the boolean could not represent.

`ui mouse owners` in `scenes/selftest.tscn`, **0 checks failed**
[deterministic], asserting: two claims count two; releasing one of two leaves
the cursor held (**the bug**); release-all lets go; a doubled claim is one
claim and needs one release; releasing a non-owner disturbs nothing.

`player.gd` now asks `UiMouse.held()` directly - the plan offered a one-line
proxy on DebugHUD as an intermediate step and it was not needed, since the
only caller was that one line. **The wheel is excluded from click-to-recapture**
in the same edit: a wheel notch is an `InputEventMouseButton` like any other,
so scrolling with the cursor free used to grab it back, and from Stage 5 the
wheel belongs to the hotbar.

`player.gd`'s own Esc path still sets the mouse mode directly rather than
through `UiMouse`. It is not an owner - it frees the cursor without claiming
it - so nothing in the set is bypassed. Left as it was; recorded so the next
lane does not read it as an oversight.

**Operational note for later stages:** a new `class_name` needs
`$G --headless --path . --import` before any gate will parse. The plan says
so; this run hit it anyway on `UiMouse` and the symptom is a *hang*, not a
clean error - the selftest scene fails to load and the process sits there.

---

## Stage 3 - the stats table, the sync ride, and the journal

`StatsTable` (`scripts/game/stats.gd`) holds `peer_id -> {hp, sp, mp}` on the
host. `DEFAULTS` carries the starting values **and** the maxima in one const -
100/100/100 - so a racial health bonus or a mana pool that grows with Magic
changes a table and nothing else. `apply_delta` is the only thing in the game
that writes a stat, and it journals `stat_changed {peer, stat, from, to, cause}`
through an injected Journal.

**Health at 0 does nothing.** No death, no downed, no respawn - Combat v1 owns
what 0 means, and the table's docstring says so rather than leaving the next
reader to infer it.

`stats table` in `scenes/selftest.tscn`, **0 checks failed** [deterministic]:
defaults are the maxima; -30 from 100 leaves 70 and writes exactly one event
with `from`/`to` correct; a zero delta and a heal against a full stat write
nothing; -500 clamps to 0; a handed-out row is a copy and writing to it does
not reach the table; `fraction_of` reads 70/100 as 0.70 and an **absent** stat
as 1.0 (a bar with no packet yet has not been contradicted - an empty health
bar on join would read as a bug); `erase` forgets a peer that left.

### The sync ride

Decision 1, as built: `_publish_stats()` merges `{"hp","sp","mp"}` into each
peer's `_states` row from inside the existing 20 Hz block, so the three floats
travel on a packet that was going out anyway. No new channel, no new rate, no
reliable-on-change RPC - **hard rule 7 untouched**. Rewritten every tick rather
than on change: three floats against a Vector3 and a transform already in the
row, and a change-detecting sender would need an acknowledgement path to
survive the loss `unreliable_ordered` exists to tolerate.

Clients keep the **whole** table now (`_last_states`, one line in
`_apply_states`) because `_last_authority` is our own row only and the Stage 5
party icons need a *friend's* health. `peer_stats(peer_id)` reads the host
table or the client copy as appropriate. **Hard rule 8 holds:** there is no
client write path to a stat anywhere, and nothing predicts one.

### The world.gd exception (Decision 10)

**+25 lines, -0. Not one existing line of `world.gd` was modified** - `git
diff` reports 25 insertions and no deletions. The two additions are a
`set_journal()` setter beside `_edits`, and one `log_event("block_edit", ...)`
in `_host_apply_edit` immediately after `_edits[world_block_pos] = block_id` -
past the validate gate, past the no-op gate, with the sender id the network
layer assigned rather than one an argument claimed. `game.gd` injects it three
lines from where BodyField gets the same journal. The client's
`_cl_apply_block` journals nothing.

### The H key (Decision 6)

`KEY_H`, **host-side only**, -10 hp through `apply_delta`, marked TEMPORARY on
the same contract the G slab is on: **Combat v1 deletes it.** Host-only is not
a convenience - a client key that took a client's own health is the exact thing
`DESIGN.md` § networking forbids, and writing it "just for a test" is how that
rule gets broken for real.

### Operational note

The default ENet port was in use on this box (the concurrent distance-v3 lane),
so the boot smoke test ran `--port 24071`. The shot driver in Stage 4 hosts
**offline** and binds no port at all, so it is unaffected.

---

## F9 tunables - starting and final values

Filled from Stage 4 onward.

---

## For Marcel to rule on

Filled as the run raises them.

---

## Deferred / wrapped

Nothing yet.
