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
| 4 | `76cccdb6` | `(-44, -124)` | all green |
| 5 | `76cccdb6` | `(-44, -124)` | all green, character selftest green **post-nametag-removal** |
| 6 | `76cccdb6` | `(-44, -124)` | all green |

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

## Stage 4 - the HUD frame, the bars, the fade, and the harness

### The harness, built first

    xvfb-run -a ~/bin/godot --path . -- --shot-hud ui-v1-hud --seed 42

writes `build/ui/ui-v1-hud/*.png` and quits. It **skips the main menu and
hosts offline**, so it binds no ENet port - which matters on this box, where
the concurrent distance-v3 lane may hold the default one; the failure mode of
getting that wrong is sitting on the menu having printed "Couldn't create an
ENet host" into a log nobody was watching.

It drives the real game: the real HUD, the real stats table, the real fade, at
seed 42. What it stages is the **situation**, and each one through the seam the
game uses - `SkyCycle.frozen` for the hour, `apply_delta` for the damage.
**There is no shot mode inside the HUD.**

`Hud.settle(seconds)` advances the fade by simulated time **through the HUD's
own `_process`**, in 0.05 s steps. Not a bypass, deliberately: a photograph
caught halfway through a 1.4 s ease is a photograph of nothing checkable, and
waiting out `fade_grace_s` in real frames is six seconds of wall clock per
shot. Because it is the real code path, a wrong fade settles to the wrong
state - which is the property a bypass would throw away.

### The evidence [deterministic]

Sampled with `~/.venvs/kubik/bin/python`, 9x9 windows. The bar cluster's
region is **derived from `HudConfig`, not guessed**: cluster rect
**(530, 663) 220x31** on a 1280x720 canvas, bars at rows 663, 675, 687.

| shot | fade line | 9x9 at each bar | hp fill |
| --- | --- | --- | --- |
| `safe-noon.png` | `hud 0.00 shown \| full true, since 99.9/6.0 s, night 0.00/0.25, danger 0.00/0.35` | **no palette hits at all** on any of the three | **no SUN pixels** |
| `night.png` | `hud 1.00 \| night 1.00/0.25` | INK 18 + SUN 54 / ALPINE_PALE 54 / ALPINE_DEEP 54 | 219/220 = 0.9955 |
| `hurt.png` | `hud 1.00 \| full false` | INK 18 + SUN 54 / PALE 54 / DEEP 54 | **154/220 = 0.7000** |
| `panel-f8.png` | - | panel rect **(16, 16) 463x688** in a 1280x720 canvas | - |

- **`safe-noon` is the acceptance test and it passes exactly.** Zero HUD ink
  in any of the three named regions - not faint, absent. Safety looks like a
  clean screen. **[eye]** The frame reads as a world with nothing on it.
- **`hurt` is 0.7000, not 0.70 ± 2 px.** 154 px of a 220 px track is 0.7
  exactly, from a -30 on 100 through `apply_delta`.
- `night` shows 219 of 220 rather than 220: the last pixel is the INK hairline
  drawn over the fill's right edge. Not an error - the bar has an edge on
  purpose, so it reads against a bright sky as well as a dark hillside.
- **The journal dump contains exactly one event**, host-side:
  `{peer: 1, stat: "hp", from: 100.0, to: 70.0, cause: "shot", kind: "stat_changed"}`.
- **`panel-f8` discharges the Stage 1 debt.** The panel spans y 16-704 in a
  720 canvas and its paper ground is continuous from y=30 to y=690 at x=400,
  with terrain at x=500. It fits, and it is now photographed rather than
  argued from anchors. It came out 463 px wide against the 360 the offsets ask
  for - a `PanelContainer` honours its child's minimum width - which is wide
  but nowhere near the edge; recorded, not fixed.

### One real bug, found by the harness on its first run

