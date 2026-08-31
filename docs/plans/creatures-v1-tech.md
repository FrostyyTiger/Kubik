# Creatures v1 tech - the overnight procedure, night 1

The build plan for `docs/plans/creatures-v1.md`. That document decides
*what*; this one is the procedure. Where the two disagree, the design doc
wins unless the disagreement is argued in **Decisions** below.

Written 2026-08-31 against `2cd7b0a` on `main`. Target: ganymede, branch
`feat/creatures-v1`, TWO nights; this document fully specifies **night 1
(Stages 0-8)** and sketches night 2, which gets its stages written against
night 1's status doc. The agent executing this plan reads **How to use this
document** before its first edit.

**Three lanes run on this box tonight.** `feat/distance-v3` (owns
`scripts/world/` far files, `worldgen_config.gd`, `debug_hud.gd` tuning
rows) and `feat/ui-v1` (owns `scripts/ui/` HUD files, `scripts/game/game.gd`
outright, `stats.gd`, `player.gd`, the scenes) are live. This lane's
territory is drawn to touch neither, and where a shared file cannot be
avoided the touch is a banner-marked append. A merge conflict at landing
time is EXPECTED in `game.gd` and `selftest.gd` and is night 2's problem,
not tonight's.

---

## The design decisions, mapped

The six decisions in `creatures-v1.md` are binding. Where each lands:

| # | decision | binds |
| --- | --- | --- |
| 1 | the pack is the point - two wolves converging | Stage 6 |
| 2 | groundwork is the deliverable - bus, board, paths, table | Stages 1, 3, 4 |
| 3 | perception simplified, interface honest - no distance checks in trees | Stage 3, hard rule 4 |
| 4 | stats are the UI lane's; the bite ships disarmed | Stage 6, hard rule 6 |
| 5 | the scenario probe is a stage; headless, faster than real time | Stage 2 |
| 6 | every creature has an address - dens, not spawners | Stage 5 |

## Decisions this plan makes

1. **Creatures are height-snapped kinematics, not physics bodies.** A wolf
   is a `Node3D` standing on `World.surface_height_m()` (the flora Y rule:
   top face of the surface block), moved along its path by the server. No
   `CharacterBody3D`, no Jolt cost, no collision shape in v1; the bite is a
   range check. Boulder/creature interplay deferred and recorded.
2. **CreatureServer is self-contained and self-ticking.** One node,
   constructed on host AND client from a single banner hook in `game.gd`
   (`add_child`, fixed name "Creatures", after the BodyField block so the
   same ordering guarantee holds). It owns its own 20 Hz accumulator in
   `_process` and its own `@rpc` - `game.gd`'s sync path, rates and packet
   shape are untouched (the ui lane owns that file tonight).
3. **The sync row copies the BodyField school.** Host broadcasts
   `id -> [pos: Vector3, yaw: float, state: int, species: int]` on its own
   unreliable_ordered rpc, distance-filtered at 128 m, capped at 16 rows,
   nearest first (`body_field.gd:355-363` is the model). Clients are
   display-only: they build views and interpolate, never decide.
4. **Night 1's wolf wears the critter's body.** The client view builds
   `Rig` + `Animator` exactly as `character_gallery.gd:1085-1091` does:
   `rig.build(PartsCritter.bone_table(), PartsData.module("critter"),
   PartsCritter.palette(), config.ao_strength)`, gait `"trot"`. A real
   animated quadruped exists in the repo today; the wolf-authored model is
   night 2's Stage. No new art tonight.
5. **The behaviour library is decided once, in Stage 0, by a ladder.**
   (a) LimboAI release compatible with Godot 4.7.2, vendored under
   `addons/limboai/` with BOTH `linux.x86_64` and `windows.x86_64` binaries
   in-repo; prove load headlessly. (b) If no compatible release or the load
   fails: Beehave (pure GDScript) vendored under `addons/beehave/`.
   (c) If the network or both fail: `scripts/creatures/bt.gd`, a minimal
   hand-rolled tick tree (Sequence / Selector / Condition / Action,
   RUNNING / SUCCESS / FAILURE), ~150 lines. The ladder is time-boxed to
   one hour; the rung taken is recorded in the status doc with the exact
   version pinned. The wolf's tree logic is the same shape on any rung.
