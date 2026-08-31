# UI v1 tech - the overnight procedure

The build plan for `docs/plans/ui-v1.md`. That document decides *what*; this
one is the procedure. Where the two disagree, this document says so out loud
in **Decisions**, and the design doc wins unless the disagreement is argued
there.

Written 2026-08-31 against `f99ec2a` on `main`. Target: ganymede, one
overnight run, branch `feat/ui-v1`. The agent executing this plan reads
**How to use this document** before its first edit.

---

## The grill

The design questions were asked and answered on 2026-08-31, before this plan
was written. **An answer here is binding.**

| # | question | answer taken | binds |
| --- | --- | --- | --- |
| 1 | minimap? | No. Compass strip only, no settings toggle, ever. | Stage 5 |
| 2 | who owns the hand? | The active hotbar slot. Five slots. No weapon slot anywhere. Sheet sockets are armour only. | Stages 5, 6 |
| 3 | which stat bars? | Health, stamina, mana - all three from day one, host-authoritative, even though nothing drains them yet. | Stages 3, 4 |
| 4 | always-on HUD? | No. Fades to zero when safe; safety looks like a clean screen. | Stage 4 |
| 5 | partner UI? | Small icons, health shown only when that member is hurt or downed; bearing on the compass strip; **the floating nametag dies**; ping deferred. | Stage 5 |
| 6 | skill chain? | Display only. The sheet is read-only; nothing is spent anywhere. | Stage 6 |
| 7 | scope? | Foundation now, queue explicitly overridden ("never mind the roadmap... every foundational prerequisite"). Scaling fix included. | Stages 1-6 |

Delegated defaults, recorded in `ui-v1.md` § "Defaults set on delegated
trust" and equally binding: one furniture cluster bottom-centre, strip
top-centre, party icons at the cluster's left edge, four corners empty; no
permanent crosshair (context dot only when the held item can act); keys 1-5 +
wheel, C for the sheet; gold on the selected hotbar slot **and nothing
else**; no new fonts, no new colours.

---

## Decisions this plan makes

The calls the design doc left to the procedure, plus one disagreement.
Marcel reviews these by reading this section, not by diffing code.

1. **Stats ride the existing state row.** A `"hp"/"sp"/"mp"` merge into the
   per-peer `_states` row travels on the 20 Hz `_cl_sync_players` broadcast
   for free; every client already receives and retains its own row
   (`_last_authority`), and `RemotePlayer.set_target()` ignores unknown keys
   by construction. No new channel, no reliable-on-change RPC. Stats are
   **pure display on the client** - there is no input-sequence rollback to
   reconcile a prediction against, and `DESIGN.md` § networking forbids
   trusting a client's claims about its own stats anyway.
2. **UI tunables get their own resource and their own panel.** A new
   `HudConfig` resource (`user://ui.tres`) with its own tuning rows on a new
   **F9** panel (CanvasLayer 12), copying the `CharacterConfig` /
   `character_debug.gd` precedent - which exists precisely to demonstrate
   this. NOT WorldgenConfig/F4: F4's rows write worldgen properties, its F5
   reload is a full world reroll (the wrong loop for UI feel), and
   `worldgen_config.gd` is the distance lane's highest-traffic file.
3. **Raw physical keys, no InputMap.** The project has no `[input]` section
   and every existing binding is `physical_keycode` polling or
   `_unhandled_input` matching. New keys follow the house style: 1-5 and
   wheel in the HUD script, C in the sheet script, F9 in the tuner. The one
   InputMap action in use stays `ui_cancel`.
4. **North is -Z, declared once.** No cardinal convention exists in the
   repo. -Z-as-north makes `heading_deg = wrapf(rad_to_deg(-player.camera_yaw()), 0.0, 360.0)`,
   +X east - and the sun (`sky_cycle.gd` arc: t=0.25 on +X) rise in the
   east, which is the only non-embarrassing reading. Written as a named
   constant with this justification in the compass file.
5. **The Status crib retires.** `$HUD/Status`'s permanent line (peer id,
   chunk count, keybind crib) moves into the F3 readout. Status stays as a
   transient message line only (reroll / config messages), left where it is.
   The permanent line was a dev convenience; the HUD replacing it is the
   point of this plan.