The cluster was placed with `Control.position`, and a Control under a
CanvasLayer **does** resolve its anchors against the viewport - but `position`
is measured from that rect's ORIGIN, not from the anchor. The cluster's global
rect was `(-110, -57)`: off the top-left corner of the screen. **Every fade
number read correctly the whole time** - `hud 1.00 shown`, `vis true` - and the
shot was of a HUD that was present, visible, at full opacity and nowhere in the
picture. Anchors and offsets now, and `Hud.layout_line()` prints the rect on
every shot so the "invisible" and "off screen" cases can never look alike
again. **This is the harness earning its place on the day it was built.**

### Decision 5, done

`_update_status()` is now `pass`. The permanent line - peer id, chunk count,
seed, keybind crib - is on the F3 readout, appended under the `# UI V1` banner,
alongside `Hud.fade_line()`, which names **which of the four conditions** is
holding the HUD in. `Status` survives as a transient message line only (reroll,
config, "only the host can reroll") and is cleared when the world is ready -
a transient line that never clears is a permanent one.

`debug_hud.gd` changes: the banner block, the `hud` field and `set_hud`, the F3
appends, the `_game_node()` helper, and the Stage 2 `_set_panel_visible`
rewiring. **`TUNING_ROWS`, `LOCAL_TUNING_ROWS`, `_build_panel`, `_spin_row` and
the panel keys are untouched** - hard rule 3 holds.

---

## Stage 5 - hotbar, compass strip, party icons, and the nametag dies

### The evidence [deterministic]

`party.png`, sampled with `~/.venvs/kubik/bin/python`. Two peers staged
through `_merge_state` + `_apply_states` - **the same functions the sync tick
calls**, so what is photographed is built from rows that arrived the way every
row arrives. KIRA due east at 60 hp; TORV due north at 100 hp.

| check | result |
| --- | --- |
| peer-2 hue | computed **independently in Python** as `hsv(fposmod(2 x 0.61803398875, 1), 0.65, 0.95)` = **#B1F255**; the game printed `b1f255`; **126 ring pixels** of it in the icon area |
| chevron in the east half | **22 px at x 864-870**, strip centre 640 - all east |
| no nametag over the body | band rows 224-264, x 560-720 (named by the driver from `unproject_position`): **0 PAPER pixels** in 6601 |
| health only when hurt | **161 SUN px** around KIRA (hp 0.60), **0** around TORV (hp 1.00) |
| gold nowhere but the selected slot | **368 GOLD px, x 508-555** - slot 1's frame is x 508-554, and there is no gold anywhere else in the hotbar row |

The nametag check is decisive on PAPER rather than on INK: the old `Label3D`
was `modulate = Deco.PAPER` with a darkened peer-hue outline, so paper WAS the
tag's ink. There is none. (The band does contain 157 INK-ish pixels - that is
Torv's dark hair, which is what is actually in that band now.)

### The journal, from the `use` step

The driver selects slot 1 and uses it. The dump:

- **1 x `stat_changed`** (the `hurt` step's -30, peer 1, 100 -> 70)
- **9 x `block_edit`**, every one `peer: 1`, at `(-1..1, 114, -1..1)`, `block: 5`

**The plan's acceptance says "exactly one `block_edit`". It is nine, and that
is correct.** The stand-in tool is the pre-existing debug *slab*, which places
a 3x3 by construction (`_toggle_debug_slab`, `for x in range(-1, 2)`) and
always has. One use, nine accepted edits, each journalled once, each with the
sender the network layer assigned. The claim the acceptance was reaching for -
select-and-use goes through the one mutation path and every accepted edit is
now recorded - holds exactly. Recorded rather than papered over.

### Three real layout faults the shots found

None of these were visible in a number; all three needed the picture.

1. **The hotbar hung off the bottom of the screen.** The cluster's box was
   sized to the bar stack alone, so the five slots laid out below its bottom
   edge, which is below the screen's. The cluster is the bars *and* the
   hotbar, and its height says so now.
2. **The icons spilled across the health bar.** Their box is sized from
   `natural_width()`, which depends on who is in the party - and the party is
   not known when the HUD builds itself. Laid out once at build time the box
   was zero wide, and a Control does not clip its own drawing, so the icons
   drew outside it. `set_members` reports a change and the row re-lays out.
3. **Two four-letter names ran into each other.** A 30 px roundel plus a 10 px
   gap is narrower than the word under it. The step is the wider of the
   roundel and the name.

### Two calls the plan did not make, taken conservatively and recorded

- **Off-strip party chevrons are PINNED to the strip's edge, not dropped.** At
  the shipped 150-degree span a friend more than 75 degrees away falls off the
  ends - which at any moment is most directions - and the first party shot had
  an icon and no chevron because of it. A tick or a cardinal that scrolls off
  is genuinely not on the strip and clamping one would be a lie about a
  direction; "your friend is somewhere off to the right" is not a lie, it is
  the half of the answer a strip can still give. This is also what makes the
  acceptance test's "chevron in the east half" true rather than vacuous.
- **Chevrons draw above the cardinals, not across them.** A friend due north
  puts their chevron exactly where the N is. `strip_height` went 26 -> 34 to
  carry both rows; both numbers are on F9.

### The nametag removal, complete

`scenes/remote_player.tscn`'s `Label3D` node, `remote_player.gd`'s `@onready`
ref, all four feed sites and the height line. The name is a stored
`display_name` field the party icons read. `selftest_character.gd`'s four
`Nametag` lines are gone - they were a no-op check even then (the body of the
`if` was `pass`) and would have crashed on the missing node.

The class docstring's paragraph on why the body is never tinted is
**rewritten, not deleted** - that reasoning still holds, and it now also says
where the hue went. `color_for_peer()` stays exactly where it is, static, per
its own doc comment.

**The character selftest is green after the removal** - the plan's stated MUST.

### The G binding is retired

Slot 1 is the slab tool and using it calls `Game.use_slab_tool()` ->
`World.request_set_block()`, the same request the key made. The keybind crib on
F3 reads `[1-5]/wheel hotbar, LMB use` now.

---

## Stage 6 - the character screen

### The evidence [deterministic]

`sheet.png`, and the driver's own label dump, which is how the count is
verified: **there is no OCR on this box**, and the plan's answer is to verify
by construction.

    sheet: 6 sockets ["Torso", "Shoulders", "Back", "Head", "Legs", "Hands"]
         | 5 skills ["Blades", "Bows", "Magic", "Mobility", "Gathering"]
         | name "unnamed" | race "stocky human"

**Six sockets, five skills**, and the name and race read off the LIVE player
(`Player/View.def`, the runtime truth the F8 panel cycles and the wire carries)
rather than off the file on disk - a sheet that showed the saved file would
disagree with the body standing in the world.

**Hard rule 10, as an assertion rather than a paragraph.** The driver sends
`ui_cancel` with the sheet open and checks both halves:

    esc from the open sheet: sheet open false, still in the game scene true

An unconsumed `ui_cancel` walks up to `Game._unhandled_input`, which calls
`Net.leave()` and changes scene - one missed consume between a player pressing
Escape on their inventory and being dropped out of their friend's world. The
sheet consumes it in `_input()` (which runs before every `_unhandled_input` in
the tree) and only while open. The driver `push_error`s if either half fails,
so a regression breaks the run rather than the session.

### The creation screen survived the extraction

`--shot-ui ui-v1-creation-after` against Stage 1's `ui-v1-stretch`:

| sheet | differing px | worst channel | % |
| --- | --- | --- | --- |
| `main-menu.png` | 0 - **identical** | - | - |
| `character-creation.png` | 1243 | 124 | **0.135%** |

**0.135% is BELOW the 0.232% same-commit noise floor measured in Stage 1.** The
turntable rig moving out of `character_creation.gd` and into
`CharacterPreview` is a no-op to the eye, which is what the plan required.

### `own_world_3d = true` is the load-bearing line

The creation screen never needed it - it is its own scene and there is no other
3D world to inherit. The sheet is opened **inside the game**, and a SubViewport
sharing the game's `World3D` would render the live world into the portrait box
and, far worse, its `camera.current` would fight the player's camera for the
main viewport. The symptom would not be a wrong preview; it would be the
player's view taken over by a portrait camera looking at their own feet.
`UPDATE_WHEN_VISIBLE` for the matching reason: the sheet is shut most of the
time and a second 3D scene rendering behind a closed screen is a cost with no
picture attached.

### One call the plan did not make

**The field register stands down while the sheet is open.** The sheet's ink
ground is 94% opaque, and in the first sheet shot the bars and the compass
strip ghosted through it - instruments faintly visible behind a printed page,
which is exactly the "UI pasted on" the acceptance test warns against. The
sheet tells the HUD to suppress itself (`Hud.set_suppressed`) and releases it
on close. The two registers are never shown at once.

### Layer order

Sheet at **5**: above the game, **under** both debug panels (10, 11) and the F9
tuner (12). A debug panel you cannot see because a screen is over it is a tool
made useless by a screen, and the tools win.

---

## F9 tunables - starting and final values

Every value this run chose by eye, all reachable from **F9** (layer 12), all
saved to `user://ui.tres` by the panel's save button. **Hard rule 5.**
"Final" is filled when Marcel moves one; until then the starting value is what
ships, and every one of them was chosen from screenshots on a box with no
monitor.

| property | F9 row | start | final |
| --- | --- | --- | --- |
| `fade_grace_s` | fade: grace (s) | **6.0** | - |
| `fade_night_max` | fade: night max | **0.25** | - |
| `fade_danger_max` | fade: danger max | **0.35** | - |
| `fade_out_s` | fade: out (s) | **1.4** | - |
| `fade_in_s` | fade: in (s) | **0.25** | - |
| `strip_floor_alpha` | strip: floor alpha | **0.0** | - |
| `bar_width` | bar: width | **220.0** | - |
| `bar_height` | bar: height | **7.0** | - |
| `bar_gap` | bar: gap | **5.0** | - |
| `cluster_margin_y` | cluster: bottom margin | **26.0** | - |
| `slot_size` | hotbar: slot size | **46.0** | - |
| `slot_gap` | hotbar: slot gap | **8.0** | - |
| `strip_width` | strip: width | **460.0** | - |
| `strip_height` | strip: height | **34.0** | - |
| `strip_margin_y` | strip: top margin | **14.0** | - |
| `strip_span_deg` | strip: span (deg) | **150.0** | - |
| `icon_radius` | party: icon radius | **15.0** | - |
| `icon_gap` | party: icon gap | **10.0** | - |
| `dot_radius` | context dot radius | **2.5** | - |

`fade_in_s` is deliberately much shorter than `fade_out_s`: instruments
appearing is the game telling you something, and a leisurely fade-in tells you
late.

**Recorded caveat on `fade_danger_max`.** `danger_at()` normalises 0 at spawn
to 1 at the furthest corner **of the current 3x3 km region**. The world is
unbounded by design (CLAUDE.md), so that normalisation is a property of today's
stage and not of the world. The fade reads it as an input and nothing bakes a
world edge in; when danger becomes regional, the threshold is one F9 row to
re-tune. Not a blocker, and named so the next lane does not find it as a
surprise.

**Recorded: time of day is per-client and unsynced.** Two players can disagree
about whether it is night, and so about whether their own HUDs are showing.
That is fine - the fade is a look input, not world truth, and nothing about the
game's state depends on it.

---

## For Marcel to rule on

Filled as the run raises them.

---

## Deferred / wrapped

Nothing yet.