6. **The species table is the Races doctrine applied to animals.**
   `class_name Species`, const TABLE as an Array indexed by enum
   (`WOLF/MARMOT/EAGLE`), static accessors, prose `silhouette` field
   included. EVERY per-species number in the game lives here - senses
   ranges, speeds, slope-cost weights, territory radius, bite damage,
   huntable flag, home type, archetype. Nothing else carries one.
7. **Salts 400-419 are claimed for creature homes**, documented beside the
   registry pattern (`tree_placement.gd:56-67` school): 400 den present,
   401 den jitter x, 402 den jitter z, 403 burrow field, 404 burrow count,
   405-419 reserved. Hashed via `WorldHash`, no RNG, no stream.
8. **Creature events are journal events**, same injection pattern as
   BodyField (`game.gd:179`). Kinds and fields are documented in a block
   comment in `species.gd` as THE schema: `howl, spotted, lost, converge,
   engage, bite, leash_turn, den_placed` now; `whistle, dive, emerge, cry,
   perch` reserved for night 2. Every event carries `{species, id, pos}`
   plus its own fields. This is habit 2's stream and the probe's evidence.
9. **Branch posture.** `feat/creatures-v1` from `main` at `2cd7b0a`, one
   commit per stage minimum, push after every stage, fast-forward only.
   **Night 1 does NOT merge to main** - two lanes will land ahead of us and
   the `game.gd` / `selftest.gd` appends must be re-merged by night 2's
   opening move (`git merge origin/main`, resolve the banner blocks, all
   gates green) before any night-2 work.
10. **The probe outruns the clock where it can.** Headless with no vsync
    the engine free-runs already; if a scenario is still wall-clock bound,
    raise `Engine.time_scale` (with `physics_ticks_per_second` scaled to
    match) and record both values per scenario. Timings quoted from probe
    runs are single-run smoke alarms, never gates.

---

## How to use this document

**Environment.** Ganymede, headless Linux. Binary at `~/bin/godot`:

```bash
G=~/bin/godot
$G --headless --path . --import   # once after checkout, and after any pull that adds a class_name
```

The creature probe is `--headless`, unwrapped - no GPU, no xvfb. Only the
Stage 8 shots render, via `xvfb-run -a`. Output under
`build/creatures/<label>/`.

**Reading order before the first edit:** `docs/plans/creatures-v1.md`
whole; `CLAUDE.md`; `docs/DESIGN.md` § Creatures (the five rules and the
tool table); `scripts/character/races.gd:1-30` and its TABLE;
`scripts/character/parts/parts_critter.gd` whole (82 lines);
`scripts/character/animator.gd:305-390` (RIG_SHAPES, `rig_shape()`,
`pose_for()`); `scripts/character/rig.gd:1-70`;
`scripts/game/journal.gd` whole (47 lines); `scripts/game/game.gd:56-75`
(the row shape), `:164-184` (the BodyField ordering comment - load-bearing),
`:186-203` (the cmdline chain), `:286-307` (the sync tick), `:834-880`
(peers and centres); `scripts/physics/body_field.gd:14-46` and `:355-420`
(the doctrine and the row filter); `scripts/world/world.gd:1658-1700` (the
mutation path), `:1908-1957` (the public ground accessors);
`scripts/world/heightmap.gd:26-100` (`step`, `slope_deg_at`);
`scripts/world/terrain_generator.gd:78-88` (zones), `:550`, `:571`,
`:1009-1021` (`danger_at` and its doc); `scripts/world/flora/tree_placement.gd:19-80`
and `:290-330` (the product, the one function, the ordering);
`scripts/world/flora/flora_placement.gd:11-18` and `:515-559` (determinism,
identity); `scripts/tools/traversal_probe.gd` whole (the walker to copy);
`scripts/tools/worldgen_probe.gd:39-99`; `scripts/tools/selftest.gd:29-75`
(the test convention). Line numbers are from `2cd7b0a` - **search for the
quoted identifiers, do not trust the numbers blind.**