6. **A TEMPORARY debug damage key: H** (host-side, self-damage 10). The
   fade, the bars, the partner-hurt icon and the journal event cannot be
   *demonstrated* without something that changes a stat. Same contract as
   the G slab: marked TEMPORARY, the combat plan deletes it.
7. **The hotbar's stand-in item is the slab tool.** Slot 1 holds "slab", and
   its use action (LMB while captured) drives the existing
   `request_set_block` slab path, proving select-and-use end to end through
   the one mutation path. The raw **G binding is retired** in the same
   commit (it was marked TEMPORARY at birth).
8. **Layers.** The play HUD builds inside the existing `$HUD` CanvasLayer
   (layer 0) - every probe path already does `$HUD.visible = false`, so
   tour/probe screenshots exclude the play HUD automatically. The character
   sheet takes layer 5 (under both debug panels). F9 tuner takes 12.
9. **Branch posture.** `feat/ui-v1` from `main`, one commit per stage
   minimum, push after every stage (fast-forward only, never force, never
   rewrite). Merge to `main` at the end ONLY if acceptance is filled and
   every hard rule checks out; if `main` moved meanwhile (the distance
   lane), `git merge main` into the branch FIRST, re-run all gates, then
   merge. A conflict in a file this plan does not own is not the agent's to
   resolve - stop, record, leave the branch pushed.
10. **The one disagreement with the design doc.** `ui-v1.md` says this lane
    "stays out of `scripts/world/` entirely", and also orders the block-edit
    journal gap closed. Both cannot hold: the only site every accepted edit
    passes through is `world.gd:~1750` (`_host_apply_edit`, after the
    validate gate and the no-op gate, with `sender_id` in hand). This plan
    takes a **single-file exception**: two appended lines in `world.gd` (a
    `set_journal()` setter and one `log_event` call) plus one injection line
    in `game.gd`. `world.gd` is on no other lane's territory - distance v3
    declares it untouched. Habit 2 beats a fence sentence.
11. **A survey correction, so the agent does not chase ghosts.** An earlier
    audit feared sub-720 logical heights under stretch. With
    `canvas_items` + `expand` the scale factor is chosen so the logical
    canvas is **never smaller than 1280x720 in either dimension** - wider
    windows gain logical width, taller windows gain logical height. The
    menu/creation overflow scenarios therefore do not occur. What still
    needs fixing is listed in Stage 1; nothing else.

---

## How to use this document

**Environment.** Ganymede, headless Linux, GPU (`xvfb-run -a` reports
Vulkan / Forward+ / RTX 3070 Ti). Binary at `~/bin/godot`, not on PATH:

```bash
G=~/bin/godot
$G --headless --path . --import        # once after checkout, and after any pull that adds a class_name
```

Anything that renders is wrapped in `xvfb-run -a`. Self-tests and script
probes use `--headless`, unwrapped. Output goes under `build/ui/<label>/`.
Python 3 + PIL are present; `tools/png_diff.py` exists.

**Reading order before the first edit** (the reasoning lives above the
code, on purpose): `docs/plans/ui-v1.md` whole; `CLAUDE.md`;
`scripts/game/game.gd` docstrings and lines 56-75, 286-320, 556-660,
683-735, 780-830, 1050-1075; `scripts/ui/debug_hud.gd` 1-120 and 324-535;
`scripts/ui/character_debug.gd` 1-120; `scripts/ui/deco.gd`,
`deco_panel.gd`, `deco_rule.gd`, `assets/ui/deco_theme.tres`;
`scripts/ui/ui_shot.gd`; `scripts/ui/character_creation.gd` 16-160 and
399-451; `scripts/player/player.gd` 196-330 and 440-503;
`scripts/player/remote_player.gd` whole (it is short);
`scripts/game/journal.gd` whole; `scripts/world/world.gd` 1659-1770 (read);
`scripts/world/sky_cycle.gd` 120-190 and 260-310 (read);
`scripts/world/terrain_generator.gd` 660-740 and 1009-1021 (read).

Line numbers in this plan are from `f99ec2a` and may have drifted by the
time the run starts - **search for the quoted identifiers, do not trust the
numbers blind.**

**The measurement rule, stated once.** No stage gates on a frame time. Every
gate is a count, a hash, a PNG that exists at a pinned size, or a PIL-sampled
window (9x9, region named in the status doc) checked against a colour claim.
Lit 3D content varies run to run; UI pixels over a flat draw do not - sample
UI regions, never terrain.

**The gates, run at the end of every stage, in order:**

```bash
$G --headless --path . scenes/selftest.tscn
$G --headless --path . scenes/character/selftest_character.tscn
$G --headless --path . --script scripts/tools/worldgen_probe.gd -- --seed 42
```

The probe's heightmap hash and spawn are **re-baselined in Stage 0, not
copied from an older plan** - and from then on they must not move. A UI lane
that moves a block has left its lane; stop and record.

**Failure protocol.** Where this plan does not answer a question, record it
in the status doc and take the conservative path, never widening scope. If
the run dies: commit what is clean, note where, resume from the next stage
boundary. The branch is never left mid-stage without a status note.

**Status doc.** `docs/status/ui-v1.md`, written **at the end of every
stage**, not the end of the run: provenance-tagged numbers (ganymede,
deterministic / single run / eye), every hash at every stage, every starting
value with its final value, failures named, a "For Marcel to rule on"
section, the deferred list, and what the next plans inherit. At the end,
`STATUS.md` at the repo root becomes a pointer to it.

---

## Territory

**Owned outright:** `scripts/ui/hud.gd`, `hud_config.gd`, `hud_tuner.gd`,
`compass.gd`, `hotbar.gd`, `party_icons.gd`, `character_screen.gd`,
`character_preview.gd`, `ui_mouse.gd` (all new); `scripts/ui/ui_shot.gd`,
`main_menu.gd`, `character_creation.gd`, `character_debug.gd`;
`scripts/game/stats.gd` (new); `scripts/game/game.gd` (distance v3
pre-conceded it); `scripts/player/player.gd`, `remote_player.gd`;
`scenes/game.tscn`, `scenes/remote_player.tscn`, `scenes/player.tscn`;
`scripts/character/skills.gd` (new, names-only table); `project.godot`
(stretch keys only); `scripts/tools/selftest_character.gd` (the nametag
lines).

**Shared, append-only:** `scripts/ui/debug_hud.gd` - F3 readout lines and
nothing else, appended, under a `# UI V1` banner comment; do not touch
`TUNING_ROWS`, `LOCAL_TUNING_ROWS` (the distance lane appends there),
`_build_panel`, `_spin_row`, or the panel keys. `scripts/tools/selftest.gd` -
new assertions only, never delete or reorder an existing one.

**The single exception:** `scripts/world/world.gd` - Decision 10. Two
appended lines, nothing else.

**Untouched (read them, never write them):** everything else under
`scripts/world/` - `look.gd`, `sky_cycle.gd`, `worldgen_config.gd`,
`terrain_generator.gd`, `chunk_mesher.gd`, all of `flora/`; all of
`scripts/net/`; `scripts/tools/far_probe.gd`, `screenshot_tour.gd`;
`scripts/character/` except the new `skills.gd`; `assets/ui/deco_theme.tres`
(the theme is settled; HUD elements are drawn Controls, not theme entries).

**Never.** No texture or image assets - bars, icons, slots, and the strip
are `_draw()` Controls in the `_Ornament` / `PosterBackdrop` idiom. No new
fonts, no colours outside `Deco`'s constants. No `[input]` section. No
change to the sync architecture (rates, reliability, packet shape) beyond
merging new keys into rows. No frame-time gates. No question left
unrecorded.

---

## Stage 0 - baseline

Branch `feat/ui-v1` from `main`. Import. Run the three gates; record the
worldgen probe's heightmap hash and spawn in the status doc as THE baseline
for every later stage. Shoot the existing UI:

```bash
xvfb-run -a $G --path . -- --shot-ui ui-v1-baseline
```

Record the two PNGs (`main-menu.png`, `character-creation.png`) and their
pixel sizes (expect 1280x720).

**Files:** none. **Evidence:** the gate transcripts and two PNGs.
**Verify:** gates green; PNGs exist at 1280x720; hashes recorded.

## Stage 1 - stretch mode, and the shots stay comparable

**Why this design.** Everything after this stage draws Controls; they must
be drawn on a canvas that scales. `canvas_items` + `expand` scales the
poster uniformly (the deliberately-absolute Deco ornament sizes become
logical pixels, which preserves the printed-poster intent) and guarantees a
logical canvas of at least 1280x720 (Decision 11).