**The measurement rule.** No frame-time gates. Every gate is a count, a
hash, a journal-event assertion, or a tolerance band over >= 5 seeded probe
runs reported as a median. Behaviour is judged from the event log, looks
are judged from Stage 8's shots by Marcel.

**The gates, run at the end of every stage, in order:**

```bash
$G --headless --path . scenes/selftest.tscn
$G --headless --path . scenes/character/selftest_character.tscn
$G --headless --path . --script scripts/tools/worldgen_probe.gd -- --seed 42
```

The probe's heightmap hash and spawn are re-baselined in Stage 0 and must
never move. A creature lane that moves a block has left its lane; stop and
record.

**Failure protocol.** Where this plan does not answer a question, record it
in the status doc and take the conservative path, never widening scope. If
the run dies: commit what is clean, note where, resume from the next stage
boundary.

**Status doc.** `docs/status/creatures-v1.md`, written at the end of every
stage: provenance-tagged numbers (ganymede, deterministic / probe median of
N / single run / eye), the baseline hash at every stage, the Stage 0 ladder
rung and pinned version, failures named, a "For Marcel to rule on" section,
the deferred list, and what night 2 inherits. At the end of the night,
`STATUS.md` at the repo root points to it.

---

## Territory

**Owned outright (all new):** `scripts/creatures/` - `species.gd`,
`senses.gd`, `pack_board.gd`, `creature_nav.gd`, `home_placement.gd`,
`creature_server.gd`, `creature.gd`, `wolf.gd`, `creature_view.gd`, and
`bt.gd` only if ladder rung (c); `scripts/tools/creature_probe.gd`;
`scripts/ui/creature_debug.gd`; `addons/` (new, vendored library only);
`docs/status/creatures-v1.md`; `build/creatures/`.

**Shared, banner-marked:** `scripts/game/game.gd` - exactly TWO
insertions under `# CREATURES V1` comments: (1) one `elif` line in the
cmdline chain for `--creature-probe`, (2) one contiguous appended block of
at most 25 lines: CreatureServer construction + `setup(Net.is_host(),
_world, _journal, self)` placed AFTER the BodyField block (its ordering
comment applies to us too), CreatureDebug construction, a public
`sim_centres_m()` one-line sibling of `_sim_centres_m()`, and
`_start_creature_probe()`. Nothing else in the file changes - the ui lane
owns it tonight. `scripts/tools/selftest.gd` - new tests appended under a
`# CREATURES V1` banner, never delete or reorder an existing one.

**Untouched (read, never write):** all of `scripts/world/` (homes READ the
generator; they never write it), all other `scripts/ui/`, `scripts/player/`,
`scripts/physics/`, `scripts/net/`, `scripts/character/` (the critter is
used as-is; wolf parts are night 2), `scripts/game/journal.gd` and
`stats.gd`, every `scenes/*.tscn`, `project.godot` (the GDExtension
self-registers from `addons/`; no editor-plugin enable needed for runtime).

**Never.** No painted danger zones. No creature decision on a client. No
raw distance check inside a behaviour tree (senses bus only - hard rule 4).
No per-species number outside `species.gd`. No damage applied (hard
rule 6). No new art assets tonight. No terrain edit from any creature path.

---

## Stage 0 - baseline, and the library ladder

Branch exists from `2cd7b0a`. Import. Run the three gates; record the
heightmap hash and spawn as THE baseline. Then Decision 5's ladder,
time-boxed one hour: fetch the LimboAI release for Godot 4.7 (check the
`.gdextension` `compatibility_minimum`; both platform binaries vendored),
import, prove load with `$G --headless --path . --import` clean plus a
one-line class probe (`ClassDB.class_exists("BTPlayer")` or the rung's
equivalent) appended to `selftest.gd` under the banner. Fail -> next rung.