1. `project.godot`: add `window/stretch/mode="canvas_items"` and
   `window/stretch/aspect="expand"` to `[display]`.
2. `ui_shot.gd`: when a shot label is active, pin the window with
   `DisplayServer.window_set_size(Vector2i(1280, 720))` before the settle
   frames, so `build/ui/` output stays 1280x720 and comparable forever.
3. `main_menu.gd` `_place_band()`: the title rect crosses from global space
   into backdrop-local space by luck (full-rect Control at origin). Make it
   honest: transform via `r.position - _backdrop.global_position` (or the
   affine inverse) before `set_title_band`.
4. `character_creation.gd`: freeze the turntable while `UiShot.wanted()`
   (deterministic shots), and drive `_viewport.size` from the container's
   displayed size on its `resized` signal so the preview stays sharp when
   the canvas scale exceeds 1. Keep `PREVIEW_SIZE` as the floor.
5. `character_debug.gd`: replace the hard-coded `Vector2(352, 640)` scroll
   height with anchor-based sizing (the F4 panel's `PRESET_RIGHT_WIDE` +
   offsets approach, on the left) so F8 fits any logical height.

**Files:** `project.godot`, `scripts/ui/ui_shot.gd`,
`scripts/ui/main_menu.gd`, `scripts/ui/character_creation.gd`,
`scripts/ui/character_debug.gd`.
**Evidence:** `--shot-ui ui-v1-stretch`, plus one run with the window forced
to 2560x1440 before capture (`--shot-ui ui-v1-stretch-2x` via a temporary
size override in the driver) to prove uniform scaling.
**Verify:** gates green; 1280x720 shots exist; on the 2x shot a 9x9 PIL
sample inside the title band reads `Deco.INK` and the band's top edge sits
at 2x the baseline row (uniform scale, no drift); the F8 panel opens fully
on-screen at 720 logical (eye sentence + one shot).

## Stage 2 - the mouse owner set and the input seams

**Why this design.** Three screens will hold the cursor (F4, F8, the sheet);
the current boolean recaptures the mouse when ANY of them closes, breaking
the others - a recorded bug. And Esc, unconsumed, leaves the multiplayer
session; the sheet must never be one missed consume away from that.

1. New `scripts/ui/ui_mouse.gd`, `class_name UiMouse`: a static owner set -
   `claim(owner: Object)`, `release(owner: Object)`, `held() -> bool`.
   Mouse mode flips VISIBLE on first claim, CAPTURED on last release.
2. `debug_hud.gd` and `character_debug.gd` route `_set_panel_visible`
   through it. `DebugHUD.ui_has_mouse` remains as a one-line proxy reading
   `UiMouse.held()` so `player.gd:219`'s check keeps working, then
   `player.gd` is pointed at `UiMouse.held()` directly and the proxy
   deleted.
3. `player.gd`: exclude `MOUSE_BUTTON_WHEEL_*` from the click-to-recapture
   branch (wheel must never recapture; it will belong to the hotbar).
4. Add a headless-testable assertion block to
   `scripts/tools/selftest.gd` (append-only): claim/claim/release leaves
   `held()` true; release-all leaves it false; double-release of one owner
   is harmless.

**Files:** `scripts/ui/ui_mouse.gd` (new), `scripts/ui/debug_hud.gd`
(append-banner rule applies - the `_set_panel_visible` body is four lines
and predates the append rule; changing exactly those lines is in-bounds and
recorded), `scripts/ui/character_debug.gd`, `scripts/player/player.gd`,
`scripts/tools/selftest.gd`.
**Evidence:** selftest transcript. **Verify:** gates green; the new
assertions counted in the selftest output.

## Stage 3 - the stats table, the sync ride, and the journal

**Why this design.** Habit 1: the bars must read facts, and the facts live
on the host. Decision 1 puts them on the wire for free.

1. New `scripts/game/stats.gd`, `class_name StatsTable extends RefCounted`.
   One table: `peer_id -> {hp, sp, mp}` plus a const `DEFAULTS`
   (`hp 100.0, sp 100.0, mp 100.0` - maxima equal defaults until a system
   says otherwise, and the maxima are data in the same const, not code).
   API: `ensure_row(peer_id)`, `erase(peer_id)`, `get_row(peer_id)`,
   `apply_delta(peer_id, stat, delta, cause) -> float` clamping to
   [0, max]. `apply_delta` is THE mutation seam - nothing else writes a
   stat - and it journals `stat_changed {peer, stat, from, to, cause}`
   through an injected Journal (skips journaling on a no-op delta).
   Health at 0 does nothing further - there is no death system, and the
   table says so in its docstring.
2. `game.gd`: `_stats := StatsTable.new()` beside `_states` (host only,
   like `_journal`); inject the journal; `ensure_row` for the host at world
   ready and for peers in `_on_peer_joined`; `erase` in `_on_peer_left`;
   a `_publish_stats()` called from the existing 20 Hz block that merges
   `{"hp": ..., "sp": ..., "mp": ...}` into every peer's `_states` row via
   `_merge_state` (per-tick fields, same contract as `p`/`v`). Retain the
   last received table on clients (`_last_states := states` in
   `_apply_states`, one line) and expose `peer_stats(peer_id) -> Dictionary`
   reading host table or client copy as appropriate.
3. The H key (Decision 6): host-side self-damage 10 through
   `_stats.apply_delta`, `_unhandled_input` beside the G handler's old home,
   marked TEMPORARY with the same docstring contract the slab had.
4. The journal gap (Decision 10): `world.gd` gains `set_journal(j)` and one
   `log_event("block_edit", {peer, pos, block})` immediately after
   `_edits[world_block_pos] = block_id` in `_host_apply_edit`; `game.gd`
   injects at the same site BodyField gets it. The client's `_cl_apply_block`
   journals nothing.
5. Append to `scripts/tools/selftest.gd`: StatsTable defaults, clamp at 0
   and max, no-op delta journals nothing, real delta journals exactly one
   event with `from`/`to` correct.

**Files:** `scripts/game/stats.gd` (new), `scripts/game/game.gd`,
`scripts/world/world.gd` (the exception, two appends),
`scripts/tools/selftest.gd`.
**Evidence:** selftest transcript; worldgen probe hash vs Stage 0.
**Verify:** gates green, hash identical, new assertions counted.

## Stage 4 - the HUD frame, the bars, the fade, and the harness that proves them

**Why this design.** The harness comes WITH the HUD, not after it - every
later stage's evidence is a `--shot-hud` PNG, so the driver is built here,
first.

1. **The driver.** A `--shot-hud <label>` branch in `game.gd`'s cmdline
   handling: boot `game.tscn` as an offline host, seed 42, wait for
   `is_world_ready()`, then step a scripted sequence, capturing via
   `UiShot.capture` (window pinned 1280x720) into `build/ui/<label>/`:
   `safe-noon` (SkyCycle frozen at 0.5, stats full - expect NO HUD ink),
   `night` (frozen 0.0 - expect HUD in), `hurt` (apply -30 hp - bars in,
   health visibly short), `sheet` (Stage 6 appends), `party` (Stage 5
   appends). SkyCycle has a `frozen` flag for exactly this; the tour uses
   it already. Settle 6 frames per shot, the `ui_shot.gd` convention.
2. **`scripts/ui/hud.gd`** on the existing `$HUD` CanvasLayer (one `script=`
   line in `game.tscn`), `_hud.setup(sky, world, player, game)` from
   `game.gd:_ready`. It owns layout: the bottom-centre cluster container and
   the top strip mount, anchors and margins only, no absolute positions.
3. **Bars.** One drawn Control class (`_draw()`: hairline `Deco.INK` frame,
   track `Deco.PAPER` at low alpha, fill a Deco constant per stat - start
   `SUN` for health, `ALPINE_PALE` stamina, `ALPINE_DEEP` mana - a taste
   ruling for Marcel, listed in the status doc). Three instances stacked
   thin above the hotbar mount. Values from `game.peer_stats(own_id)` on
   the host and `last_authority()` on a client - display only.
4. **The fade.** `hud.gd` computes safe-ness per frame: stats at max AND no
   stat changed for `fade_grace_s` AND night below `fade_night_max`
   (computed CPU-side from the statics:
   `SkyCycle.night_amount(SkyCycle.sun_position(sky.time_of_day).y)` - no
   world file is written for this) AND danger below `fade_danger_max`
   (`world.generator.danger_at` - mirror `zone_name_at_m`'s metre-to-block
   conversion in a private helper; the generator exists and agrees on both
   host and client, and the plan notes `danger_at`'s bounded-region
   normalisation as a recorded caveat, not a blocker). Safe eases opacity
   to 0 over `fade_out_s`; unsafe restores over `fade_in_s` (faster). The
   compass strip (Stage 5) gets a separate `strip_floor_alpha`.
   Time-of-day is per-client and unsynced; that is fine for a look input
   and the status doc says so.