**Files:** `addons/**` (or `scripts/creatures/bt.gd` on rung c),
`scripts/tools/selftest.gd`.
**Verify:** gates green; baseline recorded; the rung, the version and the
load proof in the status doc.

## Stage 1 - the species table and the event schema

1. `scripts/creatures/species.gd`, `class_name Species` per Decision 6.
   Columns per row: `name`, `archetype` ("rusher"/"ambient"/"sky"),
   `gait` ("trot"), `dims` (critter-DIMS-shaped, per species), `walk_mps`,
   `run_mps`, `sight_m`, `sight_deg`, `hear_m`, `slope_cost`
   (`{uphill, downhill, cliff_deg}`), `territory_m`, `home`
   ("den"/"burrow"/"crag"), `huntable` (wolf true, marmot FALSE - the
   cozy-honest rule as a column), `bite` (`{damage, range_m, cooldown_s}`,
   wolf only), `silhouette` (prose). Starting numbers are proposals; every
   one lands on F10 in Stage 8 and in the status doc.
2. The event-schema block comment (Decision 8), in the same file.
3. Selftest appends: every row carries every required key; accessors warn
   once and fall back on an unknown species (the `Races._warn_once`
   pattern).

**Files:** `scripts/creatures/species.gd` (new),
`scripts/tools/selftest.gd`.
**Verify:** gates green, hash = baseline, new assertions counted.

## Stage 2 - the scenario harness

**Why first: every later stage's evidence comes out of this.**

`scripts/tools/creature_probe.gd`, `class_name CreatureProbe extends Node`,
started by the `game.gd` elif as `--creature-probe [--scenario <name>]
[--runs N] [--seed N]`. It is `traversal_probe.gd`'s school: await
`world.is_idle()`, drive the REAL player via `wish_override` /
`sprint_override` (re-enable physics first - `traversal_probe.gd:146`), the
fall-through rescue against `surface_height_m`, and a `_finish()` that
prints a summary and quits nonzero on failure. Scenarios are a Dictionary
of name -> Callable, each returning a result dict. Tonight's null scenario:
`walk` - walk the player 200 m through the meadow, assert the journal
dumps cleanly and the probe exits 0. Multi-run: `--runs 5` repeats with
seed+i and prints per-scenario medians. Every scenario ends by dumping the
creature-kind journal slice to `build/creatures/<label>/events.json`.

**Files:** `scripts/tools/creature_probe.gd` (new), `scripts/game/game.gd`
(the two banner insertions, complete - this stage lands the whole allowed
block).
**Verify:** gates green, hash = baseline; `walk` passes 5/5; `game.gd` diff
is exactly the elif + the banner block.

## Stage 3 - senses and signals (the bus and the board)

1. `scripts/creatures/senses.gd`, `class_name SensesBus`, host-only.
   Queries: `can_see(from_pos, facing, target_pos, sight_m, sight_deg)
   -> bool` (range + cone; occlusion deferred and recorded);
   `hear_events_for(pos, hear_m) -> Array`. Emission:
   `emit_noise(pos, loudness_m, kind, source)`. Player noise derived once
   per server tick from `game.sim_centres_m()` + each peer's state byte
   (bit 1 sprint, bit 0 grounded - `locomotion_state.gd:68`): sprinting
   emits at `1.5x` base loudness, moving at `1.0x`, still at `0.3x`.
   Numbers in `species.gd`'s shared `NOISE` const, not inline.
2. `scripts/creatures/pack_board.gd`, `class_name PackBoard` - the shared
   blackboard: `members`, `target_peer`, `target_pos`, `last_seen_ms`,
   `howled_at_ms`, `den_pos`. One instance per pack, injected into each
   member's tree context. `broadcast(kind, data)` writes the board AND
   journals the event - the whistle and the howl are this one mechanism
   (design decision 2).
3. Selftest appends: cone math (behind/beside/inside cases), loudness
   scaling, board broadcast reaches a second reader.

**Files:** `scripts/creatures/senses.gd`, `pack_board.gd` (new),
`scripts/tools/selftest.gd`.
**Verify:** gates green, hash = baseline, assertions counted.

## Stage 4 - paths over the land the animals already know

`scripts/creatures/creature_nav.gd`, `class_name CreatureNav`. One
`AStarGrid2D` per pack territory, NOT per world: a square around the den,
`2 * territory_m` on a side, one cell per coarse heightmap cell (4 blocks
= 2 m, `heightmap.gd:32`). Solid diagonal policy on. Per-cell weight from
`slope_deg_at` shaped by the species `slope_cost` table (uphill dearer for
a wolf; cells past `cliff_deg` and cells under a lake's shore level -
`gen.lakes.shore_level_at_cell(gen._cell_index(...))`, `is_nan` guarded -
are solid). `path_m(from_m, to_m) -> PackedVector3Array` returns
metre-space waypoints with Y from `surface_height_m`. Movement lives in
`scripts/creatures/creature.gd` (`class_name Creature extends Node3D`):
follow waypoints at species speed scaled by ground slope, yaw-smoothed,
height-snapped per Decision 1.

Selftest appends (synthetic + real-world, the `_test_body_promotion`
two-part shape): a path across a test ridge prefers the contour over the
crest for a wolf-weighted grid; 20 random in-territory pairs on seed 42
all find paths; no waypoint lands on a solid cell.

**Files:** `scripts/creatures/creature_nav.gd`, `creature.gd` (new),
`scripts/tools/selftest.gd`.
**Verify:** gates green, hash = baseline, assertions counted.

## Stage 5 - the den has an address

`scripts/creatures/home_placement.gd`, `class_name HomePlacement` - the
`TreePlacement` school on a 64-block (32 m) candidate lattice, own Masks,
salts 400-419, `static func decide(gen, cell_x, cell_z) -> Dictionary`
("ONE FUNCTION, ASKED BY EVERYTHING"), early-out ceiling first. The
product for a den: zone in {FOREST, HEATH, ROCK} x slope band 5-25 deg x
`danger_at` band (>= 0.25, scaled up with danger) x spawn exclusion
(>= 300 m) x lattice hash. Burrow fields: MEADOW x low slope x bench-like
flatness, count hashed 3-6 per field (night 2 consumes them; placed and
tested now to prove the pattern generalises). `homes_in_region(bounds)`
enumerates; ids via the `FloraPlacement.identity()` packing with a home
model number. Nothing writes terrain, nothing spawns yet.

Probe scenario `homes`: enumerate the whole region twice - identical both
runs (the determinism contract); counts within a sane band (>= 3 dens,
>= 10 burrow fields on seed 42 - re-baseline the actual numbers in the
status doc); every den >= 300 m from spawn; every den's slope in band;
nearest den named (id, pos, danger) for Stage 6.

**Files:** `scripts/creatures/home_placement.gd` (new),
`scripts/tools/creature_probe.gd`.
**Verify:** gates green, hash = baseline (homes are a read-side
derivation); `homes` passes twice-identical.

## Stage 6 - the pack