5. **`scripts/ui/hud_config.gd`** (`HudConfig extends Resource`,
   `user://ui.tres`): `fade_grace_s`, `fade_night_max`, `fade_danger_max`,
   `fade_out_s`, `fade_in_s`, `strip_floor_alpha`, bar/cluster size scalars.
   **`scripts/ui/hud_tuner.gd`**: the F9 panel, layer 12, a straight copy of
   the `character_debug.gd` row pattern, with a save button. Every value
   chosen by eye in Stages 4-6 lands here - hard rule.
6. **Status retirement** (Decision 5): the permanent crib line moves into
   the F3 readout (appended under the `# UI V1` banner); `_update_status`
   keeps only transient messages.

**Files:** `scripts/ui/hud.gd`, `hud_config.gd`, `hud_tuner.gd` (new),
`scenes/game.tscn`, `scripts/game/game.gd`, `scripts/ui/debug_hud.gd`
(F3 append only).
**Evidence:** `xvfb-run -a $G --path . -- --shot-hud ui-v1-hud` -> at least
`safe-noon.png`, `night.png`, `hurt.png`.
**Verify:** gates green, hash identical. PIL: in `safe-noon.png` a 9x9
sample at the bar cluster's named position matches the same sample region
of the world with NO `Deco.INK`/`SUN` presence (the HUD is genuinely gone);
in `hurt.png` the health bar region contains `SUN` hue and the filled
fraction is 0.70 of track width +/- 2 px (a count, from a -30 on 100).

## Stage 5 - hotbar, compass strip, party icons, and the nametag dies

1. **Hotbar** (`scripts/ui/hotbar.gd`): five drawn slot frames
   (`DecoPanel`-idiom chamfered squares), bottom-centre under the bars.
   Selection by keys 1-5 and wheel (consumed in `_unhandled_input`; wheel
   only while captured). `Deco.GOLD` on the selected frame ONLY. Slot 1
   holds the slab tool (label "SLAB", drawn glyph, no texture); LMB while
   captured uses the held thing - slot 1's use calls the existing slab
   placement through `world.request_set_block` (which now journals). Slots
   2-5 empty and selectable. The G binding is deleted in this commit.
   A context dot (the only crosshair) draws centre-screen only while the
   held slot can act - slot 1 yes, empty slots no.
2. **Compass strip** (`scripts/ui/compass.gd`): top-centre drawn Control;
   cardinals N E S W + minor ticks scrolling by
   `-player.camera_yaw()`; the `NORTH_IS_MINUS_Z` constant with Decision
   4's justification comment. Party chevrons: for each other peer, bearing
   from `_states` positions (via `game.peer_row`), tinted
   `RemotePlayer.color_for_peer(id)` - the function stays where it is,
   static, per its own doc comment. Strip respects `strip_floor_alpha`
   when the HUD fades.
3. **Party icons** (`scripts/ui/party_icons.gd`): one small drawn roundel
   per other peer at the cluster's left edge, peer hue, display name in
   `SectionLabel` beneath at reduced size; a thin health arc appears on the
   icon only when that peer's `hp` is below max (from the synced row);
   downed later - no death system yet, recorded, not built. Zero icons
   solo. Cap 4 total bodies honoured by layout.
4. **The nametag removal**, complete: `scenes/remote_player.tscn` Nametag
   node; `remote_player.gd` `@onready` ref, the four feed sites, and the
   height line; the name-change site becomes a stored `display_name` field
   the party icons read; the class doc paragraph explaining why the body
   is never tinted is REWRITTEN in the same voice (that reasoning still
   holds), not deleted; `selftest_character.gd`'s four `Nametag` lines are
   deleted (the test would crash on the missing node - it is a no-op check
   today).
5. **Driver additions:** `party` shot - inject a scripted fake peer row
   (peer 2, fixed position 20 m due east, name "KIRA", hp 60) through the
   normal `_merge_state` path plus a spawned RemotePlayer, then capture;
   and a `use` step that fires slot 1 once and prints the journal dump.