The heart of the night. `scripts/creatures/wolf.gd` - the wolf's tree on
Stage 0's rung, states: **patrol** (waypoints hashed around the den),
**investigate** (a heard noise -> path toward it), **stalk** (seen target
-> approach), **howl** (first confirmed sight: `PackBoard.broadcast`,
journal `howl`, every member converges), **converge** (members approach
the target from bearings offset +-90-140 deg from the howler's bearing -
the flank is EXPLICIT, so the gate measures a mechanism, not luck),
**engage** (circle at bite range, lunge on cooldown - `bite` journals
`{damage_proposed, applied: 0}` per hard rule 6), **leash** (target or
self beyond `territory_m` from den -> journal `leash_turn`, disengage,
return; design decision 6's honest leash). `creature_server.gd` spawns one
pack of TWO wolves at the nearest den on world ready (host only), ticks
brains at 10 Hz staggered, total live creatures capped at 16.

Probe scenarios, each `--runs 5`, medians:
- `pack-flank`: walk the player into the territory. Howl within 5 s of
  first `spotted`; both wolves reach engage; **angular separation of the
  two wolves about the player at first simultaneous engage >= 90 deg
  median** (tolerance floor 75 deg on any single run).
- `leash`: sprint the player out of the territory. Two `leash_turn`
  events; both wolves back within `0.5 * territory_m` of the den within
  60 s; zero `engage` after the turns.
- `senses-honest`: a still player at `0.4 * hear_m` behind the sight cone
  is NOT found in 90 s (no `spotted`); the same position sprinting IS
  investigated within 20 s. Rule 1's honesty, as a number.

**Files:** `scripts/creatures/wolf.gd`, `creature_server.gd` (new),
`scripts/tools/creature_probe.gd`.
**Verify:** gates green, hash = baseline; three scenarios pass at 5-run
medians; the disarmed bite appears in `events.json` with `applied: 0`.

## Stage 7 - the wire and the view

1. `creature_server.gd` gains its own
   `@rpc("authority", "call_remote", "unreliable_ordered")
   _cl_sync_creatures(rows)` per Decisions 2-3, published from its own
   20 Hz accumulator; rows filtered 128 m / 16, nearest first.
2. `scripts/creatures/creature_view.gd` - the client body: builds the
   critter rig per Decision 4, feeds `Animator` from row velocity
   (positions lerped, the `RemotePlayer` interpolation school), state int
   maps to a small pose set (moving / still / lunge placeholder).
   The HOST also builds views for its own creatures (same class, fed
   locally) - one code path for what a creature looks like.
3. Selftest appends: row pack/unpack roundtrip; filter caps at 16;
   view node count follows row count on a synthetic feed.

Two-engine sync (the `pair_probe.gd` school) is night 2 - recorded, not
smuggled in tonight.

**Files:** `scripts/creatures/creature_server.gd`, `creature_view.gd`
(new), `scripts/tools/selftest.gd`.
**Verify:** gates green, hash = baseline, assertions counted.

## Stage 8 - the tuner, the shots, the status

1. `scripts/ui/creature_debug.gd` - F10, layer 13, the
   `character_debug.gd` row pattern (NOT `debug_hud.gd`'s TUNING_ROWS -
   the distance lane appends there): senses ranges, speeds, territory,
   flank offsets, tick rate. Every number Stage 6 chose by feel is a row.
2. Shots, `xvfb-run -a`: the pack at the den at noon and at dusk, a
   converge caught mid-flank (the probe pauses at first simultaneous
   engage and photographs the tour-camera way - `screenshot_tour.gd:899`'s
   capture recipe). Named `den-noon.png`, `den-dusk.png`, `flank.png`
   under `build/creatures/shots/`.
3. Finish `docs/status/creatures-v1.md`; point `STATUS.md` at it. Push.
   **No merge** (Decision 9).

**Files:** `scripts/ui/creature_debug.gd` (new), probe, status docs.
**Verify:** gates green, hash = baseline; three PNGs exist; the status doc
carries every number with provenance and the "For Marcel to rule on" list.

---

## Night 2 - sketched, written properly against night 1's status doc

Opening move: `git merge origin/main` (ui v1 and distance v3 will have
landed), resolve the banner appends, all gates green, re-run all Stage 6
scenarios BEFORE any new work. Then: the marmot (utility scores, whistle
through the same PackBoard broadcast, dive/emerge at burrow fields, the
untargetable flag honoured end to end); the eagle (crag placement, orbit
steering, the cry, perch - silhouette model); the wolf's own authored
model + howl/lunge poses (`parts_wolf.gd` + JSON, the parts pipeline);
arming the bite through `StatsTable.apply_delta` (one line, then the
`pack-flank` scenario asserts hp actually fell); the two-engine sync check;
the mild night-boldness dial; acceptance; merge posture per ui v1
Decision 9.

## Time budget, night 1

Stage 0 - 1h, 1 - 0.5h, 2 - 1h, 3 - 1h, 4 - 1.5h, 5 - 1h, 6 - 2h,
7 - 1.5h, 8 - 0.5h. A stage past 1.5x its share is wrapped at its last
green commit; what was cut goes in the status doc. **Stages 0, 1 and 2 are
never wrapped** - everything sits on them. If the night ends inside
Stage 6, the branch is still a coherent partial ship: table + bus + paths
+ homes, all probed, is exactly the groundwork the design doc calls the
deliverable.

## Hard rules

1. The worldgen probe hash and spawn match Stage 0's baseline at every
   stage. A creature lane that moves a block stops and records.
2. No file under `scripts/world/` is written, ever. Homes read the
   generator; `_cell_index` is called, never modified.
3. `game.gd`: the one elif and the one banner block, landed complete in
   Stage 2, never grown after. `selftest.gd`: appends under the banner
   only.
4. No raw distance-or-position check inside any behaviour tree or utility
   score - perception goes through `SensesBus`, coordination through
   `PackBoard`. This is design decision 3's guard and it is absolute.
5. Every per-species number lives in `species.gd`; every value chosen by
   eye is an F10 row listed in the status doc with starting and final
   values.
6. `applied: 0` on every bite. No stat is written, no player node is
   touched, no knockback. Arming is night 2's one line, after the merge.
7. Clients never decide. The server never renders (views are display
   nodes, not brains).
8. Creature count capped at 16 live; brain ticks 10 Hz staggered; a probe
   scenario that needs more creatures than that is out of scope tonight.
9. No frame-time gates; probe timings are single-run smoke alarms.
10. Fast-forward pushes, one commit per stage minimum, prefix
    `feat(creatures):`, body names the scenario or shot that judged it,
    the Co-Authored-By trailer per repo convention.
11. A conflict in an unowned file is not the agent's to resolve tonight.
    Stop, record, leave the branch pushed.

## Acceptance, night 1

- The three gates green on the final commit; probe hash and spawn =
  Stage 0's baseline.
- `homes` twice-identical; every den in its slope and danger bands.
- `pack-flank` median >= 90 deg over 5 runs; howl precedes every converge
  in the event log; `senses-honest` passes both halves; `leash` produces
  exactly two `leash_turn` and zero post-turn engages.
- `events.json` from Stage 6 validates against the schema comment: every
  event carries `{species, id, pos}`, every bite carries `applied: 0`.
- The Stage 8 shots exist; `flank.png` shows two wolves on opposite sides
  of the player.
- `game.gd`'s diff against `2cd7b0a` is the elif plus one banner block,
  nothing else; no write under `scripts/world/`.

## For Marcel to rule on

Left open on purpose, shipped at starting values on F10: pack size (2) and
territory radius (150 m); sight 40 m / 110 deg, hearing 30 m base; the
flank offset band (90-140 deg); wolf speeds (walk 2.0, run 7.5 m/s vs the
player's 4.4 walk / sprint multiplier); bite damage (15, disarmed); whether
the critter stand-in reads acceptably wolf-shaped until night 2's model;
den visual treatment (nothing is placed visually tonight - the den is an
address; night 2 may give it a scree mouth or keep it invisible).

## Handoff

Night 2 inherits the merge, the marmot, the eagle, the wolf model, and the
armed bite. Combat v1 (D) inherits the bite seam (`propose -> apply_delta`)
and the hurt-wolf memory rule. Sites v1 (H) inherits dens as the first
`site_type` rows. The director (K) inherits the event schema - the journal
is now being written by the world itself. Water v1 (B) is warned:
`creature_nav` treats lake cells as solid; rivers must join that contract.