**Files:** `scripts/ui/hotbar.gd`, `compass.gd`, `party_icons.gd` (new),
`scripts/ui/hud.gd`, `scripts/game/game.gd`,
`scripts/player/remote_player.gd`, `scenes/remote_player.tscn`,
`scripts/tools/selftest_character.gd`.
**Evidence:** `--shot-hud ui-v1-party` -> `party.png`, `use` journal dump.
**Verify:** gates green (character selftest MUST pass post-removal), hash
identical. Counts: journal dump contains exactly one `block_edit` with
peer 1; in `party.png` a 9x9 sample on the peer-2 icon matches
`color_for_peer(2)` hue +/- tolerance (the value is computable:
`fposmod(2 * 0.61803398875, 1.0)`), the compass chevron sits in the east
half of the strip, and NO pixel of the old nametag font renders above the
remote body's head region (named row band, INK/PAPER absence check).

## Stage 6 - the character screen

1. **Extract the turntable**: `scripts/ui/character_preview.gd`,
   `class_name CharacterPreview extends SubViewportContainer`, built from
   `character_creation.gd:70-144` with its two known corrections:
   `own_world_3d = true` on the SubViewport (in the game scene the default
   would render the LIVE WORLD and its `camera.current` would fight the
   player camera - this is the load-bearing line of the stage) and
   `UPDATE_WHEN_VISIBLE`. API: `build(def)`, `spin(delta)`,
   `set_spinning(bool)`. `character_creation.gd` is refactored onto it;
   the creation screen must survive unchanged to the eye.
2. **The sheet** (`scripts/ui/character_screen.gd`, layer 5): C toggles
   (raw key, `_unhandled_input`, consumed); claims `UiMouse`; consumes
   `ui_cancel` in `_input()` when open - Esc closes the sheet and must
   NEVER fall through to the leave-session handler. Poster register:
   `DecoPanel.stepped()` frame, ink ground. Left: the preview, built from
   the live `Player/View` def (`get_node("View").def` - the runtime truth),
   spinning. Right: the player's display name (`AccentLabel`), race line;
   the six armour sockets as labelled empty frames from
   `CharacterDef.ARMOUR_SLOT_NAMES` + `Armour.SLOTS` (every tier is 0 in
   real sessions today - the sockets render their labels and an em-dash;
   Items v1 fills them, and the render path `apply_armour` already works
   the day it does); below, the five skills.
3. **`scripts/character/skills.gd`** (new, names-only): `class_name Skills`,
   a const table of the five skill names from `DESIGN.md` (Blades, Bows,
   Magic, Mobility, Gathering). The sheet renders name + "-" for level.
   Facts as data: Skills v1 (J) replaces the dash with truth without
   touching the sheet's structure. Nothing on this screen is clickable
   except close.
4. **Driver addition:** `sheet` shot - open the sheet in the driver, settle,
   capture.

**Files:** `scripts/ui/character_preview.gd`, `character_screen.gd`,
`scripts/character/skills.gd` (new), `scripts/ui/character_creation.gd`,
`scripts/ui/hud.gd` (C key mount), `scenes/game.tscn`.
**Evidence:** `--shot-hud ui-v1-sheet` -> `sheet.png`; re-shoot
`--shot-ui ui-v1-creation-after`.
**Verify:** gates green, hash identical. `sheet.png`: six socket labels and
five skill names present (OCR is not available - verify by construction:
the driver prints the sheet's label texts, count 6 + 5); the creation
re-shoot diffs against Stage 1's within `tools/png_diff.py` tolerance
measured on two same-commit runs (the turntable is frozen under shots since
Stage 1, so the diff is meaningful).

## Stage 7 - acceptance, status, merge

Run everything: the three gates, `--shot-ui` both labels, `--shot-hud` all
states. Fill the acceptance table. Finish `docs/status/ui-v1.md` (shape per
**How to use**), point `STATUS.md` at it. Then the merge posture of
Decision 9 - merge `main` in first if it moved, gates again, then to
`main`; anything unresolved stays on the pushed branch with the status doc
saying exactly where and why.

---

## Time budget

One night. Shares: Stage 0 - 0.5h, Stage 1 - 1h, Stage 2 - 0.5h, Stage 3 -
1.5h, Stage 4 - 2h, Stage 5 - 2h, Stage 6 - 1.5h, Stage 7 - 0.5h. A stage
past 1.5x its share is wrapped at its last green commit and the next stage
starts; what was cut goes in the status doc. **Stages 0, 1 and 3 are never
wrapped** - everything sits on them. If the night ends inside Stage 5 or 6,
the branch is still a coherent partial ship: bars + fade alone are a
reviewable HUD.

## Hard rules

1. The worldgen probe hash and spawn match Stage 0's baseline at every
   stage. A UI lane that moves a block stops and records.
2. No file under `scripts/world/` is written except the two appended lines
   in `world.gd` (Decision 10). `worldgen_config.gd` is not touched at all.
3. `debug_hud.gd`: F3 appends under a `# UI V1` banner and the Stage 2
   `_set_panel_visible` rewiring only. Never `TUNING_ROWS`,
   `LOCAL_TUNING_ROWS`, `_build_panel`, `_spin_row`, panel keys.
4. No textures, no image assets, no new fonts, no colours outside `Deco`'s
   constants. Gold appears on the selected hotbar slot and nowhere else.
5. Every value chosen by eye is on the F9 panel and listed in the status
   doc with its starting and final value.
6. No frame-time gates. Timings, if ever quoted, are labelled single-run
   and non-binding.
7. Sync shape is untouched: 20 Hz, unreliable_ordered, whole-table
   broadcast. New row keys, yes; new channels or rates, no.
8. Stats are display-only on clients. No client-side stat prediction, no
   client write path to a stat, ever.
9. The sheet is read-only. If a stage is tempted to make something on it
   clickable, that stage is out of scope by pillar ruling.
10. `ui_cancel` from the open sheet never reaches the leave-session
    handler. This is tested by hand-reasoning in review AND by the driver
    (send Esc with sheet open, assert still in game scene).
11. Solo runs clean: zero party icons, fade fully functional, no code path
    that assumes a second peer. Cap 4 respected in layout.
12. Fast-forward pushes only; one commit per stage minimum; conventional
    prefix `feat(ui):` / `fix(ui):`; body names what changed and which shot
    judged it; the Co-Authored-By trailer per repo convention.
13. A conflict in an unowned file is not the agent's to resolve. Stop,
    record, leave the branch pushed.

## Acceptance

- The three gates green on the final commit, probe hash = Stage 0.
- `safe-noon.png` shows a screen with zero HUD ink (sampled, named
  regions) - safety looks like an empty screen.
- `hurt.png` shows three bars with health at 0.70 +/- 2 px of track.
- `party.png` shows the peer-2 icon in the computable hue, a chevron in
  the east half of the strip, and no nametag above the body.
- The journal dump from the `use` step contains `block_edit` and the H-key
  step `stat_changed`, each exactly once, host-side.
- `sheet.png` lists six sockets and five skills; nothing on it is
  interactive except close.
- Creation screen re-shoot within measured tolerance of Stage 1's.
- **And: shoot the night HUD over a far ridge at dusk.** If the strip, the
  bars and the world do not read as one poster - if the UI looks pasted on
  - the pass is not done, whatever the numbers say. Frame it, name it
  `dusk-poster.png`, and leave it for Marcel.

## For Marcel to rule on

Expected entries the run must leave open rather than decide: the three bar
colour assignments (SUN/ALPINE_PALE/ALPINE_DEEP is the starting guess);
fade thresholds and grace period as felt in play; compass strip density
(tick count, cardinal size); whether the party icon shows the name always
or only on hurt; hotbar slot size against the monumental horizon. Do not
block on any of these; ship the starting values on F9 and list them.

## Handoff

`docs/status/ui-v1.md` records: every hash, every F9 starting/final value,
the shots and their rulings, what was wrapped or deferred and why, and the
inheritance notes: Combat v1 (D) inherits the stats table, the H key to
delete, and the downed hook on the party icon; Items v1 (G) inherits the
hotbar shell, the slab tool to delete, and the empty sockets; Campfire v1
(E) inherits the placeable palette's home in the hotbar and the fade's
"firelight is safe" input, which this pass stubs as night-only; Navigation
v1 (I) inherits the compass strip and adds markers and the map screen;
Skills v1 (J) replaces the dashes on the sheet.
